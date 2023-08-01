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
Input :: #import "Input";

#import "MetaDesk";
#load "../metadesk_helpers.jai";

#load "resource.jai";

#load "../imui.jai";

#load "arena.jai";
#load "config.jai";

#import,file "../recycle.jai";
#load "sound.jai";
#load "render.jai";
#load "../cereal.jai";
#load "linked.jai";

#import "Spall";
#import,file "../profile.jai";

CraftProgress :: enum
{
	none;
	hover;
	mid;
	end;
}

Camera2 :: struct
{
	position: Vector2;
	zoom: float = DEFAULT_ZOOM;
	target_zoom: float = DEFAULT_ZOOM;
}

AppState :: enum
{
	nil;
	splash;
	main_menu;
	settings;
	world;
}

set_app_state :: (state: AppState)
{
	if st.app_state != state
	{
		st.exiting_app_state = st.app_state;
		st.entering_app_state = state;
		st.app_state = state;
	}
}

is_state_entry :: (state: AppState) -> bool
{
	if st.entering_app_state == state
	{
		st.entering_app_state = .nil;
		return true;
	}
	return false;
}

is_state_exit :: (state: AppState) -> bool
{
	if st.exiting_app_state == state
	{
		st.exiting_app_state = .nil;
		return true;
	}
	return false;
}

DebugConfig :: struct
{
	disable_cycle_luts: bool = false;
	ui_font_size: int = 24;
	ui_height_scale: float = 0.7;
	
	max_monster_count: int = 10;
	
	luts : []KeyFrame = .[
	.{"morning_lut",  					0.125*0.5	},
	.{"day_lut", 									 0.125*2	},
	.{"evening_lut", 						0.125*3 },
	.{"dusk_lut", 									0.125*3.5 },
	.{"early_night_lut", 		0.125*5 },
	.{"mid_night_lut", 				0.125*6 },
	.{"late_night_lut", 			0.125*7 },
	.{"dawn_lut", 									0.125*8 },
];
}

Game :: struct
{
	app_state: AppState;
	using resource_state: ResourceState;
	entering_app_state: AppState;
	exiting_app_state: AppState;
	main_menu_alpha: float;
	main_menu_alpha_t: float;
	world_alpha: float;
	world_alpha_t: float;
	camera: Camera2;
	
	window: Window_Type;
	window_w : s32 = WINDOW_X;
	window_h: s32 = WINDOW_Y;
	saved_window: Saved_Window_Info;
	is_fullscreen := false;
	mouse_pos: Vector2;
	frame_count: u64;
	refresh_rate: float;

	// gotta have the derivatives because don't wanna call windows every frame...
	_cursor_confied: bool = false; 
	_cursor_showing: bool = true;
	// these are what you set to determine the state
	confine_cursor: bool = false;
	show_cursor: bool = true;
	
	key_down: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool; // TODO - how can I get the max size of the enum?
	lines: [1024] Line;
	
	world_gen: WorldGenParams;
	using world: World;
	ui: UI_State;
	
	// preferences?
	debug_config: DebugConfig;
	expander_world_gen: bool;
	expander_dumpy: bool = true;
	
	// :particle system
	particles: [128]Particle;
	particle_cursor: int;
}
game_state: Game;
st := *game_state;

WorldGenParams :: struct
{
	seed: u64;
	flint_interval := 20.0;
	flint_threshold := 0.7;
	persistance := 0.5;
	octaves := 4;
	freq := 1.0;
	random_offset := 10.0;
}

GameFrame :: struct
{
	key_pressed: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
	key_released: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
	wheel_delta: s32;
	mouse_delta: Vector2;
}
gsf: GameFrame;

World :: struct
{
	initialized: bool;
	simulating: bool = false;
	time_elapsed: float64;
	entity_id_gen: u64;
	entities: [ENTITY_MAX]Entity;
	entity_count: u32;
	root_entity: *Entity;
	current_background: *Resource;
	day_cycle: float = CYCLE_START_TIME;
	
	player: *Entity;
	
	frame: Frame;
	Frame :: struct
	{
		events: [..]Event;
	}
	
	//
	// PLAYER state stuff
	//
	disable_player_input: bool;
	
	selected_structure: ItemID;
	placing_blueprint: EntityHandle;
	
	unlocked_recipes: [MAX_ITEM_COUNT]ItemID;
	
	hotbar_slots: [9]EntityHandle;
	stored_items: [128]EntityHandle;
	hot_slot: int;
	max_character_weight: int = 5;
	
	// interaction
	hovered_interactable: EntityHandle;
	
	// interface stuff
	interface_state: InterfaceState;
	entering_interface_state: InterfaceState;
	exiting_interface_state: InterfaceState;
	
	death_screen_alpha: float;
	death_screen_alpha_t: float;
	
	pause_menu_alpha: float;
	pause_menu_alpha_t: float;
	
	inventory_alpha: float;
	inventory_alpha_t: float;
	
	mouse_held_item: EntityHandle;
	
	// survival book
	PAGE_COUNT :: 3;
	sb_page: int = 0;
	sb_page_opacity: [PAGE_COUNT]float;
	
	// crafting stuff
	craft_items: LinkedList(EntityHandle, frame_allocator);
	craft_progress: CraftProgress;
	tooltip_alpha: float;
	craft_centre: Vector2;
	craft_cursor_pos: Vector2;
	craft_recipes_alpha: [8]float;  
	craft_error_flash: float;
	craft_scuffed_zero_all: bool;
	craft_end_alpha: float = 1.0;
}

get_max_weight :: () -> int
{
	return st.max_character_weight;
}

get_hotbar_slot_count :: () -> int
{
	// loop through all equipment and get the count
	return BASE_HOTBAR_COUNT;
}

set_interface_state :: (state: InterfaceState)
{
	if st.interface_state != state
	{
		st.exiting_interface_state = st.interface_state;
		st.entering_interface_state = state;
		st.interface_state = state;
	}
}

is_state_entry :: (state: InterfaceState) -> bool
{
	if st.entering_interface_state == state
	{
		st.entering_interface_state = .nil;
		return true;
	}
	return false;
}

is_state_exit :: (state: InterfaceState) -> bool
{
	if st.exiting_interface_state == state
	{
		st.exiting_interface_state = .nil;
		return true;
	}
	return false;
}

InterfaceState :: enum
{
	nil;
	pause_menu;
	inventory;
	build_menu;
	build_mode;
	crafting;
	survival_book;
	death_screen;
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
	array_add(*st.world.frame.events, event);
	if LOG_VERBOSE then log("new event %", event);
}

delta_t: float = 1.0 / 60.0;
last_frame_time: float64;

