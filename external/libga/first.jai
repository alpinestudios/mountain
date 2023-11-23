 
#run build();

build :: ()
{

/*
    status := build_cpp_dynamic_lib("libga", "ga.cpp", extra=.["-std=c++11"], library_files=.["Ws2_32.lib", "./windows/GameAnalytics.lib", "./windows/libcurl.lib", "./windows/libeay32.lib", "./windows/ssleay32.lib"], debug=false);
    if !status
    {
        compiler_set_workspace_status(.FAILED);
    }
    */

	if !generate_bindings()
    {
        compiler_set_workspace_status(.FAILED);
    }
}

generate_bindings :: () -> bool {
    output_filename: string;
    opts: Generate_Bindings_Options;
    {
        using opts;

        #if OS == .WINDOWS {
            output_filename          = "windows.jai";
            strip_flags = 0;
        } else #if OS == .LINUX {
            output_filename          = "linux.jai";
            strip_flags = .INLINED_FUNCTIONS; // Inlined constructor doesn't exist in the library
        } else #if OS == .MACOS {
            output_filename          = "macos.jai";
            strip_flags = .INLINED_FUNCTIONS; // Inlined constructor doesn't exist in the library
        } else {
            assert(false);
        }

        array_add(*libpaths,       ".");
        array_add(*libnames,      "libga");
        array_add(*source_files,  "ga.hpp");
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN");

        // strip_flags &= ~(Strip_Flags.CONSTRUCTORS | .DESTRUCTORS);
    }

    return generate_bindings(opts, output_filename);
}

#scope_file

#import "Basic";
#import "Compiler";
#import "BuildCpp";
#import "Check";
#import "Bindings_Generator";
#import "File";
