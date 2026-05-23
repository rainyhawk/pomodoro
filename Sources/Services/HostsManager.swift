import Foundation

final class HostsManager {
    static let helperPath = "/usr/local/bin/pomodoro-hosts"

    var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: Self.helperPath)
    }

    func apply(domains: [String]) {
        guard isInstalled, !domains.isEmpty else { return }
        run(args: ["apply", domains.joined(separator: ",")])
    }

    func clear() {
        guard isInstalled else { return }
        run(args: ["clear"])
    }

    private func run(args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        task.arguments = ["-n", Self.helperPath] + args
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            NSLog("pomodoro: hosts helper failed — \(error.localizedDescription)")
        }
    }
}
