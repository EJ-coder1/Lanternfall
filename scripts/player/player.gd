class_name Player
extends CharacterBody2D
## The Wickbearer: movement, sword combat, Flare magic, damage and respawn.
## All art is temporary placeholder geometry drawn from Polygon2D nodes.

signal died
signal respawned

const FlareScene := preload("res://scenes/player/flare.tscn")

# --- Movement tuning
const RUN_SPEED := 270.0
const ACCEL := 2000.0
const DECEL := 2600.0
const AIR_ACCEL := 1500.0
const GRAVITY := 1600.0
const FALL_GRAVITY_MULT := 1.25
const MAX_FALL_SPEED := 950.0
const JUMP_VELOCITY := -560.0
const JUMP_CUT_MULT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.12

# --- Combat tuning
const ATTACK_DURATION := 0.30
const ATTACK_ACTIVE_START := 0.07
const ATTACK_ACTIVE_END := 0.20
const ATTACK_COOLDOWN := 0.10
const ATTACK_DAMAGE := 1
const ATTACK_MOVE_MULT := 0.6
const FLARE_COST := 25.0
const FLARE_COOLDOWN := 0.35
const MANA_REGEN := 9.0
const INVULN_TIME := 1.1
const HURT_STUN := 0.25
const KILL_Y := 1100.0

var facing: int = 1
var is_dead: bool = false
var camera: Camera2D

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _attack_t: float = -1.0
var _attack_cd: float = 0.0
var _flare_cd: float = 0.0
var _invuln: float = 0.0
var _stun: float = 0.0
var _was_on_floor: bool = false
var _prev_vy: float = 0.0
var _hit_this_swing: Array = []
var _time: float = 0.0
var _sx: float = 1.0
var _sy: float = 1.0
var _hitbox: Area2D
var _hurtbox: Area2D
var _visual: Node2D
var _blade_pivot: Node2D
var _leg_l: Polygon2D
var _leg_r: Polygon2D
var _head: Node2D
var _torso: Node2D
var _scarf: Polygon2D
var _blade_tween: Tween


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.LUMEN
	floor_snap_length = 8.0
	z_index = 5

	var body_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 11.0
	capsule.height = 46.0
	body_shape.shape = capsule
	add_child(body_shape)

	_hitbox = _make_area(Vector2(46, 44), Vector2(34, -4), 0, Layers.ENEMY_BODY)
	_hurtbox = _make_area(Vector2(20, 40), Vector2.ZERO, 0, Layers.ENEMY_BODY)
	_build_visual()

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.offset = Vector2(0, -70)
	camera.zoom = Vector2(1.3, 1.3)  # larger characters read better on a phone screen
	add_child(camera)


func _make_area(size: Vector2, pos: Vector2, layer: int, mask: int) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = layer
	a.collision_mask = mask
	a.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	a.add_child(cs)
	add_child(a)
	return a


# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_time += delta
	_tick_timers(delta)

	var on_floor := is_on_floor()
	var dir: float = Input.get_axis("move_left", "move_right")
	if _stun > 0.0:
		dir = 0.0

	# Horizontal movement
	var speed := RUN_SPEED
	if _attack_t >= 0.0 and on_floor:
		speed *= ATTACK_MOVE_MULT
	var target := dir * speed
	var rate := ACCEL if on_floor else AIR_ACCEL
	if absf(dir) < 0.01:
		rate = DECEL if on_floor else AIR_ACCEL * 0.6
	if _stun <= 0.0:
		velocity.x = move_toward(velocity.x, target, rate * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if absf(dir) > 0.1 and _attack_t < 0.0 and _stun <= 0.0:
		facing = 1 if dir > 0.0 else -1

	# Gravity
	if not on_floor:
		var g := GRAVITY
		if velocity.y > 0.0:
			g *= FALL_GRAVITY_MULT
		velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)

	# Coyote time + jump buffering
	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta
	if _jump_buffer > 0.0 and _coyote > 0.0 and _stun <= 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote = 0.0
		_jump_buffer = 0.0
		_sx = 0.8
		_sy = 1.25
		Sfx.play("jump", 0.05)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULT

	# Actions
	if Input.is_action_just_pressed("attack") and _attack_t < 0.0 and _attack_cd <= 0.0 and _stun <= 0.0:
		_start_attack()
	if Input.is_action_just_pressed("magic") and _flare_cd <= 0.0 and _stun <= 0.0:
		_cast_flare()
	_update_attack(delta)

	if GameState.mana < GameState.max_mana:
		GameState.set_mana(GameState.mana + MANA_REGEN * delta)

	_prev_vy = velocity.y
	move_and_slide()

	# Landing feedback
	on_floor = is_on_floor()
	if on_floor and not _was_on_floor and _prev_vy > 220.0:
		_sx = 1.25
		_sy = 0.72
		Sfx.play("land", 0.05)
	_was_on_floor = on_floor

	_check_contact_damage()
	_check_fall()
	_animate(delta)


