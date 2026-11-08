class_name Level
extends Node2D
## Lanternroot Hollow: the first playable region (vertical slice).
## The layout is data-driven: edit the constants below to reshape the level.

const PlayerScene := preload("res://scenes/player/player.tscn")
const CrawlerScene := preload("res://scenes/enemies/crawler.tscn")
const ShardScene := preload("res://scenes/environments/shard.tscn")
const PostScene := preload("res://scenes/environments/lantern_post.tscn")
const LumenScene := preload("res://scenes/environments/lumen_platform.tscn")
const SigilScene := preload("res://scenes/environments/sigil.tscn")
const SignScene := preload("res://scenes/environments/hint_sign.tscn")
const HudScene := preload("res://scenes/ui/hud.tscn")
const TouchScene := preload("res://scenes/ui/touch_controls.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")

const START_POS := Vector2(120, 560)
const WORLD_RIGHT := 4000.0
const REPEAT_W := 1800.0

# Solid ground and ledges: Rect2(x, y, w, h)
const SOLIDS: Array[Rect2] = [
	Rect2(-100, 600, 1100, 500),
	Rect2(380, 520, 130, 24),
	Rect2(1130, 600, 770, 500),
	Rect2(1300, 520, 140, 24),
	Rect2(1480, 445, 140, 24),
	Rect2(2500, 600, 820, 500),
	Rect2(3300, 552, 120, 548),
	Rect2(3420, 504, 120, 596),
	Rect2(3540, 456, 120, 644),
	Rect2(3660, 408, 340, 692),
]

# Light-revealed platforms. The first three bridge the big gap; the last three are a secret.
const LUMENS: Array[Rect2] = [
	Rect2(1990, 560, 100, 20),
	Rect2(2150, 520, 100, 20),
	Rect2(2310, 480, 100, 20),
	Rect2(2780, 520, 100, 20),
	Rect2(2900, 440, 100, 20),
	Rect2(3020, 360, 120, 20),
]

const SHARDS: Array[Vector2] = [
	Vector2(250, 566), Vector2(300, 566), Vector2(350, 566), Vector2(445, 486),
	Vector2(850, 566), Vector2(900, 566), Vector2(1370, 486), Vector2(1520, 411),
	Vector2(1580, 411), Vector2(1760, 566), Vector2(2040, 526), Vector2(2200, 486),
	Vector2(2360, 446), Vector2(2900, 566), Vector2(3000, 566), Vector2(3360, 518),
	Vector2(3480, 470), Vector2(3600, 422), Vector2(3050, 326), Vector2(3090, 326),
	Vector2(3130, 326),
]

# [id, x, y, patrol_distance]
const ENEMIES: Array = [
	["e1", 700.0, 600.0, 120.0],
	["e2", 1600.0, 600.0, 150.0],
	["e3", 1550.0, 445.0, 45.0],
	["e4", 2750.0, 600.0, 130.0],
	["e5", 3100.0, 600.0, 120.0],
]

const POSTS: Array = [["cp1", 1170.0, 600.0], ["cp2", 2540.0, 600.0]]

const SIGNS: Array = [
	[220.0, 600.0, "Move with A / D or the arrow buttons. Hold JUMP longer to leap higher."],
	[640.0, 600.0, "Gloombacks shudder before they lunge. Dodge, then strike while they recover."],
	[1860.0, 600.0, "Hidden stones fade in with light. Cast FLARE toward the gap (K, or the FLARE button)."],
]

const SIGIL_POS := Vector2(3830, 374)

var player: Player
var hud: Hud
var pause_menu: PauseMenu
var touch: TouchControls
var enemies: Array[Crawler] = []


func _ready() -> void:
	GameState.level_done = false
	if not GameState.has_respawn:
		GameState.respawn_position = START_POS
	_build_background()
	for r in SOLIDS:
		_add_solid(r)
	_add_walls()
	_add_decor()
	for r in LUMENS:
		var l: LumenPlatform = LumenScene.instantiate()
		l.position = r.position
		l.size = r.size
		add_child(l)
	_spawn_entities()
	_spawn_player()
	_build_ui()
	Sfx.play_music("wilds")
	GameState.level_completed.connect(_on_level_completed)
	hud.show_toast("Find the Sun Sigil at the far end of the hollow.")


# ------------------------------------------------------------------ spawning

