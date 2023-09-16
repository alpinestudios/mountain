// just a dump for old code. fuck looking thru soruce control

/*
create_blueprint :: (id: ItemID) -> *Entity
{
	struc := get_item(id);
	en := create_entity();
	add_props(*en.props, .render_sprite, .blueprint, .collision_query, .placement_obstacle);
	en.item_id = id;
	en.z_layer = Z_STRUCTURES;
	
	array_copy(en.remaining_items, struc.recipe);
	
	sprite := get_sprite(get_display_sprite_id(struc));
	entity_set_sprite(en, sprite);
	en.collision_rect = rect_from_sprite(sprite.id);
	return en;
}
*/

/*
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
*/

/*
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
	push_disable_signal(!is_active);
	push_opacity(app.crafting_menu_alpha);
	
	// :crafting
	if app.crafting_menu_alpha != 0.0
	{
		ratio := 0.7;
		page_height := px(app.window_h * app.debug_config.ui_height_scale);
		width := px(page_height.value * ratio);
		
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
		
		set_next_pref_height(page_height);
		set_next_pref_width(width);
		page_backdrop := make_box(.draw_bg | .draw_border, "");
		
		spacer(pct_parent(1, 0));
		
		push_parent(page_backdrop);
		
		padding_xy(px(10));
		
		set_next_font_size(font_size_pct(2.0));
		set_next_text_justify_x(.center);
		label("Crafting");
		spacer(em(0.5));
		
		height:= em(2);
		
		// list off the building items available
		push_font(FONT_SUB);
		for g_world.unlocked_recipes
		{
			if !it then continue;
			res_id : ResourceID = xx it_index;
			res := get_item(res_id);
			
			spacer(em(0.2));
			
			set_next_pref_height(size_by_children(1));
			set_next_child_layout_axis(.X);
			box := make_box(BoxFlags.draw_bg | .draw_border | .clickable | .draw_hot_effects | .draw_active_effects, tprint("%##selector_box", res.name));
			box_sig := signal_from_box(box);
			push_parent(box);
			
			// enter build mode with one of them upon click
			if box_sig.clicked
			{
				g_world.selected_structure = res_id;
				set_interface_mode(.build_mode);
			}
			
			icon(get_display_sprite_id(res), "", height, vertical_pad_pct= 0.1, horizontal_pad_pct= 0.1);
			
			set_next_pref_height(height);
			auto_column();
			padding(pct_parent(1, 0));
			set_next_text_justify_x(.left);
			set_next_font_size(font_size_pct(1.2));
			set_next_pref_height(em(1, 1));
			lbl := label("%", res.name);
		}
	}
}
*/


	/*
	if app.inventory_alpha != 0.0
	{
		app.show_cursor = true;
		push_opacity(app.inventory_alpha);
		
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
		
		
	}
	*/



	/*
	md_root := md_parse_file("res/generate.mdesk").node;
	
	biome_node := md_find_node_with_string(md_root, "forest", true);
	ground_col := md_col_from_key(biome_node, "ground_color");
	world.current_background = get_sprite_from_name(md_string_from_key(biome_node, "background"));
	
	{
		//push_allocator(context.default_allocator);
		//report := make_leak_report();
		// for report.sorted_summaries
		// {
		// 	print("~SUMMARY %:\n%\n", it_index, <<it);
		// }
		//log_leak_report(report);
	}
	
	generators := md_find_all_nodes_with_tag(biome_node, "generator");
	for generators
	{
		parallax := md_vector2_from_key(it, "parallax");
		z_layer := md_float_from_key(it, "z_layer");
		layer_y_offset := md_float_from_key(it, "layer_y_offset");
		
		// grab generator data
		assets : [..]*ArcResource;
		next_asset := md_find_node_with_string(it, "assets", true).first_child;
		while !is_nil(next_asset)
		{
			defer next_asset = next_asset.next;
			array_add(*assets, get_sprite_from_name(md_string(next_asset.str)));
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
			entity_set_sprite(en, assets[random_int_range(0, assets.count-1)]);
			
			en.flip_sprite = true;
			
			vx := random_get_within_range(-variance.x, variance.x);
			vy := random_get_within_range(-variance.y, variance.y);
			en.rel_pos.x = sign * (cast(float)index * interval + vx);
			en.rel_pos.y += vy + y_offset + layer_y_offset;
		}	
		

	}
	*/

//
// QUEST STUFF
//

