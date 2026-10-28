import Foundation
import CoreGraphics

struct PausedApplication: Codable, Equatable, Identifiable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

struct PauseSettings: Codable, Equatable {
    static let defaultsKey = "automaticPauseSettings"
    var whenFullscreen = true
    private(set) var applications: [PausedApplication] = []

    static func load(from defaults: UserDefaults, ownBundleID: String) -> PauseSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(PauseSettings.self, from: data) else { return PauseSettings() }
        var settings = PauseSettings()
        settings.whenFullscreen = saved.whenFullscreen
        for app in saved.applications { _ = settings.add(app, ownBundleID: ownBundleID) }
        return settings
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.defaultsKey) }
    }

    @discardableResult
    mutating func add(_ app: PausedApplication, ownBundleID: String) -> Bool {
        guard !app.bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              app.bundleID != ownBundleID,
              !applications.contains(where: { $0.bundleID == app.bundleID }) else { return false }
        applications.append(app)
        applications.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return true
    }

    mutating func remove(bundleID: String) {
        applications.removeAll { $0.bundleID == bundleID }
    }
}

struct ForegroundApplication: Equatable {
    let processID: Int32
    let bundleID: String?
    let name: String
}

struct WindowMetadata: Equatable {
    let ownerPID: Int32
    let bounds: CGRect
    let alpha: Double
}

enum WindowQuery: Equatable {
    case available([WindowMetadata])
    case unavailable
}

struct ForegroundContext: Equatable {
    let application: ForegroundApplication?
    let windows: WindowQuery
    static let unavailable = ForegroundContext(application: nil, windows: .unavailable)
}

enum PauseReason: Equatable {
    case fullscreen(String)
    case excludedApplication(String)
    case detectionUnavailable

    var message: String {
        switch self {
        case .fullscreen(let name): return "自动排列已暂停：\(name) 正在全屏"
        case .excludedApplication(let name): return "自动排列已暂停：\(name) 在暂停名单中"
        case .detectionUnavailable: return "无法判断全屏状态，自动排列暂时暂停"
        }
    }
}

enum PausePolicy {
    static func coversDisplay(_ window: CGRect, display: CGRect, tolerance: CGFloat = 2) -> Bool {
        guard window.width > 0, window.height > 0, display.width > 0, display.height > 0,
              [window.minX, window.minY, window.maxX, window.maxY,
               display.minX, display.minY, display.maxX, display.maxY].allSatisfy(\.isFinite) else { return false }
        return window.minX <= display.minX + tolerance && window.minY <= display.minY + tolerance
            && window.maxX >= display.maxX - tolerance && window.maxY >= display.maxY - tolerance
    }

    static func reason(settings: PauseSettings, context: ForegroundContext, displays: [CGRect]) -> PauseReason? {
        if let app = context.application,
           settings.applications.contains(where: { $0.bundleID == app.bundleID }) {
            return .excludedApplication(app.name)
        }
        guard settings.whenFullscreen else { return nil }
        guard let app = context.application, case .available(let windows) = context.windows else {
            return .detectionUnavailable
        }
        if windows.contains(where: { window in
            window.ownerPID == app.processID && window.alpha.isFinite && window.alpha > 0
                && displays.contains(where: { coversDisplay(window.bounds, display: $0) })
        }) { return .fullscreen(app.name) }
        return nil
    }
}

// A queued move belongs to one application/Space/settings generation. Changing
// context invalidates its ticket even if the app becomes eligible again quickly.
struct AutomaticPushSession {
    private var tracker = PushTracker()
    private(set) var generation: UInt64 = 0
    var last: TimeInterval { tracker.last }
    var hasPush: Bool { tracker.edge != nil }

    mutating func reset() { tracker.reset() }
    mutating func invalidate() { generation &+= 1; reset() }

    mutating func update(edge: Side, time: TimeInterval, duration: TimeInterval, allowed: Bool) -> Double {
        guard allowed else { reset(); return 0 }
        return tracker.update(edge: edge, time: time, duration: duration)
    }

    func permitsQueuedMove(ticket: UInt64, allowed: Bool) -> Bool {
        ticket == generation && allowed
    }
}
