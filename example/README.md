# Example: Cesium 3D Tiles on Quest 3

Minimal Godot 4 project showing Google Photorealistic 3D Tiles running on Meta Quest 3.

## Setup

1. Build the plugin or download from [Releases](../../releases)
2. Copy `addons/cesium_godot/` into this directory
3. Set your Cesium Ion token: `export CESIUM_ION_ACCESS_TOKEN=your_token`
4. Open in Godot 4.x, enable the plugin, deploy to Quest 3

## Scene Structure

```
XROrigin3D
├── XRCamera3D
├── LeftHand (XRController3D)
└── RightHand (XRController3D)

CesiumGeoreference (origin: Auckland Airport)
└── Cesium3DTileset (Google 3D Tiles via Ion)

WorldEnvironment
DirectionalLight3D
```

## Files

- `cesium_xr_example.gd` — Sets up Cesium 3D tileset with XR
- `project.godot` — Project config with OpenXR enabled
