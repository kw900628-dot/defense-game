extends Area2D

var type = "level1" # 기본값
var hp = 1
var max_hp = 1
var speed = 100
var shape = "triangle"
var color = Color.WHITE

# Slow 효과 변수
var base_speed = 0
var is_slowed = false
var slow_timer = 0.0

@onready var hp_label = $HPLabel

func _ready():
	add_to_group("enemies")
	setup_enemy(type) # 초기화

func setup_enemy(new_type):
	type = new_type
	var data = GameDataManager.enemy_data.get(type, GameDataManager.enemy_data["level1"])
	
	max_hp = data.get("hp", 1)
	hp = max_hp
	base_speed = data.get("speed", 100)
	speed = base_speed
	shape = data.get("shape", "triangle")
	color = data.get("color", Color.WHITE)
	
	update_hp_label()
	
	# 체력바 색상 (밝은 배경일 때 검은색 글씨 등) - 일단 흰색 고정
	hp_label.modulate = Color.WHITE
	queue_redraw()

func _process(delta):
	# Slow Timer Check
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			recover_speed()
	
	# 이동
	position.y += speed * delta
	
	if position.y > 1300:
		queue_free()

func apply_slow():
	if is_slowed:
		slow_timer = 2.0 # 시간 갱신
		return
		
	is_slowed = true
	slow_timer = 2.0
	queue_redraw() # 시각 효과 갱신
	
	
	# 속도 감소 로직
	# "적의 speed가 20이하면 2초간 제자리에 멈춤" -> 기본 속도가 20 이하인 경우 0으로
	if base_speed <= 20:
		speed = 0
	else:
		speed = base_speed - 20
		if speed < 0: speed = 0

func recover_speed():
	is_slowed = false
	speed = base_speed
	queue_redraw() # 시각 효과 갱신

func take_damage(amount):
	hp -= amount
	update_hp_label()
	
	if hp <= 0:
		die()


func update_hp_label():
	hp_label.text = str(int(hp))
	
	# 시인성 개선 (밝은 노란색 + 아웃라인 효과는 LabelSettings 필요하지만 간단히 모듈레이트 조정)
	hp_label.modulate = Color(1.0, 1.0, 0.0) # 밝은 노란색
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 4) # 테두리 추가

func die():
	var main_game = get_parent()
	if main_game.has_method("on_enemy_killed"):
		main_game.on_enemy_killed(1)
	queue_free()

func _draw():
	# 2. Slow 효과 (Icy Visual)
	if is_slowed:
		# 더 눈에 띄게: 진한 청록색 + 테두리
		var ice_inner = Color(0.0, 1.0, 1.0, 0.4) # 내부 반투명
		
		# 내부 채우기 (은은한 효과만)
		draw_circle(Vector2.ZERO, 28, ice_inner)

	match shape:
		"triangle":
			var points = PackedVector2Array([Vector2(0, -20), Vector2(20, 20), Vector2(-20, 20)])
			draw_colored_polygon(points, color)
		"circle":
			draw_circle(Vector2.ZERO, 20, color)
		"star":
			var points = PackedVector2Array([
				Vector2(0, -25), Vector2(6, -8),
				Vector2(25, -8), Vector2(10, 5),
				Vector2(15, 25), Vector2(0, 12),
				Vector2(-15, 25), Vector2(-10, 5),
				Vector2(-25, -8), Vector2(-6, -8)
			])
			draw_colored_polygon(points, color)
		"arrow":
			# 아래를 가리키는 화살표 (이동 방향)
			var points = PackedVector2Array([
				Vector2(-10, -10), Vector2(10, -10), # 꼬리 위
				Vector2(10, 10), # 꼬리 아래
				Vector2(20, 10), # 머리 날개 우
				Vector2(0, 30), # 머리 끝
				Vector2(-20, 10), # 머리 날개 좌
				Vector2(-10, 10) # 꼬리 아래 좌
			])
			# 중심을 맞추기 위해 Y좌표 조정 (-5 정도?)
			var centered_points = PackedVector2Array()
			for p in points:
				centered_points.append(p + Vector2(0, -5))
			draw_colored_polygon(centered_points, color)
		_:
			draw_circle(Vector2.ZERO, 20, color) # Fallback
