# Twist Spaces

[English](README.md) | [简体中文](README.zh-CN.md)

自用、可扩展的原生 macOS 工作区管理工具，基于 Swift 6.1、SwiftUI 和 AppKit。要求 macOS 15 或更新版本，无第三方依赖。

## 当前范围

应用分为两个独立界面：控制中心负责编辑和设置，半透明桌面展示面板负责勾选、打开组合。原生 Split View 尚未实现。

- 原生 Swift Package 可执行工程和本地 `.app` 构建脚本。
- 点击 Dock 图标打开控制中心；左键菜单栏图标切换展示面板，右键打开菜单。诊断仅放在 debug 版本的开发者子菜单。
- 真实组合创建和编辑：名称、两个应用，以及可选的项目目录备注。可选择已安装或运行中的应用，也可浏览其他位置的应用，不要求识别窗口或线程，不插入示例数据。
- 原子保存到 `~/Library/Application Support/Twist Spaces/workspaces.json`；文件损坏或版本不支持时禁用保存，不覆盖原文件。
- 独立的「启动或激活」和「新建窗口」图标按钮，批量操作也同时保留。激活按应用去重；新建按每组选中组合的左右两侧分别请求。未运行的应用只启动一次，运行中的应用执行一次受支持的原生新建窗口命令。应用缺失时阻止批次；命令不支持时明确报错，不替换为激活或新开应用进程。
- 点击卡片左侧内容区只切换勾选，不启动应用；操作按钮点击区域为 36 点，应用图标为 32 点，卡片显示保存的左右百分比。编辑器可设置 10:90 至 90:10，旧组合默认为 50:50。比例仅保存，尚未应用到原生 Split View。
- 可设置左右侧、宽度，并主动启用边缘呼出及 Control–Option–Space。展示面板默认宽 460 点，与屏幕边缘间隔 12 点。原生 HUD 材质在完整透明度值下模糊窗口背后的内容，不再用淡化遮罩透出清晰桌面；在鼠标所在显示器打开，失焦自动收起。
- 所有下拉框共用原生选择组件，统一标签对齐和控件宽度。展示设置与语言页共用页面布局，滑块随窗口伸展。中间版本的 340 点默认值只迁移一次至 460 点，其余自定义宽度及触发设置保留。
- 用于 Finder 和 macOS 应用列表的独立应用图标；菜单栏符号保持不变。
- 只读列出正在运行的图形应用及其真实进程 ID、Bundle ID 和应用路径。
- 用户主动授权辅助功能后，读取选中应用的窗口标题、文档属性、标识属性、位置、尺寸、最小化状态及按钮支持的动作。
- 日志区域右上角的复制按钮，不受滚动位置或文本选择影响，可复制完整诊断文本并反馈复制成功。
- 界面支持英语、简体中文及跟随系统，在控制中心切换并保存选择。文案使用原生 `Localizable.strings` key；注释和脚本使用英文，README 默认英文。

应用不会自动申请权限、打开指定项目窗口、移动/调整尺寸或关闭其他应用窗口、访问应用数据库、调用私有 Spaces API，也不会用普通桌面窗口平铺代替原生 Split View。

诊断仍是独立开发工具。应用未更换时保留已有窗口元数据，但当前打开操作使用应用信息，不依赖窗口绑定。保存的目标布局仍是原生 Split View，自动配对和重新打开项目尚未实现。

## 构建与启动

使用现有 Command Line Tools，不需要安装包管理器或第三方依赖。在项目根目录执行：

```bash
bash claude_jobs/build-app.sh
open "build/debug/Twist Spaces.app"
```

应用启动显示控制中心，点击 Dock 图标重新打开控制中心；左键菜单栏图标切换展示面板。右键菜单包含两个界面的入口、debug 专用开发诊断及退出。Dock「退出」、应用菜单退出及应用内 ⌘Q 均退出同一个应用。关闭窗口或收起面板不等于退出。

