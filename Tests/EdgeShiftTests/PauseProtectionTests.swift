import XCTest
@testable import EdgeShift

final class PauseProtectionTests: XCTestCase {
    private let ownID = "com.edgeshift.app"
    private let app = ForegroundApplication(processID: 42, bundleID: "org.example.game", name: "Game")
    private let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let secondary = CGRect(x: -1470, y: -180, width: 1470, height: 956)

    private func context(bounds: CGRect, alpha: Double = 1, pid: Int32 = 42) -> ForegroundContext {
        ForegroundContext(application: app, windows: .available([
            WindowMetadata(ownerPID: pid, bounds: bounds, alpha: alpha)
        ]))
    }

    func testFullscreenOnMainAndOffsetSecondaryInLogicalCoordinates() {
        let screens = [main, secondary]
        XCTAssertEqual(PausePolicy.reason(settings: PauseSettings(), context: context(bounds: main), displays: screens), .fullscreen("Game"))
        XCTAssertEqual(PausePolicy.reason(settings: PauseSettings(), context: context(bounds: secondary), displays: screens), .fullscreen("Game"))
        // A larger borderless window spanning displays still covers a full screen.
        XCTAssertTrue(PausePolicy.coversDisplay(main.union(secondary), display: secondary))
        let scaled = CGRect(x: 1920, y: 100, width: 1512, height: 982)
        XCTAssertTrue(PausePolicy.coversDisplay(scaled, display: scaled))
        XCTAssertFalse(PausePolicy.coversDisplay(CGRect(x: 3840, y: 200, width: 3024, height: 1964), display: scaled))
    }

    func testFullscreenToleranceAndOrdinaryMaximizedWindow() {
        XCTAssertTrue(PausePolicy.coversDisplay(main.insetBy(dx: 2, dy: 2), display: main))
        XCTAssertFalse(PausePolicy.coversDisplay(main.insetBy(dx: 2.01, dy: 0), display: main))
        XCTAssertFalse(PausePolicy.coversDisplay(CGRect(x: 0, y: 25, width: 1920, height: 1000), display: main))
        XCTAssertFalse(PausePolicy.coversDisplay(.zero, display: main))
        XCTAssertFalse(PausePolicy.coversDisplay(CGRect(x: CGFloat.infinity, y: 0, width: 1920, height: 1080), display: main))
    }

    func testBackgroundAndTransparentWindowsDoNotPause() {
        XCTAssertNil(PausePolicy.reason(settings: PauseSettings(), context: context(bounds: main, pid: 99), displays: [main]))
        XCTAssertNil(PausePolicy.reason(settings: PauseSettings(), context: context(bounds: main, alpha: 0), displays: [main]))
        XCTAssertNil(PausePolicy.reason(settings: PauseSettings(), context: ForegroundContext(application: app, windows: .available([])), displays: [main]))
    }

    func testQueryFailureAndDisabledFullscreenProtection() {
        let unavailable = ForegroundContext(application: app, windows: .unavailable)
        XCTAssertEqual(PausePolicy.reason(settings: PauseSettings(), context: unavailable, displays: [main]), .detectionUnavailable)
        XCTAssertEqual(PausePolicy.reason(settings: PauseSettings(), context: .unavailable, displays: [main]), .detectionUnavailable)
        var settings = PauseSettings()
        settings.whenFullscreen = false
        XCTAssertNil(PausePolicy.reason(settings: settings, context: unavailable, displays: [main]))
        XCTAssertNil(PausePolicy.reason(settings: settings, context: context(bounds: main), displays: [main]))
    }

