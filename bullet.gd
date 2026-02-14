extends Area2D

var speed = 400
var direction = Vector2.RIGHT
var damage = 1 # 타워에서 설정됨

func _process(delta):
	position += direction * speed * delta
	
	# 타워 구역 침범 방지 (Left Zone: < 80, Right Zone: > 280)
	if direction.x > 0: # 오른쪽으로 이동 중 (왼쪽 타워 발사)
		if position.x > 280:
			queue_free()
	elif direction.x < 0: # 왼쪽으로 이동 중 (오른쪽 타워 발사)
		if position.x < 80:
			queue_free()

func _on_area_entered(area):
	# 이름 대신 그룹으로 확인
	if area.is_in_group("enemies"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		else:
			area.queue_free() # fallback
			
		queue_free() # 총알 삭제
		# 보상 지급은 이제 Enemy의 die()에서 처리함

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free() # 화면 밖으로 나가면 삭제
