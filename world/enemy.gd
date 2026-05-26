extends CharacterBody3D

enum State { HIDDEN, STALKING, HUNTING }
var current_state: State = State.HIDDEN
var is_active: bool = false 

@onready var nav_agent = $NavAgent
@onready var pivot = $Pivot
# ATENÇÃO: Confirme se este caminho corresponde ao nome do seu nó dentro do Pivot!
@onready var anim_player = $Pivot/EnemyModel/AnimationPlayer 
@onready var terror_aura = $TerrorAura
@export var player: Node3D

# Valores convertidos para "Metros" no 3D
@export var stalk_speed: float = 2.0 
@export var hunt_speed: float = 4.5
@export var base_light_energy: float = 7.0

var circle_direction: int = 1 

func _ready() -> void:
	GameManager.monster_awakened.connect(_on_monster_awakened)
	GameManager.difficulty_increased.connect(_on_difficulty_increased)

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	# Aplica gravidade para o monstro ficar no chão
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	# Verifica se o player, a tocha e a câmera existem antes de processar
	if player != null and player.get("torch") != null and player.get("camera") != null:
		var light = player.torch.light_energy
		var distance = global_position.distance_to(player.global_position)
		
		# --- MATEMÁTICA NOVA: Zona Segura Travada ---
		var raw_safe_zone = base_light_energy * light * 0.3
		var current_safe_zone = clamp(raw_safe_zone, 5.0, 12.0)
		
		# --- 1. REGRA GLOBAL: O TOQUE FATAL (1.5 Metros) ---
		if distance <= 1.5:
			print("Game Over 3D!")
			GameManager.reset_game()
			get_tree().change_scene_to_file("res://game_over_screen.tscn")
			return 
		
		# --- 2. ONIPRESENÇA (Rubber Banding para 25 Metros) ---
		if distance > 25.0: 
			teleport_near_player(current_safe_zone)
			distance = global_position.distance_to(player.global_position)
			
		# --- 3. DEFINIÇÃO DE ESTADOS ---
		var is_furious = (current_state == State.HUNTING and GameManager.terror_level > 80.0)
		
		if GameManager.terror_level >= 98.0 or is_furious:
			current_state = State.HUNTING
			current_safe_zone = 0.0 
		elif light > 6.0: 
			current_state = State.HIDDEN
		elif light > 3.25: 
			current_state = State.STALKING
		else:
			current_state = State.HUNTING
			current_safe_zone = 0.0
			
		# --- O NOVO GPS INTELIGENTE (NavMesh) ---
		# Dizemos ao GPS onde o jogador está
		nav_agent.target_position = player.global_position
		
		# Perguntamos ao GPS qual é o próximo passo para desviar das pedras/árvores
		var next_path_pos = nav_agent.get_next_path_position()
		
		# Calcula a direção apontando para o CAMINHO, e não para o jogador através da parede
		var dir = global_position.direction_to(next_path_pos)
		dir.y = 0 
		dir = dir.normalized()
		
		# --- A MÁGICA DA VISÃO (Dot Product) ---
		var player_forward = -player.camera.global_transform.basis.z.normalized()
		var dir_to_monster = player.global_position.direction_to(global_position).normalized()
		var is_player_looking = player_forward.dot(dir_to_monster) > 0.5
		
		# Gira o monstro para encarar o player (ele olha para o player, mas caminha pelo GPS)
		if dir != Vector3.ZERO:
			var target_pos = player.global_position
			target_pos.y = global_position.y 
			pivot.look_at(target_pos, Vector3.UP)
			
		# --- 4. A AÇÃO 3D ---
		match current_state:
			State.HIDDEN:
				anim_player.play("walk")
				pivot.visible = true 
				
				velocity.x = dir.x * stalk_speed * 0.4
				velocity.z = dir.z * stalk_speed * 0.4
				move_and_slide()
				
			State.STALKING:
				pivot.visible = true
				anim_player.play("walk")
				
				if not is_player_looking:
					velocity.x = dir.x * stalk_speed * 0.9
					velocity.z = dir.z * stalk_speed * 0.9
				else:
					if distance > current_safe_zone:
						velocity.x = dir.x * stalk_speed
						velocity.z = dir.z * stalk_speed
					elif distance < current_safe_zone - 2.0:
						velocity.x = -dir.x * (stalk_speed * 0.8) 
						velocity.z = -dir.z * (stalk_speed * 0.8)
					else:
						var tangent = dir.rotated(Vector3.UP, PI / 2 * circle_direction)
						velocity.x = tangent.x * (stalk_speed * 0.7)
						velocity.z = tangent.z * (stalk_speed * 0.7)
						if randf() < 0.02:
							circle_direction *= -1
				
				move_and_slide()
				
			State.HUNTING:
				anim_player.play("run")
				pivot.visible = true
				
				if distance > 15.0:
					teleport_near_player(current_safe_zone)
					distance = global_position.distance_to(player.global_position)
					
					# Atualiza a direção do GPS instantaneamente após o teleporte
					nav_agent.target_position = player.global_position
					next_path_pos = nav_agent.get_next_path_position()
					dir = global_position.direction_to(next_path_pos)
					dir.y = 0
					dir = dir.normalized()
				
				velocity.x = dir.x * hunt_speed
				velocity.z = dir.z * hunt_speed
				move_and_slide()
					
	# Lógica da Aura de Terror
	var bodies = terror_aura.get_overlapping_bodies()
	for body in bodies:
		if body.name == "Player":
			var dist = global_position.distance_to(body.global_position)
			var intensity = remap(dist, 25.0, 0.0, 4.0, 20.0)
			GameManager.increase_terror(intensity * delta)

# --- NOVO SISTEMA DE TELEPORTE SEGURO ---
func teleport_near_player(safe_zone: float) -> void:
	var random_angle = randf() * TAU 
	var spawn_distance = max(5.0, safe_zone + 5.0)
	var offset = Vector3(cos(random_angle), 0, sin(random_angle)) * spawn_distance
	
	var desired_pos = player.global_position + offset
	desired_pos.y = player.global_position.y 
	
	# Pede ao servidor do mapa o ponto azul (NavMesh) mais próximo daquela posição
	var map = get_world_3d().get_navigation_map()
	var safe_pos = NavigationServer3D.map_get_closest_point(map, desired_pos)
	
	global_position = safe_pos

func _on_monster_awakened() -> void:
	is_active = true
	if player != null and player.get("torch") != null:
		var light = player.torch.light_energy
		var raw_safe_zone = base_light_energy * light * 0.3
		var current_safe_zone = clamp(raw_safe_zone, 5.0, 12.0)
		teleport_near_player(current_safe_zone)

func _on_difficulty_increased(level: int) -> void:
	if level == 1:
		stalk_speed += 0.5 
	elif level == 2:
		stalk_speed += 0.2  
		hunt_speed += 1.0
