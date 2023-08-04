extends Control

onready var selected_device = $DevicesList
onready var refresh_devices = $RefreshDevices

onready var selected_port = $PortNum
onready var set_port_button = $SetPort

onready var save_button = $Save 
onready var close_button = $Close

onready var connect_button = $ConnectDevice

onready var shadow = $"/root/Tracker/GUILayer/GUI/ATContainer/AutoTrackingSettings/Shadow"

func _ready() -> void:
    set_port_button.connect('pressed', self, '_on_set_port_pressed')
    Events.connect('set_discovered_devices', self, '_on_devices_discovered')
    Events.connect('set_connected_device', self, '_on_set_connected_device')
    close_button.connect('pressed', self, '_on_close_pressed')
    save_button.connect('pressed', self, '_on_save_pressed')
    refresh_devices.connect('pressed', self, '_on_refresh_devices_pressed')
    connect_button.connect('pressed', self, '_on_connect_pressed')

    # Load config
    var config = ConfigFile.new()
    var err = config.load("user://config.cfg")
    if err == OK:
        if config.has_section("AutoTracking"):
            if config.get_value("AutoTracking", "Device"):
                for i in range(selected_device.get_item_count()):
                    if selected_device.get_item_text(i) == config.get_value("AutoTracking", "Device"):
                        selected_device.select(i)
                        break
            if config.get_value("AutoTracking", "Port"):
                selected_port.get_line_edit().text = config.get_value("AutoTracking", "Port")

func _on_set_port_pressed() -> void:
    Events.emit_signal('update_autotracking_port', selected_port.get_line_edit().text)

func _on_close_pressed() -> void:
    shadow.hide()

func _on_devices_discovered(_devices) -> void:
    selected_device.clear()
    for i in _devices.size():
        selected_device.add_item(_devices[i], i)

func _on_refresh_devices_pressed() -> void:
    print("Refreshing devices")
    Events.emit_signal('refresh_devices')

func _on_set_connected_device(_device) -> void:
    selected_device.select(_device)

func _on_connect_pressed() -> void:
    if selected_device.get_selected_id() > -1:
        Events.emit_signal('set_selected_device', selected_device.get_item_text(selected_device.get_selected_id()))

func _on_save_pressed() -> void:
    # Open a file
    var config = ConfigFile.new()
    if selected_device.get_selected_id() > -1:
        config.set_value("AutoTracking", "Device", selected_device.get_item_text(selected_device.get_selected_id()))
    config.set_value("AutoTracking", "Port", selected_port.get_line_edit().text)
    config.save("user://config.cfg")
