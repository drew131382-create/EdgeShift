# 参与贡献

欢迎通过 issue 反馈问题或提交 pull request。提交问题时请注明 macOS 版本、Mac 型号、显示器配置、输入设备、复现步骤及预期和实际行为；请勿附带隐私数据。

## 开发

需要 macOS 13 或更新版本、Swift 5.9 或更新版本、Apple Command Line Tools（运行 `swift test` 推荐完整 Xcode）以及 Python 3。请在独立分支上开发。

没有签名证书也能为本地测试构建：

```sh
EDGESHIFT_SIGNING_IDENTITY=- EDGESHIFT_BUNDLE_ID=org.example.edgeshift ./scripts/build-app.sh
open build/EdgeShift.app
```

将 `org.example.edgeshift` 换成自己的标识，避免与官方版本及其他本地副本共用系统授权记录。临时签名只适合本地测试，每次重新构建可能需要重新授予输入监控权限，不适合作为正式发布文件。已有 Apple Development 证书时，也可按 README 指定稳定的签名身份。

默认成功构建后会重置该应用标识的输入监控授权。若要保留授权，可额外设置 `EDGESHIFT_RESET_INPUT_MONITORING=0`；GitHub CI 使用此选项。

有完整 Xcode 时运行 `swift test`。Command Line Tools 缺少 XCTest 时，运行 README 中的独立逻辑检查。触及鼠标事件或显示器配置的变更还应在真实双屏设备上验证，说明设备、操作方式及结果。

请勿提交 `.build/`、`build/`、证书、私钥或任何凭据。提交前确认新增依赖和素材允许以本项目的方式分发，并保留所需的许可声明。
