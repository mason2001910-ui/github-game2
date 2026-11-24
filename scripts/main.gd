extends Node3D

const ACCENT := Color("#f2c778")
const MINT := Color("#89e4cf")
const TEXT := Color("#fff5e4")
const MUTED := Color("#b5bfd1")
const PANEL := Color(0.045, 0.07, 0.13, 0.94)
const UI_FONT: Font = preload("res://assets/fonts/NotoSansTC-VF.ttf")

var stage_names := ["預算發球", "投資輪轉"]
var stage_scores: Array[int] = [0, 0]
var current_stage := 0
var serve_count := 0
var team_coins := 100
var saved_coins := 0
var finance_progress := 0
var budget_answered := false
var diversified := false
var investment_delta := 0
var current_state := "intro"
var meter_clock := 0.0
var meter_value := 0.0
var last_serve_points := 0
var last_serve_title := ""
var feedback_title := ""
var feedback_body := ""
var feedback_next := ""

var ball: MeshInstance3D
var meter: ProgressBar
var meter_caption: Label
var header_score: Label
var header_coins: Label
var panel_content: VBoxContainer
var main_panel: PanelContainer


func _ready() -> void:
	_build_world()
	_build_interface()
	get_viewport().size_changed.connect(_layout_interface)
	_render_state()


func _process(delta: float) -> void:
	meter_clock += delta * 1.65
	meter_value = 0.5 + 0.5 * sin(meter_clock)
	if is_instance_valid(meter) and current_state == "rally":
		meter.value = meter_value * 100.0
		if is_instance_valid(meter_caption):
			meter_caption.text = "扣球節奏　%02d%%" % int(meter_value * 100.0)
	if is_instance_valid(ball):
		ball.rotate_x(delta * 0.7)
		ball.rotate_z(delta * 0.42)


