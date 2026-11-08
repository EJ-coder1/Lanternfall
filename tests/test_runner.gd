extends Node
## Headless gameplay test runner. Runs as a normal scene so autoloads behave exactly as in the game.
## Run: godot --headless --path . res://tests/test_scene.tscn
## Exits with code 1 if any check fails.

const LEVEL := "res://scenes/levels/lanternroot_hollow.tscn"
const MENU := "res://scenes/main_menu/main_menu.tscn"

var passes: int = 0
var fails: int = 0
var gs: Node
var ss: Node
var sfx: Node


func check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		passes += 1
		print("PASS  ", label)
	else:
		fails += 1
		print("FAIL  ", label, "   ", detail)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


func _ready() -> void:
	_run()


func _run() -> void:
	gs = get_tree().root.get_node_or_null("GameState")
	ss = get_tree().root.get_node_or_null("SaveSystem")
	sfx = get_tree().root.get_node_or_null("Sfx")
	check("autoloads present", gs != null and ss != null and sfx != null)
	if gs == null or ss == null or sfx == null:
		get_tree().quit(1)
		return
	ss.path = "user://test_save.json"
	ss.delete_save()

	await _test_save_load()
	await _test_settings_and_audio()
	await _test_menu()
	await _test_level()

	print("----------------------------------------")
	print("%d passed, %d failed" % [passes, fails])
	ss.delete_save()
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- save/load

func _test_save_load() -> void:
	gs.new_game()
	gs.shards = 7
	gs.collected_ids = ["s01", "s02"]
	gs.defeated_ids = ["e1"]
	gs.checkpoint_ids = ["cp1"]
	gs.respawn_position = Vector2(1170, 570)
	gs.has_respawn = true
	check("save_game writes file", ss.save_game() and ss.has_save())
	gs.new_game()
	check("new_game clears state", gs.shards == 0 and gs.collected_ids.is_empty())
	check("load_game succeeds", ss.load_game())
	check("save roundtrip: shards", gs.shards == 7, str(gs.shards))
	check("save roundtrip: collected ids", gs.collected_ids == ["s01", "s02"], str(gs.collected_ids))
	check("save roundtrip: defeated ids", gs.defeated_ids == ["e1"])
	check("save roundtrip: checkpoint", gs.checkpoint_ids == ["cp1"] and gs.respawn_position == Vector2(1170, 570))
	var f := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	gs.new_game()
	check("corrupt save is rejected, not crashed", ss.load_game() == false)
	f = FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string('{"version": 99}')
	f.close()
	check("wrong save version is rejected", ss.load_game() == false)
	ss.delete_save()
	check("delete_save removes file", not ss.has_save())
	gs.new_game()


func _test_settings_and_audio() -> void:
	gs.music_volume = 0.3
	gs.sfx_volume = 0.6
	gs.touch_mode = 2
	gs.save_settings()
	gs.music_volume = 0.9
	gs.sfx_volume = 0.9
	gs.touch_mode = 0
	gs.load_settings()
	check("settings roundtrip", is_equal_approx(gs.music_volume, 0.3) and is_equal_approx(gs.sfx_volume, 0.6) and gs.touch_mode == 2)
	gs.touch_mode = 0
	gs.music_volume = 0.7
	gs.sfx_volume = 0.9
	gs.save_settings()
	var names := ["jump", "land", "slash", "hit", "hurt", "die", "flare", "pickup", "checkpoint",
		"enemy_windup", "lunge", "enemy_die", "reveal", "victory", "ui_click", "deny"]
	var missing: Array = []
	for n in names:
		if not ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % n):
			missing.append(n)
	check("all sfx files import", missing.is_empty(), str(missing))
	sfx.play("jump")
	sfx.play_music("wilds")
	await frames(2)
	var stream: AudioStreamWAV = sfx._music.stream as AudioStreamWAV
	check("music loads and loops", stream != null and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 1000)
	sfx.stop_music()


