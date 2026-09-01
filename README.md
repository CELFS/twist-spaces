<p align="center">
  <img src="App/Assets/AppIcon.png" width="128" alt="Twist Spaces icon">
</p>

<h1 align="center">Twist Spaces</h1>

<p align="center">A native macOS workspace manager for launching application pairs and arranging their windows.</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="LICENSE">MIT License</a>
</p>

![Twist Spaces Control Center and layout panel on the macOS desktop](docs/images/ui-desktop.jpg)

Twist Spaces combines a full Control Center with a compact desktop layout panel. Save frequently used application pairs, choose their Split View ratio, and launch them together from the menu bar or the screen edge.

## Features

- Create reusable combinations with two applications, an optional project-folder note, and a split ratio from 10:90 to 90:10.
- Start or activate both applications, or request a new window from each supported running application.
- Capture the resulting windows, attempt native macOS Split View pairing, and adjust the divider to the saved ratio.
- Launch individual applications from a configurable Quick Launch section.
- Open the layout panel from the menu bar, a screen edge, or Control–Option–Space.
- Configure the panel side, width, edge delay, and global shortcut.
- Store combinations and settings locally with guarded, atomic persistence.
- Use English, Simplified Chinese, or the current system language.

## Interface

### Manage combinations

![Manage application combinations in the Control Center](docs/images/ui-combinations.jpg)

### Create and configure

| Create a combination | Configure the layout panel |
| --- | --- |
| ![Create a two-application combination](docs/images/new-combination.jpg) | ![Configure the layout panel](docs/images/display-settings.jpg) |

## Requirements

- macOS 15 or later
- Swift 6.1 or later from Xcode Command Line Tools or Xcode
- Accessibility permission for new-window detection, window inspection, and native Split View automation

No package manager or third-party library is required.

## Build and run

Clone the repository:

```bash
git clone https://github.com/CELFS/twist-spaces.git
cd twist-spaces
```

Create the local development signing identity once:

```bash
bash claude_jobs/setup-local-signing.sh
```

Build and open the debug application:

```bash
bash claude_jobs/build-app.sh
open "build/debug/Twist Spaces.app"
```

The generated application is written to `build/debug/Twist Spaces.app`. The build script does not install it into `/Applications` or notarize it.

For a release build:

```bash
bash claude_jobs/build-app.sh release
```

The release application is written to `build/release/Twist Spaces.app`.

## Usage

1. Open the Control Center and create a combination with two applications.
2. Set the preferred left/right ratio and save the combination.
3. Open the layout panel, then activate the applications or request new windows.

The optional project-folder field is currently a note and does not reopen a specific project window. Native Split View automation depends on Accessibility permission and compatible actions exposed by the selected applications.

## Test

Run the Swift test suite from the repository root:

```bash
swift test --disable-xctest
```

## Local data

Combinations are stored at:

```text
~/Library/Application Support/Twist Spaces/workspaces.json
```

Twist Spaces does not send workspace data or diagnostic reports over the network.

## License

Twist Spaces is available under the [MIT License](LICENSE).
