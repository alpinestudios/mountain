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
	should_load_game: bool;
	window: Window_Type;
	window_w : s32 = WINDOW_X;
	window_h: s32 = WINDOW_Y;
	saved_window: Saved_Window_Info;
	is_fullscreen := false;
	mouse_pos: Vector2;
	settings: UserSettings;
	
	// sound stuff
	silence_snapshot: *FMOD_STUDIO_EVENTINSTANCE;
	day_snapshot: *FMOD_STUDIO_EVENTINSTANCE;
	night_snapshot: *FMOD_STUDIO_EVENTINSTANCE;
	darkness_snapshot: *FMOD_STUDIO_EVENTINSTANCE;
	
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
	camera_focus_target : s8 = 1;
	
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
	particles: [256]Particle;
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
	settings_menu_alpha: float;
	settings_menu_alpha_t: float;
	workbench_alpha: float;
	workbench_alpha_t: float;
	build_mode_alpha: float;
	build_mode_alpha_t: float;
	item_place_mode_alpha: float;
	item_place_mode_alpha_t: float;
	// transient interface state
	active_storage: EntityHandle;
	active_workbench: EntityHandle;
	active_campfire: EntityHandle;
	placement_x_dir:= 1;
	mouse_held_item: EntityHandle;
	blueprint_slot_index: int = 0;
	active_blueprint_id: ItemID;
	placing_item: EntityHandle;
	last_known_placing_item: ItemID;
	
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
		do_crafting_error_flash: bool;
	}

	saving_thread: *Thread;
}

WorldState :: struct
{
	initialized: bool;
	simulating: bool = false;
	first_world_frame:= true;
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
	day_started: bool = true;
	days_survived: int= INITIAL_DAYS_SURVIVED;
	enemies : [128]EntityHandle; // TODO - @linked list rework so this is serialisable
	spawn_timer: float;
	spawn_timer_counter: int;
	boss_spawned: bool;
	
	//
	// PLAYER state stuff
	//
	unlocked_recipes: [AppState.resources.count]bool;
	recipes_given: [AppState.resources.count]bool;
	known_items: [AppState.resources.count]bool;
	respawn_timer: float;
	auto_pickup_items: bool = AUTO_PICKUP_ITEMS;
}

UserSettings :: struct
{
	volume: float;
	keybinds: KeyBinds;
}

KeyBinds :: struct
{
	move_left: Input.Key_Code;
	move_right: Input.Key_Code;
	run: Input.Key_Code;
	dash: Input.Key_Code;
	parry: Input.Key_Code;

	interact: Input.Key_Code;
	inventory: Input.Key_Code;
	drop_item: Input.Key_Code;
	build_mode: Input.Key_Code;

	attack: Input.Key_Code;
	use_item: Input.Key_Code;
}

