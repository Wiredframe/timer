import SwiftUI

struct RunView: View {
    let model: WorkoutModel
    let onClose: () -> Void

    @AppStorage(SoundPlayer.enabledKey) private var soundOn = true

    var body: some View {
        ZStack {
            if model.isFinished {
                DoneView(config: model.config, onClose: onClose)
                    .transition(.opacity)
            } else {
                TimelineView(.animation(paused: model.isPaused)) { context in
                    running(at: context.date)
                }
                .transition(.opacity)
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: model.isFinished)
    }

    private var kind: WorkoutModel.Kind { model.current.kind }
    private var isPrepare: Bool { kind == .prepare }

    /// Colour of the liquid and of everything it covers.
    private var liquid: Color {
        switch kind {
        case .prepare: Color(.systemGray5)
        case .work: .brand
        case .rest: .liquidRest
        }
    }

    private var onLiquid: Color {
        switch kind {
        case .prepare: .primary
        case .work: .ink
        case .rest: .inkRest
        }
    }

    // MARK: - Layers

    /// The fill sits behind the content; a second copy of the content in the
    /// "on liquid" colours is cut out by the same shape, so text and buttons change
    /// colour where the fill covers them. Both use the same frame, nothing is measured.
    private func running(at date: Date) -> some View {
        let hill = Hill(level: model.progress(at: date))
        return ZStack {
            content(at: date, fg: .primary, pillText: Color(.systemBackground))
            content(at: date, fg: onLiquid, pillText: liquid)
                .mask { hill.ignoresSafeArea() }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background { hill.fill(liquid).ignoresSafeArea() }
    }

    private func content(at date: Date, fg: Color, pillText: Color) -> some View {
        VStack(spacing: 0) {
            topBar(at: date, fg: fg)
            Spacer()
            VStack(spacing: 4) {
                Text(title)
                    .font(.title.bold())
                Text(isPrepare ? "\(model.remaining(at: date))" : mmss(model.remaining(at: date)))
                    .font(.system(size: 112, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: model.remaining(at: date))
            }
            .padding(.horizontal, 24)
            Spacer()
            controls(fg: fg, pillText: pillText)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .foregroundStyle(fg)
    }

    private var title: String {
        switch kind {
        case .prepare: String(localized: "PREPARE")
        case .work: String(localized: "WORK \(model.current.set)/\(model.config.sets)")
        case .rest: String(localized: "REST \(model.current.set)/\(model.config.sets)")
        }
    }

    private func topBar(at date: Date, fg: Color) -> some View {
        HStack {
            squareButton("xmark", label: String(localized: "Stop"), fg: fg, action: onClose)
            Spacer()
            if !isPrepare {
                VStack(spacing: 0) {
                    Text("REMAINING")
                        .font(.caption.bold())
                        .opacity(0.6)
                    Text(mmss(model.totalRemaining(at: date)))
                        .font(.title2.weight(.medium))
                        .monospacedDigit()
                }
            }
            Spacer()
            squareButton(soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                         label: soundOn ? String(localized: "Sound off") : String(localized: "Sound on"), fg: fg) { soundOn.toggle() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func controls(fg: Color, pillText: Color) -> some View {
        if isPrepare {
            Button(action: model.skipForward) {
                Text("Skip")
                    .font(.headline)
                    .frame(maxWidth: 240)
                    .frame(height: 60)
                    .background(fg.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 14) {
                squareButton("chevron.backward.2", label: String(localized: "Back"), size: 64, fg: fg, action: model.skipBack)
                Button(action: model.togglePause) {
                    Label(model.isPaused ? "Resume" : "Pause",
                          systemImage: model.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3.bold())
                        .foregroundStyle(pillText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(fg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                squareButton("chevron.forward.2", label: String(localized: "Next"), size: 64, fg: fg, action: model.skipForward)
            }
        }
    }

    private func squareButton(_ symbol: String, label: String, size: CGFloat = 44, fg: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(size > 44 ? .title3.bold() : .body.bold())
                .frame(width: size, height: size)
                .background(fg.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Filled area from the bottom up to `level`, its surface a gently rounded hill.
/// The hill flattens out when the fill is nearly empty or nearly full.
nonisolated struct Hill: Shape {
    var level: Double   // 0 … 1 of the height

    func path(in rect: CGRect) -> Path {
        let peak = 34 * min(1, level * 10, (1 - level) * 10)
        let base = rect.maxY - rect.height * level
        // Lift by part of the hill so the visible amount still matches `level`.
        let y = { (x: Double) -> Double in
            let u = (x - rect.midX) / (rect.width * 0.42)
            return base + peak * 0.4 - peak * exp(-u * u)
        }
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for x in stride(from: rect.minX, to: rect.maxX, by: 4) {
            path.addLine(to: CGPoint(x: x, y: y(x)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: y(rect.maxX)))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
