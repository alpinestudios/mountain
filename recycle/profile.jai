/* profiling TODO

[ ] automatically grab the function from the stack trace and use it as the name
https://github.com/Jai-Community/Jai-Community-Library/wiki/Advanced#stack-trace

[ ] some way to insert the profile_block into every single function at build time


if I need a more advanced profiler:
https://github.com/rluba/jai-tracy/tree/master


*/

DEFAULT_BUFFER_SIZE :: 64 * 1024 * 1024;

get_rdtsc_frequency :: () -> u64
{
	frequency: s64 = ---; QueryPerformanceFrequency(*frequency);
	
	qpc_begin: s64 = ---; QueryPerformanceCounter(*qpc_begin);
	tsc_begin:= rdtsc();
	Sleep(2);
	qpc_end: s64 = ---; QueryPerformanceCounter(*qpc_end);
	tsc_end:= rdtsc();
	
	tsc_freq := (tsc_end - tsc_begin) * xx frequency / xx (qpc_end - qpc_begin);
	return tsc_freq;
}

ProfileState :: struct
{
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