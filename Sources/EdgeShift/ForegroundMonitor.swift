import AppKit
import CoreGraphics

final class ForegroundMonitor {
    private let ownPID: Int32
    private let applicationProvider: () -> ForegroundApplication?
    private let windowsProvider: (Int32) -> WindowQuery
    private let isRunning: (Int32) -> Bool
    private var lastExternalContext = ForegroundContext.unavailable

    init(ownPID: Int32 = ProcessInfo.processInfo.processIdentifier,
         applicationProvider: (() -> ForegroundApplication?)? = nil,
         windowsProvider: ((Int32) -> WindowQuery)? = nil,
         isRunning: ((Int32) -> Bool)? = nil) {
        self.ownPID = ownPID
        self.applicationProvider = applicationProvider ?? Self.currentApplication
        self.windowsProvider = windowsProvider ?? Self.readWindows
        self.isRunning = isRunning ?? { NSRunningApplication(processIdentifier: $0)?.isTerminated == false }
    }

    func snapshot() -> ForegroundContext {
        guard let application = applicationProvider() else { return .unavailable }
        // A menu or settings window must not replace the protected app with
        // EdgeShift, or hide its full-screen state when we move to another Space.
        if application.processID == ownPID {
            if let app = lastExternalContext.application,
               !isRunning(app.processID) {
                lastExternalContext = .unavailable
            }
            return lastExternalContext
        }
        lastExternalContext = ForegroundContext(application: application, windows: windowsProvider(application.processID))
        return lastExternalContext
    }

    private static func currentApplication() -> ForegroundApplication? {
        guard let running = NSWorkspace.shared.frontmostApplication else { return nil }
        return ForegroundApplication(processID: running.processIdentifier, bundleID: running.bundleIdentifier,
                                     name: running.localizedName ?? running.bundleIdentifier ?? "当前应用")
    }

    private static func readWindows(for pid: Int32) -> WindowQuery {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return .unavailable }
        var windows: [WindowMetadata] = []
        for item in list {
            guard let owner = item[kCGWindowOwnerPID as String] as? NSNumber, owner.int32Value == pid else { continue }
            guard let dictionary = item[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                  let alpha = item[kCGWindowAlpha as String] as? NSNumber else { return .unavailable }
            windows.append(WindowMetadata(ownerPID: pid, bounds: bounds, alpha: alpha.doubleValue))
        }
        return .available(windows)
    }
}
