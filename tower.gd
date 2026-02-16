extends Area2D

# 총알 씬 프리로드
var bullet_scene = preload("res://Bullet.tscn")

var type = "towerA"
var damage = 1
var cost = 2
var fire_interval = 2.0
var cooldown = 0.0
var effect = "none"
var size = Vector2(40, 40) # 기본 40x40, 가변 가능
var bullet_speed = 400
var base_color = Color.WHITE

var current_texture: Texture2D # 그라데이션 텍스처 저장용

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
	var data = GameDataManager.tower_data.get(type, GameDataManager.tower_data["towerA"])
	
	damage = data.get("damage", 1)
	cost = data.get("cost", 2)
	fire_interval = data.get("fire_interval", 2.0)
	bullet_speed = data.get("bullet_speed", 400)
	effect = data.get("effect", "none")
	size = data.get("size", Vector2(40, 40))
	
	var color_hex = data.get("color", Color.WHITE)
	base_color = Color(color_hex) # Store for bullet
	create_gradient_texture(base_color)
	
	queue_redraw()

func create_gradient_texture(color):
	# 그라데이션 텍스처 생성 (중앙 볼록 입체감)
	# base_color는 "네온" 밝은 색으로 가정하거나, 여기서 밝기 조절
	var c1 = color.darkened(0.5) # 외곽 (어두운색)
	var c2 = color.lightened(0.2) # 중심 (밝은색)
	
	# 사용자 요청: 모든 타워 컬러 유지 + 입체감
	# 기존 로직과 비슷하게 처리
			
	var gradient = Gradient.new()
	gradient.set_color(0, c2) # 중심 (밝은색)
	gradient.set_color(1, c1) # 외곽 (어두운색)
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL # 원형 그라데이션
	texture.fill_from = Vector2(0.5, 0.5) # 중앙
	texture.fill_to = Vector2(0.5, 0.0) # 외곽
	
	current_texture = texture

func _physics_process(delta):
	cooldown -= delta

	if cooldown <= 0:
		if ray_cast.is_colliding():
			var collider = ray_cast.get_collider()
			if collider and collider.is_in_group("enemies"):
				shoot()

func shoot():
	if effect == "double shot":
		# 좌우(X축) 16px 간격으로 배치 (앞뒤로 나가는 형태)
		fire_bullet(Vector2(-8, 0))
		fire_bullet(Vector2(8, 0))
	else:
		fire_bullet()
		
	cooldown = fire_interval

func fire_bullet(offset = Vector2.ZERO):
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + offset # 오프셋 적용
	# 총알 발사 위치 보정 (타워 크기에 따라 다를 수 있음? 일단 중심에서 발사)
	
	bullet.damage = damage
	bullet.speed = bullet_speed
	bullet.effect = effect # 총알에 효과 전달 (slow, penetrate)
	bullet.color = base_color # 색상 전달
	
	if position.x < 180:
		bullet.direction = Vector2.RIGHT
	else:
		bullet.direction = Vector2.LEFT
		
	get_parent().add_child(bullet)

func _draw():
	if current_texture:
		# 박스 그리기 (중심 기준)
		# size가 (80, 40)이면 (-40, -20)에서 시작
		var half_size = size / 2.0
		draw_texture_rect(current_texture, Rect2(-half_size, size), false)
