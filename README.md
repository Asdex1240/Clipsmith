# Clipsmith

[![CI](https://github.com/Asdex1240/Clipsmith/actions/workflows/ci.yml/badge.svg)](https://github.com/Asdex1240/Clipsmith/actions/workflows/ci.yml)

A fast, local video editor for macOS, inspired by CapCut and built for editing vlogs: trim raw footage, cut silences and mistakes, arrange clips, add text and music, and export to MP4.

> **Status:** early development. The features below are implemented, but the app is still evolving and may change between versions.

## What the editor has today

### Projects and media
- **Projects** — create, save and open projects (`.clipsmith` files, JSON), with undo/redo, autosave recovery and relinking of moved or missing media.
- **Media library** — import by button or by dropping files on the panel; search, filter by kind (video, audio, images) and sort. Show media as a grid of same-size cards or as a compact list; vertical and horizontal videos show in full and nothing is cropped. Clipsmith remembers which view you chose. **Remove from Library** (right-click) only removes the item from the list, never the file on disk. If the timeline uses the item, Clipsmith asks first and keeps those clips where they are.

### Editing
- **Timeline** — move, trim, split and delete clips (select several with `⇧`/`⌘`-click and group them), with as many video, audio and text tracks as you need (the higher a video track, the more on top), zoom, a draggable playhead and snapping. Clips show frame thumbnails and waveforms, and each track can be muted, hidden or locked.
- **Silence removal** — find the silent stretches of a clip from its waveform (adjustable volume threshold and minimum length), review the proposed cuts, then cut them and close the gaps in one undoable step.
- **Speed** — play a clip from 0.25× to 4×; its length on the timeline follows. A one-click *slow-motion moment* slows a stretch down smoothly and speeds back up.
- **Transitions** — dissolve, fade through black or slide between touching clips.
- **Animation** — keyframes for position, size, rotation and opacity, edited at the playhead, with easing curves.

### Picture
- **Canvas** — the project's work area: presets (16:9, 9:16, 1:1, 4:5, 3:4, 4:3, 21:9), any custom width × height, a resolution shortcut (720p–4K) and automatic matching to the first clip you add. Each clip can be framed as *Fit* (bars), *Fill* (crop) or *Blur* (the whole clip over a blurred copy of itself).
- **Color and crop** — brightness, contrast, saturation, temperature, one-click looks and a per-side crop.
- **Stabilization** — smooths hand-held shaking by analyzing the shot and reframing it slightly; light, normal and strong settings.
- **Background** — find the people in a shot (Vision) and remove or blur everything behind them; removing shows the tracks below, such as B-roll.

### Text and subtitles
- **Text** — text layers with font, size, color, position, outline, background box, shadow and entrance/exit animations.
- **Titles** — a Titles tab with ready-made styles (title, lower third, location, chapter, caption) that add an animated title at the playhead.
- **Subtitles** — generate text clips from the speech in a clip, on device where the language allows (needs the packaged app, see below). Optionally highlight each word as it is spoken.

### Audio
- **Audio** — per-clip volume, fade in/out, visible waveforms, one-click volume normalization, automatic lowering of music (or any audio clip) under the speech of the main track, and noise reduction for steady background noise such as wind, hum or hiss.

### Short-form video (TikTok, Reels, Shorts)
- **Highlights** — mark ranges of a vlog as clips (in/out points), reframe each one to vertical 9:16 (fill the screen by hand or following the face, or keep the whole shot over a blurred background) and export several at once as separate MP4 files. Each highlight can be previewed in vertical before exporting. The framing can be animated with keyframes, or follow the face over time. Clipsmith can also suggest highlights from the most active stretches of a clip's audio.

### Preview and export
- **Preview** — real-time playback and scrubbing. Floating playback controls (step, scrub, timecode) fade away while you play and stay visible while the pointer is over them. Optional guides show the safe areas. A quality menu renders the preview at half or quarter resolution when a project is heavy; the export always uses full quality. *Fast preview* plays a lighter 720p copy of videos larger than Full HD while you edit; the export always uses the originals.
- **External display preview** — with more than one display connected, a button in the preview bar (or **View → Preview on External Display**) shows the preview full screen on another display, in sync with the editor and without controls or guides. With three or more displays you pick which one. It closes on its own if that display is disconnected.
- **Export** — MP4 (H.264 / HEVC) at 720p, 1080p, 1440p, 4K or exactly the canvas size, with configurable frame rate and 16:9 / 9:16 presets.

### Interface
A native macOS look (translucent materials, Liquid Glass on macOS 26) in light and dark mode, collapsible library and inspector panels, a grouped toolbar, illustrated empty states, text contrast checked against the system backgrounds, and support for the Reduce Motion and Reduce Transparency settings. Bilingual: English and Spanish.

Everything runs locally; there is no backend and no account.

Lighter copies of 4K videos and cleaned audio are cached so they are not made twice. Files unused for 30 days are removed automatically, the cache is capped at 5 GB, and **Clipsmith → Settings** (`⌘,`) shows its size and lets you clear it.

## Coming soon

What is next for the editor:

- **A signed and notarized app** — a Developer ID build that opens on any Mac without extra steps (today the packaged app is ad-hoc signed and runs on the Mac that built it).
- **Polish from real-world use** — adjustments to the newest features (background removal, stabilization, vertical framing) once they have been tried on real vlogs and different kinds of footage.
- **Screenshots and a short demo** in this README.

Ideas under consideration, not committed yet:

- **Built-in music** — royalty-free tracks to drop under a vlog (this depends on finding material with a suitable license).
- **Stickers and emoji** — overlays with the same entrance and exit animations as the titles.
- **Custom GPU effects** — extra looks and effects beyond the current color controls.

## Requirements

- macOS 14 or later (Apple Silicon)
- Swift 6 toolchain (Xcode 16 or later; the project is developed with Swift 6.3 / Xcode 26), which includes `swift format`

## Getting started

```bash
git clone https://github.com/Asdex1240/Clipsmith.git
cd Clipsmith

swift run          # build and launch the app
swift test         # run the unit tests
./scripts/install-hooks.sh # check formatting and comments before each commit
open Package.swift # open the project in Xcode
```

## Keyboard shortcuts

| Action | Key |
|--------|-----|
| Play / pause | `Space` |
| Split at playhead | `S` |
| Add text / marker | `T` / `M` |
| Trim start / end to playhead | `Q` / `W` |
| Copy / cut / paste / duplicate clip | `⌘C` / `⌘X` / `⌘V` / `⌘D` |
| Select all / group / ungroup | `⌘A` / `⌘G` / `⇧⌘G` |
| Toggle snapping | `N` |
| Mark highlight start / end / save | `I` / `O` / `H` |
| Delete / ripple delete | `⌫` / `⇧⌫` |
| Previous / next frame | `←` / `→` |
| Back / forward 1 second | `⇧←` / `⇧→` |
| Previous / next cut | `⌥←` / `⌥→` |
| Go to start / end | `Home` / `End` |
| Zoom in / out | `+` / `-` (or `⌘` + scroll over the timeline) |
| Deselect | `Esc` |
| Undo / redo | `⌘Z` / `⇧⌘Z` |
| Export | `⌘E` |
| Show or hide the library / the inspector | `⌥⌘1` / `⌥⌘2` |
| Preview on an external display | `⌥⌘P` |

Ripple delete (`⇧⌫`) on a clip of the main track closes the gap on every track, so music, text and subtitles stay in sync (clips inside the removed stretch are cut out); on any other track it only moves that track.

Single-key shortcuts are ignored while you type in a text field. **Help → Keyboard Shortcuts** lists them all.

## Building the app

```bash
Packaging/build-app.sh
```

This produces `build/Clipsmith.app` (Apple Silicon, ad-hoc signed, runs on the machine that built it). Options are passed as environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `VERSION` / `BUILD_NUMBER` | `0.1.0` / `1` | Version shown by macOS |
| `BUNDLE_ID` | `dev.clipsmith.Clipsmith` | Change it to an identifier you own |
| `SIGN_IDENTITY` | `-` (ad-hoc) | A `Developer ID Application` identity to sign for distribution |
| `MAKE_ZIP` | `0` | Set to `1` to also create a `.zip` |

Subtitles only work from this packaged app: macOS asks for speech-recognition permission the first time, and `swift run` has no app bundle to ask with.

To distribute the app to other people it must be signed with a Developer ID and notarized:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" MAKE_ZIP=1 Packaging/build-app.sh
xcrun notarytool submit build/Clipsmith-0.1.0.zip --keychain-profile "<profile>" --wait
xcrun stapler staple build/Clipsmith.app
```

The app icon is generated by `Packaging/make-icon.swift`.

## Performance

Measured on an Apple Silicon Mac with a synthetic 4K HEVC source (cuts, B-roll, title and music with fades, 22 s timeline): a 1080p H.264 export takes about 0.3× the video duration, and a 4K HEVC export about 0.6×. To reproduce:

```bash
CLIPSMITH_BENCHMARK=1 swift test --filter PerformanceBenchmarkTests
```

## Project structure

```
Sources/Clipsmith/
├── Models/       # Codable project model (Project, Track, Clip, Highlight): the source of truth
├── Stores/       # Observable state: project, media library, player, export, subtitles
├── Persistence/  # Project files, media bookmarks, crash recovery
├── Engine/       # AVFoundation composition, effects, preview, export, subtitles
├── Views/        # SwiftUI: library, preview, timeline, inspector, highlights, export
└── Resources/    # Localizable.strings (en, es)
Packaging/        # Scripts and metadata to build the .app
Tests/ClipsmithTests/
```

The project model is independent of the playback engine. Preview and export both build their `AVMutableComposition` from the same model.

## Tech stack

Swift, SwiftUI and AppKit, AVFoundation (playback, composition, export), Core Image (color, blur, compositing), Vision (people, faces and stabilization) and Speech (subtitles). No third-party dependencies.

The app is bilingual (English and Spanish). Coding conventions live in [CODE_RULES.md](CODE_RULES.md) (in Spanish).

## Contributing

Issues and pull requests are welcome. Every pull request runs the CI (formatting, no comments in the code, build and tests). Before submitting changes:

- Enable the Git hooks once with `./scripts/install-hooks.sh`. Before each commit, they check the formatting and reject comments in the code.
- Format with `swift format format --configuration .swift-format -i -r Sources Tests`.
- Run `swift test`.
- Add every new user-facing text to both `en.lproj` and `es.lproj`; a test checks that both files have the same keys.

The full conventions are in [CODE_RULES.md](CODE_RULES.md).

## License

Released under the [MIT License](LICENSE).
