extends CanvasLayer
## The arena's presentation layer. All gameplay and persistence belong to the host.

signal action(name: String, payload: Variant)

const INK := Color("09121d")
const PANEL := Color("10212d")
const LINE := Color("29404b")
const CYAN := Color("9ce8ed")
const IVORY := Color("f1e9d4")
const MUTED := Color("a5b7bd")
const BRASS := Color("bf9c63")
const CORAL := Color("ef927e")

class Sigil extends Control:
	var kind := "lance"
	var tint := Color("9ce8ed")
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.39
		draw_arc(c, r, 0.0, TAU, 48, Color(tint, 0.25), 1.0, true)
		match kind:
			"crown", "resonance":
				for i in 7:
					var a := TAU * float(i) / 7.0 - PI * 0.5
					var p := c + Vector2.from_angle(a) * r * 0.72
					var q := Vector2.from_angle(a) * r * 0.26
					draw_line(p - q, p + q, tint, 2.0, true)
				draw_arc(c, r * 0.46, 0.0, TAU, 36, tint, 1.0, true)
			"cataclysm", "aftershock", "gravity":
				for i in 8:
					var d := Vector2.from_angle(TAU * float(i) / 8.0)
					draw_line(c + d * r * 0.22, c + d * r * (1.0 if i % 2 == 0 else 0.66), tint, 2.0, true)
				draw_arc(c, r * 0.55, 0.0, TAU, 36, Color(tint, 0.65), 1.0, true)
			"chain":
				for i in 3:
					draw_arc(c + Vector2((i - 1) * r * 0.58, 0), r * 0.34, 0, TAU, 24, tint, 2.0, true)
			"fork":
				draw_line(c + Vector2(0, r), c, tint, 2.0, true)
				for i in 3:
					draw_line(c, c + Vector2((i - 1) * r * 0.8, -r * 0.8), tint, 2.0, true)
			"echo":
				for i in 3:
					var x := c.x + (i - 1) * r * 0.62
					draw_polyline(PackedVector2Array([Vector2(x - r * 0.2, c.y - r * 0.68), Vector2(x + r * 0.2, c.y), Vector2(x - r * 0.2, c.y + r * 0.68)]), Color(tint, 1.0 - i * 0.22), 2.0, true)
			"overload":
				draw_circle(c, r * 0.3, tint)
				for i in 3:
					var d := Vector2.from_angle(TAU * i / 3.0 - PI * 0.5)
					draw_line(c + d * r * 0.55, c + d * r, tint, 2.0, true)
			_:
				draw_polyline(PackedVector2Array([c + Vector2(r * 0.3, -r), c + Vector2(-r * 0.3, r * 0.03), c + Vector2(r * 0.18, -r * 0.04), c + Vector2(-r * 0.3, r)]), tint, 2.5, true)

class MenuAtmosphere extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.018, 0.037, 0.056, 0.81))
		var center := Vector2(size.x * 0.79, size.y * 0.48)
		var radius := minf(size.x * 0.21, size.y * 0.38)
		for i in 5:
			draw_arc(center, radius * (0.56 + i * 0.12), -PI * 0.83, PI * 0.93, 100, Color(0.55, 0.76, 0.79, 0.035 + i * 0.014), 1.0, true)
		for i in 36:
			var a := TAU * float(i) / 36.0
			var d := Vector2.from_angle(a)
			draw_line(center + d * radius * 1.065, center + d * radius * (1.095 if i % 3 == 0 else 1.08), Color(0.75, 0.61, 0.39, 0.26), 1.0, true)
		draw_line(Vector2(40, 27), Vector2(size.x - 40, 27), Color(0.75, 0.61, 0.39, 0.23), 1.0)
		draw_line(Vector2(40, size.y - 27), Vector2(size.x - 40, size.y - 27), Color(0.75, 0.61, 0.39, 0.23), 1.0)

