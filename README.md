# Twist Spaces

[English](README.md) | [简体中文](README.zh-CN.md)

An extensible, personal macOS workspace manager built with Swift 6.1, SwiftUI, and AppKit. Requires macOS 15 or later. No third-party dependencies.

## Current scope

This is the initial project scaffold and a capability inspection tool, not a complete workspace manager:

- A native Swift Package executable and a script that builds a local `.app` bundle.
- A menu bar entry that opens a separate window diagnostics tool.
- A custom application icon for Finder and macOS application listings; the menu bar symbol remains unchanged.
- Read-only enumeration of running GUI applications with their actual process IDs, bundle identifiers, and bundle paths.
- After explicit Accessibility authorization, inspection of the selected application's window titles, document attributes, identifiers, positions, sizes, minimized states, and available button actions.
- A copy button at the upper-right of the report area that copies the complete diagnostic text, regardless of scrolling or text selection, and confirms a successful copy.
- UI text resolved through native `Localizable.strings` keys. English is the default language; only `en` source resources are included. Code comments and scripts use English. The README is available in English and Simplified Chinese, with English as the default.

The app does not automatically request permissions, open projects, move or close other applications' windows, access application databases, call private Spaces APIs, or substitute ordinary desktop tiling for native Split View.

The diagnostics window is a development tool, not the final translucent edge panel. Its dimensions and opening/closing behavior do not establish the final panel's design.

## Build and launch

Use the existing Command Line Tools. No package manager or third-party installation is required. From the project root:

```bash
bash claude_jobs/build-app.sh
open "build/debug/Twist Spaces.app"
```

The app displays a menu bar icon without automatically opening a window. Click the icon and choose **Window Diagnostics…**. Closing that window leaves the app running in the menu bar. Choose **Quit Twist Spaces** to exit.

Build a release bundle:

```bash
bash claude_jobs/build-app.sh release
```

Build artifacts go into `build/`; caches and temporary build files stay in `.build/`. Both directories are ignored by Git. The script only applies a local ad-hoc signature. It does not install into `/Applications`, obtain certificates, notarize the app, or configure launch at login. Rebuilding or moving the app may require renewing Accessibility authorization. This is not a distribution signature.

## Version management

Edit [version.json](version.json) in the project root. It is the only source of application version values:

```json
{
  "version": "0.1.0",
  "build": 1
}
```

- `version`: the user-facing version, written to `CFBundleShortVersionString`. Use a string with three numeric components, such as `0.1.0` or `1.2.3`.
- `build`: the build number, written to `CFBundleVersion` as a string in the app bundle. Use a positive JSON integer.

After editing, run `bash claude_jobs/build-app.sh` or `bash claude_jobs/build-app.sh release`. Both configurations read the same JSON file and write the values into the generated `.app/Contents/Info.plist` before signing. The source `App/Info.plist` does not contain duplicate version values and is not rewritten by the build. Version numbers are never incremented automatically. Missing or invalid values stop the build before compilation.

Saving the JSON alone does not update an existing or running app; rebuild, then quit and reopen the app to use the new bundle.

## Read-only inspection

```bash
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --help
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --list-apps
```

Get a process ID from the application list, then replace `12345` below with that PID:

```bash
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --inspect 12345
```

The CLI never displays a permission prompt. Exit codes: `0` means completed, `1` indicates an application or inspection error, `2` means Accessibility permission is required, and `64` indicates invalid arguments. A completed inspection does not mean every optional attribute is available; check each attribute's `errorCode` as well.

In the GUI, select an application. If access is missing, click **Request accessibility access…**, authorize Twist Spaces in System Settings, return to the app, click **Refresh**, and then choose **Inspect windows**. Permission attribution can depend on the launching process, so prefer inspection from the `.app` GUI. The app does not automatically refresh windows, save diagnostic reports to disk, or send them over the network.

Diagnostic JSON includes window titles and potentially local project paths. Review it before sharing. Process IDs and window ordinals only identify the current process or report; they are not persistent project identities. Some applications do not expose `AXDocument` or `AXIdentifier`. Failed reads preserve AX error codes, and the tool does not guess project pairings from window titles.

To share a result, click the copy icon at the upper-right of the report area and paste the complete report. **Copied** appears only after the clipboard write succeeds. Copying is disabled while inspecting or when there is no result. Clipboard failures are displayed explicitly, and the existing text-selection behavior is preserved.

