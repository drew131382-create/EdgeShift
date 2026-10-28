import Foundation
import CoreGraphics

// Standalone checks for Command Line Tools installations without XCTest.
@main struct PauseChecks {
    static func main() {
        let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let secondary = CGRect(x: -1512, y: -200, width: 1512, height: 982)
        let app = ForegroundApplication(processID: 42, bundleID: "org.example.game", name: "Game")
        func context(_ bounds: CGRect, alpha: Double = 1, pid: Int32 = 42) -> ForegroundContext {
            ForegroundContext(application: app, windows: .available([WindowMetadata(ownerPID: pid, bounds: bounds, alpha: alpha)]))
        }
        let screens = [main, secondary]
        precondition(PausePolicy.reason(settings: PauseSettings(), context: context(main), displays: screens) == .fullscreen("Game"))
        precondition(PausePolicy.reason(settings: PauseSettings(), context: context(secondary), displays: screens) == .fullscreen("Game"))
        precondition(PausePolicy.coversDisplay(main.union(secondary), display: main))
        precondition(PausePolicy.coversDisplay(main.insetBy(dx: 2, dy: 2), display: main))
        precondition(!PausePolicy.coversDisplay(main.insetBy(dx: 2.01, dy: 0), display: main))
        precondition(!PausePolicy.coversDisplay(CGRect(x: 0, y: 25, width: 1920, height: 1000), display: main))
        precondition(!PausePolicy.coversDisplay(.zero, display: main))
        precondition(!PausePolicy.coversDisplay(CGRect(x: CGFloat.infinity, y: 0, width: 100, height: 100), display: main))
        precondition(PausePolicy.reason(settings: PauseSettings(), context: context(main, alpha: 0), displays: screens) == nil)
        precondition(PausePolicy.reason(settings: PauseSettings(), context: context(main, pid: 99), displays: screens) == nil)
        precondition(PausePolicy.reason(settings: PauseSettings(), context: .unavailable, displays: screens) == .detectionUnavailable)
        let failed = ForegroundContext(application: app, windows: .unavailable)
        precondition(PausePolicy.reason(settings: PauseSettings(), context: failed, displays: screens) == .detectionUnavailable)
        precondition(PausePolicy.reason(settings: PauseSettings(), context: ForegroundContext(application: app, windows: .available([])), displays: screens) == nil)

        let suite = "org.edgeshift.pausechecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(PauseSettings.load(from: defaults, ownBundleID: "com.edgeshift.app") == PauseSettings())
        var settings = PauseSettings()
        settings.whenFullscreen = false
        precondition(PausePolicy.reason(settings: settings, context: failed, displays: screens) == nil)
        precondition(PausePolicy.reason(settings: settings, context: context(main), displays: screens) == nil)
        precondition(settings.add(PausedApplication(bundleID: app.bundleID!, name: "Previous name"), ownBundleID: "com.edgeshift.app"))
        precondition(!settings.add(PausedApplication(bundleID: app.bundleID!, name: "Duplicate"), ownBundleID: "com.edgeshift.app"))
        precondition(!settings.add(PausedApplication(bundleID: "com.edgeshift.app", name: "EdgeShift"), ownBundleID: "com.edgeshift.app"))
        precondition(!settings.add(PausedApplication(bundleID: " ", name: "Invalid"), ownBundleID: "com.edgeshift.app"))
        precondition(PausePolicy.reason(settings: settings, context: failed, displays: screens) == .excludedApplication("Game"))
        let otherApp = ForegroundApplication(processID: 99, bundleID: "org.example.editor", name: "Editor")
        precondition(PausePolicy.reason(settings: settings, context: ForegroundContext(application: otherApp, windows: .available([])), displays: screens) == nil)
        settings.save(to: defaults)
        precondition(PauseSettings.load(from: defaults, ownBundleID: "com.edgeshift.app") == settings)
        settings.remove(bundleID: app.bundleID!)
        precondition(settings.applications.isEmpty)
        defaults.set(Data("invalid".utf8), forKey: PauseSettings.defaultsKey)
        precondition(PauseSettings.load(from: defaults, ownBundleID: "com.edgeshift.app") == PauseSettings())

        var current: ForegroundApplication? = app
        var query = context(main).windows
        var running = true
        let monitor = ForegroundMonitor(ownPID: 7, applicationProvider: { current }, windowsProvider: { _ in query }, isRunning: { _ in running })
        let external = monitor.snapshot()
        current = ForegroundApplication(processID: 7, bundleID: "com.edgeshift.app", name: "EdgeShift")
        query = .available([])
        precondition(monitor.snapshot() == external)
        running = false
        precondition(monitor.snapshot() == .unavailable)
        current = otherApp
        precondition(monitor.snapshot().application == otherApp)

        var session = AutomaticPushSession()
        precondition(session.update(edge: .right, time: 1, duration: 0.3, allowed: true) == 0)
        precondition(session.update(edge: .right, time: 1.1, duration: 0.3, allowed: true) > 0)
        let ticket = session.generation
        session.invalidate()
        precondition(!session.hasPush && !session.permitsQueuedMove(ticket: ticket, allowed: true))
        precondition(session.update(edge: .right, time: 1.2, duration: 0.3, allowed: true) == 0)
        precondition(session.update(edge: .right, time: 1.3, duration: 0.3, allowed: false) == 0)
        precondition(!session.hasPush)
        precondition(session.update(edge: .right, time: 1.4, duration: 0.3, allowed: true) == 0)
        for index in 1...4 { _ = session.update(edge: .right, time: 1.4 + Double(index) * 0.1, duration: 0.3, allowed: true) }
        precondition(session.update(edge: .right, time: 1.81, duration: 0.3, allowed: true) == 1)
        precondition(!session.permitsQueuedMove(ticket: session.generation, allowed: false))
        precondition(session.permitsQueuedMove(ticket: session.generation, allowed: true))
        print("Automatic pause checks passed: fullscreen geometry, foreground apps, persistence, own UI, progress reset and queued cancellation.")
    }
}
