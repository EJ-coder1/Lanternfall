class_name HintSign
extends Area2D
## Wooden sign. Shows a short hint when the player walks past (environmental teaching).

@export_multiline var hint: String = ""

var _shown_once: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(90, 80)
	cs.shape = rs
	cs.position = Vector2(0, -40)
	add_child(cs)
	body_entered.connect(_on_body_entered)

	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, -34), Vector2(-3, -34)])
	post.color = Color("3a2c1e")
	add_child(post)
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([Vector2(-20, -52), Vector2(20, -54), Vector2(20, -30), Vector2(-20, -28)])
	board.color = Color("6b4f33")
	add_child(board)
	var mark := Polygon2D.new()
	mark.polygon = PackedVector2Array([Vector2(-12, -44), Vector2(12, -44), Vector2(12, -41), Vector2(-12, -41)])
	mark.color = Color("f2b84b")
	add_child(mark)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		GameState.toast.emit(hint)
