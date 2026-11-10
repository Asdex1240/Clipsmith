# Clipsmith

A fast, local video editor for macOS, inspired by CapCut and built for editing vlogs: trim raw footage, cut silences and mistakes, arrange clips, add text and music, and export to MP4.

> **Status:** early development. The app currently opens an empty editor window; features land milestone by milestone.

## Features

Planned for the first release:

- **Projects** — create, save and open projects, with undo/redo.
- **Media library** — import video, audio and images with thumbnails and durations.
- **Timeline** — move, trim, split and delete clips, with a B-roll track, zoom, a draggable playhead and snapping.
- **Preview** — real-time playback and scrubbing.
- **Text** — text layers with font, size, color and position.
- **Audio** — per-clip volume, fade in/out and visible waveforms.
- **Export** — MP4 (H.264 / HEVC) with configurable resolution and frame rate, including 16:9 and 9:16 presets.

Everything runs locally; there is no backend and no account.

## Requirements

- macOS 14 or later (Apple Silicon)
- Swift 6 toolchain (Xcode 16 or later)

## Getting started

```bash
git clone <repository-url>
cd Clipsmith

swift run          # build and launch the app
swift test         # run the unit tests
open Package.swift # open the project in Xcode
```

## Project structure

```
Sources/Clipsmith/
├── Models/   # Codable project model (Project, Track, Clip): the source of truth
├── Engine/   # AVFoundation composition, preview and export
└── Views/    # SwiftUI: library, preview, timeline, inspector
Tests/ClipsmithTests/
```

The project model is independent of the playback engine. Preview and export both build their `AVMutableComposition` from the same model.

## Tech stack

Swift, SwiftUI, AVFoundation, Metal / Core Image.

## Contributing

Issues and pull requests are welcome. Please run `swift test` before submitting changes.
