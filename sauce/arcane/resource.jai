//
// The current definition of a resource is something that gets instantly loaded
// on startup and doesn't change throughout the game.
//

// TODO - it's probably worth putting all the resources into an enum list
// and just referencing that. That way we'll maintain order, and also have it be
// compile-time asserted. Anything that doesn't correctly load will be an error.
// Saves us from having a bunch of strings floating around everywhere.

ResourceID :: u16;
SpriteID :: ResourceID;
ItemID :: ResourceID;

Texture :: ArcResource;
Sprite :: ArcResource;

MAX_ITEM_COUNT :: 64; // assert that the items we load in are not > than this

ItemAmount :: struct
{
	item_name: string;
	amount: int;
}

ArcResource :: struct
{
	Flags :: enum
	{
		// textures are the raw d3d11 resource. Sprites are the slice into that texture.
		// we're keeping these seperate because you'd probs want to be able to have multiple sprites to a texture
		texture 		:: (1<<0);
		sprite 			:: (1<<1);
		wav 						:: (1<<2);
		
		// items can have a crafting recipe, which can be placed in the world as a blueprint structure
		item 					:: (1<<4);
		
		// archetypes are like the single type of entity that defines the broad behaviour
		// eg - goblin, player, campfire, etc.
		// that way we can store static data in here, stuff like function pointers n shit
		entity_archetype :: (1<<5);
		
		// todo
		// hot_reload :: (1<<10);
		//shader 			:: (1<<3);
	}
	
	id: ResourceID;
	flags: Flags;
	name: string;
	display_name: string;
	// path : string; ??
	props: Properties(EntityProps);
	
	// TEXTURE
	texture: *ID3D11Texture2D;
	view: *ID3D11ShaderResourceView;
	width, height: int;
	
	// SPRITE
	rect: Range2;
	offset: Vector2;
	grip_offset: Transform2 = #run make_transform(xy(0, 0), 20);
	frame_count: u8;
	play_rate: float;
	looping: bool = true;
	hand_sockets: []Transform2;
	
	// WAV
 sample_buffer : string;
 channels : int;
 
 // ITEM
 recipe: []ItemAmount;
 weight: int = 1;
 additional_hotbar_slots: int;
 build_func: (*Entity) = setup_world_item;
 on_consume: (*Entity) = nil_func;
 on_toggle: (*Entity) = nil_func;
 sprite_id: ResourceID;
 
	// hot reload
	last_modified: Apollo_Time = APOLLO_TIME_INVALID;
	modify_cooldown_timer: float;
}
nil_resource: *ArcResource;
nil_func :: (en: *Entity) { };

get_display_sprite_id :: (resource: *ArcResource) -> ResourceID
{
	if resource.sprite_id
		then return resource.sprite_id;
		else return resource.id;
}

ResourceState :: struct
{
	resources: [1024]ArcResource;
	resource_id_gen: u16;
}

is_nil :: (res: *ArcResource) -> bool
{
	return res == nil_resource;
}

is_valid :: (res: *ArcResource) -> bool
{
	return res != nil_resource && res.name != "" && res.id != 0;
}

is_texture :: (res: *ArcResource) -> bool
{
	return xx res.flags & .texture;
}

create_resource :: (name: string) -> *ArcResource
{
	assert(is_nil(find_resource(name)), tprint("Resource % already exists", name));
	game_state.resource_id_gen += 1;
	res := *game_state.resources[game_state.resource_id_gen];
	res.id = game_state.resource_id_gen;
	res.name = copy_string(name, permanent_allocator);
	return res;
}

find_resource :: (name: string) -> *ArcResource
{
	for * game_state.resources if it.name == name then return it;
	return nil_resource;
}

get_item :: get_resource;
get_sprite :: get_resource;
get_texture :: get_resource;
get_wav :: get_resource;
get_resource :: (id: ResourceID) -> *ArcResource
{
	return *game_state.resources[id];
}

get_texture :: (name: string) -> *ArcResource
{
	//res_name := tprint("%.png", name);
	res := find_resource(name);
	assert(is_valid(res) && res.flags & .texture, tprint("Resource Texture % not found", name));
	return res;
}

get_sprite :: (name: string) -> *ArcResource
{
	//res_name := tprint("%.png", name);
	res := find_resource(name);
	assert(is_valid(res) && res.flags & .sprite, tprint("Resource Sprite % not found", name));
	return res;
}

get_wav :: (name: string) -> *ArcResource
{
	res_name := tprint("%.wav", name);
	res := find_resource(res_name);
	assert(is_valid(res), tprint("Resource Wav % not found", res_name));
	assert(xx res.flags & .wav, tprint("% resource doesn't have .wav flag", res_name));
	return res;
}

get_item :: (name: string) -> *ArcResource
{
	//res_name := tprint("%.png", name);
	res := find_resource(name);
	assert(is_valid(res), tprint("Resource Item % not found", name));
	assert(xx res.flags & .item, tprint("% resource doesn't have .item flag", name));
	return res;
}

resource_id_from_name :: (name: string) -> ResourceID
{
	//res_name := tprint("%.png", name);
	res := find_resource(name);
	assert(is_valid(res), tprint("Resource % not found", name));
	return res.id;
}

