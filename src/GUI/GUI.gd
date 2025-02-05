extends Control

enum {
    MENU_RESET = 0,
    # 1 separator
    MENU_SAVE_FILE = 2,
    MENU_LOAD_FILE = 3,
    # 4 separator
    MENU_REMAINING_ENTRANCES = 5,
    MENU_DRAG_N_DROP = 6,
    MENU_OW_ITEMS = 7,
    # 8 separator
    MENU_START_AUTOTRACKING = 9,
    MENU_AUTOTRACKING_SETTINGS = 10,
    # 11 separator
    MENU_TOGGLE_DOORS_NOTES = 12,
    MENU_NOTES_ONLY = 13,
    MENU_MOVE_DOORS_NOTES = 14,
}

onready var menu = $PopupMenu
onready var autotrack_menu = $ATContainer/AutoTrackingSettings
onready var autotrack_menu_modal = $ATContainer/AutoTrackingSettings/Shadow
onready var autotrack_menu_container = $ATContainer/AutoTrackingSettings/Shadow/Container/BG
onready var tooltip = $TooltipPopup
onready var tooltip_container = $TooltipPopup/Margin/Container
onready var tooltip_timer = $TooltipPopup/Timer
onready var notes_modal = $Container/Notes/Shadow
onready var notes_container = $Container/Notes/Shadow/Container/BG
onready var undo_button = $Container/Margin/HSplitContainer/Entrances/Entrances/Settings/TextureButton

onready var autotracking_scene: PackedScene = preload("res://src/GUI/AutoTrackingSettings.tscn")

var last_hovered: MarginContainer

func _ready() -> void:
    Events.connect("notes_clicked", self, "open_notes")
    Events.connect("open_menu", self, "_open_menu")
    menu.connect("id_pressed", self, "menu_pressed")
    undo_button.connect("button_down", self, "_on_undo")

    menu.add_item("!!RESET!!", MENU_RESET)
    menu.add_separator()
    menu.add_item("Save", MENU_SAVE_FILE, KEY_S | KEY_MASK_CTRL)
    menu.add_item("Load", MENU_LOAD_FILE, KEY_O | KEY_MASK_CTRL)
    menu.add_separator()
    menu.add_check_item("Show Remaining Entrances", MENU_REMAINING_ENTRANCES)
    menu.add_check_item("Drag n' Drop Markers", MENU_DRAG_N_DROP)
    menu.add_item("Hide OW Item Markers", MENU_OW_ITEMS)
    menu.add_separator()
    menu.add_item("(Re)connect Auto-Tracking", MENU_START_AUTOTRACKING)
    menu.add_item("Auto-Tracking Settings", MENU_AUTOTRACKING_SETTINGS)
    menu.add_separator()
    menu.add_item("Toggle Doors Notes", MENU_TOGGLE_DOORS_NOTES)
    menu.add_item("Toggle Notes Only Mode", MENU_NOTES_ONLY)        

    tooltip_timer.connect("timeout", self, "_on_tooltip_timeout")
    
    for child in get_tree().get_nodes_in_group(Util.GROUP_NOTES):
        child.connect("mouse_entered", self, "_on_notes_entered", [child])
        child.connect("mouse_exited", self, "_on_notes_exited")

func save_data() -> Dictionary:
    var data = {}
    for child in get_tree().get_nodes_in_group(Util.GROUP_NOTES):
        data[child.name] = child.save_data()
    return data

func load_data(data: Dictionary) -> void:
    var nodes = {}
    for child in get_tree().get_nodes_in_group(Util.GROUP_NOTES):
        nodes[child.name] = child
    for id in data:
        nodes[id].load_data(data[id])

func open_notes(node: Node) -> void:
    for child in notes_container.get_children():
        notes_container.remove_child(child)
    notes_container.add_child(node)
    notes_modal.show()

func _open_menu() -> void:
    menu.popup()
    menu.rect_global_position = get_global_mouse_position() - menu.rect_size

