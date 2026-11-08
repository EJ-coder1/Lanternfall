class_name Crawler
extends CharacterBody2D
## Gloomback Crawler: patrols, notices the player, telegraphs a lunge, recovers (punish window).
## Placeholder geometry art.

signal defeated(at: Vector2)

enum State { PATROL, CHASE, WINDUP, LUNGE, RECOVER, HURT, DEAD }

const GRAVITY := 1600.0
const PATROL_SPEED := 55.0
const CHASE_SPEED := 105.0
const LUNGE_SPEED := 360.0
const DETECT_RANGE := 280.0
const LOSE_RANGE := 440.0
const ATTACK_RANGE := 95.0
const WINDUP_TIME := 0.55
const LUNGE_TIME := 0.28
const RECOVER_TIME := 0.65
const HURT_TIME := 0.30

@export var enemy_id: String = ""
@export var patrol_distance: float = 140.0
@export var max_hp: int = 3

var hp: int = 3
var state: State = State.PATROL
var dir: int = -1

var _state_t: float = 0.0
var _spawn_x: float = 0.0
var _body_area: Area2D
var _edge_ray: RayCast2D
var _visual: Node2D
var _shell: Polygon2D
var _eyes: Node2D
var _legs: Array[Polygon2D] = []
var _time: float = 0.0


func _ready() -> void:
	hp = max_hp
	_spawn_x = global_position.x
	collision_layer = 0
	collision_mask = Layers.WORLD

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(38, 24)
	cs.shape = rs
	cs.position = Vector2(0, -12)
	add_child(cs)

	_body_area = Area2D.new()
	_body_area.collision_layer = Layers.ENEMY_BODY
	_body_area.collision_mask = 0
	_body_area.add_to_group("enemy_body")
	var acs := CollisionShape2D.new()
	var ars := RectangleShape2D.new()
	ars.size = Vector2(42, 28)
	acs.shape = ars
	acs.position = Vector2(0, -14)
	_body_area.add_child(acs)
	add_child(_body_area)

	_edge_ray = RayCast2D.new()
	_edge_ray.collision_mask = Layers.WORLD
	_edge_ray.target_position = Vector2(0, 30)
	_edge_ray.position = Vector2(dir * 24, -6)
	add_child(_edge_ray)

	_build_visual()


func is_dangerous() -> bool:
	return state != State.HURT and state != State.DEAD and state != State.RECOVER


func take_damage(amount: int, from_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	var push := signf(global_position.x - from_pos.x)
	if push == 0.0:
		push = 1.0
	if hp <= 0:
		_die()
		return
	velocity = Vector2(push * 220.0, -180.0)
	_set_state(State.HURT)
	_flash()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_body_area.remove_from_group("enemy_body")
	Sfx.play("enemy_die", 0.05)
	defeated.emit(global_position)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "modulate:a", 0.0, 0.4)
	tw.tween_property(_visual, "scale", Vector2(1.3, 0.2), 0.4)
	tw.chain().tween_callback(queue_free)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	if s == State.WINDUP:
		Sfx.play("enemy_windup")
	elif s == State.LUNGE:
		Sfx.play("lunge", 0.05)


