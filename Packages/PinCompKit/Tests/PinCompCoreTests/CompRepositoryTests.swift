import Foundation
import Testing
@testable import PinCompCore

@MainActor
@Suite("CompRepository")
struct CompRepositoryTests {
    let repository = CompRepository.preview(withSamples: false)

    private func add(_ name: String, set: String = "TFTSet18") throws -> Comp {
        try repository.add(name: name, set: set, rawCode: "code-\(name)", championIDs: [])
    }

    @Test func appendsInListOrder() throws {
        _ = try add("A")
        _ = try add("B")
        _ = try add("C")
        #expect(try repository.comps(in: "TFTSet18").map(\.name) == ["A", "B", "C"])
        #expect(try repository.comps(in: "TFTSet18").map(\.sortIndex) == [0, 1, 2])
    }

    @Test func nextWrapsAround() throws {
        let a = try add("A")
        let b = try add("B")
        _ = try add("Old", set: "TFTSet17")
        let afterA = try #require(try repository.comp(after: a.id, in: "TFTSet18"))
        #expect(afterA.comp.id == b.id)
        #expect(afterA.position == 2 && afterA.total == 2)
        let afterB = try #require(try repository.comp(after: b.id, in: "TFTSet18"))
        #expect(afterB.comp.id == a.id)
        #expect(afterB.position == 1)
    }

    @Test func nextAfterMissingStartsAtFirst() throws {
        let a = try add("A")
        _ = try add("B")
        let next = try #require(try repository.comp(after: UUID(), in: "TFTSet18"))
        #expect(next.comp.id == a.id)
    }

    @Test func moveUpdatesSortIndex() throws {
        _ = try add("A")
        _ = try add("B")
        _ = try add("C")
        try repository.move(in: "TFTSet18", fromOffsets: [2], toOffset: 0)
        #expect(try repository.comps(in: "TFTSet18").map(\.name) == ["C", "A", "B"])
    }

    @Test func duplicateLookupUsesTrimmedCode() throws {
        let comp = try repository.add(name: "A", set: "TFTSet18", rawCode: "  \(SampleCatalog.userCode)\n", championIDs: [])
        #expect(comp.rawCode == SampleCatalog.userCode)
        #expect(try repository.comp(rawCode: " \(SampleCatalog.userCode) ")?.id == comp.id)
    }

    @Test func deleteAllClearsEverySet() throws {
        _ = try add("A")
        _ = try add("Old", set: "TFTSet17")
        try repository.deleteAll()
        #expect(try repository.comps(in: "TFTSet18").isEmpty)
        #expect(try repository.comps(in: "TFTSet17").isEmpty)
    }

    @Test func featuredChampionsPreferCostThenSlot() throws {
        let preview = CompRepository.preview()
        let comp = try #require(try preview.comps(in: "TFTSet18").first)
        let featured = comp.featuredChampions(limit: 3, in: SampleCatalog.set18.championsByID)
        #expect(featured.map(\.name) == ["Taric", "Gnar", "Lillia"])
        #expect(comp.name == "Taric comp")
    }

    @Test func defaultNameUsesStrongestTraitAndCarry() {
        let champions = Resolution(
            code: try! TeamPlannerCode(parsing: SampleCatalog.userCode),
            catalog: SampleCatalog.set18
        ).champions
        #expect(Comp.defaultName(for: champions, traits: SampleCatalog.set18.traitsByID) == "Blossom Taric")
        #expect(Comp.defaultName(for: champions) == "Taric comp")
        #expect(Comp.defaultName(for: []) == "New comp")
    }

    @Test func uniqueNameAppendsNumber() {
        #expect(Comp.uniqueName("Blossom Taric", taken: []) == "Blossom Taric")
        #expect(Comp.uniqueName("Blossom Taric", taken: ["Blossom Taric"]) == "Blossom Taric 2")
        #expect(Comp.uniqueName("Blossom Taric", taken: ["Blossom Taric", "Blossom Taric 2"]) == "Blossom Taric 3")
    }
}
