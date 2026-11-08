extends Node
## Captures real rendered frames (needs a display, e.g. xvfb) for visual review.
## Run: xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/screenshot_scene.tscn
## Output: /tmp/lanternfall_shots/*.png

const OUT := "/tmp/lanternfall_shots/"


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + shot_name + ".png")
	print("saved ", shot_name, " ", img.get_size())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var gs := get_tree().root.get_node("GameState")
	gs.new_game()
	gs.touch_mode = 1

	var menu: Control = load("res://scenes/main_menu/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(40)
	await _shot("1_menu")
	menu._show(menu._settings_panel)
	await _frames(5)
	await _shot("1b_settings")
	menu._show(menu._credits_panel)
	await _frames(5)
	await _shot("1c_credits")
	menu.queue_free()
	await _frames(3)

	var level: Level = load("res://scenes/levels/lanternroot_hollow.tscn").instantiate()
	add_child(level)
	await _frames(70)
	await _shot("2_start")

	var p: Player = level.player
	p._invuln = 9999.0
	var e1: Crawler = level.enemies[0]
	p.global_position = Vector2(e1.global_position.x - 170.0, 570)
	p.velocity = Vector2.ZERO
	var guard := 0
	while e1.state != Crawler.State.WINDUP and guard < 400:
		await get_tree().physics_frame
		guard += 1
	await _frames(18)
	await _shot("3_enemy_windup")

	p.global_position = Vector2(1860, 570)
	p.velocity = Vector2.ZERO
	p.facing = 1
	gs.set_mana(100.0)
	await _frames(40)
	Input.action_press("magic")
	await _frames(2)
	Input.action_release("magic")
	await _frames(12)
	await _shot("4_flare_in_flight")
	await _frames(20)
	p.global_position = Vector2(2200, 470)
	p.velocity = Vector2.ZERO
	await _frames(30)
	await _shot("5_lit_bridge")

	p.global_position = Vector2(3700, 360)
	p.velocity = Vector2.ZERO
	await _frames(40)
	await _shot("6_sigil_shrine")
	get_tree().quit(0)
