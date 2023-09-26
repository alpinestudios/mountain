main :: ()
{
	output_dir := "C:/rando/dev/mountain/proj/arcane/res/tex/_blender/";
	input_dir := "C:/Users/randy/Desktop/blender_export/";
	
	// args := get_command_line_arguments();
	
	log("ligma");
	
	files: []string;
	files = file_list(input_dir, recursive=true);
	for files
	{
		name := path_filename(it);
		log("%", name);
	}
	
	assert(false);
}

#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";