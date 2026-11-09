extends Node3D

const PORT := 2456
const MAX_PLAYERS := 12
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var players: Dictionary = {}
var status_label: Label
var address_input: LineEdit
var menu: Control
var world_root: Node3D
var is_host := false

func _ready() -> void:
    _build_world()
    _build_ui()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)
    _set_status("Offline • Host a world or join a friend")

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.68, 0.88)
    environment.ambient_light_energy = 0.8
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -28, 0)
    sun.light_energy = 1.4
    add_child(sun)

    world_root = Node3D.new()
    world_root.name = "World"
    add_child(world_root)

    var ground := StaticBody3D.new()
    var mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(100, 100)
    mesh.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.12, 0.34, 0.22)
    mesh.material_override = mat
    ground.add_child(mesh)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(100, 0.5, 100)
    shape.shape = box
    shape.position.y = -0.25
    ground.add_child(shape)
    ground.position.y = -0.25
    world_root.add_child(ground)

    for i in range(34):
        var tree := MeshInstance3D.new()
        var trunk := CylinderMesh.new()
        trunk.top_radius = 0.22
        trunk.bottom_radius = 0.32
        trunk.height = 2.2
        tree.mesh = trunk
        var tm := StandardMaterial3D.new()
        tm.albedo_color = Color(0.25, 0.13, 0.07)
        tree.material_override = tm
        var x := sin(float(i) * 12.31) * 36.0
        var z := cos(float(i) * 7.77) * 36.0
        tree.position = Vector3(x, 1.1, z)
        world_root.add_child(tree)
        var crown := MeshInstance3D.new()
        var cone := SphereMesh.new()
        cone.radius = 1.45
        cone.height = 3.2
        crown.mesh = cone
        var cm := StandardMaterial3D.new()
        cm.albedo_color = Color(0.07, 0.25, 0.15)
        crown.material_override = cm
        crown.position = Vector3(x, 3.0, z)
        world_root.add_child(crown)

    _add_landmark(Vector3(0, 1.5, -12), "Ancient Beacon", Color(0.15, 0.65, 1.0))
    _add_landmark(Vector3(15, 1.5, 8), "Crystal Shrine", Color(0.65, 0.25, 1.0))

func _add_landmark(pos: Vector3, label_text: String, color: Color) -> void:
    var pillar := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.8
    mesh.bottom_radius = 1.1
    mesh.height = 3.0
    pillar.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 0.7
    pillar.material_override = material
    pillar.position = pos
    world_root.add_child(pillar)
    var label := Label3D.new()
    label.text = label_text
    label.position = pos + Vector3(0, 2.4, 0)
    label.font_size = 48
    label.modulate = Color.WHITE
    world_root.add_child(label)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    menu = Control.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(menu)

    var panel := PanelContainer.new()
    panel.position = Vector2(24, 24)
    panel.custom_minimum_size = Vector2(330, 0)
    menu.add_child(panel)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 10)
    panel.add_child(vb)

    var title := Label.new()
    title.text = "AURORA ADVENTURE"
    title.add_theme_font_size_override("font_size", 24)
    vb.add_child(title)
    var subtitle := Label.new()
    subtitle.text = "Explore • Discover • Play together"
    vb.add_child(subtitle)
    address_input = LineEdit.new()
    address_input.placeholder_text = "Server IP (e.g. 203.0.113.10)"
    address_input.text = "127.0.0.1"
    vb.add_child(address_input)

    var host_btn := Button.new()
    host_btn.text = "Host World"
    host_btn.pressed.connect(host_game)
    vb.add_child(host_btn)
    var join_btn := Button.new()
    join_btn.text = "Join World"
    join_btn.pressed.connect(join_game)
    vb.add_child(join_btn)
    var leave_btn := Button.new()
    leave_btn.text = "Leave Session"
    leave_btn.pressed.connect(leave_game)
    vb.add_child(leave_btn)

    status_label = Label.new()
    status_label.text = "Starting..."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(status_label)

    var help := Label.new()
    help.text = "Move: WASD / left touch pad\nLook: drag screen / mouse\nJump: Space / JUMP button\nMobile: use the on-screen controls"
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(help)

    var jump := Button.new()
    jump.text = "JUMP"
    jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    jump.position = Vector2(-150, -100)
    jump.size = Vector2(120, 70)
    jump.pressed.connect(_mobile_jump)
    menu.add_child(jump)

    var touch_move := Button.new()
    touch_move.text = "MOVE"
    touch_move.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    touch_move.position = Vector2(24, -100)
    touch_move.size = Vector2(130, 70)
    touch_move.button_down.connect(func(): Input.action_press("move_forward"))
    touch_move.button_up.connect(func(): Input.action_release("move_forward"))
    menu.add_child(touch_move)