var _root: Control
var _hud: Control
var _menu: Control
var _menu_content: Control
var _lab: PanelContainer
var _screen := "title"
var _screen_data: Dictionary = {}
var _gameplay_visible := false
var _catalog: Array[Dictionary] = []
var _hud_data: Dictionary = {}
var _body_font: SystemFont
var _display_font: SystemFont
var _health_bar: ProgressBar
var _health_text: Label
var _wave_text: Label
var _enemy_text: Label
var _time_text: Label
var _crown_bar: ProgressBar
var _crown_text: Label
var _charge_bar: ProgressBar
var _charge_text: Label
var _dash_text: Label
var _slots: Array[Label] = []
var _boss: VBoxContainer
var _boss_bar: ProgressBar
var _boss_text: Label
var _banner: Label
var _notification: Label
var _notify_left := 0.0
var _lab_buttons: Dictionary = {}
var _lab_selection: Array = ["__uninitialized"]
var _lab_description: Label
var _settings_readouts: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(["Avenir Next", "Avenir", "Noto Sans", "DejaVu Sans"])
	_body_font.font_weight = 400
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(["Baskerville", "Georgia", "Noto Serif", "DejaVu Serif"])
	_root = Control.new()
	_root.name = "Interface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var theme := Theme.new()
	theme.default_font = _body_font
	theme.default_font_size = 20
	_root.theme = theme
	_build_hud()
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_menu)
	var atmosphere := MenuAtmosphere.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.resized.connect(atmosphere.queue_redraw)
	_menu.add_child(atmosphere)
	_menu_content = Control.new()
	_menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_menu_content)
	_build_lab()
	_notification = _label("", 21, IVORY)
	_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notification.offset_left = -380
	_notification.offset_right = 380
	_notification.offset_top = 144
	_notification.offset_bottom = 183
	_root.add_child(_notification)
	show_screen(_screen, _screen_data)

func _process(delta: float) -> void:
	if _notification == null:
		return
	_notify_left = maxf(0.0, _notify_left - delta)
	_notification.modulate.a = minf(1.0, _notify_left * 3.0)

func show_screen(screen: String, data: Dictionary = {}) -> void:
	_screen = screen
	_screen_data = data.duplicate(true)
	if not is_node_ready():
		return
	for child in _menu_content.get_children():
		child.queue_free()
		_menu_content.remove_child(child)
	_menu.visible = screen not in ["hud", "lab"]
	if screen in ["hud", "lab"]:
		_gameplay_visible = true
	elif screen in ["title", "victory", "defeat"]:
		_gameplay_visible = false
	_hud.visible = _gameplay_visible
	_lab.visible = screen == "lab"
	if screen == "lab":
		_update_lab(data.get("modifiers", _hud_data.get("modifiers", [])))
	match screen:
		"title": _build_title(data)
		"upgrade": _build_upgrade(data)
		"pause": _build_pause()
		"settings": _build_settings(data.get("settings", {}))
		"victory", "defeat": _build_results(screen, data)
		"confirm": _build_confirm(data)
	if _menu.visible:
		_focus_first_button(_menu_content)

func set_modifier_catalog(catalog: Array[Dictionary]) -> void:
	_catalog = catalog.duplicate(true)
	if is_node_ready():
		_rebuild_lab_modifiers()

