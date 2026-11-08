class_name Shard
extends Area2D
## Glimmer Shard: collectible currency. One-time pickup keyed by id.

@export var shard_id: String = ""

var _visual: Node2D
var _t: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_t = randf() * TAU

	_visual = Node2D.new()
	add_child(_visual)
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(0, -16), Vector2(12, 0), Vector2(0, 16), Vector2(-12, 0)])
	glow.color = Color(1.0, 0.75, 0.3, 0.3)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	_visual.add_child(glow)
	var gem := Polygon2D.new()
	gem.polygon = PackedVector2Array([Vector2(0, -10), Vector2(7, 0), Vector2(0, 10), Vector2(-7, 0)])
	gem.color = Color("f2b84b")
	_visual.add_child(gem)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([Vector2(0, -8), Vector2(3, -1), Vector2(0, 2), Vector2(-3, -1)])
	shine.color = Color("fff3c9")
	_visual.add_child(shine)


func _process(delta: float) -> void:
	_t += delta * 3.0
	_visual.position.y = sin(_t) * 3.0
	_visual.scale.x = 0.75 + 0.25 * absf(cos(_t * 0.7))


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if GameState.collect_shard(shard_id):
		Sfx.play("pickup", 0.04)
	queue_free()
