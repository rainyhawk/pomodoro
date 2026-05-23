import SwiftUI
import SwiftData

@main
struct PomodoroApp: App {
    let container: ModelContainer
    @State private var engine: TimerEngine

    init() {
        let schema = Schema([Session.self, BlockedSite.self, BlockedApp.self])
        let config = ModelConfiguration(schema: schema)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.container = container
        let blocker = Blocker(modelContext: container.mainContext)
        _engine = State(initialValue: TimerEngine(modelContext: container.mainContext, blocker: blocker))
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(engine)
                .modelContainer(container)
        } label: {
            MenuBarLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let engine: TimerEngine

    var body: some View {
        switch engine.state {
        case .idle:
            Image(systemName: "timer")
        case .running, .paused:
            HStack(spacing: 4) {
                Image(systemName: phaseIcon)
                Text(formatTime(engine.remaining))
                    .monospacedDigit()
            }
        }
    }

    private var phaseIcon: String {
        switch engine.phase {
        case .focus: return "brain.head.profile"
        case .shortBreak, .longBreak: return "cup.and.saucer.fill"
        }
    }
}

func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded(.up))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
