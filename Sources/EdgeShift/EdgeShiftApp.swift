import SwiftUI
import AppKit

@main
struct EdgeShiftApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            MenuBarIcon(pushing: model.progress > 0)
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("EdgeShift").font(.title3.weight(.semibold))
                    Text("显示器排列").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(model.automaticReady ? Color.green : Color.orange).frame(width: 8, height: 8)
                    .accessibilityLabel(model.automaticReady ? "自动排列已就绪" : "自动排列未就绪或已暂停")
            }
            if let snapshot = model.snapshot {
                if snapshot.secondaries.count > 1 {
                    Picker("手动调整", selection: $model.manualDisplayID) {
                        ForEach(snapshot.secondaries) { display in
                            Text("\(snapshot.number(for: display.id)) · \(display.name)").tag(display.id)
                        }
                    }
                    Text("自动排列按系统识别顺序轮流选择副屏；重新连接后顺序可能变化。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ArrangementView(snapshot: snapshot, selectedID: model.manualDisplayID, onMove: { id, origin in
                    model.manualDisplayID = id
                    model.arrange(displayID: id, origin: origin)
                })
                    .frame(height: 145)
                Text("拖动副屏贴合其他屏幕；快捷按钮针对所选副屏。")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        moveButton("移到上方", icon: "arrow.up", side: .top)
                        moveButton("移到下方", icon: "arrow.down", side: .bottom)
                    }
                    HStack(spacing: 8) {
                        moveButton("移到左侧", icon: "arrow.left", side: .left)
                        moveButton("移到右侧", icon: "arrow.right", side: .right)
                    }
                }.buttonStyle(.bordered)
            } else {
                ContentUnavailableViewCompat()
                    .frame(maxWidth: .infinity).frame(height: 135)
            }
            Divider()
            Toggle("边缘推动自动排列", isOn: $model.enabled)
            HStack {
                Text("持续推动")
                Spacer()
                Picker("持续推动", selection: $model.duration) {
                    Text("0.3 秒").tag(0.3)
                    Text("0.5 秒").tag(0.5)
                    Text("1 秒").tag(1.0)
                    Text("2 秒").tag(2.0)
                    Text("3 秒").tag(3.0)
                }.labelsHidden().frame(width: 100)
            }.disabled(!model.enabled)
            ProgressView(value: model.progress)
                .controlSize(.small)
                .opacity(model.progress > 0 ? 1 : 0)
                .accessibilityHidden(model.progress <= 0)
            Toggle("登录时自动启动", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
            Button("自动暂停设置…") { model.showPauseSettings() }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayedStatus).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 34, alignment: .topLeading)
                    .help(model.displayedStatus)
                Text(model.notice ?? "").lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 16, alignment: .topLeading)
                    .help(model.notice ?? "")
            }.font(.caption).foregroundStyle(.secondary)
            if !model.permission && model.enabled {
                HStack {
                    Button("请求输入监控权限") { model.requestPermission() }
                    Button("打开系统设置") { model.openPrivacy() }
                }.controlSize(.small)
            }
            HStack {
                Spacer()
                Button("退出 EdgeShift") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.font(.caption)
        }
        .padding(18).frame(width: 350)
    }

    private func moveButton(_ title: String, icon: String, side: Side) -> some View {
        Button { model.move(side) } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity)
        }
        .accessibilityLabel(title)
    }
}

struct ContentUnavailableViewCompat: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "display.2").font(.system(size: 28)).foregroundStyle(.secondary)
            Text("连接至少两块扩展显示器").font(.callout.weight(.medium))
            Text("镜像模式暂不支持").font(.caption).foregroundStyle(.secondary)
        }
    }
}

final class DragModel: ObservableObject {
    @Published var translation = CGSize.zero
    @Published var displayID: CGDirectDisplayID?
}

struct ArrangementView: View {
    let snapshot: DisplaySnapshot
    let selectedID: CGDirectDisplayID
    let onMove: (CGDirectDisplayID, CGPoint) -> Void
    @StateObject private var dragModel = DragModel()
    var body: some View {
        GeometryReader { proxy in
            let union = snapshot.displays.dropFirst().reduce(snapshot.displays[0].bounds) { $0.union($1.bounds) }
            let scale = min((proxy.size.width - 16) / max(union.width, 1), (proxy.size.height - 16) / max(union.height, 1), 0.13)
            let offset = CGPoint(x: (proxy.size.width - union.width * scale) / 2 - union.minX * scale,
                                 y: (proxy.size.height - union.height * scale) / 2 - union.minY * scale)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04))
                ForEach(snapshot.displays) { display in
                    if display.id == snapshot.mainID {
                        screen(display.bounds, label: "主屏 \(snapshot.number(for: display.id))", color: .secondary, scale: scale)
                            .position(x: offset.x + display.bounds.midX * scale, y: offset.y + display.bounds.midY * scale)
                    } else {
                        screen(display.bounds, label: "副屏 \(snapshot.number(for: display.id))", color: display.id == selectedID ? .accentColor : .secondary, scale: scale)
                            .position(x: offset.x + display.bounds.midX * scale + (dragModel.displayID == display.id ? dragModel.translation.width : 0),
                                      y: offset.y + display.bounds.midY * scale + (dragModel.displayID == display.id ? dragModel.translation.height : 0))
                            .gesture(DragGesture(minimumDistance: 2)
                                .onChanged { dragModel.displayID = display.id; dragModel.translation = $0.translation }
                                .onEnded { value in
                                    let point = CGPoint(x: display.bounds.minX + value.translation.width / scale,
                                                        y: display.bounds.minY + value.translation.height / scale)
                                    dragModel.translation = .zero; dragModel.displayID = nil
                                    let otherScreens = snapshot.displays.filter { $0.id != display.id }.map(\.bounds)
                                    let origin = LayoutGeometry.snappedToDisplays(secondary: display.bounds.size, proposed: point, otherScreens: otherScreens) ?? point
                                    onMove(display.id, origin)
                                })
                            .accessibilityLabel("副屏 \(snapshot.number(for: display.id))，可拖动调整位置")
                    }
                }
            }.clipped()
        }
    }
    func screen(_ rect: CGRect, label: String, color: Color, scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.18))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.7), lineWidth: 1.5))
            .overlay(Text(label).font(.caption.weight(.medium)).foregroundStyle(color))
            .frame(width: rect.width * scale, height: rect.height * scale)
    }
}
