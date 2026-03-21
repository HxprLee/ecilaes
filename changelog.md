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