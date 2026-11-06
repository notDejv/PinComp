import AppIntents

/// Island button: shows the next comp. Runs in the background; never opens the app.
public struct NextCompIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Next comp"
    public static let isDiscoverable = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        await PinService.shared.next()
        return .result()
    }
}

/// Island button: ends the Live Activity immediately.
public struct UnpinIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Unpin"
    public static let isDiscoverable = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        await PinService.shared.unpin()
        return .result()
    }
}
