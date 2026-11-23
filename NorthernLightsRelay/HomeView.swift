import SwiftUI
import SpriteKit

struct HomeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var isPlaying = false
    @State private var isZenRun = false
    @State private var finalScore: Int?
    @State private var runID = UUID()
    @State private var runScene = RelayScene(size: CGSize(width: 390, height: 844))
    @State private var isNewBest = false
    @State private var outcome = RunOutcome()
    @State private var lastRun = RunResult()
    @State private var canRestart = false
    @State private var isPaused = false
    @State private var showIntro = false
    @Environment(\.scenePhase) private var scenePhase

    private let ink = Color(red: 0.03, green: 0.10, blue: 0.17)

    var body: some View {
        GeometryReader { screen in
        ZStack {
            winterBackground

            if isPlaying {
                runView
                    .transition(.opacity)
            } else {
                // Scrolls only when the phone is too short to show it all.
                ScrollView(.vertical, showsIndicators: false) {
                    homeScreen.frame(minHeight: screen.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .transition(.opacity)
            }

            if !isPlaying && (showIntro || !settings.hasSeenIntro) {
                StoryIntroView {
                    settings.hasSeenIntro = true
                    showIntro = false
                }
                .transition(.opacity)
            }
        }
        .frame(width: screen.size.width, height: screen.size.height)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: isPlaying)
        .animation(.easeInOut(duration: 0.6), value: showIntro)
        .animation(.easeInOut(duration: 0.6), value: settings.hasSeenIntro)
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
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app mid-run pauses it, so you never return to a crash.
            if phase != .active && isPlaying && finalScore == nil { setPaused(true) }
        }
    }

    // MARK: - Home

    private var homeScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(settings.motes)", systemImage: "star.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 1, green: 0.93, blue: 0.72))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(.white.opacity(0.08), in: Capsule())
                    .accessibilityLabel("\(settings.motes) fallen stars")
                Spacer()
                settingsMenu
            }
            .padding(.horizontal, 24)
            .padding(.top, 58)

            Spacer(minLength: 8)
            Image(uiImage: FoxArt.portrait)
                .resizable()
                .scaledToFit()
                .frame(height: 104)
                .colorMultiply(settings.selectedStyle.color.mix(0.3))
                .shadow(color: settings.selectedStyle.color.opacity(0.8), radius: 14)
                .padding(.bottom, 12)
                .accessibilityHidden(true)
            Text("NORTHERN LIGHTS")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
            Text("RELAY")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .tracking(8)
                .foregroundStyle(Color.cyan.opacity(0.9))
                .padding(.top, 7)
            Text("Run the night sky. Paint the northern lights.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 12)

            Spacer(minLength: 14)

            HStack(alignment: .top, spacing: 0) {
                statColumn(title: "PERSONAL BEST", value: "\(settings.bestScore)")
                statColumn(title: "NIGHTS LIT", value: "\(settings.currentStreak)", symbol: settings.currentStreak > 0 ? "flame.fill" : nil)
            }
            .padding(.horizontal, 36)

            goalsCard
                .padding(.horizontal, 28)
                .padding(.top, 16)

            dailyGoalBar
                .padding(.horizontal, 36)
                .padding(.top, 16)

            puckPicker
                .padding(.top, 16)

            Button { startRun(zen: false) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right")
                    Text("CARRY THE FIRE").tracking(2)
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.cyan, in: Capsule())
            }
            .padding(.horizontal, 36)
            .padding(.top, 18)

            Button { startRun(zen: true) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "leaf")
                    Text("ZEN GLIDE").tracking(2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
            }
            .padding(.horizontal, 36)
            .padding(.top, 10)

            Text("DRAG TO STEER THE FOX · CENTRE PASSES ARE PERFECT")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 12)
                .padding(.bottom, 30)
        }
    }

    /// Music, sounds, haptics and the story, tucked into one calm menu.
    private var settingsMenu: some View {
        Menu {
            Toggle(isOn: $settings.musicEnabled) { Label("Music", systemImage: "music.note") }
            Toggle(isOn: $settings.effectsEnabled) { Label("Sounds", systemImage: "bell") }
            Toggle(isOn: $settings.hapticsEnabled) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }
            Divider()
            Button { showIntro = true } label: { Label("The Story", systemImage: "book") }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.08), in: Circle())
        }
        .accessibilityLabel("Settings")
    }

    /// Alto's-style: three goals at a time; finish all three to rise a level.
    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("LEVEL \(settings.level)")
                    .font(.caption2.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.cyan.opacity(0.85))
                Spacer()
                Text("\(settings.goals.filter(\.done).count) / 3")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
            }
            ForEach(settings.goals) { goal in
                HStack(spacing: 10) {
                    Image(systemName: goal.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(goal.done ? Color.green.opacity(0.85) : .white.opacity(0.35))
                    Text(goal.title)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(goal.done ? 0.5 : 0.85))
                        .strikethrough(goal.done, color: .white.opacity(0.4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    if let progress = goal.progressText {
                        Text(progress)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
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
                    .font(.system(size: 38, weight: .light, design: .rounded))
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
                Text(settings.dailyGoalMet ? "TONIGHT'S RELAY COMPLETE" : "TONIGHT'S RELAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(settings.dailyGoalMet ? Color.green.opacity(0.85) : .white.opacity(0.55))
                Spacer()
                Text("\(min(today, goal)) / \(goal) CLOUDS")
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
                                    Image(uiImage: FoxArt.portrait)
                                        .resizable()
                                        .scaledToFit()
                                        .colorMultiply(style.color.mix(0.75))
                                        .shadow(color: style.color.opacity(0.8), radius: 6)
                                        .frame(width: 30, height: 30)
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
                Text("\(next.remaining) more \(next.remaining == 1 ? "cloud" : "clouds") to meet the \(next.style.name) fox")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    // MARK: - Run

    private var runView: some View {
        ZStack(alignment: .top) {
            // The scene is fully opaque, so no transparency (cheaper to draw), and
            // 120fps on ProMotion iPhones for smoother scrolling.
            SpriteView(scene: runScene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .id(runID)

            HStack(alignment: .top, spacing: 12) {
                hudButton(symbol: "xmark", action: leaveRun)
                if finalScore == nil {
                    hudButton(symbol: isPaused ? "play.fill" : "pause.fill") { setPaused(!isPaused) }
                }
                Spacer()
                VStack(spacing: 2) {
                    if isZenRun {
                        Text("ZEN")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    // The live gate count is drawn inside RelayScene.
                }
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 58)

            if isPaused && finalScore == nil {
                pauseOverlay
                    .transition(.opacity)
            }

            if let score = finalScore {
                endOfRun(score: score)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: finalScore)
        .animation(.easeInOut(duration: 0.3), value: isPaused)
    }

    private func hudButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.12), in: Circle())
        }
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }   // swallow taps so they don't steer
            VStack(spacing: 18) {
                Text("PAUSED")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(.white.opacity(0.8))
                Button { setPaused(false) } label: {
                    Label("RESUME", systemImage: "play.fill")
                        .font(.headline.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(ink)
                        .frame(width: 220, height: 54)
                        .background(Color.cyan, in: Capsule())
                }
                homeButton
            }
        }
    }

    private var homeButton: some View {
        Button(action: leaveRun) {
            Label("HOME", systemImage: "house.fill")
                .font(.headline.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 220, height: 50)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }

    /// A calm end screen: no big panel, just the result and "tap to go again".
    private func endOfRun(score: Int) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if canRestart { startRun(zen: false) } }

            VStack(spacing: 10) {
                if lastRun.reachedDawn {
                    Text("DAWN · THE FIRE IS PASSED ON")
                        .font(.caption.weight(.bold))
                        .tracking(2.5)
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.75))
                }
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
                        Label("Tonight's relay complete · \(settings.currentStreak) \(settings.currentStreak == 1 ? "night" : "nights") lit", systemImage: "flame.fill")
                    } else {
                        Text("Tonight's relay: \(settings.todayGates) / \(SettingsStore.dailyGoal) clouds")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 14)

                runRewards

                ForEach(outcome.unlockedStyles) { style in
                    HStack(spacing: 8) {
                        Circle().fill(style.color).frame(width: 12, height: 12)
                        Text("A new fox joins the relay: \(style.name)")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }

                Text("TAP ANYWHERE TO RUN AGAIN")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(canRestart ? 0.75 : 0))
                    .padding(.top, 28)
                    .allowsHitTesting(false)

                homeButton
                    .padding(.top, 14)
            }
            .allowsHitTesting(canRestart)
        }
    }

    /// Motes earned, goals finished this run, and a level-up if it happened.
    private var runRewards: some View {
        VStack(spacing: 8) {
            if outcome.motesEarned > 0 {
                Label("+\(outcome.motesEarned) fallen stars", systemImage: "star.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 1, green: 0.93, blue: 0.72))
            }
            ForEach(outcome.completedGoals) { goal in
                Label(goal.title, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.green.opacity(0.85))
            }
            if let level = outcome.leveledUpTo {
                Text("LEVEL \(level) · +\(outcome.levelReward) STARS")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Color.cyan)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 6)
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
        isNewBest = false
        outcome = RunOutcome()
        lastRun = RunResult()
        canRestart = false
        isPaused = false
        isZenRun = zen
        // Wire the callbacks onto each new scene here. Doing it in .onAppear only
        // worked for the first run: restarting keeps the play screen on screen,
        // so onAppear never fired again and the new scene had no hooks.
        let style = settings.selectedStyle
        let scene = RelayScene(size: CGSize(width: 390, height: 844), zen: zen,
                               puckColor: SKColor(red: style.red, green: style.green, blue: style.blue, alpha: 1))
        scene.hapticsEnabled = settings.hapticsEnabled
        scene.onGameOver = { result in
            DispatchQueue.main.async {
                isNewBest = result.arches > settings.bestScore
                lastRun = result
                outcome = settings.record(result)
                finalScore = result.arches
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

    /// Leaving mid-run still banks what you earned: arches, motes and goal
    /// progress (Zen counts toward motes and Zen goals).
    private func leaveRun() {
        let result = runScene.result
        if finalScore == nil && (result.arches > 0 || result.motes > 0) {
            settings.record(result)
        }
        goHome()
    }

    private func setPaused(_ paused: Bool) {
        isPaused = paused
        runScene.gamePaused = paused
    }

    private func goHome() {
        runScene.gamePaused = true
        isPaused = false
        withAnimation { isPlaying = false; finalScore = nil }
    }
}

private extension Color {
    /// This colour blended toward white; 1 keeps it as is.
    func mix(_ amount: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: 1 - (1 - r) * amount, green: 1 - (1 - g) * amount, blue: 1 - (1 - b) * amount)
    }
}
