extends Node

const zelgawoods = "res://assets/map/zelga.json"


onready var marker_scene: PackedScene = preload("res://src/Objects/Marker.tscn")
onready var markers: Node2D = $Markers

func _ready() -> void:
    OS.low_processor_usage_mode = true
    get_tree().set_auto_accept_quit(false)
    $GUILayer/Quit.hide()
    $GUILayer/Quit/Confirmation.connect("confirmed", self, "_on_confirmed")
    $GUILayer/Quit/Confirmation.connect("popup_hide", self, "_on_cancelled")
    $GUILayer/Quit/Confirmation.get_ok().text = "YES."
    $GUILayer/Quit/Confirmation.get_cancel().text = "NO."
    $GUILayer/FileDialog/Dialog.connect("popup_hide", self, "_on_cancelled")
    $GUILayer/FileDialog/Dialog.connect("file_selected", self, "_on_file_selected")
    Events.connect("marker_clicked", self, "generate_marker")
    Events.connect("save_file_clicked", self, "open_save_dialog")
    Events.connect("load_file_clicked", self, "open_load_dialog")
    Events.connect("move_doors_notes", self, "_move_doors_notes")
    Events.emit_signal("start_autotracking")

    set_window_size()

    load_data(zelgawoods)

func _notification(what: int) -> void:
    if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
        $GUILayer/FileDialog.hide()
        $GUILayer/FileDialog/Dialog.hide()
        $GUILayer/Quit.show()
        $GUILayer/Quit/Confirmation.popup()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("save"):
        open_save_dialog()
    elif event.is_action_pressed("load"):
        open_load_dialog()

func _on_confirmed() -> void:
    save_window_size()
    get_tree().quit()

func _on_cancelled() -> void:
    $GUILayer/Quit.hide()
    $GUILayer/FileDialog.hide()

func open_save_dialog() -> void:
    $GUILayer/FileDialog.show()
    $GUILayer/FileDialog/Dialog.mode = FileDialog.MODE_SAVE_FILE
    var date = OS.get_datetime()
    $GUILayer/FileDialog/Dialog.current_path = OS.get_executable_path()
    $GUILayer/FileDialog/Dialog.current_file = "%d-%d-%d.json" % [date.year, date.month, date.day]
    $GUILayer/FileDialog/Dialog.popup()

func open_load_dialog() -> void:
    $GUILayer/FileDialog.show()
    $GUILayer/FileDialog/Dialog.mode = FileDialog.MODE_OPEN_FILE
    $GUILayer/FileDialog/Dialog.current_path = OS.get_executable_path()
    $GUILayer/FileDialog/Dialog.current_file = ""
    $GUILayer/FileDialog/Dialog.popup()

func _on_file_selected(path: String) -> void:
    match($GUILayer/FileDialog/Dialog.mode):
        FileDialog.MODE_SAVE_FILE:
            save_data(path)
        FileDialog.MODE_OPEN_FILE:
            if load_data(path):
                Events.emit_signal("tracker_restarted")

func save_data(path: String) -> bool:
    var data = {
        "light_world": $LightWorld.save_data(),
        "dark_world": $DarkWorld.save_data(),
        "markers": markers.save_data(),
        #"notes": $GUILayer/GUI.save_data()
        "notes": $NotesWindow.save_data()
    }
    var save_file = File.new()
    if save_file.open(path, File.WRITE) != OK:
        return false
    save_file.store_string(to_json(data))
    save_file.close()
    return true

func load_data(path: String) -> bool:
    var save_file = File.new()
    if !save_file.file_exists(path):
        return false
    if save_file.open(path, File.READ) != OK:
        return false
    var data = parse_json(save_file.get_as_text())
    $LightWorld.load_data(data.light_world)
    $DarkWorld.load_data(data.dark_world)
    markers.load_data(data.markers)
    if "notes" in data and data.notes is Array:
        $NotesWindow.load_data(data.notes)
    save_file.close()
    return true

