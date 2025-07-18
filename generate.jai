AT_COMPILE_TIME :: true;

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args, options.minimum_os_version) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings(get_command_line_arguments(), #run get_build_options().minimum_os_version) {
            exit(1);
        }
    }
}

generate_bindings :: (args: [] string, minimum_os_version: type_of(Build_Options.minimum_os_version)) -> bool {
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");

    SOURCE_PATH   :: "source";
    LIB_BASE_NAME :: "stb_truetype";

    #if OS == {
        case .WINDOWS;
            lib_directory   := "windows";
            output_filename := "windows.jai";
        case .MACOS;
            lib_directory   := "macos";
            output_filename := "macos.jai";
        case .LINUX;
            lib_directory   := "linux";
            output_filename := "linux.jai";
        case;
            assert(false);
    }

    if compile {
        source_file := tprint("%/stb_truetype.c", SOURCE_PATH);

        make_directory_if_it_does_not_exist(lib_directory, recursive = true);
        lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);
        success := true;

        if OS == .MACOS {
            lib_path_x64   := tprint("%_x64", lib_path);
            lib_path_arm64 := tprint("%_arm64", lib_path);

            macos_x64_version_arg   := "-mmacos-version-min=10.13"; // Our current x64 min version
            macos_arm64_version_arg := "-mmacos-version-min=11.0";  // Earliest version that supports arm64

            // x64 variant
            success &&= build_cpp_dynamic_lib(lib_path_x64,   source_file, extra = .["-arch", "x86_64", macos_x64_version_arg],   debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_x64,   source_file, extra = .["-arch", "x86_64", macos_x64_version_arg],   debug=compile_debug);

            // arm64 variant
            success &&= build_cpp_dynamic_lib(lib_path_arm64, source_file, extra = .["-arch", "arm64",  macos_arm64_version_arg], debug=compile_debug);
            success &&= build_cpp_static_lib( lib_path_arm64, source_file, extra = .["-arch", "arm64",  macos_arm64_version_arg], debug=compile_debug);

            // create universal binaries
            run_result := run_command("lipo", "-create", tprint("%.dylib", lib_path_x64), tprint("%.dylib", lib_path_arm64), "-output", tprint("%.dylib", lib_path));
            success &&= (run_result.exit_code == 0);

            run_result  = run_command("lipo", "-create", tprint("%.a",     lib_path_x64), tprint("%.a",     lib_path_arm64), "-output", tprint("%.a",     lib_path));
            success &&= (run_result.exit_code == 0);
        } else {
            extra: [..] string;
            array_add(*extra, "-fPIC");
            success &&= build_cpp_dynamic_lib(lib_path, source_file, target = OS, debug = compile_debug, extra = extra);
            success &&= build_cpp_static_lib(lib_path, source_file, target = OS, debug = compile_debug, extra = extra);
        }

        if !success return false;
    }

    using options: Generate_Bindings_Options;

    os  = OS;
    cpu = CPU;

    array_add(*library_search_paths, lib_directory);
    array_add(*libraries, .{filename=LIB_BASE_NAME});
    array_add(*source_files, tprint("%/stb_truetype.h", SOURCE_PATH));
    array_add(*typedef_prefixes_to_unwrap, "stbtt_");

    generate_library_declarations = false;
    footer = tprint("%2 :: #library \"%1/%2\";", lib_directory, LIB_BASE_NAME);

    auto_detect_enum_prefixes = true;
    log_stripped_declarations = false;
    generate_compile_time_struct_checks = false;

    return generate_bindings(options, output_filename);
}

#import "Basic";
#import "Bindings_Generator";
#import "BuildCpp";
#import "Compiler";
#import "File";
#import "Process";
