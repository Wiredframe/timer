import SwiftUI

@main
struct TimerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.brandText)
        }
    }
}

/// Switches between the setup screen and a running workout.
struct RootView: View {
    @State private var sound = SoundPlayer()
    @State private var workout: WorkoutModel?

    var body: some View {
        ZStack {
            SetupView { config in
                // A double tap must not start a second, invisible workout.
                guard workout == nil else { return }
                sound.start()
                workout = WorkoutModel(config: config, sound: sound)
            }

            if let workout {
                RunView(model: workout) {
                    workout.stop()
                    sound.stop()
                    self.workout = nil
                }
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.35), value: workout != nil)
        #if DEBUG
        .task {
            // Simulator demo: launch with -demo to start a short workout after a moment,
            // with the same slide-in transition as a tap on the start button.
            guard ProcessInfo.processInfo.arguments.contains("-demo") else { return }
            try? await Task.sleep(for: .seconds(1))
            sound.start()
            workout = WorkoutModel(config: .init(sets: 2, work: 5, rest: 5, skipLastRest: true), sound: sound)
        }
        #endif
    }
}
