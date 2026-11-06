import AppIntents

/// Lets the app decide what "Next/Previous comp" does (e.g. also cycle the floating window).
/// The handler gets the step: 1 = next, -1 = previous.
/// Unset in the widget process; intents below run in the app process (`LiveActivityIntent`).
@MainActor
public enum NextCompRouter {
    public static var handler: (@MainActor (Int) async -> Void)?
}

/// Shows the next comp. Used by the Live Activity button, the Control Center control, Siri,
/// Shortcuts, Back Tap and the Action button. Runs in the background; never opens the app.
public struct NextCompIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Next comp"
    public static let description = IntentDescription("Shows the next saved comp in the floating window and the Live Activity.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let handler = NextCompRouter.handler {
            await handler(1)
        } else {
            await PinService.shared.next()
        }
        return .result()
    }
}

/// Shows the previous comp. Same triggers as `NextCompIntent` (e.g. triple Back Tap).
public struct PreviousCompIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Previous comp"
    public static let description = IntentDescription("Shows the previous saved comp in the floating window and the Live Activity.")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let handler = NextCompRouter.handler {
            await handler(-1)
        } else {
            await PinService.shared.previous()
        }
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
