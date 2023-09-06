
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
		
		compiler_begin_intercept(w);
		add_build_file(USER_FILE, w);
		add_build_file("proj/arcane/src/arcane.jai", w);
		while true
		{
			msg := compiler_wait_for_message();
			if !msg then break;
			if msg.kind == 
			{
				// copypasted from https://github.com/rluba/jai-tracy/blob/master/instrument.jai#L52C1-L52C1
				case .TYPECHECKED;
				message_typechecked := cast(*Message_Typechecked) msg;
		  for * tc : message_typechecked.procedure_bodies
		  {
		  	body := tc.expression;
		  	if body.body_flags & .ALREADY_MODIFIED continue;
		  	
		  	h := body.header;
		  	assert(h != null);
		  	
		  	if h.procedure_flags & (h.procedure_flags.POLYMORPHIC | .COMPILER_GENERATED | .COMPILE_TIME | .QUICK | .TYPE_ONLY | .MACRO) continue;  // @Incomplete: Need maybe we want a user-generated compile_time flag; that would be different than this, which is to detect #compiler.

		  	file := body.enclosing_load;
		  	
		  	// only run this on our file
		  	if !contains(file.fully_pathed_filename, "arcane.jai")
		  	{
		  		continue;
		  	}
		  	
		  	if file && file.enclosing_import {
		  		import := file.enclosing_import;

		  		if import.module_type == {
		  			case .PRELOAD;         continue;
		  			case .RUNTIME_SUPPORT; continue;
		  			case .MAIN_PROGRAM;    // Always OK
		  			case;
		  			continue;
		  			// if !plugin.instrument_modules continue;
		  		}
		  	}
		  	
		  	// log("%", file.fully_pathed_filename);

		  	// @randy - I just used 30 as the minimum size default, idk what this means tho
		  	if tc.subexpressions.count < 30 continue; // Too small!
		  	// if plugin.should_instrument != null && !plugin.should_instrument(body) continue;

		  	for h.notes {
		  		if it.text == "NoProfile" {
		  			log("Skipping \"%\" due to NoProfile note.\n", h.name);
		  			continue;
		  		}
		  	}

		  	new_statements : [..] *Code_Node;

		  	array_reserve(*new_statements, body.block.statements.count + 1);
		  	array_add(*new_statements, compiler_get_nodes(HEADER));
		  	array_add(*new_statements, ..body.block.statements);

		  	body.block.statements = new_statements;

		  	// Submit the modify.
		  	// log("Replacing body of \"%\"", h.name);
		  	compiler_modify_procedure(msg.workspace, body);
		  }
		  
				case .COMPLETE;
				break;
			}
		}
		compiler_end_intercept(w);
	}}
}
#run build();

HEADER :: #code profile_block("");

// profile_block("")

#import,file "recycle/profile.jai";

#import "String";
#import "Basic";
#import "Compiler";
#import "File_Utilities";

//#import,file "external/Runtime_Support.jai"(ENABLE_BACKTRACE_ON_CRASH=true);

