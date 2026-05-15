extends CanvasLayer

@onready var gas_label = $PanicVignette/MarginContainer/VBoxContainer/GasLabel
@onready var terror_label = $PanicVignette/MarginContainer/VBoxContainer/TerrorLabel
@onready var panic_vignette = $PanicVignette

func _ready() -> void:
	# Começa com o filtro vermelho invisível (Opacidade / Alpha = 0)
	panic_vignette.color.a = 0.0

func _process(delta: float) -> void:
	# 1. Atualiza os textos consultando o Autoload
	gas_label.text = "Galões: " + str(GameManager.gasoline_count) + "/7"
	terror_label.text = "Terror: " + str(int(GameManager.terror_level)) + "%"
	
	# 2. O Efeito de Pânico!
	# Só começa a piscar/sujar a tela se o terror passar da metade
	if GameManager.terror_level > 50.0:
		# Transforma o terror (50 a 100) em um multiplicador (0.0 a 1.0)
		var intensity = (GameManager.terror_level - 50.0) / 50.0
		
		# Aplica a intensidade na opacidade da cor vermelha (Alpha)
		# Multipliquei por 0.5 para não ficar 100% cego quando chegar no 100 de terror
		panic_vignette.color.a = intensity * 0.5 
	else:
		panic_vignette.color.a = 0.0
