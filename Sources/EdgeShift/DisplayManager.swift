import AppKit
import CoreGraphics

struct DisplaySnapshot: Equatable {
    let mainID: CGDirectDisplayID
    let secondaryID: CGDirectDisplayID
    let main: CGRect
    let secondary: CGRect
}

enum DisplayManager {
    static func snapshot() -> DisplaySnapshot? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count == 2 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success, count == 2 else { return nil }
        let main = CGMainDisplayID()
        guard ids.contains(main), let other = ids.first(where: { $0 != main }),
              CGDisplayIsInMirrorSet(main) == 0, CGDisplayIsInMirrorSet(other) == 0,
              CGDisplayIsActive(main) != 0, CGDisplayIsActive(other) != 0 else { return nil }
        return DisplaySnapshot(mainID: main, secondaryID: other, main: CGDisplayBounds(main), secondary: CGDisplayBounds(other))
    }
    static func arrange(_ snapshot: DisplaySnapshot, origin: CGPoint) -> String? {
        guard self.snapshot() == snapshot else { return "显示器状态已改变，请重试。" }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return "无法开始显示器配置。" }
        let result = CGConfigureDisplayOrigin(config, snapshot.secondaryID, Int32(origin.x.rounded()), Int32(origin.y.rounded()))
        guard result == .success else { CGCancelDisplayConfiguration(config); return "无法设置显示器位置（\(result.rawValue)）。" }
        let complete = CGCompleteDisplayConfiguration(config, .permanently)
        guard complete == .success else { return "无法应用显示器位置（\(complete.rawValue)）。" }
        return nil
    }
}