init_quests :: ()
{
	quests := *st.quests;
	quests.allocator = world_allocator;
	array_reserve(quests, 128);
	
	new_quest :: (name: string, desc: string) -> *Quest #expand
	{
		quest = array_add(`quests);
		quest.name = name;
		quest.desc = desc;
		return quest;
	}
	new_step :: (quest: *Quest, desc: string, complete_check: () -> bool)
	{
		step := array_add(*quest.steps);
		step.desc = desc;
		step.complete_check = complete_check;
	}
	spawn_reward_item :: (item: ItemID)
	{
		en := create_ground_item(item);
		en.rel_pos = st.player.rel_pos + xy(0, 100);
	}
	quest: *Quest;
	
	// :quests
	quest = new_quest("Lumerjack", "Show the trees who runs this joint.");
	new_step(quest, "Craft a flint axe", () -> bool
	{
	 for event: game_state.world.frame.events
	  if event.kind == .craft && event.item == .flint_axe then return true;
	 return false;
	});
	new_step(quest, "Chop down a tree", () -> bool
	{
		for event: game_state.world.frame.events
			if event.kind == .death && has_prop(entity_from_handle(event.entity).props, .tree) then return true;
		return false;
	});
	quest.on_complete = ()
	{
	};
	
	// quest = new_quest("ligma", "balls");
	// new_step(quest, "1", () -> bool
	// {
	// 	return false;
	// });
	// new_step(quest, "2", () -> bool
	// {
	// 	return false;
	// });
	// new_step(quest, "3", () -> bool
	// {
	// 	return false;
	// });
}

quest_ui :: ()
{
	if key_pressed(#char "Z")
		&& (st.interface_state == .nil || st.interface_state == .build_menu)
	{
		consume_key(#char "Z");
		set_interface_state(.quest_slate);
	}
	
	if st.interface_state == .quest_slate && key_pressed(#char "Z")
	{
		consume_key(#char "Z");
		set_interface_state(.nil);
	}
	
	if st.interface_state == .quest_slate
		&& key_pressed(.ESCAPE)
	{
		consume_key(.ESCAPE);
		set_interface_state(.nil);
	}

	if st.interface_state == .quest_slate
	{
		st.show_cursor = true;
		st.disable_player_input = true;
		
		// defaults / config
		ratio := 0.7;
		height := px(st.window_h * st.debug_config.ui_height_scale);
		width := px(height.value * ratio);
		bg_col := BLACK;
		main_col := WHITE;
		accent_col := GRAY;
		push_fill_col(bg_col);
		push_text_col(main_col);
		push_border_col(main_col);
		push_text_justify_x(.center);
		
		// page backdrop
		set_next_pref_height(height);
		set_next_pref_width(width);
		set_next_flags(.FLOATING);
		page_backdrop := make_box(BoxFlags.DRAW_FILL, "");
		push_parent(page_backdrop);
		
		padding_xy(px(10));
		
		set_next_font_size(st.debug_config.ui_font_size * 2);
		label("Quest Log");
		
		spacer(em(1));
		
		{
			push_text_justify_x(.left);
			push_fill_col(accent_col);
			push_text_col(main_col);
			for * q: st.quests if q.unlocked
			{
				push_text_col(main_col);
				checkbox(q.complete, tprint("%", q.name));
				
				for * step: q.steps
				{
					auto_row();
					spacer(px(50));
					checkbox(step.complete, tprint("%", step.desc));
				}
				
				spacer(em(0.25));
				set_next_font(FONT_SUB);
				set_next_pref_height(px(30));
				label(q.desc);
				spacer(em(1));
			}
		}
	}
}

update_quests :: ()
{
	// check quest's steps for completion
	for * q: st.quests if !q.complete && q.unlocked
	{
		q_complete := true;
		for * step: q.steps if !step.complete
		{
			step.complete = step.complete_check();
			if !step.complete then q_complete = false;
		}
		if q_complete
		{
			q.complete = true;
			en := create_entity("quest_notification");
			add_props(*en.props, .big_notification);
			string_copy(en.notif_title, "Quest Complete");
			string_copy(en.notif_subtitle, q.name);
			q.on_complete();
			play_sound("quest_complete", random_spread=false);
		}
	}
}

QuestState :: struct
{
	quests: [..]Quest;
	selected_quest: int = -1;
}

Quest :: struct
{
	name: string;
	desc: string;
	
	steps: [..]Step;
	Step :: struct
	{
		complete: bool;
		desc: string;
		complete_check: () -> bool;
	}
	
	unlocked: bool = true;
	complete: bool;
	on_complete: () = () {};
}




				// use the cut points to hide the thirds
				/*
				for 1..2
				{
					cut := create_entity(tprint("cut%", it));
					add_props(cut, .render_sprite, .recieve_damage);
					cut.collision_rect = make_range(8, 14);
					cut.rel_pos.x = tree.rel_pos.x + STUMP_HEIGHT + ROT_OFFSET + TREE_THIRD * it;
					cut.z_layer = tree.z_layer + 0.5;
					cut.health = 20;
					entity_set_sprite(cut, .tree_splitcover);
					
					cut.left_log = handle_from_entity(logs[it-1]);
					cut.right_log = handle_from_entity(logs[it]);
					
					cut.on_damage = cut_damage;
					cut_damage :: (dmg: Entity.DamageEvent)
					{
						self := entity_from_handle(dmg.self);
						if self.health == 0 then return;
						self.damage_alpha = 1.0;
						play_sound("wood");
					}
					
					// ideally I'd like to be able to do some kind of death animation that gets entered each frame...
					// not too sure how I'd go about abstracting that though.
					// like it's basically the dying functionality of this tree lol
					// if .dying, enter state, tick, exit state - is the pattern
					
					cut.on_death = cut_death;
					cut_death :: (dmg: Entity.DamageEvent)
					{
						self := entity_from_handle(dmg.self);
						l_log := entity_from_handle(self.left_log);
						r_log := entity_from_handle(self.right_log);
						self.marked_for_destroy = true;
						play_sound("wood", 1.2, 0.85, false);
						
						l_log.detach_count -= 1;
						if l_log.detach_count == 0
						{
							add_props(l_log, .pick_up);
						}
						
						r_log.detach_count -= 1;
						if r_log.detach_count == 0
						{
							add_props(r_log, .pick_up);
						}
					}
				}
				*/


// PHEW WEEEEEEEEEEE this whole thing has got some STANK on it.
// it's in need of a refactor. Best thing would be to break out the rendering and have it rely on alphas ?
// Also the pile system would be biggest bang for buck.
crafting_system :: () #expand
{
	// TODO - replace items array with pile structure
	player := get_player();

	// get all currently hovered items
	/*
	hover_items: [..]EntityHandle;
	hover_items.allocator = temporary_allocator;
	hover_centre: Vector2;
	{
		pos_sum: float;
		for * st.entities if it.item
		{
			against_rect := range_shift(it.collision_rect, it.position);
			if range_collide(`interact_hitbox, against_rect)
			{
				array_add(*hover_items, handle_from_entity(it));
				pos_sum += it.position.x;
			}
		}

		if hover_items.count
		{
			hover_centre.x = pos_sum/hover_items.count;
			hover_centre.y = 16;
		}
	}

	// hover new pile
	if st.craft_progress == .none && hover_items.count > 1
	{
		st.craft_progress = .hover;
		st.craft_centre = hover_centre;
		
		array_copy(*st.craft_items, hover_items);
	}

	// unhover
	if st.craft_progress == .hover && hover_items.count <= 1
	{
		st.craft_state = .{};
		array_reset(*st.craft_items);
	}

	// X tooltip
	x_visible: bool = st.craft_progress == .hover;
	if x_visible && key_pressed(#char "X")
	{
		set_state(player, .crafting);
		st.craft_progress = .mid;
		st.craft_cursor_pos = st.craft_centre;
		x_visible = false;
	}
	animate_to_target(*st.tooltip_alpha, xx x_visible, 40);
	if !float_zero(st.tooltip_alpha)
	{
		render_st.stack_transform = .{};
		push_text("x", 150, font_name=FONT_1980,
												trs=transform(st.craft_centre, 0, 0.2 * st.tooltip_alpha));
	}
	
	// TODO - refactor out all rendering code so it's running 247 on alphas and cached stuff

	// WE CRAFTIN
	if st.craft_progress == .mid || st.craft_progress == .end
	{
		animate_to_target(*st.craft_end_alpha, xx !st.craft_scuffed_zero_all, 30);
		
		// update cursor pos
		st.craft_cursor_pos += gsf.mouse_delta / st.camera.zoom * 0.5;
		cursor_vector := st.craft_cursor_pos - st.craft_centre;

		recipes: []CraftingRecipeID = .[
			.flint_axe, .flint_sword,
		];
		recipe_root_pos := xy(0, 16);
		spacing :: 32;
		
		// find closest
		selected_slot: int = -1;
		selected_slot_pos: Vector2;
		closest_dp: float;
		for 0..recipes.count-1
		{
			recipe_pos := recipe_root_pos;
			recipe_pos.x -= (recipes.count - 1) * spacing * 0.5;
			recipe_pos.x += it * spacing;
			
			dot_to_cursor := dot(unit_vector(cursor_vector), unit_vector(recipe_pos));
			if length(cursor_vector) > 5.0
			&& (selected_slot == -1 || (dot_to_cursor - 1) > (closest_dp - 1))
			{
				closest_dp = dot_to_cursor;
				selected_slot = it;
				selected_slot_pos = recipe_pos;
			}
		}
		
		// render recipes
		for 0..recipes.count-1
		{
			recipe_pos := recipe_root_pos;
			recipe_pos.x -= (recipes.count - 1) * spacing * 0.5;
			recipe_pos.x += it * spacing;
			
			recipe := get_crafting_recipe(recipes[it]);
			item := get_item(recipe.result.item);
			sprite := get_sprite(item.sprite);
			
			alpha: *float = *st.craft_recipes_alpha[it];
			target := ifx selected_slot == it then 1.0 else 0.0;
			animate_to_target(alpha, target, 20);

			push_quad(sprite, trs=transform(recipe_pos + st.craft_centre, 0, (1-st.tooltip_alpha + <<alpha * 0.1) * st.craft_end_alpha));
			push_text(recipe.name, 100, col=xyzw(1, 1, 1, <<alpha), trs=transform(recipe_pos + st.craft_centre + xy(0, 18), 0, 0.08 * st.craft_end_alpha));
		}
		
		animate_to_target(*st.craft_error_flash, 0, 5);
		
		// render ingredients underneath
		// todo - figure out transition
		if selected_slot != -1
		{
			recipe := get_crafting_recipe(recipes[selected_slot]);
			
			// tally up existing items
			ItemTemp :: struct
			{
				entities: [..]*Entity;
				item: ItemID;
			}
			ground_items: [..]ItemTemp;
			ground_items.allocator = temporary_allocator;
			// fill items
			for recipe.ingredients
			{
				new_item: ItemTemp;
				new_item.item = it.item;
				new_item.entities.allocator = temporary_allocator;
				array_add(*ground_items, new_item);
			}
			
			for * ground_it: ground_items
			{
				for hover_items
				{
					entity := entity_from_handle(it);
					assert(entity.item != 0);
					if ground_it.item == entity.item
					{
						array_add(*ground_it.entities, entity);
					}
				}
			}
			
			craftable := true;
			
			ing_spacing :: 10;
			ing_pos := st.craft_centre + xy(-4, -35);
			for recipe.ingredients
			{
				item := get_item(it.item);
				ground_item := ground_items[it_index];
				existing_count := min(ground_item.entities.count, it.amount);
				
				is_lacking := existing_count < it.amount;
				if is_lacking then craftable = false;
				
				col := WHITE;
				scale_mult := 1.0;
				if is_lacking
				{
					col = lerp(WHITE, RED, st.craft_error_flash);
					scale_mult += st.craft_error_flash * 0.2;
				}
				
				push_quad(get_sprite(item.sprite), trs=transform(ing_pos, 0, st.craft_end_alpha));
				push_text(tprint("%/%", existing_count, it.amount), 100, col=col, trs=transform(ing_pos + xy(12, -1), 0, 0.1 * scale_mult * st.craft_end_alpha));
				
				ing_pos.y += ing_spacing;
			}
			
			if key_pressed(Input.Key_Code.MOUSE_BUTTON_LEFT)
			{
				if craftable
				{
					// CRAFT
					st.craft_scuffed_zero_all = true;
					st.craft_progress = .end;
					en := create_ground_item(recipe.result.item);
					en.position = selected_slot_pos + st.craft_centre - xy(0, en.collision_rect.max.y * 0.5);
					
					// remove items
					for ground_items for it.entities entity_destroy(it);
				}
				else
				{
					st.craft_error_flash = 1.0;
				}
			}
			
			// ending
			if st.craft_progress == .end
			&& float_zero(st.craft_end_alpha)
			{
				st.craft_state = .{};
				array_reset(*st.craft_items);
				set_state(player, .idle);
			}
		}
		
		// render cursor
		line_create(st.craft_centre, st.craft_cursor_pos, xyzw(1, 1, 1, st.craft_end_alpha), 1);
		push_quad(make_range(2, 2), trs=transform(st.craft_cursor_pos, 0, st.craft_end_alpha));
	}
	*/
}


