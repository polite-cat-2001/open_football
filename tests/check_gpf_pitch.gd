extends SceneTree
# Headless check for the ported original pitch generator (ticket 04) and the
# 13 detail layer: three macro maps, expected sizes, grass variation, mow
# stripes in the normal, perlin roughness, the overlay lines landing on the
# halfway line, and the cached 512 detail albedo/normal pair.

const GRASS_PATH := "res://assets/gpf/media/textures/pitch/seamlessgrass08.png"
const OVERLAY_PATH := "res://assets/gpf/media/textures/pitch/overlay.png"
const WIDTH := 4096
const HEIGHT := 2731

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
		print("  FAIL: ", message)


func _load_rgba(path: String) -> Image:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


# Ratio of the wrapped-edge colour delta to an inner one: ~1 when the tile is
# still seamless, much higher when a resize broke the wrap.
func _seam_ratio(image: Image) -> float:
	var width := image.get_width()
	var seam := 0.0
	var inside := 0.0
	for y in width:
		seam += absf(image.get_pixel(0, y).r - image.get_pixel(width - 1, y).r)
		inside += absf(image.get_pixel(width / 2, y).r - image.get_pixel(width / 2 + 1, y).r)
	return seam / maxf(inside, 0.0001)


# Min/max/mean/stdev of one channel, sampled on a coarse grid.
func _stats(image: Image, channel: int) -> Dictionary:
	var size := image.get_size()
	var values: Array[float] = []
	for gy in 64:
		for gx in 64:
			var x := clampi(int((gx + 0.5) * size.x / 64.0), 0, size.x - 1)
			var y := clampi(int((gy + 0.5) * size.y / 64.0), 0, size.y - 1)
			values.append(image.get_pixel(x, y)[channel])
	var mean := 0.0
	for value in values:
		mean += value
	mean /= values.size()
	var variance := 0.0
	for value in values:
		variance += (value - mean) * (value - mean)
	variance /= values.size()
	return {
		"min": values.min(),
		"max": values.max(),
		"mean": mean,
		"stdev": sqrt(variance),
	}


func _run() -> void:
	var grass := _load_rgba(GRASS_PATH)
	var overlay := _load_rgba(OVERLAY_PATH)
	_check(grass != null and grass.get_size() == Vector2i(1200, 1200),
		"seamless grass tile is loaded")
	_check(overlay != null and overlay.get_size() == Vector2i(4096, 2048),
		"pitch overlay is loaded")
	if grass == null or overlay == null:
		_finish()
		return

	var runtime := GpfRuntimeNode.new()
	var started := Time.get_ticks_msec()
	var maps: Dictionary = runtime.generate_pitch_maps(WIDTH, HEIGHT, grass, overlay)
	var elapsed := Time.get_ticks_msec() - started
	print("  generate_pitch_maps took ", elapsed, " ms")
	var albedo := maps.get("albedo") as Image
	var normal := maps.get("normal") as Image
	var roughness := maps.get("roughness") as Image
	_check(albedo != null and albedo.get_size() == Vector2i(WIDTH, HEIGHT),
		"albedo is %dx%d" % [WIDTH, HEIGHT])
	_check(normal != null and normal.get_size() == Vector2i(2731, 1821),
		"normal is 2731x1821")
	_check(roughness != null and roughness.get_size() == Vector2i(1365, 910),
		"roughness is 1365x910")
	runtime.free()
	if albedo == null or normal == null or roughness == null:
		_finish()
		return

	var albedo_r := _stats(albedo, 0)
	var albedo_g := _stats(albedo, 1)
	var albedo_b := _stats(albedo, 2)
	print("  albedo R ", albedo_r, " G mean ", albedo_g["mean"], " B mean ", albedo_b["mean"])
	_check(albedo_r["stdev"] > 0.01 and albedo_r["max"] - albedo_r["min"] > 0.12,
		"albedo is not flat")
	_check(albedo_g["mean"] > albedo_r["mean"] + 0.05
		and albedo_g["mean"] > albedo_b["mean"] + 0.08, "albedo reads as grass (green dominant)")

	var normal_r := _stats(normal, 0)
	var normal_b := _stats(normal, 2)
	print("  normal R ", normal_r, " B mean ", normal_b["mean"])
	_check(normal_r["stdev"] > 0.01 and normal_r["max"] - normal_r["min"] > 0.04,
		"normal carries the mow stripes (not flat)")
	_check(normal_b["mean"] > 0.9, "normal map points up")

	var rough_stats := _stats(roughness, 1)
	print("  roughness G ", rough_stats)
	_check(rough_stats["stdev"] > 0.01 and rough_stats["max"] - rough_stats["min"] > 0.05,
		"roughness carries perlin variation")
	_check(rough_stats["min"] > 0.3 and rough_stats["max"] <= 1.0,
		"roughness stays in the grass range")

	# The overlay's halfway line is 12 cm wide at x = 0: u = 0.5, v = 0.25.
	# It must be clearly brighter than the grass 2 m away.
	var row := int(0.25 * HEIGHT)
	var line_peak := 0.0
	var grass_peak := 0.0
	for dx in range(-8, 9):
		line_peak = maxf(line_peak, albedo.get_pixel(WIDTH / 2 + dx, row).r)
	for dx in range(64, 81):
		grass_peak = maxf(grass_peak, albedo.get_pixel(WIDTH / 2 + dx, row).r)
	print("  halfway line R ", line_peak, " vs grass ", grass_peak)
	_check(line_peak > grass_peak + 0.15, "overlay line lands on the halfway line")

	# Detail layer: the grass tile at 512, half strength, with its own normal.
	var detail_started := Time.get_ticks_msec()
	var detail: Dictionary = GpfEnvironment.pitch_detail_maps(grass)
	print("  pitch_detail_maps took ", Time.get_ticks_msec() - detail_started, " ms")
	var detail_albedo := detail.get("albedo") as Image
	var detail_normal := detail.get("normal") as Image
	_check(detail_albedo != null and detail_albedo.get_size() == Vector2i(1024, 1024)
		and detail_albedo.has_mipmaps(), "detail albedo is a 1024 mipmapped tile")
	_check(detail_normal != null and detail_normal.get_size() == Vector2i(1024, 1024)
		and detail_normal.has_mipmaps(), "detail normal is a 1024 mipmapped tile")
	if detail_albedo != null and detail_normal != null:
		var seam_ratio := _seam_ratio(detail_albedo)
		print("  detail albedo seam/inside delta ", snappedf(seam_ratio, 0.01))
		_check(seam_ratio < 2.5, "detail albedo stays seamless after the resize")
		var detail_r := _stats(detail_normal, 0)
		var detail_g := _stats(detail_normal, 1)
		var detail_b := _stats(detail_normal, 2)
		print("  detail normal R stdev ", detail_r["stdev"], " G stdev ", detail_g["stdev"],
			" B mean ", detail_b["mean"])
		_check(detail_r["stdev"] > 0.01 and detail_g["stdev"] > 0.01, "detail normal has grain")
		_check(detail_b["mean"] > 0.5, "detail normal points up")

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("CHECK PASS: gpf pitch maps")
		quit(0)
	else:
		for failure in failures:
			print("CHECK FAIL: ", failure)
		quit(1)
