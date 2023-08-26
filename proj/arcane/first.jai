/*

key:
@stability - needs patching for better shipping stability
@bounty - shit that would be nice to figure out, but I don't have the expertise / time for it

*/

ARCANE :: false;
TEST_CLIENT :: true;
DEDICATED_SERVER :: true;

build :: ()
{
	set_build_options_dc(.{do_output=false, write_added_strings=false}); // dc, during compile == this build workspace
	
	#if ARCANE
	{{
		w := compiler_create_workspace("arcane");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "arcane";
		options.backend = .X64;
		options.use_natvis_compatible_types = true;
		options.text_output_flags = .OUTPUT_TIMING_INFO;
		
		import_path: [..] string;
		array_add(*import_path, ..options.import_path);
		array_add(*import_path, tprint("../../external/"));
		array_add(*import_path, tprint("../../recycle/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		add_build_file("arcane.jai", w);
	}}
	
	#if TEST_CLIENT
	{{
		w := compiler_create_workspace("arc_test");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "arc_test";
		options.backend = .X64;
		options.use_natvis_compatible_types = true;
		options.text_output_flags = .OUTPUT_TIMING_INFO;
		
		import_path: [..] string;
		array_add(*import_path, ..options.import_path);
		array_add(*import_path, tprint("../../external/"));
		array_add(*import_path, tprint("../../recycle/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		add_build_file("client.jai", w);
	}}
	
	#if DEDICATED_SERVER
	{{
		w := compiler_create_workspace("Dedicated Server");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "arc_server";
		options.backend = .X64;
		options.use_natvis_compatible_types = true;
		options.text_output_flags = .OUTPUT_TIMING_INFO;
		
		import_path: [..] string;
		array_add(*import_path, ..options.import_path);
		array_add(*import_path, tprint("../../external/"));
		array_add(*import_path, tprint("../../recycle/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		add_build_file("server.jai", w);
	}}
}

#run build();

#import "Basic";
#import "Compiler";