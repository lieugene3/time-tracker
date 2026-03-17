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

    var symbolName: String {
        switch self {
        case .activeLearn:
            "book.closed.fill"
        case .passiveLearn:
            "headphones"
        case .media:
            "play.rectangle.fill"
        case .commuteTravel:
            "tram.fill"
        case .social:
            "person.2.fill"
        case .work:
            "briefcase.fill"
        case .exercise:
            "figure.run"
        case .sleep:
            "bed.double.fill"
        case .personal:
            "heart.fill"
        }
    }
}
