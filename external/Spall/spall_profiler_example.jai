

DEFAULT_BUFFER_SIZE :: 64 * 1024 * 1024;

ProfileState :: struct
{
	profiling:= false;
	spall_profile: SpallProfile;
	spall_buffer: SpallBuffer;
}

profile_init :: (allocator := context.allocator, buffer_size: s64 = DEFAULT_BUFFER_SIZE) -> *ProfileState
{
	state := New(ProfileState, allocator=allocator);
	state.spall_profile = spall_init_file("performance.spall", 1000000.0 / get_rdtsc_frequency());
	state.spall_buffer.data = alloc(buffer_size, allocator=allocator);
	state.spall_buffer.length = buffer_size;
	assert(spall_buffer_init(*state.spall_profile, *state.spall_buffer), "Failed to init spall buffer");
	return state;
}

profile_shutdown :: (state: *ProfileState)
{
	spall_buffer_quit(*state.spall_profile, *state.spall_buffer);
	spall_quit(*state.spall_profile);
}

profile_begin :: (state: *ProfileState, name: string) #expand
{
	spall_buffer_begin(*state.spall_profile, *state.spall_buffer, name.data, xx name.count, xx rdtsc());
}

profile_end :: (state: *ProfileState) #expand
{
	spall_buffer_end(*state.spall_profile, *state.spall_buffer, xx rdtsc());
}

#import "Basic";
#import "Windows";
#import "Machine_X64";
#import "Spall";
// https://github.com/colrdavidson/spall-web/blob/master/examples/manual_tracing/simple_benchmark.c


/*

#if PROFILE_PERFORMANCE
{
	profile_block :: (name: string, loc:= #caller_location) #expand
	{
		if !app || !app.profile_state || app.profile_state.profiling then return;
		
		_name := name;
		if _name == ""
		{
			node := context.stack_trace;
			_name = node.info.name;
		}
		
		// TODO - this kinda works I guess
		// maybe I just spin up the ol' Tracey instead?
		
		profile_begin(app.profile_state, _name);
		`defer profile_end(app.profile_state);
	}
}
else
{
	profile_block :: (name: string, loc:= #caller_location) {}
}

*/