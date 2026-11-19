import SwiftUI

/// The short story shown on first launch (and from "The Story" on home).
/// Lines fade in one at a time, slowly, then a single button continues.
struct StoryIntroView: View {
    let onBegin: () -> Void
    @State private var shownLines = 0

    private let lines = [
        "Long ago, the northern lights were carried across the sky — one lantern at a time, passed from keeper to keeper.",
        "Tonight the relay has gone dark. Only your light remains.",
        "Guide it through the ancient ice arches. Each one you pass wakes the aurora again.",
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.10), Color(red: 0.03, green: 0.10, blue: 0.16)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "sparkle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.cyan.opacity(0.85))
                    .opacity(shownLines > 0 ? 1 : 0)

                ForEach(lines.indices, id: \.self) { i in
                    Text(lines[i])
                        .font(.system(size: 18, weight: .light, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.88))
                        .opacity(shownLines > i ? 1 : 0)
                        .offset(y: shownLines > i ? 0 : 8)
                }
                Spacer()

                Button(action: onBegin) {
                    Text("BEGIN")
                        .font(.headline.weight(.bold))
                        .tracking(3)
                        .foregroundStyle(Color(red: 0.03, green: 0.10, blue: 0.17))
                        .frame(width: 200, height: 52)
                        .background(Color.cyan, in: Capsule())
                }
                .opacity(shownLines >= lines.count ? 1 : 0)
                .disabled(shownLines < lines.count)
                .padding(.bottom, 70)
            }
            .padding(.horizontal, 40)
        }
        .contentShape(Rectangle())
        // Tapping shows the remaining lines at once, for anyone who reads fast.
        .onTapGesture { withAnimation(.easeOut(duration: 0.6)) { shownLines = lines.count } }
        .task {
            for i in 1...lines.count {
                try? await Task.sleep(for: .seconds(i == 1 ? 0.5 : 2.2))
                withAnimation(.easeOut(duration: 1.4)) { shownLines = max(shownLines, i) }
            }
        }
    }
}
