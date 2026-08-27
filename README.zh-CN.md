# Twist Spaces

[English](README.md) | [简体中文](README.zh-CN.md)

自用、可扩展的原生 macOS 工作区管理工具，基于 Swift 6.1、SwiftUI 和 AppKit。要求 macOS 15 或更新版本，无第三方依赖。

## 当前范围

主入口现在是原生毛玻璃工作区面板，已实现真实管理闭环，但尚未完成项目打开和原生 Split View 流程：

- 原生 Swift Package 可执行工程和本地 `.app` 构建脚本。
- 普通 Dock 应用，同时保留菜单栏图标。左键切换工作区面板，右键打开菜单；诊断仅放在 debug 版本的 **Developer** 子菜单。
- 真实工作区创建和编辑：项目目录、名称，以及用户明确选定的左右 Cursor/Codex 窗口，不插入示例数据。
- 原子保存到 `~/Library/Application Support/Twist Spaces/workspaces.json`；文件损坏或版本不支持时禁用保存，不覆盖原文件。
- **Show windows** 和 **Show selected windows** 恢复并前置已绑定的现有窗口；操作前检查全部选中项，有无法识别的工作区时阻止批次。此操作不是重新打开项目或应用分屏布局。
- 可设置左右侧、宽度，并主动启用边缘呼出及 Control–Option–Space。面板在鼠标所在显示器打开，保持显示直到明确关闭或切换。
- 用于 Finder 和 macOS 应用列表的独立应用图标；菜单栏符号保持不变。
- 只读列出正在运行的图形应用及其真实进程 ID、Bundle ID 和应用路径。
- 用户主动授权辅助功能后，读取选中应用的窗口标题、文档属性、标识属性、位置、尺寸、最小化状态及按钮支持的动作。
- 日志区域右上角的复制按钮，不受滚动位置或文本选择影响，可复制完整诊断文本并反馈复制成功。
- 界面文案通过原生 `Localizable.strings` 的 key 读取，默认英语，目前仅提供 `en` 源资源。代码注释和脚本使用英文；README 提供中英双语，默认英文。

应用不会自动申请权限、新开项目窗口、移动/调整尺寸或关闭其他应用窗口、访问应用数据库、调用私有 Spaces API，也不会用普通桌面窗口平铺代替原生 Split View。选择 **Show windows** 仅授权恢复最小化并前置所选窗口。

诊断仍是独立开发工具。面板尺寸是可配置的当前实现值，不代表最终交互已经约定。保存的目标布局仍是原生 Split View，但自动配对和重新打开项目尚未实现。

## 构建与启动

使用现有 Command Line Tools，不需要安装包管理器或第三方依赖。在项目根目录执行：

```bash
bash claude_jobs/build-app.sh
open "build/debug/Twist Spaces.app"
```

应用启动显示工作区面板，同时保留 Dock 和菜单栏入口。点击 Dock 图标重新打开面板，左键菜单栏图标切换面板。右键菜单栏图标可进入设置、debug 专用的 **Developer > Window Diagnostics…** 和 **Quit Twist Spaces**。Dock「退出」、应用菜单 **Quit Twist Spaces** 及应用内 ⌘Q 均退出同一个应用。关闭面板或诊断窗口不等于退出。

本机固定开发签名已配置，常规构建不要重新运行签名初始化。每次构建后，必须从菜单退出旧进程，再执行上述 `open` 命令。**Refresh** 只读取窗口状态，不会编译或加载新版程序。

## 工作区操作

1. 自行打开目标 Cursor 和 Codex 项目窗口。
2. 选择 **New workspace**，填写名称和项目目录，从真实列表选择左右窗口，明确确认它们属于该项目，再保存。
3. 用 **Edit** 修改名称、目录或窗口组合。仅改名时可保留已保存的窗口记录，不要求应用正在运行。
4. 用 **Show windows**，或勾选多张卡片后点击 **Show selected windows**，前置现有窗口。这些操作明确不会应用 Split View。

项目目录是用户指定的关联，不由标题猜测。运行期间绑定真实 AX 元素，操作前重新校验。重启后只有文档身份唯一且应用及窗口属性完全相符时才自动重绑定；仅有标题或 AXIdentifier 不够，需要编辑工作区重新选择。窗口标题变化也可能要求重新选择。列表仅包含辅助功能返回的窗口，不声称已完整识别全部应用窗口。

**Panel Settings…** 中的边缘触发与快捷键默认关闭，需主动启用。边缘触发采用鼠标所在显示器指定侧的 2 pt 范围，避开菜单栏和 Dock 区域，延迟可配置。点击 **Done** 应用触发设置。显示窗口或鼠标离开都不会自动收起面板。

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

