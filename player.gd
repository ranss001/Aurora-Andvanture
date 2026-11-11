extends CharacterBody3D

const WALK := 5.0
const SPRINT := 9.0
const CROUCH := 2.5
const JUMP := 6.5
const GRAVITY := 18.0
const COOLDOWN := 1.5   # jeda bolt-action AWM (detik)

var pname := ""
var alive := true
var mine := false
var main
var head: Node3D
var cam: Camera3D
var col: CollisionShape3D
var shape: CapsuleShape3D
var body: MeshInstance3D
var tag: Label3D
var gun: MeshInstance3D
var pitch := 0.0
var move_in := Vector2.ZERO
var sprinting := false
var crouching := false
var scoped := false
var jump_req := false
var last_shot := -10.0
var net_pos := Vector3.ZERO
var net_yaw := 0.0

func setup(id: int, n: String, m) -> void:
	name = str(id)
	pname = n
	main = m
	mine = (id == m.my_id)
	set_multiplayer_authority(id)
	shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col = CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	body = MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(id * 0.137, 1.0), 0.7, 0.9)
	cm.material = mat
	body.mesh = cm
	body.position.y = 0.9
	add_child(body)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75
	head.add_child(cam)
	gun = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.1, 1.2)
	gun.mesh = bm
	gun.position = Vector3(0.25, -0.25, -0.8)
	cam.add_child(gun)
	tag = Label3D.new()
	tag.text = n
	tag.position.y = 2.3
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.005
	tag.no_depth_test = true
	add_child(tag)
	if mine:
		cam.current = true
		body.visible = false
		tag.visible = false
	else:
		gun.visible = false

func look(dx: float, dy: float) -> void:
	rotation.y -= dx
	pitch = clamp(pitch - dy, -1.4, 1.4)
	head.rotation.x = pitch

func set_scope(s: bool) -> void:
	scoped = s
	cam.fov = 12.0 if s else 75.0
	gun.visible = not s
	main.scope_ui.visible = s

func _physics_process(d: float) -> void:
	if not mine:
		var k: float = clamp(d * 15.0, 0.0, 1.0)
		global_position = global_position.lerp(net_pos, k)
		rotation.y = lerp_angle(rotation.y, net_yaw, k)
		return
	if not alive:
		return
	var spd := WALK
	if crouching:
		spd = CROUCH
	elif sprinting:
		spd = SPRINT
	var dir: Vector3 = transform.basis * Vector3(move_in.x, 0, move_in.y)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if is_on_floor():
		if jump_req and not crouching:
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * d
	jump_req = false
	move_and_slide()
	var h := 1.1 if crouching else 1.8
	shape.height = h
	col.position.y = h / 2.0
	head.position.y = lerp(head.position.y, h - 0.2, d * 12.0)
	if global_position.y < -30.0:
		global_position = main.spawn_point()
	rpc("net_sync", global_position, rotation.y, crouching)

@rpc("authority", "unreliable")
func net_sync(p: Vector3, y: float, c: bool) -> void:
	net_pos = p
	net_yaw = y
	body.scale.y = 0.65 if c else 1.0
	body.position.y = 0.9 * body.scale.y

func shoot() -> void:
	if not mine or not alive:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_shot < COOLDOWN:
		return
	last_shot = now
	pitch = clamp(pitch + 0.03, -1.4, 1.4)
	head.rotation.x = pitch
	var from: Vector3 = cam.global_position
	var to: Vector3 = from + (-cam.global_transform.basis.z) * 600.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if r.has("collider"):
		var v = r["collider"]
		if v.has_method("hit") and v.alive:
			v.rpc_id(v.get_multiplayer_authority(), "hit", main.my_id)

# Dipanggil di peer korban. 1 tembakan = mati.
@rpc("any_peer", "call_remote", "reliable")
func hit(killer: int) -> void:
	if not mine or not alive:
		return
	rpc("set_alive", false, global_position)
	main.rpc("announce", killer, int(String(name)))
	await get_tree().create_timer(3.0).timeout
	rpc("set_alive", true, main.spawn_point())

@rpc("authority", "call_local", "reliable")
func set_alive(a: bool, p: Vector3) -> void:
	alive = a
	visible = a
	col.set_deferred("disabled", not a)
	if mine and not a:
		set_scope(false)
	if a:
		global_position = p
		net_pos = p
		velocity = Vector3.ZERO
