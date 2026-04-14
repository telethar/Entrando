extends Control
onready var selected_port = $PortNum

onready var start_button = $Start
onready var close_button = $Close
onready var copy_button = $Copy

var upnp = null
var upnp_port = null
var server_status = null
var hint_text = ""
var _upnp_thread: Thread

onready var shadow = $"/root/Tracker/GUILayer/GUI/CoopServerContainer/CoopServerSettings/Shadow"
onready var status_text = $"/root/Tracker/GUILayer/GUI/CoopServerContainer/CoopServerSettings/Shadow/Container/BG/Control/StatusText"

var server_address = ""

func _ready() -> void:
    Events.connect('set_discovered_devices', self, '_on_devices_discovered')
    Events.connect('set_connected_device', self, '_on_set_connected_device')
    Events.connect('coop_server_started', self, '_on_server_started')
    Events.connect('coop_server_stopped', self, '_on_server_stopped')
    close_button.connect('pressed', self, '_on_close_pressed')
    start_button.connect('pressed', self, '_on_start_pressed')
    copy_button.connect('pressed', self, '_on_copy_pressed')

func _on_server_started(ip) -> void:
    server_address = "ws://" + ip
    server_status = "Running"
    start_button.text = "Stop Co-op Server"
    hint_text = start_button.hint_tooltip
    start_button.hint_tooltip = ""
    copy_button.show()

func _on_server_stopped() -> void:
    server_status = "Stopped"
    start_button.text = "Start Co-op Server"
    start_button.hint_tooltip = hint_text
    copy_button.hide()

func _on_copy_pressed() -> void:
    OS.set_clipboard(server_address)

func _on_start_pressed() -> void:
    if server_status == "Running":
        Events.emit_signal('stop_coop_server')
        return
    else:
        _upnp_setup(int(selected_port.get_line_edit().text))
    

func _on_close_pressed() -> void:
    shadow.hide()

func _on_upnp_completed(_err):
    Events.emit_signal('start_coop_server', int(selected_port.get_line_edit().text))

func _upnp_setup(server_port):
    # UPNP queries take some time, run in a thread to avoid blocking.
    start_button.disabled = true
    status_text.text = "Discovering UPnP gateway..."
    _upnp_thread = Thread.new()
    _upnp_thread.start(self, "_upnp_thread_func", server_port)

func _set_status(text: String) -> void:
    status_text.text = text

func _upnp_thread_func(server_port):
    upnp = UPNP.new()
    var err = upnp.discover()
    if err != OK:
        call_deferred("_set_status", "UPnP discovery failed (error %d), starting without UPnP..." % err)
        call_deferred("_upnp_thread_done", err, server_port)
        return
    if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
        call_deferred("_set_status", "UPnP gateway found, setting up port mapping...")
        upnp.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP")
        upnp.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "TCP")
        upnp_port = server_port
        call_deferred("_upnp_thread_done", OK, server_port)
    else:
        call_deferred("_set_status", "No valid UPnP gateway found, starting without UPnP...")
        call_deferred("_upnp_thread_done", ERR_CANT_CONNECT, server_port)

func _upnp_thread_done(err, _server_port):
    if _upnp_thread:
        _upnp_thread.wait_to_finish()
        _upnp_thread = null
    start_button.disabled = false
    _on_upnp_completed(err)

func _exit_tree():
    if _upnp_thread:
        _upnp_thread.wait_to_finish()
    if (upnp != null and upnp_port != null):
        upnp.delete_port_mapping(upnp_port, "UDP")
        upnp.delete_port_mapping(upnp_port, "TCP")
