# EdgeShift

EdgeShift 是一个适用于 macOS 的双屏菜单栏应用（实验性原型）。当双屏的系统排列与实际摆放不一致时，可在主屏不可跨越的边缘持续向外推动鼠标，让副屏移动到对应方向；也可在菜单栏手动拖动排列。

## 功能

- 上、下、左、右四个方向的边缘推动检测；自动和快捷排列时，副屏沿相接边居中。
- 双屏示意图拖动排列及四个方向的快捷按钮；不主动更改系统主屏。
- 自动排列开关、可调整的触发时长和登录启动开关。默认触发时长 2 秒，输入间隔超过 200 毫秒会重置，成功后冷却 3 秒。
- 仅支持恰好两块非镜像的扩展显示器；主屏可以是内建屏或外接屏。

EdgeShift 从用户输入推断意图，不测量显示器的物理位置。推到当前指针位置已能跨屏的边缘不会重排；在角落以该事件向外位移较大的方向为准。

## 使用与权限

从本仓库的 Releases 下载实验性 DMG，打开后把 EdgeShift 拖入“应用程序”，再启动并在菜单栏点击 EdgeShift 图标。当前测试包为 Apple Silicon（arm64）版本，支持 macOS 13 或更新版本；Intel 版本尚未提供。

测试包使用临时签名，尚未经 Apple 公证。macOS 可能阻止首次打开；如果用户确认下载来源可信，可以在尝试打开后进入“系统设置 → 隐私与安全性”，在 EdgeShift 的提示处选择“仍要打开”并按系统提示确认。具体选项可能因系统版本或设备管理策略而不同，参见 [Apple 的安全打开应用说明](https://support.apple.com/zh-cn/102445)。更新临时签名版本后可能需要再次执行这些步骤或重新授权。

自动排列需要**输入监控**权限，以监听鼠标移动方向；手动排列不需要该权限。应用启动时会请求授权；如果仍未获授权，会尝试打开“系统设置 → 隐私与安全性 → 输入监控”。系统可能不再显示授权提示，需要用户在设置中手动开启并按系统要求重启应用。“仍要打开”和输入监控授权是两项独立操作。

EdgeShift 在启动时默认尝试注册登录启动，可在菜单栏中关闭。系统可能要求用户在登录项中批准。

**目前没有经过 Developer ID 签名和 Apple 公证的正式发布包。** 从开发构建得到的应用不应被当作官方正式发行版。

## 本地构建

需要 macOS 13 或更新版本、Swift 5.9 或更新版本、Apple Command Line Tools 和 Python 3。图标转换使用系统自带的 `sips` 和 `iconutil`。

无证书的本地测试构建：

```sh
EDGESHIFT_SIGNING_IDENTITY=- EDGESHIFT_BUNDLE_ID=org.example.edgeshift ./scripts/build-app.sh
open build/EdgeShift.app
```

请把示例标识换成自己的标识，避免与官方应用的授权记录冲突。`-` 表示临时签名，重建后可能需要重新授权。

如果本机恰有一个 Apple Development 签名身份，直接执行 `./scripts/build-app.sh` 会使用它；也可以设置 `EDGESHIFT_SIGNING_IDENTITY` 指定签名身份。正式对外发布需要使用 Developer ID Application、启用 hardened runtime、签名和公证，并在真实设备上验证安装及更新；本脚本仅用于本地构建，不会公证或发布。

## 测试

完整 Xcode 环境运行 `swift test`。如果 Command Line Tools 不包含 XCTest，可以运行独立的布局和输入逻辑检查：

```sh
swiftc Sources/EdgeShift/Geometry.swift scripts/test-logic.swift -o /tmp/edgeshift-logic-tests
/tmp/edgeshift-logic-tests
```

CI 检查编译和逻辑，不能代替双屏实机验收。

## 已知限制

上下边缘与菜单栏、Dock 的交互，以及不同鼠标和触控板在贴边时的输入尚未完整验证。按住鼠标按钮和锁屏时会抑制自动触发；全屏游戏、远程控制和指针捕获场景尚未可靠识别，在这些场景中建议关闭自动排列。不同显示器缩放、热插拔和睡眠唤醒仍需更多实机测试。

## 贡献与许可证

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。项目采用 [MIT License](LICENSE)。
