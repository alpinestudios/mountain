/*

Issues to fix for next version:
- hashing, separate name and the hash
- need to force push_() to select a scope like with the ol' c deferloop

*/

UI_State :: struct
{
	box_table: Table(string, Box, djb2_hash);
	build_gen: u64;
	hot_box: *Box;
	active_box: *Box;
	mouse_drag_start: Vector2;
	
	debug_ui_boxes: bool = DEBUG_UI_BOXES;
	
	// per-frame data
	frame: Frame;
	Frame :: struct
	{
		root: *Box;
		hot_box_found: bool;
		using stacks: UI_Stacks;
	}
}

MAX_BOX_COUNT :: 256;

BoxFlags :: enum
{
	clickable :: 1<<0;
	
	draw_border :: 1<<1;
	draw_fill :: 1<<2;
	draw_bg :: 1<<3;
	draw_text :: 1<<4;
	draw_hot_effects :: 1<<5; // hot == hovering
	draw_active_effects :: 1<<6; // active == pressed
	draw_sprite :: 1<<7;
	debug_draw :: 1<< 8;

	skip_layout :: 1<<9;
	// makes this box practically invisible to the auto-layout algorithm
	// can then directly set a floating_pos, which'll still be relevant to the parent's tho
	floating_x :: 1<<10;
	floating_y :: 1<<11;
	floating :: floating_x | floating_y;
	
	show_name_hash :: 1<<20;
}

Box :: struct
{
	valid: bool;
	debug_name: string;

	// tree links
	first: *Box;
	last: *Box;
	next: *Box;
	//prev: *Box;
	parent: *Box;
	child_count: int;

	// persistent data
	key: string;
	last_gen_touched: u64;
	hot_t: float;
	active_t: float;
	
	// user-code value registers lol
	value: float;
	target: float;

	// computed auto-layout
	calc_rel_position: Vector2;
	calc_size: Vector2;
	rel_rect: Range2;
	rect: Range2;

	// state info from builders
	flags: BoxFlags;
	name: string;
	display_string: string;
	pref_size: [Axis2.COUNT] Size;
	child_layout_axis: Axis2;
	fill_col: Vector4;
	bg_col: Vector4;
	border_col: Vector4;
	multiply_col: Vector4;
	//font_height: int;
	floating_pos: Vector2;
	text_justify_x: PivotX;
	text_justify_y: PivotY;
	text_col: Vector4;
	text_edge_pad: float;
	font: string;
	font_size: int;
	opacity: float;
	sprite_id: SpriteID;
	quad_flags: QuadFlags;
	rect_pivot_x: PivotX;
	rect_pivot_y: PivotY;
	z_layer: float;
	disable_signal: bool;
	render_adjust_trs: Transform2;
	// randy: NOTE
	// I reallllly don't like having these quad properties duplicated in here, we're essentially duplicating
	// them in two spots because we don't have access to the quad...
	// Not sure what the solution here is though, maybe getting some kind of QuadAttributes thing that we
	// use to eventually construct the quad? Idk broski.
	// I reckon I just need to reduce the complexity in the renderer tbh.
	slice_x_pct: float;
	white_override: float;
	colour_override:= WHITE;
	colour_override_amount: float;
}

Signal :: struct
{
	contains: bool;
	hovering: bool;
	pressed: bool;
	released: bool;
	clicked: bool;
	dragging: bool;
	drag_delta: Vector2;
	
	pressed_r: bool;
	released_r: bool;
	clicked_r: bool;
}

// there's some fishy stuff going on with this, gonna avoid it for now. Very helpful syntax if I can get it work & be clear at the call-site
// TODO - finish reading for_expansions
/*
for_expansion :: (root: *Box, body: Code, flags: For_Flags) #expand
{
	__child := root.first;
	__index := 0;
	while __child
	{
		`it := __child;
		`it_index := __index;
		#insert body;
		__child = __child.next;
		__index += 1;
	}
}
*/

Size :: struct
{
	kind: Kind;
	Kind :: enum
	{
		nil;
		pixels;
		percent_of_parent;
		size_by_children;
		text_dim;
		size_by_sprite;
	}
	value: float;
	strictness: float;
}

size_by_sprite :: (strictness: float) -> Size
{
	return .{.size_by_sprite, 0, strictness};
}

size_by_children :: (strictness: float) -> Size
{
	return .{.size_by_children, 0, strictness};
}

text_dim :: (strictness: float = 1.0) -> Size
{
	return .{.text_dim, 0, strictness};
}

pct_parent :: (pct: float, strictness: float = 1.0) -> Size
{
	return .{.percent_of_parent, pct, strictness};
}

px :: (pixels: float, strictness: float = 1.0) -> Size
{
	return .{.pixels, pixels, strictness};
}

em :: (pct_font_size: float, strictness: float = 1.0) -> Size
{
	return .{.pixels, pct_font_size * top_font_size(), strictness};
}

ui_init :: (ui_state: *UI_State)
{
	st = ui_state;
	push_allocator(context.default_allocator);
	init(*ui.box_table, 1024);
}

