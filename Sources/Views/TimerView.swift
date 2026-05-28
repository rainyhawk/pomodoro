import SwiftUI

struct TimerView: View {
    @Environment(TimerEngine.self) private var engine

    private var phaseTotal: TimeInterval {
        switch engine.phase {
        case .focus: return engine.focusDuration
        case .shortBreak: return engine.shortBreakDuration
        case .longBreak: return engine.longBreakDuration
        }
    }

    private var progress: Double {
        guard phaseTotal > 0 else { return 0 }
        return min(1, max(0, 1 - engine.remaining / phaseTotal))
    }

    private var ringColor: Color {
        switch engine.phase {
        case .focus: return .accentColor
        case .shortBreak, .longBreak: return .green
        }
    }

    var body: some View {
        @Bindable var engine = engine
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)

                VStack(spacing: 6) {
                    Text(engine.phase.label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)
                    Text(formatTime(engine.remaining))
                        .font(.system(size: 42, weight: .light, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 180, height: 180)

            Spacer(minLength: 16)

            HStack(spacing: 6) {
                let done = engine.completedFocusBlocks % engine.focusBlocksBeforeLongBreak
                ForEach(0..<engine.focusBlocksBeforeLongBreak, id: \.self) { i in
                    Capsule()
                        .fill(i < done ? ringColor : Color.secondary.opacity(0.2))
                        .frame(width: i < done ? 18 : 8, height: 4)
                        .animation(.easeOut(duration: 0.25), value: done)
                }
            }

            primaryButton
                .padding(.top, 18)

            HStack {
                Menu {
                    ForEach(PomodoroPreset.allCases) { p in
                        Button {
                            engine.preset = p
                        } label: {
                            if engine.preset == p {
                                Label(p.rawValue, systemImage: "checkmark")
                            } else {
                                Text(p.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(engine.preset.rawValue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(engine.state != .idle)
                .help(engine.state != .idle ? "Reset to change preset" : "")

                Spacer()

                Text("\(engine.completedFocusBlocks) today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch engine.state {
        case .idle:
            Button {
                engine.start()
            } label: {
                Text("Start")
                    .frame(width: 110)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        case .running:
            Button {
                engine.pause()
            } label: {
                Text("Pause")
                    .frame(width: 110)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        case .paused:
            Button {
                engine.resume()
            } label: {
                Text("Resume")
                    .frame(width: 110)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
