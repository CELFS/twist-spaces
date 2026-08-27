# Application icon

`AppIcon.png` is the source artwork generated with built-in Codex ImageGen. `AppIcon.icns` is the macOS application icon bundled through `CFBundleIconFile`.

The source is a 1254 × 1254 PNG with alpha. Export the standard 16, 32, 128, 256, and 512 point representations at 1x and 2x using the macOS tools already installed:

```bash
bash claude_jobs/build-icon.sh
bash claude_jobs/build-app.sh
```

Intermediate PNG sizes are written to `.build/AppIcon.iconset`. The generated `.icns` is kept here so normal app builds do not need to regenerate artwork. The separate menu bar symbol and the app's accessory activation policy are unchanged.

## Generation prompt

```text
Create one finished macOS application icon for an app called Twist Spaces, a personal workspace manager that pairs project windows. The approved design is a dark rounded-square base with two interleaved blue and violet application-window shapes. Make a bold, memorable minimalist mark: a luminous cyan/blue upright window offset upper-left and a violet/purple upright window offset lower-right, their thick rounded rectangular frames interlocking with an elegant small twist at the overlap, communicating two paired workspaces. Subtle translucent material and restrained edge highlights, rich near-black charcoal/navy squircle base, generous margins, clean optical balance, readable at 16px and 32px. Center the icon on a square 1024x1024 canvas. The dark rounded-square tile should occupy roughly 86% of canvas width/height, leaving genuinely transparent alpha outside it, not a white background or checkerboard. No text, no letters, no badges, no extra objects, no screenshot, no mockup, no presentation board, no gradients extending outside the tile. Deliver a single polished production icon asset, straight-on, not a perspective scene.
```
