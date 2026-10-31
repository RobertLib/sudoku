//
//  ConfettiView.swift
//  sudoku
//

import SwiftUI

/// A one-shot burst of falling confetti drawn with Canvas.
struct ConfettiView: View {
    /// When the burst was thrown; `nil` until then.
    @State private var start: Date?
    @State private var particles: [Particle] = []
    @Environment(\.palette) private var palette

    private let lifetime: Double = 4.5

    struct Particle {
        var x: Double          // 0...1 of width at launch
        var velocityX: Double  // points per second
        var velocityY: Double
        var spin: Double
        var wobble: Double
        var size: CGSize
        var color: Color
        var delay: Double
        var isCircle: Bool
    }

    var body: some View {
        TimelineView(.animation(paused: particles.isEmpty)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start ?? timeline.date)
                for particle in particles {
                    let t = elapsed - particle.delay
                    guard t > 0, t < lifetime else { continue }
                    let gravity = 520.0
                    let drag = 0.55
                    let x = particle.x * size.width + particle.velocityX * t * drag + sin(t * particle.wobble) * 14
                    let y = size.height * 0.32 + particle.velocityY * t + 0.5 * gravity * t * t
                    guard y < size.height + 40 else { continue }
                    let fade = min(1, (lifetime - t) / 0.8)
                    var copy = context
                    copy.opacity = fade
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(t * particle.spin))
                    copy.scaleBy(x: cos(t * particle.wobble * 1.3), y: 1)
                    let rect = CGRect(origin: CGPoint(x: -particle.size.width / 2, y: -particle.size.height / 2), size: particle.size)
                    let shape = particle.isCircle ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                    copy.fill(shape, with: .color(particle.color))
                }
            }
        }
        .onAppear {
            // Only once: it appears again when the player comes back from a screen pushed over the game.
            guard start == nil else { return }
            start = .now
            particles = Self.makeParticles(accent: palette.accent)
        }
        .task {
            try? await Task.sleep(for: .seconds(lifetime + 1))
            particles = []
        }
    }

    private static func makeParticles(accent: Color) -> [Particle] {
        let colors: [Color] = [accent, .yellow, .pink, .orange, .green, .purple, .mint, .red]
        return (0..<150).map { index in
            Particle(
                x: Double.random(in: 0.1...0.9),
                velocityX: Double.random(in: -260...260),
                velocityY: Double.random(in: -720 ... -320),
                spin: Double.random(in: -9...9),
                wobble: Double.random(in: 3...9),
                size: CGSize(width: Double.random(in: 6...11), height: Double.random(in: 9...16)),
                color: colors[index % colors.count],
                delay: Double.random(in: 0...0.35),
                isCircle: index % 5 == 0
            )
        }
    }
}

/// A tiny picture of a board, used on cards.
struct MiniBoardView: View {
    let givens: [UInt8]
    let values: [UInt8]
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let cell = side / 9
            let board = CGRect(x: 0, y: 0, width: side, height: side)
            context.fill(Path(roundedRect: board, cornerRadius: side * 0.1), with: .color(palette.boardBackground))

            for index in 0..<81 where values[index] != 0 {
                let rect = CGRect(
                    x: CGFloat(index % 9) * cell + cell * 0.18,
                    y: CGFloat(index / 9) * cell + cell * 0.18,
                    width: cell * 0.64,
                    height: cell * 0.64
                )
                let color = givens[index] != 0 ? palette.givenDigit.opacity(0.75) : palette.accent
                context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.15), with: .color(color))
            }

            var thick = Path()
            for i in 1..<3 {
                let offset = CGFloat(i * 3) * cell
                thick.move(to: CGPoint(x: offset, y: 0))
                thick.addLine(to: CGPoint(x: offset, y: side))
                thick.move(to: CGPoint(x: 0, y: offset))
                thick.addLine(to: CGPoint(x: side, y: offset))
            }
            context.stroke(thick, with: .color(palette.thickLine.opacity(0.6)), lineWidth: 1)
            context.stroke(Path(roundedRect: board.insetBy(dx: 0.5, dy: 0.5), cornerRadius: side * 0.1), with: .color(palette.thickLine.opacity(0.6)), lineWidth: 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
