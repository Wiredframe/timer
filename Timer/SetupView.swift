import SwiftUI

struct SetupView: View {
    @AppStorage("sets") private var sets = 8
    @AppStorage("work") private var work = 20
    @AppStorage("rest") private var rest = 10
    @AppStorage("skipLastRest") private var skipLastRest = true

    let onStart: (WorkoutConfig) -> Void

    private let step = 5
    private let maxSeconds = 60 * 60

    private var config: WorkoutConfig {
        WorkoutConfig(sets: sets, work: work, rest: rest, skipLastRest: skipLastRest)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 16) {
                    card {
                        ValueRow(title: String(localized: "SETS"), tint: .secondary, value: "\(sets)",
                                 canDecrease: sets > 1, canIncrease: sets < 99,
                                 decrease: { sets -= 1 }, increase: { sets += 1 })
                    }

                    card {
                        ValueRow(title: String(localized: "WORK"), tint: .brandText, value: mmss(work),
                                 canDecrease: work > step, canIncrease: work < maxSeconds,
                                 decrease: { work -= step }, increase: { work += step })
                        Divider()
                        ValueRow(title: String(localized: "REST"), tint: .restLabel, value: mmss(rest),
                                 canDecrease: rest > 0, canIncrease: rest < maxSeconds,
                                 decrease: { rest -= step }, increase: { rest += step })
                        Divider()
                        Toggle("Skip last rest", isOn: $skipLastRest)
                            .tint(.brand)
                            .disabled(rest == 0)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            startButton
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(.selection, trigger: sets)
        .sensoryFeedback(.selection, trigger: work)
        .sensoryFeedback(.selection, trigger: rest)
    }

    private var header: some View {
        HStack {
            Text("Timer")
                .font(.largeTitle.bold())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var startButton: some View {
        Button { onStart(config) } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.fill")
                Text("Start workout")
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(mmss(config.total))
                    .monospacedDigit()
                    .opacity(0.75)
                    .contentTransition(.numericText())
            }
            .font(.title3.bold())
            .foregroundStyle(Color.ink)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 24)
            .frame(minHeight: 64)
            .background(Color.brand, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: config.total)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ValueRow: View {
    let title: String
    let tint: Color
    let value: String
    let canDecrease: Bool
    let canIncrease: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            HStack {
                stepButton("minus", label: String(localized: "Decrease \(title.capitalized)"), enabled: canDecrease, action: decrease)
                Spacer()
                Text(value)
                    .font(.system(size: 44, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("\(title.capitalized) \(value)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                Spacer()
                stepButton("plus", label: String(localized: "Increase \(title.capitalized)"), enabled: canIncrease, action: increase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func stepButton(_ symbol: String, label: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title.weight(.semibold))
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.4))
        .disabled(!enabled)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }
}
