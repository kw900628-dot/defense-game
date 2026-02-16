extends Node2D

# 우리가 만든 적과 타워 파일(tscn)을 미리 불러옵니다.
var enemy_scene = preload("res://Enemy.tscn")
var tower_scene = preload("res://tower.tscn")

var spawn_timer = 0.0

# 구역 설정
# 구역 설정
# 구역 설정
const TOWER_ZONE_WIDTH = 80 # 양쪽 타워 구역 너비
const GRID_SIZE = 40 # 격자 크기 (타워/적 크기와 동일)
const SPAWN_ZONE_Y = 100 # 적 생성 구역 아래쪽 경계
var game_over_y = 600 # 게임 오버 라인 (화면 크기에 따라 _ready에서 설정)

var screen_width = 360 # 프로젝트 설정의 뷰포트 너비
var occupied_cells = {} # 타워가 설치된 격자 위치 저장 (키: Vector2i)

# 게임 상태 변수
var lives = 5
var gold = 20
var kills = 0
var round = 1
var round_time = 60.0 # 1분 (60초)
var is_round_in_progress = false # 라운드 진행 중 여부

# 난이도 변수
var spawn_interval = 1.0 # 기본 생성 간격 (1초)
var min_spawn_interval = 0.2 # 최소 생성 간격 (0.2초)

# 타워 관련 변수
var occupied_rows = {}
var selected_tower_type = "towerA" # 기본 선택

# UI 노드 참조
@onready var round_label = %RoundLabel
@onready var time_label = %TimeLabel
@onready var coin_label = %CoinLabel
@onready var kill_label = %KillLabel
@onready var life_label = %LifeLabel

@onready var game_over_control = %GameOverControl
@onready var round_start_control = %RoundStartControl
@onready var round_start_button = $CanvasLayer/RoundStartControl/Button

@onready var shop_container = $CanvasLayer/TowerSelectionControl/ScrollContainer/HBoxContainer

var tower_buttons = {} # 생성된 버튼 참조 저장

func _ready():
	# 0. 월드 환경 설정
	var world_env = WorldEnvironment.new()
	world_env.environment = preload("res://default_env.tres")
	add_child(world_env)

	var viewport_size = get_viewport_rect().size
	screen_width = viewport_size.x
	game_over_y = viewport_size.y - 100

	if not round_start_button.pressed.is_connected(_on_start_round_button_pressed):
		round_start_button.pressed.connect(_on_start_round_button_pressed)
	
	update_ui()
	game_over_control.visible = false
	
	is_round_in_progress = false
	round_start_control.visible = true
	round_start_button.text = "Start Round %d" % round
	
	create_shop_ui() # 상점 버튼 생성

func create_shop_ui():
	# 기존 버튼 삭제 (혹시 있다면)
	for child in shop_container.get_children():
		child.queue_free()
	
	# CSV 순서대로 생성하고 싶지만 Dictionary라 순서 보장 안됨.
	# towerA, towerB 순서대로 키 정렬
	var keys = GameDataManager.tower_data.keys()
	keys.sort()
	
	for type in keys:
		var data = GameDataManager.tower_data[type]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.connect("pressed", Callable(self, "_on_tower_btn_pressed").bind(type))
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.texture = create_gradient_texture(data["color"])
		vbox.add_child(icon)
		
		var label = Label.new()
		# "타워이름 \n가격 C / 데미지 D" 형식 (소수점 제거)
		# 예: 2C / 1D
		var cost_int = int(data["cost"])
		var dmg_int = int(data["damage"])
		label.text = "%s\n%dC / %dD" % [type, cost_int, dmg_int]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		vbox.add_child(label)
		
		shop_container.add_child(btn)
		tower_buttons[type] = btn
		
	update_tower_selection_ui()

func _on_tower_btn_pressed(type):
	print("Selected Tower: ", type)
	selected_tower_type = type
	update_tower_selection_ui()

