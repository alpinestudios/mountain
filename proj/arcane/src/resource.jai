//
// The current definition of a resource is something that gets instantly loaded
// on startup and doesn't change throughout the game.
//
// TODO
// [ ] hot reloading of this entire system. Requires an @alloc cleanup
// [ ] :res_rework

ArcResource :: struct
{
	Flags :: enum
	{
		// textures are the raw d3d11 resource. Sprites are the slice into that texture.
		// we're keeping these seperate because you'd probs want to be able to have multiple sprites to a texture
		texture 		:: (1<<0);
		sprite 			:: (1<<1);
		wav 						:: (1<<2);
		comp_sound 				:: (1<<3);
		
		// Items are a core construct in the game, they can be moved between inventories and around in the world
		// Some are directly placable structures.
		item 					:: (1<<4);
		
		// Generic :animation construct for playing through keyframes
		// My hope here was to separate out the animation data from the sprites
		// since I'd ideally like to have one animation playing and be able to use that
		// for multiple visual elements. (the sword / body split on the player for eg)
		// 	- randy, 29th of September 2023
		animation :: (1<<5);
		
		// archetypes are like the single type of entity that defines the broad behaviour
		// eg - goblin, player, campfire, etc.
		// that way we can store static data in here, stuff like function pointers n shit
		archetype :: (1<<6);
		
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
	// these are about to be yeeted
	grip_offset: Transform2 = #run make_transform(xy(0, 0), 20);
	hand_sockets: []Transform2;
	//
	
	// WAV
 sample_buffer : string;
 channels : int;
 
 // COMP_SOUND
 play_type: enum {random; alternate;};
 waves: []ResourceID;
 alternate_index: int;
 
 // :animation
 frame_count: int;
 frame_duration_ms: []float;
 anim_looping: bool = true;
 
 
 // ITEM
 recipe: []ItemAmount;
 max_stack_size := DEFAULT_STACK_SIZE;
 additional_hotbar_slots: int;
 setup_func: (*Entity);
 placement_kind: enum { free; back_wall; side_wall; };
 on_consume: (*Entity) = nil_func;
 on_toggle: (*Entity) = nil_func;
 resource_sprite_id: ResourceID;
 fuel_amount: float = DEFAULT_FUEL_TIME;
 cook_time: float = DEFAULT_COOK_TIME;
 cooks_into: ItemID;
 description: string;
 unlock_prerequisites: []ItemID; // TODO
 
 // ARCHETYPE
 // honestly, I don't really know where to draw the line with archetype.
 // It feels much more flexible to just set the props and call it a day.
 
 // not too sure where the hitsound should lie. Having it in here feels to cumbersome, we'd need to make a new archetype for each thing we want to assign a hitsound to.
 // For now I'm just gonna keep it in the entity state.
 // Maybe creating a new MATERIAL flag would be better for something like this? idk broski
 // hit_sound: SoundID = .punch;
 
	// hot reload
	last_modified: Apollo_Time = APOLLO_TIME_INVALID;
	modify_cooldown_timer: float;
}
nil_resource: *ArcResource;
nil_func :: (en: *Entity) { };

// :res_rework - I rly gotta split these up so we get compile-time errors when using improper handles
SpriteID :: ResourceID;
ItemID :: ResourceID;
SoundID :: ResourceID;
AnimationID :: ResourceID;

Texture :: ArcResource;
Sprite :: ArcResource;
EntityArchetype :: ArcResource;

ItemAmount :: struct
{
	id: ItemID;
	amount: int;
}

get_display_name :: (res: *ArcResource) -> string
{
	return ifx res.display_name == "" then tprint("%", res.id) else res.display_name;
}

get_display_sprite_id :: (resource: *ArcResource) -> ResourceID
{
	if resource.resource_sprite_id
		then return resource.resource_sprite_id;
		else return resource.id;
}

is_nil :: (res: *ArcResource) -> bool
{
	return res == nil_resource;
}

is_valid :: (res: *ArcResource) -> bool
{
	return res != nil_resource && res.id != 0;
}

is_texture :: (res: *ArcResource) -> bool
{
	return xx res.flags & .texture;
}

get_resource :: (id: ResourceID) -> *ArcResource
{
	return *app.resources[id];
}

get_item :: (id: ResourceID) -> *ArcResource
{
	res := get_resource(id);
	assert(is_valid(res), "Invalid resource id %", id);
	assert(xx res.flags & .item, tprint("% resource doesn't have .item flag", res.name));
	return res;
}

get_sprite :: (id: ResourceID) -> *ArcResource
{
	res := get_resource(id);
	assert(xx res.flags & .sprite, tprint("% resource doesn't have .sprite flag", res.name));
	return res;
}

get_wav :: (id: ResourceID) -> *ArcResource
{
	res := get_resource(id);
	assert(is_valid(res), "Invalid resource id %", id);
	assert(xx res.flags & .wav, tprint("% resource doesn't have .wav flag", res.name));
	return res;
}

get_texture :: (id: ResourceID) -> *ArcResource
{
	// our nil_texture has the checkerboard pattern, so it's technically valid
	res := get_resource(id);
	assert(xx res.flags & .texture, tprint("% resource doesn't have .texture flag", res.name));
	return res;
}

//
// Try use the compile-time known ResourceID enum for better errors
//
get_resource_from_name :: (name: string) -> *ArcResource
{
	return *app.resources[resource_id_from_name(name)];
}

get_texture_from_name :: (name: string) -> *ArcResource
{
	res := get_resource_from_name(name);
	assert(is_valid(res), tprint("Resource tex % not found", name));
	assert(xx res.flags & .texture, tprint("% resource doesn't have .texture flag", name));
	return res;
}

get_sprite_from_name :: (name: string) -> *ArcResource
{
	res := get_resource_from_name(name);
	assert(is_valid(res), tprint("Resource sprite % not found", name));
	assert(xx res.flags & .sprite, tprint("% resource doesn't have .sprite flag", name));
	return res;
}

get_wav_from_name :: (name: string) -> *ArcResource
{
	res := get_resource_from_name(name);
	assert(is_valid(res), tprint("Resource Wav % not found", name));
	assert(xx res.flags & .wav, tprint("% resource doesn't have .wav flag", name));
	return res;
}

get_item_from_name :: (name: string) -> *ArcResource
{
	res := get_resource_from_name(name);
	assert(is_valid(res), tprint("Resource Item % not found", name));
	assert(xx res.flags & .item, tprint("% resource doesn't have .item flag", name));
	return res;
}

random_sprite_from_folder :: (path: string) -> *Sprite
{
	push_allocator(temp);
	files: []string;
	files = file_list(path, recursive=true);
	
	sprites: [..]*Sprite;
	
	for files
	{
		name := path_strip_extension(path_filename(it));
		res := get_resource(resource_id_from_name(name));
		if is_valid(res) && res.flags & .sprite
		{
			array_add(*sprites, res);
		}
	}
	
	if sprites.count > 0
	{
		return sprites[random_int_range(0, sprites.count-1)];
	}
	else
	{
		return nil_resource;
	}
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
	for * app.resources
	{
		it.id = xx it_index;
		it.name = sprint("%", it.id); // @alloc leak
		fill_resource_metadata(it);
	}
	
	files: []string;
	{
		push_allocator(context.default_allocator); // @alloc leak ?
		files = file_list("res", recursive=true);
	}
	
	// attempt to auto-fill in some resources
	for files
	{
		stripped_name := path_strip_extension(path_filename(it));
		res := get_resource(resource_id_from_name(stripped_name));
		if is_valid(res)
		{
			if path_extension(it) ==
			{
				case "png";
				bitmap: Bitmap;
				success := bitmap_load(*bitmap, it);
				assert(success, tprint("Failed to load %", it));
				assert(bitmap.format == .RGBA8, "Probs missing an alpha channel in the texture?");
				
				// _blender anim handling
				if contains(it, "_blender")
				{
					frame_count := cast(u8) (bitmap.width / bitmap.height);
					setup_animation(res, frame_count, 1.0/30.0*1000);
					res.offset.y = -12;
				}
				
				fill_texture(res, xx bitmap.width, xx bitmap.height, bitmap.data.data);
			
				// auto-create sprite from texture bounds
				res.flags |= .sprite;
				res.rect.max = xy(cast(float)res.width, cast(float)res.height);
				if res.frame_count == 0 then res.frame_count = 1;
				res.rect.max.x /= res.frame_count;
				
				case "wav";
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
	}
	
	push_allocator(temp);
	
	// anim metadata
	for file_list("res/tex/_blender")
	{
		if path_extension(it) == "txt" then parse_animation_metadata(it);
	}
	
	// auto-apply .item
	for file_list("res/tex/items", recursive=true)
	{
		stripped_name := path_strip_extension(path_filename(it));
		item := get_resource_from_name(stripped_name);
		item.flags |= .item;
	}
	
	for app.resources
	{
		assert(it.flags != 0, "Resource % is unused", it.name);
		if has_prop(it.props, .placeable) then assert(it.setup_func != null, "Marked as placeable yet no setup function");
	}
}

// a lot of this is copy-pasted from \jai\modules\Text_File_Handler\examples\example.jai
parse_animation_metadata :: (path: string)
{
	// Report errors and warnings. It's convenient to do this by calling these procedures,
	// since 'handler' tracks the filename and line number for you; you don't have to pass those
	// around to your various parsing routines.
	error :: (handler: Text_File_Handler, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) {
  new_format := tprint("Line % of '%'! %", handler.line_number, handler.full_path, format);
  log(new_format, .. args, flags=Log_Flags.ERROR|.CONTENT|flags, loc=loc);
	} @PrintLike
	warn :: (handler: Text_File_Handler, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) {
  new_format := tprint("Line % of '%': %", handler.line_number, handler.full_path, format);
  log(new_format, .. args, flags=Log_Flags.WARNING|.CONTENT|flags, loc=loc);
	} @PrintLike
	
	name := path_strip_extension(path_filename(path));
	res := get_resource_from_name(tprint("%_base", name));
	assert(is_valid(res), "couldn't match % with a resource", name);
	
	res.hand_sockets = NewArray(res.frame_count, Transform2, allocator=permanent_allocator);
	
	handler: Text_File_Handler;
	start_file(*handler, name, path);
	assert(!handler.failed, "failed to handle %", path);
	
	frame : int;
	frame_count : int;
	while true
	{
		line, found := consume_next_line(*handler);
  if !found break;
  
  key_name, rhs := break_by_spaces(line); // break_by_spaces gives us two strings, the one before whitespace, and the one after.
	 if !rhs {
   error(handler, "Expected a space after the key specifier.\n");
   continue;
	 }
	 
	 // read in the frame_count
	 if frame_count == 0
	 {
	 	if key_name != "frame_count" then continue;
	 	frame_count = string_to_int(rhs);
	 	assert(frame_count == res.frame_count, "mismatched frame count??");
	 	continue;
	 }
	 
 	if key_name == "frame"
 	{
 		frame = string_to_int(rhs);
 		continue;
 	}
 	
 	// :hand_pos
 	// this positioning is broken, I'm just gonna make it hover out in front of the player
 	// for now lol. MAGIC.
 	if key_name == "hand_x"
 	{
 		x := string_to_float(rhs);
 		res.hand_sockets[frame].translate.x = x;
 		continue;
 	}
 	
 	if key_name == "hand_y"
 	{
 		y := string_to_float(rhs);
 		res.hand_sockets[frame].translate.y = y;
 		continue;
 	}
	}
}

// resource_id_from_name
#insert -> string
{
	builder: String_Builder;
	print_to_builder(*builder, "resource_id_from_name :: (name: string) -> ResourceID\n");
	print_to_builder(*builder, "{\n");
	print_to_builder(*builder, "	if name ==\n");
	print_to_builder(*builder, "	{\n");
	
	enum_info : Type_Info_Enum = type_info(ResourceID);
	for enum_info.names
	{
		value := enum_info.values[it_index];
		print_to_builder(*builder, "	case \"%\"; return %;\n", it, value);
	}
	
	print_to_builder(*builder, "	case; return 0;\n");
	print_to_builder(*builder, "	}\n");
	print_to_builder(*builder, "}\n\n");
	return builder_to_string(*builder);
}

ResourceID :: enum
{
	nil;
	blank_tex;
	
	ron_idle_base;
	ron_idle_sword;
	ron_walk_base;
	ron_walk_sword;
	ron_sprint_base;
	ron_sprint_sword;
	
	ron_idle_pretty; // authored
	
	char_idle;
	char_walk;
	char_run;
	char_slash1;
	char_stab1;
	char_punch;
	char_jump_rise;
	char_jump_fall;
	char_jump_apex;
	char_hurt;
	char_land;
	char_death;
	
	gob_idle;
	gob_run;
	gob_attack;
	gob_hurt;
	gob_death;
	
	tree_full;
	tree_stump;
	tree_long_log;
	
	// particles
	p_parry;
	p_upwards;
	p_diagonal;
	p_ground;
	p_poof;
	
	// ui
	red_vignette;
	middle_mouse_flip_icon;
	right_click_icon;
	
	// luts
	early_night_lut;
	mid_night_lut;
	dawn_lut;
	day_lut;
	dusk_lut;
	evening_lut;
	late_night_lut;
	morning_lut;
	neutral_lut;
	fire_lut;
	
	// scenic stuff
	forest_ground;
	plains_ground;
	bg_forest1;
	bg_forest2;
	bg_forest3;
	mountain_00;
	mountain_01;
	sky;
	sun;
	moon;
	
	front_birch_00;
	front_birch_01;
	front_pine_00;
	front_pine_01;
	front_pine_02;
	forest_hills_00;
	forest_hills_01;
	
	middle_birch_00;
	middle_birch_01;
	middle_birch_02;
	middle_pine_00;
	middle_pine_01;
	middle_pine_02;
	
	// back_birch_00;
	// back_birch_01;
	// back_birch_02;
	// back_birch_03;
	// back_birch_04;
	back_pine_00;
	back_pine_01;
	back_pine_02;
	
	// world
	overgrown_roots_0;
	overgrown_roots_1;
	overgrown_roots_2;
	tall_grass_0;
	tall_grass_1;
	tall_grass_stub;
	
	// items
	book;
	fibre;
	flint;
	flint_axe;
	flint_sword;
	goblin_hide;
	raw_goblin_meat;
	cooked_goblin_meat;
	stone;
	tool_belt;
	wood;
	wood_log;
	torch;
	acorn;
	
	wood_wall;
	wood_defense_wall;
	// workbench;
	
	campfire_off;
	campfire_on;
	campfire_on_blue;
	
	// :animation
	// :res_rework
	anim_slash1;
	anim_slash2;
	anim_slash3;
	
	// :archeytypes
	player;
	oak_sapling; // :res_rework ARGHHHH these need to be seperate and just fking typechecked!
	tall_grass;
	gobby;
	campfire;
	corefire;
	back_wall;
	side_wall;
	
	// :sfx
	pop;
	build_finish;
	riser;
	gobby_signal;
	gobby_attack;
	wave_over;
	wave_start;
	tree_impact;
	endgame;
	pickup;
	build_0;
	build_1;
	click_0;
	click_1;
	eat_0;
	fire_extinguish;
	fire_ignite;
	harvest;
	impact_thing;
	light_whoosh_01;
	light_whoosh_02;
	sword_swing_01;
	sword_swing_02;
	page_flip;
	punch;
	wood_hit; // composite sound
	wood_hit_01;
	wood_hit_02;
	wood_break;
	air_swing;
	block;
}

// NOTE :res_rework - these should really be split into different enums for compile time safety...
// right now if we fuck up it's a runtime error, which will eventually lead to an error on a user machine
// ME NO WANT THAT.
// RUNTIME IS FUNTIME

setup_animation :: (res: *ArcResource, frame_count: int, frame_duration_ms: float)
{
	res.flags |= .animation;
	res.frame_count = frame_count;
	res.frame_duration_ms = NewArray(frame_count, float);
	for * res.frame_duration_ms
	{
		<<it = frame_duration_ms;
	}
}

fill_resource_metadata :: inline (res: *ArcResource)
{
	if res.id ==
	{
		
		// ideally this would be autogen'd by aseprite metadata
		case .anim_slash1;
		setup_animation(res, 8, 60);
		res.anim_looping = false;
		case .anim_slash2;
		setup_animation(res, 8, 60);
		res.anim_looping = false;
		case .anim_slash3;
		setup_animation(res, 8, 60);
		res.anim_looping = false;
		
		// :res_rework
		// This is the problem with the current system...
		// (could easily be avoided by separating into clear groups)
		//
		// Then againnnnn, it's sometimes not obvious what belongs where,
		// what if it's both a sprite and an animation, uno?
		// idk broski.
		case .player;
		res.flags |= .archetype;
		case .oak_sapling;
		res.flags |= .archetype;
		case .tall_grass;
		res.flags |= .archetype;
		case .gobby;
		res.flags |= .archetype;
		case .corefire;
		res.flags |= .archetype;
		case .back_wall;
		res.flags |= .archetype;
		case .side_wall;
		res.flags |= .archetype;
		
		case .acorn;
		add_props(*res.props, .placeable);
		res.setup_func = setup_sapling;
		
		case .wood_hit;
		res.flags |= .comp_sound;
		res.waves = .[.wood_hit_01, .wood_hit_02];
		res.play_type = .alternate;
		
		/*
		case .workbench;
		add_props(*res.props, .placeable);
		res.display_name = "Workbench";
		res.recipe = .[ .{.fibre, 2}, .{.wood, 2} ];
		res.setup_func = setup_workbench;
		*/
		
		case .campfire;
		add_props(*res.props, .reduce_render_scale, .placeable);
		res.display_name = "Campfire";
		res.flags |= .item;
		res.recipe = .[ .{.fibre, 4}, .{.stone, 8} ];
		res.resource_sprite_id = .campfire_off;
		res.setup_func = setup_campfire;
		
		case .campfire_on;
		setup_animation(res, 22, 60);
		// res.play_rate = 15.0;
		
		case .campfire_on_blue;
		setup_animation(res, 22, 60);
		
		// case .torch;
		// add_props(*res.props, .unstackable);
		// res.recipe = .[ .{.fibre, 2}, .{.wood, 2} ];
		
		case .wood;
		add_props(*res.props, .fuel);
		
		case .fibre;
		add_props(*res.props, .fuel);
		
		case .flint;
		// add_props(*res.props, .deconstruct_tool);
		
		case .flint_axe;
		res.display_name = "Flint Axe";
		add_props(*res.props, .axe, .deconstruct_tool);
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 1}, .{.wood, 3} ];
		res.grip_offset = make_transform(.{-2, 11}, -45);
		
		case .flint_sword;
		res.display_name = "Flint Sword";
		add_props(*res.props, .sword, .blockable, .disable_interaction_when_held);
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 3}, .{.wood, 1}, .{.fibre, 1} ];
		res.grip_offset = make_transform(.{-6, 16}, -45);
		
		case .tool_belt;
		add_props(*res.props, .equippable, .waist);
		res.max_stack_size = 1;
		// res.recipe = .[ .{.goblin_hide, 3}, .{.fibre, 1} ];	
		res.additional_hotbar_slots = 1;
		
		case .wood_wall;
		add_props(*res.props, .placeable, .reduce_render_scale);
		res.placement_kind = .back_wall;
		res.display_name = "Wooden Wall";
		res.recipe = .[ .{.wood, 10} ];
		res.setup_func = setup_wall;
		
		case .wood_defense_wall;
		// these could technically be in the archetype? ehhhhh
		add_props(*res.props, .placeable, .flippable, .reduce_render_scale);
		res.placement_kind = .side_wall;
		//
		res.display_name = "Wooden Side Wall";
		res.recipe = .[ .{.fibre, 3}, .{.wood, 10} ];	
		res.unlock_prerequisites = .[.wood_wall];
		res.setup_func = setup_side_wall;
		res.offset = .{5, 0};
		
		case .raw_goblin_meat;
		add_props(*res.props, .cookable);
		res.cooks_into = .cooked_goblin_meat;
		res.description = "It's unedible raw";
		
		case .cooked_goblin_meat;
		add_props(*res.props, .consumable);
		
		// should probs refactor this...
		heal_entity :: (en: *Entity, amount: int)
		{
			en.health += amount;
			en.health = min(en.health, en.max_health);
		}
		
		res.on_consume = (en: *Entity)
		{
			en.item_count -= 1;
			if en.item_count == 0 then en.marked_for_destroy = true;
			heal_entity(get_player(), 1);
			play_sound(.eat_0);
		};
		
		//
		// TEXTURES n SPRITES n SHIT
		//
		case .ron_idle_pretty;
		setup_animation(res, 4, 300);
		res.offset = .{0, -4};
		
		case .char_idle;
		setup_animation(res, 10, 125);
		res.offset = .{0, -8};
		res.hand_sockets = NewArray(res.frame_count, Transform2, allocator=permanent_allocator);
		res.hand_sockets[0] = make_transform(.{-6, 11}, -20);
		res.hand_sockets[1] = make_transform(.{-6, 10}, -20);
		res.hand_sockets[2] = make_transform(.{-6, 9}, -20);
		res.hand_sockets[3] = make_transform(.{-6, 9}, -20);
		res.hand_sockets[4] = make_transform(.{-6, 9}, -20);
		res.hand_sockets[5] = make_transform(.{-6, 10}, -20);
		res.hand_sockets[6] = make_transform(.{-6, 11}, -20);
		res.hand_sockets[7] = make_transform(.{-6, 11}, -20);
		res.hand_sockets[8] = make_transform(.{-6, 11}, -20);
		res.hand_sockets[9] = make_transform(.{-6, 11}, -20);
		
		case .char_walk;
		setup_animation(res, 8, 10);
		res.offset = .{0, -8};	
		res.hand_sockets = NewArray(res.frame_count, Transform2, allocator=permanent_allocator);
		res.hand_sockets[0] = make_transform(.{-5, 10}, 10);
		res.hand_sockets[1] = make_transform(.{6, 11}, -20);
		res.hand_sockets[2] = make_transform(.{9, 11}, -30);
		res.hand_sockets[3] = make_transform(.{9, 10}, -30);
		res.hand_sockets[4] = make_transform(.{5, 9}, -20);
		res.hand_sockets[5] = make_transform(.{-3, 11}, 10);
		res.hand_sockets[6] = make_transform(.{-9, 11}, 20);
		res.hand_sockets[7] = make_transform(.{-8, 10}, 30);
		
		case .char_run;
		setup_animation(res, 8, 10);
		res.offset = .{0, -8};	
		res.hand_sockets = NewArray(res.frame_count, Transform2, allocator=permanent_allocator);
		res.hand_sockets[0] = make_transform(.{0, 0}, 0);
		res.hand_sockets[1] = make_transform(.{0, 0}, 0);
		res.hand_sockets[2] = make_transform(.{0, 0}, 0);
		res.hand_sockets[3] = make_transform(.{0, 0}, 0);
		res.hand_sockets[4] = make_transform(.{0, 0}, 0);
		res.hand_sockets[5] = make_transform(.{0, 0}, 0);
		res.hand_sockets[6] = make_transform(.{0, 0}, 0);
		res.hand_sockets[7] = make_transform(.{0, 0}, 0);
		
		case .char_punch;
		setup_animation(res, 7, 10);
		res.offset = .{0, -16};	
		res.anim_looping = false;
		res.hand_sockets = NewArray(res.frame_count, Transform2, allocator=permanent_allocator);
		res.hand_sockets[0] = make_transform(.{-11, 14}, -60);
		res.hand_sockets[1] = make_transform(.{-15, 12}, -90);
		res.hand_sockets[2] = make_transform(.{-14, 13}, -90);
		res.hand_sockets[3] = make_transform(.{31, 17}, 0);
		res.hand_sockets[4] = make_transform(.{24, 9}, 20);
		res.hand_sockets[5] = make_transform(.{19, 10}, 10);
		res.hand_sockets[6] = make_transform(.{11, 13}, -10);
		
		case .char_hurt;
		setup_animation(res, 4, 1.0/15.0*1000);
		res.offset = .{0, -8};
		res.anim_looping = false;
		
		case .char_death;
		setup_animation(res, 6, 1.0/8.0*1000);
		res.offset = .{0, -32};
		res.anim_looping = false;
		
		// case .char_slash1;
		// setup_animation(res, 6, 1.0/15.0*1000);
		// res.offset = .{0, -16};
		// res.anim_looping = false;
		// res.hand_sockets = NewArray(res.frame_count, Transform2, allocator=permanent_allocator);
		// res.hand_sockets[0] = make_transform(.{-13, 21}, 130);
		// res.hand_sockets[1] = make_transform(.{-4, 30}, 180);
		// res.hand_sockets[2] = make_transform(.{10, 27}, 225);
		// res.hand_sockets[3] = make_transform(.{15, 8}, 20);
		// res.hand_sockets[4] = make_transform(.{11, 4}, 10);
		// res.hand_sockets[5] = make_transform(.{0, 11}, 4);
		
		// case .char_stab1;
		// setup_animation(res, 5, 1.0/12.0*1000);
		// res.offset = .{0, -32};	
		// res.anim_looping = false;
		// res.hand_sockets = NewArray(res.frame_count, Transform2, allocator=permanent_allocator);
		// res.hand_sockets[0] = make_transform(.{-10, 10}, 0);
		// res.hand_sockets[1] = make_transform(.{-11, 9}, 0);
		// res.hand_sockets[2] = make_transform(.{23, 14}, 0);
		// res.hand_sockets[3] = make_transform(.{25, 14}, 0);
		// res.hand_sockets[4] = make_transform(.{11, 12}, 0);
		
		case .char_jump_rise;
		res.offset = .{0, -32};	
		
		case .char_jump_fall;
		res.offset = .{0, -32};	
	
		case .char_jump_apex;
		res.offset = .{0, -32};	
	
		case .char_land;
		setup_animation(res, 4, 1.0/18.0*1000);
		res.offset = .{0, -32};
		res.anim_looping = false;
		
		// gameplay
		case .tree_full;
		res.offset = .{0, -16};
		case .tree_stump;
		res.offset = .{0, -16};
		case .tree_long_log;
		res.offset = .{0, -16};
		
		
		// particles
		case .p_parry;
		setup_animation(res, 5, 1.0/10.0*1000);
		case .p_upwards;
		setup_animation(res, 2, 1.0/8.0*1000);
		case .p_ground;
		setup_animation(res, 4, 1.0/10.0*1000);
		case .p_diagonal;
		setup_animation(res, 4, 1.0/10.0*1000);
		case .p_poof;
		setup_animation(res, 3, 1.0/10.0*1000);
		
		// GOBBY
		case .gob_idle;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .gob_run;
		setup_animation(res, 8, 1.0/12.0*1000);
		res.offset = .{0, -50};
		case .gob_attack;
		setup_animation(res, 8, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .gob_hurt;
		setup_animation(res, 3, 1.0/12.0*1000);
		res.offset = .{0, -50};
		case .gob_death;
		setup_animation(res, 4, 1.0/12.0*1000);
		res.offset = .{0, -50};
		
		// temp
		case .forest_ground;
		res.offset = .{0, -66};
		case .plains_ground;
		res.offset = .{0, -65};
		case .bg_forest1;
		res.offset = .{0, -67};
		case .bg_forest2;
		res.offset = .{0, -67};
		case .bg_forest3;
		res.offset = .{0, -67};
		case .sky;
		res.offset = .{0, -67};
	}
}


// old config
// https://github.com/bigrando420/jaitime/blob/e372343131d09785777ce5122c6430557da6a076/arcane/config.jai

#import "Text_File_Handler";