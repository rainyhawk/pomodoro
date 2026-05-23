import Foundation
import SwiftData

@Model
final class BlockedApp {
    @Attribute(.unique) var bundleID: String
    var name: String
    var enabled: Bool
    var createdAt: Date

    init(bundleID: String, name: String, enabled: Bool = true) {
        self.bundleID = bundleID
        self.name = name
        self.enabled = enabled
        self.createdAt = .now
    }
}