func _test_menu() -> void:
	var menu: Control = load(MENU).instantiate()
	add_child(menu)
	await frames(3)
	check("main menu builds", menu.get_child_count() > 3)
	var view: Vector2 = get_viewport().get_visible_rect().size
	check("main menu fills the screen (anchors resolved)", menu.size.is_equal_approx(view), "size=%s view=%s" % [menu.size, view])
	var box: Control = menu._main_box
	var box_center: Vector2 = box.global_position + box.size * 0.5
	check("menu buttons are centered on screen", absf(box_center.x - view.x * 0.5) < 4.0 and absf(box_center.y - view.y * 0.5) < 4.0,
		"center=%s" % box_center)
	var cont: Button = menu._continue_btn
	check("Continue disabled with no save", cont.disabled)
	gs.new_game()
	ss.save_game()
	menu._show(menu._main_box)
	check("Continue enabled with a save", not cont.disabled)
	ss.delete_save()
	menu.queue_free()
	await frames(2)


# -------------------------------------------------------------------- level

func _test_level() -> void:
	gs.new_game()
	gs.touch_mode = 1
	var level: Level = load(LEVEL).instantiate()
	add_child(level)
	await frames(40)
	var p: Player = level.player
	check("level spawns player", p != null and p.is_inside_tree())
	check("player lands on ground", p.is_on_floor(), "y=%s" % p.global_position.y)
	check("level has enemies, shards, posts", level.enemies.size() == 5 and get_tree().get_nodes_in_group("lumen").size() == 6)

	# ---- movement
	var x0 := p.global_position.x
	await hold("move_right", 30)
	check("moves right", p.global_position.x > x0 + 100.0, "dx=%s" % (p.global_position.x - x0))
	check("faces right", p.facing == 1)
	await frames(20)
	x0 = p.global_position.x
	await hold("move_left", 30)
	check("moves left and turns", p.global_position.x < x0 - 100.0 and p.facing == -1)
	await frames(30)

	# ---- jump + variable height
	var ground_y := p.global_position.y
	var apex_tap := ground_y
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	for i in 50:
		await get_tree().physics_frame
		apex_tap = minf(apex_tap, p.global_position.y)
	await frames(40)
	var apex_hold := p.global_position.y
	Input.action_press("jump")
	for i in 40:
		await get_tree().physics_frame
		apex_hold = minf(apex_hold, p.global_position.y)
	Input.action_release("jump")
	await frames(60)
	check("jump leaves the ground", apex_hold < ground_y - 60.0, "rise=%s" % (ground_y - apex_hold))
	check("variable jump: tap is lower than hold", (ground_y - apex_tap) < (ground_y - apex_hold) - 20.0,
		"tap=%s hold=%s" % [ground_y - apex_tap, ground_y - apex_hold])
	check("lands again after jump", p.is_on_floor())

	# ---- coyote time: run off a ledge, press jump ~50 ms after leaving the ground
	p._invuln = 999.0
	p.global_position = Vector2(940, 570)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await frames(25)
	Input.action_press("move_right")
	var guard := 0
	while p.is_on_floor() and guard < 120:
		await get_tree().physics_frame
		guard += 1
	Input.action_release("move_right")
	await frames(3)
	check("player is airborne after running off the ledge", not p.is_on_floor())
	await hold("jump", 2)
	await frames(2)
	check("coyote time: late jump after leaving ledge still works", p.velocity.y < -100.0, "vy=%s" % p.velocity.y)
	await frames(120)

	# ---- jump buffering: press jump slightly before landing
	p.global_position = Vector2(300, 520)
	p.velocity = Vector2.ZERO
	guard = 0
	while p.velocity.y < 300.0 and guard < 60:
		await get_tree().physics_frame
		guard += 1
	await hold("jump", 1)
	var buffered_jump := false
	for i in 25:
		await get_tree().physics_frame
		if p.velocity.y < -100.0:
			buffered_jump = true
	check("jump buffer: early press jumps on landing", buffered_jump)
	await frames(90)

	# ---- damage + invulnerability (open ground, no enemies nearby)
	p.global_position = Vector2(300, 570)
	p.velocity = Vector2.ZERO
	await frames(30)
	p._invuln = 0.0
	gs.set_health(5)
	p.take_damage(1, p.global_position + Vector2(30, 0))
	check("take damage reduces health", gs.health == 4)
	p.take_damage(1, p.global_position + Vector2(30, 0))
	check("invulnerability blocks double hit", gs.health == 4)
	await frames(75)
	p.take_damage(1, p.global_position + Vector2(30, 0))
	check("damage works again after invuln ends", gs.health == 3)

	# ---- sword combat on frozen enemy e1
	var e1: Crawler = level.enemies[0]
	e1.set_physics_process(false)
	p._invuln = 999.0
	p._stun = 0.0
	p._attack_cd = 0.0
	await frames(20)
	p.global_position = Vector2(e1.global_position.x - 44.0, 570)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await frames(10)
	await hold("attack", 2)
	await frames(25)
	check("sword hits enemy once per swing", e1.hp == 2, "hp=%s" % e1.hp)
	await hold("attack", 2)
	await frames(25)
	check("second swing hits again", e1.hp == 1, "hp=%s" % e1.hp)
	await hold("attack", 2)
	await frames(10)
	check("enemy defeated and recorded", is_instance_valid(e1) and e1.state == Crawler.State.DEAD and "e1" in gs.defeated_ids)
	await frames(40)
	check("defeated enemy is removed from the world", not is_instance_valid(e1))
	var drop_found := false
	for n in level.get_children():
		if n is Shard and (n as Shard).shard_id == "drop_e1":
			drop_found = true
	check("defeated enemy drops a shard", drop_found)

	# ---- enemy AI states (e2 free to act; player invulnerable and idle)
	var e2: Crawler = level.enemies[1]
	p.global_position = Vector2(e2.global_position.x - 200.0, 570)
	p.velocity = Vector2.ZERO
	p._invuln = 999.0
	var seen: Dictionary = {}
	for i in 200:
		await get_tree().physics_frame
		seen[e2.state] = true
		p.global_position.x = e2.global_position.x - 200.0 if e2.state == Crawler.State.PATROL else p.global_position.x
	check("enemy notices player (CHASE)", seen.has(Crawler.State.CHASE))
	check("enemy telegraphs (WINDUP) then lunges (LUNGE)", seen.has(Crawler.State.WINDUP) and seen.has(Crawler.State.LUNGE))
	check("enemy recovers after lunge (RECOVER)", seen.has(Crawler.State.RECOVER))
	check("enemy contact is dangerous only when active",
		e2.is_dangerous() == (e2.state != Crawler.State.RECOVER and e2.state != Crawler.State.HURT and e2.state != Crawler.State.DEAD))

	# ---- contact damage (e2 lunge reaches the player when not invulnerable)
	e2.set_physics_process(false)
	e2.state = Crawler.State.CHASE
	p._invuln = 0.0
	gs.set_health(5)
	p.global_position = Vector2(e2.global_position.x, e2.global_position.y - 20.0)
	p.velocity = Vector2.ZERO
	await frames(6)
	check("touching an active enemy hurts the player", gs.health == 4, "hp=%s" % gs.health)
	e2.queue_free()
	level.enemies.remove_at(1)

	# ---- Lumen platform is not solid while dark
	p._invuln = 999.0
	p.global_position = Vector2(2040, 500)
	p.velocity = Vector2.ZERO
	await frames(40)
	check("dark Lumen platform lets the player fall through", p.global_position.y > 640.0, "y=%s" % p.global_position.y)

	# ---- magic: Flare costs mana, reveals Lumen platforms
	p._invuln = 999.0
	p.global_position = Vector2(1860, 570)
	p.velocity = Vector2.ZERO
	p.facing = 1
	gs.set_mana(100.0)
	await frames(30)
	await hold("magic", 2)
	await frames(2)
	check("Flare spends mana", gs.mana < 80.0 and gs.mana > 70.0, "mana=%s" % gs.mana)
	var flares := level.get_children().filter(func(n: Node) -> bool: return n is Flare)
	check("Flare projectile exists", flares.size() >= 1)
	await frames(45)
	var lumens := get_tree().get_nodes_in_group("lumen")
	var lit := 0
	for l in lumens.slice(0, 3):
		if (l as LumenPlatform).revealed:
			lit += 1
	check("Flare reveals all three bridge platforms", lit == 3, "lit=%s" % lit)
	var shape0: CollisionShape2D = (lumens[0] as LumenPlatform)._shape
	check("revealed platform becomes solid", shape0.disabled == false)
	check("far secret platforms stay dark", not (lumens[5] as LumenPlatform).revealed)
	p.global_position = Vector2(2040, 500)
	p.velocity = Vector2.ZERO
	await frames(40)
	check("player can stand on a lit Lumen platform", p.is_on_floor() and p.global_position.y < 560.0 and p.global_position.y > 520.0,
		"y=%s floor=%s" % [p.global_position.y, p.is_on_floor()])
	var l3: LumenPlatform = lumens[3]
	l3.reveal(0.2)
	await frames(30)
	check("Lumen platform fades after its timer", not l3.revealed and l3._shape.disabled)
	gs.set_mana(10.0)
	var m_before: float = gs.mana
	await frames(30)
	await hold("magic", 2)
	check("Flare refused without enough mana", gs.mana <= m_before + 10.0 and gs.mana < 25.0)

	# ---- Flare damages an enemy
	var e4: Crawler = level.enemies[2]
	e4.set_physics_process(false)
	gs.set_mana(100.0)
	p.global_position = Vector2(e4.global_position.x - 220.0, 570)
	p.velocity = Vector2.ZERO
	p.facing = 1
	await frames(20)
	await hold("magic", 2)
	await frames(45)
	check("Flare damages enemies", e4.hp == 1, "hp=%s" % e4.hp)

	# ---- collectibles
	var shards0: int = gs.shards
	p.global_position = Level.SHARDS[9]
	p.velocity = Vector2.ZERO
	await frames(6)
	check("shard pickup increments count", gs.shards == shards0 + 1 and "s09" in gs.collected_ids,
		"shards=%s ids=%s" % [gs.shards, gs.collected_ids])
	check("collected shard is removed from the world", not is_instance_valid(level.get_children().filter(
		func(n: Node) -> bool: return n is Shard and (n as Shard).shard_id == "s09").pop_back()))

	# ---- checkpoint: heal, set respawn, save
	gs.set_health(2)
	p.global_position = Vector2(1170, 570)
	p.velocity = Vector2.ZERO
	await frames(8)
	check("checkpoint lights, heals, sets respawn",
		"cp1" in gs.checkpoint_ids and gs.health == gs.max_health and gs.respawn_position.distance_to(Vector2(1170, 570)) < 2.0,
		"respawn=%s hp=%s" % [gs.respawn_position, gs.health])
	check("checkpoint writes a save file", ss.has_save())

	# ---- falling into the pit costs health and respawns at the checkpoint
	p._invuln = 0.0
	var hp_before: int = gs.health
	p.global_position = Vector2(2000, 1150)
	await frames(6)
	check("pit fall costs 1 health", gs.health == hp_before - 1, "hp=%s" % gs.health)
	check("pit fall respawns at checkpoint", p.global_position.distance_to(gs.respawn_position) < 40.0, str(p.global_position))

	# ---- death and respawn
	p._invuln = 0.0
	gs.set_health(1)
	p.take_damage(1, p.global_position + Vector2(20, 0))
	check("lethal damage kills the player", p.is_dead)
	await frames(110)
	check("player respawns with full health", (not p.is_dead) and gs.health == gs.max_health, "dead=%s hp=%s" % [p.is_dead, gs.health])

	# ---- touch controls (multi-touch)
	var tc: TouchControls = level.touch
	check("touch controls visible when enabled", tc.visible)
	var right_pos: Vector2 = tc._buttons["right"]["pos"]
	var jump_pos: Vector2 = tc._buttons["jump"]["pos"]
	var t0 := InputEventScreenTouch.new()
	t0.index = 0
	t0.position = right_pos
	t0.pressed = true
	tc._input(t0)
	var t1 := InputEventScreenTouch.new()
	t1.index = 1
	t1.position = jump_pos
	t1.pressed = true
	tc._input(t1)
	check("two fingers: move_right and jump held together",
		Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"))
	t1.pressed = false
	tc._input(t1)
	check("lifting one finger releases only its button",
		Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = tc._buttons["left"]["pos"]
	tc._input(drag)
	check("sliding a finger left switches direction",
		Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"))
	tc.release_all()
	check("release_all clears every action", not Input.is_action_pressed("move_left"))

	# ---- pause
	level.pause_menu.open()
	check("pause menu pauses the tree", get_tree().paused)
	level.pause_menu.close()
	check("resume unpauses", not get_tree().paused)

	# ---- goal
	p._invuln = 999.0
	p.global_position = Level.SIGIL_POS + Vector2(0, 20)
	p.velocity = Vector2.ZERO
	await frames(8)
	check("Sun Sigil completes the level", gs.level_done)
	check("victory panel shown and game paused", level.hud._victory_layer.visible and get_tree().paused)
	get_tree().paused = false
	level.queue_free()
	await frames(3)
