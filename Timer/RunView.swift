import SwiftUI

struct RunView: View {
    let model: WorkoutModel
    let onClose: () -> Void

    @AppStorage(SoundPlayer.enabledKey) private var soundOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Frame of the full-screen liquid layer, used to align the text mask with it.
    @State private var liquidFrame: CGRect = .zero

    var body: some View {
        ZStack {
            if model.isFinished {
                DoneView(config: model.config, onClose: onClose)
                    .transition(.opacity)
            } else {
                // Keeps running while paused so the liquid surface stays alive.
                TimelineView(.animation) { context in
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

    private func running(at date: Date) -> some View {
        let waves = surface(at: date)
        return ZStack {
            ZStack {
                waves.back.fill(liquid.opacity(0.45))
                waves.front.fill(liquid)
            }
            .ignoresSafeArea()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { liquidFrame = $0 }

            // Neutral content, then the same content in the "on liquid" colours,
            // cut out by the liquid so text and buttons change colour where it covers them.
            content(at: date, fg: .primary, pillText: Color(.systemBackground))
            content(at: date, fg: onLiquid, pillText: liquid)
                .mask { aligned(waves.front) }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Two waves drift against each other; they flatten out at empty and full.
    private func surface(at date: Date) -> (front: Wave, back: Wave) {
        let progress = model.progress(at: date)
        let time = date.timeIntervalSinceReferenceDate
        let edge = min(1, progress * 14, (1 - progress) * 14)
        let amplitude = reduceMotion ? 0 : 10 * edge * (model.isPaused ? 0.5 : 1)
        return (
            Wave(level: progress, amplitude: amplitude, wavelength: 0.9, phase: time * 2.3),
            Wave(level: progress, amplitude: amplitude * 0.8, wavelength: 1.3, phase: -time * 1.7 + 1.2)
        )
    }

    /// Places a full-screen shape inside a mask whose own frame is the safe area.
    private func aligned(_ wave: Wave) -> some View {
        GeometryReader { geo in
            let own = geo.frame(in: .global)
            wave
                .frame(width: liquidFrame.width, height: liquidFrame.height)
                .offset(x: liquidFrame.minX - own.minX, y: liquidFrame.minY - own.minY)
        }
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
        case .prepare: "VORBEREITEN"
        case .work: "ARBEIT \(model.current.set)/\(model.config.sets)"
        case .rest: "AUSRUHEN \(model.current.set)/\(model.config.sets)"
        }
    }

    private func topBar(at date: Date, fg: Color) -> some View {
        HStack {
            squareButton("xmark", label: "Beenden", fg: fg, action: onClose)
            Spacer()
            if !isPrepare {
                VStack(spacing: 0) {
                    Text("VERBLEIBEND")
                        .font(.caption.bold())
                        .opacity(0.6)
                    Text(mmss(model.totalRemaining(at: date)))
                        .font(.title2.weight(.medium))
                        .monospacedDigit()
                }
            }
            Spacer()
            squareButton(soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                         label: soundOn ? "Ton aus" : "Ton an", fg: fg) { soundOn.toggle() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func controls(fg: Color, pillText: Color) -> some View {
        if isPrepare {
            Button(action: model.skipForward) {
                Text("Überspringen")
                    .font(.headline)
                    .frame(maxWidth: 240)
                    .frame(height: 60)
                    .background(fg.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 14) {
                squareButton("chevron.backward.2", label: "Zurück", size: 64, fg: fg, action: model.skipBack)
                Button(action: model.togglePause) {
                    Label(model.isPaused ? "Weiter" : "Pause",
                          systemImage: model.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3.bold())
                        .foregroundStyle(pillText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(fg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                squareButton("chevron.forward.2", label: "Weiter", size: 64, fg: fg, action: model.skipForward)
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

/// Filled area from the bottom up to `level`, with a sine-shaped surface.
nonisolated struct Wave: Shape {
    var level: Double        // 0 … 1 of the height
    var amplitude: Double    // points
    var wavelength: Double   // in screen widths
    var phase: Double        // radians

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let surface = rect.maxY - rect.height * level
        let k = 2 * Double.pi / (rect.width * wavelength)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let y = { (x: Double) in surface + amplitude * sin(k * (x - rect.minX) + phase) }
        for x in stride(from: rect.minX, to: rect.maxX, by: 6) {
            path.addLine(to: CGPoint(x: x, y: y(x)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: y(rect.maxX)))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