func _tick_timers(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_flare_cd = maxf(0.0, _flare_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_stun = maxf(0.0, _stun - delta)


# ------------------------------------------------------------------- combat

func _start_attack() -> void:
	_attack_t = 0.0
	_hit_this_swing.clear()
	_hitbox.position.x = 34.0 * facing
	Sfx.play("slash", 0.08)
	if _blade_tween and _blade_tween.is_valid():
		_blade_tween.kill()
	_blade_pivot.rotation = deg_to_rad(-100.0)
	_blade_tween = create_tween()
	_blade_tween.tween_property(_blade_pivot, "rotation", deg_to_rad(70.0), ATTACK_DURATION * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_blade_tween.tween_property(_blade_pivot, "rotation", deg_to_rad(-25.0), ATTACK_DURATION * 0.45)


func _update_attack(delta: float) -> void:
	if _attack_t < 0.0:
		return
	_attack_t += delta
	if _attack_t >= ATTACK_ACTIVE_START and _attack_t <= ATTACK_ACTIVE_END:
		for area in _hitbox.get_overlapping_areas():
			if area in _hit_this_swing or not area.is_in_group("enemy_body"):
				continue
			_hit_this_swing.append(area)
			var enemy := area.get_parent()
			if enemy.has_method("take_damage"):
				enemy.take_damage(ATTACK_DAMAGE, global_position)
				Sfx.play("hit", 0.06)
	if _attack_t >= ATTACK_DURATION:
		_attack_t = -1.0
		_attack_cd = ATTACK_COOLDOWN


func _cast_flare() -> void:
	if GameState.mana < FLARE_COST:
		Sfx.play("deny")
		_flare_cd = 0.25
		return
	GameState.set_mana(GameState.mana - FLARE_COST)
	_flare_cd = FLARE_COOLDOWN
	var f: Flare = FlareScene.instantiate()
	f.direction = Vector2(facing, 0.0)
	f.global_position = global_position + Vector2(32.0 * facing, -8.0)
	get_parent().add_child(f)
	Sfx.play("flare")


func _check_contact_damage() -> void:
	if _invuln > 0.0:
		return
	for area in _hurtbox.get_overlapping_areas():
		if not area.is_in_group("enemy_body"):
			continue
		var enemy := area.get_parent()
		if enemy.has_method("is_dangerous") and enemy.is_dangerous():
			take_damage(1, area.global_position)
			return


func take_damage(amount: int, from_pos: Vector2) -> void:
	if is_dead or _invuln > 0.0:
		return
	GameState.set_health(GameState.health - amount)
	_invuln = INVULN_TIME
	_stun = HURT_STUN
	var push := signf(global_position.x - from_pos.x)
	if push == 0.0:
		push = -float(facing)
	velocity = Vector2(push * 300.0, -320.0)
	_attack_t = -1.0
	_attack_cd = ATTACK_COOLDOWN
	Sfx.play("hurt")
	if GameState.health <= 0:
		_die()


func _check_fall() -> void:
	if global_position.y <= KILL_Y or is_dead:
		return
	GameState.set_health(GameState.health - 1)
	Sfx.play("hurt")
	if GameState.health <= 0:
		_die()
	else:
		respawn(false)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	Sfx.play("die")
	died.emit()
	var tw := create_tween()
	tw.tween_property(_visual, "modulate:a", 0.0, 0.7)
	tw.tween_interval(0.5)
	tw.tween_callback(respawn.bind(true))


func respawn(refill: bool = true) -> void:
	if refill:
		GameState.set_health(GameState.max_health)
		GameState.set_mana(GameState.max_mana)
	global_position = GameState.respawn_position
	velocity = Vector2.ZERO
	is_dead = false
	_attack_t = -1.0
	_stun = 0.0
	_invuln = 1.5
	_visual.modulate = Color.WHITE
	if camera:
		camera.reset_smoothing()
	respawned.emit()


# ------------------------------------------------------------------- visuals

func _poly(parent: Node, points: Array, color: Color, pos: Vector2 = Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p


func _build_visual() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	_scarf = _poly(_visual, [Vector2(-6, -17), Vector2(-34, -10), Vector2(-28, 2), Vector2(-6, -6)], Color("f2b84b"))
	_leg_l = _poly(_visual, [Vector2(-4, 0), Vector2(4, 0), Vector2(4, 17), Vector2(-4, 17)], Color("1b2b33"), Vector2(-5, 6))
	_leg_r = _poly(_visual, [Vector2(-4, 0), Vector2(4, 0), Vector2(4, 17), Vector2(-4, 17)], Color("24373f"), Vector2(5, 6))
	_torso = Node2D.new()
	_visual.add_child(_torso)
	_poly(_torso, [Vector2(-9, -18), Vector2(9, -18), Vector2(8, 8), Vector2(-8, 8)], Color("2f8f83"))
	_poly(_torso, [Vector2(-8, 2), Vector2(8, 2), Vector2(8, 5), Vector2(-8, 5)], Color("f2b84b"))
	_head = Node2D.new()
	_visual.add_child(_head)
	_poly(_head, [Vector2(-8, -32), Vector2(8, -32), Vector2(9, -19), Vector2(0, -15), Vector2(-9, -19)], Color("e8c39e"))
	_poly(_head, [Vector2(-10, -30), Vector2(-2, -36), Vector2(9, -31), Vector2(9, -26), Vector2(-4, -28), Vector2(-14, -18)], Color("1d4f4a"))
	_poly(_head, [Vector2(3, -27), Vector2(6, -27), Vector2(6, -24), Vector2(3, -24)], Color("0b1a20"))
	# The Wickblade: a sword with a lantern pommel.
	_blade_pivot = Node2D.new()
	_blade_pivot.position = Vector2(8, -6)
	_visual.add_child(_blade_pivot)
	var glow := _poly(_blade_pivot, [Vector2(0, -7), Vector2(42, -5), Vector2(50, 0), Vector2(42, 5), Vector2(0, 7)], Color(1.0, 0.82, 0.45, 0.28))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	_poly(_blade_pivot, [Vector2(2, -3), Vector2(36, -2), Vector2(44, 0), Vector2(36, 2), Vector2(2, 3)], Color("d9f7ff"))
	_poly(_blade_pivot, [Vector2(0, -7), Vector2(4, -7), Vector2(4, 7), Vector2(0, 7)], Color("f2b84b"))
	_poly(_blade_pivot, [Vector2(-9, -4), Vector2(-1, -4), Vector2(-1, 4), Vector2(-9, 4)], Color("a8802f"))
	_poly(_blade_pivot, [Vector2(-14, -3), Vector2(-9, -3), Vector2(-9, 3), Vector2(-14, 3)], Color("ffd27a"))
	_blade_pivot.rotation = deg_to_rad(-25.0)


func _animate(delta: float) -> void:
	var on_floor := is_on_floor()
	var speed_ratio := clampf(absf(velocity.x) / RUN_SPEED, 0.0, 1.0)

	if on_floor and speed_ratio > 0.1:
		var swing := sin(_time * 14.0) * 0.9 * speed_ratio
		_leg_l.rotation = swing
		_leg_r.rotation = -swing
		_torso.position.y = -absf(sin(_time * 14.0)) * 2.0
		_head.position.y = _torso.position.y
	elif not on_floor:
		_leg_l.rotation = 0.55
		_leg_r.rotation = -0.35
		_torso.position.y = 0.0
		_head.position.y = 0.0
	else:
		_leg_l.rotation = lerpf(_leg_l.rotation, 0.0, 12.0 * delta)
		_leg_r.rotation = lerpf(_leg_r.rotation, 0.0, 12.0 * delta)
		_torso.position.y = sin(_time * 3.0) * 0.8
		_head.position.y = _torso.position.y

	_scarf.rotation = clampf(-velocity.y * 0.0012, -0.5, 0.5) + sin(_time * 8.0) * 0.06 * (0.3 + speed_ratio)
	if _attack_t < 0.0:
		_blade_pivot.rotation = deg_to_rad(-25.0) + sin(_time * 3.0) * 0.04

	_sx = lerpf(_sx, 1.0, 12.0 * delta)
	_sy = lerpf(_sy, 1.0, 12.0 * delta)
	_visual.scale = Vector2(facing * _sx, _sy)

	if _invuln > 0.0 and not is_dead:
		_visual.modulate = Color(1, 0.5, 0.5, 0.5 + 0.5 * absf(sin(_time * 30.0)))
	elif not is_dead:
		_visual.modulate = Color.WHITE

	if camera:
		camera.offset.x = lerpf(camera.offset.x, facing * 70.0, 3.0 * delta)
