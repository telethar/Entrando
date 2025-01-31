extends HSplitContainer


var text: String setget set_notes_text, get_notes_text

onready var current_label = $NotesMargin/VBoxContainer/Current/Label
onready var current_slider = $NotesMargin/VBoxContainer/Current/Slider
onready var total_label = $NotesMargin/VBoxContainer/Total/Label
onready var total_slider = $NotesMargin/VBoxContainer/Total/Slider
onready var expand_button = $NotesMargin/VBoxContainer/HBoxContainer/Expand
onready var selectedDungeon = $NotesMargin/VBoxContainer/Dungeons/LWDungeons/HC

func _ready() -> void:
    Events.connect("dungeon_clicked", self, "_on_dungeon_clicked")
    Events.connect("total_checks_changed", self, "_selected_total_changed")
    Events.connect("current_checks_changed", self, "_selected_current_changed")
    current_slider.connect("value_changed", self, "_current_checks_changed")
    total_slider.connect("value_changed", self, "_total_checks_changed")
    expand_button.connect("button_down", self, "_expand_window")
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

func get_notes_text() -> String:
    return $"NotesMargin/VBoxContainer/NotesEdit".text
    
func _expand_window() -> void:
    OS.window_size = Vector2(OS.window_size.x * (1850.0/350.0), OS.window_size.y)
    get_tree().set_screen_stretch(get_tree().STRETCH_MODE_VIEWPORT, get_tree().STRETCH_ASPECT_KEEP, Vector2(1850, 950))
    $"/root".get_viewport().set_size(Vector2(1850, 950))
    expand_button.visible = false