func update_hud(data: Dictionary) -> void:
	_hud_data = data.duplicate(true)
	if _health_bar == null:
		return
	var health := float(data.get("health", 100))
	var max_health := maxf(1.0, float(data.get("max_health", 100)))
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_text.text = "%d / %d" % [ceili(health), int(max_health)]
	var lab_mode := bool(data.get("lab", false))
	_wave_text.text = "SPELL LABORATORY" if lab_mode else "ENCOUNTER %02d / 06" % int(data.get("wave", 1))
	_enemy_text.text = "%02d  %s" % [int(data.get("enemy_count", 0)), "TARGETS" if lab_mode else "HOSTILES"]
	_time_text.text = _format_time(float(data.get("elapsed", 0)))
	var cooldown := float(data.get("crown_cd", 0.0))
	_crown_bar.value = 1.0 - clampf(cooldown / 6.0, 0.0, 1.0)
	_crown_text.text = "READY" if cooldown <= 0 else "%.1f s" % cooldown
	_crown_text.modulate = CYAN if cooldown <= 0 else MUTED
	var charge_value := float(data.get("charge", 0))
	_charge_bar.value = charge_value
	_charge_text.text = "UNLEASH" if charge_value >= 100 else "%02d%%" % int(charge_value)
	_charge_text.modulate = IVORY if charge_value >= 100 else MUTED
	var dash_cd := float(data.get("dash_cd", 0.0))
	_dash_text.text = "SPACE   DASH" if dash_cd <= 0 else "DASH   %.1f s" % dash_cd
	var modifiers: Array = data.get("modifiers", [])
	for i in 3:
		_slots[i].text = _modifier(str(modifiers[i])).get("name", str(modifiers[i]).capitalize()) if i < modifiers.size() else "Empty law"
		_slots[i].modulate = CYAN if i < modifiers.size() else Color(MUTED, 0.5)
	var boss_health := float(data.get("boss_health", 0))
	_boss.visible = boss_health > 0 and float(data.get("boss_max_health", 0)) > 0
	if _boss.visible:
		_boss_bar.max_value = float(data.get("boss_max_health", 1))
		_boss_bar.value = boss_health
		_boss_text.text = "TEMPEST WARDEN   /   " + ("THE OPEN STORM" if int(data.get("boss_phase", 1)) == 2 else "SEALED CORE")
	_banner.text = str(data.get("banner", ""))
	_banner.visible = not _banner.text.is_empty()
	if _screen in ["hud", "lab"]:
		_lab.visible = lab_mode
	if lab_mode:
		_update_lab(modifiers)