func menu_pressed(id: int) -> void:
    if menu.is_item_checkable(id):
        menu.set_item_checked(id, !menu.is_item_checked(id))
    match(id):
        MENU_OW_ITEMS:
            get_tree().call_group(Util.GROUP_ITEMS, "queue_free")
        MENU_DRAG_N_DROP:
            Util.drag_and_drop = menu.is_item_checked(id)
        MENU_REMAINING_ENTRANCES:
            $"Container/Margin/NotesButtons/2/EntranceCounter".visible = menu.is_item_checked(id)
        MENU_SAVE_FILE:
            Events.emit_signal("save_file_clicked")
        MENU_LOAD_FILE:
            Events.emit_signal("load_file_clicked")
        MENU_RESET:
            $"/root/Tracker/GUILayer/GUI".rect_position = Vector2(0, 0)
            $"/root/Tracker/LightWorld".position = Vector2(0, 0) 
            $"/root/Tracker/DarkWorld".position = Vector2(750, 0)
            $"/root/Tracker/NotesWindow".rect_position = Vector2(1500, 0)
            get_tree().set_screen_stretch(get_tree().STRETCH_MODE_2D, get_tree().STRETCH_ASPECT_KEEP, Vector2(1500, 950))
            $"/root".get_viewport().set_size(Vector2(1500, 950))
            get_tree().reload_current_scene()
            Events.emit_signal("tracker_restarted")
        MENU_START_AUTOTRACKING:
            Events.emit_signal("start_autotracking")
        MENU_AUTOTRACKING_SETTINGS:
            autotrack_menu_modal.show()
        MENU_TOGGLE_DOORS_NOTES:
            #close notes
            if $"/root".get_viewport().size.x > 1600:
                if ($"/root/Tracker/NotesWindow".rect_position.x < 100):
                    Events.emit_signal("move_doors_notes")
                OS.window_size = Vector2(OS.window_size.x * (1500.0/1850.0), OS.window_size.y)
                get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, Vector2(1500, 950))
                $"/root".get_viewport().set_size(Vector2(1500, 950))
                menu.remove_item(MENU_MOVE_DOORS_NOTES)
            #open notes
            else:
                OS.window_size = Vector2(OS.window_size.x * (1850.0/1500.0), OS.window_size.y)
                get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, Vector2(1850, 950))
                $"/root".get_viewport().set_size(Vector2(1850, 950))
                menu.add_item("Move doors notes to the other side", MENU_MOVE_DOORS_NOTES)
        MENU_MOVE_DOORS_NOTES:
            Events.emit_signal("move_doors_notes")
        MENU_NOTES_ONLY:
            if $"/root".get_viewport().size.x < 1600:
                OS.window_size = Vector2(OS.window_size.x * (1850.0/1500.0), OS.window_size.y)
                get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, Vector2(1850, 950))
                $"/root".get_viewport().set_size(Vector2(1850, 950))
            if ($"/root/Tracker/NotesWindow".rect_position.x > 100):
                Events.emit_signal("move_doors_notes")
                if !menu.get_item_id(MENU_MOVE_DOORS_NOTES):
                    menu.add_item("Move doors notes to the other side", MENU_MOVE_DOORS_NOTES)
            OS.window_size = Vector2(OS.window_size.x * (350.0/$"/root".get_viewport().size.x), OS.window_size.y)
            get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, Vector2(350, 950))
            $"/root".get_viewport().set_size(Vector2(350, 950))
            $"/root/Tracker/NotesWindow/NotesMargin/VBoxContainer/HBoxContainer/Expand".visible = true

func _on_notes_entered(node: Node) -> void:
    if tooltip.visible:
        return
    last_hovered = node
    tooltip_timer.start()

func _on_tooltip_timeout() -> void:
    var items = last_hovered.notes_tab.item_container.get_children()
    if len(items) == 0:
        return
    for item in items:
        var sprite = TextureRect.new()
        sprite.texture = item.icons.get_child(0).texture
        tooltip_container.add_child(sprite)
        sprite.expand = true
        sprite.rect_min_size = Vector2(22, 22)
    tooltip.popup()
    tooltip.rect_size = Vector2.ZERO
    tooltip.rect_global_position = get_global_mouse_position() - tooltip.rect_size

func _on_notes_exited() -> void:
    tooltip_timer.stop()
    tooltip.hide()
    for child in tooltip_container.get_children():
        child.queue_free()

func _on_undo() -> void:
    Events.emit_signal("undo")
