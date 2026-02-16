extends Node

var tower_data = {}
var enemy_data = {}
var round_data = {}

func _ready():
	load_data()

func load_data():
	tower_data = load_csv("res://tower.csv", "type")
	enemy_data = load_csv("res://enemy.csv", "type")
	round_data = load_csv("res://round.csv", "type")
	
	# 데이터 후처리 (형변환 등)
	process_tower_data()
	process_enemy_data()
	process_round_data()
	
	print("Game Data Loaded!")
	print("Towers: ", tower_data.keys())
	print("Enemies: ", enemy_data.keys())
	print("Rounds: ", round_data.keys())

func load_csv(path, key_column):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + path)
		return {}
		
	var data = {}
	var headers = []
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() == 0: continue
		
		# 헤더 파싱
		if headers.is_empty():
			headers = line
			continue
			
		# 데이터 파싱
		var entry = {}
		var key = ""
		for i in range(headers.size()):
			if i < line.size():
				var value = line[i]
				var header = headers[i]
				
				# 숫자 변환 시도
				if value.is_valid_float():
					entry[header] = value.to_float()
				elif value.is_valid_int():
					entry[header] = value.to_int()
				else:
					entry[header] = value
				
				if header == key_column:
					key = value
		
		if key != "":
			data[key] = entry
			
	return data

func process_tower_data():
	for key in tower_data:
		var item = tower_data[key]
		# Color Hex String -> Color Object
		if item.has("color"):
			item["color"] = Color(item["color"])
		# Size String "40*40" -> Vector2
		if item.has("size") and item["size"] is String:
			var parts = item["size"].split("*")
			if parts.size() == 2:
				item["size"] = Vector2(parts[0].to_int(), parts[1].to_int())

func process_enemy_data():
	for key in enemy_data:
		var item = enemy_data[key]
		if item.has("color"):
			item["color"] = Color(item["color"])

func process_round_data():
	# 라운드 순서대로 정리할 수도 있지만, 여기서는 map형태로 유지 후 필요한 데이터 변환만 수행
	for key in round_data:
		var item = round_data[key]
		# Time "1:00" -> Seconds (int)
		if item.has("time") and item["time"] is String:
			var parts = item["time"].split(":")
			if parts.size() == 2:
				var minutes = parts[0].to_int()
				var seconds = parts[1].to_int()
				item["duration_seconds"] = minutes * 60 + seconds
