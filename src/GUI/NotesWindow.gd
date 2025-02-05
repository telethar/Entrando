extends HSplitContainer


var text: String setget set_notes_text, get_notes_text

var old_line_count = 0

onready var cross_texture
onready var cross_hover
onready var keys_saved_label = $NotesMargin/VBoxContainer/Current/KeysSavedLabel
onready var keys_saved_slider = $NotesMargin/VBoxContainer/Current/KeysSavedSlider
onready var keys_needed_label = $NotesMargin/VBoxContainer/Total/KeysNeededLabel
onready var keys_needed_slider = $NotesMargin/VBoxContainer/Total/KeysNeededSlider
onready var vitals_current_label = $NotesMargin/VBoxContainer/Current/VitalsCurrentLabel
onready var vitals_current_slider = $NotesMargin/VBoxContainer/Current/VitalsCurrentSlider
onready var vitals_total_label = $NotesMargin/VBoxContainer/Total/VitalsTotalLabel
onready var vitals_total_slider = $NotesMargin/VBoxContainer/Total/VitalsTotalSlider
onready var vitals_checkbox = $NotesMargin/VBoxContainer/ChecksContainer/VitalsCheckBox
onready var expand_button = $NotesMargin/VBoxContainer/HBoxContainer/Expand
onready var clear_button = $NotesMargin/VBoxContainer/ChecksContainer/ClearButton
onready var selectedDungeon = $NotesMargin/VBoxContainer/Dungeons/LWDungeons/HC
onready var notes = $NotesMargin/VBoxContainer/NotesEdit
onready var timer = Timer.new() #timer to update position of x buttons properly when clicking on a dungeon (TextEdit is bad and needs this)

func _ready() -> void:
    Events.connect("dungeon_clicked", self, "_on_dungeon_clicked")
    Events.connect("current_vitals_changed", self, "_current_vitals_changed")
    Events.connect("total_vitals_changed", self, "_total_vitals_changed")
    keys_saved_slider.connect("value_changed", self, "_saved_keys_changed")
    keys_needed_slider.connect("value_changed", self, "_needed_keys_changed")
    vitals_current_slider.connect("value_changed", self, "_current_vitals_changed")
    vitals_total_slider.connect("value_changed", self, "_total_vitals_changed")
    keys_saved_slider.connect("value_changed", selectedDungeon, "_saved_keys_changed")
    keys_needed_slider.connect("value_changed", selectedDungeon, "_needed_keys_changed")
    vitals_current_slider.connect("value_changed", selectedDungeon, "_current_vitals_changed")
    vitals_total_slider.connect("value_changed", selectedDungeon, "_total_vitals_changed")
    vitals_checkbox.connect("toggled", selectedDungeon, "_vitals_checkbox_toggled")
    expand_button.connect("button_down", self, "_expand_window")
    clear_button.connect("button_down", self, "_clear_notes")
    notes.connect("text_changed", self, "_on_text_changed")
    
    
    cross_texture = load("res://assets/icons/cross.png")
    cross_hover = load("res://assets/icons/cross_hover.png")
    
    self.add_child(timer)
    timer.wait_time = 0.005
    timer.one_shot = true
    timer.connect("timeout", self, "_on_timer_timeout")
    _on_dungeon_clicked(selectedDungeon)


