import Foundation

/// A trait with enough units on the board to be active.
public struct ActiveTrait: Hashable, Sendable, Identifiable {
    public let trait: Trait
    /// Distinct champions on the board with this trait.
    public let count: Int
    /// 1-based index of the highest breakpoint reached (1 = first breakpoint).
    public let tier: Int

    public var id: String { trait.id }
    public var isMaxTier: Bool { tier == trait.breakpoints.count }

    /// Active traits of a board, strongest first: higher tier, then more units, then name.
    /// Each champion counts once, as in game.
    public static func compute(slots: [CompSlot], traits: [String: Trait]) -> [ActiveTrait] {
        var seen = Set<String>()
        var counts: [String: Int] = [:]
        for champion in slots.compactMap(\.champion) where seen.insert(champion.id).inserted {
            for traitID in champion.traits { counts[traitID, default: 0] += 1 }
        }
        return counts.compactMap { traitID, count -> ActiveTrait? in
            guard let trait = traits[traitID] else { return nil }
            let tier = trait.breakpoints.filter { $0 <= count }.count
            return tier > 0 ? ActiveTrait(trait: trait, count: count, tier: tier) : nil
        }
        .sorted {
            if $0.tier != $1.tier { return $0.tier > $1.tier }
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.trait.name < $1.trait.name
        }
    }
}