ui_start :: () #expand
{
	ui.build_gen += 1;
	ui.frame = UI_State.Frame.{};
	window_w := `app.window_w;
	window_h := `app.window_h;

	// recycle stale boxes
	for * ui.box_table
		if it.last_gen_touched + 1 < ui.build_gen
	{
		table_remove(*ui.box_table, it.key);
	}
	
	if ui.active_box && ui.active_box.last_gen_touched + 1 < ui.build_gen
	{
		ui.active_box = null;
	}
	if ui.hot_box && ui.hot_box.last_gen_touched + 1 < ui.build_gen
	{
		ui.hot_box = null;
	}

	// base empty root, origin at 0,0
	ui.frame.root = make_box(BoxFlags.floating, "root");
	set_next_parent(ui.frame.root);
	
	// :screen_space root, origin at top-left
	set_next_pref_width(px(cast(float)window_w, 1.0));
	set_next_pref_height(px(cast(float)window_h, 1.0));
	set_next_floating_x(window_w * -0.5);
	set_next_floating_y(window_h * 0.5);
	_push_child_layout_axis(Axis2.Y);
	screen := make_box(BoxFlags.floating, "screen_space_root");
	_push_parent(screen);
	
	// don't need this? just gonna use the box to cache values lol
	// loop thru all boxes and tick animations
	// for * ui.box_table if it.flags & .anim_timer
	// {
	// 	tick_timer(*it.anim_timer, delta_t());
	// }
}

// ### for hashing everything to the right of it (omitting the left hand side)
// ## still hashes everything, but only renders the left hand side
make_box :: (flags: BoxFlags, name: string) -> *Box
{
	box: *Box = null;
	
	// get the actual key from the name
	hash_key := name;
	index := find_index_from_right(name, "###");
	if index != -1
	{
		hash_key = slice(name, index + 3, name.count-index);
	}
	
	if hash_key != ""
	{
		// find existing box, or just slap a new one in the table
		box = table_find_pointer(*ui.box_table, hash_key);
		if !box
		{
			new_box := Box.{};
			new_key := copy_string(hash_key, permanent_allocator);
			box = table_add(*ui.box_table, new_key, new_box);
			box.key = new_key;
			assert(ui.box_table.count < MAX_BOX_COUNT, "Max box count reached!");
		}
		
		assert(box.last_gen_touched != ui.build_gen, "Key '%' collision! You'll need to make it unique somehow", hash_key);
	}
	else
	{
		box = New(Box, true, __temporary_allocator);
	}
	assert(box != null);
	box.valid = true;

	// clear last frame's hierarchy
	box.parent = null;
	box.first = null;
	box.last = null;
	box.next = null;
	box.child_count = 0;

	// attach to the current parent
	parent := top_parent();
	if parent
	{
		// push to the back of the linked list
		if !parent.first then parent.first = box;
		if parent.last then parent.last.next = box;
		parent.last = box;

		parent.child_count += 1;
		box.parent = parent;
	}

	// state
	{
		box.last_gen_touched = ui.build_gen;
		box.name = name;
		box.display_string = "";
		box.flags = flags | top_flags();
		box.pref_size[Axis2.X] = top_pref_width();
		box.pref_size[Axis2.Y] = top_pref_height();
		box.child_layout_axis = top_child_layout_axis();
		box.fill_col = top_fill_col();
		box.bg_col = top_bg_col();
		box.multiply_col = top_multiply_col();
		box.border_col = top_border_col();
		box.text_justify_x = top_text_justify_x();
		box.text_justify_y = top_text_justify_y();
		box.text_col = top_text_col();
		box.text_edge_pad = top_text_edge_pad();
		box.font = top_font();
		box.font_size = top_font_size();
		box.opacity = top_opacity();
		box.quad_flags = top_quad_flags();
		box.rect_pivot_x = top_rect_pivot_x();
		box.rect_pivot_y = top_rect_pivot_y();
		box.z_layer = top_z_layer();
		box.disable_signal = top_disable_signal();
		// :stack

		// fixed floating positions
		box.calc_rel_position.x = top_floating_x();
		box.calc_rel_position.y = top_floating_y();
	}

	auto_pop_stacks();

	return box;
}

signal_from_box :: (box: *Box) -> Signal #expand
{
	sig : Signal;
	mouse_pos := screen_mouse_to_cardinal();
	mouse_hover := range_contains(box.rect, mouse_pos);
	sig.contains = mouse_hover;

	can_interact: bool = !box.disable_signal;

	// clear hot / active box if we disable interaction
	if !can_interact
	{
		if ui.active_box == box then ui.active_box = null;
		if ui.hot_box == box then ui.hot_box = null;
	}

	if box.flags & .clickable
		&& can_interact
	{
		// NOTE - we'd proabbly wan't to be storing the boxes as keys instead of ptrs right?
		// is there any siutation where they'd invalidate?
		
		// hot box
		if ui.active_box == null
			&& (ui.hot_box == null || !ui.frame.hot_box_found)
			&& mouse_hover
		{
			ui.hot_box = box;
			ui.frame.hot_box_found = true;
			sig.hovering = true;
		}
		else if ui.hot_box == box
			&& (mouse_hover || ui.active_box == box)
		{
			// continue the dragging
			ui.hot_box = box;
			ui.frame.hot_box_found = true;
			sig.hovering = true;
		}
		else if ui.hot_box == box
			&& !mouse_hover
		{
			ui.hot_box = null;
		}
		
		// left mouse
		if ui.hot_box == box
			&& ui.active_box == null
			&& key_pressed(.MOUSE_BUTTON_LEFT)
		{
			consume_key(.MOUSE_BUTTON_LEFT);
			ui.active_box = box;
			ui.mouse_drag_start = mouse_pos;
			sig.pressed = true;
			sig.dragging = true;
		}
		else if ui.active_box == box
		{
			sig.dragging = true;
			sig.drag_delta = mouse_pos - ui.mouse_drag_start;
			if key_released(.MOUSE_BUTTON_LEFT)
			{
				ui.active_box = null;
				sig.clicked = mouse_hover;
				sig.released = true;
			}
		}
		
		// right mouse
		if ui.hot_box == box
			&& ui.active_box == null
			&& key_pressed(.MOUSE_BUTTON_RIGHT)
		{
			consume_key(.MOUSE_BUTTON_RIGHT);
			ui.active_box = box;
			sig.pressed_r = true;
		}
		else if ui.active_box == box
		{
			if key_released(.MOUSE_BUTTON_RIGHT)
			{
				ui.active_box = null;
				sig.clicked_r = mouse_hover;
				sig.released_r = true;
			}
		}
	}

	return sig;
}

