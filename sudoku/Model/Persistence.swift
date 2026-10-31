//
//  Persistence.swift
//  sudoku
//
//  Small JSON files in Application Support. Everything stays on the device.
//
//  New properties of persisted types must be optional: synthesized Codable
//  ignores default values, so files written by an older version would no
//  longer decode. Such a file is kept aside (see `load`) instead of being lost.
//

import Foundation
import OSLog

nonisolated enum Persistence {
    enum File: String {
        case records = "records.json"
        case daily = "daily.json"
        case dailyHints = "daily-hints.json"
        case achievements = "achievements.json"
        /// Kept in `cacheDirectory`, as it can always be made again.
        case puzzleCache = "puzzle-cache.json"
    }

    private static let logger = Logger(subsystem: "cz.rob.sudoku", category: "Persistence")

    /// Where the app keeps its data. Tests pass a temporary directory to the stores instead.
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "Sudoku", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Where data that can be made again is kept: not backed up, and the system may clear it.
    static let cacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "Sudoku", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func url(for file: File, in directory: URL) -> URL {
        directory.appending(path: file.rawValue)
    }

    /// Reads a JSON file. A file that exists but can't be read (corrupted, or written with an
    /// incompatible format) is renamed first, so the next save can't overwrite the player's data.
    /// Data that can be made again (`keepsUnreadable: false`) is simply deleted instead.
    static func load<T: Decodable>(_ type: T.Type, at url: URL, keepsUnreadable: Bool = true) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Failed to load \(url.lastPathComponent): \(error.localizedDescription)")
            if keepsUnreadable {
                keepUnreadableFile(at: url)
            } else {
                delete(at: url)
            }
            return nil
        }
    }

    /// Writes a JSON file atomically. Returns whether it worked.
    @discardableResult
    static func save<T: Encodable>(_ value: T, at url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            logger.error("Failed to save \(url.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }

    /// Deletes a file. Returns whether it is gone (also when there was nothing to delete).
    @discardableResult
    static func delete(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch CocoaError.fileNoSuchFile {
            return true
        } catch {
            logger.error("Failed to delete \(url.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }

    /// The name an unreadable file is moved to, e.g. `records.unreadable-1793452800.json`.
    static func unreadableCopyURL(for url: URL, date: Date = .now) -> URL {
        url.deletingPathExtension().appendingPathExtension("unreadable-\(Int(date.timeIntervalSince1970)).json")
    }

    private static func keepUnreadableFile(at url: URL) {
        let copy = unreadableCopyURL(for: url)
        do {
            try FileManager.default.moveItem(at: url, to: copy)
            logger.notice("Kept unreadable data as \(copy.lastPathComponent)")
        } catch {
            logger.error("Failed to keep unreadable \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
