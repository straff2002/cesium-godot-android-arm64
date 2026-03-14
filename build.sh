#!/usr/bin/env bash
# ============================================================================
# Build Cesium 3D Tiles GDExtension for Godot
# ============================================================================
#
# Usage:
#   ./build.sh android arm64          # Quest 3 / Quest Pro
#   ./build.sh linux x64              # Linux desktop
#   ./build.sh windows x64            # Windows desktop
#   ./build.sh all                    # All platforms
#
# Prerequisites:
#   - CMake 3.22+, Python 3.8+, SCons 4.x, Git
#   - For Android: NDK r25+ (set ANDROID_NDK_ROOT)
#   - ~10GB disk space for cesium-native + dependencies
#
# Output:
#   build/{platform}/addons/cesium_godot/lib/*.{so,dll}
#
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_DIR="$SCRIPT_DIR/upstream"
BUILD_TYPE="${BUILD_TYPE:-Release}"
GODOT_TARGET="${GODOT_TARGET:-template_release}"
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

# ── Argument parsing ────────────────────────────────────────────────────────

PLATFORM="${1:-}"
ARCH="${2:-}"

if [[ -z "$PLATFORM" ]]; then
    echo "Usage: $0 <platform> [arch]"
    echo ""
    echo "Platforms:"
    echo "  android arm64    - Meta Quest 3 / Quest Pro"
    echo "  linux   x64      - Linux desktop"
    echo "  windows x64      - Windows desktop (cross-compile or native)"
    echo "  all              - Build all platforms"
    echo ""
    echo "Environment variables:"
    echo "  ANDROID_NDK_ROOT  - Android NDK path (required for android)"
    echo "  BUILD_TYPE        - CMake build type (default: Release)"
    echo "  GODOT_TARGET      - Godot target (default: template_release)"
    echo "  JOBS              - Parallel jobs (default: auto-detect)"
    exit 1
fi

if [[ "$PLATFORM" == "all" ]]; then
    echo "Building all platforms..."
    "$0" linux x64
    "$0" android arm64
    echo ""
    echo "All platforms built successfully!"
    exit 0
fi

if [[ -z "$ARCH" ]]; then
    case "$PLATFORM" in
        android) ARCH="arm64" ;;
        linux)   ARCH="x64" ;;
        windows) ARCH="x64" ;;
        *)       echo "ERROR: Unknown platform '$PLATFORM'"; exit 1 ;;
    esac
fi

# ── Validate prerequisites ──────────────────────────────────────────────────

check_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: $1 not found. Please install it."
        exit 1
    fi
}

check_command cmake
check_command python3
check_command scons
check_command git

# Android-specific checks
if [[ "$PLATFORM" == "android" ]]; then
    NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-}}"
    if [[ -z "$NDK_ROOT" ]]; then
        # Try common locations
        for candidate in \
            "$HOME/Library/Android/sdk/ndk/"* \
            "$HOME/Android/Sdk/ndk/"* \
            "/opt/android-ndk-"*; do
            if [[ -d "$candidate" ]]; then
                NDK_ROOT="$candidate"
                break
            fi
        done
    fi

    if [[ -z "$NDK_ROOT" || ! -d "$NDK_ROOT" ]]; then
        echo "ERROR: Android NDK not found."
        echo "Set ANDROID_NDK_ROOT to your NDK path."
        echo "Download from: https://developer.android.com/ndk/downloads"
        exit 1
    fi

    TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake"
    if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
        echo "ERROR: NDK toolchain not found at: $TOOLCHAIN_FILE"
        exit 1
    fi
    echo "NDK: $NDK_ROOT"
fi

echo "============================================"
echo "Building Cesium GDExtension for Godot"
echo "============================================"
echo "Platform:     $PLATFORM"
echo "Arch:         $ARCH"
echo "Build type:   $BUILD_TYPE"
echo "Godot target: $GODOT_TARGET"
echo "Jobs:         $JOBS"
echo ""

# ── Step 1: Clone or update upstream ─────────────────────────────────────────

if [[ -d "$UPSTREAM_DIR/.git" ]]; then
    echo "[1/5] Updating upstream source..."
    cd "$UPSTREAM_DIR"
    git pull --ff-only 2>/dev/null || true
    git submodule update --init --recursive
else
    echo "[1/5] Cloning 3D-Tiles-For-Godot..."
    git clone --recursive https://github.com/Battle-Road-Labs/3D-Tiles-For-Godot.git "$UPSTREAM_DIR"
    cd "$UPSTREAM_DIR"
fi

