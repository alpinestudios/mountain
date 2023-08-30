#import "Basic";
#import "File";
#import "String";

#import "Windows";
#import "d3d_compiler";

DEBUG :: true;

main :: ()
{
	args := get_command_line_arguments();
	path := args[1];
	shader_text, success := read_entire_file(path);
	if !success
	{
		log("Failed to read %", path);
		return;
	}
	log("Compiling %", path);

	hr : HRESULT;
	vs : string;
	vs, hr = CompileShader(shader_text, path_filename(path), "quad_vs", "vs_4_0");
	if FAILED(hr)
	{
		log("Failed to compile vs");
		return;
	}
	// dump bytecode
	vs_path := sprint("%vs", path_strip_filename(path));
	if !write_entire_file(vs_path, vs)
	{
		log("Failed to write bytecode");
		return;
	}
	log("VS compiled to %", vs_path);
	
	ps : string;
	ps, hr = CompileShader(shader_text, path_filename(path), "quad_ps", "ps_4_0");
	if FAILED(hr)
	{
		log("Failed to compile ps");
		return;
	}
	// dump bytecode
	ps_path := sprint("%ps", path_strip_filename(path));
	if !write_entire_file(ps_path, ps)
	{
		log("Failed to write bytecode");
		return;
	}
	log("PS compiled to %", ps_path);
	
	return;
}

CompileShader :: (source: string, file_name: string, entry_point: string, shader_model: string) -> string, HRESULT {
	flags := D3DCOMPILE.ENABLE_STRICTNESS; 

	#if DEBUG {
		// Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders. 
		// Setting this flag improves the shader debugging experience, but still allows  
		// the shaders to be optimized and to run exactly the way they will run in  
		// the release configuration of this program. 
		flags |= .DEBUG; 
		
		// Disable optimizations to further improve shader debugging 
		flags |= .SKIP_OPTIMIZATION; 
	}
	
	defines: [] string;
	bytecode, errors, hr := D3DCompile(source, file_name, defines, null, entry_point, shader_model, xx flags, 0);
	defer free(errors);

	if FAILED(hr) { 
		free(bytecode);
		if errors print ("\n%\n", errors);
		return "", hr;
	} 
	
	return bytecode, hr;
}