func generate_marker(texture: Texture, color: Color, connector: String) -> void:
    if Util.mode != Util.MODE_OW:
        return

    if is_instance_valid(Util.last_marker) and Util.last_marker.is_following:
        Util.last_marker.queue_free()

    var marker = marker_scene.instance()
    marker.modulate = color
    if connector != "":
        marker.add_to_group(connector)
        marker.connector = connector
        marker.is_connector = true
    Util.last_marker = marker
    markers.add_child(marker)
    marker.set_sprite(texture)
    $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.grab_focus()

func set_window_size() -> void:
    var save_file = File.new()
    var path = OS.get_executable_path().trim_suffix(".exe") + "_Settings.ini"
    if !save_file.file_exists(path) or save_file.open(path, File.READ) != OK:
        return
    var data = parse_json(save_file.get_as_text())
    
    if data.size() > 2:
        get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, str2var("Vector2" + data.viewport))
        $"/root".get_viewport().set_size(str2var("Vector2" + data.viewport))
        if $"/root".get_viewport().size.x < 500:
            $NotesWindow/NotesMargin/VBoxContainer/HBoxContainer/Expand.visible = true
            $GUILayer/GUI/PopupMenu.add_item("Move doors notes to the other side", 14)
        if data.notes == "left":
            Events.emit_signal("move_doors_notes")
        if $"/root".get_viewport().size.x > 1600:
            $GUILayer/GUI/PopupMenu.add_item("Move doors notes to the other side", 14)
    OS.window_size = str2var("Vector2" + data.size)
    OS.window_position = str2var("Vector2" + data.screen)
  
func save_window_size() -> void:
    var notes_side = "right"

    if $NotesWindow.rect_position.x > 1000:
        notes_side = "right"
    else:
        notes_side = "left"
    var data = {    
        "size": OS.window_size,
        "screen": OS.window_position,
        "viewport": $"/root".get_viewport().size,
        "notes": notes_side
    }
    var path = OS.get_executable_path().trim_suffix(".exe") + "_Settings.ini"
    var save_file = File.new()
    if save_file.open(path, File.WRITE) != OK:
        return
    save_file.store_string(to_json(data))
    save_file.close()

func _move_doors_notes() -> void:
    if $NotesWindow.rect_position.x > 1000:
        #move left
        OS.window_position = Vector2(OS.window_position.x - (OS.window_size.x * (350.0/1850.0)), OS.window_position.y)
        $GUILayer/GUI.rect_position = Vector2(350, 0)
        $LightWorld.position = Vector2(350, 0) 
        $DarkWorld.position = Vector2(1100, 0)
        $NotesWindow.rect_position = Vector2(0, 0)
        if $"/root/Tracker/Markers":
            for i in $"/root/Tracker/Markers".get_child_count():
                $"/root/Tracker/Markers".get_child(i).move_local_x(350)
        for i in $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child_count():
            if $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i) is TextureButton:
                $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i).rect_position = Vector2($NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i).rect_position.x - 1500, $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i).rect_position.y)
    else:
        #move right
        OS.window_position = Vector2(OS.window_position.x + (OS.window_size.x * (350.0/1850.0)), OS.window_position.y)
        $GUILayer/GUI.rect_position = Vector2(0, 0)
        $LightWorld.position = Vector2(0, 0) 
        $DarkWorld.position = Vector2(750, 0)
        $NotesWindow.rect_position = Vector2(1500, 0)
        if $"/root/Tracker/Markers":
            for i in $"/root/Tracker/Markers".get_child_count():
                $"/root/Tracker/Markers".get_child(i).move_local_x(-350)
        for i in $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child_count():
            if $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i) is TextureButton:
                $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i).rect_position = Vector2($NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i).rect_position.x + 1500, $NotesWindow/NotesMargin/VBoxContainer/NotesEdit.get_child(i).rect_position.y)
