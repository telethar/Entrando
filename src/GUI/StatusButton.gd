extends TextureButton

const DISABLED_TEXTURE = preload("res://assets/icons/disabled.png");
const TODO_TEXTURE = preload("res://assets/icons/todo.png");
const BLANK_TEXTURE = preload("res://assets/icons/blankTexture.png");

const CHECKED_GREY = Color("282626")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    connect("mouse_entered", self, "_on_mouse_entered")
    connect("mouse_exited", self, "_on_mouse_exited")

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton \
        and event.is_pressed():
        match(event.button_index):
            BUTTON_RIGHT:              
                set_pressed_texture(BLANK_TEXTURE);
                if get_parent().self_modulate == CHECKED_GREY:
                    get_parent().self_modulate = Color.white
                else:
                    get_parent().self_modulate = CHECKED_GREY
            BUTTON_MIDDLE:
                if (get_pressed_texture() != TODO_TEXTURE):
                    set_pressed_texture(TODO_TEXTURE);
                    set_pressed(false);
            BUTTON_LEFT:
                self.get_parent()._on_pressed();

func _on_mouse_entered() -> void:
    self.get_parent()._on_mouse_entered();

func _on_mouse_exited() -> void:
    self.get_parent()._on_mouse_exited();

