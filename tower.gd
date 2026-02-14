extends Area2D

# 총알 씬 프리로드
var bullet_scene = preload("res://Bullet.tscn")

enum TowerType {BLUE, YELLOW, ORANGE}

var type = TowerType.BLUE
var damage = 1
var cost = 2
var fire_interval = 2.0
var cooldown = 0.0

@onready var ray_cast = $RayCast2D

var build_time = 0

func _ready():
	# 화면 중앙(180) 기준으로 왼쪽/오른쪽 판단 및 레이캐스트 방향 설정
	if position.x < 180:
		ray_cast.target_position = Vector2(500, 0) # 오른쪽으로 발사
	else:
		ray_cast.target_position = Vector2(-500, 0) # 왼쪽으로 발사
	
	setup_tower(type) # 초기 설정
	build_time = Time.get_ticks_msec()

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 설치 직후(0.5초 이내)에는 판매 불가 (더블 클릭 방지 및 입력 충돌 방지)
		if Time.get_ticks_msec() - build_time < 500:
			return
			
		# 부모(MainGame)에게 판매 요청
		var main_game = get_parent()
		if main_game.has_method("sell_tower"):
			main_game.sell_tower(self)
			get_viewport().set_input_as_handled() # 입력 처리 완료 (중복 방지)


func setup_tower(new_type):
	type = new_type
	match type:
		TowerType.BLUE:
			damage = 1
			cost = 2
			fire_interval = 2.0
		TowerType.YELLOW:
			damage = 2
			cost = 4
			fire_interval = 2.0
		TowerType.ORANGE:
			damage = 4
			cost = 6
			fire_interval = 2.0
	
	queue_redraw() # 색상 변경을 위해 다시 그리기

func _physics_process(delta):
	cooldown -= delta

	if cooldown <= 0:
		if ray_cast.is_colliding():
			var collider = ray_cast.get_collider()
			if collider and collider.is_in_group("enemies"):
				shoot()

func shoot():
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position
	bullet.damage = damage # 데미지 전달
	
	if position.x < 180:
		bullet.direction = Vector2.RIGHT
	else:
		bullet.direction = Vector2.LEFT
		
	get_parent().add_child(bullet)
	cooldown = fire_interval

func _draw():
	var color = Color.BLUE
	match type:
		TowerType.BLUE:
			color = Color.BLUE
		TowerType.YELLOW:
			color = Color.YELLOW
		TowerType.ORANGE:
			color = Color(1.0, 0.5, 0.0) # ORANGE
	
	# 40x40 박스 그리기 (중심 기준)
	draw_rect(Rect2(-20, -20, 40, 40), color)
