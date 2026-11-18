import SwiftUI
import SpriteKit

struct HomeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var isPlaying = false
    @State private var finalScore: Int?
    @State private var runID = UUID()
    @State private var runScene = RelayScene(size: CGSize(width: 390, height: 844))
    @State private var currentScore = 0
    @State private var isNewBest = false

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
    }

    private var homeScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.cyan.opacity(0.9))
                .padding(.bottom, 22)
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
                .padding(.top, 24)

            Spacer()

            VStack(spacing: 7) {
                Text("PERSONAL BEST")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(settings.bestScore)")
                    .font(.system(size: 54, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 35)

            Button(action: startRun) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right")
                    Text("START RUN")
                        .tracking(2)
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.03, green: 0.10, blue: 0.17))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.cyan, in: Capsule())
            }
            .padding(.horizontal, 36)

            Text("DRAG TO STEER · SLIP THROUGH THE GATES")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.48))
                .padding(.top, 17)
                .padding(.bottom, 58)
        }
        .padding(.top, 50)
    }

    private var runView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                SpriteView(scene: runScene, options: [.allowsTransparency])
                    .ignoresSafeArea()
                    .id(runID)
                    .onAppear {
                        runScene.onScoreChanged = { score in
                            DispatchQueue.main.async { currentScore = score }
                        }
                        runScene.onGameOver = { score in
                            DispatchQueue.main.async {
                                isNewBest = score > settings.bestScore
                                settings.recordRun(score: score)
                                finalScore = score
                            }
                        }
                    }

                HStack(alignment: .top) {
                    Button {
                        withAnimation { isPlaying = false; finalScore = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
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
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 58)

                if let score = finalScore {
                    Color.black.opacity(0.54)
                        .ignoresSafeArea()
                    VStack(spacing: 14) {
                        Text("THE NIGHT RUN")
                            .font(.caption.weight(.bold))
                            .tracking(3)
                            .foregroundStyle(Color.cyan)
                        Text("\(score)")
                            .font(.system(size: 72, weight: .light, design: .rounded))
                            .monospacedDigit()
                        Text(isNewBest ? "NEW PERSONAL BEST" : "GATES CLEARED")
                            .font(.footnote.weight(.semibold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.65))
                        Button(action: startRun) {
                            Text("RUN IT BACK")
                                .font(.headline.weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(Color(red: 0.03, green: 0.10, blue: 0.17))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.cyan, in: Capsule())
                        }
                        .padding(.top, 10)
                        Button("BACK TO THE CANAL") {
                            withAnimation { isPlaying = false; finalScore = nil }
                        }
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 6)
                    }
                    .padding(30)
                    .frame(maxWidth: 320)
                    .background(Color(red: 0.04, green: 0.12, blue: 0.19).opacity(0.96), in: RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12), lineWidth: 1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

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

    private func startRun() {
        finalScore = nil
        currentScore = 0
        isNewBest = false
        runScene = RelayScene(size: CGSize(width: 390, height: 844))
        runID = UUID()
        withAnimation { isPlaying = true }
    }
}
