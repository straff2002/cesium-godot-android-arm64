# Cesium 3D Tiles for Godot — Android ARM64

Pre-built Cesium 3D Tiles GDExtension for **Godot 4.2+** on Android ARM64 devices. Developed for Meta Quest 3, compatible with any Android ARM64 target.

> **Status: Pre-release / Untested on device.** The binary compiles and links correctly but has not yet been verified running on hardware. If you test it, please report results in [Issues](../../issues).

## What This Is

A fork of [3D-Tiles-For-Godot](https://github.com/Battle-Road-Labs/3D-Tiles-For-Godot) (MIT license) with added Android ARM64 cross-compilation support, enabling photorealistic Google 3D Tiles and Cesium Ion tilesets on Android ARM64 devices.

The upstream project only ships Windows x64 and Linux x64 binaries. This project adds the build system changes needed for Android ARM64 and provides pre-built binaries.

## Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| Windows | x86_64 | ✅ (upstream) |
| Linux | x86_64 | ✅ (upstream) |
| **Android** | **ARM64** | ⚠️ **Built, awaiting device testing** |
| macOS | ARM64 | 🔜 (planned) |

## Compatible Devices

Any Android ARM64 device running a Godot 4.2+ export:

- **Meta Quest 3** (Snapdragon XR2 Gen 2) — primary development target
- **Meta Quest Pro** (Snapdragon XR2+)
- **Meta Quest 2** (Snapdragon XR2)
- **Pico 4** and other standalone VR headsets
- Android phones and tablets (ARM64)

## Quick Start

1. Download the latest release from [Releases](../../releases)
2. Place `libGodot3DTiles.android.template_release.arm64.so` in `addons/cesium_godot/lib/` in your Godot project
3. Copy the `.gdextension` file from this repo (ensure it has `android.debug.arm64` and `android.release.arm64` entries)
4. Enable the plugin in Project → Project Settings → Plugins
5. Add a `CesiumGeoreference` node to your scene
6. Add a `Cesium3DTileset` child with your Cesium Ion token

### Cesium Ion Token

Get a free token at [cesium.com/ion](https://cesium.com/ion/tokens). Set it via:

- Environment variable: `CESIUM_ION_ACCESS_TOKEN=your_token`
- Or in code: `tileset.ion_access_token = "your_token"`

### Google Photorealistic 3D Tiles

Use Cesium Ion asset ID `2275207` for Google's global 3D tiles:

```gdscript
var tileset = Cesium3DTileset.new()
tileset.ion_asset_id = 2275207
tileset.ion_access_token = "your_cesium_ion_token"
```

## Quest 3 Performance Tips

These settings are tuned for Quest 3 but are good starting points for any mobile device:

- Set `maximum_screen_space_error` to 16.0 (vs 8.0 desktop default)
- Limit `maximum_simultaneous_tile_loads` to 4
- Cap `maximum_cached_bytes` at 256MB (Quest 3 has 8GB shared RAM)
- Bake lighting — avoid realtime shadows on tilesets
- The GDExtension uses Godot's built-in HTTP client (no curl/OpenSSL needed)

## Building from Source

### Prerequisites

- Android NDK r25+ ([download](https://developer.android.com/ndk/downloads))
- CMake 3.22+
- Python 3.8+
- SCons 4.x (`pip install scons`)
- ~10GB disk space

### Build

```bash
export ANDROID_NDK_ROOT=/path/to/android-ndk-r26d

# Build everything (cesium-native + godot-cpp + GDExtension)
./build.sh android arm64

# Or build individual platforms
./build.sh linux x64
./build.sh windows x64
```

See [docs/building.md](docs/building.md) for detailed build instructions.

## Architecture

```
cesium-native (C++ library)     — 3D Tiles parsing, networking, caching
    ↓
godot-cpp (C++ bindings)        — Godot GDExtension API
    ↓
GDExtension wrapper (this repo) — CesiumGeoreference, Cesium3DTileset nodes
    ↓
Your Godot project              — Use nodes in editor or GDScript
```

### Key Changes from Upstream

1. **`CesiumBuildUtils.py`** — Added Android platform detection, NDK toolchain configuration
2. **`SCsub`** — Platform-aware library paths, Android system library linking
3. **`cesium_godot.gdextension`** — Android ARM64 library entries
4. **GodotHttpClient** — Uses Godot's HTTP stack instead of curl (avoids OpenSSL linking on Android)

## Why a Fork?

The upstream project is focused on desktop platforms. Android ARM64 support requires non-trivial build system changes (NDK toolchain integration, vcpkg cross-compilation, platform-specific linking). Rather than waiting for upstream adoption, this fork provides ready-to-use Android ARM64 binaries.

Cesium Native itself fully supports Android ARM64 — proven by [Cesium for Unreal on Quest](https://cesium.com/learn/unreal/build-for-quest/). The blocker was purely the Godot plugin's build glue.

## License

MIT — same as the upstream project and Cesium Native.

## Credits

- [Battle-Road-Labs/3D-Tiles-For-Godot](https://github.com/Battle-Road-Labs/3D-Tiles-For-Godot) — Original GDExtension
- [CesiumGS/cesium-native](https://github.com/CesiumGS/cesium-native) — Core 3D Tiles library
- [godotengine/godot-cpp](https://github.com/godotengine/godot-cpp) — GDExtension C++ bindings