# Apply Android ARM64 patches
echo "Applying patches..."
for patch in "$SCRIPT_DIR"/patches/*.patch; do
    if [[ -f "$patch" ]]; then
        git apply --check "$patch" 2>/dev/null && git apply "$patch" || true
    fi
done

# ── Step 2: Build cesium-native ──────────────────────────────────────────────

echo ""
echo "[2/5] Building cesium-native for $PLATFORM-$ARCH..."

CESIUM_SRC="$UPSTREAM_DIR/extern/cesium-native"
CESIUM_BUILD="$CESIUM_SRC/build-${PLATFORM}-${ARCH}"
mkdir -p "$CESIUM_BUILD"
cd "$CESIUM_BUILD"

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DCESIUM_MSVC_STATIC_RUNTIME_ENABLED=OFF
    -DCESIUM_TESTS_ENABLED=OFF
    -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

if [[ "$PLATFORM" == "android" ]]; then
    ANDROID_ABI="arm64-v8a"
    [[ "$ARCH" == "x64" ]] && ANDROID_ABI="x86_64"

    CMAKE_ARGS+=(
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE"
        -DANDROID_ABI="$ANDROID_ABI"
        -DANDROID_PLATFORM=android-29
        "-DCMAKE_CXX_FLAGS=-fexceptions -frtti"
    )
fi

cmake "$CESIUM_SRC" "${CMAKE_ARGS[@]}" 2>&1 | tail -20

echo "Building cesium-native (this may take 10-30 minutes)..."
cmake --build . --config "$BUILD_TYPE" --parallel "$JOBS" 2>&1 | tail -5
echo "cesium-native built successfully!"

# ── Step 3: Build godot-cpp ──────────────────────────────────────────────────

echo ""
echo "[3/5] Building godot-cpp for $PLATFORM-$ARCH..."
cd "$UPSTREAM_DIR/extern/godot-cpp"

SCONS_ARGS=(
    platform="$PLATFORM"
    target="$GODOT_TARGET"
    -j"$JOBS"
)

if [[ "$PLATFORM" == "android" ]]; then
    SCONS_ARGS+=(arch=arm64 android_api_level=29)
elif [[ "$ARCH" == "x64" ]]; then
    SCONS_ARGS+=(arch=x86_64)
fi

scons "${SCONS_ARGS[@]}" 2>&1 | tail -10
echo "godot-cpp built successfully!"

# ── Step 4: Build third-party libs ───────────────────────────────────────────

echo ""
echo "[4/5] Building third-party libraries..."
cd "$UPSTREAM_DIR"

for lib in litehtml gumbo-parser; do
    if [[ -d "extern/$lib" ]]; then
        LIB_BUILD="extern/$lib/build-${PLATFORM}-${ARCH}"
        mkdir -p "$LIB_BUILD"
        cd "$LIB_BUILD"

        LIB_CMAKE_ARGS=(
            -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
            -DBUILD_SHARED_LIBS=OFF
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        )

        if [[ "$PLATFORM" == "android" ]]; then
            LIB_CMAKE_ARGS+=(
                -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE"
                -DANDROID_ABI="$ANDROID_ABI"
                -DANDROID_PLATFORM=android-29
            )
        fi

        cmake "../.." "${LIB_CMAKE_ARGS[@]}" 2>&1 | tail -5
        cmake --build . --config "$BUILD_TYPE" --parallel "$JOBS" 2>&1 | tail -5
        cd "$UPSTREAM_DIR"
        echo "$lib built."
    fi
done

# ── Step 5: Build the GDExtension ────────────────────────────────────────────

echo ""
echo "[5/5] Building GDExtension plugin..."
cd "$UPSTREAM_DIR"

export CESIUM_NATIVE_BUILD_DIR="$CESIUM_BUILD"

GDEXT_ARGS=(
    platform="$PLATFORM"
    target="$GODOT_TARGET"
    -j"$JOBS"
)

if [[ "$PLATFORM" == "android" ]]; then
    GDEXT_ARGS+=(arch=arm64)
elif [[ "$ARCH" == "x64" ]]; then
    GDEXT_ARGS+=(arch=x86_64)
fi

scons "${GDEXT_ARGS[@]}" 2>&1 | tail -20

# ── Copy output ──────────────────────────────────────────────────────────────

echo ""
OUTPUT_DIR="$SCRIPT_DIR/build/${PLATFORM}-${ARCH}"
mkdir -p "$OUTPUT_DIR/addons/cesium_godot/lib"

FOUND_LIB=$(find "$UPSTREAM_DIR" -maxdepth 4 \
    \( -name "*${PLATFORM}*${ARCH}*.so" -o -name "*${PLATFORM}*${ARCH}*.dll" \) \
    -newer "$CESIUM_BUILD" 2>/dev/null | head -1)

if [[ -n "$FOUND_LIB" ]]; then
    cp "$FOUND_LIB" "$OUTPUT_DIR/addons/cesium_godot/lib/"
    echo "============================================"
    echo "SUCCESS!"
    echo "============================================"
    echo "Output: $OUTPUT_DIR/addons/cesium_godot/lib/$(basename "$FOUND_LIB")"
    echo ""
    echo "Copy the addons/ folder to your Godot project."
else
    echo "============================================"
    echo "BUILD INCOMPLETE"
    echo "============================================"
    echo "The SCons build system may need additional patches for $PLATFORM."
    echo "See docs/building.md for troubleshooting."
    echo ""
    echo "Completed steps:"
    echo "  ✓ cesium-native: $CESIUM_BUILD"
    echo "  ✓ godot-cpp:     extern/godot-cpp"
    echo "  ✗ GDExtension:   needs SCons patches"
    echo ""
    echo "Apply patches from patches/ directory and retry step 5."
fi
