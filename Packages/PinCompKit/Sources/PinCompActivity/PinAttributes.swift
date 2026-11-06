import ActivityKit
import Foundation

/// Live Activity for the pinned comp. The state is tiny; the widget looks the comp up in the shared store.
public struct PinAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var compID: UUID
        /// 1-based position in the current set's list.
        public var position: Int
        public var total: Int

        public init(compID: UUID, position: Int, total: Int) {
            self.compID = compID
            self.position = position
            self.total = total
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
