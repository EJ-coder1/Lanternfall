class_name Sigil
extends Area2D
## The Sun Sigil: the test objective for this slice. Touching it completes the level.

var _t: float = 0.0
var _visual: Node2D
var _triggered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body_entered)

	var plinth := Polygon2D.new()
	plinth.polygon = PackedVector2Array([Vector2(-26, 34), Vector2(26, 34), Vector2(18, 14), Vector2(-18, 14)])
	plinth.color = Color("3b4b52")
	add_child(plinth)
	_visual = Node2D.new()
	_visual.position = Vector2(0, -10)
	add_child(_visual)
	var rays := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var r := 30.0 if i % 2 == 0 else 15.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	rays.polygon = pts
	rays.color = Color("f2b84b")
	_visual.add_child(rays)
	var core := Polygon2D.new()
	var cpts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		cpts.append(Vector2(cos(a), sin(a)) * 10.0)
	core.polygon = cpts
	core.color = Color("fff3c9")
	_visual.add_child(core)
	var glow := Polygon2D.new()
	var gpts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		gpts.append(Vector2(cos(a), sin(a)) * 56.0)
	glow.polygon = gpts
	glow.color = Color(1.0, 0.8, 0.4, 0.2)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	_visual.add_child(glow)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation = _t * 0.6
	_visual.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.05)


func _on_body_entered(body: Node) -> void:
	if _triggered or not (body is Player):
		return
	_triggered = true
	GameState.level_done = true
	Sfx.play("victory")
	GameState.level_completed.emit()
