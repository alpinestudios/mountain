
// load the user file
// See no_commit_default.jai for more info!
#if #run file_exists("users/no_commit.jai")
{
	USER_FILE :: "users/no_commit.jai";
	#load "users/no_commit.jai";
}
else
{
	#run log("No local user-file found at users/no_commit.jai, using default.");
	USER_FILE :: "users/no_commit_default.jai";
	#load "users/no_commit_default.jai";
}


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
		
		add_build_file(USER_FILE, w);
		add_build_file("proj/arcane/src/arcane.jai", w);
	}}
}
#run build();

#import "Basic";
#import "Compiler";
#import "File_Utilities";

//#import,file "external/Runtime_Support.jai"(ENABLE_BACKTRACE_ON_CRASH=true);