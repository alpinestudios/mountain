build :: ()
{
	set_build_options_dc(.{do_output=false, write_added_strings=false}); // dc, during compile == this build workspace
	
	build_options := get_build_options();
	args := build_options.compile_time_command_line;
	
	is_release := false;
	for args if contains(it, "release") then is_release = true;
	
	if args.count > 0
	{
		log("%", args);
		log("building release: %", is_release);
	}
	
	// build arcane
	{
		w := compiler_create_workspace("sheet");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "sheet";
		
		if is_release
		{
			options.output_path = "release/";
			options.backend = .LLVM;
			set_optimization(*options, .VERY_OPTIMIZED, preserve_debug_info=true);
		}
		else
		{
			options.backend = .X64;
			options.use_natvis_compatible_types = true;
			options.text_output_flags = .OUTPUT_TIMING_INFO;
			options.output_path = "";
			set_optimization(*options, .DEBUG);
		}
		
		import_path: [..] string;
		array_add(*import_path, tprint("../../external/")); // overrides the default modules
		array_add(*import_path, ..options.import_path);
		array_add(*import_path, tprint("../../recycle/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		add_build_file("main.jai", w);
	}
}
#run build();

#import "String";
#import "Basic";
#import "Compiler";