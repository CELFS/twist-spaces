# Twist Spaces

[English](README.md) | [简体中文](README.zh-CN.md)

自用、可扩展的原生 macOS 工作区管理工具，基于 Swift 6.1、SwiftUI 和 AppKit。要求 macOS 15 或更新版本，无第三方依赖。

## 当前范围

当前为项目初始化和能力检查工具，尚不是完整的工作区管理器：

- 原生 Swift Package 可执行工程和本地 `.app` 构建脚本。
- 菜单栏入口，可打开独立的窗口诊断工具。
- 用于 Finder 和 macOS 应用列表的独立应用图标；菜单栏符号保持不变。
- 只读列出正在运行的图形应用及其真实进程 ID、Bundle ID 和应用路径。
- 用户主动授权辅助功能后，读取选中应用的窗口标题、文档属性、标识属性、位置、尺寸、最小化状态及按钮支持的动作。
- 日志区域右上角的复制按钮，不受滚动位置或文本选择影响，可复制完整诊断文本并反馈复制成功。
- 界面文案通过原生 `Localizable.strings` 的 key 读取，默认英语，目前仅提供 `en` 源资源。代码注释和脚本使用英文；README 提供中英双语，默认英文。

应用不会自动申请权限、打开项目、移动或关闭其他应用窗口、访问应用数据库、调用私有 Spaces API，也不会用普通桌面窗口平铺代替原生 Split View。

诊断窗口是开发验证工具，不是最终的半透明侧边面板。它的尺寸和开关行为不代表最终面板的设计约定。

## 构建与启动

使用现有 Command Line Tools，不需要安装包管理器或第三方依赖。在项目根目录执行：

```bash
bash claude_jobs/setup-local-signing.sh # One-time setup on this Mac
bash claude_jobs/build-app.sh
open "build/debug/Twist Spaces.app"
```

应用只显示菜单栏图标，不自动弹出窗口。点击图标，选择 **Window Diagnostics…**。关闭诊断窗口后，应用仍在菜单栏运行。选择 **Quit Twist Spaces** 退出。

构建 release 应用包：

```bash
bash claude_jobs/build-app.sh release
```

构建产物位于 `build/`，缓存和临时构建文件位于 `.build/`，两个目录均已加入 Git 忽略规则。一次性签名配置会在登录钥匙串创建或复用本地开发签名身份，并将证书指纹固定在被忽略的 `signing.local.json` 中。证书信任仅限当前用户的代码签名用途，不修改 TLS 信任、系统级信任、Gatekeeper 或辅助功能权限。临时私钥文件经过加密，配置结束后删除。

构建固定使用同一身份；身份不可用时直接停止，不回退到 ad-hoc 签名，也不创建替代证书。从旧 ad-hoc 构建切换到该身份后，需要为新身份授权一次。后续构建旨在保持相同代码身份，但实际权限保留仍需在 macOS 上验证。两个脚本均不会将应用安装到 `/Applications`、进行公证或设置开机启动。当前为本地开发签名，不是发布签名。

## 版本管理

编辑项目根目录的 [version.json](version.json)，它是应用版本号的唯一配置来源：

```json
{
  "version": "0.1.0",
  "build": 1
}
```

- `version`：对外版本号，写入 `CFBundleShortVersionString`。使用三段数字组成的字符串，例如 `0.1.0` 或 `1.2.3`。
- `build`：构建号，在应用包中以字符串写入 `CFBundleVersion`。这里使用正整数 JSON 数值。

修改后运行 `bash claude_jobs/build-app.sh` 或 `bash claude_jobs/build-app.sh release`。两种构建都读取同一个 JSON 文件，在签名前将版本值写入生成的 `.app/Contents/Info.plist`。源码 `App/Info.plist` 不再重复保存版本值，构建时也不会被回写。版本号不会自动递增；配置缺失或格式错误时，会在编译前停止构建。

仅保存 JSON 不会更新已有或正在运行的应用；需要重新构建，再退出并重新打开应用。

## 窗口检查

```bash
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --help
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --list-apps
```

从应用列表获取进程 ID，再将下面的 `12345` 替换为真实 PID：

```bash
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --inspect 12345
```

命令行不会弹出权限提示。退出码：`0` 表示完成，`1` 表示应用或读取错误，`2` 表示需要辅助功能权限，`64` 表示参数错误。读取完成不代表所有可选属性都可用，还应检查每个属性的 `errorCode`。

在界面中选择应用。如果尚未授权，可点击 **Request accessibility access…**，在系统设置中授权 Twist Spaces，返回应用后点击 **Refresh**，再点击 **Inspect windows**。权限归属可能受启动进程影响，因此建议优先通过 `.app` 界面检查。应用不会自动刷新窗口、将诊断报告写入文件或发送到网络。

诊断 JSON 包含窗口标题和可能的本地项目路径，分享前请自行检查。进程 ID 和窗口序号仅代表当前运行进程或当前报告中的条目，不是持久化项目标识。部分应用不提供 `AXDocument` 或 `AXIdentifier`，读取失败时会保留 AX 错误码，工具不会根据标题猜测项目配对。

