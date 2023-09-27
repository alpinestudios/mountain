main :: ()
{
	output_dir := "C:/rando/dev/mountain/proj/arcane/res/tex/_blender";
	input_dir := "C:/Users/randy/Desktop/blender_export";
	
	push_allocator(temp);
	defer reset_temporary_storage();
	
	// args := get_command_line_arguments();
	
 visitor :: (info: *File_Visit_Info, user_data: *[..] string)
 {
  array_add(user_data, copy_string(info.full_name));
 }
 
 subjects : [..] string;
 visit_files(input_dir, false, *subjects, visitor, visit_files=false, visit_directories=true);
	
	for subject_path : subjects
	{
		subject_name := path_filename(subject_path);
		log("parsing subject: %", subject_name);
		
		animations : [..] string;
 	visit_files(subject_path, false, *animations, visitor, visit_files=false, visit_directories=true);
 	
 	for anim_path : animations
 	{
 		anim_name := path_filename(anim_path);
 		// log("%", anim_name);
 		
			frame_visitor :: (info: *File_Visit_Info, user_data: *[..] string)
			{
				if path_extension(info.full_name) == "png" then array_add(user_data, copy_string(info.full_name));
			}
			frame_files: [..]string;
			visit_files(anim_path, false, *frame_files, frame_visitor);
 		
 		// they should already be sorted by name, but just in case...
 		quick_sort(frame_files, x => (parse_int(*path_filename(x))));
 		
 		bitmaps : [..]Bitmap;
 		
 		width: s32;
 		height: s32;
 		for file_path : frame_files
 		{
 			// log(file_path);
 			// now that we've got the files, time to LOAD ER UP BAYBEEEEEE
 			bitmap : Bitmap;
 			bitmap_load(*bitmap, file_path);
 			
 			// check to make sure it's not a duplicate frame
 			// note - just gonna skip this for now since I cbf parsing metadata
 			// if bitmaps.count
 			// {
 			// 	last_keyframe_data := bitmaps[bitmaps.count-1].data;
 			// 	if memcmp(last_keyframe_data.data, bitmap.data.data, bitmap.data.count) == 0 then continue;
 			// }
 			
 			array_add(*bitmaps, bitmap);
 			
 			if it_index == 0
 			{
 				width = bitmap.width;
 				height = bitmap.height;
 			}
 			assert(bitmap.width == width && bitmap.height == height, "No support for variable sizes");
 		}
 		
 		combined_width :s32= width * xx bitmaps.count;
 		
 		output_bmp : Bitmap;
 		bitmap_alloc(*output_bmp, combined_width, height, bitmaps[0].format);
 		
 		// log("%, %", output_bmp.width, output_bmp.height);
 		
 		px_bytes := get_image_bytes_per_texel(output_bmp.format);
 		
 		for bmp, bmp_index : bitmaps
 			for x : 0..width-1
 				for y : 0..height-1
 				{
 					px_start := px_bytes * (width * bmp_index + x + combined_width * y);
 					for 0..px_bytes-1 // RGBA
 						output_bmp.data[px_start + it] = bmp.data[px_bytes * (x + y * width) + it];
 				}
			
			output_file := tprint("%/%_%.png", output_dir, subject_name, anim_name);
			if bitmap_save(*output_bmp, output_file)
			{
				log("exported: %", output_file);
			}
			else
			{
				assert(false, "Failed to output %", output_file);
			}
 	}
	}
}

#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";
#import "Sort";

#import "stb_image";
#import "stb_image_write";
#import "stb_image_resize";
// I have no idea how tf to not get these be a relative path
#load "../../external/Simp/bitmap.jai";
#load "../../external/Simp/texture_format.jai";