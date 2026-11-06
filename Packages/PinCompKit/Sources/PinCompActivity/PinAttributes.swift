import ActivityKit
import Foundation
import PinCompCore

/// Live Activity for the pinned comp.
///
/// The state carries everything the widget draws (a few hundred bytes, far under the ~4 KB limit),
/// so the widget never opens the SwiftData store; it only reads cached icon files.
public struct PinAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var compID: UUID
        public var name: String
        public var set: String
        /// Slot order; unknown units use `Comp.unknownID(plannerCode:)`.
        public var championIDs: [String]
        /// 1-based position in the current set's list.
        public var position: Int
        public var total: Int

        public init(compID: UUID, name: String, set: String, championIDs: [String], position: Int, total: Int) {
            self.compID = compID
            self.name = name
            self.set = set
            self.championIDs = championIDs
            self.position = position
            self.total = total
        }

        public init(comp: Comp, position: Int, total: Int) {
            self.init(
                compID: comp.id,
                name: comp.name,
                set: comp.set,
                championIDs: comp.championIDs,
                position: position,
                total: total
            )
        }
    }

    public init() {}
}

/// Deep link to a comp's detail screen: `pincomp://comp/<uuid>`.
public enum PinLink {
    public static let scheme = "pincomp"

    public static func url(for compID: UUID) -> URL {
        URL(string: "\(scheme)://comp/\(compID.uuidString)")!
    }

    public static func compID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host() == "comp" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
