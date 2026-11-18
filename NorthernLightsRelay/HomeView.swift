import SwiftUI
import SpriteKit

struct HomeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var isPlaying = false
    @State private var isZenRun = false
    @State private var finalScore: Int?
    @State private var runID = UUID()
    @State private var runScene = RelayScene(size: CGSize(width: 390, height: 844))
    @State private var currentScore = 0
    @State private var isNewBest = false
    @State private var newlyUnlocked: [PuckStyle] = []
    @State private var canRestart = false

    private let ink = Color(red: 0.03, green: 0.10, blue: 0.17)

    var body: some View {
        ZStack {
            winterBackground

            if isPlaying {
                runView
                    .transition(.opacity)
            } else {
                homeScreen
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: isPlaying)
        .onAppear {
            AudioManager.shared.updateSettings(musicEnabled: settings.musicEnabled,
                                               effectsEnabled: settings.effectsEnabled)
        }
        .onChange(of: settings.musicEnabled) { _, enabled in
            AudioManager.shared.setMusicEnabled(enabled)
        }
        .onChange(of: settings.effectsEnabled) { _, enabled in
            AudioManager.shared.setEffectsEnabled(enabled)
        }
    }

    // MARK: - Home

    private var homeScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.cyan.opacity(0.9))
                .padding(.bottom, 18)
            Text("NORTHERN LIGHTS")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
            Text("RELAY")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .tracking(8)
                .foregroundStyle(Color.cyan.opacity(0.9))
                .padding(.top, 7)
            Text("A midnight run across the frozen canals.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 20)

            Spacer()

            HStack(alignment: .top, spacing: 0) {
                statColumn(title: "PERSONAL BEST", value: "\(settings.bestScore)")
                statColumn(title: "DAY STREAK", value: "\(settings.currentStreak)", symbol: settings.currentStreak > 0 ? "flame.fill" : nil)
            }
            .padding(.horizontal, 36)

            dailyGoalBar
                .padding(.horizontal, 36)
                .padding(.top, 22)

            audioControls
                .padding(.top, 18)

            puckPicker
                .padding(.top, 22)

            Button { startRun(zen: false) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right")
                    Text("START RUN").tracking(2)
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.cyan, in: Capsule())
            }
            .padding(.horizontal, 36)
            .padding(.top, 24)

            Button { startRun(zen: true) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "leaf")
                    Text("ZEN GLIDE").tracking(2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            }
            .padding(.horizontal, 36)
            .padding(.top, 12)

            Text("DRAG TO STEER · SLIP THROUGH THE GATES")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.48))
                .padding(.top, 14)
                .padding(.bottom, 44)
        }
        .padding(.top, 50)
    }

    private func statColumn(title: String, value: String, symbol: String? = nil) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.orange.opacity(0.85))
                }
                Text(value)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dailyGoalBar: some View {
        let today = settings.todayGates
        let goal = SettingsStore.dailyGoal
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(settings.dailyGoalMet ? "TODAY'S GOAL MET" : "TODAY'S GOAL")
                    .font(.caption2.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(settings.dailyGoalMet ? Color.green.opacity(0.85) : .white.opacity(0.55))
                Spacer()
                Text("\(min(today, goal)) / \(goal) GATES")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, Color(red: 0.45, green: 1, blue: 0.62)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * min(1, CGFloat(today) / CGFloat(goal)))
                }
            }
            .frame(height: 6)
        }
    }

    private var puckPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                ForEach(PuckStyle.all) { style in
                    let unlocked = settings.isUnlocked(style)
                    let selected = settings.selectedStyleID == style.id
                    Button {
                        if unlocked { settings.selectedStyleID = style.id }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                if !unlocked {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.5))
                                } else {
                                    Image("Puck")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                        .colorMultiply(style.color)
                                }
                            }
                            .overlay(Circle().stroke(.white.opacity(selected ? 0.9 : 0), lineWidth: 2).padding(-4))
                            Text(unlocked ? style.name.uppercased() : "\(style.unlockAt)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(.white.opacity(unlocked ? 0.7 : 0.4))
                        }
                    }
                    .disabled(!unlocked)
                }
            }
            if let next = settings.nextUnlock {
                Text("\(next.remaining) more gates to unlock \(next.style.name)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var audioControls: some View {
        HStack(spacing: 16) {
            audioButton(title: "MUSIC", symbol: settings.musicEnabled ? "music.note" : "music.note", isOn: settings.musicEnabled) {
                settings.musicEnabled.toggle()
            }
            audioButton(title: "SOUNDS", symbol: settings.effectsEnabled ? "bell" : "bell.slash", isOn: settings.effectsEnabled) {
                settings.effectsEnabled.toggle()
            }
        }
    }

    private func audioButton(title: String, symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(isOn ? 0.82 : 0.42))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(.white.opacity(isOn ? 0.10 : 0.045), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(isOn ? 0.22 : 0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title.capitalized) \(isOn ? "on" : "off")")
    }

    // MARK: - Run

    private var runView: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: runScene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .id(runID)

            HStack(alignment: .top) {
                Button(action: leaveRun) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.12), in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    if isZenRun {
                        Text("ZEN")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.55))
                    } else if finalScore == nil {
                        Text("GATES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(currentScore)")
                            .font(.system(size: 38, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 58)

            if let score = finalScore {
                endOfRun(score: score)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: finalScore)
    }

    /// A calm end screen: no big panel, just the result and "tap to go again".
    private func endOfRun(score: Int) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if canRestart { startRun(zen: false) } }

            VStack(spacing: 10) {
                Text("\(score)")
                    .font(.system(size: 76, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(isNewBest ? "NEW PERSONAL BEST" : "BEST \(settings.bestScore)")
                    .font(.footnote.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(isNewBest ? Color.cyan : .white.opacity(0.6))

                Group {
                    if settings.dailyGoalMet {
                        Label("Daily goal met · \(settings.currentStreak) day streak", systemImage: "flame.fill")
                    } else {
                        Text("Today \(settings.todayGates) / \(SettingsStore.dailyGoal) gates")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 14)

                ForEach(newlyUnlocked) { style in
                    HStack(spacing: 8) {
                        Circle().fill(style.color).frame(width: 12, height: 12)
                        Text("New puck unlocked: \(style.name)")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }

                Text("TAP ANYWHERE TO GLIDE AGAIN")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(canRestart ? 0.75 : 0))
                    .padding(.top, 40)
                    .allowsHitTesting(false)

                Button("Home") { goHome() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 8)
            }
            .allowsHitTesting(canRestart)
        }
    }

    // MARK: - Background

    private var winterBackground: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(red: 0.025, green: 0.06, blue: 0.16), Color(red: 0.03, green: 0.20, blue: 0.29), Color(red: 0.06, green: 0.10, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: proxy.size.width * 0.8)
                    .blur(radius: 70)
                    .offset(x: proxy.size.width * 0.3, y: -proxy.size.height * 0.2)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.48))
                    path.addCurve(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.55), control1: CGPoint(x: proxy.size.width * 0.3, y: proxy.size.height * 0.43), control2: CGPoint(x: proxy.size.width * 0.72, y: proxy.size.height * 0.60))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 0.60, green: 0.85, blue: 0.90).opacity(0.17), Color(red: 0.04, green: 0.22, blue: 0.32).opacity(0.02)], startPoint: .top, endPoint: .bottom))
                ForEach(0..<42, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(Double((i % 4) + 1) * 0.13))
                        .frame(width: i % 7 == 0 ? 3 : 1.5)
                        .position(x: CGFloat((i * 83 + 31) % 400) / 400 * proxy.size.width,
                                  y: CGFloat((i * 137 + 19) % 720) / 720 * proxy.size.height)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Actions

    private func startRun(zen: Bool) {
        finalScore = nil
        currentScore = 0
        isNewBest = false
        newlyUnlocked = []
        canRestart = false
        isZenRun = zen
        // Wire the callbacks onto each new scene here. Doing it in .onAppear only
        // worked for the first run: restarting keeps the play screen on screen,
        // so onAppear never fired again and the new scene had no hooks.
        let style = settings.selectedStyle
        let scene = RelayScene(size: CGSize(width: 390, height: 844), zen: zen,
                               puckColor: SKColor(red: style.red, green: style.green, blue: style.blue, alpha: 1))
        scene.onScoreChanged = { score in
            DispatchQueue.main.async { currentScore = score }
        }
        scene.onGameOver = { score in
            DispatchQueue.main.async {
                isNewBest = score > settings.bestScore
                newlyUnlocked = settings.recordRun(score: score)
                finalScore = score
                // Short pause so a finger still dragging when you crash
                // doesn't instantly start the next run.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeIn(duration: 0.6)) { canRestart = true }
                }
            }
        }
        runScene = scene
        runID = UUID()
        withAnimation { isPlaying = true }
    }

    /// Leaving mid-run still banks the gates you cleared (not in zen).
    private func leaveRun() {
        if finalScore == nil && !isZenRun && runScene.score > 0 {
            settings.recordRun(score: runScene.score)
        }
        goHome()
    }

    private func goHome() {
        runScene.isPaused = true
        withAnimation { isPlaying = false; finalScore = nil }
    }
}
