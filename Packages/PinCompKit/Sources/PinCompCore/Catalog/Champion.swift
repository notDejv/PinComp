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
    /// Trait IDs, e.g. `DA_18_Blossom`. Empty in catalogs published before traits existed.
    public let traits: [String]

    public init(id: String, name: String, cost: Int, plannerCode: Int, iconURL: URL, traits: [String] = []) {
        self.id = id
        self.name = name
        self.cost = cost
        self.plannerCode = plannerCode
        self.iconURL = iconURL
        self.traits = traits
    }

    enum CodingKeys: String, CodingKey {
        case id, name, cost, plannerCode, traits
        case iconURL = "icon"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cost = try container.decode(Int.self, forKey: .cost)
        plannerCode = try container.decode(Int.self, forKey: .plannerCode)
        iconURL = try container.decode(URL.self, forKey: .iconURL)
        traits = try container.decodeIfPresent([String].self, forKey: .traits) ?? []
    }
}

public struct Trait: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// White glyph on transparent; nil if Community Dragon has none.
    public let iconURL: URL?
    /// Unit counts at which the trait activates, ascending (e.g. `[2, 4, 6]`).
    public let breakpoints: [Int]

    public init(id: String, name: String, iconURL: URL?, breakpoints: [Int]) {
        self.id = id
        self.name = name
        self.iconURL = iconURL
        self.breakpoints = breakpoints
    }

    enum CodingKeys: String, CodingKey {
        case id, name, breakpoints
        case iconURL = "icon"
    }
}

/// `data/<set>/champions.json`.
public struct SetCatalog: Codable, Hashable, Sendable {
    public let set: String
    /// ISO 8601 string; changes only when the published data changes.
    public let generatedAt: String
    public let champions: [Champion]
    public let traits: [Trait]

    public init(set: String, generatedAt: String, champions: [Champion], traits: [Trait] = []) {
        self.set = set
        self.generatedAt = generatedAt
        self.champions = champions
        self.traits = traits
    }

    enum CodingKeys: String, CodingKey {
        case set, generatedAt, champions, traits
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        set = try container.decode(String.self, forKey: .set)
        generatedAt = try container.decode(String.self, forKey: .generatedAt)
        champions = try container.decode([Champion].self, forKey: .champions)
        traits = try container.decodeIfPresent([Trait].self, forKey: .traits) ?? []
    }

    public var traitsByID: [String: Trait] {
        Dictionary(traits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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