func _build_world() -> void:
	var arena_scene: PackedScene = load("res://assets/dreamcourt.glb")
	if arena_scene:
		var arena := arena_scene.instantiate()
		arena.name = "BlenderDreamCourt"
		add_child(arena)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#101a2c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9bb4ca")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	world.environment = environment
	add_child(world)

	var key := DirectionalLight3D.new()
	key.name = "Moonlight"
	key.rotation_degrees = Vector3(-38.0, -28.0, -16.0)
	key.light_color = Color("#d8d5ff")
	key.light_energy = 0.72
	key.shadow_enabled = true
	add_child(key)

	var court_fill := OmniLight3D.new()
	court_fill.position = Vector3(-4.0, 8.0, -2.0)
	court_fill.light_color = Color("#f8c776")
	court_fill.light_energy = 3.8
	court_fill.omni_range = 22.0
	add_child(court_fill)

	var rim := OmniLight3D.new()
	rim.position = Vector3(6.0, 6.0, 3.0)
	rim.light_color = Color("#79decf")
	rim.light_energy = 2.2
	rim.omni_range = 18.0
	add_child(rim)

	var camera := Camera3D.new()
	camera.name = "CourtCamera"
	camera.position = Vector3(12.0, 13.2, 18.4)
	camera.fov = 44.0
	camera.current = true
	camera.look_at(Vector3(0.0, 3.5, 0.35), Vector3.UP)
	add_child(camera)

	ball = MeshInstance3D.new()
	ball.name = "LiveVolleyball"
	var sphere := SphereMesh.new()
	sphere.radius = 0.48
	sphere.height = 0.96
	sphere.radial_segments = 32
	sphere.rings = 20
	ball.mesh = sphere
	var ball_material := StandardMaterial3D.new()
	ball_material.albedo_color = Color("#fff1d7")
	ball_material.roughness = 0.29
	ball_material.metallic = 0.08
	ball_material.emission_enabled = true
	ball_material.emission = Color("#e9c278")
	ball_material.emission_energy_multiplier = 0.22
	sphere.material = ball_material
	ball.position = Vector3(2.1, 1.35, 3.5)
	add_child(ball)

	var ball_light := OmniLight3D.new()
	ball_light.position = Vector3(2.1, 1.7, 3.5)
	ball_light.light_color = Color("#ffda91")
	ball_light.light_energy = 0.55
	ball_light.omni_range = 4.2
	add_child(ball_light)


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 2
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var ui_theme := Theme.new()
	ui_theme.default_font = UI_FONT
	root.theme = ui_theme
	canvas.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.035, 0.075, 0.30)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var header := HBoxContainer.new()
	header.anchor_left = 0.04
	header.anchor_top = 0.035
	header.anchor_right = 0.96
	header.anchor_bottom = 0.13
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var brand := PanelContainer.new()
	brand.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.105, 0.90), Color(1, 1, 1, 0.12), 18))
	var brand_pad := MarginContainer.new()
	brand_pad.add_theme_constant_override("margin_left", 18)
	brand_pad.add_theme_constant_override("margin_right", 18)
	brand_pad.add_theme_constant_override("margin_top", 9)
	brand_pad.add_theme_constant_override("margin_bottom", 9)
	var brand_stack := VBoxContainer.new()
	brand_stack.add_theme_constant_override("separation", 0)
	brand_stack.add_child(_label("DREAMCOURT", 16, ACCENT, false))
	brand_stack.add_child(_label("月光球場　·　排球 × 理財", 12, MUTED, false))
	brand_pad.add_child(brand_stack)
	brand.add_child(brand_pad)
	header.add_child(brand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var score_box := PanelContainer.new()
	score_box.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.105, 0.90), Color(1, 1, 1, 0.12), 18))
	var score_pad := MarginContainer.new()
	score_pad.add_theme_constant_override("margin_left", 18)
	score_pad.add_theme_constant_override("margin_right", 18)
	score_pad.add_theme_constant_override("margin_top", 13)
	score_pad.add_theme_constant_override("margin_bottom", 13)
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 22)
	header_score = _label("得分　000", 15, TEXT, false)
	header_coins = _label("球幣　100", 15, ACCENT, false)
	score_row.add_child(header_score)
	score_row.add_child(_label("✦", 15, Color("#8291a8"), false))
	score_row.add_child(header_coins)
	score_pad.add_child(score_row)
	score_box.add_child(score_pad)
	header.add_child(score_box)

	main_panel = PanelContainer.new()
	main_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.67, 0.79, 1.0, 0.16), 24))
	main_panel.anchor_left = 0.045
	main_panel.anchor_top = 0.17
	main_panel.anchor_right = 0.55
	main_panel.anchor_bottom = 0.92
	root.add_child(main_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.add_child(scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 30)
	pad.add_theme_constant_override("margin_right", 30)
	pad.add_theme_constant_override("margin_top", 26)
	pad.add_theme_constant_override("margin_bottom", 26)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	panel_content = VBoxContainer.new()
	panel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_content.add_theme_constant_override("separation", 14)
	pad.add_child(panel_content)

	var footer := Label.new()
	footer.text = "虛構球幣　·　遊戲中的投資練習不代表真實報酬"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.91, 0.91, 0.95, 0.82))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.anchor_left = 0.46
	footer.anchor_top = 0.955
	footer.anchor_right = 0.965
	footer.anchor_bottom = 0.99
	root.add_child(footer)

	_layout_interface()


func _layout_interface() -> void:
	if not is_instance_valid(main_panel):
		return
	var size := get_viewport().get_visible_rect().size
	if size.x < 850.0:
		main_panel.anchor_left = 0.035
		main_panel.anchor_top = 0.155
		main_panel.anchor_right = 0.965
		main_panel.anchor_bottom = 0.945
	else:
		main_panel.anchor_left = 0.045
		main_panel.anchor_top = 0.17
		main_panel.anchor_right = 0.55
		main_panel.anchor_bottom = 0.92


func _render_state() -> void:
	_clear_panel()
	_update_header()
	meter = null
	meter_caption = null
	match current_state:
		"intro":
			_render_intro()
		"rally":
			_render_rally()
		"serve_feedback":
			_render_serve_feedback()
		"budget_question":
			_render_budget_question()
		"investment_choice":
			_render_investment_choice()
		"investment_result":
			_render_investment_result()
		"complete":
			_render_complete()


