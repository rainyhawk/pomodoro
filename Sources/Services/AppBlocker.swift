import AppKit
import Foundation

final class AppBlocker {
    private var timer: Timer?
    private var blockedBundleIDs: Set<String> = []

    func start(bundleIDs: [String]) {
        blockedBundleIDs = Set(bundleIDs)
        terminateMatching()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.terminateMatching()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        blockedBundleIDs = []
    }

    private func terminateMatching() {
        guard !blockedBundleIDs.isEmpty else { return }
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, blockedBundleIDs.contains(id) else { continue }
            app.terminate()
        }
    }
}