After rebuilding an app that is already running, quit Twist Spaces through its menu and reopen the `.app` to load the updated interface. The build script does not restart running applications.

## Application icon

The app icon uses two interleaved blue and violet windows on a dark rounded-square tile. Source artwork, the exported `.icns`, and the generation prompt are in [App/Assets](App/Assets/README.md).

To regenerate the macOS icon sizes from the existing PNG artwork:

```bash
bash claude_jobs/build-icon.sh
bash claude_jobs/build-app.sh
```

This uses the system `sips` and `iconutil` tools, without installing dependencies. Normal builds copy the existing `.icns` into the application bundle.

## Observed local environment

Observed on 2026-08-27: macOS 15.4.1, arm64, Swift 6.1, and the toolchain at `/Library/Developer/CommandLineTools`.

- Cursor: `/Applications/Cursor.app`, bundle identifier `com.todesktop.230313mzl4w4u92`. The bundle includes the Cursor CLI and declares the `cursor` URL scheme. Opening a specific project has not been tested.
- Current Codex host: `/Applications/ChatGPT.app`, bundle identifier `com.openai.codex`, with a declared `codex` URL scheme. A registered scheme alone does not establish support for opening a particular project in a new window; route semantics remain unverified.

These are local observations, not hardcoded paths or automatic pairing rules.

## Tests and verification

Run the tests with the system-provided Swift Testing framework:

```bash
swift test --disable-xctest
```

The tests cover separate process identities, diagnostic JSON and attribute error preservation, permission-blocked versus empty reports, English resources, missing localization keys, and copying complete reports. Clipboard tests use private pasteboards and do not modify the user's general clipboard. They do not inspect real windows or request permissions. XCTest is disabled because this project uses Swift Testing and does not require full Xcode.

Initialization checks on 2026-08-27:

- The debug arm64 `.app` compiled, passed strict signature verification, and loaded its packaged English resources.
- All five Swift tests and seven CLI argument/error checks passed.
- Outside the development sandbox, the CLI enumerated 11 running GUI applications and identified Cursor and Codex by bundle identifier.
- Both target inspections returned exit code `2`: Twist Spaces has not been granted Accessibility access. Actual window reads and native Split View pairing remain unverified.
- The menu bar and diagnostics GUI have not yet been visually verified.

## Remaining verification and decisions

1. Inspect real Cursor and Codex windows and determine whether different projects can be identified reliably.
2. Decide whether to reuse existing windows or open new ones, then verify how to open the intended project window.
3. Verify whether public Accessibility operations can pair the selected windows in native fullscreen Split View. This is neither implemented nor verified yet.
4. Confirm the final edge panel's width, dismissal rules, edge activation area and delay, shortcut, and multiple-display behavior.
5. Once the core capabilities are established, implement workspace persistence, editing, grouping, and batch opening.

Apple distinguishes native Split View from ordinary desktop window tiling; Split View creates a new desktop space. Exposing actions such as `AXPress` does not prove that two specific windows can be paired automatically. The tool therefore does not report native Split View support based on button availability. References: [Apple Split View guide](https://support.apple.com/en-ca/guide/mac-help/mchl4fbe2921/mac), [Accessibility authorization API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions), and [Accessibility attribute API](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue).

## Project structure

```text
App/Info.plist                 Application bundle metadata
App/Assets/                    Source artwork, macOS icon, and generation prompt
Package.swift                  Native Swift Package entry point
version.json                   Single source for the application version and build number
Sources/TwistSpaces/App/       App lifecycle and menu bar
Sources/TwistSpaces/Features/  Diagnostics window and view model
Sources/TwistSpaces/Models/    Read-only reports, not workspace persistence schemas
Sources/TwistSpaces/Services/  Application catalog, permission checks, and AX inspection
Sources/TwistSpaces/Resources/ Native localization resources
Tests/TwistSpacesTests/        Basic tests using Swift Testing
claude_jobs/build-app.sh       Build, bundle, and local signing
claude_jobs/build-icon.sh      Export macOS icon sizes from the approved PNG
```

The `temp/` directory is reserved for requirements maintained manually by the user. Neither app code nor the build process writes there. Adding it to `.gitignore` does not unstage or untrack existing files; Git state is managed by the user.
