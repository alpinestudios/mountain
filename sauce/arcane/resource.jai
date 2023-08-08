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
		// types
		texture 		:: (1<<0);
		sprite 			:: (1<<1);
		wav 						:: (1<<2);
		shader 			:: (1<<3);
		item 					:: (1<<4);
		
		//
		hot_reload :: (1<<10);
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
 on_consume: (*Entity);
 
	// hot reload
	last_modified: Apollo_Time = APOLLO_TIME_INVALID;
	modify_cooldown_timer: float;
}
nil_resource: *ArcResource;

get_display_sprite_id :: (resource: *ArcResource) -> ResourceID
{
	return resource.id; // kinda redundant for now since we're just sharing data
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

#load "metadata.jai";
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
}