func _spawn_entities() -> void:
	for i in SHARDS.size():
		var id := "s%02d" % i
		if id in GameState.collected_ids:
			continue
		var s: Shard = ShardScene.instantiate()
		s.shard_id = id
		s.position = SHARDS[i]
		add_child(s)
	for p in POSTS:
		var post: LanternPost = PostScene.instantiate()
		post.post_id = p[0]
		post.position = Vector2(p[1], p[2])
		add_child(post)
	for sg in SIGNS:
		var sign_node: HintSign = SignScene.instantiate()
		sign_node.position = Vector2(sg[0], sg[1])
		sign_node.hint = sg[2]
		add_child(sign_node)
	for e in ENEMIES:
		if e[0] in GameState.defeated_ids:
			continue
		var c: Crawler = CrawlerScene.instantiate()
		c.enemy_id = e[0]
		c.position = Vector2(e[1], e[2] - 2.0)
		c.patrol_distance = e[3]
		c.defeated.connect(_on_enemy_defeated.bind(c))
		add_child(c)
		enemies.append(c)
	var sigil: Sigil = SigilScene.instantiate()
	sigil.position = SIGIL_POS
	add_child(sigil)


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.position = GameState.respawn_position
	add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_right = int(WORLD_RIGHT)
	player.camera.limit_top = -300
	player.camera.limit_bottom = 800
	var flies := CPUParticles2D.new()
	flies.amount = 36
	flies.lifetime = 5.0
	flies.local_coords = false
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(680, 280)
	flies.gravity = Vector2(0, -5)
	flies.initial_velocity_min = 4.0
	flies.initial_velocity_max = 14.0
	flies.scale_amount_min = 1.5
	flies.scale_amount_max = 3.5
	flies.color = Color(1.0, 0.85, 0.5, 0.75)
	flies.position = Vector2(0, -60)
	flies.z_index = 8
	player.add_child(flies)
	GameState.set_health(GameState.health)
	GameState.set_mana(GameState.mana)


func _build_ui() -> void:
	hud = HudScene.instantiate()
	add_child(hud)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 9
	touch_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(touch_layer)
	touch = TouchScene.instantiate()
	touch_layer.add_child(touch)
	pause_menu = PauseScene.instantiate()
	add_child(pause_menu)
	hud.pause_pressed.connect(pause_menu.toggle)
	hud.menu_pressed.connect(_return_to_menu)
	pause_menu.opened.connect(touch.release_all)


func _on_enemy_defeated(at: Vector2, enemy: Crawler) -> void:
	if not (enemy.enemy_id in GameState.defeated_ids):
		GameState.defeated_ids.append(enemy.enemy_id)
	var drop: Shard = ShardScene.instantiate()
	drop.shard_id = "drop_" + enemy.enemy_id
	drop.position = at + Vector2(0, -24)
	call_deferred("add_child", drop)


func _on_level_completed() -> void:
	SaveSystem.save_game()
	hud.show_victory(GameState.shards)
	touch.release_all()
	get_tree().paused = true


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.MENU_PATH)


# --------------------------------------------------------------- world build

func _add_solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = r.position
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.position = r.size * 0.5
	body.add_child(cs)
	body.add_child(_rect_poly(Vector2.ZERO, r.size, Color("26363a")))
	var bands := int(minf(r.size.y, 200.0) / 44.0)
	for j in range(1, bands):
		body.add_child(_rect_poly(Vector2(0, 14 + j * 44), Vector2(r.size.x, 8), Color(0, 0, 0, 0.18)))
	body.add_child(_rect_poly(Vector2.ZERO, Vector2(r.size.x, minf(14.0, r.size.y)), Color("3f9a62")))
	body.add_child(_rect_poly(Vector2.ZERO, Vector2(r.size.x, 4), Color("93e0a4")))
	add_child(body)


func _add_walls() -> void:
	for x in [-140.0, WORLD_RIGHT]:
		var wall := StaticBody2D.new()
		wall.collision_layer = Layers.WORLD
		wall.collision_mask = 0
		wall.position = Vector2(x, -600)
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(140, 2400)
		cs.shape = rs
		cs.position = rs.size * 0.5
		wall.add_child(cs)
		add_child(wall)


func _rect_poly(pos: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)])
	p.position = pos
	p.color = color
	return p


