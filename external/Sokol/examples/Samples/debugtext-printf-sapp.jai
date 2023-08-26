c_context: Context;

state: struct {
    pass_action : sg_pass_action;
    frame_count : u64;
    time_stamp  : u64;
    palette     : [6]sg_color;
} = .{
    pass_action = .{
        colors[0] = .{
            action = .CLEAR,
            value  = .{ 0.0, 0.125, 0.25, 1.0 },
        },
    },
};

init :: () {
    stm_setup();
    
    {
        desc: sg_desc;
        desc._context = sapp_sgcontext();
        sg_setup(*desc);
    }

    {
        desc := sdtx_desc_with_all_fonts();
        sdtx_setup(*desc);
    }

    state.palette[0] = sg_make_color_4b(0xF4, 0x43, 0x36, 0xFF);
    state.palette[1] = sg_make_color_4b(0x21, 0x96, 0xF3, 0xFF);
    state.palette[2] = sg_make_color_4b(0x4C, 0xAF, 0x50, 0xFF);
    state.palette[3] = SG_SIENNA;
    state.palette[4] = SG_DARK_ORCHID;
    state.palette[5] = SG_OLD_LACE;
}

format :: (format_string: string, args: ..Any) -> *u8 {
    return temp_c_string(tprint(format_string, ..args));
}

frame :: () {
    frame_time := stm_ms(stm_laptime(*state.time_stamp));

    sdtx_canvas(sapp_width() * 0.5, sapp_height() * 0.5);
    sdtx_origin(3, 3);

    for 0..state.palette.count - 1 {
        color := state.palette[it];
        sdtx_font(xx it);
        sdtx_color3f(color.r, color.g, color.b);

        {
            value := "World";
            if state.frame_count & (1 << 7) value = "Welt";
            sdtx_puts(format("Hello, '%'\n", value));
        }

        sdtx_puts(format("\tFrame Time:\t\t%\n", frame_time));
        sdtx_puts(format("\tFrame Count:\t%1\t%1\n", state.frame_count));

        sdtx_putr("Range Test 1(xyzbla)", 12);
        sdtx_putr("\nRange Test 2\n", 32);

        sdtx_move_y(2);
    }

    sg_begin_default_pass(*state.pass_action, sapp_width(), sapp_height());
    sdtx_draw();
    sg_end_pass();
    sg_commit();

    state.frame_count += 1;
    reset_temporary_storage();
}

cleanup :: () {
    sdtx_shutdown();
    sg_shutdown();
}

main :: () {
    desc := sapp_desc.{
        init_cb = () #c_call {
            push_context c_context { init(); }
        },
        frame_cb = () #c_call {
            push_context c_context { frame(); }
        },
        cleanup_cb = () #c_call {
            push_context c_context { cleanup(); }
        },

        width =  1024,
        height = 600,
        gl_force_gles2 = true,
        window_title = "Sample - DebugText",
    };

    sapp_run(*desc);
}


#load "../../module.jai";

#import "Math";
#import "Basic";