display_string_from_box_name :: (box: *Box) -> string
{
	str := box.name;
	if !(box.flags & .show_name_hash)
	{
		// chop off the end hash
		index := find_substring(box.name, "##");
		if index != -1 then str.count = index;
	}
	return str;
}

//
// layout
//

// disabled the floors because I feel like we need dat precision
// there was some cases of things being rounded to the wrong int and putting the UI outta whack

solve_standalone_sizes :: (root: *Box, axis: Axis2)
{
	if root.pref_size[axis].kind ==
	{
		case .pixels;
		root.calc_size.component[axis] = root.pref_size[axis].value;

		case .size_by_sprite;
		root.calc_size.component[axis] = get_sprite_size(root.sprite_id).component[axis];

		case .text_dim;
		str := display_string_from_box_name(root);
		
		width, height: float;
		{
			push_allocator(context.default_allocator);
			font := get_font_at_size("res/font/", root.font, root.font_size);
			width = xx prepare_text(font, str);
			height = xx font.character_height;
		}
		
		if axis ==
		{
			case .X;
			root.calc_size.x = ceil(width + root.text_edge_pad * 2);
			case .Y;
			root.calc_size.y = height;
		}
	}

	// recursive
	child := root.first;
	while child
	{
		defer child = child.next;
		solve_standalone_sizes(child, axis);
	}
}

solve_upward_dependant_sizes :: (root: *Box, axis: Axis2)
{
	if root.pref_size[axis].kind ==
	{
		case .percent_of_parent;
		ancestor : *Box;
		parent := root.parent;
		while parent
		{
			if parent.pref_size[axis].kind != .size_by_children
			{
				ancestor = parent;
				break;
			}
			parent = parent.parent;
		}
		if ancestor
		{
			root.calc_size.component[axis] = ancestor.calc_size.component[axis] * root.pref_size[axis].value;
			// root.calc_size.component[axis] = floor(root.calc_size.component[axis]);
		}
	}

	// recursive
	child := root.first;
	while child
	{
		defer child = child.next;
		solve_upward_dependant_sizes(child, axis);
	}
}

solve_downward_dependant_sizes :: (root: *Box, axis: Axis2)
{
	// recursive
	{
		child := root.first;
		while child
		{
			defer child = child.next;
			solve_downward_dependant_sizes(child, axis);
		}
	}
	
	if root.pref_size[axis].kind ==
	{
		case .size_by_children;
		total_child_size: float;
		child := root.first;
		while child
		{
			defer child = child.next;
			if !(child.flags & .skip_layout) && child.pref_size[axis].kind != .percent_of_parent
			{
				ifx axis == root.child_layout_axis
				then total_child_size += child.calc_size.component[axis];
				else total_child_size = Max(total_child_size, child.calc_size.component[axis]);
			}
		}
		root.calc_size.component[axis] = total_child_size;
		//root.calc_size.component[axis] = floor(root.calc_size.component[axis]);
	}
}

