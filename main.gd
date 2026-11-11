extends Node

const PlayerScript := preload("res://player.gd")
const PORT := 7777
const MAX_PLAYERS := 12
const MAP_SEED := 4242
const MAP_SIZE := 300.0

var my_id := 0
var my_name := ""
var names := {}
var kills := {}
var players := {}
var local
var spawns: Array[Vector3] = []

var menu: Control
var hud: Control
var scope_ui: Control
var name_edit: LineEdit
var ip_edit: LineEdit
var status: Label
var feed_box: VBoxContainer
var title_lbl: Label
var kill_lbl: Label
var btns: Array[Control] = []
var joy_id := -1
var joy_origin := Vector2.ZERO
var joy := Vector2.ZERO
var look_id := -1

func _ready() -> void:
	build_map()
	build_menu()
	build_hud()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(func(): get_tree().reload_current_scene())
	multiplayer.peer_disconnected.connect(_on_peer_left)

# ---------------- MAP ----------------
func box(pos: Vector3, size: Vector3, color: Color) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	sb.add_child(mi)
	add_child(sb)

func build_map() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var h := MAP_SIZE / 2.0
	box(Vector3(0, -0.5, 0), Vector3(MAP_SIZE, 1, MAP_SIZE), Color(0.3, 0.5, 0.3))
	var wc := Color(0.4, 0.4, 0.45)
	box(Vector3(0, 4, h), Vector3(MAP_SIZE, 8, 1), wc)
	box(Vector3(0, 4, -h), Vector3(MAP_SIZE, 8, 1), wc)
	box(Vector3(h, 4, 0), Vector3(1, 8, MAP_SIZE), wc)
	box(Vector3(-h, 4, 0), Vector3(1, 8, MAP_SIZE), wc)
	# Penghalang / tembok / kontainer acak (sama di semua pemain karena seed tetap)
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	for i in 90:
		var sz := Vector3(rng.randf_range(2, 9), rng.randf_range(1, 6), rng.randf_range(2, 9))
		var p := Vector3(rng.randf_range(-h + 10, h - 10), sz.y / 2.0, rng.randf_range(-h + 10, h - 10))
		box(p, sz, Color.from_hsv(rng.randf(), 0.2, 0.6))
	for i in 24:
		spawns.append(Vector3(rng.randf_range(-h + 20, h - 20), 15, rng.randf_range(-h + 20, h - 20)))

func spawn_point() -> Vector3:
	return spawns[randi() % spawns.size()]

# ---------------- UI ----------------
func full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func big(c: Control, s: int = 30) -> void:
	c.add_theme_font_size_override("font_size", s)

func build_menu() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(menu)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	var t := Label.new()
	t.text = "AWM ARENA"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big(t, 56)
	v.add_child(t)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Masukkan nama (wajib)"
	name_edit.max_length = 12
	big(name_edit)
	v.add_child(name_edit)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "IP server"
	big(ip_edit)
	v.add_child(ip_edit)
	var hb := Button.new()
	hb.text = "BUAT SERVER (Host)"
	big(hb)
	hb.pressed.connect(_on_host)
	v.add_child(hb)
	var jb := Button.new()
	jb.text = "GABUNG SERVER"
	big(jb)
	jb.pressed.connect(_on_join)
	v.add_child(jb)
	status = Label.new()
	status.text = "Maks %d pemain per server" % MAX_PLAYERS
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big(status, 24)
	v.add_child(status)

func mkbtn(txt: String, ox: float, oy: float, w: float, h: float, toggle := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.toggle_mode = toggle
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = ox
	b.offset_top = oy
	b.offset_right = ox + w
	b.offset_bottom = oy + h
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0.75)
	big(b, 26)
	hud.add_child(b)
	btns.append(b)
	return b

func build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	hud = Control.new()
	full(hud)
	hud.hide()
	cl.add_child(hud)
	# crosshair
	var ch := ColorRect.new()
	ch.color = Color(1, 1, 1, 0.9)
	ch.anchor_left = 0.5
	ch.anchor_right = 0.5
	ch.anchor_top = 0.5
	ch.anchor_bottom = 0.5
	ch.offset_left = -3
	ch.offset_right = 3
	ch.offset_top = -3
	ch.offset_bottom = 3
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ch)
	# overlay scope
	scope_ui = Control.new()
	full(scope_ui)
	scope_ui.hide()
	hud.add_child(scope_ui)
	var hl := ColorRect.new()
	hl.color = Color(0, 0, 0, 0.9)
	full(hl)
	hl.anchor_top = 0.5
	hl.anchor_bottom = 0.5
	hl.offset_top = -1
	hl.offset_bottom = 1
	scope_ui.add_child(hl)
	var vl := ColorRect.new()
	vl.color = Color(0, 0, 0, 0.9)
	full(vl)
	vl.anchor_left = 0.5
	vl.anchor_right = 0.5
	vl.offset_left = -1
	vl.offset_right = 1
	scope_ui.add_child(vl)
	# skor
	kill_lbl = Label.new()
	kill_lbl.text = "Kill: 0"
	kill_lbl.position = Vector2(20, 14)
	big(kill_lbl, 34)
	hud.add_child(kill_lbl)
	# kill feed
	feed_box = VBoxContainer.new()
	feed_box.anchor_left = 1.0
	feed_box.anchor_right = 1.0
	feed_box.offset_left = -400
	feed_box.offset_right = -14
	feed_box.offset_top = 14
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(feed_box)
	# judul kill
	title_lbl = Label.new()
	full(title_lbl)
	title_lbl.anchor_top = 0.2
	title_lbl.anchor_bottom = 0.35
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate.a = 0.0
	big(title_lbl, 56)
	hud.add_child(title_lbl)
	# tombol
	var fire := mkbtn("TEMBAK", -190, -200, 150, 150)
	var scope := mkbtn("BIDIK", -190, -330, 150, 100)
	var jump := mkbtn("LOMPAT", -360, -150, 150, 110)
	var spr := mkbtn("SPRINT", -360, -280, 150, 100, true)
	var cro := mkbtn("JONGKOK", -360, -400, 150, 100, true)
	fire.pressed.connect(func(): if local: local.shoot())
	scope.pressed.connect(func(): if local: local.set_scope(not local.scoped))
	jump.button_down.connect(func(): if local: local.jump_req = true)
	spr.toggled.connect(func(on): if local: local.sprinting = on)
	cro.toggled.connect(func(on): if local: local.crouching = on)

