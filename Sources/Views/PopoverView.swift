import SwiftUI


struct PopoverView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case timer, stats, blocks
        var id: String { rawValue }
        var title: String {
            switch self {
            case .timer: return "Timer"
            case .stats: return "Stats"
            case .blocks: return "Blocks"
            }
        }
    }

    @State private var tab: Tab = .timer
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            Group {
                switch tab {
                case .timer: TimerView()
                case .stats: StatsView()
                case .blocks: BlockListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 300, height: 400)
        .onAppear { engine.rolloverCounterIfNeeded() }
    }
}
