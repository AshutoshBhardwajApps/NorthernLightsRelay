import Foundation
import SwiftUI

/// The template's small, UserDefaults-backed app store, adapted for this game.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let prefix = "northernlights."

    @Published var musicEnabled: Bool { didSet { save() } }
    @Published var effectsEnabled: Bool { didSet { save() } }
    @Published private(set) var bestScore: Int
    @Published private(set) var runsCompleted: Int

    private init() {
        let defaults = UserDefaults.standard
        musicEnabled = defaults.object(forKey: prefix + "music") as? Bool ?? true
        effectsEnabled = defaults.object(forKey: prefix + "effects") as? Bool ?? true
        bestScore = defaults.integer(forKey: prefix + "bestScore")
        runsCompleted = defaults.integer(forKey: prefix + "runs")
    }

    func recordRun(score: Int) {
        bestScore = max(bestScore, score)
        runsCompleted += 1
        save()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(musicEnabled, forKey: prefix + "music")
        defaults.set(effectsEnabled, forKey: prefix + "effects")
        defaults.set(bestScore, forKey: prefix + "bestScore")
        defaults.set(runsCompleted, forKey: prefix + "runs")
    }
}
