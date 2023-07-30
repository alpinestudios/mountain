
// TODO
// figure out how to give metadata to each animation frame.
// Ideally we split things up like how doom do it, that way we can have sfx / functions on each frame as wellllllllllllll

init_item :: (item: *Resource)
{
	if path_strip_extension(item.name) ==
	{
		case "flint_axe";
		add_props(*item.props, .axe);
		item.recipe = .[ .{"flint", 1}, .{"wood", 3} ];
		
		case "flint_sword";
		add_props(*item.props, .sword);
		item.recipe = .[ .{"flint", 3}, .{"wood", 1} ];
		
		case "tool_belt";
		add_props(*item.props, .equippable, .waist);
		item.recipe = .[ .{"goblin_hide", 3}, .{"fibre", 1} ];	
		
		case "wood_defense_wall";
		item.recipe = .[ .{"wood_log", 1}, .{"fibre", 1}, .{"wood", 1} ];	
	}
}

init_texture :: (tex: *Resource)
{
	if path_strip_extension(tex.name) ==
	{
		case "char_idle";
		tex.frame_count = 10;
		tex.play_rate = 8;
		tex.offset = .{0, -8};
		tex.hand_sockets = NewArray(tex.frame_count, Transform2, allocator=permanent_allocator);
		tex.hand_sockets[0] = make_transform(.{-6, 11}, -20);
		tex.hand_sockets[1] = make_transform(.{-6, 10}, -20);
		tex.hand_sockets[2] = make_transform(.{-6, 9}, -20);
		tex.hand_sockets[3] = make_transform(.{-6, 9}, -20);
		tex.hand_sockets[4] = make_transform(.{-6, 9}, -20);
		tex.hand_sockets[5] = make_transform(.{-6, 10}, -20);
		tex.hand_sockets[6] = make_transform(.{-6, 11}, -20);
		tex.hand_sockets[7] = make_transform(.{-6, 11}, -20);
		tex.hand_sockets[8] = make_transform(.{-6, 11}, -20);
		tex.hand_sockets[9] = make_transform(.{-6, 11}, -20);
		
		case "char_walk";
		tex.frame_count = 8;
		tex.play_rate = 10;
		tex.offset = .{0, -8};	
		tex.hand_sockets = NewArray(tex.frame_count, Transform2, allocator=permanent_allocator);
		tex.hand_sockets[0] = make_transform(.{-5, 10}, 10);
		tex.hand_sockets[1] = make_transform(.{6, 11}, -20);
		tex.hand_sockets[2] = make_transform(.{9, 11}, -30);
		tex.hand_sockets[3] = make_transform(.{9, 10}, -30);
		tex.hand_sockets[4] = make_transform(.{5, 9}, -20);
		tex.hand_sockets[5] = make_transform(.{-3, 11}, 10);
		tex.hand_sockets[6] = make_transform(.{-9, 11}, 20);
		tex.hand_sockets[7] = make_transform(.{-8, 10}, 30);
		
		case "char_run";
		tex.frame_count = 8;
		tex.play_rate = 10;
		tex.offset = .{0, -8};	
		tex.hand_sockets = NewArray(tex.frame_count, Transform2, allocator=permanent_allocator);
		tex.hand_sockets[0] = make_transform(.{0, 0}, 0);
		tex.hand_sockets[1] = make_transform(.{0, 0}, 0);
		tex.hand_sockets[2] = make_transform(.{0, 0}, 0);
		tex.hand_sockets[3] = make_transform(.{0, 0}, 0);
		tex.hand_sockets[4] = make_transform(.{0, 0}, 0);
		tex.hand_sockets[5] = make_transform(.{0, 0}, 0);
		tex.hand_sockets[6] = make_transform(.{0, 0}, 0);
		tex.hand_sockets[7] = make_transform(.{0, 0}, 0);
		
		case "char_punch";
		tex.frame_count = 7;
		tex.play_rate = 10;
		tex.offset = .{0, -16};	
		tex.looping = false;
		tex.hand_sockets = NewArray(tex.frame_count, Transform2, allocator=permanent_allocator);
		tex.hand_sockets[0] = make_transform(.{-11, 14}, -60);
		tex.hand_sockets[1] = make_transform(.{-15, 12}, -90);
		tex.hand_sockets[2] = make_transform(.{-14, 13}, -90);
		tex.hand_sockets[3] = make_transform(.{31, 17}, 0);
		tex.hand_sockets[4] = make_transform(.{24, 9}, 20);
		tex.hand_sockets[5] = make_transform(.{19, 10}, 10);
		tex.hand_sockets[6] = make_transform(.{11, 13}, -10);
		
		case "char_hurt";
		tex.frame_count = 4;
		tex.play_rate = 15;
		tex.offset = .{0, -8};
		tex.looping = false;
		
		case "char_death";
		tex.frame_count = 6;
		tex.play_rate = 8;
		tex.offset = .{0, -32};
		tex.looping = false;
		
		case "char_slash1";
		tex.frame_count = 6;
		tex.play_rate = 15;
		tex.offset = .{0, -16};
		tex.looping = false;
		tex.hand_sockets = NewArray(tex.frame_count, Transform2, allocator=permanent_allocator);
		tex.hand_sockets[0] = make_transform(.{-13, 21}, 130);
		tex.hand_sockets[1] = make_transform(.{-4, 30}, 180);
		tex.hand_sockets[2] = make_transform(.{10, 27}, 225);
		tex.hand_sockets[3] = make_transform(.{15, 8}, 20);
		tex.hand_sockets[4] = make_transform(.{11, 4}, 10);
		tex.hand_sockets[5] = make_transform(.{0, 11}, 4);
		
		case "char_stab1";
		tex.frame_count = 5;
		tex.play_rate = 12;
		tex.offset = .{0, -32};	
		tex.looping = false;
		tex.hand_sockets = NewArray(tex.frame_count, Transform2, allocator=permanent_allocator);
		tex.hand_sockets[0] = make_transform(.{-10, 10}, 0);
		tex.hand_sockets[1] = make_transform(.{-11, 9}, 0);
		tex.hand_sockets[2] = make_transform(.{23, 14}, 0);
		tex.hand_sockets[3] = make_transform(.{25, 14}, 0);
		tex.hand_sockets[4] = make_transform(.{11, 12}, 0);
		
		case "char_jump_rise";
		tex.offset = .{0, -32};	
		
		case "char_jump_fall";
		tex.offset = .{0, -32};	
	
		case "char_jump_apex";
		tex.offset = .{0, -32};	
	
		case "char_land";
		tex.frame_count = 4;
		tex.play_rate = 18;
		tex.offset = .{0, -32};
		tex.looping = false;
		
		// gameplay
		case "tree_full";
		tex.offset = .{0, -16};
		case "tree_stump";
		tex.offset = .{0, -16};
		case "tree_long_log";
		tex.offset = .{0, -16};
		case "wood_defense_wall";
		tex.offset = .{12, 0};
		
		// items
		case "flint_sword";
		tex.grip_offset = make_transform(.{-6, 16}, -45);
		case "flint_axe";
		tex.grip_offset = make_transform(.{-2, 11}, -45);
		
		// particles
		case "p_parry";
		tex.frame_count = 5;
		tex.play_rate = 10;
		case "p_upwards";
		tex.frame_count = 2;
		tex.play_rate = 8;
		case "p_ground";
		tex.frame_count = 4;
		tex.play_rate = 10;
		case "p_diagonal";
		tex.frame_count = 4;
		tex.play_rate = 10;
		case "p_poof";
		tex.frame_count = 3;
		tex.play_rate = 10;
		
		// GOBBY
		case "gob_idle";
		tex.frame_count = 4;
		tex.play_rate = 8;
		tex.offset = .{0, -50};
		case "gob_run";
		tex.frame_count = 8;
		tex.play_rate = 12;
		tex.offset = .{0, -50};
		case "gob_attack";
		tex.frame_count = 8;
		tex.play_rate = 8;
		tex.offset = .{0, -50};
		case "gob_hurt";
		tex.frame_count = 3;
		tex.play_rate = 12;
		tex.offset = .{0, -50};
		case "gob_death";
		tex.frame_count = 4;
		tex.play_rate = 12;
		tex.offset = .{0, -50};
		
		// temp
		case "forest_ground";
		tex.offset = .{0, -66};
		case "bg_forest1";
		tex.offset = .{0, -67};
		case "bg_forest2";
		tex.offset = .{0, -67};
		case "bg_forest3";
		tex.offset = .{0, -67};
		case "bg_mountains";
		tex.offset = .{0, -67};
		case "sky";
		tex.offset = .{0, -67};
	}
}


// old config
// https://github.com/bigrando420/jaitime/blob/e372343131d09785777ce5122c6430557da6a076/arcane/config.jai
