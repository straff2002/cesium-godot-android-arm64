# Patches

These patches are applied to the upstream 3D-Tiles-For-Godot source to add Android ARM64 support.

## How patches work

1. `build.sh` clones the upstream repo into `upstream/`
2. Patches from this directory are applied via `git apply`
3. The patched source is then built for Android ARM64

## Patch descriptions

### 001-android-platform-detection.patch
Adds Android target detection to `CesiumBuildUtils.py` so the build system knows how to configure cmake and compiler flags for ARM64 Android.

### 002-android-library-paths.patch
Updates `SCsub` with platform-aware library paths and Android system library linking (`log`, `android`, `z`).

### 003-gdextension-android-entries.patch
Adds Android ARM64 library entries to the `.gdextension` manifest file.

### 004-godot-http-android.patch
Enables the GodotHttpClient wrapper for Android builds (avoids curl/OpenSSL linking issues). Uses Godot's built-in HTTP client which delegates to Android's networking stack.

## Creating patches

If you modify the upstream source manually, generate a patch with:

```bash
cd upstream
git diff > ../patches/NNN-description.patch
```

## Applying patches manually

```bash
cd upstream
git apply ../patches/*.patch
```