func _render_intro() -> void:
	panel_content.add_child(_label("A NIGHT GAME FOR BRIGHT IDEAS", 12, MINT, false))
	panel_content.add_child(_label("月光球場", 48, TEXT, false))
	panel_content.add_child(_label("一記好球，開啟好習慣。", 23, ACCENT, false))
	panel_content.add_child(_label("踏進夢境體育館，和小小球隊一起打兩局。練習掌握發球節奏，也學會先規劃、再思考投資風險。", 16, MUTED, true))
	panel_content.add_child(_spacer(10))
	panel_content.add_child(_info_card("今晚的練習", "第一局　預算發球　·　把近期需要先留下\n第二局　投資輪轉　·　比較分散與集中風險", MINT))
	panel_content.add_child(_info_card("怎麼玩", "等節奏計量條靠近金色區域時按下扣球。每局三次出手，得分和球幣會記錄在球場計分板。", ACCENT))
	panel_content.add_child(_spacer(4))
	panel_content.add_child(_button("走進球場　　開始挑戰　→", true, _start_game))
	panel_content.add_child(_label("適合小學生　·　單人遊玩　·　約 3 分鐘", 12, MUTED, false))


func _start_game() -> void:
	current_stage = 0
	serve_count = 0
	stage_scores = [0, 0]
	team_coins = 100
	saved_coins = 0
	finance_progress = 0
	budget_answered = false
	diversified = false
	investment_delta = 0
	current_state = "rally"
	_render_state()


func _render_rally() -> void:
	var name := "先規劃隊費，再漂亮開球" if current_stage == 0 else "球隊輪轉，風險也要輪轉"
	var intent := "看準時機打出好球，替球隊累積預算。" if current_stage == 0 else "第二局加快節奏；留意每次出手和隊伍得分。"
	panel_content.add_child(_label("ROUND 0%d　/　02　　·　　%s" % [current_stage + 1, stage_names[current_stage].to_upper()], 12, MINT, false))
	panel_content.add_child(_label(name, 28, TEXT, true))
	panel_content.add_child(_label(intent, 15, MUTED, true))
	panel_content.add_child(_score_strip())
	panel_content.add_child(_spacer(2))
	panel_content.add_child(_label("扣球節奏", 14, ACCENT, false))
	meter_caption = _label("扣球節奏　—", 12, MUTED, false)
	panel_content.add_child(meter_caption)
	meter = ProgressBar.new()
	meter.min_value = 0
	meter.max_value = 100
	meter.value = 0
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(0, 20)
	meter.add_theme_stylebox_override("background", _panel_style(Color(0.08, 0.12, 0.19, 1), Color(1, 1, 1, 0.08), 10))
	meter.add_theme_stylebox_override("fill", _panel_style(Color("#88e4cf"), Color(0, 0, 0, 0), 10))
	panel_content.add_child(meter)
	panel_content.add_child(_label("光標越接近金色拍點，扣球分數越高。", 13, MUTED, true))
	panel_content.add_child(_button("扣　球！", true, _take_serve))
	panel_content.add_child(_serve_progress())
	panel_content.add_child(_info_card("球場提示", "每一局三次出手。先用眼睛抓節奏，再按下扣球；準備好了就試試看。", Color("#a7b8ff")))


func _take_serve() -> void:
	if current_state != "rally":
		return
	var distance: float = absf(meter_value - 0.78)
	if distance < 0.13:
		last_serve_points = 2
		last_serve_title = "完美扣球！"
	elif distance < 0.31:
		last_serve_points = 1
		last_serve_title = "漂亮回球！"
	else:
		last_serve_points = 0
		last_serve_title = "再試一次節奏"
	stage_scores[current_stage] += last_serve_points
	team_coins += 4 + last_serve_points * 2
	serve_count += 1
	_animate_ball()
	current_state = "serve_feedback"
	_render_state()