func notify(message: String) -> void:
	if _notification == null:
		return
	_notification.text = message
	var lower := message.to_lower()
	if "crown" in lower or "cataclysm" in lower or "charge" in lower:
		_notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		var offset := 280.0 if "cataclysm" in lower or "charge" in lower else 60.0
		_notification.offset_left = offset - 280
		_notification.offset_right = offset + 280
		_notification.offset_top = -189
		_notification.offset_bottom = -147
	else:
		_notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_notification.offset_left = -380
		_notification.offset_right = 380
		_notification.offset_top = 144
		_notification.offset_bottom = 183
	_notify_left = 2.7
	_notification.modulate.a = 1.0

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hud)
	var vitals := _panel(Vector2(310, 101), Color(INK, 0.88))
	_place(vitals, _hud, 32, 36, 342, 137)
	var vitals_box := _padded(vitals, 20, 13)
	var health_header := HBoxContainer.new()
	vitals_box.add_child(health_header)
	health_header.add_child(_label("VITALITY", 16, BRASS, true))
	_health_text = _label("100 / 100", 17, IVORY)
	_health_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_header.add_child(_health_text)
	_health_bar = _bar(CYAN, 100, 6)
	vitals_box.add_child(_health_bar)
	var vitality_note := _label("STORMWRIGHT", 13, MUTED, true)
	vitals_box.add_child(vitality_note)
	var progress := VBoxContainer.new()
	progress.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(progress, _hud, -260, 37, 260, 113, Control.PRESET_CENTER_TOP)
	_wave_text = _label("ENCOUNTER 01 / 06", 19, IVORY, true)
	_wave_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_child(_wave_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	progress.add_child(row)
	_enemy_text = _label("00  HOSTILES", 14, MUTED, true)
	row.add_child(_enemy_text)
	row.add_child(_label("/", 14, BRASS))
	_time_text = _label("00:00", 14, MUTED)
	row.add_child(_time_text)
	var pause_button := _button("ESC   PAUSE", "pause", null, false, 15)
	_place(pause_button, _hud, -184, 38, -34, 80, Control.PRESET_TOP_RIGHT)
	_boss = VBoxContainer.new()
	_place(_boss, _hud, -260, 109, 260, 157, Control.PRESET_CENTER_TOP)
	_boss_text = _label("TEMPEST WARDEN", 13, CORAL, true)
	_boss_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss.add_child(_boss_text)
	_boss_bar = _bar(CORAL, 1, 5)
	_boss.add_child(_boss_bar)
	_boss.hide()
	_banner = _label("", 32, IVORY)
	_banner.add_theme_font_override("font", _display_font)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_banner, _hud, -520, 192, 520, 252, Control.PRESET_CENTER_TOP)
	var loadout := VBoxContainer.new()
	loadout.add_theme_constant_override("separation", 7)
	_place(loadout, _hud, 34, -111, 390, -34, Control.PRESET_BOTTOM_LEFT)
	loadout.add_child(_label("EQUIPPED LAWS", 13, BRASS, true))
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 17)
	loadout.add_child(slot_row)
	for i in 3:
		var slot := VBoxContainer.new()
		slot_row.add_child(slot)
		slot.add_child(_label("0%d" % (i + 1), 12, BRASS))
		var title := _label("Empty law", 17, MUTED)
		slot.add_child(title)
		_slots.append(title)
	var spell_row := HBoxContainer.new()
	spell_row.add_theme_constant_override("separation", 10)
	_place(spell_row, _hud, -462, -137, 462, -32, Control.PRESET_CENTER_BOTTOM)
	# Bottom spells are slightly right of center, keeping the build summary separate.
	spell_row.offset_left = -265
	spell_row.offset_right = 421
	_spell_tile(spell_row, "lance", "STORM LANCE", "LMB  /  HOLD", "READY")
	var crown := _spell_tile(spell_row, "crown", "STORM CROWN", "RMB", "READY")
	_crown_text = crown["status"]
	_crown_bar = crown["bar"]
	var ultimate := _spell_tile(spell_row, "cataclysm", "CATACLYSM", "Q", "00%")
	_charge_text = ultimate["status"]
	_charge_bar = ultimate["bar"]
	_charge_bar.max_value = 100
	var movement := VBoxContainer.new()
	movement.alignment = BoxContainer.ALIGNMENT_END
	_place(movement, _hud, -245, -87, -34, -34, Control.PRESET_BOTTOM_RIGHT)
	_dash_text = _label("SPACE   DASH", 16, IVORY, true)
	_dash_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	movement.add_child(_dash_text)
	var move_label := _label("WASD / ARROWS   MOVE", 13, MUTED, true)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	movement.add_child(move_label)

func _spell_tile(parent: Node, icon: String, title: String, key: String, status: String) -> Dictionary:
	var panel := _panel(Vector2(210, 105), Color(INK, 0.9))
	parent.add_child(panel)
	var box := _padded(panel, 16, 11)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	var sigil := Sigil.new()
	sigil.kind = icon
	sigil.custom_minimum_size = Vector2(35, 35)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sigil)
	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 1)
	top.add_child(text_column)
	text_column.add_child(_label(title, 13, IVORY, true))
	text_column.add_child(_label(key, 12, BRASS, true))
	var state_label := _label(status, 13, CYAN, true)
	box.add_child(state_label)
	var bar := _bar(CYAN if icon != "cataclysm" else BRASS, 1, 3)
	bar.value = 1
	box.add_child(bar)
	return {"status": state_label, "bar": bar}

