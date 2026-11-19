import Foundation
import SwiftUI

/// A lantern spirit (the light's colour, halo and trail) awakened by passing
/// arches over all runs. Called a "puck" in older code.
struct PuckStyle: Identifiable, Equatable {
    let id: String
    let name: String
    let unlockAt: Int          // total gates cleared needed
    let red: Double, green: Double, blue: Double

    var color: Color { Color(red: red, green: green, blue: blue) }

    static let all: [PuckStyle] = [
        PuckStyle(id: "frost", name: "Frost", unlockAt: 0, red: 0.42, green: 0.94, blue: 1.00),
        PuckStyle(id: "aurora", name: "Aurora", unlockAt: 100, red: 0.45, green: 1.00, blue: 0.62),
        PuckStyle(id: "twilight", name: "Twilight", unlockAt: 250, red: 0.74, green: 0.58, blue: 1.00),
        PuckStyle(id: "ember", name: "Ember", unlockAt: 500, red: 1.00, green: 0.72, blue: 0.42),
    ]

    static func style(id: String) -> PuckStyle { all.first { $0.id == id } ?? all[0] }
}

/// The template's small, UserDefaults-backed app store, adapted for this game.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    static let dailyGoal = 25
    private let prefix = "northernlights."

    @Published var musicEnabled: Bool { didSet { save() } }
    @Published var effectsEnabled: Bool { didSet { save() } }
    @Published var selectedStyleID: String { didSet { save() } }
    @Published var hasSeenIntro: Bool { didSet { save() } }
    @Published var hapticsEnabled: Bool { didSet { save() } }
    @Published private(set) var motes: Int
    @Published private(set) var level: Int
    @Published private(set) var goals: [Goal]
    @Published private(set) var bestScore: Int
    @Published private(set) var runsCompleted: Int
    @Published private(set) var totalGates: Int
    @Published private(set) var dailyGates: Int
    @Published private(set) var dailyDate: String
    @Published private(set) var streak: Int
    @Published private(set) var lastGoalDate: String

    private init() {
        let defaults = UserDefaults.standard
        musicEnabled = defaults.object(forKey: prefix + "music") as? Bool ?? true
        effectsEnabled = defaults.object(forKey: prefix + "effects") as? Bool ?? true
        selectedStyleID = defaults.string(forKey: prefix + "style") ?? "frost"
        hasSeenIntro = defaults.bool(forKey: prefix + "seenIntro")
        hapticsEnabled = defaults.object(forKey: prefix + "haptics") as? Bool ?? true
        motes = defaults.integer(forKey: prefix + "motes")
        let savedLevel = max(1, defaults.integer(forKey: prefix + "level"))
        level = savedLevel
        if let data = defaults.data(forKey: prefix + "goals"),
           let saved = try? JSONDecoder().decode([Goal].self, from: data), saved.count == 3 {
            goals = saved
        } else {
            goals = Goal.goals(forLevel: savedLevel)
        }
        bestScore = defaults.integer(forKey: prefix + "bestScore")
        runsCompleted = defaults.integer(forKey: prefix + "runs")
        totalGates = defaults.integer(forKey: prefix + "totalGates")
        dailyGates = defaults.integer(forKey: prefix + "dailyGates")
        dailyDate = defaults.string(forKey: prefix + "dailyDate") ?? ""
        streak = defaults.integer(forKey: prefix + "streak")
        lastGoalDate = defaults.string(forKey: prefix + "lastGoalDate") ?? ""
    }

    // MARK: - Derived values

    var selectedStyle: PuckStyle { PuckStyle.style(id: selectedStyleID) }

    func isUnlocked(_ style: PuckStyle) -> Bool { totalGates >= style.unlockAt }

    /// Gates cleared today (resets when the calendar day changes).
    var todayGates: Int { dailyDate == Self.dayKey(Date()) ? dailyGates : 0 }

    var dailyGoalMet: Bool { todayGates >= Self.dailyGoal }

    /// The streak only counts while it is alive: goal met today or yesterday.
    var currentStreak: Int {
        let today = Self.dayKey(Date())
        let yesterday = Self.dayKey(Date().addingTimeInterval(-86_400))
        return (lastGoalDate == today || lastGoalDate == yesterday) ? streak : 0
    }

    /// The next locked style and how many more gates it needs, if any.
    var nextUnlock: (style: PuckStyle, remaining: Int)? {
        guard let next = PuckStyle.all.first(where: { !isUnlocked($0) }) else { return nil }
        return (next, next.unlockAt - totalGates)
    }

    // MARK: - Recording

    /// Records a run (normal or zen): motes, goals and levels for both; best,
    /// totals, tonight's relay and spirit unlocks for normal runs only.
    @discardableResult
    func record(_ run: RunResult) -> RunOutcome {
        var outcome = RunOutcome()
        motes += run.motes
        outcome.motesEarned = run.motes
        for i in goals.indices where goals[i].apply(run) {
            outcome.completedGoals.append(goals[i])
        }
        if goals.allSatisfy(\.done) {
            outcome.levelReward = 20 * level
            motes += outcome.levelReward
            level += 1
            goals = Goal.goals(forLevel: level)
            outcome.leveledUpTo = level
        }
        if !run.isZen {
            outcome.unlockedStyles = recordRun(score: run.arches)
        } else {
            save()
        }
        return outcome
    }

    /// Records a scored run. Returns styles unlocked by this run.
    @discardableResult
    private func recordRun(score: Int) -> [PuckStyle] {
        let lockedBefore = PuckStyle.all.filter { !isUnlocked($0) }
        bestScore = max(bestScore, score)
        runsCompleted += 1
        totalGates += score

        let today = Self.dayKey(Date())
        if dailyDate != today {
            dailyDate = today
            dailyGates = 0
        }
        let wasMet = dailyGates >= Self.dailyGoal
        dailyGates += score
        if !wasMet && dailyGates >= Self.dailyGoal {
            let yesterday = Self.dayKey(Date().addingTimeInterval(-86_400))
            streak = (lastGoalDate == yesterday) ? streak + 1 : 1
            lastGoalDate = today
        }
        save()
        return lockedBefore.filter { isUnlocked($0) }
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(musicEnabled, forKey: prefix + "music")
        defaults.set(effectsEnabled, forKey: prefix + "effects")
        defaults.set(selectedStyleID, forKey: prefix + "style")
        defaults.set(hasSeenIntro, forKey: prefix + "seenIntro")
        defaults.set(hapticsEnabled, forKey: prefix + "haptics")
        defaults.set(motes, forKey: prefix + "motes")
        defaults.set(level, forKey: prefix + "level")
        defaults.set(try? JSONEncoder().encode(goals), forKey: prefix + "goals")
        defaults.set(bestScore, forKey: prefix + "bestScore")
        defaults.set(runsCompleted, forKey: prefix + "runs")
        defaults.set(totalGates, forKey: prefix + "totalGates")
        defaults.set(dailyGates, forKey: prefix + "dailyGates")
        defaults.set(dailyDate, forKey: prefix + "dailyDate")
        defaults.set(streak, forKey: prefix + "streak")
        defaults.set(lastGoalDate, forKey: prefix + "lastGoalDate")
    }
}