main :: ()
{
	app_init(); defer app_shutdown();
	steam_init();
	
	while !app.should_quit
	{
		update_delta_t();
		Tracy.FrameMark();
		Tracy.ZoneScoped("main_loop");
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
		if g_steamState.initialized then steam_client_update();
		saving_thread_update();

		// :world target alpha
		if is_state_entry(.world)
		{
			app.world_alpha_t = 1.0;
			if !app.world.initialized then world_init(*app.world);
			if app.should_load_game
			{
				//world_load();
				app.should_load_game = false;
				deserialise_world(g_world);
				g_world.simulating = true;
			}

			app.confine_cursor = true;
		}
		if is_state_exit(.world)
		{
			app.world_alpha_t = 0.0;
		}
		animate_to_target(*app.world_alpha, app.world_alpha_t, delta_t(), rate=15);
		
		// clear out the nil entity
		nil_entity = .{};
		
		// :update
		if g_world.simulating
		{
			// profile_block("world update");
			defer g_world.first_world_frame = false;
			
			app.world.time_elapsed += delta_t_scaled();
			
			world_cycle_update();
			
			in_game_user_interaction();
			
			respawn_ui();
			display_notifications();
			update_storage_slabs();
			update_workbenches();
			update_campfires();
			inventory_ui();
			build_mode_ux();
			item_placement_ux();
			
			// UPDATE
			// Always update the starting biome
			// update_corefire();
			update_items();
			update_ground_torches();
			update_farming_totem();
			update_crops();
			update_animations();
			monster_spawner_update();
			ai_update();
			overlap_damage_update();
			player_update();
			gobby_update();
			ogre_update();
			skele_update();
			petrified_update();
			#if ROB_TESTING
			{
				update_spells();
				ifx app.debug_config.rob_test then mage_update();
				//grid_entity_update();
			}
			update_healing_totem();
			// boss_altar_update();
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
			update_particle_emitters();
			update_particles();
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
		
		// randy: NOTE
		// can we actually have these down here without breaking something?? (the were above the sim update earlier)
		gamemode_update();
		main_menu_ui();
		pause_ui();
		game_over_ui();
		hints_menu();
		settings_menu();
		
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
			render_particles();
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

	if g_steamState.initialized then steam_shutdown();
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
	
	// :sound
	sound_init();
	{
		// play all the loops
		play_sound_loop("event:/loops/day_ambiance");
		play_sound_loop("event:/loops/night_ambiance");
		play_sound_loop("event:/loops/the_darkness");
		
		// setup the snapshots
		app.silence_snapshot = setup_snapshot("snapshot:/silence");
		app.day_snapshot = setup_snapshot("snapshot:/day");
		app.night_snapshot = setup_snapshot("snapshot:/night");
		app.darkness_snapshot = setup_snapshot("snapshot:/darkness");
		
		play_fmod_instance(app.silence_snapshot);
		play_fmod_instance(app.day_snapshot);
	}
	
	ui_init(*app.ui);
	set_app_mode(START_APP_STATE);
	
	app.refresh_rate = get_refresh_rate();
	app.rdtsc_frequency = get_rdtsc_frequency();

	//Default input :keybinds
	if !settings_deserialise(*app.settings)
	{
		//Defaults don't exist, make 'em
		{
			using app.settings;
			//Movement
			keybinds.move_left = #char "A";
			keybinds.move_right = #char "D";
			keybinds.run = .SHIFT;
			keybinds.dash = .SPACEBAR;
			keybinds.parry = .MOUSE_BUTTON_RIGHT;
	
			keybinds.interact = #char "E";
			keybinds.inventory = .TAB;
			keybinds.drop_item = #char "Q";
			keybinds.build_mode = #char "C";
	
			keybinds.attack = .MOUSE_BUTTON_LEFT;
			keybinds.use_item = .MOUSE_BUTTON_RIGHT;
		}
		app.settings.volume = 1.0;

		settings_serialise(*app.settings);
	}
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
		Tracy.ZoneScoped(":debug");
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
		if CHECK_FOR_FUNNY_BUSINESS // this check costs >3ms so it's disabled by default, until you think you need it
		{
			Tracy.ZoneScoped("funny business check");
			blank_en: Entity;
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
		}
		
		// debug collision boxes
		if app.debug_config.draw_collision_boxes
		{
			Tracy.ZoneScoped("debug collision boxes");
			for * en: app.world.entities 
			{
				if is_valid(en) && (en.collision_rect.min != .{} || en.collision_rect.max != .{})
				debug_rect(get_collision_rect(en), 1);
			}
		}
		
		// GOBBY GRINDER
		if key_pressed(#char "G")
		{
			en := create_gobby(false);
			en.pos.x = get_player().pos.x + 200.0;
			
			empower_entity(en);
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
			
			if button("unlock recipes").pressed
			{
				unlock_all_recipes();
			}
			
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
#import "Reflection";
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
#load "../../../recycle/mdf.jai";

#load "config.jai";
#load "steam.jai";

#import,file "../../../recycle/recycle.jai";
#load "sound.jai";
#load "render.jai";
#load "../../../recycle/cereal.jai";
#load "linked.jai";
#load "log.jai";

Tracy :: #import "tracy"(.CLIENT, ENABLED=ENABLE_TRACY);

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

input_attempt_portal :: (en: *Entity) -> bool
{
	if key_pressed(app.settings.keybinds.interact)
	{
		consume_key(app.settings.keybinds.interact);
		if en.state == .on then en.state = .off; else en.state = .on;
	}
	
	return true;
}

update_portal :: (en: *Entity)
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

CAMERA_TARGET_OFS :: 32.0;
CAMERA_TRIGGER_OFS :: 64.0;

CAMERA_EDGE_OFS :: 128.0;
CAMERA_POS_MIN :: CAMERA_EDGE_OFS;
CAMERA_POS_MAX :: WORLD_RADIUS - CAMERA_EDGE_OFS;

update_camera :: (current_cam: Camera2, player: Entity) -> Camera2
{
	camera := current_cam;	
	
	target_entity : *Entity = get_nil_entity();
	if is_player_alive()
	{
		target_entity = get_player();
	}
	else
	{
		// set to closest enemy lol
		for * en : g_world.entities if is_valid(en) && has_prop(en.props, .monster)
		{
			if is_nil(target_entity) || en.pos.x < target_entity.pos.x
			{
				target_entity = en;
			}
		}
		
		// fallback to totem
		if is_nil(target_entity)
		{
			target_entity = get_totem();
		}
	}

	if target_entity.pos.x <= camera.target_position.x - CAMERA_TRIGGER_OFS
	{
		app.camera_focus_target = -1;
	}
	else if target_entity.pos.x >= camera.target_position.x + CAMERA_TRIGGER_OFS
	{
		
		app.camera_focus_target = 1;
	}

	if target_entity.x_dir == app.camera_focus_target
	{
		camera.target_position.x = target_entity.pos.x + app.camera_focus_target * CAMERA_TARGET_OFS;
	}

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
	
	clamped_target_pos := camera.target_position;
	clamped_target_pos.x = clamp(clamped_target_pos.x, CAMERA_POS_MIN, CAMERA_POS_MAX);
	// animate pos to target
	animate_to_target(*camera.position, clamped_target_pos, delta_t_scaled());

	// animate zoom to target
	animate_to_target(*camera.zoom, camera.target_zoom, delta_t_scaled());
	return camera;
}

ui_storage_slot :: (unique_name_hash: string, storage_slot: *EntityHandle, internal_padding: Size)
{
	slot := make_box(.clickable | .draw_hot_effects | .draw_active_effects, unique_name_hash);
	push_parent(slot);
	
	item_en := entity_from_handle(storage_slot);
	item := get_resource(item_en.item_id);

	if has_prop(item_en.props, .equippable) && get_item_equipped_slot(item_en) != null
	{
		slot.border_col = .{0.0, 0.0, 1.0, 1.0};
	}
	
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

		if has_prop(item_en.props, .durability)
		{
			set_next_pref_size(pct_parent(1), text_dim(1));
			set_next_text_justify_x(.right);
			make_box(.draw_text | .skip_layout | .floating, tprint("%###itemhealth_%", item_en.health, unique_name_hash));
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
		label("%###", get_dynamic_display_name(item, item_en));
		
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
		else if has_prop(item_en.props, .placeable)
		{
			set_next_pref_size(size_by_children(1));
			auto_row();
			
			icon(.right_click_icon, "", em(1));
			
			set_next_pref_width(text_dim(1));
			set_next_pref_height(text_dim(1));
			label("Place");
			
			if slot_signal.clicked_r
			{
				app.placing_item = handle_from_entity(item_en);
				set_interface_mode(.item_place);
			}
		}
		else if has_prop(item_en.props, .equippable)
		{
			equipped_slot := get_item_equipped_slot(item_en);
			
			if slot_signal.clicked_r
			{
				if equipped_slot == null
				{
					//Equip
					free_slot := get_free_equipment_slot();
					equip_item(item_en, free_slot);
				}
				else
				{
					//Unequip
					<<equipped_slot = .{};
				}
			}
			
			set_next_pref_size(size_by_children(1));
			auto_row();
			
			icon(.right_click_icon, "", em(1));
			
			set_next_pref_width(text_dim(1));
			set_next_pref_height(text_dim(1));
			label(ifx equipped_slot == null then "Equip" else "Unequip");
		}
		
		if key_pressed(app.settings.keybinds.drop_item)
		{
			consume_key(app.settings.keybinds.drop_item);
			
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
	assert(is_valid(item_res), "No item id found when trying to convert blueprint? Can't infer the recipe from %", en.item_id);
	array_copy(en.remaining_items, item_res.recipe);
}

input_attempt_blueprint :: (en: *Entity) -> bool
{
	can_interact:= false;
	
	// see if there's anything we can take from the inventory
	for get_player_storage_slots()
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
	if can_interact && key_pressed(app.settings.keybinds.interact)
	{
		consume_key(app.settings.keybinds.interact);
		struc := get_item(en.item_id);
		
		// for each item in inv, try and subtract it from the reamining items in the blueprint
		for stored : get_player_storage_slots()
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
			new_event(.{kind=.repair, entity=handle_from_entity(en)});
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
		else
		{
			draw_sprite(scaffolding_res.id, en.pos, animation_index=0, z_layer=en.z_layer-0.01);
		}
	}
}

hud_item_blueprint :: (world : WorldState)
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

hud_consume_item :: (world : WorldState)
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

hud :: (world: WorldState)
{
	if app.app_mode != .world then return;
	player := entity_from_handle(world.player_handle);
	
	push_layer_cbuff(.{lut_strength=0});
	
	// randy: NOTE
	// I tried making this less annoying with a LOW_HEALTH_THRESHOLD, but I think we just need to yeet
	// the vignette displaying at all times and have more subtle ways of signalling low-health.
	// Like the sound getting low-passed and whatnot.
	// Would still be good to flash red on hit though?
	//
	// red vignette
	{
		alpha := player.timer2 / 1.0;
		alpha *= 0.8;
		draw_rect(make_range(xy(xx app.window_w, xx app.window_h)), texture=get_texture(.red_vignette), col=xyzw(1, 1, 1, alpha), z_layer=Z_UI-0.5, flags=.skip_camera_transform);
	}

	set_next_pref_width(px(xx app.window_w));
	set_next_pref_height(px(xx app.window_h));
	set_next_child_layout_axis(.Y);
	box := make_box(BoxFlags.floating, "");
	push_parent(box);

	{
		spacer(em(UI_MARGIN / 2));

		// Status icons & health
		{
			set_next_child_layout_axis(.X);
			status_effects_n_health := make_box(0, "");
			push_parent(status_effects_n_health);
			spacer(pct_parent(1, 0));
			{
				set_next_child_layout_axis(.X);
				status_effects := make_box(0, "");		
				{
					push_parent(status_effects);
					spacer(pct_parent(1, 0));
					icon_size := em(1, 1);
					for * status_effect : player.effects
					{
						if status_effect.kind == .nil then continue;
						{
							set_next_child_layout_axis(.Y);
							set_next_pref_size(size_by_children(1));
							s_effect_box := make_box(0, "");
							push_parent(s_effect_box);
							padding(em(0.27));

							if status_effect.kind == 
							{

								case .poison;
								set_next_pref_size(icon_size);
								ui_status_effect("sf_poison", .icon_poison, status_effect.length_timer);
								case .on_fire;
								set_next_pref_size(icon_size);
								ui_status_effect("sf_burning", .icon_fire, status_effect.length_timer);
								case .heal;
								set_next_pref_size(icon_size);
								ui_status_effect("sf_healing", .icon_heal, status_effect.length_timer);
								case .shrouded;
								set_next_pref_size(icon_size);
								ui_status_effect("sf_shrouded", .icon_shrouded, status_effect.length_timer);
								case .rested;
								set_next_pref_size(icon_size);
								ui_status_effect("sf_rested", .icon_rested);
							}
						}
						padding(px(3));
					}
				}
			}

			//Health
			{
				set_next_child_layout_axis(.X);
				set_next_pref_width(size_by_children(1));
				health := make_box(0, "");
				{
					push_parent(health);
					spacer(pct_parent(1, 0));
					
					// randy: TODO - we need to have a sizebyspriteratio thingo so we only need to set
					// one of these and have the other one auto-size by the sprite
					// this is good enough for now tho.
					push_pref_height(em(1.5));
					push_pref_width(em(10));
					
					set_next_child_layout_axis(.X);
					healthbar_bg_box := make_box(.draw_sprite, "");
					healthbar_bg_box.sprite_id = .healthbar_bg;
					{
						push_parent(healthbar_bg_box);
						health_pct := entity_health_pct(player);
						set_next_quad_flags(.slice_x | top_quad_flags());
						fill_box := make_box(.draw_sprite, "");
						fill_box.sprite_id = .healthbar_fill;
						fill_box.slice_x_pct = health_pct;

						if signal_from_box(fill_box).hovering || 
							app.interface_mode == .inventory
						{
							push_parent(fill_box);
							label("% / %", player.health, player.max_health);
						}
					}
					padding(em(UI_MARGIN / 2));
				}
			}
		}
		
		//Hunger
		{
			set_next_child_layout_axis(.X);
			set_next_pref_size(pct_parent(1), size_by_children(1));
			hunger_bones_container := make_box(0, "");
			push_parent(hunger_bones_container);
			spacer(pct_parent(1, 0));
			{
				for < hunger_index : PLAYER_MAX_HUNGER/2..1
				{
					icon_size := em(1, 1);
					set_next_pref_size(icon_size);
					bone_pic := make_box(.draw_sprite, "");
					
					hunger := cast(float)player.hunger / 2.0;
					remainder := hunger - floor(hunger);
					has_remainder := abs(remainder) > 0.1;
					// log("%, %", hunger, has_remainder);
					
					if cast(float)hunger_index > hunger
					{
						bone_pic.sprite_id = .hunger_none;
					}
					else
					{
						bone_pic.sprite_id = .hunger_full;
					}
					
					// half
					if hunger_index == cast(int)ceil(hunger) && has_remainder
					{
						bone_pic.sprite_id = .hunger_half;
					}
				}
			}

			spacer(em(UI_MARGIN));
		}
		
		//Dash
		{
			// push_flags(.debug_draw);
			
			spacer(em(0.1)); // randy: this is just here to compensate for me being lazy and not properly adding
			// margins in between each of these rows, and sizing the health bar properly.
			
			set_next_child_layout_axis(.X);
			dash_box := make_box(0, "dash_box_1");
			
			// animate to target and back when a dash gets recharged
			if player.frame.dash_recharged then dash_box.target = 1.0;
			if animate_to_target(*dash_box.value, dash_box.target, delta_t(), rate=30.0, good_enough=0.01) && dash_box.target == 1.0 then dash_box.target = 0;
			
			{
				push_parent(dash_box);
				spacer(pct_parent(1, 0));
				

				// Get max possible dashes
				additional_dashes := 0;
				for get_player().equipped_items if is_valid(it)
				{
					en := entity_from_handle(it);
					item := get_item(en.item_id);
					additional_dashes += item.additional_dashes;
				}
				max_dashes := DASH_BASE_COUNT + additional_dashes;
				full_cutoff := max_dashes - player.dash_count;

				for 1..max_dashes
				{
					push_pref_width(em(2.5));
					push_pref_height(em(1));
					
					dash_bg_box := make_box(.draw_sprite, "");
					dash_bg_box.sprite_id = .dash_bg;
					{
						push_parent(dash_bg_box);
						
						dash_pct: float;

						if it == full_cutoff + 1
						{
							dash_pct = float_map(1 - player.dash_cooldown_timer / DASH_COOLDOWN, 0, 1, 0.1, 0.9);
						}
						else if it > full_cutoff 
						{
							dash_pct = 0.0;
						}
						else
						{
							dash_pct = 1.0;
						}

						set_next_quad_flags(.slice_x | top_quad_flags());
						fill_box := make_box(.draw_sprite, "");
						fill_box.sprite_id = .dash_fill;
						fill_box.slice_x_pct = dash_pct;
						
						// Flash only the latest-filled box
						if it == full_cutoff
						{
							dash_bg_box.white_override = dash_box.value;
							fill_box.white_override = dash_box.value;
						} 
					}
				}
				padding(em(UI_MARGIN / 2));
			}

		}
	}

	{
		if app.saving_thread != null && !thread_is_done(app.saving_thread)
		{
			push_parent(box);
			spacer(pct_parent(1, 0));

			set_next_child_layout_axis(.X);
			saving_icon_box := make_box(0, "");

			{
				push_parent(saving_icon_box);
				padding(px(8));

				set_next_pref_width(px(48));
				set_next_pref_height(px(48));

				saving_icon := make_box(.draw_sprite, "");
				saving_icon.sprite_id = .floppy;
			}

			
			padding(px(4));
		}
	}
}

ui_status_effect :: (unique_name_hash: string, sprite: SpriteID, duration: float = -1.0)
{
	icon := make_box(.draw_sprite | .draw_border | .clickable | .draw_hot_effects | .draw_active_effects, unique_name_hash);
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
		case(.icon_heal);
		label("Healing###");
		case(.icon_shrouded);
		label("Shrouded###");
		case(.icon_rested);
		label("Rested###");
	}

	if duration > -1 then
	label("%", formatFloat(duration, width=1, trailing_width=0, zero_removal=.NO));
}

hud_tooltips :: (world: WorldState)
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

hud_entity_health_bars :: (world: WorldState)
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
	return clamp(cast(float) en.health / cast(float) en.max_health, 0, 1);
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
		Tracy.ZoneScoped("RENDER_BACKGROUND");
		
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
		Tracy.ZoneScoped(":render generic entities");
		for * en : world.entities
			if is_visible(en)
		{
			// lol
			if is_campfire(en)
			{
				render_campfire(en);
			}
			else if is_workbench(en)
			{
				render_workbench(en);
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
			// else if is_boss_altar(en)
			// {
			// 	render_boss_altar(en);
			// }
			else if is_tree(en)
			{
				render_tree(en);
			}
			else if has_prop(en.props, .render_sprite)
			{
				if has_prop(en.props, .empowered)
				{
					quad := draw_generic_entity(en, make_transform(xy(0,-2), 0, 1.1));
					quad.layer_cbuffer.colour_override_amount = 0.6;
					quad.layer_cbuffer.colour_override = WHITE;
				}
				
				draw_generic_entity(en);
			}			
		}
	}
	
	// custom_render_player();
	
	#if DEBUG 
	{
		// scuffed line render
		{
			Tracy.ZoneScoped("scuffed line render");
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

					draw_rect(rect, col = line.col, trs=line.transform, z_layer = 0.1);
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
	}
	
	ui_end_and_render();

	//draw_sliced_sprite(.char_idle);
	
	//
	actually_render();
	
	// reset render state
	reset(*render_st.quads);
	render_st.cbuffer = .{};
	render_st.layer_cbuffer = .{};
}


apply_quad_adjustments_from_entity :: (quad: *Quad, en: Entity)
{
	quad.white_override = en.white_override;
	quad.white_override += en.interactable_alpha * 0.2;
	
	if has_prop(en.props, .petrified)
	{
		STONE_GRAY :: Vector4.{0.5, 0.5, 0.6, 1.0};
		quad.layer_cbuffer.colour_override = STONE_GRAY;
		quad.layer_cbuffer.colour_override_amount = 0.9;
	}
	
	quad.col *= en.frame.colour_multiplier;
	
	// damage animation
	if en.damage_alpha != 0
	{
		quad.white_override = 1.0;
	}
}

draw_generic_entity :: (en: Entity, trs_adjust:Transform2=.{}) -> *Quad
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
	
	col := en.col;
	
	trs:= merge_transform(local_trs, render_trs);
	trs= merge_transform(trs, trs_adjust);
	
	flags := ifx flip_x then QuadFlags.x_flipped else 0;
	
	quad := draw_rect(sprite_id=sprite.id, sprite_pivot=.bottom_center, z_layer=en.z_layer, col=col, uv_rect=uv_rect, flags=flags, trs=trs);
	
	apply_quad_adjustments_from_entity(quad, en);
	return quad;
}

is_player_alive :: () -> bool
{
	return get_player().health > 0;
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

get_inventory_slot_count :: () -> int
{
	additional_slots := 0;
	for get_player().equipped_items if is_valid(it)
	{
		en := entity_from_handle(it);
		if en.item_id == .gobby_pouch
		{
			additional_slots += 10;
		}
	}
	return BASE_INVENTORY_COUNT + additional_slots;
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
	item_place;
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
		repair;
		damage;
		death;
		pickup;
		activate;
		upgrade;
		start_campfire_craft;
	};
	entity: EntityHandle;
	res_id: ResourceID;
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
	heal;
	shrouded;
	rested;
	
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

entity_has_effect :: (en: *Entity, effect_kind: EffectKind) -> bool
{
	return en.effects[effect_kind].kind != 0;
}

remove_effect_from_entity :: (en: *Entity, effect_kind: EffectKind)
{
	for * dot: en.effects if dot.kind == effect_kind
	{
		//NOTE(fhomolka): give shrouded some time to do a fade-out
		if dot.kind == .shrouded
		{
			dot.length_timer = -1;
			continue;
		}
		<<dot = .{};
	}
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
				
				case .heal;
				{
					if tick_timer(*dot.interval_timer, delta_t_scaled(), zero_counts_as_complete=true)
					{
						heal_entity(en, 1);
						dot.interval_timer = HEAL_FREQUENCY;
					}
					if tick_timer(*dot.length_timer, delta_t_scaled()) then <<dot = .{}; // finish effect
					
					create_emitter(en.pos, .p_heal);
				}

				case .shrouded;
				{
					//NOTE(fhomolka): I'm (ab)using the length timer here, since it's never actually ticked
					if(dot.length_timer) > 0
					{
						animate_to_target(*dot.interval_timer, 1.0, delta_t());
					}
					else
					{
						animate_to_target(*dot.interval_timer, 0.0, delta_t());
					}
					
					alpha := dot.interval_timer;
					draw_rect(make_range(xy(xx app.window_w, xx app.window_h)), texture=get_texture(.red_vignette), col=xyzw(0, 0, 0, alpha), z_layer=Z_UI-0.5, flags=.skip_camera_transform);
					if alpha <= 0 then <<dot = .{};
				}

				case .rested;
				{
					if tick_timer(*dot.interval_timer, delta_t_scaled(), zero_counts_as_complete=true)
					{
						heal_entity(en, dot.stack_count);
						dot.interval_timer = HEAL_FREQUENCY;
					}
					if tick_timer(*dot.length_timer, delta_t_scaled()) then <<dot = .{}; // finish effect
					
					//create_emitter(en.pos, .p_heal);
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
		en := create_entity("ground");
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
		
		en := create_entity("hills1");
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
		
		en := create_entity("tree1");
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
		
		en := create_entity("tree2");
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
		
		en := create_entity("tree3");
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
		en := create_entity("bg_mountain");
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
	
	// berry bushes
	tile_strucs = get_world_tile_array();
	BERRY_STEP := TILE_WIDTH * 8.0;
	point = RESOURCE_GEN_START + BERRY_STEP;
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
			en := create_entity("berry_bush");
			setup_berry_bush(en);
			en.pos.x = point;
			
			point += random_get_within_range(BERRY_STEP, BERRY_STEP*3);
		}
	}
	
	// randy: what if we don't spawn these naturally, and force the player to mine for them straight away?
	/*
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
	*/
	
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
	en.hunger = PLAYER_MAX_HUNGER;
	return en;
}

unlock_all_recipes :: ()
{
	for * app.resources if (it.flags & .item) && has_prop(it.props, .unlockable)
	{
		g_world.unlocked_recipes[it.id] = true;
	}
}

world_bootstrap :: ()
{
	en: *Entity;
	
	#if DEBUG_UNLOCK_RECIPES
	{
		unlock_all_recipes();
	}
	
	en = create_player();
	g_world.player_handle = handle_from_entity(en);
	player := en;
	teleport_player_and_camera(xy(100, 0));
	
	totem := create_entity("totem");
	setup_base_totem(totem);
	convert_to_blueprint(totem);
	totem.pos = xy(0, 1);
	g_world.base_totem_handle = handle_from_entity(totem);

	// en = create_entity();
	// setup_boss_altar(en);
	// convert_to_blueprint(en);
	// en.pos.x = WORLD_RADIUS - 256;
	
	en = create_world_item(.stone);
	en.pos.x = 22;
	en = create_world_item(.stone);
	en.pos.x = 0;
	en = create_world_item(.stone);
	en.pos.x = 160;
	en = create_world_item(.stone);
	en.pos.x = 190;

	/*
	#if !RELEASE
	{
		en = create_world_item(.monster_essence);
		en.item_count=16;
		attempt_store_item(get_player_storage_slots(), en);
		
		en = create_world_item(.stone);
		en.item_count = 16;
		attempt_store_item(get_player_storage_slots(), en);
		
		en = create_world_item(.wood);
		en.item_count = 16;
		attempt_store_item(get_player_storage_slots(), en);
		
		en = create_world_item(.wood);
		en.item_count = 16;
		attempt_store_item(get_player_storage_slots(), en);
	}
	*/

	// :map
	#if TESTING
	{
		// en = create_gobby(false);
		// en.pos.x = 200;
		
		en = create_world_item(.flint_sword);
		attempt_store_item(get_player_storage_slots(), en);
		player.hot_slot = 1;
		
		en = create_world_item(.monster_essence);
		en.item_count=16;
		attempt_store_item(get_player_storage_slots(), en);
		
		// en = create_world_item(.flint_pickaxe_recipe);
		// attempt_store_item(get_player_storage_slots(), en);
		
		// axe
		// en = create_world_item(.flint_axe);
		// en.pos.x = 45;
		// attempt_store_item(get_player_storage_slots(), en);
		// player.hotbar_slots[2] = handle_from_entity(en);
		// player.hot_slot = 2;

		en = create_world_item(.stone);
		en.item_count = 16;
		attempt_store_item(get_player_storage_slots(), en);

		en = create_world_item(.monster_essence);
		en.item_count = 16;
		attempt_store_item(get_player_storage_slots(), en);
		
		en = create_world_item(.raw_goblin_meat);
		en.item_count = 16;
		attempt_store_item(get_player_storage_slots(), en);
		
		// en = create_world_item(.rare_item);
		// en.item_count = 16;
		// attempt_store_item(get_player_storage_slots(), en);
		
		// en = create_world_item(.fibre);
		// en.item_count = 16;
		// attempt_store_item(get_player_storage_slots(), en);

		en = create_world_item(.goblin_pendant);
		en.item_count = 1;
		attempt_store_item(get_player_storage_slots(), en);

		en = create_world_item(.forbidden_fruit);
		en.item_count = 1;
		attempt_store_item(get_player_storage_slots(), en);
	}
}

// :cycle
KeyFrame :: struct
{
	value: ResourceID;
	time: float;
}

// @animtool
// TODO - make this a generic structure next time I do an animation
// Hi future Randy!

// ideally this would be editable visually somehow... @animation editor?

luts : []KeyFrame = .[
	.{.day_lut, 							0.0	},
	.{.day_lut, 					0.5 },
	.{.mid_night_lut, 					0.55 },
	.{.mid_night_lut, 					0.95 },
	.{.day_lut, 							1.0	},
];


// select the frames to either side of time and return an linear alpha for blending between the two
get_keyframes_at_time :: (keyframe_array: []$T, time: float) -> T, T, float
{
	prev : *T;
	next : *T;
	alpha : float;
	
	if time <= keyframe_array[0].time
	{
		prev = *keyframe_array[keyframe_array.count-1];
		next = *keyframe_array[0];
		alpha = float_alpha(time, 0, keyframe_array[0].time);
	}
	else
	{
		for * keyframe_array
		{
			if it.time >= time // find the first greater frame
			{
				prev = *keyframe_array[it_index-1];
				next = it;
				break;
			}
		}
		
		alpha = (time - prev.time) / (next.time - prev.time);
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
	return ifx cycle < 0.75 then float_alpha(cycle, 0.42, 0.5) else 1-float_alpha(cycle, 0.95, 1.0);
}

is_night_time :: () -> bool
{
	cycle := get_time_cycle_alpha();
	return cycle > 0.5 && cycle < 0.97;
}

is_siege_time :: () -> bool
{
	cycle := get_time_cycle_alpha();
	return cycle > 0.425 && cycle < 0.9;
}

world_cycle_update :: ()
{
	#if DISABLE_NIGHT then return;
	
	player := get_player();
	
	// tick up the day cycle
	g_world.day_cycle += app.delta_t;
	if g_world.day_cycle > CYCLE_LENGTH
	{
		g_world.day_cycle = 0.0;
	}
	
	cycle_alpha := get_time_cycle_alpha();

	// select the luts
	{
		
		/*
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
		*/
		
		night_alpha := get_night_darkness_alpha();
		
		// luts
		render_st.lut1 = .morning_lut;
		render_st.lut2 = .early_night_lut;
		render_st.cbuffer.lut_blend_alpha = night_alpha;
	}
	
	if is_siege_time()
	{
		// randy: I reworked the spawning so we've got more control on the design of each wave.
		// see the day_0 array.
		// The idea here is we can hand-craft each and every wave to balance it properly. Each number
		// can mean whatever we want it to mean.
		// Right now I've just got the 1 to == a gobby for simplicity
		
		// Siege of Gondor
		#if !DISABLE_MONSTERS
		{
			base_range := get_base_range();
			wave := get_wave(g_world.days_survived);
			
			spawn_interval :float= NIGHT_LENGTH / cast(float)wave.count;
			if tick_timer(*g_world.spawn_timer, delta_t_scaled(), zero_counts_as_complete=true)
			{
				g_world.spawn_timer = spawn_interval;
				defer g_world.spawn_timer_counter += 1;
				
				enemy_id := wave[clamp_top(g_world.spawn_timer_counter, wave.count-1)];
				spawn_something := enemy_id != 0;
				if spawn_something
				{
					en := create_entity();
					en.pos.x = random_get_within_range(base_range.max, WORLD_RADIUS);
					if enemy_id ==
					{
						case 2; #through;
						case 1;
						// gobby time
						//setup_gobby(en, false);
						monster_spawner_setup(en, .gobby);
						
						// randy: NOTE
						// just gonna hand-spawn the empowered ones for now since it's easier to balance
						// We also don't want to restrict ourselves to one empowered enemy each night.
						//
						// randy: Disabled since it's not shippable yet
						//
						// case 2;
						// setup_gobby(en, false);
						// empower_entity(en);
						
						case;
						log_error("enemy id % not handled yet!", enemy_id);
						
						// randy: NOTE
						// keeping these out of the design for now since they're not yet shippable
						/*
						case 2;
						// Shrek
						setup_ogre(en);
						case 3;
						// Skeletor
						setup_skele(en);
						*/
					}
					
					log("spawned %", en.archetype);
				}
			}
		}
	}


	// night/day update
	if is_night_time()
	{
		// enter night
		if !g_world.night_started
		{
			g_world.night_started = true;
			g_world.day_started = false;
			
			play_fmod_instance(app.night_snapshot);
		}
	
	}
	else
	{
		// enter day
		if !g_world.day_started
		{
			g_world.day_started = true;
			g_world.night_started = false;
			g_world.spawn_timer_counter = 0;
			
			g_world.days_survived += 1;
			
			stop_fmod_instance(app.night_snapshot);
			
			for * en: g_world.entities if is_valid(en) && has_prop(en.props, .monster)
			{
				monster_petrify(en);
			}
			
			create_notification(tprint("Nights Survived: %", g_world.days_survived), is_big=true);

			// remove_effect_from_entity(get_player(), .shrouded);
		}
	}
	
	// shrouded effect on player
	// randy: NOTE, disabling this for now since it's too much design work to make it work, for too little payoff.
	// My original idea behind it was to force the player back to the base, but it was me making a premature
	// decision without observing the problem in playtesting first.
	// 1st of November 2023
	/*
	if is_night_time()
	{
		base_range := get_base_range();
		should_shroud := true;

		// Maybe do this in update_point_lights?
		for * en: g_world.entities if is_visible(en) && has_prop(en.props, .point_light)
		{
			light_range := Range1.{en.pos.x - en.light_radius, en.pos.x + en.light_radius};
			if player.pos.x > light_range.min && player.pos.x < light_range.max
			{
				should_shroud = false;
				break;
			}
		}
		
		// randy: bruh I fking hate this retained mode effect shit... we really oughta
		// rework the effects so it's a lot more functional/immediate, which'll remove a lot of this
		// unecessary setup/destroy OO bullshit
		
		if should_shroud && !entity_has_effect(player, .shrouded)
		{
			apply_effect_to_entity(player, .shrouded, 20, 1);
			play_fmod_instance(app.darkness_snapshot);
		}
		
		if !should_shroud && entity_has_effect(player, .shrouded)
		{
			remove_effect_from_entity(player, .shrouded);
			stop_fmod_instance(app.darkness_snapshot);
		}
	}
	*/
}

// 1: gobby
// 2: emp gobby
get_wave :: (day: int) -> []int
{
	#if MEAT_GRINDER_WAVE
	{
	return int.
	[
		1,1,1,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,1,1,0,0,1,1,1,1,1,0,0,0,0,0,1,1,1,0,0,1,1,0,0,0,0,0,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,
		0,0,0,1,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
	];
	}
	
	// hand-crafted waves for each night
	if day ==
	{
		case 0;
		return int.
		[
		1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		];
		
		case 1;
		return int.
		[
		1,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,2,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
		];
		
		case 2;
		return int.
		[
		1,0,1,1,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,
		0,0,0,1,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,1,0,0,2,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1,0,0,
		];
		
		case; #through; // fall back to the hardest night we've authored when we run out
		case 3;
		return int.
		[
		1,0,1,1,0,0,0,0,0,1,0,0,0,0,1,0,1,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,1,0,0,0,0,0,0,1,0,0,1,0,1,0,0,0,0,0,0,0,0,
		0,0,0,1,0,1,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,0,2,0,1,0,0,0,1,0,0,0,1,0,0,0,0,0,1,1,0,1,0,1,0,0,
		];
	}
}

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

monster_spawner_create :: inline (monster_prop: EntityProps = .gobby) -> *Entity
{
	en := create_entity("monster_spawner");
	monster_spawner_setup(en, monster_prop);
	return en;
}

SPAWN_TIMER :: 2.0;

monster_spawner_setup :: (en: *Entity, monster_prop: EntityProps)
{
	add_props(*en.props, .monster_spawner);

	//re-use upgrade_count to determine which enemy it'll spawn
	en.upgrade_count = xx EntityProps.gobby;

	en.timer1 = SPAWN_TIMER;
}

monster_spawner_update :: ()
{
	for * en : g_world.entities if is_valid(en) && has_prop(en.props, .monster_spawner)
	{
		if !tick_timer(*en.timer1, delta_t_scaled(), zero_counts_as_complete=true)
		{
			create_emitter(en.pos + xy(0, 10), .p_enemy_spawn);
			continue;
		}

		monster := create_entity("spawned_monster");
		if en.upgrade_count ==
		{
			case xx EntityProps.gobby;
			setup_gobby(monster);
			case;
		}

		monster.pos = en.pos;

		en.marked_for_destroy = true;
	}
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
	if (app.key_down[app.settings.keybinds.move_left])
	{
		result.x -= 1;
	}
	if (app.key_down[app.settings.keybinds.move_right])
	{
		result.x += 1;
	}
	// Are these even used?
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

debug_pos :: (pos: Vector2, tick_count := 0)
{
	line_create(pos - xy(0, 5), pos + xy(0, 5), RED, tick_count);
	line_create(pos - xy(5, 0), pos + xy(5, 0), RED, tick_count);
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
	// find_attack_target :: 84;
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
	healing_totem :: 98;
	campfire_recipe :: 99;
	unlockable :: 100;
	workbench_recipe :: 101;
	durability :: 102;
	build_recipe :: 103;
	club :: 104;
	farming_totem :: 105;
	dmg_touch :: 106; //fhomolka: so, this is a damage-specific prop. I want to ignore these for blocks
	monster_spawner :: 107;
	empowered :: 108;
	berry_bush :: 109;
	damage_when_overlap :: 110;
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
	original_item_from_placement: ItemID;
	
	// research page item
	recipe_to_unlock: ItemID;
	
	// recieve_damage
	health: int = BASE_MAX_HEALTH;
	max_health: int = BASE_MAX_HEALTH;
	damage_alpha: float;
	recieve_damage_from: Properties(EntityProps);
	dmg_props_must_be_exact: bool;
	damage_event: DamageEvent;
	damage_immunity_cooldown: float;
	hunger: int;
	hunger_timer: float = HUNGER_TIMER_DURATION;
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
	
	// workbench stuff
	crafting_slot_index: int;
	
	// ui stuff
	active_alpha: float;
	active_alpha_target: float;
	
	// particle
	emitter: EmitterKind;
	from_entity: EntityHandle;

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
	crafting_item_id: ItemID;
	crafting_timer: float;
	
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
	blocking_timer: float;
	block_cooldown_timer: float;
	can_block: bool;
	dashing: bool;
	dash_timer: float;
	dash_cooldown_timer: float;
	dash_initial_pos: Vector2;
	dash_dir: int;
	dash_count: int; //Not currently available, how many times did the player dash
	
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
		dash_recharged: bool;
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
		if !has_prop(damage_props, .dmg_touch) && en.is_blocking && en.x_dir != xx sign(en.pos.x - from.pos.x)
		{
			//NOTE(fhomolka): It's here now, because of damage indicators

			// play_sound_old(.block);
			create_emitter(get_held_item_render_pos() + xy(en.x_dir * 5.0, 5.0), .parry);
			return false;
		}

		if en.damage_event.amount == 0
		{
			if en == get_player() && en.damage_immunity_cooldown != 0.0
			{
				// we cool bro
				return false;
			}
			else
			{
				en.damage_immunity_cooldown = 1.0;
			}
			
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

get_collision_rect :: (en: Entity, $skip_pos_shift:=false) -> Range2
{
	rect := en.collision_rect;
	if rect.min == .{} && rect.max == .{}
	{
		rect = rect_from_sprite(en.sprite_id);
	}
	#if !skip_pos_shift then rect = range_shift(rect, en.pos);
	return rect;
}

validate_entity :: (en: Entity, usage_debug_name: string = "")
{
	// FAILURE IS NOT AN OPTION, SOLDIER!
	assert(!is_nil(en), "NIL entity at %", usage_debug_name);
	assert(has_prop(en.props, .valid), "invalid entity at %\n%", usage_debug_name, en);
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

entity_set_sprite :: (en: *Entity, sprite: *ArcResource, random_frame := false, reset_animation := true) -> did_change:bool
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
		
		return true;
	}
	else
	{
		return false;
	}
}
entity_set_sprite :: (en: *Entity, sprite_id: SpriteID, random_frame := false, reset_animation := true) -> bool
{
	sprite := get_resource(sprite_id);
	return entity_set_sprite(en, sprite, random_frame, reset_animation);
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

setup_stone_defense_wall :: (en: *Entity)
{
	en.item_id = .stone_defense_wall;
	en.z_layer = Z_SIDE_WALL;
	en.health = 100;
	en.max_health = en.health;
	entity_set_sprite(en, .stone_defense_wall);
	add_props(*en.props, .rigid_body, .static, .render_sprite, .attack_target, .defense_wall, .draw_health_bar, .deconstructable, .interactable, .structure);
	add_props(*en.recieve_damage_from, .monster);
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
	entity_set_sprite(en, .chest);
	add_props(*en.props, .render_sprite, .interactable, .storage, .storage_slab, .structure);
	en.storage_slot_count = 8;
}

is_storage_slab :: (en: Entity) -> bool
{
	return has_prop(en.props, .storage_slab);
}

input_attempt_storage_slab :: (en: *Entity) -> bool
{
	if key_pressed(app.settings.keybinds.interact)
	{
		consume_key(app.settings.keybinds.interact);
		
		if app.active_storage.entity_id == en.id
		{
			app.active_storage = .{};
		}
		else
		{
			app.active_storage = handle_from_entity(en);
		}
	}
	return true;
}

update_storage_slabs :: ()
{
	for * en: g_world.entities if is_valid(en) && is_storage_slab(en)
	{
		en.active_alpha_target = ifx en.id == app.active_storage.entity_id then 1.0 else 0.0;
		
		// auto yeet when we get far enough away
		if app.active_storage.entity_id == en.id &&  abs(en.pos.x - get_player().pos.x) > 50
		{
			en.active_alpha_target = 0.0;
			app.active_storage = .{};
		}
		// yeet on esc
		if app.active_storage.entity_id == en.id && key_pressed(.ESCAPE)
		{
			consume_key(.ESCAPE);
			en.active_alpha_target = 0.0;
			app.active_storage = .{};
		}
		
		// early out
		if en.active_alpha_target == 0.0 && en.active_alpha == 0.0 then continue;
		
		animate_to_target(*en.active_alpha, en.active_alpha_target, delta_t());
		
		is_enabled := en.active_alpha_target == 1.0;
		alpha := en.active_alpha;
		
		if alpha != 0.0
		{
			push_disable_signal(!is_enabled);
			push_opacity(alpha);
			
			pos := world_pos_to_screen(en.pos + xy(0, 30));
			
			// parent box
			set_next_floating_x(pos.x);
			set_next_floating_y(pos.y);
			set_next_pref_size(size_by_children(1));
			set_next_child_layout_axis(.X);
			set_next_bg_col(xyzw(0, 0, 0, 0.5));
			set_next_rect_pivot_x(.center);
			set_next_rect_pivot_y(.bottom);
			flags :BoxFlags= .floating | .clickable;
			flags |= .draw_bg | .draw_border;
			parent_box := make_box(flags, tprint("%_storage_ui", en.id));
			push_parent(parent_box);
			
			// edge padding
			padding(em(UI_EDGE_PADDING));
			set_next_pref_size(size_by_children(1));
			auto_column();
			padding(em(UI_EDGE_PADDING));
			
			{
				ROW_LENGTH :: 4;
				
				slot_it := 0;
				for row : 0..en.storage_slot_count / ROW_LENGTH
				{
					if row != 0 then spacer(em(UI_SLOT_SPACING));
					
					set_next_pref_height(size_by_children(1));
					set_next_pref_width(size_by_children(1));
					auto_row();
					
					for column : 1..ROW_LENGTH
					{
						defer slot_it += 1;
						if slot_it >= en.storage_slot_count then break;
						
						if column != 1 then spacer(em(UI_SLOT_SPACING));
						
						set_next_flags(.draw_bg | .draw_border);
						set_next_pref_size(em(UI_SLOT_SIZE));
						ui_storage_slot(tprint("st_%_slot_%_%", en.id, row, column), *en.storage_slots[slot_it], em(UI_SLOT_ICON_PADDING));
					}
				}
			}
		}
	}
}

render_storage_slab :: (en: *Entity)
{
	draw_generic_entity(en);
	
	// randy: just going back to the good ol' chest instead of storage slab
	/*
	slot := en.storage_slots[0];
	slot_en := entity_from_handle(slot);
	if is_valid(slot_en)
	{
		draw_sprite(slot_en.sprite_id, xy(en.pos.x, 6 + sin_breathe(3) * 1), z_layer=en.z_layer - 0.1);
	}
	*/
}

/*
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
*/

/*
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
*/

setup_gobby :: (en: *Entity, is_heavy: bool = false)
{
	if is_heavy
	{
		en.archetype = .gobby_heavy;
		en.max_health = 50;
	}
	else
	{
		en.archetype = .gobby;
		en.max_health = 31;
	}
	//en.debug_name = "gobby";
	en.health = en.max_health;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .gobby, .monster, .loot_drops, .draw_health_bar, .damage_when_overlap);
	add_props(*en.recieve_damage_from, .player);
	
	en.collision_rect = make_range(xy(32, 32), pivot=.bottom_center);
	
	set_state(en, .idle_wait);
	en.idle_wait_timer = random_get_within_range(0, 0.5);
	
	if random_pct(0.25) then array_add(en.loot_drops, .{id=.goblin_hide, amount=1});
	if random_pct(0.3) then array_add(en.loot_drops, .{id=.raw_goblin_meat, amount=1});
	array_add(en.loot_drops, .{id=.monster_essence, amount=1});
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
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .ogre, .monster, .loot_drops, .draw_health_bar);
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
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .mage, .monster, .loot_drops, .draw_health_bar);
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
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .skele, .monster, .loot_drops, .draw_health_bar);
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
			entity_death(en);
		}
		
		// enter agro
		target_entity := get_entity_target(en);
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
		txt1 := from_c_string(en.notif_title.data);
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
	
	// randy: uhhh why the fuck wasn't this just a function to begin with lol???
	/*
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
	*/
}

get_entity_target :: (self: *Entity) -> target:*Entity
{
	real_target := ifx is_player_alive() then get_player() else get_totem();
	
	range_to_real_target := make_range(real_target.pos.x, self.pos.x);

	closest_obstacle: *Entity;
	closest_dist := FLOAT32_INFINITY;
	for * obst: app.world.entities if is_valid(obst) && has_prop(obst.props, .attack_target)
	{
		dist := abs(obst.pos.x - self.pos.x);
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
	return target_entity;
}

monster_petrify :: (en: *Entity)
{
	create_emitter(en.pos + .{0, 5}, .petrify, en);
	//remove_props(*en.props, .enabled);
	add_props(*en.props, .petrified);
	remove_props(*en.props, .draw_health_bar);
	en.velocity.x = 0.0;
	en.acceleration.x = 0.0;
	en.x_speed_target = 0.0;
}

petrified_update :: ()
{
	for * en: app.world.entities if is_enabled(en) && has_prop(en.props, .petrified)
	{
		// process damage event
		if en.damage_event.amount != 0
		{
			defer memory_zero(*en.damage_event);
			dmg := en.damage_event;

			//en.marked_for_destroy = true;
			set_state(en, .dead);
			CRUMBLE_TIME :: 0.1;
			en.timer1 = CRUMBLE_TIME;
			em := create_emitter(en.pos + .{0, 5}, .rock_spray, en);

			em.x_dir = get_player().x_dir;

			create_emitter(en.pos + .{0, 5}, .crumble, en);
		}

		if en.state == .dead
		{
			if tick_timer(*en.timer1, delta_t_scaled(), zero_counts_as_complete=true)
			{
				en.marked_for_destroy = true;
				create_emitter(en.pos, .death_poof);
			}
			
		}
	}
}

gobby_update :: ()
{
	player := get_player();
	
	// MAKE CONTENT.
	
	// :GOBBY
	for * en: app.world.entities if is_enabled(en) && has_prop(en.props, .gobby) && !has_prop(en.props, .petrified)
	{
		is_heavy := en.archetype == .gobby_heavy;
		target_entity := get_entity_target(en);

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
			
			// face target
			if is_valid(target_entity)
			{
				en.x_dir = sign(target_entity.pos.x - en.pos.x);
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
			entity_death(en);
		}
		
		// enter agro
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
				attack_hitbox:Range2;
				attack_hitbox.max = xy(30, 30);
				if en.x_dir == -1 then attack_hitbox = range_flip_x(attack_hitbox);
				attack_hitbox = range_shift(attack_hitbox, get_absolute_position(en));
				// debug_rect(attack_hitbox, 500);
				
				against_rect := range_shift(target_entity.collision_rect, get_absolute_position(target_entity));
				// debug_rect(against_rect, 50);
				if range_collide(against_rect, attack_hitbox)
				{
					attempt_damage_entity(target_entity, GOBBY_DAMAGE, en, make_props(EntityProps.gobby, .monster));
				}
			}
			
			if en.sprite_anim.is_finish
			{
				set_state(en, .idle_wait);
				en.idle_wait_timer = random_get_within_range(0.0, 0.5);
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

entity_death :: (en: *Entity)
{
	en.marked_for_destroy = true;
	do_death_poof(en);
	spawn_items_at_location(en.loot_drops, en.pos);
	new_event(.{kind=.death, entity=handle_from_entity(en)});
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
			entity_death(en);
		}
		
		// enter agro
		target_entity := get_entity_target(en);
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
			entity_death(en);
		}
		
		// enter agro
		target_entity := get_entity_target(en);
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
		item.pickup_cooldown = 0.2;
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
	if random_pct(0.5) then en.loot_drops[1] = .{id=.wood, amount=1};
	en.flip_sprite = random_bool();
	entity_set_sprite(en, .tall_grass_0);
}
setup_tall_grass_stub :: (en: *Entity)
{
	add_props(*en.props, .crop, .render_sprite, .structure);
	en.z_layer = Z_TALL_GRASS;
	en.archetype = .tall_grass;
	entity_set_sprite(en, .tall_grass_stub);
	en.time_til_growth = random_get_within_range(60, 240);
}

// randy: NOTE
// when setting up the berry bush, I want the behvaiour to be localised in the one spot, so I know
// what to do when authoring a new one.
// Right now, the .harvestable and .crop growing are spread out into their own systems with a branch.
// We want that to happen right here instead to keep things localised.
// how do??
// mebe something like...

// ...we got the base resource setup
berry_res_init :: (res: *ArcResource)
{
	add_props(*res.props, .consumable);
	res.flags |= .item;
	res.on_consume = (en: *Entity)
	{
		consume_item(en);
		heal_entity(get_player(), 10);
		restore_hunger(2);
		play_sound_global("eat");
	};
}

// ...and the entity setup
setup_berry_bush :: (en: *Entity)
{
	add_props(*en.props, .berry_bush, .render_sprite, .loot_drops, .harvestable, .structure, .damage_when_overlap);
	en.z_layer = Z_TALL_GRASS;
	en.loot_drops[0] = .{id=.berry, amount=1+cast(int)random_pct(0.5)};
	en.flip_sprite = random_bool();
	entity_set_sprite(en, .berry_bush);
}
setup_berry_bush_plucked :: (en: *Entity)
{
	add_props(*en.props, .crop, .render_sprite, .structure, .damage_when_overlap);
	en.z_layer = Z_TALL_GRASS;
	entity_set_sprite(en, .berry_bush_plucked);
	en.time_til_growth = random_get_within_range(60, 240);
}

// ... then the specific props that give it functionality
// :harvest
berry_bush_harvest :: (en: *Entity)
{
	reset_entity_props(en);
	setup_berry_bush_plucked(en);
	spawn_items_at_location(en.loot_drops, en.pos);
}
// :crop
berry_bush_crop :: (en: *Entity)
{
	if tick_timer(*en.time_til_growth, delta_t_scaled())
	{
		reset_entity_props(en);
		setup_berry_bush(en);
	}
}

// ^^^ ... this ????
// randy: Like it keeps things nice and central so that changing stuff is easy.
// It's kinda like a light-weight version of the OOP base class overiding of functions in
// a lot of game engines. Maybe we're on the right track here. Idk?
// We'll see how it holds up with time - 19-11-2023-102521



update_crops :: ()
{
	for * en : app.world.entities
		if is_valid(en) && has_prop(en.props, .crop)
	{
		if has_prop(en.props, .berry_bush)
		{
			berry_bush_crop(en);
		}
		else if en.archetype ==
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

			tile_pos := world_to_tile_pos(en.pos.x);
			trees := get_world_trees();
			should_grow := true;

			for tree : trees
			{
				tree_tile_pos := world_to_tile_pos(tree.pos.x);
				if abs(tile_pos - tree_tile_pos) <= 2
				{
					should_grow = false;
					break;
				}
			}

			if should_grow && tick_timer(*en.time_til_growth, delta_t_scaled())
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
	add_props(*en.recieve_damage_from, .axe, .pickaxe, .club);
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
	add_props(*en.recieve_damage_from, .axe, .club);
	entity_set_sprite(en, "tree_full");
	en.collision_rect.max = xy(14, 64);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.health = TREE_HEALTH;
	en.max_health = TREE_HEALTH;
	en.z_layer = Z_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	en.item_id = .tree;
	en.x_dir = 0;
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
			
			if tree.x_dir == 0
			{
				tree.x_dir = sign(player.pos.x - tree.pos.x);
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
				/*
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
				}*/
				
				// randy: no longer splitting the logs up, just straight up dropping the loot
				drops : [..]ItemID;
				for 0..3
					array_add(*drops, .wood);
				for 0..cast(int)random_pct(0.15)
					array_add(*drops, .acorn);
				array_shuffle(*drops);
				for drops
				{
					en := create_world_item(it);
					pos := xy(tree.pos.x + (30.0 + it_index * 20.0) * tree.x_dir, 0);
					en.pos = pos;
					en.velocity.x = random_get_within_range(100, 200);
					
					create_emitter(pos, .death_poof);
				}
				
				new_event(.{kind=.death, entity=handle_from_entity(tree)});
				tree.marked_for_destroy = true;
				
				// play_sound_old(.tree_impact);
				camera_shake_at_pos(0.6, tree.pos, 300, 400);
			}
		}
	}
}

render_tree :: (en: Entity)
{
	draw_generic_entity(en);
	
	pct := entity_health_pct(en);
	flags := ifx en.flip_sprite then QuadFlags.x_flipped else 0;
	if en.x_dir == 1
	{
		flags |= .slice_x_from_right;
	}
	else
	{
		flags |= .slice_x_from_left;
	}
	
	quad := draw_sprite(.tree_cover, en.pos + xy(0, 14), z_layer=Z_TREE-0.1, slice_pct=pct, flags=flags);
	apply_quad_adjustments_from_entity(quad, en);
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
	add_props(*en.recieve_damage_from, .pickaxe, .club);
	entity_set_sprite(en, .rock_deposit);
	//en.collision_rect.max = xy(64, 64);
	//en.collision_rect = range_bottom_center(en.collision_rect);
	en.collision_rect = make_range(xy(128, 16), pivot=.bottom_center);
	en.health = 30;
	en.z_layer = Z_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	en.item_id = .rock_deposit;
	en.loot_drops[0] = .{id=.stone, amount=1+cast(int)random_pct(0.8)};
	en.loot_drops[1] = .{id=.flint, amount=1+cast(int)random_pct(0.2)};
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

get_entity_width_range :: (en: *Entity) -> Range1
{
	return .{en.pos.x - 6.0, en.pos.x + 6.0};
}

player_update :: ()
{
	player := get_player();
	if !has_prop(player.props, .enabled) then return;
	
	// dmg cooldown tick
	tick_timer(*player.damage_immunity_cooldown, delta_t_scaled());
	
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
	
	// set the movement dir
	if player.input_axis.x != 0.0 && !disable_input
	{
		player.x_speed_accel = PLAYER_ACCEL;
		player.x_speed_decel = PLAYER_DECEL;
		
		player.x_speed_target = max_player_move_speed;
		player.x_dir = sign(player.input_axis.x);
	}
	else
	{
		player.x_speed_target = 0.0;
	}
	
	// blocking
	BLOCK_DURATION :: 0.6;
	BLOCK_COOLDOWN :: 1.0;

	if player.can_block 
	{
		attempt_block := key_down(.MOUSE_BUTTON_RIGHT)
					//&& has_prop(get_held_entity().props, .blockable)
					&& (player.state == .idle || player.state == .walk);

		if attempt_block 
		{
			player.is_blocking = true;
			player.white_override = 0.8;
			if tick_timer(*player.blocking_timer, delta_t_scaled(), zero_counts_as_complete=true)
			{
				player.can_block = false;
				player.block_cooldown_timer = BLOCK_COOLDOWN;
			}
		}
		else
		{

			player.is_blocking = false;
			player.white_override = 0.0;
		}	
	}
	else
	{
		if tick_timer(*player.block_cooldown_timer, delta_t_scaled(), zero_counts_as_complete=true)
		{
			player.can_block = true;
			player.blocking_timer = BLOCK_DURATION;
		}
		player.is_blocking = false;
		player.white_override = 0.0;
	}

	held_en := get_held_entity();

	if app.interface_mode == .nil &&
	key_pressed(.MOUSE_BUTTON_RIGHT)
	{
		if has_prop(held_en.props, .placeable)
		{
			consume_key(.MOUSE_BUTTON_RIGHT);
			app.placing_item = handle_from_entity(held_en);
			set_interface_mode(.item_place);
			
		}
		else if has_prop(held_en.props, .consumable)
		{
			consume_key(.MOUSE_BUTTON_RIGHT);
			item := get_item(held_en.item_id);
			item.on_consume(held_en);
		}
		else if has_prop(held_en.props, .equippable)
		{

			equipped_slot := get_item_equipped_slot(held_en);
			consume_key(.MOUSE_BUTTON_RIGHT);
			if equipped_slot == null
			{
				//Equip
				free_slot := get_free_equipment_slot();
				equip_item(held_en, free_slot);
			}
			else
			{
				//Unequip
				<<equipped_slot = .{};
			}
		}
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
	
	// WALK
	if player.state == .walk
	{
		entity_set_sprite(player, .ron_sprint_base);
		
		if player.input_axis.x == 0.0
		{
			set_state(player, .idle);
		}
	}

	// :DASH
	// randy: move everything here to simplify things. No longer using state since we'd like to preserve
	// running and stuff. I just cave man threw some variables in.

	// Get max possible dashes
	additional_dashes := 0;
	for get_player().equipped_items if is_valid(it)
	{
		en := entity_from_handle(it);
		item := get_item(en.item_id);
		additional_dashes += item.additional_dashes;
	}
	max_dashes := DASH_BASE_COUNT + additional_dashes;

	if tick_timer(*player.dash_cooldown_timer, delta_t_scaled())
	{
		player.frame.dash_recharged = true;
		player.dash_count -= 1;
		// print("% dash count is now: %\n max dashes: %\n", app.frame_count, player.dash_count, max_dashes);
		//Player dashed a few more times
		if player.dash_count > 0
		{
			player.dash_cooldown_timer = DASH_COOLDOWN;
		}
		else if player.dash_count < 0 then player.dash_count = 0;
	}
	if !disable_input && 
		player.dash_count < max_dashes &&
		app.frame.key_pressed[app.settings.keybinds.dash]
	{
		consume_key(app.settings.keybinds.dash);
		player.dashing = true;
		if player.dash_timer <= 0.0 then player.dash_timer = DASH_DURATION;
		player.dash_dir = player.x_dir;
		player.dash_initial_pos = player.pos;
		player.dash_count += 1;
		
		create_emitter(player.pos, .dash, player);
		
		play_sound("dash", player.pos);
		
		player.damage_immunity_cooldown = DASH_DURATION + 0.5;
		
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
		DASH_DISTANCE :: 100.0;
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

	// :hunger
	//Probably should be damage event, how to handle several damage events?
	#if !DISABLE_HUNGER_TICK
	{
	if tick_timer(*player.hunger_timer, delta_t_scaled(), zero_counts_as_complete=true)
	{
		player.hunger_timer = get_hunger_timer_duration();

		if player.hunger > 0 then player.hunger -= 1;

		if player.hunger <= 0 then player.health -= 1;

		if player.health <= 0 then set_state(player, .dying);
	}
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
			player.timer2 = 1.0;
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

			storage_slots := get_player_storage_slots();

			for slot : storage_slots
			{
				item_en := entity_from_handle(slot);

				while item_en.item_count > 1
				{
					item_en.item_count -= 1;
					new_item := entity_duplicate(item_en);
					new_item.item_count = 1;
					drop_item(new_item);
				}

				drop_item(item_en);
				slot.* = .{};
			}
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
		held_en := get_held_entity();
		
		// enter slash
		if key_pressed(.MOUSE_BUTTON_LEFT)
			&& get_held_entity().item_id == .flint_sword
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .player_sword_slash1_item);
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
		
		// enter bonk
		if key_pressed(.MOUSE_BUTTON_LEFT)
			&& has_prop(held_en.props, .club)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			play_animation(*player.attack_anim, .player_club_bonk_item);
		}
	}
	
	// CLUB :BONK
	if player.attack_anim.id == .player_club_bonk_item
	{
		if player.attack_anim.is_start
		{
			create_emitter(player.pos, .club_bonk_trail, player);
		}
		
		axe_hitbox: Range2;
		axe_hitbox.min = xy(0, 0);
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
	
	// AXE
	if player.attack_anim.id == .axe_swing_item
	{
		if player.attack_anim.is_start
		{
			// play_sound("pop");
			// play_sound_old(.sword_swing_01);
		}
		
		axe_hitbox: Range2;
		axe_hitbox.min = xy(0, 0);
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
	
	slash_hitbox: Range2;
	slash_hitbox.min = xy(0, 0);
	slash_hitbox.max = xy(40, 45);
	if player.x_dir == -1 then slash_hitbox = range_flip_x(slash_hitbox);
	slash_hitbox = range_shift(slash_hitbox, player.pos);
	// SLASH
	if player.attack_anim.id == .player_sword_slash1_item
	{
		if player.attack_anim.is_start
		{
			create_emitter(player.pos, .slash2, player);
		}
		
		// hit
		// TODO - this would ideally be some kind of tagged hitframe instead of hard-coded
		// on the frame here.
		if player.attack_anim.frame == 2 && player.attack_anim.frame_advanced
		{
			player_hit_thing(slash_hitbox);
			// debug_rect(slash_hitbox, 3000);
		}
		
		if player.attack_anim.frame < 5
		{
			app.disable_player_input = true;
		}
		
		if player.attack_anim.is_finish
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

	if is_inside_enclosed_base(player)
	{
		stack_count := 1 + entity_from_handle(g_world.base_totem_handle).upgrade_count;
		if !entity_has_effect(player, .rested)
		{
			apply_effect_to_entity(player, .rested, 25, stack_count);

			create_emitter(player.pos + .{0, 20}, .p_heal);			
		}
	}
	else
	{
		if entity_has_effect(player, .rested)
		{
			remove_effect_from_entity(player, .rested);
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

		held_en := get_held_entity();
		
		// apply effects from weapon
		effect_prop_check(held_en, hit_en);
		// todo - change this to an axe prop ?
		if held_item.id == .flint_axe
		{
			emit := create_emitter(player.pos + xy(player.x_dir * 40.0, 16), .wood_spray);
			emit.x_dir = player.x_dir;
			play_sound("wood_hit", player.pos);
			// TODO - I need some kinda way of knowing if this hit has killed the entity, so we can play
			// the hit_break sound
		}
		
		if held_item.id == .crude_club
		{
			play_sound_global("bonk");
		}
		
		if held_item.id == .flint_pickaxe
		{
			particle_type := EmitterKind.rock_spray;

			//We're hitting a stump, not a rock deposit
			if !has_prop(hit_en.props, .rock_deposit) then particle_type = .wood_spray;

			emit := create_emitter(player.pos + xy(player.x_dir * 40.0, 16), particle_type);
			emit.x_dir = player.x_dir;
			play_sound("rock_hit", player.pos);
		}
		
		if held_item.id == .flint_sword
		{
			play_sound("hit_impact", player.pos);
		}

		if has_prop(held_en.props, .durability)
		{
			held_en.health -= 1;
			if held_en.health <= 0
			{
				held_en.marked_for_destroy = true;
				play_sound_global("tool_break");
				create_emitter(player.pos, .tool_break, player);
				
				// exit player out of anim
				player.attack_anim = .{};
				set_state(player, .idle);
			}
		}
	}
	else
	{
		if held_item.id == .flint_sword || held_item.id == .flint_axe || held_item.id == .flint_pickaxe
		{
			play_sound("sword_swing_miss", player.pos);
		}
		
		if has_prop(held_item.props, .club)
		{
			app.camera.trauma += 0.4;
		}
	}
}

// :player_render - search it for all the lil dumbass state tendrils
// We're altering entity state here so I can be a caveman and just get it working
render_player :: (en: *Entity)
{
	// draw the base player sprite
	quad := draw_generic_entity(en);
	if en.damage_immunity_cooldown
	{
		quad.col.w = 0.85;
	}
	
	if !is_enabled(en) then return;

	flags := ifx en.x_dir == -1 then QuadFlags.x_flipped else 0;
	offset := make_transform(xy(0, -32));
	
	if en.attack_anim.is_finish
	{
		en.attack_anim.id = 0;
	}
	
	playing_anim := false;
	if en.attack_anim.id ==
	{
		case .player_sword_slash1_item;
		draw_sprite(.player_sword_slash2_item, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		// draw_sprite(.player_sword_slash1_trail, en.pos, offset_trs=offset, z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
		
		case .axe_swing_item;
		draw_sprite(.axe_swing_item, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.player_axe_swing_trail, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;

		case .pickaxe_swing_item;
		draw_sprite(.pickaxe_swing_item, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
		draw_sprite(.pickaxe_swing_trail, en.pos, offset_trs=make_transform(xy(0, -32)), z_layer=Z_FRONT_VFX, animation_index=en.attack_anim.frame, flags=flags);
		playing_anim = true;
		
		case .player_club_bonk_item;
		draw_sprite(.player_club_bonk_item, en.pos, offset_trs=offset, z_layer=en.z_layer-0.5, animation_index=en.attack_anim.frame, flags=flags);
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
		else if held_entity.item_id == .crude_club
		{
			trs := make_transform(xy(-14.0, 24.0 + xx sin(g_world.time_elapsed * 4)), 90);
			if abs(en.velocity.x) > 1
			{
				trs.translate.y -= abs(en.velocity.x) / 40.0;
				trs.translate.x -= en.x_dir * en.velocity.x / 50.0;
			}
			draw_sprite(.crude_club, en.pos, offset_trs=trs, z_layer=en.z_layer, flags=flags);
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
		else if held_entity.item_id != .nil
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
			label("%##%", from_c_string(it.notif_title.data), it.id);
			
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
		label(tprint("%##notif", from_c_string(big_notif.notif_title.data)));
		
		set_next_font_size(app.debug_config.ui_font_size * 2);
		set_next_pref_height(text_dim());
		label(tprint("%##notif_sub", from_c_string(big_notif.notif_subtitle.data)));
		
		if tick_timer(*big_notif.notif_remaining, delta_t())
		{
			entity_destroy_immediate(big_notif);
		}
	}
}

hints_menu :: ()
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
	label("SPACE - dash");
	spacer(em(0.5));
	label("E - interact");
	label("TAB - inventory");
	label("C - enter build mode");
	label("Q - drop item");
	spacer(em(0.5));
	label("Left Click - use tool");
	//label("Hold Right Click - block");
}

settings_menu :: ()
{
	animate_to_target(*app.settings_menu_alpha, app.settings_menu_alpha_t, delta_t());

	if app.settings_menu_alpha <= 0 then return;

	push_opacity(app.settings_menu_alpha);
	set_next_floating_y((1 - app.settings_menu_alpha) * 30.0);
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
	label("Settings");
	spacer(em(1));
	
	push_font_size(font_size_pct(1.2));
	push_text_justify_x(.center);
	push_pref_height(text_dim());
	push_pref_width(em(13));
	
	{
		//TODO(fhomolka): Side padding
		//Volume
		{
			adjusted_val := app.settings.volume * 100;
			val, sig := slider_int(xx adjusted_val, 0, 100, "Volume");
			app.settings.volume = val / 100.0;
		}

		if button("Save & Close###settings_save").clicked
		{
			app.settings_menu_alpha_t = 0.0;
			if app.app_mode == .main_menu
			{
				app.main_menu_alpha_t = 1.0;
			}
			else
			app.pause_menu_alpha_t = 1.0;
			settings_serialise(*app.settings);
		}
	}
	
	spacer(em(1));

}

// Main Menu

main_menu_ui :: ()
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
	/*
	if app.main_menu_alpha == 1.0 && app.world.initialized
	{
		serialise_world(*app.world);
		app.world = .{};
	}
	*/
	
	if app.main_menu_alpha == 0.0
	{
		return;
	}
	
	// menu background
	push_opacity(app.main_menu_alpha);
	set_next_pref_width(px(xx app.window_w));
	set_next_pref_height(px(xx app.window_h));
	menu_bg := make_box(.floating | .draw_sprite, "");
	menu_bg.sprite_id = .sky;
	push_parent(menu_bg);
	
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
			set_next_floating_y(-100);
			logo_box := make_box(.floating | .draw_sprite, "");
			logo_box.sprite_id = .game_logo;
		}

		//push_font(FONT_MAIN);
		//push_pref_height(text_dim());
		spacer(em(3.5));

		BUTTON_SPACER :: 0.2;

		if button("New Game##main").clicked
		{
			app.main_home_alpha_t = 0.0;
			app.main_controls_alpha_t = 1.0;
		}
		spacer(em(BUTTON_SPACER, 0));


		if file_exists(SAVE_FILE) && button("Load Game##main").clicked
		{
			set_interface_mode(.nil);
			set_app_mode(.world);
			//world_load();
			app.should_load_game = true;
		}
		spacer(em(BUTTON_SPACER, 0));

		if button("Controls##main_menu").clicked
		{
			//app.main_menu_alpha_t = 0.0;
			app.hints_menu_alpha_t = 1.0;
		}

		spacer(em(BUTTON_SPACER, 0));

		if button("Settings##main_menu").clicked
		{
			app.main_menu_alpha_t = 0.0;
			app.settings_menu_alpha_t = 1.0;
		}
		spacer(em(1, 0));

		set_next_fill_col(hex_to_rgba(0xa35256ff));
		if button("QUIT##main_menu").clicked
		{
			app.should_quit = true;
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
				push_parent(make_box(.draw_border | .draw_bg , ""));
				
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

gamemode_update :: ()
{
	// are we game over?
	totem := get_totem();
	if app.interface_mode != .game_over && !is_player_alive()
	{
		if totem.state == .off
		{
			set_interface_mode(.game_over);
		}
		else
		{
			set_interface_mode(.respawn_mode);
		}
	}
}

game_over_ui :: ()
{
	// game over state
	if is_state_entry(.game_over)
	{
		// play_sound_global("endgame");
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
	// pause the game
	if app.app_mode == .world && key_pressed(.ESCAPE) && app.interface_mode == .nil
	{
		consume_key(.ESCAPE);
		set_interface_mode(.pause_menu);
	}
	
	if app.interface_mode == .pause_menu && key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
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
		app.settings_menu_alpha_t = 0.0;
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
		if button("Settings##m").clicked
		{
			app.pause_menu_alpha_t = 0.0;
			app.settings_menu_alpha_t = 1.0;
		}
		
		spacer(em(0.5));
		divider();
		
		if button("SAVE").clicked
		{
			//serialise_world(g_world);
			start_saving_thread();
		}

		if file_exists(SAVE_FILE) && button("LOAD").clicked
		{
			set_interface_mode(.nil);
			world_load();
		}
		spacer(em(0.5));
		divider();
		
		set_next_fill_col(hex_to_rgba(0xa35256ff));
		if button("RESTART").clicked
		{
			world_reset();
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
			//add_props(*old_body.props, .harvestable);
			
			en := create_player();
			g_world.player_handle = handle_from_entity(en);
			set_interface_mode(.nil);
			old_body.marked_for_destroy = true;
			
			en.damage_immunity_cooldown = 2.0;
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

in_game_user_interaction :: ()
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
	
	player_storage_slots := get_player_storage_slots();
	
	// attempt to interact with them one-by-one
	hot_interactable: *Entity = get_nil_entity();
	for en: overlapped
	{
		if has_prop(en.props, .deconstructable)
		{
			if has_prop(get_held_entity().props, .deconstruct_tool)
			{
				defer break;
				hot_interactable = en;
				
				if key_pressed(app.settings.keybinds.interact)
				{
					consume_key(app.settings.keybinds.interact);
					create_emitter(en.pos, .death_poof);
					play_sound("harvest", en.pos);
					en.marked_for_destroy = true;
					
					if en.original_item_from_placement != .nil
					{
						// randy: we're a placed item
						spawn_items_at_location(.[.{en.original_item_from_placement, 1}], en.pos);
					}
					else if en.item_id
					{
						// randy: we're a structure I guess??
						item_res := get_resource(en.item_id);
						
						// drop the existing spent items
						spent_items: [en.remaining_items.count]ItemAmount;
						array_copy(spent_items, en.remaining_items);

						for * spent_items
						{
							if it.id == .nil then continue;
							//Broken into several lines for debugging
							recipe_amt := item_res.recipe[it_index].amount;
							remaining_amt := en.remaining_items[it_index].amount;
							it.amount = recipe_amt - remaining_amt;
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
		
		if is_campfire(en)
		{
			if attempt_campfire_input(en)
			{
				hot_interactable = en;
				break;
			}
		}
		else if is_workbench(en)
		{
			if input_attempt_workbench(en)
			{
				hot_interactable = en;
				break;
			}
		}
		else if is_storage_slab(en)
		{
			if input_attempt_storage_slab(en)
			{
				hot_interactable = en;
				break;
			}
		}
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
		else if (is_blueprint(en) || has_prop(en.props, .attack_target))
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
			
			if key_pressed(app.settings.keybinds.interact)
			{
				consume_key(app.settings.keybinds.interact);
				create_emitter(en.pos, .death_poof);
				
				play_sound_global("item_click");
				
				// :harvest
				if has_prop(en.props, .berry_bush)
				{
					berry_bush_harvest(en);
				}
				else if en.archetype == 
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
					for get_entity_storage_slots(en)
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

attempt_campfire_input :: (en : *Entity) -> bool
{
	if key_pressed(app.settings.keybinds.interact)
	{
		consume_key(app.settings.keybinds.interact);
		
		if app.active_campfire.entity_id == en.id
		{
			app.active_campfire = .{};
		}
		else
		{
			app.active_campfire = handle_from_entity(en);
		}
	}
	return true;
}

update_campfires :: ()
{
	for * en: app.world.entities if is_valid(en) && is_campfire(en)
	{
		campfire_ux(en);
		
		if en.crafting_item_id
		{
			if tick_timer(*en.crafting_timer, delta_t_scaled(), zero_counts_as_complete=true)
			{
				defer en.crafting_item_id = 0;
				
				item := create_world_item(en.crafting_item_id);
				item.pos = en.pos + xy(0, 20);
				item.velocity = xy(random_get_within_range(-30, 30), random_get_within_range(150, 200));
				
				create_emitter(item.pos + xy(0, 10), .parry, item);
				
				play_sound("pop", en.pos);
			}
			
			if entity_set_sprite(en, .campfire_on)
			{
				add_props(*en.props, .point_light);
				play_sound("fire_light", en.pos);
				en.light_radius_t = 200.0;
			}
		}
		else
		{
			if entity_set_sprite(en, .campfire_off)
			{
				create_emitter(en.pos, .death_poof);
				// play_sound("fire_putout", en.pos);
				remove_props(*en.props, .point_light);
			}
		}
	}
}

render_campfire :: (en : Entity)
{
	draw_generic_entity(en);
	
	if en.crafting_item_id
	{
		draw_sprite(en.crafting_item_id, en.pos + xy(0, 20 + 1.0 * sin_breathe(4.0)), z_layer=en.z_layer-0.1);
	}
	
	// completion progress wheel
	if en.crafting_timer != 0
	{
		// randy: TODO - should probably do this via the UI system so we can animate it better
		// This is good enough for now tho.
		item_res := get_resource(en.crafting_item_id);
		pct_complete := 1-(en.crafting_timer / item_res.craft_time);
		anim_frame :int= xx (cast(float)(get_resource(.completion_wheel).frame_count-1) * pct_complete);
		draw_sprite(.completion_wheel, en.pos + xy(0, -20), z_layer=Z_UI, animation_index=anim_frame);
	}
}

campfire_ux :: (en: *Entity)
{
	we_are_active_campfire := en.id == app.active_campfire.entity_id;
	en.active_alpha_target = ifx we_are_active_campfire then 1.0 else 0.0;
	
	// auto yeet when we get far enough away
	if we_are_active_campfire && abs(en.pos.x - get_player().pos.x) > 50
	{
		en.active_alpha_target = 0.0;
		app.active_campfire = .{};
	}
	// yeet on esc
	if we_are_active_campfire && key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		en.active_alpha_target = 0.0;
		app.active_campfire = .{};
	}
	
	// early out
	if en.active_alpha_target == 0.0 && en.active_alpha == 0.0 then return;
	
	animate_to_target(*en.active_alpha, en.active_alpha_target, delta_t());
	
	is_enabled := en.active_alpha_target == 1.0;
	alpha := en.active_alpha;
	
	if alpha != 0.0
	{
		before_slot := en.crafting_slot_index;
		defer
		{
			if before_slot != en.crafting_slot_index
			{
				play_sound_global("click");
			}
		}
		
		if is_enabled
		{
			// scroll up n down
			if app.frame.wheel_delta < 0
			{
				app.frame.wheel_delta = 0;
				en.crafting_slot_index += 1;
			}
			else if app.frame.wheel_delta > 0
			{
				app.frame.wheel_delta = 0;
				en.crafting_slot_index -= 1;
			}
		}
		
		// put all available crafting recipes in an array
		crafting_recipes : [..]*ArcResource;
		crafting_recipes.allocator = temp;
		for unlocked : g_world.unlocked_recipes
		{
			res := get_resource(xx it_index);
			if has_prop(res.props, .campfire_recipe) array_add(*crafting_recipes, res);
		}
		
		// fix up index to be in bounds
		en.crafting_slot_index = clamp(en.crafting_slot_index, 0, crafting_recipes.count-1);
		
		active_slot := en.crafting_slot_index;
		pos := world_pos_to_screen(en.pos + xy(0, 30));
		
		push_disable_signal(!is_enabled);
		push_opacity(alpha);
		
		slot_size := em(UI_SLOT_SIZE);
		margin := em(UI_MARGIN);
		slot_icon_padding := em(UI_SLOT_ICON_PADDING);
		slot_spacing := em(UI_SLOT_SPACING);
		slot_bg_col := COL_UI_BG;
		slot_border_col := GRAY;
		
		// parent box
		set_next_floating_x(pos.x);
		set_next_floating_y(pos.y);
		set_next_pref_size(size_by_children(1));
		set_next_child_layout_axis(.Y);
		set_next_bg_col(xyzw(0, 0, 0, 0.5));
		set_next_rect_pivot_x(.center);
		set_next_rect_pivot_y(.bottom);
		flags :BoxFlags= .floating | .clickable;
		// flags |= .draw_bg | .draw_border;
		parent_box := make_box(flags, tprint("%_campfire_ui", en.id));
		{
			push_parent(parent_box);
			
			push_pref_width(slot_size);
			push_pref_height(slot_size);
			
			if crafting_recipes.count > 0
			{
				slot_radius_count := 3;
				active_res := crafting_recipes[active_slot];
				
				// ingredients
				set_next_pref_width(pct_parent(1, 0));
				set_next_pref_height(size_by_children(1));
				// set_next_flags(.debug_draw);
				{
					auto_row();
					padding(pct_parent(1, 0));
					
					is_unlocked := g_world.unlocked_recipes[active_res.id];
					if is_unlocked && active_res.recipe.count > 0
					{
						for recipe_it : active_res.recipe
						{
							// grab le total item count
							storage_slots := get_player_storage_slots();
							total_item_count : int;
							for slot : storage_slots
							{
								slot_en := entity_from_handle(slot);
								if is_valid(slot_en) && slot_en.item_id == recipe_it.id
								{
									total_item_count += slot_en.item_count;
								}
							}
							
							// UI
							set_next_pref_height(size_by_children(1));
							set_next_pref_width(slot_size);
							set_next_flags(top_flags() | .draw_bg);
							{
								auto_column();
								
								box, icon := ui_item_icon(tprint("crafting_slot_%_material_%_%", active_slot, it_index, en.id), recipe_it.id, 0, slot_size, em(UI_SLOT_ICON_PADDING * 1.5));
								sig := signal_from_box(box);
								if sig.hovering
								{
									set_next_rect_pivot_y(.bottom);
									push_tooltip();
									item_tooltip(recipe_it.id);
								}
								
								set_next_font_size(font_size_pct(0.8));
								set_next_pref_height(text_dim(1));
								set_next_pref_width(pct_parent(1));
								set_next_text_justify_x(.center);
								lbl := label("%/%###", total_item_count, recipe_it.amount);
								
								// error flash
								if app.last_frame.do_crafting_error_flash
								{
									is_missing := total_item_count < recipe_it.amount;
									if is_missing then icon.target = 1.0;
								}
								if animate_to_target(*icon.value, icon.target, delta_t(), rate=40.0) && icon.target == 1.0 then icon.target = 0;
								if icon.value != 0
								{
									icon.render_adjust_trs.scale = xy(1.0 + icon.value * 0.2);
									icon.multiply_col = lerp(WHITE, RED, icon.value);
									lbl.render_adjust_trs.scale = xy(1.0 + icon.value * 0.2);
									lbl.multiply_col = lerp(WHITE, RED, icon.value);
								}
							}
						}
					}
				}
				
				// recipes row
				set_next_pref_width(size_by_children(1));
				set_next_pref_height(slot_size);
				{
					auto_row();
					
					for active_slot-slot_radius_count..active_slot+slot_radius_count
					{
						we_are_active_slot := it == active_slot;
						
						if it < 0 || it > crafting_recipes.count-1
						{
							make_box(0, ""); // dummy box to keep layout fixed
						}
						else
						{
							// we're a crafting recipe!
							recipe_res := crafting_recipes[it];
							is_unlocked := g_world.unlocked_recipes[recipe_res.id];
							
							flags := BoxFlags.draw_bg;
							if we_are_active_slot then flags |= .draw_border;
							push_parent(make_box(flags, ""));
							box, icon_box := ui_item_icon(tprint("crafting_slot_%_%", it, en.id), recipe_res.id, 0, slot_size, slot_icon_padding);
							
							if !is_unlocked
							{
								icon_box.colour_override = GRAY;
								icon_box.colour_override_amount = 1.0;
							}
							else
							{
								icon_box.colour_override_amount = 0.0;
							}
							
							sig := signal_from_box(box);
							if sig.pressed && en.crafting_item_id == 0
							{
								en.crafting_slot_index = it;
								
								if we_are_active_slot && is_unlocked
								{
									can_craft := can_craft_recipe(recipe_res);
									if can_craft
									{
										#if !IGNORE_MATERIAL_COST then take_recipe_items(recipe_res);
										app.active_campfire = .{};
										en.crafting_item_id = recipe_res.id;
										en.crafting_timer = recipe_res.craft_time;
										
										play_sound_global("item_click");
										
										new_event(.{kind=.start_campfire_craft, res_id=recipe_res.id});
									}
									else
									{
										app.frame.do_crafting_error_flash = true;
									}
								}
							}
							if sig.hovering
							{
								push_tooltip();
								if is_unlocked
								{
									item_tooltip(recipe_res.id);
									if we_are_active_slot
									{
										set_next_pref_size(size_by_children(1));
										auto_row();
										{
											icon(.left_click_icon, "", em(1));
											
											set_next_pref_width(text_dim(1));
											set_next_pref_height(text_dim(1));
											label("craft");
										}
									}
								}
								else
								{
									label("???###");
								}
							}
						}
					}
				}
			}
		}
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

	if item.durability > 0
	{
		en.health = item.durability;
		add_props(*en.props, .durability);
	}
}

update_items :: ()
{
	player := get_player();
	player_storage_slots := get_player_storage_slots();
	
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
			&& is_player_alive()
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
	slots : [..]*EntityHandle;
	slots.allocator = temp;
	array_reserve(*slots, 128);
	
	en := get_player();
	
	for * en.hotbar_slots
	{
		// I'm not using the 0 slot. Idk why this is??
		if it_index == 0 then continue;
		if it_index == get_hotbar_slot_count() + 1 then break;
		array_add(*slots, it);
	}
	
	for * en.storage_slots
	{
		if it_index == get_inventory_slot_count() then break;
		array_add(*slots, it);
	}
	
	return slots;
}

get_entity_storage_slots :: (en: *Entity) -> [..]*EntityHandle
{
	slots : [..]*EntityHandle;
	slots.allocator = temp;
	array_reserve(*slots, 128);
	
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
		&& key_pressed(app.settings.keybinds.inventory)
	{
		consume_key(app.settings.keybinds.inventory);
		set_interface_mode(.inventory);
	}
	// exit
	if app.interface_mode == .inventory
		&& key_pressed(app.settings.keybinds.inventory)
	{
		consume_key(app.settings.keybinds.inventory);
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
		
		push_disable_signal(!is_inventory_open);
		
		// inventory slots
		{
			push_opacity(app.inventory_alpha);
			
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			auto_column();
			defer spacer(margin);
			
			ROW_LENGTH :: 5;
			
			slot_count := 0;
			for row : 0..get_inventory_slot_count() / ROW_LENGTH
			{
				if row != 0 then spacer(slot_spacing);
				
				set_next_pref_height(size_by_children(1));
				set_next_pref_width(size_by_children(1));
				auto_row();
				padding(margin);
				
				for column : 1..ROW_LENGTH
				{
					defer slot_count += 1;
					if slot_count == get_inventory_slot_count() then break;
					
					if column != 1 then spacer(slot_spacing);
					
					set_next_pref_size(slot_size, slot_size);
					set_next_border_col(slot_border_col);
					set_next_bg_col(slot_bg_col);
					set_next_flags(.draw_bg | .draw_border);
					ui_storage_slot(tprint("inv_slot_%_%", column, row), *player.storage_slots[slot_count], slot_icon_padding);
				}
			}
		}
		
		if is_inventory_open
		{
			bg_box_sig = signal_from_box(bg_box);
		}
	}
	
	// Cursor
	{
		item_en := entity_from_handle(app.mouse_held_item);
		
		// randy: this is an auto drop when inv closes
		// if !is_inventory_open && is_valid(item_en)
		// {
		// 	item_to_drop = entity_from_handle(app.mouse_held_item);
		// 	app.mouse_held_item = .{};
		// }
		
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
			if !bg_box_sig.contains
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
	if item_to_drop == null && !app.disable_player_input && is_valid(get_held_entity()) && key_pressed(app.settings.keybinds.drop_item)
	{
		consume_key(app.settings.keybinds.drop_item);
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

get_free_equipment_slot :: () -> *EntityHandle
{
	for * get_player().equipped_items
	{
		if !has_prop(entity_from_handle(it).props, .valid)  then return it;
	}
	return null;
}

equip_item :: inline (item: *Entity, slot: *EntityHandle)
{
	<<slot = handle_from_entity(item);
}

snap_to_tile_grid :: (world_pos: float) -> float
{
	return round(world_pos / TILE_WIDTH) * TILE_WIDTH;
}

world_to_tile_pos :: (world_pos: float) -> int
{
	return xx round(world_pos / TILE_WIDTH);
}

tile_pos_to_world :: (tile_pos: int) -> float
{
	return cast(float)TILE_WIDTH * tile_pos;
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

get_world_trees :: () -> [..]*Entity
{
	tree_array : [..]*Entity;
	tree_array.allocator = temp;
	for * en: g_world.entities if is_valid(en) && has_prop(en.props, .tree)
	{
		array_add(*tree_array, en);
	}
	quick_sort(tree_array, x => (x.pos.x));
	#if false
	{
		for en : tree_array
			print("%, ", en.item_id);
		if tree_array.count then print("\n");
	}
	return tree_array;
}

get_world_crops :: () -> [..]*Entity
{
	crop_array : [..]*Entity;
	crop_array.allocator = temp;
	for * en: g_world.entities if is_valid(en) && has_prop(en.props, .crop)
	{
		array_add(*crop_array, en);
	}
	quick_sort(crop_array, x => (x.pos.x));
	#if false
	{
		for en : crop_array
			print("%, ", en.item_id);
		if crop_array.count then print("\n");
	}
	return crop_array;
}

item_placement_ux :: ()
{
	if app.interface_mode == .item_place && (key_pressed(.ESCAPE) || key_pressed(.MOUSE_BUTTON_RIGHT))
	{
		if key_pressed(.ESCAPE)
			{consume_key(.ESCAPE);}
		else 
			{consume_key(.MOUSE_BUTTON_RIGHT);}
		set_interface_mode(.nil);
	}
	
	if app.interface_mode == .item_place
	{
		app.item_place_mode_alpha_t = 1.0;
	}
	else
	{
		app.item_place_mode_alpha_t = 0.0;
	}
	animate_to_target(*app.item_place_mode_alpha, app.item_place_mode_alpha_t, delta_t());
	is_placing := app.item_place_mode_alpha_t == 1.0;
	
	player := get_player();
	item_en := entity_from_handle(app.placing_item);
	item_res := get_resource(item_en.item_id);
	
	if app.item_place_mode_alpha != 0
	{
		slot_size := em(UI_SLOT_SIZE);
		margin := em(UI_MARGIN);
		slot_icon_padding := em(UI_SLOT_ICON_PADDING);
		slot_spacing := em(UI_SLOT_SPACING);
		slot_bg_col := COL_UI_BG;
		slot_border_col := GRAY;
		
		// lil ui icon
		{
			alpha := app.item_place_mode_alpha;
			push_disable_signal(!is_placing);
			push_opacity(alpha);
			
			set_next_child_layout_axis(.Y);
			set_next_pref_width(pct_parent(1));
			set_next_pref_height(pct_parent(1));
			push_parent(make_box(.floating, ""));
			spacer(pct_parent(1, 0));
			
			{
				set_next_child_layout_axis(.X);
				set_next_pref_height(size_by_children(1));
				set_next_pref_width(pct_parent(1));
				set_next_opacity(alpha);
				// set_next_bg_col(COL_UI_BG * 0.5);
				bg_box := make_box(0, "");
				push_parent(bg_box);
				
				padding(pct_parent(1, 0)); 
				
				set_next_pref_width(size_by_children(1));
				set_next_pref_height(slot_size);
				auto_row();
				{
					push_pref_width(slot_size);
					push_pref_height(slot_size);
					
					push_parent(make_box(.draw_bg | .draw_border, ""));
					box := ui_item_icon(tprint("place_mode_icon"), app.last_known_placing_item, item_en.item_count, slot_size, slot_icon_padding);
					sig := signal_from_box(box);
				}
			}
		}
	}
		
	if is_placing && is_valid(item_res)
	{
		app.last_known_placing_item = item_res.id;
		
		// see if we've got room at out mouse pos
		pos: Vector2 = xy(round(mouse_pos_in_world().x), 0);
		pos.x = clamp_bottom(0.0, pos.x);
		pos.x = snap_to_tile_grid(pos.x);
		tile_pos := world_to_tile_pos(pos.x);
		is_valid_spot, _ := attempt_place_item_at_pos(item_res.id, tile_pos);
		
		// click to place
		if key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			
			if is_valid_spot
			{
				en := create_entity();
				item_res.setup_func(en);
				add_props(*en.props, .deconstructable);
				en.x_dir = app.placement_x_dir;
				en.pos = pos;
				en.biome = g_world.player_biome;
				en.original_item_from_placement = item_res.id;
				add_props(*en.props, .placed_by_player);
				
				play_sound("struc_hammer", en.pos);
				new_event(.{kind=.place, entity=handle_from_entity(en)});
				
				consume_item(item_en);
				if item_en.marked_for_destroy
				{
					// doneskis, exit place
					set_interface_mode(.nil);
				}
			}
			else
			{
				app.frame.tried_to_place_but_failed = true;
			}
		}
		
		// ghost preview of placing item
		{
			// do a dummy setup so we can get the values we're after
			dummy_entity : Entity;
			item_res.setup_func(*dummy_entity);
			
			col := ifx is_valid_spot then WHITE else RED;
			col.w = 0.7;
			
			flags : QuadFlags = ifx app.placement_x_dir == -1 then .x_flipped;
			
			draw_sprite(dummy_entity.sprite_id, pos, flags=flags, z_layer=dummy_entity.z_layer, col=col);
		}
	}
}

tile_range_from_entity :: (en: *Entity) -> Range1
{
	range := tile_range_from_item(en.pos.x, get_resource(en.item_id));
	return range;
}

tile_range_from_item :: (world_pos: float, item_res: *ArcResource) -> Range1
{
	half_width := (cast(float)item_res.structure_tile_width / 2.0) * TILE_WIDTH;
	// randy: the -2.0 padding is here so we don't overlap right on the edge
	range := Range1.{world_pos - half_width + 2.0, world_pos + half_width - 2.0};
	return range;
}

attempt_place_item_at_pos :: (item: ItemID, tile_pos: int) -> is_valid_spot:bool, error_msg:string
{
	world_structures := get_world_structures();
	item_res := get_resource(item);
	pos_x := tile_pos_to_world(tile_pos);
	
	our_range := tile_range_from_item(pos_x, item_res);
	#if TESTING
	{
		debug_pos(xy(our_range.min, 0), 1);
		debug_pos(xy(our_range.max, 0), 1);
	}
	
	// grab all the overlapping thingos
	overlapped_obstacles: [..]*Entity;
	overlapped_obstacles.allocator = temp;
	does_overlap := false;
	for against_en : world_structures
		if get_resource(against_en.item_id).tile_blocking_layer == item_res.tile_blocking_layer
	{
		// do they be overlapping dou?
		against_range := tile_range_from_entity(against_en);
		if range_overlaps(against_range, our_range)
		{
			does_overlap = true;
			array_add(*overlapped_obstacles, against_en);
			break;
		}
	}
	
	
	
	error_msg : string;
	is_valid_spot : bool;
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
	
	// base building constraints
	if !has_prop(item_res.props, .can_place_outside_base)
	{
		if is_base_active()
		{
			if !range_contains(get_base_range(), pos_x)
			{
				is_valid_spot = false;
				error_msg = "Out of base range";
			}
			
			/*
			if !has_prop(item_res.props, .only_placable_inside_core_base)
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
	
	// make all overlapped thingos red so it's clear what the problem is
	if !is_valid_spot
	for en : overlapped_obstacles
	{
		en.frame.colour_multiplier = RED;
	}

	if  item == .wood_defense_wall ||
		item == .stone_defense_wall
	{
		back_wall_seq := get_back_wall_grid_sequence();

		if back_wall_seq <= 0
		{
			is_valid_spot = false;
			error_msg = "Build a Back Wall first";
		}
		else
		{
			is_valid_spot = back_wall_seq + 1 == tile_pos;

			if !is_valid_spot
			{
				error_msg = "must be placed at the edge of the back wall";
			}
		}

	}
	else if item == .wood_back_wall
	{
		back_wall_seq := get_back_wall_grid_sequence();

		if back_wall_seq < 0
		{
			is_valid_spot = tile_pos == 0;

			if !is_valid_spot
			{
				error_msg = "The wall must start at the edge";
			}
		}
		else if back_wall_seq + 3 != tile_pos
		{
			is_valid_spot = false;
			error_msg = "The wall must continue the existing wall";
		}
	}

	return is_valid_spot, error_msg;
}

// particle system

// use this, for the kind, make a new one at each :/particle jump point
create_emitter :: (pos: Vector2, kind: EmitterKind, from_entity: *Entity=null) -> *Entity
{
	en := create_entity("", g_world.player_biome);
	add_props(*en.props, .particle_emitter, .render_sprite);
	en.pos = pos;
	en.emitter = kind;
	en.from_entity = handle_from_entity(from_entity);
	return en;
}

new_particle :: () -> *Particle
{
	app.particle_cursor = (app.particle_cursor + 1) % app.particles.count;
	p := *app.particles[app.particle_cursor];
	#if DEBUG
	{
		if p.flags & .valid then log_warning("We're overriding particles! Increase array size or pull back on amount");
	}
	<<p = .{};
	p.flags |= .valid;
	return p;
}

empower_entity :: (en: *Entity)
{
	add_props(*en.props, .particle_emitter, .empowered);
	en.emitter = .empowered;

	en.max_health *= 2;
	en.health = en.max_health;

	// array_add(en.loot_drops, .{id=.research_page, amount=1});
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
	lifetime: float;
	pivot: Pivot = .center_center;
	trs: Transform2;
	flags: ParticleFlags;
	sprite: string;
	animation_frame: int;
	time_til_next_frame: float;
	play_rate: float;
	x_dir: int;
	
	// randy: temp, until we do a proper @animtool
	// which I know full well won't happen because I'm lazy lol
	fade_out_length:= 0.2;
	fade_in_length:= 0.05;
}

EmitterKind :: enum #specified
{
	nil :: 0;
	jump_dust :: 1;
	landing_dust :: 2;
	void_ambiance :: 3;
	death_poof :: 4;
	single_poof :: 5;
	parry :: 6;
	wood_spray :: 7;
	rock_spray :: 8;
	empowered :: 9;
	slash1 :: 10;
	slash2 :: 11;
	poisoned :: 12;
	on_fire :: 13;
	p_heal :: 14;
	dash :: 15;
	tool_break :: 16;
	club_bonk_trail :: 17;
	crumble :: 18;
	petrify :: 19;
	p_learn :: 20;
	p_farming :: 21;
	p_enemy_spawn :: 22;
	// :particle
}

update_particle_emitters :: ()
{
	push_random_seed(get_chaos_seed());
	
	for * en : app.world.entities if is_valid(en) && has_prop(en.props, .particle_emitter)
	{
		from_en := entity_from_handle(en.from_entity);
		
		if en.emitter ==
		{
			case;
			log("Emitter not selected.");
			
			// :particle
			
			case .club_bonk_trail;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos - xy(0, 32);
			p.col = WHITE;
			p.vel = from_en.velocity * 0.2;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "player_club_bonk_trail";
			p.z_layer = Z_FRONT_VFX;
			p.pivot = .bottom_center;
			p.x_dir = from_en.x_dir;
			
			case .tool_break;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos + xy(from_en.x_dir * 30.0, 20.0);
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "p_parry";
			p.z_layer = Z_ENTITY_VFX;
			p.play_rate = 30;
			
			
			case .dash;
			en.marked_for_destroy = true;
			for 0..6
			{
				y_offset := it * 4.0;
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-5, 5), y_offset + random_get_within_range(-3, 3));
				p.col = WHITE;
				p.flags |= ParticleFlags.animate_sprite;
				p.vel = xy(from_en.x_dir * 100.0, random_get_within_range(-5, 5));
				p.sprite = "p_poof";
				p.z_layer = Z_ENTITY_VFX;
				p.play_rate = random_get_within_range(70, 100);
			}
			
			case .slash2;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos - xy(0, 32);
			p.col = WHITE;
			// p.vel = from_en.velocity;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "player_sword_slash2_trail";
			p.z_layer = Z_FRONT_VFX;
			p.pivot = .bottom_center;
			p.x_dir = from_en.x_dir;
			
			case .slash1;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos - xy(0, 32);
			p.col = WHITE;
			// p.vel = from_en.velocity;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "player_sword_slash1_trail";
			p.z_layer = Z_FRONT_VFX;
			p.pivot = .bottom_center;
			p.x_dir = from_en.x_dir;
			
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
			p.play_rate = 40;
			
			case .single_poof;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.pos;
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.vel = xy(random_get_within_range(-5, 5), random_get_within_range(0, 2));
			p.sprite = "p_poof";
			p.z_layer = Z_ENTITY_VFX;
			p.play_rate = random_get_within_range(50, 200);
			
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
				p.play_rate = random_get_within_range(50, 200);
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
			box := range_scale(get_collision_rect(en, skip_pos_shift=true), xy(0.8, 1.0));
			box.max *= 0.6;
			box = range_shift(box, en.pos);
			if tick_on_app_frequency(0.05)
			{
				p := new_particle();
				p.pos = xy(random_get_within_range(box.min.x, box.max.x), random_get_within_range(box.min.y, box.max.y));
				p.col = lerp(BLACK, WHITE, random_get_within_range(0, 0.5));
				p.lifetime = 0.3;
				p.z_layer = ifx random_bool() then Z_ENTITY_PFX else Z_ENTITY_VFX;
				p.flags |= ParticleFlags.fade_out | .fade_in;
				
				p.vel = xy(random_get_within_range(-2, 2), random_get_within_range(20, 40));
				p.vel += en.velocity * 0.5;
			}
			
			/*
			for 0..cast(int)(100.0 * delta_t_scaled())
			{
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-en.collision_rect.max.x, en.collision_rect.max.x), random_get_within_range(10, en.collision_rect.max.y + 10));
				p.vel = en.velocity/2.0 + xy(random_get_within_range(-0.5, 0.5), random_get_within_range(0.5, 1));
				p.col = WHITE;
				p.time_left = 20;
				p.z_layer = Z_ENTITY_VFX;
				p.flags |= ParticleFlags.animate_sprite | .fade_out;
				p.sprite = "p_ember2";
			}
			*/

			case .crumble;
			en.marked_for_destroy = true;
			MAX_HEIGHT :: 20;
			for 0..cast(int)(600.0 * delta_t_scaled()) //600 may be overkill
			{
				p := new_particle();
				p.flags |= .fade_out | .gravity;
				p.pos = en.pos + xy(random_get_within_range(-8, 8), xx (it % MAX_HEIGHT));
				p.col = lerp(#run hex_to_rgba(0x62797aff), WHITE, random_get_within_range(0, 0.5));
				p.vel = xy(0, random_get_within_range(50, 100));
				p.z_layer = 0.1;
				p.time_left = random_get_within_range(2, 5);
				p.trs.scale = xy(random_get_within_range(1, 2));
			}

			case .petrify;
			en.marked_for_destroy = true;
			MAX_HEIGHT :: 20;
			for 0..cast(int)(50 * delta_t_scaled())
			{
				p := new_particle();
				p.flags |= .fade_out | .gravity;
				p.pos = en.pos + xy(random_get_within_range(-8, 8), xx (it % MAX_HEIGHT));
				p.col = lerp(#run hex_to_rgba(0x62797aff), WHITE, random_get_within_range(0, 0.5));
				p.vel = xy(0, random_get_within_range(100, 200));
				p.z_layer = 0.1;
				p.time_left = random_get_within_range(2, 5);
				p.trs.scale = xy(random_get_within_range(1, 2));
			}

			case .p_learn;
			en.marked_for_destroy = true;
			for 0..cast(int)(100.0 * delta_t_scaled())
			{
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-5, 5), random_get_within_range(-10, 5));
				p.vel = en.velocity/2 + xy(random_get_within_range(-10, 10), random_get_within_range(6, 20));	
				p.col = WHITE;
				p.time_left = 20;
				p.z_layer = Z_PLAYER + ifx random_bool() then -0.5 else + 0.5;
				p.flags |= .animate_sprite | .fade_out;
				p.sprite = "p_learn";
				p.play_rate = random_get_within_range(70, 100);
			}

			case .p_farming;
			en.marked_for_destroy = true;
			if tick_on_app_frequency(0.46)
			{
				p := new_particle();
				p.pos = en.pos + xy(random_get_within_range(-5, 5), random_get_within_range(-10, 5));
				p.vel = en.velocity/2 + xy(random_get_within_range(-10, 10), random_get_within_range(6, 20));
				p.col = WHITE;
				p.flags |= ParticleFlags.animate_sprite;
				p.sprite = "p_farming";
				p.z_layer = Z_PLANTS + ifx random_bool() then -0.5 else + 0.5;
				p.pivot = .bottom_center;
				p.play_rate = random_get_within_range(90, 110);
			}

			case .p_enemy_spawn;
			{
				en.marked_for_destroy = true;
				for 0..cast(int)(100.0 * delta_t_scaled())
				{
					p := new_particle();
					p.flags |= .fade_out | .gravity;
					p.pos = en.pos + xy(random_get_within_range(-8, 8), random_get_within_range(-2, 1));
					p.col = lerp(#run hex_to_rgba(0xAA4646ff), WHITE, random_get_within_range(0, 0.5));
					//p.vel = xy(0, random_get_within_range(50, 100));
					p.z_layer = Z_PLAYER + random_get_within_range(-0.5, 0.5);
					p.time_left = random_get_within_range(2, 5);
					p.trs.scale = xy(random_get_within_range(1, 2));
				}
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
				p.play_rate = random_get_within_range(4, 6) * delta_t_scaled();
				//Transform the sprite so that they look less uniform
				p.trs.scale = xy(random_get_within_range(1, 1.5));
			}

		}
	}
}

update_particles :: ()
{
	// update particles
	for * p : app.particles
	{
		// apply gravity
		if p.flags & .gravity
		{
			p.vel.y -= 600 * delta_t_scaled();
		}
		
		// integrate
		// TODO - add acceleration and air drag
		p.pos += p.vel * delta_t_scaled();
		
		// start timer
		if p.time_left == 0
		{
			p.time_left = p.lifetime;
		}
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
			// if p.play_rate == 0 then p.play_rate = sprite.frame_duration_ms[0]; // broken
			
			// start of new frame
			if p.time_til_next_frame == 0
				&& !(p.flags & .paused)
			{
				rate := p.play_rate;
				if rate == 0
				{
					rate = sprite.frame_duration_ms[p.animation_frame];
				}
				
				p.time_til_next_frame = rate / 1000.0;
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
	}
}

// @animtool
// get colour over time?
// this'll also do the ol' alpha animation

render_particles :: ()
{
	for * p : app.particles
	{
		if p.flags & .valid
		{
			// calc the alpha
			alpha := p.col.w;
			pct := 1.0-float_alpha(p.time_left, 0.0, p.lifetime);
			if p.flags & .fade_in && pct < p.fade_in_length
			{
				alpha *= pct / p.fade_in_length;
			}
			if p.flags & .fade_out && pct > 1.0-p.fade_out_length
			{
				alpha *= 1-float_alpha(pct, 1.0-p.fade_out_length, 1.0);
			}
			col := p.col;
			col.w = alpha;
			
			if p.sprite == "" // single blank particle
			{
				adjust_trs := p.trs;
				adjust_trs.translate = p.pos;
				draw_rect(make_range(xy(1, 1)), col=col, trs=adjust_trs, z_layer=p.z_layer);
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
				
				flags := ifx p.x_dir == -1 then QuadFlags.x_flipped else 0;
				
				draw_rect(rect, texture=texture_from_sprite(sprite), col=col, uv_rect=uv_rect, z_layer=p.z_layer, flags=flags, trs=adjust_trs);
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

world_thread_copy: WorldState;

game_save_thread_proc :: (thread: *Thread) -> s64
{
	serialise_world(*world_thread_copy);
	return 0;
}

start_saving_thread :: ()
{

	world_thread_copy = <<g_world;
	//TEMP(fhomolka): Arena allocator can't handle this, so let me do all of this here.
	context.allocator = Allocator.{__default_allocator_proc, null};
	app.saving_thread = New(Thread);
	thread_init(app.saving_thread, game_save_thread_proc);
	thread_start(app.saving_thread);
}

saving_thread_update :: ()
{
	if app.saving_thread == null then return;
	context.allocator = Allocator.{__default_allocator_proc, null};
	if !thread_is_done(app.saving_thread) then return;

	thread_deinit(app.saving_thread);
	free(app.saving_thread);
	app.saving_thread = null;
}


serialise_world :: (world: *WorldState)
{
	sav_file, success := file_open(SAVE_FILE, for_writing=true);
	defer file_close(*sav_file);
	#if !MDF_SERIALISER
{
	cereal_write(*sav_file, *app.world, "world_save");
	return;
}

	//NOTE(fhomolka): I tried just dumping the entire WorldState, but that just freezes my pc, lmao

	file_write(*sav_file, "World = {\n");
	defer file_write(*sav_file, "\n}");

	world_ti := type_info(WorldState);
	world_void_ptr : *void = world;

	for world_ti.members
	{
		if it.type.type == .ARRAY then continue;

		val := world_void_ptr + it.offset_in_bytes;

		file_write(*sav_file, tprint("% = ", it.name));
		defer file_write(*sav_file, "\n");
		dump_str := value_to_string(val, it.type);
		file_write(*sav_file, dump_str);
	}

	for world_ti.members
	{
		if it.type.type != .ARRAY then continue;
		if it.name == "entities" then continue;

		val := world_void_ptr + it.offset_in_bytes;

		file_write(*sav_file, tprint("% = ", it.name));
		defer file_write(*sav_file, "\n");
		dump_str := value_to_string(val, it.type);
		file_write(*sav_file, dump_str);
		file_write(*sav_file, "\n");
	}

	{
		file_write(*sav_file, "entities = [\n");

		for * world.entities
		{
			file_write(*sav_file, "Entity = \n");
			dump_str := entity_to_string(it);
			file_write(*sav_file, dump_str);
			file_write(*sav_file, "\n");
		}
		file_write(*sav_file, "\n]\n");
	}

}

deserialise_world :: (world: *WorldState)
{
	sav_file, success := file_open(SAVE_FILE, for_writing=false);
	defer file_close(*sav_file);
#if !MDF_SERIALISER
{
	cereal_read(*sav_file, *app.world, "world_save");
	return;
}

	doc, err := load_from_file(SAVE_FILE);
	if err != .NONE then return;
	defer destroy(doc);

	if doc.elements[0].name != "World"
	{
		print("Found the Save file, but it's malformed!\n");
		return;
	}

	dst : *void = g_world;
	type_info_world := type_info(WorldState);
	for * elem, key : doc.elements[0].chunk_props
	{
		if key == "entities" then continue; //special case

		found, idx := find_member_by_name(type_info_world.members, key);
		if !found then continue;

		member := type_info_world.members[idx];
		field_ptr := dst + member.offset_in_bytes;

		print("member: %\n", member.name);
		value_from_element(elem, field_ptr, member.type);
	}

	//NOTE(fhomolka): A special pass for the entities
	/*
	* Look, this is jank, I know, but if it's handled through the for above
	* it causes issues. I don't understand why.
	*/
	
	if table_contains(doc.elements[0].chunk_props, "entities")
	{
		arr_ptr := table_find_pointer(doc.elements[0].chunk_props, "entities");

		for * arr_ptr.arr_props
		{
			if it.type != .CHUNK
			{
				print("Entities array contains non-chunks!\n");
			}

			en := *g_world.entities[it_index];

			fill_entity_from_chunk(en, it);

			//TODO(fhomolka): There's issues with valid
			if !has_prop(en.props, .valid) && en.id > 0
			{
				print("% Entity % is not valid\n", en.id, en.debug_name);
			}
			if en.id < 1
			{
				en.* = <<get_nil_entity();
			}
		}
	}
}

settings_serialise :: (settings: *UserSettings)
{
	sav_file, success := file_open(SETTINGS_FILE, for_writing=true);
	defer file_close(*sav_file);

	settings_info := type_info(UserSettings);
	settings_str := struct_to_string(settings, settings_info);
	file_write(*sav_file, "Settings = ");
	file_write(*sav_file, settings_str);
	
}

settings_deserialise :: (settings: *UserSettings) -> bool
{
	doc, ok := load_from_file(SETTINGS_FILE);
	if ok != .NONE then return false;
	defer destroy(doc);

	if doc.elements[0].name != "Settings"
	{
		print("Found the settings file, but it's malformed!\n");
		return false;
	}

	if table_contains(doc.elements[0].chunk_props, "volume")
	{
		val := table_find_pointer(doc.elements[0].chunk_props, "volume");
		fval := parse_float(*val.val);
		app.settings.volume = fval;
	}

	table_contains(doc.elements[0].chunk_props, "keybinds");
	{
		kbinds := table_find_pointer(doc.elements[0].chunk_props, "keybinds");

		v_left := table_find_pointer(kbinds.chunk_props, "move_left");
		v_right := table_find_pointer(kbinds.chunk_props, "move_right");
		v_run := table_find_pointer(kbinds.chunk_props, "run");
		v_dash := table_find_pointer(kbinds.chunk_props, "dash");
		v_interact := table_find_pointer(kbinds.chunk_props, "interact");
		v_inventory := table_find_pointer(kbinds.chunk_props, "inventory");
		v_drop := table_find_pointer(kbinds.chunk_props, "drop_item");
		v_build := table_find_pointer(kbinds.chunk_props, "build_mode");
		v_attack := table_find_pointer(kbinds.chunk_props, "attack");
		v_use := table_find_pointer(kbinds.chunk_props, "use_item");


		temp := parse_int(*v_left.val);
		app.settings.keybinds.move_left = xx temp;
		temp = parse_int(*v_right.val);
		app.settings.keybinds.move_right = xx temp;
		temp = parse_int(*v_run.val);
		app.settings.keybinds.run = xx temp;
		temp = parse_int(*v_dash.val);
		app.settings.keybinds.dash = xx temp;
		temp = parse_int(*v_interact.val);
		app.settings.keybinds.interact = xx temp;
		temp = parse_int(*v_inventory.val);
		app.settings.keybinds.inventory = xx temp;
		temp = parse_int(*v_drop.val);
		app.settings.keybinds.drop_item = xx temp;
		temp = parse_int(*v_build.val);
		app.settings.keybinds.build_mode = xx temp;
		temp = parse_int(*v_attack.val);
		app.settings.keybinds.attack = xx temp;
		temp = parse_int(*v_use.val);
		app.settings.keybinds.use_item = xx temp;
	}

	return true;
}

unlock_recipe :: (item_id: ItemID, silent:= false)
{
	if !g_world.unlocked_recipes[item_id]
	{
		g_world.unlocked_recipes[item_id] = true;
		item_res := get_resource(item_id);
		if !silent
		{
			create_notification(tprint("+ %", get_display_name(item_res)), is_big=true);
			play_sound_global("unlock");
			set_interface_mode(.nil);
		}
	}
}

update_recipe_unlocks :: ()
{
	if g_world.first_world_frame
	{
		unlock_recipe(.workbench, silent=true);
		unlock_recipe(.coal, silent=true);
		
		// unlock_recipe(.wood_defense_wall, silent=true);
		// unlock_recipe(.wood_back_wall, silent=true);
		// unlock_recipe(.campfire, silent=true);
		
		// this is temporary, so pretend it's not here
		unlock_recipe(.destroy_hammer, silent=true);
	}
	
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
		&& has_prop(it.props, .unlockable)
	{
		// skip if we've already handled this recipe
		recipe_known := g_world.unlocked_recipes[it.id];
		recipe_given := g_world.recipes_given[it.id];
		if recipe_known || recipe_given then continue;
		
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
				if event.kind == .start_campfire_craft
					should_unlock = true;
			
			case .storage_slab;
			slots := get_player_storage_slots();
			is_full := true;
			for slots
				if entity_from_handle(it).item_id == .nil
				{
					is_full = false;
					break;
				}
			should_unlock = is_full;
			
			case .stone_defense_wall;
			for event: g_world.events_this_frame
			{
				en := entity_from_handle(event.entity);
				if event.kind == .upgrade && has_prop(en.props, .base_totem) && en.upgrade_count > 1
					should_unlock = true;
			}
			
			case .crude_club;
			for event: g_world.events_this_frame
				if event.kind == .place && is_workbench(entity_from_handle(event.entity))
					should_unlock = true;
					
			case .wood_back_wall;
			for event: g_world.events_this_frame
				if event.kind == .pickup && entity_from_handle(event.entity).item_id == .crude_club
					should_unlock = true;
					
			case .wood_defense_wall;
			for event: g_world.events_this_frame
				if event.kind == .place && is_back_wall(entity_from_handle(event.entity))
					should_unlock = true;
					
			case .campfire;
			for event: g_world.events_this_frame
				if event.kind == .place && is_back_wall(entity_from_handle(event.entity))
					should_unlock = true;
			
			case .flint_shard;
			for event: g_world.events_this_frame
				if event.kind == .death && has_prop(entity_from_handle(event.entity).props, .gobby)
					should_unlock = true;
					
			case .flint_axe;
			for event: g_world.events_this_frame
				if event.kind == .death && is_tree(entity_from_handle(event.entity))
					should_unlock = true;
			
			case .flint_sword;
			for event: g_world.events_this_frame
				if event.kind == .death && has_prop(entity_from_handle(event.entity).props, .monster)
					should_unlock = true;
			
			case .flint_pickaxe;
			for event: g_world.events_this_frame
				if event.kind == .death && has_prop(entity_from_handle(event.entity).props, .rock_deposit)
					should_unlock = true;
			
			// randy: ingredient unlock
			// case .flint_shard; #through;
			// case .flint_pickaxe; #through;
			// case .flint_axe;
			case .gobby_pouch; #through;
			case .cooked_goblin_meat;
			should_unlock = all_ingredients_known;
			
			case;
			// randy: by default, we don't unlock it, so either work it into the game design with unlock pages
			// or just do a cheeky ingredient unlock
		}
		
		// unlock recipe yayyy
		if should_unlock
		{
			unlock_recipe(it.id);
			em := create_emitter(get_player().pos + xy(0, 50), .p_learn, get_player());
			em.z_layer = Z_ENTITY_PFX;
			
			// randy: old unlock
			//initiate_epic_unlock_sequence(it.id);
		}
	}
}

// make it fall from the fking sky lol
initiate_epic_unlock_sequence :: (item_to_unlock: ItemID)
{
	player := get_player();
	
	en := create_world_item(.research_page);
	en.pos = player.pos + xy(60 * random_sign(), 200);
	en.recipe_to_unlock = item_to_unlock;
	
	g_world.recipes_given[item_to_unlock] = true;
}

restore_hunger :: (amount: int)
{
	player := get_player();
	player.hunger += amount;
	player.hunger = clamp(player.hunger, 0, PLAYER_MAX_HUNGER);
	player.hunger_timer = get_hunger_timer_duration();
}

get_hunger_timer_duration :: () -> float
{
	// randy: this'll be procedural depending on some tings I'm sure
	return HUNGER_TIMER_DURATION;
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

build_mode_ux :: ()
{
	/*
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
	*/
	
	// randy: NOTE
	// We're now just using a hotkey to enter build mode
	if (app.interface_mode == .inventory || app.interface_mode == .nil)
		&& key_pressed(app.settings.keybinds.build_mode)
	{
		consume_key(app.settings.keybinds.build_mode);
		set_interface_mode(.build);
	}
	if app.interface_mode == .build && key_pressed(app.settings.keybinds.build_mode)
	{
		consume_key(app.settings.keybinds.build_mode);
		set_interface_mode(.nil);
	}
	// exit with esc
	if app.interface_mode == .build && key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
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
	
	is_enabled := app.build_mode_alpha_t == 1.0;
	
	// UI
	if app.build_mode_alpha != 0
	{
		// todo - crank up the visual coldness with a lut?
		
		before_slot := app.blueprint_slot_index;
		defer
		{
			if before_slot != app.blueprint_slot_index
			{
				play_sound_global("click");
			}
		}
		
		if is_enabled
		{
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
		}
		
		// put all available crafting recipes in an array
		blueprints : [..]ArcResource;
		blueprints.allocator = temp;
		for g_world.unlocked_recipes
		{
			res := get_resource(xx it_index);
			if has_prop(res.props, .build_recipe) then array_add(*blueprints, res);
		}
		
		// fix up index to be in bounds
		app.blueprint_slot_index = clamp(app.blueprint_slot_index, 0, blueprints.count-1);
		// update active selected bp
		if blueprints.count > 0 then app.active_blueprint_id = blueprints[app.blueprint_slot_index].id;
		
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
			is_unlocked := g_world.unlocked_recipes[recipe_res.id];

			set_next_child_layout_axis(.X);
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(pct_parent(1));
			set_next_opacity(app.build_mode_alpha);
			// set_next_bg_col(COL_UI_BG * 0.5);
			bg_box := make_box(.clickable, "build_mode_materials_box");
			push_parent(bg_box);
			
			padding(pct_parent(1, 0)); 
			
			storage_slots := get_player_storage_slots();

			if is_unlocked
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
			
			push_pref_width(slot_size);
			push_pref_height(slot_size);
			
			set_next_pref_width(size_by_children(1));
			set_next_pref_height(slot_size);
			{
				auto_row();
				
				count_each_side := 4;
				active_slot := app.blueprint_slot_index;
				
				if blueprints.count > 0
				{
					slot_radius_count := 5;
					active_res := blueprints[active_slot];
					
					for active_slot-slot_radius_count..active_slot+slot_radius_count
					{
						we_are_active_slot := it == active_slot;
						
						if it < 0 || it > blueprints.count-1
						{
							make_box(0, ""); // dummy box to keep layout fixed
						}
						else
						{
							recipe_res := blueprints[it];
							is_unlocked := g_world.unlocked_recipes[recipe_res.id];
							
							flags := BoxFlags.draw_bg;
							if we_are_active_slot then flags |= .draw_border;
							push_parent(make_box(flags, ""));
							box, icon_box := ui_item_icon(tprint("buildmode_slot_%", it), recipe_res.id, 0, slot_size, slot_icon_padding);
							if !is_unlocked
							{
								icon_box.colour_override = GRAY;
								icon_box.colour_override_amount = 1.0;
							}
							else
							{
								icon_box.colour_override_amount = 0.0;
							}
							sig := signal_from_box(box);
							if sig.pressed
							{
								app.blueprint_slot_index = it;
							}
							if sig.hovering
							{
								set_next_rect_pivot_y(.bottom);
								push_tooltip();
								if is_unlocked
								{
									item_tooltip(recipe_res.id);
								}
								else
								{
									label("???###");
								}
							}
						}
					}
				}
				
				
				/*
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
				*/
			}
		}
	}
	
	// yeet out now if this is locked, we ain't placin dat shit
	is_unlocked := g_world.unlocked_recipes[app.active_blueprint_id];
	if !is_unlocked then return;
	
	// actual placement logic
	pos: Vector2 = xy(round(mouse_pos_in_world().x), 0);
	pos.x = clamp_bottom(0.0, pos.x);
	pos.x = snap_to_tile_grid(pos.x);
	tile_pos := world_to_tile_pos(pos.x);
	is_valid_spot: bool;
	error_msg: string;
	
	is_placing := app.build_mode_alpha_t == 1.0;
	if is_placing
	{
		item_res := get_resource(app.active_blueprint_id);
		
		is_valid_spot, error_msg = attempt_place_item_at_pos(item_res.id, tile_pos);

		// Do they even have enough to build it?
		has_enough_for_recipe := true;
		storage_slots := get_player_storage_slots();
		for * recipe_item : item_res.recipe
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
		#if IGNORE_MATERIAL_COST then has_enough_for_recipe = true;
		if !has_enough_for_recipe
		{
			is_valid_spot = false;
		}
		
		// click to place
		if key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			
			if is_valid_spot && has_enough_for_recipe
			{
				en := create_entity();
				item_res.setup_func(en);
				add_props(*en.props, .deconstructable);
				en.x_dir = app.placement_x_dir;
				en.pos = pos;
				en.biome = g_world.player_biome;
				add_props(*en.props, .placed_by_player);
				
				play_sound("struc_hammer", en.pos);
				new_event(.{kind=.place, entity=handle_from_entity(en)});
				
				// Remove items from inventory
				#if !IGNORE_MATERIAL_COST
				for * recipe_item : item_res.recipe
				{
					if recipe_item.id == .nil then continue;
					en.remaining_items[it_index].id = recipe_item.id;
					en.remaining_items[it_index].amount = 0;

					remaining_amount := recipe_item.amount;
					for * storage_slots
					{
						slot_en := entity_from_handle(<<it);
						if is_valid(slot_en) && slot_en.item_id == recipe_item.id
						{
							remaining_amount -= en.item_count;
							if slot_en.item_count <= recipe_item.amount
							{
								slot_en.item_count = 0;
							}
							else
							{
								slot_en.item_count -= recipe_item.amount;
							}
							if slot_en.item_count <= 0 slot_en.marked_for_destroy = true;

							
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
	
	// post placement UI
	item_res := get_resource(app.active_blueprint_id);
	if is_valid(item_res) && app.build_mode_alpha != 0
	{
		// ghost preview of placing item
		{
			// do a dummy setup so we can get the values we're after
			dummy_entity : Entity;
			item_res.setup_func(*dummy_entity);
			
			col := ifx is_valid_spot then WHITE else RED;
			col.w = 0.7 * app.build_mode_alpha;
			
			flags : QuadFlags = ifx app.placement_x_dir == -1 then .x_flipped;
			
			draw_sprite(dummy_entity.sprite_id, pos, flags=flags, z_layer=dummy_entity.z_layer, col=col);
		}
		
		// mouse tooltip
		{
			push_opacity(app.build_mode_alpha);
			
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
	recipe[0] = .{id=.monster_essence, amount=4 * xx pow(2, xx upgrade_count)};
	return recipe;
}

set_totem_upgrade_count_and_recipe :: (en: *Entity, upgrade_count: int)
{
	en.upgrade_count = upgrade_count;
	memory_zero(*en.remaining_items_for_upgrade);
	array_copy(en.remaining_items_for_upgrade, get_totem_recipe_from_upgrade_count(upgrade_count));
}

finish_upgrade_of_entity :: (en: *Entity)
{
	// this is just assuming we're the base totem rn, but you could imagine this being a callback for a generic .upgrade
	set_totem_upgrade_count_and_recipe(en, en.upgrade_count + 1);
	play_sound("totem_on", en.pos);
	camera_shake(0.5);
	create_notification(tprint("+ Base Level %", en.upgrade_count + 1), is_big=true);
	new_event(.{kind=.upgrade, entity=handle_from_entity(en)});
}

setup_base_totem :: (en: *Entity)
{
	add_props(*en.props, .base_totem, .interactable, .render_sprite, .attack_target, .structure, .draw_health_bar);
	add_props(*en.recieve_damage_from, .monster);
	entity_set_sprite(en, .base_totem);
	en.z_layer = Z_BASE_TOTEM;
	en.item_id = .base_totem;
	en.health = BASE_MAX_HEALTH;
	en.max_health = BASE_MAX_HEALTH;
	set_totem_upgrade_count_and_recipe(en, 0);
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
					if key_pressed(app.settings.keybinds.interact)
					{
						consume_key(app.settings.keybinds.interact);
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

		//This auto-activates the base totem. lol ez
		set_state(en, .on);
		en.upgrade_count -= 1;
		finish_upgrade_of_entity(en);
		new_event(.{kind=.activate, entity=handle_from_entity(en)});
		return true;
	}
	
	return false;
}

update_base_totem :: (totem: *Entity)
{
	// receive damage
	if totem.damage_event.amount != 0
	{
		defer memory_zero(*totem.damage_event);
		
		totem.damage_alpha = 1.0;
		
		play_sound("wood_hit_break", totem.pos);

		item_res := get_resource(totem.item_id);
			for * totem.remaining_items
			{
				if it.id == .nil then continue;
				if it.amount >= item_res.recipe[it_index].amount continue;

				it.amount += 1;
		
				break;
			}

			should_break := true;
			for * totem.remaining_items
			{
				if it.id == .nil then continue;
				
				if it.amount >= item_res.recipe[it_index].amount then continue;
				
				should_break = false;
				break;
			}

			if should_break
			{
				//Deconstructed all items
				play_sound("wood_struc_break", totem.pos);
				convert_to_blueprint(totem);
			}
	}
	
	// update
	if totem.state == .on
	{
		if is_state_entry(totem, .on)
		{
			play_sound("totem_on", totem.pos);
			camera_shake(0.5);

			if g_steamState.initialized == true
			{
				steam_unlock_achievement(ACH_ID_BASE_TOTEM_ACTIVATED);
			}
		}
	}
	
	if totem.state == .off
	{
		if is_state_entry(totem, .off)
		{
		}
	}
}

get_totem :: () -> *Entity
{
	return entity_from_handle(g_world.base_totem_handle);
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

/*
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
*/

setup_cave_back :: (en: *Entity)
{
	en.debug_name = "cave_back";
	en.z_layer = Z_STRUCTURES;
	add_props(*en.props, .render_sprite);
	entity_set_sprite(en, .cave_edge_back);
}

create_cave_back :: inline () -> *Entity
{
	en := create_entity("cave_back");
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
	en := create_entity("cave_front");
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

create_healing_totem :: () -> *Entity
{
	en := create_entity("healing_totem");
	setup_healing_totem(en);
	return en;
}

setup_healing_totem :: (en: *Entity)
{
	en.max_health = 200;
	en.z_layer = Z_STRUCTURES;
	add_props(*en.props, .render_sprite, .structure, .healing_totem);
	entity_set_sprite(en, .healing_totem);
	en.collision_rect = rect_from_sprite(.healing_totem);
	en.timer1 = HEAL_FREQUENCY;
}

HEAL_FREQUENCY :: 1.0;
HEAL_AMOUNT :: 5;

update_healing_totem :: ()
{
	player := get_player();
	base_range := get_base_range();

	in_base := player.pos.x > base_range.min && player.pos.x < base_range.max;
	if !in_base
	{
		remove_effect_from_entity(player, .heal);
		return;
	}
	

	healing_totem: *Entity = get_nil_entity();

	for * en : g_world.entities	if is_valid(en) && has_prop(en.props, .healing_totem)
	{
		healing_totem = en;
		break;
	}

	if is_valid(healing_totem) && tick_timer(*healing_totem.timer1, delta_t_scaled(), zero_counts_as_complete=true)
	{
		apply_effect_to_entity(player, .heal, 10, 1);
		healing_totem.timer1 = 0.5;
	}
}

create_farming_totem :: () -> *Entity
{
	en := create_entity("farming_totem");
	setup_farming_totem(en);
	return en;
}

setup_farming_totem :: (en: *Entity)
{
	en.max_health = 200;
	en.z_layer = Z_STRUCTURES;
	add_props(*en.props, .render_sprite, .structure, .farming_totem);
	entity_set_sprite(en, .farming_totem);
	en.collision_rect = rect_from_sprite(.farming_totem);
}

FARM_BOOST_RADIUS :: 5;

update_farming_totem :: ()
{
	crops := get_world_crops();

	for * totem : g_world.entities if is_valid(totem) && has_prop(totem.props, .farming_totem)
	{
		totem_tile_pos := world_to_tile_pos(totem.pos.x);

		for crop : crops
		{
			crop_tile_pos := world_to_tile_pos(crop.pos.x);

			if abs(crop_tile_pos - totem_tile_pos) > FARM_BOOST_RADIUS then continue;

			tick_timer(*crop.time_til_growth, delta_t_scaled());
			//create_emitter(crop.pos, .p_heal); //IDEA: show the boosted plant?
		}
		crop_min_pos := tile_pos_to_world(totem_tile_pos - FARM_BOOST_RADIUS);
		crop_max_pos := tile_pos_to_world(totem_tile_pos  + FARM_BOOST_RADIUS);

		particle_pos := crop_min_pos;

		while particle_pos < crop_max_pos
		{
			increment := 1 + random_get_within_range(2, 4.5);
	 		em := create_emitter(xy(particle_pos, 1), .p_farming, totem);
	 		em.z_layer = 1;
			particle_pos += increment;
		}
	}	
}

setup_workbench :: (en: *Entity)
{
	en.item_id = .workbench;
	en.z_layer = Z_STRUCTURES;
	entity_set_sprite(en, .workbench);
	add_props(*en.props, .render_sprite, .workbench, .interactable, .structure);
}

is_workbench :: (en: Entity) -> bool
{
	return has_prop(en.props, .workbench);
}

input_attempt_workbench :: (en: *Entity) -> bool
{
	if key_pressed(app.settings.keybinds.interact)
	{
		consume_key(app.settings.keybinds.interact);
		
		if app.active_workbench.entity_id == en.id
		{
			app.active_workbench = .{};
		}
		else
		{
			app.active_workbench = handle_from_entity(en);
		}
	}
	return true;
}

render_workbench :: (en: Entity)
{
	draw_generic_entity(en);
	
	if en.crafting_item_id
	{
		draw_sprite(en.crafting_item_id, en.pos + xy(0, 20 + 1.0 * sin_breathe(4.0)), z_layer=en.z_layer-0.1);
	}
	
	// completion progress wheel
	if en.crafting_timer != 0
	{
		// randy: TODO - should probably do this via the UI system so we can animate it better
		// This is good enough for now tho.
		item_res := get_resource(en.crafting_item_id);
		pct_complete := 1-(en.crafting_timer / item_res.craft_time);
		anim_frame :int= xx (cast(float)(get_resource(.completion_wheel).frame_count-1) * pct_complete);
		draw_sprite(.completion_wheel, en.pos + xy(0, -20), z_layer=Z_UI, animation_index=anim_frame);
	}
}

update_workbenches :: ()
{
	for * en: g_world.entities if is_valid(en) && is_workbench(en)
	{
		workbench_ux(en);
		
		if en.crafting_item_id
		{
			if tick_timer(*en.crafting_timer, delta_t_scaled(), zero_counts_as_complete=true)
			{
				defer en.crafting_item_id = 0;
				
				item := create_world_item(en.crafting_item_id);
				item.pos = en.pos + xy(0, 20);
				item.velocity = xy(random_get_within_range(-30, 30), random_get_within_range(150, 200));
				
				create_emitter(item.pos + xy(0, 10), .parry, item);
				
				camera_shake_at_pos(0.4, item.pos, 200, 100);
				
				play_sound("craft", en.pos);
			}
		}
	}
}

workbench_ux :: (en: *Entity)
{
	// randy: NOTE, this should probably be an app-level interaction instead of a per-entity thang
	// good enuf tho!
	
	we_are_active_workbench := en.id == app.active_workbench.entity_id;
	en.active_alpha_target = ifx we_are_active_workbench then 1.0 else 0.0;
	
	// auto yeet when we get far enough away
	if we_are_active_workbench && abs(en.pos.x - get_player().pos.x) > 50
	{
		en.active_alpha_target = 0.0;
		app.active_workbench = .{};
	}
	// yeet on esc
	if we_are_active_workbench && key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		en.active_alpha_target = 0.0;
		app.active_workbench = .{};
	}
	
	// early out
	if en.active_alpha_target == 0.0 && en.active_alpha == 0.0 then return;
	
	animate_to_target(*en.active_alpha, en.active_alpha_target, delta_t());
	
	is_enabled := en.active_alpha_target == 1.0;
	alpha := en.active_alpha;
	
	if alpha != 0.0
	{
		before_slot := en.crafting_slot_index;
		defer
		{
			if before_slot != en.crafting_slot_index
			{
				play_sound_global("click");
			}
		}
		
		// scroll up n down
		if is_enabled
		{
			if app.frame.wheel_delta < 0
			{
				app.frame.wheel_delta = 0;
				en.crafting_slot_index += 1;
			}
			else if app.frame.wheel_delta > 0
			{
				app.frame.wheel_delta = 0;
				en.crafting_slot_index -= 1;
			}
		}
		
		// put all available crafting recipes in an array
		crafting_recipes : [..]*ArcResource;
		crafting_recipes.allocator = temp;
		for g_world.unlocked_recipes
		{
			res := get_resource(xx it_index);
			if has_prop(res.props, .workbench_recipe) then array_add(*crafting_recipes, res);
		}
		
		// fix up index to be in bounds
		en.crafting_slot_index = clamp(en.crafting_slot_index, 0, crafting_recipes.count-1);
		
		active_slot := en.crafting_slot_index;
		pos := world_pos_to_screen(en.pos + xy(0, 30));
		
		push_disable_signal(!is_enabled);
		push_opacity(alpha);
		
		slot_size := em(UI_SLOT_SIZE);
		margin := em(UI_MARGIN);
		slot_icon_padding := em(UI_SLOT_ICON_PADDING);
		slot_spacing := em(UI_SLOT_SPACING);
		slot_bg_col := COL_UI_BG;
		slot_border_col := GRAY;
		
		// parent box
		set_next_floating_x(pos.x);
		set_next_floating_y(pos.y);
		set_next_pref_size(size_by_children(1));
		set_next_child_layout_axis(.Y);
		set_next_bg_col(xyzw(0, 0, 0, 0.5));
		set_next_rect_pivot_x(.center);
		set_next_rect_pivot_y(.bottom);
		flags :BoxFlags= .floating | .clickable;
		// flags |= .draw_bg | .draw_border;
		parent_box := make_box(flags, tprint("%_workbench_ui", en.id));
		{
			push_parent(parent_box);
			
			push_pref_width(slot_size);
			push_pref_height(slot_size);
			
			if crafting_recipes.count > 0
			{
				slot_radius_count := 3;
				active_res := crafting_recipes[active_slot];
				
				set_next_pref_width(pct_parent(1, 0));
				set_next_pref_height(size_by_children(1));
				// set_next_flags(.debug_draw);
				{
					auto_row();
					padding(pct_parent(1, 0));
					
					is_unlocked := g_world.unlocked_recipes[active_res.id];
					if is_unlocked && active_res.recipe.count > 0
					{
						for recipe_it : active_res.recipe
						{
							// grab le total item count
							storage_slots := get_player_storage_slots();
							total_item_count : int;
							for slot : storage_slots
							{
								slot_en := entity_from_handle(slot);
								if is_valid(slot_en) && slot_en.item_id == recipe_it.id
								{
									total_item_count += slot_en.item_count;
								}
							}
							
							// UI
							set_next_pref_height(size_by_children(1));
							set_next_pref_width(slot_size);
							set_next_flags(top_flags() | .draw_bg);
							{
								auto_column();
								
								box, icon := ui_item_icon(tprint("crafting_slot_%_material_%_%", active_slot, it_index, en.id), recipe_it.id, 0, slot_size, em(UI_SLOT_ICON_PADDING * 1.5));
								sig := signal_from_box(box);
								if sig.hovering
								{
									set_next_rect_pivot_y(.bottom);
									push_tooltip();
									item_tooltip(recipe_it.id);
								}
								
								set_next_font_size(font_size_pct(0.8));
								set_next_pref_height(text_dim(1));
								set_next_pref_width(pct_parent(1));
								set_next_text_justify_x(.center);
								lbl := label("%/%###", total_item_count, recipe_it.amount);
								
								// error flash
								if app.last_frame.do_crafting_error_flash
								{
									is_missing := total_item_count < recipe_it.amount;
									if is_missing then icon.target = 1.0;
								}
								if animate_to_target(*icon.value, icon.target, delta_t(), rate=40.0) && icon.target == 1.0 then icon.target = 0;
								if icon.value != 0
								{
									icon.render_adjust_trs.scale = xy(1.0 + icon.value * 0.2);
									icon.multiply_col = lerp(WHITE, RED, icon.value);
									lbl.render_adjust_trs.scale = xy(1.0 + icon.value * 0.2);
									lbl.multiply_col = lerp(WHITE, RED, icon.value);
								}
							}
						}
					}
				}
				
				// recipes row
				set_next_pref_width(size_by_children(1));
				set_next_pref_height(slot_size);
				{
					auto_row();
					
					for active_slot-slot_radius_count..active_slot+slot_radius_count
					{
						we_are_active_slot := it == active_slot;
						
						if it < 0 || it > crafting_recipes.count-1
						{
							make_box(0, ""); // dummy box to keep layout fixed
						}
						else
						{
							// we're a crafting recipe!
							recipe_res := crafting_recipes[it];
							is_unlocked := g_world.unlocked_recipes[recipe_res.id];
							
							flags := BoxFlags.draw_bg;
							if we_are_active_slot then flags |= .draw_border;
							push_parent(make_box(flags, ""));
							box, icon_box := ui_item_icon(tprint("crafting_slot_%_%", it, en.id), recipe_res.id, 0, slot_size, slot_icon_padding);
							if !is_unlocked
							{
								icon_box.colour_override = GRAY;
								icon_box.colour_override_amount = 1.0;
							}
							else
							{
								icon_box.colour_override_amount = 0.0;
							}
							sig := signal_from_box(box);
							if sig.pressed && en.crafting_item_id == 0
							{
								en.crafting_slot_index = it;
								
								if we_are_active_slot && is_unlocked
								{
									can_craft := can_craft_recipe(recipe_res);
									if can_craft
									{
										#if !IGNORE_MATERIAL_COST then take_recipe_items(recipe_res);
										app.active_workbench = .{};
										en.crafting_item_id = recipe_res.id;
										en.crafting_timer = recipe_res.craft_time;
										
										play_sound_global("item_click");
									}
									else
									{
										app.frame.do_crafting_error_flash = true;
									}
								}
							}
							if sig.hovering
							{
								push_tooltip();
								if is_unlocked
								{
									item_tooltip(recipe_res.id);
									
									if we_are_active_slot
									{
										set_next_pref_size(size_by_children(1));
										auto_row();
										{
											icon(.left_click_icon, "", em(1));
											
											set_next_pref_width(text_dim(1));
											set_next_pref_height(text_dim(1));
											label("craft");
										}
									}
								}
								else
								{
									label("???###");
								}
							}
						}
					}
				}
			}
		}
	}
}

can_craft_recipe :: (recipe_res: *ArcResource) -> bool
{
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
			// array_add(*missing_items, recipe_item.id);
		}
	}
	#if IGNORE_MATERIAL_COST then has_enough_for_recipe = true;
	return has_enough_for_recipe;
}

take_recipe_items :: (recipe_res: *ArcResource)
{
	storage_slots := get_player_storage_slots();
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
		assert(remaining == 0, "There's not enough, did you screen that we had enough?");
	}
}

attempt_craft_item :: (recipe_res: *ArcResource) -> has_enough_error:bool
{
	assert(is_valid(recipe_res), "Invalid recipe resource");
	storage_slots := get_player_storage_slots();
	
	has_enough_for_recipe:= can_craft_recipe(recipe_res);
	
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
		take_recipe_items(recipe_res);
		
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
	
	return !has_enough_for_recipe;
}

get_back_wall_grid_sequence :: () -> int
{
	back_wall_sequence_len := -1;

	structures := get_world_structures();

	for structures if it != null && has_prop(it.props, .back_wall)
	{
		tile_pos := world_to_tile_pos(it.pos.x);
		if tile_pos <= back_wall_sequence_len + 3
		{
			back_wall_sequence_len = tile_pos;
		}
	}

	return back_wall_sequence_len;
}

is_inside_enclosed_base :: (en: *Entity) -> bool
{
	is_base_enclosed := false;
	defense_wall := get_nil_entity();
	back_wall_sequence_len := 0;

	structures := get_world_structures();

	for structures if it != null
	{
		if has_prop(it.props, .back_wall)
		{
			//Back wall continues the sequence
			if world_to_tile_pos(it.pos.x) <= back_wall_sequence_len + 3
			{
				back_wall_sequence_len = world_to_tile_pos(it.pos.x);
			}
		}
		else if has_prop(it.props, .defense_wall)
		{
			//Defense wall at the end of the sequence
			if world_to_tile_pos(it.pos.x) <= back_wall_sequence_len + 1
			{
				is_base_enclosed = true;
				defense_wall = it;
			}
		}
	}

	if !is_base_enclosed then return false;

	return en.pos.x < defense_wall.pos.x;
}

// Serialisation to MDF format

value_to_string :: (val: *void, type_i: *Type_Info) -> string
{
	ret_str : string ="";
	if type_i.type ==
	{
			case .INTEGER;
				type_i_int: *Type_Info_Integer = xx type_i;

				bit_size := type_i_int.runtime_size * 8;

				if type_i_int.signed
				{
					if bit_size <= 8
					{
						val_int: *s8 = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
					else if bit_size <= 16
					{
						val_int: *s16 = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
					else if bit_size <= 32
					{
						val_int: *s32 = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
					else if bit_size <= 64
					{
						val_int: *s64 = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
					else //Life is like a box of chocolates
					{
						val_int: *int = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
				}
				else
				{
					if bit_size <= 8
					{
						val_int: *u8 = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
					else if bit_size <= 16
					{
						val_int: *u16 = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
					else if bit_size <= 32
					{
						val_int: *u32 = val;
						ret_str = tprint("\"%\"", <<val_int);
						return ret_str;
					}
					else if bit_size <= 64
					{
						val_int: *u64 = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
					
					else //never know what you're gonna get
					{
						val_int: *int = val;
						ret_str = tprint("\"%\"", <<val_int);
					}
				}
			case .FLOAT;
				bit_size := type_i.runtime_size * 8;
				if bit_size == 64
				{
					val_float: *float64 = val;
					ret_str = tprint("\"%\"", <<val_float);
				}
				else
				{
					val_float: *float32 = val;
					ret_str = tprint("\"%\"", <<val_float);
				}
			case .BOOL;
				val_bool: *bool = val;
				ret_str = tprint("\"%\"", <<val_bool);
			case .STRING;
				val_string: *string = val;
				if <<val_string == "\"\"" then ret_str = "\"\"";
				else				
				ret_str = tprint("\"%\"", <<val_string);
			case .ENUM;
				type_i_enum: *Type_Info_Enum = xx type_i;
				type_i_int: *Type_Info_Integer = type_i_enum.internal_type;
				return value_to_string(val, type_i_int);
			case .STRUCT;
				val_struct: *Type_Info_Struct = cast(*Type_Info_Struct) type_i;
				ret_str = struct_to_string(val, val_struct);
			case .ARRAY;
				info_array: *Type_Info_Array = cast(*Type_Info_Array) type_i;
				ret_str = array_to_string(val, info_array);
			case;
				//print("Did not Serialise: % : %\n", type_i.type, <<(cast(*u64)val));
	}

	return ret_str;
}


array_to_string :: (val_ptr: *void, ti_array: *Type_Info_Array) -> string
{
	ret_str : string = "[";
	array_count, array_data := get_array_count_and_data(val_ptr, ti_array);
	element_size := ti_array.element_type.runtime_size;

	for 0..array_count  -1
	{
		val := array_data + it * element_size;

		val_str := value_to_string(val, ti_array.element_type);
		ret_str = tprint("%\n%", ret_str, val_str);
	}
	ret_str = tprint("%\n]", ret_str);
	return ret_str;
}

struct_to_string :: (val_ptr: *void, ti_struct: *Type_Info_Struct) -> string
{
	ret_str : string = tprint("{");
	for ti_struct.members
	{
		//Vectors have this. It's the same data, but presented as an array
		if it.name == "component" ||
			it.name == "Kind" ||
			it.name == "Frame" || //HACK(fhomolka): Probably retrieve the name differently 
			                      // randy: we could use @ignore tags on certain members?
			it.name == "state_buffer" ||
			it.name == "xy" ||
			it.name == "yz" ||
			it.name == "zw" ||
			it.name == "xyz" ||
			it.name == "yzw" ||
			it.name == "min" ||
			it.name == "max"
		{continue;} 

		val := val_ptr + it.offset_in_bytes;

		ret_str = tprint("%\n%", ret_str, it.name);
		val_str := value_to_string(val, it.type);
		ret_str = tprint("% = %", ret_str, val_str);
	}

	ret_str = tprint("%\n}", ret_str);

	return ret_str;
}

entity_to_string :: (ent: *Entity) -> string
{
	info := type_info(Entity);

	return struct_to_string(ent, info);
}

value_from_element :: (elem: *Element, field_ptr: *void, type_i: *Type_Info)
{
	if type_i.type ==
		{
			case .INTEGER;
			{
				type_i_int := cast(*Type_Info_Integer) type_i;
				bit_size := type_i_int.runtime_size * 8;

				if type_i_int.signed
				{
					if bit_size <= 8
					{
						field_int: *s8 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else if bit_size <= 16
					{
						field_int: *s16 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else if bit_size <= 32
					{
						field_int: *s32 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else if bit_size <= 64
					{
						field_int: *s64 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else //Life is like a box of chocolates
					{
						field_int: *int = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
				}
				else
				{
					if bit_size <= 8
					{
						field_int: *u8 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else if bit_size <= 16
					{
						field_int: *u16 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else if bit_size <= 32
					{
						field_int: *u32 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else if bit_size <= 64
					{
						field_int: *u64 = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
					else //never know what you're gonna get
					{
						field_int: *int = field_ptr;
						<<field_int = xx parse_int(*elem.val);
					}
				}
			}
			case .FLOAT;
			{
				bit_size := type_i.runtime_size * 8;
				if bit_size == 64
				{
					float_field: *float64 = field_ptr;
					<<float_field = xx parse_float(*elem.val);
				}
				else
				{
					float_field: *float32 = field_ptr;
					<<float_field = xx parse_float(*elem.val);
				}
			}
			case .BOOL;
			{
				bool_field: *bool = field_ptr;
				<<bool_field = ifx elem.val == "true" then true else false;
			}
			case .STRING;
			{
				field_string: *string = field_ptr;
				<<field_string = elem.val;
			}
			case .ENUM;
			{
				type_i_enum: *Type_Info_Enum = xx type_i;
				type_i_int: *Type_Info_Integer = type_i_enum.internal_type;
				value_from_element(elem, field_ptr, type_i_int);
			}
			case .STRUCT;
			{
				ti_struct: *Type_Info_Struct = xx type_i;
				struct_from_chunk(elem, field_ptr, ti_struct);
			}
			case .ARRAY;	
			{
				ti_array: *Type_Info_Array= xx type_i;
				array_from_mdf_arr(elem, field_ptr, ti_array);
			}
		}
}

array_from_mdf_arr :: (arr: *Element, field_ptr: *void, ti_array: *Type_Info_Array)
{
	array_count, array_data := get_array_count_and_data(field_ptr, ti_array);
	element_size := ti_array.element_type.runtime_size;

	for * elem : arr.arr_props
	{
		val_ptr := array_data + it_index * element_size;
		value_from_element(elem, val_ptr, ti_array.element_type);
	}
}

find_member_by_name :: (array: []Type_Info_Struct_Member, item: string) -> bool, s64 
	{
    	for array if it.name == item return true, it_index;
    	print("did not find field: %\n", item);
    	return false, -1;
	}

struct_from_chunk :: (chunk: *Element, dst: *void, ti_struct: *Type_Info_Struct)
{
	for elem, key : chunk.chunk_props
	{
		key_found, idx := find_member_by_name(ti_struct.members, key);
		if !key_found continue;

		member := ti_struct.members[idx];
		field_ptr := dst + member.offset_in_bytes;	
		

		value_from_element(*elem, field_ptr, member.type);
	}
}

fill_entity_from_chunk :: (en: *Entity, chunk: *Element)
{
	info := type_info(Entity);
	struct_from_chunk(chunk, en, info);
}

overlap_damage_update :: ()
{
	player := get_player();
	
	// test for overlap on enemies and yeet
	for * en: g_world.entities if is_valid(en) && has_prop(en.props, .damage_when_overlap)
	{
		if player.damage_event.amount == 0 && range_overlaps(get_entity_width_range(en), get_entity_width_range(player))
		{
			// randy: TODO - need to make deez variables instead of just gobby
			attempt_damage_entity(player, 5, en, make_props(EntityProps.gobby, .monster, .dmg_touch));
			break;
		}
	}
}