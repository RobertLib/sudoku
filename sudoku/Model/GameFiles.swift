//
//  GameFiles.swift
//  sudoku
//
//  Unfinished games, one JSON file per game, so saving a move rewrites only
//  the game being played – not every started daily challenge with its history.
//

import Foundation

nonisolated struct GameFiles {
    /// The `Games` folder holding one `<id>.json` per game.
    let directory: URL
    /// What each file holds right now, so unchanged games are skipped when saving.
    private var written: [UUID: GameState] = [:]

    /// - Parameter root: The app's data directory.
    init(root: URL) {
        directory = root.appending(path: "Games", directoryHint: .isDirectory)
    }

    /// Reads all saved games, oldest first.
    mutating func load() -> [GameState] {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let games = files
            // Skips files kept aside as unreadable, e.g. `<id>.unreadable-1793452800.json`.
            .filter { $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
            .compactMap { Persistence.load(GameState.self, at: $0) }
            .sorted { $0.createdAt < $1.createdAt }
        written = Dictionary(games.map { ($0.id, $0) }) { first, _ in first }
        return games
    }

    /// Writes the games that changed since the last save and deletes the files of games that are gone.
    /// A file that couldn't be deleted is tried again on the next save.
    mutating func save(_ games: [GameState]) {
        for id in Set(written.keys).subtracting(games.map(\.id)) where Persistence.delete(at: url(for: id)) {
            written[id] = nil
        }
        for game in games where written[game.id] != game {
            if Persistence.save(game, at: url(for: game.id)) {
                written[game.id] = game
            }
        }
    }

    private func url(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }
}
