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
    /// Moves to the previous current-set comp, wrapping around.
    func previous() async
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
        let state = PinAttributes.ContentState(comp: comp, position: position, total: total)
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
        await step(by: 1)
    }

    public func previous() async {
        await step(by: -1)
    }

    private func step(by offset: Int) async {
        guard let running = runningState else { return refreshState() }
        guard let next = try? repository.comp(after: running.compID, in: currentSet(running), offset: offset) else { return }
        await update(PinAttributes.ContentState(comp: next.comp, position: next.position, total: next.total))
    }

    public func compsChanged() async {
        guard let running = runningState else { return refreshState() }
        let comps = (try? repository.comps(in: currentSet(running))) ?? []
        guard let index = comps.firstIndex(where: { $0.id == running.compID }) else { return await unpin() }
        // Also picks up renames and replaced codes.
        await update(PinAttributes.ContentState(comp: comps[index], position: index + 1, total: comps.count))
    }

    /// The published latest set; before the catalog exists, the pinned comp's own set.
    private func currentSet(_ running: PinAttributes.ContentState) -> String {
        cache.loadIndex()?.latest ?? running.set
    }

    private func update(_ state: PinAttributes.ContentState) async {
        for activity in Activity<PinAttributes>.activities where Self.isRunning(activity) && activity.content.state != state {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        pinnedCompID = state.compID
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
    public func previous() async { calls.append("previous") }
    public func compsChanged() async { calls.append("compsChanged") }
    public func refreshState() {}
}
