class_name LumenPlatform
extends StaticBody2D
## A platform of hardened light. Faintly outlined while dark, solid only while lit by a Flare.

const DARK_ALPHA := 0.16

@export var size: Vector2 = Vector2(100, 20)

var revealed: bool = false

var _timer: float = 0.0
var _shape: CollisionShape2D
var _fill: Node2D


func _ready() -> void:
	add_to_group("lumen")
	collision_layer = Layers.LUMEN
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	_shape.shape = rs
	_shape.position = size * 0.5
	_shape.disabled = true
	add_child(_shape)

	_fill = Node2D.new()
	add_child(_fill)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	body.color = Color("7fe0ff")
	_fill.add_child(body)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, 4), Vector2(0, 4)])
	edge.color = Color("e6fbff")
	_fill.add_child(edge)
	_fill.modulate.a = DARK_ALPHA


func reveal(seconds: float) -> void:
	_timer = maxf(_timer, seconds)
	if revealed:
		return
	revealed = true
	_shape.set_deferred("disabled", false)
	Sfx.play("reveal")
	var tw := create_tween()
	tw.tween_property(_fill, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	if not revealed:
		return
	_timer -= delta
	if _timer <= 0.0:
		revealed = false
		_shape.set_deferred("disabled", true)
		_fill.modulate.a = DARK_ALPHA
	elif _timer < 1.2:
		# warn the player before the platform fades
		_fill.modulate.a = 1.0 if int(_timer * 10.0) % 2 == 0 else 0.45


func distance_to_point(point: Vector2) -> float:
	var rect := Rect2(global_position, size)
	var cx := clampf(point.x, rect.position.x, rect.end.x)
	var cy := clampf(point.y, rect.position.y, rect.end.y)
	return Vector2(cx, cy).distance_to(point)
