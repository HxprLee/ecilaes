# Changelog - 2026-03-30

### Added

- **Sidebar Customization**: Added the ability to manage and reorder library sections in the sidebar from the Customization hub.
- **Playback Caching and Pre-Caching**: Added caching for YouTube Music playbacks for faster loading when playing the songs again.

### Changed
- **Customization Page**: Change "Appearance" section to "Customization" section in Settings to include more customization options.
- **Decoupling Library UI**: Decoupled library UI from the main app shell, allowing for more flexible layout configurations.
- **Improved Settings Navigation**: Migrated all UI-related settings (Themes, Lyrics typography, and Layouts) into the Customization page.

### Fixed
- **Persistent Grid/List Toggles**: Resolved an issue where library view toggles became unresponsive after the first interaction.
- **Player Bar Customization**: Fixed a routing issue that prevented "Player Bar Layout" settings from correctly applying to the UI.

---

# Changelog - 2026-03-24

### Added
- **YouTube Music Pages**: Added dedicated screens for YouTube Music Explore/Home, Albums, Artists, and Playlists.
- **YouTube Music Search Suggestions**: Added search suggestions with dropdown overlay for desktop and a full-page suggestion for mobile.
- **Improved Discord RPC Integration**: Discord now displays a progress bar just like Spotify or other app's implementation.

### Changed
- **Better Marquee effect**: Replaced custom marquee text with `package:marquee` for improved stability, handling, and trailing removal on short titles.
- **Improved YouTube Artwork**: YouTube Music artwork is now pre-cached, stored locally and instantly mapped, ensuring it appears consistently everywhere, especially for the widget and the media controls of Android.
- **Bumped Flutter version**: Bumped Flutter to version 3.41.5.

### Fixed
- **PageHeader Scroll Gap**: Resolved a layout issue where a large gap was left between the header bar and content when scrolling down on search and library pages.
- **YouTube Artist Parsing**: Fixed the "Unknown" artist result bug in YouTube searches by resolving missing metadata mapping keys.
- **Grid Layout Spacing**: Added proper bottom padding to the "Recently Played" and "Recently Added" grid views to prevent the player bar from obscuring list items.

---

# Changelog - 2026-03-19

### Added
- **Lyrics Support**: Added support for LRC lyrics files and plain text lyrics, it will check for LRC file first, if not found, it will search in lrclib.net online lyrics provider.
- **Custom Lyrics Typography**: Added a dedicated setting in the Lyrics Appearance section, allowing independent font size control for synced and non-synced lyrics.
- **Mini Player Marquee**: The song title in the collapsed player bar now features a marquee effect.
- **Experimental YouTube playback**: Added support for YouTube playback, the current way to play a YouTube audio now is to search a song in the search page on the "YouTube" tab.
- **Song Info**: Added a new Popup to display song information, access by clicking more button in the player bar.

### Changed
- **Metadata Engine Migration**: Replaced `metadata_god` dependency with `audio_metadata_reader`. Improved indexing speed by a LOT.
- **Consistent Title Scrolling**: The marquee effect now applies to the **mini player title** as well. No more cut-off text — long song names now scroll elegantly in both collapsed and expanded states.
- **Customizable Player Bar Actions**: The row of buttons in the player bar is now fully personalizable via drag-and-drop in settings.
- **Adaptive Space-Aware Layout**: Implemented an intelligent layout switch that monitors the actual space available for the player bar. If horizontal space drops below **800px** (due to window resizing or the sidebar), the player automatically switches to a compact art-on-left layout to prevent any component overlap.

### Fixed
- **Marquee Overlap**: Resolved a visual bug where long song titles would scroll over the playback icons in the player bar.
- **Refined Color Palette extraction**: Updated the color palette extraction logic to use a more dominant color scheme of the artwork.