func _build_title(data: Dictionary) -> void:
	_hud.hide()
	var outer := MarginContainer.new()
	_place(outer, _menu_content, 100, 73, 720, -64, Control.PRESET_FULL_RECT)
	outer.anchor_right = 0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	outer.add_child(column)
	column.add_child(_label("THE OBSIDIAN CIRCUIT", 16, BRASS, true))
	var title := _label("STORMWRIGHT", 72, IVORY)
	title.add_theme_font_override("font", _display_font)
	column.add_child(title)
	column.add_child(_label("Write the laws. Become the storm.", 25, CYAN))
	_spacer(column, 13)
	var intro := _label("Three impossible spells. Eight ways to transform them.\nOne temple waiting to be torn apart.", 20, MUTED)
	column.add_child(intro)
	_spacer(column, 18)
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size.x = 380
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	buttons.add_child(_button("ENTER THE CIRCUIT", "start", null, true))
	buttons.add_child(_button("SPELL LABORATORY", "lab"))
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 10)
	buttons.add_child(secondary)
	secondary.add_child(_button("SETTINGS", "settings"))
	if not OS.has_feature("web"):
		secondary.add_child(_button("QUIT", "quit"))
	_spacer(column, 12)
	column.add_child(_label("Move  WASD     Aim  MOUSE     Dash  SPACE\nLance  HOLD LMB     Crown  RMB     Cataclysm  Q", 16, MUTED))
	if data.has("best") and not str(data["best"]).is_empty():
		_spacer(column, 5)
		column.add_child(_label(_best_text(data["best"]), 14, BRASS))
	var sigil := Sigil.new()
	sigil.kind = "cataclysm"
	sigil.tint = CYAN
	_place(sigil, _menu_content, -260, -260, 260, 260, Control.PRESET_CENTER)
	sigil.anchor_left = 0.79
	sigil.anchor_right = 0.79
	var note := _label("A SPELLCRAFT ARENA", 14, BRASS, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(note, _menu_content, -270, 200, 270, 240, Control.PRESET_CENTER)
	note.anchor_left = 0.79
	note.anchor_right = 0.79

func _build_upgrade(data: Dictionary) -> void:
	var replacing := not str(data.get("replace_id", "")).is_empty()
	var column := _center_column(Vector2(1100, 610))
	column.add_child(_eyebrow("SPELL COMPOSITION   /   THREE LAWS"))
	column.add_child(_heading("Rewrite a law" if replacing else "Choose your next law", 46))
	var new_id := str(data.get("replace_id", ""))
	var modifiers: Array = data.get("modifiers", [])
	var subtitle := "Combat rests. Choose a transformation, or keep your current spellcraft."
	if replacing:
		subtitle = "Add %s. Select the law it will replace; your other two remain equipped." % str(_modifier(new_id).get("name", new_id))
	column.add_child(_center_label(subtitle, 19, MUTED))
	_spacer(column, 18)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	column.add_child(cards)
	if replacing:
		for i in modifiers.size():
			var result: Array = modifiers.duplicate()
			result[i] = new_id
			_modifier_card(cards, str(modifiers[i]), i, "replace_modifier", i, "REPLACE WITH " + str(_modifier(new_id).get("name", new_id)).to_upper(), "New build: " + _build_names(result))
	else:
		var choices: Array = data.get("choices", [])
		for i in choices.size():
			_modifier_card(cards, str(choices[i]), i, "choose_modifier", str(choices[i]))
	_spacer(column, 14)
	var skip := _button("KEEP CURRENT BUILD", "skip", null, false, 16)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.custom_minimum_size.x = 290
	column.add_child(skip)

func _modifier_card(parent: Node, id: String, index: int, action_name: String, payload: Variant, footer := "INSCRIBE THIS LAW", preview := "") -> void:
	var item := _modifier(id)
	var card := _button("", action_name, payload)
	card.custom_minimum_size = Vector2(330, 324 if preview.is_empty() else 360)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 21)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 11)
	margin.add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var glyph := Sigil.new()
	glyph.kind = id
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.custom_minimum_size = Vector2(62, 62)
	top.add_child(glyph)
	var number := _label("0%d" % (index + 1), 19, BRASS)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(number)
	box.add_child(_label(str(item.get("name", id.capitalize())), 28, IVORY))
	var applies: Variant = item.get("spells", [])
	box.add_child(_label(_spell_list(applies), 12, BRASS, true))
	var description := _label(str(item.get("description", "Transform your spellcraft.")), 18, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	if not preview.is_empty():
		var result := _label(preview, 15, CYAN)
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(result)
	box.add_child(_label(footer, 12, CYAN, true))

func _build_pause() -> void:
	var box := _center_column(Vector2(620, 560))
	box.add_child(_eyebrow("THE STORM CAN WAIT"))
	box.add_child(_heading("Paused", 55))
	_spacer(box, 15)
	box.add_child(_button("RESUME", "resume", null, true))
	box.add_child(_button("RESTART RUN", "restart"))
	box.add_child(_button("SETTINGS", "settings"))
	box.add_child(_button("RETURN TO TITLE", "title"))
	_spacer(box, 13)
	box.add_child(_center_label("WASD / arrows  Move    Mouse  Aim    Space  Dash\nHold LMB  Lance    RMB  Crown    Q  Cataclysm", 17, MUTED))

func _build_settings(settings: Dictionary) -> void:
	_settings_readouts.clear()
	var box := _center_column(Vector2(710, 670))
	box.add_child(_eyebrow("MAKE THE STORM YOURS"))
	box.add_child(_heading("Settings", 48))
	_spacer(box, 13)
	_slider_row(box, "Master volume", "master", float(settings.get("master", 0.8)))
	_slider_row(box, "Spell & combat sound", "effects", float(settings.get("effects", 0.8)))
	_slider_row(box, "Arena ambience", "ambience", float(settings.get("ambience", 0.5)))
	_slider_row(box, "Camera shake", "shake", float(settings.get("shake", 0.45)))
	_spacer(box, 7)
	_toggle_row(box, "Reduced flash", "Softer peaks of light during impacts.", "reduced_flash", bool(settings.get("reduced_flash", false)))
	_toggle_row(box, "Reduced particles", "Fewer fragments and trails; identical spell behavior.", "reduced_particles", bool(settings.get("reduced_particles", false)))
	_spacer(box, 10)
	box.add_child(_button("DONE", "back", null, true))
	box.add_child(_center_label("Changes apply immediately and are saved automatically.", 15, MUTED))

func _slider_row(parent: Node, title: String, key: String, value: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	parent.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_label(title, 20, IVORY))
	var readout := _label("%d%%" % roundi(value * 100), 17, CYAN)
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	_settings_readouts[key] = readout
	var slider := HSlider.new()
	slider.custom_minimum_size.y = 30
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = value
	for entry in [["slider", Color("1b313e")], ["grabber_area", BRASS], ["grabber_area_highlight", CYAN]]:
		var track := _style(entry[1], Color.TRANSPARENT, 0, 3)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		slider.add_theme_stylebox_override(entry[0], track)
	slider.value_changed.connect(func(v: float):
		readout.text = "%d%%" % roundi(v * 100)
		action.emit("setting", {"key": key, "value": v})
	)
	box.add_child(slider)

func _toggle_row(parent: Node, title: String, note: String, key: String, enabled: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = enabled
	toggle.custom_minimum_size.y = 35
	toggle.add_theme_font_size_override("font_size", 20)
	toggle.add_theme_color_override("font_color", IVORY)
	toggle.add_theme_color_override("font_hover_color", CYAN)
	toggle.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, BRASS, 1))
	toggle.toggled.connect(func(value: bool): action.emit("setting", {"key": key, "value": value}))
	parent.add_child(toggle)
	parent.add_child(_label(note, 15, MUTED))

