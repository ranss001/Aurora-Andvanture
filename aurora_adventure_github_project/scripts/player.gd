extends CharacterBody3D

const SPEED := 6.0
const JUMP_VELOCITY := 5.5
var gravity := 18.0
var camera_pivot: Node3D
var camera: Camera3D
var sync_timer := 0.0
var remote_target := Vector3.ZERO

func _ready() -> void:
    _make_character()
    if is_multiplayer_authority():
        camera.current = true
    else:
        camera.current = false
        set_process_input(false)

func _make_character() -> void:
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.45
    capsule.height = 1.8
    var body := MeshInstance3D.new()
    body.mesh = capsule
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.2, 0.72, 0.95) if name == "1" else Color(0.95, 0.58, 0.2)
    body.material_override = material
    body.position.y = 0.9
    add_child(body)

    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.45
    shape.height = 1.8
    collision.shape = shape
    collision.position.y = 0.9
    add_child(collision)

    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.5
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 2.0, 5.5)
    camera.look_at_from_position(camera.position, Vector3.ZERO)
    camera_pivot.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
    if not is_multiplayer_authority():
        return
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        camera_pivot.rotate_y(-event.relative.x * 0.004)
        camera.rotate_x(-event.relative.y * 0.004)
        camera.rotation.x = clamp(camera.rotation.x, -1.0, 0.7)
    elif event is InputEventScreenDrag:
        camera_pivot.rotate_y(-event.relative.x * 0.004)
        camera.rotate_x(-event.relative.y * 0.004)
        camera.rotation.x = clamp(camera.rotation.x, -1.0, 0.7)

func _physics_process(delta: float) -> void:
    if is_multiplayer_authority():
        _move_local(delta)
        sync_timer += delta
        if sync_timer >= 0.05 and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
            sync_timer = 0.0
            _send_state.rpc(global_position, rotation.y)
    else:
        global_position = global_position.lerp(remote_target, min(delta * 12.0, 1.0))

func _move_local(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var input_dir := Vector2.ZERO
    input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    input_dir.y = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
    if input_dir == Vector2.ZERO:
        input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var direction := (camera_pivot.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    direction.y = 0
    if direction.length() > 0.01:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED * delta * 4)
        velocity.z = move_toward(velocity.z, 0, SPEED * delta * 4)
    move_and_slide()

@rpc("authority", "unreliable")
func _send_state(pos: Vector3, yaw: float) -> void:
    _apply_state.rpc(pos, yaw)

@rpc("authority", "call_local", "unreliable")
func _apply_state(pos: Vector3, yaw: float) -> void:
    if not is_multiplayer_authority():
        remote_target = pos
        rotation.y = yaw
