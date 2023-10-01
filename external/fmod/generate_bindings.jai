#import "Basic";
#import "Compiler";
#import "String";
#import "Bindings_Generator";

// PATH_SDK :: "C:/Program Files/FMOD/Studio API Windows/api";
PATH_SDK :: "2.02.10";

#run {
    set_build_options_dc(.{do_output = false});
    
    output_filename: string;
    options: Generate_Bindings_Options;
    {
        using options;

        #if OS == .WINDOWS {
            output_filename          = "fmod_windows.jai";
        } else {
            assert(false);
        }

        // binaries
        array_add(*libpaths
            , join(PATH_SDK, "/studio/lib/x64")
            , join(PATH_SDK, "/fsbank/lib/x64")
            , join(PATH_SDK, "/core/lib/x64")
            );
        array_add(*libnames
            , "fmodstudio"
            , "fsbank"
            , "fmod"
        );
        
        // source files
        array_add(*include_paths, join(PATH_SDK, "/studio/inc"));
        array_add(*include_paths, join(PATH_SDK, "/core/inc"));
        array_add(*source_files
            , "fmod_studio.h"
        );
        
        // array_add(*strip_prefixes, "FMOD");
        array_add(*generate_enums_from_macros_with_prefixes
            , "FMOD_DEBUG_LEVEL"
            , "FMOD_DEBUG_TYPE"
            , "FMOD_DEBUG_DISPLAY"
            , "FMOD_MEMORY"
            , "FMOD_INIT"
            // , "FMOD_DRIVER_STATE"
            // , "FMOD_TIMEUNIT"
            // , "FMOD_SYSTEM_CALLBACK"
            // , "FMOD_CHANNELMASK"
            // , "FMOD_THREAD_PRIORITY"
            // , "FMOD_THREAD_STACK_SIZE"
            // , "FMOD_THREAD_AFFINITY"
            // , "FMOD_CODEC_SEEK_METHOD"
            , "FMOD_STUDIO_INIT"
            , "FMOD_STUDIO_PARAMETER"
            // , "FMOD_STUDIO_SYSTEM_CALLBACK"
            // , "FMOD_STUDIO_EVENT_CALLBACK"
            , "FMOD_STUDIO_LOAD_BANK"
            , "FMOD_STUDIO_COMMANDCAPTURE"
            // , "FMOD_STUDIO_COMMANDREPLAY"
            , "FMOD_LOOP"
        );
        
        array_add(*system_include_paths, GENERATOR_DEFAULT_SYSTEM_INCLUDE_PATH);
        array_add(*extra_clang_arguments, "-x", "c++");
        generate_compile_time_struct_checks = false;
        strip_flags = 0;
        // strip_flags &= ~(Strip_Flags.CONSTRUCTORS | .DESTRUCTORS);
    }
    
    // return generate_bindings(opts, output_filename);
    success := generate_bindings(options, output_filename, log_results = true);
    log("wwise binding gen %", ifx success then "success" else "failure");
}