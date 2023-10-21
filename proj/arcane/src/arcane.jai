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
	// randy: NOTE - this now does nothing, since we're
	// showing cursor always
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
	frame_stepping := false;
	lines: [1024] Line;
	using debug_config: DebugConfig;
	expander_world_gen: bool;
	expander_dumpy: bool = true;
	expander_spawn: bool;
	spawn_entity_option: SpriteID = .gob_idle;

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
	build_mode_alpha: float;
	build_mode_alpha_t: float;
	// transient interface state
	active_workbench: EntityHandle;
	placement_x_dir:= 1;
	mouse_held_item: EntityHandle;
	crafting_slot_index: int = 0;
	blueprint_slot_index: int = 0;
	active_blueprint_id: ItemID;
	
	view_matrix: Matrix4;
	
	frame: FrameStorage; // gets zeroed each frame
	last_frame: FrameStorage;
	FrameStorage :: struct
	{
		key_pressed: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
		key_released: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
		wheel_delta: s32;
		mouse_delta: Vector2;
		hot_interactable: EntityHandle;
		hot_blueprint: EntityHandle;
		hovered_interactable: EntityHandle;
		tried_to_place_but_failed: bool;
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
	base_totem_handle: EntityHandle;
	player_handle: EntityHandle;

	// Biomes
	open_biome: BiomeType;
	player_biome: BiomeType;
	
	// cycle / wave stuff
	day_cycle: float = INITIAL_DAY_START_TIME;
	night_started: bool;
	day_started: bool;
	days_survived: int= INITIAL_DAYS_SURVIVED;
	enemies : [128]EntityHandle; // TODO - @linked list rework so this is serialisable
	spawn_timer: float;
	spawn_counter: int;
	boss_spawned: bool;
	
	//
	// PLAYER state stuff
	//
	unlocked_recipes: [AppState.resources.count]bool;
	known_items: [AppState.resources.count]bool;
	respawn_timer: float;
	auto_pickup_items: bool = AUTO_PICKUP_ITEMS;
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
			app.last_frame = app.frame;
			app.frame = .{};
		}
		
		context.allocator = frame_allocator;
		
		sound_update();
		
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
		animate_to_target(*app.world_alpha, app.world_alpha_t, delta_t(), rate=15);
		
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
			storage_ui();
			inventory_ui();
			build_mode_ux();
			structure_placement();
			
			// UPDATE
			// Always update the starting biome
			// update_corefire();
			update_items();
			update_ground_torches();
			update_campfires();
			update_crops();
			update_animations();
			ai_update();
			player_update();
			gobby_update();
			ogre_update();

			skele_update();
			#if ROB_TESTING
			{
				update_spells();
				ifx app.debug_config.rob_test then mage_update();
				//grid_entity_update();
			}
			boss_altar_update();
			boss_update();
			physics_update();
			projectile_update(); // after physics because they fly
			update_defense_walls();
			update_trap();
			update_blueprints();
			update_base_totem(entity_from_handle(g_world.base_totem_handle));
			update_portals(); // after physics bc we need to know how far the player travelled this frame
			update_trees();
			update_rock_deposits();
			update_and_apply_effects();
			recieve_damage();
			dmg_indicator_update();
			update_particle_system();
			update_point_lights();
			update_recipe_unlocks();
			
			app.camera = update_camera(app.camera, get_player());
			
			// destroy entities that're marked
			for * g_world.entities if is_valid(it) && it.marked_for_destroy
			{
				entity_destroy_immediate(it);
			}

			for * en : g_world.entities if is_visible(en)
			{
				// update damage alpha
				if en.damage_alpha != 0
				{
					tick_timer(*en.damage_alpha, delta_t_scaled() * 10.0);
				}
				
				if en.animate_render_offset_to_target
				{
					// animate render offset to target
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
		}
		
		// :hud
		// this should only change state in a few places: UI, submitting to the render,
		// and potentially app settings, ie - we remeber what page book we're on, etc
		hud_item_blueprint(g_world);
		hud_consume_item(g_world);
		hud_entity_health_bars(g_world);
		hud_tooltips(g_world);
		hud(g_world);
		
		render_base_hud();
		
		//Edge-fading
		{
			//NOTE(fhomolka): This fading stuff probably has a better place
			//				  But i put it here, because i know it'll not get removed by pausing
			FADE_DISTANCE :: 50.0;
			dist_to_edge := WORLD_RADIUS - abs(get_player().pos.x);
			if dist_to_edge <= FADE_DISTANCE
			{

				DRAW_RECT_FADE :: true;
				#if DRAW_RECT_FADE
				{
					opacity := 1.0 - (dist_to_edge / FADE_DISTANCE);
					
					window_range: Range2 = Range2.{-WORLD_DIAMETER, -WORLD_DIAMETER, WORLD_DIAMETER, WORLD_DIAMETER};
					color := Vector4.{0.0, 0.0, 0.0, opacity};

					draw_rect(window_range, col=color, z_layer=Z_EDGE_FADE);
				}
				else
				{
					opacity := 1.0 - (dist_to_edge / FADE_DISTANCE);
					push_opacity(opacity);
					set_next_pref_width(px(xx app.window_w));
					set_next_pref_height(px(xx app.window_h));
					make_box(.floating | .draw_bg, "");
				}
			}
		}

		{
			// profile_block("render");
			render_world_from_state(g_world);
		}
		
		if g_world.simulating
		{
			memory_zero(*app.world.events_this_frame);
			
			// core entity update
			for * g_world.entities if is_valid(it)
			{
				it.time_alive += delta_t_scaled();
				
				// clear entity's frame state
				it.frame.pos = it.pos;
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
	swap_n_reset_frame_arenas();
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
		// randy:  commented out for now since it's annoying. Who tf doesn't play in fullscreen anyway?
		/*
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
		*/
		
		// match the actual cursor state to our derivative
		/*
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
		*/
		
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
	
	// ui setup and default values
	ui_start();
	_push_fill_col(COL_UI_FILL);
	_push_text_col(COL_UI_TEXT);
	_push_bg_col(COL_UI_BG);
	_push_border_col(COL_UI_BORDERS);
	
	_push_font(FONT_SUB);
	_push_font_size(app.debug_config.ui_font_size);
	_push_text_edge_pad(10);
	_push_pref_width(pct_parent(1.0, 0.0));
	_push_pref_height(em(1.5));
	
	// display debug
	#if SHOW_DIAGNOSTICS
	{
		set_next_pref_width(px(xx app.window_w, 0));
		set_next_pref_height(px(xx app.window_h, 0));
		set_next_child_layout_axis(.X);
		push_parent(make_box(.floating, ""));
		spacer(pct_parent(1, 0));
		
		set_next_child_layout_axis(.Y);
		set_next_pref_height(pct_parent(1));
		set_next_pref_width(size_by_children(1));
		push_parent(make_box(0, ""));
		
		spacer(pct_parent(1, 0));
		
		push_pref_width(em(3));
		push_pref_height(em(1));
		push_text_justify_x(.left);
		
		label("%###", app.fps);
		
		last_frame_length := cast(float) (app.frame_start_time - app.last_frame_start_time) / app.rdtsc_frequency;
		label("%###", float_to_string(last_frame_length * 1000, decimals=2));
		
		label("%###", VERSION);
	}
	
	#if DEBUG // :debug
	{
		fun_val += app.frame.mouse_delta.x / 100;
		
		// debug text
		// label("%", get_player().state);
		
		
		
		// randy: I needed it to be this because I've got global AHK overrides for alt + l
		if app.app_mode == .world && app.frame.key_pressed[#char "R"] && key_down(.SHIFT) && key_down(.ALT)
		{
			consume_key(#char "R");
			world_load();
		}
		
		// speed up timescale for testing
		if app.frame.key_pressed[#char "G"] && key_down(.ALT)
		{
			consume_key(#char "G");
			SPEED_X :: 5.0;
			if almost_equals(g_world.time_scale, SPEED_X)
			{
				g_world.time_scale = 1.0;
			}
			else
			{
				g_world.time_scale = SPEED_X;
			}
		}
		
		// reset g_world
		if app.app_mode == .world && app.frame.key_pressed[#char "R"] && key_down(.ALT)
		{
			consume_key(#char "R");
			world_reset();
		}

		if app.app_mode == .world && app.frame.key_pressed[#char "L"] && key_down(.ALT)
		{
			consume_key(#char "L");
			world_load();
		}

		if app.app_mode == .world && app.frame.key_pressed[#char "S"] && key_down(.ALT)
		{
			consume_key(#char "S");
			serialise_world(g_world);
		}
		
		// biome switching
		if app.frame.key_pressed[#char "1"] && key_down(.CTRL)
		{
			consume_key(#char "1");
			app.world.player_biome = BiomeType.INITIAL;
			get_player().biome = BiomeType.INITIAL;
		}
		else if app.frame.key_pressed[#char "2"] && key_down(.CTRL)
		{
			consume_key(#char "2");
			app.world.player_biome = BiomeType.OTHER;
			get_player().biome = BiomeType.OTHER;
		}
		
		// scuffed debug stepping
		if app.frame_stepping
		{
			g_world.simulating = false;
			
			if key_down(#char "`")
			{
				g_world.simulating = true;
			}
			
			if key_pressed(.ESCAPE)
			{
				consume_key(.ESCAPE);
				g_world.simulating = true;
				app.frame_stepping = false;
			}
		}
		else
		{
			if key_pressed(#char "`")
			{
				g_world.simulating = false;
				app.frame_stepping = true;
			}
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
		
		// debug collision boxes
		if app.debug_config.draw_collision_boxes
		for * en: app.world.entities if is_valid(en)
			&& (en.collision_rect.min != .{} || en.collision_rect.max != .{})
		{
			debug_rect(get_collision_rect(en), 1);
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
			app.expander_spawn = ui_expander(app.expander_spawn, "Manual Spawn");
			if app.expander_spawn
			{
				set_next_pref_height(size_by_children(1));
				auto_row();
				spacer(em(1.5));
				set_next_pref_height(size_by_children(1));
				auto_column();

				en : *Entity;			
				if button("Spawn Gobby").clicked
				{	if app.debug_config.rob_test
					{
						app.spawn_entity_option = .gob_idle;
					}
					else
					{
						en = create_gobby(false);
						en.pos.x = get_player().pos.x + 200;
						
					}
				}
				if button("Spawn GobMage").clicked
				{
					if app.debug_config.rob_test
					{
						app.spawn_entity_option = .gob_mage_idle;
					}
					else
					{
						en = create_mage();
						en.pos.x = get_player().pos.x + 200;
						add_props(*en.props, .enabled, .valid);
					}
				}
				if button("Spawn Ogre").clicked
				{
					if app.debug_config.rob_test
					{
						app.spawn_entity_option = .ogre_idle;
					}
					else {
						en = create_ogre();
						en.pos.x = get_player().pos.x + 200;
						array_add(g_world.enemies, handle_from_entity(en));
					}
				}
				if button("Spawn Heavy Gob").clicked
				{
					if app.debug_config.rob_test
					{
						app.spawn_entity_option = .gob_heavy_idle;
					}
					else{
						en = create_gobby(true);
						en.pos.x = get_player().pos.x + 200;
						array_add(g_world.enemies, handle_from_entity(en));
					}
				}
				if button("Spawn Smelly Skelly").clicked
				{
					if app.debug_config.rob_test
					{
						app.spawn_entity_option = .skele_idle;
					}
					else
					{
						en = create_skele();
						en.pos.x = get_player().pos.x + 200;
						array_add(g_world.enemies, handle_from_entity(en));
					}
				}
			}
			label("Monsters");
			//label("Cnt: %###", g_world.enemies.count);
		}
	}
		//Make a mouse spawner
		if app.debug_config.rob_test
		{	
			quad_ := draw_sprite(app.spawn_entity_option, mouse_pos_in_world(), make_transform(xy(0), scale = 0.7));
			quad_.col.w = 0.4;
			if key_pressed(.MOUSE_BUTTON_RIGHT)
			{
				if app.spawn_entity_option ==
				{
					case .gob_idle;
					en := create_gobby(false);
					en.pos = mouse_pos_in_world();
					case .gob_mage_idle;
					en := create_mage();
					en.pos = mouse_pos_in_world();
					case .gob_heavy_idle;
					en := create_gobby(true);
					en.pos = mouse_pos_in_world();
					case .ogre_idle;
					en := create_ogre();
					en.pos = mouse_pos_in_world();
					case .skele_idle;
					en := create_skele();
					en.pos = mouse_pos_in_world();
				}

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

// :imports
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

// #import "MetaDesk";
// #load "../../../external/MetaDesk/metadesk_helpers.jai";

#load "resource.jai";

#load "../../../recycle/imui.jai";
#load "../../../recycle/arena.jai";

#load "config.jai";

#import,file "../../../recycle/recycle.jai";
#load "sound.jai";
#load "render.jai";
#load "../../../recycle/cereal.jai";
#load "linked.jai";
#load "log.jai";

#import "tracy"(IMPORT_MODE=.CLIENT, ENABLED=PROFILE_PERFORMANCE);

// :portal
// The portal is anchored / visible in both the original world, and wherever it leads.
// I find it kinda cool the fact that it isn't a copy and is physically the same in both places
// at the same time lol. MAGIC.
//
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
	add_props(*en.props, .portal, .interactable, .structure);
	en.item_id = .portal;
	en.z_layer = Z_PORTAL;
	entity_set_sprite(en, .portal_off);
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
	player := get_player();
	
	if en.state == .on
	{
		en.sprite_id = .portal_on;
		
		// when the player crosses over the spot where the portal is, teleport
		range_travelled := make_range(player.last_frame.pos.x, player.pos.x);
		if range_contains(range_travelled, en.pos.x)
		{
			if app.world.player_biome == .INITIAL
			{
				app.world.player_biome = .OTHER;
				player.biome = .OTHER;
			}
			else
			{
				app.world.player_biome = .INITIAL;
				player.biome = .INITIAL;
			}
		}
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



MAX_TRAUMA :: 0.6;
Camera2 :: struct
{
	position: Vector2;
	target_position: Vector2;
	zoom: float = DEFAULT_ZOOM;
	target_zoom: float = DEFAULT_ZOOM;
	trauma: float;
}

camera_shake :: (amount: float)
{
	cam := *app.camera;
	cam.trauma += amount;
}

// radius is the distance it'll shake at the specified amount
// falloff_distance is the distance that it'll slowly fall off after the radius
camera_shake_at_pos :: (amount: float, source_position: Vector2, radius: float, falloff_distance: float, $log_trauma:=false)
{
	cam := *app.camera;
	
	source := source_position.x;
	cam_centre := get_player().pos.x; // randy: TODO - actually make this the camera position
	trauma := amount;
	
	dist_to_source := abs(cam_centre - source);
	x_dir := sign(cam_centre - source);
	
	if dist_to_source > radius
	{
		point_a := source + radius * x_dir;
		point_b := source + (radius + falloff_distance) * x_dir;
		
		// randy: just linear for now, but you could plug in an ease here if it's needed?
		falloff_alpha := 1.0-float_alpha(cam_centre, point_a, point_b);
		
		trauma *= falloff_alpha;
	}
	
	#if log_trauma then log("trauma: %", trauma);
	cam.trauma += trauma;
}

teleport_player_and_camera :: (pos: Vector2)
{
	get_player().pos = pos;
	app.camera.target_position = pos;
	app.camera.position = pos;
}

update_camera :: (current_cam: Camera2, player: Entity) -> Camera2
{
	camera := current_cam;
	
	// target to player
	// randy: we could also add some additional targets in here in future to weight the camera around
	camera.target_position.x = player.pos.x;
	
	// randy: this feels to jarring
	// target out in front of player
	// if player.x_speed_target != 0
	// {
	// 	offset_in_front :float= player.x_speed_target * player.x_dir * 0.5;
	// 	camera.target_position.x -= offset_in_front;
	// }
	
	//camera.target_zoom = window_h / scene_height * ifx k_key_debug then 1.4 else 1.0;
	
	camera.trauma = clamp_top(camera.trauma, MAX_TRAUMA);
	
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
	
	// animate pos to target
	animate_to_target(*camera.position, camera.target_position, delta_t_scaled());

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
	if slot_signal.pressed
	{
		play_sound_global("item_click");
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
			label(item.consume_verb);
			
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

// :blueprint

is_blueprint :: (en: Entity) -> bool
{
	return has_prop(en.props, .blueprint);
}

// turns an existing structure that's been setup, into a blueprint
convert_to_blueprint :: (en: *Entity)
{
	reset_entity_props(en);
	add_props(*en.props, .render_sprite, .blueprint, .interactable, .structure);
	
	item_res := get_resource(en.item_id);
	assert(is_valid(item_res), tprint("No item id found when trying to convert blueprint? Can't infer the recipe from %", en.item_id));
	array_copy(en.remaining_items, item_res.recipe);
}

input_attempt_blueprint :: (en: *Entity) -> bool
{
	can_interact:= false;
	
	// see if there's anything we can take from the inventory
	for get_entity_storage_slots(get_player())
	{
		item := get_resource(entity_from_handle(it).item_id);
		if !is_valid(item) then continue;
		
		for en.remaining_items
			if it.id == item.id && it.id != .nil && it.amount > 0
		{
			can_interact = true;
			break;
		}
	}
	#if IGNORE_MATERIAL_COST { can_interact = true; }
	
	// do the actual interaction
	if can_interact && key_pressed(#char "E")
	{
		consume_key(#char "E");
		struc := get_item(en.item_id);
		
		// for each item in inv, try and subtract it from the reamining items in the blueprint
		for stored : get_entity_storage_slots(get_player())
		{
			if !is_valid(stored) then continue;
			item_en := entity_from_handle(stored);
			stored_item := get_item(item_en.item_id);
			
			used := false;
			for * remaining : en.remaining_items
				if remaining.id == stored_item.id && remaining.id != .nil && remaining.amount > 0
			{
				remaining.amount 	-= 1;
				item_en.item_count -= 1;
				if item_en.item_count == 0
				{
					item_en.marked_for_destroy = true;
				}
				used = true;
				break;
			}
			if used then break;
		}
		
		// is the bp done?
		has_items_remaining := false;
		for en.remaining_items
		{
			if it.amount != 0
			{
				has_items_remaining = true;
				break;
			}
		}
		
		if !has_items_remaining || IGNORE_MATERIAL_COST
		{
			new_event(.{kind=.build, entity=handle_from_entity(en)});
			play_sound("struc_finish", en.pos);
			play_sound("struc_hammer", en.pos);
			
			// build entity
			reset_entity_props(en);
			get_item(en.item_id).setup_func(en);
		}
		else
		{
			play_sound("struc_hammer", en.pos);
		}
	}
	
	return can_interact;
}

update_blueprints :: ()
{
	for * en : g_world.entities
		if is_valid(en) && is_blueprint(en)
	{
		// idk why I set this up lol
	}
}

render_blueprint :: (en: Entity)
{
	item_res := get_resource(en.item_id);
	assert(is_valid(item_res), "no item_id found, yet we're a blueprint? Did ya forget to set it in the setup func?");
	
	// ghost background
	quad := draw_generic_entity(en);
	apply_quad_adjustments_from_entity(quad, en);
	// bp colour override
	quad.col *= xyzw(0.5, 0.5, 1.0, ifx has_prop(item_res.props, .more_transparent) then 0.4 else 0.75);
	quad.layer_cbuffer.colour_override = WHITE;
	quad.layer_cbuffer.colour_override_amount = 0.3;
	
	// this basically means we're a world-item, so we don't wanna do any extra rendering on top
	// randy: probs not needed anymore now that we can't actually have bps in our inv?
	/*
	if !has_prop(en.props, .placed_by_player)
	{
		// kinda scuffed but does the tricks
		return;
	}
	*/
	
	// render the scaffolding that gets completed piece by piece on top
	scaffolding_res := get_resource(item_res.scaffolding_id);
	if is_valid(scaffolding_res) && (scaffolding_res.flags & .sprite)
	{
		// calculate which frame of the scaffolding animation we should be on
		total_count := 0;
		actual_count := 0;
		for recipe_item : item_res.recipe
		{
			total_count += recipe_item.amount;
			actual_count += recipe_item.amount - en.remaining_items[it_index].amount;
		}
		
		// ideally we try and match the building animation to the amount of materials we need,
		// but ehhh we caveman fallback if not perfect and just do the final X amount based on how many
		// frames in the animation so it feels kinda meaty.
		frame := max(0, 1+scaffolding_res.frame_count-cast(int)(total_count-actual_count));
		if frame != 0
		{
			draw_sprite(scaffolding_res.id, en.pos, animation_index=frame-1, z_layer=en.z_layer-0.01);
		}
	}
}

hud_item_blueprint :: inline (world : WorldState)
{
	for en : world.entities
		if is_visible(en) && (has_prop(en.props, .blueprint) || has_prop(en.props, .attack_target))
	{
		is_hot := en.id == app.frame.hot_blueprint.entity_id; // MAN IS HAWT
		
		blueprint_alpha_t := ifx is_hot then 1.0 else 0.0;
		
		sprite := get_sprite(en.sprite_id);
		
		// push into the correct space
		push_parent(ui.frame.root); // this makes us skip past the usual root :screen_space
		push_quad_flags(0); // removes the default .skip_camera_transform, kinda sketch lol
		
		p := make_box(0, tprint("bp_hud_%", en.id));
		push_parent(p);
		animate_to_target(*p.value, blueprint_alpha_t, delta_t(), rate = 20);
		blueprint_alpha := p.value;
		
		if blueprint_alpha == 0 then continue;
		
		push_opacity(blueprint_alpha);
		
		// defaults
		push_font(FONT_MAIN);
		push_font_size(10);
		push_text_justify_x(.center);
		push_pref_width(em(2));
		push_pref_height(em(1));
		
		// container for ui
		set_next_floating_x(en.pos.x);
		set_next_floating_y(en.pos.y - 5 - 5 * (1-blueprint_alpha));
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
			if remaining.amount <= 0 then continue; //TODO(fhomolka): Exclude from blueprints?
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

hud_consume_item :: inline (world : WorldState)
{
	for en : world.entities
		if is_visible(en) && has_prop(en.props, .interactable)
	{
		is_hot := en.id == app.frame.hot_interactable.entity_id; // MAN IS HAWT
		
		alpha_t := ifx is_hot && en.about_to_consume_item != .nil then 1.0 else 0.0;
		
		// push into the correct space
		push_parent(ui.frame.root); // this makes us skip past the usual root :screen_space
		push_quad_flags(0); // removes the default .skip_camera_transform, kinda sketch lol
		
		p := make_box(0, tprint("consume_item_%", en.id));
		push_parent(p);
		animate_to_target(*p.value, alpha_t, delta_t(), rate = 20);
		alpha := p.value;
		
		if alpha == 0 then continue;
		
		push_opacity(alpha);
		
		// defaults
		push_font(FONT_MAIN);
		push_font_size(10);
		push_text_justify_x(.center);
		push_pref_width(em(2));
		push_pref_height(em(1));
		
		// container for ui
		set_next_floating_x(en.pos.x);
		set_next_floating_y(en.pos.y - 5 - 5 * (1-alpha));
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_child_layout_axis(.X);
		set_next_fill_col(xyzw(0, 0, 0, 0.5));
		set_next_rect_pivot_x(.center);
		set_next_rect_pivot_y(.top);
		row := make_box(BoxFlags.floating, "");
		push_parent(row);
		
		icon(get_display_sprite_id(get_resource(en.about_to_consume_item)), "", em(2), horizontal_pad_pct=0.3);
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
	
	// randy: NOTE
	// G'day Filip! Here's a lil crash course on the imui.
	// I got this system from Ryan Fleury, and ik how hard it is to learn first hand (the auto-layouting side of things).
	// Once you get the hang of it though, it's extremely powerful.
	//
	// Toggle this to visualise what's happening
	// push_flags(.debug_draw);
	
	set_next_pref_width(px(xx app.window_w));
	set_next_pref_height(px(xx app.window_h));
	set_next_child_layout_axis(.Y);
	box := make_box(BoxFlags.floating, "");
	push_parent(box);
	// ^^^ we're now in a box the size of the screen
	// note that everything after here will be children of this box
	// the auto_row and auto_column also do this as well


	{
		set_next_child_layout_axis(.X);
		stats_row := make_box(.floating, "");
		push_parent(stats_row);

		spacer(pct_parent(1, 0));

		set_next_child_layout_axis(.Y);
		stats_box := make_box(0, "");
		push_parent(stats_box);

		//Hunger
		set_next_child_layout_axis(.X);
		hunger := make_box(0, "");
		push_parent(hunger);
		spacer(pct_parent(1, 0));
		label(tprint("hunger: %/%###", player.hunger, 10));
		push_parent(stats_box);

		//Health
		set_next_child_layout_axis(.X);
		health := make_box(0, "");
		push_parent(health);
		spacer(pct_parent(1, 0));
		label(tprint("health: %/%###", player.health, player.max_health));
		push_parent(stats_box);
		
		//Dash
		set_next_child_layout_axis(.X);
		dash := make_box(0, "");
		push_parent(dash);
		spacer(pct_parent(1, 0));
		label(tprint("dash: %###", 1 - player.dash_cooldown_timer / DASH_COOLDOWN));
	}
	
	// since we're on the .Y layout axis, this is an empty box that pushes us all the way down
	// it's basically sized to 100% of the screen, except the strictness value is 0. This means that
	// other things will be able to subtract their size from it, essentially cutting it away.
	// This gives the effect of everything below it being on the bottom of the screen.
	spacer(pct_parent(1, 0));
	
	// status effects row
	{
		// just put them all in a row, side by size
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(pct_parent(1)); // the whole width of the screen
		auto_row();
		spacer(pct_parent(1, 0)); // this box pushes everything to the right, like how we did out top spacer earlier
		
		for * status_effect : player.effects
		{
			// we're setting the actual size of the icons here. You'll notice that this is an actual size,
			// which essentially defines the dimensions of allll the boxes above us in an auto-layout algorithm.
			// (we've told a lot of things to size by children, these are the children)
			icon_size := em(UI_SLOT_SIZE, 1);
			set_next_pref_size(icon_size);
			if status_effect.kind == 
			{
				case .nil;
				continue;
				case .poison;
				ui_status_effect("sf_poison", .icon_poison, status_effect.length_timer);
				case .on_fire;
				ui_status_effect("sf_burning", .icon_fire, status_effect.length_timer);
			}
		}
	}
	
	// health "bar" row
	// this is just another row underneath the one above
	#if false
	{
		// we do the same "push to the right" stuff as the previous row
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(pct_parent(1));
		auto_row();
		spacer(pct_parent(1, 0));
		
		set_next_pref_width(text_dim());
		set_next_pref_height(text_dim());
		set_next_font_size(font_size_pct(1.5));
		label(tprint("health: %/%", player.health, player.max_health));
	}
}

ui_status_effect :: (unique_name_hash: string, sprite: SpriteID, duration: float)
{
	icon := make_box(.draw_sprite | .clickable | .draw_hot_effects | .draw_active_effects, unique_name_hash);
	icon.sprite_id = sprite;

	mouse_pos := screen_mouse_to_cardinal();
	mouse_hover := range_contains(icon.rect, mouse_pos);

	if !mouse_hover then return;

	push_tooltip();

	set_next_pref_height(text_dim(1));
	set_next_pref_width(text_dim(1));

	if sprite ==
	{
		case .icon_poison;
		label("Poisoned###");
		case .icon_fire;
		label("Burning###");
	}

	label("%###", duration);
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
		if is_visible(en) && has_prop(en.props, .draw_health_bar)
	{
		// todo - ideally we store some animation state in the UI box here for some juiciness
		
		if en.health == en.max_health then continue;
		
		height := range_size(get_collision_rect(en)).y + 5;
		
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

entity_health_pct :: inline (en: Entity) -> float
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
	view_matrix *= make_translation_matrix4(xyz(-app.camera.position.x, -app.camera.position.y, 0));
	
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
		offset_for_centering_on_camera := app.camera.position;
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
		
		// start cliff
		{
			draw_sprite(.start_cliff_front, xy(0, 0), z_layer=Z_FRONT_PARALLAX);
			draw_sprite(.start_cliff_core, xy(0, 0), z_layer=Z_START_CLIFF_CORE);
			draw_sprite(.start_cliff_back, xy(0, 0), z_layer=Z_TREES_1-0.5);
		}
		
		// end cliff
		{
			flags : QuadFlags;
			draw_sprite(.side_cave_playspace, xy(WORLD_RADIUS, 0), z_layer=Z_PLAYER+0.5, flags=flags);
			// could probs put a parallax on these, but cbf for now
			draw_sprite(.side_cave_mid, xy(WORLD_RADIUS, 0), z_layer=Z_FRONT_PARALLAX, flags=flags);
			draw_sprite(.side_cave_front, xy(WORLD_RADIUS, 0), z_layer=Z_FRONT_PARALLAX-0.1, flags=flags);
		}
		
		// border markers
		// draw_sprite(.nil, xy(WORLD_RADIUS, 0));
		// draw_sprite(.nil, xy(-WORLD_RADIUS, 0));
	}

	// :render generic entities
	if app.world_alpha != 0
	{
		for * en : world.entities
			if is_visible(en)
		{
			// lol
			if is_campfire(en)
			{
				render_campfire(en);
			}
			else if is_storage_slab(en)
			{
				render_storage_slab(en);
			}
			else if en.archetype == .player
			{
				render_player(en);
			}
			else if is_portal(en)
			{
				render_portal(en);
			}
			else if is_blueprint(en)
			{
				render_blueprint(en);
			}
			else if is_base_totem(en)
			{
				render_base_totem(en);
			}
			else if is_boss_altar(en)
			{
				render_boss_altar(en);
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
	
	ui_end_and_render();
	
	//
	actually_render();
	
	// reset render state
	reset(*render_st.quads);
	render_st.cbuffer = .{};
	render_st.layer_cbuffer = .{};
	
	FrameMark();
}



apply_quad_adjustments_from_entity :: (quad: *Quad, en: Entity)
{
	quad.white_override = en.white_override;
	quad.white_override += en.interactable_alpha * 0.5;
	
	// damage animation
	if en.damage_alpha != 0
	{
		quad.white_override = 1.0;
	}
}

draw_generic_entity :: (en: Entity) -> *Quad
{
	local_trs: Transform2;
	render_trs: Transform2;
	
	// skip the big stuff in hands
	if get_held_entity().id == en.id && has_prop(en.props, .reduce_render_scale)
	{
		return null;
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
	if en.parallax.x != 0 then render_trs.translate.x += app.camera.position.x * en.parallax.x;
	
	col := ifx has_prop(en.props, .petrified) then .{0.2, 0.2, 0.2, 1.0} else en.col;
	col *= en.frame.colour_multiplier;
	
	trs:= merge_transform(local_trs, render_trs);
	
	flags := ifx flip_x then QuadFlags.x_flipped else 0;
	
	quad := draw_rect(sprite_id=sprite.id, sprite_pivot=.bottom_center, z_layer=en.z_layer, col=col, uv_rect=uv_rect, flags=flags, trs=trs);
	
	apply_quad_adjustments_from_entity(quad, en);
	return quad;
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

// #if DEBUG {
// TODO - stop using this for actual values in non-debug stuff ya silly goose!
	
DebugConfig :: struct
{
	draw_collision_boxes := false;
	disable_cycle_luts: bool = false;
	ui_font_size: int = 32;
	ui_height_scale: float = 0.7;
	
	max_monster_count: int = 0;
	test_val: float;
	rob_test:= false;
	
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

// } else {
// 	DebugConfig :: struct {}
// }


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
	build;
	workbench;
	respawn_mode;
	game_over;
	
	max;
}


Event :: struct
{
	kind: enum {
		nil;
		craft;
		place;
		build;
		damage;
		death;
		pickup;
		activate;
	};
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

EffectKind :: enum 
{
	nil;
	
	poison;
	on_fire;
	
	max;
}

Effect :: struct
{
	kind: EffectKind;
	length_timer: float;
	interval_timer: float;
	inflictor: EntityHandle; // unused atm, but we might want it?
	stack_count: int;
}

// randy: this is probably a better way of inflicting the effect, instead of it having to come from an item
// I needed it for applying the poison when consuming the raw goblin meat
apply_effect_to_entity :: (en: *Entity, effect_kind: EffectKind, length: float, stack_count: int)
{
	dot := *en.effects[effect_kind]; // this is the purpose of having the array be the max count of the enum, we use the enum as an index into it
	dot.kind = effect_kind;
	dot.length_timer = length; // we'll override the timer for now
	dot.stack_count += stack_count; // and add the stack size
	/* 
				Theoretical Scaling
				it.count += 1;
				it.length += 5.0 / it.count;
				it.damage_amount += 1;	
				*/
}

effect_prop_check :: (en: *Entity, target_entity: *Entity) -> bool
{
	out := false;
	if has_prop(en.props, .inflict_poison)
	{
		apply_effect_to_entity(target_entity, .poison, 5, 1);
		out = true;
	}
	if has_prop(en.props, .inflict_fire)
	{
		apply_effect_to_entity(target_entity, .on_fire, 10, 1);
		out = true;
	}
	return out;
}

update_and_apply_effects :: ()
{
	for * en: g_world.entities if is_enabled(en)
	{
		for * dot: en.effects
		{
			// Now this may seem kinda redundant since there's a lot of duplicate code here that, on the surface, looks
			// like it could be abstracted away into variables.
			// But don't underestimate the power of this new lack of structure. Oftentimes the more content (effects) you add
			// to a system, the more it differs in really subtle ways and becomes a big mess of complexity.
			// Trying to encapsulate that complexity into a datastructure with a bunch of variables leads to very bad things.
			//
			// The soltuion to this problem I've found, over the years, is to have as little structure as possible
			// even if that means just typing it out repeatedly and repeating yourself.
			//
			// At the end of the day, just TIO (type it out), the mortal enemy of DRY
			//
			// - randy, 9th of October 2023
			//
			if dot.kind ==
			{
				case .poison;
				{
					// interval damage tick
					if tick_timer(*dot.interval_timer, delta_t_scaled(), zero_counts_as_complete=true)
					{
						// TODO - stack handling. You'd probably want to scale up the interval + damage
						// amount based on how many stacks we've got. TIO.
						attempt_damage_entity(en, 1, null, make_props(EntityProps.poison_damage, .bypass_damage_mask), false); // apply poison damage
						dot.interval_timer = 1; // need to tweak this and balance it
					}
					if tick_timer(*dot.length_timer, delta_t_scaled()) then <<dot = .{}; // finish effect
					
					create_emitter(en.pos, .poisoned);
				}
				
				case .on_fire;
				{
					// interval damage tick
					if tick_timer(*dot.interval_timer, delta_t_scaled(), zero_counts_as_complete=true)
					{
						attempt_damage_entity(en, 1, null, make_props(EntityProps.fire_damage, .bypass_damage_mask), false);
						dot.interval_timer = 1.0;
					}
					if tick_timer(*dot.length_timer, delta_t_scaled()) then <<dot = .{}; // finish effect
					
					create_emitter(en.pos, .on_fire);
				}
				
				case;
			}
		}
	}
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

world_load :: ()
{
	world_reset();
	deserialise_world(g_world);
	g_world.simulating = true;
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
	
	//#if !SKIP_INTRO then create_notification("Defend Your Flame.", is_big=true);
	
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
	max_count = cast(int) WORLD_RADIUS/xx interval;
	max_count += 6;
	for 0..max_count
	{
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_GROUND;
		entity_set_sprite(en, sprite);
		
		en.pos.x = it * interval;
	}
	
	point : float;
	
	// hills1
	point = -WORLD_RADIUS * 0.2;
	while point < xx WORLD_RADIUS
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
	point = -WORLD_RADIUS * 0.2;
	while point < xx WORLD_RADIUS
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
	point = -WORLD_RADIUS * 0.2;
	while point < xx WORLD_RADIUS
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
	point = -WORLD_RADIUS * 0.2;
	while point < xx WORLD_RADIUS
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
	max_count = cast(int) WORLD_RADIUS/xx interval;
	max_count += 3;
	for 0..max_count
	{
		en := create_entity();
		add_props(*en.props, .render_sprite);
		en.z_layer = Z_MOUNTAIN;
		en.parallax.x = en.z_layer/100.0;
		entity_set_sprite(en, sprite);
		
		en.pos.x = it * interval;
		en.pos.y = -57;
	}
	
	//
	// resource :gen
	//
	
	RESOURCE_GEN_START :: #run snap_to_tile_grid(100.0);
	
	forest_radius :float= cast(float)WORLD_RADIUS * 0.95;
	
	// trees
	point = RESOURCE_GEN_START;
	root_index := 0;
	while point < forest_radius
	{
		MIN_STEP := 100.0;
		point += random_get_within_range(MIN_STEP, MIN_STEP * 2.0);
		if point > forest_radius then break;
		
		point = snap_to_tile_grid(point);
		
		en := create_tree();
		en.pos.x = point;
		
		if random_pct(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.pos.x = point - TILE_WIDTH;
		}
		
		if random_pct(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.pos.x = point + TILE_WIDTH;
		}
	}
	
	// tall grass
	point = RESOURCE_GEN_START;
	while point < forest_radius
	{
		MIN_STEP := 100.0;
		point += random_get_within_range(MIN_STEP, MIN_STEP * 2.0);
		point = snap_to_tile_grid(point);
		if point > forest_radius then break;
		
		en := create_entity("grass");
		setup_tall_grass(en);
		en.pos.x = point;
	}
	
	get_world_structures();
	
	// randy: trying out a new method of gen since we've got tiles now
	// rock deposits
	tile_strucs := get_world_tile_array();
	
	MIN_STEP :: TILE_WIDTH * 6;
	point = RESOURCE_GEN_START + MIN_STEP;
	while point < forest_radius
	{
		point += TILE_WIDTH;
		if point > forest_radius then break;
		
		existing := tile_strucs[world_to_tile_pos(point)];
		if existing
		{
			continue;
		}
		else
		{
			en := create_entity("rock_deposit");
			setup_rock_deposit(en);
			en.pos.x = point;
			
			point += random_get_within_range(MIN_STEP, MIN_STEP*3);
		}
	}
	
	// flint
	point = RESOURCE_GEN_START + 100.0;
	while point < forest_radius
	{
		point += 150;
		if point > forest_radius then break;
		
		en := create_world_item(.flint);
		en.pos.x = point + random_get_within_range(-90, 90);
	}
	
	// stone
	point = RESOURCE_GEN_START;
	while point < xx WORLD_RADIUS
	{
		point += 160;
		
		en := create_world_item(.stone);
		en.pos.x = point + random_get_within_range(-50, 50);
	}
	
	// rocky edge "biome"
	rock_start_radius := forest_radius + 50;
	rock_end_radius := WORLD_RADIUS - 100;
	point = rock_start_radius;
	while point < rock_end_radius
	{
		point += random_get_within_range(20, 50);
		if point > rock_end_radius then break;
		if point > -rock_start_radius && point < rock_start_radius then continue; // skip over the middle forest lol
		
		en := create_entity("rock_deposit");
		setup_rock_deposit(en);
		en.pos.x = point;
		point += get_sprite_size(en.sprite_id).x / 2;
	}
	
	// generate world structures
	{
		/*
		for 0..MAX_BASE_EXPANSIONS-1
		{
			en := create_entity();
			setup_base_expansion_shrine(en);
			en.pos.x = UPGRADE_TOTEM_START + it * UPGRADE_TOTEM_SPACING;
			
			// add to array of shrines or something?
			
			strucs := get_overlapping_structures_in_range(tile_range_from_entity(en), ignore_self=en);
			for en : strucs
			{
				en.marked_for_destroy = true;
			}
		}
		*/
	}
	
	// wood
	// replacing dis with tree root bc it's more satisfying
	/*
	point = 0.0;
	root_index = 0;
	while point < forest_radius
	{
		point += 100;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_world_item(.wood);
		en.pos.x = point + random_get_within_range(-50, 50);
	}
	*/
	
	//Right edge cave
	/*
	cave := create_cave_back();
	cave.pos.x = WORLD_RADIUS;
	cave = create_cave_front();
	cave.pos.x = WORLD_RADIUS;

	//Left edge cave
	cave = create_cave_back();
	cave.pos.x = -WORLD_RADIUS;
	cave.flip_sprite = true;
	cave = create_cave_front();
	cave.pos.x = -WORLD_RADIUS - 450;
	cave.flip_sprite = true;
	*/
	
	//
	// Rock Biome Gen
	//
	/*
	// ground
	sprite = get_sprite(.plains_ground);
	interval = range_size(sprite.rect).x;
	max_count = cast(int) WORLD_RADIUS/xx interval;
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
	// rock
	point = 0.0;
	while point < xx (WORLD_RADIUS * 1.5)
	{
		point += 200;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_entity("", BiomeType.OTHER);
		en.item_id = .stone;
		setup_world_item(en);		
		en.pos.x = point + random_get_within_range(-100, 100);
	}

	//Rock deposits
	point = 0.0;
	while point < xx (WORLD_RADIUS * 1.5)
	{
		point += 200;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_entity("", BiomeType.OTHER);
		en.item_id = .rock_deposit;
		setup_rock_deposit(en);		
		en.pos.x = point + random_get_within_range(-100, 100);
	}

	//Iron Deposits
	point = 0.0;
	while point < xx (WORLD_RADIUS * 1.5)
	{
		point += 200;
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_entity("", BiomeType.OTHER);
		en.item_id = .iron_deposit;
		setup_iron_deposit(en);		
		en.pos.x = point + random_get_within_range(-100, 100);
	}
	*/
}

create_player :: () -> *Entity
{
	// :character :player
	en := create_entity("player");
	en.archetype = .player;
	add_props(*en.props, .rigid_body, .render_sprite, .override_death, .player, .storage);
	add_props(*en.recieve_damage_from, .monster);
	en.z_layer = Z_PLAYER;
	en.state = .idle;
	entity_set_sprite(en, "char_idle");
	en.collision_rect.max = xy(25, 50);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.storage_slot_count = BASE_INVENTORY_COUNT;
	en.hunger = 10;
	return en;
}

world_bootstrap :: ()
{
	en: *Entity;
	
	#if DEBUG_UNLOCK_RECIPES
	{
		for * app.resources if (it.flags & .item) && has_prop(it.props, .craftable)
		{
			g_world.unlocked_recipes[it.id] = true;
		}
	}
	
	unlock_recipe(.wood_defense_wall, silent=true);
	unlock_recipe(.wood_back_wall, silent=true);
	unlock_recipe(.campfire, silent=true);
	
	en = create_player();
	g_world.player_handle = handle_from_entity(en);
	player := en;
	teleport_player_and_camera(xy(100, 0));
	
	totem := create_entity();
	setup_base_totem(totem);
	convert_to_blueprint(totem);
	totem.pos = xy(0, 1);
	g_world.base_totem_handle = handle_from_entity(totem);

	// en = create_entity();
	// setup_boss_altar(en);
	// convert_to_blueprint(en);
	// en.pos.x = WORLD_RADIUS - 256;
	
	en = create_world_item(.stone);
	en.pos.x = 20;
	en = create_world_item(.stone);
	en.pos.x = 160;

	// :map
	#if TESTING
	{
		en = create_world_item(.flint_sword);
		attempt_store_item(get_entity_storage_slots(get_player()), en);
		player.hot_slot = 1;
		
		en = create_world_item(.flint_pickaxe_recipe);
		attempt_store_item(get_player_storage_slots(), en);
		
		#if TEST_NIGHT_ATTACK
		{
			
		}
		
		// en = create_world_item(.hammer);
		// en.pos.x = 45;
		// attempt_store_item(get_entity_storage_slots(get_player()), en);
		// en.hot_slot = 1;
		
		// axe
		// en = create_world_item(.flint_axe);
		// en.pos.x = 45;
		// attempt_store_item(get_entity_storage_slots(get_player()), en);
		// player.hotbar_slots[2] = handle_from_entity(en);
		// player.hot_slot = 2;

		// en = create_world_item(.stone);
		// en.item_count = 64;
		// attempt_store_item(get_entity_storage_slots(get_player()), en);

		// en = create_world_item(.monster_essence);
		// en.item_count = 16;
		// attempt_store_item(get_entity_storage_slots(get_player()), en);
		
		// en = create_world_item(.raw_goblin_meat);
		// en.item_count = 16;
		// attempt_store_item(get_entity_storage_slots(get_player()), en);
		
		// en = create_world_item(.rare_item);
		// en.item_count = 16;
		// attempt_store_item(get_entity_storage_slots(get_player()), en);
		
		// en = create_world_item(.fibre);
		// en.item_count = 16;
		// attempt_store_item(get_entity_storage_slots(get_player()), en);
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
	{
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
	}
	
	if is_night_time()
	{
		// enter night
		if g_world.night_started
		{
			g_world.night_started = true;
			g_world.day_started = false;
		}
		
		// randy: I reworked the spawning so we've got more control on the design of each wave.
		// see the day_0 array.
		// The idea here is we can hand-craft each and every wave to balance it properly. Each number
		// can mean whatever we want it to mean.
		// Right now I've just got the 1 to == a gobby for simplicity
		
		// Siege of Gondor
		#if !DISABLE_MONSTERS
		{
			spawn_interval :float: NIGHT_LENGTH / cast(float)night_0.count;
			if tick_timer(*g_world.spawn_timer, delta_t_scaled(), zero_counts_as_complete=true)
			{
				log("%", g_world.spawn_counter);
				defer g_world.spawn_counter += 1;
				g_world.spawn_timer = spawn_interval;

				spawn_boss := random_bool() && !g_world.boss_spawned;

				// Boss has not spawned throughout the night
				if !g_world.boss_spawned && g_world.spawn_counter >= night_0.count-1
				{
					spawn_boss = true;
				}
				
				enemy := night_0[clamp_top(g_world.spawn_counter, night_0.count-1)];
				if enemy == 1
				{
					// gobby time
					en := create_entity();
					setup_gobby(en, false);
					en.pos.x = WORLD_RADIUS;
					log("spawned %", en.archetype);
					if spawn_boss 
					{
						empower_entity(en);
						g_world.boss_spawned = true;

					}	
				}
			}
		}
	}
	else
	{
		// enter day
		if g_world.day_started
		{
			g_world.day_started = true;
			g_world.night_started = false;
			g_world.spawn_counter = 0;
			
			for * en: g_world.entities if is_valid(en) && has_prop(en.props, .monster)
			{
				monster_petrify(en);
			}
		}
	}
}

// randy: right now each entry is fits into 1 second of night, but we can adjust however
// We also don't have to hand-author this, we could technically generate it procedurally, but I think it's
// a lot easier to just hand-craft these for balancing.
night_0 ::
int.
[
	// randy: this is just a test wave right now so I can have a meat grinder to test out my new combat changes
	1,1,1,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,1,1,0,0,1,1,1,1,1,0,0,0,0,0,1,1,1,0,0,1,1,0,0,0,0,0,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,
	0,0,0,1,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
];

/*
* NOTE(fhomolka): Not truly random. (is anything truly random?)
* The spawn chance is weighted, so we don't
* accidentally overwhelm the player with
* 50 Shades of Shrek
*
* Each enemy type is given a score.
* This locks out 'high-tier' enemies when the player is not ready
* while providing a more-or-less balanced result.
*/

// randy: this is no longer in use, now just manually setting the monsters each night
/*
GOBBY_SCORE :: 1;
HEAVY_GOBBY_SCORE :: 2;
SKELE_SCORE :: 3;
MAGE_SCORE :: 6;
OGRE_SCORE :: 7;

SPICE_MIN :: -1;
SPICE_MAX :: +2;

create_random_enemy_by_score :: (current_score: *int, day_theshold: int) -> *Entity
{
	en := create_entity();
	// randy: we'll disable this for now so we can focus on deterministic balancing
	// spice := random_int_range(SPICE_MIN, SPICE_MAX);
	res := random_int_range(0, day_theshold);

	if res >= SKELE_SCORE
	{
		setup_skele(en);
		<<current_score += SKELE_SCORE;
	}
	else if res >= OGRE_SCORE
	{
		setup_ogre(en);
		<<current_score += OGRE_SCORE;
	}
	else
	{
		// randy: disabled the heavy for now, since we're gonna start making each entity have a chance to be
		// heavy, and forcing a single one each wave (instead of it being random)
		setup_gobby(en, false);
		<<current_score += GOBBY_SCORE;
	}

	//print("Score: %; Created %\n", <<current_score, en.debug_name);

	return en;
}
*/


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
	dash;
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
	block;
	
	on;
	off;
}

EntityProps :: enum #specified
{
	// :core_props for every entity
	// Whether or not this entity is actually an active entity or just invalid / unused memory.
	valid :: 0;
	// Whether or not it's visible to systems like rendering
	visible :: 1;
	// Is it enabled in the world and doing things like update ticks, collision queries, etc.
	enabled :: 2;
	
	furnace :: 10;
	campfire :: 11;
	portal :: 12;
	fuel :: 13;
	cookable :: 14;
	render_sprite :: 15;
	draw_health_bar :: 16;
	rigid_body :: 17;
	override_movement :: 18;
	static :: 19;
	attack_player :: 20;
	interactable :: 21;
	pick_up :: 22;
	harvestable :: 23;
	deconstructable :: 24;
	storage :: 25;
	placeable :: 26;
	placed_by_player :: 27;
	structure :: 28;
	flippable :: 29;
	reduce_render_scale :: 30;
	attack_target :: 31;
	collision_query :: 32;
	blueprint :: 33;
	generic_damage :: 34;
	manually_enter_damage :: 35;
	override_death :: 36;
	loot_drops :: 37;
	particle_emitter :: 38;
	destroy_on_complete :: 39;
	item :: 40;
	sword :: 41;
	axe :: 42;
	pickaxe :: 43;
	flint_tool :: 44;
	iron_tool :: 45;
	projectile :: 46;
	craftable :: 47;
	consumable :: 48;
	blockable :: 49;
	deconstruct_tool :: 50;
	disable_interaction_when_held :: 51;
	equippable :: 52;
	waist :: 53;
	tree :: 54;
	tree_root :: 55;
	rock_deposit :: 56;
	iron_deposit :: 57;
	workbench :: 58;
	crop :: 59;
	big_notification :: 60;
	smol_notification :: 61;
	dmg_indicator :: 62;
	point_light :: 63;
	fire_damage :: 64;
	poison_damage :: 65;
	bypass_damage_mask :: 66;
	player :: 67;
	monster :: 68;
	gobby :: 69;
	ogre :: 70;
	skele :: 71;
	mage :: 72;
	fist :: 73;
	damage_over_time :: 74;
	inflict_poison :: 75;
	inflict_fire :: 76;
	ground_torch :: 77;
	spell :: 78;
	casting_medium :: 79;
	cast_blood_drain :: 80;
	cast_magic_arrows :: 81;
	cast_heal :: 82;
	defense_wall :: 83;
	find_attack_target :: 84;
	base_totem :: 85;
	back_wall :: 86;
	more_transparent :: 87;
	bow :: 88;
	boss_altar :: 89;
	free_place :: 90;
	can_place_outside_base :: 91;
	storage_slab :: 92;
	trap :: 93;
	petrified :: 94;
	only_placable_inside_core_base :: 95;
	upgrade_shrine :: 96;
	boss :: 97;
	// ^^^ add new :props here
}

Entity :: struct
{
	id: u64;
	debug_name: string;
	props: Properties(EntityProps);
	marked_for_destroy: bool;
	archetype: ResourceID;
	time_alive: float64;
	lifetime: float64;
	
	// TODO - make some @linked list helpers specific to EnitityHandle
	// that way, we can serialise arrays better and not have to define
	// a maximum value.
	
	state: EntityState;
	state_buffer: [8] EntityStateEvent;

	x_dir := 1;
	x_speed_target: float;
	x_speed_accel: float = PLAYER_ACCEL;
	x_speed_decel: float = PLAYER_DECEL;
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
	target_entity: EntityHandle;
	
	has_attacked: bool;
	state_cooldown: float;
	timer1: float; // this is asking for trouble lol
	timer2: float;
	start_position: Vector2;

	// item stuff
	item_id: ItemID;
	item_count: int = 1;
	loot_drops: [4]ItemAmount;
	pickup_cooldown: float;
	
	// recieve_damage
	health: int = BASE_MAX_HEALTH;
	max_health: int = BASE_MAX_HEALTH;
	damage_alpha: float;
	recieve_damage_from: Properties(EntityProps);
	dmg_props_must_be_exact: bool;
	damage_event: DamageEvent;

	hunger: int;
	hunger_timer: float;
	
	damage: float;

	// notification
	// it seems wise to just keep piling shit into this megastruct, since we're essentially alreadying getting
	// all the create/destroy/update functionality for free
	notif_title: [64]u8;
	notif_subtitle: [32]u8;
	notif_remaining: float;
	
	// blueprint
	remaining_items: [4]ItemAmount;
	
	// upgrade recipe
	// randy: now this could just use the remaining_items
	// of the blueprint code path, but who knows, we might want both at the same time?
	// better to make less assumptions than more.
	upgrade_count: int;
	//
	remaining_items_for_upgrade: [4]ItemAmount;
	
	// interactable
	interactable_alpha: float;
	interactable_alpha_t: float;
	about_to_consume_item: ItemID;
	
	// particle
	emitter: EmitterKind;

	// pointlight
	flicker_strength:= 1.0;
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
	// randy: Yeah we really needa start pulling this out lol
	//
	hotbar_slots: [9]EntityHandle; // these are actual slots
	hot_slot: int = 1;
	equipped_items: [16]EntityHandle; // this are a dummy ref
	is_blocking: bool;
	dashing: bool;
	dash_timer: float;
	dash_cooldown_timer: float;
	dash_initial_pos: Vector2;
	dash_dir: int;
	
	// custom player :animation / rendering
	attack_anim: AnimationState;
	
	// rob's contributions
	effects: [EffectKind.max]Effect;
	//For now Entities should only have 1 spell effect?
	spell_effect: Custom_Spell_Effects;
	cooldown: float;

	is_healing: bool;
	heal_time: float;

	speed_modified: bool;
	speed_scale: float = -100.0;
	last_damaged: float;

	//grid_position: int;
	//spell_effects: [Custom_Spell_Effects.max]Custom_Spell_Effects;
	//
	
	// janky frame stuff which should probs not exist, but
	// is actually essential for quickly writing gameplay
	// code without trying to be perfect lol
	frame: Frame;
	last_frame: Frame;
	Frame :: struct
	{
		// randy, 4th of October 2023
		// tbh we could probably just store a duplicate
		// of every single entity, being the last frame's one.
		// But why bother when this was the only thing I needed.
		// 
		// This is here so we can get the entity's pos last frame
		pos: Vector2;
		
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

// this is a slower alternative, but it doesn't need the pointer
/*
handle_from_entity :: (en: Entity) -> EntityHandle
{
	handle: EntityHandle;
	if is_valid(entity)
	{
		handle.entity_id = entity.id;
		handle.index = // todo - find by looping over the whole entity array and matching it lol
	}
	return handle;
}
*/

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

attempt_damage_entity :: (en: *Entity, amount: int, from: *Entity, damage_props: Properties(EntityProps), knockback := true) -> bool
{
	if match_props_any(damage_props, en.recieve_damage_from) || has_prop(damage_props, .bypass_damage_mask)
	{
		if en.damage_event.amount == 0
		{
			dmg: DamageEvent;
			dmg.amount = amount;
			dmg.self = handle_from_entity(en);
			dmg.inflictor = handle_from_entity(from);
			if is_valid(from) && knockback then dmg.direction.x = xx sign(en.pos.x - from.pos.x);
			if !knockback 
			{
				dmg.direction = xy(0);
			}
			en.damage_event = dmg;
			
			// randy: I moved the item inflict effect to a more appropriate place. But we might want
			// some kind of generic idea of attack element type that has a % chance of inflicting effects.
			// For now, just handle it on a case-by-case basis whenever we actually deal out the damage.
			// No point over-structuring.
			
			//HACK(fhomolka): Best way that i could thought of for now, to display zeroes, and 'lock out' lower tiers
			if en.dmg_props_must_be_exact &&
				match_props_any(damage_props, en.recieve_damage_from)
			{
				en.damage_event.amount = 0;
			}

			ind := create_dmg_indicator();
			ind.health = en.damage_event.amount;
			ind.pos.x = en.pos.x;
			ind.pos.y = en.pos.y + en.collision_rect.y + en.collision_rect.w / 2;

			return true;
		}
		else
		{
			log_warning("damage event already exists, it's either overloaded from two sources on the one frame or it hasn't been consumed");
			return false;
		}
	}
	
	//BUG(fhomolka): As it turns out, A LOT of these happen
	// 				 So, if we displayed all of the zeroes, they'd appear *everywhere*
/*
	ind := create_dmg_indicator();
	ind.health = 0;
	ind.pos.x = en.pos.x;
	ind.pos.y = en.pos.y;
*/
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
is_valid :: (entity: *Entity) -> bool
{
	return entity != null && !is_nil(entity) && has_prop(entity.props, .valid);
} 
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
		en.sprite_anim.id = sprite.id;
		
		// :animation
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
	add_props(*en.props, .render_sprite, .tree_root, .loot_drops, .harvestable, .structure);
	entity_set_sprite(en, tprint("overgrown_roots_%", variant));
	en.collision_rect = rect_from_sprite(en.sprite_id);
	en.z_layer = Z_ROOTS;
	en.flip_sprite = does_flip;
	
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(1, 3)};
	
	return en;
}

is_back_wall :: (en: Entity) -> bool
{
	return has_prop(en.props, .back_wall);
}

setup_wall :: (en: *Entity)
{
	en.archetype = .back_wall;
	en.item_id = .wood_back_wall;
	en.z_layer = Z_BACK_WALL;
	entity_set_sprite(en, .wood_back_wall);
	add_props(*en.props, .render_sprite, .deconstructable, .structure, .back_wall);
}

is_defense_wall :: (en: Entity) -> bool
{
	return has_prop(en.props, .defense_wall);
}

setup_defense_wall :: (en: *Entity)
{
	en.archetype = .side_wall;
	en.item_id = .wood_defense_wall;
	en.z_layer = Z_SIDE_WALL;
	en.health = 100;
	en.max_health = en.health;
	entity_set_sprite(en, "wood_defense_wall");
	add_props(*en.props, .rigid_body, .static, .render_sprite, .attack_target, .defense_wall, .draw_health_bar, .deconstructable, .interactable, .structure);
	add_props(*en.recieve_damage_from, .monster);
	en.collision_rect.max = xy(11, 68);
	// en.collision_rect = range_shift(en.collision_rect, xy(-12, 0));
}

//Could collate into update_defenses
update_defense_walls :: ()
{
	for * en : g_world.entities if is_valid(en) && is_defense_wall(en)
	{
		if en.damage_event.amount != 0
		{
			defer memory_zero(*en.damage_event);
			
			en.damage_alpha = 1.0;
			set_state(en, .damaged);
			
			play_sound("wood_hit_break", en.pos);

			item_res := get_resource(en.item_id);
			for * en.remaining_items
			{
				if it.id == .nil then continue;
				if it.amount >= item_res.recipe[it_index].amount continue;

				it.amount += 1;
		
				//print("item: % - % / % \n", item_res.recipe[it_index].id, it.amount, item_res.recipe[it_index].amount);
				break;
			}

			should_break := true;
			for * en.remaining_items
			{
				if it.id == .nil then continue;
				//print("Break check :item: % - % / % \n", item_res.recipe[it_index].id, it.amount, item_res.recipe[it_index].amount);
				
				if it.amount >= item_res.recipe[it_index].amount then continue;
				
				should_break = false;
				break;
			}

			if should_break
			{
				//Deconstructed all items
				play_sound("wood_struc_break", en.pos);
				convert_to_blueprint(en);
			}
		}
	}
}

setup_storage_slab :: (en: *Entity)
{
	en.item_id = .storage_slab;
	en.z_layer = Z_STRUCTURES;
	en.health = 100;
	en.max_health = en.health;
	entity_set_sprite(en, .storage_slab);
	add_props(*en.props, .static, .render_sprite, .interactable, .storage, .storage_slab, .structure);
	// randy: we're just gonna disable these for the time being, since it's using the old way of handling input
	// and it'll take some elbow grease to update it.
	en.storage_slot_count = 1;
}

create_storage_slab :: inline () -> *Entity
{
	en := create_entity();
	setup_storage_slab(en);
	return en;
}

is_storage_slab :: (en: Entity) -> bool
{
	return has_prop(en.props, .storage_slab);
}

render_storage_slab :: (en: *Entity)
{
	draw_generic_entity(en);
	
	slot := en.storage_slots[0];
	slot_en := entity_from_handle(slot);
	if is_valid(slot_en)
	{
		draw_sprite(slot_en.sprite_id, xy(en.pos.x, 6 + sin_breathe(3) * 1), z_layer=en.z_layer - 0.1);
	}
}

// formerly workbench_ui
storage_ui :: ()
{
	hovered_en := entity_from_handle(app.frame.hot_interactable);
	
	// interact with hovered workbench
	if has_prop(hovered_en.props, .storage)
	{
		if key_pressed(#char "E")
		{
			consume_key(#char "E");
		
			if app.interface_mode == .workbench
			{
				set_interface_mode(.nil);
			}
			else
			{
				set_interface_mode(.workbench);
			}
			
			app.active_workbench = app.frame.hot_interactable;
		}
	}
	
	storage := entity_from_handle(app.active_workbench);
	
	// exit when far away
	if app.interface_mode == .workbench
		&& abs(storage.pos.x - get_player().pos.x) > 50
	{
		set_interface_mode(.nil);
	}
	
	// exit workbench on esc
	if app.interface_mode == .workbench
		&& key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		set_interface_mode(.nil);
	}
	// exit on tab press
	if app.interface_mode == .workbench
		&& key_pressed(.TAB)
	{
		consume_key(.TAB);
		set_interface_mode(.nil);
	}
	
	// animate alpha
	app.workbench_alpha_t = ifx app.interface_mode == .workbench then 1.0;
	animate_to_target(*app.workbench_alpha, app.workbench_alpha_t, delta_t(), rate=UI_ANIMATE_RATE);
	
	is_active := app.workbench_alpha_t == 1.0;
	if is_active
	{
		app.show_cursor = true;
		//app.disable_player_input = true;
	}
	push_disable_signal(!is_active);
	push_opacity(app.workbench_alpha);
	
	if app.workbench_alpha != 0
	{
		pos := world_pos_to_screen(storage.pos + xy(0, 30));
		recipe_element_height := em(1.5);
		width := em(12);
		
		// parent box
		set_next_floating_x(pos.x);
		set_next_floating_y(pos.y);
		set_next_pref_size(width, size_by_children(1));
		set_next_child_layout_axis(.X);
		set_next_bg_col(xyzw(0, 0, 0, 0.5));
		set_next_rect_pivot_x(.center);
		set_next_rect_pivot_y(.bottom);
		flags :BoxFlags= .floating | .clickable;
		flags |= .draw_bg | .draw_border;
		parent_box := make_box(flags, tprint("%_storage_ui", storage.id));
		push_parent(parent_box);
		
		push_pref_width(pct_parent(1, 0));
		
		// edge padding
		padding(em(UI_EDGE_PADDING));
		auto_column(height=size_by_children(1));
		padding(em(UI_EDGE_PADDING));
		
		// bottom drawer for storage
		{
			// set_next_pref_width(pct_parent(1, 0));
			// set_next_pref_height(size_by_children(1));
			// auto_column();
			// padding(pct_parent(1, 0));
			
			// set_next_pref_height(text_dim(1));
			// label("workbench_storage###");
			
			set_next_pref_width(pct_parent(1, 0));
			set_next_pref_height(size_by_children(1));
			auto_row();
			padding(pct_parent(1, 0));
			
			set_next_child_layout_axis(.X);
			set_next_pref_size(size_by_children(1));
			push_parent(make_box(0, ""));
			
			// inventory slots of the workbench
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			auto_column();
			spacer(em(UI_MARGIN));
			
			set_next_font_size(font_size_pct(0.9));
			set_next_pref_height(text_dim(1));
			set_next_text_edge_pad(0);
			set_next_text_justify_x(.center);
			label("Storage###");
			
			ROW_LENGTH :: 5;
			
			slot_it := 0;
			for row : 0..storage.storage_slot_count / ROW_LENGTH
			{
				if row != 0 then spacer(em(UI_SLOT_SPACING));
				
				set_next_pref_height(size_by_children(1));
				set_next_pref_width(size_by_children(1));
				auto_row();
				
				for column : 1..ROW_LENGTH
				{
					defer slot_it += 1;
					if slot_it >= storage.storage_slot_count then break;
					
					if column != 1 then spacer(em(UI_SLOT_SPACING));
					
					set_next_flags(.draw_bg | .draw_border);
					set_next_pref_size(em(UI_SLOT_SIZE));
					ui_storage_slot(tprint("st_%_slot_%_%", storage.id, row, column), *storage.storage_slots[slot_it], em(UI_SLOT_ICON_PADDING));
				}
			}
		}
		
		// consume the click of the back parent box as well
		parent_signal := signal_from_box(parent_box);
		if parent_signal.clicked
		{
			consume_key(.MOUSE_BUTTON_LEFT);
		}
	}
}

input_attempt_structure :: inline (en: *Entity) -> bool
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
			
			// play_sound_old(.wood_hit);
			en.health += STRUCTURE_REPAIR_AMOUNT;
			if en.health > en.max_health then en.health = en.max_health;		
		}
	}
	
	return can_interact;
}

setup_gobby :: (en: *Entity, is_heavy: bool)
{
	if is_heavy
	{
		en.archetype = .gobby_heavy;
		en.max_health = 50;
	}
	else
	{
		en.archetype = .gobby;
		en.max_health = 30;
	}
	en.health = en.max_health;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .gobby, .monster, .loot_drops, .draw_health_bar, .find_attack_target);
	add_props(*en.recieve_damage_from, .player);
	
	en.collision_rect = make_range(xy(32, 32), pivot=.bottom_center);
	
	set_state(en, .idle_wait);
	en.idle_wait_timer = random_get_within_range(0, 2);
	
	if random_pct(0.5) then array_add(en.loot_drops, .{id=.goblin_hide, amount=1+xx random_pct(0.1)});
	array_add(en.loot_drops, .{id=.raw_goblin_meat, amount=1+xx random_pct(0.1)});
	array_add(en.loot_drops, .{id=.monster_essence, amount=1});
	if is_heavy
	{
		array_add(en.loot_drops, .{id=.raw_goblin_meat, amount=1});
	}
}

/*
create_gobby :: () -> *Entity
{
	en := create_entity("gobby");
	en.archetype = .gobby;
	en.max_health = 30;
	en.health = 30;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .gobby, .monster, .loot_drops, .draw_health_bar);
	add_props(*en.recieve_damage_from, .player);
	
	en.collision_rect = make_range(xy(32, 32), pivot=.bottom_center);
	
	set_state(en, .idle_wait);
	en.idle_wait_timer = random_get_within_range(0, 2);
	
	if random_pct(0.5) then array_add(en.loot_drops, .{id=.goblin_hide, amount=1+xx random_pct(0.1)});
	array_add(en.loot_drops, .{id=.raw_goblin_meat, amount=1+xx random_pct(0.1)});
	array_add(en.loot_drops, .{id=.monster_essence, amount=1});
	return en;
}
*/
create_gobby :: (is_heavy: bool) -> *Entity
{
	en := create_entity("gobby");
	setup_gobby(en, is_heavy);
	return en;
}

/*
create_skele :: () -> *Entity
{
	en := create_entity("skelle");
	en.health = 20;
	en.z_layer = -1;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .generic_damage, .skele, .monster);
	add_props(*en.recieve_damage_from, .player);
	return en;
}
*/

setup_ogre :: (en: *Entity)
{
	en.health = 80;
	en.max_health = en.health;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .ogre, .monster, .loot_drops, .draw_health_bar, .find_attack_target);
	add_props(*en.recieve_damage_from, .player);
	en.collision_rect = make_range(xy(42, 50), pivot=.bottom_center);

	set_state(en, .idle_wait);
	en.idle_wait_timer = random_get_within_range(0, 2);
	en.loot_drops[0] = .{id=.raw_goblin_meat, amount=random_int_range(1, 2)};
}

create_ogre :: inline () -> *Entity
{
	en := create_entity("ogre");
	setup_ogre(en);
	return en;
}

setup_mage :: (en: *Entity)
{
	en.archetype = .mage;
	en.max_health = 30;
	en.health = 30;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .mage, .monster, .loot_drops, .draw_health_bar, .find_attack_target);
	add_props(*en.recieve_damage_from, .player);
	
	en.collision_rect = make_range(xy(32, 32), pivot=.bottom_center);
	
	set_state(en, .idle_wait);
	en.idle_wait_timer = random_get_within_range(0, 2);
	
	push_random_seed(get_chaos_seed());
	en.loot_drops[0] = .{id=.raw_goblin_meat, amount=random_int_range(1, 2)};
}

create_mage :: inline () -> *Entity
{
	en := create_entity("mage");
	setup_mage(en);
	return en;
}

setup_skele :: (en: *Entity)
{
	en.archetype = .skele;
	en.max_health = 30;
	en.health = 30;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .skele, .monster, .loot_drops, .draw_health_bar, .find_attack_target);
	add_props(*en.recieve_damage_from, .player);
	
	en.collision_rect = make_range(xy(32, 32), pivot=.bottom_center);
	
	set_state(en, .idle_wait);
	en.idle_wait_timer = random_get_within_range(0, 2);
	
	en.loot_drops[0] = .{id=.monster_essence, amount=1};
}


create_skele :: inline () -> *Entity
{
	en := create_entity("skele");
	setup_skele(en);
	return en;
}

skele_update :: ()
{
	player := get_player();

	for * en: app.world.entities if is_enabled(en) && has_prop(en.props, .skele) && !has_prop(en.props, .petrified)
	{
		// move away from others
		for * other: app.world.entities if is_valid(other) && has_prop(other.props, .skele)
		{
			dist := en.pos.x - other.pos.x;
			if abs(dist) < 4.0
			{
				en.pos.x += sign(dist) * delta_t_scaled() * 10.0;
			}
		}

		en.state_timer += delta_t_scaled();
		
		if en.state == .nil
		{
			set_state(en, .idle);
		}
		
		if en.state == .idle
		{
			if is_state_entry(en, .idle)
			{
				entity_set_sprite(en, .skele_idle, random_frame=true);
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
				entity_set_sprite(en, .skele_idle);
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

			if en.is_blocking && en.x_dir != sign(dmg.direction.x)
			{
				// play_sound_old(.block);
			create_emitter(get_held_item_render_pos() + xy(player.x_dir * 5.0, 5.0), .parry);
			}
			else
			{ 
				en.health -= dmg.amount;
				en.health = clamp_bottom(0, en.health);
				
				// some kind of persistent damage event ??
				// that way when rendering we can do the flash
				// also we can look back in time to when the thingo happend
				
				// play_sound_old(.punch);
				
				en.velocity = en.damage_event.direction * random_get_within_range(100, 150);
				en.velocity.y = 40.0;
				
				if en.health <= 0
				{
					set_state(en, .dying);
				}
			}
			memory_zero(*en.damage_event);
		}
		
		// death
		if en.state == .dying
		{
			entity_set_sprite(en, .skele_death);
			if en.sprite_anim.is_finish then set_state(en, .dead);
		}
		if en.state == .dead
		{
			// sadge
			en.marked_for_destroy = true;
			do_death_poof(en);
			spawn_items_at_location(en.loot_drops, en.pos);
			// play_sound_old(.impact_thing);
		}
		
		// enter agro
		target_entity := entity_from_handle(en.target_entity);
		if is_valid(target_entity)
			&& is_any(en.state, .idle, .wandering)
			&& !is_any(en.state, .damaged, .dying, .dead)
			&& abs(target_entity.pos.x - en.pos.x) < MONSTER_AGGRO_RANGE
		{
			set_state(en, .agro_target);
		}
		// agro
		if en.state == .agro_target
		{
			en.walk_position = target_entity.pos.x;
		}
		
		// enter attack
		POWER:: 300;
		//Maybe add if they get too close goblin will start running away
		if is_valid(target_entity) && within_target_range(en.pos, target_entity.pos, POWER)
			&& is_any(en.state, .idle, .wandering, .agro_target)
			&& !is_any(en.state, .damaged, .dying, .dead)
		{
			set_state(en, .attack_charge);
		}


		BLOCK_RANGE :: 50;
		dist_to_target := abs(target_entity.pos.x - en.pos.x);
		en.is_blocking = false;
		if dist_to_target <= BLOCK_RANGE
			&& !is_any(en.state, .damaged, .dying, .dead)
		{
			set_state(en, .block);
		}

		if en.state == .block
		{
			if is_state_entry(en, .block)
			{
				entity_set_sprite(en, .skele_shield);
			}
			en.is_blocking = true;

			if dist_to_target > BLOCK_RANGE
			{
				set_state(en, .agro_target);
			}

			if en.health <= 0
			{
				set_state(en, .dying);
			}
		}
		
		// attack windup
		if en.state == .attack_charge
		{
			if is_state_entry(en, .attack_charge)
			{
				entity_set_sprite(en, .skele_throw);
				// play_sound_old(.gobby_attack, delay=0.6);
			}
			
			attack_frame :: 3;
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
				proj_spawn := en.pos + xy(0.0, 20.0);
				ball:= create_projectile(proj_spawn, projectile_target_velocity(proj_spawn, target_entity.pos, POWER), .thrown_sword, 1.0, "arrow");
				add_props(*ball.props, .monster);
			}
			
			if en.sprite_anim.is_finish
			{
				set_state(en, .idle_wait);
				en.idle_wait_timer = random_get_within_range(1.0, 3);
			}
		}
		
		// this is kinda a parent of agro & wandering
		if en.state == .agro_target || en.state == .wandering
		{
			entity_set_sprite(en, .skele_walk, random_frame=true);
			dist := en.walk_position - en.pos.x;
			en.x_speed_target = 40.0;
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

//Converts projectile power/Velocity into Vector2 Velocity - gravity will arc, no gravity will directly aim
projectile_target_velocity :: (start_position : Vector2, target_position : Vector2, power: float, gravity:= true) -> Vector2
{	target_angle := 0.0;
	if gravity
	{
		target_angle = proj_motion_get_angle(start_position, target_position, power);
	} 
	else 
	{
		relative_pos := target_position-start_position;
		target_angle = atan2(relative_pos.y,relative_pos.x);
	}
	target_velocity := xy(power*cos(target_angle),power*sin(target_angle));
	//debug_break();
	return target_velocity;
}
get_angle:: (start_position : Vector2, target_position : Vector2) -> float
{
	relative_pos := target_position-start_position;
	target_angle := atan2(relative_pos.y,relative_pos.x);
	return target_angle;
}
//Gets the ideal angle (Least Travel Time) based on a target position and inital velocity (units/s)- in Radians
proj_motion_get_angle :: (start_position : Vector2, target_position : Vector2, power: float) -> float
{
	//Relative to a 0,0 position
	//Can only shoot up I think
	relative_pos := target_position-start_position;
	calc := (GRAVITY*relative_pos.x)/pow(power,2);
	out := 0.5*(asin(calc));
	ifx !within_target_range(start_position, target_position, power) then out = PI/4.0;
	//Pretty Much checking which quadrant it is in
	if relative_pos.x <= 0
	{

		out = out - PI;
	}	
	return out;
}

//Checks if the target is within range to target with an attack
within_target_range :: (start_position : Vector2, target_position : Vector2, power : float) -> bool
{
	//Max range occurs at 45 degrees
	max_range:= (pow(power, 2)*sin(2*PI/4.0))/GRAVITY;

	if start_position.x - max_range <= target_position.x && target_position.x <= start_position.x + max_range
	{
		return true;
	}
	else {
		return false;
	}
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

// randy: NOTE
// Gonna use this for pulling out patterns for some of the more general stuff shared across entities.
// Now that we've got a bunch of them and can actually see the things we could reuse.
//
ai_update :: ()
{
	player := get_player();
	
	for * en: app.world.entities if is_enabled(en) && !has_prop(en.props, .petrified)
	{
		// find a target and stuff it in target_entity
		if has_prop(en.props, .find_attack_target)
		{
			is_player_dead := player.health <= 0;
			is_player_gone := player.biome != en.biome;
			
			// randy: TODO - make them attack the base somehow
			if is_player_dead || is_player_gone
			{
				en.target_entity = .{};
			}
			else
			{
				real_target := get_player();
				
				range_to_real_target := make_range(real_target.pos.x, en.pos.x);
			
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
				target_entity := ifx closest_obstacle then closest_obstacle else real_target;
				
				// target entity is the actual thing we're running towards to attack (could be an obstacle)
				en.target_entity = handle_from_entity(target_entity);
			}
		}
	}
}

monster_petrify :: (en: *Entity)
{
	//remove_props(*en.props, .enabled);
	add_props(*en.props, .petrified);
	en.velocity.x = 0.0;
	en.acceleration.x = 0.0;
	en.x_speed_target = 0.0;
}

gobby_update :: ()
{
	player := get_player();
	
	// MAKE CONTENT.
	
	// :GOBBY
	for * en: app.world.entities if is_enabled(en) && has_prop(en.props, .gobby) && !has_prop(en.props, .petrified)
	{
		is_heavy := en.archetype == .gobby_heavy;

		// move away from others
		for * other: app.world.entities if is_valid(other) && has_prop(other.props, .gobby)
		{
			dist := en.pos.x - other.pos.x;
			if abs(dist) < 4.0
			{
				en.pos.x += sign(dist) * delta_t_scaled() * 10.0;
			}
		}
		
		en.state_timer += delta_t_scaled();
		
		if en.state == .nil
		{
			set_state(en, .idle);
		}
		
		if en.state == .idle
		{
			if is_state_entry(en, .idle)
			{
				gob_idle_variant : SpriteID = ifx is_heavy then .gob_heavy_idle else .gob_idle;
				entity_set_sprite(en, gob_idle_variant, random_frame=true);
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
				gob_idle_variant : SpriteID = ifx is_heavy then .gob_heavy_idle else .gob_idle;
				entity_set_sprite(en, gob_idle_variant);
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
			defer memory_zero(*en.damage_event);
			dmg := en.damage_event;
			
			en.health -= dmg.amount;
			en.health = clamp_bottom(0, en.health);
			en.damage_alpha = 1.0;
			
			// some kind of persistent damage event ??
			// that way when rendering we can do the flash
			// also we can look back in time to when the thingo happend
			
			if en.damage_event.direction.x != 0
			{
				en.velocity += en.damage_event.direction * random_get_within_range(100, 150);
				en.velocity.y += 40.0;
			}
			
			if en.health <= 0
			{
				set_state(en, .dying);
			}
		}
		
		// death
		if en.state == .dying
		{
			if is_state_entry(en, .dying)
			{
				play_sound("gobby_death", pos=en.pos);
			}
			
			gob_death_variant : SpriteID = ifx is_heavy then .gob_heavy_death else .gob_death;
			entity_set_sprite(en, gob_death_variant);
			if en.sprite_anim.is_finish then set_state(en, .dead);
		}
		if en.state == .dead
		{
			// sadge
			en.marked_for_destroy = true;
			do_death_poof(en);
			spawn_items_at_location(en.loot_drops, en.pos);
			// play_sound_old(.impact_thing);
		}
		
		// enter agro
		target_entity := entity_from_handle(en.target_entity);
		if is_valid(target_entity)
			&& is_any(en.state, .idle, .wandering)
			&& !is_any(en.state, .damaged, .dying, .dead)
			&& abs(target_entity.pos.x - en.pos.x) < MONSTER_AGGRO_RANGE
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
		if is_valid(target_entity)
			&& dist_to_target < ATTACK_RANGE
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
				gob_attack_variant : SpriteID = ifx is_heavy then .gob_heavy_attack else .gob_attack;
				entity_set_sprite(en, gob_attack_variant);
				
				play_sound("gobby_attack", pos=en.pos);
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
					attempt_damage_entity(target_entity, GOBBY_DAMAGE, en, make_props(EntityProps.gobby, .monster));
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
			gob_run_variant : SpriteID = ifx is_heavy then .gob_heavy_run else .gob_run;
			entity_set_sprite(en, gob_run_variant, random_frame=true);
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
		
		// footsteps
		if en.sprite_id == .gob_run
		{
			if en.sprite_anim.frame_advanced && (en.sprite_anim.frame == 1 || en.sprite_anim.frame == 5)
			{
				play_sound("footstep_smol", pos=en.pos);
			}
		}
	}
}

ogre_update :: ()
{
	player := get_player();

	for * en: app.world.entities if is_enabled(en) && has_prop(en.props, .ogre) && !has_prop(en.props, .petrified)
	{
		// move away from others
		for * other: app.world.entities if is_valid(other) && has_prop(other.props, .ogre)
		{
			dist := en.pos.x - other.pos.x;
			if abs(dist) < 4.0
			{
				en.pos.x += sign(dist) * delta_t_scaled() * 10.0;
			}
		}

		en.state_timer += delta_t_scaled();
		
		if en.state == .nil
		{
			set_state(en, .idle);
		}
		
		if en.state == .idle
		{
			if is_state_entry(en, .idle)
			{
				entity_set_sprite(en, .ogre_idle, random_frame=true);
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
				entity_set_sprite(en, .ogre_idle);
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
			
			// play_sound_old(.punch);
			
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
			//TODO(fhomolka):Ogre death sprite
			entity_set_sprite(en, .gob_death);
			if en.sprite_anim.is_finish then set_state(en, .dead);
		}
		if en.state == .dead
		{
			// sadge
			en.marked_for_destroy = true;
			do_death_poof(en);
			spawn_items_at_location(en.loot_drops, en.pos);
			// play_sound_old(.impact_thing);
		}
		
		// enter agro
		target_entity := entity_from_handle(en.target_entity);
		if is_valid(target_entity)
			&& is_any(en.state, .idle, .wandering)
			&& !is_any(en.state, .damaged, .dying, .dead)
			&& abs(target_entity.pos.x - en.pos.x) < MONSTER_AGGRO_RANGE
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
		if is_valid(target_entity)
			&& dist_to_target < ATTACK_RANGE
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
				entity_set_sprite(en, .ogre_attack);
				// play_sound_old(.gobby_attack, delay=0.6);
			}
			
			attack_frame :: 3;
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
					attempt_damage_entity(target_entity, 20, en, make_props(EntityProps.ogre, .monster));
				}
			}
			
			if en.sprite_anim.is_finish
			{
				set_state(en, .idle_wait);
				en.idle_wait_timer = random_get_within_range(1.0, 3);
			}
		}
		
		// this is kinda a parent of agro & wandering
		if en.state == .agro_target || en.state == .wandering
		{
			entity_set_sprite(en, .ogre_walk, random_frame=true);
			dist := en.walk_position - en.pos.x;
			en.x_speed_target = 10.0;
			en.input_axis.x = xx sign(dist);
			en.x_dir = sign(en.input_axis.x);
		}
		else
		{
			en.input_axis.x = 0;
			en.x_speed_target = 0.0;
		}
		
		// footsteps
		if en.sprite_id == .ogre_walk
		{
			if en.sprite_anim.frame_advanced && (en.sprite_anim.frame == 3 || en.sprite_anim.frame == 7)
			{
				play_sound("footstep_beeg", pos=en.pos);
				camera_shake_at_pos(0.4, en.pos, 200, 500);
			}
		}
	}

}

mage_update :: ()
{
	player := get_player();

	for * en: app.world.entities if is_enabled(en) && has_prop(en.props, .mage) && !has_prop(en.props, .petrified)
	{
		// move away from others
		for * other: app.world.entities if is_valid(other) && has_prop(other.props, .mage)
		{
			dist := en.pos.x - other.pos.x;
			if abs(dist) < 4.0
			{
				en.pos.x += sign(dist) * delta_t_scaled() * 10.0;
			}
		}

		en.state_timer += delta_t_scaled();
		
		if en.state == .nil
		{
			set_state(en, .idle);
		}
		
		if en.state == .idle
		{
			if is_state_entry(en, .idle)
			{
				entity_set_sprite(en, .gob_mage_idle, random_frame=true);
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
				entity_set_sprite(en, .gob_mage_idle);
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
			
			// play_sound_old(.punch);
			
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
			//TODO(fhomolka):Mage death sprite
			entity_set_sprite(en, .gob_mage_death);
			if en.sprite_anim.is_finish then set_state(en, .dead);
		}
		if en.state == .dead
		{
			// sadge
			en.marked_for_destroy = true;
			do_death_poof(en);
			spawn_items_at_location(en.loot_drops, en.pos);
			// play_sound_old(.impact_thing);
		}
		
		// enter agro
		target_entity := entity_from_handle(en.target_entity);
		if is_valid(target_entity)
		&& is_any(en.state, .idle, .wandering)
		&& !is_any(en.state, .damaged, .dying, .dead)
		&& abs(target_entity.pos.x - en.pos.x) < MONSTER_AGGRO_RANGE
		{
			set_state(en, .agro_target);
		}
		// agro
		if en.state == .agro_target
		{
			en.walk_position = target_entity.pos.x;
		}
		
		// enter attack
		POWER:: 300;
		dist_to_target := abs(target_entity.pos.x - en.pos.x);
		//Maybe add if they get too close goblin will start running away
		if is_valid(target_entity) 
		&& within_target_range(en.pos, target_entity.pos, POWER)
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
				//TODO(fhomolka): Mage attack
				entity_set_sprite(en, .gob_mage_attack);
				// play_sound_old(.gobby_attack, delay=0.6);
			}
			
			attack_frame :: 3;
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
				if !app.debug_config.rob_test 
				{
					proj_spawn := en.pos + xy(0.0, 20.0);
					ball:= create_projectile(proj_spawn, projectile_target_velocity(proj_spawn, target_entity.pos, POWER), .fireball, 1.0, "arrow");
					add_props(*ball.props, .inflict_fire);
					} else {
						spell_magic_arrows(en, target_entity.pos);
					}
				}
				
				if en.sprite_anim.is_finish
				{
					set_state(en, .idle_wait);
					en.idle_wait_timer = random_get_within_range(1.0, 3);
				}
			}
			
			// this is kinda a parent of agro & wandering
			if en.state == .agro_target || en.state == .wandering
			{
				//TODO(fhomolka):MAGE walk
				entity_set_sprite(en, .gob_mage_move, random_frame=true);
				dist := en.walk_position - en.pos.x;
				en.x_speed_target = 40.0;
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
		// randy:
		// This is another classic example of me trying to "not repeat myself" but it backfiring.
		// Either use the generic damage or don't. There is no middle ground.
		//
		// Honestly, even using this generic system might be too much. Surely we can easily make some helper functions
		// for the damage being easier to do custom in every single update.
		// TIO.
		//
		assert(!has_prop(en.props, .manually_enter_damage), "Either use the generic_damage, or if you need more control, remove generic_damage and fully handle it in the entity update. See :gobby for example.");
		
		if en.damage_event.amount != 0
		{
			defer memory_zero(*en.damage_event);
			
			en.health -= en.damage_event.amount;
			en.health = max(en.health, 0);
			en.damage_alpha = 1.0;
			set_state(en, .damaged);
			
			// play_sound_old(en.hit_sound);
		}
		
		if !has_prop(en.props, .override_death) && en.health <= 0
		{
			en.marked_for_destroy = true;
			do_death_poof(en);
			spawn_items_at_location(en.loot_drops, en.pos);
		}
	}
}

//:projectile update
projectile_update :: ()
{

	against_rect : Range2;
	for * en: app.world.entities if has_prop(en.props, .valid) && has_prop(en.props, .projectile)
	{
		if en.velocity != xy(0,0)
		{
			target_rotation :float = radians_to_degrees(atan2(en.velocity.y, en.velocity.x));
			en.render_offset.rotate = target_rotation;
		}
		attack_hitbox := range_shift(en.collision_rect, get_absolute_position(en));

		//Checks if the projectile is player spawned or monster spawned then checks if its colliding with any entities in the world
		if has_prop(en.props, .player)
		{
			for * target_entity : app.world.entities if has_prop(target_entity.props, .monster)
			{	
				against_rect := range_shift(target_entity.collision_rect, get_absolute_position(target_entity));
				if range_collide(against_rect, attack_hitbox) && en.pos.y > 0
				{
					effect_prop_check(en, target_entity);
					attempt_damage_entity(target_entity, cast(int)en.damage, en, make_props(EntityProps.projectile, .player));
					en.marked_for_destroy = true;
				}
			}
		}
		if has_prop(en.props, .monster)
		{
			for * target_entity : app.world.entities if has_prop(target_entity.props, .player)
			{	
				against_rect := range_shift(target_entity.collision_rect, get_absolute_position(target_entity));
				if range_collide(against_rect, attack_hitbox) && en.pos.y > 0
				{
					effect_prop_check(en, target_entity);
					attempt_damage_entity(target_entity, cast(int)en.damage, en, make_props(EntityProps.projectile, .monster));
					en.marked_for_destroy = true;
				}
			}

		}

		//Preparation for visuals arrow sticking out of ground
		
		//TODO(fhomolka): ?Stick around for a bit?
		if en.pos.y <= 0
		{
			en.marked_for_destroy = true;
			//en.velocity = xy(0,0);
			//ifx en.lifetime >= en.time_alive then en.marked_for_destroy = true;
			
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
	// play_sound_old(.air_swing, pitch=0.8);
	item_en.pickup_cooldown = 1.5;
	
	item_en.pos = player.pos + xy(player.x_dir * 16.0, 20);
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
		item.biome = get_player().biome; //TODO(fhomolka): Remove if we start dropping stuff when player isn't there
	}
}



setup_sapling :: (en: *Entity)
{
	add_props(*en.props, .render_sprite, .deconstructable, .crop, .structure);
	en.archetype = .oak_sapling;
	entity_set_sprite(en, .oak_sapling);
	en.loot_drops[0] = .{id=.acorn, amount=1};
	en.time_til_growth = random_get_within_range(120, 360);
	en.z_layer = Z_PLANTS;
}

setup_tall_grass :: (en: *Entity)
{
	en.archetype = .tall_grass;
	add_props(*en.props, .render_sprite, .loot_drops, .harvestable, .structure);
	en.z_layer = Z_TALL_GRASS;
	en.loot_drops[0] = .{id=.fibre, amount=1+cast(int)random_pct(0.2)};
	en.flip_sprite = random_bool();
	entity_set_sprite(en, tprint("tall_grass_%", random_int_range(0, 1)));
}
setup_tall_grass_stub :: (en: *Entity)
{
	add_props(*en.props, .crop, .render_sprite, .structure);
	en.z_layer = Z_TALL_GRASS;
	en.archetype = .tall_grass;
	entity_set_sprite(en, .tall_grass_stub);
	en.time_til_growth = random_get_within_range(60, 240);
}

update_crops :: ()
{
	for * en : app.world.entities
		if is_valid(en) && has_prop(en.props, .crop)
	{
		if en.archetype ==
		{
			case .rock_deposit;
			
			/*
			MAX_STAGE :: 2;
			stage := en.sprite_anim.frame;
			
			if stage < MAX_STAGE && en.time_til_growth == 0
			{
				en.time_til_growth = ROCK_GROWTH_TIME + random_get_within_range(0, ROCK_GROWTH_TIME/4.0);
			}
			
			if tick_timer(*en.time_til_growth, delta_t_scaled())
			{
				en.sprite_anim.frame += 1;
			}
			*/
			
			case .stone;
			if en.time_til_growth == 0
			{
				en.time_til_growth = ROCK_GROWTH_TIME + random_get_within_range(0, ROCK_GROWTH_TIME/4.0);
			}
			if tick_timer(*en.time_til_growth, delta_t_scaled())
			{
				en.marked_for_destroy = true;
				rock := create_entity();
				setup_rock_deposit(rock);
				rock.pos = en.pos;
			}
			
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
	// en.hit_sound = .wood_hit;
	entity_set_sprite(en, .wood_log);
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(2, 3)};
	return en;
}

create_stump :: () -> *Entity
{
	en := create_entity("stump");
	add_props(*en.props, .render_sprite, .generic_damage, .structure);
	add_props(*en.recieve_damage_from, .axe);
	en.health = 30;
	en.z_layer = Z_TREE - 0.1;
	// en.hit_sound = .wood_hit;
	entity_set_sprite(en, "tree_stump");
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(1, 2)};
	en.collision_rect = make_range(xy(30, 16), pivot=.bottom_center);
	return en;
}

is_tree :: (en: Entity) -> bool
{
	return has_prop(en.props, .tree);
}

create_tree :: () -> *Entity
{
	en := create_entity("tree");
	add_props(*en.props, .render_sprite, .tree, .structure);
	add_props(*en.recieve_damage_from, .axe);
	entity_set_sprite(en, "tree_full");
	en.collision_rect.max = xy(14, 64);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.health = TREE_HEALTH;
	en.z_layer = Z_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	en.item_id = .tree;
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
			
			// play_sound_old(.wood_hit);
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
				
				play_sound("tree_fall", tree.pos);
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
				
				// play_sound_old(.tree_impact);
				camera_shake_at_pos(0.6, tree.pos, 300, 400);
			}
		}
	}
}

render_tree :: inline (en: Entity)
{
	draw_generic_entity(en);
	
	// todo - hit mark %
}

setup_rock_sapling :: (en: *Entity)
{
	en.archetype = .stone;
	add_props(*en.props, .render_sprite, .structure, .deconstructable, .crop, .structure);
	entity_set_sprite(en, .stone);
	en.loot_drops[0] = .{id=.stone, amount=1};
	en.z_layer = Z_PLANTS;
}

setup_rock_deposit :: (en: *Entity)
{
	add_props(*en.props, .render_sprite, .rock_deposit, .structure);
	add_props(*en.recieve_damage_from, .pickaxe);
	entity_set_sprite(en, .rock_deposit);
	//en.collision_rect.max = xy(64, 64);
	//en.collision_rect = range_bottom_center(en.collision_rect);
	en.collision_rect = make_range(xy(64, 16), pivot=.bottom_center);
	en.health = 30;
	en.z_layer = Z_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	en.item_id = .rock_deposit;
	en.loot_drops[0] = .{id=.stone, amount=1+cast(int)random_pct(0.5)};
}

update_rock_deposits :: ()
{
	player := get_player();
	
	 //TEMP(fhomolka): put iron here, for now
	for * en: app.world.entities if is_valid(en) && 
		(has_prop(en.props, .rock_deposit) || has_prop(en.props, .iron_deposit))
	{
		if en.damage_event.amount != 0
		{
			defer memory_zero(*en.damage_event);
			dmg := en.damage_event;
			
			en.damage_alpha = 1.0;
			
			en.health -= dmg.amount;
			en.health = clamp_bottom(0, en.health);
			
			if en.health <= 0
			{
				set_state(en, .dying);
			}
			
			// play_sound_old(.wood_hit);
		}
		
		if en.state == .dying
		{
			if is_state_entry(en, .dying)
			{
				en.recieve_damage_from = .{};
			}
	
			spawn_pos: = en.pos;
			spawn_pos.y = 16;

			spawn_items_at_location(en.loot_drops, spawn_pos);
			new_event(.{kind=.death, entity=handle_from_entity(en)});
			en.marked_for_destroy = true;
			
			// play_sound_old(.tree_impact);
			app.camera.trauma += 0.5;
		}
	}
}

setup_iron_item :: (en: *Entity)
{
	en.item_id = .iron;
	setup_world_item(en);	
}

setup_iron_deposit :: (en: *Entity)
{
	add_props(*en.props, .render_sprite, .rock_deposit, .structure);
	add_props(*en.recieve_damage_from, .pickaxe, .flint_tool);
	entity_set_sprite(en, .iron_deposit);
	//en.collision_rect.max = xy(64, 64);
	//en.collision_rect = range_bottom_center(en.collision_rect);
	en.collision_rect = make_range(xy(64, 16), pivot=.bottom_center);
	en.dmg_props_must_be_exact = true;
	en.health = 70;
	en.z_layer = Z_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	en.loot_drops[0] = .{id=.iron, amount=random_int_range(1, 2)};
	en.loot_drops[1] = .{id=.iron, amount=random_int_range(0, 1)};
}

player_update :: ()
{
	player := get_player();
	if !has_prop(player.props, .enabled) then return;

	// @cleanup
	
	disable_input: bool = app.disable_player_input;
	app.disable_player_input = false;
	
	tick_timer(*player.timer2, delta_t_scaled());
	
	player.input_axis = .{};
	if !disable_input
	{
		player.input_axis = WASDInputAxis();
		player.input_axis.y = 0.0;
	}
	
	sprinting := false;
	// set the movement dir
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
		
		player.x_speed_target = max_player_move_speed * mult;
		player.x_dir = sign(player.input_axis.x);
	}
	else
	{
		player.x_speed_target = 0.0;
	}
	
	// blocking
	// if key_down(.MOUSE_BUTTON_RIGHT)
	// 	&& has_prop(get_held_entity().props, .blockable)
	// 	&& (player.state == .idle || player.state == .walk)
	// {
	// 	player.is_blocking = true;
	// }
	// else
	// {
	// 	player.is_blocking = false;
	// }


		
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

	// DASH
	// randy: move everything here to simplify things. No longer using state since we'd like to preserve
	// running and stuff. I just cave man threw some variables in.
	tick_timer(*player.dash_cooldown_timer, delta_t_scaled());
	if player.dash_cooldown_timer == 0 && !disable_input && !player.dashing && app.frame.key_pressed[Input.Key_Code.SPACEBAR]
	{
		consume_key(.SPACEBAR);
		player.dashing = true;
		player.dash_timer = DASH_DURATION;
		player.dash_dir = player.x_dir;
		player.dash_initial_pos = player.pos;
		
		play_sound("dash", player.pos);
		
		// randy: this is kinda inconsistent due to the way I'm doing the velocity targeting...
		// player.velocity.x += 300.0 * player.x_dir;
	}
	if player.dashing
	{
		// randy: I'm gonna work on getting this feeling better 
		// I think I might have to knuckle down and get some proper friction controls in for the physics
		// because I think that's what is holding me back here.
		
		// randy: this way of doing things felt inconsistent with the physics
		// player.x_speed_accel = DASHING_MULT * PLAYER_ACCEL;
		// player.x_speed_decel = DASHING_MULT * PLAYER_DECEL;
		// player.x_speed_target = max_player_move_speed * DASHING_MULT;
		
		// randy: This feels really jarring at the moment, need to make it more physics-based
		// DASH_VEL :: 400.0;
		// player.pos.x += player.dash_dir * DASH_VEL * delta_t_scaled();
		
		// randy: ehhh same issues as velocity
		// player.acceleration.x = 4000.0 * player.dash_dir;
		
		// randy: at the end of the day, hard programming it like this is the most consistent, but it's a tad jarring
		// since we're not modelling proper physics.
		// Feels meaty though, so should be good enough for now.
		DASH_DISTANCE :: 50.0;
		alpha := 1-(player.dash_timer / DASH_DURATION);
		alpha = ease_out_exp(alpha, rate=4);
		player.pos.x = player.dash_initial_pos.x + DASH_DISTANCE * alpha * player.dash_dir;
		
		// player.frame.colour_multiplier.w = 1-(player.dash_timer / DASH_DURATION);
		
		if tick_timer(*player.dash_timer, delta_t_scaled())
		{
			player.dashing = false;
			#if !DISABLE_DASH_COOLDOWN then player.dash_cooldown_timer = DASH_COOLDOWN;
		}
	}

	HUNGER_TIMER_DURATION :: 120;
	//Probably should be damage event, how to handle several damage events?
	if tick_timer(*player.hunger_timer, delta_t_scaled())
	{
		player.hunger_timer = HUNGER_TIMER_DURATION;

		if player.hunger > 0 then player.hunger -= 1;

		if player.hunger <= 0 then player.health -= 1;
	}

	// process damage event
	if player.damage_event.amount != 0
	{
		defer memory_zero(*player.damage_event);
		dmg := player.damage_event;
		
		if player.state != .dash
		{
			#if !INVINCIBLE_PLAYER
			{
				player.health -= dmg.amount;
				player.health = clamp_bottom(0, player.health);
			}
			
			set_state(player, .damaged);
			// play_sound_old(.punch);
			
			app.camera.trauma += 0.4;
			
			player.x_dir = -sign(dmg.direction.x);
			player.velocity.x += -player.x_dir * 80.0;
		}
	}

	// damaged
	if player.state == .damaged
	{
		is_dead := player.health <= 0;
		if is_dead
		{
			set_state(player, .dying);
			player.velocity.x = 0;
			player.acceleration.x = 0;
			player.x_speed_target = 0;
		}
		else
		{
			if is_state_entry(player, .damaged)
			{
				entity_set_sprite(player, "char_hurt");
				play_sound("player_hit", player.pos);
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
			remove_props(*player.props, .enabled);
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
			
			play_animation(*player.attack_anim, .slash1_sword);
		}
		
		// enter axe swing
		if key_pressed(.MOUSE_BUTTON_LEFT)
			&& get_held_entity().item_id == .flint_axe
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .axe_swing_item);
		}

		// enter pickaxe swing
		if key_pressed(.MOUSE_BUTTON_LEFT)
			&& get_held_entity().item_id == .flint_pickaxe
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .pickaxe_swing_item);
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
				if has_prop(held_entity.props, .axe) || has_prop(held_entity.props, .pickaxe)
				{
					set_state(player, .chop);
				}
				else
				{
					set_state(player, .punch);
				}
				
			}
			else
			{
				set_state(player, .punch);
			}
		}
	}
	
	slash_hitbox: Range2;
	slash_hitbox.min = xy(-20, 0);
	slash_hitbox.max = xy(58, 45);
	if player.x_dir == -1 then slash_hitbox = range_flip_x(slash_hitbox);
	slash_hitbox = range_shift(slash_hitbox, player.pos);
	
	// This is done with a separate animation state
	// AXE
	if player.attack_anim.id == .axe_swing_item
	{
		if player.attack_anim.is_start
		{
			// play_sound("pop");
			// play_sound_old(.sword_swing_01);
		}
		
		axe_hitbox: Range2;
		axe_hitbox.min = xy(25, 0);
		axe_hitbox.max = xy(45, 24);
		if player.x_dir == -1 then axe_hitbox = range_flip_x(axe_hitbox);
		axe_hitbox = range_shift(axe_hitbox, player.pos);
		
		// hit
		if player.attack_anim.frame == 3 && player.attack_anim.frame_advanced
		{
			player_hit_thing(axe_hitbox);
			// debug_rect(axe_hitbox, 300);
		}
		
		if player.attack_anim.is_finish
		{
			set_state(player, .idle);
		}
	}

	// PICKAXE
	if player.attack_anim.id == .pickaxe_swing_item
	{
		if player.attack_anim.is_start
		{
			// play_sound("pop");
			// play_sound_old(.sword_swing_01);
		}
		
		axe_hitbox: Range2;
		axe_hitbox.min = xy(25, 0);
		axe_hitbox.max = xy(45, 24);
		if player.x_dir == -1 then axe_hitbox = range_flip_x(axe_hitbox);
		axe_hitbox = range_shift(axe_hitbox, player.pos);
		
		// hit
		if player.attack_anim.frame == 3 && player.attack_anim.frame_advanced
		{
			player_hit_thing(axe_hitbox);
			// debug_rect(axe_hitbox, 300);
		}
		
		if player.attack_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	// SLASH1
	if player.attack_anim.id == .slash1_sword
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
			player_hit_thing(slash_hitbox);
			// debug_rect(slash_hitbox, 300);
		}
		
		// combo into slash2
		if player.attack_anim.frame > 5
			&& key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .slash2_sword);
		}
		
		if player.attack_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	// SLASH2
	if player.attack_anim.id == .slash2_sword
	{
		if player.attack_anim.is_start
		{
			// play_sound_old(.sword_swing_02);
		}
		
		// hit
		if player.attack_anim.frame == 2 && player.attack_anim.frame_advanced
		{
			player_hit_thing(slash_hitbox);
			// debug_rect(slash_hitbox, 300);
		}
		
		// combo into slash3
		if player.attack_anim.frame > 4
			&& key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .slash3_sword);
		}
		
		if player.attack_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	// SLASH3
	if player.attack_anim.id == .slash3_sword
	{
		if player.attack_anim.is_start
		{
			// play_sound_old(.sword_swing_01);
		}
		
		// hit
		if player.attack_anim.frame == 2 && player.attack_anim.frame_advanced
		{
			player_hit_thing(slash_hitbox);
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
			player_hit_thing(punch_hitbox);
			//debug_rect(punch_hitbox, 1000);
			//play_sound_old(.punch);
		}
		
		if player.sprite_anim.is_finish
		{
			set_state(player, .idle);
		}
	}
	
	// player footsteps
	if player.sprite_id == .ron_walk_base
	{
		if player.sprite_anim.frame_advanced && (player.sprite_anim.frame == 3*4 || player.sprite_anim.frame == 7*4)
		{
			play_sound_global("footstep_player");
		}
	}
	if player.sprite_id == .ron_sprint_base
	{
		if player.sprite_anim.frame_advanced && (player.sprite_anim.frame == 7 || player.sprite_anim.frame == 19)
		{
			play_sound_global("footstep_player");
		}
	}

	// draw_sprite(0 , mouse_pos_in_world());
	//Rob: I need to slow the player when he's pulling the bow
	//Gotta Add Amunition
	if has_prop(get_held_entity().props, .bow)
	{
		bow := get_held_entity();
		POWER :: 800;
		if key_pressed(.MOUSE_BUTTON_RIGHT) && ammo_check()
		{
			play_animation(*player.attack_anim, .bow);
			bow.timer1 = 3.0;
		}
		if key_down(.MOUSE_BUTTON_RIGHT) && ammo_check()
		{

			if tick_timer(*bow.timer1, delta_t_scaled(), true)
			{
				//Stops the animation for the bow from playing (And Finishing)
				player.attack_anim.is_playing = false;
			} 
			else
			{
				reverse_tick_timer(*bow.timer2, delta_t_scaled());
			}
		}
		//When they release shoot the arrow
		if key_released(.MOUSE_BUTTON_RIGHT, true) && ammo_check()
		{
			ammo_check(true);
			if between(0.0,bow.timer1,3.0) {
				//If they have not waited the full charge time
				dam := cast(float)cast(int)(bow.timer2+0.5);
				en:=create_projectile(player.pos+xy(0,20), projectile_target_velocity(player.pos+xy(0,20), mouse_pos_in_world(),POWER * (1-(bow.timer1/3)), false), .arrow, damage =5*dam);
				player.attack_anim.frame = 2;
				player.attack_anim.time_til_next_frame = 0.01;
				player.attack_anim.is_playing = true;
				add_props(*en.props, .player);
			}
			else
			{
				en:=create_projectile(player.pos +xy(0,20), projectile_target_velocity(player.pos+xy(0,20), mouse_pos_in_world(),POWER, false), .arrow, damage= 20);
				player.attack_anim.is_playing = true;
				add_props(*en.props, .player);
			}
			bow.timer2 = 0;
		}
	}
}

// scuffed af
player_hit_thing :: (hitbox: Range2)
{
	player := get_player();
	
	held_item := get_resource(get_held_entity().item_id);
	
	hit_en : *Entity;
	
	did_hit := false;
	for * en: g_world.entities
		if is_enabled(en) && is_visible(en)
		&& en != player
	{
		against_rect := get_collision_rect(en);
		//debug_rect(against_rect, 1);
		//debug_rect(attack_hitbox, 1);
		if range_collide(hitbox, against_rect)
		{
			damage_props := get_resource(get_held_entity().item_id).props;
			add_props(*damage_props, .player);
			merge_props(*damage_props, held_item.props);
			landed := attempt_damage_entity(en, HIT_DAMAGE, player, damage_props);
			if landed
			{
				did_hit = true;
				en.damage_alpha = 1.0;
				
				hit_en = en;
			}
		}
	}
	
	if did_hit
	{
		app.camera.trauma += 0.45;
		
		// apply effects from weapon
		effect_prop_check(get_held_entity(), hit_en);
		// todo - change this to an axe prop ?
		if held_item.id == .flint_axe
		{
			emit := create_emitter(player.pos + xy(player.x_dir * 40.0, 16), .wood_spray);
			emit.x_dir = player.x_dir;
			play_sound("wood_hit", player.pos);
			// TODO - I need some kinda way of knowing if this hit has killed the entity, so we can play
			// the hit_break sound
		}
		
		if held_item.id == .flint_pickaxe
		{
			emit := create_emitter(player.pos + xy(player.x_dir * 40.0, 16), .rock_spray);
			emit.x_dir = player.x_dir;
			play_sound("rock_hit", player.pos);
		}
		
		if held_item.id == .flint_sword
		{
			play_sound("hit_impact", player.pos);
		}
	}
	else
	{
		if held_item.id == .flint_sword
		{
			play_sound("sword_swing_miss", player.pos);
		}
	}
}

// :player_render - search it for all the lil dumbass state tendrils
// We're altering entity state here so I can be a caveman and just get it working
render_player :: (en: *Entity)
{
	// draw the base player sprite
	draw_generic_entity(en);
	
	if !is_enabled(en) then return;

	flags := ifx en.x_dir == -1 then QuadFlags.x_flipped else 0;
	offset := make_transform(xy(16, -32));
	
	if en.attack_anim.is_finish
	{
		en.attack_anim.id = 0;
	}
	
	// TODO - needa lanch the vfx off as particles so it's not tied to the state
	playing_anim := false;
	if en.attack_anim.id ==
	{
		case .slash1_sword;
		draw_sprite(.slash1_sword, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.slash1_trail, en.pos, offset_trs=offset, z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
		
		case .slash2_sword;
		draw_sprite(.slash2_sword, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.slash2_trail, en.pos, offset_trs=offset, z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
		
		case .slash3_sword;
		draw_sprite(.slash3_sword, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.slash3_trail, en.pos, offset_trs=offset, z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
		
		case .axe_swing_item;
		draw_sprite(.axe_swing_item, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.axe_swing_trail, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;

		case .pickaxe_swing_item;
		draw_sprite(.pickaxe_swing_item, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.pickaxe_swing_trail, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
	}
	
	// draw floating items
	
	held_entity := get_held_entity();
	
	if !playing_anim
	{
		if held_entity.item_id == .flint_sword
		{
			trs := make_transform(xy(-30.0, 20.0 + xx sin(g_world.time_elapsed * 4)), -120);
			if abs(en.velocity.x) > 1
			{
				trs.translate.y -= abs(en.velocity.x) / 40.0;
				trs.translate.x -= en.x_dir * en.velocity.x / 50.0;
			}
			draw_sprite(.flint_sword, en.pos, offset_trs=trs, z_layer=en.z_layer, flags=flags);
		}
		else if held_entity.item_id == .flint_axe
		{
			trs := make_transform(xy(-14.0, 24.0 + xx sin(g_world.time_elapsed * 4)), 90);
			if abs(en.velocity.x) > 1
			{
				trs.translate.y -= abs(en.velocity.x) / 40.0;
				trs.translate.x -= en.x_dir * en.velocity.x / 50.0;
			}
			draw_sprite(.flint_axe, en.pos, offset_trs=trs, z_layer=en.z_layer, flags=flags);
		}
		else if held_entity.item_id == .flint_pickaxe
		{
			trs := make_transform(xy(-14.0, 24.0 + xx sin(g_world.time_elapsed * 4)), 90);
			if abs(en.velocity.x) > 1
			{
				trs.translate.y -= abs(en.velocity.x) / 40.0;
				trs.translate.x -= en.x_dir * en.velocity.x / 50.0;
			}
			draw_sprite(.flint_pickaxe, en.pos, offset_trs=trs, z_layer=en.z_layer, flags=flags);
		}
		else if held_entity.item_id == .bow_static
		{
			//Very Weird Maths
			//Adjust Angle of bow
			rotate := radians_to_degrees(get_angle(en.pos+xy(0,20), mouse_pos_in_world()));
			rotate = en.x_dir*(rotate-90)+90;
			trs := make_transform(xy(0,20), rotate);
			rotate_rads := degrees_to_radians(rotate);
			trs.translate =xy(10*cos(rotate_rads),15*sin(rotate_rads)+20);
			//Draw the pivot point
			//draw_sprite(0,en.pos, offset_trs=trs, z_layer=en.z_layer, animation_index=en.attack_anim.frame, flags=flags);
			draw_sprite(.bow, en.pos, offset_trs=trs, z_layer=en.z_layer, animation_index=en.attack_anim.frame, flags=flags);
			// Apparently always showing- Fix
			if ammo_check()
			{
				trs.translate =xy(10*cos(rotate_rads)-2.5*en.attack_anim.frame*cos(rotate_rads),15*sin(rotate_rads)+20-2.5*en.attack_anim.frame*sin(rotate_rads));
				draw_sprite(.arrow, en.pos, offset_trs=trs, z_layer=en.z_layer, animation_index=en.attack_anim.frame, flags=flags);
			}
		}
		else if held_entity.item_id != .nil && !has_prop(held_entity.props, .placeable)
		{
			// it's a regular item, put it out in front of the player
			trs := make_transform(xy(16.0, 20.0 + xx sin(g_world.time_elapsed * 4)));
			draw_sprite(held_entity.item_id, en.pos, offset_trs=trs, z_layer=en.z_layer, flags=flags);
		}
	}
}

// :animation
AnimationState :: struct
{
	id: SpriteID;
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
		if has_prop(en.props, .valid) && has_prop(en.props, .render_sprite) && !has_prop(en.props, .petrified)
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
	if is_valid(res) && anim.is_playing && res.frame_count > 1
	{
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
	for * en: app.world.entities if is_visible(en) && (has_prop(en.props, .rigid_body) || has_prop(en.props, .override_movement)) && !has_prop(en.props, .static)
	{
		// target velocity
		{
			// randy: todo
			// read acceleration section and maybe implement a simplier weighted average to the target?
			// http://higherorderfun.com/blog/2012/05/20/the-guide-to-implementing-2d-platformers/
			//
			assert(en.x_speed_target >= 0, "speed is absolute!");
			
			x_vel_target:= en.x_dir * en.x_speed_target * en.move_speed_scale;
			diff_sign:= sign(x_vel_target - en.velocity.x);
			//randy: NOTE - deceleration speed isn't doing anything at the moment
			constant:= en.x_speed_accel; //ifx x_vel_target == 0.0 then en.x_speed_decel else en.x_speed_accel;
			
			// this is basically just acceleration?
			en.velocity.x += diff_sign * constant * delta_t_scaled();
			
			if diff_sign != sign(x_vel_target - en.velocity.x) then en.velocity.x = x_vel_target;
			// if en == player then log("%\n", velocity.x);
		}
		ifx has_prop(en.props, .rigid_body) then en.acceleration.y = -GRAVITY;
			

		// en.acceleration.x = en.input_axis.x * 100.0;
		// en.acceleration.x -= en.velocity.x * 1;

		en.velocity += en.acceleration * delta_t_scaled();
		next_pos:= en.pos + en.velocity * delta_t_scaled();
		
		// randy: uhhh why was this commented out??
		// Rob: This kind of shouldn't happen as Acceleration only really effects velocity - 
		// technically you can put the en.x_speed_accel into the horizontal and it should function as if there is horizontal resistance
		// so resetting this does nothing essentially currently (as horizontal is handled differently and vertical is pretty much set to -GRAVITY)
		en.acceleration = xy(0);
		if en.speed_modified
		{
			en.acceleration = xy(en.velocity.x*en.speed_scale, 0);
		}
		
		if next_pos.y < 0
		{
			en.frame.did_land = true;
			en.frame.y_collision_dir = -1;
			next_pos.y = 0;
			en.velocity.y = 0;
		}
		
		if next_pos.x < 13
		{
			next_pos.x = 13;
			en.velocity.x = 0;
		}
		
		if next_pos.x > WORLD_RADIUS
		{
			next_pos.x = WORLD_RADIUS;
			en.velocity.x = 0;
		}
		
		en.pos = next_pos;
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
		// sort
		quick_sort(smol_notifications, x => (x.notif_remaining));
		
		set_next_pref_height(pct_parent(1));
		set_next_pref_width(pct_parent(1));
		box := make_box(.floating, "");
		push_parent(box);
		
		spacer(pct_parent(1, 0));
		for smol_notifications
		{
			LENGTH :: 10.0;
			if it.notif_remaining == 0.0 then it.notif_remaining = LENGTH;
			
			alpha := (it.notif_remaining / LENGTH);
			// randy: kinda scuffed but works lol. We need some kind of animation curve helpers.
			if alpha < 0.1
			{
				alpha = alpha * 10;
			}
			else
			{
				alpha = 1;
			}
			
			push_opacity(alpha);
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
	label("SHIFT - sprint");
	label("SPACE - dash");
	spacer(em(0.5));
	label("E - interact with highlighted object");
	label("TAB - inventory");
	label("Q - drop item");
	spacer(em(0.5));
	label("Left Click - use tool");
	label("Right Click Hammer - build mode");
	//label("Hold Right Click - block");
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
	
	// save and unload world
	if app.main_menu_alpha == 1.0 && app.world.initialized
	{
		serialise_world(*app.world);
		app.world = .{};
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
		// play_sound_old(.endgame);
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
	
	if app.game_over_alpha != 0
	{
		alpha := app.game_over_alpha;
		
		g_world.time_scale = 1-app.game_over_alpha;
		
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
		
		if button("SAVE").clicked
		{
			serialise_world(g_world);
		}

		if file_exists(SAVE_FILE) && button("LOAD").clicked
		{
			world_load();
		}
		spacer(em(0.5));
		divider();
		
		set_next_fill_col(hex_to_rgba(0xa35256ff));
		if button("RESTART").clicked
		{
			set_app_mode(.main_menu);
		}

		set_next_fill_col(hex_to_rgba(0xa35256ff));
		if button("QUIT").clicked
		{
			app.should_quit = true;
		}
	}
}

respawn_ui :: ()
{
	player := get_player();
	
	// enter respawn mode
	if app.interface_mode != .respawn_mode && player.health <= 0
	{
		set_interface_mode(.respawn_mode);
	}
	
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
			
			en := create_player();
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
		return has_prop(en.props, .interactable) || has_prop(en.props, .harvestable) || has_prop(en.props, .deconstructable);
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
	
	player_storage_slots := get_entity_storage_slots(get_player());
	
	// attempt to interact with them one-by-one
	hot_interactable: *Entity = get_nil_entity();
	for en: overlapped
	{
		if is_campfire(en)
		{
			if attempt_campfire_input(en)
			{
				hot_interactable = en;
				break;
			}
		}
		// randy: NOTE - gonna disable this for now since we've got the autopickup
		/*
		else if has_prop(en.props, .pick_up)
		{
			if can_store_item(player_storage_slots, en)
			{
				defer break;
				hot_interactable = en;
				
				if key_pressed(#char "E")
				{
					consume_key(#char "E");
					
					create_emitter(en.pos, .single_poof);
					new_event(Event.{kind=.pickup, entity=handle_from_entity(en)});
					attempt_store_item(player_storage_slots, en);
					play_sound_global("item_click");
				}
			}
		}
		*/
		else if is_base_totem(en)
		{
			app.frame.hovered_interactable = handle_from_entity(en); // randy: this probs isn't right, but ehhh
			if input_attempt_base_totem(en)
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
		// randy: we could move the deconstruct tool up top, but things broke for some reason before?
		// idk I'm just gonna do dis for now. Try it out again tho.
		else if (is_blueprint(en) || has_prop(en.props, .attack_target)) && !has_prop(get_held_entity().props, .deconstruct_tool)
		{
			if !is_valid(app.frame.hot_blueprint)
			{
				app.frame.hot_blueprint = handle_from_entity(en);
			}
			if input_attempt_blueprint(en)
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
				create_emitter(en.pos, .death_poof);
				
				play_sound_global("item_click");
				
				
				if en.archetype == 
				{
					// case .tall_grass;
					// reset_entity_props(en);
					// setup_tall_grass_stub(en);
					// spawn_items_at_location(en.loot_drops, en.pos);
					
					case .player;
					en.marked_for_destroy = true;
					// ideally this would be an override of the harvest of some sort
					// maybe we start having entity resources that're static?
					
					excess_items : [..]EntityHandle;
					
					// return inv to player
					for get_entity_storage_slots(en)
					{
						en := entity_from_handle(it);
						if en.item_id == 0 then continue;
						
						stored := attempt_store_item(get_entity_storage_slots(get_player()), en);
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
					// play_sound_old(.harvest);
					create_emitter(en.pos, .death_poof);
					
					en.marked_for_destroy = true;

					
					if en.item_id
					{
						// randy: TODO: FIX THIS!!

						item := get_resource(en.item_id);
						// drop the existing spent items
						spent_items: [en.remaining_items.count]ItemAmount;
						array_copy(spent_items, en.remaining_items);

						for * spent_items
						{
							if it.id == .nil then continue;
							//Broken into several lines for debugging
							recipe_amt := item.recipe[it_index].amount;
							remaining_amt := en.remaining_items[it_index].amount;
							it.amount = recipe_amt - remaining_amt;
						}
						/*

						if has_prop(en.props, .blueprint)
						{
							// subtract from health
							pct_return := cast(float)en.health / cast(float)en.max_health;
							for * spent_items
							{
								it.amount = xx (pct_return * cast(float)it.amount);
							}
						}
						*/
						
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

/*
get_corefire :: () -> *Entity
{
	return entity_from_handle(g_world.corefire_handle);
}
setup_corefire :: (en: *Entity)
{
	add_props(*en.props, .render_sprite, .placement_obstacle, .attack_target, .point_light);
	add_props(*en.recieve_damage_from, .monster);
	entity_set_sprite(en, .corefire_on);
	en.state = .on;
	en.archetype = .corefire;
	en.z_layer = Z_STRUCTURES;
	en.light_radius_t = 100.0;
	en.flicker_strength = 0.5;
	en.health = 10;
	
	// add_props(*en.props, .storage, .workbench, .interactable);
	// en.storage_slot_count = BASE_WORKBENCH_SLOT_COUNT;
}
update_corefire :: ()
{
	en := entity_from_handle(g_world.corefire_handle);
	
	if en.health > 0
	{
		// turn it on
		set_state(en, .on);
		if is_state_entry(en, .on)
		{
			add_props(*en.props, .attack_target);
			entity_set_sprite(en, .corefire_on);
			play_sound("fire_light", en.pos);
		}
		
		// process damage
		if en.damage_event.amount != 0
		{
			defer memory_zero(*en.damage_event);
			dmg := en.damage_event;
			
			create_emitter(en.pos, .death_poof);

			en.health = 0;
		}
	}
	
	// :(
	if en.health <= 0
	{
		set_state(en, .off);
		if is_state_entry(en, .off)
		{
			remove_props(*en.props, .attack_target);
			entity_set_sprite(en, .corefire_off);
			play_sound("fire_putout", en.pos);
			create_notification(tprint("Death is now permanent"));
		}
	}
	
	// randy: if player is dead, game over or respawn depending on state of corefire
	player := get_player();
	if player.health <= 0
	{
		if en.health > 0
		{
			set_interface_mode(.respawn_mode);
		}
		else
		{
			set_interface_mode(.game_over);
		}
	}
}
*/

// randy: This actually is just an upgraded version of the campfire. I've simplified the cooking recipes.
// the constraint is there will only ever be one thing cooking. And it's a clear -> single transform
// Can just keep using the campfire then :)
// CONTENT BAYBEE! Fking stop inventing new systems, we've got enough right now.
//
// OOOohh idea: the furnace can be used to queue up items instead of it being fed 1-by-1, still make it cook slow tho
//
is_furnace :: (en: Entity) -> bool
{
	return has_prop(en.props, .furnace);
}
setup_furnace :: (en: *Entity)
{
	en.item_id = .furnace;
	add_props(*en.props, .furnace, .interactable, .render_sprite, .structure);
	entity_set_sprite(en, .furnace_off);
	en.z_layer = Z_STRUCTURES;
	en.state = .off;
}
input_attempt_furnace :: (en: *Entity) -> bool
{
	return true;
}
update_furnaces :: ()
{
	
}
render_furnace :: (en: Entity)
{
	
}


is_campfire :: inline (en: Entity) -> bool
{
	// changed this to a prop so we can remove its functionality
	return has_prop(en.props, .campfire);
}

setup_campfire :: (en : *Entity)
{
	en.item_id = .campfire;
	add_props(*en.props, .campfire, .interactable, .render_sprite, .structure);
	entity_set_sprite(en, .campfire_off);
	en.archetype = .campfire;
	en.z_layer = Z_STRUCTURES;
	en.state = .off;
}
attempt_campfire_input :: (camp : *Entity) -> bool
{
	can_interact:= false;
	
	// try for a cookable item
	if camp.cooking_item_id == .nil
	for stored : get_entity_storage_slots(get_player())
	{
		item_en := entity_from_handle(stored);
		item_res := get_resource(item_en.item_id);
		if !is_valid(item_res) then continue;
		
		if has_prop(item_en.props, .cookable)
		{
			// randy: NOTE
			// I merged these paths into one. Since the attempt input serves as both "can we interact" being called every frame,
			// and the "okay, actually do the interaction then pls"
			can_interact = true;
			if key_pressed(#char "E")
			{
				consume_key(#char "E");
				play_sound_global("item_click");
				
				camp.cooking_item_id = item_res.id;
				camp.cooking_timer = item_res.cook_time;
				
				create_notification(tprint("-1 % ", get_display_name(item_res)));
				consume_item(item_en);
			}
			
			if can_interact
			{
				camp.about_to_consume_item = item_res.id;
				return true;
			}
		}
	}
	
	// try for a fuel item
	if camp.remaining_fuel_time < MAX_FUEL_TIME
	for stored : get_entity_storage_slots(get_player())
	{
		item_en := entity_from_handle(stored);
		item_res := get_resource(item_en.item_id);
		if !is_valid(item_res) then continue;
		
		if has_prop(item_en.props, .fuel)
		{
			can_interact = true;
			if key_pressed(#char "E")
			{
				consume_key(#char "E");
				play_sound("fire_light", camp.pos);
				
				camp.remaining_fuel_time += item_res.fuel_amount;
				
				create_notification(tprint("-1 % ", get_display_name(item_res)));
				consume_item(item_en);
			}
			
			if can_interact
			{
				camp.about_to_consume_item = item_res.id;
				return true;
			}
		}
	}
	
	return false;
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
			
			play_sound("pop", camp.pos);
		}
	}
	
	// off
	if camp.state == .off
	{
		if is_state_entry(camp, .off)
		{
			create_emitter(camp.pos, .death_poof);
			entity_set_sprite(camp, .campfire_off);
			play_sound("fire_putout", camp.pos);
			remove_props(*camp.props, .point_light);
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
			add_props(*camp.props, .point_light);
			play_sound("fire_light", camp.pos);
		}
		
		camp.light_radius_t = 200.0;
	}
}
render_campfire :: inline (camp : Entity)
{
	draw_generic_entity(camp);
	
	if camp.cooking_item_id
	{
		draw_sprite(camp.cooking_item_id, camp.pos + xy(0, 10), z_layer=camp.z_layer+0.5);
	}
	
	// remaining fuel bar
	if camp.remaining_fuel_time != 0
	{
		pct := camp.remaining_fuel_time / MAX_FUEL_TIME;
		
		draw_rect(make_range(xy(16.0 * pct, 2), pivot=.top_center), z_layer=Z_UI, trs=make_transform(camp.pos - xy(0, 3)));
	}
	
	// completion progress wheel
	if camp.cooking_timer != 0
	{
		// randy: TODO - should probably do this via the UI system so we can animate it better
		// This is good enough for now tho.
		item_res := get_resource(camp.cooking_item_id);
		pct_complete := 1-(camp.cooking_timer / item_res.cook_time);
		anim_frame :int= xx (cast(float)(get_resource(.completion_wheel).frame_count-1) * pct_complete);
		draw_sprite(.completion_wheel, camp.pos + xy(0, -20), z_layer=Z_UI, animation_index=anim_frame);
	}
}

update_point_lights :: ()
{
	cbuff := get_global_const_buff();
	for * en : g_world.entities if is_visible(en) && has_prop(en.props, .point_light)
	{
		pulse_speed := 5.0;
		amplitude := 5.0;
		{
			// randy: this'll randomise it based on each entity, but also remain constant each frame
			push_random_seed(en.id);
			pulse_speed += random_get_within_range(0, 1);
			amplitude += random_get_within_range(0, 1);
		}
		pulse_speed *= en.flicker_strength;
		amplitude *= en.flicker_strength;
		variance := ifx en.light_radius_t != 0 then (sin(cast(float)en.time_alive * pulse_speed) * amplitude);
		animate_to_target(*en.light_radius, en.light_radius_t + variance, delta_t_scaled());
		
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
	en.pickup_cooldown = random_get_within_range(0.0, 0.4);
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
	if item.render_offset != make_transform(xy(0, 0), 0)
	{
		en.render_offset = merge_transform(en.render_offset,item.render_offset);
	}
	if has_prop(en.props, .casting_medium)
	{

	}
	if has_prop(en.props, .reduce_render_scale)
	{
		en.render_offset.scale *= 0.2;
	}

}

update_items :: ()
{
	player := get_player();
	player_storage_slots := get_entity_storage_slots(player);
	
	// get all storage slots in the world lol
	world_storage_slots : [..]*EntityHandle;
	world_storage_slots.allocator = temp;
	array_reserve(*world_storage_slots, 128);
	for * en : app.world.entities if is_valid(en) && has_prop(en.props, .storage)
	{
		for * en.storage_slots
		{
			array_add(*world_storage_slots, it);
		}
		for * en.hotbar_slots
		{
			array_add(*world_storage_slots, it);
		}
	}
	array_add(*world_storage_slots, *app.mouse_held_item);
	
	// update item
	for * en : app.world.entities if is_valid(en) && has_prop(en.props, .item)
	{
		// set world vis
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
		if is_in_inventory 
		{
			remove_props(*en.props, .visible);
		}
		else
		{
			add_props(*en.props, .visible);
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
		
		// auto-move to player if in range
		// randy: auto_pickup_items is non-constant because we might want to give this as an upgrade to the player?
		if g_world.auto_pickup_items
			&& can_store_item(player_storage_slots, en)
			&& !is_in_inventory
			&& tick_timer(*en.pickup_cooldown, delta_t(), zero_counts_as_complete=true)
		{
			PICK_UP_RADIUS :: 50.0;
			if abs(distance(player.pos, en.pos)) < PICK_UP_RADIUS
			{
				animate_to_target(*en.pos, player.pos, delta_t(), rate=30);
			}
			
			STORE_RADIUS :: 5.0;
			if abs(distance(player.pos, en.pos)) < STORE_RADIUS
			{
				play_sound_global("item_click");
				attempt_store_item(player_storage_slots, en);
			}
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

get_player_items :: () -> [..]*Entity
{
	slots := get_player_storage_slots();
	items : [..]*Entity;
	items.allocator = temp;
	for slot : slots
	{
		en := entity_from_handle(slot);
		if is_valid(en) then array_add(*items, en);
	}
	return items;
}

get_player_storage_slots :: () -> [..]*EntityHandle
{
	return get_entity_storage_slots(get_player());
}

get_entity_storage_slots :: (en: *Entity) -> [..]*EntityHandle
{
	slots : [..]*EntityHandle;
	slots.allocator = temp;
	array_reserve(*slots, 128);
	
	for * en.hotbar_slots
	{
		// I'm not using the 0 slot. Idk why this is??
		if it_index == 0 then continue;
		if it_index == get_hotbar_slot_count() + 1 then break;
		array_add(*slots, it);
	}
	
	for * en.storage_slots
	{
		if it_index == en.storage_slot_count then break;
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
	
	stored_slot : *EntityHandle = null;
	
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
				stored_slot = it;
				break;
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
			stored_slot = it;
			break;
		}
	}
	
	if stored_slot
	{
		new_event(Event.{kind=.pickup, entity=handle_from_entity(entity_to_store)});
		return stored_slot;
	}
	else
	{
		// inventory full
		return null;
	}
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

// old hand-held torch
/*
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
*/

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

	if !app.disable_player_input && 
	   (app.interface_mode != .inventory) &&
	   (app.interface_mode != .build) &&
	   (app.interface_mode != .workbench) &&
		app.frame.wheel_delta != 0
	{
		player.hot_slot += ifx app.frame.wheel_delta > 0 then -1 else 1;
	}

	// when it goes out of range, we just reset
	if player.hot_slot > get_hotbar_slot_count()
	{
		player.hot_slot = 0;
	}
	else if player.hot_slot < 0
	{
		player.hot_slot = get_hotbar_slot_count();
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
	
	// :crafting segment
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
			app.crafting_slot_index += 1;
		}
		else if app.frame.wheel_delta > 0
		{
			app.crafting_slot_index -= 1;
		}
		
		// put all available crafting recipes in an array
		crafting_recipes : [..]ArcResource;
		crafting_recipes.allocator = temp;
		for unlocked : g_world.unlocked_recipes
			if unlocked
		{
			res := get_resource(xx it_index);
			if !has_prop(res.props, .blueprint) array_add(*crafting_recipes, res);
		}
		
		// fix up index to be in bounds
		app.crafting_slot_index = clamp(app.crafting_slot_index, 0, crafting_recipes.count-1);
		
		count_each_side := 4;
		active_slot := app.crafting_slot_index;
		
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
						app.crafting_slot_index = index;
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
				
				recipe_res := crafting_recipes[app.crafting_slot_index];
				{
					push_parent(make_box(.draw_bg | .draw_border, ""));
					box := ui_item_icon(tprint("crafting_slot_%", slot_count), recipe_res.id, 0, slot_size, slot_icon_padding);
					sig := signal_from_box(box);
					
					// attempt to craft the item
					if sig.pressed
					{
						// do we have all the materials for the recipe?
						storage_slots := get_entity_storage_slots(get_player());
						has_enough_for_recipe:= true;
						if !has_prop(recipe_res.props, .blueprint)
						{
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
							if !has_prop(recipe_res.props, .blueprint)
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
								new_event(.{kind=.craft, entity=handle_from_entity(held_en)});
							}
							else
							{
								// craft the new item and put it in our cursor
								new_item := create_world_item(recipe_res.id);
								app.mouse_held_item = handle_from_entity(new_item);
								new_event(.{kind=.craft, entity=handle_from_entity(new_item)});
							}
							
							play_sound_global("item_click");
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
				if !has_prop(recipe_res.props, .blueprint)
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
						app.crafting_slot_index = index;
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
		
		if !is_inventory_open && is_valid(item_en)
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

snap_to_tile_grid :: (world_pos: float) -> float
{
	return round(world_pos / TILE_WIDTH) * TILE_WIDTH;
}

world_to_tile_pos :: (world_pos: float) -> int
{
	return xx round(world_pos / TILE_WIDTH);
}

get_world_tile_array :: () -> []*Entity
{
	strucs : []*Entity = NewArray(xx WORLD_RADIUS/TILE_WIDTH + 8, *Entity, allocator=temp);
	for * en : g_world.entities if is_valid(en) && has_prop(en.props, .structure)
	{
		strucs[world_to_tile_pos(en.pos.x)] = en;
	}
	return strucs;
}

// randy: returns a sorted array of all the world structures
get_world_structures :: () -> [..]*Entity
{
	struc_array : [..]*Entity;
	struc_array.allocator = temp;
	for * en: g_world.entities if is_valid(en) && has_prop(en.props, .structure)
	{
		array_add(*struc_array, en);
	}
	quick_sort(struc_array, x => (x.pos.x));
	#if false
	{
		for en : struc_array
			print("%, ", en.item_id);
		if struc_array.count then print("\n");
	}
	return struc_array;
}

structure_placement :: ()
{
	player := get_player();
	
	held_en : *Entity = *nil_entity;
	held_item : *ArcResource;
	if app.build_mode_alpha_t == 1.0
	{
		// selected thingy from the build mode
		held_item = get_resource(app.active_blueprint_id);
	}
	else
	{
		// from inventory
		held_en = ifx is_valid(app.mouse_held_item) then entity_from_handle(app.mouse_held_item) else get_held_entity();
		held_item = get_resource(held_en.item_id);
	}
	
	if has_prop(held_item.props, .placeable)
	{
		app.placement_alpha_t = 1.0;
	}
	else
	{
		app.placement_alpha_t = 0.0;
	}
	animate_to_target(*app.placement_alpha, app.placement_alpha_t, delta_t(), rate=UI_ANIMATE_RATE);
	
	world_structures := get_world_structures();
	
	is_placing := app.placement_alpha_t == 1.0;
	if is_placing
	{
		app.show_cursor = true;
		
		pos: Vector2 = xy(round(mouse_pos_in_world().x), 0);
		pos.x = clamp_bottom(0.0, pos.x);
		tile_pos := world_to_tile_pos(pos.x);
		
		// snap 'er into a good spot depending on what we've got in our hands
		snap_radius :: 6.0;
		snap_points: [..]Vector2;
		overlapped_obstacles: [..]*Entity;
		overlapped_obstacles.allocator = temp;
		is_valid_spot : bool;
		has_enough_for_recipe : bool; ;
		error_msg : string;
		
		if !has_prop(held_item.props, .free_place)
		{
			// snap to grid
			pos.x = snap_to_tile_grid(pos.x);
		}
		
		does_overlap := false;
		for against_en : world_structures
			if get_resource(against_en.item_id).tile_blocking_layer == held_item.tile_blocking_layer
		{
			// our range
			half_width :int= xx floor(cast(float)held_item.structure_tile_width / 2.0);
			range := Range1.{xx (tile_pos - half_width), xx (tile_pos + half_width)};
			
			// do they be overlapping dou?
			if range_overlaps(tile_range_from_entity(against_en), range)
			{
				does_overlap = true;
				array_add(*overlapped_obstacles, against_en);
				break;
			}
		}
		
		if does_overlap
		{
			// randy: ehhhh we probs don't need an error here
			// error_msg = "Existing structure";
			is_valid_spot = false;
		}
		else
		{
			is_valid_spot = true;
		}
		
		if !has_prop(held_item.props, .can_place_outside_base)
		{
			if is_base_active()
			{
				if !range_contains(get_base_range(), pos.x)
				{
					is_valid_spot = false;
					error_msg = "Out of base range";
				}
				
				/*
				if !has_prop(held_item.props, .only_placable_inside_core_base)
				&& !range_contains(get_base_outer_range(), pos.x)
				{
					is_valid_spot = false;
					error_msg = "Out of base range";
				}
				*/
			}
			else
			{
				is_valid_spot = false;
				error_msg = "Base core not activated";
			}
		}

		// mouse tooltip
		{
			set_next_floating_x(app.mouse_pos.x);
			set_next_floating_y(world_pos_to_screen(xy(0, -10)).y);
			set_next_flags(.floating);
			set_next_rect_pivot_x(.center);
			set_next_pref_size(size_by_children(1));
			auto_column();
			
			if error_msg != "" && (!is_valid_spot)
			{
				set_next_text_justify_x(.center);
				set_next_pref_width(text_dim(1));
				label("%###", error_msg);
			}
			
			// flip
			/*
			if has_prop(held_item.props, .flippable)
			{
				if key_pressed(#char "R")
				{
					consume_key(#char "R");
					app.placement_x_dir *= -1;
				}
				
				set_next_text_justify_x(.center);
				set_next_pref_width(text_dim(1));
				icon(.rotate_icon, "", em(1));
				label("R###");
			}
			else
			{
				app.placement_x_dir = 1;
			}
			*/
		}
		
		// Do they even have enough to build it?
		has_enough_for_recipe = true;
		storage_slots := get_entity_storage_slots(get_player());
		for * recipe_item : held_item.recipe
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
			}
		}
		if !has_enough_for_recipe
		{
			is_valid_spot = false;
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
		if key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			
			if is_valid_spot && has_enough_for_recipe
			{
				en := create_entity();
				held_item.setup_func(en);
				add_props(*en.props, .deconstructable);
				en.x_dir = app.placement_x_dir;
				en.pos = pos;
				en.biome = g_world.player_biome;
				add_props(*en.props, .placed_by_player);
				
				play_sound("struc_hammer", en.pos);
				new_event(.{kind=.build, entity=handle_from_entity(en)});
				
				if is_valid(held_en)
				{
					held_en.item_count -= 1;
					if held_en.item_count <= 0
					{
						held_en.marked_for_destroy = true;
					}
				}

				// Remove items from inventory
				for * recipe_item : held_item.recipe
				{
					remaining_amount := recipe_item.amount;
					for * storage_slots
					{
						en := entity_from_handle(<<it);
						if is_valid(en) && en.item_id == recipe_item.id
						{
							remaining_amount -= en.item_count;
							if en.item_count <= recipe_item.amount
							{
								en.item_count = 0;
							}
							else
							{
								en.item_count -= recipe_item.amount;
							}
							if en.item_count <= 0 en.marked_for_destroy = true;
						}
						if remaining_amount <= 0 then break;
					}
				}
			}
			else
			{
				app.frame.tried_to_place_but_failed = true;
			}
		}
	}
}

// particle system

// use this, for the kind, make a new one at each :particle jump point
create_emitter :: (pos: Vector2, kind: EmitterKind) -> *Entity
{
	// TODO - pass down the thing it's attached to so we can call up and not be dumb
	en := create_entity("", g_world.player_biome);
	add_props(*en.props, .particle_emitter, .render_sprite);
	en.pos = pos;
	en.emitter = kind;
	return en;
}

new_particle :: () -> *Particle
{
	app.particle_cursor = (app.particle_cursor + 1) % app.particles.count;
	p := *app.particles[app.particle_cursor];
	<<p = .{};
	p.flags |= .valid;
	return p;
}

empower_entity :: (en: *Entity)
{
	add_props(*en.props, .particle_emitter);
	en.emitter = .empowered;

	en.max_health *= 2;
	en.health = en.max_health;
}

ParticleFlags :: enum
{
	valid 			:: 1<<0;
	fade_in 	:: 1<<1;
	fade_out :: 1<<2;
	
	gravity :: 1<<3;
	
	animate_sprite :: 1<<20;
	loop 										:: 1<<21;
	paused 								:: 1<<22;
}

Particle :: struct
{
	pos: Vector2;
	vel: Vector2;
	col:= WHITE;
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

EmitterKind :: enum
{
	nil;
	
	jump_dust;
	landing_dust;
	void_ambiance;
	death_poof;
	single_poof;
	parry;
	wood_spray;
	rock_spray;
	empowered;
	// :particle

	//Rob
	poisoned;
	on_fire;
	p_heal;
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
			
			// :particle
			
			case .rock_spray;
			en.marked_for_destroy = true;
			for 0..20
			{
				p := new_particle();
				p.flags |= .fade_out | .gravity;
				p.pos = en.pos + xy(random_get_within_range(-4, 4), random_get_within_range(-1, 1));
				p.col = lerp(#run hex_to_rgba(0x62797aff), WHITE, random_get_within_range(0, 0.5));
				p.vel = xy(en.x_dir * random_get_within_range(150, 300), random_get_within_range(50, 100));
				p.z_layer = Z_ENTITY_VFX;
				p.time_left = random_get_within_range(2, 5);
				p.trs.scale = xy(random_get_within_range(1, 2));
			}
			
			case .wood_spray;
			en.marked_for_destroy = true;
			for 0..20
			{
				p := new_particle();
				p.flags |= .fade_out | .gravity;
				p.pos = en.pos + xy(random_get_within_range(-4, 4), random_get_within_range(-1, 1));
				p.col = lerp(#run hex_to_rgba(0xa07946ff), WHITE, random_get_within_range(0, 0.5));
				p.vel = xy(en.x_dir * random_get_within_range(150, 300), random_get_within_range(50, 100));
				p.z_layer = Z_ENTITY_VFX;
				p.time_left = random_get_within_range(2, 5);
				p.trs.scale = xy(random_get_within_range(1, 2));
			}
			
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

			case .empowered;
			for 0..random_int_range(25, 50)
			{
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-en.collision_rect.max.x, en.collision_rect.max.x), random_get_within_range(10, en.collision_rect.max.y + 10));
				p.vel = en.velocity/2.0 + xy(random_get_within_range(-0.5, 0.5), random_get_within_range(0.5, 1));
				p.col = WHITE;
				p.time_left = 20;
				p.z_layer = 0;
				p.flags |= ParticleFlags.animate_sprite | .fade_out;
				p.sprite = "p_ember";
			}

			//Rob
			case .poisoned;
			en.marked_for_destroy = true;
			if tick_on_app_frequency(0.18)
			{
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-6, 6), random_get_within_range(-10, 5));
				p.vel = en.velocity/2 + xy(random_get_within_range(-5, 5), random_get_within_range(6, 20));
				p.col = WHITE;
				p.flags |= ParticleFlags.animate_sprite;
				p.sprite = "poison_bubble";
				//Randomise Layer so not too many on the front of the model
				if random_bool()
				p.z_layer = Z_ENTITY_PFX;
				else
				p.z_layer = Z_ENTITY_VFX;
				p.pivot = .bottom_center;
				p.play_rate = random_get_within_range(2.5, 5);
				//Transform the sprite so that they look less uniform
				// p.trs.scale = xy(2);
			}


			case .on_fire;
			//Add Lighting Effect cause Fire- may have to change lighting radius depending on size of original ent
			en.light_radius = 30.0;
			en.light_radius_t = 200 + (sin(cast(float)g_world.time_elapsed * 5) * 5);
			//Time between flickers
			if tick_on_app_frequency(0.45)
			{
				en.light_radius = 30.0 + random_get_within_range(-5, 5);
				en.light_radius_t = 200 + (sin(cast(float)g_world.time_elapsed * 5) * 5);
			}
			en.marked_for_destroy = true;

			//Put Delay into Entity - For an Emitter
			if tick_on_app_frequency(0.1)
			{
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-3, 3), random_get_within_range(-8, 5));
				p.vel = xy(random_get_within_range(-5, 5), random_get_within_range(3, 10));
				p.col = WHITE;
				p.flags |= ParticleFlags.animate_sprite;
				p.sprite = "p_ember";

				p.pivot = .bottom_center;

				//p.z_layer = ifx  random_bool() Z_ENTITY_PFX else Z_ENTITY_VFX;
				if random_bool()
				p.z_layer = Z_ENTITY_PFX;
				else
				p.z_layer = Z_ENTITY_VFX;

				p.play_rate = random_get_within_range(0.8, 1.5);
				//p.trs = make_transform(xy(0,0),0,random_get_within_range(0.75, 2));;
			}

			case .p_heal;
			en.marked_for_destroy = true;
			if tick_on_app_frequency(0.46)
			{
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-5, 5), random_get_within_range(-10, 5));
				p.vel = en.velocity/2 + xy(random_get_within_range(-10, 10), random_get_within_range(6, 20));
				p.col = WHITE;
				p.flags |= ParticleFlags.animate_sprite;
				p.sprite = "p_heart";
				//Randomise Layer so not too many on the front of the model
				if random_bool()
				p.z_layer = Z_ENTITY_PFX;
				else
				p.z_layer = Z_ENTITY_VFX;
				p.pivot = .bottom_center;
				p.play_rate = random_get_within_range(4, 6);
				//Transform the sprite so that they look less uniform
				p.trs.scale = xy(random_get_within_range(1, 1.5));
			}

		}
}
	
	// particles
	for * p : app.particles
	{
		// apply gravity
		if p.flags & .gravity
		{
			p.vel.y -= 600 * delta_t_scaled();
		}
		
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
			if p.sprite == "" // single blank particle
			{
				adjust_trs := p.trs;
				adjust_trs.translate = p.pos;
				draw_rect(make_range(xy(1, 1)), col=p.col, trs=adjust_trs, z_layer=p.z_layer);
			}
			else // sprite particle
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
				
				adjust_trs := p.trs;
				adjust_trs.translate = p.pos;
				
				draw_rect(rect, texture=texture_from_sprite(sprite), uv_rect=uv_rect, z_layer=p.z_layer, trs=adjust_trs);
			}
		}
	}
}

//NOTE(fhomolka): damage indicators use timer1 as a 'longevity' measurement
DMG_INDICATOR_LIFETIME :: 1;

setup_dmg_indicator :: (en: *Entity)
{
	en.timer1 = DMG_INDICATOR_LIFETIME;
	en.health = en.max_health;
	add_props(*en.props, .dmg_indicator); 
}

create_dmg_indicator :: () -> *Entity
{
	en := create_entity("dmg_indicator");
	setup_dmg_indicator(en);
	return en;
}

dmg_indicator_update :: ()
{
	for * en : g_world.entities if is_valid(en) && has_prop(en.props, .dmg_indicator)
	{
		if tick_timer(*en.timer1, delta_t())
		{
			en.marked_for_destroy = true;
		}
		alpha := en.timer1 / DMG_INDICATOR_LIFETIME;
		push_text(tprint("%", en.health), font_size_pct(0.3), col=xyzw(1, 1, 1, alpha), z_layer=Z_UI, trs=make_transform(en.pos));
		en.pos.y += 30 * delta_t();
		
		// randy: the ui system really shouldn't be used for something as simple as this
		// I still have no idea why it was crashing on occasion though. Weird...
		/*
		// push into the correct space
		push_parent(ui.frame.root); // this makes us skip past the usual root :screen_space
		push_quad_flags(0); // removes the default .skip_camera_transform, kinda sketch lol
		
		p := make_box(0, tprint("dmg_hud_%", en.id));
		push_parent(p);
		animate_to_target(*p.value, indicator_alpha_t, delta_t(), rate = 20);
		indicator_alpha := p.value;
		
		if indicator_alpha == 0 then continue;
		
		push_opacity(indicator_alpha);
		
		// defaults
		push_font(FONT_MAIN);
		push_font_size(10);
		push_text_justify_x(.center);
		push_pref_width(em(2));
		push_pref_height(em(1));
		
		// container for ui
		set_next_floating_x(en.pos.x);
		set_next_floating_y(en.pos.y);
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_child_layout_axis(.X);
		set_next_fill_col(xyzw(0, 0, 0, 0.5));
		set_next_rect_pivot_x(.center);
		set_next_rect_pivot_y(.top);
		row := make_box(BoxFlags.floating, tprint("%_dmg_ind", en.id));
		// row.flags |= .draw_fill
		push_parent(row);

		set_next_pref_width(size_by_children(1));
		set_next_pref_height(size_by_children(1));
		//auto_column();
		
		label("%###", en.health);

		en.pos.y += 30 * delta_t();

		if tick_timer(*en.timer1, delta_t(), zero_counts_as_complete=true)
		{
			en.marked_for_destroy = true;
		}
		*/
	}
}


BiomeType :: enum u32
{
	INITIAL;
	OTHER;
	COUNT;
}

serialise_world :: (world: *WorldState)
{
	sav_file, success := file_open(SAVE_FILE, for_writing=true);
	cereal_write(*sav_file, *app.world, "world_save");
	file_close(*sav_file);
}

deserialise_world :: (world: *WorldState)
{
	sav_file, success := file_open(SAVE_FILE, for_writing=false);
	cereal_read(*sav_file, *app.world, "world_save");
	file_close(*sav_file);
}

unlock_recipe :: (item_id: ItemID, silent:= false)
{
	g_world.unlocked_recipes[item_id] = true;
	item_res := get_resource(item_id);
	if !silent
	{
		if has_prop(item_res.props, .blueprint)
		{
			create_notification(tprint("% blueprint unlocked", get_display_name(item_res)));
		}
		else
		{
			create_notification(tprint("% recipe unlocked", get_display_name(item_res)));
		}
	}
}

update_recipe_unlocks :: ()
{
	// add to the known items list
	for event: g_world.events_this_frame
	{
		if event.kind ==
		{
			case .craft; #through;
			case .place; #through;
			case .pickup;
			en := entity_from_handle(event.entity);
			en.item_id;
			if !en.item_id then continue;
			g_world.known_items[en.item_id] = true;
		}
	}
	
	// look thru all locked recipes to see if we meet the requirements to unlock
	for * app.resources
		if (it.flags & .item)
		&& has_prop(it.props, .craftable)
		&& !g_world.unlocked_recipes[it.id] // skip if already unlocked
	{
		// figure out if we've seen the ingredients for it
		all_ingredients_known := true;
		for it.recipe
		{
			if it.id == .nil then break;
			all_ingredients_known = all_ingredients_known && g_world.known_items[it.id];
		}
		
		// pre-requisite checks
		should_unlock := false;
		if it.id ==
		{
			// crafting recipe :progression
			
			case .ground_torch_off;
			for event: g_world.events_this_frame
				if event.kind == .build && entity_from_handle(event.entity).item_id == .campfire
			{
				should_unlock = true;
			}
			
			case .destroy_hammer;
			for event: g_world.events_this_frame
				if event.kind == .place
			{
				should_unlock = true;
			}
			
			case .hammer;
			for event: g_world.events_this_frame
				if event.kind == .activate && is_base_totem(entity_from_handle(event.entity))
			{
				should_unlock = true;
			}
			
			case .wood_defense_wall;
			for event: g_world.events_this_frame
				if event.kind == .build && entity_from_handle(event.entity).item_id == .wood_back_wall
			{
				should_unlock = true;
			}
			
			case .wood_back_wall;
			for event: g_world.events_this_frame
				if event.kind == .craft && entity_from_handle(event.entity).item_id == .hammer
			{
				should_unlock = true;
			}
			
			// randy: easy peasy ingredient unlock
			// case .flint_sword;
			// case .campfire; #through;
			case .flint_axe;
			should_unlock = all_ingredients_known;
			
			case;
			// randy: by default, we don't unlock it, so either work it into the game design with unlock pages
			// or just do a cheeky ingredient unlock
		}
		
		// unlock recipe yayyy
		if should_unlock
		{
			unlock_recipe(it.id);
		}
	}
}

heal_entity :: (en: *Entity, amount: int)
{
	en.health += amount;
	en.health = min(en.health, en.max_health);
}

consume_item :: (en: *Entity)
{
	if en.item_id
	{
		en.item_count -= 1;
		if en.item_count == 0 then en.marked_for_destroy = true;
	}
}

is_ground_torch :: (en: Entity) -> bool
{
	return has_prop(en.props, .ground_torch);
}
setup_ground_torch :: (en: *Entity)
{
	// randy: I'm just gonna force these on for now, no point in turning them off.
	en.item_id = .ground_torch_off;
	add_props(*en.props, .ground_torch, .render_sprite, .point_light, .structure);
	entity_set_sprite(en, .ground_torch_off);
	en.z_layer = Z_STRUCTURES;
}
update_ground_torches :: ()
{
	for * en : g_world.entities
		if is_valid(en) && is_ground_torch(en)
	{
		if en.state != .on
		{
			entity_set_sprite(en, .ground_torch_on);
			set_state(en, .on);
			en.light_radius_t = 200.0;
		}
	}
}


//:Spell :Skill

SKILL :: struct 
{
	spell_id: Spell_Name;
	cooldown: float;

	//Kinda duplicate to entities, but it allows you to just insert them straight in when making the entity
	//props: Properties(EntityProps);
	//sprite_id: SpriteID;

	//Maybe just an Entity in general?
	//Could Swap as a sub part of entity too
	casting_medium: * Entity;
	//Maybe custom effects (functions etc that can be added)
	//Ambitious but I wanted to keep it open if we wanted
	custom_effects: Properties(Custom_Spell_Effects);
	_effect: Effect;
}

//need better name
Spell_Name :: enum
{
	nil;

	//Leaving the idea of custom spells in. Could be just a drag and drop rune system eg. type(projectile, static, buff), element (fire,water,earth), shape(wall, circle, square, shield)
	CUSTOM;
	max;
}

Custom_Spell_Effects :: enum 
{
	nil;

	blood_drain;
	magic_arrows;
	heal;

	max;
}

spell_blood_drain :: (caster: *Entity, target_entity: *Entity)
{
	//Does Something maybe deals damage and heals for that amount / less 
}

spell_magic_arrows :: (caster: *Entity, target_pos: Vector2, sprite_id: SpriteID = .magic_arrow_1, amount:= 5, damage:= 3.0)
{
	POWER :: 200;
	for 1..amount
	{
		start_pos := caster.pos +xy(0, cast(float)get_sprite(caster.sprite_id).height)+ xy(random_get_within_range(-10,10), random_get_within_range(2,15));
		//start_pos := caster.pos +xy(0, cast(float)get_sprite(caster.sprite_id).height) + xy(0,30.0);
		en := create_projectile(start_pos, projectile_target_velocity(start_pos, target_pos + xy(0,0),0.1, false), .magic_arrow_1, damage , "", rigid = false);
		if caster == get_player()
		{
			add_props(*en.props, .spell, .player);
		} else {
			add_props(*en.props, .spell, .monster);
		}	
		
		en.lifetime = 12.0;
		en.spell_effect = .magic_arrows;
		en.timer1 = 1.0;
	}
}
//This is literally the same as heal_entity oops- Dunno if i keep as is or just change to heal_entity :: Maybe think about flags
spell_heal :: (caster: *Entity, amount:= 10)
{
	caster.is_healing = true;
	caster.heal_time = 1.0;
	ifx caster.max_health <= caster.health+amount then caster.health = caster.max_health else caster.health += amount;
}
 
create_projectile :: (init_position: Vector2, init_velocity: Vector2, sprite_id: SpriteID, damage:= 1.0, debug_name:= "",  rigid:= true, lifetime:= 10.0) -> *Entity
{
	en := create_entity(debug_name);
	en.health = 100;
	en.max_health = en.health;
	en.z_layer = Z_PROJECTILES;
	en.sprite_id = sprite_id;
	//Have to check this works or for bigger version they will be reduced
	en.collision_rect = rect_from_sprite(en.sprite_id);
	en.damage = damage;
	en.lifetime = lifetime;
	//If it will be affected by gravity or not
	if rigid
	{
		add_props(*en.props, .render_sprite, .rigid_body, .projectile, .reduce_render_scale);
	} else {
		add_props(*en.props, .render_sprite, .projectile, .reduce_render_scale, .override_movement);
	}

	en.pos = init_position;

	//for now remove wind res
	en.x_speed_accel = 0.0;
	en.velocity = init_velocity;
	//SHould there be an assert to make sure that the sprite ID exists? 
	entity_set_sprite(en, sprite_id);

	return en;
}


update_spells :: () 
{
	for * en : app.world.entities 
	{
		//en.heal_time is there to ensure it ticks
		if en.is_healing || en.heal_time > 0.0
		{
			create_emitter(en.pos+xy(0,20), .p_heal);
			ifx tick_timer(*en.heal_time, delta_t_scaled(),true) then en.is_healing = false;
		}

		if has_prop(en.props, .valid) && has_prop(en.props, .spell)
		{
			if en.time_alive >= en.lifetime
			{
				en.marked_for_destroy = true;
			}
			//Concept test 
			if en.spell_effect ==
			{
				//case .blood_drain;

				case .magic_arrows;
				if en.timer1 != 0
				{
					if tick_timer(*en.timer1, delta_t_scaled(), true) 
					{
						en.velocity = en.velocity *2000;
					}
				}
				//Shouldn't need an update but just in case
				//case .heal;

				//case;
			}
		}
	}


	player := get_player();
	//::Heal Spell
	spell_cooldown_ready := tick_timer(*get_held_entity().cooldown, delta_t_scaled(), true);
	last_notif :bool;
	//Check if held item is casting medium with last notif
	if has_prop(get_held_entity().props, .casting_medium) 
	{
		last_notif = tick_timer(*get_held_entity().notif_remaining, delta_t_scaled(), true);
		app.show_cursor = true;
	}

	if spell_cooldown_ready
	{	//:Heal
		if key_down(.MOUSE_BUTTON_RIGHT)
		&& has_prop(get_held_entity().props, .cast_heal)
		&& (player.state == .idle) 
		{	
			spell_heal(player);
			get_held_entity().cooldown = 5.0;
			get_held_entity().notif_remaining = 1.0;	
		} //:Magic Arrows
		else if key_down(.MOUSE_BUTTON_RIGHT)
		&& has_prop(get_held_entity().props, .cast_magic_arrows)
		&& (player.state == .idle) 
		{	

			spell_magic_arrows(player, mouse_pos_in_world(), damage = 4);

			get_held_entity().cooldown = 4.0;
			#if ROB_TESTING
			{
				//get_held_entity().cooldown = 1.0;
			}
			get_held_entity().notif_remaining = 1.0;	
		}
		else if (key_down(.MOUSE_BUTTON_RIGHT)
			&& has_prop(get_held_entity().props, .casting_medium) 
			&& !(player.state == .idle) 
			&& last_notif)
		{ //Rob: should you have to stand still to cast
			create_notification("Stand still to cast!");
			get_held_entity().notif_remaining = 1.0;
		}

	} 
	else if (!spell_cooldown_ready 
		&& key_down(.MOUSE_BUTTON_RIGHT)
		&& has_prop(get_held_entity().props, .casting_medium) 
		&& last_notif)
	{
		create_notification("Cooldown is not ready yet");
		get_held_entity().notif_remaining = 1.0;
	} 
	// Targetting Check
	
}

ammo_check :: (consume := false) -> bool 
{
	for enh : get_player().storage_slots
	{
		en := entity_from_handle(enh);
		if en.item_id == .arrow
		{
			if consume
			{
				consume_item(en);
			}
			return true;
		}
	}
	return false;
}
//Counts up instead of down- can also be used in if statements- Kinda Redundant
reverse_tick_timer :: (timer: *float, delta_t: float) -> float
{
	<<timer += delta_t;
	return <<timer;
}
//Returns a bool for a comparison between 2 numbers
between :: (Lower : float, input:float, Higher: float) -> bool
{
	out : bool;
	ifx Lower < input && input <= Higher then out = true else out = false;
	return out;
}
//Currently as Entities can only have one spell effect useless- Will keep in if in future can have more than one
//This could be used to add multiple effects to entities technically
add_spells :: (en : *Entity, props : Properties )
{
	if has_prop(props, .cast_heal)
	{
		en.spell_effect = .heal;
	}
	if has_prop(props, .cast_blood_drain)
	{
		en.spell_effect = .blood_drain;
	}
	if has_prop(props, .cast_magic_arrows)
	{
		en.spell_effect = .cast_magic_arrows;
	}	
}

// randy:
// The idea here is we right click with the builder hammer, enter build mode, which we can scroll around and
// select the structures we wanna place down. Then exit when doneskis.
//
build_mode_ux :: ()
{
	if app.interface_mode != .build
		&& get_held_entity().item_id == .hammer
		&& !app.disable_player_input
	{
		if key_pressed(.MOUSE_BUTTON_RIGHT)
		{
			consume_key(.MOUSE_BUTTON_RIGHT);
			set_interface_mode(.build);
		}
	}
	
	// exit with esc
	if app.interface_mode == .build && key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		set_interface_mode(.nil);
	}
	// exit with left click
	if app.interface_mode == .build && key_pressed(.MOUSE_BUTTON_RIGHT)
	{
		consume_key(.MOUSE_BUTTON_RIGHT);
		set_interface_mode(.nil);
	}
	// exit when we change items
	if app.interface_mode == .build && get_held_entity().item_id != .hammer
	{
		set_interface_mode(.nil);
	}
	
	// target to alpha
	if app.interface_mode == .build
	{
		app.build_mode_alpha_t = 1.0;
	}
	else
	{
		app.build_mode_alpha_t = 0.0;
	}
	animate_to_target(*app.build_mode_alpha, app.build_mode_alpha_t, delta_t());
	
	slot_size := em(UI_SLOT_SIZE);
	margin := em(UI_MARGIN);
	slot_icon_padding := em(UI_SLOT_ICON_PADDING);
	slot_spacing := em(UI_SLOT_SPACING);
	slot_bg_col := COL_UI_BG;
	slot_border_col := GRAY;
	
	if app.build_mode_alpha != 0
	{
		// todo - crank up the visual coldness with a lut?
		
		// scroll up n down
		if app.frame.wheel_delta < 0
		{
			app.frame.wheel_delta = 0;
			app.blueprint_slot_index += 1;
		}
		else if app.frame.wheel_delta > 0
		{
			app.frame.wheel_delta = 0;
			app.blueprint_slot_index -= 1;
		}
		
		// randy: TODO
		// Make everything hit the one code path and add in a destroy mode at the beginning
		//
		// put all available crafting recipes in an array
		blueprints : [..]ArcResource;
		blueprints.allocator = temp;
		for unlocked : g_world.unlocked_recipes
			if unlocked
		{
			res := get_resource(xx it_index);
			if has_prop(res.props, .blueprint) array_add(*blueprints, res);
		}
		
		// fix up index to be in bounds
		app.blueprint_slot_index = clamp(app.blueprint_slot_index, 0, blueprints.count-1);
		// update active selected bp
		if blueprints.count > 0 then app.active_blueprint_id = blueprints[app.blueprint_slot_index].id;
		
		is_enabled := app.build_mode_alpha_t == 1.0;
		if is_enabled
		{
			app.show_cursor = true;
		}
		push_disable_signal(!is_enabled);
		push_opacity(app.build_mode_alpha);
		
		set_next_child_layout_axis(.Y);
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		push_parent(make_box(.floating, ""));
		spacer(pct_parent(1, 0)); // push to the top
		
		// set_next_pref_width(pct_parent(1));
		// set_next_text_justify_x(.center);
		// label("%", get_display_name(get_resource(app.active_blueprint_id)));

		// list out materials
		{
			recipe_res := blueprints[app.blueprint_slot_index];

			set_next_child_layout_axis(.X);
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(pct_parent(1));
			set_next_opacity(app.build_mode_alpha);
			// set_next_bg_col(COL_UI_BG * 0.5);
			bg_box := make_box(.clickable, "build_mode_materials_box");
			push_parent(bg_box);
			
			padding(pct_parent(1, 0)); 
			
			storage_slots := get_entity_storage_slots(get_player());

			for recipe_item : recipe_res.recipe
			{
				set_next_pref_height(slot_size);
				set_next_pref_width(slot_size); 
				push_parent(make_box(.draw_bg, ""));
				box, icon := ui_item_icon(tprint("blueprint_slot_%_material_%", app.blueprint_slot_index, it_index), recipe_item.id, recipe_item.amount, slot_size, slot_icon_padding);
				sig := signal_from_box(box);
				if sig.hovering
				{
					set_next_rect_pivot_y(.bottom);
					push_tooltip();
					item_tooltip(recipe_item.id);
				}
				
				// do we be missing it dou?
				missing_item := false;
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
					missing_item = true;
				}
				
				if missing_item
				{
					icon.multiply_col = RED;
				}
				
				// error flash
				if missing_item && app.last_frame.tried_to_place_but_failed
				{
					icon.target = 1.0;
				}
				if animate_to_target(*icon.value, icon.target, delta_t(), rate=40.0) && icon.target == 1.0 then icon.target = 0;
				if icon.value != 0
				{
					icon.render_adjust_trs.scale = xy(1.0 + icon.value * 0.2);
				}
			}
		}
			
		// building list
		{
			// parent bg box
			set_next_child_layout_axis(.X);
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(pct_parent(1));
			set_next_opacity(app.build_mode_alpha);
			// set_next_bg_col(COL_UI_BG * 0.5);
			bg_box := make_box(.clickable, "build_mode_box");
			push_parent(bg_box);
			
			padding(pct_parent(1, 0)); 
			
			set_next_pref_width(size_by_children(1));
			set_next_pref_height(slot_size);
			auto_row();
			
			count_each_side := 4;
			active_slot := app.blueprint_slot_index;
			
			push_pref_width(slot_size);
			push_pref_height(slot_size);
			
			if blueprints.count > 0
			{
				// TODO - merge these paths lol
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
						
						recipe_res := blueprints[index];
						push_parent(make_box(.draw_bg, ""));
						box := ui_item_icon(tprint("blueprint_slot_%", slot_count), recipe_res.id, 0, slot_size, slot_icon_padding);
						sig := signal_from_box(box);
						if sig.pressed
						{
							app.blueprint_slot_index = index;
						}
						if sig.hovering
						{
							set_next_rect_pivot_y(.bottom);
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
					
					recipe_res := blueprints[app.blueprint_slot_index];
					{
						push_parent(make_box(.draw_bg | .draw_border, ""));
						box := ui_item_icon(tprint("blueprint_slot_%", slot_count), recipe_res.id, 0, slot_size, slot_icon_padding);
						sig := signal_from_box(box);
						
						// tooltip
						if sig.hovering
						{
							set_next_rect_pivot_y(.bottom);
							push_tooltip();
							item_tooltip(recipe_res.id);
						}
						
						slot_count += 1;
					}
					
					set_next_pref_height(slot_size);
					set_next_pref_width(size_by_children(1));
					set_next_bg_col(BLACK * 0.7);
					set_next_flags(.draw_bg);
					auto_row();
					
				}
				
				// bottom
				for active_slot+1..active_slot+count_each_side
				{
					index := it;
					if index < blueprints.count
					{
						opacity := top_opacity();
						if slot_count == count_each_side * 2
						{
							opacity *= 0.5;
						}
						push_opacity(opacity);
						
						recipe_res := blueprints[index];
						push_parent(make_box(.draw_bg, ""));
						box := ui_item_icon(tprint("blueprint_slot_%", slot_count), recipe_res.id, 0, slot_size, slot_icon_padding);
						sig := signal_from_box(box);
						if sig.pressed
						{
							app.blueprint_slot_index = index;
						}
						if sig.hovering
						{
							set_next_rect_pivot_y(.bottom);
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
	}
}


/*
is_base_valid :: () -> bool, left_wall:*Entity, right_wall:*Entity
{
	right_defense_wall := entity_from_handle(app.right_defense_wall);
	left_defense_wall := entity_from_handle(app.left_defense_wall);
	if is_valid(right_defense_wall) && is_valid(left_defense_wall)
	{
		return true, left_defense_wall, right_defense_wall;
	}
	else
	{
		return false, left_defense_wall, right_defense_wall;
	}
}
*/

/*
get_outer_walls :: () -> left: *Entity, right: *Entity
{
	DEBUG_PRINT_LIST :: false;
	DEBUG_SET_COLOUR :: false;
	totem := entity_from_handle(g_world.base_totem_handle);
	
	// grab a sorted list of all the structures in the world
	struc_array : [..]*Entity;
	struc_array.allocator = temp;
	for * en: g_world.entities if is_valid(en) && has_prop(en.props, .structure)
	{
		array_add(*struc_array, en);
	}
	quick_sort(struc_array, x => (x.pos.x));
	#if DEBUG_PRINT_LIST
	{
		for en : struc_array
			print("%, ", en.item_id);
		if struc_array.count then print("\n");
	}
	
	// where do the totem be?
	totem_index := 0;
	for struc_array if it == totem then totem_index = it_index;
	
	wall_width := get_sprite_size(.wood_back_wall).x;
	
	// find right wall
	right_defense_wall := get_nil_entity();
	{
		index := totem_index + 1;
		last_valid_back_wall_pos := totem.pos.x; // this allows for a gap in the wall atm, but oh well
		while index < struc_array.count
		{
			defer index += 1;
			en := struc_array[index];
			if has_prop(en.props, .blueprint) then continue;
			
			// break if we've gone too far without a wall
			if en.pos.x > last_valid_back_wall_pos + wall_width then break; // might need a +0.5 ?
			
			if is_defense_wall(en)
			{
				right_defense_wall = en;
			}
			else if is_back_wall(en)
			{
				last_valid_back_wall_pos = en.pos.x;
			}
			
			#if DEBUG_SET_COLOUR then en.frame.colour_multiplier = GREEN;
		}
		#if DEBUG_SET_COLOUR then right_defense_wall.frame.colour_multiplier = BLACK;
	}
	
	// find left wall
	left_defense_wall := get_nil_entity();
	{
		index := totem_index - 1;
		last_valid_back_wall_pos := totem.pos.x;
		while index >= 0
		{
			defer index -= 1;
			en := struc_array[index];
			if has_prop(en.props, .blueprint) then continue;
			
			// break if we've gone too far without a wall
			if en.pos.x < last_valid_back_wall_pos - wall_width then break; // might need a +0.5 ?
			
			if is_defense_wall(en)
			{
				left_defense_wall = en;
			}
			else if is_back_wall(en)
			{
				last_valid_back_wall_pos = en.pos.x;
			}
			
			#if DEBUG_SET_COLOUR then en.frame.colour_multiplier = GREEN;
		}
		#if DEBUG_SET_COLOUR then left_defense_wall.frame.colour_multiplier = BLACK;
	}
	
	return left_defense_wall, right_defense_wall;
}
*/

is_base_totem :: (en: Entity) -> bool
{
	return has_prop(en.props, .base_totem);
}

get_base_range :: () -> Range1
{
	totem := entity_from_handle(g_world.base_totem_handle);
	range := Range1.{0, totem.pos.x + BASE_BASE_RADIUS};
	
	range.max += BASE_BASE_RADIUS * totem.upgrade_count;
	
	return range;
}

is_base_active :: () -> bool
{
	totem := entity_from_handle(g_world.base_totem_handle);
	return totem.state == .on;
}

get_totem_recipe_from_upgrade_count :: (upgrade_count: int) -> []ItemAmount
{
	recipe := NewArray(1, ItemAmount, allocator=temp);
	recipe[0] = .{id=.monster_essence, amount=8 * xx pow(2, xx upgrade_count)};
	return recipe;
}

set_totem_upgrade_count_and_recipe :: (en: *Entity, upgrade_count: int)
{
	en.upgrade_count = upgrade_count;
	memory_zero(*en.remaining_items_for_upgrade);
	array_copy(en.remaining_items_for_upgrade, get_totem_recipe_from_upgrade_count(upgrade_count));
}

setup_base_totem :: (en: *Entity)
{
	add_props(*en.props, .base_totem, .interactable, .render_sprite, .attack_target, .structure, .draw_health_bar);
	add_props(*en.recieve_damage_from, .monster);
	entity_set_sprite(en, .base_totem);
	en.z_layer = Z_BASE_TOTEM;
	en.item_id = .base_totem;
	en.health = BASE_MAX_HEALTH;
	set_totem_upgrade_count_and_recipe(en, 0);
}

finish_upgrade_of_entity :: (en: *Entity)
{
	// this is just assuming we're the base totem rn, but you could imagine this being a callback for a generic .upgrade
	set_totem_upgrade_count_and_recipe(en, en.upgrade_count + 1);
	play_sound("totem_on", en.pos);
	camera_shake(0.5);
}

input_attempt_base_totem :: (en: *Entity) -> bool
{
	if en.state == .on
	{
		// randy: TODO - pull this out into a generic .upgrade action (when I've got another one for an example)
		for item_en : get_player_items()
		{
			item_res := get_resource(item_en.item_id);
			
			for * upgrade_item : en.remaining_items_for_upgrade
				if upgrade_item.amount > 0
			{
				if upgrade_item.id == item_res.id
				{
					if key_pressed(#char "E")
					{
						consume_key(#char "E");
						consume_item(item_en);
						upgrade_item.amount -= 1;
						
						play_sound("item_click", en.pos);
						
						// are we done upgrading??
						finished := true;
						for * en.remaining_items_for_upgrade
						 if it.amount != 0
						{
							finished = false;
							break;
						}
						if finished
						{
							finish_upgrade_of_entity(en);
						}
					}
					return true;
				}
			}
		}
	}
	else
	{
		if key_pressed(#char "E")
		{
			consume_key(#char "E");
			set_state(en, .on);
			new_event(.{kind=.activate, entity=handle_from_entity(en)});
		}
		return true;
	}
	
	return false;
}

// randy: TODO
// don't have a hard constraint on there being walls. It's implicit.
// As soon as you activate it, a message will show
// "Protect your core."

update_base_totem :: (totem: *Entity)
{
	if totem.damage_event.amount != 0
	{
		defer memory_zero(*totem.damage_event);
		
		totem.health -= totem.damage_event.amount;
		totem.health = max(totem.health, 0);
		totem.damage_alpha = 1.0;
		
		play_sound("wood_hit_break", totem.pos);
		
		if totem.health <= 0
		{
			set_state(totem, .off);
			convert_to_blueprint(totem);
		}
	}
	
	if totem.state == .on
	{
		if is_state_entry(totem, .on)
		{
			play_sound("totem_on", totem.pos);
			camera_shake(0.5);
		}
	}
	else if totem.state == .off
	{
		if is_state_entry(totem, .off)
		{
		}
	}
}

render_base_totem :: (en: Entity)
{
	draw_generic_entity(en);
	
	// randy: cracks on top, this could probs be generic? hold off for a few implementations first tho
	if en.health < en.max_health
	{
		pct := entity_health_pct(en);
		
		quad := draw_sprite(.base_totem_cracks, en.pos, z_layer=en.z_layer-0.1);
		quad.col.w = 1.0-pct;
	}
	
	// glow when it's on
	if en.state == .on
	{
		quad := draw_sprite(.base_totem_glow, en.pos, z_layer=en.z_layer-0.2);
		// quad.col.w = 0.95 + sin(cast(float)g_world.time_elapsed * 4) / 20.0;
	}
	
	// remaining items for upgrade hud
	{
		is_hovered := app.frame.hovered_interactable.entity_id == en.id;
		alpha_t := ifx is_hovered && en.state == .on then 1.0 else 0.0;
			
		
		set_next_floating_x(world_pos_to_screen(en.pos).x);
		set_next_floating_y(world_pos_to_screen(en.pos).y);
		set_next_flags(.floating);
		p := make_box(0, tprint("upgrade_items_%", en.id));
		push_parent(p);
		animate_to_target(*p.value, alpha_t, delta_t(), rate = 20);
		alpha := p.value;
		
		if alpha != 0
		{
			push_opacity(alpha);
			
			// container for ui
			set_next_floating_y(5 * (1-alpha));
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			set_next_child_layout_axis(.X);
			set_next_fill_col(xyzw(0, 0, 0, 0.5));
			set_next_rect_pivot_x(.center);
			set_next_rect_pivot_y(.top);
			row := make_box(BoxFlags.floating, "");
			push_parent(row);
			
			recipe := get_totem_recipe_from_upgrade_count(en.upgrade_count);
			for remaining: en.remaining_items_for_upgrade
			{
				if remaining.id == .nil then break;
				assert(remaining.id == recipe[it_index].id);
				item := get_item(remaining.id);
				
				set_next_pref_width(size_by_children(1));
				set_next_pref_height(size_by_children(1));
				auto_column();
			
				icon(get_display_sprite_id(item), "", em(2), horizontal_pad_pct=0.3);
				
				label("%/%###", recipe[it_index].amount - remaining.amount, recipe[it_index].amount);
			}
		}
	}
}

render_base_hud :: ()
{
	totem := entity_from_handle(g_world.base_totem_handle);
	base_range := get_base_range();
	// outer_range := get_base_outer_range();
	
	if totem.state == .on
	{
		draw_sprite(.base_mark, xy(base_range.min, -20), z_layer=Z_GROUND-0.1);
		draw_sprite(.base_mark, xy(base_range.max, -20), z_layer=Z_GROUND-0.1);
		
		// draw_sprite(.outer_marker, xy(outer_range.max, -20), z_layer=Z_GROUND-0.1);
	}
}

//TODO(fhomolka): Do the whole item insertion thing once the altar is built

is_boss_altar :: inline (en: *Entity) -> bool
{
	return has_prop(en.props, .boss_altar);
}

setup_boss_altar :: (en: *Entity)
{
	add_props(*en.props, .interactable, .render_sprite, .structure, .boss_altar, .deconstructable);
	//add_props(*en.recieve_damage_from, .monster);
	entity_set_sprite(en, .boss_altar);
	en.z_layer = Z_STRUCTURES;
	en.item_id = .boss_altar;
	en.health = BASE_MAX_HEALTH;
}

render_boss_altar :: (en: *Entity)
{
	draw_generic_entity(en);
	draw_sprite(.boss_altar_glow, en.pos, z_layer=Z_STRUCTURES-0.2);

	rare_item_positions := Vector2.[
		.{en.pos.x - 42, en.pos.y + 3},
		.{en.pos.x - 22, en.pos.y + 3},
		.{en.pos.x + 22, en.pos.y + 3},
		.{en.pos.x + 46, en.pos.y + 3},
	];

	for * pos : rare_item_positions
	{
		draw_sprite(.rare_item, pos, z_layer=Z_STRUCTURES-0.2);
	}
}

boss_altar_update :: ()
{

	altar : *Entity;

	for * en : g_world.entities if has_prop(en.props, .boss_altar)
	{
		altar = en;
	}

	for event: g_world.events_this_frame
				if event.kind == .build && entity_from_handle(event.entity).item_id == .boss_altar
	{
		boss := create_boss();
		boss.pos = altar.pos;
		boss.pos.y = 100;

		app.disable_player_input = true;
	}
}

setup_cave_back :: (en: *Entity)
{
	en.debug_name = "cave_back";
	en.z_layer = Z_STRUCTURES;
	add_props(*en.props, .render_sprite);
	entity_set_sprite(en, .cave_edge_back);
}

create_cave_back :: inline () -> *Entity
{
	en := create_entity();
	setup_cave_back(en);
	return en;
}

setup_cave_front :: (en: *Entity)
{
	en.debug_name = "cave_front";
	en.z_layer = Z_FRONT_VFX;
	add_props(*en.props, .render_sprite);
	entity_set_sprite(en, .cave_edge_front);
}

create_cave_front :: inline () -> *Entity
{
	en := create_entity();
	setup_cave_front(en);
	return en;
}

setup_boss_portal :: (en: *Entity)
{
	//add_props(*en.props, .portal, .interactable, .blueprint);
	add_props(*en.props, .render_sprite, .blueprint, .interactable, .structure);
	en.item_id = .boss_portal;
	en.z_layer = Z_PORTAL;
	entity_set_sprite(en, .boss_portal_off);
	item_res := get_resource(en.item_id);
	array_copy(en.remaining_items, item_res.recipe);
}

create_boss_portal :: () -> *Entity
{
	en := create_entity();
	setup_boss_portal(en);
	return en;
}


setup_spikes :: (en: *Entity)
{
	en.item_id = .barbed_vines;
	en.archetype = .trap;
	en.z_layer = Z_TRAPS;
	en.health = 100;
	en.damage = 1;
	entity_set_sprite(en, "barbed_vines");
	add_props(*en.props, .rigid_body, .static, .render_sprite, .trap, .structure);

}
update_trap :: ()
{
	for * target_entity : g_world.entities if is_valid(target_entity) && has_prop(target_entity.props, .attack_player)
	{
		against_rect := range_shift(target_entity.collision_rect, get_absolute_position(target_entity));
		for * en : g_world.entities if is_valid(en) && has_prop(en.props, .trap)
		{
			attack_hitbox := range_shift(en.collision_rect, get_absolute_position(en));
			if range_collide(against_rect, attack_hitbox)
				{
					target_entity.speed_modified = true;
					if reverse_tick_timer(*target_entity.last_damaged, delta_t_scaled()) > 0.5
					{
						attempt_damage_entity(target_entity, 1, en, make_props(EntityProps.trap, .player), false);
						target_entity.last_damaged = 0.0;
						en.health -= 1;
						//Only damages Enemies 100 times before dying
						if en.health <= 0
						{
							en.marked_for_destroy = true;
						}
					}
					break;
				} 
				else 
				{
					target_entity.speed_modified = false;
				}
		}
	}
}

tile_range_from_entity :: (en: Entity) -> Range1
{
	tile_pos := world_to_tile_pos(en.pos.x);
	half_width :int= xx floor(cast(float)get_resource(en.item_id).structure_tile_width / 2.0);
	range := Range1.{xx (tile_pos - half_width), xx (tile_pos + half_width)};
	return range;
}

get_overlapping_structures_in_range :: (range: Range1, ignore_self: *Entity = null) -> [..]*Entity
{
	strucs := get_world_structures();
	overlapping : [..]*Entity;
	overlapping.allocator = temp;
	for en : strucs
	{
		if ignore_self == en then continue;
		
		against_range := tile_range_from_entity(en);
		if range_overlaps(against_range, range)
		{
			array_add(*overlapping, en);
		}
	}
	return overlapping;
}


//Currently only does the cutscene
setup_boss :: (en: *Entity)
{
	en.max_health = 100;
	en.health = 100;
	en.z_layer = Z_MONSTER;
	add_props(*en.props, .render_sprite, .rigid_body, .boss);
	entity_set_sprite(en, .ogre_idle);
	en.collision_rect = rect_from_sprite(.ogre_idle);

	set_state(en, .idle);
}

create_boss :: () -> *Entity
{
	en := create_entity("boss");
	setup_boss(en);
	return en;
}

boss_update :: ()
{
	boss: *Entity = get_nil_entity();
	for * en : g_world.entities if has_prop(en.props, .boss)
	{
		boss = en;
	}

	if boss == get_nil_entity() then return;

	print("boss y pos: %\n", boss.pos.y);

	if boss.pos.y >= 1 then return;

	if boss.state == .idle then set_state(boss, .block);

	if boss.state == .block
	{
		if is_state_entry(boss, .block)
		{
			boss.timer1 = 1.5;
		}

		if tick_timer(*boss.timer1, delta_t_scaled(), zero_counts_as_complete=true)
		{
			set_state(boss, .dash);
		}
	}

	if boss.state == .dash
	{
		if is_state_entry(boss, .dash)
		{
			// play_sound_old(.pop);
			create_notification("rawr xD", true);
			//app.should_quit = true;
			boss.timer1 = 1.0;
		}

		if tick_timer(*boss.timer1, delta_t_scaled(), zero_counts_as_complete=true)
		{
			set_state(boss, .chop);
		}

		opacity := 1.0 - boss.timer1;
		push_opacity(opacity);
		set_next_pref_width(px(xx app.window_w));
		set_next_pref_height(px(xx app.window_h));
		make_box(.floating | .draw_bg, "");
	}

	if boss.state == .chop
	{
		set_next_pref_width(px(xx app.window_w));
		set_next_pref_height(px(xx app.window_h));
		make_box(.floating | .draw_bg, "");
	}
}