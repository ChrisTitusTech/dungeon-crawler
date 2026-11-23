extends GutTest


func test_main_scene_can_be_instantiated() -> void:
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var main_scene: PackedScene = load(main_scene_path) as PackedScene
	assert_not_null(main_scene, "The project has a loadable startup scene.")
	if main_scene == null:
		return

	var root: Node = autofree(main_scene.instantiate())
	assert_is(root, Control, "The startup scene has a UI root.")


func test_exploration_inputs_are_bound() -> void:
	var exploration_actions: Array[StringName] = [
		&"move_up", &"move_down", &"move_left", &"move_right",
		&"interact", &"select_tile", &"wait_turn", &"open_party",
		&"open_inventory", &"open_equipment", &"toggle_minimap", &"pause",
	]
	for action: StringName in exploration_actions:
		assert_true(InputMap.has_action(action), "Missing input action: %s" % action)
		if InputMap.has_action(action):
			assert_false(InputMap.action_get_events(action).is_empty(), "Unbound input action: %s" % action)
