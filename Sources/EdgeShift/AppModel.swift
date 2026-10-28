import AppKit
import Combine
import CoreGraphics
import ServiceManagement

final class AppModel: ObservableObject {
    @Published var snapshot: DisplaySnapshot?
    @Published var status = "正在检查显示器…"
    @Published var notice: String?
    @Published var progress = 0.0
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); reset(); updateTap() } }
    @Published var duration: Double { didSet { UserDefaults.standard.set(duration, forKey: "duration"); reset() } }
    @Published var loginEnabled = false
    @Published var permission = false
    @Published var manualDisplayID: CGDirectDisplayID = 0
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var tracker = PushTracker()
    private var cooldownUntil: TimeInterval = 0
    private var timer: Timer?
    private var isArranging = false
    private var screenLocked = false
    private var permissionFallbackScheduled = false
    private var displayCycle = DisplayCycle<CGDirectDisplayID>()

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        duration = defaults.object(forKey: "duration") as? Double ?? 2
        refresh()
        if defaults.object(forKey: "loginAttempted") == nil {
            defaults.set(true, forKey: "loginAttempted")
            setLogin(true)
        } else { refreshLogin() }
        updateTap()
        // Ask once per launch after AppKit has initialized. macOS may suppress
        // the prompt after a previous decision, so the settings link remains available.
        if enabled && !permission {
            DispatchQueue.main.async { [weak self] in self?.requestPermission() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(lockScreen), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(unlockScreen), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    }
    @objc private func lockScreen() { screenLocked = true; reset() }
    @objc private func unlockScreen() { screenLocked = false; reset(); refresh() }
    @objc private func wake() { reset(); refresh(); updateTap() }
    func refresh() {
        let new = DisplayManager.snapshot()
        if new != snapshot {
            if new?.mainID != snapshot?.mainID || Set(new?.displays.map(\.id) ?? []) != Set(snapshot?.displays.map(\.id) ?? []) {
                displayCycle.reset()
            }
            snapshot = new
            reset()
        }
        if let new, !new.secondaries.contains(where: { $0.id == manualDisplayID }) {
            manualDisplayID = new.secondaries.first?.id ?? 0
        }
        permission = CGPreflightListenEventAccess()
        if permission && notice == "请在系统设置的“隐私与安全性 → 输入监控”中开启 EdgeShift。" { notice = nil }
        if new == nil { status = "需要至少两块非镜像的扩展显示器" }
        else if !enabled { status = "自动排列已关闭" }
        else if !permission { status = "请授予输入监控权限以启用自动排列" }
        else { status = "已连接 \(new!.displays.count) 块屏幕，自动排列已就绪" }
    }
    private func tick() {
        if tracker.edge != nil && ProcessInfo.processInfo.systemUptime - tracker.last > 0.2 { reset() }
        let wasPermission = permission
        refresh()
        if permission != wasPermission { updateTap() }
    }
    func requestPermission() {
        _ = CGRequestListenEventAccess()
        refresh(); updateTap()
        if !permission {
            notice = "请在系统设置的“隐私与安全性 → 输入监控”中开启 EdgeShift。"
            if !permissionFallbackScheduled {
                permissionFallbackScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self else { return }
                    self.permissionFallbackScheduled = false
                    self.refresh()
                    if self.enabled && !self.permission { self.openPrivacy() }
                }
            }
        } else {
            notice = nil
        }
    }
    func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") { NSWorkspace.shared.open(url) }
    }
    func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { notice = "登录启动设置失败：\(error.localizedDescription)" }
        refreshLogin()
    }
    func refreshLogin() { loginEnabled = SMAppService.mainApp.status == .enabled }
    private func reset() { tracker.reset(); progress = 0 }
    @discardableResult
    func arrange(displayID: CGDirectDisplayID, origin: CGPoint) -> Bool {
        guard let s = snapshot, !isArranging else { return false }
        isArranging = true; reset()
        let error = DisplayManager.arrange(s, displayID: displayID, origin: origin)
        isArranging = false
        if let error { notice = error; return false }
        cooldownUntil = ProcessInfo.processInfo.systemUptime + 3
        refresh(); notice = "显示器排列已更新"
        return true
    }
    func move(_ edge: Side) {
        move(displayID: manualDisplayID, edge: edge)
    }
    @discardableResult
    private func move(displayID: CGDirectDisplayID, edge: Side) -> Bool {
        guard let s = snapshot, let target = s.secondaries.first(where: { $0.id == displayID }) else { return false }
        let obstacles = s.displays.filter { $0.id != displayID && $0.id != s.mainID }.map(\.bounds)
        let origin = LayoutGeometry.nextAvailableOrigin(edge: edge, main: s.main, target: target.bounds, obstacles: obstacles)
        return arrange(displayID: displayID, origin: origin)
    }
    private func updateTap() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes); self.source = nil }
        if let tap { CFMachPortInvalidate(tap); self.tap = nil }
        guard enabled, CGPreflightListenEventAccess() else { return }
        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let model = Unmanaged<AppModel>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { if let tap = model.tap { CGEvent.tapEnable(tap: tap, enable: true) }; model.reset() }
            else if type == .mouseMoved { model.handle(event) }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { status = "无法监听鼠标事件，请检查输入监控权限。"; return }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    private func handle(_ event: CGEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        guard enabled, !screenLocked, !isArranging, now >= cooldownUntil, let s = snapshot,
              !CGEventSource.buttonState(.combinedSessionState, button: .left),
              !CGEventSource.buttonState(.combinedSessionState, button: .right),
              !CGEventSource.buttonState(.combinedSessionState, button: .center) else { reset(); return }
        let p = event.location
        let dx = CGFloat(event.getIntegerValueField(.mouseEventDeltaX))
        let dy = CGFloat(event.getIntegerValueField(.mouseEventDeltaY))
        guard let edge = LayoutGeometry.outwardEdge(point: p, deltaX: dx, deltaY: dy, main: s.main),
              !s.secondaries.contains(where: { LayoutGeometry.traversable(edge: edge, at: p, main: s.main, secondary: $0.bounds) }) else { reset(); return }
        progress = tracker.update(edge: edge, time: now, duration: duration)
        if progress >= 1 {
            cooldownUntil = now + 3
            reset()
            let mainID = s.mainID
            let ids = s.secondaries.map(\.id)
            guard let target = displayCycle.next(in: ids) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.snapshot?.mainID == mainID,
                      self.snapshot?.secondaries.map(\.id) == ids else { return }
                if self.move(displayID: target, edge: edge) { self.displayCycle.didMove(target) }
            }
        }
    }
}
