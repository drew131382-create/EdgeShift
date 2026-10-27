import SwiftUI
import AppKit

@main
struct EdgeShiftApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            Image(systemName: model.progress > 0 ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
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
                    Text("双屏排列").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(model.snapshot == nil ? Color.orange : Color.green).frame(width: 8, height: 8)
            }
            if let snapshot = model.snapshot {
                ArrangementView(snapshot: snapshot, onMove: model.arrange)
                    .frame(height: 145)
                Text("拖动副屏调整位置，松开后自动贴合主屏。")
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
            Divider()
            Text(model.notice ?? model.status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            Text("连接两块扩展显示器").font(.callout.weight(.medium))
            Text("镜像模式和多屏暂不支持").font(.caption).foregroundStyle(.secondary)
        }
    }
}

final class DragModel: ObservableObject {
    @Published var translation = CGSize.zero
}

struct ArrangementView: View {
    let snapshot: DisplaySnapshot
    let onMove: (CGPoint) -> Void
    @StateObject private var dragModel = DragModel()
    var body: some View {
        GeometryReader { proxy in
            let union = snapshot.main.union(snapshot.secondary)
            let scale = min((proxy.size.width - 16) / max(union.width, 1), (proxy.size.height - 16) / max(union.height, 1), 0.13)
            let offset = CGPoint(x: (proxy.size.width - union.width * scale) / 2 - union.minX * scale,
                                 y: (proxy.size.height - union.height * scale) / 2 - union.minY * scale)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04))
                screen(snapshot.main, label: "主屏", color: .secondary, scale: scale)
                    .position(x: offset.x + snapshot.main.midX * scale, y: offset.y + snapshot.main.midY * scale)
                screen(snapshot.secondary, label: "副屏", color: .accentColor, scale: scale)
                    .position(x: offset.x + snapshot.secondary.midX * scale + dragModel.translation.width, y: offset.y + snapshot.secondary.midY * scale + dragModel.translation.height)
                    .gesture(DragGesture(minimumDistance: 2)
                        .onChanged { dragModel.translation = $0.translation }
                        .onEnded { value in
                            let point = CGPoint(x: snapshot.secondary.minX + value.translation.width / scale,
                                                y: snapshot.secondary.minY + value.translation.height / scale)
                            dragModel.translation = .zero
                            onMove(LayoutGeometry.snapped(main: snapshot.main, secondary: snapshot.secondary.size, proposed: point))
                        })
                    .accessibilityLabel("副屏，可拖动调整位置")
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
