/*

Defend your fire.
- build a base around your fire
- each night a wave of enemies come
- defeat all of them, night is over
- collect essence & crafting materials from enemies
- feed essence to fire to grow stronger
- basic stat point upgrades for each essence fed
	- vitality, mana, speed, base building range, respawn time, etc
- game over when enemies destroy your fire

*/

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
	resources: [#run enum_count(ResourceID)]ArcResource;
	should_quit: bool;
	window: Window_Type;
	window_w : s32 = WINDOW_X;
	window_h: s32 = WINDOW_Y;
	saved_window: Saved_Window_Info;
	is_fullscreen := false;
	mouse_pos: Vector2;
	
	refresh_rate: float;
	delta_t: float = 1.0 / 60.0;
	last_frame_time: float64;
	
		// gotta have the derivatives for some finicky windows reason
	_cursor_confied: bool = false; 
	_cursor_showing: bool = true;
	// these are what you set to determine the state
	confine_cursor: bool = false;
	show_cursor: bool = true;
	key_down: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
	
	frame_count: u64;
	
	app_mode: AppMode;
	entering_app_mode: AppMode;
	exiting_app_mode: AppMode;
	main_menu_alpha: float;
	main_menu_alpha_t: float;
	world_alpha: float;
	world_alpha_t: float;
	
	camera: Camera2;
	camera_trauma: float;
	
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
	crafting_menu_alpha: float;
	crafting_menu_alpha_t: float;
	game_over_alpha: float;
	game_over_alpha_t: float;
	
	mouse_held_item: EntityHandle;
	
	PAGE_COUNT :: 3; // survival book
	sb_page: int = 0;
	sb_page_opacity: [PAGE_COUNT]float;
	
	// big ol sloppie dump
	// ..
	
	frame : FrameStorage; // gets zeroed each frame
	FrameStorage :: struct
	{
		key_pressed: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
		key_released: [Input.Key_Code.MOUSE_WHEEL_DOWN + 1] bool;
		wheel_delta: s32;
		mouse_delta: Vector2;
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
	
	// cycle / wave stuff
	is_wave_active: bool;
	wave_start: bool;
	wave_dir: enum { left; right; both; };
	days_survived: int;
	day_timer: float;
	darkness_alpha: float;
	darkness_alpha_t: float;
	riser_triggered: bool;
	day_start: bool = true;
	
	//
	// PLAYER state stuff
	//
	selected_structure: ItemID;
	placing_blueprint: EntityHandle;
	
	unlocked_recipes: [AppState.resources.count]bool;
	known_items: [AppState.resources.count]bool;
	
	hovered_interactable: EntityHandle;
	
	respawn_timer: float;
}

//
// 
//

main :: ()
{
	local_app_init(); defer local_app_shutdown();
	
	while !app.should_quit
	{
		context.allocator = frame_allocator;
		
		sound_update();
		
		ui_start();
		push_fill_col(GRAY);
		push_text_col(WHITE);
		push_border_col(WHITE);
		push_font(FONT_SUB);
		push_font_size(app.debug_config.ui_font_size);
		push_text_edge_pad(10);
		push_pref_width(pct_parent(1.0, 0.0));
		push_pref_height(em(1.5));
		
		local_app_update();
		
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
		
		// :update
		if g_world.simulating
		{
			app.world.time_elapsed += delta_t_scaled();
			world_cycle_update();
			
			respawn_ui();
			display_notifications();
			inventory_ui();
			survival_book_ui();
			
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
			ui_crafting_menu();
			build_mode(); // is part of user interaction?
			in_game_user_interaction();
			
			// UPDATE
			{
				update_corefire(g_world);
			}
			// these other functions aren't state sandboxed yet, still using globals
			update_items();
			update_torches();
			update_campfires();
			animate_sprites();
			player_update();
			enemy_update();
			physics_update();
			update_trees();
			recieve_damage();
			update_particle_system();
			update_point_lights();
			
			// unlock recipe of picked up items
			#if DEBUG_UNLOCK_RECIPES 
			{
				for * item_res : app.resources if item_res.flags & .item && item_res.recipe.count != 0
				{
					g_world.unlocked_recipes[item_res.id] = true;
				}
			}
			for event: g_world.events_this_frame if event.kind == .pickup
			{
				// add to known item list
				en := entity_from_handle(event.entity);
				en.item_id;
				if !en.item_id then continue;
				g_world.known_items[en.item_id] = true;
				
				for * item_res : app.resources if item_res.flags & .item
				{
					if item_res.recipe.count == 0 then continue;
					
					all_ingredients_known := true;
					for item_res.recipe
					{
						if it.id == .nil then break;
						all_ingredients_known = all_ingredients_known && g_world.known_items[it.id];
					}
					
					if all_ingredients_known
					{
						was_just_unlocked := g_world.unlocked_recipes[item_res.id] == false;
						g_world.unlocked_recipes[item_res.id] = true;
						
						if was_just_unlocked
						{
							create_notification(tprint("% recipe unlocked", get_display_name(item_res)));
						}
					}
				}
			}
			
			// destroy entities that're marked
			for * g_world.entities if is_valid(it) && it.marked_for_destroy
			{
				entity_destroy_immediate(it);
			}

			// camera stuff
			{
				player := get_player();
				
				app.camera.position = xy(0);
				
				// todo - some kinda soft camera target stuff
				
				if player.health != 0
				{
					app.camera.position.x = -get_player().pos.x;
				}
				
				app.camera.position += CAMERA_OFFSET;
				//app.camera.target_zoom = window_h / scene_height * ifx k_key_debug then 1.4 else 1.0;
				
				// decrease trauma across time
				app.camera_trauma -= delta_t_scaled();
				app.camera_trauma = clamp_bottom(app.camera_trauma, 0);

				#if TOOLING
				{
					if (app.frame.wheel_delta) && key_down(.ALT)
					{
						app.camera.target_zoom += app.frame.wheel_delta / 5.0;
						app.camera.target_zoom = clamp(app.camera.target_zoom, 1, 20.0);
					}
				}

				animate_to_target(*app.camera.zoom, app.camera.target_zoom, delta_t_scaled());
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
		
		ui_finish_and_render();
		render_world_from_state(g_world);

		// clear game's frame state
		app.frame = .{};
		
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

		app.frame_count += 1;
	}
}

local_app_init :: ()
{
	init_state_pointers();
	
	// windows setup
	Windows.SetProcessDPIAware();
	Windows.timeBeginPeriod(1);
	// this is kinda sketch lol, ideally I'd just like to tack it into the Windows namespace, but idk
	// how to do that without modifying Windows.jai
	WindowsX.FreeConsole();
	
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
	
	app.refresh_rate = WindowsX.get_refresh_rate();
}

local_app_shutdown :: ()
{
	sound_shutdown();
}

local_app_update :: ()
{
	reset_temporary_storage();
	
	// update delta_t
	{
		current_time := get_time();
		if (app.last_frame_time)
		{
			if !VSYNC
			{
				app.delta_t = cast(float) (current_time - app.last_frame_time);
			}
		}
		app.last_frame_time = current_time;
	}
	
	if VSYNC then app.delta_t = 1.0/app.refresh_rate;
	
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
		
		hovering_playspace := WindowsX.PtInRect(*play_window, cursor_pos);
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
	
	
	#if DEBUG // :debug
	{
		fun_val += app.frame.mouse_delta.x / 100;
		
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
		}
		
		// L key debug
		if key_pressed(#char "L")
		{
			app.camera_trauma += 0.4;
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
				
				g_world.day_timer = slider_float(g_world.day_timer, 0, DAY_LENGTH, "day/night cycle");
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
		}
	}
}

// ----- the :chaos waterline ----- //

get_occupied_world_space :: inline (en: Entity) -> Range1
{
	return range_shift(en.occupied_space, en.pos.x);
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

delta_t :: inline () -> float
{
	return app.delta_t;
}

delta_t_scaled :: inline () -> float
{
	return g_world.time_scale * app.delta_t;
}

ui_crafting_menu :: inline ()
{
	// enter menu
	if app.interface_mode != .crafting_menu
		&& key_pressed(#char "C")
	{
		consume_key(#char "C");
		set_interface_mode(.crafting_menu);
	}
	// exit
	if app.interface_mode == .crafting_menu
		&& key_pressed(#char "C")
	{
		consume_key(#char "C");
		set_interface_mode(.nil);
	}
	if app.interface_mode == .crafting_menu
		&& key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		set_interface_mode(.nil);
	}
	
	// animate alpha
	if app.interface_mode == .crafting_menu
	{
		app.crafting_menu_alpha_t = 1.0;
	}
	else
	{
		app.crafting_menu_alpha_t = 0.0;
	}
	animate_to_target(*app.crafting_menu_alpha, app.crafting_menu_alpha_t, delta_t(), rate=UI_ANIMATE_RATE);
	
	is_active := app.crafting_menu_alpha_t == 1.0;
	if is_active
	{
		app.show_cursor = true;
		//app.disable_player_input = true;
	}
	push_flags(ifx !is_active then .disable_interaction);
	push_opacity(app.crafting_menu_alpha);
	
	// :crafting
	if app.crafting_menu_alpha != 0.0
	{
		ratio := 0.7;
		height := px(app.window_h * app.debug_config.ui_height_scale);
		width := px(height.value * ratio);
		
		// defaults
		push_bg_col(COL_UI_BG);
		push_fill_col(COL_UI_FILL);
		push_text_col(COL_UI_TEXT);
		push_border_col(COL_UI_BORDERS);
		push_text_justify_x(.center);
		
		//
		set_next_pref_height(px(xx app.window_h));
		set_next_pref_width(px(xx app.window_w));
		set_next_child_layout_axis(.Y);
		set_next_floating_x(10);
		push_parent(make_box(.floating, ""));
		
		spacer(pct_parent(1, 0));
		
		set_next_pref_height(height);
		set_next_pref_width(width);
		page_backdrop := make_box(.draw_bg | .draw_border, "");
		
		spacer(pct_parent(1, 0));
		
		push_parent(page_backdrop);
		
		padding_xy(px(10));
		
		set_next_font_size(font_size_pct(2.0));
		set_next_text_justify_x(.center);
		label("Crafting");
		spacer(em(0.5));
		
		// list off the building items available
		push_font(FONT_SUB);
		for g_world.unlocked_recipes
		{
			height:= em(3);
			
			if !it then continue;
			spacer(em(0.2));
			
			item_id : ItemID = xx it_index;
			item := get_item(item_id);
			
			set_next_pref_height(size_by_children(1));
			set_next_child_layout_axis(.X);
			box := make_box(BoxFlags.draw_bg | .draw_border | .clickable | .draw_hot_effects | .draw_active_effects, tprint("%##selector_box", item.name));
			box_sig := signal_from_box(box);
			push_parent(box);
			
			// enter build mode with one of them upon click
			if box_sig.clicked
			{
				g_world.selected_structure = item_id;
				set_interface_mode(.build_mode);
			}
			
			icon(get_display_sprite_id(item), "", height, vertical_pad_pct= 0.1, horizontal_pad_pct= 0.1);
			
			set_next_pref_height(height);
			auto_column();
			padding(pct_parent(1, 0));
			set_next_text_justify_x(.left);
			set_next_font_size(font_size_pct(1.2));
			set_next_pref_height(em(1, 1));
			lbl := label("%", item.name);
		}
	}
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
		if en.id == world.hovered_interactable.entity_id
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
		push_quad_flags(0); // removes the default .SKIP_CAMERA_TRANSFORM, kinda sketch lol
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
	player := entity_from_handle(world.player_handle, world);
	
	// red vignette
	alpha := 1-float_alpha(xx player.health, 1, xx player.max_health);
	alpha *= 0.8;
	draw_rect(make_range(xy(xx app.window_w, xx app.window_h)), texture=get_texture(.red_vignette), col=xyzw(1, 1, 1, alpha), z_layer=Z_UI-0.5, flags=.SKIP_CAMERA_TRANSFORM);
	
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
	player := entity_from_handle(world.player_handle, world);
	hovered_en := entity_from_handle(world.hovered_interactable, world);
	
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
		
		push_z_layer(en.z_layer);
		push_parent(app.ui.frame.root); // this makes us skip past the usual root :screen_space
		push_quad_flags(0); // removes the default .SKIP_CAMERA_TRANSFORM, kinda sketch lol
		set_next_floating_x(en.pos.x);
		set_next_floating_y(en.pos.y + 30);

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

// This function should not alter the world state, merely render what is being shown
render_world_from_state :: (world: WorldState)
{
	// setup transform matricies
	view_matrix : Matrix4 = Matrix4_Identity;
	{
		// shake
		cam_shake := clamp_top(pow(app.camera_trauma, 3), 1);
		
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
	}
	
	//
	// :render
	//
	
	#if RENDER_BACKGROUND
	{
		bg_parallax_offset := get_actual_camera_pos() * -1.0;
		bg_size := get_sprite_size(.sky);
		pixel_zoom := app.window_w / bg_size.x;
		
		// sky
		bg_rect := make_range(.{}, xy(xx app.window_w, xx app.window_h), pivot=.center_center);
		draw_rect(bg_rect, col=rbg_helper(49, 161, 227), z_layer=Z_BACKDROP, flags=.SKIP_CAMERA_TRANSFORM);
		draw_rect(sprite_id=.sky, sprite_pivot=.center_center, z_layer=Z_BACKDROP-0.5, trs=make_transform(bg_parallax_offset + xy(0, 160) + get_sprite(.sky).offset));
		
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
		draw_rect(make_range(xy(xx app.window_w, 5000), pivot=.top_center, shifter=xy(0, -20)), col=hex_to_rgba(GROUND_COL), z_layer=Z_GROUND+0.1, trs=make_transform(bg_parallax_offset));
	}
	
	// render generic entities
	for * en : world.entities
		if is_visible(en) && has_prop(en.props, .render_sprite)
	{
		// if en == get_player() || en == get_held_entity() then continue;
		
		draw_generic_entity(en);
	}
	
	// custom_render_player();
	
	//
	actually_render();
	
	// reset render state
	reset(*render_st.quads);
	render_st.cbuffer = .{};
	render_st.layer_cbuffer = .{};
}

draw_generic_entity :: inline (en: Entity)
{
	local_trs: Transform2;
	render_trs: Transform2;
	
	sprite := get_sprite(en.sprite_id);
	texture := texture_from_sprite(sprite);
	
	// grab the UV coords, apply animation frame as well
	uv_rect := sprite.rect;
	uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * en.animation_frame, 0.0));
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
	if en.parallax.x != 0 then render_trs.translate.x -= get_actual_camera_pos().x * en.parallax.x;
	
	col := en.col;
	if has_prop(en.props, .blueprint)
	{
		col *= xyzw(0.5, 0.5, 1.0, 0.85);
	}
	col *= en.frame.colour_multiplier;
		
	trs:= merge_transform(local_trs, render_trs);
	quad := draw_rect(sprite_id=sprite.id, sprite_pivot=.bottom_center, z_layer=en.z_layer, col=col, uv_rect=uv_rect, flip_x=flip_x, trs=trs);
	quad.white_override = en.white_override;
}

custom_render_player :: ()
{
	
	// setup texture / RTV
	if render_st.player_rtv == null
	{
		td: D3D11_TEXTURE2D_DESC;
		td.Width = 128;
		td.Height = 128;
		td.MipLevels = 1;
		td.ArraySize = 1;
		td.Format = .R8G8B8A8_UNORM;
		td.SampleDesc.Count = 1;
		td.Usage = .DEFAULT;
		td.BindFlags = .SHADER_RESOURCE | .RENDER_TARGET;
		ID3D11Device_CreateTexture2D(render_st.d3d_device, *td, null, *render_st.player_tex);
		
		rtv_desc: D3D11_RENDER_TARGET_VIEW_DESC;
		rtv_desc.Format = td.Format;
		rtv_desc.ViewDimension = .TEXTURE2D;
		ID3D11Device_CreateRenderTargetView(render_st.d3d_device, render_st.player_tex, *rtv_desc, *render_st.player_rtv);
	}
	
	// TODO - continue dis
	// basically render the player into this texture rtv
	// then use that texture handle to push into the main pipeline
	
	
}

actually_render :: () #expand
{
	hwnd: HWND = app.window;
	window_w, window_h := get_window_rect();
	hr: HRESULT;
	
	// NOTE - I've got some kinda stateful bug going on with the textures lol. Clearing it seems to fix hehe - randy
	// will probs need to crack down on this for @speed ?
	ID3D11DeviceContext_ClearState(render_st.d3d_context);
	
	// resize buffer & create RTV
	if render_st.render_target_view == null
		|| window_w != render_st.current_render_w || window_h != render_st.current_render_h
	{
		if render_st.render_target_view
		{
			// yeet exisitng rtv
			IUnknown_Release(render_st.render_target_view);
			render_st.render_target_view = null;
		}
		
		// new window for a non-zero size
		if window_w != 0 && window_h != 0
		{
			hr = IDXGISwapChain_ResizeBuffers(render_st.swap_chain, 0, xx window_w, xx window_h, .UNKNOWN, 0);
			assert(SUCCEEDED(hr), tprint("ResizeBuffers failed %", hr));
			
			// create RenderTarget view for new backbuffer texture
			back_buffer: *ID3D11Texture2D;
			IDXGISwapChain_GetBuffer(render_st.swap_chain, 0, *uid(ID3D11Texture2D_UUID), xx *back_buffer);
			assert(SUCCEEDED(hr), tprint("GetBuffer failed %", hr));
			defer IUnknown_Release(back_buffer);
			
			hr = ID3D11Device_CreateRenderTargetView(render_st.d3d_device, back_buffer, null, *render_st.render_target_view); 
			assert(SUCCEEDED(hr), tprint("CreateRenderTargetView failed: %", hr));
			
			render_st.current_render_w = window_w;
			render_st.current_render_h = window_h;
		}
	}
	
	if render_st.render_target_view
	{
		ID3D11DeviceContext_OMSetRenderTargets(render_st.d3d_context, 1, *render_st.render_target_view, null); 

		// VIEWPORT
		vp: D3D11_VIEWPORT; 
		vp.Width = xx window_w; 
		vp.Height = xx window_h; 
		vp.MinDepth = 0.0;
		vp.MaxDepth = 1.0;
		vp.TopLeftX = 0;
		vp.TopLeftY = 0;
		ID3D11DeviceContext_RSSetViewports(render_st.d3d_context, 1, *vp);

		// Clear the back buffer
		ID3D11DeviceContext_ClearRenderTargetView(render_st.d3d_context, render_st.render_target_view, *CLEAR_COL.component);

		render_st.active_texture = get_texture(.blank_tex);
	}
	else
	{
		return;
	}
	
	// apply transform to the lights
	cbuff := get_global_const_buff();
	for 0..cbuff.light_count-1
	{
		light := *cbuff.lights[it];
		point := xyzw(light.x, light.y, 0, 1);
		point = `view_matrix * point;
		// shift into screen pixel space
		point.x = (point.x / cast(float)app.window_w + 0.5) * cast(float)app.window_w;
		point.y = (point.y / cast(float)app.window_h - 0.5) * -cast(float)app.window_h;
		
		light.xy = point.xy;
		light.z *= app.camera.zoom;
		
		//log("% -> %", light, cbuff.lights[it].xy);
	}
	
	// fill in some other cbuffer values
	cbuff.window_size = .{xx window_w, xx window_h};
	cbuff.debug_val = key_down(#char "H");
	cbuff.cam_zoom = app.camera.zoom;
	cbuff.params.x = g_world.darkness_alpha;
	
	// CONSTANT BUFFER uplaod
	{
		res: D3D11_MAPPED_SUBRESOURCE;
		ID3D11DeviceContext_Map(render_st.d3d_context, render_st.const_buffer_resource, 0, .WRITE_DISCARD, 0, *res);
		memcpy(res.pData, *render_st.cbuffer, size_of(GlobalConstBuffer));
		ID3D11DeviceContext_Unmap(render_st.d3d_context, render_st.const_buffer_resource, 0);
	}

	// sort the quads by z_layer
	sorted_quads: [..] *Quad;
	sorted_quads.allocator = temp;
	next_quad := render_st.quads.first;
	while next_quad
	{
		array_add(*sorted_quads, next_quad);
		next_quad = next_quad.next;
	}
	bubble_sort(sorted_quads, (a, b) => compare_floats(b.z_layer, a.z_layer));
	
	// fill & flush verticies from sorted quads
	verticies: [..]QuadVertex;
	verticies.allocator = temp;
	for sorted_quads
	{
		
		// flush the existing vertices if we've got a new tex or cbuf
		new_texture := it.texture != render_st.active_texture;
		new_cbuff := !compare_memory(it.layer_cbuffer, render_st.layer_cbuffer);
		if new_texture || new_cbuff
		{
			flush_verticies(*verticies);
			array_reset_keeping_memory(*verticies);
		}
		if new_texture then render_st.active_texture = it.texture;
		if new_cbuff then render_st.layer_cbuffer = it.layer_cbuffer;
		
		// apply view & proj matrix
		projection_matrix := get_cardinal_projection();
		view := Matrix4_Identity;
		if !(it.flags & .SKIP_CAMERA_TRANSFORM)
		{
			view = `view_matrix;
		}
		it.p0 = projection_matrix * view * it.p0;
		// it.p0.z = 0;
		it.p1 = projection_matrix * view * it.p1;
		// it.p1.z = 0;
		it.p2 = projection_matrix * view * it.p2;
		// it.p2.z = 0;
		it.p3 = projection_matrix * view * it.p3;
		// it.p3.z = 0;

		// dump verticies
		vert := array_add(*verticies);
		vert.pos = it.p0.xyz;
		vert.uv = it.uv0;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p2.xyz;
		vert.uv = it.uv2;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p1.xyz;
		vert.uv = it.uv1;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p0.xyz;
		vert.uv = it.uv0;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p3.xyz;
		vert.uv = it.uv3;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p2.xyz;
		vert.uv = it.uv2;
		vert.col = it.col;
		vert.white_override = it.white_override;
	}
	flush_verticies(*verticies);

	hr = IDXGISwapChain_Present(render_st.swap_chain, xx ifx VSYNC then 1 else 0, 0); 
	assert(SUCCEEDED(hr), tprint("Present failed: %", hr));
}

flush_verticies :: (quad_verticies: *[..]QuadVertex)
{
	if quad_verticies.count == 0 then return;

	using render_st;
	hwnd: HWND = app.window;
	window_w, window_h := get_window_rect();

	// log("flushed with %", active_texture);

	// QUAD RENDER
	
	// copy vert data to scratch buffer
	sub_res: D3D11_MAPPED_SUBRESOURCE;
	ID3D11DeviceContext_Map(d3d_context, scratch_buffer, 0, .WRITE_DISCARD, 0, *sub_res);
	memcpy(sub_res.pData, quad_verticies.data, size_of(QuadVertex) * quad_verticies.count);
	ID3D11DeviceContext_Unmap(d3d_context, scratch_buffer, 0);

	// layer cbuffer upload
	{
		res: D3D11_MAPPED_SUBRESOURCE;
		ID3D11DeviceContext_Map(d3d_context, layer_cbuffer_resource, 0, .WRITE_DISCARD, 0, *res);
		memcpy(res.pData, *render_st.layer_cbuffer, size_of(LayerConstBuffer));
		ID3D11DeviceContext_Unmap(d3d_context, layer_cbuffer_resource, 0);
	}

	// rasterizer stage
	viewport: D3D11_VIEWPORT;
	viewport.Width = xx window_w;
	viewport.Height = xx window_h;
	viewport.MaxDepth = 1.0;
	ID3D11DeviceContext_RSSetViewports(d3d_context, 1, *viewport);
	
	ID3D11DeviceContext_RSSetState(d3d_context, rasterizer);

	// INPUT ASSEMBLER
	ID3D11DeviceContext_IASetInputLayout(d3d_context, ilay_quad);
	ID3D11DeviceContext_IASetPrimitiveTopology(d3d_context, .TRIANGLELIST);
	stride: u32 = size_of(QuadVertex);
	offset: u32 = 0;
	ID3D11DeviceContext_IASetVertexBuffers(d3d_context, 0, 1, *scratch_buffer, *stride, *offset);

	// scissorrr
	scissor_rect: D3D11_RECT;
	scissor_rect.right = window_w;
	scissor_rect.bottom = window_h;
	// todo - actually do this?

	// VSHADER
	ID3D11DeviceContext_VSSetShader(d3d_context, vertex_shader, null, 0);
	ID3D11DeviceContext_VSSetConstantBuffers(d3d_context, 0, 1, *const_buffer_resource);
	ID3D11DeviceContext_VSSetConstantBuffers(d3d_context, 1, 1, *layer_cbuffer_resource);

	// PSHADER
	ID3D11DeviceContext_PSSetSamplers(d3d_context, 0, 1, *sampler);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 0, 1, *active_texture.view);
	ID3D11DeviceContext_PSSetShader(d3d_context, pixel_shader, null, 0); 
	ID3D11DeviceContext_PSSetConstantBuffers(d3d_context, 0, 1, *const_buffer_resource);
	ID3D11DeviceContext_PSSetConstantBuffers(d3d_context, 1, 1, *layer_cbuffer_resource);
	// lut lut lut lut lut
	ID3D11DeviceContext_PSSetSamplers(d3d_context, 1, 1, *lut_sampler);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 1, 1, *get_texture(render_st.lut1).view);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 2, 1, *get_texture(render_st.lut2).view);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 3, 1, *get_texture(.fire_lut).view);

	// OUTPUT MERGER
	ID3D11DeviceContext_OMSetBlendState(d3d_context, blend_state, null, 0xffffffff);

	// DRAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAW
	ID3D11DeviceContext_Draw(d3d_context, xx quad_verticies.count, 0);
}

get_player :: inline () -> *Entity
{
	return entity_from_handle(g_world.player_handle);
}

Camera2 :: struct
{
	position: Vector2;
	zoom: float = DEFAULT_ZOOM;
	target_zoom: float = DEFAULT_ZOOM;
}

get_actual_camera_pos :: () -> Vector2
{
	return app.camera.position - CAMERA_OFFSET;
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
	ui_font_size: int = 24;
	ui_height_scale: float = 0.7;
	
	max_monster_count: int = 0;
	test_val: float;
	
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

WorldGenParams :: struct
{
	seed: u64 = 123;
	flint_interval := 20.0;
	flint_threshold := 0.7;
	persistance := 0.5;
	octaves := 4;
	freq := 1.0;
	random_offset := 10.0;
}

get_max_weight :: () -> int
{
	return BASE_WEIGHT;
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
	crafting_menu;
	build_mode;
	survival_book;
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

	random_seed(gen.seed);
	defer random_seed(get_chaos_seed());
	
	push_allocator(world_allocator);
	world_bootstrap();
	g_world.simulating = true;
	
	//
	// :g_world gen
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
	// resource gen
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
		
		if pct_chance(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.pos.x = point + random_get_within_range(-50, -20);
		}
		
		if pct_chance(0.5)
		{
			root_index += 1;
			en = create_tree_root(root_index);
			en.pos.x = point + random_get_within_range(20, 40);
		}
	}
	
	// tall grass
	point = -cast(float)world_radius;
	root_index = 0;
	while point < xx world_radius
	{
		MIN_STEP := 100.0;
		point += random_get_within_range(MIN_STEP, MIN_STEP * 2.0);
		if point > -spawn_area_radius && point < spawn_area_radius then continue;
		
		en := create_tall_grass(root_index);
		en.pos.x = point + random_get_within_range(-50, -20);
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
			
			point = starting_point + it * gen.flint_interval + random_offset;
			if point > -spawn_area_radius && point < spawn_area_radius then continue;
			
			en := create_world_item(.flint);
			en.pos.x = point;
		}
	}
}

