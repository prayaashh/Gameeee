extends CanvasLayer

## Hearts + mana + credits HUD. Lives inside every room scene (see
## room_template.tscn) and rebinds itself to whichever player and GameState
## data the room starts with.

@export_group("Heart art")
## Sprite for a full heart. Assign once in scenes/hud.tscn - every room uses it.
@export var full_heart: Texture2D
## Sprite for a lost (empty) heart.
@export var lost_heart: Texture2D
## On-screen size of one heart, in pixels. The art keeps its aspect ratio and is
## scaled to fit, so a 64x64 sprite still displays at this size.
@export var heart_size := Vector2(32, 32)

@onready var hearts: HBoxContainer = $Row/Hearts
@onready var credits_label: Label = $Row/Credits
@onready var mana_bar: ProgressBar = $ManaBar
@onready var weapon_label: Label = $Weapon

var _mana_tween: Tween
var _mana_synced := false     # first sync snaps, later changes animate

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
	if not player.weapon_changed.is_connected(_on_weapon_changed):
		player.weapon_changed.connect(_on_weapon_changed)
	_on_health_changed(player.health, player.max_health)
	_on_mana_changed(player.mana, player.max_mana)
	_on_weapon_changed(StringName(player.weapon_name()))

func _on_health_changed(current: int, maximum: int) -> void:
	_sync_heart_count(maxi(maximum, 0))
	for index in hearts.get_child_count():
		var heart := hearts.get_child(index) as TextureRect
		if heart != null:
			heart.texture = full_heart if index < current else lost_heart

## Adds/removes heart icons so the row always matches max_health.
func _sync_heart_count(count: int) -> void:
	while hearts.get_child_count() > count:
		var extra := hearts.get_child(hearts.get_child_count() - 1)
		hearts.remove_child(extra)
		extra.queue_free()
	while hearts.get_child_count() < count:
		hearts.add_child(_make_heart())

func _make_heart() -> TextureRect:
	var heart := TextureRect.new()
	heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	# EXPAND_IGNORE_SIZE stops the texture's own 64x64 size from becoming the
	# minimum: the icon is always scaled to fit `heart_size` instead.
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.custom_minimum_size = heart_size
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return heart

func _on_mana_changed(current: int, maximum: int) -> void:
	mana_bar.max_value = maxi(maximum, 1)
	if _mana_tween:
		_mana_tween.kill()
	# A room rebuilds this HUD: show the stored value immediately instead of
	# animating 0 -> current, which looks like the bar refilled on room entry.
	if not _mana_synced:
		_mana_synced = true
		mana_bar.value = float(current)
		return
	# smooth the bar instead of snapping, for a bit of polish
	_mana_tween = create_tween()
	_mana_tween.tween_property(mana_bar, "value", float(current), 0.15)

func _on_credits_changed(total: int) -> void:
	credits_label.text = "credits: "+str(total)

func _on_weapon_changed(weapon_name: StringName) -> void:
	weapon_label.text = "weapon: " + str(weapon_name)
