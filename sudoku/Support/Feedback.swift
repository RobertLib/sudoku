//
//  Feedback.swift
//  sudoku
//
//  Haptics and synthesized sound effects. Sounds are generated at runtime,
//  so the app ships without audio files and works fully offline.
//

import AVFoundation
import UIKit

nonisolated enum FeedbackEvent: Hashable, Sendable {
    case selection
    case place
    case note
    case erase
    case undo
    case blocked
    case mistake
    case houseCompleted
    case hint
    case win
    case gameOver
}

enum Feedback {
    static func play(_ event: FeedbackEvent, settings: AppSettings) {
        if settings.hapticsEnabled {
            Haptics.play(event)
        }
        if settings.soundEnabled {
            SoundEngine.shared.play(event)
        }
    }
}

private enum Haptics {
    static let selection = UISelectionFeedbackGenerator()
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let soft = UIImpactFeedbackGenerator(style: .soft)
    static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    static let notification = UINotificationFeedbackGenerator()

    static func play(_ event: FeedbackEvent) {
        let generator: UIFeedbackGenerator
        switch event {
        case .selection: selection.selectionChanged(); generator = selection
        case .place: light.impactOccurred(); generator = light
        case .note, .erase, .undo: soft.impactOccurred(intensity: 0.7); generator = soft
        case .blocked: rigid.impactOccurred(intensity: 0.5); generator = rigid
        case .mistake, .gameOver: notification.notificationOccurred(.error); generator = notification
        case .houseCompleted: rigid.impactOccurred(); generator = rigid
        case .hint: soft.impactOccurred(); generator = soft
        case .win: notification.notificationOccurred(.success); generator = notification
        }
        // Moves come in runs: keeps the Taptic Engine ready for the next one, without the start-up delay.
        generator.prepare()
    }
}

/// Plays short synthesized tones through a small pool of player nodes.
final class SoundEngine {
    static let shared = SoundEngine()

    private var engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [FeedbackEvent: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var isConfigured = false
    /// Pauses the engine once the sounds have played: a running engine keeps the audio hardware busy.
    private var idleTask: Task<Void, Never>?
    private var resetObserver: (any NSObjectProtocol)?

    private init() {}

    /// Sets up the audio engine and renders the sounds ahead of time (off the
    /// main thread) so the first sound plays without delay.
    func warmUp() async {
        guard configureIfNeeded() else { return }
        let events: [FeedbackEvent] = [.place, .note, .erase, .undo, .mistake, .houseCompleted, .hint, .win, .gameOver]
        let sampleRate = format.sampleRate
        let rendered = await Task.detached(priority: .utility) {
            events.compactMap { event in
                Self.tones(for: event).map { (event, Self.synthesize($0, sampleRate: sampleRate)) }
            }
        }.value
        for (event, samples) in rendered where buffers[event] == nil {
            buffers[event] = makeBuffer(samples)
        }
    }

    func play(_ event: FeedbackEvent) {
        guard configureIfNeeded(), let buffer = buffer(for: event) else { return }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                // An interruption (a call, Siri) deactivates the session, and nothing else would turn it back on.
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    try engine.start()
                } catch {
                    return
                }
            }
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        try? player.playAudio()