func feed(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	big(l, 24)
	feed_box.add_child(l)
	if feed_box.get_child_count() > 6:
		feed_box.get_child(0).queue_free()
	get_tree().create_timer(5.0).timeout.connect(l.queue_free)

func show_title(text: String, c: Color) -> void:
	title_lbl.text = text
	title_lbl.modulate = Color(c.r, c.g, c.b, 1.0)
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_property(title_lbl, "modulate:a", 0.0, 0.7)

# ---------------- INPUT ----------------
func _input(ev: InputEvent) -> void:
	if local == null:
		return
	var w: float = get_viewport().get_visible_rect().size.x
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position
		if ev.pressed:
			for b in btns:
				if b.get_global_rect().has_point(p):
					return
			if p.x < w * 0.4:
				if joy_id == -1:
					joy_id = ev.index
					joy_origin = p
			elif look_id == -1:
				look_id = ev.index
		else:
			if ev.index == joy_id:
				joy_id = -1
				joy = Vector2.ZERO
			if ev.index == look_id:
				look_id = -1
	elif ev is InputEventScreenDrag:
		if ev.index == joy_id:
			joy = ((ev.position - joy_origin) / 90.0).limit_length(1.0)
		elif ev.index == look_id:
			var s: float = 0.004 * (0.25 if local.scoped else 1.0)
			local.look(ev.relative.x * s, ev.relative.y * s)

func _process(_d: float) -> void:
	if local == null:
		return
	var k := Vector2(
		int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
		int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	local.move_in = (joy + k).limit_length(1.0)
	if Input.is_key_pressed(KEY_SPACE):
		local.jump_req = true

# ---------------- NETWORK ----------------
func valid_name() -> bool:
	my_name = name_edit.text.strip_edges()
	if my_name == "":
		status.text = "Nama wajib diisi!"
		return false
	return true

func _on_host() -> void:
	if not valid_name():
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		status.text = "Gagal membuat server"
		return
	multiplayer.multiplayer_peer = peer
	my_id = 1
	add_player(1, my_name)

func _on_join() -> void:
	if not valid_name():
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip_edit.text.strip_edges(), PORT)
	if err != OK:
		status.text = "Gagal menyambung"
		return
	multiplayer.multiplayer_peer = peer
	status.text = "Menyambung..."

func _on_connected() -> void:
	my_id = multiplayer.get_unique_id()
	rpc_id(1, "register", my_name)

func _on_failed() -> void:
	multiplayer.multiplayer_peer = null
	status.text = "Gagal: server tidak ditemukan / penuh (maks 12)"

func _on_peer_left(id: int) -> void:
	if multiplayer.is_server():
		rpc("remove_player", id)

@rpc("any_peer", "reliable")
func register(n: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	n = n.strip_edges().left(12)
	if n == "":
		n = "Pemain" + str(id % 1000)
	for pid in names.keys():
		rpc_id(id, "add_player", pid, names[pid])
	rpc("add_player", id, n)

@rpc("authority", "call_local", "reliable")
func add_player(id: int, n: String) -> void:
	if players.has(id):
		return
	names[id] = n
	kills[id] = 0
	var p = PlayerScript.new()
	p.setup(id, n, self)
	var sp := spawn_point()
	p.position = sp
	p.net_pos = sp
	add_child(p)
	players[id] = p
	if id == my_id:
		local = p
		menu.hide()
		hud.show()
	feed(n + " bergabung")

@rpc("authority", "call_local", "reliable")
func remove_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)
	if names.has(id):
		feed(String(names[id]) + " keluar")
	names.erase(id)
	kills.erase(id)

@rpc("any_peer", "call_local", "reliable")
func announce(killer: int, victim: int) -> void:
	var kn: String = names.get(killer, "?")
	var vn: String = names.get(victim, "?")
	kills[killer] = int(kills.get(killer, 0)) + 1
	feed(kn + "  >>  " + vn)
	if killer == my_id:
		kill_lbl.text = "Kill: " + str(kills[killer])
		show_title("KILL  " + vn, Color(1, 0.8, 0.1))
	elif victim == my_id:
		show_title("Dibunuh " + kn + " (respawn 3 dtk)", Color(1, 0.3, 0.3))
