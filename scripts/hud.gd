extends CanvasLayer

## Hearts + credits HUD. Lives inside every room scene (see room_template.tscn)
## and rebinds itself to whichever player and GameState data the room starts with.

@onready var hearts_full: Label = $Row/HeartsFull
@onready var hearts_empty: Label = $Row/HeartsEmpty
@onready var credits_label: Label = $Row/Credits

func _ready() -> void:
	GameState.credits_changed.connect(_on_credits_changed)
	_on_credits_changed(GameState.credits)
	_bind_player.call_deferred()     # the player may finish _ready after us

func _bind_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Player = players[0]
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)

func _on_health_changed(current: int, maximum: int) -> void:
	hearts_full.text = "♥".repeat(maxi(current, 0))
	hearts_empty.text = "♡".repeat(maxi(maximum - current, 0))

func _on_credits_changed(total: int) -> void:
	credits_label.text = str(total)