solve_final_rect :: (root: *Box, axis: Axis2)
{
	// solve size voilations
	//
	total_taken_space_from_children: float;
	total_fixup_budget_from_children: float;
	// if !overflow flag
	{
		child := root.first;
		while child
		{
			defer child = child.next;
			if child.flags & .floating_x << axis || child.flags & .skip_layout then continue;
			
			if axis == root.child_layout_axis
				then total_taken_space_from_children += child.calc_size.component[axis];
				else total_taken_space_from_children = Max(total_taken_space_from_children, child.calc_size.component[axis]); // get the biggest child size instead
				
			// grab the potential budget based on the strictness of the size
			fixup_budget_this_child := child.calc_size.component[axis] * (1.0 - child.pref_size[axis].strictness);
			total_fixup_budget_from_children += fixup_budget_this_child;
		}
	}
	
	available_space := root.calc_size.component[axis];
	
	// fix up children as much as possible
	// if !overflow flag
	{
		voilated_space := total_taken_space_from_children - available_space;
		if voilated_space > 0 && total_fixup_budget_from_children > 0
		{
			child := root.first;
			while child
			{
				defer child = child.next;
				if child.flags & .floating_x << axis || child.flags & .skip_layout then continue;
				
				fixup_budget_this_child := child.calc_size.component[axis] * (1.0 - child.pref_size[axis].strictness);
				fixup_size_this_child := ifx axis == root.child_layout_axis
					then fixup_budget_this_child * (voilated_space / total_fixup_budget_from_children)
					else child.calc_size.component[axis] - available_space;
				
				fixup_size_this_child = clamp(fixup_size_this_child, 0, fixup_budget_this_child);
				child.calc_size.component[axis] -= fixup_size_this_child;
				// child.calc_size.component[axis] = floor(child.calc_size.component[axis]);
			}
		}
	}
	
	//
	// set children relative positions
	if axis == root.child_layout_axis
	{
		last_size: float;
		pos: float;
		child := root.first;
		while child
		{
			defer child = child.next;
			if child.flags & .floating_x << axis then continue;
			
			if child.flags & .skip_layout
			{
				child.calc_rel_position.component[axis] = pos - last_size;
			}
			else
			{
				child.calc_rel_position.component[axis] = pos;
				last_size = child.calc_size.component[axis] * ifx axis == .Y then -1 else 1;
				pos += last_size;
			}
		}
	}
	else
	{
		child := root.first;
		while child
		{
			defer child = child.next;
			if child.flags & .floating_x << axis then continue;
			
			child.calc_rel_position.component[axis] = 0;
		}
	}

	// set children rects
	child := root.first;
	while child
	{
		defer child = child.next;
		if axis == .Y
		{
			// make sure the Y goes downward. kinda scuffed but it gets the job done lol - randy
			child.rel_rect.min.component[axis] = child.calc_rel_position.component[axis];
			child.rel_rect.max.component[axis] = child.calc_rel_position.component[axis] - child.calc_size.component[axis];
			child.rect.min.component[axis] = root.rect.min.component[axis] + child.rel_rect.min.component[axis];
			child.rect.max.component[axis] = child.rect.min.component[axis] - child.calc_size.component[axis];
		
			// adjust based on rect pivot 
			if child.rect_pivot_y ==
			{
				case .bottom;    child.rect = range_shift(child.rect, .{0, range_size(child.rect).y});
				case .center;    child.rect = range_shift(child.rect, .{0, range_size(child.rect).y * 0.5});
				case .top;
			}
		}
		else
		{
			child.rel_rect.min.component[axis] = child.calc_rel_position.component[axis];
			child.rel_rect.max.component[axis] = child.calc_rel_position.component[axis] + child.calc_size.component[axis];
			child.rect.min.component[axis] = root.rect.min.component[axis] + child.rel_rect.min.component[axis];
			child.rect.max.component[axis] = child.rect.min.component[axis] + child.calc_size.component[axis];
			
			// adjust based on rect pivot
			if child.rect_pivot_x ==
			{
				case .left;
				case .center;    child.rect = range_shift(child.rect, .{range_size(child.rect).x * -0.5, 0});
				case .right;     child.rect = range_shift(child.rect, .{-range_size(child.rect).x, 0});
			}
		}
		
		// floooor
		// if ! floating?
		// child.rect.min.component[axis] = floor(child.rect.min.component[axis]);
		// child.rect.max.component[axis] = floor(child.rect.max.component[axis]);
	}
	root.rect = range_correct(root.rect);

	// recursive
	child = root.first;
	while child
	{
		defer child = child.next;
		solve_final_rect(child, axis);
	}
}

ui_end_and_render :: ()
{
	// end build
	assert(ui.frame.root != null); // no root? make sure ya call ui_start
	
	// layout pass
	for 0..Axis2.Y
	{
		solve_standalone_sizes(ui.frame.root, it); 
		solve_upward_dependant_sizes(ui.frame.root, it);
		solve_downward_dependant_sizes(ui.frame.root, it);
		solve_final_rect(ui.frame.root, it);
	}

	// animation pass
	animate_box_recursive :: (box: *Box)
	{
		anim_rate :: 50;
		target_hot: float = xx (box == ui.hot_box);
		target_active: float = xx (box == ui.active_box);
		animate_to_target(*box.hot_t, target_hot, delta_t(), rate=anim_rate);
		animate_to_target(*box.active_t, target_active, delta_t(), rate=anim_rate); 
		
		// recurse down
		child := box.first;
		while child
		{
			defer child = child.next;
			animate_box_recursive(child);
		}
	}
	animate_box_recursive(ui.frame.root);

	// @render
	
	batch_set_projection(app.camera_to_clip);
	render_box_recursive(ui.frame.root);
}

box_parent_count :: (box: Box) -> int
{
	count := 0;
	p := box.parent;
	while p
	{
		count += 1;
		p = p.parent;
	}
	return count;
}

