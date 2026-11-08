class_name LanternPost
extends Area2D
## Checkpoint. First contact lights it, heals the player and saves the game.

@export var post_id: String = ""

var active: bool = false

var _glow: Polygon2D
var _flame: Polygon2D
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(70, 130)
	cs.shape = rs
	cs.position = Vector2(0, -65)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_build_visual()
	if post_id in GameState.checkpoint_ids:
		_set_lit(true)


func _build_visual() -> void:
	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(3, -96), Vector2(-3, -96)])
	pole.color = Color("3a2c1e")
	add_child(pole)
	var cage := Polygon2D.new()
	cage.polygon = PackedVector2Array([Vector2(-14, -96), Vector2(14, -96), Vector2(11, -128), Vector2(-11, -128)])
	cage.color = Color("1b2b33")
	add_child(cage)
	_flame = Polygon2D.new()
	_flame.polygon = PackedVector2Array([Vector2(-8, -99), Vector2(8, -99), Vector2(6, -124), Vector2(0, -131), Vector2(-6, -124)])
	_flame.color = Color("4a5a5e")
	add_child(_flame)
	_glow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 54.0 + Vector2(0, -112))
	_glow.polygon = pts
	_glow.color = Color(1.0, 0.75, 0.3, 0.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	add_child(_glow)


func _set_lit(lit: bool) -> void:
	active = lit
	_flame.color = Color("ffd27a") if lit else Color("4a5a5e")
	_glow.color = Color(1.0, 0.75, 0.3, 0.22 if lit else 0.0)


func _process(delta: float) -> void:
	if active:
		_t += delta
		_glow.scale = Vector2.ONE * (1.0 + sin(_t * 5.0) * 0.06)


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	GameState.set_checkpoint(post_id, global_position + Vector2(0, -30))
	if active:
		return
	_set_lit(true)
	GameState.set_health(GameState.max_health)
	GameState.set_mana(GameState.max_mana)
	var saved := SaveSystem.save_game()
	GameState.toast.emit("Lantern lit. Progress saved." if saved else "Lantern lit. (Save failed)")
	Sfx.play("checkpoint")
