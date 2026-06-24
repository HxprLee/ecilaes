<div align="center">

# Ecilaes
**A beautiful, local-first, cross-platform music player.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform: Android | Linux](https://img.shields.io/badge/Platform-Android%20%7C%20Linux-green.svg)]()
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg?logo=flutter)](https://flutter.dev)

</div>

Ecilaes (pronounced *e-seal-eyes*, "sealice" spelled backwards) is an elegant music player built with Flutter. It seamlessly unifies your local music library and YouTube Music behind a fluid Material 3 interface, bringing all your tunes together without compromise.

## ✨ Features

### Core Experience
*   **Unified Library:** Browse local files (MP3, FLAC, M4A, OGG) and streaming tracks from YouTube Music in the same sleek UI.
*   **Discover Music:** Deep integration with YouTube Music's Explore API—browse moods, genres, new releases, and trending charts.
*   **Stream Caching:** YouTube streams are cached to disk transparently, allowing for instant replay and offline playback.
*   **Advanced Audio Engine:** Powered by `just_audio` and `media_kit` (MPV backend), featuring gapless playback support, LUFS audio normalization, and a fully functional 10-band equalizer (if backend supported).
*   **Synced Lyrics:** Real-time synced lyrics fetched from LRCLib, SimpMusic, KuGou, and BetterLyrics, complete with optional Romanization for international tracks.

### Design & Customization
*   **Dynamic Theming:** Extracts a primary color palette from the currently playing album art to dynamically theme the entire application using `palette_generator`.
*   **Signature Style:** Choose between standard Material 3 or the custom "eclipx" signature aesthetic.
*   **Morphing Player:** A highly responsive, stateful expandable player that hosts lyrics, up-next queue, and interactive song actions.
*   **Highly Configurable:** Drag-and-drop to reorder player bar actions, context menu items, and sidebar navigation links. Customize text scales, background blur, and more.

### Platform Integrations
*   **Android:** Comes with a custom-built Kotlin Home Screen Widget (`es.antonborri.home_widget`) reflecting the currently playing track.
*   **Desktop (Linux/Windows/macOS):** Native window controls, system tray integration, single-instance locking, translucent window backgrounds (acrylic blur), and Discord Rich Presence.
*   **Scrobbling:** Fully integrated Last.fm scrobbling support (Now Playing updates and track scrobbles).

## 🚀 Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.1 or higher)
*   **Android:** Android Studio and SDK toolchain.
*   **Linux:** Clang, CMake, Ninja, `pkg-config`, `libgtk-3-dev`. 
    *   To build an AppImage, you'll also need `appimagetool`.

### Building the App

1. Clone the repository:
   ```bash
   git clone https://github.com/hxprlee/ecilaes.git
   cd ecilaes
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run locally for development:
   ```bash
   flutter run
   ```

4. Build production releases:
   *   **Android APK:**
       ```bash
       flutter build apk --release --split-per-abi
       ```
   *   **Linux AppImage:**
       ```bash
       bash scripts/build_all.sh --skip-android
       ```

## 🏗️ Architecture Overview

Ecilaes relies heavily on reactive state management via `signals_flutter` to decouple the UI from backend services. 

*   **Signals (`lib/signals/`)**: Reactive singletons representing the source of truth (`AudioSignal` for playback, `SettingsSignal` for preferences, `QueueSignal` for queue management, `SearchSignal` for YouTube explore APIs).
*   **Services (`lib/services/`)**: Framework-agnostic background utilities (Disk caching, Metadata extraction, HTTP requests, Last.fm integrations). 
*   **Widgets (`lib/widgets/`)**: Reusable UI components. Local ephemeral state is managed with simple `setState`, while global properties use `Watch((context) => ...)`.

For a more in-depth look at contributing and the code architecture, please refer to the [`AGENTS.md`](AGENTS.md) file.

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
