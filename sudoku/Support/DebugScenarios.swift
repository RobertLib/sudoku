//
//  DebugScenarios.swift
//  sudoku
//
//  Debug-only launch arguments that jump straight to a screen, e.g.
//  `-debugScenario hint -debugDifficulty expert`. Used for screenshots and
//  manual testing; compiled out of release builds.
//

#if DEBUG
import UIKit

enum DebugScenarios {
    /// Runs before the app model exists, so the stores load what is written here.
    /// `-debugHistory 1` replaces the player's data with six weeks of plausible play (see `seedHistory`).
    static func prepareData() {
        guard UserDefaults.standard.bool(forKey: "debugHistory") else { return }
        let fileManager = FileManager.default
        let directory = Persistence.directory
        for url in (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            try? fileManager.removeItem(at: url)
        }
        seedHistory(in: directory)
    }

    static func run(model: AppModel) async {
        let defaults = UserDefaults.standard
        guard let scenario = defaults.string(forKey: "debugScenario") else { return }
        let difficulty = defaults.string(forKey: "debugDifficulty").flatMap(Difficulty.init(rawValue:)) ?? .medium
        model.showWelcome = false
        if defaults.object(forKey: "debugSeed") != nil {
            model.puzzles.debugSeed = UInt64(max(0, defaults.integer(forKey: "debugSeed")))
        }
        if defaults.bool(forKey: "debugLandscape"),
           let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }

        switch scenario {
        case "game", "notes", "progress", "hint", "hintDetail", "win", "lost", "paused", "demo":
            model.request(.new(difficulty))
            if model.pendingRequest != nil { model.confirmPendingRequest() }
            while model.session == nil || model.isPreparingGame {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard let session = model.session else { return }
            session.debugAddElapsed(defaults.double(forKey: "debugElapsed"))
            try? await Task.sleep(for: .milliseconds(600))
            if scenario == "demo" {
                await playDemo(session)
            } else {
                await prepare(session, scenario: scenario)
            }
        case "advancedHint":
            await showAdvancedHint(model: model, difficulty: difficulty, minimumLevel: 4)
        case "dailyPrint":
            for offset in [0, -1, -2] {
                let challenge = DailyChallenge.today.adding(days: offset)
                let start = Date()
                let puzzle = await model.puzzles.puzzle(for: challenge)
                let seconds = String(format: "%.2f", Date().timeIntervalSince(start))
                print("DAILY \(challenge.key) \(challenge.difficulty.rawValue) \(PuzzleParser.string(from: puzzle.puzzle)) \(seconds)s")
            }
            print("DAILY DONE")
        case "autoplay":
            await autoplay(model: model, difficulties: difficultiesToAutoplay(default: difficulty))
        case "daily": model.path = [.daily]
        case "stats": model.path = [.statistics]
        case "achievements": model.path = [.achievements]
        case "help": model.path = [.help]
        case "custom": model.path = [.customPuzzle]
        case "settings": model.showSettings = true
        // `home` only skips the welcome sheet; HomeView opens the picker for `difficulty`.
        default: break
        }
        markReady()
    }

    /// The App Preview's game. Half of the puzzle is filled in at once, then the rest is played
    /// the way a person plays: the last cell of a row, column or box first, otherwise the single
    /// nearest the last move, one every `-debugDemoPace` seconds. Once a few moves are in and no
    /// house is down to its last cell (a Full House hint teaches nothing), it takes a hint through
    /// both stages, applies it and plays on to the win.
    /// The ready marker drops before the first move and play starts `-debugDemoLead` seconds
    /// later, which is the time Tools/appstore_media.sh has to start recording.
    private static func playDemo(_ session: GameSession) async {
        let defaults = UserDefaults.standard
        let pace = defaults.object(forKey: "debugDemoPace") == nil ? 0.4 : defaults.double(forKey: "debugDemoPace")
        let lead = defaults.object(forKey: "debugDemoLead") == nil ? 1.5 : defaults.double(forKey: "debugDemoLead")
        let solution = session.state.solution
        let empty = (0..<81).filter { session.state.values[$0] == 0 }
        for cell in empty.enumerated().filter({ $0.offset % 2 == 0 }).map(\.element) {
            session.select(cell)
            session.enter(Int(solution[cell]))
        }
        session.selection = nil
        markReady()
        try? await Task.sleep(for: .seconds(lead))

        var last = 40
        var moves = 0
        var tookHint = false
        while session.status == .inProgress {
            let values = session.state.values
            if !tookHint, moves >= 4, fullHouses(in: values).isEmpty || moves >= 10 {
                tookHint = true
                session.requestHint()
                while session.hint == nil { try? await Task.sleep(for: .milliseconds(20)) }
                try? await Task.sleep(for: .seconds(1.8))
                while session.hint.map({ $0.isNudge || !$0.isLastStage }) == true { session.showNextHintStage() }
                try? await Task.sleep(for: .seconds(2.8))
                session.applyHint()
                try? await Task.sleep(for: .seconds(pace * 2))
                continue
            }
            let open = (0..<81).filter { values[$0] == 0 }
            let houses = fullHouses(in: values)
            let candidates = houses.isEmpty ? singles(in: values) : houses
            let distance = { (cell: Int) in abs(cell / 9 - last / 9) + abs(cell % 9 - last % 9) }
            guard let cell = (candidates.isEmpty ? open : candidates).min(by: { distance($0) < distance($1) }) else { break }
            session.select(cell)
            try? await Task.sleep(for: .seconds(pace * 0.35))
            session.enter(Int(solution[cell]))
            last = cell
            moves += 1
            try? await Task.sleep(for: .seconds(pace * 0.65))
        }
    }

