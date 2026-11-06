import Foundation
import SwiftData

/// SwiftData access shared by the app, the widget and the intents.
@MainActor
public final class CompRepository {
    public static let shared: CompRepository = {
        do {
            return CompRepository(container: try makeContainer())
        } catch {
            fatalError("Cannot open comp store: \(error)")
        }
    }()

    public let container: ModelContainer
    public var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    public static var storeURL: URL {
        AppGroup.containerURL
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
            .appending(path: "PinComp.store")
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            let url = storeURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            configuration = ModelConfiguration(url: url)
        }
        return try ModelContainer(for: Comp.self, configurations: configuration)
    }

    // MARK: Reading

    /// Comps of one set in list order.
    public func comps(in set: String) throws -> [Comp] {
        let descriptor = FetchDescriptor<Comp>(
            predicate: #Predicate { $0.set == set },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    public func comp(id: UUID) throws -> Comp? {
        var descriptor = FetchDescriptor<Comp>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// The saved comp with the same (trimmed) code, from any set.
    public func comp(rawCode: String) throws -> Comp? {
        let code = TeamPlannerCode.normalized(rawCode)
        var descriptor = FetchDescriptor<Comp>(predicate: #Predicate { $0.rawCode == code })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// 1-based position of a comp within its set, and the set's comp count.
    public func position(of id: UUID, in set: String) throws -> (position: Int, total: Int)? {
        let comps = try comps(in: set)
        guard let index = comps.firstIndex(where: { $0.id == id }) else { return nil }
        return (index + 1, comps.count)
    }

    /// The comp after `id` by `sortIndex`, wrapping around. Falls back to the first comp if `id` is gone.
    public func comp(after id: UUID, in set: String) throws -> (comp: Comp, position: Int, total: Int)? {
        let comps = try comps(in: set)
        guard !comps.isEmpty else { return nil }
        let next = comps.firstIndex(where: { $0.id == id }).map { ($0 + 1) % comps.count } ?? 0
        return (comps[next], next + 1, comps.count)
    }

    // MARK: Writing

    @discardableResult
    public func add(name: String, set: String, rawCode: String, championIDs: [String]) throws -> Comp {
        let last = try comps(in: set).last?.sortIndex ?? -1
        let comp = Comp(name: name, set: set, rawCode: rawCode, championIDs: championIDs, sortIndex: last + 1)
        context.insert(comp)
        try context.save()
        return comp
    }

    public func delete(_ comp: Comp) throws {
        context.delete(comp)
        try context.save()
    }

    /// `List.onMove` semantics within one set's ordered comps.
    public func move(in set: String, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let current = try comps(in: set)
        let moving = source.map { current[$0] }
        var comps = current.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.count(in: 0..<destination)
        comps.insert(contentsOf: moving, at: min(max(insertAt, 0), comps.count))
        for (index, comp) in comps.enumerated() where comp.sortIndex != index {
            comp.sortIndex = index
        }
        try context.save()
    }

    /// Deletes every comp of every set.
    public func deleteAll() throws {
        try context.delete(model: Comp.self)
        try context.save()
    }

    public func save() throws {
        try context.save()
    }
}
