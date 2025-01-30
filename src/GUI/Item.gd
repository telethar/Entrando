extends HBoxContainer
var arrow_icon_scene: PackedScene
var icons: HBoxContainer

func init() -> void:
    arrow_icon_scene = load("res://src/GUI/ArrowIcon.tscn")
    icons = $Icons

func connect_children(node: Node) -> void:
    for child in node.get_children():
        if child.get_child_count() > 0:
            connect_children(child)
        elif child is TextureButton:
            child.connect("pressed", self, "add_arrow", [child.texture_normal])

func _ready() -> void:
    $Icons/ItemIcon.connect("gui_input", self, "_item_gui_input")
    connect_children($Compass)

func set_item(texture: Texture) -> void:
    $Icons/ItemIcon.texture = texture

func add_arrow(texture: Texture) -> void:
    var arrow = arrow_icon_scene.instance()
    arrow.texture = texture
    icons.add_child(arrow)

func _item_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
        and event.button_index == BUTTON_RIGHT \
        and event.is_pressed():
        queue_free()
