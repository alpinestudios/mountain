plugins: [..] *Metaprogram_Plugin;

build :: ()
{
	set_build_options_dc(.{do_output=false, write_added_strings=false}); // dc, during compile == this build workspace
	
	#if BUILD_ARCANE
	{{
		w := compiler_create_workspace("arcane");
		if !w
		{
			log_error("Workspace creation failed.");
			return;
		}
		
		plugin_names : [..]string;
		array_add(*plugin_names, "Check");
		#if PROFILE_PERFORMANCE then array_add(*plugin_names, "tracy");
		
		init_plugins(plugin_names, *plugins, w);
		
		options : Build_Options = get_build_options(w);
		options.output_executable_name = "arcane";
		options.backend = .X64;
		options.use_natvis_compatible_types = true;
		options.text_output_flags = .OUTPUT_TIMING_INFO;
		options.output_path = "proj/arcane/";
		
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
		
		add_build_file("dev_config.jai", w);
		add_build_file("proj/arcane/src/arcane.jai", w);
		
		message_loop(w);
		
		compiler_end_intercept(w);
		
		for plugins if it.finish   it.finish  (it);
  for plugins if it.shutdown it.shutdown(it);
	}}
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

#load "dev_config.jai";

#import "Metaprogram_Plugins";
#import "String";
#import "Basic";
#import "Compiler";
#import "File_Utilities";