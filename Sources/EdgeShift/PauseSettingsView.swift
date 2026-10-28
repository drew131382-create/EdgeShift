import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class PauseSettingsWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) { self.model = model }

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "EdgeShift · 自动暂停"
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: PauseSettingsView(model: model, onAdd: { [weak self] in
                self?.chooseApplications()
            }))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func chooseApplications() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "添加需要暂停自动排列的应用"
        panel.prompt = "添加"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.model.addPausedApplications(from: panel.urls)
        }
    }
}

private struct PauseSettingsView: View {
    @ObservedObject var model: AppModel
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("自动暂停保护").font(.title2.weight(.semibold))
                Text("仅暂停边缘推动，手动排列和快捷按钮仍可使用。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Toggle("前台应用全屏时暂停", isOn: $model.pauseSettings.whenFullscreen)
            Text("覆盖任一整块屏幕的窗口会视为全屏，包括无边框游戏。切换到普通窗口应用后自动恢复。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Text("指定应用内暂停").font(.headline)
                Spacer()
                Button("添加应用…", action: onAdd)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04))
                if model.pauseSettings.applications.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "app.dashed").font(.title2).foregroundStyle(.secondary)
                        Text("尚未添加应用").font(.callout)
                        Text("添加游戏或其他需要暂停的应用")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.pauseSettings.applications) { app in
                                HStack(spacing: 10) {
                                    Image(nsImage: icon(for: app)).resizable().frame(width: 30, height: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name).lineLimit(1)
                                        Text(app.bundleID).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                    Button { model.removePausedApplication(bundleID: app.bundleID) } label: {
                                        Image(systemName: "minus.circle")
                                    }.buttonStyle(.borderless).help("移除 \(app.name)")
                                        .accessibilityLabel("移除 \(app.name)")
                                }.padding(10)
                            }
                        }
                    }
                }
            }.frame(height: 174)
            Text("名单中的应用仅在前台时暂停，切换离开后恢复。恢复后需重新持续推动鼠标。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(model.pauseSettingsMessage ?? "设置会自动保存。")
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
        }.padding(24).frame(width: 480)
    }

    private func icon(for app: PausedApplication) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}