main :: ()
{
	// :init
	#if OS == .WINDOWS
	{
		Windows :: #import "Windows";
		Windows.SetProcessDPIAware();
		Windows.timeBeginPeriod(1);
		
		// this is kinda sketch lol, ideally I'd just like to tack it into the Windows namespace, but idk
		// how to do that without modifying Windows.jai
		#load "../../modules/windows_extra.jai";
		FreeConsole();
	}
	st.window = create_window(st.window_w, st.window_h, app_title, background_color_rgb=CLEAR_COL.xyz.component);
	
	nil_resource = *game_state.resources[0];
	context.allocator = permanent_allocator;
	memory_init();
	render_init();
	init_resources();
	sound_init();
	ui_init(*st.ui);
		
	set_app_state(START_APP_STATE);
	
	st.refresh_rate = get_refresh_rate();
	
	quit := false;
	while !quit
	{
		context.allocator = frame_allocator;
		
		{
			current_time:= get_time();
			if (last_frame_time)
			{
				if !VSYNC
				{
					delta_t = cast(float) (current_time - last_frame_time);
				}
			}
			last_frame_time = current_time;
		}
		
		if VSYNC then delta_t = 1.0/st.refresh_rate;
		
		swap_n_reset_frame_arenas();
		
		nil_entity = .{}; // clear out the nil entity
		
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
				if (it.window == st.window)
				{
					st.window_w = it.width;
					st.window_h = it.height;
				}
			}

			// EVENTS
			for Input.events_this_frame
			{
				if it.type ==
				{
					case .QUIT;
					quit = true;

					// update keypress events
					case .KEYBOARD;
					if it.key_pressed
					{
						if (!st.key_down[it.key_code])
						{
							gsf.key_pressed[it.key_code] = true;
						}
						st.key_down[it.key_code] = true;
					}
					else
					{
						if (st.key_down[it.key_code])
						{
							gsf.key_released[it.key_code] = true;
						}
						st.key_down[it.key_code] = false;
					}

					case .MOUSE_WHEEL;
					gsf.wheel_delta += it.wheel_delta / it.typical_wheel_delta;
				}
			}
		}
		
		// CURSOR CLIPPING & FOCUS STUFF
		{
			window_rect: RECT;
			GetWindowRect(st.window, *window_rect);
			
			// play window is basically the client rect, just adusted to always have the correct position in screen coordinates
			play_window: RECT;
			GetClientRect(st.window, *play_window);
			min: POINT = .{play_window.left, play_window.bottom};
			max: POINT = .{play_window.right, play_window.top};
			ClientToScreen(st.window, *min);
			ClientToScreen(st.window, *max);
			play_window.left = min.x;
			play_window.right = max.x;
			play_window.top = max.y;
			play_window.bottom = min.y;
			
			cursor_pos: POINT;
			GetCursorPos(*cursor_pos);
			
			hovering_playspace := PtInRect(*play_window, cursor_pos);
			is_window_focused := GetFocus() == st.window;
			
			// This whole thing is a big spiderweb of state since win32 is fun
			
			// enter focus state
			if is_window_focused
				&& hovering_playspace
				&& key_pressed(.MOUSE_BUTTON_LEFT)
			{
				st.confine_cursor = true;
			}
			
			if !is_window_focused
			{
				st.confine_cursor = false;
			}
			
			// match focus to our derivative
			if st._cursor_confied
				&& !st.confine_cursor
			{
				st._cursor_confied = false;
				ClipCursor(null);
			}
			if !st._cursor_confied
				&& st.confine_cursor
			{
				st._cursor_confied = true;
				ClipCursor(*play_window);
			}
			
			// match the actual cursor state to our derivative
			if st._cursor_showing
				&& !st.show_cursor
			{
				ShowCursor(0); // we need the intermediate because this can't be called every frame...
				st._cursor_showing = false;
			}
			if !st._cursor_showing
				&& st.show_cursor
			{
				ShowCursor(1);
				st._cursor_showing = true;
			}
			
			// lock the clip cursor accordingly
			if st.confine_cursor
			{
				st.show_cursor = false;
			}
			else
			{
				st.show_cursor = true;
			}
		}
		
		// mouse pos
		{
			x, y := get_mouse_pointer_position(st.window, true); 
			st.mouse_pos.x = xx x;
			st.mouse_pos.y = xx y;
			
			gsf.mouse_delta.x = xx Input.mouse_delta_x;
			gsf.mouse_delta.y = xx -Input.mouse_delta_y;
		}
		
		// fullscren :)
		if gsf.key_pressed[Input.Key_Code.F11]
		{
			if toggle_fullscreen(st.window, !st.is_fullscreen, *st.saved_window) then st.is_fullscreen = !st.is_fullscreen;
		}

		// play_sound("ligma");
		
		// debug stuff
		k_key_debug := st.key_down[#char "K"];

		if gsf.key_pressed[#char "L"] then play_sound("ligma");

		fun_val += gsf.mouse_delta.x / 100;

		// reset world
		if st.app_state == .world && gsf.key_pressed[#char "R"]
			&& (st.interface_state == .death_screen || DEBUG_RESTART)
		{
			consume_key(#char "R");
			world_reset();
		}

		// pause / frame stepper
		if gsf.key_pressed[#char "`"]
		{
			st.simulating = !st.simulating;
		}
		single_frame_simulate:= false;
		if !st.simulating && st.key_down[#char "F"]
		{
			st.simulating = true;
			single_frame_simulate = true;
		}

		// :UI
		ui_start();
		push_fill_col(GRAY);
		push_text_col(WHITE);
		push_border_col(WHITE);
		push_font(FONT_SUB);
		push_font_size(st.debug_config.ui_font_size);
		push_text_edge_pad(10);
		push_pref_width(pct_parent(1.0, 0.0));
		push_pref_height(em(1.5));
		
		
		#if DEBUG
		{
			// :debug ui
			if key_pressed(#char "1") && key_down(.ALT) then show_debug_ui = !show_debug_ui;
			if show_debug_ui
			{
				st.show_cursor = true;
				
				push_fill_col(rbg_helper(56, 56, 56));
				push_pref_width(pct_parent(1, 0));

				set_next_pref_width(em(12));
				set_next_pref_height(size_by_children(1));
				set_next_fill_col(xyzw(0, 0, 0, 0.9));
				box := make_box(BoxFlags.draw_fill | .draw_border, "");
				push_parent(box);

				set_next_text_justify_x(.center);
				label("- DEBUG -");
				
				st.expander_dumpy = ui_expander(st.expander_dumpy, "Debug Config");
				if st.expander_dumpy
				{
					set_next_pref_height(size_by_children(1));
					auto_row();
					spacer(em(1.5));
					set_next_pref_height(size_by_children(1));
					set_next_pref_width(pct_parent(1, 0));
					auto_column();
					
					st.world.day_cycle = slider_float(st.world.day_cycle, 0, CYCLE_LENGTH, "day/night cycle");
					
					ui_edit_struct(*st.debug_config);
				}
				
				st.expander_world_gen = ui_expander(st.expander_world_gen, "World Gen");
				if st.expander_world_gen
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
					st.world_gen.flint_interval, sig = slider_float(st.world_gen.flint_interval, 5.0, 100.0, "flint_interval");
					if sig.dragging then changed = true;
					st.world_gen.flint_threshold, sig = slider_float(st.world_gen.flint_threshold, 0.0, 1.0, "flint_thres");
					if sig.dragging then changed = true;
					
					st.world_gen.persistance, sig = slider_float(st.world_gen.persistance, 0, 1, "persistance");
					if sig.dragging then changed = true;
					
					st.world_gen.octaves, sig = slider_int(st.world_gen.octaves, 1, 16, "octaves");
					if sig.dragging then changed = true;
					
					st.world_gen.freq, sig = slider_float(st.world_gen.freq, 0, 2, "freq");
					if sig.dragging then changed = true;
					
					st.world_gen.random_offset, sig = slider_float(st.world_gen.random_offset, 0, 20, "random_offset");
					if sig.dragging then changed = true;
					
					if changed then world_reset();
				}
			}
		}
		
		// pause the game
		if st.app_state == .world && key_pressed(.ESCAPE) && st.interface_state == .nil
		{
			consume_key(.ESCAPE);
			set_interface_state(.pause_menu);
		}
	
		// :world target alpha
		if is_state_entry(.world)
		{
			st.world_alpha_t = 1.0;
			if !st.world.initialized then world_init(*st.world); 
			st.confine_cursor = true;
		}
		if is_state_exit(.world)
		{
			st.world_alpha_t = 0.0;
		}
		reached := animate_to_target(*st.world_alpha, st.world_alpha_t, 15);
		if reached && st.world_alpha_t == 0.0 && st.world.initialized
		{
			// "unload"
			st.world = .{};
		}
		
		render_begin();
		
		main_menu_ui();
		pause_ui();
		
		// :update
		if st.simulating
		{
			st.world.time_elapsed += delta_t;
			day_cycle_update();
			
			// monster spawning
			if is_night_time()
				&& tick_on_app_frequency(0.2)
			{
				if get_entity_count_with_prop(.monster) < st.debug_config.max_monster_count
					&& pct_chance(0.5)
				{
					en := create_gobby();
					en.rel_pos.x = st.player.rel_pos.x + 300.0 * random_sign() + random_get_within_range(-100, 100);
				}
			}
			
			death_screen_ui();
			display_notifications();
			building_ui();
			inventory_ui();
			survival_book_ui();
			
			build_mode(); // is part of user interaction?
			in_game_user_interaction();
			
			animate_sprites();
			player_update();
			enemy_update();
			physics_update();
			tree_update();
			blueprint_update();
			recieve_damage();
			update_particle_system();
			
			// unlock recipe of picked up items
			/*
			for event: st.world.frame.events if event.kind == .pickup
			{
				for * bp, bp_index: st.world.dynamic_blueprints if !bp.unlocked
				{
					if bp_index == 0 then continue;
					static_bp := get_static_blueprint(xx bp_index);
					
					all_ingredients_known := true;
					for ing, ing_index: static_bp.recipe
					{
						if ing.item == .nil then break;
						
						// add to the known item list
						if ing.item == event.item
						{
							bp.known_ingredients[ing_index] = true;
						}
						
						all_ingredients_known = all_ingredients_known && bp.known_ingredients[ing_index];
					}
					
					if all_ingredients_known
					{
						bp.unlocked = true;
						create_notification(tprint("Unlocked Crafting Recipe: %", static_bp.name));
					}
				}
			}
			*/
			
			// destroy entities that're marked
			for * st.entities if is_valid(it) && it.marked_for_destroy
			{
				entity_destroy_immediate(it);
			}

			st.camera.position = xy(0);
			st.camera.position.x = -st.player.rel_pos.x;
			st.camera.position += camera_offset;
			//st.camera.target_zoom = window_h / scene_height * ifx k_key_debug then 1.4 else 1.0;

			#if TOOLING
			{
				if (gsf.wheel_delta) && key_down(.ALT)
				{
					st.camera.target_zoom += gsf.wheel_delta / 5.0;
					st.camera.target_zoom = clamp(st.camera.target_zoom, 1, 20.0);
				}
			}

			//log("%\n", camera_diff);

			animate_to_target(*st.camera.zoom, st.camera.target_zoom);
		}
		
		// :render the world
		// todo - push this global alpha onto the renderer
		if st.world_alpha != 0.0
		{
			camera_diff := st.camera.position - camera_offset; // for parallax
			
			// background
			#if RENDER_BACKGROUND
			{
				bg_parallax_offset := camera_diff * -1.0;
				
				bg_size := sprite_size(st.world.current_background.id);
				pixel_zoom := st.window_w / bg_size.x;
				
				bg_rect := make_range(0.0, 0.0, xx st.window_w, xx st.window_h, pivot=.center_center);
				push_quad(bg_rect, col=rbg_helper(49, 161, 227), z_layer=-500, flags=.SKIP_CAMERA_TRANSFORM);
				
				push_quad(st.world.current_background, z_layer=-200, trs=make_transform(bg_parallax_offset + xy(0, 160)));
				
				cycle_alpha := get_time_cycle_alpha();
				phase_offset := 90;
				sun_rot := phase_offset + 180.0 + cycle_alpha*360.0;
				moon_rot := phase_offset + cycle_alpha*360.0;
				
				push_quad(get_sprite("sun"), z_layer=-180, trs=make_transform(bg_parallax_offset + xy(0, 200), rotate=sun_rot, pivot=xy(0, 300)));
				push_quad(get_sprite("moon"), z_layer=-180, trs=make_transform(bg_parallax_offset + xy(0, 200), rotate=moon_rot, pivot=xy(0, 300)));
			}
		
			// TODO - @refactor for the love of god
			// generic entity render
			for * st.entities if is_valid(it) && WORLD_RENDER && (has_prop(it.props, .render_rect) || has_prop(it.props, .render_sprite))
			{
				// animate to target trs
				if it.render_offset_animate && it.render_offset_target != it.render_offset
				{
					animate_to_target(*it.render_offset.translate, it.render_offset_target.translate, 40);
					animate_to_target(*it.render_offset.pivot_offset, it.render_offset_target.pivot_offset, 40);
				
					// correct current rotation to take the shortest path to target
					a := it.render_offset.rotate;
					b := it.render_offset_target.rotate;
					if abs(b-a) > 180.0
					{
						it.render_offset.rotate = it.render_offset.rotate + 360.0 * -sign(a);
					}
					animate_to_target(*it.render_offset.rotate, it.render_offset_target.rotate, 40);
				} 
				
				if !it.visible then continue;
				
				// todo - make this a whole ass TRS instead of just pos
				absolute_pos := get_absolute_position(it);
				
				render_trs: Transform2;
				render_trs.translate = absolute_pos;
				
				// parallax the render transform
				if it.parallax.x != 0.0
				{
					render_trs.translate.x -= camera_diff.x * it.parallax.x;
				}
				if it.parallax.y != 0.0
				{
				}
				
				// flip the local offset
				local_trs := it.render_offset;
				ifx it.x_dir == -1 then local_trs.translate.x *= -1;

				if has_prop(it.props, .render_rect)
				{
					rect := it.collision_rect;
					
					tex: *Texture = get_texture(WHITE_TEX);
					uv_rect := DEFAULT_UV;
					if it.sprite_id
					{
						sprite := get_sprite(it.sprite_id);
						tex = texture_from_sprite(sprite);
						
						// wrap texture across the whole rect
						rect_size := range_size(rect);
						uv_rect = .{};
						uv_rect.min.x = rect_size.x / tex.width;
						uv_rect.min.y = rect_size.y / tex.height;
					}
					
					push_quad(rect, it.col, tex=tex, uv_rect=uv_rect, z_layer=it.z_layer, trs=merge_transform(render_trs, local_trs));
				}
				else if has_prop(it.props, .render_sprite)
				{
					//assert(it.sprite_id != 0, "No sprite ID set for rendering");
					
					sprite := get_sprite(it.sprite_id);
					texture := texture_from_sprite(sprite);

					uv_rect := sprite.rect;
					uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * it.animation_frame, 0.0));
					uv_rect.min.x /= texture.width;
					uv_rect.min.y /= texture.height;
					uv_rect.max.x /= texture.width;
					uv_rect.max.y /= texture.height;
					flip_x := it.x_dir == -1;
					if it.flip_sprite then flip_x = !flip_x;
					
					// :sprite_transform
					local_trs.translate.x += it.x_dir * sprite.offset.x;
					local_trs.translate.y += sprite.offset.y;
					local_trs.pivot_offset += sprite.offset;
					
					// set render rect from sprite
					rect: Range2;
					rect.max = range_size(sprite.rect);
					if texture.name == "" then rect.max *= 4; // blow up the nil so we can see it
					rect = range_pivot(rect, .bottom_center);
					
					quad := push_quad(rect, it.col, uv_rect, texture, z_layer=it.z_layer, flip_x=flip_x, trs=merge_transform(render_trs, local_trs));
					quad.white_override = it.white_override;
				}
			}

			// HUD
			if st.player
			{
				// player health vignette thing
				alpha := 0.0;
				if st.player.health ==
				{
					case 0;
					#through;
					case 1;
					alpha = 1.0;

					case 2;
					alpha = 0.3;
				}
				//Simp.immediate_quad(st.window_w * -0.5, st.window_h * -0.5, st.window_w * 0.5, st.window_h * 0.5, rgba(1, 1, 1, alpha));
			}

			// scuffed line render
			for * line: st.lines if line.valid
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

					push_quad(rect, col = line.col, trs=line.transform);
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
			
		ui_finish_and_render();

		//push_text("balls", 100, FONT_MAIN);
		//push_quad(Range2.{-100, 0, 0, 50});

		render_end(get_view_matrix(), get_cardinal_projection());

		reset_temporary_storage();

		// clear game's frame state
		gsf = GameFrame.{};
		
		if st.simulating
		{
			// clear world frame state
			st.world.frame = World.Frame.{};
			
			// clear entity's frame state
			for * st.entities if is_valid(it)
			{
				it.last_frame = it.frame;
				it.frame = Entity.Frame.{};
			}
		}

		if single_frame_simulate
		{
			st.simulating = false;
		}

		st.frame_count += 1;
	}
	
	shutdown();
}

shutdown :: ()
{
	sound_shutdown();
}

//
// :WORLD
//

set_random_world_seed :: ()
{
	st.world_gen.seed = get_chaos_seed();
}

world_reset :: ()
{
	st.world = .{};
	world_init(*st.world);
}

world_init :: (world: *World)
{
	assert(!world.initialized, "World already initialized!");
	world.initialized = true;
	
	gen := st.world_gen;
	
	random_seed(gen.seed);
	
	push_allocator(world_allocator);
	world.root_entity = create_entity("root");
	world_bootstrap();
	world.simulating = true;
	
	//
	// :world gen
	//
	
	#if !DO_WORLD_GEN
	{
		return;
	}
	
	// NOTE - Keep this format light and art-centric!
	// the purpose of this file is to expose artistic design parameters to freddy. Not to be a general purpose
	// generator / definition of what's actually in the biomes. It'll probs be a lot better to just handle all the
	// entity-specific stuff in the code.
	md_root := md_parse_file("res/generate.mdesk").node;
	
	biome_node := md_find_node_with_string(md_root, "forest", true);
	ground_col := md_col_from_key(biome_node, "ground_color");
	world.current_background = get_sprite(md_string_from_key(biome_node, "background"));
	
	generators := md_find_all_nodes_with_tag(biome_node, "generator");
	for generators
	{
		parallax := md_vector2_from_key(it, "parallax");
		z_layer := md_float_from_key(it, "z_layer");
		layer_y_offset := md_float_from_key(it, "layer_y_offset");
		
		// grab generator data
		assets : [..]*Resource;
		assets_node := md_find_node_with_string(it, "assets", true);
		for assets_node.first_child
		{
			array_add(*assets, get_sprite(md_string(it.str)));
		}
		assert(assets.count > 0, "No assets found");
		interval := md_float_from_key(it, "interval");
		if interval == 0 then interval = range_size(assets[0].rect).x;
		variance := md_vector2_from_key(it, "variance");
		z_nudge := md_float_from_key(it, "z_nudge");
		y_offset := md_float_from_key(it, "y_offset");
		
		max_count := world_radius/xx interval + 6;
		for s: 0..1
		for 1..max_count
		{
			sign := ifx s == 0 then -1.0 else 1.0;
			index := it;
			if s == 0 then index = max_count-index;
			if s == 1 && index == max_count then continue;
			
			en := create_entity();
			add_props(*en.props, .render_sprite);
			en.parallax = parallax;
			en.z_layer = z_layer + z_nudge;
			entity_set_sprite(en, assets[cast(int)random_get_within_range(0, assets.count-1.0)]);
			
			en.flip_sprite = true;
			
			vx := random_get_within_range(-variance.x, variance.x);
			vy := random_get_within_range(-variance.y, variance.y);
			en.rel_pos.x = sign * (cast(float)index * interval + vx);
			en.rel_pos.y += vy + y_offset + layer_y_offset;
		}	
		
		solid_ground := create_entity();
		add_props(*solid_ground.props, .render_sprite, .render_rect);
		solid_ground.parallax = .{1, 1};
		solid_ground.collision_rect = make_range(xy(10000, 1000), .top_center, shifter=xy(0, -50));
		solid_ground.z_layer -= 0.5;
		solid_ground.col = ground_col;
	}
	
	// :RESOURCE GENERATION!
	point : float;
	
	// trees
	point = -cast(float)world_radius;
	root_index := 0;
	while point < xx world_radius
	{
		MIN_STEP := 100.0;
		point += random_get_within_range(MIN_STEP, MIN_STEP * 2.0);
		
		en := create_tree();
		en.rel_pos.x = point;
		
		if pct_chance(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.rel_pos.x = point + random_get_within_range(-50, -20);
		}
		
		if pct_chance(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.rel_pos.x = point + random_get_within_range(20, 40);
		}
	}
	
	// tall grass
	point = -cast(float)world_radius;
	root_index = 0;
	while point < xx world_radius
	{
		MIN_STEP := 100.0;
		point += random_get_within_range(MIN_STEP, MIN_STEP * 2.0);
		
		en := create_tall_grass(root_index);
		en.rel_pos.x = point + random_get_within_range(-50, -20);
	}
	
	// flint
	{
		// spawns flint at a fixed interval, then uses perlin noise to cut away at it
		size :: world_radius * 2.0;
		starting_point : float : -cast(float)world_radius;
		max_count : int = cast(int)(size / gen.flint_interval);
		
		perlin := generate_perlin_noise_buffer(max_count, gen.persistance, gen.octaves);
		
		for 0..max_count-1
		{
			noise := perlin[it];
			random_offset := random_get_within_range(-gen.random_offset, gen.random_offset);
			if noise < gen.flint_threshold then continue;
			
			en := create_world_item("flint");
			en.rel_pos.x = starting_point + it * gen.flint_interval + random_offset;
		}
	}
}

world_bootstrap :: ()
{
	// :map
	en: *Entity;
	
	// :player
	en = create_entity();
	add_props(*en.props, .rigid_body, .recieve_damage, .render_sprite, .override_death, .player);
	add_props(*en.recieve_damage_from, .monster);
	en.state = .idle;
	en.health = 20;
	entity_set_sprite(en, "char_idle");
	en.collision_rect.max = xy(25, 50);
	en.collision_rect = range_bottom_center(en.collision_rect);
	st.player = en;

	#if TESTING
	{
		
		// ground items
		//en = create_world_item("book_survival");
		//en.rel_pos.x = -50;
		en = create_world_item("flint_axe");
		en.rel_pos.x = 30;
		attempt_store_item(en);
		
		en = create_world_item("tool_belt");
		en.rel_pos.x = 10;
		en = create_world_item("flint");
		en.rel_pos.x = 50;
		attempt_store_item(en);
		
		// en = create_world_item("wood");
		// en.rel_pos.x = 20;
		// en = create_world_item("wood");
		// en.rel_pos.x = 30;
		// en = create_world_item("wood");
		// en.rel_pos.x = 45;

		//en = create_world_item("flint_sword");
		//en.rel_pos.x = 45;

		// bp wall
		//en = create_blueprint(.wood_defense_wall);
		//en.rel_pos.x = 200;
		
		// :wall
		// en = create_wall();
		// en.rel_pos.x = -80;

		// :gobby
		#if SPAWN_GOBBY
		{
			en = create_gobby();
			en.rel_pos.x = -100;
			// en.health = 0;
			// set_state(en, .damaged);
		}
	}
}

// :cycle
KeyFrame :: struct
{
	value: string;
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
	
	if time <= st.debug_config.luts[0].frame_time
	{
		prev = *st.debug_config.luts[st.debug_config.luts.count-1];
		next = *st.debug_config.luts[0];
		alpha = float_alpha(time, 0, st.debug_config.luts[0].frame_time);
	}
	else
	{
		for * st.debug_config.luts
		{
			if it.frame_time >= time // find the first greater frame
			{
				prev = *st.debug_config.luts[it_index-1];
				next = it;
				break;
			}
		}
		
		alpha = (time - prev.frame_time) / (next.frame_time - prev.frame_time);
	}
	
	return prev, next, alpha;
}

day_cycle_update :: ()
{
	// tick up the day cycle
	st.world.day_cycle += delta_t;
	if st.world.day_cycle > CYCLE_LENGTH
	{
		st.world.day_cycle = 0.0;
	}
	
	cycle_alpha := get_time_cycle_alpha();

	// select the luts
	f1, f2, alpha := get_keyframes(cycle_alpha);
	//log("%, % alpha: %", f1.value, f2.value, alpha);
	// @ship
	if st.debug_config.disable_cycle_luts
	{
		render_st.lut1 = "neutral_lut";
		render_st.lut2 = "neutral_lut";
		render_st.cbuffer.lut_blend_alpha = 0;
	}
	else
	{
		render_st.lut1 = f1.value;
		render_st.lut2 = f2.value;
		render_st.cbuffer.lut_blend_alpha = alpha;
	}
}

// 0 = dawn, 0.25 = midday, 0.5 = dusk, 0.75 = midnight, 1.0 = dawn
get_time_cycle_alpha :: () -> float
{
	day_progress := float_map(st.world.day_cycle, 0, DAY_LENGTH, 0, 1);
	night_progress := float_map(st.world.day_cycle, DAY_LENGTH, DAY_LENGTH+NIGHT_LENGTH, 0, 1);
	return day_progress/2 + night_progress/2;
}

is_night_time :: () -> bool
{
	return get_time_cycle_alpha() > 0.5;
}

format_version := 1;
world_write :: (world_src: World, world_name: string = DEFAULT_WORLD)
{
	path := tprint("%.ligma", world_name);
	file, success := file_open(path, for_writing=true);
	defer file_close(*file);
	assert(success);

	/*
	cereal_write(*file, format_version, "format_version");
	cereal_write(*file, st.maxent, "st.maxent");
	for st.entities
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

world_read :: (world_dest: *World, world_name: string = DEFAULT_WORLD)
{
	path := tprint("%.ligma", world_name);
	file, success := file_open(path);
	defer file_close(*file);
	assert(success);

	<<world_dest = World.{}; // reset

	version: int;
	cereal_read(*file, *version, "format_version");
	assert(version == format_version);
	// else, convert

	/*
	count: int;
	cereal_read(*file, *count, "st.maxent");
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
	held_item := get_item(held_entity.item_id);
	return held_item.name;
}

font_size_pct :: (pct: float) -> int
{
	return xx (cast(float)get_font_size() * pct);
}

get_font_size :: () -> int
{
	return st.debug_config.ui_font_size;
}

key_down :: (key: Input.Key_Code) -> bool
{
	down := st.key_down[key];
	return down;
}

key_pressed :: (key: Input.Key_Code) -> bool
{
	pressed := gsf.key_pressed[key];
	return pressed;
}

key_released :: (key: Input.Key_Code, consume: bool = true) -> bool
{
	released := gsf.key_released[key];
	if released && consume then gsf.key_released[key] = false;
	return released;
}

consume_key :: (key: Input.Key_Code)
{
	gsf.key_pressed[key] = false;
}

get_player :: () -> *Entity
{
	return st.player;
}

WASDInputAxis :: () -> Vector2
{
	result: Vector2;
	if (st.key_down[#char "A"])
	{
		result.x -= 1;
	}
	if (st.key_down[#char "D"])
	{
		result.x += 1;
	}
	if (st.key_down[#char "W"])
	{
		result.y += 1;
	}
	if (st.key_down[#char "S"])
	{
		result.y -= 1;
	}
	return result;
}

CameraFreeMove :: (using cam: *Camera2)
{
	if (st.key_down[Input.Key_Code.MOUSE_BUTTON_MIDDLE])
	{
		if (Input.mouse_delta_x || Input.mouse_delta_y)
		log("% %\n", Input.mouse_delta_x, Input.mouse_delta_y);
		// TODO - not too sure how I can get this in the correct world space
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
	for * st.lines if !it.valid
	{
		it.valid = true;
		it.p0 = p0;
		it.p1 = p1;
		it.ticks_left = tick_count;
		it.col = col;
		it.transform = trs;
		return *st.lines[it_index];
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
	agro_player;
	attack_charge;
	attack_hit;
}

EntityProps :: enum
{
	valid;
	rigid_body;
	static;
	render_sprite;
	attack_player;
	pick_up;
	obstacle;
	render_rect;
	collision_query;
	blueprint;
	interactable;
	recieve_damage;
	manually_enter_damage;
	override_death; // have to manually handle the death within the .damaged state
	loot_drops;
	particle_emitter;
	destroy_on_complete;

	item;
	craftable;
	unstackable;

	equippable;
	waist;
	
	tree;
	tree_root;
	big_notification;
	smol_notification;

	player;
	monster;
	gobby;
	skele;
	sword;
	axe;
	fist;
}

Entity :: struct
{
	id: u64;
	
	// yeeted the heirarchy for now because it's kinda complex
	//parent: EntityHandle;
	//next: EntityHandle;
	//prev: EntityHandle;
	//first_child: EntityHandle;
	//last_child: EntityHandle;
	//child_count: int;
	
	debug_name: string;
	props: Properties(EntityProps);
	marked_for_destroy: bool;
	
	state: EntityState;
	state_buffer: [8] EntityStateEvent;

	x_dir := 1;
	x_speed_target: float;
	x_speed_accel: float = 800.0;
	x_speed_decel: float = 500.0;
	rel_pos: Vector2;
	velocity: Vector2;
	acceleration: Vector2;
	collision_rect: Range2; // also used for solid-fill rect rendering

	// rendering
	visible: bool = true;
	sprite_id: SpriteID;
	render_offset: Transform2;
	render_offset_target: Transform2;
	render_offset_animate: bool;
	z_layer: float;
	col: Vector4 = WHITE;
	flip_sprite: bool; // manual switch
	parallax: Vector2;
	white_override: float; // overrides the pixel colour with white in the shader
	
	// AI
	input_axis: Vector2;
	walk_position: float;
	state_timer: float;
	// note - DON'T MAKE A NEW AI STATE ya silly fucking goose.
	// it's a FSM for a reason. Just break it out into another state / behaviour. Or store more data if need be.
	
	// animation stuff?
	breathe_current: float;
	breathe_target: float;
	//bob_alpha: float;
	
	animation_playing: bool = true;
	animation_frame: int;
	time_til_next_frame: float;
	
	has_attacked: bool;
	state_cooldown: float;
	timer1: float; // this is asking for trouble lol
	timer2: float;
	start_position: Vector2;

	// item stuff
	item_id: ItemID;
	item_count: int = 1;
	loot_drops: [4]ItemAmount;

	// recieve_damage
	health: int;
	damage_alpha: float;
	last_damage_source: DamageEvent;
	recieve_damage_from: Properties(EntityProps);
	hit_sound: string = "punch";
	
	// tree-specific lol
	detach_count: int;
	left_log: EntityHandle;
	right_log: EntityHandle;
	// ^ how are we gonna take this dogshit and localise it within the gameplay code?
	// we'd need a way of dynamically allocating memory that was scoped to the entity lifetime.
	// it's almost like each entity needs their own arena............
	// yet, we've already kinda got that here with this megastruct
	// ehhhhh just bite the bullet and write this shit out. Who cares if it's polluting the megastruct. That's
	// kinda the whole point of this pattern... - randy 18-05-2023

	// notification
	// it seems wise to just keep piling shit into this megastruct, since we're essentially alreadying getting
	// all the create/destroy/update functionality for free
	notif_title: [64]u8;
	notif_subtitle: [32]u8;
	notif_remaining: float;
	
	// blueprint
	blueprint_alpha: float;
	blueprint_target_alpha: float;
	remaining_items: [4]ItemAmount;
	
	// interactable
	interactable_alpha: float;
	interactable_alpha_t: float;
	
	// particle
	emitter: EmitterKind;
	
	frame: Frame;
	last_frame: Frame;
	Frame :: struct
	{
		did_anim_finish: bool;
		anim_frame_advance: bool;
		did_state_change: bool;
		did_land: bool;
		damages: [..]DamageEvent;
		//x_collision_dir: s8;
		y_collision_dir: s8;
		// hit_entities: [..]EntityHandle;
	}
}
nil_entity := Entity.{};

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
	entity: *Entity = *st.world.entities[handle.index];
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
		handle.index = entity - st.entities.data;
	}
	return handle;
}

is_nil :: (entity: *Entity) -> bool
{
	return (entity == *nil_entity);
}

get_name :: (entity: *Entity) -> string
{
	name := entity.debug_name;
	return name;
}

create_entity :: (debug_name := "") -> *Entity
{
	en: *Entity;
	for * st.entities if !has_prop(it.props, .valid)
	{
		en = *st.entities[it_index]; // reuse an existing invalid one
	}
	// todo - more robust growth strat??
	if en == null
	{
		log_error("Max entities reached!");
		return *nil_entity;
	}

	add_props(*en.props, .valid);
	st.world.entity_id_gen += 1;
	en.id = st.world.entity_id_gen;
	en.debug_name = copy_string(debug_name, world_allocator);
	
	if st.root_entity
	{
		// todo - reimpl
		//entity_attach_to_parent(en, st.root_entity);
	}

	if LOG_VERBOSE then log(tprint("% created", ifx debug_name == "" then "entity" else debug_name));

	return en;
}

entity_destroy_immediate :: (entity: *Entity)
{
	// remove from hierarchy
	// todo - remove children
	//entity_detach_from_parent(entity);
	
	<<entity = Entity.{};
}

entity_duplicate :: (source: *Entity) -> *Entity
{
	en := create_entity();
	id := en.id;
	<<en = <<source;
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

damage_entity :: (en: *Entity, amount: int, from: *Entity, damage_props: Properties(EntityProps))
{
	dmg: DamageEvent;
	dmg.amount = amount;
	dmg.self = handle_from_entity(en);
	dmg.inflictor = handle_from_entity(from);
	dmg.direction.x = xx sign(en.rel_pos.x - from.rel_pos.x);
	dmg.damage_props = damage_props;
	array_add(*en.frame.damages, dmg);
}

get_entity_count_with_prop :: (prop: EntityProps) -> int
{
	// todo - optimise / cache this?
	count : int;
	for * en : st.world.entities
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

// calculates the absolute world-space position by looping up thru the parents
get_absolute_position :: (en: *Entity) -> Vector2
{
	/*
	result: Vector2;
	next := en;
	while is_valid(next)
	{
		defer next = entity_from_handle(next.parent);
		result += next.rel_pos;
	}
	*/
	return en.rel_pos;
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

get_collision_rect :: (en: *Entity) -> Range2
{
	return range_shift(en.collision_rect, get_absolute_position(en));
}

validate_entity :: (en: *Entity, usage_debug_name: string = "")
{
	// FAILURE IS NOT AN OPTION, SOLDIER!
	assert(en != null, tprint("null entity at %", usage_debug_name));
	assert(!is_nil(en), tprint("NIL entity at %", usage_debug_name));
	assert(has_prop(en.props, .valid), tprint("invalid entity at %\n%", usage_debug_name, <<en));
}

is_valid :: (entity: *Entity) -> bool
{
	return entity && !is_nil(entity) && has_prop(entity.props, .valid);
} 

is_valid :: (entity_handle: EntityHandle) -> bool
{
	return is_valid(entity_from_handle(entity_handle));
}

entity_set_sprite :: (en: *Entity, sprite: *Resource)
{
	if en.sprite_id != sprite.id
	{
		// @cleanup - not a fan of all this state jank...
		en.sprite_id = sprite.id;
		en.animation_frame = 0;
		en.last_frame.did_anim_finish = false;
		en.frame.did_anim_finish = false;
		en.last_frame.anim_frame_advance = true;
		en.frame.anim_frame_advance = true;
		en.time_til_next_frame = 1.0 / sprite.play_rate;
	}
}
entity_set_sprite :: (en: *Entity, sprite_name: string)
{
	sprite := get_sprite(sprite_name);
	entity_set_sprite(en, sprite);
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
		array_insert_start(en.state_buffer, .{kind=.exit, state=previous_state, frame=st.frame_count, time=get_time()});
		array_insert_start(en.state_buffer, .{kind=.enter, state=new_state, frame=st.frame_count, time=get_time()});
		en.state = new_state;
		en.state_timer = 0.0;
	}
}

is_state_entry :: (en: *Entity, state: EntityState) -> bool
{
	// look for an enter event and consume it
	for * en.state_buffer
	{
		if !(it.frame == st.frame_count || it.frame == st.frame_count - 1) then break;
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
		if !(it.frame == st.frame_count || it.frame == st.frame_count - 1) then break; // only for this frame or last frame
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

world_item_props :: #run make_props(EntityProps.render_sprite, .pick_up, .rigid_body, .interactable);

create_world_item :: (item_name: string) -> *Entity
{
	item := get_item(item_name);
	en := create_entity();
	en.item_id = item.id;
	en.z_layer = LAYER_ITEMS;
	merge_props(*en.props, item.props);
	merge_props(*en.props, world_item_props);
	add_props(*en.props, .item);
	entity_set_sprite(en, get_sprite(get_display_sprite_id(item)));
	return en;
}

total_weight_in_storage :: () -> int
{
	total_weight : int;
	for * st.stored_items
	{
		en := entity_from_handle(it);
		if is_valid(en)
		{
			stored_item := get_item(en.item_id);
			total_weight += stored_item.weight * en.item_count;
		}
	}
	return total_weight;
}

attempt_store_item :: (entity_item: *Entity) -> bool
{
	item := get_item(entity_item.item_id);
	
	total_weight := total_weight_in_storage();
	if total_weight + item.weight <= st.max_character_weight
	{
		// find slots
		empty_slot : *EntityHandle;
		stackable_slot : *EntityHandle;
		for * st.stored_items
		{
			en := entity_from_handle(it);
			en_item := get_item(en.item_id);
			if !stackable_slot && is_valid(en) && en_item == item
			{
				stackable_slot = it;
			}
			if !empty_slot && !is_valid(en)
			{
				empty_slot = it;
			}
			if empty_slot && stackable_slot then break;
		}
		
		if !has_prop(item.props, .unstackable) && stackable_slot
		{
			entity_item.marked_for_destroy = true;
			entity_stack := entity_from_handle(<<stackable_slot);
			entity_stack.item_count += 1;
		}
		else
		{
			assert(empty_slot != null, "No empty slot found in stored_items. Increase size?");
			<<empty_slot = handle_from_entity(entity_item);
		}
		
		remove_props(*entity_item.props, .render_sprite, .pick_up, .rigid_body, .interactable);
		return true;
	}
	
	return false;
}

// todo - gotta figure out how I can pull dem arguments out into a variable, that way updates can be made to the list
// across all of these specific helpers...
create_tree :: () -> *Entity
{
	en := create_entity("tree");
	add_props(*en.props, .render_sprite, .recieve_damage, .override_death, .tree);
	add_props(*en.recieve_damage_from, .axe);
	entity_set_sprite(en, "tree_full");
	en.collision_rect.max = xy(14, 64);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.health = 10;
	en.z_layer = LAYER_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	en.hit_sound = "wood";
	return en;
}

create_tree_root :: (variant_index: int) -> *Entity
{
	VARIANT_COUNT :: 3;
	variant := variant_index % VARIANT_COUNT;
	does_flip : bool = xx (variant_index % 2);
	
	en := create_entity("tree_root");
	add_props(*en.props, .render_sprite, .recieve_damage, .tree_root, .loot_drops);
	add_props(*en.recieve_damage_from, .player);
	entity_set_sprite(en, tprint("overgrown_roots_%", variant));
	en.collision_rect = rect_from_sprite(en.sprite_id);
	en.health = 20;
	en.z_layer = LAYER_ROOTS;
	en.flip_sprite = does_flip;
	
	en.loot_drops[0] = .{item_name="wood", amount=random_int_range(1, 3)};
	en.hit_sound = "wood";
	
	return en;
}

create_tall_grass :: (variant_index: int) -> *Entity
{
	VARIANT_COUNT :: 1;
	variant := variant_index % VARIANT_COUNT;
	does_flip : bool = xx (variant_index % 2);
	
	en := create_entity("tall_grass");
	add_props(*en.props, .render_sprite, .recieve_damage, .tree_root, .loot_drops);
	add_props(*en.recieve_damage_from, .player);
	entity_set_sprite(en, tprint("tall_grass_%", variant));
	en.collision_rect = rect_from_sprite(en.sprite_id);
	en.health = 20;
	en.z_layer = LAYER_TALL_GRASS;
	en.flip_sprite = does_flip;
	
	en.loot_drops[0] = .{item_name="fibre", amount=random_int_range(1, 2)};
	en.hit_sound = "wood";
	
	return en;
}

create_stump :: () -> *Entity
{
	en := create_entity("stump");
	add_props(*en.props, .render_sprite, .recieve_damage);
	add_props(*en.recieve_damage_from, .axe);
	en.health = 30;
	en.z_layer = LAYER_TREE - 0.1;
	entity_set_sprite(en, "tree_stump");
	en.hit_sound = "wood";
	return en;
}

create_log :: () -> *Entity
{
	en := create_entity("log");
	add_props(*en.props, .render_sprite, .rigid_body, .pick_up, .interactable);
	en.item_id = resource_id_from_name("tree_third");
	// :itemrework ^^ ? not sure bout dis fella
	entity_set_sprite(en, "tree_third");
	en.collision_rect = make_range(xy(64, 16), .bottom_center);
	return en;
}

create_wall :: () -> *Entity
{
	en := create_entity("wall");
	en.z_layer = -10;
	en.health = 20;
	entity_set_sprite(en, "wood_defense_wall");
	add_props(*en.props, .rigid_body, .static, .render_sprite, .obstacle, .recieve_damage);
	add_props(*en.recieve_damage_from, .monster);
	en.collision_rect.max = xy(11, 68);
	en.collision_rect = range_shift(en.collision_rect, xy(-12, 0));
	return en;
}

create_gobby :: () -> *Entity
{
	en := create_entity("gobby");
	en.health = 20;
	en.z_layer = -1;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .recieve_damage, .manually_enter_damage, .override_death, .gobby, .monster, .loot_drops);
	add_props(*en.recieve_damage_from, .player);
	en.loot_drops[0] = .{item_name="goblin_hide", amount=random_int_range(1, 3)};
	return en;
}

create_skele :: () -> *Entity
{
	en := create_entity("skelle");
	en.health = 20;
	en.z_layer = -1;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .recieve_damage, .override_death, .skele, .monster);
	add_props(*en.recieve_damage_from, .player);
	return en;
}

create_notification :: (txt: string, is_big := false) -> *Entity
{
	en := create_entity();
	add_props(*en.props, ifx is_big then EntityProps.big_notification else EntityProps.smol_notification);
	string_copy(en.notif_title, txt);
	return en;
}

survival_book_ui :: ()
{
	held_item_name := get_held_entity_item_name();
	
	// entry condition
	if held_item_name == "book_survival"
		&& st.interface_state == .nil
		&& key_pressed(.MOUSE_BUTTON_RIGHT)
	{
		set_interface_state(.survival_book);
	}
	
	// exit condition
	if st.interface_state == .survival_book
		&& (held_item_name != "book_survival" || key_pressed(.ESCAPE))
	{
		set_interface_state(.nil);
	}
	
	// survival book state
	if st.interface_state == .survival_book
	{
		if is_state_entry(.survival_book)
		{
			// ...
		}
		
		// render UI
		st.show_cursor = true;
		st.disable_player_input = true;
		
		// flip pages
		prev_page := st.sb_page;
		st.sb_page += xx key_pressed(#char "D");
		st.sb_page -= xx key_pressed(#char "A");
		st.sb_page = clamp(st.sb_page, 0, st.PAGE_COUNT-1);
		if st.sb_page != prev_page then play_sound("page_flip");
		
		// update alpha to target for each page
		for * st.sb_page_opacity
		{
			target_opacity := ifx it_index == st.sb_page then 1.0 else 0.0;
			animate_to_target(it, target_opacity, 30);
		}
		
		// defaults
		push_fill_col(WHITE);
		push_text_col(BLACK);
		push_text_edge_pad(2);
		push_pref_width(pct_parent(1.0, 0.0));
		push_pref_height(px(40));
		push_text_justify_x(.center);
		
		// page backdrop
		ui_center();
		height := px(800);
		width := px(600);
		set_next_pref_height(height);
		set_next_pref_width(width);
		page_backdrop := make_box(BoxFlags.draw_fill, "");
		push_parent(page_backdrop);
		
		//
		// PAGES
		//
		for page: 0..st.PAGE_COUNT-1
			if st.sb_page_opacity[page]
		{
			push_opacity(st.sb_page_opacity[page]);
			
			// make a floating parent so we can be overlapped with other pages
			set_next_pref_height(pct_parent(1));
			set_next_pref_width(pct_parent(1));
			push_parent(make_box(.floating, ""));
			
			// page-specifics
			if page ==
			{
				case 0;
				ui_center();
				push_text_justify_x(.center);
				push_text_edge_pad(0);
				set_next_pref_height(px(64));
				label("- Survival 101 -");
				set_next_font(FONT_SUB);
				label("a guide to liveliness");
				
				case 1;
				label("yeet");
				
				case 2;
				label("balls");
			}
			
			// page number
			if page > 0
			{
				spacer(pct_parent(1, 0));
				// page number at bottom
				set_next_fill_col(GRAY);
				set_next_text_justify_x(.right);
				set_next_pref_height(px(60));
				set_next_text_edge_pad(10);
				label("pg%", page);
			}
		}
	}
}

enemy_update :: ()
{
	player := get_player();
	
	// todo - skele
	// literally just copy out the gobby and adjust as needed
	// do this 1 more time for another monster, THEN figure out if we can abstract stuff
	
	// :GOBBY
	for * en: st.entities if is_valid(en) && has_prop(en.props, .gobby)
	{
		range_to_player: Range1 = .{player.rel_pos.x, en.rel_pos.x};
		range_to_player = range_correct(range_to_player);
		dist_to_player := range_size(range_to_player);
		is_player_dead := st.player.health <= 0;
		
		// find target entity
		closest_obstacle: *Entity = *nil_entity;
		for * obst: st.entities if is_valid(obst) && has_prop(obst.props, .obstacle)
		{
			prev_dist := abs(closest_obstacle.rel_pos.x - en.rel_pos.x);
			new_dist := abs(obst.rel_pos.x - en.rel_pos.x);
			in_range := range_contains(range_to_player, get_absolute_position(obst).x);
			if in_range
				&& (is_nil(closest_obstacle) || new_dist < prev_dist)
			{
				closest_obstacle = obst;
			}
		}
		target_entity : *Entity = ifx is_valid(closest_obstacle) then closest_obstacle else st.player;
		
		// TODO -
		// add more enemies, and THEN refactor. Just go FSM.
		// MAKE CONTENT.
		
		en.state_timer += delta_t;
		
		AGRO_RANGE :: 100;
		ATTACK_RANGE :: 25;
		LOOSE_AGRO :: 200;
		
		move: bool;
		
		if en.state == .nil
		{
			set_state(en, .idle);
		}
		
		if en.state == .idle
		{
			if is_state_entry(en, .idle)
			{
				entity_set_sprite(en, "gob_idle");
			}
			
			if en.state_timer > 2.0
			{
				set_state(en, .wandering);
			}
		}
		
		if en.state == .wandering
		{
			if is_state_entry(en, .wandering)
			{
				en.walk_position = en.rel_pos.x + random_get_within_range(30, 200) * random_sign();
			}
			
			if abs(en.walk_position - en.rel_pos.x) < 5.0
			{
				set_state(en, .idle);
			}
		}
		
		// enter recieve damage
		if en.damage_alpha == 1.0
		{
			set_state(en, .damaged);
		}
		// recieve damage
		if en.state == .damaged
		{
			is_dead := en.health <= 0;
			if is_state_entry(en, .damaged)
			{
				en.velocity = en.last_damage_source.direction * ifx is_dead then 200.0 else 100.0;
			}
			
			if is_dead
			{
				set_state(en, .dying);
			}
			else
			{
				entity_set_sprite(en, "gob_hurt");
				if en.frame.did_anim_finish then set_state(en, .idle);
			}
		}
		
		// death
		if en.state == .dying
		{
			entity_set_sprite(en, "gob_death");
			if en.frame.did_anim_finish then set_state(en, .dead);
		}
		if en.state == .dead
		{
			// sadge
			en.marked_for_destroy = true;
			do_death_poof(en);
			do_loot_drops(en);
			play_sound("impact_thing");
		}
		
		// enter agro
		if dist_to_player < AGRO_RANGE
			&& !is_player_dead
			&& is_any(en.state, .idle, .wandering)
			&& !is_any(en.state, .damaged, .dying, .dead)
		{
			set_state(en, .agro_player);
		}
		// agro
		if en.state == .agro_player
		{
			en.walk_position = target_entity.rel_pos.x;
			
			if dist_to_player > LOOSE_AGRO
			{
				set_state(en, .idle);
			}
		}
		
		// enter attack
		dist_to_target := abs(target_entity.rel_pos.x - en.rel_pos.x);
		if dist_to_target < ATTACK_RANGE
			&& !is_player_dead
			&& is_any(en.state, .idle, .wandering, .agro_player)
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
			}
			
			attack_frame :: 6;
			if is_valid(target_entity) && en.animation_frame == attack_frame
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
				//if en.x_dir == -1 then attack_hitbox = range_flip_x(attack_hitbox);
				attack_hitbox = range_shift(attack_hitbox, get_absolute_position(en));
				against_rect := range_shift(target_entity.collision_rect, get_absolute_position(target_entity));
				// debug_rect(attack_hitbox, 50);
				// debug_rect(against_rect, 50);
				if range_collide(against_rect, attack_hitbox)
				{
					damage_entity(target_entity, 10, en, make_props(EntityProps.gobby, .monster));
				}
			}
			
			if en.frame.did_anim_finish
			{
				set_state(en, .idle);
			}
		}
		
		// this is kinda a parent of agro_player & wandering
		if en.state == .agro_player || en.state == .wandering
		{
			entity_set_sprite(en, "gob_run");
			dist := en.walk_position - en.rel_pos.x;
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

recieve_damage :: ()
{
	// I think this whole thing might've been going a little too far into generic territory...
		
	for * en: st.entities if has_prop(en.props, .recieve_damage)
	{
		// damage animation
		tick_timer(*en.damage_alpha);
		if en.damage_alpha != 0
		{
			exp := ease_out_exp(1-en.damage_alpha, rate=20);
			en.white_override = 1-exp;
		}
		
		// loop thru all damages
		if en.frame.damages.count
			&& en.health > 0
		{
			main_visual_damage: DamageEvent;
			for dmg: en.frame.damages
				if match_props_any(dmg.damage_props, en.recieve_damage_from) // mask out damages from wrong sources
			{
				if it_index == 0 then main_visual_damage = dmg;
				en.health -= dmg.amount;
				en.health = max(en.health, 0);
			}
			
			if main_visual_damage.amount != 0
			{
				en.last_damage_source = main_visual_damage;
				en.damage_alpha = 1.0;
				if !has_prop(en.props, .manually_enter_damage) then set_state(en, .damaged);
				
				play_sound(en.hit_sound);
			}
		}
		
		if !has_prop(en.props, .override_death) && en.health <= 0
		{
			en.marked_for_destroy = true;
			do_death_poof(en);
			do_loot_drops(en);
		}
	}
}

do_death_poof :: (en: *Entity)
{
	create_emitter(en.rel_pos, .death_poof);	
}

do_loot_drops :: (en: *Entity)
{
	for en.loot_drops 
	{
		if it.item_name == "" then break;
		
		for it_amount : 0..it.amount-1
		{
			item := create_world_item(it.item_name);
			item.rel_pos = en.rel_pos + xy((it.amount / -2.0) + it_amount * 10.0, 10);
		}
	}
}


tree_update :: ()
{
	for * tree: st.entities if is_valid(tree) && has_prop(tree.props, .tree)
	{
		
		if tree.state == .damaged
		{
			if tree.health <= 0 then set_state(tree, .dying);
		}
		
		if tree.state == .dying
		{
			fall_length :: 2.2;
			if is_state_entry(tree, .dying)
			{
				entity_set_sprite(tree, "tree_long_log");
				tree.timer1 = fall_length;
				
				stump := create_stump();
				stump.rel_pos = tree.rel_pos;
			}
			
			ROT_OFFSET :: -7;
			// TIMBERRRR
			alpha := 1-tree.timer1 / fall_length;
			alpha = (ease_in_cubic(alpha) + ease_in_exp(alpha)) / 2;
			tree.render_offset.pivot_offset.y = ROT_OFFSET;
			tree.render_offset.rotate = alpha * -90;
			
			// finished falling
			if tick_timer(*tree.timer1)
			{
				STUMP_HEIGHT :: 16.0;
				TREE_THIRD :: 64.0;
				HALF_WIDTH :: TREE_THIRD * 0.5;
				
				// split the log into thirds
				logs: [3]*Entity;
				for 1..3
				{
					tree_log := create_log();
					tree_log.rel_pos = tree.rel_pos;
					tree_log.rel_pos.x += ROT_OFFSET + STUMP_HEIGHT + TREE_THIRD * (it-1.0) + HALF_WIDTH;
					tree_log.z_layer = tree.z_layer;
					//tree_log.detach_count = ifx it == 2 then 2 else 1; // the middle needs both sides to detach first, kinda scuffed but works lol
					logs[it-1] = tree_log;
					tree_log.velocity.x = 50 * (it-1.0);
				}
				
				new_event(.{kind=.death, entity=handle_from_entity(tree)});
				
				tree.marked_for_destroy = true;
			}
		}
	}
}

player_update :: ()
{
	player := get_player();

	attack_hitbox: Range2;
	attack_hitbox.max = xy(40, 24);
	if player.x_dir == -1 then attack_hitbox = range_flip_x(attack_hitbox);
	attack_hitbox = range_shift(attack_hitbox, player.rel_pos);


	// @cleanup
	
	disable_input: bool = st.disable_player_input;
	st.disable_player_input = false;
	// disable_input = disable_input
	// || (player.state == .dead
	// || player.state == .crafting);
	
	player.input_axis = .{};
	if !disable_input
	{
		player.input_axis = WASDInputAxis();
		player.input_axis.y = 0.0;
		
		if gsf.key_pressed[Input.Key_Code.SPACEBAR]
		{
			consume_key(.SPACEBAR);
			set_state(player, .jump);
		}
	}
	
	// set the movement dir
	sprinting := false;
	if player.input_axis.x != 0.0 && !disable_input
	{
		mult := 1.0;
		if st.key_down[Input.Key_Code.SHIFT]
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
	
	
	
	//
	// :player state
	//
	
	if player.state == .idle
	{
		entity_set_sprite(player, "char_idle");
		player.x_speed_target = 0.0;
		
		if player.input_axis.x != 0.0 && !disable_input
		{
			set_state(player, .walk);
		}
	}
	
	// jump / landing
	if player.state == .jump
	{
		if is_state_entry(player, .jump)
		{
			player.velocity.y = 250.0;
			create_emitter(player.rel_pos, .jump_dust);
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
			emit := create_emitter(player.rel_pos, .landing_dust);
			emit.velocity.x = player.velocity.x * 0.2;
		}
		
		if player.frame.did_anim_finish
		{
			set_state(player, .idle);
		}
	}
	
	// WALK
	if player.state == .walk
	{
		if sprinting
		{
			entity_set_sprite(player, "char_run");
		}
		else
		{
			entity_set_sprite(player, "char_walk");
		}
		
		if player.input_axis.x == 0.0
		{
			set_state(player, .idle);
		}
	}
	
	if player.damage_alpha == 1.0
	{
		set_state(player, .damaged);
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
				player.x_dir = -sign(player.last_damage_source.direction.x);
				player.velocity.x += -player.x_dir * 80.0;
			}
			
			st.disable_player_input = true;
			
			if player.frame.did_anim_finish then set_state(player, .idle); 
		}
	}
	
	// death
	if player.state == .dying
	{
		if is_state_entry(player, .dying)
		{
			entity_set_sprite(player, "char_death");
			set_interface_state(.death_screen);
		}
		
		st.disable_player_input = true;
	}

	// rotate in direction of travel
	if player.state == .idle || player.state == .walk
	{
		//player.render_offset.pivot_offset = xy(0);
		//alpha := player.velocity.x / max_player_move_speed;
		//player.render_offset.rotate = player_move_tilt * alpha;
	}
	
	// enter attack state
	if (player.state == .idle || player.state == .walk)
		&& (key_pressed(Input.Key_Code.MOUSE_BUTTON_LEFT) || key_pressed(#char "K"))
	{
		consume_key(.MOUSE_BUTTON_LEFT);
		
		held_entity := get_held_entity();
		
		// launch into attack state
		attack_state: EntityState = .punch;
		if is_valid(held_entity)
		{
			if has_prop(held_entity.props, .axe)
			{
				attack_state = .chop;
			}
			else if has_prop(held_entity.props, .sword)
			{
				// flip flop between slashes
				state, time_ago := get_last_state_from_set(player, .[.slash_1, .slash_2]);
				if state == .slash_1 && time_ago < 1
				{
					attack_state = .slash_2;
				}
				else
				{
					attack_state = .slash_1;
				}
			}
		}

		set_state(player, attack_state);
	}
	
	// :hit :punch and shit
	// todo - make this good
	hit :: (hitbox: Range2, source: *Entity)
	{
		for * en: st.entities
			if is_valid(en)
			&& has_prop(en.props, .recieve_damage)
			&& en != source
		{
			against_rect := get_collision_rect(en);
			//debug_rect(against_rect, 1);
			//debug_rect(attack_hitbox, 1);
			if range_collide(hitbox, against_rect)
			{
				damage_props := get_item(get_held_entity().item_id).props;
				add_props(*damage_props, .player);
				damage_entity(en, 10, source, damage_props);
			}
		}
	}
	
	// sword attacking
	if player.state == .slash_1
	{
		if is_state_entry(player, .slash_1)
		{
			play_sound("light_whoosh_01");
		}
		
		st.disable_player_input = true;
		entity_set_sprite(player, "char_slash1");
		held_en := get_held_entity();
		
		// hit
		if player.animation_frame == 3 && player.frame.anim_frame_advance
		{
			hit(attack_hitbox, player);
		}
		
		if player.frame.did_anim_finish
		{
			set_state(player, .idle);
		}
	}
	
	if player.state == .slash_2
	{
		if is_state_entry(player, .slash_2)
		{
			play_sound("light_whoosh_02");
		}
		
		st.disable_player_input = true;
		entity_set_sprite(player, "char_stab1"); // just using stab now bc we don't have a second slash yet
		held_en := get_held_entity();
		
		// hit
		if player.animation_frame == 2 && player.frame.anim_frame_advance
		{
			hit(attack_hitbox, player);
			player.velocity.x += player.x_dir * 100.0;
		}
		
		if player.frame.did_anim_finish
		{
			set_state(player, .idle);
		}
	}
	
	
	// play out the attack state
	if player.state == .chop || player.state == .punch
	{
		st.disable_player_input = true;
		entity_set_sprite(player, "char_punch");
		
		// hit
		if player.animation_frame == 3 && player.frame.anim_frame_advance
		{
			hit(attack_hitbox, player);
			//play_sound("punch");
		}
		
		if player.frame.did_anim_finish
		{
			set_state(player, .idle);
		}
	}
}

animate_sprites :: ()
{
	for * en: st.entities if has_prop(en.props, .valid) && en.sprite_id
	{
		using en;

		if time_til_next_frame != 0.0 && animation_playing
		{
			time_til_next_frame -= delta_t;
			if time_til_next_frame <= 0
			{
				animation_frame += 1;
				frame.anim_frame_advance = true;
				sprite := get_sprite(sprite_id);
				time_til_next_frame = 1.0 / sprite.play_rate;
				if animation_frame >= sprite.frame_count
				{
					if sprite.looping
					{
						animation_frame = 0;
					}
					else
					{
						animation_frame -= 1;
						time_til_next_frame = 0.0;
					}
					
					frame.did_anim_finish = true;
				}
			}
		}
	}
}

// :physics
physics_update :: ()
{
	for * entity: st.entities if is_valid(entity) && has_prop(entity.props, .rigid_body) && !has_prop(entity.props, .static)
	{
		// target velocity
		{
			using entity;
			assert(x_speed_target >= 0); // speed is absolute!
			x_vel_target:= x_dir * x_speed_target;
			diff_sign:= sign(x_vel_target - velocity.x);
			constant:= ifx x_vel_target == 0.0 then x_speed_decel else x_speed_accel;
			velocity.x += diff_sign * constant * delta_t;
			if diff_sign != sign(x_vel_target - velocity.x) then velocity.x = x_vel_target;
			// if entity == player then log("%\n", velocity.x);
		}

		gravity :: 980.0;
		entity.acceleration.y -= (ifx entity.velocity.y < 0.0 then 2.0 else 1.0) * gravity;

		next_pos:= entity.rel_pos + entity.velocity * delta_t + entity.acceleration * 0.5 * delta_t * delta_t;
		entity.velocity += entity.acceleration * delta_t;
		entity.acceleration = xy(0, 0);

		if next_pos.y < 0
		{
			entity.frame.did_land = true;
			entity.frame.y_collision_dir = -1;
			next_pos.y = 0;
			entity.velocity.y = 0;
		}
		
		if abs(next_pos.x) > xx world_radius
		{
			next_pos.x = world_radius * cast(float) sign(next_pos.x);
			entity.velocity.x = 0;
		}

		entity.rel_pos = next_pos;

		/*
		// resolve against all other rigid bodies
		for * against: st.entities if against.valid
		{
			entity_bounds:= range_shift(entity.collision_rect, next_pos);
			against_bounds:= range_shift(against.collision_rect, against.position);

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
	for * en: st.entities if is_valid(en)
	{
		if has_prop(en.props, .big_notification) && !big_notif
		{
			big_notif = en;
		}
		if has_prop(en.props, .smol_notification)
		{
			array_add(*smol_notifications, en);
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
			LENGTH :: 5.0;
			if it.notif_remaining == 0.0 then it.notif_remaining = LENGTH;
			alpha := 1-(it.notif_remaining / LENGTH);
			
			opacity: float = 1.0;
			if alpha < 0.1
			{
				opacity = float_map(alpha, 0, 0.05, 0, 1);
			}
			else if alpha > 0.8
			{
				opacity = 1-float_map(alpha, 0.8, 1.0, 0, 1);
			}
			
			push_opacity(opacity);
			label(to_string(it.notif_title));
			
			if tick_timer(*it.notif_remaining)
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
		
		spacer(pct_parent(0.6));
		
		set_next_font_size(st.debug_config.ui_font_size * 4);
		set_next_pref_height(text_dim());
		label(tprint("%##notif", to_string(big_notif.notif_title)));
		
		set_next_font_size(st.debug_config.ui_font_size * 2);
		set_next_pref_height(text_dim());
		label(tprint("%##notif_sub", to_string(big_notif.notif_subtitle)));
		
		if tick_timer(*big_notif.notif_remaining)
		{
			entity_destroy_immediate(big_notif);
		}
	}
}

main_menu_ui :: ()
{
	if is_state_exit(.main_menu)
	{
		st.main_menu_alpha_t = 0.0;
	}
	if is_state_entry(.main_menu)
	{
		st.main_menu_alpha_t = 1.0;
	}
	animate_to_target(*st.main_menu_alpha, st.main_menu_alpha_t, 15);
	
	if st.main_menu_alpha_t == 1.0
	{
		st.show_cursor = true;
		st.confine_cursor = false;
	}
	
	if st.main_menu_alpha != 0.0
	{
		alpha := st.main_menu_alpha;
		
		push_opacity(alpha);
		push_text_justify_x(.center);
		push_flags(ifx st.main_menu_alpha_t == 0.0 then BoxFlags.DISABLE_INTERACTION);
		
		// black bg
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		set_next_fill_col(BLACK);
		set_next_flags(.draw_fill);
		auto_column();
		
		set_next_floating_y((1-alpha) * 30.0 * ifx st.main_menu_alpha_t == 1 then -1 else 1);
		set_next_child_layout_axis(.X);
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		box := make_box(BoxFlags.floating , "");
		push_parent(box);
		padding(pct_parent(1, 0));
		
		set_next_pref_height(pct_parent(1));
		auto_column();
		padding(pct_parent(1, 0));
		
		set_next_font(FONT_MAIN);
		set_next_font_size(32);
		label("Arcane Survival");
		
		spacer(em(0.5));
		
		if button("Begin.").clicked
		{
			set_app_state(.world);
		}
	}
}

pause_ui :: ()
{
	if st.interface_state == .pause_menu && key_pressed(.ESCAPE)
	{
		set_interface_state(.nil);
	}
	
	// entry / exit
	if is_state_entry(.pause_menu)
	{
		st.pause_menu_alpha_t = 1.0;
		st.simulating = false;
	}
	if is_state_exit(.pause_menu)
	{
		st.pause_menu_alpha_t = 0.0;
		st.confine_cursor = true;
		st.simulating = true;
	}
	
	if st.app_state != .world
	{
		st.pause_menu_alpha_t = 0.0;
	}
	
	animate_to_target(*st.pause_menu_alpha, st.pause_menu_alpha_t, 10);
	
	if st.interface_state == .pause_menu
	{
		st.show_cursor = true;
		st.confine_cursor = false;
		st.disable_player_input = true;
	}
	
	if st.pause_menu_alpha != 0.0
	{
		alpha := st.pause_menu_alpha;
		
		push_opacity(alpha);
		push_text_justify_x(.center);
		push_flags(ifx st.interface_state != .pause_menu then BoxFlags.DISABLE_INTERACTION);
		
		set_next_floating_x((1-alpha) * -300.0);
		set_next_child_layout_axis(.Y);
		set_next_pref_width(em(10));
		set_next_pref_height(size_by_children(1));
		set_next_fill_col(BLACK);
		box := make_box(BoxFlags.floating | .draw_fill | .draw_border, "");
		defer spacer(pct_parent(1, 0));
		push_parent(box);
		
		label("- PAUSED -");
		if button("main menu").clicked
		{
			set_app_state(.main_menu);
		}
	}
}

death_screen_ui :: ()
{
	if st.interface_state == .death_screen
	{
		st.death_screen_alpha_t = 1.0;
		animate_to_target(*st.death_screen_alpha, st.death_screen_alpha_t, 2);
	}
	else
	{
		st.death_screen_alpha_t = 0.0;
		animate_to_target(*st.death_screen_alpha, st.death_screen_alpha_t, 30);
	}
	
	if st.death_screen_alpha != 0
	{
		alpha := st.death_screen_alpha;
		
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
		
		set_next_font_size(st.debug_config.ui_font_size * 4);
		set_next_pref_height(text_dim());
		label("ur ded lol");
		
		set_next_font_size(st.debug_config.ui_font_size * 2);
		set_next_pref_height(text_dim());
		label("press R to restart");
		
		spacer(pct_parent(0.3));
	}
}

in_game_user_interaction :: ()
{
	interact_hitbox: Range2;
	interact_hitbox.min.x = -10;
	interact_hitbox.max = xy(40, 32);
	if st.player.x_dir == -1 then interact_hitbox = range_flip_x(interact_hitbox);
	interact_hitbox = range_shift(interact_hitbox, st.player.rel_pos);
	//debug_rect(interact_hitbox, 1);
	
	// GRAB OVERLAPPED INTERACTABLES
	overlapped: [..]*Entity;
	for * en: st.entities
		if is_valid(en)
		&& has_prop(en.props, .interactable)
		&& en != get_held_entity()
	{
		// add overlapping
		against_rect := get_collision_rect(en);
		if range_collide(interact_hitbox, against_rect)
		{
			array_add(*overlapped, en);
		}
	}
	
	// SET HOVERED INTERACTABLE
	hovered_interactable: *Entity = *nil_entity;
	for en: overlapped
	{
		is_closer: bool;
		if is_nil(hovered_interactable)
		|| abs(get_absolute_position(hovered_interactable).x - st.player.rel_pos.x) > abs (get_absolute_position(en).x - st.player.rel_pos.x)
		{
			is_closer = true;
		}
		
		// can we pickup item?
		pickup_interact := true;
		if has_prop(en.props, .pick_up)
		{
			pickup_interact = !is_valid(get_held_entity()); // if we don't already have a held item
		}
		
		// can we equip item?
		equip_interact := true;
		if has_prop(en.props, .equippable)
		{
			for st.stored_items
			{
				equipped := entity_from_handle(it);
				if is_valid(equipped) && equipped.item_id == en.item_id
				{
					// existing equipped item
					equip_interact = false;
					break;
				}
			}
		}
		
		// can we interact with this blueprint?
		blueprint_interact := true;
		if has_prop(en.props, .blueprint)
		{
			struc := get_item(en.item_id);
			
			held_entity := get_held_entity();
			held_item := get_item(held_entity.item_id);
			can_we_use_item := false;
			for * en.remaining_items
			{
				if it.item_name == "" || !is_valid(held_item) then break;
				remaining_amount := struc.recipe[it_index].amount - it.amount;
				
				// check that the bp needs our held item
				if it.item_name == held_item.name && remaining_amount > 0
				{
					can_we_use_item = true;
					break;
				}
			}
			blueprint_interact = can_we_use_item || IGNORE_MATERIAL_COST;
		}
		
		// can we actually interact with this guy?
		if !st.disable_player_input
			&& is_closer && pickup_interact && blueprint_interact && equip_interact
		{
			hovered_interactable = en;
		}
	}
	last_interactable := entity_from_handle(st.hovered_interactable);
	st.hovered_interactable = handle_from_entity(hovered_interactable);
	
	//
	// IN-GAME UI
	//
	
	// set the the target visible state for various UI elements
	interaction_target := false;
	for * en: st.entities if is_valid(en)
	{
		// The general idea here is that we're always ready to render the UI,
		// that way it can be smoothly faded in / out depending on its alpha
		// irrespective of our actual target_alpha (which is either 1 or 0)
		// It's like a derivative of the actual state.
		
		//
		// INTERACTION target state
		//
		if has_prop(en.props, .interactable)
			&& en == hovered_interactable && hovered_interactable != last_interactable
		{
			en.interactable_alpha_t = 1.0; // enter interaction
			en.breathe_target = 1.0;
		}
		if !has_prop(en.props, .interactable) || (en == last_interactable && last_interactable != hovered_interactable)
		{
			en.interactable_alpha_t = 0; // exit interaction
			en.breathe_target = 0;
		}
		if en.interactable_alpha != en.interactable_alpha_t
			then animate_to_target(*en.interactable_alpha, en.interactable_alpha_t, 20); // update alpha to target
		
		// ensure there's only one interaction target
		if en.interactable_alpha_t == 1.0
		{
			assert(!interaction_target, "There should only be one interaction target!");
			interaction_target = true;
		}
		
		//
		// BLUEPRINT ui target state
		//
		in_player_range := abs(get_absolute_position(en).x - get_absolute_position(st.player).x) < 100;
		if has_prop(en.props, .blueprint)
			&& in_player_range
		{
			en.blueprint_target_alpha = 1.0;
		}
		else
		{
			en.blueprint_target_alpha = 0;
		}
		if en.blueprint_alpha != en.blueprint_target_alpha
			then animate_to_target(*en.blueprint_alpha, en.blueprint_target_alpha, 20); // update alpha to target
	}
	
	// from this point, the hovered interactable is now assumed to have the all-clear for the interaction button press
	
	// INTERACTABLE UI
	for * en: st.entities if is_valid(en) && en.interactable_alpha != 0.0
	{
		sprite := get_sprite(en.sprite_id);
		
		// breathe white
		did_reach := lerp_to_target(*en.breathe_current, en.breathe_target);
		if did_reach && en == entity_from_handle(st.hovered_interactable)
		{
			en.breathe_current = 0.0; // reset
		}
		en.white_override = en.interactable_alpha * ease_sin_breathe(en.breathe_current) * 0.5;
		
		assert(ifx en.interactable_alpha_t != 0 then en == hovered_interactable else true, "the target should be the hovered");
		
		// item equip
		if en.interactable_alpha_t != 0
			&& has_prop(en.props, .equippable)
			&& key_pressed(#char "E")
		{
			consume_key(#char "E");
			//play_sound("equip");
			found_slot : bool;
			for * st.stored_items
			{
				equipped := entity_from_handle(it);
				if is_valid(equipped) then continue;
				<<it = handle_from_entity(en);
				found_slot = true;
				break;
			}
			assert(found_slot, "Equip slot not found?");
			en.marked_for_destroy = true;
		}
		
		// item pickup
		if en.interactable_alpha_t != 0
			&& has_prop(en.props, .pick_up)
		{
			// todo - better tooltip tutorial thang
			// trs := make_transform(get_absolute_position(en), 0, en.interactable_alpha);
			// trs.translate.y += range_size(sprite.rect).y + 5;
			// trs.translate.y += ease_sin_breathe(en.breathe_current) * 2.0;
			// push_text("E", 10, FONT_1980, col=xyzw(1, 1, 1, en.interactable_alpha), z_layer=100, trs=trs);
		
			if key_pressed(#char "E")
				&& en == hovered_interactable
			{
				consume_key(#char "E");
				play_sound("air_swing");
				attempt_store_item(en);
				new_event(Event.{kind=.pickup, entity=handle_from_entity(en)});
			}
		}
	}
	
	// :BLUEPRINT UI
	for * en: st.entities if is_valid(en) && en.blueprint_alpha != 0.0
	{
		sprite := get_sprite(en.sprite_id);
		
		// push into the correct space
		push_parent(st.ui.frame.root); // this makes us skip past the usual root :screen_space
		push_quad_flags(0); // removes the default .SKIP_CAMERA_TRANSFORM, kinda sketch lol
		pos := get_absolute_position(en);
		set_next_floating_x(pos.x);
		set_next_floating_y(pos.y - 10 * en.blueprint_alpha);
		push_opacity(en.blueprint_alpha);
		
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
			if remaining.item_name == "" then break;
			assert(remaining.item_name == struc.recipe[it_index].item_name);
			item := get_item(remaining.item_name);
			
			padding(em(0.2));
			{
				set_next_pref_width(size_by_children(1));
				set_next_pref_height(size_by_children(1));
				auto_column();
			
				icon(get_display_sprite_id(item), tprint("%_%_icon", it_index, en.id), em(2));
				
				label("%/%##quantity_%", remaining.amount, struc.recipe[it_index].amount, en.id);
			}
		}
		
		trs := make_transform(get_absolute_position(en), 0, 0.1 * en.interactable_alpha);
		trs.translate.y += 3 + range_size(sprite.rect).y;
		trs.translate.y += ease_sin_breathe(en.breathe_current) * 2.0;
		push_text("E", 100, FONT_1980, col=xyzw(1, 1, 1, en.interactable_alpha), z_layer=100, trs=trs);
	
		can_interact := en.interactable_alpha_t == 1.0;
		if can_interact && key_pressed(#char "E")
		{
			consume_key(#char "E");
			struc := get_item(en.item_id);
			held_entity := get_held_entity();
			held_item := get_item(held_entity.item_id);
			// assert(held_item != .nil, "marked as interactable yet we don't have a held item??");
			did_consume := false;
			bp_finished := true;
			for * en.remaining_items
			{
				if it.item_name == "" then break;
				if it.item_name == held_item.name
				{
					it.amount += 1;
					held_entity.marked_for_destroy = true;
					did_consume = true;
				}
				if it.amount != struc.recipe[it_index].amount then bp_finished = false;
			}
			// assert(did_consume, "We were marked for consumption by being interactable, yet it failed?");
			
			if bp_finished || IGNORE_MATERIAL_COST
			{
				on_build(en);
				new_event(.{kind=.craft, entity=handle_from_entity(en)});
				play_sound("build_finish", random_spread=false);
			}
			else
			{
				play_random_sound("build", 2);
			}
		}
	}
	
	//
	// :HELD ITEM STUFF
	//
	
	// update held item pos
	held_en := get_held_entity();
	if is_valid(held_en)
	{
		remove_props(*held_en.props, .rigid_body);
		held_en.x_dir = st.player.x_dir;
		flip := st.player.x_dir == -1;
		held_en.render_offset_animate = true;
		
		held_sprite := get_sprite(held_en.sprite_id);
		
		target_offset_trs: Transform2;
		player_anim := get_sprite(st.player.sprite_id);
		if player_anim.hand_sockets.count > 0
		{
			target_offset_trs = player_anim.hand_sockets[st.player.animation_frame];
			target_offset_trs.rotate *= -1;
		}
		target_offset_trs.translate -= held_sprite.grip_offset.translate;
		target_offset_trs.pivot_offset = held_sprite.grip_offset.translate * -1;
		target_offset_trs.pivot_offset.x *= ifx flip then -1 else 1;
		target_offset_trs.rotate -= held_sprite.grip_offset.rotate;
		
		if flip then target_offset_trs.rotate *= -1;
		
		held_en.render_offset_target = target_offset_trs;
		held_en.rel_pos = st.player.rel_pos;
		// todo - pickup animation
		//animate_to_target(*held_en.rel_pos, st.player.rel_pos, 20);
	}
	
	// drop the current held item
	if !st.disable_player_input && is_valid(get_held_entity()) && key_pressed(#char "Q")
	{
		consume_key(#char "Q");
		en := get_held_entity();
		add_props(*en.props, .rigid_body);
		en.render_offset_target = .{};
		en.velocity.x = st.player.velocity.x;
		en.velocity.y = st.player.velocity.y;
		play_sound("air_swing", pitch=0.8);
		
		// drop from inv
		st.hotbar_slots[st.hot_slot] = .{};
	}
}

// ^ :update

//
// :INVENTORY
//

get_held_entity :: () -> *Entity
{
	return entity_from_handle(st.hotbar_slots[st.hot_slot]);
}

inventory_ui :: ()
{
	// enter
	if st.interface_state != .inventory
		&& key_pressed(.TAB)
	{
		consume_key(.TAB);
		set_interface_state(.inventory);
	}
	// exit
	if st.interface_state == .inventory
		&& key_pressed(.TAB)
	{
		consume_key(.TAB);
		set_interface_state(.nil);
	}
	if st.interface_state == .inventory
		&& key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		set_interface_state(.nil);
	}
	
	// target to alpha
	if st.interface_state == .inventory
	{
		st.inventory_alpha_t = 1.0;
	}
	else
	{
		st.inventory_alpha_t = 0.0;
	}
	animate_to_target(*st.inventory_alpha, st.inventory_alpha_t, rate=30);
	
	// change hotbar from input
	{
		for 0..get_hotbar_slot_count()-1
		{
			if key_pressed(xx (#char "1" + it))
			{
				st.hot_slot = it;
			}
		}
		
	}
	
	if st.inventory_alpha != 0.0
	{
		st.show_cursor = true;
		push_opacity(st.inventory_alpha);
		
		// defaults / config
		bg_col := BLACK;
		fill_col := WHITE;
		push_fill_col(fill_col);
		push_bg_col(bg_col);
		push_text_col(fill_col);
		
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_fill_col(xyzw(1, 1, 1, 0.4));
		set_next_floating_x(20);
		set_next_floating_y(-20);
		set_next_child_layout_axis(.X);
		bg_box := make_box(BoxFlags.draw_fill | .draw_border | .floating | .clickable, "inv_bg");
		push_parent(bg_box);
		padding(em(0.2));
		
		// spacer(em(0.5));
		// set_next_font_size(get_font_size() * 2);
		// set_next_font(FONT_SUB);
		// set_next_pref_width(text_dim());
		// label("Equipment");
		// spacer(em(0.5));
		
		box_size := em(2);
		
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		auto_column();
		padding(em(0.2));
		
		push_text_col(BLACK);
		push_font(FONT_MAIN);
		push_font_size(font_size_pct(1.5));
		push_text_justify_x(.center);
		
		// equipment will be a seperate upgrade list of items?
		// like minecraft but without the slots
		
		// hotbar
		{
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			auto_row();
			for 0..get_hotbar_slot_count()-1
			{
				if it != 0 then spacer(em(0.1));
				
				slot_active := st.hot_slot == it;
				
				set_next_pref_height(box_size);
				set_next_pref_width(box_size);
				set_next_border_col(BLACK);
				if slot_active then set_next_fill_col(rbg_helper(237, 158, 104));
				slot := make_box(BoxFlags.draw_fill | .clickable | .draw_hot_effects | .draw_active_effects , tprint("hotbar_slot_%", it));
				sig := signal_from_box(slot);
				
				en := entity_from_handle(st.hotbar_slots[it]);
				
				if is_valid(en)
				{
					set_next_flags(BoxFlags.skip_layout);
					icon(en.sprite_id, tprint("hotbar_slot_icon_%", it), box_size, 0.1, 0.1);
				}
			}
		}
		
		// inventory
		{
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));	
			auto_row();
			spacer(em(0.2));
			
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));	
			auto_column();
			
			total_weight : int;
			for * stored_handle : st.stored_items
			{
				en := entity_from_handle(stored_handle);
				if !is_valid(en) then continue;
				
				if total_weight == 0 then spacer(em(0.5));
				
				item := get_item(en.item_id);
				
				weight_count := item.weight * en.item_count;
				total_weight += weight_count;
				
				{
					set_next_pref_height(size_by_children(1));
					set_next_pref_width(size_by_children(1));	
					auto_row();
					
					set_next_pref_width(box_size);
					set_next_pref_height(box_size);
					set_next_font_size(font_size_pct(1.3));
					label(tprint("%##weight_count_%", weight_count, en.id));
					
					set_next_fill_col(xyzw(0.5, 0.5, 0.5, 0.7));
					set_next_flags(BoxFlags.draw_fill | .clickable | .draw_hot_effects | .draw_active_effects);
					box := icon(en.sprite_id, tprint("inventory_slot_%", it_index), box_size, 0.1, 0.1);
					sig := signal_from_box(box);
					if sig.pressed
					{
						st.mouse_held_item = stored_handle;
					}
					
					if !has_prop(en.props, .unstackable)
					{
						set_next_text_justify_y(.bottom);
						set_next_pref_width(box_size);
						set_next_pref_height(box_size);
						label(tprint("x%##count_%", en.item_count, en.id));
					}
				}
				
				spacer(em(0.1));
			}
			
			if total_weight > 0
			{
				set_next_pref_width(pct_parent(1, 0));
				label("% / %##total_inv_weight", total_weight, get_max_weight());
			}
		}
		
		bg_box_sig := signal_from_box(bg_box);
		
		// drop held mouse item
		{
			en := entity_from_handle(st.mouse_held_item);
			if is_valid(en) && key_pressed(.MOUSE_BUTTON_LEFT)
			{
				consume_key(.MOUSE_BUTTON_LEFT);
				
				// find slot
				slot : *EntityHandle;
				for * st.stored_items
				{
					if entity_from_handle(it) == en
					{
						slot = it;
						break;
					}
				}
				assert(slot != null, "Couldn't find held item in inventory?");
				
				merge_props(*en.props, world_item_props);
				en.rel_pos = st.player.rel_pos + xy(0, 14);
				en.velocity.x = st.player.x_dir * 100.0;
				
				<<slot = .{};
				st.mouse_held_item = .{};
			}
		}
		
		// render mouse item
		{
			mouse_held_item := entity_from_handle(st.mouse_held_item);
			if is_valid(mouse_held_item)
			{
				pos := st.mouse_pos - xy(0, xx st.window_h) - xy(box_size.value, -box_size.value);
				set_next_floating_x(pos.x);
				set_next_floating_y(pos.y);
				set_next_flags(BoxFlags.floating | .skip_layout);
				set_next_pref_height(size_by_children(1));
				set_next_pref_width(size_by_children(1));
				auto_column();
				
				icon(mouse_held_item.sprite_id, "mouse_item", box_size);
				
				if !bg_box_sig.contains
				{
					set_next_font_size(font_size_pct(1));
					set_next_text_col(WHITE);
					label("drop");
				}
			}
		}
	}
}

has_equipped_item_prop :: (prop : EntityProps) -> bool, *Entity
{
	for st.stored_items
	{
		en := entity_from_handle(it);
		if !is_valid(en) then continue;
		item := get_item(en.item_id);
		if has_prop(item.props, prop) then return true, en;
	}
	return false, *nil_entity;
}

//
// :BUILDING
//

building_ui :: ()
{
	held_entity := get_held_entity();
	
	// enter build menu
	if st.interface_state != .build_menu
		&& key_pressed(#char "C")
	{
		consume_key(#char "C");
		set_interface_state(.build_menu);
	}
	// exit
	if st.interface_state == .build_menu
		&& key_pressed(#char "C")
	{
		consume_key(#char "C");
		set_interface_state(.nil);
	}
	if st.interface_state == .build_menu
		&& key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		set_interface_state(.nil);
	}
	
	// :crafting
	// build menu ui
	if st.interface_state == .build_menu
	{
		st.show_cursor = true;
		st.disable_player_input = true;
		
		// defaults / config
		ratio := 0.7;
		height := px(st.window_h * st.debug_config.ui_height_scale);
		width := px(height.value * ratio);
		bg_col := rbg_helper(162, 137, 106);
		main_col := WHITE;
		accent_col := rbg_helper(33, 33, 100);
		push_fill_col(bg_col);
		push_text_col(main_col);
		push_text_justify_x(.center);
		
		// page backdrop
		set_next_pref_height(height);
		set_next_pref_width(width);
		set_next_flags(.floating);
		page_backdrop := make_box(BoxFlags.draw_fill, "");
		push_parent(page_backdrop);
		
		padding_xy(px(10));
		
		set_next_font_size(st.debug_config.ui_font_size * 2);
		set_next_text_justify_x(.center);
		label("Crafting");
		spacer(em(0.5));
		
		// list off the building items available
		push_font(FONT_SUB);
		for st.unlocked_recipes
		{
			if it == 0 then continue;
			spacer(em(0.2));
			
			item := get_item(it);
			
			set_next_child_layout_axis(.X);
			box := make_box(BoxFlags.draw_fill | .draw_border | .clickable | .draw_hot_effects | .draw_active_effects, tprint("%##selector_box", item.name));
			box_sig := signal_from_box(box);
			push_parent(box);
			
			// enter build mode with one of them upon click
			if box_sig.clicked
			{
				st.selected_structure = xx it_index;
				set_interface_state(.build_mode);
			}
			
			//icon(struc.sprite, tprint("%##icon", struc.name), em(2));
			
			auto_column();
			padding(pct_parent(1, 0));
			set_next_text_justify_x(.left);
			lbl := label("%", item.name);
		}
	}
}

build_mode :: ()
{
	if is_state_exit(.build_mode)
	{
		placing := entity_from_handle(st.placing_blueprint);
		if is_valid(placing)
		{
			placing.marked_for_destroy = true;
		}
	}
	
	if st.interface_state == .build_mode
	{
		if is_state_entry(.build_mode)
		{
			assert(st.selected_structure != 0, "Entered build mode without a selected structure?");
			
			st.selected_structure;
			en := create_blueprint(st.selected_structure);
			st.placing_blueprint = handle_from_entity(en);
		}
		
		st.show_cursor = true;
		
		place_en := entity_from_handle(st.placing_blueprint);
		assert(is_valid(place_en));
		place_en.rel_pos.x = mouse_pos_in_world().x;
		
		if gsf.wheel_delta
		{
			place_en.x_dir *= -1;
		}
		
		// click to place
		if key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			set_interface_state(.nil);
			st.placing_blueprint = .{};
			st.selected_structure = 0;
		}
	}
}

create_blueprint :: (id: ItemID) -> *Entity
{
	struc := get_item(id);
	en := create_entity();
	add_props(*en.props, .render_sprite, .blueprint, .interactable, .collision_query);
	en.item_id = id;
	en.z_layer = LAYER_STRUCTURES;
	
	array_copy(en.remaining_items, struc.recipe);
	for * en.remaining_items it.amount = 0;
	
	sprite := get_sprite(get_display_sprite_id(struc));
	entity_set_sprite(en, sprite);
	en.collision_rect = rect_from_sprite(sprite.id);
	return en;
}

blueprint_update :: ()
{
	for * en: st.entities if is_valid(en) && has_prop(en.props, .blueprint)
	{
		/*
		element_count := 0;
		for en.remaining_items
		{
			if it.item == 0 then element_count += 1;
		}
		*/
		
		en.col = xyzw(0.5, 0.5, 1.0, 0.85);
		//debug_rect(get_collision_rect(en), 1);
		
	}
}

on_build :: (self: *Entity)
{
	item := get_item(self.item_id);
	
	// todo
}

// :particle system

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
	st.particle_cursor = (st.particle_cursor + 1) % st.particles.count;
	p := *st.particles[st.particle_cursor];
	<<p = .{};
	p.flags |= .valid;
	return p;
}

create_emitter :: (pos: Vector2, kind: EmitterKind) -> *Entity
{
	en := create_entity();
	add_props(*en.props, .particle_emitter, .render_sprite);
	en.rel_pos = pos;
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
}

update_particle_system :: ()
{
	push_random_seed(get_chaos_seed());
	
	// emitters
	for * en : st.world.entities if is_valid(en) && has_prop(en.props, .particle_emitter)
	{
		if en.emitter ==
		{
			case;
			log("Emitter not selected.");
			
			case .death_poof;
			en.marked_for_destroy = true;
			for 0..2
			{
				x_offset := (it - 1) * 10.0;
				p := new_particle();
				p.pos = en.rel_pos + xy(x_offset, random_get_within_range(0, 3));
				p.col = WHITE;
				p.flags |= ParticleFlags.animate_sprite;
				p.vel = xy(random_get_within_range(-5, 5), random_get_within_range(0, 2));
				p.sprite = "p_poof";
				p.z_layer = LAYER_ENTITY_VFX;
				p.play_rate = random_get_within_range(4, 15);
			}
			
			case .jump_dust;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.rel_pos;
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.vel = xy(0, 40);
			p.sprite = "p_upwards";
			p.z_layer = LAYER_ENTITY_VFX;
			p.pivot = .bottom_center;
			
			case .landing_dust;
			en.marked_for_destroy = true;
			p := new_particle();
			p.pos = en.rel_pos;
			p.vel = en.velocity;
			p.col = WHITE;
			p.flags |= ParticleFlags.animate_sprite;
			p.sprite = "p_ground";
			p.z_layer = LAYER_ENTITY_VFX;
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
	for * p : st.particles
	{
		// integrate
		p.pos += p.vel * delta_t;
		
		// tick down time
		if p.time_left != 0
		{
			p.time_left -= delta_t;
			if p.time_left < 0
			{
				<<p = .{};
			}
		}
		
		// animate
		if p.flags & .animate_sprite
		{
			sprite := get_sprite(p.sprite);
			
			// get default playrate from sprite if we don't have one specified
			if p.play_rate == 0 then p.play_rate = sprite.play_rate;
			
			// start of new frame
			if p.time_til_next_frame == 0
				&& !(p.flags & .paused)
			{
				p.time_til_next_frame = 1.0 / p.play_rate;
			}
			
			// advance timer
			if tick_timer(*p.time_til_next_frame)
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
				push_quad(make_range(xy(1, 1), shifter=p.pos), col=p.col, trs=p.trs, z_layer=p.z_layer);
			}
			else
			{
				sprite := get_sprite(p.sprite);
				uv_rect := sprite.rect;
				uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * p.animation_frame, 0.0));
				uv_rect.min.x /= sprite.width;
				uv_rect.min.y /= sprite.height;
				uv_rect.max.x /= sprite.width;
				uv_rect.max.y /= sprite.height;
				
				rect: Range2;
				rect.max = range_size(sprite.rect);
				rect = range_pivot(rect, p.pivot);
				
				push_quad(rect, tex=sprite, uv_rect=uv_rect, z_layer=p.z_layer, trs=merge_transform(p.trs, make_transform(p.pos)));
			}
		}
	}
}