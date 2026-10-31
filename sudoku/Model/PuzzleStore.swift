//
//  PuzzleStore.swift
//  sudoku
//
//  Keeps a few pre-generated puzzles per difficulty so new games start instantly.
//  Generation runs in the background at low priority.
//

import Foundation

@Observable
final class PuzzleStore {
    private var cache: [String: [GeneratedPuzzle]]
    private var refillTask: Task<Void, Never>?
    private let cacheSize = 2
    private let url: URL
    /// Whether `refill` generates anything; tests turn it off.
    private let fillsCache: Bool
    #if DEBUG
    /// Set by `-debugSeed`: new games skip the cache and are generated from this seed (and the
    /// next one for each further game), so screenshot poses get the same puzzles on every run.
    var debugSeed: UInt64?
    #endif

    /// - Parameters:
    ///   - directory: Where the cache is kept, normally `Persistence.cacheDirectory`.
    ///   - fillsCache: Whether puzzles are generated ahead of time (see `refill`).
    init(directory: URL, fillsCache: Bool = true) {
        self.fillsCache = fillsCache
        url = Persistence.url(for: .puzzleCache, in: directory)
        cache = Persistence.load([String: [GeneratedPuzzle]].self, at: url, keepsUnreadable: false) ?? [:]
    }

    /// Returns a fresh puzzle, from the cache when possible.
    func puzzle(for difficulty: Difficulty) async -> GeneratedPuzzle {
        #if DEBUG
        if let seed = debugSeed {
            debugSeed = seed &+ 1
            return await Task.detached(priority: .userInitiated) {
                var rng = SeededGenerator(seed: seed)
                return Generator.generate(difficulty, using: &rng)
            }.value
        }
        #endif
        defer { refill() }
        if var queue = cache[difficulty.rawValue], !queue.isEmpty {
            let puzzle = queue.removeFirst()
            cache[difficulty.rawValue] = queue
            save()
            return puzzle
        }
        return await Self.generate(difficulty, priority: .userInitiated)
    }

    /// The deterministic puzzle of a given day.
    func puzzle(for challenge: DailyChallenge) async -> GeneratedPuzzle {
        await Task.detached(priority: .userInitiated) {
            challenge.generatePuzzle()
        }.value
    }

    /// Tops up the cache in the background.
    func refill() {
        guard fillsCache, refillTask == nil else { return }
        refillTask = Task(priority: .utility) {
            for difficulty in Difficulty.allCases {
                while (cache[difficulty.rawValue]?.count ?? 0) < cacheSize {
                    let puzzle = await Self.generate(difficulty, priority: .utility)
                    cache[difficulty.rawValue, default: []].append(puzzle)
                    save()
                }
            }
            refillTask = nil
        }
    }

    private func save() {
        Persistence.save(cache, at: url)
    }

    private nonisolated static func generate(_ difficulty: Difficulty, priority: TaskPriority) async -> GeneratedPuzzle {
        await Task.detached(priority: priority) {
            var rng = SeededGenerator.random()
            return Generator.generate(difficulty, using: &rng)
        }.value
    }
}
