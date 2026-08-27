# Twist Spaces

[English](README.md) | [简体中文](README.zh-CN.md)

An extensible, personal macOS workspace manager built with Swift 6.1, SwiftUI, and AppKit. Requires macOS 15 or later. No third-party dependencies.

## Current scope

The app has two separate interfaces: a Control Center for editing and settings, and a translucent desktop display panel for selecting and opening combinations. Native Split View is not yet implemented.

- A native Swift Package executable and a script that builds a local `.app` bundle.
- A regular Dock app opens the Control Center. Left-clicking the menu bar icon toggles the display panel; right-clicking opens its menu. Diagnostics lives under **Developer** in debug builds only.
- Real combination creation and editing: a name, two applications, and an optional project-folder note. Choose installed or running applications, or browse for an app elsewhere; window or thread discovery is not required. No sample combinations are inserted.
- Atomic local persistence at `~/Library/Application Support/Twist Spaces/workspaces.json`. Corrupt or unsupported files block saving instead of being overwritten.
- Separate **Start or activate** and **New windows** icon buttons, with both batch actions. Activation deduplicates shared apps; new-window requests run for each side of each selected group. A stopped app starts once; a running app receives one supported native New Window command. Missing apps block the batch, and unsupported commands fail visibly without substituting activation or extra app processes.
- The card's left content area toggles selection without launching; action buttons have 36 pt hit targets, application icons are 32 pt, and cards preview the saved left/right percentages. Edit the split ratio from 10:90 to 90:10; older combinations default to 50:50. The ratio is stored, not applied to native Split View yet.
- Configurable left/right edge, width, opt-in edge activation and Control–Option–Space. The display panel defaults to 460 pt wide with a 12 pt screen inset. Its native HUD material blurs behind the window at full alpha, rather than exposing sharp desktop content through a faded overlay. It opens on the pointer's display and collapses when it loses focus.
- All dropdowns share a native picker component with consistent label alignment and bounded control widths. Display and language settings share the same page layout; sliders expand with the window. The interim 340 pt default migrates once to 460 pt; other custom widths and trigger settings are retained.
- A custom application icon for Finder and macOS application listings; the menu bar symbol remains unchanged.
- Read-only enumeration of running GUI applications with their actual process IDs, bundle identifiers, and bundle paths.
- After explicit Accessibility authorization, inspection of the selected application's window titles, document attributes, identifiers, positions, sizes, minimized states, and available button actions.
- A copy button at the upper-right of the report area that copies the complete diagnostic text, regardless of scrolling or text selection, and confirms a successful copy.
- English and Simplified Chinese UI, selectable in the Control Center with a follow-system option. Text uses native `Localizable.strings` keys. Comments and scripts use English; this README defaults to English.

The app does not automatically request permissions, open specific project windows, move/resize or close other applications' windows, access application databases, call private Spaces APIs, or substitute ordinary desktop tiling for native Split View.

Diagnostics remains a separate development tool. Existing saved window metadata is preserved when its application is unchanged; the current opening action uses applications, not window bindings. Native Split View remains the saved target layout, but automatic pairing and project reopening are not implemented.

## Build and launch

Use the existing Command Line Tools. No package manager or third-party installation is required. From the project root:

```bash
bash claude_jobs/build-app.sh
open "build/debug/Twist Spaces.app"
```

The app opens the Control Center and keeps both Dock and menu bar entries. Click the Dock icon to reopen the Control Center; left-click the menu bar icon to toggle the display panel. The right-click menu includes both interfaces, debug-only **Developer > Window Diagnostics…**, and **Quit Twist Spaces**. Dock **Quit**, the application menu **Quit Twist Spaces**, and in-app ⌘Q terminate the same application. Closing a window or collapsing the panel does not quit.

The fixed signing identity is already configured on this Mac. Do not rerun signing setup for normal builds. After every build, quit the old process through its menu, then run the `open` command above. **Refresh** reads window state; it does not compile or load a new executable.

