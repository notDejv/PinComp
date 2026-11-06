import ActivityKit
import Foundation
import Observation
import PinCompCore

@MainActor
public protocol PinControlling: AnyObject {
    var pinnedCompID: UUID? { get }
    /// Pins `comp`, ending any running activity first (one pinned comp at a time).
    func pin(_ comp: Comp) async throws
    func unpin() async
    /// Moves to the next current-set comp by `sortIndex`, wrapping around.
    func next() async
    /// Re-syncs position/total after reorder, add or delete; unpins if the pinned comp is gone.
    func compsChanged() async
    /// Reads the system's activities, e.g. after the 8-hour limit ended one silently.
    func refreshState()
}

@MainActor
@Observable
public final class PinService: PinControlling {
    public static let shared = PinService(repository: .shared, cache: .shared)

    public private(set) var pinnedCompID: UUID?

    private let repository: CompRepository
    private let cache: CatalogCache

    public init(repository: CompRepository, cache: CatalogCache) {
        self.repository = repository
        self.cache = cache
        refreshState()
    }

    /// The running activity's state. Activities are read fresh from ActivityKit each time
    /// rather than stored, so they never cross isolation boundaries.
    private var runningState: PinAttributes.ContentState? {
        Activity<PinAttributes>.activities.first(where: Self.isRunning)?.content.state
    }

    private nonisolated static func isRunning(_ activity: Activity<PinAttributes>) -> Bool {
        activity.activityState == .active || activity.activityState == .stale
    }

    public func refreshState() {
        pinnedCompID = runningState?.compID
    }

    public func pin(_ comp: Comp) async throws {
        await endAll()
        let (position, total) = (try? repository.position(of: comp.id, in: comp.set)) ?? (1, 1)
        let state = PinAttributes.ContentState(compID: comp.id, position: position, total: total)
        _ = try Activity.request(
            attributes: PinAttributes(),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
        pinnedCompID = comp.id
    }

    public func unpin() async {
        await endAll()
        pinnedCompID = nil
    }

    public func next() async {
        guard let current = runningState?.compID else { return refreshState() }
        guard let set = currentSet(fallbackCompID: current),
              let next = try? repository.comp(after: current, in: set)
        else { return }
        await update(compID: next.comp.id, position: next.position, total: next.total)
    }

    public func compsChanged() async {
        guard let id = runningState?.compID else { return refreshState() }
        guard let set = currentSet(fallbackCompID: id),
              let place = try? repository.position(of: id, in: set)
        else { return await unpin() }
        await update(compID: id, position: place.position, total: place.total)
    }

    /// The published latest set; before the catalog exists, the pinned comp's own set.
    private func currentSet(fallbackCompID: UUID) -> String? {
        cache.loadIndex()?.latest ?? (try? repository.comp(id: fallbackCompID))?.set
    }

    private func update(compID: UUID, position: Int, total: Int) async {
        let state = PinAttributes.ContentState(compID: compID, position: position, total: total)
        for activity in Activity<PinAttributes>.activities where Self.isRunning(activity) && activity.content.state != state {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        pinnedCompID = compID
    }

    private func endAll() async {
        for activity in Activity<PinAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// Records calls instead of touching ActivityKit. For previews and tests.
@MainActor
@Observable
public final class FakePinService: PinControlling {
    public private(set) var pinnedCompID: UUID?
    public private(set) var calls: [String] = []

    public init(pinnedCompID: UUID? = nil) {
        self.pinnedCompID = pinnedCompID
    }

    public func pin(_ comp: Comp) async throws {
        calls.append("pin")
        pinnedCompID = comp.id
    }

    public func unpin() async {
        calls.append("unpin")
        pinnedCompID = nil
    }

    public func next() async { calls.append("next") }
    public func compsChanged() async { calls.append("compsChanged") }
    public func refreshState() {}
}
