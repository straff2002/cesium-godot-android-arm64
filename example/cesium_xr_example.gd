## Minimal Cesium 3D Tiles + XR example.
## Shows Google Photorealistic 3D Tiles on Meta Quest 3.
extends Node3D

# Auckland Airport coordinates (change to your location)
const ORIGIN_LAT := -37.0082
const ORIGIN_LNG := 174.7850
const ORIGIN_HEIGHT := 7.0

# Cesium Ion asset ID for Google Photorealistic 3D Tiles
const GOOGLE_3D_TILES := 2275207


func _ready() -> void:
	# Start XR
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true
		print("OpenXR initialized")

	# Set up Cesium
	_setup_cesium()


func _setup_cesium() -> void:
	if not ClassDB.class_exists("CesiumGeoreference"):
		push_error("Cesium plugin not loaded! Install the GDExtension first.")
		return

	# Georeference — anchors the 3D world to real coordinates
	var georef = ClassDB.instantiate("CesiumGeoreference")
	georef.name = "Georeference"
	if "origin_latitude" in georef:
		georef.origin_latitude = ORIGIN_LAT
		georef.origin_longitude = ORIGIN_LNG
		georef.origin_height = ORIGIN_HEIGHT
	add_child(georef)

	# 3D Tileset — loads Google's photorealistic tiles via Cesium Ion
	var tileset = ClassDB.instantiate("Cesium3DTileset")
	tileset.name = "GoogleTiles"

	var token := OS.get_environment("CESIUM_ION_ACCESS_TOKEN")
	if token == "":
		push_warning("Set CESIUM_ION_ACCESS_TOKEN env var for Cesium Ion tiles")
		return

	if "ion_asset_id" in tileset:
		tileset.ion_asset_id = GOOGLE_3D_TILES
		tileset.ion_access_token = token

	# Quest 3 performance settings
	if "maximum_screen_space_error" in tileset:
		tileset.maximum_screen_space_error = 16.0
	if "maximum_simultaneous_tile_loads" in tileset:
		tileset.maximum_simultaneous_tile_loads = 4
	if "maximum_cached_bytes" in tileset:
		tileset.maximum_cached_bytes = 256 * 1024 * 1024  # 256MB

	georef.add_child(tileset)
	print("Cesium 3D Tiles configured — rendering Google tiles at [%s, %s]" % [
		ORIGIN_LAT, ORIGIN_LNG
	])
