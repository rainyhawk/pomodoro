import Foundation
import SwiftData

final class Blocker {
    private let hosts = HostsManager()
    private let apps = AppBlocker()
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var hostsHelperInstalled: Bool { hosts.isInstalled }

    func startBlocking() {
        let sites = (try? modelContext.fetch(FetchDescriptor<BlockedSite>())) ?? []
        let blockedApps = (try? modelContext.fetch(FetchDescriptor<BlockedApp>())) ?? []

        let activeDomains = sites.filter(\.enabled).map(\.domain)
        let activeBundleIDs = blockedApps.filter(\.enabled).map(\.bundleID)

        hosts.apply(domains: activeDomains)
        apps.start(bundleIDs: activeBundleIDs)
    }

    func stopBlocking() {
        hosts.clear()
        apps.stop()
    }
}