func _animate_ball() -> void:
	if not is_instance_valid(ball):
		return
	var home := Vector3(2.1, 1.35, 3.5)
	var target := Vector3(-1.7 if serve_count % 2 == 0 else 1.8, 3.2 + meter_value * 1.1, -1.2 if current_stage == 0 else 0.4)
	ball.position = home
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "position", Vector3(0.1, 4.6, 1.1), 0.24)
	tween.tween_property(ball, "position", target, 0.44)
	tween.tween_property(ball, "position", home, 0.28).set_delay(0.38)


func _render_serve_feedback() -> void:
	panel_content.add_child(_label("ROUND 0%d　/　02　　·　　%s" % [current_stage + 1, stage_names[current_stage].to_upper()], 12, MINT, false))
	panel_content.add_child(_label(last_serve_title, 32, ACCENT if last_serve_points > 0 else TEXT, false))
	var result_text := "+%d 分　·　+%d 枚球幣" % [last_serve_points, 4 + last_serve_points * 2]
	if last_serve_points == 0:
		result_text = "這球沒有得分，但球幣仍留在隊伍預算裡。"
	panel_content.add_child(_label(result_text, 18, TEXT, true))
	panel_content.add_child(_score_strip())
	panel_content.add_child(_spacer(8))
	panel_content.add_child(_info_card("節奏回饋", "" if last_serve_points == 2 else "計量條每次移動都一樣快。試著等光標靠近金色拍點，再扣球。", MINT))
	var next_label := "再打一球　→" if serve_count < 3 else ("進入預算挑戰　→" if current_stage == 0 else "進入投資挑戰　→")
	panel_content.add_child(_button(next_label, true, _next_after_serve))


func _next_after_serve() -> void:
	if serve_count < 3:
		current_state = "rally"
	else:
		current_state = "budget_question" if current_stage == 0 else "investment_choice"
	_render_state()


func _render_budget_question() -> void:
	panel_content.add_child(_label("HALF-TIME　·　MONEY MOVE 01", 12, MINT, false))
	panel_content.add_child(_label("先把隊費留起來", 30, TEXT, false))
	panel_content.add_child(_label("球隊原本有 100 枚球幣，下週一定要付 30 枚場地費。你會先怎麼做？", 17, MUTED, true))
	panel_content.add_child(_score_strip())
	panel_content.add_child(_spacer(4))
	var answers := [
		"先留下 30 枚，再規劃剩下的球幣",
		"先把球幣花完，下週再想辦法",
		"把 100 枚全部拿去買可能變貴的球鞋"
	]
	for i in range(answers.size()):
		panel_content.add_child(_button(answers[i], i == 0, _answer_budget.bind(i)))
	panel_content.add_child(_info_card("理財小筆記", "把必要支出和想要的東西分開，能讓短期目標更安心。", ACCENT))


func _answer_budget(choice: int) -> void:
	budget_answered = choice == 0
	if budget_answered:
		saved_coins = 30
		finance_progress = 50
		feedback_title = "好球！先留好近期需要。"
		feedback_body = "場地費 30 枚先留在安全的球隊帳本；剩下的球幣才是可以討論怎麼使用的部分。"
	else:
		saved_coins = 0
		feedback_title = "差一點！先看日期和預算。"
		feedback_body = "下週一定要用的場地費，最好先保留。計畫好近期需要，再考慮其他選擇。"
	feedback_next = "next_stage"
	current_state = "investment_result"
	_render_state()


func _render_investment_choice() -> void:
	panel_content.add_child(_label("FINAL SET　·　MONEY MOVE 02", 12, MINT, false))
	panel_content.add_child(_label("投資輪轉", 32, TEXT, false))
	panel_content.add_child(_label("已預留 %d 枚下週隊費。把剩下的夢球幣當作半年後才用的練習資金；你會怎麼安排？" % saved_coins, 16, MUTED, true))
	panel_content.add_child(_score_strip())
	panel_content.add_child(_spacer(4))
	panel_content.add_child(_button("分成三份，支持三支夢想球隊", true, _choose_investment.bind("diversified")))
	panel_content.add_child(_button("全部押在同一支明星球隊", false, _choose_investment.bind("single")))
	panel_content.add_child(_button("先放回存錢箱，保持穩定", false, _choose_investment.bind("save")))
	panel_content.add_child(_info_card("沒有保證報酬", "分散可以降低單一隊伍失利的影響；投資仍會波動，結果可能增加或減少。", ACCENT))