本机固定开发签名已配置，常规构建不要重新运行签名初始化。每次构建后，必须从菜单退出旧进程，再执行上述 `open` 命令。**Refresh** 只读取窗口状态，不会编译或加载新版程序。

## 工作区操作

1. 在控制中心选择「新建组合」，填写名称并选择两个应用。项目目录仅为可选备注，不控制启动行为。
2. 保存组合，之后可用「编辑」修改；不需要辅助功能授权。
3. 从菜单栏或「显示布局面板」打开展示面板，点击卡片左侧区域勾选；箭头负责启动/激活，加号窗口图标负责新建。底部同时提供批量激活和批量新建。
4. 在控制中心的「语言」页切换英语、简体中文或跟随系统，选择会被保存。

应用列表合并标准应用目录（`/Applications`、`~/Applications`、`/System/Applications`、`/System/Library/CoreServices/Applications`）、运行中的应用及已保存的选择。排除应用包内部的辅助程序和纯后台应用；其他位置的应用可通过浏览选择。显示名同时包含应用包声明的别名，例如本机 `ChatGPT.app` 声明了 `Codex` 别名。选择和去重使用 Bundle ID 与路径，不依赖显示名。保存和启动不使用窗口标题或对话线程。应用打开不等于指定项目窗口已经打开或完成配对。

为运行中的应用新建窗口需要已有的辅助功能权限。程序寻找已启用且唯一的中英文顶层「新建窗口」菜单命令，不盲发 Cmd-N。只执行一次，再检查是否出现新的标准 AX 窗口；超时不会自动重试。若未确认成功，请先检查目标应用再重试。这不代表打开指定项目、创建对话、普通平铺或原生 Split View。已看到 Cursor 的真实新建窗口菜单；当前环境限制自动操作 Codex 宿主，其端到端新建仍未实测。

控制中心展示设置中的边缘触发与快捷键默认关闭，需主动启用。边缘触发采用鼠标所在显示器指定侧的 2 pt 范围，避开菜单栏和 Dock 区域，延迟可配置。设置即时生效；展示面板失焦自动收起，仅移开鼠标不会收起。

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

在诊断界面中选择应用。如果尚未授权，可点击 **Request accessibility access…**，在系统设置中授权 Twist Spaces，返回应用后点击 **Refresh**，再点击 **Inspect windows**。权限归属可能受启动进程影响，因此建议优先通过 `.app` 界面检查。诊断不会自动刷新、将报告写入文件或发送到网络。组合编辑及应用启动不扫描窗口。

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

2026-08-27 当前界面与崩溃修复检查：

- 此前 49 项测试覆盖草稿取消、持久化、应用枚举、国际化及面板配置。2026-08-28 的操作与比例改动新增了激活/新建分离、首次启动、逐组新建、明确失败、菜单命令匹配、比例兼容、勾选不启动及图标点击区域测试。
- debug 应用已沿用固定开发签名构建。
- 真实界面已显示中文控制中心及独立毛玻璃展示面板；连续 8 次新建后取消正常。展示面板失焦后返回控制中心，面板不再保持展开。
- 旧崩溃报告指向编辑弹窗关闭时对空草稿的强制解包绑定，现改为编辑器持有独立可观察草稿引用。这不代表已经证明所有操作都不会崩溃。
- 本轮尚未实测真实组合的端到端保存/启动、语言切换、Dock 右键菜单、边缘触发、全局快捷键及原生 Split View，单元测试不能代替这些检查。

2026-08-27 历史工作区检查（界面拆分及崩溃修复前，未证明编辑器稳定性）：

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
4. 验证边缘触发、快捷键及多显示器行为。收起规则已确定为失焦自动折叠。
5. 应用组合持久化、编辑及启动已实现；指定项目打开及原生 Split View 尚未完成，打开应用不等于这些需求完成。

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