// TODO - multithread this
	// load from disk if not in cache
	/*
	if !texture
	{
		bitmap : Bitmap;
		success := bitmap_load(*bitmap, path);
		if success
		{
			if bitmap.format == .RGBA8
			{
				tex := texture_alloc(xx bitmap.width, xx bitmap.height, bitmap.data.data);
				texture = cache_texture(tex, key);
				
				modtime, size, success := file_modtime_and_size(path);
				assert(success);
				texture.last_modified = modtime;
				if LOG_VERBOSE then log("texture % created", key); 
			}
			else
			{
				log("Texture % is format %. Expected %", key, bitmap.format, Texture_Format.RGBA8);
			}
		}
	}
	*/

	// hot reload
	// todo - use file_watcher instead
	/*
	if texture && texture.last_modified != APOLLO_TIME_INVALID
	{
		modtime, size, success := file_modtime_and_size(path);
		if success && modtime != texture.last_modified
		{
			texture.last_modified = modtime;
			texture.modify_cooldown_timer = 0.1;
		}
		// had to put a cooldown on the modify because aesprite modifies files twice when saving lol - randy
		if tick_timer(*texture.modify_cooldown_timer)
		{
			bitmap : Bitmap;
			success := bitmap_load(*bitmap, path);
			assert(success); // todo - abstract this loading of the bitmap out into own function, proper error checks
			assert(bitmap.width == texture.width && bitmap.height == texture.height && bitmap.format == .RGBA8);

			// copy new data into existing texture
			res : D3D11_MAPPED_SUBRESOURCE;
			ID3D11DeviceContext_Map(render_st.d3d_context, texture.texture, 0, .WRITE_DISCARD, 0, *res);
			memcpy(res.pData, bitmap.data.data, 4 * texture.width * texture.height);
			ID3D11DeviceContext_Unmap(render_st.d3d_context, texture.texture, 0);

			log("hot-reloaded %", key);
		}
	}
	*/

