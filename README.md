<div align="left">

# Ecilaes
**A local-first, cross-platform music player.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform: Android | Linux](https://img.shields.io/badge/Platform-Android%20%7C%20Linux-green.svg)]()
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg?logo=flutter)](https://flutter.dev)

</div>

Ecilaes is an music player built with Flutter, seamlessly unifies your local music library and YouTube Music.

##  Features
*   **Synced lyrics**: fetched from LRCLib, BetterLyrics and KuGou with optional Romanization for international tracks.
*   **Dynamic Theming:** Extracts a primary color palette from the currently playing album art to dynamically theme the entire application using `palette_generator` (when using Material 3 Color Style).  
*   **Color Style:** Choose between Material 3 or "eclipx" color.
*   **YouTube Music integration**: Intergrate with YouTube Music for online music provider, allows signing in
*   **Last.fm intergration**: scrobbling for the nerds out there
*   **Highly Configurable:** Drag-and-drop to reorder player bar actions, context menu items, and sidebar navigation links. Customize text scales, background blur, and more.
*   And more...

### Platform Integrations
*   **Android:** Comes with a custom-built Kotlin Home Screen Widget, showing the current playing track.
*   **Desktop (Linux/Windows):** Custom Windows controls (CSD), system tray integration, single-instance locking, translucent window backgrounds (acrylic blur), and Discord Rich Presence.
*   **Scrobbling:** Integrated Last.fm scrobbling support.

## Getting Started

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

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
