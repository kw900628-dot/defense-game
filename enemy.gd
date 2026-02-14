extends Area2D

enum EnemyType {TRIANGLE, CIRCLE, STAR}

var type = EnemyType.TRIANGLE
var hp = 3
var max_hp = 3
var speed = 100 # 적이 내려오는 속도

@onready var hp_label = $HPLabel

func _ready():
	add_to_group("enemies") # 적 그룹에 추가
	
	# 타입은 MainGame에서 spawn_enemy() 할 때 설정됨 (기본값은 TRIANGLE)
	setup_enemy()


func setup_enemy():
	match type:
		EnemyType.TRIANGLE:
			max_hp = 3
			speed = 100
		EnemyType.CIRCLE:
			max_hp = 6
			speed = 80 # 조금 느림
		EnemyType.STAR:
			max_hp = 9
			speed = 60 # 더 느림
	
	hp = max_hp
	update_hp_label()
	
	if type == EnemyType.CIRCLE:
		hp_label.modulate = Color.BLACK
	else:
		hp_label.modulate = Color.WHITE
		
	queue_redraw() # _draw 호출

func _process(delta):
	# 매 프레임마다 아래(y축 양의 방향)로 이동
	position.y += speed * delta
	
	# 화면 아래(1300픽셀)보다 더 내려가면 삭제 (메모리 정리)
	if position.y > 1300:
		queue_free()

func take_damage(amount):
	hp -= amount
	update_hp_label()
	
	if hp <= 0:
		die()

func update_hp_label():
	hp_label.text = str(hp)

func die():
	# 보상 지급 (메인 게임 호출)
	var main_game = get_parent()
	if main_game.has_method("on_enemy_killed"):
		main_game.on_enemy_killed(1) # 보상은 1코인 고정 (요청사항)
	
	queue_free()

func _draw():
	var color = Color.WHITE
	match type:
		EnemyType.TRIANGLE:
			color = Color.RED
			# 세모 그리기 (중심 기준)
			var points = PackedVector2Array([
				Vector2(0, -20),
				Vector2(20, 20),
				Vector2(-20, 20)
			])
			draw_colored_polygon(points, color)
		EnemyType.CIRCLE:
			color = Color.WHITE
			draw_circle(Vector2.ZERO, 20, color)
		EnemyType.STAR:
			color = Color.CYAN # 하늘색
			# 별 그리기 (약식 포인트)
			var points = PackedVector2Array([
				Vector2(0, -25), Vector2(6, -8),
				Vector2(25, -8), Vector2(10, 5),
				Vector2(15, 25), Vector2(0, 12),
				Vector2(-15, 25), Vector2(-10, 5),
				Vector2(-25, -8), Vector2(-6, -8)
			])
			draw_colored_polygon(points, color)