func _add_decor() -> void:
	# Dim background saplings and ferns on the big ground slabs (silhouettes, behind gameplay).
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for r in SOLIDS:
		if r.size.x < 500.0:
			continue
		var x := r.position.x + 90.0
		while x < r.end.x - 60.0:
			var h := rng.randf_range(70.0, 150.0)
			var trunk := _rect_poly(Vector2(x - 4, r.position.y - h), Vector2(8, h), Color("17302f"))
			trunk.z_index = -2
			add_child(trunk)
			var canopy := Polygon2D.new()
			var pts := PackedVector2Array()
			var rad := rng.randf_range(34.0, 56.0)
			for i in 12:
				var a := TAU * float(i) / 12.0
				pts.append(Vector2(cos(a) * rad, sin(a) * rad * 0.8))
			canopy.polygon = pts
			canopy.position = Vector2(x, r.position.y - h - 8)
			canopy.color = Color("1d4a43")
			canopy.z_index = -2
			add_child(canopy)
			x += rng.randf_range(170.0, 300.0)


func _build_background() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -20
	add_child(sky_layer)
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2(-400, -400), Vector2(2400, -400), Vector2(2400, 1200), Vector2(-400, 1200)])
	sky.vertex_colors = PackedColorArray([Color("08161e"), Color("08161e"), Color("236a5c"), Color("236a5c")])
	sky_layer.add_child(sky)
	var moon := Polygon2D.new()
	var mpts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		mpts.append(Vector2(cos(a), sin(a)) * 70.0)
	moon.polygon = mpts
	moon.position = Vector2(1000, 170)
	moon.color = Color("e8f6ee")
	sky_layer.add_child(moon)
	var halo := Polygon2D.new()
	var hpts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		hpts.append(Vector2(cos(a), sin(a)) * 150.0)
	halo.polygon = hpts
	halo.position = moon.position
	halo.color = Color(0.7, 0.95, 0.9, 0.08)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = mat
	sky_layer.add_child(halo)

	_add_parallax(0.12, Color("1a4455"), 650.0, "peaks", 11, -30)
	_add_parallax(0.30, Color("153a41"), 650.0, "pines", 22, -28)
	_add_parallax(0.55, Color("0f2a31"), 690.0, "pines_tall", 33, -26)
	_add_parallax(0.85, Color(0.75, 1.0, 0.95, 0.05), 640.0, "fog", 44, -24)


func _add_parallax(scroll: float, color: Color, base_y: float, kind: String, seed_value: int, z: int) -> void:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scroll, 1.0)
	p.repeat_size = Vector2(REPEAT_W, 0)
	p.repeat_times = 3
	p.z_index = z
	var shapes := Node2D.new()
	p.add_child(shapes)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var polys: Array[PackedVector2Array] = []
	match kind:
		"peaks":
			var pts := PackedVector2Array()
			pts.append(Vector2(0, base_y + 600))
			var x := 0.0
			while x <= REPEAT_W:
				var h := 140.0 + 90.0 * sin(TAU * 2.0 * x / REPEAT_W) + 50.0 * sin(TAU * 5.0 * x / REPEAT_W + 1.0)
				pts.append(Vector2(x, base_y - h))
				x += 60.0
			pts.append(Vector2(REPEAT_W, base_y + 600))
			polys.append(pts)
		"pines", "pines_tall":
			var tall := kind == "pines_tall"
			var x := 60.0
			while x < REPEAT_W - 120.0:
				var h := rng.randf_range(210.0, 300.0) if tall else rng.randf_range(120.0, 200.0)
				var w := h * 0.38
				for tier in 3:
					var ty := base_y - h * (0.35 + 0.25 * tier)
					var tw := w * (1.0 - 0.28 * tier)
					polys.append(PackedVector2Array([Vector2(x - tw, ty + h * 0.3), Vector2(x + tw, ty + h * 0.3), Vector2(x, ty - h * 0.12)]))
				polys.append(PackedVector2Array([Vector2(x - 5, base_y), Vector2(x + 5, base_y), Vector2(x + 5, base_y - h * 0.4), Vector2(x - 5, base_y - h * 0.4)]))
				x += rng.randf_range(90.0, 170.0) if tall else rng.randf_range(60.0, 110.0)
		"fog":
			for i in 5:
				var fx := rng.randf_range(0.0, REPEAT_W - 400.0)
				var fy := base_y - rng.randf_range(0.0, 120.0)
				polys.append(PackedVector2Array([Vector2(fx, fy), Vector2(fx + 380, fy - 10), Vector2(fx + 340, fy + 40), Vector2(fx + 20, fy + 36)]))
	shapes.draw.connect(func() -> void:
		for poly in polys:
			shapes.draw_colored_polygon(poly, color))
	add_child(p)
