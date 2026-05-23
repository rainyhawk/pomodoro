import Foundation
import SwiftData

enum SessionType: String, Codable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
}

@Model
final class Session {
    var startedAt: Date
    var endedAt: Date?
    var typeRaw: String
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    var completed: Bool

    var type: SessionType {
        get { SessionType(rawValue: typeRaw) ?? .focus }
        set { typeRaw = newValue.rawValue }
    }

    init(
        startedAt: Date = .now,
        type: SessionType,
        plannedDuration: TimeInterval
    ) {
        self.startedAt = startedAt
        self.endedAt = nil
        self.typeRaw = type.rawValue
        self.plannedDuration = plannedDuration
        self.actualDuration = 0
        self.completed = false
    }
}
