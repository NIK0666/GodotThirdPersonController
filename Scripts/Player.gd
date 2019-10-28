extends KinematicBody

export var Sensitivity_X: float = 0.1
export var Sensitivity_Y: float = 0.1
export var Zoom_Step: float = 0.5
export var Jump_Speed: float = 15.0
export var Acceleration_Start: float = 0.2
export var Acceleration_Stop: float = 0.5
export var Walk_Max_Speed: float = 3.5
export var Sprint_Max_Speed: float = 8
export var Rotate_Model_Step: float = PI * 2.0

const GRAVITY = 9.8 * 5
enum RotateSide {NONE, LEFT, RIGHT}


onready var camera_node: Spatial = $SpringArm
onready var model_node: Spatial = $Hero_Model
onready var state_machine: AnimationTree = get_node("AnimationTree")

var mouse_relative: Vector2 = Vector2()
var move_offset: Vector2 = Vector2()
var normalized_offset: Vector2  = Vector2()
var move_forward: float = 0
var move_right: float = 0
var velocity: Vector3 = Vector3()
var max_speed: float = Walk_Max_Speed
var current_speed: float = 0.0
var is_sprint: bool = false
var rotate_side = RotateSide.NONE
var jumping: bool = false setget _set_jumping

func _ready():
	
	# Setup camera script defaults
	_setup_spring_arm() 
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_spring_arm():
	# Set init variables
	camera_node.zoom_step = Zoom_Step
	camera_node.sens_x = Sensitivity_X
	camera_node.sens_y = Sensitivity_Y

func _input(event):
	# Player actions processing
	if event.is_action_pressed("jump") and is_on_floor():
		self.jumping = true
	elif event.is_action_pressed("move_sprint"):
		is_sprint = true
	elif event.is_action_released("move_sprint"):
		is_sprint = false

func _process(delta):
	move_offset = Vector2(Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward"),
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))

func _physics_process(delta):
	
	var can_move: bool = true
	if move_forward == 0 and move_right == 0 and move_offset != Vector2.ZERO:
		var rot: int = rotate_model(delta)

		if rot == RotateSide.LEFT:
			state_machine.set("parameters/conditions/end_left_turn", false)
			state_machine.set("parameters/conditions/left_turn", true)
			can_move = false
		elif rot == RotateSide.RIGHT:
			state_machine.set("parameters/conditions/end_right_turn", false)
			state_machine.set("parameters/conditions/right_turn", true)
			can_move = false
		else:
			state_machine.set("parameters/conditions/end_right_turn", true)
			state_machine.set("parameters/conditions/end_left_turn", true)
			state_machine.set("parameters/conditions/left_turn", false)
			state_machine.set("parameters/conditions/right_turn", false)

#	if jumping or !is_on_floor():
#		can_move = false
	
	if can_move:
		move(delta)
	
	velocity.y -= GRAVITY * delta
	velocity = move_and_slide(velocity, Vector3.UP)
	
#	if move_offset != Vector2.ZERO or move_forward != 0 or move_right != 0 or jumping or !is_on_floor():
#		move(delta)
	
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
	
	if is_on_floor():
		
		
		# Calculate speed
		if move_offset == Vector2.ZERO:
			current_speed = max(current_speed - Acceleration_Stop, 0)
		else:
			normalized_offset = move_offset.normalized()
			current_speed = min(current_speed + Acceleration_Start, max_speed)
		
		move_forward = current_speed * normalized_offset.x
		move_right = current_speed * normalized_offset.y
		
	var direction: Vector3 = Vector3()
	direction.x = move_right
	direction.z = move_forward
	
	direction = direction.rotated(Vector3(0, 1, 0), camera_node.rotation.y)
	
	velocity.x = direction.x
	velocity.z = direction.z

	
	if jumping and is_on_floor():
		velocity.y += Jump_Speed
		self.jumping = false

	state_machine.set("parameters/Moving/blend_position", Vector2(move_right, move_forward).length())

	if move_offset != Vector2.ZERO:
		rotate_model(delta)

func rotate_model(delta):
	
	if jumping or !is_on_floor():
		return RotateSide.NONE
	
	var target_rotation_y = camera_node.rotation.y + PI
	
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
		return RotateSide.NONE
	
	if model_node.rotation.y > target_rotation_y:
		model_node.rotation.y = max(model_node.rotation.y - delta * Rotate_Model_Step, target_rotation_y)
		return RotateSide.RIGHT
	else:
		model_node.rotation.y = min(model_node.rotation.y + delta * Rotate_Model_Step, target_rotation_y)
		return RotateSide.LEFT







