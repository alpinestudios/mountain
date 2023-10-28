//
// The current definition of a resource is something that gets instantly loaded
// on startup and doesn't change throughout the game.
//
// TODO
// [ ] hot reloading of this entire system. Requires an @alloc cleanup

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
		//
		// Turns out this was just far too complicated. Why didn't I just use the base body as the animation?
		// Silly goose.
		// - randy, 21th of October 2023
		//
		// animation :: (1<<5);
		
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
	texture_id: ResourceID;
	rect: Range2;
	offset: Vector2;
	render_offset: Transform2 =#run make_transform(xy(0, 0), 0);//Custom Render Size : Rob
	// these are about to be yeeted
	grip_offset: Transform2 = #run make_transform(xy(0, 0), 20);
	hand_sockets: []Transform2;
	// animation
	frame_count: int;
 frame_duration_ms: []float;
 anim_looping: bool = true;
	
	// WAV
 sample_buffer : string;
 channels : int;
 
 // COMP_SOUND
 play_type: enum {random; alternate;};
 waves: []ResourceID;
 alternate_index: int;
 
 // ITEM
 recipe: []ItemAmount;
 scaffolding_id: ResourceID;
 max_stack_size := DEFAULT_STACK_SIZE;
 additional_hotbar_slots: int;
 additional_dashes: int;
 setup_func: (*Entity);
 on_consume: (*Entity) = nil_func;
 on_toggle: (*Entity) = nil_func;
 display_sprite_id: ResourceID;
 fuel_amount: float = DEFAULT_FUEL_TIME;
 cook_time: float = DEFAULT_COOK_TIME;
 cooks_into: ItemID;
 description: string;
 structure_tile_width: int = 1;
 tile_blocking_layer: enum { playspace; back_wall; };
 consume_verb: string = "Eat";
 
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
	if res.display_name == ""
	{
		return snake_to_pretty_string(tprint("%", res.id));
	}
	else
	{
		return res.display_name;
	}
}

get_display_sprite_id :: (resource: *ArcResource) -> ResourceID
{
	if resource.display_sprite_id
		then return resource.display_sprite_id;
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
	assert(xx sprite.flags & .texture, "No texture found from this sprite? Perhaps grab the display_sprite instead?");
	return sprite;
}

