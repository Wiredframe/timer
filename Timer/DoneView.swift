import SwiftUI

/// End screen: a lime circle pops in, rings expand, then a short summary.
struct DoneView: View {
    let config: WorkoutConfig
    let onClose: () -> Void

    @State private var stage = 0

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.14))
                        .frame(width: 300, height: 300)
                        .scaleEffect(stage >= 2 ? 1 : 0.5)
                        .opacity(stage >= 2 ? 1 : 0)
                    Circle()
                        .fill(Color.brand.opacity(0.28))
                        .frame(width: 230, height: 230)
                        .scaleEffect(stage >= 2 ? 1 : 0.6)
                        .opacity(stage >= 2 ? 1 : 0)
                    Circle()
                        .fill(Color.brand)
                        .frame(width: 160, height: 160)
                        .shadow(color: Color.brand.opacity(0.4), radius: 16, y: 6)
                        .scaleEffect(stage >= 1 ? 1 : 0.2)
                    Text("💪")
                        .font(.system(size: 72))
                        .scaleEffect(stage >= 2 ? 1 : 0.3)
                        .opacity(stage >= 2 ? 1 : 0)
                }

                VStack(spacing: 6) {
                    Text("Gute Arbeit!")
                        .font(.largeTitle.bold())
                    Text("\(config.sets) Sets · \(mmss(config.total))")
                        .font(.title3.weight(.medium))
                        .monospacedDigit()
                        .opacity(0.8)
                }
                .foregroundStyle(.primary)
                .padding(.top, 36)
                .opacity(stage >= 3 ? 1 : 0)
                .offset(y: stage >= 3 ? 0 : 16)

                Spacer()

                Button(action: onClose) {
                    Text("Fertig")
                        .font(.title3.bold())
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .opacity(stage >= 3 ? 1 : 0)
            }
        }
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { stage = 1 }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { stage = 2 }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.4)) { stage = 3 }
        }
    }
}