func _choose_investment(choice: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	diversified = choice == "diversified"
	if choice == "diversified":
		investment_delta = rng.randi_range(-8, 9)
		finance_progress = 100 if budget_answered else 50
		feedback_title = "輪轉得分！你把風險分散了。"
		feedback_body = "三支隊伍的模擬結果合計 %s%d 枚球幣。分散能減少單一隊伍的影響，但市場仍會波動，這次結果不代表未來。" % ["+" if investment_delta >= 0 else "", investment_delta]
	elif choice == "single":
		investment_delta = rng.randi_range(-18, 20)
		finance_progress = 65 if budget_answered else 15
		feedback_title = "集中一隊，變化也更集中。"
		feedback_body = "單一隊伍的模擬結果 %s%d 枚球幣。表現好時可能增加，失利時也可能減少；借錢加碼還會讓損失更難承受。" % ["+" if investment_delta >= 0 else "", investment_delta]
	else:
		investment_delta = 0
		finance_progress = 75 if budget_answered else 25
		feedback_title = "存錢箱守住了這筆球幣。"
		feedback_body = "近期就要使用的錢，留在較穩定的地方可能比較合適；長期目標才有時間思考波動與分散。"
	team_coins = maxi(0, team_coins + investment_delta)
	feedback_next = "complete"
	current_state = "investment_result"
	_render_state()


func _render_investment_result() -> void:
	var is_budget_feedback := feedback_next == "next_stage"
	panel_content.add_child(_label("COACH'S NOTE　·　理財回顧" if not is_budget_feedback else "COACH'S NOTE　·　預算回顧", 12, MINT, false))
	panel_content.add_child(_label(feedback_title, 27, ACCENT, true))
	panel_content.add_child(_label(feedback_body, 16, TEXT, true))
	panel_content.add_child(_score_strip())
	panel_content.add_child(_spacer(8))
	if not is_budget_feedback:
		panel_content.add_child(_progress_card())
		panel_content.add_child(_info_card("球隊帳本", "預留隊費：%d　·　目前球幣：%d" % [saved_coins, team_coins], MINT))
	var button_text := "走向第二局　→" if is_budget_feedback else "查看這場練習的進步　→"
	panel_content.add_child(_button(button_text, true, _continue_after_feedback))


func _continue_after_feedback() -> void:
	if feedback_next == "next_stage":
		current_stage = 1
		serve_count = 0
		current_state = "rally"
	else:
		current_state = "complete"
	_render_state()


func _render_complete() -> void:
	var total: int = stage_scores[0] + stage_scores[1]
	panel_content.add_child(_label("NIGHT MATCH　·　TRAINING COMPLETE", 12, MINT, false))
	panel_content.add_child(_label("今晚打得真好。", 34, TEXT, false))
	panel_content.add_child(_label("比分會結束，學到的方法可以帶回生活。", 16, MUTED, true))
	panel_content.add_child(_spacer(4))
	panel_content.add_child(_summary_card("排球得分", "%d" % total, "第一局 %d　·　第二局 %d" % [stage_scores[0], stage_scores[1]], ACCENT))
	panel_content.add_child(_summary_card("理財進步", "%d%%" % finance_progress, "從 0%% 練習到 %d%%　·　預留 %d 枚隊費" % [finance_progress, saved_coins], MINT))
	panel_content.add_child(_info_card("帶走兩個觀念", "先安排近期需要；規劃長期目標時，理解分散與風險，並記得投資不保證獲利。", Color("#a7b8ff")))
	panel_content.add_child(_label("遊戲球幣沒有真實價值，也不構成投資建議。", 12, MUTED, true))
	panel_content.add_child(_button("再打一場　↺", true, _render_restart))


func _render_restart() -> void:
	current_state = "intro"
	_render_state()


func _score_strip() -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	strip.add_child(_stat_card("本局比分", "%d" % stage_scores[current_stage], ACCENT))
	strip.add_child(_stat_card("出手次數", "%d / 3" % serve_count, MINT))
	strip.add_child(_stat_card("球隊球幣", "%d" % team_coins, Color("#f6dba7")))
	return strip


func _stat_card(title: String, value: String, tint: Color) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.12, 0.19, 0.96), Color(1, 1, 1, 0.07), 14))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	var column := VBoxContainer.new()
	column.add_child(_label(title, 11, MUTED, false))
	column.add_child(_label(value, 18, tint, false))
	pad.add_child(column)
	card.add_child(pad)
	return card


