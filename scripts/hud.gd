extends CanvasLayer

## Hearts + mana + credits HUD. Lives inside every room scene (see
## room_template.tscn) and rebinds itself to whichever player and GameState
## data the room starts with.

@onready var hearts_full: Label = $Row/HeartsFull
@onready var hearts_empty: Label = $Row/HeartsEmpty
@onready var credits_label: Label = $Row/Credits
@onready var mana_bar: ProgressBar = $ManaBar

var _mana_tween: Tween

func _ready() -> void:
	GameState.credits_changed.connect(_on_credits_changed)
	_on_credits_changed(GameState.credits)
	_bind_player.call_deferred()     # the player may finish _ready after us

func _bind_player() -> void:
	# On boot the save may point at another room: this HUD is torn down by the
	# scene change before the deferred call runs, so get_tree() can be null.
	if not is_inside_tree():
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Player = players[0]
	if not player.health_changed.is_connected(_on_health_changed):
		player.health_changed.connect(_on_health_changed)
	if not player.mana_changed.is_connected(_on_mana_changed):
		player.mana_changed.connect(_on_mana_changed)
	_on_health_changed(player.health, player.max_health)
	_on_mana_changed(player.mana, player.max_mana)

func _on_health_changed(current: int, maximum: int) -> void:
	hearts_full.text = "♥".repeat(maxi(current, 0))
	hearts_empty.text = "♡".repeat(maxi(maximum - current, 0))

func _on_mana_changed(current: int, maximum: int) -> void:
	mana_bar.max_value = maxi(maximum, 1)
	# smooth the bar instead of snapping, for a bit of polish
	if _mana_tween:
		_mana_tween.kill()
	_mana_tween = create_tween()
	_mana_tween.tween_property(mana_bar, "value", float(current), 0.15)

func _on_credits_changed(total: int) -> void:
	credits_label.text = str(total)