func _build_results(screen: String, data: Dictionary) -> void:
	_hud.hide()
	var won := screen == "victory"
	var box := _center_column(Vector2(770, 610))
	box.add_child(_eyebrow("THE CIRCUIT IS COMPLETE" if won else "THE CIRCUIT REMEMBERS"))
	box.add_child(_heading("The storm is yours." if won else "Even storms fall.", 54))
	box.add_child(_center_label("The Warden has fallen. Your laws endure." if won else "Take what you learned. Write a different ending.", 21, MUTED))
	_spacer(box, 18)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 74)
	box.add_child(stats)
	_stat(stats, "TIME", _format_time(float(data.get("elapsed", 0))))
	_stat(stats, "DEFEATED", str(data.get("kills", 0)))
	_stat(stats, "ENCOUNTER", "%d / 6" % int(data.get("wave", 6 if won else 1)))
	_spacer(box, 10)
	box.add_child(_center_label("YOUR SPELLCRAFT", 13, BRASS))
	box.add_child(_center_label(_build_names(data.get("modifiers", [])), 22, CYAN))
	if data.has("best"):
		box.add_child(_center_label(_best_text(data["best"]), 16, MUTED))
	_spacer(box, 18)
	box.add_child(_button("WRITE ANOTHER STORM", "restart", null, true))
	box.add_child(_button("RETURN TO TITLE", "title"))