// lambda



   
   // example of an auto-freeing dynamic array across the frame boundary
    player.frame.hit_entities.allocator = frame_allocator;
    if player.last_frame.hit_entities.data
    {
     array_copy(*player.frame.hit_entities, player.last_frame.hit_entities);
     // this'll basically expire for free the moment our chopping state is done,
     // since last frame's hit entities wil get nulled if we don't put in a fresh array
     // LOOK HOW FKING LOCALISED THIS SHIT IS!!! memory arenas lesgoooooo
    }
    
    
    
    
 // meta dumping out mebers
 info := type_info(Stack);
 for info.members
 {
 log("%", it);
 }    
    
    
    
// old manual fixed arena
PERMANENT_SIZE :: #run gigabytes(1);
   WORLD_SIZE :: #run gigabytes(1);
   FRAME_SIZE :: #run megabytes(512);
   TOTAL_SIZE :: PERMANENT_SIZE + WORLD_SIZE + FRAME_SIZE * 2;
   
   // grab one massive ol' buffer
   base_memory := alloc(TOTAL_SIZE, context.default_allocator);
   memory_state.backing_buffer = base_memory;
   memory_state.backing_buffer_size = TOTAL_SIZE;
   
   // init arenas, giving each its own chunk from the backing buffer
   arena_init :: (arena : *Arena, base_memory : *void, size : u64, name : string)
   {
      arena.name = name;
      arena.buffer = base_memory;
      arena.buffer_size = size;
   }
   arena_init(*memory_state.permanent_arena, base_memory, PERMANENT_SIZE, "PERMANENT");
   base_memory += PERMANENT_SIZE;
   arena_init(*memory_state.world_arena, base_memory, WORLD_SIZE, "WORLD");
   base_memory += WORLD_SIZE;
   arena_init(*memory_state.frame_arena[0], base_memory, FRAME_SIZE, "FRAME1");
   base_memory += FRAME_SIZE;
   arena_init(*memory_state.frame_arena[1], base_memory, FRAME_SIZE, "FRAME2");
   base_memory += FRAME_SIZE;
   assert(base_memory - TOTAL_SIZE == memory_state.backing_buffer);
   

 // player damage
 /*
 if being_damaged
 && state != damaged
 {
  entity_set_state(player, damaged);
  health -= 1;
  health = max(0, health);
  if health == 0
  {
   being_damaged = false;
   entity_set_state(player, dead);
   timer1 = 1.0;
  }
  else
  {
   // todo - velocity dir override
   velocity.x = -x_dir * 200.0;
   velocity.y = 100.0;
  }
 }

 // death animation
 if state == dead && timer1
 {
  if tick_timer(*timer1)
  {
   log("Balls.\n");
  }
 }

 // exit damage
 if state == damaged
 {
  down_time :: 1.0;
  if timer1 == 0 then timer1 = down_time;
  if tick_timer(*timer1)
  {
   being_damaged = false;
   entity_set_state(player, idle);
  }
 }
 */