    func testApplicationListMatchesBundleIDAndOnlyForegroundApp() {
        var settings = PauseSettings()
        settings.whenFullscreen = false
        XCTAssertTrue(settings.add(PausedApplication(bundleID: "org.example.game", name: "Old name"), ownBundleID: ownID))
        XCTAssertEqual(PausePolicy.reason(settings: settings, context: context(bounds: .zero), displays: [main]), .excludedApplication("Game"))
        let other = ForegroundApplication(processID: 99, bundleID: "org.example.editor", name: "Editor")
        let background = ForegroundContext(application: other, windows: .available([WindowMetadata(ownerPID: 42, bounds: main, alpha: 1)]))
        XCTAssertNil(PausePolicy.reason(settings: settings, context: background, displays: [main]))
        settings.whenFullscreen = true
        XCTAssertEqual(PausePolicy.reason(settings: settings, context: ForegroundContext(application: app, windows: .unavailable), displays: [main]), .excludedApplication("Game"))
        settings.remove(bundleID: "org.example.game")
        XCTAssertTrue(settings.applications.isEmpty)
    }

    func testSettingsPersistenceDeduplicationAndSelfExclusion() {
        let suite = "org.edgeshift.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(PauseSettings.load(from: defaults, ownBundleID: ownID), PauseSettings())
        var settings = PauseSettings()
        settings.whenFullscreen = false
        XCTAssertTrue(settings.add(PausedApplication(bundleID: app.bundleID!, name: app.name), ownBundleID: ownID))
        XCTAssertFalse(settings.add(PausedApplication(bundleID: app.bundleID!, name: "Duplicate"), ownBundleID: ownID))
        XCTAssertFalse(settings.add(PausedApplication(bundleID: ownID, name: "EdgeShift"), ownBundleID: ownID))
        XCTAssertFalse(settings.add(PausedApplication(bundleID: " ", name: "Invalid"), ownBundleID: ownID))
        settings.save(to: defaults)
        XCTAssertEqual(PauseSettings.load(from: defaults, ownBundleID: ownID), settings)
        defaults.set(Data("invalid".utf8), forKey: PauseSettings.defaultsKey)
        XCTAssertEqual(PauseSettings.load(from: defaults, ownBundleID: ownID), PauseSettings())
    }

    func testOpeningOwnUIRetainsExternalFullscreenContext() {
        var current: ForegroundApplication? = app
        var windows = WindowQuery.available([WindowMetadata(ownerPID: 42, bounds: main, alpha: 1)])
        var running = true
        let monitor = ForegroundMonitor(ownPID: 7, applicationProvider: { current }, windowsProvider: { _ in windows }, isRunning: { _ in running })
        let external = monitor.snapshot()
        current = ForegroundApplication(processID: 7, bundleID: ownID, name: "EdgeShift")
        windows = .available([])
        XCTAssertEqual(monitor.snapshot(), external)
        running = false
        XCTAssertEqual(monitor.snapshot(), .unavailable)
        current = ForegroundApplication(processID: 99, bundleID: "org.example.editor", name: "Editor")
        XCTAssertEqual(monitor.snapshot().application?.processID, 99)
    }

    func testPauseAndContextChangeDiscardProgressAndQueuedMoves() {
        var session = AutomaticPushSession()
        XCTAssertEqual(session.update(edge: .left, time: 10, duration: 0.3, allowed: true), 0)
        XCTAssertGreaterThan(session.update(edge: .left, time: 10.1, duration: 0.3, allowed: true), 0)
        let ticket = session.generation
        session.invalidate() // app/Space/settings/protection changed
        XCTAssertFalse(session.hasPush)
        XCTAssertFalse(session.permitsQueuedMove(ticket: ticket, allowed: true))
        XCTAssertEqual(session.update(edge: .left, time: 10.2, duration: 0.3, allowed: true), 0)
        XCTAssertEqual(session.update(edge: .left, time: 10.3, duration: 0.3, allowed: false), 0)
        XCTAssertFalse(session.hasPush)
        XCTAssertEqual(session.update(edge: .left, time: 10.4, duration: 0.3, allowed: true), 0)
        XCTAssertFalse(session.permitsQueuedMove(ticket: session.generation, allowed: false))
        XCTAssertTrue(session.permitsQueuedMove(ticket: session.generation, allowed: true))
        for index in 1...4 { _ = session.update(edge: .left, time: 10.4 + Double(index) * 0.1, duration: 0.3, allowed: true) }
        XCTAssertEqual(session.update(edge: .left, time: 10.81, duration: 0.3, allowed: true), 1)
    }
}
