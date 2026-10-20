extends SceneTree
## Offline baker for environment sprites: CC0 models (Quaternius Stylized Nature MegaKit,
## KayKit Medieval Hexagon) rendered from the game camera into individual sprites with an ink
## outline, plus a separate cast-shadow sprite rendered from the same sun onto a catcher plane.
##
##   godot --path . --script res://tools/bake_props.gd [-- --only=prefix]
##
## Output: assets/props/<name>.png, <name>_sh.png and assets/props/props.json
## ({name: {w, h, ax, ay, sh: [w, h, ax, ay] | null, foot: [width, depth] in world units, top}}).

const R := 3.0           # final pixels per world unit
const SS := 2
const WU := 12.0         # world units per metre
const ELEV := 40.0
const OUT := "res://assets/props/"
const NAT := "res://art_src/quaternius_nature/"
const MED := "res://art_src/kaykit_medieval/"
## the sun: from the upper left, slightly behind the scene (shadows fall right and toward the camera)
const SUN_DIR := Vector3(0.66, -0.86, 0.3)

## [name, file, size, options]. size: {"h": height in world units} | {"w": width} | {"s": scale}
## options: sh (cast shadow, default true), rot (yaw degrees), ol (outline px at 2x), sat
var PROPS := [
	# trees
	["oak_1", NAT + "CommonTree_1.gltf", {"h": 92.0}, {}], ["oak_2", NAT + "CommonTree_2.gltf", {"h": 98.0}, {}],
	["oak_3", NAT + "CommonTree_3.gltf", {"h": 104.0}, {}], ["oak_4", NAT + "CommonTree_4.gltf", {"h": 96.0}, {}],
	["oak_5", NAT + "CommonTree_5.gltf", {"h": 90.0}, {}], ["oak_1b", NAT + "CommonTree_1.gltf", {"h": 84.0}, {"rot": 140.0}],
	["oak_3b", NAT + "CommonTree_3.gltf", {"h": 96.0}, {"rot": 200.0}],
	["pine_1", NAT + "Pine_1.gltf", {"h": 110.0}, {}], ["pine_2", NAT + "Pine_2.gltf", {"h": 120.0}, {}],
	["pine_3", NAT + "Pine_3.gltf", {"h": 104.0}, {}], ["pine_4", NAT + "Pine_4.gltf", {"h": 96.0}, {}],
	["pine_5", NAT + "Pine_5.gltf", {"h": 116.0}, {}],
	["autumn_1", NAT + "TwistedTree_1.gltf", {"h": 90.0}, {}], ["autumn_2", NAT + "TwistedTree_2.gltf", {"h": 96.0}, {}],
	["autumn_3", NAT + "TwistedTree_3.gltf", {"h": 86.0}, {}], ["autumn_4", NAT + "TwistedTree_4.gltf", {"h": 92.0}, {}],
	["autumn_5", NAT + "TwistedTree_5.gltf", {"h": 88.0}, {}],
	["dead_1", NAT + "DeadTree_1.gltf", {"h": 84.0}, {}], ["dead_2", NAT + "DeadTree_2.gltf", {"h": 80.0}, {}],
	["dead_3", NAT + "DeadTree_3.gltf", {"h": 96.0}, {}], ["dead_4", NAT + "DeadTree_4.gltf", {"h": 90.0}, {}],
	["dead_5", NAT + "DeadTree_5.gltf", {"h": 92.0}, {}],
	# undergrowth
	["bush_1", NAT + "Bush_Common.gltf", {"h": 22.0}, {}], ["bush_2", NAT + "Bush_Common_Flowers.gltf", {"h": 22.0}, {}],
	["bush_1b", NAT + "Bush_Common.gltf", {"h": 18.0}, {"rot": 120.0}], ["fern", NAT + "Fern_1.gltf", {"h": 12.0}, {}],
	["plant_1", NAT + "Plant_1.gltf", {"w": 9.0}, {"sh": false, "ol": 1.0, "ink": Color(0.11, 0.2, 0.08, 0.85)}], ["plant_1b", NAT + "Plant_1_Big.gltf", {"w": 16.0}, {}],
	["plant_7", NAT + "Plant_7.gltf", {"w": 10.0}, {"sh": false, "ol": 1.0, "ink": Color(0.11, 0.2, 0.08, 0.85)}], ["plant_7b", NAT + "Plant_7_Big.gltf", {"w": 18.0}, {"sh": false}],
	["grass_1", NAT + "Grass_Common_Short.gltf", {"h": 6.0}, {"sh": false, "ol": 0.9, "ink": Color(0.11, 0.2, 0.08, 0.85)}],
	["grass_2", NAT + "Grass_Common_Tall.gltf", {"h": 10.0}, {"sh": false, "ol": 0.9, "ink": Color(0.11, 0.2, 0.08, 0.85)}],
	["grass_3", NAT + "Grass_Wispy_Short.gltf", {"h": 6.0}, {"sh": false, "ol": 0.9, "ink": Color(0.11, 0.2, 0.08, 0.85)}],
	["grass_4", NAT + "Grass_Wispy_Tall.gltf", {"h": 11.0}, {"sh": false, "ol": 0.9, "ink": Color(0.11, 0.2, 0.08, 0.85)}],
	["flowers_1", NAT + "Flower_3_Group.gltf", {"h": 8.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	["flowers_2", NAT + "Flower_4_Group.gltf", {"h": 8.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	["flower_1", NAT + "Flower_3_Single.gltf", {"h": 6.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	["flower_2", NAT + "Flower_4_Single.gltf", {"h": 6.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	["clover_1", NAT + "Clover_1.gltf", {"w": 7.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	["clover_2", NAT + "Clover_2.gltf", {"w": 7.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	["mushroom_1", NAT + "Mushroom_Common.gltf", {"h": 4.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	["mushroom_2", NAT + "Mushroom_Laetiporus.gltf", {"h": 4.0}, {"sh": false, "ol": 0.9, "ink": Color(0.16, 0.2, 0.1, 0.8)}],
	# stones
	["rock_1", NAT + "Rock_Medium_1.gltf", {"w": 26.0}, {}], ["rock_2", NAT + "Rock_Medium_2.gltf", {"w": 30.0}, {}],
	["rock_3", NAT + "Rock_Medium_3.gltf", {"w": 34.0}, {}],
	["pebble_1", NAT + "Pebble_Round_1.gltf", {"w": 6.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["pebble_2", NAT + "Pebble_Round_3.gltf", {"w": 5.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["pebble_3", NAT + "Pebble_Square_2.gltf", {"w": 6.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["pebble_4", NAT + "Pebble_Square_5.gltf", {"w": 7.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["path_1", NAT + "RockPath_Round_Wide.gltf", {"w": 30.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["path_2", NAT + "RockPath_Round_Small_1.gltf", {"w": 16.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["path_3", NAT + "RockPath_Square_Wide.gltf", {"w": 30.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["path_4", NAT + "RockPath_Round_Small_3.gltf", {"w": 14.0}, {"sh": false, "ol": 1.0, "ink": Color(0.2, 0.17, 0.14, 0.8)}],
	["petals_1", NAT + "Petal_1.gltf", {"w": 3.0}, {"sh": false, "ol": 1.0}],
	# medieval buildings (KayKit, March red / Crown blue roofs)
	["house_a_red", MED + "buildings/red/building_home_A_red.gltf", {"w": 110.0}, {}],
	["house_b_red", MED + "buildings/red/building_home_B_red.gltf", {"w": 110.0}, {}],
	["house_a_blue", MED + "buildings/blue/building_home_A_blue.gltf", {"w": 110.0}, {}],
	["house_b_blue", MED + "buildings/blue/building_home_B_blue.gltf", {"w": 110.0}, {}],
	["tavern_blue", MED + "buildings/blue/building_tavern_blue.gltf", {"w": 130.0}, {}],
	["market_blue", MED + "buildings/blue/building_market_blue.gltf", {"w": 130.0}, {}],
	["smithy_blue", MED + "buildings/blue/building_blacksmith_blue.gltf", {"w": 130.0}, {}],
	["church_blue", MED + "buildings/blue/building_church_blue.gltf", {"w": 140.0}, {}],
	["castle_blue", MED + "buildings/blue/building_castle_blue.gltf", {"w": 420.0}, {}],
	["tower_a_blue", MED + "buildings/blue/building_tower_A_blue.gltf", {"w": 90.0}, {}],
	["tower_b_blue", MED + "buildings/blue/building_tower_B_blue.gltf", {"w": 90.0}, {}],
	["tower_cat_blue", MED + "buildings/blue/building_tower_catapult_blue.gltf", {"w": 90.0}, {}],
	["windmill_blue", MED + "buildings/blue/building_windmill_blue.gltf", {"w": 120.0}, {}],
	["well_blue", MED + "buildings/blue/building_well_blue.gltf", {"w": 44.0}, {}],
	["barracks_red", MED + "buildings/red/building_barracks_red.gltf", {"w": 140.0}, {}],
	["archery_red", MED + "buildings/red/building_archeryrange_red.gltf", {"w": 130.0}, {}],
	["tower_a_red", MED + "buildings/red/building_tower_A_red.gltf", {"w": 80.0}, {}],
	["ruin", MED + "buildings/neutral/building_destroyed.gltf", {"w": 110.0}, {}],
	["scaffold", MED + "buildings/neutral/building_scaffolding.gltf", {"w": 100.0}, {}],
	["grain", MED + "buildings/neutral/building_grain.gltf", {"w": 90.0}, {}],
	["bridge_a", MED + "buildings/neutral/building_bridge_A.gltf", {"w": 120.0}, {}],
	["fence_stone", MED + "buildings/neutral/fence_stone_straight.gltf", {"w": 60.0}, {}],
	["fence_wood", MED + "buildings/neutral/fence_wood_straight.gltf", {"w": 60.0}, {}],
	["wall_seg", MED + "buildings/neutral/wall_straight.gltf", {"w": 120.0}, {}],
	["wall_gate", MED + "buildings/neutral/wall_straight_gate.gltf", {"w": 120.0}, {}],
	# camp and street props
	["tent", MED + "decoration/props/tent.gltf", {"w": 52.0}, {}],
	["tent_b", MED + "decoration/props/tent.gltf", {"w": 48.0}, {"rot": 90.0}],
	["barrel", MED + "decoration/props/barrel.gltf", {"h": 12.0}, {}],
	["arrows", MED + "decoration/props/bucket_arrows.gltf", {"h": 12.0}, {}],
	["crate_a", MED + "decoration/props/crate_A_big.gltf", {"h": 14.0}, {}],
	["crate_b", MED + "decoration/props/crate_B_small.gltf", {"h": 9.0}, {}],
	["crates_long", MED + "decoration/props/crate_long_A.gltf", {"w": 24.0}, {}],
	["crate_open", MED + "decoration/props/crate_open.gltf", {"h": 11.0}, {}],
	["flag_red", MED + "decoration/props/flag_red.gltf", {"h": 46.0}, {}],
	["flag_blue", MED + "decoration/props/flag_blue.gltf", {"h": 46.0}, {}],
	["ladder", MED + "decoration/props/ladder.gltf", {"h": 30.0}, {}],
	["pallet", MED + "decoration/props/pallet.gltf", {"w": 18.0}, {"sh": false}],
	["lumber", MED + "decoration/props/resource_lumber.gltf", {"w": 26.0}, {}],
	["stones", MED + "decoration/props/resource_stone.gltf", {"w": 24.0}, {}],
	["sack", MED + "decoration/props/sack.gltf", {"h": 9.0}, {}],
	["target", MED + "decoration/props/target.gltf", {"h": 20.0}, {}],
	["weaponrack", MED + "decoration/props/weaponrack.gltf", {"w": 24.0}, {}],
	["cart", MED + "decoration/props/wheelbarrow.gltf", {"w": 22.0}, {}],
	["boulder_1", MED + "decoration/nature/rock_single_A.gltf", {"w": 40.0}, {}],
	["boulder_2", MED + "decoration/nature/rock_single_C.gltf", {"w": 46.0}, {}],
	["boulder_3", MED + "decoration/nature/rock_single_E.gltf", {"w": 54.0}, {}],
	["mountain_1", MED + "decoration/nature/mountain_A_grass_trees.gltf", {"w": 520.0}, {}],
	["mountain_2", MED + "decoration/nature/mountain_B_grass_trees.gltf", {"w": 560.0}, {}],
	["hills_1", MED + "decoration/nature/hills_A_trees.gltf", {"w": 380.0}, {}],
	["hills_2", MED + "decoration/nature/hills_C_trees.gltf", {"w": 360.0}, {}],
]

var vp3: SubViewport
var vp2: SubViewport
var world: Node3D
var cam: Camera3D
var env: Environment
var key: DirectionalLight3D
var fill: DirectionalLight3D
var catcher: MeshInstance3D
var post: TextureRect
var mat_color: ShaderMaterial
var mat_shadow: ShaderMaterial
var meta := {}
var only := ""

func _init() -> void:
	# also used as a helper library by bake_siege.gd: only bake when run as the main script
	if not ("res://tools/bake_props.gd" in OS.get_cmdline_args()):
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()

func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path), st)
	assert(err == OK, "cannot load " + path)
	return doc.generate_scene(st) as Node3D

func _each(n: Node, cb: Callable) -> void:
	cb.call(n)
	for c in n.get_children():
		_each(c, cb)

func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack := [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D and node != n:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var b: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for c in node.get_children():
			stack.append([c, t])
	return box

const POST := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D src : filter_linear;
uniform vec2 src_px;
uniform float radius = 2.0;
uniform int mode = 0;          // 0 colour + outline, 1 shadow
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform vec4 shadow_col : source_color = vec4(0.08, 0.1, 0.2, 1.0);
void fragment() {
	vec4 c = texture(src, UV);
	if (mode == 1) {
		float a = clamp(1.0 - c.r * 1.08, 0.0, 1.0);
		COLOR = vec4(shadow_col.rgb, a);
	} else {
		float m = 0.0;
		for (int i = 0; i < 16; i++) {
			float ang = float(i) * 0.3927;
			vec2 d = vec2(cos(ang), sin(ang)) * src_px;
			m = max(m, texture(src, UV + d * radius).a);
			m = max(m, texture(src, UV + d * radius * 0.55).a);
		}
		float o = radius > 0.01 ? smoothstep(0.08, 0.6, m) * ink.a : 0.0;
		vec4 p = vec4(c.rgb + ink.rgb * o * (1.0 - c.a), c.a + o * (1.0 - c.a));
		vec3 straight = p.a > 0.003 ? p.rgb / p.a : ink.rgb;
		COLOR = vec4(straight, p.a);
	}
}
"""

func _setup() -> void:
	vp3 = SubViewport.new()
	vp3.size = Vector2i(64, 64)
	vp3.transparent_bg = true
	vp3.msaa_3d = Viewport.MSAA_4X
	vp3.positional_shadow_atlas_size = 0
	vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp3)
	world = Node3D.new()
	vp3.add_child(world)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.64, 0.7, 0.86)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	we.environment = env
	world.add_child(we)
	key = DirectionalLight3D.new()
	key.light_energy = 1.15
	key.light_color = Color(1.0, 0.95, 0.85)
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 400.0
	world.add_child(key)
	key.look_at_from_position(Vector3.ZERO, SUN_DIR, Vector3.UP)
	fill = DirectionalLight3D.new()
	fill.light_energy = 0.32
	fill.light_color = Color(0.72, 0.8, 1.0)
	world.add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.4, -0.5, -0.8), Vector3.UP)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-ELEV, 0, 0)
	cam.near = 0.5
	cam.far = 600.0
	world.add_child(cam)
	cam.current = true
	catcher = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	catcher.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color.WHITE
	cm.roughness = 1.0
	cm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	cm.disable_ambient_light = true
	cm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	catcher.material_override = cm
	catcher.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(catcher)
	vp2 = SubViewport.new()
	vp2.size = Vector2i(32, 32)
	vp2.transparent_bg = true
	vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp2)
	post = TextureRect.new()
	post.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	post.stretch_mode = TextureRect.STRETCH_SCALE
	post.texture = vp3.get_texture()
	var sh := Shader.new()
	sh.code = POST
	mat_color = ShaderMaterial.new()
	mat_color.shader = sh
	mat_color.set_shader_parameter("src", vp3.get_texture())
	post.material = mat_color
	vp2.add_child(post)

func _style(m: BaseMaterial3D, sat: float) -> BaseMaterial3D:
	var nm: BaseMaterial3D = m.duplicate()
	nm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	nm.roughness = maxf(nm.roughness, 0.8)
	nm.metallic_specular = 0.2
	nm.rim_enabled = true
	nm.rim = 0.25
	nm.rim_tint = 0.5
	if nm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		nm.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	if sat != 1.0:
		var c := nm.albedo_color
		var l := c.get_luminance()
		nm.albedo_color = Color(lerpf(l, c.r, sat), lerpf(l, c.g, sat), lerpf(l, c.b, sat), c.a)
	return nm

func _bake(e: Array) -> void:
	await _bake_node(e[0], _load(e[1]), e[2], e[3])

## Bakes any 3D node (a loaded model or one built in code) into a sprite and its shadow.
func _bake_node(name: String, model: Node3D, size: Dictionary, opt: Dictionary) -> void:
	var cache := {}
	_each(model, func(c):
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if m:
					if not cache.has(m):
						cache[m] = _style(m, float(opt.get("sat", 1.0)))
					mi.set_surface_override_material(s, cache[m])
	)
	model.rotation_degrees.y = float(opt.get("rot", 0.0))
	var holder := Node3D.new()
	holder.add_child(model)
	var box := _aabb(holder)
	var sc := 1.0
	if size.has("h"):
		sc = float(size["h"]) / WU / maxf(box.size.y, 0.001)
	elif size.has("w"):
		sc = float(size["w"]) / WU / maxf(maxf(box.size.x, box.size.z), 0.001)
	else:
		sc = float(size["s"])
	holder.scale = Vector3.ONE * sc
	world.add_child(holder)
	box = AABB(box.position * sc, box.size * sc)
	# ground the model: its lowest point sits on y = 0
	holder.position.y = -box.position.y
	var base := Vector3(box.get_center().x, 0.0, box.get_center().z)
	if opt.get("origin", false):
		# animated objects keep their own origin so every frame lines up
		base = Vector3.ZERO
		holder.position.y = 0.0
	holder.position.x = -base.x
	holder.position.z = -base.z
	box.position += holder.position
	var shadow: bool = opt.get("sh", true)
	# screen bounds of the model (and of its shadow on the ground)
	var right := cam.transform.basis.x
	var up := cam.transform.basis.y
	var pts: Array = []
	for i in 8:
		var q := box.position + Vector3(box.size.x * (i & 1), box.size.y * ((i >> 1) & 1), box.size.z * ((i >> 2) & 1))
		pts.append(q)
		if shadow:
			pts.append(q + SUN_DIR * (q.y / -SUN_DIR.y))
	var umin := INF
	var umax := -INF
	var vmin := INF
	var vmax := -INF
	for q in pts:
		umin = minf(umin, q.dot(right))
		umax = maxf(umax, q.dot(right))
		vmin = minf(vmin, q.dot(up))
		vmax = maxf(vmax, q.dot(up))
	var margin := 0.25
	umin -= margin
	umax += margin
	vmin -= margin
	vmax += margin
	var ppm := R * WU * SS
	var vsize := Vector2i(int(ceil((umax - umin) * ppm)), int(ceil((vmax - vmin) * ppm)))
	vsize = vsize.clamp(Vector2i(16, 16), Vector2i(8192, 8192))
	vp3.size = vsize
	vp2.size = vsize / SS
	post.size = Vector2(vp2.size)
	cam.size = float(vsize.y) / ppm
	cam.position = right * (umin + umax) * 0.5 + up * (vmin + vmax) * 0.5 + cam.transform.basis.z * 200.0
	mat_color.set_shader_parameter("src_px", Vector2.ONE / Vector2(vsize))
	mat_color.set_shader_parameter("radius", float(opt.get("ol", 2.0)))
	mat_color.set_shader_parameter("ink", opt.get("ink", Color(0.06, 0.05, 0.08, 1.0)))
	# colour pass
	catcher.visible = false
	key.shadow_enabled = false
	key.light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ambient_light_energy = 0.55
	fill.visible = true
	_cast(holder, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	mat_color.set_shader_parameter("mode", 0)
	var img: Image = await _grab()
	var used := img.get_used_rect()
	var anchor := Vector2(-umin, vmax) * R * WU    # ground point under the model centre
	var entry := {}
	if used.size.x > 0:
		img.get_region(used).save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		entry = {"w": used.size.x, "h": used.size.y, "ax": anchor.x - used.position.x, "ay": anchor.y - used.position.y}
	# shadow pass: the model only casts, the white catcher shows where the sun is blocked
	entry["sh"] = null
	if shadow:
		catcher.visible = true
		key.shadow_enabled = true
		key.light_energy = 3.5
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.ambient_light_energy = 0.0
		fill.visible = false
		_cast(holder, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		mat_color.set_shader_parameter("mode", 1)
		var simg: Image = await _grab()
		var su := simg.get_used_rect()
		if su.size.x > 0:
			simg.get_region(su).save_png(ProjectSettings.globalize_path(OUT + name + "_sh.png"))
			entry["sh"] = [su.size.x, su.size.y, anchor.x - su.position.x, anchor.y - su.position.y]
	entry["foot"] = [snappedf(box.size.x * WU, 0.1), snappedf(box.size.z * WU * sin(deg_to_rad(ELEV)), 0.1)]
	entry["top"] = snappedf(box.size.y * WU, 0.1)
	meta[name] = entry
	holder.queue_free()
	await process_frame

func _cast(n: Node, mode: int) -> void:
	_each(n, func(c):
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = mode
	)

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp2.get_texture().get_image()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var mp := ProjectSettings.globalize_path(OUT + "props.json")
	if only != "" and FileAccess.file_exists(mp):
		meta = JSON.parse_string(FileAccess.get_file_as_string(mp))
	_setup()
	var t0 := Time.get_ticks_msec()
	for e in PROPS:
		if only != "" and not String(e[0]).begins_with(only):
			continue
		await _bake(e)
		print("  baked ", e[0], " ", meta.get(e[0], {}).get("w", 0), "x", meta.get(e[0], {}).get("h", 0))
	var f := FileAccess.open(mp, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print("[props] %d props in %.1f s" % [meta.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
