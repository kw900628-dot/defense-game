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

# 타워 관련 상수 및 변수
enum TowerType {BLUE, YELLOW, ORANGE}
const TOWER_COSTS = {
	TowerType.BLUE: 2,
	TowerType.YELLOW: 4,
	TowerType.ORANGE: 6
}
var occupied_rows = {} # 행별 타워 설치 여부 (키: grid_y, 값: {"left": bool, "right": bool})
var selected_tower_type = TowerType.BLUE # 기본 선택 타워

# UI 노드 참조
@onready var round_label = %RoundLabel
@onready var time_label = %TimeLabel
@onready var coin_label = %CoinLabel
@onready var kill_label = %KillLabel
@onready var life_label = %LifeLabel

@onready var game_over_control = %GameOverControl
@onready var round_start_control = %RoundStartControl
@onready var round_start_button = $CanvasLayer/RoundStartControl/Button

@onready var blue_btn = %BlueTowerBtn
@onready var yellow_btn = %YellowTowerBtn
@onready var orange_btn = %OrangeTowerBtn

func _ready():
	# 0. 월드 환경 설정 (기본 디자인 업그레이드 - Glow/Adjustment)
	var world_env = WorldEnvironment.new()
	world_env.environment = load("res://default_env.tres")
	add_child(world_env)

	# 게임 시작 시 화면 크기를 가져와서 설정합니다.
	var viewport_size = get_viewport_rect().size
	screen_width = viewport_size.x
	game_over_y = viewport_size.y - 100 # 바닥에서 100픽셀 위

	# 시그널 강제 연결 (에디터 연결 문제 방지)
	if not round_start_button.pressed.is_connected(_on_start_round_button_pressed):
		round_start_button.pressed.connect(_on_start_round_button_pressed)
	
	update_ui() # 초기 UI 갱신
	game_over_control.visible = false # 게임오버 화면 숨김
	
	# 라운드 시작 대기 상태로 시작
	is_round_in_progress = false
	round_start_control.visible = true
	round_start_button.text = "Start Round %d" % round

func _process(delta):
	# 라운드가 진행 중일 때만 로직 실행
	if not is_round_in_progress:
		return

	# 1. 라운드 타이머 업데이트
	round_time -= delta
	if round_time <= 0:
		# 라운드 종료 (일시 정지 및 대기)
		is_round_in_progress = false
		
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
	
	# 타이머 UI 갱신 (초당 한 번씩만 해도 되지만, 부드러움을 위해 매 프레임)
	var minutes = int(round_time) / 60
	var seconds = int(round_time) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]

	# 2. 적 생성 타이머 (게임 오버가 아닐 때만)
	if lives > 0:
		spawn_timer += delta
		if spawn_timer > spawn_interval: # 변수 사용
			spawn_enemy() # 첫 번째 적
			
			# 러시 아워: 종료 10초 전이면 한 마리 더!
			if round_time <= 10.0:
				spawn_enemy()
				
			spawn_timer = 0.0 # 타이머 초기화
	
	# 3. 게임 오버 체크 (적 위치 기반)
	for child in get_children():
		if child.is_in_group("enemies"):
			if child.position.y > game_over_y:
				on_enemy_escaped(child)

func _on_start_round_button_pressed():
	print("Start Round Button Pressed!")
	is_round_in_progress = true
	round_start_control.visible = false

# 타워 선택 버튼 핸들러
func _on_blue_tower_btn_pressed():
	print("Blue Tower Selected")
	selected_tower_type = TowerType.BLUE
	update_tower_selection_ui()

func _on_yellow_tower_btn_pressed():
	print("Yellow Tower Selected")
	selected_tower_type = TowerType.YELLOW
	update_tower_selection_ui()

func _on_orange_tower_btn_pressed():
	print("Orange Tower Selected")
	selected_tower_type = TowerType.ORANGE
	update_tower_selection_ui()

func update_tower_selection_ui():
	# 선택된 버튼 강조 (색상 변경 등)
	blue_btn.modulate = Color.WHITE if selected_tower_type == TowerType.BLUE else Color(0.5, 0.5, 0.5)
	yellow_btn.modulate = Color.WHITE if selected_tower_type == TowerType.YELLOW else Color(0.5, 0.5, 0.5)
	orange_btn.modulate = Color.WHITE if selected_tower_type == TowerType.ORANGE else Color(0.5, 0.5, 0.5)

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
	# 적을 복제(Instance)합니다.
	var new_enemy = enemy_scene.instantiate()
	
	# 적 스크립트의 Enum 값에 접근하기 위해 스크립트 로드 (또는 하드코딩)
	# 여기서는 간단하게 정수값 사용 (TRIANGLE=0, CIRCLE=1, STAR=2)
	# enemy.gd의 순서: TRIANGLE, CIRCLE, STAR
	
	var elapsed_time = 60.0 - round_time # 경과 시간 (0 ~ 60)
	var allowed_types = []
	
	if elapsed_time <= 10.0:
		allowed_types = [0] # TRIANGLE
	elif elapsed_time <= 30.0:
		allowed_types = [0, 1] # TRIANGLE, CIRCLE
	else:
		allowed_types = [0, 1, 2] # TRIANGLE, CIRCLE, STAR
		
	# 타입 설정
	new_enemy.type = allowed_types.pick_random()
	
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
	# 상단 스폰 구역 (어두운 녹색 배경)
	draw_rect(Rect2(0, 0, screen_width, SPAWN_ZONE_Y), Color(0.1, 0.3, 0.1))
	
	# 하단 게임오버 구역 (어두운 빨간색 배경)
	draw_rect(Rect2(0, game_over_y, screen_width, viewport_height - game_over_y), Color(0.3, 0.1, 0.1))
	
	# 중앙 적 이동 구역 (약간 더 밝은 회색 배경)
	var enemy_zone_width = screen_width - (TOWER_ZONE_WIDTH * 2)
	var enemy_zone_height = game_over_y - SPAWN_ZONE_Y
	draw_rect(Rect2(TOWER_ZONE_WIDTH, SPAWN_ZONE_Y, enemy_zone_width, enemy_zone_height), Color(0.2, 0.2, 0.2))
	
	# 1. 세로 구분선 (타워 구역 vs 적 구역)
	draw_line(Vector2(TOWER_ZONE_WIDTH, 0), Vector2(TOWER_ZONE_WIDTH, viewport_height), Color.WHITE, 2.0)
	draw_line(Vector2(screen_width - TOWER_ZONE_WIDTH, 0), Vector2(screen_width - TOWER_ZONE_WIDTH, viewport_height), Color.WHITE, 2.0)
	
	# 2. 가로 구분선 (스폰 구역, 게임오버 구역)
	# 상단 스폰 한계선 (녹색)
	draw_line(Vector2(0, SPAWN_ZONE_Y), Vector2(screen_width, SPAWN_ZONE_Y), Color.GREEN, 2.0)
	# 하단 게임오버 선 (빨간색)
	draw_line(Vector2(0, game_over_y), Vector2(screen_width, game_over_y), Color.RED, 2.0)

