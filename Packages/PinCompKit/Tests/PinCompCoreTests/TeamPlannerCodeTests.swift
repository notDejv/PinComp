import Testing
@testable import PinCompCore

@Suite("TeamPlannerCode")
struct TeamPlannerCodeTests {
    @Test func parsesUserCode() throws {
        let code = try TeamPlannerCode(parsing: "0242043A4004123E942A43C430401000TFTSet18")
        #expect(code.version == "02")
        #expect(code.set == "TFTSet18")
        #expect(code.championCodes == [1056, 1082, 1024, 1042, 1001, 1066, 1084, 1072, 1025])
    }

    @Test func acceptsSurroundingWhitespace() throws {
        let code = try TeamPlannerCode(parsing: "  \n\t0242043A4004123E942A43C430401000TFTSet18 \n")
        #expect(code.set == "TFTSet18")
        #expect(code.championCodes.count == 9)
    }

    @Test func acceptsLowercaseHex() throws {
        let code = try TeamPlannerCode(parsing: "0242043a4004123e942a43c430401000TFTSet18")
        #expect(code.championCodes.first == 1056)
    }

    @Test func emptyBoard() throws {
        let code = try TeamPlannerCode(parsing: "02" + String(repeating: "0", count: 30) + "TFTSet18")
        #expect(code.championCodes.isEmpty)
    }

    @Test(arguments: [
        ("", TeamPlannerCode.ParseError.missingSetSuffix),
        ("0242043A4004123E942A43C430401000", .missingSetSuffix),
        ("0242043A4004123E942A43C430401000TFTSet", .missingSetSuffix),
        ("hello world", .missingSetSuffix),
        ("0342043A4004123E942A43C430401000TFTSet18", .unsupportedVersion("03")),
        ("TFTSet18", .unsupportedVersion("")),
        ("0242043A4004123E942A43C43040100TFTSet18", .badLength(29)),
        ("0242043A4004123E942A43C4304010000TFTSet18", .badLength(31)),
        ("02ZZ043A4004123E942A43C430401000TFTSet18", .invalidHex("ZZ0")),
        ("02+1A43A4004123E942A43C430401000TFTSet18", .invalidHex("+1A")),
    ])
    func rejectsInvalid(raw: String, expected: TeamPlannerCode.ParseError) {
        #expect(throws: expected) { try TeamPlannerCode(parsing: raw) }
    }

    @Test func normalizedTrims() {
        #expect(TeamPlannerCode.normalized(" abc\n") == "abc")
    }
}

@Suite("TFTSet")
struct TFTSetTests {
    @Test func number() {
        #expect(TFTSet.number(of: "TFTSet18") == 18)
        #expect(TFTSet.number(of: "TFTSet4_Stage2") == 4)
        #expect(TFTSet.number(of: "Set18") == nil)
    }

    @Test func relation() {
        #expect(TFTSet.relation(of: "TFTSet18", toLatest: "TFTSet18") == .current)
        #expect(TFTSet.relation(of: "TFTSet17", toLatest: "TFTSet18") == .older)
        #expect(TFTSet.relation(of: "TFTSet19", toLatest: "TFTSet18") == .newer)
        #expect(TFTSet.relation(of: "TFTSet9", toLatest: "TFTSet18") == .older)
    }
}