func update_tower_selection_ui():
	for type in tower_buttons:
		var btn = tower_buttons[type]
		if type == selected_tower_type:
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.5, 0.5, 0.5)

func create_gradient_texture(base_color):
	var c1 = base_color.darkened(0.5)
	var c2 = base_color.lightened(0.2)
	
	var gradient = Gradient.new()
	gradient.set_color(0, c2)
	gradient.set_color(1, c1)
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture

func create_space_background():
	# CanvasLayer를 사용하여 가장 뒤에 렌더링되도록 보장
	var bg_layer = CanvasLayer.new()
	bg_layer.layer = -100 # 가장 뒤 레이어
	add_child(bg_layer)
	
	# 1. 우주 배경 (Deep Blue/Purple Gradient)
	var bg_rect = TextureRect.new()
	bg_rect.name = "SpaceBackground"
	bg_rect.anchors_preset = Control.PRESET_FULL_RECT
	# CanvasLayer 하위이므로 anchors_preset 동작함 (하지만 명시해주는 게 안전)
	bg_rect.size = Vector2(screen_width, 1300)
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.05, 0.05, 0.1)) # 아주 어두운 남색 (위)
	gradient.set_color(1, Color(0.0, 0.0, 0.05)) # 거의 검은색 (아래)
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	bg_rect.texture = texture
	
	bg_layer.add_child(bg_rect)
	
	# 2. 별 효과 (CPUParticles2D)
	var stars = CPUParticles2D.new()
	stars.name = "Stars"
	stars.position = Vector2(screen_width / 2, -50)
	stars.amount = 200
	stars.lifetime = 40.0
	stars.preprocess = 20.0
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	stars.emission_rect_extents = Vector2(screen_width / 2, 0)
	stars.direction = Vector2.DOWN
	stars.spread = 0
	stars.gravity = Vector2(0, 0)
	stars.initial_velocity_min = 30
	stars.initial_velocity_max = 80
	stars.scale_amount_min = 2.0
	stars.scale_amount_max = 5.0
	stars.color = Color(1, 1, 1, 0.8)
	
	bg_layer.add_child(stars)

func _process(delta):
	# 라운드가 진행 중일 때만 로직 실행
	if not is_round_in_progress:
		return

	# 1. 라운드 타이머 업데이트
	round_time -= delta
	if round_time <= 0:
		# 라운드 종료 (일시 정지 및 대기)
		is_round_in_progress = false
		
		# 라운드 종료 시 모든 적 삭제
		get_tree().call_group("enemies", "queue_free")
		
		# 다음 라운드 준비
		round += 1
		round_time = 60.0 # 시간 리셋 (1분)
		
		# 난이도 상승 (간격 감소)
		spawn_interval = max(min_spawn_interval, spawn_interval - 0.1)
		print("Round Up! New Interval: ", spawn_interval)
		
		# UI 업데이트 및 시작 버튼 표시
		update_ui()
		round_start_control.visible = true
		round_start_button.text = "Start Round %d" % round
		return # 프레임 나머지 로직(적 생성 등) 실행 방지
	
	# 타이머 UI 갱신 (초당 한 번씩만 해도 되지만, 부드러움을 위해 매 프레임)
	var minutes = int(round_time) / 60
	var seconds = int(round_time) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]

	# 2. 적 생성 타이머 (게임 오버가 아닐 때만)
	if lives > 0:
		spawn_timer += delta
		if spawn_timer > spawn_interval: # 변수 사용
			spawn_enemy() # 첫 번째 적
			
			# Fever Time: 종료 20초 전이면 적 생성 2배 (한 마리 더 생성)
			if round_time <= 20.0:
				spawn_enemy()
				
			spawn_timer = 0.0 # 타이머 초기화
	
	# 3. 게임 오버 체크 (적 위치 기반)
	for child in get_children():
		if child.is_in_group("enemies"):
			if child.position.y > game_over_y:
				on_enemy_escaped(child)