func _serve_progress() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label("本局節奏", 12, MUTED, false))
	for i in range(3):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(24, 5)
		dot.color = MINT if i < serve_count else Color(0.47, 0.54, 0.68, 0.45)
		row.add_child(dot)
	return row


func _progress_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.12, 0.19, 0.96), Color(0.55, 0.9, 0.82, 0.24), 16))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 15 if side == "left" or side == "right" else 12)
	var col := VBoxContainer.new()
	col.add_child(_label("理財練習進度", 12, MUTED, false))
	col.add_child(_label("%d%%" % finance_progress, 25, MINT, false))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = finance_progress
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.04, 0.07, 0.12, 1), Color(1, 1, 1, 0.08), 8))
	bar.add_theme_stylebox_override("fill", _panel_style(MINT, Color(0, 0, 0, 0), 8))
	col.add_child(bar)
	pad.add_child(col)
	card.add_child(pad)
	return card


func _summary_card(title: String, value: String, detail: String, tint: Color) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.12, 0.19, 0.96), Color(1, 1, 1, 0.08), 16))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16 if side == "left" or side == "right" else 13)
	var row := HBoxContainer.new()
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_label(title, 13, MUTED, false))
	col.add_child(_label(detail, 12, MUTED, true))
	row.add_child(col)
	row.add_child(_label(value, 30, tint, false))
	pad.add_child(row)
	card.add_child(pad)
	return card


func _info_card(title: String, body: String, tint: Color) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.105, 0.17, 0.92), Color(tint.r, tint.g, tint.b, 0.2), 16))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.add_child(_label(title, 12, tint, false))
	col.add_child(_label(body, 14, TEXT, true))
	pad.add_child(col)
	card.add_child(pad)
	return card


func _button(text: String, primary: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", UI_FONT)
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#142134") if primary else TEXT)
	button.add_theme_color_override("font_hover_color", Color("#142134") if primary else TEXT)
	button.add_theme_color_override("font_pressed_color", Color("#142134"))
	button.add_theme_color_override("font_focus_color", TEXT)
	var base := Color("#e9c278") if primary else Color(0.11, 0.16, 0.24, 0.98)
	var border := Color("#ffe1a4") if primary else Color(1, 1, 1, 0.13)
	button.add_theme_stylebox_override("normal", _panel_style(base, border, 15, 17, 13))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#f4d99a") if primary else Color(0.17, 0.23, 0.33, 0.99), border, 15, 17, 13))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#d9aa5d") if primary else Color(0.14, 0.2, 0.3, 0.99), border, 15, 17, 13))
	button.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color("#89e4cf"), 15, 17, 13))
	button.pressed.connect(action)
	return button


func _label(text: String, size: int, color: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _panel_style(bg: Color, border: Color, radius: int, left: int = 16, vertical: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = left
	style.content_margin_right = left
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _clear_panel() -> void:
	if not is_instance_valid(panel_content):
		return
	for child in panel_content.get_children():
		panel_content.remove_child(child)
		child.queue_free()


func _update_header() -> void:
	if is_instance_valid(header_score):
		header_score.text = "得分　%03d" % (stage_scores[0] + stage_scores[1])
	if is_instance_valid(header_coins):
		header_coins.text = "球幣　%d" % team_coins
