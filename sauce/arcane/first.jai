/*
This'll be the hub for the project.

@stability - needs patching for better shipping stability

TODO:
- make this compile the project

*/

#import "Basic";
#import "Compiler";

build :: ()
{
	w := compiler_create_workspace("Arcane Build");
	if !w
	{
		log_error("Workspace creation failed.");
		return;
	}
	
	options : Build_Options = get_build_options(w);
	options.output_executable_name = "arcane";
	options.backend = .X64;
	options.use_natvis_compatible_types = true;
	
	import_path: [..] string;
 array_add(*import_path, ..options.import_path);
 array_add(*import_path, tprint("../../modules/"));
 options.import_path = import_path;
 
	set_build_options(options, w);
	
	add_build_file("main.jai", w);
	
	set_build_options_dc(.{do_output=false, write_added_strings=false}); // dc, during compile == this build workspace
}

#run build();