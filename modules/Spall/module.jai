REBUILD :: false;
#if REBUILD
{
	
#import "BuildCpp";
#import "Basic";
#run {
	print("Building dynamic library:\n");
	build_cpp_dynamic_lib("../../modules/Spall/spall", "../../modules/Spall/spall.c");

	print("Building static library:\n");
	build_cpp_static_lib("../../modules/Spall/spall", "../../modules/Spall/spall.c");

	//set_build_options_dc(.{do_output = false});
};

} else {

spall :: #library "spall";

SpallProfile :: struct
{
	timestamp_unit: float64;
	is_json: bool;
	write: *void; // these are funciton ptrs
	flush: *void;
	close: *void;
	data: *void;
}

SpallBuffer :: struct
{
 data: *void;
 length: s64;
 // Internal data - don't assign this
 head: s64;
 ctx: *SpallProfile;
}

spall_init_file :: (filename: *u8, timestamp_unit: float64) -> SpallProfile #foreign spall;

// bool spall_buffer_init(SpallProfile *ctx, SpallBuffer *wb)
spall_buffer_init :: (ctx : *SpallProfile, wb: *SpallBuffer) -> bool #foreign spall;
// bool spall_buffer_begin(SpallProfile *ctx, SpallBuffer *wb, const char *name, signed long name_len, double when)
spall_buffer_begin :: (ctx: *SpallProfile, wb: *SpallBuffer, name: *u8, name_len: s32, when: float64) -> bool #foreign spall;
// bool spall_buffer_end(SpallProfile *ctx, SpallBuffer *wb, double when)
spall_buffer_end :: (ctx: *SpallProfile, wb: *SpallBuffer, when: float64) -> bool #foreign spall;
// bool spall_buffer_quit(SpallProfile *ctx, SpallBuffer *wb)
spall_buffer_quit :: (ctx: *SpallProfile, wb: *SpallBuffer) -> bool #foreign spall;
// spall_quit(SpallProfile *ctx)
spall_quit :: (ctx: *SpallProfile) #foreign spall;

}