func _on_dungeon_clicked(dungeon: Node) -> void:
    selectedDungeon.selected(false)
    selectedDungeon.text = get_notes_text()
    keys_saved_slider.disconnect("value_changed", selectedDungeon, "_saved_keys_changed")
    keys_needed_slider.disconnect("value_changed", selectedDungeon, "_needed_keys_changed")
    vitals_current_slider.disconnect("value_changed", selectedDungeon, "_current_vitals_changed")
    vitals_total_slider.disconnect("value_changed", selectedDungeon, "_total_vitals_changed")
    vitals_checkbox.disconnect("toggled", selectedDungeon, "_vitals_checkbox_toggled")
    selectedDungeon = dungeon
    set_notes_text(selectedDungeon.text)
    selectedDungeon.selected(true)
    keys_saved_slider.value = selectedDungeon.keys_saved
    keys_saved_slider.connect("value_changed", selectedDungeon, "_saved_keys_changed")
    keys_needed_slider.value = selectedDungeon.keys_needed
    keys_needed_slider.connect("value_changed", selectedDungeon, "_needed_keys_changed")
    vitals_current_slider.value = selectedDungeon.current_vitals
    vitals_current_slider.connect("value_changed", selectedDungeon, "_current_vitals_changed")
    vitals_total_slider.value = selectedDungeon.total_vitals
    vitals_total_slider.connect("value_changed", selectedDungeon, "_total_vitals_changed")
    vitals_checkbox.pressed = selectedDungeon.show_vitals
    vitals_checkbox.connect("toggled", selectedDungeon, "_vitals_checkbox_toggled")
    keys_saved_label.text = "%d" % keys_saved_slider.value
    keys_needed_label.text = "%d" % keys_needed_slider.value
    vitals_current_label.text = "%d" % vitals_current_slider.value
    vitals_total_label.text = "%d" % vitals_total_slider.value
    timer.start()

func _current_vitals_changed(_value: int) -> void:
    vitals_current_slider.value = _value
    vitals_current_label.text = "%d" % vitals_current_slider.value

func _total_vitals_changed(_value: int) -> void:
    vitals_total_slider.value = _value
    vitals_total_label.text = "%d" % vitals_total_slider.value
    
func _saved_keys_changed(_value: int) -> void:
    keys_saved_label.text = "%d" % keys_saved_slider.value
    
func _needed_keys_changed(_value: int) -> void:
    keys_needed_label.text = "%d" % keys_needed_slider.value

func set_notes_text(value: String) -> void:
    notes.text = value
    notes.cursor_set_line(notes.get_line_count())
    notes.cursor_set_column(notes.get_line(notes.cursor_get_line()).length())
    
func get_notes_text() -> String:
    return notes.text
    
func _expand_window() -> void:
    
    get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, Vector2(1850, 950))
    $"/root".get_viewport().set_size(Vector2(1850, 950))
    OS.window_size = Vector2(OS.window_size.x * (1850.0/350.0), OS.window_size.y)
    
    expand_button.visible = false
    notes.grab_focus()

func _clear_notes() -> void:
    notes.text = ""
    notes.grab_focus()
    _on_text_changed()
    
func _on_text_changed() -> void:
    # add x buttons
    if old_line_count < notes.get_line_count():
        for i in range(old_line_count, notes.get_line_count()):
            var cross_button = TextureButton.new()
            cross_button.set_normal_texture(cross_texture)
            cross_button.set_hover_texture(cross_hover)
            cross_button.set_as_toplevel(true)
            cross_button.rect_position = Vector2(clear_button.rect_global_position.x, notes.get_pos_at_line_column(i, 0).y)
            notes.add_child(cross_button)
            cross_button.connect("button_down", self, "_on_delete_line")
    
    # update x button positions
    var count = 0
    for i in notes.get_child_count():
        if notes.get_child(i) is TextureButton:
            count = count + 1
            if count > notes.get_line_count():
                notes.get_child(i).queue_free()
            else:
                notes.get_child(i).rect_position = Vector2(clear_button.rect_global_position.x, notes.get_pos_at_line_column(count-1, 0).y)
        
    old_line_count = notes.get_line_count()

func _on_delete_line() -> void:
    var line = notes.get_line_column_at_pos(get_viewport().get_mouse_position() - Vector2(0, notes.get_line_height())).y
    if line > 0:
        notes.set_line(line, "[delete this]")
        set_notes_text(notes.text.replace("\n[delete this]", ""))
    else:
        if notes.get_line_count() > 1:
            notes.set_line(line, "[delete this]")
            set_notes_text(notes.text.replace("[delete this]\n", ""))
        else:
            notes.set_line(line, "")
    notes.grab_focus()

func _on_timer_timeout() -> void:
    _on_text_changed()