// player attack stuff
 // start attack
 if (state == idle || state == walk) && gsf.key_pressed[Input.Key_Code.MOUSE_BUTTON_LEFT]
 {
  last_state, time_ago:= entity_get_first_last_state(player, .[attack1, attack2]);

  if last_state == attack1 && time_ago < 0.5
  {
   entity_set_state(player, attack2);
   entity_set_sprite(player, SpriteID.player_attack2); 
  }
  else
  {
   entity_set_state(player, attack1);
   entity_set_sprite(player, SpriteID.player_attack1);
  }
 }

 // attack keyframe
 if (state == attack1 || state == attack2) && !has_attacked
 {
  has_attacked = true;
  ogre_hitbox: Range2;
  ogre_hitbox.max = xy(60, 90);
  ogre_hitbox = range_bottom_center(ogre_hitbox);

  for * st.entities if it.flags & .recieve_damage && it != player
  {
   against_rect:= range_shift(ogre_hitbox, it.position);
   //debug_rect(against_rect, 200);
   if range_collide(attack_hitbox, against_rect)
   {
    // play damage state
    //it.being_damaged = true;
   }
  }

  //debug_rect(hitbox, 200);
 }

 // end attac
 if (state == attack1 || state == attack2) && frame.did_anim_finish
 {
  entity_set_state(player, idle);
  entity_set_sprite(player, SpriteID.player_idle);
  has_attacked = false;
 }



 // old timer dodgeroll
 /*
 if state == roll && time_left
 {
  if tick_timer(*time_left)
  {
   entity_set_sprite(player, SpriteID.player_idle);
   entity_set_state(player, idle);
  }
  alpha := 1-time_left / dodgeroll_length;

  end_position := start_position + xy(x_dir * 50.0, 0);

  position = lerp(start_position, end_position, alpha);
  rotation = 360 * alpha * -x_dir;
  rotation_offset = xy(0, range_size(rect).y / -2.0);
  // TODO - curves :)

  KeyFrameRot :: struct
  {
   alpha : float;
   rotation : float;
  }
  key_rot : [] KeyFrameRot = .[
  .{0, 0},
  .{0.4, 45.0},
  .{0.6, 135.0},
  .{1, 360}
  ];

  // todo - sample keyframe

  // immediate mode animation keyframes
 }
 */
 
  // start dodgeroll
 //dodgeroll_length :: 0.2;
 // if (state == walk || state == idle)
 // && st.key_down[Input.Key_Code.SHIFT] && input_axis.x != 0.0
 // {
 //  entity_set_state(player, roll);
 //  entity_set_sprite(player, SpriteID.player_roll);
 //  velocity.x = x_dir * 400.0;
 //  //time_left = dodgeroll_length;
 //  //start_position = position;
 // }

 // if state == roll
 // && sprite_id == SpriteID.player_roll
 // && frame.did_anim_finish
 // {
 //  entity_set_sprite(player, SpriteID.player_idle);
 //  entity_set_state(player, idle);
 // }