// @specific - relies on the rendering layer
// pull it out into a seperate file?
render_box_recursive :: (box: *Box)
{
	assert(box.valid, "Invalid box!");
	
	batch_set_lut_strength_for_scope(0.0);
	
	// debug
	draw_debug := box.flags & .debug_draw || st.debug_ui_boxes;
	if draw_debug
	{
		mouse_pos := screen_mouse_to_cardinal();
		mouse_hover := range_contains(box.rect, mouse_pos);
		p_count := box_parent_count(box);
		
		// draw parent count at centre
		if p_count > 1
		{
			trs := make_transform(box.rect.min + range_size(box.rect) / 2.0);
			txt := box.debug_name;
			if txt == "" then txt = tprint("%", p_count);
			push_text(txt, 32, pivot_x=.left, flags=box.quad_flags, trs=trs, z_layer = 1.2);
		}
		
		// colour it
		if p_count > 2
		{
			seed :u64= cast(u64) (box.rect.min.x * box.rect.min.y * box.rect.max.x * box.rect.max.y);
			scope_random_seed(seed);
			
			col := xyzw(random_get_within_range(0, 1), random_get_within_range(0, 1), random_get_within_range(0, 1), 0.2);
			if mouse_hover then col.w *= 2;
			draw_rect(box.rect, col=col, flags=box.quad_flags, z_layer = 1.2);
		}
	}
	
	// EFFECTS
	effects_adjustment := 0.0;
	if box.flags & .draw_active_effects || box.flags & .draw_hot_effects
	{
		if box.flags & .draw_active_effects
		{
			effects_adjustment += (box.active_t)/2;
		}
		if box.flags & .draw_hot_effects
		{
			effects_adjustment += (box.hot_t)/2;
		}
		
		// gonna implement this in each draw path instead of overlaying. That way it's localised to the specific box.
		// col := xyzw(0.3, 0.3, 0.3, 1);
		// col.w = lerp(0.0, 0.7, alpha) * box.opacity;
		// draw_rect(box.rect, col=col, flags=box.quad_flags, z_layer = box.z_layer-0.05);
	}
	
	
	// draw_bg
	if box.flags & .draw_bg
	{
		col := box.bg_col;
		col.w = box.bg_col.w * box.opacity;
		col = highlight_colour(col, effects_adjustment);
		col *= box.multiply_col;

		trs := box.render_adjust_trs;
		trs.pivot_offset = -lerp(box.rect.min, box.rect.max, 0.5);

		draw_rect(box.rect, col=col, flags=box.quad_flags, trs=trs, z_layer = box.z_layer);
	}
	
	// FILL SHIT
	if box.flags & .draw_fill
	{
		col := box.fill_col;
		col.w = box.fill_col.w * box.opacity;
		col = highlight_colour(col, effects_adjustment);
		col *= box.multiply_col;
		
		trs := box.render_adjust_trs;
		trs.pivot_offset = -lerp(box.rect.min, box.rect.max, 0.5);

		draw_rect(box.rect, col=col, flags=box.quad_flags, trs=trs, z_layer = box.z_layer);
	}
	
	// BORDER
	if box.flags & .draw_border || draw_debug
	{
		col := box.border_col;
		col.w *= box.opacity;
		col = highlight_colour(col, effects_adjustment);
		col *= box.multiply_col;
		
		thickness := 2.0;
		
		left := box.rect;
		left.max.x = left.min.x;
		left.max.x += thickness;
		draw_rect(left, col=col, flags=box.quad_flags, z_layer = box.z_layer);
		
		right := box.rect;
		right.min.x = right.max.x;
		right.min.x -= thickness;
		draw_rect(right, col=col, flags=box.quad_flags, z_layer = box.z_layer);
		
		top := box.rect;
		top.min.y = top.max.y;
		top.min.y -= thickness;
		draw_rect(top, col=col, flags=box.quad_flags, z_layer = box.z_layer);
		
		bot := box.rect;
		bot.max.y = bot.min.y;
		bot.max.y += thickness;
		draw_rect(bot, col=col, flags=box.quad_flags, z_layer = box.z_layer);
	}
	
	// SPRITE
	if box.flags & .draw_sprite
	{
		// sized to maintain aspect ratio, fitting within the constraints of the box.rect
		render_rect := box.rect;
		render_size := range_size(render_rect);
		sprite := get_resource(box.sprite_id);
		sprite_rect := sprite.rect;
		sprite_size := range_size(sprite_rect);
		
		// scale to fit within the render rect
		scale_by_width: bool;
		if render_size.x >= render_size.y
		{
			if sprite_size.x > sprite_size.y
			{
				scale_by_width = true;
			}
			else
			{
				scale_by_width = false;
			}
		}
		else
		{
			if sprite_size.x >= sprite_size.y
			{
				scale_by_width = true;
			}
			else
			{
				scale_by_width = false;
			}
		}
		scale := ifx scale_by_width then render_size.x / sprite_size.x else render_size.y / sprite_size.y;
		sprite_rect = range_scale(sprite_rect, scale);
		
		diff := range_size(render_rect) - range_size(sprite_rect); // for centering
		
		render_rect.max = render_rect.min;
		render_rect.max += range_size(sprite_rect);
		render_rect = range_shift(render_rect, diff * 0.5);
		
		col := xyzw(1, 1, 1, box.opacity);
		col = highlight_colour(col, effects_adjustment);
		col *= box.multiply_col;
		
		trs := box.render_adjust_trs;
		trs.pivot_offset = -lerp(render_rect.min, render_rect.max, 0.5);
		
		//push_quad(render_rect, col=WHITE, flags=box.quad_flags, z_layer = box.z_layer);
		draw_rect(
			  render_rect
			, texture = texture_from_sprite(sprite)
			, col=col
			, slice_pct=box.slice_x_pct
			, flags=box.quad_flags
			, trs=trs
			, z_layer = box.z_layer
			, colour_override = Vector4.{xyz = box.colour_override.xyz, w = box.colour_override_amount}
			, white_override = box.white_override
			);
	}

	// TEXT
	if box.flags & .draw_text
	{
		str : string;
		if box.display_string == ""
		{
			str = display_string_from_box_name(box);
		}
		else
		{
			str = box.display_string;
		}
		
		col := box.text_col;
		col.w *= box.opacity;
		col = highlight_colour(col, effects_adjustment);
		col *= box.multiply_col;
		//height: int = xx floor(range_size(box.rect).y);
		pos := box.rect.min;
		push_text(str, box.font_size, edge_pad=box.text_edge_pad, font_name=box.font, col=col, size_box=box.calc_size, pivot_x=box.text_justify_x, pivot_y=box.text_justify_y, flags=box.quad_flags, trs=make_transform(pos), z_layer = box.z_layer);
	}

	// recurse down
	child := box.first;
	while child
	{
		defer child = child.next;
		render_box_recursive(child);
	}
}

