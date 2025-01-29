extends MarginContainer

var text: String
var current_checks: int setget set_current_checks
var isSelected : bool
export var total_checks: int setget set_total_checks
export var icon: Texture
export var locked_total_checks: bool
export var color: Color

onready var label = $Label

func _ready() -> void:
	update_label()
	#add_to_group(Util.GROUP_NOTES)
	$Texture.texture = icon
	$Texture.modulate = color
	#$label.modulate = color

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.is_pressed():
		match(event.button_index):
			BUTTON_LEFT:
				Events.emit_signal("dungeon_clicked", self)
			BUTTON_RIGHT:
				current_checks += 1
				if current_checks > total_checks:
					current_checks = total_checks
				set_current_checks(current_checks)
			BUTTON_WHEEL_UP:
				set_total_checks(total_checks + 1)
			BUTTON_WHEEL_DOWN:
				if total_checks > 1:
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
	#notes_tab.current_slider.value = current_checks
	total_checks = data.total_checks
	#notes_tab.total_slider.value = total_checks
	#notes_tab.text = data.notes
	update_label()
	
func selected(_isSelected: bool) -> void:
	isSelected = _isSelected
	$ColorRect.visible = isSelected
	if current_checks == total_checks:
		$ColorRect.color = Color("b0c23d19") #red
		$ColorRect.visible = true
	if isSelected:
		$ColorRect.color = Color("b064e60c") #green
		$ColorRect.visible = true
	
	
func update_label() -> void:
	label.text = "%d/%d" % [current_checks, total_checks]
	if current_checks == total_checks and not isSelected:
		$ColorRect.color = Color("b0c23d19")
		$ColorRect.visible = true
	elif not isSelected:
		$ColorRect.visible = false

func set_current_checks(value: int) -> void:
	current_checks = value
	if label:
		update_label()
	if isSelected:
		Events.emit_signal("current_checks_changed", current_checks)

func set_total_checks(value: int) -> void:
	if !locked_total_checks:
		total_checks = value
	if label:
		update_label()
	if isSelected:
		Events.emit_signal("total_checks_changed", total_checks)

func _current_checks_changed(value: int) -> void:
	current_checks = value
	if current_checks > total_checks:
		current_checks = total_checks
		
	if label:
		update_label()


func _total_checks_changed(value: int) -> void:
	total_checks = value
	#notes_tab.total_slider.value = total_checks
	if label:
		update_label()
