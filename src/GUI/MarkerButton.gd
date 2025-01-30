extends TextureButton

export(String,
	"",

	# dungeons
	"hc",
	"ep",
	"dp",
	"th",
	"at",
	"pd",
	"sp",
	"sw",
	"tt",
	"ip",
	"mm",
	"tr",
	"gt",
	"ganon",

	# connectors
	"spec",
	"paradox",
	"bunny",
	"bumper",
	"brother",
	"granny",
	"fairy",
	"keese",
	"oldman",
	"mountain",
	"spiral",
	"sick_kid",
	"sriracha",
	"spike",
	"potion_shop",
	"luck_fairy",
	"smith",
	"big_bomb",
	"library",
	
	#dropdowns
	"well",
	"uncle",
	"hideout",
	"lumberjacks",

	# items
	"sword",
	"mirror",
	"mearl",
	"hammer",
	"hookshot",
	"lamp",
	"fire_rod",
	"ice_rod",
	"somaria",
	"byrna_cape",
	"powder",
	"bow",
	"gloves",
	"mitts",
	"bombos",
	"ether",
	"quake",
	"boots",
	"flippers",
	"key",
	"big_key",
	"bombs",
	"bottle",
	"magic",
	"flute",
	"shovel",
	"mushroom",
	"bottle",
	"book",
	
	# entrances
	"aginah",
	"bonk_rocks",
	"brewery",
	"c_house",
	"cave_45",
	"checkerboard",
	"chest_game",
	"chicken_house",
	"dam",
	"graveyard_ledge",
	"hammer_pegs",
	"kings_tomb",
	"mire shed",
	"pyramid fairy",
	"waterfall fairy",
	"mini moldorm",
	"hype cave",
	"blinds house",
	"mimic cave",
	"tavern",
	"shop"
) var connector
export(Color) var line_color: Color = Color.red
var is_hovering: bool = false

onready var count_label = $Label
onready var count = 0

func _ready() -> void:
	connect("button_down", self, "_on_pressed")
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")
	count_label.text = "%d" % [count]

func _draw() -> void:
	if connector == "":
		return
	if !visible:
		return
	if !is_hovering:
		return

	for node in get_tree().get_nodes_in_group(connector):
		if node == self \
			or !node.visible \
			or node.is_following:
			continue
		draw_line(
			rect_size / 2,
			node.global_position - rect_global_position,
			line_color,
			2, true
		)

func _on_pressed() -> void:
	Events.emit_signal("marker_clicked", texture_normal, modulate, connector)

func _on_mouse_entered() -> void:
	is_hovering = true
	update()

func _on_mouse_exited() -> void:
	is_hovering = false
	update()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.is_pressed():
		match(event.button_index):
			BUTTON_WHEEL_UP:
				set_count(count + 1)
			BUTTON_WHEEL_DOWN:
				if count >= 0:
					set_count(count - 1)

func set_count(new_count: int) -> void:
	count = new_count
	if count >= 0:
		count_label.visible = true
	else:
		count_label.visible = false
	count_label.text = "%d" % [count]