func _build_confirm(data: Dictionary) -> void:
	var box := _center_column(Vector2(680, 340))
	box.add_child(_eyebrow("LEAVE THIS STORM BEHIND?"))
	box.add_child(_heading("Abandon this run?", 44))
	var description := _center_label(str(data.get("confirm_text", "Your current encounter and spell build will be lost.")), 20, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	_spacer(box, 18)
	box.add_child(_button("KEEP PLAYING", "cancel", null, true))
	box.add_child(_button("CONFIRM", "confirm"))

func _build_lab() -> void:
	_lab = _panel(Vector2(274, 0), Color(INK, 0.93))
	_place(_lab, _root, 33, 179, 325, 651)
	var box := _padded(_lab, 18, 16)
	box.add_child(_label("WRITE YOUR SPELLCRAFT", 13, BRASS, true))
	box.add_child(_label("Equip up to three laws", 20, IVORY))
	var grid := GridContainer.new()
	grid.name = "ModifierGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	_lab_description = _label("Choose a law to reshape your spells. Select it again to remove it.", 15, MUTED)
	_lab_description.custom_minimum_size.y = 93
	_lab_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_lab_description)
	box.add_child(_button("REFILL HEALTH & CHARGE", "lab_refill", null, true, 13))
	box.add_child(_button("RESET TARGETS", "lab_reset", null, false, 13))
	box.add_child(_label("ESC   Menu & settings", 13, MUTED))
	_rebuild_lab_modifiers()
	_lab.hide()

func _rebuild_lab_modifiers() -> void:
	if _lab == null:
		return
	var grid := _lab.find_child("ModifierGrid", true, false)
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
		grid.remove_child(child)
	_lab_buttons.clear()
	_lab_selection = ["__rebuild"]
	for modifier in _catalog:
		var id := str(modifier.get("id", ""))
		var button := _button(str(modifier.get("name", id.capitalize())), "lab_modifier", id, false, 14)
		button.custom_minimum_size = Vector2(119, 38)
		button.tooltip_text = str(modifier.get("description", ""))
		button.mouse_entered.connect(func():
			_lab_description.text = str(modifier.get("description", "")) + "\n" + _spell_list(modifier.get("spells", []))
		)
		grid.add_child(button)
		_lab_buttons[id] = button

func _update_lab(modifiers: Array) -> void:
	if _lab_selection == modifiers:
		return
	_lab_selection = modifiers.duplicate()
	for id in _lab_buttons:
		var button: Button = _lab_buttons[id]
		var selected: bool = id in modifiers
		button.add_theme_stylebox_override("normal", _style(Color("1b3943") if selected else Color(PANEL, 0.7), CYAN if selected else LINE, 1))
		button.add_theme_color_override("font_color", CYAN if selected else MUTED)
		button.text = ("• " if selected else "") + str(_modifier(id).get("name", str(id).capitalize()))

func _modifier(id: String) -> Dictionary:
	for entry in _catalog:
		if str(entry.get("id", "")) == id:
			return entry
	return {"id": id, "name": id.capitalize(), "description": "", "spells": []}

