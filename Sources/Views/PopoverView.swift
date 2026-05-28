import SwiftUI

struct PopoverView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case timer, stats, blocks
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .timer: return "timer"
            case .stats: return "chart.bar.fill"
            case .blocks: return "shield.lefthalf.filled"
            }
        }
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
            Group {
                switch tab {
                case .timer: TimerView()
                case .stats: StatsView()
                case .blocks: BlockListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 0) {
                ForEach(Tab.allCases) { t in
                    tabButton(t)
                }
            }
            .padding(.vertical, 6)
            .background(.background.secondary)
        }
        .frame(width: 320, height: 400)
        .onAppear { engine.rolloverCounterIfNeeded() }
    }

    private func tabButton(_ t: Tab) -> some View {
        Button {
            tab = t
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(t.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(tab == t ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
