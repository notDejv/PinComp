import Foundation
import PinCompActivity
import PinCompCore
import SwiftData

/// What the island shows for one content state, read from the shared App Group store and catalog cache.
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

    @MainActor
    static func load(_ state: PinAttributes.ContentState) -> PinSnapshot? {
        if state.compID == previewID { return preview(state) }
        guard let container = WidgetStore.container else { return nil }
        // A fresh context per render so changes saved by the app are always visible.
        let context = ModelContext(container)
        let id = state.compID
        var descriptor = FetchDescriptor<Comp>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let comp = try? context.fetch(descriptor).first else { return nil }
        let champions = CatalogCache.shared.loadCatalog(set: comp.set)?.championsByID ?? [:]
        return PinSnapshot(
            compID: comp.id,
            name: comp.name,
            set: comp.set,
            slots: comp.slots(in: champions),
            position: state.position,
            total: state.total
        )
    }

    // MARK: Previews

    static let previewID = UUID(uuidString: "00000000-0000-0000-0000-00000000C0DE")!

    static func preview(_ state: PinAttributes.ContentState) -> PinSnapshot {
        let code = try! TeamPlannerCode(parsing: SampleCatalog.userCode)
        let resolution = Resolution(code: code, catalog: SampleCatalog.set18)
        return PinSnapshot(
            compID: previewID,
            name: Comp.defaultName(for: resolution.champions),
            set: code.set,
            slots: resolution.compSlots,
            position: state.position,
            total: state.total
        )
    }
}

@MainActor
enum WidgetStore {
    static let container: ModelContainer? = try? CompRepository.makeContainer()
}
