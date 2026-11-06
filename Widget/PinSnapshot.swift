import Foundation
import PinCompActivity
import PinCompCore

/// What the island shows for one content state.
///
/// Built only from the content state and the App Group catalog cache (JSON + icon files).
/// The widget deliberately doesn't open the SwiftData store.
struct PinSnapshot {
    let compID: UUID
    let name: String
    let set: String
    let slots: [CompSlot]
    let position: Int
    let total: Int

    var canCycle: Bool { total > 1 }
    var positionText: String { "\(position)/\(total)" }

    func featured(_ limit: Int) -> [Champion] {
        Comp.featured(slots, limit: limit)
    }

    /// Featured units as slots, for a one-row board.
    func featuredSlots(_ limit: Int) -> [CompSlot] {
        featured(limit).enumerated().map { CompSlot(index: $0.offset, championID: $0.element.id, champion: $0.element) }
    }

    init(_ state: PinAttributes.ContentState, catalog: [String: Champion]) {
        compID = state.compID
        name = state.name
        set = state.set
        slots = state.championIDs.enumerated().map {
            CompSlot(index: $0.offset, championID: $0.element, champion: catalog[$0.element])
        }
        position = state.position
        total = state.total
    }

    static func load(_ state: PinAttributes.ContentState) -> PinSnapshot {
        let catalog = state.set == SampleCatalog.set18.set && state.compID == previewID
            ? SampleCatalog.set18
            : CatalogCache.shared.loadCatalog(set: state.set)
        return PinSnapshot(state, catalog: catalog?.championsByID ?? [:])
    }

    // MARK: Previews

    static let previewID = UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE")!

    static func previewState(position: Int, total: Int) -> PinAttributes.ContentState {
        let code = try! TeamPlannerCode(parsing: SampleCatalog.userCode)
        let resolution = Resolution(code: code, catalog: SampleCatalog.set18)
        return PinAttributes.ContentState(
            compID: previewID,
            name: Comp.defaultName(for: resolution.champions),
            set: code.set,
            championIDs: resolution.championIDs,
            position: position,
            total: total
        )
    }
}