        idleTask?.cancel()
        idleTask = Task {
            // Longer than any sound (the longest lasts about a second).
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            engine.pause()
        }
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }
        if resetObserver == nil {
            resetObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            }
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return false
        }
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            do {
                try engine.connectNode(player, to: engine.mainMixerNode, format: format)
            } catch {
                engine.detach(player)
                continue
            }
            players.append(player)
        }
        guard !players.isEmpty else { return false }
        engine.mainMixerNode.outputVolume = 0.55
        engine.prepare()
        isConfigured = true
        return true
    }

    /// After the media services restart (rare), the engine and its nodes are dead: the next sound
    /// sets everything up again. The rendered buffers don't depend on the engine and are kept.
    private func rebuild() {
        idleTask?.cancel()
        engine.stop()
        engine = AVAudioEngine()
        players = []
        nextPlayer = 0
        isConfigured = false
    }

    // MARK: Synthesis

    private nonisolated struct Tone: Sendable {
        var frequency: Double
        var start: Double
        var duration: Double
        var volume: Double
        var harmonics: [Double] = [1, 0.35, 0.12]
    }

    private nonisolated static func tones(for event: FeedbackEvent) -> [Tone]? {
        switch event {
        case .selection, .blocked:
            return nil
        case .place:
            return [Tone(frequency: 784, start: 0, duration: 0.12, volume: 0.45)]
        case .note:
            return [Tone(frequency: 1175, start: 0, duration: 0.07, volume: 0.22, harmonics: [1, 0.2])]
        case .erase, .undo:
            return [Tone(frequency: 523, start: 0, duration: 0.09, volume: 0.3, harmonics: [1, 0.2])]
        case .mistake:
            return [
                Tone(frequency: 233, start: 0, duration: 0.16, volume: 0.5, harmonics: [1, 0.5, 0.3, 0.2]),
                Tone(frequency: 196, start: 0.09, duration: 0.2, volume: 0.45, harmonics: [1, 0.5, 0.3, 0.2]),
            ]
        case .houseCompleted:
            return [
                Tone(frequency: 784, start: 0, duration: 0.18, volume: 0.35),
                Tone(frequency: 988, start: 0.06, duration: 0.18, volume: 0.35),
                Tone(frequency: 1175, start: 0.12, duration: 0.3, volume: 0.35),
            ]
        case .hint:
            return [
                Tone(frequency: 1319, start: 0, duration: 0.25, volume: 0.25, harmonics: [1, 0.3]),
                Tone(frequency: 1760, start: 0.07, duration: 0.3, volume: 0.18, harmonics: [1, 0.3]),
            ]
        case .win:
            return [
                Tone(frequency: 523, start: 0, duration: 0.25, volume: 0.35),
                Tone(frequency: 659, start: 0.1, duration: 0.25, volume: 0.35),
                Tone(frequency: 784, start: 0.2, duration: 0.25, volume: 0.35),
                Tone(frequency: 1047, start: 0.3, duration: 0.7, volume: 0.4),
                Tone(frequency: 1319, start: 0.3, duration: 0.7, volume: 0.22),
            ]
        case .gameOver:
            return [
                Tone(frequency: 392, start: 0, duration: 0.3, volume: 0.35),
                Tone(frequency: 330, start: 0.18, duration: 0.3, volume: 0.35),
                Tone(frequency: 262, start: 0.36, duration: 0.6, volume: 0.35),
            ]
        }
    }

    private func buffer(for event: FeedbackEvent) -> AVAudioPCMBuffer? {
        if let cached = buffers[event] { return cached }
        guard let tones = Self.tones(for: event),
              let buffer = makeBuffer(Self.synthesize(tones, sampleRate: format.sampleRate))
        else { return nil }
        buffers[event] = buffer
        return buffer
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }

    /// Additive synthesis: a few harmonics with a fast attack and exponential decay.
    private nonisolated static func synthesize(_ tones: [Tone], sampleRate: Double) -> [Float] {
        let length = (tones.map { $0.start + $0.duration }.max() ?? 0) + 0.02
        var samples = [Float](repeating: 0, count: Int(length * sampleRate))
        for tone in tones {
            let startFrame = Int(tone.start * sampleRate)
            let toneFrames = Int(tone.duration * sampleRate)
            let attack = 0.004 * sampleRate
            let norm = tone.harmonics.reduce(0, +)
            for n in 0..<toneFrames where startFrame + n < samples.count {
                let t = Double(n) / sampleRate
                let envelope = min(1, Double(n) / attack) * exp(-t * 5.5 / tone.duration)
                var value = 0.0
                for (index, amplitude) in tone.harmonics.enumerated() {
                    value += amplitude * sin(2 * .pi * tone.frequency * Double(index + 1) * t)
                }
                samples[startFrame + n] += Float(value / norm * envelope * tone.volume)
            }
        }
        return samples
    }
}