func _player() -> Player:
	var p := get_tree().get_first_node_in_group("player")
	if p is Player and not (p as Player).is_dead:
		return p as Player
	return null


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_time += delta
	_state_t += delta
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)

	var pl := _player()
	var dx := 0.0
	var dy := 0.0
	if pl:
		dx = pl.global_position.x - global_position.x
		dy = pl.global_position.y - global_position.y

	match state:
		State.PATROL:
			velocity.x = dir * PATROL_SPEED
			if _blocked_ahead() or absf(global_position.x - _spawn_x) > patrol_distance:
				# turn around, but never beyond the patrol bounds
				if (global_position.x - _spawn_x) * dir > 0.0 or _blocked_ahead():
					dir = -dir
			if pl and absf(dx) < DETECT_RANGE and absf(dy) < 90.0:
				_set_state(State.CHASE)
		State.CHASE:
			if pl == null or absf(dx) > LOSE_RANGE:
				_set_state(State.PATROL)
			else:
				dir = 1 if dx > 0.0 else -1
				velocity.x = 0.0 if _blocked_ahead() else dir * CHASE_SPEED
				if absf(dx) < ATTACK_RANGE and absf(dy) < 60.0:
					_set_state(State.WINDUP)
		State.WINDUP:
			velocity.x = 0.0
			if pl:
				dir = 1 if dx > 0.0 else -1
			if _state_t >= WINDUP_TIME:
				_set_state(State.LUNGE)
		State.LUNGE:
			velocity.x = 0.0 if _blocked_ahead() else dir * LUNGE_SPEED
			if _state_t >= LUNGE_TIME:
				_set_state(State.RECOVER)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _state_t >= RECOVER_TIME:
				_set_state(State.CHASE)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _state_t >= HURT_TIME:
				_set_state(State.CHASE)

	_edge_ray.position.x = dir * 24
	move_and_slide()
	_animate()


func _blocked_ahead() -> bool:
	_edge_ray.position.x = dir * 24
	_edge_ray.force_raycast_update()
	var ledge := is_on_floor() and not _edge_ray.is_colliding()
	return ledge or is_on_wall()


# ------------------------------------------------------------------- visuals

func _dome(rx: float, ry: float, steps: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var a := PI * float(i) / float(steps)
		pts.append(Vector2(-cos(a) * rx, -sin(a) * ry))
	return pts


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	for lx in [-12.0, -4.0, 5.0, 13.0]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(1.5, 8), Vector2(-1.5, 8)])
		leg.color = Color("2b2417")
		leg.position = Vector2(lx, -8)
		_visual.add_child(leg)
		_legs.append(leg)
	_shell = Polygon2D.new()
	_shell.polygon = _dome(22, 18)
	_shell.color = Color("4a2c3d")
	_shell.position = Vector2(0, -6)
	_visual.add_child(_shell)
	var ridge := Polygon2D.new()
	ridge.polygon = _dome(14, 11)
	ridge.color = Color("6b3d56")
	ridge.position = Vector2(-2, -6)
	_visual.add_child(ridge)
	var moss := Polygon2D.new()
	moss.polygon = PackedVector2Array([Vector2(-16, -20), Vector2(-8, -26), Vector2(0, -21), Vector2(8, -27), Vector2(14, -19), Vector2(0, -17)])
	moss.color = Color("9be8c8")
	_visual.add_child(moss)
	_eyes = Node2D.new()
	_eyes.position = Vector2(15, -12)
	_visual.add_child(_eyes)
	for ex in [0.0, 6.0]:
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		eye.color = Color("ffb347")
		eye.position = Vector2(ex, 0)
		_eyes.add_child(eye)


func _animate() -> void:
	_visual.scale.x = float(dir)
	for i in _legs.size():
		_legs[i].rotation = sin(_time * 12.0 + i * 1.6) * 0.5 * clampf(absf(velocity.x) / 60.0, 0.0, 1.0)
	if state == State.WINDUP:
		# Telegraph: squash down, eyes flare white, shell shudders.
		var k := _state_t / WINDUP_TIME
		_visual.scale.y = lerpf(1.0, 0.7, k)
		_visual.position.x = sin(_time * 60.0) * 1.5 * k
		for e in _eyes.get_children():
			(e as Polygon2D).color = Color("fff3c9") if int(_time * 20.0) % 2 == 0 else Color("ff5a3c")
		_shell.color = Color("4a2c3d").lerp(Color("c0502c"), k)
	else:
		_visual.scale.y = lerpf(_visual.scale.y, 1.0, 0.25)
		_visual.position.x = 0.0
		for e in _eyes.get_children():
			(e as Polygon2D).color = Color("ffb347")
		_shell.color = Color("4a2c3d")


func _flash() -> void:
	_visual.modulate = Color(2.0, 2.0, 2.0)
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color.WHITE, 0.2)
