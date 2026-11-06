import Foundation
import SwiftData

@Model
public final class Comp {
    public static let maxChampions = TeamPlannerCode.slotCount

    @Attribute(.unique) public var id: UUID
    public var name: String
    public var set: String
    /// Trimmed team code; also the duplicate key.
    public var rawCode: String
    /// Slot order, max 10. Unknown planner codes are stored as `unknownID(plannerCode:)`.
    public var championIDs: [String]
    /// List order = island cycle order.
    public var sortIndex: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        set: String,
        rawCode: String,
        championIDs: [String],
        sortIndex: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.set = set
        self.rawCode = TeamPlannerCode.normalized(rawCode)
        self.championIDs = Array(championIDs.prefix(Self.maxChampions))
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    public static func unknownID(plannerCode: Int) -> String { "?\(plannerCode)" }
}

/// One board slot of a comp; `champion` is nil for codes the catalog doesn't know.
public struct CompSlot: Identifiable, Hashable, Sendable {
    public let index: Int
    public let championID: String
    public let champion: Champion?

    public var id: Int { index }

    public init(index: Int, championID: String, champion: Champion?) {
        self.index = index
        self.championID = championID
        self.champion = champion
    }
}

extension Comp {
    public func slots(in catalog: [String: Champion]) -> [CompSlot] {
        championIDs.enumerated().map { CompSlot(index: $0.offset, championID: $0.element, champion: catalog[$0.element]) }
    }

    /// Highest-cost units first, ties broken by slot order. Unknown units are skipped.
    public func featuredChampions(limit: Int, in catalog: [String: Champion]) -> [Champion] {
        Self.featured(slots(in: catalog), limit: limit)
    }

    public static func featured(_ slots: [CompSlot], limit: Int) -> [Champion] {
        slots
            .compactMap { slot in slot.champion.map { (slot.index, $0) } }
            .sorted { $0.1.cost != $1.1.cost ? $0.1.cost > $1.1.cost : $0.0 < $1.0 }
            .prefix(max(limit, 0))
            .map(\.1)
    }

    /// Default name in the community's style, strongest trait + carry ("Blossom Taric").
    /// Falls back to "<carry> comp" when no catalog traits are known.
    /// Single-unit traits (first breakpoint 1) are skipped: they only repeat a champion's name.
    public static func defaultName(for champions: [Champion], traits: [String: Trait] = [:]) -> String {
        let slots = champions.enumerated().map { CompSlot(index: $0.offset, championID: $0.element.id, champion: $0.element) }
        guard let carry = featured(slots, limit: 1).first else { return "New comp" }
        let trait = ActiveTrait.compute(slots: slots, traits: traits)
            .first { ($0.trait.breakpoints.first ?? 1) > 1 }
        return trait.map { "\($0.trait.name) \(carry.name)" } ?? "\(carry.name) comp"
    }

    /// `base`, or `base 2`, `base 3`, … if `taken` already contains it.
    public static func uniqueName(_ base: String, taken: Set<String>) -> String {
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }
}