spawn_character :: () -> *Entity
{
	// :character :player
	en := create_entity("player");
	add_props(*en.props, .rigid_body, .render_sprite, .override_death, .player);
	add_props(*en.recieve_damage_from, .monster);
	en.z_layer = Z_PLAYER;
	en.state = .idle;
	entity_set_sprite(en, "char_idle");
	en.collision_rect.max = xy(25, 50);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.max_health = DEFAULT_MAX_HEALTH;
	en.health = 3;
	return en;
}

world_bootstrap :: ()
{
	// :map
	en: *Entity;
	
	en = spawn_character();
	en.pos.x = 30;
	en.x_dir = -1;
	g_world.player_handle = handle_from_entity(en);
	player := en;
	
	en = create_entity();
	setup_corefire(en);
	g_world.corefire_handle = handle_from_entity(en);

	en = create_world_item(.flint);
	en.pos.x = -30;
	
	en = create_world_item(.wood);
	en.pos.x = -40;

	#if TESTING
	{
		
		// :gobby spawn
		// en = create_gobby();
		// en.pos.x = -100;
		// en.health = 0;
		// set_state(en, .damaged);
		
		// ground items
		//en = create_world_item("book_survival");
		//en.pos.x = -50;
		en = create_world_item(.flint_axe);
		en.pos.x = 100;
		//attempt_store_item(en);
		
		// en = create_world_item("goblin_meat");
		// en.pos.x = 10;
		// en.item_count = 4;
		//attempt_store_item(en);
		// en = create_world_item(.torch);
		// en.pos.x = 50;
		//attempt_store_item(en);
		
		// CAMPFIRE
		// en = create_entity();
		// en.pos.x = 20;
		// setup_campfire(en);
		
		en = create_world_item(.flint_sword);
		en.pos.x = 45;
		attempt_store_item(player, en);
		player.hotbar_slots[1] = handle_from_entity(en);
		player.hot_slot = 1;

		// bp wall
		//en = create_blueprint(.wood_defense_wall);
		//en.pos.x = 200;
		
		// :wall
		// en = create_wall();
		// en.pos.x = -80;
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

world_cycle_update :: ()
{
	riser_length :: 13.0;
	
	// DAY START
	if g_world.day_start
	{
		g_world.day_start = false;
		g_world.wave_dir = ifx random_bool() then .left else .right;
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
		
		v_left := ifx g_world.wave_dir == .right then 0.4 else 1.1;
		v_right := ifx g_world.wave_dir == .left then 0.4 else 1.1;
		// play_sound(.wave_start, v_left=v_left, v_right=v_right, random_spread=false);
		app.camera_trauma += 0.8;
		
		x_dir := ifx g_world.wave_dir == .left then -1.0 else 1.0;
		
		spawn_pos := x_dir * 200.0;
		for 0..g_world.days_survived
		{
			en := create_gobby();
			en.pos.x = spawn_pos;
			
			spawn_pos += x_dir * random_get_within_range(20, 100);
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
			play_sound(.wave_over, random_spread=false);
		}
	}
	else
	{
		// DAY TIME
		if tick_timer(*g_world.day_timer, delta_t_scaled())
		{
			g_world.wave_start = true;
		}
		
		#if RISER_SOUND
		{
			if !g_world.riser_triggered && g_world.day_timer < riser_length
			{
				g_world.riser_triggered = true;
				v_left := ifx g_world.wave_dir == .right then 0.4 else 1.0;
				v_right := ifx g_world.wave_dir == .left then 0.4 else 1.0;
				play_sound(.riser, random_spread=false, v_left=v_left, v_right=v_right);
			}
		}
		
		g_world.darkness_alpha_t = 1.0-float_map(g_world.day_timer, 0, riser_length * 0.75, 0, 1);
	}
	
	animate_to_target(*g_world.darkness_alpha, g_world.darkness_alpha_t, delta_t_scaled(), rate=5);
	
	render_st.lut1 = .day_lut;
	render_st.lut2 = .early_night_lut;
	render_st.cbuffer.lut_blend_alpha = g_world.darkness_alpha * 0.7;
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
		if (Input.mouse_delta_x || Input.mouse_delta_y)
		log("% %\n", Input.mouse_delta_x, Input.mouse_delta_y);
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
	valid;
	visible;
	
	render_sprite;
	draw_health_bar;
	
	rigid_body;
	static;
	attack_player;

	interactable;
	pick_up;
	harvestable;
	deconstructable;
	
	placement_obstacle;
	obstacle;
	collision_query;
	blueprint;
	generic_damage;
	manually_enter_damage;
	override_death; // have to manually handle the death within the .damaged state
	loot_drops;
	particle_emitter;
	destroy_on_complete;

	item;
	craftable;
	unstackable;
	consumable;
	blockable;
	deconstruct_tool;

	equippable;
	waist;
	
	tree;
	tree_root;
	
	big_notification;
	smol_notification;
	point_light;

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
	debug_name: string;
	props: Properties(EntityProps);
	marked_for_destroy: bool;
	archetype: ResourceID;
	
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
	render_offset: Transform2;
	render_offset_t: Transform2;
	animate_render_offset_to_target: bool;
	z_layer: float;
	col: Vector4 = WHITE;
	flip_sprite: bool; // manual switch
	parallax: Vector2;
	white_override: float; // overrides the pixel colour with white in the shader
	
	// AI
	input_axis: Vector2;
	walk_position: float;
	state_timer: float;
	idle_wait_timer: float;
	// note - DON'T MAKE A NEW AI STATE ya silly fucking goose.
	// it's a FSM for a reason. Just break it out into another state / behaviour. Or store more data if need be.
	
	// animation stuff?
	// breathe_current: float;
	// breathe_target: float;
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
	
	hit_sound: SoundID = .punch;

	// recieve_damage
	health: int = DEFAULT_MAX_HEALTH;
	max_health: int = DEFAULT_MAX_HEALTH;
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

	// player-specific
	//
	// ideally this would not be included in all entities and just tacked on at the end
	// but I'm not sure how we'd go about doing this without some dynamically allocated mem
	// which would break the clean serialistion...
	// For now we'll just put it in all entities
	//
	hotbar_slots: [9]EntityHandle;
	equipped_items: [16]EntityHandle;
	stored_items: [32]EntityHandle;
	hot_slot: int;
	is_blocking: bool;
	
	// janky frame stuff which should probs not exist?
	frame: Frame;
	last_frame: Frame;
	Frame :: struct
	{
		colour_multiplier: Vector4 = WHITE;
		did_anim_finish: bool;
		anim_frame_advance: bool;
		did_state_change: bool;
		did_land: bool;
		//x_collision_dir: s8;
		y_collision_dir: s8;
	}
}
nil_entity : Entity; // I need a way of protecting this memory from writing

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
	return entity_from_handle(handle, g_world);
}

entity_from_handle :: (handle: EntityHandle, world: WorldState) -> *Entity
{
	entity: *Entity = *world.entities[handle.index];
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
		handle.index = entity - g_world.entities.data;
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

create_entity :: (debug_name := "") -> *Entity
{
	en: *Entity;
	for * g_world.entities if !has_prop(it.props, .valid) && it_index != 0
	{
		en = *g_world.entities[it_index]; // reuse an existing invalid one
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
	
	if LOG_VERBOSE then log(tprint("% created", ifx debug_name == "" then "entity" else debug_name));

	return en;
}

copy_entity :: (original: Entity) -> *Entity
{
	en := create_entity(original.debug_name);
	id := en.id;
	<<en = original;
	en.id = id;
	return en;
}

reset_entity_props :: (en: *Entity)
{
	en.props = .{};
	add_props(*en.props, .valid, .visible);
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
	return range_shift(en.collision_rect, en.pos);
}

validate_entity :: (en: Entity, usage_debug_name: string = "")
{
	// FAILURE IS NOT AN OPTION, SOLDIER!
	assert(!is_nil(en), tprint("NIL entity at %", usage_debug_name));
	assert(has_prop(en.props, .valid), tprint("invalid entity at %\n%", usage_debug_name, en));
}

is_valid :: (entity: Entity) -> bool
{
	return !is_nil(entity) && has_prop(entity.props, .valid);
} 

is_visible :: (en: Entity) -> bool
{
	return is_valid(en) && has_prop(en.props, .visible);
}

is_valid :: (entity_handle: EntityHandle) -> bool
{
	return is_valid(entity_from_handle(entity_handle));
}

entity_set_sprite :: (en: *Entity, sprite: *ArcResource, random_frame := false)
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
		
		if random_frame
		{
			en.animation_frame = random_int_range(0, sprite.frame_count-1);
		}
	}
}
entity_set_sprite :: (en: *Entity, sprite_id: SpriteID, random_frame := false)
{
	sprite := get_sprite(sprite_id);
	entity_set_sprite(en, sprite, random_frame);
}
entity_set_sprite :: (en: *Entity, sprite_name: string, random_frame := false)
{
	sprite := get_sprite_from_name(sprite_name);
	entity_set_sprite(en, sprite, random_frame);
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
	add_props(*en.props, .render_sprite, .deconstructable, .tree_root, .loot_drops, .placement_obstacle);
	entity_set_sprite(en, tprint("overgrown_roots_%", variant));
	en.collision_rect = rect_from_sprite(en.sprite_id);
	en.health = 20;
	en.z_layer = Z_ROOTS;
	en.flip_sprite = does_flip;
	
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(1, 3)};
	
	return en;
}

