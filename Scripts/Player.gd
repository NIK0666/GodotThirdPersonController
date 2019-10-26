extends KinematicBody

export var Sensitivity_X: float = 0.1
export var Sensitivity_Y: float = 0.1
export var Zoom_Step: float = 0.5
export var Jump_Speed: float = 12.0
export var Acceleration_Start: float = 10
export var Acceleration_Stop: float = 25
export var Walk_Max_Speed: float = 200
export var Sprint_Max_Speed: float = 400
export var Rotate_Model_Step: float = PI * 2.0

const GRAVITY = 9.8 * 4
enum ROTATE_TURN {none, left, right}


onready var rotate_node: Spatial = $SpringArm
onready var model_node: Spatial = $Hero_Model
onready var state_machine: AnimationTree = get_node("AnimationTree")

var mouse_relative: Vector2 = Vector2()
var move_offset: Vector2 = Vector2()
var move_forward: float = 0
var move_right: float = 0
var velocity: Vector3 = Vector3()
var max_speed: float = Walk_Max_Speed
var is_sprint: bool = false
var rotate_turn = ROTATE_TURN.none
var jumping: bool = false setget _set_jumping

func _ready():
	_setup_spring_arm()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_spring_arm():
	rotate_node.zoom_step = Zoom_Step
	rotate_node.sens_x = Sensitivity_X
	rotate_node.sens_y = Sensitivity_Y

func _input(event):
	
	if event.is_action_pressed("jump") and is_on_floor():
		self.jumping = true
	
	if event.is_action_pressed("move_sprint"):
		is_sprint = true
	elif event.is_action_released("move_sprint"):
		is_sprint = false
	
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
	if move_offset != Vector2.ZERO or move_forward != 0 or move_right != 0 or jumping or !is_on_floor():
		move(delta)
	
	state_machine.set("parameters/conditions/is_floor", is_on_floor())
	state_machine.set("parameters/conditions/is_not_floor", !is_on_floor())
	
	if is_sprint:
		if max_speed < Sprint_Max_Speed:
			max_speed = min(max_speed + Acceleration_Start, Sprint_Max_Speed)
	else:
		if max_speed > Walk_Max_Speed:
			max_speed = max(max_speed - Acceleration_Start, Walk_Max_Speed)

func _set_jumping(_jumping: bool):
	jumping = _jumping
	state_machine.set("parameters/conditions/is_jump", _jumping)

func move(delta):
	
	if move_forward == 0 and move_right == 0:
		if rotate_model(delta):
			state_machine.set("parameters/conditions/end_right_turn", false)
			state_machine.set("parameters/conditions/end_left_turn", false)
			if rotate_turn == ROTATE_TURN.left:
				state_machine.set("parameters/conditions/left_turn", true)
				state_machine.set("parameters/conditions/right_turn", false)
			elif rotate_turn == ROTATE_TURN.right:
				state_machine.set("parameters/conditions/right_turn", true)
				state_machine.set("parameters/conditions/left_turn", false)
			return
	
	state_machine.set("parameters/conditions/right_turn", false)
	state_machine.set("parameters/conditions/left_turn", false)
	state_machine.set("parameters/conditions/end_right_turn", true)
	state_machine.set("parameters/conditions/end_left_turn", true)
	
	if is_on_floor():
		var normalized_offset: Vector2 = move_offset.normalized()
		if move_offset.x < 0:
			move_forward = max(move_forward - Acceleration_Start, max_speed * normalized_offset.x)
		elif move_offset.x > 0:
			move_forward = min(move_forward + Acceleration_Start, max_speed  * normalized_offset.x)
		elif move_forward > 0:
			move_forward = max(move_forward - Acceleration_Stop, 0)
		elif move_forward < 0:
			move_forward = min(move_forward + Acceleration_Stop, 0)
			
		if move_offset.y < 0:
			move_right = max(move_right - Acceleration_Start, max_speed * normalized_offset.y)
		elif move_offset.y > 0:
			move_right = min(move_right + Acceleration_Start, max_speed * normalized_offset.y)
		elif move_right > 0:
			move_right = max(move_right - Acceleration_Stop, 0)
		elif move_right < 0:
			move_right = min(move_right + Acceleration_Stop, 0)
		
	var direction: Vector3 = Vector3()
	direction.x = move_right * delta
	direction.z = move_forward * delta
	
	direction = direction.rotated(Vector3(0, 1, 0), rotate_node.rotation.y)
	
	velocity.x = direction.x
	velocity.z = direction.z
	velocity.y -= GRAVITY * delta
	if jumping and is_on_floor():
		velocity.y += Jump_Speed
		self.jumping = false
	
	velocity = move_and_slide(velocity, Vector3(0, 1, 0))
	state_machine.set("parameters/Moving/blend_position", Vector2(move_right, move_forward).length())

	if move_offset != Vector2.ZERO:
		rotate_model(delta)

func rotate_model(delta):
	
	if jumping or !is_on_floor():
		return
	
	var target_rotation_y = rotate_node.rotation.y + PI
	
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
		rotate_turn = ROTATE_TURN.right
	else:
		model_node.rotation.y = min(model_node.rotation.y + delta * Rotate_Model_Step, target_rotation_y)
		rotate_turn = ROTATE_TURN.left
		
	
	return true