## Workspace workflow

1. In the Control Center, choose **New combination**, enter a name, and select two applications. A project-folder note is optional and does not control launching.
2. Save the combination. Use **Edit** to change it later; Accessibility authorization is not required.
3. Open the display panel from the menu bar or **Show panel**. Click a card's left area to select it. The arrow starts/activates its apps; the plus-window icon requests new windows. The footer offers both actions for selected groups.
4. Use the Control Center's **Language** tab to switch between English, Simplified Chinese, or the system language. The choice is saved.

Application choices merge standard application directories (`/Applications`, `~/Applications`, `/System/Applications`, and `/System/Library/CoreServices/Applications`), running applications, and saved selections. Nested application helpers and background-only bundles are excluded; apps elsewhere can be selected with Browse. The list shows bundle-declared alternate names as well as the display name: this Mac's `ChatGPT.app` declares `Codex` as an alternate name. Selection and deduplication use bundle ID plus path, not the displayed name. Window titles and conversation threads are not used for saving or launching. Opening applications is not proof that the intended project windows are open or paired.

New windows in running apps require existing Accessibility permission. The app looks for an enabled, unambiguous top-level New Window command in English or Chinese, not a generic Cmd-N shortcut. It presses once and checks for a new standard AX window; timeouts are not retried automatically. If creation cannot be confirmed, inspect the target app before retrying. No project-folder route, conversation creation, ordinary window tiling, or native Split View is implied. Cursor's actual New Window menu was observed; automated operation of the Codex host is restricted in this environment, so its end-to-end creation remains unverified.

In the Control Center's display settings, edge and shortcut activation are off until enabled. Edge activation uses 2 pt on the selected side of the pointer's display, excluding the menu bar and Dock areas, with a configurable delay. Settings apply immediately. The display panel collapses on loss of focus; moving the pointer alone does not dismiss it.

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

In the diagnostics GUI, select an application. If access is missing, click **Request accessibility access…**, authorize Twist Spaces in System Settings, return to the app, click **Refresh**, and then choose **Inspect windows**. Permission attribution can depend on the launching process, so prefer inspection from the `.app` GUI. Diagnostics does not automatically refresh or save reports to disk, or send them over the network. Combination editing and application launching do not scan windows.

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

Current interface and action checks on 2026-08-28:

- All 60 Swift tests passed. The 11 new tests cover separate activate/new paths, cold startup, per-group creation, explicit failures, menu command matching, ratio compatibility, selection-only clicks, and larger icon hit targets; the earlier 49 tests are retained.
- The debug app was built and strictly verified using the existing fixed signing identity. The previous process was quit through the app menu, confirmed stopped, and the new bundle was opened.
- The real UI showed separate activate/new icon buttons and ratio previews. Selecting and deselecting a card updated both batch buttons without launching applications. The editor slider updated its draft from 50:50 to 55:45; the test draft was cancelled without saving.
- The real UI displayed a Chinese Control Center and a separate translucent display panel. Eight consecutive new/cancel cycles completed; switching focus away from the display panel returned to the Control Center without the panel remaining open.
- The earlier crash reports identify an invalid force-unwrapped optional draft binding during sheet dismissal. The editor now retains its own observable draft reference. No claim of exhaustive crash-free operation is made.
- End-to-end saving/launching real combinations, language switching, Dock's context menu, edge activation, the global shortcut, and native Split View remain unverified in this pass. Unit tests do not substitute for those checks.

Historical workspace checks on 2026-08-27 (before the interface split and crash fix; these did not establish editor stability):

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
4. Verify edge activation, shortcut, and multiple-display behavior. The agreed dismissal rule is collapse on loss of focus.
5. Application-combination persistence, editing, and launching are implemented. Specific project opening and native Split View remain incomplete; application launch is not completion of those requirements.

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
