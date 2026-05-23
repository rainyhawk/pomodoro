import SwiftUI

struct TimerView: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        @Bindable var engine = engine
        VStack(spacing: 20) {
            Text(engine.phase.label)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            Text(formatTime(engine.remaining))
                .font(.system(size: 64, weight: .light, design: .monospaced))

            HStack(spacing: 12) {
                switch engine.state {
                case .idle:
                    Button("Start") { engine.start() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                case .running:
                    Button("Pause") { engine.pause() }
                        .buttonStyle(.bordered)
                case .paused:
                    Button("Resume") { engine.resume() }
                        .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: 8) {
                let cycleProgress = engine.completedFocusBlocks % engine.focusBlocksBeforeLongBreak
                ForEach(0..<engine.focusBlocksBeforeLongBreak, id: \.self) { i in
                    Circle()
                        .fill(i < cycleProgress ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 4)

            Text("\(engine.completedFocusBlocks) focus blocks completed today")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Picker("Preset", selection: $engine.preset) {
                ForEach(PomodoroPreset.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(engine.state != .idle)
            .help(engine.state != .idle ? "Reset to change preset" : "")
        }
        .padding()
    }
}
