import Foundation

struct FlowerShowPurchaseContext: Equatable, Identifiable, Sendable {
    enum Origin: Equatable, Sendable {
        case afterClassFive
        case lockedClass
        case home
    }

    let origin: Origin
    let targetClass: Int?

    static var afterClassFive: Self {
        Self(origin: .afterClassFive, targetClass: 6)
    }

    static func lockedClass(_ classNumber: Int) -> Self {
        Self(origin: .lockedClass, targetClass: classNumber)
    }

    static var home: Self {
        Self(origin: .home, targetClass: 6)
    }

    var id: String {
        let target = targetClass.map(String.init) ?? "none"
        return "\(origin)-\(target)"
    }
}