init_resources :: ()
{
	for * app.resources
	{
		it.id = xx it_index;
		it.name = sprint("%", it.id); // @alloc leak
		fill_resource_metadata_pre(it);
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
				res.flags |= .wav;
				
				// gonna be replaced by fmod
				/*
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
				*/
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
		// assert(it.flags != 0, "Resource % has no flags, it's unused. Couldn't auto-match with a texture or just not setup properly manually.", it.name);
		if has_prop(it.props, .placeable) || has_prop(it.props, .blueprint)
		{
			assert(it.setup_func != null, "Marked as placeable yet no setup function");
			
			entity : Entity;
			it.setup_func(*entity);
			assert(has_prop(entity.props, .structure), "Entity setup function for % doesn't add a .structure flag during setup, did you forget to add it?", it.id);
		}
	}
	
	for * app.resources
	{
		fill_resource_metadata_post(it);
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

// randy:
// We're gonna needa start caring about not breaking saves.
// Append each new resource to the end of the list at the ':'res jump point below
// We need to slowly start doing this for existing enums as well.
//
ResourceID :: enum #specified
// randy: alright, time to stop breaking this, fr fr
{
	nil :: 0;
	blank_tex :: 1;
	axe_swing_item :: 2;
	player_axe_swing_trail :: 3;
	pickaxe_swing_item :: 4;
	pickaxe_swing_trail :: 5;
	ron_idle_base :: 6;
	ron_idle_sword :: 7;
	ron_walk_base :: 8;
	ron_walk_sword :: 9;
	ron_sprint_base :: 10;
	ron_sprint_sword :: 11;
	ron_idle_pretty :: 12;
	char_idle :: 13;
	char_walk :: 14;
	char_run :: 15;
	char_slash1 :: 16;
	char_stab1 :: 17;
	char_punch :: 18;
	char_jump_rise :: 19;
	char_jump_fall :: 20;
	char_jump_apex :: 21;
	char_roll :: 22;
	char_hurt :: 23;
	char_land :: 24;
	char_death :: 25;
	gob_idle :: 26;
	gob_run :: 27;
	gob_attack :: 28;
	gob_hurt :: 29;
	gob_death :: 30;
	gob_heavy_idle :: 31;
	gob_heavy_run :: 32;
	gob_heavy_attack :: 33;
	gob_heavy_hurt :: 34;
	gob_heavy_death :: 35;
	ogre_idle :: 36;
	ogre_walk :: 37;
	ogre_attack :: 38;
	mage_idle :: 39;
	tree_full :: 40;
	tree_stump :: 41;
	tree_long_log :: 42;
	rock_deposit :: 43;
	iron_deposit :: 44;
	p_parry :: 45;
	p_upwards :: 46;
	p_diagonal :: 47;
	p_ground :: 48;
	p_poof :: 49;
	red_vignette :: 50;
	middle_mouse_flip_icon :: 51;
	right_click_icon :: 52;
	left_click_icon :: 53;
	early_night_lut :: 54;
	mid_night_lut :: 55;
	dawn_lut :: 56;
	day_lut :: 57;
	dusk_lut :: 58;
	evening_lut :: 59;
	late_night_lut :: 60;
	morning_lut :: 61;
	neutral_lut :: 62;
	fire_lut :: 63;
	forest_ground :: 64;
	plains_ground :: 65;
	bg_forest1 :: 66;
	bg_forest2 :: 67;
	bg_forest3 :: 68;
	mountain_00 :: 69;
	mountain_01 :: 70;
	sky :: 71;
	sun :: 72;
	moon :: 73;
	front_birch_00 :: 74;
	front_birch_01 :: 75;
	front_pine_00 :: 76;
	front_pine_01 :: 77;
	front_pine_02 :: 78;
	forest_hills_00 :: 79;
	forest_hills_01 :: 80;
	middle_birch_00 :: 81;
	middle_birch_01 :: 82;
	middle_birch_02 :: 83;
	middle_pine_00 :: 84;
	middle_pine_01 :: 85;
	middle_pine_02 :: 86;
	back_pine_00 :: 87;
	back_pine_01 :: 88;
	back_pine_02 :: 89;
	overgrown_roots_0 :: 90;
	overgrown_roots_1 :: 91;
	overgrown_roots_2 :: 92;
	tall_grass_0 :: 93;
	tall_grass_1 :: 94;
	tall_grass_stub :: 95;
	flint_axe :: 96;
	flint_pickaxe :: 97;
	flint_sword :: 98;
	hammer :: 99;
	destroy_hammer :: 100;
	monster_essence :: 101;
	fibre :: 102;
	flint :: 103;
	goblin_hide :: 104;
	raw_goblin_meat :: 105;
	cooked_goblin_meat :: 106;
	stone :: 107;
	iron :: 108;
	tool_belt :: 109;
	wood :: 110;
	wood_log :: 111;
	torch :: 112;
	acorn :: 113;
	fireball :: 114;
	arrow :: 115;
	magic_arrow_1 :: 116;
	wood_back_wall :: 117;
	wood_back_wall_scaffolding :: 118;
	wood_defense_wall :: 119;
	campfire_off :: 120;
	campfire_on :: 121;
	furnace :: 122;
	furnace_on :: 123;
	furnace_off :: 124;
	player_sword_slash1_item :: 125;
	player_sword_slash1_trail :: 126;
	player_sword_slash2_item :: 127;
	player_sword_slash2_trail :: 128;
	// slash3_sword :: 129;
	// slash3_trail :: 130;
	player :: 131;
	oak_sapling :: 132;
	tall_grass :: 133;
	gobby :: 134;
	gobby_heavy :: 135;
	ogre :: 136;
	mage :: 137;
	skele :: 138;
	campfire :: 139;
	corefire :: 140;
	back_wall :: 141;
	side_wall :: 142;
	portal :: 143;
	portal_on :: 144;
	portal_off :: 145;
	poison_bubble :: 146;
	p_ember :: 147;
	ground_torch_on :: 148;
	ground_torch_off :: 149;
	raw_essence_brick :: 150;
	essence_brick :: 151;
	completion_wheel :: 152;
	ron_dash_base :: 153;
	skele_idle :: 154;
	skele_walk :: 155;
	skele_throw :: 156;
	skele_death :: 157;
	skele_shield :: 158;
	thrown_sword :: 159;
	heart_gem :: 160;
	p_heart :: 161;
	corefire_on :: 162;
	corefire_off :: 163;
	rotate_icon :: 164;
	arrow_rune :: 165;
	base_totem :: 166;
	gob_mage_attack :: 167;
	gob_mage_hurt :: 168;
	gob_mage_move :: 169;
	gob_mage_death :: 170;
	gob_mage_idle :: 171;
	cave_edge_back :: 172;
	cave_edge_front :: 173;
	side_cave_front :: 174;
	side_cave_mid :: 175;
	side_cave_playspace :: 176;
	base_mark :: 177;
	boss_portal :: 178;
	boss_portal_off :: 179;
	boss_portal_on :: 180;
	base_totem_scaffold :: 181;
	base_totem_cracks :: 182;
	base_totem_glow :: 183;
	bow_static :: 184;
	bow :: 185;
	storage_slab :: 186;
	boss_altar :: 187;
	boss_altar_scaffold :: 188;
	boss_altar_glow :: 189;
	rare_item :: 190;
	start_cliff_front :: 191;
	start_cliff_core :: 192;
	start_cliff_back :: 193;
	barbed_vines :: 194;
	trap :: 195;
	base_expansion_shrine :: 196;
	outer_marker :: 197;
	tree :: 198;
	icon_poison :: 199;
	icon_fire :: 200;
	research_page :: 201;
	wood_defense_wall_broken :: 202;
	flint_pickaxe_recipe :: 203;
	hunger_full :: 204;
	hunger_half :: 205;
	hunger_none :: 206;
	healthbar_bg :: 207;
	healthbar_fill :: 208;
	tree_cover :: 209;
	dash_bg :: 210;
	dash_fill :: 211;
	goblin_hide_vest :: 212;
	goblin_pendant :: 213;
	p_ember2 :: 214;
	healing_totem :: 215;
	forbidden_fruit :: 216;
	chest :: 217;
	flint_shard :: 218;
	icon_heal :: 219;
	icon_shrouded :: 220;
	// ^^^ append new :res entries here! Don't break ordering, unless you want broken bones
}

setup_animation :: (res: *ArcResource, frame_count: int, frame_duration_ms: float)
{
	res.frame_count = frame_count;
	res.frame_duration_ms = NewArray(frame_count, float);
	for * res.frame_duration_ms
	{
		<<it = frame_duration_ms;
	}
}

fill_resource_metadata_post :: inline (res: *ArcResource)
{
	if res.id ==
	{
		case .ron_dash_base;
		for * res.frame_duration_ms
		{
			<<it = DASH_DURATION * 1000 / res.frame_count;
		}
	}
}

fill_resource_metadata_pre :: inline (res: *ArcResource)
{
	if res.id ==
	{
		// define :res metadata here
		
		case .flint_shard;
		add_props(*res.props, .craftable);
		res.recipe = .[ .{.flint, 2}, .{.stone, 2} ];
		
		case .flint_pickaxe_recipe;
		add_props(*res.props, .consumable);
		res.flags |= .item;
		res.display_sprite_id = .research_page;
		res.consume_verb = "Learn";
		res.on_consume = (en: *Entity)
		{
			en.marked_for_destroy = true;
			unlock_recipe(.flint_pickaxe);
		};
		
		// randy: hmmmmmmmm this is weird
		// I think I need to formalise the idea of having entities each have their own resource storage by default
		// that doesn't get serialised. Idk tho.
		// This is very tricky, me brain hurty
		case .tree;
		res.flags |= .item;
		res.structure_tile_width = 3;
		
		case .base_expansion_shrine;
		res.flags |= .item;
		/*
		add_props(*res.props, .blueprint);
		res.recipe = .[ .{.stone, 4} ];
		res.setup_func = setup_base_expansion_shrine;
		*/
		
		case .start_cliff_front; #through;
		case .start_cliff_core; #through;
		case .start_cliff_back;
		res.offset = .{-283+13, -469};
		
		case .side_cave_front;
		res.offset = .{90, -404};
		case .side_cave_mid;
		res.offset = .{90, -404};
		case .side_cave_playspace;
		res.offset = .{90, -404};
		
		case .base_totem_scaffold;
		setup_animation(res, 4, 40);
		case .base_totem;
		add_props(*res.props, .blueprint, );
		res.recipe = .[ .{.stone, 4} ];
		res.setup_func = setup_base_totem;
		res.flags |= .item;
		res.scaffolding_id = .base_totem_scaffold;

		case .boss_altar_scaffold;
		setup_animation(res, 8, 0);
		case .boss_altar;
		// add_props(*res.props, .blueprint, .more_transparent);
		// res.recipe = .[ .{.stone, 26}, .{.rare_item, 4} ];
		// res.setup_func = setup_boss_altar;
		// res.flags |= .item;
		// res.scaffolding_id = .boss_altar_scaffold;
		
		case .corefire_on;
		setup_animation(res, 22, 60);
		
		case .stone;
		res.display_name = "Rock";
		res.description = "Plant me!";
		add_props(*res.props, .placeable, .can_place_outside_base);
		res.setup_func = setup_rock_sapling;
		
		case .completion_wheel;
		setup_animation(res, 28, 20);
		
		case .essence_brick;
		case .raw_essence_brick;
		add_props(*res.props, .craftable, .cookable);
		res.display_name = "Raw Essence Brick";
		res.description = "Cook me!";
		res.recipe = .[ .{.monster_essence, 4} ];
		res.cooks_into = .essence_brick;

		case .rare_item;
		add_props(*res.props, .craftable);
		res.display_name = "Concentrated Essence Brick";
		res.recipe = .[ .{.essence_brick, 16} ];
		
		case .ground_torch_on;
		setup_animation(res, 22, 60);
		case .ground_torch_off;
		// add_props(*res.props, .craftable, .blueprint, .reduce_render_scale, .placeable);
		// res.flags |= .item;
		// res.display_name = "Standing Torch";
		// res.description = "A cracked out night-light";
		// res.recipe = .[ .{.fibre, 1}, .{.wood, 3} ];
		// res.setup_func = setup_ground_torch;

		case .healing_totem;
		add_props(*res.props, .craftable, .placeable, .blueprint);
		res.display_name = "Healing Totem";
		res.flags |= .item;
		res.recipe = .[ .{.fibre, 4}, .{.stone, 4} ];
		res.setup_func = setup_healing_totem;
		
		case .axe_swing_item;
		setup_animation(res, 8, 70);
		res.anim_looping = false;
		case .player_axe_swing_trail;
		setup_animation(res, 8, 70);
		res.anim_looping = false;

		case .pickaxe_swing_item;
		setup_animation(res, 8, 70);
		res.anim_looping = false;
		case .pickaxe_swing_trail;
		setup_animation(res, 8, 70);
		res.anim_looping = false;
		
		// case .axe_swing;
		// setup_animation(res, 9, 70);
		// res.anim_looping = false;
		
		case .player_sword_slash1_item;
		setup_animation(res, 8, 60);
		res.anim_looping = false;
		res.frame_duration_ms[res.frame_duration_ms.count-1] *= 10;
		case .player_sword_slash1_trail;
		setup_animation(res, 8, 60);
		res.anim_looping = false;
		
		case .player_sword_slash2_item;
		setup_animation(res, 6, 60);
		// res.frame_duration_ms[res.frame_duration_ms.count-1] *= 10;
		res.anim_looping = false;
		case .player_sword_slash2_trail;
		setup_animation(res, 6, 60);
		res.anim_looping = false;
		
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
		case .gobby_heavy;
		res.flags |= .archetype;
		case .ogre;
		res.flags |= .archetype;
		case .mage;
		res.flags |= .archetype;
		case .skele;
		res.flags |= .archetype;
		case .corefire;
		res.flags |= .archetype;
		case .back_wall;
		res.flags |= .archetype;
		case .side_wall;
		res.flags |= .archetype;
		case .trap;
		res.flags |= .archetype;

		
		case .acorn;
		add_props(*res.props, .placeable, .can_place_outside_base);
		res.setup_func = setup_sapling;
		res.description = "Plant me!";
		
		// case .torch;
		// add_props(*res.props, .unstackable);
		// res.recipe = .[ .{.fibre, 2}, .{.wood, 2} ];
		
		case .wood;
		add_props(*res.props, .fuel);
		
		case .fibre;
		add_props(*res.props, .placeable, .can_place_outside_base);
		res.setup_func = setup_tall_grass_stub;
		res.description = "Plant me!";
		add_props(*res.props, .fuel);
		
		case .flint;
		// add_props(*res.props, .deconstruct_tool);
		
		case .destroy_hammer;
		res.display_name = "Destroyer's Hammer";
		add_props(*res.props, .craftable, .deconstruct_tool);
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 1}, .{.wood, 1} ];
		case .hammer;
		res.display_name = "Builder's Hammer";
		add_props(*res.props, .craftable);
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 1}, .{.wood, 1} ];
		
		case .flint_axe;
		add_props(*res.props, .craftable, .axe);
		res.display_name = "Flint Axe";
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 1}, .{.wood, 3} ];
		res.grip_offset = make_transform(.{-2, 11}, -45);

		case .flint_pickaxe;
		add_props(*res.props, .craftable, .pickaxe);
		res.display_name = "Flint Pickaxe";
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint_shard, 1}, .{.wood, 3} ];
		res.grip_offset = make_transform(.{-2, 11}, -45);
		
		case .flint_sword;
		res.display_name = "Flint Sword";
		add_props(*res.props, .craftable, .sword, .blockable, .disable_interaction_when_held);
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 3}, .{.wood, 1}, .{.fibre, 1} ];
		res.grip_offset = make_transform(.{-6, 16}, -45);
		
		case .tool_belt;
		add_props(*res.props, .equippable, .waist);
		res.max_stack_size = 1;
		// res.recipe = .[ .{.goblin_hide, 3}, .{.fibre, 1} ];	
		res.additional_hotbar_slots = 1;

		case .goblin_hide_vest;
		add_props(*res.props, .equippable, .craftable);
		res.flags |= .item;

		case .goblin_pendant;
		add_props(*res.props, .equippable, .craftable);
		res.flags |= .item;
		res.additional_dashes = 1;
		res.recipe =.[.{.goblin_hide, 3}, .{.fibre, 1}];
		
			/*
		case .workbench;
		add_props(*res.props, .placeable);
		res.display_name = "Workbench";
		res.recipe = .[ .{.fibre, 2}, .{.wood, 2} ];
		res.setup_func = setup_workbench;
		*/
		
		case .portal;
		res.flags |= .item;
		// res.display_sprite_id = .portal_off;
		// add_props(*res.props, .craftable, .blueprint, .reduce_render_scale, .placeable);
		// res.display_name = "Stone Portal";
		// res.recipe = .[ .{.stone, 40} ];
		// res.setup_func = setup_portal;

		case .boss_portal;
		res.flags |= .item;
		// res.display_sprite_id = .boss_portal_off;
		// add_props(*res.props, .craftable, .blueprint, .reduce_render_scale, .placeable);
		// res.display_name = "Evil Portal";
		// res.recipe = .[ .{.essence_brick, 666} ];
		// res.setup_func = setup_boss_portal;
		
		case .furnace_on;
		setup_animation(res, 22, 60);
		case .furnace;
		res.flags |= .item;
		// add_props(*res.props, .craftable, .blueprint, .reduce_render_scale, .placeable);
		// res.display_name = "Furnace";
		// res.description = "HAWT HAWT";
		// res.recipe = .[ .{.stone, 20} ];
		// res.setup_func = setup_furnace;
		
		case .campfire;
		add_props(*res.props, .craftable, .blueprint, .reduce_render_scale, .placeable);
		res.display_name = "Campfire";
		res.flags |= .item;
		res.recipe = .[ .{.fibre, 4}, .{.stone, 4} ];
		res.display_sprite_id = .campfire_off;
		res.setup_func = setup_campfire;
		case .campfire_on;
		setup_animation(res, 22, 60);

		// example of new scaffolding setup
		case .wood_back_wall;
		add_props(*res.props, .craftable, .blueprint, .placeable, .reduce_render_scale, .only_placable_inside_core_base);
		res.display_name = "Wood Wall";
		res.recipe = .[ .{.wood, 7}, .{.fibre, 1} ];
		res.setup_func = setup_wall;
		res.scaffolding_id = .wood_back_wall_scaffolding;
		res.tile_blocking_layer = .back_wall;
		case .wood_back_wall_scaffolding;
		setup_animation(res, 6, 0);
		
		case .wood_defense_wall;
		add_props(*res.props, .craftable, .blueprint, .placeable, .flippable, .reduce_render_scale, .only_placable_inside_core_base);
		res.display_name = "Wood Defense Wall";
		res.recipe = .[ .{.fibre, 3}, .{.wood, 10} ];	
		res.setup_func = setup_defense_wall;
		res.scaffolding_id = .wood_defense_wall_broken;
		res.offset = .{0, 0};
		res.structure_tile_width = 3;
		case .wood_defense_wall_broken;
		setup_animation(res, 1, 0);

		case .storage_slab;
		add_props(*res.props, .craftable, .blueprint, .placeable);
		res.flags |= .item;
		res.display_sprite_id = .chest;
		res.display_name = "Chest";
		res.recipe = .[ .{.wood, 16}, .{.fibre, 4} ];
		res.setup_func = setup_storage_slab;

		case .raw_goblin_meat;
		add_props(*res.props, .cookable, .consumable);
		res.cooks_into = .cooked_goblin_meat;
		res.on_consume = (en: *Entity)
		{
			consume_item(en);
			player := get_player();
			apply_effect_to_entity(player, .poison, 5, 1);
			// apply_effect_to_entity(player, .on_fire, 5, 1);
			play_sound_global("eat");
		};
		
		case .cooked_goblin_meat;
		add_props(*res.props, .consumable);
		res.on_consume = (en: *Entity)
		{
			consume_item(en);
			heal_entity(get_player(), 10);
			play_sound_global("eat");
		};

		case .forbidden_fruit;
		res.flags |= .item;
		add_props(*res.props, .consumable);
		res.on_consume = (en: *Entity)
		{
			consume_item(en);
			player := get_player();
			player.max_health += 10;
			// player.health = player.max_health;
			play_sound_global("eat");
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
		setup_animation(res, 7, 80);
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

		case .char_roll;
		setup_animation(res, 7, DASH_DURATION * 1000 / 7.0);
		res.offset = .{0, -8};
	
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
		setup_animation(res, 5, 10);
		case .p_upwards;
		setup_animation(res, 2, 10);
		case .p_ground;
		setup_animation(res, 4, 10);
		case .p_diagonal;
		setup_animation(res, 4, 10);
		case .p_poof;
		setup_animation(res, 3, 10);
		
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

		// GOBBY HEAVY
		case .gob_heavy_idle;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .gob_heavy_run;
		setup_animation(res, 8, 1.0/12.0*1000);
		res.offset = .{0, -50};
		case .gob_heavy_attack;
		setup_animation(res, 8, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .gob_heavy_hurt;
		setup_animation(res, 3, 1.0/12.0*1000);
		res.offset = .{0, -50};
		case .gob_heavy_death;
		setup_animation(res, 4, 1.0/12.0*1000);
		res.offset = .{0, -50};

		//OGRE
		case .ogre_idle;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, 0};
		case .ogre_walk;
		setup_animation(res, 8, 200);
		res.offset = .{0, 0};
		case .ogre_attack;
		setup_animation(res, 7, 200);
		res.offset = .{0, 0};

		//MAGE
		case .mage_idle;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, -50};

		//Mr. Skellybones
		case .skele_idle;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .skele_walk;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .skele_throw;
		setup_animation(res, 6, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .skele_shield;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, -50};
		case .skele_death;
		setup_animation(res, 4, 1.0/8.0*1000);
		res.offset = .{0, -50};

		/*
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
		*/

		case .cave_edge_front;
		res.offset = .{225, 0};

		// temp
		case .forest_ground;
		res.offset = .{0, -66};
		case .plains_ground;
		res.offset = .{0, -64};
		case .bg_forest1;
		res.offset = .{0, -67};
		case .bg_forest2;
		res.offset = .{0, -67};
		case .bg_forest3;
		res.offset = .{0, -67};
		case .sky;
		res.offset = .{0, -67};

		//Rob
		case .poison_bubble;
		setup_animation(res, 8, 0.5*1000);
		case .p_ember;
		setup_animation(res, 2, 0.5*1000);
		case .p_ember2;
		setup_animation(res, 4, 0.5*1000);
		case .p_heart;
		setup_animation(res, 8, 0.5*1000);

		case .gob_mage_attack;
		setup_animation(res, 5, 1.0/8.0*1000);
		case .gob_mage_hurt;
		setup_animation(res, 4, 1.0/8.0*1000);
		case .gob_mage_move;
		setup_animation(res, 6, 1.0/6.0*1000);
		case .gob_mage_death;
		setup_animation(res, 4, 1.0/8.0*1000);
		case .gob_mage_idle;
		setup_animation(res, 3,  0.4*1000);

		case .heart_gem;
		// randy: added this in so it doesn't get shipped to users rn lol
		#if ROB_TESTING
		{
			res.display_name = "Heart Gem";
			res.description = "Casts Heal on use";
			add_props(*res.props, .craftable, .disable_interaction_when_held, .casting_medium, .cast_heal);
			res.max_stack_size = 1;
			res.recipe = .[.{.wood, 1} ];
		}

		case .arrow_rune;

		#if ROB_TESTING
		{
			res.display_name = "Arrow Rune";
			res.description = "Casts Magic Arrow on use";
			add_props(*res.props, .craftable, .disable_interaction_when_held, .casting_medium, .cast_magic_arrows);
			res.max_stack_size = 1;
			res.recipe = .[.{.wood, 1} ];
		}

		case .bow_static;
		/*
			res.display_name = "Bow";
			res.description = "Shoots Arrows";
			add_props(*res.props, .craftable, .disable_interaction_when_held, .bow, .render_sprite);
			res.max_stack_size = 1;
			res.recipe = .[.{.wood, 10}, .{.fibre, 5} ];
			res.offset = .{-5,-10};
		*/

		case .arrow;
		/*
		res.display_name = "Arrows";
		res.description = "Ammo for the Bow";
		add_props(*res.props, .craftable);
		res.recipe = .[ .{.flint, 1}, .{.wood, 1} ];
		res.max_stack_size = 99;
		*/


		case .bow;
		setup_animation(res, 3, 1.0*1000);
		res.offset = .{0,-15};

		case .barbed_vines;
			add_props(*res.props, .craftable, .blueprint, .placeable, .reduce_render_scale, .trap);
			res.display_name = "Spikes";
			res.recipe = .[ .{.flint, 1}, .{.wood, 3} ];	
			res.setup_func = setup_spikes;	
	}
}


// old config
// https://github.com/bigrando420/jaitime/blob/e372343131d09785777ce5122c6430557da6a076/arcane/config.jai

#import "Text_File_Handler";
