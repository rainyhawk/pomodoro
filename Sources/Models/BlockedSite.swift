import Foundation
import SwiftData

@Model
final class BlockedSite {
    @Attribute(.unique) var domain: String
    var enabled: Bool
    var createdAt: Date

    init(domain: String, enabled: Bool = true) {
        self.domain = domain
        self.enabled = enabled
        self.createdAt = .now
    }
}