func _set_status(message: String) -> void:
    if is_instance_valid(status_label):
        status_label.text = message

func host_game() -> void:
    leave_game()
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, MAX_PLAYERS)
    if error != OK:
        _set_status("Could not host. Error: %s" % error)
        return
    multiplayer.multiplayer_peer = peer
    is_host = true
    _spawn_player(1)
    _set_status("Hosting on UDP %d • Share your public IP" % PORT)

func join_game() -> void:
    leave_game()
    var ip := address_input.text.strip_edges()
    if ip.is_empty():
        _set_status("Enter the host IP first")
        return
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_client(ip, PORT)
    if error != OK:
        _set_status("Could not connect. Error: %s" % error)
        return
    multiplayer.multiplayer_peer = peer
    _set_status("Connecting to %s:%d..." % [ip, PORT])

func leave_game() -> void:
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    for id in players.keys():
        if is_instance_valid(players[id]):
            players[id].queue_free()
    players.clear()
    is_host = false
    _set_status("Disconnected")

func _on_connected() -> void:
    _set_status("Connected! Waiting for world players...")
    _request_spawn.rpc_id(1)

func _on_connection_failed() -> void:
    _set_status("Connection failed. Check IP, port and internet.")

func _on_server_disconnected() -> void:
    leave_game()
    _set_status("Server disconnected")

func _on_peer_connected(id: int) -> void:
    if multiplayer.is_server():
        _spawn_player(id)
        for existing_id in players.keys():
            if existing_id != id:
                _spawn_remote.rpc_id(id, int(existing_id), players[existing_id].global_position)

func _on_peer_disconnected(id: int) -> void:
    if players.has(id):
        players[id].queue_free()
        players.erase(id)

@rpc("any_peer", "reliable")
func _request_spawn() -> void:
    if multiplayer.is_server():
        var id := multiplayer.get_remote_sender_id()
        _spawn_player(id)
        _spawn_remote.rpc_id(id, id, Vector3(0, 1, 0))
        for other_id in players.keys():
            if other_id != id:
                _spawn_remote.rpc_id(id, int(other_id), players[other_id].global_position)
        _broadcast_spawn.rpc(id, Vector3(0, 1, 0))

@rpc("authority", "call_local", "reliable")
func _broadcast_spawn(id: int, pos: Vector3) -> void:
    _spawn_remote(id, pos)

@rpc("authority", "reliable")
func _spawn_remote(id: int, pos: Vector3) -> void:
    if not players.has(id):
        _create_player(id, pos)

func _spawn_player(id: int) -> void:
    if not players.has(id):
        _create_player(id, Vector3(float(id % 4) * 2.0, 1, 0))
        if multiplayer.is_server():
            _broadcast_spawn.rpc(id, players[id].global_position)

func _create_player(id: int, pos: Vector3) -> void:
    var player := CharacterBody3D.new()
    player.name = str(id)
    player.set_script(load("res://scripts/player.gd"))
    player.set_multiplayer_authority(id)
    player.global_position = pos
    add_child(player)
    players[id] = player

func _mobile_jump() -> void:
    Input.action_press("jump")
    await get_tree().create_timer(0.15).timeout
    Input.action_release("jump")
