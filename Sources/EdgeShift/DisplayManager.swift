import AppKit
import CoreGraphics

struct DisplayItem: Equatable, Identifiable {
    let id: CGDirectDisplayID
    let bounds: CGRect
    let name: String
}

struct DisplaySnapshot: Equatable {
    let mainID: CGDirectDisplayID
    // Preserve the order returned by CGGetOnlineDisplayList.
    let displays: [DisplayItem]
    var main: CGRect { displays.first(where: { $0.id == mainID })!.bounds }
    var secondaries: [DisplayItem] { displays.filter { $0.id != mainID } }
    func number(for id: CGDirectDisplayID) -> Int { (displays.firstIndex(where: { $0.id == id }) ?? 0) + 1 }
}

enum DisplayManager {
    static func snapshot() -> DisplaySnapshot? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count >= 2 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success, count >= 2 else { return nil }
        ids = Array(ids.prefix(Int(count)))
        let main = CGMainDisplayID()
        guard ids.contains(main), ids.allSatisfy({ CGDisplayIsInMirrorSet($0) == 0 && CGDisplayIsActive($0) != 0 }) else { return nil }
        let screens = NSScreen.screens
        let displays = ids.map { id in
            let name = screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }?.localizedName ?? "显示器"
            return DisplayItem(id: id, bounds: CGDisplayBounds(id), name: name)
        }
        return DisplaySnapshot(mainID: main, displays: displays)
    }
    static func arrange(_ snapshot: DisplaySnapshot, displayID: CGDirectDisplayID, origin: CGPoint) -> String? {
        guard self.snapshot() == snapshot else { return "显示器状态已改变，请重试。" }
        guard let target = snapshot.secondaries.first(where: { $0.id == displayID }) else { return "找不到目标副屏，请重试。" }
        let destination = CGRect(origin: CGPoint(x: origin.x.rounded(), y: origin.y.rounded()), size: target.bounds.size)
        let others = snapshot.displays.filter { $0.id != displayID }.map(\.bounds)
        guard !others.contains(where: { $0.intersects(destination) }) else { return "目标位置与其他屏幕重叠，请调整位置。" }
        guard LayoutGeometry.allConnected(others + [destination]) else { return "调整会使屏幕布局断开，请先手动调整其他屏幕。" }
        if destination.origin == target.bounds.origin { return nil }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return "无法开始显示器配置。" }
        let result = CGConfigureDisplayOrigin(config, displayID, Int32(destination.minX), Int32(destination.minY))
        guard result == .success else { CGCancelDisplayConfiguration(config); return "无法设置显示器位置（\(result.rawValue)）。" }
        let complete = CGCompleteDisplayConfiguration(config, .permanently)
        guard complete == .success else { return "无法应用显示器位置（\(complete.rawValue)）。" }
        // macOS can adjust other screens as part of its own configuration rules.
        if let updated = self.snapshot() {
            let changedOther = snapshot.displays.filter { $0.id != displayID }.contains { old in
                updated.displays.first(where: { $0.id == old.id })?.bounds != old.bounds
            }
            if updated.mainID != snapshot.mainID || changedOther { return "系统同时调整了其他显示器，请检查显示器排列。" }
        }
        return nil
    }
}
