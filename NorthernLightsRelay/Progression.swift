import Foundation

/// Everything a single run produced, handed from the scene to the progress store.
struct RunResult {
    var arches = 0
    var perfects = 0
    var bestPerfectStreak = 0
    var motes = 0              // stars actually caught
    var auroraBands = 0
    var reachedDawn = false
    var isZen = false
}

/// What recording a run changed, for the end screen.
struct RunOutcome {
    var unlockedStyles: [PuckStyle] = []
    var completedGoals: [Goal] = []
    var leveledUpTo: Int?
    var motesEarned = 0
    var levelReward = 0
}

/// One of the three active goals. Alto's-style: finish all three to level up.
struct Goal: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case archesInRun, perfectStreak, perfectsInRun, motesInRun
        case totalArches, auroraBands, zenArches, runs, reachDawn
    }

    var id = UUID()
    let kind: Kind
    let target: Int
    var progress = 0           // only used by goals that add up across runs
    var done = false

    var title: String {
        switch kind {
        case .archesInRun:   return "Part \(target) clouds in one run"
        case .perfectStreak: return "Make \(target) perfect passes in a row"
        case .perfectsInRun: return "Make \(target) perfect passes in one run"
        case .motesInRun:    return "Gather \(target) fallen stars in one run"
        case .totalArches:   return "Part \(target) clouds in total"
        case .auroraBands:   return target == 1 ? "Wake an aurora band" : "Wake \(target) aurora bands in one run"
        case .zenArches:     return "Part \(target) clouds in Zen"
        case .runs:          return "Carry the fire \(target) times"
        case .reachDawn:     return "Carry the fire until dawn"
        }
    }

    /// Shown under cumulative goals, e.g. "42 / 90".
    var progressText: String? {
        guard !done, [.totalArches, .zenArches, .runs].contains(kind) else { return nil }
        return "\(progress) / \(target)"
    }

    /// Applies a run. Returns true if this run completed the goal.
    mutating func apply(_ run: RunResult) -> Bool {
        guard !done else { return false }
        switch kind {
        case .archesInRun:   done = !run.isZen && run.arches >= target
        case .perfectStreak: done = !run.isZen && run.bestPerfectStreak >= target
        case .perfectsInRun: done = !run.isZen && run.perfects >= target
        case .motesInRun:    done = run.motes >= target
        case .auroraBands:   done = !run.isZen && run.auroraBands >= target
        case .reachDawn:     done = !run.isZen && run.reachedDawn
        case .totalArches:
            if !run.isZen { progress += run.arches }
            done = progress >= target
        case .zenArches:
            if run.isZen { progress += run.arches }
            done = progress >= target
        case .runs:
            if !run.isZen { progress += 1 }
            done = progress >= target
        }
        return done
    }

    /// Three different goals for a level, scaled gently with the level and the
    /// same every time for that level (seeded, not random per launch).
    static func goals(forLevel level: Int) -> [Goal] {
        var rng = SeededGenerator(seed: UInt64(level) &* 2_654_435_761 &+ 17)
        var kinds: [Kind] = [.archesInRun, .perfectStreak, .perfectsInRun, .motesInRun,
                             .totalArches, .auroraBands, .zenArches, .runs]
        if level >= 5 { kinds.append(.reachDawn) }
        // Level 1 is a gentle introduction to the three core ideas.
        let picked: [Kind] = level == 1
            ? [.archesInRun, .perfectsInRun, .motesInRun]
            : Array(kinds.shuffled(using: &rng).prefix(3))
        return picked.map { Goal(kind: $0, target: target(for: $0, level: level)) }
    }

    private static func target(for kind: Kind, level l: Int) -> Int {
        switch kind {
        case .archesInRun:   return min(55, 6 + 3 * l)
        case .perfectStreak: return min(10, 1 + (l + 1) / 2)
        case .perfectsInRun: return min(25, 2 + l)
        case .motesInRun:    return min(15, 2 + l)
        case .totalArches:   return 30 + 20 * l
        case .auroraBands:   return min(4, 1 + l / 3)
        case .zenArches:     return 15 + 5 * l
        case .runs:          return 3 + l / 2
        case .reachDawn:     return 1
        }
    }
}

/// Small deterministic RNG so each level's goals are stable.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
