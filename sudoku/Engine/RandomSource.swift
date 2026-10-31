//
//  RandomSource.swift
//  sudoku
//
//  Deterministic random numbers so a seed (e.g. a daily challenge date)
//  always produces the same puzzle on every device and OS version.
//

import Foundation

/// xoshiro256** seeded through SplitMix64.
nonisolated struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var s0: UInt64
    private var s1: UInt64
    private var s2: UInt64
    private var s3: UInt64

    init(seed: UInt64) {
        var x = seed
        func splitMix() -> UInt64 {
            x &+= 0x9E37_79B9_7F4A_7C15
            var z = x
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        s0 = splitMix()
        s1 = splitMix()
        s2 = splitMix()
        s3 = splitMix()
    }

    /// A generator seeded from the system's secure random source.
    static func random() -> SeededGenerator {
        var system = SystemRandomNumberGenerator()
        return SeededGenerator(seed: system.next())
    }

    mutating func next() -> UInt64 {
        let result = ((s1 &* 5) << 7 | (s1 &* 5) >> 57) &* 9
        let t = s1 << 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = s3 << 45 | s3 >> 19
        return result
    }
}

nonisolated extension RandomNumberGenerator {
    /// A value in `0..<bound`. Implemented here (instead of `Int.random(in:using:)`)
    /// so the sequence never changes with the standard library.
    mutating func nextInt(below bound: Int) -> Int {
        precondition(bound > 0)
        return Int(next() % UInt64(bound))
    }
}

nonisolated extension Array {
    /// Fisher–Yates shuffle with a stable algorithm for reproducible results.
    mutating func stableShuffle<R: RandomNumberGenerator>(using rng: inout R) {
        guard count > 1 else { return }
        for i in stride(from: count - 1, to: 0, by: -1) {
            swapAt(i, rng.nextInt(below: i + 1))
        }
    }

    func stableShuffled<R: RandomNumberGenerator>(using rng: inout R) -> [Element] {
        var copy = self
        copy.stableShuffle(using: &rng)
        return copy
    }
}