在诊断界面中选择应用。如果尚未授权，可点击 **Request accessibility access…**，在系统设置中授权 Twist Spaces，返回应用后点击 **Refresh**，再点击 **Inspect windows**。权限归属可能受启动进程影响，因此建议优先通过 `.app` 界面检查。诊断不会自动刷新、将报告写入文件或发送到网络。工作区编辑器在打开或主动刷新时读取窗口；显示已保存窗口前也会重新检查。

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

2026-08-27 工作区实现检查结果：

- 31 项 Swift 测试全部通过，包括原有 22 项和新增 9 项工作区测试。新增覆盖持久化/编辑、无效文件保护、精确会话绑定、唯一文档匹配及拒绝仅凭标题重绑定。
- debug 应用沿用已有固定签名构建，在受限工具沙箱外通过严格签名验证。
- 已分别实际执行应用菜单退出和应用内 ⌘Q，每次均检查进程消失后重新打开应用；通过真实界面检查工作区面板和创建表单，辅助功能仍为已授权。
- 实际编辑器返回 1 个 Cursor 窗口，未返回 Codex/ChatGPT 窗口，枚举完整性尚未证明。没有为绕过此限制而保存虚构工作区。真实 Cursor–Codex 配对的端到端保存/显示、批量行为、Dock 右键菜单、边缘触发及全局快捷键仍未验证。
- 项目重新打开和自动原生 Split View 尚未实现；目标布局仅被保存，尚不执行。

2026-08-27 早期初始化检查记录（工作区实现之前）：

- debug arm64 `.app` 已编译，通过严格签名校验，并成功加载应用包内的英文资源。
- 5 项 Swift 测试和 7 项命令行参数及错误处理检查全部通过。
- 在开发沙箱外，命令行列出了 11 个正在运行的图形应用，并通过 Bundle ID 识别到 Cursor 和 Codex。
- 两个目标的检查均返回退出码 `2`：Twist Spaces 尚未获得辅助功能权限。实际窗口读取和原生 Split View 配对仍未验证。
- 菜单栏和诊断界面尚未进行视觉验证。

## 剩余实现和验证

1. 检查实际 Cursor 和 Codex 窗口，确认能否可靠地区分不同项目。
2. 确认复用已有窗口还是新开窗口，再验证如何打开指定项目窗口。
3. 验证公开辅助功能操作能否将选中的窗口组成原生全屏 Split View。目前尚未实现，也尚未验证。
4. 确认正式侧边面板的宽度、收起规则、边缘触发范围与延迟、快捷键及多显示器行为。
5. 持久化与编辑已经实现；还需完成真实的单组/批量项目打开和原生 Split View，显示现有窗口不等于这些需求已完成。

Apple 将原生 Split View 与普通桌面窗口平铺区分，Split View 会创建新的桌面空间。按钮暴露 `AXPress` 等动作，并不能证明两扇指定窗口能够自动配对，因此工具不会根据按钮可用性报告支持原生分屏。参考：[Apple Split View 说明](https://support.apple.com/en-ca/guide/mac-help/mchl4fbe2921/mac)、[辅助功能授权 API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)、[辅助功能属性读取 API](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue)。

## 项目结构

```text
App/Info.plist                 应用包元信息
App/Assets/                    源图、macOS 图标和生成提示词
Package.swift                  原生 Swift Package 入口
version.json                   应用版本号和构建号的唯一来源
signing.local.json             被忽略的本机签名证书指纹配置
Sources/TwistSpaces/App/       应用生命周期与菜单栏
Sources/TwistSpaces/Features/  工作区面板、编辑器、设置及开发诊断
Sources/TwistSpaces/Models/    工作区持久化协议和诊断快照
Sources/TwistSpaces/Services/  本地存储、面板触发、权限检查及 AX 窗口操作
Sources/TwistSpaces/Resources/ 原生本地化资源
Tests/TwistSpacesTests/        使用 Swift Testing 的基础测试
claude_jobs/build-app.sh       构建、打包和本地签名
claude_jobs/setup-local-signing.sh 一次性本地签名身份配置
claude_jobs/build-icon.sh      从已确认的 PNG 导出 macOS 图标尺寸
```

`temp/` 目录留给用户手动维护需求文档，应用代码和构建流程均不会写入该目录。加入 `.gitignore` 不会取消已暂存或已跟踪文件的状态，Git 状态由用户自行管理。
