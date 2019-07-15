extends KinematicBody

export var Sensitivity_X = 0.1
export var Sensitivity_Y = 0.1
export var Zoom_Step = 0.5
export var Acceleration_Start = 10
export var Acceleration_Stop = 25
export var Max_Speed = 250
export var Rotate_Model_Step = PI * 4

const MIN_ROT_Y = -89
const MAX_ROT_Y = 45
const ZOOM_MIN = 2
const ZOOM_MAX = 10
const GRAVITY = 9.8

onready var rotate_node = $SpringArm
onready var model_node = $CSG_Model

var mouse_relative = Vector2()
var move_offset = Vector2()
var move_forward = 0
var move_right = 0
var velocity = Vector3()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		mouse_relative += event.relative
	elif event.is_action_pressed("camera_zoom_in"):
		zoom_camera(1)
	elif event.is_action_pressed("camera_zoom_out"):
		zoom_camera(-1)
	
	if event.is_action_pressed("move_forward"):
		move_offset.x -= 1
	elif event.is_action_pressed("move_backward"):
		move_offset.x += 1
	elif event.is_action_pressed("move_right"):
		move_offset.y += 1
	elif event.is_action_pressed("move_left"):
		move_offset.y -= 1
	
	if event.is_action_released("move_forward"):
		move_offset.x += 1
	elif event.is_action_released("move_backward"):
		move_offset.x -= 1
	elif event.is_action_released("move_right"):
		move_offset.y -= 1
	elif event.is_action_released("move_left"):
		move_offset.y += 1

func _physics_process(delta):
	if mouse_relative != Vector2.ZERO:
		rotate_camera(Vector2(mouse_relative.y * delta * Sensitivity_X, mouse_relative.x * delta * Sensitivity_Y))
		mouse_relative = Vector2()

	if move_offset != Vector2.ZERO or move_forward != 0 or move_right != 0 or !is_on_floor():
		move(delta)

func rotate_camera(offset):
	rotate_node.rotation.y -= offset.y
	
	if rotate_node.rotation.y > PI:
		rotate_node.rotation.y -= PI*2
	elif rotate_node.rotation.y < -PI:
		rotate_node.rotation.y += PI*2
	
	if offset.x <= 0 and rotate_node.rotation_degrees.x >= MAX_ROT_Y:
		return
	if offset.x >= 0 and rotate_node.rotation_degrees.x <= MIN_ROT_Y:
		return
	
	rotate_node.rotation.x -= offset.x

func zoom_camera(direction):
	
	if direction > 0 and rotate_node.spring_length <= ZOOM_MIN:
		rotate_node.spring_length = ZOOM_MIN
	elif direction < 0 and rotate_node.spring_length >= ZOOM_MAX:
		rotate_node.spring_length = ZOOM_MAX
	else:
		rotate_node.spring_length -= direction * Zoom_Step

func move(delta):
	
	if move_forward == 0 and move_right == 0:
		if rotate_model(delta):
			return
		
	
	if move_offset.x < 0:
		move_forward = max(move_forward - Acceleration_Start, -Max_Speed)
	elif move_offset.x > 0:
		move_forward = min(move_forward + Acceleration_Start, Max_Speed)
	elif move_forward > 0:
		move_forward = max(move_forward - Acceleration_Stop, 0)
	elif move_forward < 0:
		move_forward = min(move_forward + Acceleration_Stop, 0)
		
	if move_offset.y < 0:
		move_right = max(move_right - Acceleration_Start, -Max_Speed)
	elif move_offset.y > 0:
		move_right = min(move_right + Acceleration_Start, Max_Speed)
	elif move_right > 0:
		move_right = max(move_right - Acceleration_Stop, 0)
	elif move_right < 0:
		move_right = min(move_right + Acceleration_Stop, 0)
		
	var direction = Vector3()
	direction.x = move_right * delta
	direction.z = move_forward * delta
	direction = direction.rotated(Vector3(0, 1, 0), rotate_node.rotation.y)
	
	velocity.x = direction.x
	velocity.z = direction.z
	velocity.y -= GRAVITY * delta
	velocity = move_and_slide(velocity, Vector3(0, 1, 0))
	
	if move_offset != Vector2.ZERO:
		rotate_model(delta)

func rotate_model(delta):
	var target_rotation_y = rotate_node.rotation.y
	
	if move_offset.x > 0 and move_offset.y == 0:
		target_rotation_y -= PI
	elif move_offset.x == 0 and move_offset.y > 0:
		target_rotation_y -= PI / 2
	elif move_offset.x == 0 and move_offset.y < 0:
		target_rotation_y += PI / 2
	
	elif move_offset.x > 0 and move_offset.y > 0:
		target_rotation_y -= PI - PI / 4
	elif move_offset.x > 0 and move_offset.y < 0:
		target_rotation_y -= PI + PI / 4
	elif move_offset.x < 0 and move_offset.y < 0:
		target_rotation_y += PI / 4
	elif move_offset.x < 0 and move_offset.y > 0:
		target_rotation_y -= PI / 4
	
	if abs(model_node.rotation.y - target_rotation_y) > PI:
		if model_node.rotation.y - target_rotation_y > 0:
			model_node.rotation.y -= PI * 2
		else:
			model_node.rotation.y += PI * 2
	
	if abs(model_node.rotation.y - target_rotation_y) < 0.01:
		return false
	
	if model_node.rotation.y > target_rotation_y:
		model_node.rotation.y = max(model_node.rotation.y - delta * Rotate_Model_Step, target_rotation_y)
	else:
		model_node.rotation.y = min(model_node.rotation.y + delta * Rotate_Model_Step, target_rotation_y)
	
	return true








