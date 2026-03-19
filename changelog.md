# Changelog - 2026-03-19

### Added

- **Lyrics Support**: Added support for LRC lyrics files and plain text lyrics, it will check for LRC file first, if not found, it will search in lrclib.net online lyrics provider.
- **Custom Lyrics Typography**: Added a dedicated setting in the Lyrics Appearance section, allowing independent font size control for synced and non-synced lyrics.
- **Mini Player Marquee**: The song title in the collapsed player bar now features a marquee effect.
- **Experimental YouTube playback**: Added support for YouTube playback, the current way to play a YouTube audio now is to search a song in the search page on the "YouTube" tab.
- **Song Info**: Added a new Popup to display song information, access by clicking more button in the player bar.

### Changed
- **Metadata Engine Migration**: Replaced `metadata_god` dependency with `audio_metadata_reader`. Improved indexing speed by a LOT.
- **Refactored Marquee Logic**: Rebuilt the `MarqueeText` widget with a more robust animation loop and better handling of layout constraints and window resizing.
- **Player Bar Layout Optimization**: Increased the reserved width for playback controls in the player bar to 400px on desktop

### Fixed
- **Marquee Overlap**: Resolved a visual bug where long song titles would scroll over the playback icons in the player bar.
- **Refined Color Palette extraction**: Updated the color palette extraction logic to use a more dominant color scheme of the artwork.