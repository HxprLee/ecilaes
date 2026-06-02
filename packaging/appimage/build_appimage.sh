#!/usr/bin/env bash
#
# Build an AppImage for Ecilaes (music_app).
#
# Usage:
#   ./build_appimage.sh [--skip-build]
#
# Prerequisites:
#   - appimagetool (AppImageKit) — https://github.com/AppImage/AppImageKit
#   - rsvg-convert or ImageMagick's convert (for icon generation)
#   - Flutter SDK

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

APP_NAME="Ecilaes"
BINARY_NAME="ecilaes"
APPLICATION_ID="com.example.ecilaes"
VERSION="0.5.0"
ARCH="x86_64"

BUILD_DIR="$PROJECT_DIR/build"
RELEASE_BUNDLE="$BUILD_DIR/linux/x64/release/bundle"
APPDIR="$BUILD_DIR/appimage/$APP_NAME.AppDir"
OUTPUT_DIR="$BUILD_DIR/appimage"
OUTPUT="$OUTPUT_DIR/${APP_NAME}-${VERSION}-${ARCH}.AppImage"

ICON_SRC="$PROJECT_DIR/assets/icons/ic_launcher.png"
ICON_PNG="$APPDIR/${APPLICATION_ID}.png"

# ---------------------------------------------------------------
# Step 1 — Build Flutter Linux release (unless skipped)
# ---------------------------------------------------------------
if [[ "${1:-}" != "--skip-build" ]]; then
  echo "==> Building Flutter Linux release..."
  cd "$PROJECT_DIR"
  flutter build linux --release
else
  echo "==> Skipping Flutter build (--skip-build)"
fi

if [[ ! -d "$RELEASE_BUNDLE" ]]; then
  echo "Error: release bundle not found at $RELEASE_BUNDLE"
  echo "Run without --skip-build or run 'flutter build linux --release' first."
  exit 1
fi

# ---------------------------------------------------------------
# Step 2 — Create AppDir
# ---------------------------------------------------------------
echo "==> Creating AppDir at $APPDIR"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Copy binary, libraries, and data
cp "$RELEASE_BUNDLE/$BINARY_NAME" "$APPDIR/"
cp -r "$RELEASE_BUNDLE/lib" "$APPDIR/"
cp -r "$RELEASE_BUNDLE/data" "$APPDIR/"

# ---------------------------------------------------------------
# Step 3 — Copy icon
# ---------------------------------------------------------------
echo "==> Copying icon..."
cp "$ICON_SRC" "$ICON_PNG"

# ---------------------------------------------------------------
# Step 4 — Create .desktop file
# ---------------------------------------------------------------
echo "==> Creating desktop file..."
cat > "$APPDIR/${APPLICATION_ID}.desktop" <<DESKTOP_EOF
[Desktop Entry]
Name=$APP_NAME
Comment=A local/streaming, cross-platform music player
Exec=$BINARY_NAME
Icon=${APPLICATION_ID}
Type=Application
Categories=AudioVideo;Music;Player;
Terminal=false
StartupWMClass=$APPLICATION_ID
DESKTOP_EOF

# Symlink icon without extension for AppStream compatibility
ln -sf "${APPLICATION_ID}.png" "$APPDIR/${APPLICATION_ID}"

# ---------------------------------------------------------------
# Step 5 — Create AppRun entry point
# ---------------------------------------------------------------
echo "==> Creating AppRun..."
cat > "$APPDIR/AppRun" <<'APPRUN_EOF'
#!/usr/bin/env bash
set -euo pipefail

HERE="$(dirname "$(readlink -f "$0")")"
cd "$HERE"
export LD_LIBRARY_PATH="$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export FLUTTER_PRESERVE_EXECUTION=1

exec ./ecilaes "$@"
APPRUN_EOF
chmod +x "$APPDIR/AppRun"

# ---------------------------------------------------------------
# Step 6 — Run appimagetool
# ---------------------------------------------------------------
if command -v appimagetool &>/dev/null; then
  echo "==> Running appimagetool..."
  mkdir -p "$OUTPUT_DIR"
  appimagetool "$APPDIR" "$OUTPUT"
  echo "==> Done! AppImage created at: $OUTPUT"
else
  echo "==> appimagetool not found."
  echo "    The AppDir is ready at: $APPDIR"
  echo "    Install appimagetool and run:"
  echo "      appimagetool $APPDIR $OUTPUT"
  echo ""
  echo "    Alternatively, create a tarball:"
  TARBALL="$OUTPUT_DIR/${APP_NAME}-${VERSION}-${ARCH}.tar.gz"
  tar czf "$TARBALL" -C "$(dirname "$APPDIR")" "$(basename "$APPDIR")"
  echo "      $TARBALL"
fi