    /// Empty cells that are a naked or a hidden single on the given board.
    private static func singles(in values: [UInt8]) -> [Int] {
        var result = Set<Int>()
        for cell in 0..<81 where values[cell] == 0 {
            let seen = Set(Grid.peers[cell].map { values[$0] })
            if (1...9).count(where: { !seen.contains(UInt8($0)) }) == 1 { result.insert(cell) }
        }
        for house in Grid.houseCells {
            for digit in UInt8(1)...9 where !house.contains(where: { values[$0] == digit }) {
                let spots = house.filter { values[$0] == 0 && !Grid.peers[$0].contains { values[$0] == digit } }
                if spots.count == 1 { result.insert(spots[0]) }
            }
        }
        return Array(result)
    }

    /// Empty cells that are the last one left in their row, column or box.
    private static func fullHouses(in values: [UInt8]) -> [Int] {
        Grid.houseCells.compactMap { house in
            let open = house.filter { values[$0] == 0 }
            return open.count == 1 ? open[0] : nil
        }
    }

    /// Drops `Documents/shot-ready` once a scenario is set up, so Tools/appstore_media.sh
    /// photographs it then rather than after a guessed number of seconds.
    private static func markReady() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "shot-ready")
        try? Data().write(to: url)
    }

    /// Six weeks of play ending today: regular games on every difficulty, daily challenges
    /// with a 12-day streak ending yesterday (today's is still to play), and the achievements
    /// they earned, each unlocked on the day it was earned. Seeded, so every run is the same.
    private static func seedHistory(in directory: URL) {
        var rng = SeededGenerator(seed: 2026)
        let calendar = DailyChallenge.calendar
        let startOfToday = calendar.startOfDay(for: .now)
        let typicalTime: [Difficulty: TimeInterval] = [.easy: 250, .medium: 430, .hard: 800, .expert: 1280, .master: 1850]

        func date(daysAgo: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday)!
            return calendar.date(bySettingHour: hour, minute: Int.random(in: 0..<60, using: &rng), second: 0, of: day)!
        }

        func record(daysAgo: Int, hour: Int, kind: GameKind, difficulty: Difficulty, outcome: Outcome = .won) -> GameRecord {
            let mistakes = outcome == .lost ? 3 : [0, 0, 0, 0, 0, 1, 1, 2].randomElement(using: &rng)!
            let hints = outcome == .won && Int.random(in: 0..<7, using: &rng) == 0 ? Int.random(in: 1...3, using: &rng) : 0
            let share = outcome == .won ? Double.random(in: 0.8...1.3, using: &rng) : Double.random(in: 0.3...0.7, using: &rng)
            return GameRecord(
                date: date(daysAgo: daysAgo, hour: hour),
                kind: kind,
                difficulty: difficulty,
                outcome: outcome,
                duration: (typicalTime[difficulty]! * share).rounded(),
                mistakes: mistakes,
                hints: hints,
                usedAutoNotes: Bool.random(using: &rng),
                gameID: UUID()
            )
        }

        var records: [GameRecord] = []
        var dailyResults: [String: DailyResult] = [:]
        for daysAgo in Array(1...12) + [14, 15, 16, 18, 21, 22, 25, 29] {
            let challenge = DailyChallenge(date: startOfToday).adding(days: -daysAgo)
            let game = record(daysAgo: daysAgo, hour: [8, 19, 20, 21].randomElement(using: &rng)!,
                              kind: .daily(challenge.key), difficulty: challenge.difficulty)
            records.append(game)
            dailyResults[challenge.key] = DailyResult(
                duration: game.duration, mistakes: game.mistakes, hints: game.hints,
                completedAt: game.date, startedAt: game.date.addingTimeInterval(-game.duration)
            )
        }
        let games: [(daysAgo: Int, difficulty: Difficulty, outcome: Outcome)] = [
            (40, .easy, .won), (39, .easy, .won), (38, .medium, .won), (37, .medium, .lost),
            (36, .medium, .won), (35, .hard, .won), (34, .easy, .won), (33, .medium, .won),
            (32, .hard, .abandoned), (31, .hard, .won), (30, .medium, .won), (28, .hard, .won),
            (27, .expert, .won), (26, .hard, .won), (24, .expert, .lost), (23, .hard, .won),
            (20, .medium, .won), (19, .expert, .won), (17, .hard, .won), (13, .hard, .won),
            (11, .expert, .won), (10, .master, .won), (9, .hard, .won), (7, .medium, .won),
            (6, .expert, .won), (4, .hard, .won), (3, .hard, .won), (2, .expert, .won), (1, .medium, .won),
        ]
        for game in games {
            records.append(record(daysAgo: game.daysAgo, hour: [9, 12, 18, 20, 21, 22].randomElement(using: &rng)!,
                                  kind: .standard, difficulty: game.difficulty, outcome: game.outcome))
        }
        // The speed achievements and Pen and Paper need a game that is a little better than typical.
        records.append(GameRecord(date: date(daysAgo: 34, hour: 13), kind: .standard, difficulty: .easy, outcome: .won,
                                  duration: 172, mistakes: 0, hints: 0, usedAutoNotes: true, gameID: UUID()))
        records.append(GameRecord(date: date(daysAgo: 30, hour: 21), kind: .standard, difficulty: .medium, outcome: .won,
                                  duration: 341, mistakes: 1, hints: 0, usedAutoNotes: false, gameID: UUID()))
        records.append(GameRecord(date: date(daysAgo: 23, hour: 20), kind: .standard, difficulty: .hard, outcome: .won,
                                  duration: 905, mistakes: 1, hints: 0, usedAutoNotes: false, gameID: UUID()))
        records.sort { $0.date < $1.date }

        var unlocked: [String: Date] = [:]
        for index in records.indices {
            let now = records[index].date
            let results = dailyResults.filter { $0.value.completedAt <= now }
            let context = AchievementContext(records: Array(records[...index]), dailyCompleted: results.count,
                                             dailyBestStreak: DailyStore.bestStreak(in: results))
            for achievement in Achievement.allCases where unlocked[achievement.rawValue] == nil && achievement.isEarned(in: context) {
                unlocked[achievement.rawValue] = now
            }
        }

        Persistence.save(records, at: Persistence.url(for: .records, in: directory))
        Persistence.save(dailyResults, at: Persistence.url(for: .daily, in: directory))
        Persistence.save(unlocked, at: Persistence.url(for: .achievements, in: directory))
    }

    private static func difficultiesToAutoplay(default difficulty: Difficulty) -> [Difficulty] {
        UserDefaults.standard.bool(forKey: "debugAllDifficulties") ? Difficulty.allCases : [difficulty]
    }

    /// Solves whole puzzles using nothing but Hint → Apply, checking that the
    /// board never gets a wrong digit. Prints a summary line per puzzle.
    private static func autoplay(model: AppModel, difficulties: [Difficulty]) async {
        for difficulty in difficulties {
            let previous = model.session?.state.id
            model.request(.new(difficulty))
            if model.pendingRequest != nil { model.confirmPendingRequest() }
            while model.session == nil || model.session?.state.id == previous || model.isPreparingGame {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard let session = model.session else { return }
            try? await Task.sleep(for: .milliseconds(300))
            session.fillAllNotes()
            var applied = 0
            var techniques: [String: Int] = [:]
            var failure: String?
            while session.status == .inProgress, applied < 200 {
                session.requestHint()
                var waited = 0
                while session.hint == nil, waited < 400 {
                    try? await Task.sleep(for: .milliseconds(10))
                    waited += 1
                }
                guard let hint = session.hint else { failure = "no hint"; break }
                switch hint.content {
                case .logic(let entries):
                    for entry in entries { techniques[entry.step.technique.rawValue, default: 0] += 1 }
                    while session.hint.map({ $0.isNudge || !$0.isLastStage }) == true { session.showNextHintStage() }
                case .noStep:
                    failure = "no logical step"
                case .mistakes, .badNotes:
                    failure = "unexpected \(hint.content)"
                }
                if failure != nil { break }
                session.applyHint()
                applied += 1
                if (0..<81).contains(where: session.isWrong) { failure = "wrong digit placed"; break }
                try? await Task.sleep(for: .milliseconds(5))
            }
            let verdict = failure.map { "FAILED (\($0))" } ?? (session.status == .won ? "OK" : "NOT SOLVED")
            let summary = techniques.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value)" }.joined(separator: " ")
            print("AUTOPLAY \(difficulty.rawValue): \(verdict) after \(applied) hints – \(summary)")
            try? await Task.sleep(for: .milliseconds(1500))
        }
        print("AUTOPLAY DONE")
    }

    /// Plays by hints until one needs a technique of at least `minimumLevel`, then shows its details.
    private static func showAdvancedHint(model: AppModel, difficulty: Difficulty, minimumLevel: Int) async {
        for _ in 0..<15 {
            let previous = model.session?.state.id
            model.request(.new(difficulty))
            if model.pendingRequest != nil { model.confirmPendingRequest() }
            while model.session == nil || model.session?.state.id == previous || model.isPreparingGame {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard let session = model.session else { return }
            session.debugAddElapsed(UserDefaults.standard.double(forKey: "debugElapsed"))
            try? await Task.sleep(for: .milliseconds(300))
            session.fillAllNotes()
            while session.status == .inProgress {
                session.requestHint()
                while session.hint == nil { try? await Task.sleep(for: .milliseconds(10)) }
                guard let hint = session.hint else { break }
                if let index = hint.entries.firstIndex(where: { $0.step.technique.level >= minimumLevel }) {
                    for _ in 0...index { session.showNextHintStage() }
                    return
                }
                while session.hint.map({ $0.isNudge || !$0.isLastStage }) == true { session.showNextHintStage() }
                session.applyHint()
            }
        }
    }

    private static func prepare(_ session: GameSession, scenario: String) async {
        let solution = session.state.solution
        let empty = (0..<81).filter { session.state.values[$0] == 0 }
        switch scenario {
        case "notes":
            for cell in empty.prefix(empty.count / 3) {
                session.select(cell)
                session.enter(Int(solution[cell]))
            }
            session.fillAllNotes()
            session.select(empty[empty.count / 2])
        case "progress":
            // A game well under way: two in five empty cells solved all over the board, pencil
            // marks in every third cell left, and an empty cell selected near the middle.
            let placed = empty.enumerated().filter { $0.offset % 5 < 2 }.map(\.element)
            for cell in placed {
                session.select(cell)
                session.enter(Int(solution[cell]))
            }
            let open = empty.filter { !placed.contains($0) }
            session.isNotesMode = true
            for cell in open.enumerated().filter({ $0.offset % 3 == 0 }).map(\.element) {
                session.select(cell)
                let seen = Set(Grid.peers[cell].map { session.state.values[$0] })
                for digit in 1...9 where !seen.contains(UInt8(digit)) {
                    session.enter(digit)
                }
            }
            session.isNotesMode = false
            let unmarked = open.enumerated().filter { $0.offset % 3 != 0 }.map(\.element)
            session.select(unmarked.min { abs($0 - 40) < abs($1 - 40) } ?? empty[0])
        case "hint", "hintDetail":
            session.fillAllNotes()
            session.requestHint()
            try? await Task.sleep(for: .milliseconds(500))
            if scenario == "hintDetail" { session.showNextHintStage() }
        case "win":
            for cell in empty.dropLast() {
                session.select(cell)
                session.enter(Int(solution[cell]))
            }
            if let last = empty.last {
                session.select(last)
                session.enter(Int(solution[last]))
            }
        case "lost":
            for cell in empty.prefix(3) {
                session.select(cell)
                session.enter(Int(solution[cell]) % 9 + 1)
            }
        case "paused":
            session.pause()
        default:
            session.select(empty.first ?? 0)
        }
    }
}
#endif