//
// COMMON WIDGETS
//

button :: (name: string) -> Signal
{
	box := make_box(BoxFlags.draw_text | .draw_fill | .clickable | .draw_hot_effects | .draw_active_effects, name);;
	return signal_from_box(box);
}

label :: (name: string) -> *Box
{
	return make_box(BoxFlags.draw_text, name);
}

label :: (format_string: string, args: .. Any) -> *Box
{
	builder: String_Builder;
	print_to_builder(*builder, format_string, ..args);
	s := builder_to_string(*builder, __temporary_allocator);
	return label(s);
}

checkbox :: (checked: bool, lbl: string) -> bool, Signal
{
	outline_size := em(1.0);
	check_size := em(0.5);
	
	set_next_child_layout_axis(.X);
	box := make_box(BoxFlags.clickable | .draw_hot_effects | .draw_active_effects, lbl);
	sig := signal_from_box(box);
	
	checked_res := checked;
	if sig.clicked then checked_res = !checked_res;
	
	push_parent(box);
	//padding(pad_size);
	
	{
		push_pref_width(size_by_children(1));
		auto_column();
		padding(pct_parent(1, 0));
		
		set_next_pref_width(outline_size);
		set_next_pref_height(outline_size);
		outline := make_box(BoxFlags.draw_border, "");
		push_parent(outline);
		
		if checked_res
		{
			padding(pct_parent(1, 0));
		
			set_next_pref_width(pct_parent(1));
			push_pref_height(size_by_children(1));
			auto_row();
			padding(pct_parent(1, 0));
			
			set_next_pref_width(check_size);
			set_next_pref_height(check_size);
			check := make_box(BoxFlags.draw_fill, "");
		}
	}
	
	label("%##check_label", lbl);
	
	return checked_res, sig;
}

ui_sprite :: (name: string, sprite_id: SpriteID, trs:=Transform2.{}) -> *Box
{
	sprite := make_box(BoxFlags.draw_sprite, name);
	sprite.sprite_id = sprite_id;
	
	return sprite;
}

// a centered icon that maintains aspect ratio
icon :: (sprite_id: SpriteID, name: string, size: Size, vertical_pad_pct:= 0.0, horizontal_pad_pct:= 0.0) -> *Box
{
	vertical_pad_size := px(size.value * vertical_pad_pct, 1);
	horizontal_pad_size := px(size.value * horizontal_pad_pct, 1);
	target_height := px(size.value - vertical_pad_size.value*2);
	target_width := px(size.value - horizontal_pad_size.value*2);
	
	set_next_pref_width(size);
	set_next_pref_height(size);
	set_next_child_layout_axis(.Y);
	center_box := make_box(0, ifx name == "" then "" else tprint("%_center_box", name));
	push_parent(center_box);
	padding(pct_parent(1, 0));
	padding(vertical_pad_size); // fixed padding
	
	set_next_pref_width(size);
	set_next_pref_height(size_by_children(1));
	set_next_child_layout_axis(.X);
	//set_next_fill_col(RED);
	row := make_box(0, "");
	//row.flags |= .draw_fill;
	push_parent(row);
	padding(pct_parent(1, 0));
	padding(horizontal_pad_size); // fixed padding
	
	set_next_pref_width(target_width);
	set_next_pref_height(target_height);
	//set_next_fill_col(GRAY);
	image := make_box(BoxFlags.draw_sprite, name);
	//image.flags |= .draw_fill;
	image.sprite_id = sprite_id;
	
	return center_box;
}

slider_float :: (current: float, min: float, max: float, name: string) -> float, Signal
{
	box := make_box(BoxFlags.draw_fill | .draw_hot_effects | .draw_active_effects | .clickable, name);
	sig := signal_from_box(box);
	push_parent(box);
	
	slider_val := current;
	
	slider_mouse_alpha := float_alpha(screen_mouse_to_cardinal().x, box.rect.min.x, box.rect.max.x);
	if sig.dragging
	{
		slider_val = min + (max - min) * slider_mouse_alpha;
	}
	
	bar_alpha := float_alpha(slider_val, min, max);
	
	// todo - secondary color variable
	// or seperate out background col and fill col
	set_next_fill_col(GRAY);
	set_next_pref_width(px(range_size(box.rect).x * bar_alpha, 1));
	fill := make_box(BoxFlags.draw_fill, tprint("%_fill", name));
	
	set_next_flags(.floating);
	label("%: %###%_lbl", name, current, name);
	
	return slider_val, sig;
}

