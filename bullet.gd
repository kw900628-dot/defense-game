extends Area2D

var speed = 400
var direction = Vector2.RIGHT
var damage = 1
var effect = "none" # "none", "slow", "penetrate"
var color = Color.WHITE

func _ready():
	$ColorRect.color = color
	
	if effect == "penetrate":
		# 길쭉한 형태로 변경 (예: 가로 20, 세로 6)
		$ColorRect.size = Vector2(20, 6)
		$ColorRect.position = Vector2(-10, -3) # 중심 맞추기
		
		# 충돌 범위도 변경해야 하나, Area2D 충돌체는 Resources로 공유될 수 있어 주의.
		# 여기서는 간단히 scale로 조정
		$CollisionShape2D.scale = Vector2(2.0, 0.6)

func _process(delta):
	position += direction * speed * delta
	
	# 타워 구역 침범 방지 (Left Zone: < 80, Right Zone: > 280)
	if direction.x > 0: # 오른쪽으로 이동 중
		if position.x > 280:
			queue_free()
	elif direction.x < 0: # 왼쪽으로 이동 중
		if position.x < 80:
			queue_free()

func _on_area_entered(area):
	if area.is_in_group("enemies"):
		# 데미지 적용
		if area.has_method("take_damage"):
			area.take_damage(damage)
			
		# 특수 효과 적용
		if effect == "slow":
			if area.has_method("apply_slow"):
				area.apply_slow()
		
		# 관통 여부 확인
		if effect == "penetrate":
			# 관통 시 총알 삭제 안 함
			pass
		else:
			queue_free() # 총알 삭제

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
