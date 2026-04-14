extends Node

enum {MODE_OW, MODE_DUNGEON}

const GROUP_MARKER = "markers"
const GROUP_ITEMS = "items"
const GROUP_ENTRANCES = "entrances"
const GROUP_NOTES = "notes_buttons"
const COOP_PROTOCOL_VERSION = 2

var mode: int = MODE_OW
# only shows entrances, and not OW items
var andy_mode: bool = false
# enables drag and dropping markers
var drag_and_drop: bool = false
var nodes_hidden: Array = []
var last_marker
var alph = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
var coop_server = false


func _ready() -> void:
    Events.connect("tracker_restarted", self, "_on_tracker_restarted")
    Events.connect("mode_changed", self, "_on_mode_changed")
    Events.connect("undo", self, "unhide_node")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
        and event.is_pressed():
         match(event.button_index):
            BUTTON_XBUTTON1:
                unhide_node()

     
func add_hidden(node: Node) -> void:
    nodes_hidden.append(node)
    if len(nodes_hidden) > 10:
        var to_delete = nodes_hidden[0]
        nodes_hidden.erase(to_delete)
        if is_instance_valid(to_delete):
            to_delete.queue_free()
    Events.emit_signal("entrances_changed", -1)

func _on_tracker_restarted() -> void:
    nodes_hidden.clear()

func _on_mode_changed(new_mode: int) -> void:
    mode = new_mode

func unhide_node() -> void:
    if len(nodes_hidden) > 0:
        var node = nodes_hidden[len(nodes_hidden) - 1]
        node.show()
        nodes_hidden.erase(node)
        Events.emit_signal("entrances_changed", 1)

func generate_uuid() -> String:
    """ This is a super simple UUID generator. It's not perfect, but it's good enough for this project."""
    var uuid = ""
    for _i in range(0, 32):
        uuid += alph[randi() % alph.length()]
    return uuid

func get_external_ip_address() -> String:
    var http = HTTPClient.new()
    var err = 0
    var headers = [
        "User-Agent: Pirulo/1.0 (Godot)",
        "Accept: */*"
    ]
    err = http.connect_to_host("http://api.ipify.org")
    if err != OK:
        return "127.0.0.1"
    while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
        http.poll()
        yield(Engine.get_main_loop(), "idle_frame")

    if http.get_status() != HTTPClient.STATUS_CONNECTED:
        return "127.0.0.1"
        
    err = http.request(HTTPClient.METHOD_GET, "/", headers)

    while http.get_status() == HTTPClient.STATUS_REQUESTING:
        http.poll()
        yield(Engine.get_main_loop(), "idle_frame")
    
    if http.get_status() != HTTPClient.STATUS_BODY and http.get_status() != HTTPClient.STATUS_CONNECTED:
        return "127.0.0.1"
    var ip_address = ""
    if http.has_response():
         ip_address = http.read_response_body_chunk().get_string_from_utf8()
    else:
        ip_address = "127.0.0.1"
    return ip_address