// ogre update
for * ogre: st.entities if ogre.flags & .valid && ogre.kind == EntityKind.ogre
{
 using ogre;
 using EntityState;
 x_speed_target = 0.0;
 pos_diff:= player.position - position;
 dist_to_player:= abs(pos_diff.x);

 // recieve damage animation thing
 /*
 if being_damaged
 {
  flash_length :: 0.2;
  if timer1 == 0 then timer1 = flash_length;
  col.w = timer1 / flash_length + 2.0;

  if tick_timer(*timer1)
  {
   log("yeetus\n");
  }
 }
 */

 // ogre attacc
 if !has_attacked
 && (state == attack1 && animation_frame == 18) || (state == attack2 && animation_frame == 10)
 {
  has_attacked = true;

  hitbox: Range2;
  hitbox.max = ifx state == attack1 then xy(88, 152) else xy(40, 20);
  if x_dir == -1 then hitbox = range_flip_x(hitbox);
  hitbox = range_shift(hitbox, position);
  debug_rect(hitbox, 200);

  player_hitbox := player.collision_rect;
  player_hitbox = range_bottom_center(player_hitbox);

  for * st.entities if it.flags & .recieve_damage && it != ogre
  {
   against_rect:= range_shift(player_hitbox, it.position);
   //debug_rect(against_rect, 200);
   if range_collide(hitbox, against_rect)
   {
    it.being_damaged = true;
    it.x_dir = -x_dir;
   }
  }
 }

 // finish attacc
 if (state == attack1 || state == attack2) && frame.did_anim_finish
 {
  has_attacked = false;
  entity_set_state(ogre, idle);
  entity_set_sprite(ogre, SpriteID.ogre_idle);
 }

 // should start walk
 if state == idle
 && dist_to_player < 200.0
 && player.state != dead
 {
  entity_set_state(ogre, walk);
  entity_set_sprite(ogre, SpriteID.ogre_walk);
 }

 // change direction
 if !(state == attack1 || state == attack2)
 || state == attack1 && animation_frame < 12
 || state == attack2 && animation_frame < 8
 {
  x_dir = sign(pos_diff.x); 
 }

 // move to player
 if state == walk
 {
  if dist_to_player < 40.0
  {
   entity_set_state(ogre, attack2);
   entity_set_sprite(ogre, SpriteID.ogre_attack2);
  }
  else if dist_to_player < 70.0
  {
   entity_set_state(ogre, attack1);
   entity_set_sprite(ogre, SpriteID.ogre_attack1);
  }
  else
  {
   x_speed_target = 30.0;
  }
 }
}