slider_int :: (current: int, min: int, max: int, name: string) -> int, Signal
{
	val, sig := slider_float(xx current, xx min, xx max, name);
	return xx val, sig;
}

int_adjuster :: (current: int, name: string) -> int
{
	set_next_child_layout_axis(.X);
	box := make_box(BoxFlags.draw_fill, name);
	push_parent(box);
	push_text_justify_x(.center);
	current_res := current;
	
	set_next_pref_width(em(1.5, 1));
	left_box := make_box(BoxFlags.draw_hot_effects | .draw_active_effects | .clickable | .draw_text, tprint("%_left", name));
	left_box.display_string = "-";
	left_sig := signal_from_box(left_box);
	if left_sig.clicked then current_res -= 1;
	
	set_next_pref_width(pct_parent(1.0, 0.0));
	lbl_box := label("%_lbl", name);
	lbl_box.display_string = tprint("%: %", display_string_from_box_name(box), current);
	
	set_next_pref_width(em(1.5, 1));
	right_box := make_box(BoxFlags.draw_hot_effects | .draw_active_effects | .clickable | .draw_text, tprint("%_right", name));
	right_box.display_string = "+";
	right_sig := signal_from_box(right_box);
	if right_sig.clicked then current_res += 1;
	
	return current_res;
}

ui_expander :: (expanded: bool, name: string) -> bool, Signal
{
	box := make_box(BoxFlags.draw_fill | .draw_hot_effects | .draw_active_effects | .clickable | .draw_text, name);
	sig := signal_from_box(box);
	expand_res := expanded;
	if sig.clicked then expand_res = !expanded;
	box.display_string = tprint("% %", ifx expand_res then "-" else "+", display_string_from_box_name(box));
	return expand_res, sig;
}

ui_edit_struct :: (ptr_to_struct: *$T)
{
	#assert type_info(T).type == .STRUCT;
	info := type_info(T);
	
	for info.members
	{
		value : *void = ptr_to_struct;
		value += it.offset_in_bytes;
		
		if it.type.type ==
		{
			case .BOOL;
			v_bool : *bool = value;
			
			<<v_bool = checkbox(<<v_bool, it.name);
			
			case .INTEGER;
			v_int : *int = value;
			
			<<v_int = int_adjuster(<<v_int, it.name);
			
			case .FLOAT;
			v_float : *float = value;
			<<v_float = slider_float(<<v_float, 0, 1, it.name);
			
			case .ARRAY;
			array_info : *Type_Info_Array = xx it.type;
			element_info : *Type_Info_Struct = xx array_info.element_type;
			// TODO - continue this
			// recursively do this thang
			
			case .STRUCT;
			// resurse down to the base primitves if it's a struct
			// for struct.members
			// {
			// 	log("%", it.type.type);
			// }
			
			case;
			log("Type % not supported", it.type.type);
		}
	}
}

divider :: ()
{
	label("-----###");
}

spacer :: (size: Size)
{
	parent := top_parent();
	set_next_pref_size_axis(parent.child_layout_axis, size);
	set_next_pref_size_axis(axis_flip(parent.child_layout_axis), px(0, 0));
	make_box(0, "");
}

padding  :: (size: Size) #expand
{
	spacer(size);
	`defer spacer(size);
}

padding_xy :: (size: Size) #expand
{
	original_axis := top_parent().child_layout_axis;
	
	set_next_pref_width(pct_parent(1.0, 0));
	set_next_pref_height(pct_parent(1.0, 0));
	set_next_child_layout_axis(axis_flip(original_axis));
	__box := make_box(0, "");
	_push_parent(__box);
	`defer _pop_parent();
	
	spacer(size);
	`defer spacer(size);
	
	set_next_pref_width(pct_parent(1.0, 0));
	set_next_pref_height(pct_parent(1.0, 0));
	set_next_child_layout_axis(original_axis);
	_box := make_box(0, "");
	_push_parent(_box);
	`defer _pop_parent();
	
	spacer(size);
	`defer spacer(size);
}

ui_center :: () #expand
{
	spacer(pct_parent(1, 0));
	`defer spacer(pct_parent(1, 0));
	
	set_next_pref_height(size_by_children(1.0));
	set_next_pref_width(pct_parent(1, 0));
	set_next_child_layout_axis(.X);
	row := make_box(0, "");
	_push_parent(row);
	`defer _pop_parent();
	
	spacer(pct_parent(1, 0));
	`defer spacer(pct_parent(1, 0));
	
	set_next_pref_height(size_by_children(1.0));
	set_next_pref_width(size_by_children(1.0));
	set_next_child_layout_axis(.Y);
	col := make_box(0, "");
	_push_parent(col);
	`defer _pop_parent();
}

// makes a new row box & pushes it as the parent, pops at end of scope
auto_row :: (width: Size = .{}, height: Size = .{}) -> *Box #expand
{
	if width.kind != .nil then set_next_pref_width(width);
	if height.kind != .nil then set_next_pref_height(height);
	set_next_child_layout_axis(.X);
	row := make_box(0, "");
	_push_parent(row);
	`defer _pop_parent();
	return row;
}

