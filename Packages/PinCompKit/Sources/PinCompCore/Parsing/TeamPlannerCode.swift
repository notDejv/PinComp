import Foundation

/// A TFT Team Planner code, e.g. `0242043A4004123E942A43C430401000TFTSet18`.
///
/// Format (version `02`): `"02"` + 10 × 3 hex chars (one per slot, `000` = empty) + `"TFTSet<N>"`.
public struct TeamPlannerCode: Equatable, Hashable, Sendable {
    public static let supportedVersion = "02"
    public static let slotCount = 10
    static let setPrefix = "TFTSet"

    public let version: String
    /// Set identifier, e.g. `TFTSet18`.
    public let set: String
    /// Planner codes of the non-empty slots, in slot order.
    public let championCodes: [Int]

    public enum ParseError: Error, Equatable, Sendable {
        case missingSetSuffix
        case unsupportedVersion(String)
        case badLength(Int)
        case invalidHex(String)
    }

    public init(parsing raw: String) throws(ParseError) {
        let trimmed = Self.normalized(raw)
        guard let suffix = trimmed.range(of: Self.setPrefix, options: .backwards),
              suffix.upperBound < trimmed.endIndex
        else { throw .missingSetSuffix }

        let body = trimmed[..<suffix.lowerBound]
        let version = String(body.prefix(Self.supportedVersion.count))
        guard version == Self.supportedVersion else { throw .unsupportedVersion(version) }

        let slots = Array(body.dropFirst(Self.supportedVersion.count))
        guard slots.count == Self.slotCount * 3 else { throw .badLength(slots.count) }

        var codes: [Int] = []
        for start in stride(from: 0, to: slots.count, by: 3) {
            let chunk = String(slots[start..<start + 3])
            guard chunk.allSatisfy(\.isHexDigit), let code = Int(chunk, radix: 16) else {
                throw .invalidHex(chunk)
            }
            if code != 0 { codes.append(code) }
        }

        self.version = version
        self.set = String(trimmed[suffix.lowerBound...])
        self.championCodes = codes
    }

    /// The form stored and compared for duplicates.
    public static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Helpers for `TFTSet<N>` identifiers.
public enum TFTSet {
    /// `TFTSet18` → 18. Returns nil for anything without a leading set number.
    public static func number(of set: String) -> Int? {
        guard set.hasPrefix(TeamPlannerCode.setPrefix) else { return nil }
        let digits = set.dropFirst(TeamPlannerCode.setPrefix.count).prefix(while: \.isNumber)
        return Int(digits)
    }

    /// `TFTSet18` → "Set 18".
    public static func displayName(of set: String) -> String {
        number(of: set).map { "Set \($0)" } ?? set
    }

    public enum Relation: Equatable, Sendable {
        case current, older, newer
    }

    /// How `set` relates to the latest published set.
    public static func relation(of set: String, toLatest latest: String) -> Relation {
        if set == latest { return .current }
        guard let n = number(of: set), let l = number(of: latest) else { return .newer }
        if n < l { return .older }
        if n > l { return .newer }
        // Same number, different suffix (e.g. a variant mode): not published.
        return .newer
    }
}