func _on_start_round_button_pressed():
	print("Start Round Button Pressed!")
	
	# 라운드 데이터 로드
	var key = "round%d" % round
	if GameDataManager.round_data.has(key):
		var data = GameDataManager.round_data[key]
		round_time = float(data.get("duration_seconds", 60))
	else:
		round_time = 60.0 # 기본값
		
	is_round_in_progress = true
	round_start_control.visible = false

# (구UI 핸들러 삭제됨)

func on_enemy_killed(reward_gold):
	kills += 1
	gold += reward_gold
	update_ui()

func on_enemy_escaped(enemy):
	enemy.queue_free() # 적 삭제
	lives -= 1
	if lives < 0:
		lives = 0
		
	update_ui()
	
	if lives <= 0:
		game_over()

func update_ui():
	# 라운드
	round_label.text = "Round: %d" % round
	
	# 코인
	coin_label.text = "Coin: %d" % gold
	
	# 킬
	kill_label.text = "Kills: %d" % kills
	
	# 생명 (하트 개수로 표시)
	var hearts = ""
	for i in range(lives):
		hearts += "❤️"
	life_label.text = hearts

func game_over():
	print("Game Over!")
	life_label.text = "GAME OVER"
	game_over_control.visible = true # 게임오버 화면 표시
	get_tree().paused = true # 게임 일시 정지

func _on_restart_button_pressed():
	get_tree().paused = false # 일시 정지 해제
	get_tree().reload_current_scene() # 씬 재시작

func spawn_enemy():
	# 현재 라운드 정보 가져오기
	var key = "round%d" % round
	var enemies = []
	
	if GameDataManager.round_data.has(key):
		var data = GameDataManager.round_data[key]
		# enemy1 ~ enemy4 확인
		for i in range(1, 5):
			var enemy_key = "enemy%d" % i
			var enemy_type = data.get(enemy_key, "none")
			if enemy_type != "none":
				enemies.append(enemy_type)
	
	if enemies.is_empty():
		enemies = ["level1"] # Fallback
		
	# 적을 복제(Instance)합니다.
	var new_enemy = enemy_scene.instantiate()
	
	# 타입 설정 (랜덤 선택)
	new_enemy.type = enemies.pick_random()
	
	# 중앙 구역(적 구역) 계산
	# 적의 너비가 40픽셀이므로, 반너비인 20픽셀만큼 안쪽으로 들어와야 안전하게 생성됩니다.
	var enemy_half_width = 20.0
	var safe_start = TOWER_ZONE_WIDTH + enemy_half_width
	var safe_end = (screen_width - TOWER_ZONE_WIDTH) - enemy_half_width
	
	# 적의 위치를 랜덤하게 잡습니다 (중앙 구역 내에서)
	var random_x = randf_range(safe_start, safe_end)
	# 생성 위치는 SPAWN_ZONE_Y보다 위쪽이어야 함
	new_enemy.position = Vector2(random_x, -50)
	
	# 게임 화면에 적을 추가합니다.
	add_child(new_enemy)

# 마우스 입력 처리 함수
func _unhandled_input(event):
	# 마우스 왼쪽 버튼을 '눌렀을 때'
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("_unhandled_input detected click at: ", event.position)
		try_place_tower(event.position)

