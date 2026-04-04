extends Area2D

var connector: String = ""
var uuid: String = ""
var is_following: bool = true
var is_connector: bool = false
var is_hovering: bool = false
var sprite_path: String setget set_sprite_path, get_sprite_path

var sprite: Sprite

onready var count_label = $Label
onready var count = 0

func _get_marker_data(marker: Node2D, delete: bool = false) -> Dictionary:
    if delete:
        return {
            "event": "remove_marker",
            "uuid": marker.uuid
            }

    # Send coordinates relative to LightWorld so they are layout-independent
    var lw = get_node("/root/Tracker/LightWorld")
    var map_pos = marker.global_position - lw.global_position
    return {
        "event": "update_marker",
        "uuid": marker.uuid,
        "x": map_pos.x,
        "y": map_pos.y,
        "count": marker.count,
        "connector": marker.connector,
        "color": marker.modulate.to_html(false),
        "is_connector": marker.is_connector,
        "sprite_path": marker.sprite_path,
    }


func init() -> void:
    sprite = $Sprite

func _ready() -> void:
    init()
    connect("mouse_entered", self, "_on_mouse_entered")
    connect("mouse_exited", self, "_on_mouse_exited")
    add_to_group(Util.GROUP_MARKER)
    count_label.text = "%d" % [count]

func _process(_delta: float) -> void:
    if is_following:
        global_position = get_global_mouse_position()

func _draw() -> void:
    if connector == "":
        return
    if !visible:
        return
    if is_following:
        return
    if !is_hovering:
        return

    for node in get_tree().get_nodes_in_group(connector):
        if node == self \
            or !node.visible:
            continue
        draw_line(
            Vector2.ZERO,
            node.global_position - global_position,
            Color.red,
            2, true
        )

func _input(event: InputEvent) -> void:
    if !Util.drag_and_drop:
        return

    if event is InputEventMouseButton \
        and event.button_index == BUTTON_LEFT \
        and !event.is_pressed():
            is_following = false
            Events.emit_signal("coop_send_update", _get_marker_data(self))
            if global_position.y > 750:
                queue_free()

func _input_event(_viewport: Object, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            is_following = event.is_pressed() 
            if !is_following and global_position.y > 750:
                queue_free()
            if !is_following:
                Events.emit_signal("coop_send_update", _get_marker_data(self))
        elif event.button_index == BUTTON_RIGHT \
            and event.is_pressed():
            hide()
            Util.add_hidden(self)
            Events.emit_signal("coop_send_update", _get_marker_data(self, true))
        elif event.button_index == BUTTON_WHEEL_UP and event.is_pressed():
            set_count(count + 1)
            Events.emit_signal("coop_send_update", _get_marker_data(self))
        elif event.button_index == BUTTON_WHEEL_DOWN and event.is_pressed():
            if count >= 0:
                set_count(count - 1)
                Events.emit_signal("coop_send_update", _get_marker_data(self))

func _on_mouse_entered() -> void:
    is_hovering = true
    update()

func _on_mouse_exited() -> void:
    is_hovering = false
    update()

func set_sprite(texture: Texture) -> void:
    sprite.texture = texture

func set_sprite_path(path: String) -> void:
    var texture = load(path)
    if texture is Texture:
        sprite.texture = texture

func get_sprite_path() -> String:
    if sprite:
        return sprite.texture.resource_path
    return ""

func set_count(new_count: int) -> void:
    count = new_count
    if count >= 0:
        count_label.visible = true
    else:
        count_label.visible = false
    count_label.text = "%d" % [count]
