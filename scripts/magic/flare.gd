class_name Flare
extends Area2D
## Flare: a thrown bolt of lantern light. Damages enemies and reveals hidden Lumen platforms.

const SPEED := 560.0
const LIFETIME := 1.5
const DAMAGE := 2
const REVEAL_RADIUS := 130.0
const REVEAL_SECONDS := 7.0

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0
var _done: bool = false
var _visual: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.ENEMY_BODY
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_build_visual()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	global_position += direction * SPEED * delta
	for p in get_tree().get_nodes_in_group("lumen"):
		if p.has_method("distance_to_point") and p.distance_to_point(global_position) < REVEAL_RADIUS:
			p.reveal(REVEAL_SECONDS)
	if _age >= LIFETIME:
		_burst()


func _on_body_entered(_body: Node) -> void:
	_burst()


func _on_area_entered(area: Area2D) -> void:
	if _done or not area.is_in_group("enemy_body"):
		return
	var enemy := area.get_parent()
	if enemy.has_method("take_damage"):
		enemy.take_damage(DAMAGE, global_position - direction * 10.0)
		Sfx.play("hit", 0.06)
	_burst()


func _burst() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector2(3.0, 3.0), 0.2)
	tw.tween_property(_visual, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


func _circle(radius: float, color: Color, steps: int = 14) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	return p


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	var glow := _circle(20.0, Color(1.0, 0.75, 0.3, 0.3))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	_visual.add_child(glow)
	_visual.add_child(_circle(8.0, Color("ffd27a")))
	_visual.add_child(_circle(4.5, Color("fff3c9")))
	var trail := CPUParticles2D.new()
	trail.amount = 16
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 4.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 8.0
	trail.initial_velocity_max = 30.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 4.0
	trail.color = Color("ffd27a")
	add_child(trail)