func _draw():
	var viewport_height = get_viewport_rect().size.y
	
	# 0. 배경 색상 채우기 
	# 우주 배경이 보이도록 불투명 사각형 제거하고 반투명으로 변경
	
	# 상단 스폰 구역 (반투명 녹색)
	draw_rect(Rect2(0, 0, screen_width, SPAWN_ZONE_Y), Color(0.0, 1.0, 0.0, 0.1))
	
	# 하단 게임오버 구역 (반투명 빨간색)
	draw_rect(Rect2(0, game_over_y, screen_width, viewport_height - game_over_y), Color(1.0, 0.0, 0.0, 0.1))
	
	# 중앙 적 이동 구역 (투명하게 처리하여 우주 배경 노출)
	# draw_rect(...) 제거
	
	# 0.5. 격자 그리기 (유효한 타워 배치 구역 표시)
	var grid_color = Color(1.0, 1.0, 1.0, 0.15)
	for gy in range(int(viewport_height / GRID_SIZE)):
		var center_y = gy * GRID_SIZE + (GRID_SIZE / 2.0)
		# 유효 범위 체크 (위아래 여유 공간)
		if (center_y - 20) < SPAWN_ZONE_Y: continue
		if (center_y + 20) > game_over_y: continue
		
		# 왼쪽 (2칸 너비)
		for gx in range(int(TOWER_ZONE_WIDTH / GRID_SIZE)):
			draw_rect(Rect2(gx * GRID_SIZE, gy * GRID_SIZE, GRID_SIZE, GRID_SIZE), grid_color, false, 1.0)
			
		# 오른쪽 (2칸 너비)
		var right_start_x = screen_width - TOWER_ZONE_WIDTH
		for gx in range(int(TOWER_ZONE_WIDTH / GRID_SIZE)):
			draw_rect(Rect2(right_start_x + gx * GRID_SIZE, gy * GRID_SIZE, GRID_SIZE, GRID_SIZE), grid_color, false, 1.0)
	
	# 1. 세로 구분선 (타워 구역 vs 적 구역) - 네온 효과 (HDR Color)
	draw_line(Vector2(TOWER_ZONE_WIDTH, 0), Vector2(TOWER_ZONE_WIDTH, viewport_height), Color(2.0, 2.0, 2.0), 3.0)
	draw_line(Vector2(screen_width - TOWER_ZONE_WIDTH, 0), Vector2(screen_width - TOWER_ZONE_WIDTH, viewport_height), Color(2.0, 2.0, 2.0), 3.0)
	
	# 2. 가로 구분선 (스폰 구역, 게임오버 구역) - 네온 효과
	# 상단 스폰 한계선 (형광 녹색)
	draw_line(Vector2(0, SPAWN_ZONE_Y), Vector2(screen_width, SPAWN_ZONE_Y), Color(0.0, 3.0, 0.0), 3.0)
	# 하단 게임오버 선 (형광 빨간색)
	draw_line(Vector2(0, game_over_y), Vector2(screen_width, game_over_y), Color(3.0, 0.0, 0.0), 3.0)

