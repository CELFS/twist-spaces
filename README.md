# Twist Spaces

[English](README.md) | [简体中文](README.zh-CN.md)

An extensible, personal macOS workspace manager built with Swift 6.1, SwiftUI, and AppKit. Requires macOS 15 or later. No third-party dependencies.

## Current scope

The main entry now opens a native translucent workspace panel. This is a working management slice, not yet the complete project-opening and native Split View workflow:

- A native Swift Package executable and a script that builds a local `.app` bundle.
- A regular Dock app and a menu bar icon. Left-click opens/toggles the workspace panel; right-click opens its menu. Diagnostics lives under **Developer** in debug builds only.
- Real workspace creation and editing: a project folder, name, and explicitly selected left/right Cursor or Codex windows. No sample workspaces are inserted.
- Atomic local persistence at `~/Library/Application Support/Twist Spaces/workspaces.json`. Corrupt or unsupported files block saving instead of being overwritten.
- **Show windows** and **Show selected windows** restore/raise the explicitly bound existing windows. The entire selection is checked before the first window change; an unresolved workspace blocks the batch. This is not project reopening or layout application.
- Configurable left/right edge, width, opt-in edge activation and Control–Option–Space. The panel opens on the pointer's display and stays open until explicitly closed or toggled.
- A custom application icon for Finder and macOS application listings; the menu bar symbol remains unchanged.
- Read-only enumeration of running GUI applications with their actual process IDs, bundle identifiers, and bundle paths.
- After explicit Accessibility authorization, inspection of the selected application's window titles, document attributes, identifiers, positions, sizes, minimized states, and available button actions.
- A copy button at the upper-right of the report area that copies the complete diagnostic text, regardless of scrolling or text selection, and confirms a successful copy.
- UI text resolved through native `Localizable.strings` keys. English is the default language; only `en` source resources are included. Code comments and scripts use English. The README is available in English and Simplified Chinese, with English as the default.

The app does not automatically request permissions, open new project windows, move/resize or close other applications' windows, access application databases, call private Spaces APIs, or substitute ordinary desktop tiling for native Split View. Selecting **Show windows** explicitly authorizes restoring minimized windows and raising that selection only.

The diagnostics window remains a separate development tool. Panel dimensions are configurable implementation values, not a claim that final interaction design has been agreed. Native Split View remains the saved target layout, but automatic pairing and project reopening are not implemented.

## Build and launch

Use the existing Command Line Tools. No package manager or third-party installation is required. From the project root:

```bash
bash claude_jobs/build-app.sh
open "build/debug/Twist Spaces.app"
```

The app opens the workspace panel and keeps both Dock and menu bar entries. Click the Dock icon to reopen the panel; left-click the menu bar icon to toggle it. Right-click the menu bar icon for settings, debug-only **Developer > Window Diagnostics…**, and **Quit Twist Spaces**. Dock **Quit**, the application menu **Quit Twist Spaces**, and in-app ⌘Q terminate the same application. Closing the panel or diagnostics window does not quit.

The fixed signing identity is already configured on this Mac. Do not rerun signing setup for normal builds. After every build, quit the old process through its menu, then run the `open` command above. **Refresh** reads window state; it does not compile or load a new executable.

## Workspace workflow

1. Open the intended Cursor and Codex project windows yourself.
2. Choose **New workspace**, enter a name and project folder, and select the actual left/right windows from the live list. Confirm that both belong to the project, then save.
3. Use **Edit** to change the folder, name, or window pair. Renaming can preserve the stored selection without requiring running applications.
4. Use **Show windows**, or select several cards and choose **Show selected windows**, to bring those existing windows forward. These controls explicitly do not apply Split View.

The project folder is a user-provided association, not inferred from a title. Session bindings retain actual AX elements and revalidate them before use. After a restart, automatic rebinding requires a unique exact document identity plus the saved application and window attributes. A title or AXIdentifier alone is not enough: edit and select the window again. Changes to a window title can also require reselection. The list contains only windows exposed by Accessibility and is not claimed to include every application window.

In **Panel Settings…**, edge and shortcut activation are off until enabled. Edge activation uses 2 pt on the selected side of the pointer's display, excluding the menu bar and Dock areas, with a configurable delay. Click **Done** to apply trigger settings. Neither showing windows nor moving the pointer away closes the panel.

Build a release bundle:

```bash
bash claude_jobs/build-app.sh release
```

Build artifacts go into `build/`; caches and temporary build files stay in `.build/`. Both directories are ignored by Git. One-time signing setup creates or reuses a local development identity in the login keychain and pins its certificate fingerprint in the ignored `signing.local.json`. It restricts certificate trust to code signing for the current user; it does not change TLS trust, system-wide trust, Gatekeeper, or Accessibility permissions. Temporary private-key files are encrypted and removed after setup.

Builds use that same identity and stop if it is unavailable; they never fall back to ad-hoc signing or create replacement certificates. Switching from the old ad-hoc build to this identity requires authorizing the new identity once. Subsequent builds are intended to retain the same code identity, but actual permission retention must be checked on macOS. Neither script installs the app into `/Applications`, notarizes it, or configures launch at login. This is a local development signature, not a distribution signature.

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

