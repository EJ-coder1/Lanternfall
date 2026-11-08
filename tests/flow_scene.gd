extends Node
## Scene-flow smoke test: menu -> New Game -> level -> pause -> menu -> Continue (from a save).
## Run: godot --headless --path . res://tests/flow_scene.tscn

const MENU := "res://scenes/main_menu/main_menu.tscn"

var passes: int = 0
var fails: int = 0


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


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame  # the root is busy while the main scene loads
	var gs: Node = get_tree().root.get_node("GameState")
	var ss: Node = get_tree().root.get_node("SaveSystem")
	ss.path = "user://flow_save.json"
	ss.delete_save()

	# Make the menu the current scene so change_scene_to_file never frees this runner.
	var menu: Control = load(MENU).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await frames(10)

	menu._on_new_game()
	await frames(70)
	var level := get_tree().current_scene as Level
	check("New Game loads the level scene", level != null)
	if level == null:
		_finish(ss)
		return
	check("New Game starts at the level spawn", level.player.global_position.distance_to(Level.START_POS) < 40.0,
		str(level.player.global_position))
	check("New Game starts with full health and no shards", gs.health == gs.max_health and gs.shards == 0)

	level.pause_menu.open()
	check("pause opens during play", get_tree().paused and level.pause_menu.visible)
	level.pause_menu._on_menu()
	await frames(70)
	var back: Node = get_tree().current_scene
	check("Pause > Main Menu returns to the menu and unpauses", back.has_method("_show") and not get_tree().paused)

	# Continue from a mid-level save
	gs.new_game()
	gs.shards = 2
	gs.collected_ids = ["s00", "s01"]
	gs.defeated_ids = ["e1"]
	gs.checkpoint_ids = ["cp2"]
	gs.respawn_position = Vector2(2540, 570)
	gs.has_respawn = true
	ss.save_game()
	gs.new_game()
	back._show(back._main_box)
	check("Continue button enabled when a save exists", not back._continue_btn.disabled)
	back._on_continue()
	await frames(70)
	level = get_tree().current_scene as Level
	check("Continue loads the level", level != null)
	if level != null:
		check("Continue restores shard count", gs.shards == 2, str(gs.shards))
		check("Continue puts the player at the saved checkpoint",
			level.player.global_position.distance_to(Vector2(2540, 570)) < 40.0, str(level.player.global_position))
		var collected_gone := true
		for n in level.get_children():
			if n is Shard and ((n as Shard).shard_id == "s00" or (n as Shard).shard_id == "s01"):
				collected_gone = false
		check("Continue does not respawn collected shards", collected_gone)
		check("Continue does not respawn defeated enemies", level.enemies.size() == 4, str(level.enemies.size()))
		var lit := false
		for n in level.get_children():
			if n is LanternPost and (n as LanternPost).post_id == "cp2":
				lit = (n as LanternPost).active
		check("Continue shows the saved checkpoint as lit", lit)
	_finish(ss)


func _finish(ss: Node) -> void:
	ss.delete_save()
	print("----------------------------------------")
	print("%d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)
