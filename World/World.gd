extends Spatial

func _init():
	VisualServer.set_debug_generate_wireframes(true)

func _ready():
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
