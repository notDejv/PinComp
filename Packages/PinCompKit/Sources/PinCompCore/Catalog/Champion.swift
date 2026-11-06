import Foundation

public struct Champion: Codable, Hashable, Sendable, Identifiable {
    /// Riot character ID, e.g. `DA_18_Ahri`.
    public let id: String
    public let name: String
    /// 1…5.
    public let cost: Int
    public let plannerCode: Int
    /// Remote icon; the app caches it locally (see `CatalogCache`).
    public let iconURL: URL

    public init(id: String, name: String, cost: Int, plannerCode: Int, iconURL: URL) {
        self.id = id
        self.name = name
        self.cost = cost
        self.plannerCode = plannerCode
        self.iconURL = iconURL
    }

    enum CodingKeys: String, CodingKey {
        case id, name, cost, plannerCode
        case iconURL = "icon"
    }
}

/// `data/<set>/champions.json`.
public struct SetCatalog: Codable, Hashable, Sendable {
    public let set: String
    /// ISO 8601 string; changes only when the published data changes.
    public let generatedAt: String
    public let champions: [Champion]

    public init(set: String, generatedAt: String, champions: [Champion]) {
        self.set = set
        self.generatedAt = generatedAt
        self.champions = champions
    }

    public func champion(plannerCode: Int) -> Champion? {
        champions.first { $0.plannerCode == plannerCode }
    }

    public var championsByID: [String: Champion] {
        Dictionary(champions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

/// `data/index.json`.
public struct CatalogIndex: Codable, Hashable, Sendable {
    public let sets: [String]
    public let latest: String

    public init(sets: [String], latest: String) {
        self.sets = sets
        self.latest = latest
    }
}

/// A team code matched against a set catalog. Unknown codes keep their slot.
public struct Resolution: Hashable, Sendable {
    public struct Slot: Hashable, Sendable {
        public let code: Int
        public let champion: Champion?
    }

    public let set: String
    public let slots: [Slot]

    public init(code: TeamPlannerCode, catalog: SetCatalog) {
        set = code.set
        slots = code.championCodes.map { Slot(code: $0, champion: catalog.champion(plannerCode: $0)) }
    }

    public var champions: [Champion] { slots.compactMap(\.champion) }
    public var unknown: [Int] { slots.filter { $0.champion == nil }.map(\.code) }

    /// IDs in slot order as stored on `Comp`; unknown codes become placeholders.
    public var championIDs: [String] {
        slots.map { $0.champion?.id ?? Comp.unknownID(plannerCode: $0.code) }
    }

    /// Board slots for previewing a code before it is saved.
    public var compSlots: [CompSlot] {
        zip(slots, championIDs).enumerated().map { CompSlot(index: $0.offset, championID: $0.element.1, champion: $0.element.0.champion) }
    }
}
