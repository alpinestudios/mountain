//
// The current definition of a resource is something that gets instantly loaded
// on startup and doesn't change throughout the game.
//
// TODO
// [ ] hot reloading of this entire system. Requires an @alloc cleanup

// randy: Where I think I went wrong with this resource system was having too
// blury of a division between types of resource. It's lead to runtime errors,
// which is cringe. This isn't Unity.
// I think having a clear division between Sprite/Texture/Item/Archetype would
// serve me better and simplify the codebase quite a bit.
// Well, that's a lesson for future me, since it'll be too much work to go back
// on now... 13-12-2023-093311

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
		
		// randy: I'm putting this back in here since we actually need this for cold
		// storage of entity data, in stuff like the structure_tile_width
		archetype :: (1<<5);
		
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
	durability: int;
	
	// TEXTURE
	texture: *ID3D11Texture2D;
	view: *ID3D11ShaderResourceView;
	width, height: int;
	
	// SPRITE
	texture_id: ResourceID;
	rect: Range2;
	offset: Vector2;
	grip_offset: Transform2;
	grip_xform: Matrix4;
	hand_sockets: []Transform2;
	pivot: Pivot = .bottom_center;
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
 tile_blocking_layer: enum { playspace; back_wall; decoration; };
 consume_verb: string = "Eat";
 craft_time := DEFAULT_CRAFT_TIME;
 attack_length:= 0.0;
 recovery_length := 0.0;
 grow_into_entity_func := setup_oak_tree;
 
	// todo - hot reload
	last_modified: Apollo_Time = APOLLO_TIME_INVALID;
	modify_cooldown_timer: float;
}
nil_resource: *ArcResource;
nil_func :: (en: *Entity) { };

ArchetypeID :: ResourceID;
SpriteID :: ResourceID;
ItemID :: ResourceID;
SoundID :: ResourceID;
AnimationID :: ResourceID;

Texture :: ArcResource;
Sprite :: ArcResource;

ItemAmount :: struct
{
	id: ItemID;
	amount: int;
}

// randy: uses entity for the dynamic data
get_dynamic_display_name :: (res: *ArcResource, entity: *Entity) -> string
{
	if res.id ==
	{
		case .research_page;
		assert(entity.recipe_to_unlock != .nil, "no recipe provided, can't derive name");
		unlock_item_name := get_display_name(get_resource(entity.recipe_to_unlock));
		return tprint("% Recipe", unlock_item_name);
		
		case;
		return get_display_name(res);
	}
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
	assert(xx res.flags & .item, "% resource doesn't have .item flag", res.name);
	return res;
}

get_sprite :: (id: ResourceID) -> *ArcResource
{
	res := get_resource(id);
	assert(xx res.flags & .sprite, "% resource doesn't have .sprite flag", res.name);
	return res;
}

get_wav :: (id: ResourceID) -> *ArcResource
{
	res := get_resource(id);
	assert(is_valid(res), "Invalid resource id %", id);
	assert(xx res.flags & .wav, "% resource doesn't have .wav flag", res.name);
	return res;
}

get_texture :: (id: ResourceID) -> *ArcResource
{
	// our nil_texture has the checkerboard pattern, so it's technically valid
	res := get_resource(id);
	assert(xx res.flags & .texture, "% resource doesn't have .texture flag", res.name);
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
	assert(is_valid(res), "Resource tex % not found", name);
	assert(xx res.flags & .texture, "% resource doesn't have .texture flag", name);
	return res;
}

get_sprite_from_name :: (name: string) -> *ArcResource
{
	res := get_resource_from_name(name);
	assert(is_valid(res), "Resource sprite % not found", name);
	assert(xx res.flags & .sprite, "% resource doesn't have .sprite flag", name);
	return res;
}

get_wav_from_name :: (name: string) -> *ArcResource
{
	res := get_resource_from_name(name);
	assert(is_valid(res), "Resource Wav % not found", name);
	assert(xx res.flags & .wav, "% resource doesn't have .wav flag", name);
	return res;
}

