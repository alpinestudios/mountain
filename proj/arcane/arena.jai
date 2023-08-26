
ZERO_ON_RESET :: true; // might help in catching some stale pointer bugs?

//~ notes
//
// The arenas are basically game-specific. I just don't think it's that important to make this a proper module
// and have full reusability at the expense of not keeping things localised.
// Clone & Adjust is the way to go I reckon - randy 11/05/2023

// TODO - make these puppies run-time initialisable, EVERYBODY GETS AN ARENA MUAHAHAHAHHA

Arena :: struct
{
	name : string;
	buffer : *void;
	buffer_size : u64;
	cursor : u64;
}

MemoryState :: struct
{
	initialized : bool;
	permanent_arena : Arena;
	world_arena : Arena;
	//frame_arena : [2]Arena;
}
memory_state : MemoryState;

// allocators
// permanent_allocator :: context.default_allocator;
// world_allocator :: context.default_allocator;
frame_allocator :: temp;
permanent_allocator :: Allocator.{permanent_alloc_proc, null};
world_allocator :: Allocator.{world_alloc_proc, null};
// frame_allocator :: Allocator.{frame_alloc_proc, null};
// NOTE
// fuck having my own frame arena, we're just gonna keep using temp storage


arena_init :: (arena : *Arena, size : u64, debug_name : string)
{
	arena.name = debug_name;
	arena.buffer = VirtualAlloc(arena.buffer, size, MEM_COMMIT, PAGE_READWRITE);
	//arena.buffer = alloc(xx , context.default_allocator);
	arena.buffer_size = size;
}

memory_init :: ()
{
	assert(!memory_state.initialized);
	memory_state.initialized = true;
	
	arena_init(*memory_state.permanent_arena, gigabytes(2), "permanent");
	arena_init(*memory_state.world_arena, gigabytes(2), "world");
	// arena_init(*memory_state.frame_arena[0], gigabytes(2), "frame1");
	// arena_init(*memory_state.frame_arena[1], gigabytes(2), "frame2");
}

validate_memory_state :: ()
{
	assert(memory_state.initialized, "call memory_init first");
}

is_valid :: (arena : *Arena) -> bool
{
	return arena && arena.buffer && arena.name != "";
}

arena_reset :: (arena : *Arena)
{
	validate_memory_state();
	assert(is_valid(arena));
	#if ZERO_ON_RESET then memset(arena.buffer, 0, xx arena.cursor);
	arena.cursor = 0;
}

// swap_n_reset_frame_arenas :: ()
// {
// 	validate_memory_state();
// 	Swap(*memory_state.frame_arena[0], *memory_state.frame_arena[1]);
// 	arena_reset(*memory_state.frame_arena[0]);
// }

permanent_alloc_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void
{
	return arena_allocator_proc(mode, requested_size, old_size, old_memory, *memory_state.permanent_arena);
}

world_alloc_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void
{
	return arena_allocator_proc(mode, requested_size, old_size, old_memory, *memory_state.world_arena);
}

// frame_alloc_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void
// {
// 	return arena_allocator_proc(mode, requested_size, old_size, old_memory, *memory_state.frame_arena[0]);
// }

arena_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void
{
	validate_memory_state();
	arena : *Arena = allocator_data;
	assert(is_valid(arena));
	
	ptr : *u8;
	if mode ==
	{
		case .RESIZE;
		#through;
		case .ALLOCATE;
		alloc_size := align_forward(requested_size, 8);
		assert(xx alloc_size + arena.cursor < arena.buffer_size, 
		       tprint("Out of memory in arena % - increase the size or be a better programmer", arena.name));
		
		ptr = arena.buffer + arena.cursor;
		arena.cursor += xx alloc_size;
		memset(ptr, 0, alloc_size);
		
		// Just leak the old memory, since it's most likely temporary storage. Makes Jai's resizable structures play nice
		// This is exactly what the native temporary_storage does anyway lol...
		if mode == .RESIZE && old_size != 0
		{
			memcpy(ptr, old_memory, old_size);
			// is_temporary := arena == *memory_state.frame_arena[0] || arena == *memory_state.frame_arena[1];
			// if !is_temporary then log("WARNING: resizing on a linear allocator, old memory will be leaked", flags=.WARNING);
		}
		
		case;
		assert(false, tprint("% not handled", mode));
	}
	
	return ptr;
}

#scope_module;
#import "Basic";