## Window inspection

```bash
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --help
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --list-apps
```

Get a process ID from the application list, then replace `12345` below with that PID:

```bash
"build/debug/Twist Spaces.app/Contents/MacOS/TwistSpaces" --inspect 12345
```

The CLI never displays a permission prompt. Exit codes: `0` means completed, `1` indicates an application or inspection error, `2` means Accessibility permission is required, and `64` indicates invalid arguments. A completed inspection does not mean every optional attribute is available; check each attribute's `errorCode` as well.

In the diagnostics GUI, select an application. If access is missing, click **Request accessibility access…**, authorize Twist Spaces in System Settings, return to the app, click **Refresh**, and then choose **Inspect windows**. Permission attribution can depend on the launching process, so prefer inspection from the `.app` GUI. Diagnostics does not automatically refresh or save reports to disk, or send them over the network. The workspace editor reads windows on opening and on explicit refresh; showing saved windows scans again before acting.

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

Compatibility tests use simulated window reads and attribute writes to verify application and permission guards, process identity checks, bounded recovery from empty results, and error preservation. Missing optional window attributes do not trigger recovery. Tests do not enable accessibility in a real application.

Workspace implementation checks on 2026-08-27:

- All 31 Swift tests passed, including the 22 existing tests and nine new workspace tests. New coverage includes persistence/editing, invalid-file protection, exact session bindings, unique document matching, and rejection of title-only rebinding.
- The debug app was built with the existing fixed signing identity and passed strict signature verification outside the restricted tool sandbox.
- The actual app menu's Quit action and in-app ⌘Q were exercised separately; process termination was checked and the new bundle was reopened after each. The workspace panel and creation form were inspected through the real UI; Accessibility remained granted.
- The live editor returned one Cursor window and no Codex/ChatGPT windows. Enumeration is not proven complete. No fabricated workspace was saved to bypass this limitation. End-to-end saving/showing a real Cursor–Codex pair, batch behavior, Dock's right-click menu, edge activation, and the global shortcut remain unverified.
- Project reopening and automatic native Split View are not implemented. The target layout is stored, not executed.

Historical initialization checks (before the workspace implementation) on 2026-08-27:

- The debug arm64 `.app` compiled, passed strict signature verification, and loaded its packaged English resources.
- All five Swift tests and seven CLI argument/error checks passed.
- Outside the development sandbox, the CLI enumerated 11 running GUI applications and identified Cursor and Codex by bundle identifier.
- Both target inspections returned exit code `2`: Twist Spaces has not been granted Accessibility access. Actual window reads and native Split View pairing remain unverified.
- The menu bar and diagnostics GUI have not yet been visually verified.

## Remaining implementation and verification

1. Inspect real Cursor and Codex windows and determine whether different projects can be identified reliably.
2. Decide whether to reuse existing windows or open new ones, then verify how to open the intended project window.
3. Verify whether public Accessibility operations can pair the selected windows in native fullscreen Split View. This is neither implemented nor verified yet.
4. Confirm the final edge panel's width, dismissal rules, edge activation area and delay, shortcut, and multiple-display behavior.
5. Workspace persistence and editing are implemented. Complete true single/batch project opening and native Split View; showing existing windows is not completion of those requirements.

Apple distinguishes native Split View from ordinary desktop window tiling; Split View creates a new desktop space. Exposing actions such as `AXPress` does not prove that two specific windows can be paired automatically. The tool therefore does not report native Split View support based on button availability. References: [Apple Split View guide](https://support.apple.com/en-ca/guide/mac-help/mchl4fbe2921/mac), [Accessibility authorization API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions), and [Accessibility attribute API](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue).

## Project structure

```text
App/Info.plist                 Application bundle metadata
App/Assets/                    Source artwork, macOS icon, and generation prompt
Package.swift                  Native Swift Package entry point
version.json                   Single source for the application version and build number
signing.local.json             Ignored machine-specific signing certificate fingerprint
Sources/TwistSpaces/App/       App lifecycle and menu bar
Sources/TwistSpaces/Features/  Workspace panel, editor, settings, and development diagnostics
Sources/TwistSpaces/Models/    Workspace persistence schema and diagnostic snapshots
Sources/TwistSpaces/Services/  Workspace storage, panel triggers, permissions, and AX window operations
Sources/TwistSpaces/Resources/ Native localization resources
Tests/TwistSpacesTests/        Basic tests using Swift Testing
claude_jobs/build-app.sh       Build, bundle, and local signing
claude_jobs/setup-local-signing.sh One-time local signing identity setup
claude_jobs/build-icon.sh      Export macOS icon sizes from the approved PNG
```

The `temp/` directory is reserved for requirements maintained manually by the user. Neither app code nor the build process writes there. Adding it to `.gitignore` does not unstage or untrack existing files; Git state is managed by the user.
