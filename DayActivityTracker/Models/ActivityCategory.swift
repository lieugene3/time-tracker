import Foundation

enum ActivityCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case activeLearn
    case passiveLearn
    case media
    case commuteTravel
    case social
    case work
    case exercise
    case sleep
    case personal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .activeLearn:
            "Active Learn"
        case .passiveLearn:
            "Passive Learn"
        case .media:
            "Media"
        case .commuteTravel:
            "Commute/Travel"
        case .social:
            "Social"
        case .work:
            "Work"
        case .exercise:
            "Exercise"
        case .sleep:
            "Sleep"
        case .personal:
            "Personal"
        }
    }

    var supportsSubActivities: Bool {
        switch self {
        case .activeLearn, .passiveLearn:
            true
        default:
            false
        }
    }
}