func try_place_tower(mouse_pos): # 2. 그리드 점유 확인 (기존 로직 + 1행 1타워 제한)
	var grid_x = int(mouse_pos.x / GRID_SIZE)
	var grid_y = int(mouse_pos.y / GRID_SIZE)
	var grid_pos = Vector2i(grid_x, grid_y)
	
	print("Attempting to place tower at grid: ", grid_pos)
	
	var data = GameDataManager.tower_data[selected_tower_type]
	var cost = data["cost"]
	var size = data["size"]
	
	# 1행 1타워 제한 로직은 유효 구역 체크 후 하단에서 수행합니다.
	pass
			
	# 기존 점유 로직 (타워 크기 고려)
	# can_build_at 함수는 현재 정의되어 있지 않으므로, 이 부분은 주석 처리하거나
	# can_build_at 함수를 추가해야 합니다.
	# if not can_build_at(grid_x, grid_y, size):
	# 	print("Invalid Build Position (Occupied)")
	# 	return
		
	if gold < cost:
		print("코인이 부족합니다!")
		return
		
	# 배치 위치 및 점유 계산
	# size.x가 80이면 2칸 차지 (현재 칸 + 오른쪽 칸)
	# 이 경우 중심좌표를 오른쪽으로 20만큼 이동시켜야 두 칸에 딱 맞음
	var is_large = size.x > 40
	var cells_needed = 1
	if is_large: cells_needed = 2
	
	var center_x = grid_x * GRID_SIZE + (GRID_SIZE / 2.0)
	var center_y = grid_y * GRID_SIZE + (GRID_SIZE / 2.0)
	
	if is_large:
		center_x += 20 # 2칸의 중앙으로 이동
		
	var target_pos = Vector2(center_x, center_y)
	
	# 구역(Side) 및 유효성 체크
	# 왼쪽 구역: 0 ~ TOWER_ZONE_WIDTH
	# 오른쪽 구역: screen_width - TOWER_ZONE_WIDTH ~ screen_width
	
	var side = ""
	
	# 점유하려는 모든 칸이 유효 영역 내에 있어야 함
	# 간단히: target_pos 기준 반경으로 체크
	var half_w = size.x / 2.0
	var half_h = size.y / 2.0
	
	if (target_pos.x + half_w) <= TOWER_ZONE_WIDTH:
		side = "left"
	elif (target_pos.x - half_w) >= (screen_width - TOWER_ZONE_WIDTH):
		side = "right"
	else:
		return # 유효 구역 아님
		
	# 상하 제한
	if (target_pos.y - half_h) < SPAWN_ZONE_Y or (target_pos.y + half_h) > game_over_y:
		return

	# 점유 체크 (1행 1타워 제한 - Side별 분리)
	# side "left"이면 왼쪽 구역 전체(0, 1열) 확인
	# side "right"이면 오른쪽 구역 전체(start_col ~ end_col) 확인
	
	if occupied_rows.has(grid_y):
		var check_start_col = 0
		var check_end_col = 1
		
		if side == "right":
			check_start_col = int((screen_width - TOWER_ZONE_WIDTH) / GRID_SIZE)
			check_end_col = check_start_col + 1
			
		for existing_x in occupied_rows[grid_y]:
			if existing_x >= check_start_col and existing_x <= check_end_col:
				print("이미 해당 구역(%s)의 행에 타워가 있습니다." % side)
				return

	if not occupied_rows.has(grid_y):
		occupied_rows[grid_y] = [] # 좌표 리스트로 관리하거나 Set 사용
	
	# 타워가 차지하는 x 인덱스들
	var occupy_indices = []
	for i in range(cells_needed):
		occupy_indices.append(grid_x + i)
		
	# 이미 점유된 위치인지 확인 (세포 단위 - 중복 방지용)
	for idx in occupy_indices:
		if idx in occupied_rows[grid_y]:
			print("이미 타워가 있습니다 (겹침).")
			return
			
	# 배치 수행
	place_tower(target_pos, selected_tower_type)
	gold -= cost
	
	# 점유 표시
	for idx in occupy_indices:
		if not idx in occupied_rows[grid_y]: # 중복 방지
			occupied_rows[grid_y].append(idx)
		
	update_ui()


func place_tower(pos, type):
	var new_tower = tower_scene.instantiate()
	new_tower.position = pos
	new_tower.setup_tower(type) # setup 호출
	add_child(new_tower)

func sell_tower(tower):
	var data = GameDataManager.tower_data[tower.type]
	var size = data["size"]
	var cost = data["cost"]
	
	# 점유 해제
	# 타워 중심 좌표 역산
	# Large(80)인 경우 center_x가 grid_x * 40 + 40 위치임.
	# grid_x = floor((pos.x - 20) / 40) ?
	# 또는 그냥 pos.x 기준으로 범위 내의 그리드 삭제?
	
	var grid_y = floor(tower.position.y / GRID_SIZE)
	
	# 차지하고 있는 x범위
	var start_x = tower.position.x - (size.x / 2.0)
	var end_x = tower.position.x + (size.x / 2.0)
	
	# 포함되는 그리드 인덱스 찾기
	# 그리드 i의 범위: i*40 ~ (i+1)*40
	# 교차하는지 확인
	
	if occupied_rows.has(grid_y):
		var to_remove = []
		for x_idx in occupied_rows[grid_y]:
			var cell_center = x_idx * GRID_SIZE + 20
			if cell_center > start_x and cell_center < end_x:
				to_remove.append(x_idx)
		
		for x in to_remove:
			occupied_rows[grid_y].erase(x)
			
	gold += cost # 100% 환불
	tower.queue_free()
	update_ui()
