# Building from Source

## Prerequisites

### All platforms
- **CMake** 3.22+ — `brew install cmake` / `apt install cmake`
- **Python 3.8+** — `python3 --version`
- **SCons 4.x** — `pip install scons`
- **Git** — with submodule support
- **~10GB disk space** — cesium-native + vcpkg dependencies

### Android ARM64 (Quest 3 / Quest Pro)
- **Android NDK r25+** — [download](https://developer.android.com/ndk/downloads)
  - Recommended: r26d
  - Set `ANDROID_NDK_ROOT` environment variable

### Linux x86_64
- **GCC 11+** or **Clang 14+** — for C++20 support
- **pkg-config** — `apt install pkg-config`

### Windows x86_64
- **Visual Studio 2022** — with C++ workload
- **vcpkg** — for dependency management

## Quick Build

```bash
# Clone this repo
git clone --recursive https://github.com/YOUR_USERNAME/cesium-godot-quest.git
cd cesium-godot-quest

# Android ARM64 (Quest 3)
export ANDROID_NDK_ROOT=/path/to/android-ndk-r26d
./build.sh android arm64

# Linux x86_64
./build.sh linux x64

# All platforms
./build.sh all
```

Output goes to `build/{platform}-{arch}/addons/cesium_godot/lib/`.

## Manual Build (Step by Step)

If the automated build fails, follow these steps manually.

### Step 1: Clone Upstream + Submodules

```bash
git clone --recursive https://github.com/Battle-Road-Labs/3D-Tiles-For-Godot.git upstream
cd upstream
```

### Step 2: Apply Patches

```bash
for patch in ../patches/*.patch; do
    git apply "$patch"
done
```

### Step 3: Build cesium-native

#### Android ARM64

```bash
cd extern/cesium-native
mkdir -p build-android-arm64 && cd build-android-arm64

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-29 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCESIUM_MSVC_STATIC_RUNTIME_ENABLED=OFF \
    -DCESIUM_TESTS_ENABLED=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    "-DCMAKE_CXX_FLAGS=-fexceptions -frtti"

cmake --build . --config Release --parallel $(nproc)
```

This takes 10-30 minutes depending on your machine. It downloads and builds ~20 vcpkg dependencies cross-compiled for ARM64.

#### Linux x86_64

```bash
cd extern/cesium-native
mkdir -p build-linux-x64 && cd build-linux-x64

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCESIUM_TESTS_ENABLED=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON

cmake --build . --config Release --parallel $(nproc)
```

### Step 4: Build godot-cpp

#### Android ARM64

```bash
cd extern/godot-cpp
scons platform=android arch=arm64 target=template_release \
    android_api_level=29 -j$(nproc)
```

#### Linux x86_64

```bash
cd extern/godot-cpp
scons platform=linux target=template_release -j$(nproc)
```

### Step 5: Build Third-Party Libraries

If the project has litehtml/gumbo-parser in `extern/`:

```bash
# litehtml (Android ARM64)
cd extern/litehtml
mkdir -p build-android-arm64 && cd build-android-arm64
cmake ../.. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-29 \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build . --config Release --parallel $(nproc)
```

### Step 6: Build the GDExtension

```bash
cd upstream  # back to plugin root
export CESIUM_NATIVE_BUILD_DIR=$(pwd)/extern/cesium-native/build-android-arm64

scons platform=android arch=arm64 target=template_release -j$(nproc)
```

### Step 7: Install

Copy the built `.so` to your Godot project:

```bash
cp project/addons/cesium_godot/lib/libGodot3DTiles.android.template_release.arm64.so \
    /path/to/your/godot/project/addons/cesium_godot/lib/
```

## Troubleshooting

### "No arm64 library found for GDExtension"

This is the original error that this project solves. Make sure your `.gdextension` file includes Android entries:

```ini
[libraries]
android.debug.arm64 = "res://addons/cesium_godot/lib/libGodot3DTiles.android.template_debug.arm64.so"
android.release.arm64 = "res://addons/cesium_godot/lib/libGodot3DTiles.android.template_release.arm64.so"
```

### vcpkg bootstrap fails during cesium-native build

vcpkg is bundled inside cesium-native and auto-bootstraps. If it fails:

1. Check your CMake version: `cmake --version` (needs 3.22+)
2. For Android: make sure `ANDROID_NDK_ROOT` is set
3. Try deleting `extern/cesium-native/extern/vcpkg/` and re-running cmake

### SQLite linking errors

Cesium Native uses SQLite for tile caching. On Android, you may need to explicitly build SQLite:

```bash
# If cmake fails with SQLite errors, try:
cmake .. [your args] -DVCPKG_OVERLAY_TRIPLETS=path/to/custom/triplets
```

See [Cesium for Unreal issue #1265](https://github.com/CesiumGS/cesium-unreal/issues/1265) for the known fix.

### SSL/TLS certificate errors on Quest 3

Android doesn't have `/etc/ssl/certs`. The GodotHttpClient wrapper (enabled by `CESIUM_USE_GODOT_HTTP_CLIENT` define) avoids this by delegating to Android's networking stack, which handles certificates natively.

### Out of memory during build

cesium-native is large. Reduce parallel jobs:

```bash
cmake --build . --config Release --parallel 2
```

### SCons doesn't recognize "android" platform

The upstream SCons build may not have Android support. Make sure patches are applied:

```bash
cd upstream
git diff --stat  # Should show CesiumBuildUtils.py, SCsub changes
```

## Quest 3 Performance Tuning

Once built and running, tune these settings for Quest 3's 8GB shared RAM:

| Setting | Desktop Default | Quest 3 Recommended |
|---------|----------------|-------------------|
| `maximum_screen_space_error` | 8.0 | 16.0 |
| `maximum_simultaneous_tile_loads` | 16 | 4 |
| `maximum_cached_bytes` | 512MB | 256MB |
| Realtime shadows | On | Off (bake lighting) |

## CI/CD

The GitHub Actions workflow (`.github/workflows/build.yml`) automatically builds Android ARM64 and Linux x86_64 on every push to main. Tagged releases (`v*`) create GitHub Releases with downloadable zip files.
