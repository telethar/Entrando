extends Node

# The URL we will connect to

# Our WebSocketClient instance
var _client = WebSocketClient.new()
var connected_to = ""
var _should_reconnect = false
var _reconnect_delay = 1.0
var _reconnect_timer: Timer
var _pending_updates = []
const RECONNECT_DELAY_MIN = 1.0
const RECONNECT_DELAY_MAX = 30.0

onready var connect_status = $"/root/Tracker/GUILayer/GUI/CoopClientContainer/CoopClientConnect/Shadow/Container/BG/Control/StatusText"
onready var gui_status = $"/root/Tracker/GUILayer/GUI/Container/Margin/HSplitContainer/Entrances/Dungeons/MarginContainer/VBoxContainer/HBoxContainer2/CoopStatus"
onready var gui_status_container = $"/root/Tracker/GUILayer/GUI/Container/Margin/HSplitContainer/Entrances/Dungeons/MarginContainer/VBoxContainer/HBoxContainer2"
onready var gui_label_container = $"/root/Tracker/GUILayer/GUI/Container/Margin/HSplitContainer/Entrances/Dungeons/MarginContainer/VBoxContainer/HBoxContainer"
const TODO_TEXTURE = preload("res://assets/icons/todo.png");
const CHECKED_GREY = Color("282626")

func _ready():
    # Connect base signals to get notified of connection open, close, and errors.
    _client.connect("connection_closed", self, "_closed")
    _client.connect("connection_error", self, "_closed")
    _client.connect("connection_established", self, "_connected")
    _client.connect("data_received", self, "_on_data")
    _client.connect("server_close_request", self, "_server_close_request")
    Events.connect("coop_send_update", self, "_send_update")
    Events.connect("connect_to_coop_server", self, "_on_connect_to_server")
    Events.connect("stop_coop_server", self, "_on_stop_coop_server")

    _reconnect_timer = Timer.new()
    _reconnect_timer.one_shot = true
    _reconnect_timer.connect("timeout", self, "_on_reconnect_timeout")
    add_child(_reconnect_timer)

func _on_connect_to_server(websocket_url) -> void:
    # Initiate connection to the given URL.
    _reconnect_timer.stop()
    var err = _client.connect_to_url(websocket_url, [])
    if err != OK:
        connect_status.text = "Unable to connect"
        return
    connected_to = websocket_url
    _should_reconnect = true

func _on_stop_coop_server() -> void:
    _should_reconnect = false
    _reconnect_timer.stop()

var _close_reason = ""

func _server_close_request(code: int, reason: String) -> void:
    if code == 4000:
        _close_reason = reason
        _should_reconnect = false

func _closed(_was_clean = false):
    if _close_reason != "":
        connect_status.text = _close_reason
        gui_status.text = "Version mismatch"
        _close_reason = ""
    elif _should_reconnect and connected_to != "":
        connect_status.text = "Reconnecting in %ds..." % int(_reconnect_delay)
        gui_status.text = "Reconnecting..."
        _reconnect_timer.wait_time = _reconnect_delay
        _reconnect_timer.start()
        _reconnect_delay = min(_reconnect_delay * 2, RECONNECT_DELAY_MAX)
    else:
        connect_status.text = "Connection closed"
        gui_status.text = "Disconnected"

func _on_reconnect_timeout() -> void:
    if !_should_reconnect or connected_to == "":
        return
    connect_status.text = "Reconnecting..."
    var err = _client.connect_to_url(connected_to, [])
    if err != OK:
        connect_status.text = "Reconnect failed, retrying in %ds..." % int(_reconnect_delay)
        _reconnect_timer.wait_time = _reconnect_delay
        _reconnect_timer.start()
        _reconnect_delay = min(_reconnect_delay * 2, RECONNECT_DELAY_MAX)

func _connected(_proto = ""):
    _reconnect_delay = RECONNECT_DELAY_MIN
    connect_status.text = "Connected to " + connected_to
    gui_status_container.show()
    gui_label_container.show()
    if (!Util.coop_server):
        gui_status.text = "Connected"
    # Send our protocol version to the server
    var handshake = {"event": "handshake", "protocol_version": Util.COOP_PROTOCOL_VERSION}
    _client.get_peer(1).put_packet(JSON.print(handshake).to_utf8())

func _flush_pending_updates() -> void:
    # Compact the queue: for markers, only the latest state per uuid matters
    var marker_state = {}
    var other_updates = []
    for data in _pending_updates:
        if data.get("event") == "update_marker" or data.get("event") == "remove_marker":
            var uuid = data.get("uuid", "")
            if uuid != "":
                marker_state[uuid] = data
        else:
            other_updates.append(data)
    _pending_updates.clear()
    for data in other_updates:
        _client.get_peer(1).put_packet(JSON.print(data).to_utf8())
    for uuid in marker_state:
        _client.get_peer(1).put_packet(JSON.print(marker_state[uuid]).to_utf8())

func _send_update(data: Dictionary) -> void:
    if _client.get_connected_host() == "":
        if _should_reconnect:
            _pending_updates.append(data)
        return
    _client.get_peer(1).put_packet(JSON.print(data).to_utf8())

func _on_data():
    var pkt = parse_json(_client.get_peer(1).get_packet().get_string_from_utf8())
    if typeof(pkt) != TYPE_DICTIONARY:
        return

    if pkt['event'] == "ping":
        return

    if pkt['event'] == "handshake":
        var server_ver = pkt.get("protocol_version", -1)
        if server_ver != Util.COOP_PROTOCOL_VERSION:
            # Server should also kick us, but disconnect from our side too
            _should_reconnect = false
            _close_reason = "Coop protocol mismatch: server v%d, client v%d. Ensure server and clients are using the same version of Entrando." % [server_ver, Util.COOP_PROTOCOL_VERSION]
            _client.disconnect_from_host(4000, "Protocol version mismatch")
            return
        # Handshake OK — flush any queued offline updates
        _flush_pending_updates()
        return

    if pkt['event'] == "update_marker":
        Events.emit_signal("coop_update_marker", pkt)

    elif pkt['event'] == "remove_marker":
        Events.emit_signal("coop_remove_marker", pkt.uuid)

    elif pkt['event'] == "toggle_todo":
        var icon = get_node(pkt['node_path'])
        if (icon.get_pressed_texture() != TODO_TEXTURE):
            icon.set_pressed_texture(TODO_TEXTURE)
        if (icon.get_parent().self_modulate != CHECKED_GREY) and !icon.is_pressed():
            icon.set_pressed(pkt['is_pressed'])

    elif pkt['event'] == "toggle_button":
        var button = get_node(pkt['node_path'])
        button.set_pressed(false)
        if button.get_parent().self_modulate != CHECKED_GREY && pkt['checked']:
            button.get_parent().self_modulate = CHECKED_GREY
        elif button.get_parent().self_modulate == CHECKED_GREY && !pkt['checked']:
            button.get_parent().self_modulate = Color.white

    elif pkt['event'] == "add_location":
        var location = get_node(pkt['node_path'])
        location.show()
        Util.remove_hidden(location)

    elif pkt['event'] == "remove_location":
        var location = get_node(pkt['node_path'])
        location.hide()
        Util.add_hidden(location)

func _process(delta):
    _client.poll()
