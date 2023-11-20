/*

current build cmd:
jai build.jai -import_dir external

idk how to get rid of the manual import of external/

release + profile build cmd:
jai build.jai -import_dir external - release prof

*/

ENABLE_TRACY :: false;

plugins: [..] *Metaprogram_Plugin;

build :: ()
{
	set_build_options_dc(.{do_output=false, write_added_strings=false}); // dc, during compile == this build workspace
	
	build_options := get_build_options();
	args := build_options.compile_time_command_line;
	
	is_release := false;
	for args if contains(it, "release") then is_release = true;
	
	// idk how to get rid of the -import "external" requirement, since we need it right now...
	
	if args.count > 0
	{
		log("%", args);
		log("building release: %", is_release);
	}
	
	// build arcane
	{
		w := compiler_create_workspace("arcane");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		plugin_names : [..]string;
		// if profile_performance then array_add(*plugin_names, "tracy");
		array_add(*plugin_names, "Check");
		
		init_plugins(plugin_names, *plugins, w);
		
		// manually add tracy plugin, because I (Stef) couldn't figure out how to properly pass the 'instrument_modules' option through the cmd args
		#if ENABLE_TRACY
		{
			tracyPlugin := cast(*Tracy.My_Plugin)Tracy.get_plugin();
			tracyPlugin.workspace = w;
			tracyPlugin.instrument_modules = false;
			array_add(*plugins, tracyPlugin);
		}
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "arcane";
		
		if is_release
		{
			options.output_path = "proj/arcane/release/";
			options.backend = .LLVM;
			set_optimization(*options, .VERY_OPTIMIZED, preserve_debug_info=true);
			
			// always keep these on?
			// I think these are more for the debug symbols instead of actually doing anything meaningful crash-wise when shipping.
			// options.array_bounds_check = .ON;
	  // options.cast_bounds_check  = .FATAL;
	  // options.null_pointer_check = .ON;
		}
		else
		{
			options.backend = .X64;
			options.enable_bytecode_inliner = false; // disabled this to stop inlining in debug
			options.use_natvis_compatible_types = true;
			options.text_output_flags = .OUTPUT_TIMING_INFO;
			options.output_path = "proj/arcane/";
			set_optimization(*options, .DEBUG);
		}
		
		import_path: [..] string;
		array_add(*import_path, tprint("external/")); // overrides the default modules
		array_add(*import_path, ..options.import_path);
		array_add(*import_path, tprint("recycle/"));
		options.import_path = import_path;
		
		set_build_options(options, w);
		
		intercept_flags: Intercept_Flags;
		for plugins if it.before_intercept it.before_intercept(it, *intercept_flags);
		
		compiler_begin_intercept(w, intercept_flags);
		
		for plugins if it.add_source it.add_source(it);
		
		add_build_string(tprint("RELEASE :: %;", is_release), w);
		
		add_build_string(tprint("ENABLE_TRACY :: %;", ifx ENABLE_TRACY then "true" else "false"), w);
		add_build_file("proj/arcane/src/arcane.jai", w);
		
		message_loop(w);
		
		compiler_end_intercept(w);
		
		for plugins if it.finish   it.finish  (it);
  		for plugins if it.shutdown it.shutdown(it);
	}
}
#run build();

message_loop :: (w: Workspace)
{
 while true
 {
 	// We ask the compiler for the next message. If one is not available,
 	// we will wait until it becomes available.
 	message := compiler_wait_for_message();
 	// Pass the message to all plugins.
 	for plugins if it.message it.message(it, message);

 	if message.kind == .COMPLETE break;
 }
}

#import "File";
#import "Metaprogram_Plugins";
#import "String";
#import "Basic";
#import "Compiler";
#import "File_Utilities";
#if ENABLE_TRACY then Tracy :: #import "tracy"(.METAPROGRAM);