texture_from_sprite :: (sprite: *ArcResource) -> *ArcResource
{
	// for now this is just an assert because all textures are sprites
	// but in future we may want to create a new resource that references another texture
	assert(xx sprite.flags & .texture);
	return sprite;
}

init_resources :: ()
{
	files: []string;
	{
		push_allocator(context.default_allocator); // @alloc leak ?
		files = file_list("res", recursive=true);
	}
	
	for files
	{
		if path_extension(it) ==
		{
			case "png";
			bitmap: Bitmap;
			success := bitmap_load(*bitmap, it);
			assert(success, tprint("Failed to load %", it));
			assert(bitmap.format == .RGBA8, "Probs missing an alpha channel in the texture?");
			
			stripped_name := path_strip_extension(path_filename(it));
			res := create_resource(stripped_name);
			fill_texture(res, xx bitmap.width, xx bitmap.height, bitmap.data.data);
			
			// auto-create sprite from texture bounds
			res.flags |= .sprite;
			res.rect.max = xy(cast(float)res.width, cast(float)res.height);
			
			init_texture(res);
			
			if res.frame_count == 0 then res.frame_count = 1;
			res.rect.max.x /= res.frame_count;
			
			case "wav";
			stripped_name := path_filename(it);
			res := create_resource(stripped_name);
			
			push_allocator(permanent_allocator);
			file_data, success := read_entire_file(it);
			assert(success);
			
			format, samples, success2, extra := get_wav_header(file_data);
			// I am a dictator.
			assert(success2);
			assert(format.wFormatTag == WAVE_FORMAT_PCM);
			assert(format.nSamplesPerSec == SAMPLE_RATE, tprint("Expected sample rate % from %, instead got %", SAMPLE_RATE, res.name, format.nSamplesPerSec));
			assert(format.nChannels == 2);
			assert(format.wBitsPerSample == 16);
			
			// fill in resource
			res.sample_buffer = samples;
			res.channels = format.nChannels;
			res.flags |= .wav;
		}
	}
	
	// ITEMS
	item_files: []string;
	{
		push_allocator(context.default_allocator); // @alloc leak ?
		item_files = file_list("res/tex/items", recursive=true);
	}
	for item_files
	{
		stripped_name := path_strip_extension(path_filename(it));
		item := find_resource(stripped_name);
		item.flags |= .item;
		init_item(item);
	}
	
	extra_init();
}


// TODO
// figure out how to give metadata to each animation frame.
// Ideally we split things up like how doom do it, that way we can have sfx / functions on each frame as wellllllllllllll

// I really just need a big ol' enum for this, with setup happening underneath in a proc

/*

ResourceID :: enum
{
	nil;
	flint_axe;
	wood_defence_wall;
	
	campfire_off;
	campfire_on;
	campfire; @manual // we'll assert that nothing can be auto-loaded into it
	
	sound_effect;
}
// we look through these names, and try to match them to files on disc first, auto-filling shit accordingly
// sound_effect is seen as a wav file, we attach flag and fill, etc.

// for extra setup, we have...
init :: ()
{
	for res : all_res if res.id ==
	{
		case .campfire;
		res.yeet = 15;
		// etc
	}
}

*/

extra_init :: ()
{
	res := create_resource("campfire");
	res.flags |= .item;
	res.recipe = .[ .{"stone", 3}, .{"fibre", 2}, .{"wood", 2} ];
	res.sprite_id = get_sprite("campfire_off").id;
	res.build_func = setup_campfire;
	
	// ehhhh, this probably isn't good practice.
	// what if we want to turn it off a different way, just by doing a state change, etc?
	// I won't overthink this for now. If it works, it works.
	res.on_toggle = (en: *Entity)
	{
		
	};
}

init_item :: (item: *ArcResource)
{
	if path_strip_extension(item.name) ==
	{
		case "flint_axe";
		add_props(*item.props, .axe, .unstackable);
		item.recipe = .[ .{"flint", 1}, .{"wood", 3} ];
		item.weight = 2;
		
		case "flint_sword";
		add_props(*item.props, .sword, .unstackable);
		item.recipe = .[ .{"flint", 3}, .{"wood", 1} ];
		item.weight = 2;
		
		case "tool_belt";
		add_props(*item.props, .equippable, .waist, .unstackable);
		item.recipe = .[ .{"goblin_hide", 3}, .{"fibre", 1} ];	
		item.additional_hotbar_slots = 1;
		
		case "wood_defense_wall";
		item.recipe = .[ .{"wood_log", 1}, .{"fibre", 1}, .{"wood", 1} ];	
		item.weight = 3;
		item.build_func = setup_wall;
		
		case "goblin_meat";
		add_props(*item.props, .consumable);
		item.on_consume = (en: *Entity)
		{
			en.item_count -= 1;
			if en.item_count == 0 then en.marked_for_destroy = true;
			heal_entity(st.player, 1);
			play_sound("eat_0");
		};
	}
}

heal_entity :: (en: *Entity, amount: int)
{
	en.health += amount;
	en.health = min(en.health, en.max_health);
}

init_texture :: (tex: *ArcResource)
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
		case "plains_ground";
		tex.offset = .{0, -65};
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