create_tall_grass :: (variant_index: int) -> *Entity
{
	VARIANT_COUNT :: 1;
	variant := variant_index % VARIANT_COUNT;
	does_flip : bool = xx (variant_index % 2);
	
	en := create_entity("tall_grass");
	add_props(*en.props, .render_sprite, .tree_root, .loot_drops, .deconstructable, .placement_obstacle);
	entity_set_sprite(en, tprint("tall_grass_%", variant));
	en.collision_rect = rect_from_sprite(en.sprite_id);
	en.health = 20;
	en.z_layer = Z_TALL_GRASS;
	en.flip_sprite = does_flip;
	
	en.loot_drops[0] = .{id=.fibre, amount=random_int_range(1, 2)};
	
	return en;
}

setup_wall :: (en: *Entity)
{
	en.z_layer = Z_STRUCTURES;
	en.health = 20;
	entity_set_sprite(en, "wood_defense_wall");
	add_props(*en.props, .rigid_body, .static, .render_sprite, .obstacle, .generic_damage, .deconstructable, .placement_obstacle);
	add_props(*en.recieve_damage_from, .monster);
	en.collision_rect.max = xy(11, 68);
	en.collision_rect = range_shift(en.collision_rect, xy(-12, 0));
}

create_gobby :: () -> *Entity
{
	en := create_entity("gobby");
	en.max_health = 50;
	en.health = 50;
	en.z_layer = Z_MONSTER;
	en.render_offset.scale = xy(0.7);
	add_props(*en.props, .render_sprite, .rigid_body, .attack_player, .generic_damage, .manually_enter_damage, .override_death, .gobby, .monster, .loot_drops, .draw_health_bar);
	add_props(*en.recieve_damage_from, .player);
	
	push_random_seed(get_chaos_seed());
	en.loot_drops[0] = .{id=.goblin_hide, amount=random_int_range(1, 3)};
	en.loot_drops[1] = .{id=.goblin_meat, amount=random_int_range(1, 3)};
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

survival_book_ui :: ()
{
	held_item_name := get_held_entity_item_name();
	
	// entry condition
	if held_item_name == "book_survival"
		&& app.interface_mode == .nil
		&& key_pressed(.MOUSE_BUTTON_RIGHT)
	{
		set_interface_mode(.survival_book);
	}
	
	// exit condition
	if app.interface_mode == .survival_book
		&& (held_item_name != "book_survival" || key_pressed(.ESCAPE))
	{
		set_interface_mode(.nil);
	}
	
	// survival book state
	if app.interface_mode == .survival_book
	{
		if is_state_entry(.survival_book)
		{
			// ...
		}
		
		// render UI
		app.show_cursor = true;
		app.disable_player_input = true;
		
		// flip pages
		prev_page := app.sb_page;
		app.sb_page += xx key_pressed(#char "D");
		app.sb_page -= xx key_pressed(#char "A");
		app.sb_page = clamp(app.sb_page, 0, app.PAGE_COUNT-1);
		if app.sb_page != prev_page then play_sound(.page_flip);
		
		// update alpha to target for each page
		for * app.sb_page_opacity
		{
			target_opacity := ifx it_index == app.sb_page then 1.0 else 0.0;
			animate_to_target(it, target_opacity, delta_t(), rate=30);
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
		for page: 0..app.PAGE_COUNT-1
			if app.sb_page_opacity[page]
		{
			push_opacity(app.sb_page_opacity[page]);
			
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
	for * en: g_world.entities if is_valid(en) && has_prop(en.props, .gobby)
	{
		
		// move away from others
		for * other: g_world.entities if is_valid(other) && has_prop(other.props, .gobby)
		{
			dist := en.pos.x - other.pos.x;
			if abs(dist) < 4.0
			{
				en.pos.x += sign(dist) * delta_t_scaled() * 10.0;
			}
		}
		
		//
		range_to_player: Range1 = .{player.pos.x, en.pos.x};
		range_to_player = range_correct(range_to_player);
		dist_to_player := range_size(range_to_player);
		is_player_dead := get_player().health <= 0;
		
		// find target entity
		closest_obstacle: *Entity = *nil_entity;
		for * obst: g_world.entities if is_valid(obst) && has_prop(obst.props, .obstacle)
		{
			prev_dist := abs(closest_obstacle.pos.x - en.pos.x);
			new_dist := abs(obst.pos.x - en.pos.x);
			in_range := range_contains(range_to_player, get_absolute_position(obst).x);
			if in_range
				&& (is_nil(closest_obstacle) || new_dist < prev_dist)
			{
				closest_obstacle = obst;
			}
		}
		target_entity : *Entity;
		if is_player_dead
		{
			target_entity = entity_from_handle(g_world.corefire_handle);
		}
		else
		{
			target_entity = ifx is_valid(closest_obstacle) then closest_obstacle else get_player();
		}
		
		// TODO -
		// add more enemies, and THEN refactor. Just go FSM.
		// MAKE CONTENT.
		
		en.state_timer += delta_t_scaled();
		
		ATTACK_RANGE :: 25;
		
		move: bool;
		
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
			
			play_sound(.punch);
			
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
			if en.frame.did_anim_finish then set_state(en, .dead);
		}
		if en.state == .dead
		{
			// sadge
			en.marked_for_destroy = true;
			do_death_poof(en);
			drop_items_at_location(en.loot_drops, en.pos);
			play_sound(.impact_thing);
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
				play_sound(.gobby_attack, delay=0.6);
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
				attack_hitbox = range_shift(attack_hitbox, get_absolute_position(en));
				against_rect := range_shift(target_entity.collision_rect, get_absolute_position(target_entity));
				// debug_rect(attack_hitbox, 50);
				// debug_rect(against_rect, 50);
				if range_collide(against_rect, attack_hitbox)
				{
					attempt_damage_entity(target_entity, 1, en, make_props(EntityProps.gobby, .monster));
				}
			}
			
			if en.frame.did_anim_finish
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
		
	for * en: g_world.entities if has_prop(en.props, .generic_damage)
	{
		// damage animation
		tick_timer(*en.damage_alpha, delta_t_scaled());
		if en.damage_alpha != 0
		{
			exp := ease_out_exp(1-en.damage_alpha, rate=20);
			en.white_override = 1-exp;
		}
		
		if en.damage_event.amount != 0
		{
			defer memory_zero(*en.damage_event);
			
			en.health -= en.damage_event.amount;
			en.health = max(en.health, 0);
			en.damage_alpha = 1.0;
			if !has_prop(en.props, .manually_enter_damage) then set_state(en, .damaged);
			
			play_sound(en.hit_sound);
		}
		
		if !has_prop(en.props, .override_death) && en.health <= 0
		{
			en.marked_for_destroy = true;
			do_death_poof(en);
			drop_items_at_location(en.loot_drops, en.pos);
		}
	}
}

do_death_poof :: (en: *Entity)
{
	create_emitter(en.pos, .death_poof);	
}

drop_items_at_location :: (items: []ItemAmount, pos: Vector2)
{
	count := 0;
	for items 
	{
		if it.id == .nil then break;
		count += 1;
	}
	
	for items
	{
		if it.id == .nil then break;
		spacing :: 10.0;
		
		item := create_world_item(it.id);
		item.item_count = it.amount;
		item.pos = pos + xy((xx (count - 1.0) / -2.0) * spacing + it_index * spacing, 0);
		item.velocity = xy(random_get_within_range(-30, 30), random_get_within_range(100, 150));
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

create_tree :: () -> *Entity
{
	en := create_entity("tree");
	add_props(*en.props, .render_sprite, .tree, .placement_obstacle);
	add_props(*en.recieve_damage_from, .axe);
	entity_set_sprite(en, "tree_full");
	en.collision_rect.max = xy(14, 64);
	en.collision_rect = range_bottom_center(en.collision_rect);
	en.health = 10;
	en.z_layer = Z_TREE;
	en.flip_sprite = xx random_int_range(0, 1);
	return en;
}

create_stump :: () -> *Entity
{
	en := create_entity("stump");
	add_props(*en.props, .render_sprite, .generic_damage, .placement_obstacle);
	add_props(*en.recieve_damage_from, .axe);
	en.health = 30;
	en.z_layer = Z_TREE + 0.1;
	en.hit_sound = .wood_hit;
	entity_set_sprite(en, "tree_stump");
	en.loot_drops[0] = .{id=.wood, amount=random_int_range(1, 2)};
	return en;
}

update_trees :: ()
{
	player := get_player();
	
	for * tree: g_world.entities if is_valid(tree) && has_prop(tree.props, .tree)
	{
		
		if tree.damage_event.amount != 0
		{
			defer memory_zero(*tree.damage_event);
			dmg := tree.damage_event;
			
			tree.health -= dmg.amount;
			tree.health = clamp_bottom(0, tree.health);
			
			if tree.health <= 0
			{
				set_state(tree, .dying);
			}
			
			play_sound(.wood_hit);
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
				}
				
				new_event(.{kind=.death, entity=handle_from_entity(tree)});
				tree.marked_for_destroy = true;
				
				play_sound(.tree_impact);
				app.camera_trauma += 0.6;
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
	attack_hitbox = range_shift(attack_hitbox, player.pos);


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
		
		if total_weight_in_storage() > get_max_weight()
		{
			weight_over := total_weight_in_storage() - get_max_weight();
			speed_decrease := float_map(xx weight_over, 0, 3, 1.0, 0.25);
			mult *= speed_decrease;
		}
		
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
	
	// process damage event
	if player.damage_event.amount != 0
	{
		dmg := player.damage_event;
		
		if player.is_blocking && player.x_dir != sign(dmg.direction.x)
		{
			play_sound(.block);
			create_emitter(get_held_item_render_pos() + xy(player.x_dir * 5.0, 5.0), .parry);
		}
		else
		{
			player.health -= dmg.amount;
			player.health = clamp_bottom(0, player.health);
			
			set_state(player, .damaged);
			play_sound(.punch);
			
			app.camera_trauma += 0.4;
			
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
			
			if player.frame.did_anim_finish then set_state(player, .idle); 
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
		held_item := get_resource(get_held_entity().item_id);
		
		did_hit := false;
		for * en: g_world.entities
			if is_valid(en)
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
				landed := attempt_damage_entity(en, 10, source, damage_props);
				if landed then did_hit = true;
			}
		}
		
		if did_hit
		{
			app.camera_trauma += 0.4;
		}
	}
	
	// sword attacking
	if player.state == .slash_1
	{
		if is_state_entry(player, .slash_1)
		{
			play_sound(.sword_swing_01);
		}
		
		app.disable_player_input = true;
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
			play_sound(.sword_swing_02);
		}
		
		app.disable_player_input = true;
		entity_set_sprite(player, "char_stab1"); // just using stab now bc we don't have a second slash yet
		held_en := get_held_entity();
		
		// hit
		if player.animation_frame == 2 && player.frame.anim_frame_advance
		{
			hit(attack_hitbox, player);
			// player.velocity.x += player.x_dir * 100.0;
		}
		
		if player.frame.did_anim_finish
		{
			set_state(player, .idle);
		}
	}
	
	
	// play out the attack state
	if player.state == .chop || player.state == .punch
	{
		app.disable_player_input = true;
		entity_set_sprite(player, "char_punch");
		
		// hit
		if player.animation_frame == 3 && player.frame.anim_frame_advance
		{
			hit(attack_hitbox, player);
			//debug_rect(attack_hitbox, 1000);
			//play_sound(.punch);
		}
		
		if player.frame.did_anim_finish
		{
			set_state(player, .idle);
		}
	}
}

animate_sprites :: ()
{
	for * en: g_world.entities if has_prop(en.props, .valid) && en.sprite_id
	{
		using en;

		if time_til_next_frame != 0.0 && animation_playing
		{
			time_til_next_frame -= delta_t_scaled();
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
	for * entity: g_world.entities if is_visible(entity) && has_prop(entity.props, .rigid_body) && !has_prop(entity.props, .static)
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
		
		if abs(next_pos.x) > xx world_radius
		{
			next_pos.x = world_radius * cast(float) sign(next_pos.x);
			entity.velocity.x = 0;
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
			LENGTH :: 5.0;
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

main_menu_ui :: ()
{
	if is_state_exit(.main_menu)
	{
		app.main_menu_alpha_t = 0.0;
	}
	if is_state_entry(.main_menu)
	{
		app.main_menu_alpha_t = 1.0;
	}
	animate_to_target(*app.main_menu_alpha, app.main_menu_alpha_t, 15);
	
	if app.main_menu_alpha_t == 1.0
	{
		app.show_cursor = true;
		app.confine_cursor = false;
	}
	
	if app.main_menu_alpha != 0.0
	{
		alpha := app.main_menu_alpha;
		
		push_opacity(alpha);
		push_text_justify_x(.center);
		push_flags(ifx app.main_menu_alpha_t == 0.0 then BoxFlags.disable_interaction);
		
		// black bg
		set_next_pref_width(pct_parent(1));
		set_next_pref_height(pct_parent(1));
		set_next_fill_col(BLACK);
		set_next_flags(.draw_fill);
		auto_column();
		
		set_next_floating_y((1-alpha) * 30.0 * ifx app.main_menu_alpha_t == 1 then -1 else 1);
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
			set_app_mode(.world);
		}
	}
}

game_over_ui :: ()
{
	if is_state_entry(.game_over)
	{
		play_sound(.endgame);
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
		
		// set_next_font_size(app.debug_config.ui_font_size * 2);
		// set_next_pref_height(text_dim());
		// label("press R to respawn");
		
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
	}
	
	if app.app_mode != .world
	{
		app.pause_menu_alpha_t = 0.0;
	}
	
	animate_to_target(*app.pause_menu_alpha, app.pause_menu_alpha_t, 10);
	
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
		push_flags(ifx app.interface_mode != .pause_menu then BoxFlags.disable_interaction);
		
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

in_game_user_interaction :: ()
{
	player:= get_player();
	
	interact_hitbox: Range2;
	interact_hitbox.min.x = -10;
	interact_hitbox.max = xy(40, 32);
	if player.x_dir == -1 then interact_hitbox = range_flip_x(interact_hitbox);
	interact_hitbox = range_shift(interact_hitbox, player.pos);
	//debug_rect(interact_hitbox, 1);
	
	// :interaction
	
	// get overlapped interactables
	overlapped: [..]*Entity;
	for * en: g_world.entities
		if is_visible(en)
		// TODO make everything based solely around the .interactable flag
	{
		add : bool;
		
		if has_prop(en.props, .blueprint) && en.id != g_world.placing_blueprint.entity_id
		{
			add = true;
		}
		
		// pickup when there's no item held
		if has_prop(en.props, .pick_up) && !is_valid(get_held_entity())
		{
			add = true;
		}
		
		// harvest when there's no item held
		if has_prop(en.props, .harvestable) && !is_valid(get_held_entity())
		{
			add = true;
		}
		
		// only deconstruct when proper tool is held
		if has_prop(en.props, .deconstructable) && has_prop(get_held_entity().props, .deconstruct_tool)
		{
			add = true;
		}
		
		if add
		{
			// add overlapping
			against_rect := get_collision_rect(en);
			if range_collide(interact_hitbox, against_rect)
			{
				array_add(*overlapped, en);
			}
		}
	}
	
	// SELECT the hovered interactable
	// we want pinpoint accuracy here, that's the constraint. The user
	// is selecting what they want to interact with. If they can't actually
	// then we show them why with an error
	hovered_en: *Entity = *nil_entity;
	for en: overlapped
	{
		if is_nil(hovered_en)
		|| abs(get_absolute_position(hovered_en).x - player.pos.x) > abs (get_absolute_position(en).x - player.pos.x)
		{
			hovered_en = en;
		}
	}
	g_world.hovered_interactable = handle_from_entity(hovered_en);
	
	// NOTE
	// everything about this is fucked up broski
	// I should not be trying to do ALL the interaction functionality in here
	// It should be happening right in their respective update functions, immediate style
	// All this needs to be doing is selecting the desired interactable. NOTHING ELSE YA SILLY GOOSE
	
	
	
	// We're assuming only one type of interaction that can occur
	// I don't see a case where we'd need to (or even could easily communicate) multiple potential
	// interactions from a given entity. Nor would need it?? Time will tell.
	
	// :PICKUP :INTERACT
	if has_prop(hovered_en.props, .pick_up)
	{
		if key_pressed(#char "E")
		{
			consume_key(#char "E");
			
			create_emitter(hovered_en.pos, .single_poof);
			new_event(Event.{kind=.pickup, entity=handle_from_entity(hovered_en)});
			stored_slot := attempt_store_item(player, hovered_en);
			assert(stored_slot != null, "Failed to store %", get_name(hovered_en));
			
			play_sound(.pickup);
			
			/*
			can_go_in_hand := player.hot_slot != 0 && !is_valid(get_held_entity());
			if can_go_in_hand
			{
				player.hotbar_slots[player.hot_slot] = <<stored_slot;
				play_sound(.air_swing);
			}
			else
			{
				play_sound(.pickup);
			}
			*/
		}
	}
	
	// :DECONSTRUCT
	if has_prop(hovered_en.props, .deconstructable) && has_prop(get_held_entity().props, .deconstruct_tool)
	{
		if key_pressed(#char "E")
		{
			consume_key(#char "E");
			play_sound(.harvest);
			create_emitter(hovered_en.pos, .death_poof);
			hovered_en.marked_for_destroy = true;
			
			if hovered_en.item_id
			{
				item := get_item(hovered_en.item_id);
				// drop the existing spent items
				spent_items: [Entity.remaining_items.count]ItemAmount;
				array_copy(spent_items, item.recipe);
				for * spent_items
				{
					it.amount = it.amount - hovered_en.remaining_items[it_index].amount;
				}
				drop_items_at_location(spent_items, hovered_en.pos);
			}
			else
			{
				drop_items_at_location(hovered_en.loot_drops, hovered_en.pos);
			}
		}
	}
	
	// :BLUEPRINT :INTERACT
	if has_prop(hovered_en.props, .blueprint)
	{
		// check if there's anything in the inv to contribute
		is_interaction_valid : bool;
		for player.stored_items
		{
			item := get_resource(entity_from_handle(it).item_id);
			if !is_valid(item) then continue;
			
			for hovered_en.remaining_items
			{
				if it.id == .nil || it.amount == 0 then continue;
				if it.id == item.id
				{
					is_interaction_valid = true;
					break;
				}
			}
		}
		#if IGNORE_MATERIAL_COST { is_interaction_valid = true; }
		
		if !is_interaction_valid && key_pressed(#char "E")
		{
			consume_key(#char "E");
			
			// @tutorial ?
			// str :: "No items found in inventory.";
			// if !does_notification_exist(str) then create_notification(str);
		}
		
		if is_interaction_valid && key_pressed(#char "E")
		{
			consume_key(#char "E");
			struc := get_item(hovered_en.item_id);
			
			used_item := false;
			
			// grab first item and put it towards the recipe
			for * stored : player.stored_items
			{
				if !is_valid(stored) then continue;
				item_en := entity_from_handle(stored);
				stored_item := get_item(item_en.item_id);
				
				for * remaining : hovered_en.remaining_items
				{
					if remaining.id == .nil || remaining.amount == 0 then continue;
					if remaining.id == stored_item.id
					{
						remaining.amount -= 1;
						item_en.item_count -= 1;

						if item_en.item_count == 0
						{
							item_en.marked_for_destroy = true;
						}
						
						used_item = true;
						break;
					}
				}
				
				if used_item then break;
			}
			
			has_items_remaining := false;
			for hovered_en.remaining_items
			{
				if it.amount != 0
				{
					has_items_remaining = true;
					break;
				}
			}
			
			play_random_sound("build", 2, volume=0.6);
			
			if !has_items_remaining || IGNORE_MATERIAL_COST
			{
				new_event(.{kind=.craft, entity=handle_from_entity(hovered_en)});
				play_sound(.build_finish, random_spread=false);
				
				// build entity
				reset_entity_props(hovered_en);
				get_item(hovered_en.item_id).build_func(hovered_en);
			}
		}
	}

	// :HARVEST
	if has_prop(hovered_en.props, .harvestable)
	{
		if key_pressed(#char "E")
		{
			consume_key(#char "E");
			play_sound(.harvest);
			create_emitter(hovered_en.pos, .death_poof);
			hovered_en.marked_for_destroy = true;
			
			if has_prop(hovered_en.props, .player)
			{
				// ideally this would be an override of the harvest of some sort
				// maybe we start having entity resources that're static?
				
				// return inv to player
				for * hovered_en.stored_items
				{
					en := entity_from_handle(it);
					if en.item_id == 0 then continue;
					
					stored := attempt_store_item(player, en);
					assert(stored != null, "Failed to store item, shit will get yeeted into the ether...");
				}
				player.hotbar_slots = hovered_en.hotbar_slots;
				player.equipped_items = hovered_en.equipped_items;
				player.hot_slot = hovered_en.hot_slot;
				hovered_en.marked_for_destroy = true;
				
				do_death_poof(hovered_en);
			}
			else
			{
				drop_items_at_location(hovered_en.loot_drops, hovered_en.pos);
			}
		}
	}
	
	// generic interaction visuals
	for * en: g_world.entities if is_valid(en)
	{
		// set the correct target
		if en == entity_from_handle(g_world.hovered_interactable) && !app.disable_player_input
		{
			en.interactable_alpha_t = 1.0;
		}
		else
		{
			en.interactable_alpha_t = 0.0;
		}
		animate_to_target(*en.interactable_alpha, en.interactable_alpha_t, delta_t_scaled(), rate=30); // update alpha to target
		
		if en.interactable_alpha == 0.0 then continue;
		
		sprite := get_sprite(en.sprite_id);
		
		// TODO
		// ideally make the invalid interaction red
		// need some way of passing in immediate parameters for controlling the rendering, which
		// get reset back to 0 when the path isn't run
		
		en.white_override = en.interactable_alpha * 0.5;
		
		// todo - better tooltip tutorial thang
		// trs := make_transform(get_absolute_position(en), 0, en.interactable_alpha);
		// trs.translate.y += range_size(sprite.rect).y + 5;
		// trs.translate.y += ease_sin_breathe(en.breathe_current) * 2.0;
		// push_text("E", 10, FONT_1980, col=xyzw(1, 1, 1, en.interactable_alpha), z_layer=100, trs=trs);
	}
	
	// update :helditem pos
	// this is pretty scuffed, maybe I needa make the entity invisible entirely and just do a
	// manual render on the player? yeeee probs, idk
	// if it ain't broke don't fix it
	held_en := get_held_entity();
	if is_valid(held_en)
	{
		remove_props(*held_en.props, .rigid_body);
		held_en.x_dir = player.x_dir;
		flip := player.x_dir == -1;
		held_en.animate_render_offset_to_target = true;
		
		held_sprite := get_sprite(held_en.sprite_id);
		
		target_offset_trs: Transform2;
		player_anim := get_sprite(player.sprite_id);
		if player_anim.hand_sockets.count > 0
		{
			target_offset_trs = player_anim.hand_sockets[player.animation_frame];
			target_offset_trs.rotate *= -1;
		}
		target_offset_trs.translate -= held_sprite.grip_offset.translate;
		target_offset_trs.pivot_offset = held_sprite.grip_offset.translate * -1;
		target_offset_trs.pivot_offset.x *= ifx flip then -1 else 1;
		target_offset_trs.rotate -= held_sprite.grip_offset.rotate;
		
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
	}
}

setup_corefire :: (en: *Entity)
{
	add_props(*en.props, .render_sprite, .placement_obstacle);
	add_props(*en.recieve_damage_from, .monster);
	entity_set_sprite(en, .campfire_on_blue);
	en.archetype = .corefire;
	en.z_layer = Z_STRUCTURES;
	en.light_radius = 100.0;
}
update_corefire :: (world: *WorldState)
{
	fire := entity_from_handle(world.corefire_handle);
	
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

setup_campfire :: (en : *Entity)
{
	add_props(*en.props, .interactable, .render_sprite, .deconstructable, .placement_obstacle);
	en.archetype = .campfire;
	en.z_layer = Z_STRUCTURES;
}
update_campfires :: ()
{
	for * en: g_world.entities if is_valid(en) && en.archetype == .campfire
	{
		update_campfire(en);
	}
}
update_campfire :: inline (en : *Entity)
{
	// toggle campfire on/off
	hovered := entity_from_handle(g_world.hovered_interactable) == en;
	if hovered && key_pressed(#char "E")
	{
		consume_key(#char "E");
		set_state(en, ifx en.state == .on then .off else .on);
	}
	
	// off
	if en.state == .off
	{
		if is_state_entry(en, .off)
		{
			create_emitter(en.pos, .death_poof);
			entity_set_sprite(en, .campfire_off);
			play_sound(.fire_extinguish);
		}
		
		en.light_radius_t = 0.0;
		en.light_radius = 0.0;
	}
	
	// on
	if en.state == .on
	{
		if is_state_entry(en, .on)
		{
			entity_set_sprite(en, .campfire_on);
			play_sound(.fire_ignite);
		}
		
		en.light_radius_t = 200.0 + (sin(cast(float)g_world.time_elapsed * 5) * 5);
	}
	animate_to_target(*en.light_radius, en.light_radius_t, delta_t_scaled());
}
// todo - some kind of ignite property? that way we can extend it to everything

update_point_lights :: ()
{
	cbuff := get_global_const_buff();
	for * en : g_world.entities if is_visible(en)
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
}

update_items :: ()
{
	held_item := get_held_entity();
	for * en : g_world.entities if is_valid(en) && has_prop(en.props, .item)
	{
		update_item(en);
	}
}
update_item :: inline (en: *Entity) #expand
{
	is_held := `held_item == en;
	
	is_in_inventory := false;
	for get_player().stored_items
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
	
	// is it g_world or on the player?
	if is_in_inventory
	{
		remove_props(*en.props, world_item_props);
	}
	else
	{
		merge_props(*en.props, world_item_props);
	}
}

total_weight_in_storage :: () -> int
{
	total_weight : int;
	for * get_player().stored_items
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

can_store_item :: (entity_item: *Entity) -> bool
{
	item := get_item(entity_item.item_id);
	
	// find slots
	empty_slot : *EntityHandle;
	stackable_slot : *EntityHandle;
	for * get_player().stored_items
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
		
	can_stack : bool = !has_prop(item.props, .unstackable) && stackable_slot;
	enough_weight := total_weight_in_storage() + item.weight <= get_max_weight();
	
	return enough_weight && (can_stack || empty_slot);
}

// return: success, the slot that it was sotred in
attempt_store_item :: (in : *Entity, entity_item: *Entity) -> *EntityHandle
{
	if !is_valid(entity_item) then return null;
	
	item := get_item(entity_item.item_id);
	
	// find slots
	empty_slot : *EntityHandle;
	stackable_slot : *EntityHandle;
	for * in.stored_items
	{
		en := entity_from_handle(it);
		en_item := get_resource(en.item_id);
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
		entity_stack.item_count += entity_item.item_count;
		return stackable_slot;
	}
	
	if empty_slot == null
	{
		assert(false, "No empty slot found in stored items, increase size?");
		return null;
	}
	else
	{
		<<empty_slot = handle_from_entity(entity_item);
		return empty_slot;
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

update_torches :: ()
{
	held_en := get_held_entity();
	for * en : g_world.entities if is_visible(en) && en.item_id == .torch
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
			play_sound(.fire_extinguish);
		}
		
		en.light_radius_t = 0.0;
		en.light_radius = 0.0;
	}
	
	// on
	if en.state == .on
	{
		if is_state_entry(en, .on)
		{
			play_sound(.fire_ignite);
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
	if app.interface_mode == .inventory
	{
		app.inventory_alpha_t = 1.0;
	}
	else
	{
		app.inventory_alpha_t = 0.0;
	}
	animate_to_target(*app.inventory_alpha, app.inventory_alpha_t, delta_t(), rate=UI_ANIMATE_RATE);
	
	// :hotbar :helditem
	{
		// change hotbar from input
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
	}
	
	drop_item : *Entity;
	
	if app.inventory_alpha != 0.0
	{
		app.show_cursor = true;
		push_opacity(app.inventory_alpha);
		
		// defaults / config
		bg_col := BLACK;
		fill_col := WHITE;
		push_fill_col(fill_col);
		push_bg_col(bg_col);
		push_text_col(fill_col);
		
		//
		// left side
		//
		set_next_pref_height(size_by_children(1));
		set_next_pref_width(size_by_children(1));
		set_next_fill_col(xyzw(1, 1, 1, 0.4));
		set_next_floating_x(20);
		set_next_floating_y(-20);
		set_next_child_layout_axis(.X);
		bg_box := make_box(BoxFlags.draw_fill | .draw_border | .floating | .clickable, "inv_bg");
		_push_parent(bg_box);
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
		
		HIGHLIGHT_COL := rbg_helper(237, 158, 104);
		
		// hotbar
		{
			set_next_pref_height(size_by_children(1));
			set_next_pref_width(size_by_children(1));
			auto_row();
			for 1..get_hotbar_slot_count()
			{
				if it != 1 then spacer(em(0.1));
				
				slot_active := player.hot_slot == it;
				
				set_next_pref_height(box_size);
				set_next_pref_width(box_size);
				set_next_border_col(BLACK);
				if slot_active then set_next_fill_col(HIGHLIGHT_COL);
				slot := make_box(BoxFlags.draw_fill | .clickable | .draw_hot_effects | .draw_active_effects , tprint("hotbar_slot_%", it));
				sig := signal_from_box(slot);
				
				held_en := entity_from_handle(app.mouse_held_item);
				if is_valid(held_en)
				{
					// put in hotbar
					if sig.clicked
					{
						player.hotbar_slots[it] = app.mouse_held_item;
						app.mouse_held_item = .{};
					}
				}
				else
				{
					// put in mouse
					if sig.clicked && is_valid(player.hotbar_slots[it])
					{
						app.mouse_held_item = player.hotbar_slots[it];
					}
				}
				
				// clear on rightclick
				if sig.clicked_r
				{
					player.hotbar_slots[it] = .{};
				}
				
				// draw icon
				en := entity_from_handle(player.hotbar_slots[it]);
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
			for * stored_handle : player.stored_items
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
					
					set_next_fill_col(ifx get_item_equipped_slot(en) then HIGHLIGHT_COL else xyzw(0.5, 0.5, 0.5, 0.7));
					set_next_flags(BoxFlags.draw_fill | .clickable | .draw_hot_effects | .draw_active_effects);
					box := icon(en.sprite_id, tprint("inventory_slot_%", it_index), box_size, 0.1, 0.1);
					sig := signal_from_box(box);
					if sig.pressed
					{
						if is_valid(app.mouse_held_item)
						{
							app.mouse_held_item = .{};
						}
						else
						{
							app.mouse_held_item = stored_handle;
						}
					}
					
					if sig.pressed_r
					{
						// equip the item
						if has_prop(en.props, .equippable)
						{
							equip_slot := get_item_equipped_slot(en);
							if equip_slot == null
							{
								// does it already have the slot equipped?
								// TODO - make this based on the slot (eg - waist), instead of the item
								can_equip := true;
								for player.equipped_items
								{
									equipped := entity_from_handle(it);
									if is_valid(equipped) && equipped.item_id == en.item_id
									{
										can_equip = false;
										break;
									}
								}
								
								if can_equip
								{
									free_slot : *EntityHandle;
									for * player.equipped_items
									{
										if !is_valid(it) then free_slot = it;
									}
									assert(free_slot != null, "No equippable slots left. Increase size?");
									
									<<free_slot = handle_from_entity(en);
								}
							}
							else
							{
								<<equip_slot = .{};
							}
						}
						else if has_prop(en.props, .consumable)
						{
							item.on_consume(en);
						}
					}
					
					// drop a single item
					if sig.hovering && key_pressed(#char "Q")
					{
						consume_key(#char "Q");
						stored_en := entity_from_handle(stored_handle);
						
						if stored_en.item_count > 1
						{
							copy := copy_entity(stored_en);
							copy.item_count = 1;
							drop_item = copy;
							stored_en.item_count -= 1;
						}
						else
						{
							drop_item = stored_en;
						}
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
		
		//
		// right side
		//
		_pop_parent();
		
		
		
		//
		// cursor
		//
		
		bg_box_sig := signal_from_box(bg_box);
		// render mouse item
		{
			mouse_held_item := entity_from_handle(app.mouse_held_item);
			if is_valid(mouse_held_item)
			{
				pos := app.mouse_pos - xy(0, xx app.window_h) - xy(box_size.value, -box_size.value);
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
				
				if bg_box_sig.pressed
				{
					consume_key(.MOUSE_BUTTON_LEFT);
					app.mouse_held_item = .{};
				}
			}
		}
	}
	
	// drop held mouse item
	if drop_item == null
	{
		en := entity_from_handle(app.mouse_held_item);
		if is_valid(en) && key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			app.mouse_held_item = .{};
			drop_item = en;
		}
	}
	
	// drop from Q
	if drop_item == null && !app.disable_player_input && is_valid(get_held_entity()) && key_pressed(#char "Q")
	{
		consume_key(#char "Q");
		drop_item = get_held_entity();
	}
	
	if drop_item
	{
		add_props(*drop_item.props, .visible);
		drop_item.render_offset_t = .{};
		drop_item.velocity.x = player.x_dir * 100.0 + player.velocity.x;
		drop_item.velocity.y = player.velocity.y;
		play_sound(.air_swing, pitch=0.8);
		
		drop_item.pos = player.pos + xy(0, 14);
		
		// clear slots
		for * player.stored_items
		{
			if entity_from_handle(it) == drop_item
			{
				<<it = .{};
			}
		}
		for * player.hotbar_slots
		{
			if entity_from_handle(it) == drop_item
			{
				<<it = .{};
			}
		}
		for * player.equipped_items
		{
			if entity_from_handle(it) == drop_item
			{
				<<it = .{};
			}
		}
	}
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
	for get_player().stored_items
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

build_mode :: ()
{
	if is_state_exit(.build_mode)
	{
		placing := entity_from_handle(g_world.placing_blueprint);
		if is_valid(placing)
		{
			placing.marked_for_destroy = true;
		}
	}
	
	if app.interface_mode == .build_mode
	{
		if is_state_entry(.build_mode)
		{
			assert(g_world.selected_structure != 0, "Entered build mode without a selected structure?");
			
			g_world.selected_structure;
			en := create_blueprint(g_world.selected_structure);
			g_world.placing_blueprint = handle_from_entity(en);
		}
		
		app.show_cursor = true;
		
		place_en := entity_from_handle(g_world.placing_blueprint);
		assert(is_valid(place_en));
		place_en.pos.x = mouse_pos_in_world().x;
		
		if app.frame.wheel_delta
		{
			place_en.x_dir *= -1;
		}
		
		is_valid_spot := true;
		for en : g_world.entities if is_valid(en) && has_prop(en.props, .placement_obstacle) && en.id != place_en.id
		{
			r1 := get_occupied_world_space(en);
			r2 := get_occupied_world_space(place_en);
			if range_collide(r1, r2)
			{
				is_valid_spot = false;
				break;
			}
		}
		
		if !is_valid_spot
		{
			place_en.frame.colour_multiplier = RED;
		}
		
		// click to place
		if is_valid_spot && key_pressed(.MOUSE_BUTTON_LEFT)
		{
			set_interface_mode(.nil);
			g_world.placing_blueprint = .{};
			g_world.selected_structure = 0;
			play_random_sound("build", 2, volume=0.6);
		}
		
		consume_key(.MOUSE_BUTTON_LEFT);
	}
}

create_blueprint :: (id: ItemID) -> *Entity
{
	struc := get_item(id);
	en := create_entity();
	add_props(*en.props, .render_sprite, .blueprint, .collision_query, .deconstructable, .placement_obstacle);
	en.item_id = id;
	en.z_layer = Z_STRUCTURES;
	
	array_copy(en.remaining_items, struc.recipe);
	
	sprite := get_sprite(get_display_sprite_id(struc));
	entity_set_sprite(en, sprite);
	en.collision_rect = rect_from_sprite(sprite.id);
	return en;
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
	en := create_entity();
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
		
		// animate
		if p.flags & .animate_sprite
		{
			sprite := get_sprite_from_name(p.sprite);
			
			// get default playrate from sprite if we don't have one specified
			if p.play_rate == 0 then p.play_rate = sprite.play_rate;
			
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
Input :: #import "Input";
Windows :: #import "Windows";
WindowsX :: #import,file "../../../external/windows_extra.jai";

// lol this is a fucking mess

#import "MetaDesk";
#load "../../../external/MetaDesk/metadesk_helpers.jai";

#load "resource.jai";

#load "../../../recycle/imui.jai";

#load "arena.jai";
#load "config.jai";

#import,file "../../../recycle/recycle.jai";
#load "sound.jai";
#load "render.jai";
#load "../../../recycle/cereal.jai";
#load "linked.jai";

#import "Spall";
#import,file "../../../recycle/profile.jai";

// #import,file "../../external/Runtime_Support.jai"(ENABLE_BACKTRACE_ON_CRASH=true);