/*


 // sine wave example
 hertz := 40;
 wave_period := sample_rate / hertz;
 val := sin(5.0 * PI * st.temp_counter / wave_period);
 val *= 0.1; // hearing protection lol
 st.buffer[st.buffer_pos] = val;
 st.buffer[st.buffer_pos+1] = val;
 st.buffer_pos += 2;
 st.temp_counter += 1;
 

callback model example

audio_stream_callback :: (buffer : *float, num_frames : s32, num_channels : s32) -> void #c_call
{
 new_context : Context;
 push_context new_context
 {
  assert(num_channels == 1);
  sample_rate := saudio_sample_rate();
  hertz := 40;
  wave_period := sample_rate / hertz;

  for 0..num_frames-1
  {
   val := sin(5.0 * PI * st.counter / wave_period);
   val *= 0.1;
   buffer[it] = val;
   st.counter += 1;
  }
 }
}
*/

// push model example
 /*
 expected_samples := saudio_expect();
 for 0..expected_samples-1
 {
  output : Vector2;
  sound := st.sound_instance_first;
  next_sound : SoundInstance;
  while sound
  {
   next_sound := sound.next; // grab it straight away to prevent destroy fuckery
   defer sound = next_sound;
   
   wave := sound_wave_from_key(sound.wave_key);
   assert(wave.channels == 2);
   
   samp : *s16 = xx wave.sample_buffer.data;
   sample_index : int = xx floor(sound.samples_played * 2.0);
   sample_index = sample_index - sample_index % 2;
   sample_frac : float = xx frac(sound.samples_played);
   for 0..1
   {
    a := s16_to_float(samp[sample_index]);
    b := s16_to_float(samp[sample_index+2]);
    // this is kinda sketch, but it was overruning the buffer without it. Probs just me having dodgey math... - randy
    has_next_sample : bool = sample_index + 2 < wave.sample_buffer.count / 2;
    value : float = ifx has_next_sample then lerp(a, b, sample_frac) else a;
    
    output.component[it] += master_vol * value * sound.volume.component[it];
    sample_index += 1;
   }
   
   // advance sample   
   sound.samples_played += sound.pitch;
   if sound.samples_played * 2 >= xx wave.sample_buffer.count / 2.0
   {
    sound.samples_played = 0;
    if sound.loop_count > 0 then sound.loop_count -= 1;
    if sound.loop_count == 0 then sound_instance_destroy(sound);
   }
  }
  output.x = clamp(output.x, -1, 1);
  output.y = clamp(output.y, -1, 1);
  output.x *= HEARING_PROTECTION;
  output.y *= HEARING_PROTECTION;
  
  // write value to the sound buffer
  st.buffer[st.buffer_pos]   = output.x;
  st.buffer[st.buffer_pos+1] = output.y;
  st.buffer_pos += 2;
  
  // flush intermediate buffer to the actual sound buffer
  if st.buffer_pos >= st.buffer.count
  {
   pushed := saudio_push(st.buffer.data, st.buffer.count / 2);
   assert(pushed == st.buffer.count / 2);
   memset(st.buffer.data, 0, size_of(float) * st.buffer.count);
   st.buffer_pos = 0;
  }
 }
 */



