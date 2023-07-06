//
// The current definition of a resource is something that gets instantly loaded
// on startup and doesn't change throughout the game.
//

ResourceID :: #run type_of(Resource.id);
SpriteID :: #run type_of(Resource.id);

Texture :: Resource;
Sprite :: Resource;

Resource :: struct
{
	Flags :: enum
	{
		// types
		texture 		:: (1<<0);
		sprite 			:: (1<<1);
		wav 						:: (1<<2);
		
		//
		hot_reload :: (1<<10);
	}
	
	flags: Flags;
	name: string;
	id: u16;
	
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
	
	// hot reload
	last_modified: Apollo_Time = APOLLO_TIME_INVALID;
	modify_cooldown_timer: float;
}
nil_resource: *Resource;

ResourceState :: struct
{
	MAX_RESOURCES :: 1024;
	resources: [MAX_RESOURCES]Resource;
	resource_id_gen: u16;
}

is_nil :: (res: *Resource) -> bool
{
	return res == nil_resource;
}

is_valid :: (res: *Resource) -> bool
{
	return res != nil_resource && res.name != "" && res.id != 0;
}

create_resource :: (name: string) -> *Resource
{
	assert(is_nil(find_resource(name)), tprint("Resource % already exists", name));
	game_state.resource_id_gen += 1;
	res := *game_state.resources[game_state.resource_id_gen];
	res.id = game_state.resource_id_gen;
	res.name = copy_string(name, permanent_allocator);
	return res;
}

find_resource :: (name: string) -> *Resource
{
	for * game_state.resources if it.name == name then return it;
	return nil_resource;
}

get_texture :: (name: string) -> *Resource
{
	res := find_resource(name);
	assert(is_valid(res) && res.flags & .texture, tprint("Texture % not found", name));
	return res;
}
get_texture :: (id: u32) -> *Resource
{
	return *game_state.resources[id];
}

get_sprite :: (name: string) -> *Resource
{
	res := find_resource(name);
	assert(is_valid(res) && res.flags & .sprite, tprint("Spirte % not found", name));
	return res;
}
get_sprite :: (id: u32) -> *Resource
{
	return *game_state.resources[id];
}

texture_from_sprite :: (sprite: *Resource) -> *Resource
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
		push_allocator(context.default_allocator);
		files = file_list("res", recursive=true);
	}
	
	for files if path_extension(it) == "png"
	{
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
	}
	
	// metadata for resources
	parse := md_parse_file("res/res.mdesk");
	root := parse.node;
	
	// loop over meta textures
	textures_node := MD_FirstNodeWithString(root.first_child, md_string("textures"), 0);
	for node: textures_node.first_child
	{
		name := md_string(node.str);
		res := find_resource(name);
		if is_nil(res)
		{
			log_error("Texture % doesn't exist, metadata isn't being used", name);
			continue;
		}
		assert(is_texture(res));
		
		// fill in metadata
		res.frame_count = xx md_u64_from_key(node, "frame_count");
		ifx res.frame_count == 0 then res.frame_count = 1;
		res.rect.max.x /= res.frame_count;
		res.play_rate = md_float_from_key(node, "play_rate");
		res.offset = md_vector2_from_key(node, "offset");
		res.looping = !md_has_key(node, "disable_loop");
	}
}

is_texture :: (res: *Resource) -> bool
{
	return xx res.flags & .texture;
}