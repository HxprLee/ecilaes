#!/usr/bin/env bash
#
# Build all release artifacts for Ecilaes.
#
# Outputs go to build/release/:
#   android/  — ABI-split APKs + universal APK
#   ecilaes-<version>-x86_64.AppImage
#
# Usage:
#   ./scripts/build_all.sh [--skip-android] [--skip-linux] [--skip-build]
#     --skip-android   Skip Android builds
#     --skip-linux     Skip Linux build and AppImage packaging
#     --skip-build     Skip Flutter build step (use existing build artifacts)

set -euo pipefail

show_help() {
  cat << 'EOF'
Usage: build_all.sh [options]

Build all release artifacts for Ecilaes.

Outputs go to build/release/:
  android/           — ABI-split APKs + universal APK
  Ecilaes-<ver>-x86_64.AppImage

Options:
  -h, --help        Show this help message
  --skip-android    Skip Android builds
  --skip-linux      Skip Linux build and AppImage packaging
  --skip-build      Skip Flutter build step (use existing artifacts)

EOF
}

# Filter out our own flags so they don't leak into flutter commands
FLUTTER_ARGS=()
for arg in "$@"; do
  case "$arg" in
    -h|--help) show_help; exit 0 ;;
    --skip-android|--skip-linux|--skip-build) ;;
    *) FLUTTER_ARGS+=("$arg") ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="Ecilaes"
BINARY_NAME="ecilaes"
APPLICATION_ID="com.example.ecilaes"
VERSION="$(cd "$PROJECT_ROOT" && grep '^version:' pubspec.yaml | awk '{print $2}' | tr -d ' ')"
    if [[ -z "$VERSION" ]]; then VERSION="0.5.4"; fi
ARCH="x86_64"

OUTPUT_DIR="$PROJECT_ROOT/build/release"
APPDIR="$PROJECT_ROOT/build/ecilaes.AppDir"
RELEASE_BUNDLE="$PROJECT_ROOT/build/linux/x64/release/bundle"
ICON_SRC="$PROJECT_ROOT/assets/icons/ic_launcher.png"

rm -rf "$OUTPUT_DIR" "$APPDIR"
mkdir -p "$OUTPUT_DIR/android"

# ---------------------------------------------------------------
# Android — ABI splits
# ---------------------------------------------------------------
skip_android=false
for arg in "$@"; do
  if [[ "$arg" == "--skip-android" ]]; then skip_android=true; fi
done

if $skip_android; then
  echo "=== Skipping Android builds ==="
else
  echo "=== Building Android (universal) ==="
  flutter build apk --release "${FLUTTER_ARGS[@]}"
  mkdir -p "$OUTPUT_DIR/android"
  cp "$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_DIR/android/"

  echo "=== Building Android (ABI splits) ==="
  flutter build apk --release --split-per-abi "${FLUTTER_ARGS[@]}"
  cp "$PROJECT_ROOT/build/app/outputs/flutter-apk/"*.apk "$OUTPUT_DIR/android/"
fi

# ---------------------------------------------------------------
# Linux — release build
# ---------------------------------------------------------------
skip_linux=false
for arg in "$@"; do
  if [[ "$arg" == "--skip-linux" ]]; then skip_linux=true; fi
done

if ! $skip_linux; then
  skip_build=false
  for arg in "$@"; do
    if [[ "$arg" == "--skip-build" ]]; then skip_build=true; fi
  done

  if $skip_build; then
    echo "=== Skipping Flutter Linux build (--skip-build) ==="
  else
    echo "=== Building Linux ==="
    flutter build linux --release "${FLUTTER_ARGS[@]}"
  fi

  if [[ ! -d "$RELEASE_BUNDLE" ]]; then
    echo "Error: Linux release bundle not found at $RELEASE_BUNDLE"
    echo "Run without --skip-build or 'flutter build linux --release' first."
    exit 1
  fi

  # ---------------------------------------------------------------
  # AppImage — create AppDir
  # ---------------------------------------------------------------
  echo "=== Creating AppImage AppDir ==="

  mkdir -p "$APPDIR"

  cp "$RELEASE_BUNDLE/$BINARY_NAME" "$APPDIR/"
  cp -r "$RELEASE_BUNDLE/lib" "$APPDIR/"
  cp -r "$RELEASE_BUNDLE/data" "$APPDIR/"

  if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APPDIR/${APPLICATION_ID}.png"
  fi

  cat > "$APPDIR/${APPLICATION_ID}.desktop" << 'DESKTOP_EOF'
[Desktop Entry]
Name=Ecilaes
Comment=A local/streaming, cross-platform music player
Exec=ecilaes
Icon=com.example.ecilaes
Type=Application
Categories=AudioVideo;Music;Player;
Terminal=false
StartupWMClass=com.example.ecilaes
DESKTOP_EOF

  ln -sf "${APPLICATION_ID}.png" "$APPDIR/${APPLICATION_ID}" 2>/dev/null || true

  cat > "$APPDIR/AppRun" << 'APPRUN_EOF'
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
  # AppImage — package with appimagetool
  # ---------------------------------------------------------------
  APPIMAGE_OUTPUT="$OUTPUT_DIR/${APP_NAME}-${VERSION}-${ARCH}.AppImage"

  if command -v appimagetool &>/dev/null; then
    echo "=== Packaging AppImage ==="
    appimagetool "$APPDIR" "$APPIMAGE_OUTPUT"
    echo "==> AppImage created at: $APPIMAGE_OUTPUT"
  else
    echo "==> appimagetool not found; AppDir is ready at: $APPDIR"
    echo "    Install appimagetool and run:"
    echo "      appimagetool $APPDIR $APPIMAGE_OUTPUT"
  fi
else
  echo "=== Skipping Linux and AppImage ==="
fi

echo ""
echo "=== Build complete ==="
echo "Output: $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/" 2>/dev/null || true
ls -lh "$OUTPUT_DIR/android/" 2>/dev/null || true
