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

spall_init_file :: (filename: *u8, timestamp_unit: float64) -> SpallProfile #foreign spall;

// TODO - cont
// https://github.com/colrdavidson/spall-web/blob/master/examples/manual_tracing/simple_benchmark.c

}