func _build_names(modifiers: Array) -> String:
	if modifiers.is_empty():
		return "Pure storm · no modifiers"
	var names := PackedStringArray()
	for id in modifiers:
		names.append(str(_modifier(str(id)).get("name", str(id).capitalize())))
	return "  /  ".join(names)

func _spell_list(spells: Variant) -> String:
	if spells is String:
		return spells.to_upper()
	var names := PackedStringArray()
	for spell in spells:
		var value := str(spell).replace("storm_", "").replace("_", " ")
		names.append(value.to_upper())
	return "  +  ".join(names)

func _best_text(best: Variant) -> String:
	if best is Dictionary:
		if best.is_empty():
			return "Your first record awaits."
		var seconds := float(best.get("elapsed", best.get("time", best.get("best_time", 0))))
		if seconds > 0:
			return "BEST CIRCUIT  " + _format_time(seconds)
		return "PERSONAL BEST  /  %s defeated" % str(best.get("kills", 0))
	if best is float or best is int:
		return "BEST CIRCUIT  " + _format_time(float(best)) if float(best) > 0 else "Your first record awaits."
	return str(best)

func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]

func _stat(parent: Node, title: String, value: String) -> void:
	var box := VBoxContainer.new()
	parent.add_child(box)
	box.add_child(_center_label(title, 13, BRASS))
	var number := _center_label(value, 39, IVORY)
	number.add_theme_font_override("font", _display_font)
	box.add_child(number)

func _center_column(minimum: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_content.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = minimum
	box.add_theme_constant_override("separation", 11)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	return box

func _label(value: String, font_size := 20, color := IVORY, uppercase := false) -> Label:
	var label := Label.new()
	label.text = value.to_upper() if uppercase else value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _center_label(value: String, font_size := 20, color := IVORY) -> Label:
	var label := _label(value, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _eyebrow(value: String) -> Label:
	return _center_label(value, 14, BRASS)

func _heading(value: String, font_size := 48) -> Label:
	var label := _center_label(value, font_size, IVORY)
	label.add_theme_font_override("font", _display_font)
	return label

func _button(value: String, action_name: String, payload: Variant = null, primary := false, font_size := 18) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK if primary else IVORY)
	button.add_theme_color_override("font_hover_color", INK if primary else CYAN)
	button.add_theme_color_override("font_pressed_color", INK if primary else IVORY)
	button.add_theme_color_override("font_focus_color", INK if primary else CYAN)
	button.add_theme_stylebox_override("normal", _style(IVORY if primary else Color(PANEL, 0.75), BRASS if primary else LINE, 1))
	button.add_theme_stylebox_override("hover", _style(CYAN if primary else Color("19333e"), CYAN, 1))
	button.add_theme_stylebox_override("pressed", _style(BRASS if primary else Color("23404a"), IVORY, 1))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, BRASS, 2))
	button.pressed.connect(_emit_action.bind(action_name, payload))
	return button

func _emit_action(name_value: String, payload: Variant) -> void:
	action.emit(name_value, payload)

func _panel(minimum: Vector2, color := PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, LINE, 1))
	return panel

func _padded(parent: Node, horizontal: int, vertical: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	return box

func _bar(color: Color, maximum: float, thickness: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = thickness
	bar.max_value = maximum
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("223440"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 0))
	return bar

func _style(color: Color, border: Color, width := 1, radius := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

func _spacer(parent: Node, height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)

func _place(control: Control, parent: Node, left: float, top: float, right: float, bottom: float, preset := Control.PRESET_TOP_LEFT) -> void:
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(preset)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom
	if control is not BaseButton:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _focus_first_button(node: Node) -> bool:
	for child in node.get_children():
		if child is Button:
			_focus_if_live.call_deferred(weakref(child))
			return true
		if _focus_first_button(child):
			return true
	return false

func _focus_if_live(reference: WeakRef) -> void:
	var control: Control = reference.get_ref()
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and not control.is_queued_for_deletion():
		control.grab_focus()