/*
old sound player example

#import "Sound_Player";
WAV :: "wav";
OGG :: "ogg";

SoundState :: struct
{
 sound_player : *Sound_Player; 
}
st : SoundState;

sound_init :: ()
{
 st.sound_player = New(Sound_Player);
 st.sound_player.update_history = true;

 success := init(st.sound_player, xx st.window, true, true);
 assert(success);
}

play_sound :: (name : string)
{
 
}

// ---

update_sound_player :: (dt: float)
{
 // Move sound streams forward by dt.
 lock(*st.sound_player.sound_mutex);
 defer unlock(*st.sound_player.sound_mutex);

 pre_entity_update(st.sound_player);

 // @Incomplete We're not removing sound streams once they're consumed.
 for st.sound_player.streams {
  it.marked = true;
 }

 post_entity_update(st.sound_player, dt);
}

play_sound :: (data: *Mixer_Sound_Data, perturb: bool = true) -> *stream {
 stream := make_stream(st.sound_player, data);

 if stream {
  stream.sound_data = data;
 }

 if perturb && stream {
  stream.user_volume_scale = random_get_within_range(0.7, 1);
  stream.desired_rate = random_get_within_range(0.7, 1.22);
 }

 stream.repeat_end_position = cast(int)(data.sampling_rate * 234.475);  // @Temporary @Hack! We do not get the duration by default from an ogg file...
 
 return stream;
}

load_sound :: (basename: string) -> *Mixer_Sound_Data {
 name := tprint("res/%.wav", basename);
 data := load_audio_file(name);

 if !data {
  print("Error: Could not load wav file: %\n", name);
  assert(false); 
  return null;
 }

 return data;
}

load_audio_file :: (name : string) -> *Mixer_Sound_Data {
 data : *Mixer_Sound_Data = null;

 file_data, success := read_entire_file(name);
 if !success return data;

 has_extension :: (name: string, extension: string) -> bool {
  if name.count < extension.count  return false;
  test := name;
  advance(*test, name.count - extension.count);
  return test == extension;
 }

 if has_extension(name, WAV) {
  data = New(Mixer_Sound_Data);
  data.name = copy_string(name);
  data.buffer = file_data;

  format, samples, success2, extra := get_wav_header(data.buffer);
  if !success2 {
   log_error("Unable to parse '%' as wav.\n", data.full_path);
   return data;
  }

 if format.wFormatTag == WAVE_FORMAT_PCM {
  data.type                     = .LINEAR_SAMPLE_ARRAY;
  data.nchannels                = cast(u16) format.nChannels;
  data.nsamples_times_nchannels = samples.count/2;
  } else if format.wFormatTag == WAVE_FORMAT_DVI_ADPCM {
   data.type             = .ADPCM_COMPRESSED;
   data.wSamplesPerBlock = extra.wSamplesPerBlock;
   data.nBlockAlign      = format.nBlockAlign;

   data.nchannels = cast(u16) format.nChannels;
   // The value in the FACT chunk is number of samples by time. 
   data.nsamples_times_nchannels = extra.wSamplesAccordingToFactChunk * data.nchannels;
  } else {
   assert(false);
  }

  data.samples       = cast(*s16) samples.data;
  data.sampling_rate = cast(u32) format.nSamplesPerSec;
  } else if has_extension(name, OGG) {
  data = New(Mixer_Sound_Data);
  data.name   = copy_string(name);
  data.buffer = file_data;
  data.type   = .OGG_COMPRESSED;
  } else {
   // Unsupported format.
  }

 return data;
}
*/