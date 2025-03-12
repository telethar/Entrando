extends MarginContainer

var text: String
var current_checks: int setget set_current_checks
var current_keys: int setget set_current_keys
var isSelected : bool
var show_vitals = false
var keys_saved = 0
var keys_needed = 0
var current_vitals = 0
var total_vitals = 0
export var total_checks: int setget set_total_checks
export var total_keys: int setget set_total_keys
export var icon: Texture
export var locked_total_checks: bool
export var color: Color

onready var label = $Label
onready var key_label = $KeyLabel

func _ready() -> void:
    total_keys = -1
    update_label()
    update_key_label()
    $Texture.texture = icon
    $Texture.modulate = color

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
        and event.is_pressed():
        match(event.button_index):
            BUTTON_LEFT:
                Events.emit_signal("dungeon_clicked", self)
            BUTTON_RIGHT:
                if show_vitals:
                    current_vitals += 1
                    if current_vitals > total_vitals:
                        current_vitals = total_vitals
                    set_current_vitals(current_vitals)
                else:
                    current_checks += 1
                    if current_checks > total_checks:
                        current_checks = total_checks
                    set_current_checks(current_checks)
            BUTTON_WHEEL_UP:
                if show_vitals:
                    set_total_vitals(total_vitals + 1)
                else:
                    set_total_checks(total_checks + 1)
            BUTTON_WHEEL_DOWN:
                if show_vitals:
                    if total_vitals > 0:
                        set_total_vitals(total_vitals - 1)
                        if current_vitals > total_vitals:
                            current_vitals = total_vitals
                            set_current_vitals(current_vitals)
                else:
                    if total_checks > 0:
                        set_total_checks(total_checks - 1)
                        if current_checks > total_checks:
                            current_checks = total_checks
                            set_current_checks(current_checks)
    

func save_data() -> Dictionary:
    var data = {
        "current_checks": current_checks,
        "total_checks": total_checks,
        "notes": text,
        "paths": []
    }

    return data

func load_data(data: Dictionary) -> void:
    current_checks = data.current_checks
    total_checks = data.total_checks
    update_label()
    
func selected(_isSelected: bool) -> void:
    isSelected = _isSelected
    $ReferenceRect.visible = isSelected
    
    
func update_label() -> void:
    if show_vitals:
        label.text = "%d/%d" % [current_vitals, total_vitals]
        label.modulate = Color.cyan
    else:
        label.text = "%d/%d" % [current_checks, total_checks]
        label.modulate = Color.white
    if current_checks == total_checks or (show_vitals and current_vitals >= total_vitals):
        $ColorRect.color = Color("b0c23d19") #red
        $ColorRect.visible = true
    else:
        $ColorRect.visible = false
    $"/root/Tracker/NotesWindow/NotesMargin/VBoxContainer/NotesEdit".grab_focus()
        
func update_key_label() -> void:
    if total_keys == -1:
        key_label.text = "%d" % [current_keys]
    else:
        key_label.text = "%d\n%d" % [current_keys, max((total_keys - keys_saved), 0)]
    if current_keys >= total_keys - keys_saved and total_keys > -1:
        key_label.modulate = Color("008000") #green
    elif current_keys < keys_needed:
        key_label.modulate = Color.red
    else:
        key_label.modulate = Color("f8d038") #yellow

func set_current_checks(value: int) -> void:
    current_checks = value
    if label:
        update_label()

func set_total_checks(value: int) -> void:
    if !locked_total_checks:
        total_checks = value
    if label:
        update_label()
        
func set_current_vitals(value: int) -> void:
    current_vitals = value
    if label:
        update_label()
    if isSelected:
        Events.emit_signal("current_vitals_changed", current_vitals)

func set_total_vitals(value: int) -> void:
    total_vitals = value
    if label:
        update_label()
    if isSelected:
        Events.emit_signal("total_vitals_changed", total_vitals)
        
func set_current_keys(value: int) -> void:
    current_keys = value
    if key_label:
        update_key_label()

func set_total_keys(value: int) -> void:
    total_keys = value
    if key_label:
        update_key_label()

func _current_checks_changed(value: int) -> void:
    current_checks = value
    if current_checks > total_checks:
        current_checks = total_checks        
    if label:
        update_label()


func _total_checks_changed(value: int) -> void:
    total_checks = value
    if label:
        update_label()
        
func _current_vitals_changed(value: int) -> void:
    current_vitals = value
    if show_vitals:
        update_label()
        
func _total_vitals_changed(value: int) -> void:
    total_vitals = value
    if show_vitals:
        update_label()
        
func _saved_keys_changed(value: int) -> void:
    keys_saved = value
    if total_keys > -1:
        update_key_label()
        
func _needed_keys_changed(value: int) -> void:
    keys_needed = value
    update_key_label()

func _vitals_checkbox_toggled(value: bool) -> void:
    show_vitals = value
    update_label()