auto_column :: (width: Size = .{}, height: Size = .{}) -> *Box #expand
{
	if width.kind != .nil then set_next_pref_width(width);
	if height.kind != .nil then set_next_pref_height(height);
	set_next_child_layout_axis(.Y);
	col := make_box(0, "");
	_push_parent(col);
	`defer _pop_parent();
	return col;
}

// helpers

push_tooltip :: () #expand
{
	pos := app.mouse_pos - xy(app.window_w * 0.5, app.window_h * 0.5);
	
	set_next_parent(ui.frame.root);
	set_next_pref_width(size_by_children(1));
	set_next_pref_height(size_by_children(1));
	set_next_floating_x(pos.x + 5);
	set_next_floating_y(pos.y - 10);
	if cast(float)pos.x / cast(float)app.window_w >= 0.3 then set_next_rect_pivot_x(.right);
	set_next_child_layout_axis(.Y);
	box := make_box(.floating | .skip_layout, "");
	
	_push_parent(box);
	`defer _pop_parent();
}

set_next_pref_size :: (width_and_height: Size)
{
	set_next_pref_width(width_and_height);
	set_next_pref_height(width_and_height);
}

set_next_pref_size :: (width: Size, height: Size)
{
	set_next_pref_width(width);
	set_next_pref_height(height);
}

set_next_pref_size_axis :: (axis: Axis2, size: Size)
{
	(ifx axis == .X then set_next_pref_width else set_next_pref_height)(size);
}


//
// STACK CODEGEN
//
STACK_MAX :: 128;
#insert -> string
{
	Stack :: struct
	{
		name: string;
		type: string;
		default: string;
	}

	stacks := Stack.[
		.{name="parent",             type="*Box",        default="=null"                            },
		.{name="pref_width",         type="Size"                                               },
		.{name="pref_height",        type="Size"                                               },
		.{name="floating_x",         type="float"                                              },
		.{name="floating_y",         type="float"                                              },
		.{name="fill_col",           type="Vector4"                                            },
		.{name="bg_col", 		          type="Vector4"                                            },
		.{name="border_col",         type="Vector4"                                            },
		.{name="multiply_col",       type="Vector4", default="=WHITE"                          },
		.{name="child_layout_axis",  type="Axis2"                                              },
		.{name="text_justify_x",     type="PivotX"                                             },
		.{name="text_justify_y",     type="PivotY",    default="=.center"                      },
		.{name="text_col",           type="Vector4"                                            },
		.{name="text_edge_pad",      type="float"                                              },
		.{name="font",               type="string"                                             },
		.{name="opacity",            type="float",     default="=1.0"                          },
		.{name="font_size",          type="int"                                                },
		.{name="quad_flags",         type="QuadFlags"									       },
		.{name="rect_pivot_x",       type="PivotX"                                             },
		.{name="rect_pivot_y",       type="PivotY",    default="=.top"                         },
		.{name="flags",       type="BoxFlags",    default="=0"                         },
		.{name="z_layer",      type="float", default="=Z_UI"                                              },
		.{name="disable_signal",      type="bool", default="=false"                                              },
	];
	// :stack

	builder: String_Builder;

	// declarations
	print_to_builder(*builder, "UI_Stacks :: struct\n");
	print_to_builder(*builder, "{\n");
	for stacks
	{
		print_to_builder(*builder, " %: [STACK_MAX] %;\n", it.name, it.type);
		print_to_builder(*builder, " %_count: int;\n", it.name);
		print_to_builder(*builder, " %_auto_pop: bool;\n", it.name);
	}
	print_to_builder(*builder, "}\n\n");

	// push/pop/top/next helpers
	for stacks
	{
		str :: #string DONE
push_%1 :: (in: %2) #expand
{
	_push_%1(in);
	`defer _pop_%1();
}
		
_push_%1 :: (in: %2)
{
	ui.frame.stacks.%1[ui.frame.stacks.%1_count] = in;
	ui.frame.stacks.%1_count += 1;
}

_pop_%1 :: ()
{
	empty: %2;
	ui.frame.stacks.%1[ui.frame.stacks.%1_count - 1] = empty;
	ui.frame.stacks.%1_count -= 1;
}

top_%1 :: () -> %2
{
	empty: %2%3;
	return ifx ui.frame.stacks.%1_count then ui.frame.stacks.%1[ui.frame.stacks.%1_count - 1] else empty;
}

set_next_%1 :: (in: %2)
{
	_push_%1(in);
	ui.frame.stacks.%1_auto_pop = true;
}

		DONE

		print_to_builder(*builder, str, it.name, it.type, it.default);
	}

	// auto pop
	print_to_builder(*builder, "auto_pop_stacks :: ()\n");
	print_to_builder(*builder, "{\n");
	for stacks
	{
		print_to_builder(*builder, " if ui.frame.stacks.%1_auto_pop then _pop_%1(); ui.frame.stacks.%1_auto_pop = false;\n", it.name);
	}
	print_to_builder(*builder, "}\n");

	result := builder_to_string(*builder);
	return result;
}

#scope_file
st: *UI_State;