分享结果时，点击日志区域右上角的复制图标，再粘贴完整报告。只有剪贴板写入成功后才显示 **Copied**。检查进行中或尚无结果时，复制按钮不可用。剪贴板写入失败会明确提示，原有文本选择功能保留。

如果构建时应用仍在运行，请通过 Twist Spaces 菜单退出，再重新打开 `.app` 以加载更新后的界面。构建脚本不会重启正在运行的应用。

## 应用图标

应用图标采用深色圆角底板和蓝紫色交错双窗口。源图、导出的 `.icns` 和生成提示词位于 [App/Assets](App/Assets/README.md)。

基于现有 PNG 源图重新导出 macOS 图标尺寸：

```bash
bash claude_jobs/build-icon.sh
bash claude_jobs/build-app.sh
```

使用系统自带的 `sips` 和 `iconutil`，无需安装依赖。普通构建会将已有 `.icns` 复制到应用包中。

## 已观察到的本机环境

2026-08-27：macOS 15.4.1、arm64、Swift 6.1，工具链位于 `/Library/Developer/CommandLineTools`。

- Cursor：`/Applications/Cursor.app`，Bundle ID 为 `com.todesktop.230313mzl4w4u92`。应用包内包含 Cursor CLI，并声明了 `cursor` URL scheme。尚未测试打开指定项目的行为。
- 当前 Codex 宿主：`/Applications/ChatGPT.app`，Bundle ID 为 `com.openai.codex`，声明了 `codex` URL scheme。注册 scheme 本身不足以证明可以在新窗口中打开指定项目，路由语义仍未验证。

以上仅为本机观察，不作为硬编码路径或自动配对规则。

## 测试与验证

使用系统自带的 Swift Testing 框架运行测试：

```bash
swift test --disable-xctest
```

测试覆盖进程身份区分、诊断 JSON 和属性错误保留、权限不足与空结果的区别、英文资源、缺失本地化 key 的显示及完整报告复制。剪贴板测试使用私有剪贴板，不修改用户的通用剪贴板。测试不会读取真实窗口或申请权限。项目使用 Swift Testing，因此关闭 XCTest，不要求安装完整 Xcode。

兼容性测试使用模拟的窗口读取和属性写入，验证应用与权限检查、进程身份检查、空结果的有界恢复及错误保留。可选窗口属性缺失不会触发恢复，测试不会启用真实应用的无障碍支持。

2026-08-27 初始化检查结果：

- debug arm64 `.app` 已编译，通过严格签名校验，并成功加载应用包内的英文资源。
- 5 项 Swift 测试和 7 项命令行参数及错误处理检查全部通过。
- 在开发沙箱外，命令行列出了 11 个正在运行的图形应用，并通过 Bundle ID 识别到 Cursor 和 Codex。
- 两个目标的检查均返回退出码 `2`：Twist Spaces 尚未获得辅助功能权限。实际窗口读取和原生 Split View 配对仍未验证。
- 菜单栏和诊断界面尚未进行视觉验证。

## 后续验证与待确认事项

1. 检查实际 Cursor 和 Codex 窗口，确认能否可靠地区分不同项目。
2. 确认复用已有窗口还是新开窗口，再验证如何打开指定项目窗口。
3. 验证公开辅助功能操作能否将选中的窗口组成原生全屏 Split View。目前尚未实现，也尚未验证。
4. 确认正式侧边面板的宽度、收起规则、边缘触发范围与延迟、快捷键及多显示器行为。
5. 核心能力明确后，再实现工作区持久化、编辑、分组和批量打开。

Apple 将原生 Split View 与普通桌面窗口平铺区分，Split View 会创建新的桌面空间。按钮暴露 `AXPress` 等动作，并不能证明两扇指定窗口能够自动配对，因此工具不会根据按钮可用性报告支持原生分屏。参考：[Apple Split View 说明](https://support.apple.com/en-ca/guide/mac-help/mchl4fbe2921/mac)、[辅助功能授权 API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)、[辅助功能属性读取 API](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue)。

## 项目结构

```text
App/Info.plist                 应用包元信息
App/Assets/                    源图、macOS 图标和生成提示词
Package.swift                  原生 Swift Package 入口
version.json                   应用版本号和构建号的唯一来源
signing.local.json             被忽略的本机签名证书指纹配置
Sources/TwistSpaces/App/       应用生命周期与菜单栏
Sources/TwistSpaces/Features/  诊断窗口与视图模型
Sources/TwistSpaces/Models/    只读报告结构，不是工作区持久化协议
Sources/TwistSpaces/Services/  应用枚举、权限检查和 AX 检查
Sources/TwistSpaces/Resources/ 原生本地化资源
Tests/TwistSpacesTests/        使用 Swift Testing 的基础测试
claude_jobs/build-app.sh       构建、打包和本地签名
claude_jobs/setup-local-signing.sh 一次性本地签名身份配置
claude_jobs/build-icon.sh      从已确认的 PNG 导出 macOS 图标尺寸
```

`temp/` 目录留给用户手动维护需求文档，应用代码和构建流程均不会写入该目录。加入 `.gitignore` 不会取消已暂存或已跟踪文件的状态，Git 状态由用户自行管理。
