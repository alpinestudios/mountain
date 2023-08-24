/*
key:
@stability - needs patching for better shipping stability
@bounty - shit that would be nice to figure out, but I don't have the expertise / time for it

*/

#import "Basic";
#import "Compiler";

// https://github.com/Ivo-Balbaert/The_Way_to_Jai/blob/main/book/30_Integrated_build_system.md#304-the-build-options
build :: ()
{
	set_build_options_dc(.{do_output=false, write_added_strings=false}); // dc, during compile == this build workspace
	
	// ARCANE CLIENT
	if false
	{
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
		array_add(*import_path, tprint("../../modules/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		add_build_file("arcane.jai", w);
	}
	
	// TEST
	{
		Steam :: #import,file "../../modules/Steam/module.jai"(building=true);
		
		w := compiler_create_workspace("client");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "client";
		options.backend = .X64;
		options.use_natvis_compatible_types = true;
		options.text_output_flags = .OUTPUT_TIMING_INFO;
		
		import_path: [..] string;
		array_add(*import_path, ..options.import_path);
		array_add(*import_path, tprint("../../modules/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		compiler_begin_intercept(w);
		
		add_build_file("client.jai", w);
		
		while true
		{
			message := compiler_wait_for_message();
			if !message continue;
			if message.workspace != w continue;
			if message.kind == .COMPLETE break;

			Steam.steam_build_step(message);
		}
		
		compiler_end_intercept(w);
	}
	
	// SERVER
	// if false
	{
		Steam :: #import,file "../../modules/Steam/module.jai"(building=true);
		
		w := compiler_create_workspace("server");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "server";
		options.backend = .X64;
		options.use_natvis_compatible_types = true;
		options.text_output_flags = .OUTPUT_TIMING_INFO;
		
		import_path: [..] string;
		array_add(*import_path, ..options.import_path);
		array_add(*import_path, tprint("../../modules/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		// compiler_begin_intercept(w);
		
		add_build_file("server.jai", w);
		
		// while true
		// {
		// 	message := compiler_wait_for_message();
		// 	if !message continue;
		// 	if message.workspace != w continue;
		// 	if message.kind == .COMPLETE break;

		// 	Steam.steam_build_step(message);
		// }
		
		// compiler_end_intercept(w);
	}
}

#run build();