func try_place_tower(mouse_pos):
	# 1. 격자 좌표 계산 (마우스 위치를 GRID_SIZE로 나눈 몫)
	var grid_x = floor(mouse_pos.x / GRID_SIZE)
	var grid_y = floor(mouse_pos.y / GRID_SIZE)
	var grid_pos = Vector2i(grid_x, grid_y)
	
	print("Attempting to place tower at grid: ", grid_pos)
	
	# 2. 실제 배치될 중심 좌표 계산
	var center_x = grid_x * GRID_SIZE + (GRID_SIZE / 2.0)
	var center_y = grid_y * GRID_SIZE + (GRID_SIZE / 2.0)
	var target_pos = Vector2(center_x, center_y)
	
	# 3. 타워 구역 내인지 확인 및 좌우 판단
	var side = ""
	var tower_half_width = 20.0
	
	if (target_pos.x + tower_half_width) <= TOWER_ZONE_WIDTH:
		side = "left"
	elif (target_pos.x - tower_half_width) >= (screen_width - TOWER_ZONE_WIDTH):
		side = "right"
	else:
		print("타워 구역이 아닙니다.")
		# 타워 선택 버튼 클릭과 겹치지 않게 하기 위함 (버튼은 아래쪽)
		return

	# 4. 상/하단 금지 구역 확인
	var tower_half_height = 20.0
	if (target_pos.y - tower_half_height) < SPAWN_ZONE_Y:
		print("적 생성 구역을 침범할 수 없습니다.")
		return
	if (target_pos.y + tower_half_height) > game_over_y:
		print("게임오버 구역을 침범할 수 없습니다.")
		return
	
	# 5. 비용 확인
	var current_cost = TOWER_COSTS[selected_tower_type]
	if gold < current_cost:
		print("코인이 부족합니다! (필요: %d, 보유: %d)" % [current_cost, gold])
		return
	
	# 6. 배치 제한 확인 (행별 1개 제한)
	if not occupied_rows.has(grid_y):
		occupied_rows[grid_y] = {"left": false, "right": false}
		
	if occupied_rows[grid_y][side]:
		print("이미 이 행의 %s 구역에 타워가 있습니다." % side)
		return
		
	# 7. 설치 및 차감
	place_tower(target_pos, selected_tower_type)
	occupied_rows[grid_y][side] = true
	gold -= current_cost
	update_ui()
	print("타워 설치 완료! 잔액: ", gold)
	
	# 입력 처리 완료 (중복 방지)
	get_viewport().set_input_as_handled()

func place_tower(pos, type): # 인자 추가
	# 타워를 복제합니다.
	var new_tower = tower_scene.instantiate()
	
	# 위치 설정
	new_tower.position = pos
	new_tower.type = type # 타워 타입 설정 (setup_tower 호출은 _ready에서 됨)
	# 또는 명시적으로 호출: new_tower.setup_tower(type) 이 낫지만 _ready 실행 전이라 변수 할당이 안전
	
	# 게임 화면에 타워를 추가합니다.
	add_child(new_tower)

func sell_tower(tower):
	# 1. 타워 위치로 격자 및 사이드(좌/우) 계산
	var grid_x = floor(tower.position.x / GRID_SIZE)
	var grid_y = floor(tower.position.y / GRID_SIZE)
	var tower_half_width = 20.0
	var side = ""
	
	if (tower.position.x + tower_half_width) <= TOWER_ZONE_WIDTH:
		side = "left"
	elif (tower.position.x - tower_half_width) >= (screen_width - TOWER_ZONE_WIDTH):
		side = "right"
		
	# 2. 점유 해제
	if occupied_rows.has(grid_y):
		if side != "":
			occupied_rows[grid_y][side] = false
			print("격자 해제: Row %d, Side %s" % [grid_y, side])
			
	# 3. 환불 (100%)
	var refund_amount = TOWER_COSTS[tower.type]
	gold += refund_amount
	
	# 4. 타워 삭제 및 UI 갱신
	tower.queue_free()
	update_ui()
	print("타워 판매 완료! 환불: $%d, 잔액: $%d" % [refund_amount, gold])
