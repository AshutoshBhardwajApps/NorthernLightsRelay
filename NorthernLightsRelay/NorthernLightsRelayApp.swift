import SwiftUI

@main
struct NorthernLightsRelayApp: App {
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