get_item_from_name :: (name: string) -> *ArcResource
{
	res := get_resource_from_name(name);
	assert(is_valid(res), "Resource Item % not found", name);
	assert(xx res.flags & .item, "% resource doesn't have .item flag", name);
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
				assert(success, "Failed to load %", it);
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
				assert(format.nSamplesPerSec == SAMPLE_RATE, "Expected sample rate % from %, instead got %", SAMPLE_RATE, res.name, format.nSamplesPerSec);
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
			// randy: bro this is fucked lol, we really need a clean slate with this whole resource system. Too late now though! 06-12-2023-101919
			// assert(entity.item_id != .nil, "% setup func needs to set an item_id so we can later recall the resource if needed.", it.id);
		}
		
		if has_prop(it.props, .attackable)
		{
			assert(it.attack_length != 0, "Marked as attack, but no attack_length set?");
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
	
	// randy: my solution to the ordering issue lol
	// structures
	base_stone :: 5;
	
	// crafting items
	wood_axe :: 50;
	
	//
	axe_swing_item :: 102;
	player_axe_swing_trail :: 103;
	pickaxe_swing_item :: 104;
	pickaxe_swing_trail :: 105;
	ron_idle_base :: 106;
	ron_idle_sword :: 107;
	ron_walk_base :: 108;
	ron_walk_sword :: 109;
	ron_sprint_base :: 110;
	ron_sprint_sword :: 111;
	ron_idle_pretty :: 112;
	char_idle :: 113;
	char_walk :: 114;
	char_run :: 115;
	char_slash1 :: 116;
	char_stab1 :: 117;
	char_punch :: 118;
	char_jump_rise :: 119;
	char_jump_fall :: 120;
	char_jump_apex :: 121;
	char_roll :: 122;
	char_hurt :: 123;
	char_land :: 124;
	char_death :: 125;
	gob_idle :: 126;
	gob_run :: 127;
	gob_attack :: 128;
	gob_hurt :: 129;
	gob_death :: 130;
	gob_heavy_idle :: 131;
	gob_heavy_run :: 132;
	gob_heavy_attack :: 133;
	gob_heavy_hurt :: 134;
	gob_heavy_death :: 135;
	ogre_idle :: 136;
	ogre_walk :: 137;
	ogre_attack :: 138;
	mage_idle :: 139;
	tree_full :: 140;
	tree_stump :: 141;
	tree_long_log :: 142;
	rock_deposit :: 143;
	iron_deposit :: 144;
	p_parry :: 145;
	p_upwards :: 146;
	p_diagonal :: 147;
	p_ground :: 148;
	p_poof :: 149;
	red_vignette :: 150;
	middle_mouse_flip_icon :: 151;
	right_click_icon :: 152;
	left_click_icon :: 153;
	early_night_lut :: 154;
	mid_night_lut :: 155;
	dawn_lut :: 156;
	day_lut :: 157;
	dusk_lut :: 158;
	evening_lut :: 159;
	late_night_lut :: 160;
	morning_lut :: 161;
	neutral_lut :: 162;
	fire_lut :: 163;
	forest_ground :: 164;
	plains_ground :: 165;
	bg_forest1 :: 166;
	bg_forest2 :: 167;
	bg_forest3 :: 168;
	mountain_00 :: 169;
	mountain_01 :: 170;
	sky :: 171;
	sun :: 172;
	moon :: 173;
	front_birch_00 :: 174;
	front_birch_01 :: 175;
	front_pine_00 :: 176;
	front_pine_01 :: 177;
	front_pine_02 :: 178;
	forest_hills_00 :: 179;
	forest_hills_01 :: 180;
	middle_birch_00 :: 181;
	middle_birch_01 :: 182;
	middle_birch_02 :: 183;
	middle_pine_00 :: 184;
	middle_pine_01 :: 185;
	middle_pine_02 :: 186;
	back_pine_00 :: 187;
	back_pine_01 :: 188;
	back_pine_02 :: 189;
	overgrown_roots_0 :: 190;
	overgrown_roots_1 :: 191;
	overgrown_roots_2 :: 192;
	tall_grass_0 :: 193;
	crude_club :: 194;
	tall_grass_stub :: 195;
	flint_axe :: 196;
	flint_pickaxe :: 197;
	flint_sword :: 198;
	workbench :: 199;
	destroy_hammer :: 200;
	monster_essence :: 201;
	fibre :: 202;
	flint :: 203;
	goblin_hide :: 204;
	raw_goblin_meat :: 205;
	cooked_goblin_meat :: 206;
	stone :: 207;
	iron :: 208;
	tool_belt :: 209;
	wood :: 210;
	wood_log :: 211;
	torch :: 212;
	acorn :: 213;
	fireball :: 214;
	arrow :: 215;
	magic_arrow_1 :: 216;
	wood_back_wall :: 217;
	wood_back_wall_scaffolding :: 218;
	wood_defense_wall :: 219;
	campfire_off :: 220;
	campfire_on :: 221;
	furnace :: 222;
	furnace_on :: 223;
	furnace_off :: 224;
	player_sword_slash1_item :: 225;
	player_sword_slash1_trail :: 226;
	player_sword_slash2_item :: 227;
	player_sword_slash2_trail :: 228;
	player :: 229;
	oak_sapling :: 230;
	tall_grass :: 231;
	gobby :: 232;
	gobby_heavy :: 233;
	ogre :: 234;
	mage :: 235;
	skele :: 236;
	campfire :: 237;
	corefire :: 238;
	back_wall :: 239;
	side_wall :: 240;
	portal :: 241;
	portal_on :: 242;
	portal_off :: 243;
	poison_bubble :: 244;
	p_ember :: 245;
	ground_torch_on :: 246;
	ground_torch_off :: 247;
	raw_essence_brick :: 248;
	essence_brick :: 249;
	completion_wheel :: 250;
	ron_dash_base :: 251;
	skele_idle :: 252;
	skele_walk :: 253;
	skele_throw :: 254;
	skele_death :: 255;
	skele_shield :: 256;
	thrown_sword :: 257;
	heart_gem :: 258;
	p_heart :: 259;
	corefire_on :: 260;
	corefire_off :: 261;
	rotate_icon :: 262;
	arrow_rune :: 263;
	base_totem :: 264;
	gob_mage_attack :: 265;
	gob_mage_hurt :: 266;
	gob_mage_move :: 267;
	gob_mage_death :: 268;
	gob_mage_idle :: 269;
	cave_edge_back :: 270;
	cave_edge_front :: 271;
	side_cave_front :: 272;
	side_cave_mid :: 273;
	side_cave_playspace :: 274;
	base_mark :: 275;
	boss_portal :: 276;
	boss_portal_off :: 277;
	boss_portal_on :: 278;
	base_totem_scaffold :: 279;
	base_totem_cracks :: 280;
	base_totem_glow :: 281;
	bow_static :: 282;
	bow :: 283;
	storage_slab :: 284;
	boss_altar :: 285;
	boss_altar_scaffold :: 286;
	boss_altar_glow :: 287;
	rare_item :: 288;
	start_cliff_front :: 289;
	start_cliff_core :: 290;
	start_cliff_back :: 291;
	barbed_vines :: 292;
	trap :: 293;
	base_expansion_shrine :: 294;
	outer_marker :: 295;
	tree :: 296;
	icon_poison :: 297;
	icon_fire :: 298;
	research_page :: 299;
	wood_defense_wall_broken :: 300;
	flint_pickaxe_recipe :: 301;
	hunger_full :: 302;
	hunger_half :: 303;
	hunger_none :: 304;
	healthbar_bg :: 305;
	healthbar_fill :: 306;
	tree_cover :: 307;
	dash_bg :: 308;
	dash_fill :: 309;
	goblin_hide_vest :: 310;
	goblin_pendant :: 311;
	p_ember2 :: 312;
	healing_totem :: 313;
	forbidden_fruit :: 314;
	chest :: 315;
	flint_shard :: 316;
	icon_heal :: 317;
	icon_shrouded :: 318;
	coal :: 319;
	player_club_bonk_item :: 320;
	player_club_bonk_trail :: 321;
	icon_rested :: 322;
	game_logo :: 323;
	stone_defense_wall :: 324;
	farming_totem :: 325;
	vfx_learn :: 326;
	floppy :: 327;
	p_farming :: 328;
	gobby_pouch :: 329;
	berry_bush :: 330;
	berry_bush_plucked :: 331;
	berry :: 332;
	wind_blade :: 333;
	attack_crescent_1 :: 334;
	//  :: 343;
	plains_far :: 340;
	plains_mid :: 341;
	plains_near :: 342;
	plains_sky :: 343;
	plains_tree :: 344;
	plains_rock_tree :: 345;
	plains_ironwood_tree :: 346;
	rock_seed :: 357;
	//  :: 358;
	vfx_slash :: 359;
	mob_grunt :: 360;
	mob_slime_smol :: 361;
	mob_slime_beeg :: 362;
	p_uncrafted :: 363;
	//  :: 364;
	grass_0 :: 365;
	grass_1 :: 366;
	grass_2 :: 367;
	fibre_seed :: 368;
	vfx_impact_lines :: 369;
	oak_tree :: 370;
	ironwood_tree :: 371;
	rock_tree :: 372;
	slime_beeg :: 373;
	slime_smol :: 374;
	grunt :: 375;
	rock_sapling :: 376;
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

fill_resource_metadata_post :: (res: *ArcResource)
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

fill_resource_metadata_pre :: (res: *ArcResource)
{
	if res.id ==
	{
		// define :res metadata here
		
		case .vfx_impact_lines;
		setup_animation(res, 4, 40);
		res.pivot = .center_center;
		
		case .rock_sapling;
		res.grow_into_entity_func = setup_rock_tree;
		case .oak_sapling;
		res.grow_into_entity_func = setup_oak_tree;
		
		case .rock_seed;
		add_props(*res.props, .placeable, .can_place_outside_base);
		res.setup_func = setup_rock_sapling;
		res.description = "Plant me!";
		res.flags |= .item;
		
		case .acorn;
		add_props(*res.props, .placeable, .can_place_outside_base);
		res.setup_func = setup_oak_sapling;
		res.description = "Plant me!";

		case .fibre_seed;
		add_props(*res.props, .placeable, .can_place_outside_base);
		res.setup_func = setup_tall_grass_stub;
		res.description = "Plant me!";
		res.flags |= .item;
		
		case .base_stone;
		res_setup_base_stone(res);
		
		case .vfx_slash;
		setup_animation(res, 3, 50);
		
		case .flint_sword;
		add_props(*res.props, .attackable, .unlockable, .workbench_recipe, .sword, .blockable);
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 3}, .{.wood, 3}, .{.fibre, 2} ];
		res.grip_xform = make_transform_mat4(.{6, -4}, -70);
		res.durability = 100;
		res.attack_length = 0.2;
		
		case .wood_axe;
		add_props(*res.props, .attackable, .unlockable, .workbench_recipe, .axe);
		res.max_stack_size = 1;
		res.recipe = .[ .{.wood, 1}, .{.fibre, 2} ];
		res.grip_xform = make_transform_mat4(.{2, -11}, 0);
		res.durability = 10;
		res.attack_length = 0.2;
		
		case .flint_axe;
		add_props(*res.props, .attackable, .unlockable, .workbench_recipe, .axe);
		res.max_stack_size = 1;
		res.recipe = .[ .{.flint, 2}, .{.wood, 3}, .{.fibre, 2} ];
		res.grip_xform = make_transform_mat4(.{2, -11}, 0);
		res.durability = 100;
		res.attack_length = 0.2;
		res.recovery_length = 0.2;

		
		case .plains_far; #through;
		case .plains_mid; #through;
		case .plains_near; #through;
		case .plains_ground;
		res.offset = .{0, -71};
		
		case .wind_blade;
		res.flags |= .item;
		res.attack_length = 0.3;
		res.grip_offset = make_transform(xy(-4, 4), 45);
		add_props(*res.props, .draw_behind);
		
		case .berry;
		berry_res_init(res);
		
		case .gobby_pouch;
		add_props(*res.props, .equippable, .workbench_recipe, .unlockable);
		res.recipe = .[ .{.goblin_hide, 8}, .{.fibre, 4}, ];
		
		case .stone_defense_wall;
		add_props(*res.props, .unlockable, .build_recipe, .placeable, .reduce_render_scale, .only_placable_inside_core_base);
		res.recipe = .[ .{.stone, 16} ];	
		res.setup_func = setup_stone_defense_wall;
		res.structure_tile_width = 2;
		
		case .player_club_bonk_item;
		setup_animation(res, 10, 80);
		case .player_club_bonk_trail;
		setup_animation(res, 10, 80);
		
		case .crude_club;
		// add_props(*res.props, .draw_behind, .workbench_recipe, .unlockable, .club);
		// res.display_name = "Big Bonker 5000";
		// res.recipe = .[ .{.wood, 2}, ];
		// res.flags |= .item;
		// res.max_stack_size = 1;
		// res.craft_time = DEFAULT_CRAFT_TIME * 0.5;
		// res.durability = 10;
		// res.grip_offset = make_transform(xy(-4, 4), 45);
		
		case .coal;
		add_props(*res.props, .campfire_recipe, .unlockable);
		res.recipe = .[ .{.wood, 1}, ];
		res.flags |= .item;
		res.craft_time = DEFAULT_CRAFT_TIME * 0.5;
		
		case .workbench;
		add_props(*res.props, .build_recipe, .placeable, .unlockable);
		res.flags |= .item;
		res.recipe = .[ .{.wood, 2}, .{.fibre, 2} ];
		res.setup_func = setup_workbench;
		res.structure_tile_width = 2;
		
		case .flint_shard;
		// add_props(*res.props, .campfire_recipe, .unlockable);
		// res.recipe = .[ .{.flint, 2}, .{.stone, 2}, .{.coal, 1} ];
		
		case .research_page;
		add_props(*res.props, .consumable);
		res.flags |= .item;
		res.max_stack_size = 1;
		res.consume_verb = "Learn";
		res.on_consume = (en: *Entity)
		{
			assert(en.recipe_to_unlock != .nil, "No recipe provided");
			en.marked_for_destroy = true;
			unlock_recipe(en.recipe_to_unlock);
		};
		
		// randy: hmmmmmmmm this is weird
		// I think I need to formalise the idea of having entities each have their own resource storage by default
		// that doesn't get serialised. Idk tho.
		// This is very tricky, me brain hurty
		//
		// randy: yeaaa I'm coming back to this like months later. Still have no fucking
		// idea what to do here. I kinda regret doing this whole resource system, but at
		// the same time don't. We need this data to be "constant" and not on the entities
		// because it's a part of the game design, not the simulation.
		//
		// randy: I've done a patchwork solution that kinda works. Now using the archetype
		// to basically double as the resource storage. GOOD ENUF! 13-12-2023-094626
		case .oak_tree;
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
		// res.description = "Plant me!";
		// add_props(*res.props, .placeable, .can_place_outside_base);
		// res.setup_func = setup_rock_sapling;

		case .monster_essence;
		res.flags |= .item;
		res.max_stack_size = 999;
		
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
		add_props(*res.props, .unlockable, .build_recipe, .reduce_render_scale, .placeable);
		res.flags |= .item;
		res.display_name = "Standing Torch";
		res.description = "A cracked out night-light";
		res.recipe = .[ .{.fibre, 1}, .{.wood, 3} ];
		res.setup_func = setup_ground_torch;
		res.tile_blocking_layer = .decoration;

		case .healing_totem;
		add_props(*res.props, .placeable, .blueprint);
		res.display_name = "Healing Totem";
		res.flags |= .item;
		res.recipe = .[ .{.fibre, 4}, .{.stone, 4} ];
		res.setup_func = setup_healing_totem;

		case .farming_totem;
		add_props(*res.props, .placeable, .blueprint, .build_recipe, .unlockable);
		res.display_name = "Farming Totem";
		res.flags |= .item;
		res.recipe = .[ .{.fibre, 4}, .{.stone, 4} ];
		res.setup_func = setup_farming_totem;
		
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
		// res.frame_duration_ms[res.frame_duration_ms.count-1] *= 10;
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
		
		
		// case .torch;
		// add_props(*res.props, .unstackable);
		// res.recipe = .[ .{.fibre, 2}, .{.wood, 2} ];
		
		case .wood;
		add_props(*res.props, .fuel);
		
		case .fibre;
		//
		
		case .flint;
		// add_props(*res.props, .deconstruct_tool);
		
		case .destroy_hammer;
		// res.display_name = "Destroyer's Hammer";
		// res.description = "Destroys placed things";
		// add_props(*res.props, .unlockable, .workbench_recipe, .deconstruct_tool);
		// res.max_stack_size = 1;
		// res.recipe = .[ .{.flint, 1}, .{.wood, 1} ];

		// case .hammer;
		// res.display_name = "Builder's Hammer";
		// add_props(*res.props, .craftable);
		// res.max_stack_size = 1;
		// res.recipe = .[ .{.flint, 1}, .{.wood, 1} ];
		
		case .flint_pickaxe;
		// add_props(*res.props, .draw_behind, .unlockable, .workbench_recipe, .pickaxe);
		// res.max_stack_size = 1;
		// res.recipe = .[ .{.flint, 2}, .{.wood, 3}, .{.fibre, 2} ];
		// res.grip_offset = make_transform(.{-2, 11}, 0);
		// res.durability = 100;
		
		case .tool_belt;
		add_props(*res.props, .equippable, .waist);
		res.max_stack_size = 1;
		// res.recipe = .[ .{.goblin_hide, 3}, .{.fibre, 1} ];	
		res.additional_hotbar_slots = 1;

		case .goblin_hide_vest;
		add_props(*res.props, .equippable, .craftable);
		res.recipe = .[ .{.goblin_hide, 6}, .{.fibre, 1} ];	
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
		add_props(*res.props, .build_recipe, .unlockable, .reduce_render_scale, .placeable);
		res.display_name = "Campfire";
		res.flags |= .item;
		res.recipe = .[ .{.fibre, 4}, .{.stone, 4} ];
		res.display_sprite_id = .campfire_off;
		res.setup_func = setup_campfire;
		case .campfire_on;
		setup_animation(res, 22, 60);

		// example of new scaffolding setup
		case .wood_back_wall;
		add_props(*res.props, .unlockable, .build_recipe, .placeable, .reduce_render_scale, .only_placable_inside_core_base);
		res.display_name = "Wood Wall";
		res.recipe = .[ .{.wood, 3}, .{.fibre, 1} ];
		res.setup_func = setup_wall;
		res.scaffolding_id = .wood_back_wall_scaffolding;
		res.tile_blocking_layer = .back_wall;
		res.structure_tile_width = 3;
		case .wood_back_wall_scaffolding;
		setup_animation(res, 6, 0);
		
		case .wood_defense_wall;
		add_props(*res.props, .unlockable, .build_recipe, .placeable, .flippable, .reduce_render_scale, .only_placable_inside_core_base, .auto_flip_around_center);
		res.display_name = "Wood Defense Wall";
		res.recipe = .[ .{.fibre, 2}, .{.wood, 5} ];	
		res.setup_func = setup_defense_wall;
		res.scaffolding_id = .wood_defense_wall_broken;
		res.offset = .{0, 0};
		res.structure_tile_width = 2;
		case .wood_defense_wall_broken;
		setup_animation(res, 1, 0);

		case .storage_slab;
		add_props(*res.props, .unlockable, .build_recipe, .placeable);
		res.flags |= .item;
		res.display_sprite_id = .chest;
		res.display_name = "Chest";
		res.recipe = .[ .{.wood, 16}, .{.fibre, 4} ];
		res.setup_func = setup_storage_slab;

		case .raw_goblin_meat;
		add_props(*res.props, .cookable, .consumable);
		res.description = "Might want to cook this first...";
		res.on_consume = (en: *Entity)
		{
			consume_item(en);
			player := get_player();
			apply_effect_to_entity(player, .poison, 5, 1);
			// apply_effect_to_entity(player, .on_fire, 5, 1);
			play_sound_global("eat");
		};
		
		case .cooked_goblin_meat;
		add_props(*res.props, .consumable, .campfire_recipe, .unlockable);
		res.recipe = .[ .{.raw_goblin_meat, 1}, ];
		res.on_consume = (en: *Entity)
		{
			consume_item(en);
			heal_entity(get_player(), 10);
			restore_hunger(4);
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
		setup_animation(res, 8, 1.0/10.0*1000);
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
		
		case .p_uncrafted;
		setup_animation(res, 8, 0.5*1000);
		case .vfx_learn;
		setup_animation(res, 3, 50);
		case .p_farming;
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

		// case .barbed_vines;
		// 	add_props(*res.props, .blueprint, .placeable, .reduce_render_scale, .trap);
		// 	res.display_name = "Spikes";
		// 	res.recipe = .[ .{.flint, 1}, .{.wood, 3} ];	
		// 	res.setup_func = setup_spikes;	
	}
}


// old config
// https://github.com/bigrando420/jaitime/blob/e372343131d09785777ce5122c6430557da6a076/arcane/config.jai

#import "Text_File_Handler";
