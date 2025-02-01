extends HSplitContainer


var text: String setget set_notes_text, get_notes_text

var old_line_count = 0

onready var cross_texture
onready var cross_hover
onready var current_label = $NotesMargin/VBoxContainer/Current/Label
onready var current_slider = $NotesMargin/VBoxContainer/Current/Slider
onready var total_label = $NotesMargin/VBoxContainer/Total/Label
onready var total_slider = $NotesMargin/VBoxContainer/Total/Slider
onready var expand_button = $NotesMargin/VBoxContainer/HBoxContainer/Expand
onready var clear_button = $NotesMargin/VBoxContainer/ChecksContainer/ClearButton
onready var selectedDungeon = $NotesMargin/VBoxContainer/Dungeons/LWDungeons/HC
onready var notes = $NotesMargin/VBoxContainer/NotesEdit

func _ready() -> void:
    Events.connect("dungeon_clicked", self, "_on_dungeon_clicked")
    Events.connect("total_checks_changed", self, "_selected_total_changed")
    Events.connect("current_checks_changed", self, "_selected_current_changed")
    current_slider.connect("value_changed", self, "_current_checks_changed")
    total_slider.connect("value_changed", self, "_total_checks_changed")
    expand_button.connect("button_down", self, "_expand_window")
    clear_button.connect("button_down", self, "_clear_notes")
    notes.connect("text_changed", self, "_on_text_changed")
    
    
    cross_texture = load("res://assets/icons/cross.png")
    cross_hover = load("res://assets/icons/cross_hover.png")
    
    _on_dungeon_clicked(selectedDungeon)


func _on_dungeon_clicked(dungeon: Node) -> void:
    selectedDungeon.selected(false)
    selectedDungeon.text = get_notes_text()
    current_slider.disconnect("value_changed", selectedDungeon, "_current_checks_changed")
    total_slider.disconnect("value_changed", selectedDungeon, "_total_checks_changed")
    selectedDungeon = dungeon
    set_notes_text(selectedDungeon.text)
    selectedDungeon.selected(true)
    current_slider.value = selectedDungeon.current_checks
    current_slider.connect("value_changed", selectedDungeon, "_current_checks_changed")
    total_slider.value = selectedDungeon.total_checks
    total_slider.connect("value_changed", selectedDungeon, "_total_checks_changed")
    total_label.text = "%d" % total_slider.value
    current_label.text = "%d" % min(current_slider.value, total_slider.value)

func _current_checks_changed(_value: int) -> void:
    current_label.text = "%d" % min(current_slider.value, total_slider.value)
    current_slider.value = min(current_slider.value, total_slider.value)

func _total_checks_changed(_value: int) -> void:
    total_label.text = "%d" % total_slider.value
    current_slider.value = min(current_slider.value, total_slider.value)
    
func _selected_total_changed(_value: int) -> void:
    total_slider.value = _value
    
func _selected_current_changed(_value: int) -> void:
    current_slider.value = _value

func set_notes_text(value: String) -> void:
    $"NotesMargin/VBoxContainer/NotesEdit".text = value
    $"NotesMargin/VBoxContainer/NotesEdit".cursor_set_line($"NotesMargin/VBoxContainer/NotesEdit".get_line_count())
    $"NotesMargin/VBoxContainer/NotesEdit".cursor_set_column($"NotesMargin/VBoxContainer/NotesEdit".get_line($"NotesMargin/VBoxContainer/NotesEdit".cursor_get_line()).length())
    
func get_notes_text() -> String:
    return $"NotesMargin/VBoxContainer/NotesEdit".text
    
func _expand_window() -> void:
    OS.window_size = Vector2(OS.window_size.x * (1850.0/350.0), OS.window_size.y)
    get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, Vector2(1850, 950))
    $"/root".get_viewport().set_size(Vector2(1850, 950))
    expand_button.visible = false

func _clear_notes() -> void:
    $"NotesMargin/VBoxContainer/NotesEdit".text = ""
    
func _on_text_changed() -> void:
    print(old_line_count, " ", notes.get_line_count())
    if old_line_count < notes.get_line_count():
        var cross_button = TextureButton.new()
        cross_button.set_normal_texture(cross_texture)
        cross_button.set_hover_texture(cross_hover)
        cross_button.set_as_toplevel(true)
        cross_button.rect_position = Vector2(clear_button.rect_global_position.x, notes.get_pos_at_line_column(notes.get_line_count()-1, 0).y)
        notes.add_child(cross_button)
        cross_button.connect("button_down", self, "_on_delete_line")
    
    if old_line_count > notes.get_line_count():
        var count = 0
        for i in notes.get_child_count():
            if notes.get_child(i) is TextureButton:
                print("button found")
                count = count + 1
            if count > notes.get_line_count():
                print("freeing")
                notes.get_child(i).queue_free()
            
    
    old_line_count = notes.get_line_count()

func _on_delete_line() -> void:
    var line = notes.get_line_column_at_pos(get_viewport().get_mouse_position() - Vector2(0, notes.get_line_height())).y
    print(line)
    notes.set_line(line, "")
    notes.cursor_set_line(line)
    notes.grab_focus()
