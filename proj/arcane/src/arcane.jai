// don't overthink, just do.
// short circuit the logical fallacy.
// https://youtube.com/clip/UgkxXiHnwowYSjQ9h0MC686afN-_vxR0V_o9?si=4jX_HCfBf-Zb_haq

app : *AppState;
g_world : *WorldState;
ui : *UI_State;
init_state_pointers :: ()
{
	// these pointers should never really change
	app = *__app_state;
	g_world = *__app_state.world;
	ui = *__app_state.ui;
}

__app_state : AppState;
AppState :: struct
{
	resources: [#run enum_highest_value(ResourceID)+1]ArcResource;
	should_quit: bool;
	window: Window_Type;
	window_w : s32 = WINDOW_X;
	window_h: s32 = WINDOW_Y;
	saved_window: Saved_Window_Info;
	is_fullscreen := false;
	mouse_pos: Vector2;
	
	// measurements
	rdtsc_frequency: u64;
	refresh_rate: float;
	delta_t: float = 1.0 / 60.0;
	
	frame_start_time: u64;
	last_frame_start_time: u64;
	
	time_elapsed: float64;
	frame_count: u64;
	fps_counter: u64;
	fps_timer: float = 1.0;
	fps: u64;
	
		// gotta have the derivatives for some finicky windows reason
	_cursor_confied: bool = false; 
	_cursor_showing: bool = true;
	// these are what you set to determine the state
	confine_cursor: bool = false;
	show_cursor: bool = true;
	key_down: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
	
	app_mode: AppMode;
	entering_app_mode: AppMode;
	exiting_app_mode: AppMode;
	
	main_menu_alpha: float;
	main_menu_alpha_t: float;
	world_alpha: float;
	world_alpha_t: float;
	// sub main menu
	main_home_alpha: float;
	main_home_alpha_t: float;
	main_controls_alpha: float;
	main_controls_alpha_t: float;
	
	camera: Camera2;
	
	world_gen: WorldGenParams;
	world: WorldState;
	
	ui: UI_State;
	
	// debug
	lines: [1024] Line;
	using debug_config: DebugConfig;
	expander_world_gen: bool;
	expander_dumpy: bool = true;
	
	// :particle system
	particles: [128]Particle;
	particle_cursor: int;
	
	
	// game interface stuff
	interface_mode: InterfaceMode;
	entering_interface_mode: InterfaceMode;
	exiting_interface_mode: InterfaceMode;
	disable_player_input: bool;
	// interface animations
	respawn_mode_alpha: float;
	respawn_mode_alpha_t: float;
	pause_menu_alpha: float;
	pause_menu_alpha_t: float;
	inventory_alpha: float;
	inventory_alpha_t: float;
	game_over_alpha: float;
	game_over_alpha_t: float;
	hints_menu_alpha: float;
	hints_menu_alpha_t: float;
	workbench_alpha: float;
	workbench_alpha_t: float;
	placement_alpha: float;
	placement_alpha_t: float;
	// transient interface state
	active_workbench: EntityHandle;
	placement_x_dir:= 1;
	mouse_held_item: EntityHandle;
	
	view_matrix: Matrix4;
	
	frame : FrameStorage; // gets zeroed each frame
	FrameStorage :: struct
	{
		key_pressed: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
		key_released: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
		wheel_delta: s32;
		mouse_delta: Vector2;
		hot_interactable: EntityHandle;
	}
}

WorldState :: struct
{
	initialized: bool;
	simulating: bool = false;
	time_scale: float = 1.0;
	time_elapsed: float64;
	events_this_frame: [16]Event;
	
	entity_id_gen: u64;
	entities: [ENTITY_MAX]Entity;
	entity_count: u32;
	corefire_handle: EntityHandle;
	player_handle: EntityHandle;

	// Biomes
	open_biome: BiomeType;
	player_biome: BiomeType;
	
	// cycle / wave stuff
	day_cycle: float = INITIAL_DAY_START_TIME;
	night_started: bool;
	day_started: bool;
	days_survived: int= INITIAL_DAYS_SURVIVED;
	enemies : [..]EntityHandle; // TODO - @linked list rework so this is serialisable
	spawn_timer: float;
	
	//
	// PLAYER state stuff
	//
	unlocked_recipes: [AppState.resources.count]bool;
	known_items: [AppState.resources.count]bool;
	
	crafting_slot_index: int = 3; // we may as well save dis
	
	respawn_timer: float;
}

main :: ()
{
	app_init(); defer app_shutdown();
	
	while !app.should_quit
	{
		update_delta_t();
		defer
		{
			app.frame_count += 1;
			app.fps_counter += 1;
			app.frame = .{};
		}
		
		context.allocator = frame_allocator;
		
		sound_update();
		
		// ui :defaults
		ui_start();
		push_fill_col(COL_UI_FILL);
		push_text_col(COL_UI_TEXT);
		push_bg_col(COL_UI_BG);
		push_border_col(COL_UI_BORDERS);
		
		push_font(FONT_SUB);
		push_font_size(app.debug_config.ui_font_size);
		push_text_edge_pad(10);
		push_pref_width(pct_parent(1.0, 0.0));
		push_pref_height(em(1.5));
		
		app_update();

		// pause the game
		if app.app_mode == .world && key_pressed(.ESCAPE) && app.interface_mode == .nil
		{
			consume_key(.ESCAPE);
			set_interface_mode(.pause_menu);
		}
	
		// :world target alpha
		if is_state_entry(.world)
		{
			app.world_alpha_t = 1.0;
			if !app.world.initialized then world_init(*app.world); 
			app.confine_cursor = true;
		}
		if is_state_exit(.world)
		{
			app.world_alpha_t = 0.0;
		}
		reached := animate_to_target(*app.world_alpha, app.world_alpha_t, delta_t(), rate=15);
		if reached && app.world_alpha_t == 0.0 && app.world.initialized
		{
			// "unload"
			app.world = .{};
		}
		
		// clear out the nil entity
		nil_entity = .{};
		
		
		main_menu_ui();
		pause_ui();
		game_over_ui();
		hints_menu();
		
		// :update
		if g_world.simulating
		{
			// profile_block("world update");
			
			app.world.time_elapsed += delta_t_scaled();
			world_cycle_update();
			
			in_game_user_interaction();
			
			respawn_ui();
			display_notifications();
			inventory_ui();
			
			// :hud
			{
				// this should only change state in a few places: UI, submitting to the render,
				// and potentially app settings, ie - we remeber what page book we're on, etc
				
				// these puppies are "PUREEEEEEEE"
				// http://www.sevangelatos.com/john-carmack-on/
				
				// the world state is passed by reference
				// see 250_how_parameters_are_passed for more info
				hud_item_blueprint(g_world);
				hud_entity_health_bars(g_world);
				hud_tooltips(g_world);
				hud(g_world);
			}
			
			// the rest of this shit on the other hand... we're directly altering the world state somehow, so this'll
			// be tricky to split apart into networked code.
			// Ideally we'd do it thru the form of high level actions that make specific changes, but I cbf yet.
			
			structure_placement();
			
			player_held_item_update();
			
			// UPDATE
			// Always update the starting biome
			update_corefire();
			update_portals();
			update_items();
			update_torches();
			update_campfires();
			update_crops();
			update_animations();
			player_update();
			gobby_update();
			physics_update();
			update_trees();
			recieve_damage();
			update_particle_system();
			update_point_lights();
			
			app.camera = update_camera(app.camera, get_player());
			
			// unlock recipe of picked up items
			#if DEBUG_UNLOCK_RECIPES 
			{
				for * app.resources if it.flags & .item && it.recipe.count != 0
				{
					g_world.unlocked_recipes[it.id] = true;
				}
			}
			for event: g_world.events_this_frame if event.kind == .pickup
			{
				// add to known item list
				en := entity_from_handle(event.entity);
				en.item_id;
				if !en.item_id then continue;
				g_world.known_items[en.item_id] = true;
				
				for * app.resources if it.flags & .item && it.recipe.count != 0
				{
					all_ingredients_known := true;
					for it.recipe
					{
						if it.id == .nil then break;
						all_ingredients_known = all_ingredients_known && g_world.known_items[it.id];
					}
					
					if all_ingredients_known
					{
						was_just_unlocked := g_world.unlocked_recipes[it.id] == false;
						g_world.unlocked_recipes[it.id] = true;
						
						if was_just_unlocked
						{
							create_notification(tprint("% recipe unlocked", get_display_name(it)));
						}
					}
				}
			}
			
			// destroy entities that're marked
			for * g_world.entities if is_valid(it) && it.marked_for_destroy
			{
				entity_destroy_immediate(it);
			}

			// animate render offset to target
			for * en : g_world.entities
				if en.animate_render_offset_to_target && is_visible(en)
			{
				animate_to_target(*en.render_offset.translate, en.render_offset_t.translate, delta_t_scaled(), rate=40);
				animate_to_target(*en.render_offset.pivot_offset, en.render_offset_t.pivot_offset, delta_t_scaled(), rate=40);
			
				// correct current rotation to take the shortest path to target
				a := en.render_offset.rotate;
				b := en.render_offset_t.rotate;
				if abs(b-a) > 180.0
				{
					en.render_offset.rotate = en.render_offset.rotate + 360.0 * -sign(a);
				}
				animate_to_target(*en.render_offset.rotate, en.render_offset_t.rotate, delta_t_scaled(), rate=40);
			}
		}
		
		{
			// profile_block("render");
			ui_end_and_render();
			render_world_from_state(g_world);
		}
		
		if g_world.simulating
		{
			memory_zero(*app.world.events_this_frame);
			
			// clear entity's frame state
			for * g_world.entities if is_valid(it)
			{
				it.last_frame = it.frame;
				it.frame = Entity.Frame.{};
			}
		}
	}
}

app_init :: ()
{
	setup_output_file();
	
	init_state_pointers();
	
	// windows setup
	Windows.SetProcessDPIAware();
	Windows.timeBeginPeriod(1);
	// this is kinda sketch lol, ideally I'd just like to tack it into the Windows namespace, but idk
	// how to do that without modifying Windows.jai
	FreeConsole();
	
	app.window = create_window(app.window_w, app.window_h, app_title, background_color_rgb=CLEAR_COL.xyz.component);
	
	// default allocator is permanent
	context.allocator = permanent_allocator;
	
	// do all the init shit baybee
	nil_resource = *app.resources[0];
	memory_init();
	render_init();
	init_resources();
	
	sound_init();
	ui_init(*app.ui);
		
	set_app_mode(START_APP_STATE);
	
	app.refresh_rate = get_refresh_rate();
	app.rdtsc_frequency = get_rdtsc_frequency();
}

setup_output_file :: ()
{
	// we basically create a new file + new handles for stdout/err and set our process to use those
	// before any of the runtime support stuff happens and it caches the handles
	
	file_delete("output.txt");
	
	out := CreateFileW(utf8_to_wide("output.txt"), FILE_GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
	assert(out != INVALID_HANDLE_VALUE);
	
	stdout := GetStdHandle(STD_OUTPUT_HANDLE);
	assert(DuplicateHandle(GetCurrentProcess(), out, GetCurrentProcess(), *stdout, 0, .TRUE, 0x00000002) == .TRUE);
	assert(SetStdHandle(cast,no_check(DWORD)STD_OUTPUT_HANDLE, stdout) == .TRUE);
	
	stderr := GetStdHandle(STD_ERROR_HANDLE);
	assert(DuplicateHandle(GetCurrentProcess(), out, GetCurrentProcess(), *stderr, 0, .TRUE, 0x00000002) == .TRUE);
	assert(SetStdHandle(cast,no_check(DWORD)STD_ERROR_HANDLE, stderr) == .TRUE);
}

app_shutdown :: ()
{
	sound_shutdown();
	memory_free();
}

app_update :: ()
{
	reset_temporary_storage();
	
	// Input stuff
	{
		// The Input module is a bit of an allocation festival
		// Just falling back to the default alloc, since beggars can't be choosers
		// @stability - rework this to use arenas
		push_allocator(context.default_allocator);
		
		Input.update_window_events();

		// RESIZE
		for Input.get_window_resizes()
		{
			if (it.window == app.window)
			{
				app.window_w = it.width;
				app.window_h = it.height;
			}
		}

		// EVENTS
		for Input.events_this_frame
		{
			if it.type ==
			{
				case .QUIT;
				app.should_quit = true;

				// update keypress events
				case .KEYBOARD;
				if it.key_pressed
				{
					if (!app.key_down[it.key_code])
					{
						app.frame.key_pressed[it.key_code] = true;
					}
					app.key_down[it.key_code] = true;
				}
				else
				{
					if (app.key_down[it.key_code])
					{
						app.frame.key_released[it.key_code] = true;
					}
					app.key_down[it.key_code] = false;
				}

				case .MOUSE_WHEEL;
				app.frame.wheel_delta += it.wheel_delta / it.typical_wheel_delta;
			}
		}
	}
	
	// CURSOR CLIPPING & FOCUS STUFF
	{
		window_rect: RECT;
		GetWindowRect(app.window, *window_rect);
		
		// play window is basically the client rect, just adusted to always have the correct position in screen coordinates
		play_window: RECT;
		GetClientRect(app.window, *play_window);
		min: POINT = .{play_window.left, play_window.bottom};
		max: POINT = .{play_window.right, play_window.top};
		ClientToScreen(app.window, *min);
		ClientToScreen(app.window, *max);
		play_window.left = min.x;
		play_window.right = max.x;
		play_window.top = max.y;
		play_window.bottom = min.y;
		
		cursor_pos: POINT;
		GetCursorPos(*cursor_pos);
		
		hovering_playspace := PtInRect(*play_window, cursor_pos);
		is_window_focused := GetFocus() == app.window;
		
		// This whole thing is a big spiderweb of state since win32 is fun
		
		// enter focus state
		if is_window_focused
		&& hovering_playspace
		&& key_pressed(.MOUSE_BUTTON_LEFT)
		{
			app.confine_cursor = true;
		}
		
		if !is_window_focused
		{
			app.confine_cursor = false;
		}
		
		// match focus to our derivative
		if app._cursor_confied
		&& !app.confine_cursor
		{
			app._cursor_confied = false;
			ClipCursor(null);
		}
		if !app._cursor_confied
		&& app.confine_cursor
		{
			app._cursor_confied = true;
			ClipCursor(*play_window);
		}
		
		// match the actual cursor state to our derivative
		if app._cursor_showing
		&& !app.show_cursor
		{
			ShowCursor(0); // we need the intermediate because this can't be called every frame...
			app._cursor_showing = false;
		}
		if !app._cursor_showing
		&& app.show_cursor
		{
			ShowCursor(1);
			app._cursor_showing = true;
		}
		
		// lock the clip cursor accordingly
		if app.confine_cursor
		{
			app.show_cursor = false;
		}
		else
		{
			app.show_cursor = true;
		}
	}
	
	// mouse pos
	{
		x, y := get_mouse_pointer_position(app.window, true); 
		app.mouse_pos.x = xx x;
		app.mouse_pos.y = xx y;
		
		app.frame.mouse_delta.x = xx Input.mouse_delta_x;
		app.frame.mouse_delta.y = xx -Input.mouse_delta_y;
	}
	
	// fullscren :)
	if app.frame.key_pressed[Input.Key_Code.F11]
	{
		if toggle_fullscreen(app.window, !app.is_fullscreen, *app.saved_window) then app.is_fullscreen = !app.is_fullscreen;
	}
	
	// display debug
	#if SHOW_DIAGNOSTICS
	{
		set_next_pref_width(px(xx app.window_w, 0));
		set_next_pref_height(px(xx app.window_h, 0));
		set_next_child_layout_axis(.X);
		push_parent(make_box(.floating, ""));
		spacer(pct_parent(1, 0));
		
		set_next_child_layout_axis(.Y);
		set_next_pref_width(size_by_children(1));
		push_parent(make_box(0, ""));
		
		push_pref_width(em(3));
		push_pref_height(em(1));
		push_text_justify_x(.left);
		
		label("%###fps", app.fps);
		
		last_frame_length := cast(float) (app.frame_start_time - app.last_frame_start_time) / app.rdtsc_frequency;
		label("%###frame_time", float_to_string(last_frame_length * 1000, decimals=2));
	}
	
	#if DEBUG // :debug
	{
		fun_val += app.frame.mouse_delta.x / 100;
		
		// debug text
		label("%", get_player().state);
		
		
		// reset g_world
		if app.app_mode == .world && app.frame.key_pressed[#char "R"] && key_down(.ALT)
		{
			consume_key(#char "R");
			world_reset();
		}
		
		// assert that there's no funny business going on in the world
		blank_en : Entity;
		for en : g_world.entities
		{
			if !has_prop(en.props, .valid)
			{
				assert(memcmp(*blank_en, *en, size_of(Entity)) == 0, "We have an invalid prop, yet our memory isn't zeroed? There's a bug somewhere.");
			}
			
			if has_prop(en.props, .enabled) && !has_prop(en.props, .visible) && has_prop(en.props, .monster)
			{
				log_error("we've got an invisible enemy still simulating");
			}
		}
		
		// L key debug
		if key_pressed(#char "L")
		{
			app.camera.trauma += 0.4;
		}
		
		// debug ui
		if key_pressed(#char "1") && key_down(.ALT) then show_debug_ui = !show_debug_ui;
		if show_debug_ui
		{
			app.show_cursor = true;
			
			push_fill_col(rbg_helper(56, 56, 56));
			push_pref_width(pct_parent(1, 0));

			set_next_pref_width(em(12));
			set_next_pref_height(size_by_children(1));
			set_next_fill_col(xyzw(0, 0, 0, 0.9));
			box := make_box(BoxFlags.draw_fill | .draw_border, "");
			push_parent(box);

			set_next_text_justify_x(.center);
			label("- DEBUG -");
			
			// :debug tweaks
			{
				g_world.time_scale = slider_float(g_world.time_scale, 0, 2, "timescale");
				
				g_world.day_cycle = slider_float(g_world.day_cycle, 0, CYCLE_LENGTH, "day/night cycle");
				
				label("night: %###", is_night_time());
			}
			
			app.expander_dumpy = ui_expander(app.expander_dumpy, "Debug Config");
			if app.expander_dumpy
			{
				set_next_pref_height(size_by_children(1));
				auto_row();
				spacer(em(1.5));
				set_next_pref_height(size_by_children(1));
				set_next_pref_width(pct_parent(1, 0));
				auto_column();
				
				ui_edit_struct(*app.debug_config);
			}
			
			app.expander_world_gen = ui_expander(app.expander_world_gen, "World Gen");
			if app.expander_world_gen
			{
				set_next_pref_height(size_by_children(1));
				auto_row();
				spacer(em(1.5));
				set_next_pref_height(size_by_children(1));
				auto_column();
				
				if button("randomise seed").clicked
				{
					set_random_world_seed();
				}
				
				changed : bool;
				sig : Signal;
				app.world_gen.flint_interval, sig = slider_float(app.world_gen.flint_interval, 5.0, 100.0, "flint_interval");
				if sig.dragging then changed = true;
				app.world_gen.flint_threshold, sig = slider_float(app.world_gen.flint_threshold, 0.0, 1.0, "flint_thres");
				if sig.dragging then changed = true;
				
				app.world_gen.persistance, sig = slider_float(app.world_gen.persistance, 0, 1, "persistance");
				if sig.dragging then changed = true;
				
				app.world_gen.octaves, sig = slider_int(app.world_gen.octaves, 1, 16, "octaves");
				if sig.dragging then changed = true;
				
				app.world_gen.freq, sig = slider_float(app.world_gen.freq, 0, 2, "freq");
				if sig.dragging then changed = true;
				
				app.world_gen.random_offset, sig = slider_float(app.world_gen.random_offset, 0, 20, "random_offset");
				if sig.dragging then changed = true;
				
				if changed then world_reset();
			}

			label("Player Pos");
			label("X: %###", get_player().pos.x);
			set_next_child_layout_axis(.X);
			label("Y: %###", get_player().pos.y);
		}
	}
}

update_delta_t :: inline ()
{
	frame_start_time := rdtsc();
	if app.frame_start_time != 0
	{
		app.last_frame_start_time = app.frame_start_time;
		
		if !VSYNC
		{
			app.delta_t = cast(float) (frame_start_time - app.last_frame_start_time) / app.rdtsc_frequency;
			app.time_elapsed += app.delta_t;
		}
	}
	app.frame_start_time = frame_start_time;
	
	if VSYNC then app.delta_t = 1.0/app.refresh_rate;
	
	// measure fps
	if tick_timer(*app.fps_timer, app.delta_t)
	{
		app.fps = app.fps_counter;
		app.fps_timer = 1.0;
		app.fps_counter = 0;
	}
}

// ----- the :chaos waterline ----- //

// :portal
is_portal :: (en: Entity) -> bool
{
	// I'm putting this in a function bc we might want to change this to archetype, idk tho
	return has_prop(en.props, .portal);
}

update_portals :: ()
{
	for * en : g_world.entities
		if is_valid(en) && is_portal(en)
	{
		update_portal(en);
	}
}

setup_portal :: (en: *Entity)
{
	add_props(*en.props, .portal, .interactable);
	en.z_layer = Z_PORTAL;
}

input_attempt_portal :: inline (en: *Entity) -> bool
{
	if key_pressed(#char "E")
	{
		consume_key(#char "E");
		if en.state == .on then en.state = .off; else en.state = .on;
	}
	
	return true;
}

update_portal :: inline (en: *Entity)
{
	if en.state == .on
	{
		en.sprite_id = .portal_on;
		
		// teleport the player when we go thru
	}
	else
	{
		en.sprite_id = .portal_off;
	}
}

render_portal :: inline (en: Entity)
{
	draw_generic_entity(en);
}



Camera2 :: struct
{
	position: Vector2;
	zoom: float = DEFAULT_ZOOM;
	target_zoom: float = DEFAULT_ZOOM;
	trauma: float;
}

update_camera :: (current_cam: Camera2, player: Entity) -> Camera2
{
	camera := current_cam;
	camera.position = xy(0);
	
	// todo - some kinda soft camera target stuff
	
	if player.health != 0
	{
		camera.position.x = -player.pos.x;
	}
	
	//camera.target_zoom = window_h / scene_height * ifx k_key_debug then 1.4 else 1.0;
	
	// decrease trauma across time
	camera.trauma -= delta_t_scaled();
	camera.trauma = clamp_bottom(camera.trauma, 0);

	#if DEBUG
	{
		if (app.frame.wheel_delta) && key_down(.ALT)
		{
			camera.target_zoom += app.frame.wheel_delta / 5.0;
			camera.target_zoom = clamp(camera.target_zoom, 1, 20.0);
		}
	}

	// animate zoom to target
	animate_to_target(*camera.zoom, camera.target_zoom, delta_t_scaled());
	return camera;
}

/*
setup_workbench :: (en: *Entity)
{
	en.item_id = .workbench;
	en.z_layer = Z_STRUCTURES;
	entity_set_sprite(en, .workbench);
	add_props(*en.props, .render_sprite, .deconstructable, .placement_obstacle, .workbench, .interactable, .storage);
	en.storage_slot_count = BASE_WORKBENCH_SLOT_COUNT;
}
*/

ui_storage_slot :: (unique_name_hash: string, storage_slot: *EntityHandle, internal_padding: Size)
{
	slot := make_box(.clickable | .draw_hot_effects | .draw_active_effects, unique_name_hash);
	push_parent(slot);
	
	item_en := entity_from_handle(storage_slot);
	item := get_resource(item_en.item_id);
	
	// draw slot item icon
	if item_en.item_id
	{
		{
			padding(internal_padding); // center vertically
		
			auto_row(pct_parent(1, 0), pct_parent(1, 0));
			padding(internal_padding); // centre horizontally
			
			set_next_pref_size(pct_parent(1, 0), pct_parent(1, 0));
			icon := make_box(.draw_sprite, "");
			icon.sprite_id = item_en.sprite_id;
		}
		
		if item_en.item_count > 1
		{
			set_next_pref_size(pct_parent(1), text_dim(1));
			set_next_text_justify_x(.left);
			make_box(.draw_text | .skip_layout | .floating, tprint("%###itemcount_%", item_en.item_count, unique_name_hash));
		}
	}
	
	// process slot interaction
	slot_signal := signal_from_box(slot);
	if slot_signal.clicked
	{
		process_slot_clicked_action(storage_slot, *app.mouse_held_item);
	}
	
	if slot_signal.hovering && item.id
	{
		// set_next_flags(.draw_fill);
		push_tooltip();
		
		// :item_tooltip
		// I'm not pulling this out because we actually do consume commands and stuff here
		// Maybe I could just pull out the description segment?
		set_next_pref_height(text_dim(1));
		set_next_pref_width(text_dim(1));
		label("%###", get_display_name(item));
		
		if item.description != ""
		{
			set_next_font_size(font_size_pct(0.7));
			set_next_pref_height(text_dim(1));
			set_next_pref_width(text_dim(1));
			label("%###", item.description);
		}
		
		if has_prop(item_en.props, .consumable)
		{
			set_next_pref_size(size_by_children(1));
			auto_row();
			
			icon(.right_click_icon, "", em(1));
			
			set_next_pref_width(text_dim(1));
			set_next_pref_height(text_dim(1));
			label("eat");
			
			if slot_signal.clicked_r
			{
				item.on_consume(item_en);
			}
		}
		
		if key_pressed(#char "Q")
		{
			consume_key(#char "Q");
			
			if item_en.item_count > 1
			{
				item_en.item_count -= 1;
				new_item := entity_duplicate(item_en);
				new_item.item_count = 1;
				drop_item(new_item);
			}
			else
			{
				drop_item(item_en);
				<<storage_slot = .{};
			}
		}
	}
}

get_entity_world_rect_from_sprite :: (en: Entity) -> Range2
{
	rect := rect_from_sprite(en.sprite_id);
	rect = range_shift(rect, en.pos);
	return rect;
}

get_sprite_size :: (sprite_name: string) -> Vector2
{
	return get_sprite_size(get_sprite_from_name(sprite_name).id);
}
get_sprite_size :: (id: SpriteID) -> Vector2
{
	sprite := get_sprite(id);
	return range_size(sprite.rect);
}

rect_from_sprite :: (sprite_name: string) -> Range2
{
	return rect_from_sprite(get_sprite_from_name(sprite_name).id);
}
rect_from_sprite :: (sprite_id: SpriteID) -> Range2
{
	sprite := get_sprite(sprite_id);
	// NOTE - this has to be the same transform as :sprite_transform
	result: Range2;
	result.max = range_size(sprite.rect);
	result = range_bottom_center(result);
	result = range_shift(result, sprite.offset);
	return result;
}

// use delta_t by itself doesn't have slow motion
delta_t :: inline () -> float
{
	return app.delta_t;
}
// scaled variant allows for slow motion in the world
delta_t_scaled :: inline () -> float
{
	return g_world.time_scale * app.delta_t;
}

hud_item_blueprint :: inline (world : WorldState)
{
	for en : world.entities
		if is_visible(en) && has_prop(en.props, .blueprint)
	{
		
		// determine target alpha
		// in_player_range := abs(get_absolute_position(en).x - get_absolute_position(get_player()).x) < 100;
		// if has_prop(en.props, .blueprint) && in_player_range
		// {
		// 	en.blueprint_alpha_t = 1.0;
		// }
		// else
		// {
		// 	en.blueprint_alpha_t = 0;
		// }
		// animate_to_target(*en.blueprint_alpha, en.blueprint_alpha_t, 20); // update alpha to target
		
		// TODO - store alpha anim in UI
		
		blueprint_alpha : float;
		if en.id == app.frame.hot_interactable.entity_id
		{
			blueprint_alpha = 1.0;
		}
		else
		{
			blueprint_alpha = 0.0;
		}
		
		if blueprint_alpha == 0.0 then continue;
		
		sprite := get_sprite(en.sprite_id);
		
		// push into the correct space
		push_parent(ui.frame.root); // this makes us skip past the usual root :screen_space
		push_quad_flags(0); // removes the default .skip_camera_transform, kinda sketch lol
		set_next_floating_x(en.pos.x);
		set_next_floating_y(en.pos.y - 10 * blueprint_alpha);
		push_opacity(blueprint_alpha);
		
		// defaults
		push_font(FONT_MAIN);
		push_font_size(10);
		push_text_justify_x(.center);
		push_pref_width(em(2));
		push_pref_height(em(1));
		
		// container for ui
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_child_layout_axis(.X);
		set_next_fill_col(xyzw(0, 0, 0, 0.5));
		set_next_rect_pivot_x(.center);
		set_next_rect_pivot_y(.top);
		row := make_box(BoxFlags.floating, tprint("%_item_ui", en.id));
		// row.flags |= .draw_fill
		push_parent(row);
		
		// render icons n shiiit
		struc := get_item(en.item_id);
		for remaining: en.remaining_items
		{
			if remaining.id == .nil then break;
			assert(remaining.id == struc.recipe[it_index].id);
			item := get_item(remaining.id);
			
			// padding(em(0.2));
			{
				set_next_pref_width(size_by_children(1));
				set_next_pref_height(size_by_children(1));
				auto_column();
			
				icon(get_display_sprite_id(item), tprint("%_%_icon", it_index, en.id), em(2), horizontal_pad_pct=0.3);
				
				label("%/%##quantity_%_%", struc.recipe[it_index].amount - remaining.amount, struc.recipe[it_index].amount, en.id, item.id);
			}
		}
		
		// trs := make_transform(get_absolute_position(en), 0, 0.1 * en.interactable_alpha);
		// trs.translate.y += 3 + range_size(sprite.rect).y;
		// trs.translate.y += ease_sin_breathe(en.breathe_current) * 2.0;
		// push_text("E", 100, FONT_1980, col=xyzw(1, 1, 1, en.interactable_alpha), z_layer=100, trs=trs);

	}
}

hud :: inline (world: WorldState)
{
	player := entity_from_handle(world.player_handle);
	
	push_layer_cbuff(.{lut_strength=0});
	
	// red vignette
	alpha := 1-float_alpha(xx player.health, 1, xx player.max_health);
	alpha *= 0.8;
	draw_rect(make_range(xy(xx app.window_w, xx app.window_h)), texture=get_texture(.red_vignette), col=xyzw(1, 1, 1, alpha), z_layer=Z_UI-0.5, flags=.skip_camera_transform);
	
	set_next_pref_width(px(xx app.window_w));
	set_next_pref_height(px(xx app.window_h));
	set_next_child_layout_axis(.Y);
	box := make_box(BoxFlags.floating, "hud_box");
	push_parent(box);
	
	spacer(pct_parent(1, 0));
	
	auto_row();
	spacer(pct_parent(1, 0));
	
	set_next_pref_width(text_dim());
	set_next_font_size(font_size_pct(1.5));
	label(tprint("health: %/%", player.health, player.max_health));
}

hud_tooltips :: inline (world: WorldState)
{
	player := entity_from_handle(world.player_handle);
	hovered_en := entity_from_handle(app.frame.hot_interactable);
	
	if is_valid(hovered_en) && hovered_en.item_count > 1
	{
		offset := 3.0 + 2.0 * sin_alpha_from_time(xx world.time_elapsed * 4.0);
		pos := hovered_en.pos + xy(0, get_sprite_size(hovered_en.item_id).y + offset);
		push_text(tprint("x%", hovered_en.item_count), xx (get_font_size() * 0.5), pivot_y=.bottom, trs=make_transform(pos));
	}
}

hud_entity_health_bars :: inline (world: WorldState)
{
	for * en : world.entities
		if is_visible(en) && has_prop(en.props, .draw_health_bar) && en.biome == world.player_biome
	{
		// todo - ideally we store some animation state in the UI box here for some juiciness
		
		if en.health == en.max_health then continue;
		
		height := get_sprite_size(en.sprite_id).y;
		if en.archetype == .gobby
		{
			height = 30;
		}
		
		push_z_layer(en.z_layer);
		push_parent(app.ui.frame.root); // this makes us skip past the usual root :screen_space
		push_quad_flags(0); // removes the default .skip_camera_transform, kinda sketch lol
		set_next_floating_x(en.pos.x);
		set_next_floating_y(en.pos.y + height);

		// defaults
		push_font(FONT_MAIN);
		push_font_size(10);
		push_text_justify_x(.center);
		push_pref_width(em(2));
		push_pref_height(em(1));
		
		// container for ui
		set_next_pref_height(em(0.3));
		set_next_pref_width(em(3.5));
		set_next_child_layout_axis(.Y);
		set_next_fill_col(xyzw(0, 0, 0, 0.5));
		set_next_rect_pivot_x(.center);
		set_next_rect_pivot_y(.bottom);
		row := make_box(BoxFlags.floating | .draw_fill, tprint("%_healthbar", en.id));
		push_parent(row);
		
		set_next_pref_height(pct_parent(1));
		set_next_pref_width(pct_parent(1.0 * entity_health_pct(en)));
		set_next_fill_col(RED);
		make_box(.draw_fill, "");
	}
}

entity_health_pct :: inline (en: *Entity) -> float
{
	return cast(float) en.health / cast(float) en.max_health;
}

get_camera_matrix :: get_view_matrix;
get_view_matrix :: () -> Matrix4
{
	view_matrix : Matrix4 = Matrix4_Identity;
	
	// shake
	cam_shake := clamp_top(pow(app.camera.trauma, 3), 1);
	
	// pre-offset
	// ground will always take up 1/4 of the screen height
	view_matrix *= make_translation_matrix4(xyz(0, (xx app.window_h / 2.0) * -0.5, 0));
	
	// S
	view_matrix *= make_scale_matrix4(xyz(app.camera.zoom, app.camera.zoom, 1));
	
	// R
	shake_rotate := MAX_CAMERA_SHAKE_ROT * cam_shake * random_get_within_range(-1, 1);
	view_matrix *= make_rotation_matrix(shake_rotate);
	
	// T
	view_matrix *= make_translation_matrix4(xyz(app.camera.position.x, app.camera.position.y, 0));
	
	shake_x := MAX_CAMERA_SHAKE_TRANS * cam_shake * random_get_within_range(-1, 1);
	shake_y := MAX_CAMERA_SHAKE_TRANS * cam_shake * random_get_within_range(-1, 1);
	view_matrix *= make_translation_matrix4(xyz(shake_x, shake_y, 0));
	
	return view_matrix;
}

// This function should not alter the world state, merely render what is being shown
render_world_from_state :: (world: WorldState)
{
	//
	// :render
	//
	
	// cached once since this calls random functions for the shake.
	// TODO - Ideally we make it perlin noise and pass in time. That way we can slow it down as well.
	// use generate_perlin_noise_buffer() ??
	app.view_matrix = get_view_matrix();
	
	if app.world_alpha != 0 && RENDER_BACKGROUND
	{
		offset_for_centering_on_camera := app.camera.position * xy(-1, 1);
		bg_size := get_sprite_size(.sky);
		pixel_zoom := app.window_w / bg_size.x;
		
		// sky
		bg_rect := make_range(.{}, xy(xx app.window_w, xx app.window_h), pivot=.center_center);
		draw_rect(bg_rect, col=rbg_helper(49, 161, 227), z_layer=Z_BACKDROP, flags=.skip_camera_transform);
		draw_rect(sprite_id=.sky, sprite_pivot=.center_center, z_layer=Z_BACKDROP-0.5, trs=make_transform(offset_for_centering_on_camera + xy(0, 160) + get_sprite(.sky).offset));
		
		// sun / moon
		/*
		cycle_alpha := get_time_cycle_alpha();
		phase_offset := 90;
		sun_rot := phase_offset + 180.0 + cycle_alpha*360.0;
		moon_rot := phase_offset + cycle_alpha*360.0;
		
		draw_rect(sprite_id=.sun, z_layer=Z_CELESTIAL, sprite_pivot=.center_center, trs=make_transform(bg_parallax_offset + xy(0, 200), rotate=sun_rot, pivot=xy(0, 300)));
		draw_rect(sprite_id=.moon, z_layer=Z_CELESTIAL, sprite_pivot=.center_center, trs=make_transform(bg_parallax_offset + xy(0, 200), rotate=moon_rot, pivot=xy(0, 300)));
		*/
		
		// solid blank ground extension
		draw_rect(make_range(xy(xx app.window_w, 5000), pivot=.top_center, shifter=xy(0, -20)), col=hex_to_rgba(GROUND_COL), z_layer=Z_GROUND+0.1, trs=make_transform(offset_for_centering_on_camera));
	}
	
	// :render generic entities
	if app.world_alpha != 0
	{
		for * en : world.entities
			if is_visible(en)
		{
			if en.archetype == .campfire
			{
				render_campfire(en);
			}
			else if en.archetype == .player
			{
				render_player(en);
			}
			else if has_prop(en.props, .portal)
			{
				// idk why this isn't an archetype, oh well potato potato
				render_portal(en);
			}
			else if has_prop(en.props, .render_sprite)
			{
				draw_generic_entity(en);
			}
		}
	}
	
	// custom_render_player();
	
	#if DEBUG
	{
		// scuffed line render
		for * line: app.lines if line.valid
		{
			diff:= line.p0 - line.p1;
			longness:= length(diff);

			for 0..abs(cast(int) longness)
			{
				point:= line.p0 - diff * (cast(float)it / longness);
				rect: Range2;
				rect.max = xy(0.5, 0.5);
				rect = range_center_center(rect);
				rect = range_shift(rect, point);

				draw_rect(rect, col = line.col, trs=line.transform);
			}

			if line.ticks_left > 0
			{
				line.ticks_left -= 1;
				if line.ticks_left == 0
				{
					<<line = .{};
				}
			}
		}
	}
	
	//
	actually_render();
	
	// reset render state
	reset(*render_st.quads);
	render_st.cbuffer = .{};
	render_st.layer_cbuffer = .{};
	
	FrameMark();
}

// This monster of a function basically draws an entity based on a bunch of things that have been set in its state.
// It might be a good idea to create a stripped down version of this that doesn't rely on an actualy entity?
// That way we can generic draw any sprite and still have it be highlighted and hit all the other good codepaths.
// I haven't needed to create an entity that's split into two different sprites yet that need it tho. So problem
// for a future day - randy, 4th of October 2023
//
draw_generic_entity :: (en: Entity)
{
	local_trs: Transform2;
	render_trs: Transform2;
	
	// skip the big stuff
	if get_held_entity().id == en.id && has_prop(en.props, .reduce_render_scale)
	{
		return;
	}
	
	sprite := get_sprite(en.sprite_id);
	texture := texture_from_sprite(sprite);
	
	// player-specific
	cbuff := render_st.layer_cbuffer;
	if en.id == get_player().id && contains(sprite.name, "char_")
	{
		cbuff.colour_override_amount = 1;
		cbuff.colour_override = hex_to_rgba(0xffe2c3ff);
	}
	push_layer_cbuff(cbuff);
	
	// grab the UV coords, apply animation frame as well
	uv_rect := sprite.rect;
	uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * en.sprite_anim.frame, 0.0));
	uv_rect.min.x /= texture.width;
	uv_rect.min.y /= texture.height;
	uv_rect.max.x /= texture.width;
	uv_rect.max.y /= texture.height;
	flip_x := en.x_dir == -1;
	if en.flip_sprite then flip_x = !flip_x;
	
	// apply the local render offset
	local_trs = en.render_offset;
	ifx en.x_dir == -1 then local_trs.translate.x *= -1;
	
	// apply the resource's sprite offsets
	local_trs.translate.x += en.x_dir * sprite.offset.x;
	local_trs.translate.y += sprite.offset.y;
	local_trs.pivot_offset += sprite.offset;
	
	// final rendering position
	render_trs.translate = en.pos;
	
	// apply parallax
	if en.parallax.x != 0 then render_trs.translate.x -= app.camera.position.x * en.parallax.x;
	
	col := en.col;
	if has_prop(en.props, .blueprint)
	{
		col *= xyzw(0.5, 0.5, 1.0, 0.85);
	}
	col *= en.frame.colour_multiplier;
	
	trs:= merge_transform(local_trs, render_trs);
	
	flags := ifx flip_x then QuadFlags.x_flipped else 0;
	
	quad := draw_rect(sprite_id=sprite.id, sprite_pivot=.bottom_center, z_layer=en.z_layer, col=col, uv_rect=uv_rect, flags=flags, trs=trs);
	quad.white_override = en.white_override;
	quad.white_override += en.interactable_alpha * 0.5;
	
	// damage animation
	tick_timer(*en.damage_alpha, delta_t_scaled() * 10.0);
	if en.damage_alpha != 0
	{
		quad.white_override = 1.0;
	}
}

get_player :: inline () -> *Entity
{
	return entity_from_handle(g_world.player_handle);
}

AppMode :: enum
{
	nil;
	splash;
	main_menu;
	settings;
	world;
}

set_app_mode :: (state: AppMode)
{
	if app.app_mode != state
	{
		app.exiting_app_mode = app.app_mode;
		app.entering_app_mode = state;
		app.app_mode = state;
	}
}

is_state_entry :: (state: AppMode) -> bool
{
	if app.entering_app_mode == state
	{
		app.entering_app_mode = .nil;
		return true;
	}
	return false;
}

is_state_exit :: (state: AppMode) -> bool
{
	if app.exiting_app_mode == state
	{
		app.exiting_app_mode = .nil;
		return true;
	}
	return false;
}

DebugConfig :: struct
{
	disable_cycle_luts: bool = false;
	ui_font_size: int = 32;
	ui_height_scale: float = 0.7;
	
	max_monster_count: int = 0;
	test_val: float;
	
	luts : []KeyFrame = .[
	.{.morning_lut,  					0.125*0.5	},
	.{.day_lut, 									 0.125*2	},
	.{.evening_lut, 						0.125*3 },
	.{.dusk_lut, 									0.125*3.5 },
	.{.early_night_lut, 		0.125*5 },
	.{.mid_night_lut, 				0.125*6 },
	.{.late_night_lut, 			0.125*7 },
	.{.dawn_lut, 									0.125*8 },
];
}

WorldGenParams :: struct
{
	seed: u64 = START_SEED;
	flint_interval := 20.0;
	flint_threshold := 0.7;
	persistance := 0.5;
	octaves := 4;
	freq := 1.0;
	random_offset := 10.0;
}

get_hotbar_slot_count :: () -> int
{
	additional_slots := 0;
	for get_player().equipped_items if is_valid(it)
	{
		en := entity_from_handle(it);
		item := get_item(en.item_id);
		additional_slots += item.additional_hotbar_slots;
	}
	
	return BASE_HOTBAR_COUNT + additional_slots;
}

set_interface_mode :: (state: InterfaceMode)
{
	if app.interface_mode != state
	{
		app.exiting_interface_mode = app.interface_mode;
		app.entering_interface_mode = state;
		app.interface_mode = state;
	}
}

is_state_entry :: (state: InterfaceMode) -> bool
{
	if app.entering_interface_mode == state
	{
		app.entering_interface_mode = .nil;
		return true;
	}
	return false;
}

is_state_exit :: (state: InterfaceMode) -> bool
{
	if app.exiting_interface_mode == state
	{
		app.exiting_interface_mode = .nil;
		return true;
	}
	return false;
}

InterfaceMode :: enum
{
	nil;
	
	pause_menu;
	inventory;
	workbench;
	respawn_mode;
	game_over;
	
	max;
}


Event :: struct
{
	kind: Kind;
	Kind :: enum
	{
		nil;
		craft;
		damage;
		death;
		pickup;
	}
	entity: EntityHandle;
}
new_event :: (event: Event)
{
	for * app.world.events_this_frame
	{
		if it.kind == .nil
		{
			<<it = event;
		}
	}
	if LOG_VERBOSE then log("new event %", event);
}




//
// :WORLD
//

set_random_world_seed :: ()
{
	app.world_gen.seed = get_chaos_seed();
}

world_reset :: ()
{
	app.world = .{};
	world_init(*app.world);
}

world_init :: (g_world: *WorldState)
{
	assert(!g_world.initialized, "World already initialized!");
	g_world.initialized = true;
	nil_entity = *g_world.entities[0];
	
	app.interface_mode = .nil;
	
	gen := app.world_gen;
	#if RANDOMIZE_SEED then gen.seed = get_chaos_seed();
	
	random_seed(gen.seed);
	defer random_seed(get_chaos_seed());
	
	push_allocator(world_allocator);
	world_bootstrap();
	g_world.simulating = true;
	
	#if !SKIP_INTRO then create_notification("Defend Your Flame.", is_big=true);
	
	//
	// world gen
	//
	
	#if !DO_WORLD_GEN
	{
		return;
	}
	
	// push_random_seed(get_chaos_seed());
	
	max_count : int;
	interval : float;
	sprite : *Sprite;
	
	// ground
	sprite = get_sprite(.plains_ground);
	interval = range_size(sprite.rect).x;
	max_count = cast(int) world_radius/xx interval;
	max_count += 6;
	for s: 0..1
	for 1..max_count
	{
		sign := ifx s == 0 then -1.0 else 1.0;
		index := it;
		if s == 0 then index = max_count-index;
		if s == 1 && index == max_count then continue;
		
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_GROUND;
		entity_set_sprite(en, sprite);
		
		en.pos.x = sign * cast(float) index * interval;
	}
	
	point : float;
	
	// hills1
	point = -cast(float)world_radius;
	while point < xx world_radius
	{
		sprite := get_sprite_from_name(tprint("forest_hills_0%", random_int_range(0, 0)));
		
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_HILLS_1;
		en.parallax.x = en.z_layer/100.0;
		en.flip_sprite = random_bool();
		entity_set_sprite(en, sprite);
		
		en.pos.x = point;
		en.pos.y = -30;
		
		point += range_size(sprite.rect).x * 0.7;
	}
	
	// trees1
	point = -cast(float)world_radius;
	while point < xx world_radius
	{
		sprite := random_sprite_from_folder("res/tex/backgrounds/01_forest/front");
		
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_TREES_1;
		en.parallax.x = en.z_layer/100.0;
		en.flip_sprite = random_bool();
		entity_set_sprite(en, sprite);
		
		en.pos.x = point;
		en.pos.y = -70;
		
		point += range_size(sprite.rect).x * 0.5 + random_get_within_range(0, 40);
	}
	
	// trees2
	point = -cast(float)world_radius;
	while point < xx world_radius
	{
		sprite := random_sprite_from_folder("res/tex/backgrounds/01_forest/middle");
		
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_TREES_2;
		en.parallax.x = en.z_layer/100.0;
		en.flip_sprite = random_bool();
		entity_set_sprite(en, sprite);
		
		en.pos.x = point;
		en.pos.y = -70;
		
		point += range_size(sprite.rect).x * 0.4 + random_get_within_range(0, 30);
	}
	
	// trees3
	point = -cast(float)world_radius;
	while point < xx world_radius
	{
		sprite := random_sprite_from_folder("res/tex/backgrounds/01_forest/back");
		
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_TREES_3;
		en.parallax.x = en.z_layer/100.0;
		en.flip_sprite = random_bool();
		entity_set_sprite(en, sprite);
		
		en.pos.x = point;
		en.pos.y = -70;
		
		point += range_size(sprite.rect).x * 0.4 + random_get_within_range(0, 20);
	}
	
	// bg mountains
	sprite = get_sprite(.mountain_00);
	interval = range_size(sprite.rect).x - 300.0;
	max_count = cast(int) world_radius/xx interval;
	max_count += 6;
	for s: 0..1
	for 1..max_count
	{
		sign := ifx s == 0 then -1.0 else 1.0;
		index := it;
		if s == 0 then index = max_count-index;
		if s == 1 && index == max_count then continue;
		
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_MOUNTAIN;
		en.parallax.x = en.z_layer/100.0;
		entity_set_sprite(en, sprite);
		
		en.pos.x = sign * cast(float) index * interval;
		en.pos.y = -57;
	}
	
	//
	// resource :gen
	//
	
	spawn_area_radius :: 70;
	
	// trees
	point = -cast(float)world_radius;
	root_index := 0;
	while point < xx world_radius
	{
		MIN_STEP := 100.0;
		point += random_get_within_range(MIN_STEP, MIN_STEP * 2.0);
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_tree();
		en.pos.x = point;
		
		if random_pct(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.pos.x = point + random_get_within_range(-50, -20);
		}
		
		if random_pct(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.pos.x = point + random_get_within_range(20, 40);
		}
	}
	
	// tall grass
	point = -cast(float)world_radius;
	while point < xx world_radius
	{
		MIN_STEP := 100.0;
		point += random_get_within_range(MIN_STEP, MIN_STEP * 2.0);
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_entity("grass");
		setup_tall_grass(en);
		en.pos.x = point + random_get_within_range(-50, -20);
	}
	
	// flint
	point = -cast(float)world_radius;
	while point < xx (world_radius * 1.5)
	{
		point += 300;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_world_item(.flint);
		en.pos.x = point + random_get_within_range(-150, 150);
	}
	
	// stone
	point = -cast(float)world_radius;
	while point < xx (world_radius * 1.5)
	{
		point += 200;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_world_item(.stone);
		en.pos.x = point + random_get_within_range(-100, 100);
	}
	
	// wood
	// replacing dis with tree root bc it's more satisfying
	/*
	point = -cast(float)world_radius;
	root_index = 0;
	while point < xx world_radius
	{
		point += 100;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_world_item(.wood);
		en.pos.x = point + random_get_within_range(-50, 50);
	}
	*/

	//
	// Rock Biome Gen
	//
	// ground
	sprite = get_sprite(.plains_ground);
	interval = range_size(sprite.rect).x;
	max_count = cast(int) world_radius/xx interval;
	max_count += 6;
	for s: 0..1
	for 1..max_count
	{
		sign := ifx s == 0 then -1.0 else 1.0;
		index := it;
		if s == 0 then index = max_count-index;
		if s == 1 && index == max_count then continue;
		
		en := create_entity("rock_ground", BiomeType.OTHER);
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_GROUND;
		entity_set_sprite(en, sprite);
		
		en.pos.x = sign * cast(float) index * interval;
	}

	// Resource
	// stone
	point = -cast(float)world_radius;
	while point < xx (world_radius * 1.5)
	{
		point += 200;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_entity("", BiomeType.OTHER);
		en.item_id = .stone;
		setup_world_item(en);		
		en.pos.x = point + random_get_within_range(-100, 100);
	}

}

spawn_character :: () -> *Entity
{
	// :character :player
	en := create_entity("player");
	en.archetype = .player;
	en.pos.x = 30;
	add_props(*en.props, .rigid_body, .render_sprite, .override_death, .player, .storage);
	add_props(*en.recieve_damage_from, .monster);
	en.z_layer = Z_PLAYER;
	en.state = .idle;
	entity_set_sprite(en, "char_idle");
	en.collision_rect.max = xy(25, 50);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.health = 3;
	en.storage_slot_count = BASE_INVENTORY_COUNT;
	return en;
}

world_bootstrap :: ()
{
	// :map
	en: *Entity;
	
	en = spawn_character();
	g_world.player_handle = handle_from_entity(en);
	player := en;
	
	en = create_entity();
	setup_corefire(en);
	g_world.corefire_handle = handle_from_entity(en);

	// en = create_world_item(.flint);
	// en.pos.x = -30;
	// en = create_world_item(.wood);
	// en.pos.x = -40;

	#if TESTING
	{
		
		en = create_entity();
		setup_portal(en);
		en.pos.x = 100;
		
		// :gobby spawn
		// en = create_gobby();
		// en.pos.x = -100;
		// en.health = 0;
		// set_state(en, .damaged);
		
		// en = create_world_item(.flint_axe);
		// en.pos.x = 100;
		// attempt_store_item(get_player_storage_slots(), en);
		
		// en = create_entity();
		// en.pos.x = 70;
		// setup_campfire(en);
		
		// en = create_world_item(.raw_goblin_meat);
		// en.item_count = 4;
		// attempt_store_item(get_player_storage_slots(), en);
		
		// en = create_world_item(.wood);
		// en.item_count = 4;
		// attempt_store_item(get_player_storage_slots(), en);
		
		// en = create_world_item(.torch);
		// en.pos.x = 50;
		//attempt_store_item(en);
		
		// en = create_entity();
		// en.pos.x = 60;
		// setup_workbench(en);
		
		en = create_world_item(.flint_sword);
		en.pos.x = 45;
		attempt_store_item(get_player_storage_slots(), en);
		player.hotbar_slots[1] = handle_from_entity(en);
		player.hot_slot = 1;

		// WALL
		en = create_entity();
		setup_side_wall(en);
		en.pos.x = -50;
	}
}

// :cycle
KeyFrame :: struct
{
	value: ResourceID;
	frame_time: float;
}

// TODO - make this a generic structure next time I do an animation
// Hi future Randy!

// ideally this would be editable visually somehow... @animation editor?

get_keyframes :: (time: float) -> KeyFrame, KeyFrame, float
{
	// select the frames to either side of time
	prev : *KeyFrame;
	next : *KeyFrame;
	alpha : float;
	
	if time <= app.debug_config.luts[0].frame_time
	{
		prev = *app.debug_config.luts[app.debug_config.luts.count-1];
		next = *app.debug_config.luts[0];
		alpha = float_alpha(time, 0, app.debug_config.luts[0].frame_time);
	}
	else
	{
		for * app.debug_config.luts
		{
			if it.frame_time >= time // find the first greater frame
			{
				prev = *app.debug_config.luts[it_index-1];
				next = it;
				break;
			}
		}
		
		alpha = (time - prev.frame_time) / (next.frame_time - prev.frame_time);
	}
	
	return prev, next, alpha;
}

get_monster_count :: () -> int
{
	count: int;
	for * en : g_world.entities if is_valid(en) && has_prop(en.props, .monster)
	{
		count += 1;
	}
	return count;
}

// 0 = dawn, 0.25 = midday, 0.5 = dusk, 0.75 = midnight, 1.0 = dawn
get_time_cycle_alpha :: () -> float
{
	day_progress := float_map(g_world.day_cycle, 0, DAY_LENGTH, 0, 1);
	night_progress := float_map(g_world.day_cycle, DAY_LENGTH, DAY_LENGTH+NIGHT_LENGTH, 0, 1);
	return day_progress/2 + night_progress/2;
}

get_night_progress_alpha :: () -> float
{
	return float_alpha(get_time_cycle_alpha(), 0.5, 1.0);
}

get_night_darkness_alpha :: () -> float
{
	cycle := get_time_cycle_alpha();
	return ifx cycle < 0.75 then float_alpha(cycle, 0.4, 0.6) else 1-float_alpha(cycle, 0.8, 1.0);
}

is_night_time :: () -> bool
{
	return get_time_cycle_alpha() > 0.5;
}

world_cycle_update :: ()
{
	#if DISABLE_NIGHT then return;
	
	// tick up the day cycle
	g_world.day_cycle += app.delta_t;
	if g_world.day_cycle > CYCLE_LENGTH
	{
		g_world.day_cycle = 0.0;
	}
	
	cycle_alpha := get_time_cycle_alpha();

	// select the luts
	f1, f2, alpha := get_keyframes(cycle_alpha);
	//log("%, % alpha: %", f1.value, f2.value, alpha);
	if app.debug_config.disable_cycle_luts
	{
		render_st.lut1 = .neutral_lut;
		render_st.lut2 = .neutral_lut;
		render_st.cbuffer.lut_blend_alpha = 0;
	}
	else
	{
		render_st.lut1 = f1.value;
		render_st.lut2 = f2.value;
		render_st.cbuffer.lut_blend_alpha = alpha;
	}
	
	// UPDATE
	if is_night_time()
	{
		is_entry := !g_world.night_started;
		if is_entry
		{
			g_world.night_started = true;
			g_world.day_started = false;
			
			g_world.enemies.allocator = context.default_allocator; // temp
		}
		
		#if !DISABLE_MONSTERS
		{
			if tick_timer(*g_world.spawn_timer, delta_t_scaled(), zero_counts_as_complete=true)
			{
				g_world.spawn_timer = SPAWN_TIMER;
				
				base_amount := 1 + g_world.days_survived;
				group_count := random_int_range(base_amount, base_amount + xx random_bool());
				for 0..group_count-1
				{
					en := create_gobby();
					en.pos.x = random_sign() * MONSTER_SPAWN_RADIUS;
					array_add(*g_world.enemies, handle_from_entity(en));
				}
			}
		}
	}
	else
	{
		// DAY
		
		if !g_world.day_started
		{
			g_world.day_started = true;
			g_world.night_started = false;
		}
		
		if g_world.enemies.count > 0
		{
			still_alive : bool;
			for en : g_world.enemies
			{
				if is_valid(en)
				{
					still_alive = true;
				}
			}
			
			if !still_alive
			{
				g_world.days_survived += 1;
				create_notification(tprint("Nights Survived: %", g_world.days_survived), is_big=true);
				play_sound_old(.wave_over, random_spread=false);
				
				array_reset(*g_world.enemies);
			}
		}
	}
	

	/*
	riser_length :: 13.0;
	
	// DAY START
	if g_world.day_start
	{
		g_world.day_start = false;
		g_world.is_wave_active = false;
		g_world.day_timer = INITIAL_DAY_START_TIME;
		g_world.riser_triggered = false;
	}
	
	// NIGHT START
	if g_world.wave_start
	{
		g_world.wave_start = false;
		g_world.is_wave_active = true;
		g_world.darkness_alpha_t = 1.0;
		
		app.camera.trauma += 0.8;
		
		// TODO - more robust difficulty scaling
		
		total_monster_count := 2 + g_world.days_survived;
		
		left_spawn_count := total_monster_count/2;
		if total_monster_count % 2 == 1 then left_spawn_count += ifx random_bool() then 1;
		spawn_pos := -MONSTER_SPAWN_RADIUS;
		for 0..left_spawn_count-1
		{
			en := create_gobby();
			en.pos.x = spawn_pos;
			
			spawn_pos -= random_get_within_range(20, 100);
		}
		
		spawn_right_count := total_monster_count-left_spawn_count;
		spawn_pos = MONSTER_SPAWN_RADIUS;
		for 0..spawn_right_count-1
		{
			en := create_gobby();
			en.pos.x = spawn_pos;
			
			spawn_pos += random_get_within_range(20, 100);
		}
	}
	
	if g_world.is_wave_active
	{
		// NIGHT TIME
		
		if get_monster_count() == 0
		{
			// reset to day
			g_world.day_start = true;
			g_world.days_survived += 1;
			create_notification(tprint("Days Survived: %", g_world.days_survived), is_big=true);
			play_sound_old(.wave_over, random_spread=false);
		}
	}
	else
	{
		// DAY TIME
		if tick_timer(*g_world.day_timer, delta_t_scaled())
		{
			g_world.wave_start = true;
		}
	
		#if !DISABLE_RISER
		{
			if !g_world.riser_triggered && g_world.day_timer < riser_length
			{
				g_world.riser_triggered = true;
				play_sound_old(.riser, random_spread=false);
			}
		}
		
		g_world.darkness_alpha_t = 1.0-float_map(g_world.day_timer, 0, riser_length, 0, 1);
	}
	
	animate_to_target(*g_world.darkness_alpha, g_world.darkness_alpha_t, delta_t_scaled(), rate=5);
	
	render_st.lut1 = .day_lut;
	render_st.lut2 = .early_night_lut;
	render_st.cbuffer.lut_blend_alpha = g_world.darkness_alpha * 0.7;
	*/
}

format_version := 1;
world_write :: (world_src: WorldState, world_name: string = DEFAULT_WORLD)
{
	path := tprint("%.ligma", world_name);
	file, success := file_open(path, for_writing=true);
	defer file_close(*file);
	assert(success);

	/*
	cereal_write(*file, format_version, "format_version");
	cereal_write(*file, app.maxent, "app.maxent");
	for g_world.entities
	{
		using it;
		cereal_write(*file, flags, "flags");
		cereal_write(*file, kind, "kind");
		cereal_write(*file, state, "state");
		cereal_write(*file, state_buffer, "state_buffer"); // TODO - test
		cereal_write(*file, parallax, "parallax");
		cereal_write(*file, health, "health");
		cereal_write(*file, position, "position");
		cereal_write(*file, velocity, "velocity");
		cereal_write(*file, acceleration, "acceleration");
		cereal_write(*file, sprite_id, "sprite_id");
		cereal_write(*file, rect, "rect");
		cereal_write(*file, z_layer, "layer");
		cereal_write(*file, col, "col");
		cereal_write(*file, rotation_offset, "rotation_offset");
		cereal_write(*file, x_dir, "x_dir");
		cereal_write(*file, x_speed_target, "x_speed_target");
		cereal_write(*file, x_speed_accel, "x_speed_accel");
		cereal_write(*file, x_speed_decel, "x_speed_decel");
		cereal_write(*file, animation_playing, "animation_playing");
		cereal_write(*file, animation_frame, "animation_frame");
		cereal_write(*file, time_til_next_frame, "time_til_next_frame");
		cereal_write(*file, has_attacked, "has_attacked");
		cereal_write(*file, being_damaged, "being_damaged");
		cereal_write(*file, time_left, "time_left");
		cereal_write(*file, start_position, "start_position");
		cereal_write(*file, frame, "frame");
		cereal_write(*file, last_frame, "last_frame");
	}
	*/
}

world_read :: (world_dest: *WorldState, world_name: string = DEFAULT_WORLD)
{
	path := tprint("%.ligma", world_name);
	file, success := file_open(path);
	defer file_close(*file);
	assert(success);

	<<world_dest = WorldState.{}; // reset

	version: int;
	cereal_read(*file, *version, "format_version");
	assert(version == format_version);
	// else, convert

	/*
	count: int;
	cereal_read(*file, *count, "app.maxent");
	for 0..count-1
	{
		dummy_entity: Entity;
		using dummy_entity;
		cereal_read(*file, *flags, "flags");
		cereal_read(*file, *kind, "kind");
		cereal_read(*file, *state, "state");
		cereal_read(*file, *state_buffer, "state_buffer"); // TODO - test
		cereal_read(*file, *parallax, "parallax");
		cereal_read(*file, *health, "health");
		cereal_read(*file, *position, "position");
		cereal_read(*file, *velocity, "velocity");
		cereal_read(*file, *acceleration, "acceleration");
		cereal_read(*file, *sprite_id, "sprite_id");
		cereal_read(*file, *rect, "rect");
		cereal_read(*file, *z_layer, "layer");
		cereal_read(*file, *col, "col");
		cereal_read(*file, *rotation, "rotation");
		cereal_read(*file, *rotation_offset, "rotation_offset");
		cereal_read(*file, *x_dir, "x_dir");
		cereal_read(*file, *x_speed_target, "x_speed_target");
		cereal_read(*file, *x_speed_accel, "x_speed_accel");
		cereal_read(*file, *x_speed_decel, "x_speed_decel");
		cereal_read(*file, *animation_playing, "animation_playing");
		cereal_read(*file, *animation_frame, "animation_frame");
		cereal_read(*file, *time_til_next_frame, "time_til_next_frame");
		cereal_read(*file, *has_attacked, "has_attacked");
		cereal_read(*file, *being_damaged, "being_damaged");
		cereal_read(*file, *time_left, "time_left");
		cereal_read(*file, *start_position, "start_position");
		cereal_read(*file, *frame, "frame");
		cereal_read(*file, *last_frame, "last_frame");
		
		if flags & .valid
		{
			entity := create_entity();
			<<entity = dummy_entity;
		}
	}
	*/
}

//
// :UTILITY
//

get_held_entity_item_name :: () -> string
{
	held_entity := get_held_entity();
	held_item := get_resource(held_entity.item_id);
	if is_valid(held_item)
	{
	 return held_item.name;
	}
	else
	{
	 return "";
	}
}

font_size_pct :: (pct: float) -> int
{
	return xx (cast(float)get_font_size() * pct);
}

get_font_size :: () -> int
{
	return app.debug_config.ui_font_size;
}

key_down :: (key: Input.Key_Code) -> bool
{
	down := app.key_down[key];
	return down;
}

key_pressed :: (key: Input.Key_Code) -> bool
{
	pressed := app.frame.key_pressed[key];
	return pressed;
}

key_released :: (key: Input.Key_Code, consume: bool = true) -> bool
{
	released := app.frame.key_released[key];
	if released && consume then app.frame.key_released[key] = false;
	return released;
}

consume_key :: (key: Input.Key_Code)
{
	app.frame.key_pressed[key] = false;
}

WASDInputAxis :: () -> Vector2
{
	result: Vector2;
	if (app.key_down[#char "A"])
	{
		result.x -= 1;
	}
	if (app.key_down[#char "D"])
	{
		result.x += 1;
	}
	if (app.key_down[#char "W"])
	{
		result.y += 1;
	}
	if (app.key_down[#char "S"])
	{
		result.y -= 1;
	}
	return result;
}

CameraFreeMove :: (using cam: *Camera2)
{
	if (app.key_down[Input.Key_Code.MOUSE_BUTTON_MIDDLE])
	{
		// for some reason this Input mouse_delta_x is being munted in my build script?
		// if (Input.mouse_delta_x || Input.mouse_delta_y)
		// log("% %\n", Input.mouse_delta_x, Input.mouse_delta_y);
		// TODO - not too sure how I can get this in the correct g_world space
		position += xy(cast(float) Input.mouse_delta_x, -cast(float) Input.mouse_delta_y);
	}
	else
	{
		input_axis:= WASDInputAxis();
		position += -input_axis / zoom / 2.0;
	}
}

Line :: struct
{
	valid: bool;
	p0: Vector2;
	p1: Vector2;
	ticks_left: int;
	col: Vector4;
	transform: Transform2;
}

line_create :: (p0: Vector2, p1: Vector2, col: Vector4, tick_count: int = 0, trs: Transform2 = .{}) -> *Line
{
	for * app.lines if !it.valid
	{
		it.valid = true;
		it.p0 = p0;
		it.p1 = p1;
		it.ticks_left = tick_count;
		it.col = col;
		it.transform = trs;
		return *app.lines[it_index];
	}
	return null;
}

debug_rect :: (r: Range2, tick_count: int = 0)
{
	line_create(r.min, xy(r.max.x, r.min.y), RED, tick_count);
	line_create(xy(r.max.x, r.min.y), r.max, RED, tick_count);
	line_create(r.max, xy(r.min.x, r.max.y), RED, tick_count);
	line_create(xy(r.min.x, r.max.y), r.min, RED, tick_count);
}

//
// ENTITY
//

EntityState :: enum
{
	nil;
	idle;
	idle_wait;
	walk;
	jump;
	land;
	sidestep;
	roll;
	
	punch;
	chop;
	slash_1;
	slash_2;
	
	damaged;
	dying;
	dead;
	
	// gob
	wandering;
	agro_target;
	attack_charge;
	attack_hit;
	
	on;
	off;
}

EntityProps :: enum
{
	// :core_props - these are added by default to every entity
	//
	// Whether or not this entity is actually an active entity
	// or just invalid / unused memory.
	valid;
	//
	// Whether or not it's renderered
	visible;
	//
	// Is it enabled in the world and doing things
	// like update ticks, collision queries, etc.
	enabled;
	
	// :properties dump
	portal;
	fuel;
	cookable;
	render_sprite;
	draw_health_bar;
	rigid_body;
	static;
	attack_player;
	interactable;
	pick_up;
	harvestable;
	deconstructable;
	storage;
	placeable;
	placement_obstacle;
	// placed_by_player;
	structure;
	flippable;
	reduce_render_scale;
	attack_target;
	collision_query;
	blueprint;
	generic_damage;
	manually_enter_damage;
	override_death; // have to manually handle the death within the .damaged state
	loot_drops;
	particle_emitter;
	destroy_on_complete;
	item;
	sword;
	axe;
	craftable;
	consumable;
	blockable;
	deconstruct_tool;
	disable_interaction_when_held;
	equippable;
	waist;
	tree;
	tree_root;
	workbench;
	crop;
	big_notification;
	smol_notification;
	point_light;
	
	// masking
	player;
	monster;
	gobby;
	skele;
	fist;
	
	max;
}

Entity :: struct
{
	id: u64;
	debug_name: string;
	props: Properties(EntityProps);
	marked_for_destroy: bool;
	archetype: ResourceID;
	
	// TODO - make some @linked list helpers specific to EnitityHandle
	// that way, we can serialise arrays better and not have to define
	// a maximum value.
	
	state: EntityState;
	state_buffer: [8] EntityStateEvent;

	x_dir := 1;
	x_speed_target: float;
	x_speed_accel: float = 800.0;
	x_speed_decel: float = 500.0;
	move_speed_scale: float = 1.0;
	pos: Vector2;
	velocity: Vector2;
	acceleration: Vector2;
	collision_rect: Range2; // also used for solid-fill rect rendering

	// generic rendering
	sprite_id: SpriteID;
	sprite_anim: AnimationState;
	render_offset: Transform2;
	render_offset_t: Transform2;
	animate_render_offset_to_target: bool;
	z_layer: float;
	col: Vector4 = WHITE;
	flip_sprite: bool; // manual switch
	parallax: Vector2;
	white_override: float; // overrides the pixel colour with white in the shader

	//Biome
	biome: BiomeType;
	
	// AI
	input_axis: Vector2;
	walk_position: float;
	state_timer: float;
	idle_wait_timer: float;
	// note - DON'T MAKE A NEW AI STATE ya silly fucking goose.
	// it's a FSM for a reason. Just break it out into another state / behaviour. Or store more data if need be.
	
	has_attacked: bool;
	state_cooldown: float;
	timer1: float; // this is asking for trouble lol
	timer2: float;
	start_position: Vector2;

	// item stuff
	item_id: ItemID;
	item_count: int = 1;
	loot_drops: [4]ItemAmount;
	
	hit_sound: SoundID = .punch;

	// recieve_damage
	health: int = BASE_MAX_HEALTH;
	max_health: int = BASE_MAX_HEALTH;
	damage_alpha: float;
	recieve_damage_from: Properties(EntityProps);
	damage_event: DamageEvent;

	// notification
	// it seems wise to just keep piling shit into this megastruct, since we're essentially alreadying getting
	// all the create/destroy/update functionality for free
	notif_title: [64]u8;
	notif_subtitle: [32]u8;
	notif_remaining: float;
	
	// blueprint
	remaining_items: [4]ItemAmount;
	occupied_space: Range1 = .{-10, 10};
	
	// interactable
	interactable_alpha: float;
	interactable_alpha_t: float;
	
	// particle
	emitter: EmitterKind;

	// pointlight
	light_radius: float;
	light_radius_t: float;

 // storage
	storage_slots: [32]EntityHandle;
	storage_slot_count:= 0;
	
	// sapling growth
	time_til_growth: float;
	
	// campfire
	remaining_fuel_time: float;
	cooking_item_id: ItemID;
	cooking_timer: float;
	
	// player-specific
	//
	// ideally this would not be included in all entities and just tacked on at the end
	// but I'm not sure how we'd go about doing this without some dynamically allocated mem
	// which would break the clean serialistion...
	// For now we'll just put it in all entities
	//
	hotbar_slots: [9]EntityHandle;
	hot_slot: int = 1;
	equipped_items: [16]EntityHandle;
	is_blocking: bool;
	
	// custom player :animation / rendering
	// The reason I separated out this animation was so that
	// we could detach ourselves from the underlying sprite
	// that's playing and do this sword slash overlay in any state.
	attack_anim: AnimationState;
	
	// janky frame stuff which should probs not exist?
	frame: Frame;
	last_frame: Frame;
	Frame :: struct
	{
		colour_multiplier: Vector4 = WHITE;
		did_state_change: bool;
		did_land: bool;
		//x_collision_dir: s8;
		y_collision_dir: s8;
	}
}
nil_entity : Entity; // I need a way of protecting this memory from writing
get_nil_entity :: () -> *Entity
{
	return *nil_entity;
}

EntityHandle :: struct
{
	entity_id: u64;
	index: int;
}

operator == :: (a: EntityHandle, b: EntityHandle) -> bool
{
	return a.entity_id == b.entity_id && a.index == b.index;
}

entity_from_handle :: (handle: EntityHandle) -> *Entity
{
	entity: *Entity = *app.world.entities[handle.index];
	if handle.entity_id == 0 || entity == null || is_nil(entity) || entity.id != handle.entity_id
	{
		entity = *nil_entity;
	}
	return entity;
}

handle_from_entity :: (entity: *Entity) -> EntityHandle
{
	handle: EntityHandle;
	if is_valid(entity)
	{
		handle.entity_id = entity.id;
		handle.index = entity - app.world.entities.data;
	}
	return handle;
}

is_nil :: (entity: Entity) -> bool
{
	return (entity.id == nil_entity.id);
}

get_name :: (entity: *Entity) -> string
{
	return tprint("%-%", entity.debug_name, get_item(entity.item_id).name);
}

create_entity :: (debug_name := "", biome := BiomeType.INITIAL) -> *Entity
{
	en: *Entity;
	for * app.world.entities if !has_prop(it.props, .valid) && it_index != 0
	{
		en = *app.world.entities[it_index]; // reuse an existing invalid one
	}
	// todo - more robust growth strat??
	if en == null
	{
		log_error("Max entities reached!");
		return *nil_entity;
	}

	reset_entity_props(en);
	app.world.entity_id_gen += 1;
	en.id = app.world.entity_id_gen;
	en.debug_name = copy_string(debug_name, world_allocator);
	en.biome = biome;
	
	if LOG_VERBOSE then log(tprint("% created", ifx debug_name == "" then "entity" else debug_name));

	return en;
}

reset_entity_props :: (en: *Entity)
{
	en.props = .{};
	add_props(*en.props, .valid, .visible, .enabled);
}

entity_destroy_immediate :: (entity: *Entity)
{
	// remove from hierarchy
	// todo - remove children
	//entity_detach_from_parent(entity);
	
	<<entity = Entity.{};
}

entity_duplicate :: (source: Entity) -> *Entity
{
	en := create_entity(source.debug_name);
	id := en.id;
	<<en = source;
	en.id = id;
	return en;
}

DamageEvent :: struct
{
	amount: int;
	direction: Vector2;
	self: EntityHandle;
	inflictor: EntityHandle;
	damage_props: Properties(EntityProps);
}

attempt_damage_entity :: (en: *Entity, amount: int, from: *Entity, damage_props: Properties(EntityProps)) -> bool
{
	if match_props_any(damage_props, en.recieve_damage_from)
		&& en.damage_event.amount == 0 // not already being damaged
	{
		dmg: DamageEvent;
		dmg.amount = amount;
		dmg.self = handle_from_entity(en);
		dmg.inflictor = handle_from_entity(from);
		dmg.direction.x = xx sign(en.pos.x - from.pos.x);
		dmg.damage_props = damage_props;
		en.damage_event = dmg;
		return true;
	}
	return false;
}

get_entity_count_with_prop :: (prop: EntityProps) -> int
{
	// todo - optimise / cache this?
	count : int;
	for * en : app.world.entities
		if is_valid(en) && has_prop(en.props, prop)
			&& en.state != .dead
	{
		count += 1;
	}
	return count;
}

/*
entity_detach_from_parent :: (entity: *Entity)
{
	parent: *Entity = entity_from_handle(entity.parent);
	if is_valid(parent)
	{
		dll_remove(*parent.first, *parent.last, handle_from_entity(entity), "entity.next", "entity.prev", ".{}");
		parent.child_count -= 1;
	}
}

entity_attach_to_parent :: (entity: *Entity, parent: *Entity)
{
	validate_entity(entity, "root child");
	validate_entity(parent, "parent");
	
	entity_detach_from_parent(entity);
	
	entity.parent = handle_from_entity(parent);
	
	// yeeted this because this structure is complicated. Doing a linked list without pointers is... interesting
	// dll_push_back(*parent.first, *parent.last, handle_from_entity(entity), "entity.next", "entity.prev", ".{}");
	
	parent.child_count += 1;
}
*/

// calculates the absolute g_world-space position by looping up thru the parents
get_absolute_position :: (en: *Entity) -> Vector2
{
	/*
	result: Vector2;
	next := en;
	while is_valid(next)
	{
		defer next = entity_from_handle(next.parent);
		result += next.pos;
	}
	*/
	return en.pos;
}

// for expansion that traverses the entity tree from the root depth-first
// this is so fucking cool lmao
/*
depth_first :: (root: *Entity, body: Code, flags: For_Flags) #expand
{
	#assert(!(flags & .REVERSE));
	
	_recurse_down(root, 0, 0);
	_recurse_down :: (root: *Entity, _depth: int, _count: int) -> int
	{
		`it := root;
		`it_index := _count;
		`depth := _depth;
		
		#insert body;
		
		count := _count + 1;
		
		sibling := entity_from_handle(root.first);
		while !is_nil(sibling)
		{
			next_cached := entity_from_handle(sibling.next);
			count = _recurse_down(sibling, _depth + 1, count);
			sibling = next_cached;
		}
		
		return count;
	}
}
*/

// recurses up through parents
// this gives a compiler crash lol, broken at the moment. Just write the code yourself ya lazy FUCK
/*
recurse_up :: (root: *Entity, body: Code, flags: For_Flags) #expand
{
	#assert(!(flags & .REVERSE));
	
	_recurse_up(root, 0);
	_recurse_up :: (root: *Entity, count: int)
	{
		`it := root;
		`it_index := count;
		
		#insert body;
		
		parent := entity_from_handle(root.parent);
		if !is_nil(parent)
		{
			_recurse_up(parent, count + 1);
		}
	}
}
*/

get_collision_rect :: (en: Entity) -> Range2
{
	rect := en.collision_rect;
	if rect.min == .{} && rect.max == .{}
	{
		rect = rect_from_sprite(en.sprite_id);
	}
	return range_shift(rect, en.pos);
}

validate_entity :: (en: Entity, usage_debug_name: string = "")
{
	// FAILURE IS NOT AN OPTION, SOLDIER!
	assert(!is_nil(en), tprint("NIL entity at %", usage_debug_name));
	assert(has_prop(en.props, .valid), tprint("invalid entity at %\n%", usage_debug_name, en));
}

// see :core_props for info on what these do
is_valid :: (entity: Entity) -> bool
{
	return !is_nil(entity) && has_prop(entity.props, .valid);
} 
is_valid :: (entity_handle: EntityHandle) -> bool
{
	return is_valid(entity_from_handle(entity_handle));
}

is_enabled :: (en: Entity) -> bool
{
	return is_valid(en) && has_prop(en.props, .enabled);
}

is_visible :: (en: Entity) -> bool
{
	vis :=
		is_valid(en) && has_prop(en.props, .visible)
		//
		// I pulled the biome checking out into here so we can have it in the one spot.
		// Instead of having to remember to do a check every time we loop over the entity array we just do is_visible
		// Time will tell if this was wise or not.
		// - randy, 4th of October 2023
		//
		&& (en.biome == g_world.player_biome || is_portal(en)); // is it in the same dimension as us?
	return vis;
}

entity_set_sprite :: (en: *Entity, sprite: *ArcResource, random_frame := false, reset_animation := true)
{
	if en.sprite_id != sprite.id
	{
		en.sprite_id = sprite.id;
		
		// :animation
		if sprite.flags & .animation
		{
			en.sprite_anim.id = sprite.id;
			
			if reset_animation
			{
				en.sprite_anim.is_playing = true;
				en.sprite_anim.frame = 0;
				en.sprite_anim.time_til_next_frame = 0;
				
				// janky frame state notifiers
				en.sprite_anim.is_start = true;
				en.sprite_anim.is_finish = false;
				en.sprite_anim.frame_advanced = true; // idk why this would be true...
			}
			
			if random_frame
			{
				en.sprite_anim.frame = random_int_range(0, sprite.frame_count-1);
			}
		}
	}
}
entity_set_sprite :: (en: *Entity, sprite_id: SpriteID, random_frame := false, reset_animation := true)
{
	sprite := get_resource(sprite_id);
	entity_set_sprite(en, sprite, random_frame, reset_animation);
}
entity_set_sprite :: (en: *Entity, sprite_name: string, random_frame := false, reset_animation := true)
{
	sprite := get_sprite_from_name(sprite_name);
	entity_set_sprite(en, sprite, random_frame, reset_animation);
}

EntityStateEvent :: struct
{
	Kind :: enum
	{
		enter;
		exit;
	}
	kind: Kind;
	state: EntityState;
	frame: u64;
	time: float64;
	
	consumed: bool; // debug or neccessary?
}

set_state :: (en: *Entity, new_state: EntityState)
{
	if en.state != new_state
	{
		previous_state := en.state;
		array_insert_start(en.state_buffer, .{kind=.exit, state=previous_state, frame=app.frame_count, time=get_time()});
		array_insert_start(en.state_buffer, .{kind=.enter, state=new_state, frame=app.frame_count, time=get_time()});
		en.state = new_state;
		en.state_timer = 0.0;
	}
}

is_state_entry :: (en: *Entity, state: EntityState) -> bool
{
	// look for an enter event and consume it
	for * en.state_buffer
	{
		if !(it.frame == app.frame_count || it.frame == app.frame_count - 1) then break;
		if it.kind == .enter && it.state == state && !it.consumed
		{
			it.consumed = true;
			return true;
		}
	}
	return false;
}

is_state_exit :: (en: *Entity, state: EntityState) -> bool
{
	// look for an exit event and consume it
	for * en.state_buffer
	{
		if !(it.frame == app.frame_count || it.frame == app.frame_count - 1) then break; // only for this frame or last frame
		if it.kind == .exit && it.state == state && !it.consumed
		{
			it.consumed = true;
			return true;
		}
	}
	return false;
}

entity_was_in_state :: (en: *Entity, state: EntityState) -> bool, float64
{
	for en.state_buffer
	if it.state == state then return true, get_time() - it.time;

	return false, 0;
}

// takes in a set of potential states, returns the first state found and how long ago it was
get_last_state_from_set :: (en: *Entity, state_set: [] EntityState) -> EntityState, float64
{
	for buffer: en.state_buffer
	for match: state_set
	if buffer.state == match then return match, get_time() - buffer.time;
	return 0, 0;
}

//
// :ENTITY HELPERS
//

create_tree_root :: (variant_index: int) -> *Entity
{
	VARIANT_COUNT :: 3;
	variant := variant_index % VARIANT_COUNT;
	does_flip : bool = xx (variant_index % 2);
	
	en := create_entity("tree_root");
	add_props(*en.props, .render_sprite, .tree_root, .loot_drops, .harvestable, .placement_obstacle);
	entity_set_sprite(en, tprint("overgrown_roots_%", variant));
	en.collision_rect = rect_from_sprite(en.sprite_id);
	en.z_layer = Z_ROOTS;
	en.flip_sprite = does_flip;
	
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(1, 3)};
	
	return en;
}

setup_wall :: (en: *Entity)
{
	en.archetype = .back_wall;
	en.item_id = .wood_wall;
	en.z_layer = Z_BACK_WALL;
	entity_set_sprite(en, .wood_wall);
	add_props(*en.props, .render_sprite, .deconstructable, .structure);
}

setup_side_wall :: (en: *Entity)
{
	en.archetype = .side_wall;
	en.item_id = .wood_defense_wall;
	en.z_layer = Z_SIDE_WALL;
	en.health = 10;
	en.max_health = 10;
	entity_set_sprite(en, "wood_defense_wall");
	add_props(*en.props, .rigid_body, .static, .render_sprite, .attack_target, .generic_damage, .placement_obstacle, .draw_health_bar, .deconstructable, .structure);
	add_props(*en.recieve_damage_from, .monster);
	en.collision_rect.max = xy(11, 68);
	en.collision_rect = range_shift(en.collision_rect, xy(-12, 0));
}

create_gobby :: () -> *Entity
{
	en := create_entity("gobby");
	en.archetype = .gobby;
	en.max_health = 30;
	en.health = 30;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .generic_damage, .manually_enter_damage, .override_death, .gobby, .monster, .loot_drops, .draw_health_bar);
	add_props(*en.recieve_damage_from, .player);
	
	en.collision_rect = make_range(xy(32, 32), pivot=.bottom_center);
	
	set_state(en, .idle_wait);
	en.idle_wait_timer = random_get_within_range(0, 2);
	
	push_random_seed(get_chaos_seed());
	en.loot_drops[0] = .{id=.raw_goblin_meat, amount=random_int_range(1, 2)};
	// en.loot_drops[1] = .{id=.goblin_hide, amount=random_int_range(1, 3)};
	return en;
}

create_skele :: () -> *Entity
{
	en := create_entity("skelle");
	en.health = 20;
	en.z_layer = -1;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .generic_damage, .override_death, .skele, .monster);
	add_props(*en.recieve_damage_from, .player);
	return en;
}

does_notification_exist :: (txt: string, is_big := false) -> bool
{
	for en : g_world.entities if has_prop(en.props, ifx is_big then EntityProps.big_notification else EntityProps.smol_notification)
	{
		txt1 := to_string(en.notif_title.data);
		if txt1 == txt then return true;
	}
	return false;
}

create_notification :: (txt: string, is_big := false) -> *Entity
{
	en := create_entity();
	add_props(*en.props, ifx is_big then EntityProps.big_notification else EntityProps.smol_notification);
	string_copy(en.notif_title, txt);
	return en;
}

gobby_update :: ()
{
	player := get_player();
	
	// todo - skele
	// literally just copy out the gobby and adjust as needed
	// do this 1 more time for another monster, THEN figure out if we can abstract stuff
	
	// MAKE CONTENT.
	
	// :GOBBY
	for * en: app.world.entities if is_enabled(en) && has_prop(en.props, .gobby)
	{
		
		// move away from others
		for * other: app.world.entities if is_valid(other) && has_prop(other.props, .gobby)
		{
			dist := en.pos.x - other.pos.x;
			if abs(dist) < 4.0
			{
				en.pos.x += sign(dist) * delta_t_scaled() * 10.0;
			}
		}
		
		
		is_player_dead := get_player().health <= 0;
		//is_player_gone := *app.world.biomes[app.world.player_biome] != biome;
		
		// real target is where we want to go
		real_target := ifx is_player_dead /*|| is_player_gone*/ then entity_from_handle(g_world.corefire_handle) else get_player();
		range_to_real_target := make_range(real_target.pos.x, en.pos.x);
		
		// target entity is the actual thing we're running towards to attack (could be an obstacle)
		target_entity: *Entity;
		
		closest_obstacle: *Entity;
		closest_dist := FLOAT32_INFINITY;
		for * obst: app.world.entities if is_valid(obst) && has_prop(obst.props, .attack_target)
		{
			dist := abs(obst.pos.x - en.pos.x);
			// is it in the way of our real target?
			if range_contains(range_to_real_target, obst.pos.x) && dist < closest_dist
			{
				closest_obstacle = obst;
				closest_dist = dist;
			}
		}
		// if there's an obstacle in the way, target that first
		target_entity = ifx closest_obstacle then closest_obstacle else real_target;
		
		en.state_timer += delta_t_scaled();
		
		if en.state == .nil
		{
			set_state(en, .idle);
		}
		
		if en.state == .idle
		{
			if is_state_entry(en, .idle)
			{
				entity_set_sprite(en, .gob_idle, random_frame=true);
			}
			
			if en.state_timer > 2.0
			{
				set_state(en, .wandering);
			}
		}
		
		if en.state == .idle_wait
		{
			if is_state_entry(en, .idle_wait)
			{
				entity_set_sprite(en, "gob_idle");
			}
			
			if tick_timer(*en.idle_wait_timer, delta_t_scaled(), zero_counts_as_complete=true)
			{
				set_state(en, .idle);
			}
		}
		
		if en.state == .wandering
		{
			if is_state_entry(en, .wandering)
			{
				en.walk_position = en.pos.x + random_get_within_range(30, 200) * random_sign();
			}
			
			if abs(en.walk_position - en.pos.x) < 5.0
			{
				set_state(en, .idle);
			}
		}
		
		// process damage event
		if en.damage_event.amount != 0
		{
			dmg := en.damage_event;
			
			en.health -= dmg.amount;
			en.health = clamp_bottom(0, en.health);
			
			// some kind of persistent damage event ??
			// that way when rendering we can do the flash
			// also we can look back in time to when the thingo happend
			
			play_sound_old(.punch);
			
			en.velocity = en.damage_event.direction * random_get_within_range(100, 150);
			en.velocity.y = 40.0;
			
			if en.health <= 0
			{
				set_state(en, .dying);
			}
			
			memory_zero(*en.damage_event);
		}
		
		// death
		if en.state == .dying
		{
			entity_set_sprite(en, "gob_death");
			if en.sprite_anim.is_finish then set_state(en, .dead);
		}
		if en.state == .dead
		{
			// sadge
			en.marked_for_destroy = true;
			do_death_poof(en);
			spawn_items_at_location(en.loot_drops, en.pos);
			play_sound_old(.impact_thing);
		}
		
		// enter agro
		if is_valid(target_entity)
			&& is_any(en.state, .idle, .wandering)
			&& !is_any(en.state, .damaged, .dying, .dead)
		{
			set_state(en, .agro_target);
		}
		// agro
		if en.state == .agro_target
		{
			en.walk_position = target_entity.pos.x;
		}
		
		// enter attack
		ATTACK_RANGE :: 25;
		dist_to_target := abs(target_entity.pos.x - en.pos.x);
		if dist_to_target < ATTACK_RANGE
			&& is_any(en.state, .idle, .wandering, .agro_target)
			&& !is_any(en.state, .damaged, .dying, .dead)
		{
			set_state(en, .attack_charge);
		}
		
		// attack windup
		if en.state == .attack_charge
		{
			if is_state_entry(en, .attack_charge)
			{
				entity_set_sprite(en, "gob_attack");
				play_sound_old(.gobby_attack, delay=0.6);
			}
			
			attack_frame :: 6;
			if is_valid(target_entity) && en.sprite_anim.frame == attack_frame
			{
				set_state(en, .attack_hit);
			}
		}
		
		// attack hit / follow through
		if en.state == .attack_hit
		{
			if is_state_entry(en, .attack_hit)
			{
				attack_hitbox: Range2 = make_range(xy(88, 45) * 0.7, .bottom_center);
				attack_hitbox = range_shift(attack_hitbox, get_absolute_position(en));
				against_rect := range_shift(target_entity.collision_rect, get_absolute_position(target_entity));
				// debug_rect(attack_hitbox, 50);
				// debug_rect(against_rect, 50);
				if range_collide(against_rect, attack_hitbox)
				{
					attempt_damage_entity(target_entity, 1, en, make_props(EntityProps.gobby, .monster));
				}
			}
			
			if en.sprite_anim.is_finish
			{
				set_state(en, .idle_wait);
				en.idle_wait_timer = random_get_within_range(0.0, 1.5);
			}
		}
		
		// this is kinda a parent of agro & wandering
		if en.state == .agro_target || en.state == .wandering
		{
			entity_set_sprite(en, "gob_run", random_frame=true);
			dist := en.walk_position - en.pos.x;
			en.x_speed_target = 50.0;
			en.input_axis.x = xx sign(dist);
			en.x_dir = sign(en.input_axis.x);
		}
		else
		{
			en.input_axis.x = 0;
			en.x_speed_target = 0.0;
		}
	}
}

get_entity_archetype :: (en: *Entity) -> *EntityArchetype
{
	return get_resource(en.archetype);
}

recieve_damage :: ()
{
	// I think this whole thing might've been going a little too far into generic territory...
		
	for * en: app.world.entities if has_prop(en.props, .generic_damage)
	{
		if en.damage_event.amount != 0
		{
			defer memory_zero(*en.damage_event);
			
			en.health -= en.damage_event.amount;
			en.health = max(en.health, 0);
			en.damage_alpha = 1.0;
			if !has_prop(en.props, .manually_enter_damage) then set_state(en, .damaged);
			
			play_sound_old(en.hit_sound);
		}
		
		if !has_prop(en.props, .override_death) && en.health <= 0
		{
			en.marked_for_destroy = true;
			do_death_poof(en);
			spawn_items_at_location(en.loot_drops, en.pos);
		}
	}
}

do_death_poof :: (en: *Entity)
{
	create_emitter(en.pos, .death_poof);	
}

drop_item :: (item_en: *Entity)
{
	player := get_player();
	item_en.render_offset_t = .{};
	item_en.velocity.x = player.x_dir * random_get_within_range(80, 120) + player.velocity.x;
	item_en.velocity.y = player.velocity.y;
	play_sound_old(.air_swing, pitch=0.8);
	
	item_en.pos = player.pos + xy(0, 14);
	item_en.biome = player.biome;
}

spawn_items_at_location :: (items: []ItemAmount, pos: Vector2)
{
	count := 0;
	for items 
	{
		if it.id == .nil then break;
		count += 1;
	}
	
	drop_list : [..]ItemAmount;
	drop_list.allocator = temp;
	if count > 1 || count == 1 && items[0].amount > 4
	{
		for items
		{
			if it.id == .nil then break;
			array_add(*drop_list, it);
		}
	}
	else
	{
		// if it's of one type, just spread them out
		for item : items
		{
			if item.id == .nil then break;
			for 0..item.amount-1
			{
				array_add(*drop_list, ItemAmount.{item.id, 1});
			}
		}
	}
	
	array_shuffle(*drop_list);
	
	for drop_list
	{
		spacing :: 10.0;
		item := create_world_item(it.id);
		item.item_count = it.amount;
		item.pos = pos + xy((xx (drop_list.count - 1.0) / -2.0) * spacing + it_index * spacing, 0);
		item.velocity = xy(random_get_within_range(-30, 30), random_get_within_range(100, 150));
	}
}



setup_sapling :: (en: *Entity)
{
	add_props(*en.props, .render_sprite, .placement_obstacle, .deconstructable, .crop);
	en.archetype = .oak_sapling;
	entity_set_sprite(en, .oak_sapling);
	en.loot_drops[0] = .{id=.acorn, amount=1};
	en.time_til_growth = random_get_within_range(120, 360);
}

setup_tall_grass :: (en: *Entity)
{
	en.archetype = .tall_grass;
	add_props(*en.props, .render_sprite, .loot_drops, .harvestable);
	en.z_layer = Z_TALL_GRASS;
	en.loot_drops[0] = .{id=.fibre, amount=1+cast(int)random_pct(0.1)};
	en.flip_sprite = random_bool();
	entity_set_sprite(en, tprint("tall_grass_%", random_int_range(0, 1)));
}
setup_tall_grass_stub :: (en: *Entity)
{
	en.archetype = .tall_grass;
	entity_set_sprite(en, .tall_grass_stub);
	add_props(*en.props, .crop, .render_sprite, .placement_obstacle);
	en.time_til_growth = random_get_within_range(60, 240);
}

update_crops :: ()
{
	for * en : app.world.entities
		if is_valid(en) && has_prop(en.props, .crop)
	{
		if en.archetype ==
		{
			case .oak_sapling;
			if tick_timer(*en.time_til_growth, delta_t_scaled())
			{
				en.marked_for_destroy = true;
				tree := create_tree();
				tree.pos = en.pos;
			}
			
			case .tall_grass;
			if tick_timer(*en.time_til_growth, delta_t_scaled())
			{
				reset_entity_props(en);
				setup_tall_grass(en);
			}
		}
	}
}

create_log :: () -> *Entity
{
	en := create_entity("log");
	add_props(*en.props, .render_sprite, .generic_damage, .rigid_body);
	add_props(*en.recieve_damage_from, .axe);
	en.health = 30;
	en.z_layer = Z_TREE;
	en.hit_sound = .wood_hit;
	entity_set_sprite(en, .wood_log);
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(2, 3)};
	return en;
}

create_stump :: () -> *Entity
{
	en := create_entity("stump");
	add_props(*en.props, .render_sprite, .generic_damage, .placement_obstacle);
	add_props(*en.recieve_damage_from, .axe);
	en.health = 30;
	en.z_layer = Z_TREE - 0.1;
	en.hit_sound = .wood_hit;
	entity_set_sprite(en, "tree_stump");
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(1, 2)};
	return en;
}

create_tree :: () -> *Entity
{
	en := create_entity("tree");
	add_props(*en.props, .render_sprite, .tree, .placement_obstacle);
	add_props(*en.recieve_damage_from, .axe);
	entity_set_sprite(en, "tree_full");
	en.collision_rect.max = xy(14, 64);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.health = TREE_HEALTH;
	en.z_layer = Z_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	return en;
}

update_trees :: ()
{
	player := get_player();
	
	for * tree: app.world.entities if is_valid(tree) && has_prop(tree.props, .tree)
	{
		
		if tree.damage_event.amount != 0
		{
			defer memory_zero(*tree.damage_event);
			dmg := tree.damage_event;
			
			tree.damage_alpha = 1.0;
			
			tree.health -= dmg.amount;
			tree.health = clamp_bottom(0, tree.health);
			
			if tree.health <= 0
			{
				set_state(tree, .dying);
			}
			
			play_sound_old(.wood_hit);
		}
		
		if tree.state == .dying
		{
			fall_length :: 2.2;
			if is_state_entry(tree, .dying)
			{
				entity_set_sprite(tree, "tree_long_log");
				tree.timer1 = fall_length;
				
				stump := create_stump();
				stump.pos = tree.pos;
				
				tree.x_dir = sign(tree.pos.x - player.pos.x);
				
				tree.recieve_damage_from = .{};
			}
			
			ROT_OFFSET :: -7;
			// TIMBERRRR
			alpha := 1-tree.timer1 / fall_length;
			alpha = (ease_in_cubic(alpha) + ease_in_exp(alpha)) / 2;
			tree.render_offset.pivot_offset.y = ROT_OFFSET;
			tree.render_offset.rotate = alpha * -90 * tree.x_dir;
			
			// finished falling
			if tick_timer(*tree.timer1, delta_t_scaled())
			{
				STUMP_HEIGHT :: 16.0;
				TREE_THIRD :: 64.0;
				HALF_WIDTH :: TREE_THIRD * 0.5;
				
				// split the log into thirds
				logs: [3]*Entity;
				for 1..3
				{
					tree_log := create_log();
					tree_log.pos = tree.pos;
					tree_log.pos.x += tree.x_dir * (ROT_OFFSET + STUMP_HEIGHT + TREE_THIRD * (it-1.0) + HALF_WIDTH);
					logs[it-1] = tree_log;
					tree_log.velocity.x = 50 * (it-1.0) * tree.x_dir;
					
					if it != 3 && random_pct(0.7)
					{
						en := create_world_item(.acorn);
						en.pos.x = tree.pos.x + tree.x_dir * (ROT_OFFSET + STUMP_HEIGHT + TREE_THIRD * it);
						en.velocity = xy(random_get_within_range(-30, 30), random_get_within_range(100, 150));
					}
				}
				
				new_event(.{kind=.death, entity=handle_from_entity(tree)});
				tree.marked_for_destroy = true;
				
				play_sound_old(.tree_impact);
				app.camera.trauma += 0.6;
			}
		}
	}
}

player_update :: ()
{
	player := get_player();

	// @cleanup
	
	disable_input: bool = app.disable_player_input;
	app.disable_player_input = false;
	// disable_input = disable_input
	// || (player.state == .dead
	// || player.state == .crafting);
	
	player.input_axis = .{};
	if !disable_input
	{
		player.input_axis = WASDInputAxis();
		player.input_axis.y = 0.0;
		
		if app.frame.key_pressed[Input.Key_Code.SPACEBAR]
		{
			consume_key(.SPACEBAR);
			set_state(player, .jump);
		}

		//TEMP(fhomolka): Quick'n'dirty biome switching
		if app.frame.key_pressed[#char "1"] && key_down(.CTRL)
		{
			consume_key(#char "1");
			app.world.player_biome = BiomeType.INITIAL;
			player.biome = BiomeType.INITIAL;
		}
		else if app.frame.key_pressed[#char "2"] && key_down(.CTRL)
		{
			consume_key(#char "2");
			app.world.player_biome = BiomeType.OTHER;
			player.biome = BiomeType.OTHER;
		}
	}
	
	// set the movement dir
	sprinting := false;
	if player.input_axis.x != 0.0 && !disable_input
	{
		mult := 1.0;
		if app.key_down[Input.Key_Code.SHIFT]
		{
			mult = 2.0 * SPRINT_MULT;
			sprinting = true;
		}
		
		player.x_speed_accel = mult * PLAYER_ACCEL;
		player.x_speed_decel = mult * PLAYER_DECEL;
		
		// overweight
		// if total_weight_in_storage() > get_max_weight()
		// {
		// 	weight_over := total_weight_in_storage() - get_max_weight();
		// 	speed_decrease := float_map(xx weight_over, 0, 3, 1.0, 0.25);
		// 	mult *= speed_decrease;
		// }
		
		player.x_speed_target = max_player_move_speed * mult;
		player.x_dir = sign(player.input_axis.x);
	}
	else
	{
		player.x_speed_target = 0.0;
	}
	
	// blocking
	if key_down(.MOUSE_BUTTON_RIGHT)
		&& has_prop(get_held_entity().props, .blockable)
		&& (player.state == .idle || player.state == .walk)
	{
		player.is_blocking = true;
	}
	else
	{
		player.is_blocking = false;
	}
	
	//
	// :player state
	//
	
	if player.state == .idle
	{
		if player.input_axis.x != 0.0 && !disable_input
		{
			set_state(player, .walk);
		}
		else
		{
			entity_set_sprite(player, .ron_idle_pretty);
			player.x_speed_target = 0.0;
		}
	}
	
	// jump / landing
	if player.state == .jump
	{
		if is_state_entry(player, .jump)
		{
			player.velocity.y = 250.0;
			create_emitter(player.pos, .jump_dust);
		}
		else if player.last_frame.did_land
		{
			set_state(player, .land);
		}
		
		apex_range :: 50;
		if abs(player.velocity.y) < apex_range
		{
			entity_set_sprite(player, "char_jump_apex");
		}
		else if player.velocity.y > 0
		{
			entity_set_sprite(player, "char_jump_rise");
		}
		else
		{
			entity_set_sprite(player, "char_jump_fall");
		}
	}
	if player.state == .land
	{
		if is_state_entry(player, .land)
		{
			entity_set_sprite(player, "char_land");
			emit := create_emitter(player.pos, .landing_dust);
			emit.velocity.x = player.velocity.x * 0.2;
		}
		
		if player.sprite_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	// WALK
	if player.state == .walk
	{
		if sprinting
		{
			entity_set_sprite(player, .ron_sprint_base);
		}
		else
		{
			entity_set_sprite(player, .ron_walk_base);
		}
		
		if player.input_axis.x == 0.0
		{
			set_state(player, .idle);
		}
	}
	
	// process damage event
	if player.damage_event.amount != 0
	{
		dmg := player.damage_event;
		
		if player.is_blocking && player.x_dir != sign(dmg.direction.x)
		{
			play_sound_old(.block);
			create_emitter(get_held_item_render_pos() + xy(player.x_dir * 5.0, 5.0), .parry);
		}
		else
		{
			player.health -= dmg.amount;
			player.health = clamp_bottom(0, player.health);
			
			set_state(player, .damaged);
			play_sound_old(.punch);
			
			app.camera.trauma += 0.4;
			
			player.x_dir = -sign(dmg.direction.x);
			player.velocity.x += -player.x_dir * 80.0;
		}
		
		memory_zero(*player.damage_event);
	}
	
	// damaged
	if player.state == .damaged
	{
		is_dead := player.health <= 0;
		if is_dead
		{
			set_state(player, .dying);
		}
		else
		{
			if is_state_entry(player, .damaged)
			{
				entity_set_sprite(player, "char_hurt");
			}
			
			app.disable_player_input = true;
			
			if player.sprite_anim.is_finish then set_state(player, .idle); 
		}
	}
	
	// death
	if player.state == .dying
	{
		if is_state_entry(player, .dying)
		{
			entity_set_sprite(player, "char_death");
			set_interface_mode(.respawn_mode);
		}
		
		app.disable_player_input = true;
	}

	// rotate in direction of travel
	if player.state == .idle || player.state == .walk
	{
		//player.render_offset.pivot_offset = xy(0);
		//alpha := player.velocity.x / max_player_move_speed;
		//player.render_offset.rotate = player_move_tilt * alpha;
	}
	
	// attacc
	if player.attack_anim.id == 0
	{
		// enter slash
		if key_pressed(Input.Key_Code.MOUSE_BUTTON_LEFT)
			&& get_held_entity().item_id == .flint_sword
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			
			play_animation(*player.attack_anim, .anim_slash1);
		}
		
		// enter attack state
		if (player.state == .idle || player.state == .walk)
		&& (key_pressed(Input.Key_Code.MOUSE_BUTTON_LEFT))
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			
			held_entity := get_held_entity();
			
			// launch into attack state
			if is_valid(held_entity)
			{
				if has_prop(held_entity.props, .axe)
				{
					set_state(player, .chop);
				}
				else
				{
					set_state(player, .punch);
				}
			}
		}
	}
	
	// :hit :punch and shit
	// todo - make this good
	hit :: (hitbox: Range2, source: *Entity)
	{
		held_item := get_resource(get_held_entity().item_id);
		
		did_hit := false;
		for * en: g_world.entities
			if is_enabled(en) && is_visible(en)
			&& en != source
		{
			against_rect := get_collision_rect(en);
			//debug_rect(against_rect, 1);
			//debug_rect(attack_hitbox, 1);
			if range_collide(hitbox, against_rect)
			{
				damage_props := get_resource(get_held_entity().item_id).props;
				add_props(*damage_props, .player);
				merge_props(*damage_props, held_item.props);
				landed := attempt_damage_entity(en, HIT_DAMAGE, source, damage_props);
				if landed
				{
					did_hit = true;
					en.damage_alpha = 1.0;
				}
			}
		}
		
		if did_hit
		{
			app.camera.trauma += 0.4;
		}
	}
	
	slash_hitbox: Range2;
	slash_hitbox.min = xy(-20, 0);
	slash_hitbox.max = xy(58, 45);
	if player.x_dir == -1 then slash_hitbox = range_flip_x(slash_hitbox);
	slash_hitbox = range_shift(slash_hitbox, player.pos);
	
	// This is done with a separate animation state
	// SLASH1
	if player.attack_anim.id == .anim_slash1
	{
		if player.attack_anim.is_start
		{
			// play_sound("pop");
			// play_sound_old(.sword_swing_01);
		}
		
		// hit
		// TODO - this would ideally be some kind of tagged hitframe instead of hard-coded
		// on the frame here.
		if player.attack_anim.frame == 3 && player.attack_anim.frame_advanced
		{
			hit(slash_hitbox, player);
			// debug_rect(slash_hitbox, 300);
		}
		
		// combo into slash2
		if player.attack_anim.frame > 5
			&& key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .anim_slash2);
		}
		
		if player.attack_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	// SLASH2
	if player.attack_anim.id == .anim_slash2
	{
		if player.attack_anim.is_start
		{
			play_sound_old(.sword_swing_02);
		}
		
		// hit
		if player.attack_anim.frame == 2 && player.attack_anim.frame_advanced
		{
			hit(slash_hitbox, player);
			// debug_rect(slash_hitbox, 300);
		}
		
		// combo into slash3
		if player.attack_anim.frame > 4
			&& key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .anim_slash3);
		}
		
		if player.attack_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	// SLASH3
	if player.attack_anim.id == .anim_slash3
	{
		if player.attack_anim.is_start
		{
			play_sound_old(.sword_swing_01);
		}
		
		// hit
		if player.attack_anim.frame == 2 && player.attack_anim.frame_advanced
		{
			hit(slash_hitbox, player);
			// debug_rect(slash_hitbox, 300);
		}
		
		if player.attack_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	
	// play out the attack state
	if player.state == .chop || player.state == .punch
	{
		app.disable_player_input = true;
		entity_set_sprite(player, "char_punch");
		
		punch_hitbox: Range2;
		punch_hitbox.max = xy(40, 24);
		if player.x_dir == -1 then punch_hitbox = range_flip_x(punch_hitbox);
		punch_hitbox = range_shift(punch_hitbox, player.pos);
		
		// hit
		if player.sprite_anim.frame == 3 && player.sprite_anim.frame_advanced
		{
			hit(punch_hitbox, player);
			//debug_rect(attack_hitbox, 1000);
			//play_sound_old(.punch);
		}
		
		if player.sprite_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
}

// :player_render - search it for all the lil dumbass state tendrils
// We're altering entity state here so I can be a caveman and just get it working
render_player :: (en: *Entity)
{
	// draw the base player sprite
	draw_generic_entity(en);

	flags := ifx en.x_dir == -1 then QuadFlags.x_flipped else 0;
	offset := make_transform(xy(16, -34));
	
	if en.attack_anim.is_finish
	{
		en.attack_anim.id = 0;
	}
	
	// TODO - needa lanch the vfx off as particles so it's not tied to the state
	playing_anim := false;
	if en.attack_anim.id ==
	{
		case .anim_slash1;
		draw_sprite(.slash1_sword, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.slash1_trail, en.pos, offset_trs=offset, z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
		
		case .anim_slash2;
		draw_sprite(.slash2_sword, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.slash2_trail, en.pos, offset_trs=offset, z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
		
		case .anim_slash3;
		draw_sprite(.slash3_sword, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.slash3_trail, en.pos, offset_trs=offset, z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
	}
	
	// draw sword item
	if get_held_entity().item_id == .flint_sword
	{
		if !playing_anim
		{
			// not too sure how the player's gonna feel about having the sword behind them, feels a little counter-intuitive.
			trs := make_transform(xy(-30.0, 20.0 + xx sin(g_world.time_elapsed * 4)), -120);
			if abs(en.velocity.x) > 1
			{
				trs.translate.y -= abs(en.velocity.x) / 40.0;
				trs.translate.x -= en.x_dir * en.velocity.x / 50.0;
			}
			draw_sprite(.flint_sword, en.pos, offset_trs=trs, z_layer=en.z_layer, animation_index=en.attack_anim.frame, flags=flags);
		}
		
		// This was about to be code for drawing the item at the end hanging spots of the animations, but was too
		// complex and I decided to just not do it. Instead just gonna extend the keyframes of the animations to hang.
		//
		// Ideally we'd go through with this tho, since it'll allow for a smooth interpolation back to idle
		// - randy, 30th of September 2023
		/*
		trs :Transform2;
		z_layer := en.z_layer;
		render_sword := false;
		if !playing_anim
		{
			trs = make_transform(xy(-30.0, 20.0 + xx sin(g_world.time_elapsed * 4)), -120);
			render_sword = true;
		}
		else
		if en.hanging_on_animation ==
		{
			case .anim_slash1;
			trs = make_transform(xy(-20.0, 40.0), -120);
			z_layer += 0.5;
			render_sword = true;
			
			case .anim_slash2;
			
		}
		*/
	}
}

// :animation
AnimationState :: struct
{
	id: AnimationID;
	is_playing: bool = true;
	frame: int;
	time_til_next_frame: float;
	
	// per-frame helpers
	is_start: bool;
	is_finish: bool;
	frame_advanced: bool;
}
play_animation :: (anim: *AnimationState, anim_id: AnimationID)
{
	anim.id = anim_id;
	anim.is_playing = true;
	anim.is_start = true;
	anim.frame = 0;
	anim.time_til_next_frame = 0;
}
update_animations :: ()
{
	for * en: app.world.entities
		if has_prop(en.props, .valid) && has_prop(en.props, .render_sprite)
	{
		update_animation_state(*en.sprite_anim);
		update_animation_state(*en.attack_anim);
	}
}

update_animation_state :: (anim: *AnimationState)
{
	anim.is_start = false;
	anim.is_finish = false;
	anim.frame_advanced = false;
	
	res := get_resource(anim.id);
	if is_valid(res) && anim.is_playing
	{
		// might wanna remove this assert, just doing it for the refactor
		assert(res.frame_count != 0, "Marked as animation, yet no frame count?");
		
		if anim.time_til_next_frame == 0.0
		{
			// it's the start of a frame
			anim.time_til_next_frame = res.frame_duration_ms[anim.frame] / 1000.0;
		}
		
		// tick down to next frame
		anim.time_til_next_frame -= delta_t_scaled();
		if anim.time_til_next_frame <= 0
		{
			anim.time_til_next_frame = 0;
			anim.frame += 1;
			anim.frame_advanced = true;
			
			// if we've reached the end
			if anim.frame == res.frame_count
			{
				anim.is_finish = true;
				
				// I don't see why we'd need to change the looping at run-time, so I'm just gonna keep
				// it in the static resource data for now - randy, 29th of September 2023
				if res.anim_looping
				{
					anim.frame = 0;
				}
				else
				{
					anim.is_playing = false;
					anim.frame -= 1; // leave on the last frame
				}
			}
		}
	}
}

// :physics
physics_update :: ()
{
	for * entity: app.world.entities if is_visible(entity) && has_prop(entity.props, .rigid_body) && !has_prop(entity.props, .static)
	{
		// target velocity
		{
			using entity;
			assert(x_speed_target >= 0, "speed is absolute!");
			x_vel_target:= x_dir * x_speed_target * move_speed_scale;
			diff_sign:= sign(x_vel_target - velocity.x);
			constant:= ifx x_vel_target == 0.0 then x_speed_decel else x_speed_accel;
			velocity.x += diff_sign * constant * delta_t_scaled();
			if diff_sign != sign(x_vel_target - velocity.x) then velocity.x = x_vel_target;
			// if entity == player then log("%\n", velocity.x);
		}

		gravity :: 980.0;
		entity.acceleration.y -= (ifx entity.velocity.y < 0.0 then 2.0 else 1.0) * gravity;

		next_pos:= entity.pos + entity.velocity * delta_t_scaled() + entity.acceleration * 0.5 * delta_t_scaled() * delta_t_scaled();
		entity.velocity += entity.acceleration * delta_t_scaled();
		entity.acceleration = xy(0, 0);

		if next_pos.y < 0
		{
			entity.frame.did_land = true;
			entity.frame.y_collision_dir = -1;
			next_pos.y = 0;
			entity.velocity.y = 0;
		}
		
		/*
		if abs(next_pos.x) > xx world_radius
		{
			next_pos.x = world_radius * cast(float) sign(next_pos.x);
			entity.velocity.x = 0;
		}
		*/

		//TODO(fhomolka): ?Some rem-based clipping?
		if next_pos.x <= -WORLD_DIAMETER 
		{
			diff := next_pos.x + WORLD_DIAMETER;
			next_pos.x = WORLD_DIAMETER + diff;
		}
		else if next_pos.x >= WORLD_DIAMETER 
		{
			diff := next_pos.x - WORLD_DIAMETER;
			next_pos.x = -WORLD_DIAMETER + diff;
		}

		entity.pos = next_pos;


		/*
		// resolve against all other rigid bodies
		for * against: g_world.entities if againapp.valid
		{
			entity_bounds:= range_shift(entity.collision_rect, next_pos);
			against_bounds:= range_shift(againapp.collision_rect, againapp.position);

			// query collision against each other
			// whether or not it collides?
			// the normal of the collision
			// the depth of the col
			// TODO - rect on rect collision
		}
		*/
	}
}

display_notifications :: ()
{
	smol_notifications: [..]*Entity;
	big_notif: *Entity;
	for * en: g_world.entities if is_valid(en)
	{
		if has_prop(en.props, .big_notification) && !big_notif
		{
			big_notif = en;
		}
		if has_prop(en.props, .smol_notification)
		{
			array_insert_at(*smol_notifications, en, 0);
		}
	}
	
	// smol bois
	{
		set_next_pref_height(pct_parent(1));
		set_next_pref_width(pct_parent(1));
		box := make_box(.floating, "");
		push_parent(box);
		
		spacer(pct_parent(1, 0));
		for smol_notifications
		{
			LENGTH :: 10.0;
			if it.notif_remaining == 0.0 then it.notif_remaining = LENGTH;
			alpha := 1-(it.notif_remaining / LENGTH);
			
			opacity: float = 1.0;
			// todo - figure out how minecraft handles this
			// if alpha < 0.1
			// {
			// 	opacity = float_map(alpha, 0, 0.05, 0, 1);
			// }
			// else if alpha > 0.8
			// {
			// 	opacity = 1-float_map(alpha, 0.8, 1.0, 0, 1);
			// }
			
			push_opacity(opacity);
			label("%##%", to_string(it.notif_title), it.id);
			
			if tick_timer(*it.notif_remaining, delta_t())
			{
				entity_destroy_immediate(it);
			}
		} 
	}
	
	
	// big boi
	if big_notif
	{
		LENGTH :: 3.0;
		if big_notif.notif_remaining == 0.0 then big_notif.notif_remaining = LENGTH;
		alpha := 1-(big_notif.notif_remaining / LENGTH);
		
		// todo @anim - proper animation curve lol this shit's scuffed asf
		opacity: float = 1.0;
		if alpha < 0.25
		{
			opacity = float_map(alpha, 0, 0.1, 0, 1);
		}
		else if alpha > 0.6
		{
			opacity = 1-float_map(alpha, 0.6, 1.0, 0, 1);
		}
		
		push_opacity(opacity);
		push_text_justify_x(.center);
		
		set_next_floating_y(alpha * 30);
		set_next_child_layout_axis(.X);
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		box := make_box(BoxFlags.floating, "");
		push_parent(box);
		padding(pct_parent(1, 0));
		
		set_next_pref_height(pct_parent(1));
		auto_column();
		padding(pct_parent(1, 0));
		
		set_next_font_size(app.debug_config.ui_font_size * 4);
		set_next_pref_height(text_dim());
		label(tprint("%##notif", to_string(big_notif.notif_title)));
		
		set_next_font_size(app.debug_config.ui_font_size * 2);
		set_next_pref_height(text_dim());
		label(tprint("%##notif_sub", to_string(big_notif.notif_subtitle)));
		
		if tick_timer(*big_notif.notif_remaining, delta_t())
		{
			entity_destroy_immediate(big_notif);
		}
	}
}

hints_menu :: inline ()
{
	// app.hints_menu_alpha_t = 1.0;
	
	animate_to_target(*app.hints_menu_alpha, app.hints_menu_alpha_t, delta_t());
	
	if app.hints_menu_alpha != 0
	{
		alpha := app.hints_menu_alpha;
		push_opacity(alpha);
		
		set_next_floating_y((1-alpha) * 30.0);
		set_next_child_layout_axis(.X);
		set_next_pref_width(px(xx app.window_w, 0));
		set_next_pref_height(px(xx app.window_h, 0));
		box := make_box(BoxFlags.floating, "");
		push_parent(box);
		
		padding(pct_parent(1, 0)); // we're now centered along the X
		
		set_next_pref_height(pct_parent(1, 0));
		set_next_pref_width(size_by_children(1));
		auto_column();
		padding(pct_parent(1, 0)); // we're now centered along the Y
		
		// background page
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_child_layout_axis(.Y);
		push_parent(make_box(.draw_bg, ""));
		
		spacer(em(0.5));
	
		set_next_text_justify_x(.center);
		set_next_font_size(font_size_pct(3));
		set_next_pref_height(text_dim());
		label("Controls");
		spacer(em(1));
		
		push_font_size(font_size_pct(1.2));
		push_text_justify_x(.center);
		push_pref_height(text_dim());
		push_pref_width(em(13));
		
		controls_chunk();
		spacer(em(1));
	}
}

controls_chunk :: ()
{
	label("A - move left");
	label("D - move right");
	label("SPACE - jump");
	spacer(em(0.5));
	label("E - interact");
	label("TAB - inventory");
	label("Q - drop item");
	spacer(em(0.5));
	label("Left Click - attack");
	label("Hold Right Click - block");
}

main_menu_ui :: inline ()
{
	if is_state_exit(.main_menu)
	{
		app.main_menu_alpha_t = 0.0;
	}
	if is_state_entry(.main_menu)
	{
		app.main_menu_alpha_t = 1.0;
		app.main_home_alpha_t = 1.0;
	}
	animate_to_target(*app.main_menu_alpha, app.main_menu_alpha_t, delta_t(), rate=15);
	
	if app.main_menu_alpha_t == 1.0
	{
		app.show_cursor = true;
		app.confine_cursor = false;
	}
	
	if app.main_menu_alpha == 0.0
	{
		return;
	}
	
	// menu background
	push_opacity(app.main_menu_alpha);
	set_next_pref_width(px(xx app.window_w));
	set_next_pref_height(px(xx app.window_h));
	push_parent(make_box(.floating | .draw_bg, ""));
	
	push_pref_width(em(15));
	push_text_justify_x(.center);
	
	// home
	animate_to_target(*app.main_home_alpha, app.main_home_alpha_t, delta_t(), rate=15);
	if app.main_home_alpha != 0.0
	{
		alpha := app.main_home_alpha * app.main_menu_alpha;
		push_opacity(alpha);
		push_disable_signal(app.main_home_alpha_t == 0 || app.main_menu_alpha_t == 0);
		
		// floating box
		set_next_floating_y((1-alpha) * 30.0 * ifx app.main_home_alpha_t == 1 then -1 else 1);
		set_next_child_layout_axis(.X);
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		push_parent(make_box(BoxFlags.floating , ""));
		padding(pct_parent(1, 0));
		
		set_next_pref_width(size_by_children(1));
		set_next_pref_height(pct_parent(1));
		auto_column();
		padding(pct_parent(1, 0));
		
		{
			push_font(FONT_MAIN);
			push_pref_height(text_dim());
			
			// label("Arcane Survival");
			set_next_font_size(font_size_pct(1.2));
			label("press F11 to fullscreen");
			spacer(em(1));
			label("don't press this button");
			label("until you're recording & are ready");
		}
		
		spacer(em(1.5));
		
		if button("next##main").clicked
		{
			app.main_home_alpha_t = 0.0;
			app.main_controls_alpha_t = 1.0;
		}
	}
	
	// controls
	animate_to_target(*app.main_controls_alpha, app.main_controls_alpha_t, delta_t(), rate=15);
	if app.main_controls_alpha != 0.0
	{
		alpha := app.main_controls_alpha * app.main_menu_alpha;
		push_opacity(alpha);
		push_disable_signal(app.main_controls_alpha_t == 0 || app.main_menu_alpha_t == 0);
		
		// floating box
		set_next_floating_y((1-alpha) * 30.0 * ifx app.main_controls_alpha_t == 1 then -1 else 1);
		set_next_child_layout_axis(.X);
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		push_parent(make_box(BoxFlags.floating , ""));
		padding(pct_parent(1, 0)); // we're now centered along the X
		
		set_next_pref_height(pct_parent(1, 0));
		set_next_pref_width(size_by_children(1));
		auto_column();
		padding(pct_parent(1, 0)); // we're now centered along the Y
		
		// background page
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_child_layout_axis(.Y);
		push_parent(make_box(0, ""));
		
		set_next_text_justify_x(.center);
		set_next_font_size(font_size_pct(2));
		set_next_pref_height(text_dim());
		set_next_pref_width(pct_parent(1, 0));
		label("Controls##main");
		spacer(em(1));
		
		{
			push_font_size(font_size_pct(1.2));
			push_text_justify_x(.left);
			push_pref_height(text_dim());
			push_pref_width(em(13));
			
			{
				// controls background
				set_next_pref_height(size_by_children(1));
				set_next_pref_width(size_by_children(1));
				push_parent(make_box(.draw_border, ""));
				
				spacer(em(0.5));
				controls_chunk();
				spacer(em(0.5));
			}
			
			spacer(em(1));
			
			push_text_justify_x(.center);
			label("you can revist these in-game");
			label("via the 'ESC' menu");
		}
		
		spacer(em(1));
		
		if button("Begin.##ctrls").clicked
		{
			app.main_controls_alpha_t = 0.0;
			set_app_mode(.world);
		}
	}
}

game_over_ui :: ()
{
	if is_state_entry(.game_over)
	{
		play_sound_old(.endgame);
	}
	
	if app.interface_mode == .game_over
	{
		app.game_over_alpha_t = 1.0;
	}
	else
	{
		app.game_over_alpha_t = 0.0;
	}
	animate_to_target(*app.game_over_alpha, app.game_over_alpha_t, delta_t(), rate=5);
	// timer_to_target(*app.game_over_alpha, app.game_over_alpha_t, delta_t());
	
	g_world.time_scale = 1-app.game_over_alpha;
	
	if app.game_over_alpha != 0
	{
		alpha := app.game_over_alpha;
		
		push_opacity(alpha);
		push_text_justify_x(.center);
		
		set_next_floating_y(alpha * 30.0);
		set_next_child_layout_axis(.X);
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		box := make_box(BoxFlags.floating, "");
		push_parent(box);
		padding(pct_parent(1, 0));
		
		set_next_pref_height(pct_parent(1));
		auto_column();
		padding(pct_parent(1, 0));
		
		set_next_font_size(app.debug_config.ui_font_size * 4);
		set_next_pref_height(text_dim());
		label("Game Over");
		
		set_next_font_size(app.debug_config.ui_font_size * 2);
		set_next_pref_height(text_dim());
		label("press R to restart");
		
		if key_pressed(#char "R")
		{
			world_reset();
		}
		
		spacer(pct_parent(0.3));
	}
}

pause_ui :: ()
{
	if app.interface_mode == .pause_menu && key_pressed(.ESCAPE)
	{
		set_interface_mode(.nil);
	}
	
	// entry / exit
	if is_state_entry(.pause_menu)
	{
		app.pause_menu_alpha_t = 1.0;
		g_world.simulating = false;
	}
	if is_state_exit(.pause_menu)
	{
		app.pause_menu_alpha_t = 0.0;
		app.confine_cursor = true;
		g_world.simulating = true;
		
		app.hints_menu_alpha_t = 0.0;
	}
	
	if app.app_mode != .world
	{
		app.pause_menu_alpha_t = 0.0;
	}
	
	animate_to_target(*app.pause_menu_alpha, app.pause_menu_alpha_t, delta_t(), rate=30);
	
	if app.interface_mode == .pause_menu
	{
		app.show_cursor = true;
		app.confine_cursor = false;
		app.disable_player_input = true;
	}
	
	if app.pause_menu_alpha != 0.0
	{
		alpha := app.pause_menu_alpha;
		
		push_opacity(alpha);
		push_text_justify_x(.center);
		push_disable_signal(app.interface_mode != .pause_menu);
		
		set_next_floating_x((1-alpha) * -300.0);
		set_next_child_layout_axis(.Y);
		set_next_pref_width(em(10));
		set_next_pref_height(size_by_children(1));
		set_next_fill_col(BLACK);
		box := make_box(BoxFlags.floating | .draw_bg | .draw_border, "");
		defer spacer(pct_parent(1, 0));
		push_parent(box);
		
		label("- PAUSED -");
		spacer(em(0.5));
		
		
		if button("Controls##menu").clicked
		{
			app.pause_menu_alpha_t = 0.0;
			app.hints_menu_alpha_t = 1.0;
		}
		
		spacer(em(0.5));
		divider();
		
		set_next_font_size(font_size_pct(0.8));
		label("WARNING: there's no saving yet");
		
		set_next_fill_col(hex_to_rgba(0xa35256ff));
		if button("RESTART").clicked
		{
			set_app_mode(.main_menu);
		}
	}
}

respawn_ui :: ()
{
	if is_state_entry(.respawn_mode)
	{
		g_world.respawn_timer = RESPAWN_LENGTH;
	}
	
	if app.interface_mode == .respawn_mode
	{
		app.respawn_mode_alpha_t = 1.0;
		animate_to_target(*app.respawn_mode_alpha, app.respawn_mode_alpha_t, delta_t(), rate=2);
		
		if tick_timer(*g_world.respawn_timer, delta_t_scaled())
		{
			old_body := get_player();
			add_props(*old_body.props, .harvestable);
			
			en := spawn_character();
			g_world.player_handle = handle_from_entity(en);
			set_interface_mode(.nil);
		}
	}
	else
	{
		app.respawn_mode_alpha_t = 0.0;
		animate_to_target(*app.respawn_mode_alpha, app.respawn_mode_alpha_t, delta_t(), rate=30);
	}
	
	if app.respawn_mode_alpha != 0
	{
		alpha := app.respawn_mode_alpha;
		
		push_opacity(alpha);
		push_text_justify_x(.center);
		
		set_next_floating_y(alpha * 30.0);
		set_next_child_layout_axis(.X);
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		box := make_box(BoxFlags.floating, "");
		push_parent(box);
		padding(pct_parent(1, 0));
		
		set_next_pref_height(pct_parent(1));
		auto_column();
		padding(pct_parent(1, 0));
		
		set_next_font_size(app.debug_config.ui_font_size * 4);
		set_next_pref_height(text_dim());
		label("Respawn in");
		
		set_next_font_size(app.debug_config.ui_font_size * 2);
		set_next_pref_height(text_dim());
		
		label("%###respawn_countdown", float_to_string(g_world.respawn_timer, decimals=0));
		
		spacer(pct_parent(0.3));
	}
}

in_game_user_interaction :: inline ()
{
	player:= get_player();
	
	interact_hitbox: Range2;
	interact_hitbox.min.x = -10;
	interact_hitbox.max = xy(40, 32);
	if get_player().x_dir == -1 then interact_hitbox = range_flip_x(interact_hitbox);
	interact_hitbox = range_shift(interact_hitbox, get_player().pos);
	//debug_rect(interact_hitbox, 1);
	
	// :interaction
	// ALRIGHT BUCKO.
	// It's impossible to do this locally within the entity update!
	// Since we need to go through each possible iteraction one-by-one to ensure it pass or fails.
	// That's impossible to do without doing a pre-pass on the whole thing.
	// We also need to sort by the closest ones.
	// THEREFORE, shit needs to be tried one-by-one in a non-trivial order that can't be determined
	// locally while in the entity update.
	
	is_interactable :: (en: Entity) -> bool
	{
		return has_prop(en.props, .interactable) || has_prop(en.props, .pick_up) || has_prop(en.props, .harvestable) || has_prop(en.props, .deconstructable);
	}
	
	// get overlapped interactables
	overlapped: [..]*Entity;
	for * en: g_world.entities
		if is_visible(en) && is_interactable(en)
	{
		against_rect := get_collision_rect(en);
		if range_collide(interact_hitbox, against_rect)
		{
			array_add(*overlapped, en);
		}
	}
	
	// sort by closest to player
	quick_sort(overlapped, x => (abs(x.pos.x - get_player().pos.x)));
	
	// attempt to interact with them one-by-one
	hot_interactable: *Entity = get_nil_entity();
	for en: overlapped
	{
		if has_prop(en.props, .pick_up)
		{
			if can_store_item(get_player_storage_slots(), en)
			{
				defer break;
				hot_interactable = en;
				
				if key_pressed(#char "E")
				{
					consume_key(#char "E");
					
					create_emitter(en.pos, .single_poof);
					new_event(Event.{kind=.pickup, entity=handle_from_entity(en)});
					attempt_store_item(get_player_storage_slots(), en);
					play_sound_old(.pickup);
				}
			}
		}
		else if is_campfire(en)
		{
			if attempt_campfire_input(en)
			{
				hot_interactable = en;
				break;
			}
		}
		else if is_portal(en)
		{
			if input_attempt_portal(en)
			{
				hot_interactable = en;
				break;
			}
		}
		else if has_prop(en.props, .harvestable)
		{
			defer break;
			hot_interactable = en;
			
			if key_pressed(#char "E")
			{
				consume_key(#char "E");
				play_sound_old(.harvest);
				create_emitter(en.pos, .death_poof);
				
				if en.archetype == 
				{
					case .tall_grass;
					reset_entity_props(en);
					setup_tall_grass_stub(en);
					spawn_items_at_location(en.loot_drops, en.pos);
					
					case .player;
					en.marked_for_destroy = true;
					// ideally this would be an override of the harvest of some sort
					// maybe we start having entity resources that're static?
					
					excess_items : [..]EntityHandle;
					
					// return inv to player
					for * en.storage_slots
					{
						en := entity_from_handle(it);
						if en.item_id == 0 then continue;
						
						stored := attempt_store_item(get_player_storage_slots(), en);
						if stored == null
						{
							// fallback to just dropping it on the ground
							array_add(*excess_items, it);
						}
					}
					player.equipped_items = en.equipped_items;
					en.marked_for_destroy = true;
					
					// TODO - TEST THIS!
					for excess_items
					{
						en := entity_from_handle(it);
						add_props(*en.props, .visible);
						en.pos = en.pos;
						en.velocity = xy(random_get_within_range(-30, 30), random_get_within_range(100, 150));
					}
					
					do_death_poof(en);
					
					//
					// default
					case;
					en.marked_for_destroy = true;
					spawn_items_at_location(en.loot_drops, en.pos);
				}
			}
		}
		else if has_prop(en.props, .deconstructable)
		{
			if has_prop(get_held_entity().props, .deconstruct_tool)
			{
				defer break;
				hot_interactable = en;
				
				if key_pressed(#char "E")
				{
					consume_key(#char "E");
					play_sound_old(.harvest);
					create_emitter(en.pos, .death_poof);
					
					en.marked_for_destroy = true;
					
					if en.item_id
					{
						item := get_item(en.item_id);
						// drop the existing spent items
						spent_items: [Entity.remaining_items.count]ItemAmount;
						array_copy(spent_items, item.recipe);
						for * spent_items
						{
							it.amount = it.amount - en.remaining_items[it_index].amount;
						}
						
						// subtract from health
						pct_return := cast(float)en.health / cast(float)en.max_health;
						for * spent_items
						{
							it.amount = xx (pct_return * cast(float)it.amount);
						}
						
						spawn_items_at_location(spent_items, en.pos);
					}
					else
					{
						spawn_items_at_location(en.loot_drops, en.pos);
					}
				}
			}
		}
		else if has_prop(en.props, .interactable)
		{
			// no screening needed, just a generic interact that we'll handle in our own entity update
			hot_interactable = en;
			break;
		}
	}
	
	// animate interaction alphas
	for * en: g_world.entities if is_valid(en)
	{
		// set the correct target
		if hot_interactable.id == en.id && !app.disable_player_input
		{
			en.interactable_alpha_t = 1.0;
		}
		else
		{
			en.interactable_alpha_t = 0.0;
		}
		animate_to_target(*en.interactable_alpha, en.interactable_alpha_t, delta_t_scaled(), rate=30);
	}
	
	app.frame.hot_interactable = handle_from_entity(hot_interactable);
}

player_held_item_update :: inline ()
{
	player := get_player();
	
	// update :helditem pos
	// this is pretty scuffed, maybe I needa make the entity invisible entirely and just do a
	// manual render on the player? yeeee probs, idk
	// if it ain't broke don't fix it
	// :player_render
	held_en := get_held_entity();
	if is_valid(held_en)
	{
		remove_props(*held_en.props, .rigid_body);
		held_en.x_dir = player.x_dir;
		flip := player.x_dir == -1;
		held_en.animate_render_offset_to_target = true;
		
		held_sprite := get_sprite(held_en.sprite_id);
		
		target_offset_trs: Transform2;
		// player_anim := get_sprite(player.sprite_id);
		
		// see :hand_pos in resource.jai for current thoughts
		// if player_anim.hand_sockets.count > 0
		// {
		// 	target_offset_trs = player_anim.hand_sockets[player.animation_frame];
		// 	target_offset_trs.rotate *= -1;
		// }
		// target_offset_trs.translate -= held_sprite.grip_offset.translate;
		// target_offset_trs.pivot_offset = held_sprite.grip_offset.translate * -1;
		// target_offset_trs.pivot_offset.x *= ifx flip then -1 else 1;
		// target_offset_trs.rotate -= held_sprite.grip_offset.rotate;
		
		target_offset_trs.translate = xy(10.0, 15.0);
		
		if player.is_blocking
		{
			target_offset_trs.translate.x += 15;
			target_offset_trs.rotate += 60;
		}
		
		if flip then target_offset_trs.rotate *= -1;
		
		held_en.render_offset_t = target_offset_trs;
		held_en.pos = player.pos;
		// todo - pickup animation
		//animate_to_target(*held_en.pos, get_player().pos, 20);

		//TODO(fhomolka): Do we really have to do this every frame? Maybe do it on biome swap?
		held_en.biome = player.biome;
	}
}

setup_corefire :: (en: *Entity)
{
	add_props(*en.props, .render_sprite, .placement_obstacle, .attack_target);
	add_props(*en.recieve_damage_from, .monster);
	entity_set_sprite(en, .campfire_on_blue);
	en.archetype = .corefire;
	en.z_layer = Z_STRUCTURES;
	en.light_radius = 100.0;
	
	// add_props(*en.props, .storage, .workbench, .interactable);
	// en.storage_slot_count = BASE_WORKBENCH_SLOT_COUNT;
}
update_corefire :: ()
{
	fire := entity_from_handle(g_world.corefire_handle);
	
	// uh oh
	// process damage event example
	if fire.damage_event.amount != 0
	{
		defer memory_zero(*fire.damage_event);
		dmg := fire.damage_event;
		
		entity_set_sprite(fire, .campfire_off);
		create_emitter(fire.pos, .death_poof);
		set_interface_mode(.game_over);
	}
}

/*
campfire_ui :: ()
{
	// can just interact with wood in hand to fuel
	// then interact with cookable thing in hand to pop it on
	
	// don't rly do a ui for now?
}
*/

is_campfire :: (en: Entity) -> bool
{
	return en.archetype == .campfire;
}

setup_campfire :: (en : *Entity)
{
	// en.item_id = .campfire;
	add_props(*en.props, .interactable, .render_sprite, .placement_obstacle);
	entity_set_sprite(en, .campfire_off);
	en.archetype = .campfire;
	en.z_layer = Z_STRUCTURES;
	en.state = .off;
}
attempt_campfire_input :: (camp : *Entity) -> bool
{
	can_interact:= false;
	
	held_en := get_held_entity();
	held_item := get_resource(held_en.item_id);
	
	if has_prop(held_en.props, .fuel)
	{
		can_interact = true;
		
		if key_pressed(#char "E")
		{
			held_en.item_count -= 1;
			if held_en.item_count < 1 then held_en.marked_for_destroy = true;
			consume_key(#char "E");
			
			play_sound_old(.fire_ignite);
			
			camp.remaining_fuel_time += held_item.fuel_amount;
		}
	}
	else if has_prop(held_en.props, .cookable) && camp.cooking_item_id == .nil
	{
		// place on fire to cook
		can_interact = true;
		
		if key_pressed(#char "E")
		{
			consume_key(#char "E");
			play_sound_old(.pickup);
			
			camp.cooking_item_id = held_item.id;
			camp.cooking_timer = held_item.cook_time;
			
			held_en.item_count -= 1;
			if held_en.item_count < 1 then held_en.marked_for_destroy = true;
		}
	}
	
	return can_interact;
}
update_campfires :: ()
{
	for * en: app.world.entities if is_valid(en) && is_campfire(en)
	{
		update_campfire(en);
	}
}
update_campfire :: inline (camp : *Entity)
{
	// tick down the fuel
	tick_timer(*camp.remaining_fuel_time, delta_t_scaled());
	
	if camp.remaining_fuel_time > 0
	{
		set_state(camp, .on);
	}
	else
	{
		set_state(camp, .off);
	}
	
	// tick down the cooking timer
	if camp.state == .on && camp.cooking_item_id != .nil
	{
		if tick_timer(*camp.cooking_timer, delta_t_scaled(), zero_counts_as_complete=true)
		{
			res := get_resource(camp.cooking_item_id);
			
			item := create_world_item(res.cooks_into);
			item.pos = camp.pos;
			item.velocity = xy(random_get_within_range(-30, 30), random_get_within_range(150, 250));
			
			camp.cooking_item_id = .nil;
			
			play_sound_old(.pop);
		}
	}
	
	// off
	if camp.state == .off
	{
		if is_state_entry(camp, .off)
		{
			create_emitter(camp.pos, .death_poof);
			entity_set_sprite(camp, .campfire_off);
			play_sound_old(.fire_extinguish);
		}
		
		camp.light_radius_t = 0.0;
		camp.light_radius = 0.0;
	}
	
	// on
	if camp.state == .on
	{
		if is_state_entry(camp, .on)
		{
			entity_set_sprite(camp, .campfire_on);
		}
		
		camp.light_radius_t = 200.0 + (sin(cast(float)g_world.time_elapsed * 5) * 5);
	}
	animate_to_target(*camp.light_radius, camp.light_radius_t, delta_t_scaled());
}
render_campfire :: inline (camp : Entity)
{
	draw_generic_entity(camp);
	
	if camp.cooking_item_id
	{
		draw_sprite(camp.cooking_item_id, camp.pos + xy(0, 10), z_layer=camp.z_layer+0.5);
	}
}

update_point_lights :: ()
{
	cbuff := get_global_const_buff();
	for * en : g_world.entities if is_visible(en) && en.biome == g_world.player_biome
	{
		if en.light_radius == 0 then continue;
		
		if cbuff.light_count + 1 >= MAX_LIGHTS
		{
			log_error("Max lights reached!");
			return;
		}
		
		pos := en.pos;
		
		cbuff.lights[cbuff.light_count].xy = pos;
		cbuff.lights[cbuff.light_count].z = en.light_radius;
		cbuff.lights[cbuff.light_count].w = 0;
		cbuff.light_count += 1;
	}
	// TODO - put this in a debug info thingo
	// log("lightcount %", cbuff.light_count);
}

world_item_props :: #run make_props(EntityProps.pick_up, .rigid_body);

create_world_item :: (item_id: ItemID) -> *Entity
{
	en := create_entity();
	en.item_id = item_id;
	setup_world_item(en);
	return en;
}

setup_world_item :: (en: *Entity)
{
	item := get_item(en.item_id);
	en.z_layer = Z_ITEMS;
	merge_props(*en.props, item.props);
	merge_props(*en.props, world_item_props);
	add_props(*en.props, .item, .render_sprite);
	entity_set_sprite(en, get_sprite(get_display_sprite_id(item)));
	
	if has_prop(en.props, .reduce_render_scale)
	{
		en.render_offset.scale *= 0.2;
	}
}

update_items :: ()
{
	// get all storage slots in the world lol
	world_storage_slots := get_player_storage_slots();
	for * en : app.world.entities if is_valid(en) && has_prop(en.props, .storage)
	{
		for * en.storage_slots
		{
			array_add(*world_storage_slots, it);
		}
	}
	array_add(*world_storage_slots, *app.mouse_held_item);
	
	held_item := get_held_entity();
	player := get_player();
	
	for * en : app.world.entities if is_valid(en) && has_prop(en.props, .item)
	{
		is_held := held_item == en;
	
		is_in_inventory := false;
		for world_storage_slots
		{
			if it == .{} then continue;
			if en == entity_from_handle(it)
			{
				is_in_inventory = true;
				break;
			}
		}
		
		// determine if it's visible
		if is_in_inventory && !is_held
		{
			remove_props(*en.props, .visible);
		}
		else
		{
			add_props(*en.props, .visible);
		}
		
		// this is fucked cunt
		// :player_render specifc stuff here, this whole thing is ickyyyyy ew
		if held_item.item_id == .flint_sword
		{
			if is_in_inventory || is_held
			{
				remove_props(*en.props, .visible);
			}
			else
			{
				add_props(*en.props, .visible);
			}
		}
		
		
		// is it the world or on the player?
		if is_in_inventory
		{
			remove_props(*en.props, world_item_props);
		}
		else
		{
			merge_props(*en.props, world_item_props);
		}
	}
}

process_slot_clicked_action :: (dest: *EntityHandle, source: *EntityHandle)
{
	en_dest := entity_from_handle(dest);
	en_source := entity_from_handle(source);
	
	// attempt to stack
	if en_dest.item_id == en_source.item_id
	{
		item := get_resource(en_dest.item_id);
		if !is_valid(item) then return; // both items are nil
		
		if en_dest.item_count != item.max_stack_size
		{
			en_dest.item_count += en_source.item_count;
			en_source.item_count = 0;
			
			if en_dest.item_count > item.max_stack_size
			{
				en_source.item_count = en_dest.item_count - item.max_stack_size;
				en_dest.item_count = item.max_stack_size;
			}
			
			if en_source.item_count == 0
			{
				en_source.marked_for_destroy = true;
			}
			
			return;
		}
	}
	
	// if we get here, then they're not stackable, so just swap em
	Swap(dest, source);
}

get_player_storage_slots :: () -> [..]*EntityHandle
{
	player := get_player();
	slots : [..]*EntityHandle;
	slots.allocator = temp;
	array_reserve(*slots, 128);
	
	for * player.hotbar_slots
	{
		// I'm not using the 0 slot. Idk why this is??
		if it_index == 0 then continue;
		if it_index == get_hotbar_slot_count() + 1 then break;
		array_add(*slots, it);
	}
	
	for * player.storage_slots
	{
		if it_index == player.storage_slot_count then break;
		array_add(*slots, it);
	}
	
	return slots;
}

// we could get ^v these two merged into one with a branch for actually executing, but ehhhhh
// feels to complicated. Just gonna type it out instead of trying to mash them together

can_store_item :: (potential_slots : []*EntityHandle, entity_to_store: *Entity) -> bool
{
	if !is_valid(entity_to_store) then return false;
	item := get_item(entity_to_store.item_id);
	
	// existing stacks
	for potential_slots
	{
		dest_en := entity_from_handle(it);
		if item.id == dest_en.item_id
		{
			if dest_en.item_count < item.max_stack_size
			{
				return true;
			}
		}
	}
	
	// put it in the first available slot
	for potential_slots
	{
		dest_en := entity_from_handle(it);
		if !is_valid(dest_en)
		{
			return true;
		}
	}
	
	// inventory full
	return false;
}

// returns the slot that it was stored in
attempt_store_item :: (potential_slots : []*EntityHandle, entity_to_store: *Entity) -> *EntityHandle
{
	if !is_valid(entity_to_store) then return null;
	item := get_item(entity_to_store.item_id);
	
	// loop over all potential slots and try add them to existing stacks
	for potential_slots
	{
		dest_en := entity_from_handle(it);
		if item.id == dest_en.item_id
		{
			dest_en.item_count += entity_to_store.item_count;
			entity_to_store.item_count = 0;
			
			if dest_en.item_count > item.max_stack_size
			{
				entity_to_store.item_count = dest_en.item_count - item.max_stack_size;
				dest_en.item_count = item.max_stack_size;
			}
			
			if entity_to_store.item_count == 0
			{
				entity_to_store.marked_for_destroy = true;
				return it;
			}
		}
	}
	
	// if not zero by this point, put it in the first available slot
	for potential_slots
	{
		dest_en := entity_from_handle(it);
		if !is_valid(dest_en)
		{
			<<it = handle_from_entity(entity_to_store);
			return it;
		}
	}
	
	// inventory full
	return null;
}

get_held_item_render_pos :: () -> Vector2
{
	pos : Vector2;
	en := get_held_entity();
	pos = en.pos + en.render_offset.translate * xy(xx en.x_dir, 1) - en.render_offset.pivot_offset;
	return pos;
}

get_held_entity :: () -> *Entity
{
	player:= get_player();
	return entity_from_handle(player.hotbar_slots[player.hot_slot]);
}

update_torches :: ()
{
	held_en := get_held_entity();
	for * en : app.world.entities if is_visible(en) && en.item_id == .torch
	{
		update_torch(en);
	}
}
update_torch :: inline (en: *Entity) #expand
{
	// toggle on/off
	if `held_en == en && key_pressed(#char "E")
	{
		consume_key(#char "E");
		set_state(en, ifx en.state == .on then .off else .on);
	}
	
	// off
	if en.state == .off
	{
		if is_state_entry(en, .off)
		{
			create_emitter(en.pos + xy(0, 14), .single_poof);
			play_sound_old(.fire_extinguish);
		}
		
		en.light_radius_t = 0.0;
		en.light_radius = 0.0;
	}
	
	// on
	if en.state == .on
	{
		if is_state_entry(en, .on)
		{
			play_sound_old(.fire_ignite);
		}
		
		en.light_radius_t = 200.0 + (sin(cast(float)g_world.time_elapsed * 5) * 5);
	}
	
	animate_to_target(*en.light_radius, en.light_radius_t, delta_t_scaled());
}

//
// :INVENTORY
//

inventory_ui :: ()
{
	player := get_player();
	
	// enter
	if app.interface_mode != .inventory
		&& key_pressed(.TAB)
	{
		consume_key(.TAB);
		set_interface_mode(.inventory);
	}
	// exit
	if app.interface_mode == .inventory
		&& key_pressed(.TAB)
	{
		consume_key(.TAB);
		set_interface_mode(.nil);
	}
	if app.interface_mode == .inventory
		&& key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		set_interface_mode(.nil);
	}
	
	// target to alpha
	if app.interface_mode == .inventory || app.interface_mode == .workbench
	{
		app.inventory_alpha_t = 1.0;
	}
	else
	{
		app.inventory_alpha_t = 0.0;
	}
	animate_to_target(*app.inventory_alpha, app.inventory_alpha_t, delta_t(), rate=UI_ANIMATE_RATE);
	
	// change hotbar slot
	for 1..get_hotbar_slot_count()
	{
		if key_pressed(xx (#char "1" + it-1))
		{
			if player.hot_slot != it
			{
				player.hot_slot = it;
			}
			else
			{
				player.hot_slot = 0;
			}
		}
	}
	// when it goes out of range, we just reset
	if player.hot_slot > get_hotbar_slot_count()
	{
		player.hot_slot = 0;
	}
	
	item_to_drop : *Entity;
	
	is_inventory_open := app.inventory_alpha_t == 1.0;
	if is_inventory_open
	{
		app.show_cursor = true;
	}
	
	slot_size := em(UI_SLOT_SIZE);
	margin := em(UI_MARGIN);
	slot_icon_padding := em(UI_SLOT_ICON_PADDING);
	slot_spacing := em(UI_SLOT_SPACING);
	slot_bg_col := COL_UI_BG;
	slot_border_col := GRAY;
	
	set_next_pref_width(pct_parent(1));
	set_next_pref_height(pct_parent(1));
	push_parent(make_box(0, ""));
	
	// Main inventory
	bg_box_sig : Signal;
	{
		push_disable_signal(!is_inventory_open);
		
		// parent bg box
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_opacity(app.inventory_alpha);
		set_next_bg_col(COL_UI_BG * 0.5);
		bg_box := make_box(.draw_bg | .draw_border | .clickable, "inv_main_box");
		push_parent(bg_box);
		
		// hotbar slots
		{
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			auto_column();
			spacer(margin);
			
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			auto_row();
			padding(margin);
			for 1..get_hotbar_slot_count()
			{
				if it != 1 then spacer(slot_spacing);
				
				slot_active := player.hot_slot == it;
				
				set_next_pref_height(slot_size);
				set_next_pref_width(slot_size);
				set_next_border_col(ifx slot_active then WHITE else slot_border_col);
				set_next_bg_col(slot_bg_col);
				set_next_flags(.draw_bg | .draw_border);
				ui_storage_slot(tprint("hotbar_slot_%", it), *player.hotbar_slots[it], slot_icon_padding);
			}
		}
		
		spacer(em(1));
		
		// inventory slots
		{
			push_opacity(app.inventory_alpha);
			
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			auto_column();
			defer spacer(margin);
			
			ROW_LENGTH :: 5;
			
			slot_count := 0;
			for row : 0..player.storage_slot_count / ROW_LENGTH
			{
				if row != 0 then spacer(slot_spacing);
				
				set_next_pref_height(size_by_children(1));
				set_next_pref_width(size_by_children(1));
				auto_row();
				padding(margin);
				
				for column : 1..ROW_LENGTH
				{
					defer slot_count += 1;
					if slot_count == player.storage_slot_count then break;
					
					if column != 1 then spacer(slot_spacing);
					
					set_next_pref_size(slot_size, slot_size);
					set_next_border_col(slot_border_col);
					set_next_bg_col(slot_bg_col);
					set_next_flags(.draw_bg | .draw_border);
					ui_storage_slot(tprint("inv_slot_%_%", column, row), *player.storage_slots[slot_count], slot_icon_padding);
				}
			}
		}
		
		bg_box_sig = signal_from_box(bg_box);
	}
	
	// crafting segment
	{
		push_disable_signal(!is_inventory_open);
		push_opacity(app.inventory_alpha);
		
		padding(pct_parent(1, 0));
		
		// parent bg box
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_opacity(app.inventory_alpha);
		// set_next_bg_col(COL_UI_BG * 0.5);
		bg_box := make_box(.clickable, "inv_crafting_box");
		push_parent(bg_box);
		
		set_next_pref_width(slot_size);
		set_next_pref_height(size_by_children(1));
		auto_column();
		
		// scroll up n down
		if app.frame.wheel_delta < 0
		{
			g_world.crafting_slot_index += 1;
		}
		else if app.frame.wheel_delta > 0
		{
			g_world.crafting_slot_index -= 1;
		}
		
		// put all available crafting recipes in an array
		crafting_recipes : [..]ArcResource;
		crafting_recipes.allocator = temp;
		for unlocked : g_world.unlocked_recipes
			if unlocked
		{
			array_add(*crafting_recipes, get_resource(xx it_index));
		}
		
		// fix up index to be in bounds
		g_world.crafting_slot_index = clamp(g_world.crafting_slot_index, 0, crafting_recipes.count-1);
		
		count_each_side := 4;
		active_slot := g_world.crafting_slot_index;
		
		push_pref_width(slot_size);
		push_pref_height(slot_size);
		
		// scuffed terraria-like crafting list
		if crafting_recipes.count > 0
		{
			// top
			slot_count := 0;
			for active_slot-count_each_side..active_slot-1
			{
				index := it;
				if index >= 0
				{
					opacity := top_opacity();
					if slot_count == 0
					{
						opacity *= 0.5;
					}
					push_opacity(opacity);
					
					recipe_res := crafting_recipes[index];
					push_parent(make_box(.draw_bg, ""));
					box := ui_item_icon(tprint("crafting_slot_%", slot_count), recipe_res.id, 0, slot_size, slot_icon_padding);
					sig := signal_from_box(box);
					if sig.pressed
					{
						g_world.crafting_slot_index = index;
					}
					if sig.hovering
					{
						push_tooltip();
						item_tooltip(recipe_res.id);
					}
				}
				else
				{
					// dummy thing to keep layout fixed
					make_box(0, "");
				}
				slot_count += 1;
			}
			
			// slot in the middle
			{
				set_next_pref_height(slot_size);
				set_next_pref_width(size_by_children(1));
				auto_row();
				
				missing_items: [..]ItemID;
				missing_items.allocator = temp;
				
				recipe_res := crafting_recipes[g_world.crafting_slot_index];
				{
					push_parent(make_box(.draw_bg | .draw_border, ""));
					box := ui_item_icon(tprint("crafting_slot_%", slot_count), recipe_res.id, 0, slot_size, slot_icon_padding);
					sig := signal_from_box(box);
					
					// attempt to craft the item
					if sig.pressed
					{
						// do we have all the materials for the recipe?
						storage_slots := get_player_storage_slots();
						has_enough_for_recipe:= true;
						for recipe_item : recipe_res.recipe
						{
							remaining := recipe_item.amount;
							for storage_slots
							{
								en := entity_from_handle(it);
								if is_valid(en) && en.item_id == recipe_item.id
								{
									remaining -= en.item_count;
								}
							}
							if remaining > 0
							{
								has_enough_for_recipe = false;
								array_add(*missing_items, recipe_item.id);
							}
						}
						#if IGNORE_MATERIAL_COST then has_enough_for_recipe = true;
						
						can_hold_item := true;
						held_en := entity_from_handle(app.mouse_held_item);
						if is_valid(held_en) && !(held_en.item_id == recipe_res.id && held_en.item_count + 1 <= recipe_res.max_stack_size)
						{
							can_hold_item = false;
						}
						
						if can_hold_item && has_enough_for_recipe
						{
							// take away items
							#if !IGNORE_MATERIAL_COST
							for recipe_item : recipe_res.recipe
							{
								remaining := recipe_item.amount;
								for storage_slots
								{
									en := entity_from_handle(it);
									if is_valid(en) && en.item_id == recipe_item.id
									{
										remaining -= en.item_count;
										en.item_count = 0;
										
										if remaining < 0
										{
											// took too much, put it back
											en.item_count = abs(remaining);
											remaining = 0;
										}
										
										if en.item_count == 0 then en.marked_for_destroy = true;
										if remaining == 0 then break;
									}
								}
							}
							
							if is_valid(held_en)
							{
								// increment existing item stack
								held_en.item_count += 1;
							}
							else
							{
								// craft the new item and put it in our cursor
								new_item := create_world_item(recipe_res.id);
								app.mouse_held_item = handle_from_entity(new_item);
							}
							
							play_sound_old(.click_1);
						}
						else
						{
							// error sound ?
						}
					}
					
					// tooltip
					if sig.hovering
					{
						push_tooltip();
						item_tooltip(recipe_res.id);
						
						set_next_pref_size(size_by_children(1));
						auto_row();
						
						icon(.left_click_icon, "", em(1));
						
						set_next_pref_width(text_dim(1));
						set_next_pref_height(text_dim(1));
						label("craft");
					}
					
					slot_count += 1;
				}
				
				set_next_pref_height(slot_size);
				set_next_pref_width(size_by_children(1));
				set_next_bg_col(BLACK * 0.7);
				set_next_flags(.draw_bg);
				auto_row();
				
				// list out materials
				for recipe_it : recipe_res.recipe
				{
					box, icon := ui_item_icon(tprint("crafting_slot_%_material_%", slot_count, it_index), recipe_it.id, recipe_it.amount, slot_size, slot_icon_padding);
					
					// error flash
					is_missing := false;
					for missing_items
					{
						if it == recipe_it.id
						{
							is_missing = true;
							break;
						}
					}
					if is_missing then icon.target = 1.0;
					if animate_to_target(*icon.value, icon.target, delta_t(), rate=40.0) && icon.target == 1.0 then icon.target = 0;
					if icon.value != 0
					{
						icon.render_adjust_trs.scale = xy(1.0 + icon.value * 0.2);
						icon.multiply_col = lerp(WHITE, RED, icon.value);
					}
				}
			}
			
			// bottom
			for active_slot+1..active_slot+count_each_side
			{
				index := it;
				if index < crafting_recipes.count
				{
					opacity := top_opacity();
					if slot_count == count_each_side * 2
					{
						opacity *= 0.5;
					}
					push_opacity(opacity);
					
					recipe_res := crafting_recipes[index];
					push_parent(make_box(.draw_bg, ""));
					box := ui_item_icon(tprint("crafting_slot_%", slot_count), recipe_res.id, 0, slot_size, slot_icon_padding);
					sig := signal_from_box(box);
					if sig.pressed
					{
						g_world.crafting_slot_index = index;
					}
					if sig.hovering
					{
						push_tooltip();
						item_tooltip(recipe_res.id);
					}
				}
				else
				{
					// dummy thing to keep layout fixed
					make_box(0, "");
				}
				slot_count += 1;
			}
		}
	}
	
	// Cursor
	{
		item_en := entity_from_handle(app.mouse_held_item);
		
		if !is_inventory_open && is_valid(item_en) && !has_prop(item_en.props, .placeable)
		{
			item_to_drop = entity_from_handle(app.mouse_held_item);
			app.mouse_held_item = .{};
		}
		
		item_en = entity_from_handle(app.mouse_held_item);
		if is_valid(item_en)
		{
			pos := app.mouse_pos - xy(0, xx app.window_h) - xy(slot_size.value * 0.5, -slot_size.value * 0.5);
			set_next_floating_x(pos.x);
			set_next_floating_y(pos.y);
			set_next_flags(.floating | .skip_layout);
			set_next_pref_height(slot_size);
			set_next_pref_width(slot_size);
			auto_column();
			
			{
				padding(slot_icon_padding); // center vertically
				
				auto_row(pct_parent(1, 0), pct_parent(1, 0));
				padding(slot_icon_padding); // centre horizontally
				
				set_next_pref_size(pct_parent(1, 0), pct_parent(1, 0));
				icon := make_box(.draw_sprite, "");
				icon.sprite_id = item_en.sprite_id;
			}
			
			if item_en.item_count > 1
			{
				set_next_pref_size(pct_parent(1), text_dim(1));
				set_next_text_justify_x(.left);
				make_box(.draw_text | .skip_layout | .floating, tprint("%###itemcountmouse", item_en.item_count));
			}
			
			// drop held item
			if !bg_box_sig.contains && !has_prop(item_en.props, .placeable)
			{
				if key_pressed(.MOUSE_BUTTON_LEFT)
				{
					consume_key(.MOUSE_BUTTON_LEFT);
					app.mouse_held_item = .{};
					item_to_drop = item_en;
				}
			}
		}
	}
	
	// drop from Q
	if item_to_drop == null && !app.disable_player_input && is_valid(get_held_entity()) && key_pressed(#char "Q")
	{
		consume_key(#char "Q");
		item_to_drop = get_held_entity();
	}
	
	if item_to_drop
	{
		drop_item(item_to_drop);
		
		// clear slots
		for * player.storage_slots
		{
			if entity_from_handle(it) == item_to_drop
			{
				<<it = .{};
			}
		}
		for * player.hotbar_slots
		{
			if entity_from_handle(it) == item_to_drop
			{
				<<it = .{};
			}
		}
		for * player.equipped_items
		{
			if entity_from_handle(it) == item_to_drop
			{
				<<it = .{};
			}
		}
	}
}

// :item_tooltip
item_tooltip :: (item_id: ItemID)
{
	item := get_resource(item_id);
	if is_valid(item)
	{
		set_next_pref_height(text_dim(1));
		set_next_pref_width(text_dim(1));
		label("%###", get_display_name(item));
		
		if item.description != ""
		{
			set_next_font_size(font_size_pct(0.7));
			set_next_pref_height(text_dim(1));
			set_next_pref_width(text_dim(1));
			label("%###", item.description);
		}
	}
}

ui_item_icon :: (unique_name: string, item_id: ItemID, amount: int, size: Size, internal_padding: Size) -> main:*Box, icon:*Box
{
	set_next_pref_size(size);
	box := make_box(.clickable, unique_name);
	push_parent(box);
	
	icon: *Box;
	{
		padding(internal_padding); // center vertically
		
		auto_row(pct_parent(1, 0), pct_parent(1, 0));
		padding(internal_padding); // centre horizontally
		
		set_next_pref_size(pct_parent(1, 0), pct_parent(1, 0));
		icon = make_box(.draw_sprite, tprint("%_icon", unique_name));
		icon.sprite_id = get_display_sprite_id(get_resource(item_id));
	}
	
	if amount > 1
	{
		set_next_pref_size(pct_parent(1), text_dim(1));
		set_next_text_justify_x(.left);
		make_box(.draw_text | .skip_layout | .floating, tprint("%###", amount));
	}
	
	return box, icon;
}

get_item_equipped_slot :: (item_en: *Entity) -> *EntityHandle
{
	for * get_player().equipped_items
	{
		if entity_from_handle(it) == item_en then return it;
	}
	return null;
}

has_equipped_item_prop :: (prop : EntityProps) -> bool, *Entity
{
	for get_player().storage_slots
	{
		en := entity_from_handle(it);
		if !is_valid(en) then continue;
		item := get_item(en.item_id);
		if has_prop(item.props, prop) then return true, en;
	}
	return false, *nil_entity;
}

// helper funcitons for structure placement
is_existing_structure_at_point :: (point: Vector2, archetype: ResourceID) -> bool
{
	for en : g_world.entities
		if is_valid(en) && has_prop(en.props, .structure) && en.archetype == archetype
	{
		rect := rect_from_sprite(en.sprite_id);
		rect = range_shift(rect, en.pos);
		if range_contains(rect, point) then return true;
	}
	return false;
}
is_overlapping_obstacle_at_point :: (point_x: float, occupied_space := Range1.{-10, 10}, obstacle_prop_mask: Properties(EntityProps) = .{})
	-> bool, obstacles: [..]*Entity
{
	obstacles: [..]*Entity;
	obstacles.allocator = temp;
	for * en : g_world.entities
		if is_valid(en) && has_prop(en.props, .placement_obstacle) && en.biome == g_world.player_biome
	{
		r1 :Range1 = range_shift(en.occupied_space, en.pos.x);
		r2 :Range1 = range_shift(occupied_space, point_x);
		if range_collide(r1, r2)
		{
			array_add(*obstacles, en);
		}
	}
	return obstacles.count > 0, obstacles;
}
snap_to_closest_point :: (snaps: []Vector2, current_point: Vector2, $check_for_obstacles := true)
	-> point_found: bool, point: Vector2, obstacles: [..]*Entity #expand
{
	snap_radius := `snap_radius;
	
	closest_dist := FLOAT32_INFINITY;
	point:= current_point;
	obstacles: [..]*Entity;
	for snaps
	{
		dist := distance(it, current_point);
		if dist < snap_radius && dist < closest_dist
		{
			point = it;
			closest_dist = dist;
			
			#if check_for_obstacles
			{
				is_overlapping, obst := is_overlapping_obstacle_at_point(it.x);
				if is_overlapping
				{
					obstacles = obst;
				}
			}
		}
	}
	
	return closest_dist != FLOAT32_INFINITY, point, obstacles;
}

structure_placement :: ()
{
	held_en := ifx is_valid(app.mouse_held_item) then entity_from_handle(app.mouse_held_item) else get_held_entity();
	held_item := get_resource(held_en.item_id);
	if has_prop(held_en.props, .placeable)
	{
		app.placement_alpha_t = 1.0;
	}
	else
	{
		app.placement_alpha_t = 0.0;
	}
	animate_to_target(*app.placement_alpha, app.placement_alpha_t, delta_t(), rate=UI_ANIMATE_RATE);
	
	is_placing := app.placement_alpha_t == 1.0;
	if is_placing
	{
		app.show_cursor = true;
		
		if has_prop(held_en.props, .flippable)
		{
			if app.frame.wheel_delta
			{
				app.placement_x_dir *= -1;
			}
			
			// flip icon
			set_next_floating_x(app.mouse_pos.x);
			set_next_floating_y(world_pos_to_screen(xy(0, -10)).y);
			set_next_flags(.floating);
			set_next_rect_pivot_x(.center);
			icon(.middle_mouse_flip_icon, "", em(1.5));
		}
		else
		{
			app.placement_x_dir = 1;
		}
		
		pos: Vector2 = xy(mouse_pos_in_world().x, 0);
		
		// snap 'er into a good spot depending on what we've got in our hands
		snap_radius :: 4.0;
		snap_points: [..]Vector2;
		overlapped_obstacles: [..]*Entity;
		overlapped_obstacles.allocator = temp;
		is_valid_spot : bool;
		if held_item.placement_kind ==
		{
			case;
			assert(false, "unimplemented placement_kind %", held_item.placement_kind);
			
			case .free;
			// place anywhere it doesn't overlap with something else
			is_overlapping, overlapped_obstacles= := is_overlapping_obstacle_at_point(pos.x);
			is_valid_spot = !is_overlapping;

			//
			//
			//
			case .back_wall;
			// snap points to either side of existing walls
			wall_count : int;
			for en : g_world.entities
				if is_valid(en) && has_prop(en.props, .structure) && en.archetype == .back_wall && en.biome == g_world.player_biome
			{
				wall_count += 1;
				wall_size := get_sprite_size(.wood_wall);
				pos: Vector2;
				
				// left side
				pos = en.pos - xy(wall_size.x, 0);
				if !is_existing_structure_at_point(pos, .back_wall)
				{
					array_add(*snap_points, pos);
				}
				
				// right side
				pos = en.pos + xy(wall_size.x, 0);
				if !is_existing_structure_at_point(pos, .back_wall)
				{
					array_add(*snap_points, pos);
				}
			}
			
			is_valid_spot = true;
			
			// snappy
			snap_found:, pos = snap_to_closest_point(snap_points, pos, check_for_obstacles=false);
			
			if !snap_found
			{
				// free place
				
				wall_range := Range1.{get_sprite(.wood_wall).rect.min.x, get_sprite(.wood_wall).rect.max.x};
				
				// check for existing walls
				for * en : g_world.entities
					if is_valid(en) && has_prop(en.props, .structure) && en.archetype == .back_wall && en.biome == g_world.player_biome
				{
					r1 :Range1 = range_shift(wall_range, en.pos.x);
					r2 :Range1 = range_shift(wall_range, pos.x);
					if range_collide(r1, r2)
					{
						array_add(*overlapped_obstacles, en);
					}
				}
				
				if overlapped_obstacles.count > 0
				{
					is_valid_spot = false;
				}
			}
			
			
			//
			//
			//
			case .side_wall;
			// snap points at the edge of each back wall
			for en : g_world.entities
				if is_valid(en) && has_prop(en.props, .structure) && en.archetype == .back_wall && en.biome == g_world.player_biome
			{
				wall_size := get_sprite_size(.wood_wall);
				pos: Vector2;
				
				// left side
				pos = en.pos - xy(wall_size.x * 0.5, 0);
				if !is_existing_structure_at_point(pos, .side_wall)
				{
					array_add(*snap_points, pos);
				}
				
				// right side
				pos = en.pos + xy(wall_size.x * 0.5, 0);
				if !is_existing_structure_at_point(pos, .side_wall)
				{
					array_add(*snap_points, pos);
				}
			}
			
			// snappy
			has_snap:, pos=, overlapped_obstacles= snap_to_closest_point(snap_points, pos, check_for_obstacles=true);
			is_valid_spot = has_snap && overlapped_obstacles.count == 0;
		}
		
		// invalid UX
		if !is_valid_spot
		{
			// make all overlapped thingos red so it's clear what the problem is
			for en : overlapped_obstacles
			{
				en.frame.colour_multiplier = RED;
			}
		}
		
		// ghost preview of placing item
		{
			// do a dummy setup so we can get the values we're after
			dummy_entity : Entity;
			held_item.setup_func(*dummy_entity);
			
			col := ifx is_valid_spot then WHITE else RED;
			col.w = 0.7;
			
			flags : QuadFlags = ifx app.placement_x_dir == -1 then .x_flipped;
			
			draw_sprite(dummy_entity.sprite_id, pos, flags=flags, z_layer=dummy_entity.z_layer, col=col);
		}
		
		// click to place
		if is_valid_spot && key_pressed(.MOUSE_BUTTON_LEFT)
		{
			en := create_entity();
			held_item.setup_func(en);
			en.x_dir = app.placement_x_dir;
			en.pos = pos;
			en.biome = g_world.player_biome;
			// add_props(*ghost_en.props, .placed_by_player);
			
			play_random_sound_old("build", 2, volume=0.6);
			
			held_en.item_count -= 1;
			if held_en.item_count <= 0
			{
				held_en.marked_for_destroy = true;
			}
		}
		
		consume_key(.MOUSE_BUTTON_LEFT);
	}
}

// particle system

ParticleFlags :: enum
{
	valid 			:: (1<<0);
	fade_in 	:: (1<<1);
	fade_out :: (1<<2);
	
	animate_sprite :: (1<<20);
	loop 										:: (1<<21);
	paused 								:: (1<<22);
}

Particle :: struct
{
	pos: Vector2;
	vel: Vector2;
	col: Vector4;
	z_layer: float;
	time_left: float;
	pivot: Pivot = .center_center;
	trs: Transform2;
	flags: ParticleFlags;
	sprite: string;
	animation_frame: int;
	time_til_next_frame: float;
	play_rate: float;
}

new_particle :: () -> *Particle
{
	app.particle_cursor = (app.particle_cursor + 1) % app.particles.count;
	p := *app.particles[app.particle_cursor];
	<<p = .{};
	p.flags |= .valid;
	return p;
}

create_emitter :: (pos: Vector2, kind: EmitterKind) -> *Entity
{
	en := create_entity("", g_world.player_biome);
	add_props(*en.props, .particle_emitter, .render_sprite);
	en.pos = pos;
	en.emitter = kind;
	return en;
}

EmitterKind :: enum
{
	nil;
	
	jump_dust;
	landing_dust;
	void_ambiance;
	death_poof;
	single_poof;
	parry;
	
	// :particles
}

update_particle_system :: ()
{
	push_random_seed(get_chaos_seed());
	
	// emitters
	for * en : app.world.entities if is_valid(en) && has_prop(en.props, .particle_emitter)
	{
		if en.emitter ==
		{
			case;
			log("Emitter not selected.");
			
			case .parry;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos;
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "p_parry";
			p.z_layer = Z_ENTITY_VFX;
			p.play_rate = 20;
			
			case .single_poof;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos;
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.vel = xy(random_get_within_range(-5, 5), random_get_within_range(0, 2));
			p.sprite = "p_poof";
			p.z_layer = Z_ENTITY_VFX;
			p.play_rate = random_get_within_range(4, 15);
			
			case .death_poof;
			en.marked_for_destroy = true;
			for 0..2
			{
				x_offset := (it - 1) * 10.0;
				p := new_particle();
				p.pos = en.pos + xy(x_offset, random_get_within_range(0, 3));
				p.col = WHITE;
				p.flags |= ParticleFlags.animate_sprite;
				p.vel = xy(random_get_within_range(-5, 5), random_get_within_range(0, 2));
				p.sprite = "p_poof";
				p.z_layer = Z_ENTITY_VFX;
				p.play_rate = random_get_within_range(4, 15);
			}
			
			case .jump_dust;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos;
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.vel = xy(0, 40);
			p.sprite = "p_upwards";
			p.z_layer = Z_ENTITY_VFX;
			p.pivot = .bottom_center;
			
			case .landing_dust;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos;
			p.vel = en.velocity;
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "p_ground";
			p.z_layer = Z_ENTITY_VFX;
			p.pivot = .bottom_center;
			
			case .void_ambiance;
			if tick_on_app_frequency(0.5)
			{
				p := new_particle();
				p.col = WHITE;
				p.time_left = 10;
				p.flags |= ParticleFlags.fade_in | .fade_out | .animate_sprite;
				p.sprite = "p_parry";
			}
		}
	}
	
	// particles
	for * p : app.particles
	{
		// integrate
		p.pos += p.vel * delta_t_scaled();
		
		// tick down time
		if p.time_left != 0
		{
			p.time_left -= delta_t_scaled();
			if p.time_left < 0
			{
				<<p = .{};
			}
		}
		
		// :animate
		// This is basically a stripped down version of the entity animation update function
		// Since these are particles we needa keep it lightweight - randy, 29th of September 2023
		if p.flags & .animate_sprite
		{
			sprite := get_sprite_from_name(p.sprite);
			
			// get default playrate from sprite if we don't have one specified
			if p.play_rate == 0 then p.play_rate = sprite.frame_duration_ms[0]; // broken
			
			// start of new frame
			if p.time_til_next_frame == 0
				&& !(p.flags & .paused)
			{
				p.time_til_next_frame = 1.0 / p.play_rate;
			}
			
			// advance timer
			if tick_timer(*p.time_til_next_frame, delta_t_scaled())
			{
				p.animation_frame += 1;
				
				// end of animation
				if p.animation_frame == sprite.frame_count
				{
					if p.flags & .loop
					{
						p.animation_frame = 0;
					}
					else
					{
						<<p = .{};
					}
				}
			}
		}
		
		// render
		if p.flags & .valid
		{
			if p.sprite == ""
			{
				draw_rect(make_range(xy(1, 1), shifter=p.pos), col=p.col, trs=p.trs, z_layer=p.z_layer);
			}
			else
			{
				sprite := get_sprite_from_name(p.sprite);
				uv_rect := sprite.rect;
				uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * p.animation_frame, 0.0));
				uv_rect.min.x /= sprite.width;
				uv_rect.min.y /= sprite.height;
				uv_rect.max.x /= sprite.width;
				uv_rect.max.y /= sprite.height;
				
				rect: Range2;
				rect.max = range_size(sprite.rect);
				rect = range_pivot(rect, p.pivot);
				
				draw_rect(rect, texture=texture_from_sprite(sprite), uv_rect=uv_rect, z_layer=p.z_layer, trs=merge_transform(p.trs, make_transform(p.pos)));
			}
		}
	}
}


BiomeType :: enum u32
{
	INITIAL;
	OTHER;
	COUNT;
}

#import "Basic";
#import "Math";
#import "Window_Creation";
#import "Sort";
#import "String";
#import "System";
#import "File";
#import "Wav_File";
#import "Random";
#import "Thread";
#import "Compiler";
#import "Hash";
#import "Hash_Table";
#import "Program_Print";
#import "Bit_Operations";
#import "Machine_X64";
#import "Process";
Input :: #import "Input";
Windows :: #import "Windows";
#import,file "../../../external/windows_extra.jai";

// lol this is a fucking mess

// note(amelie): COCK IMPORTS
#load "cock/kernel.jai";
#load "cock/arena.jai";

// #import "MetaDesk";
// #load "../../../external/MetaDesk/metadesk_helpers.jai";

#load "resource.jai";

#load "../../../recycle/imui.jai";

#load "config.jai";

#import,file "../../../recycle/recycle.jai";
#load "sound.jai";
#load "render.jai";
#load "../../../recycle/cereal.jai";
#load "linked.jai";

#import "tracy"(IMPORT_MODE=.CLIENT, ENABLED=PROFILE_PERFORMANCE);
