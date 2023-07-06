c_context: Context;

state: struct {
    pass_action: sg_pass_action;
} = .{
    pass_action = .{
        colors[0] = .{
            action = .CLEAR,
            value  = .{ 0.0, 0.125, 0.25, 1.0 },
        },
    },
};

init :: () {
    {
        desc: sg_desc;
        desc._context = sapp_sgcontext();
        sg_setup(*desc);
    }

    {
        desc := sdtx_desc_with_all_fonts();
        sdtx_setup(*desc);
    }
}

frame :: () {
    sdtx_canvas(sapp_width() * 0.5, sapp_height() * 0.5);
    sdtx_origin(0, 2);
    sdtx_home();

    print_font(FONT_KC853, "KC85/3:\n",      0xf4, 0x43, 0x36);
    print_font(FONT_KC854, "KC85/4:\n",      0x21, 0x96, 0xf3);
    print_font(FONT_Z1013, "Z1013:\n",       0x4c, 0xaf, 0x50);
    print_font(FONT_CPC,   "Amstrad CPC:\n", 0xff, 0xeb, 0x3b);
    print_font(FONT_C64,   "C64:\n",         0x79, 0x86, 0xcb);
    print_font(FONT_ORIC,  "Oric Atmos:\n",  0xff, 0x98, 0x00);

    sg_begin_default_pass(*state.pass_action, sapp_width(), sapp_height());
    sdtx_draw();
    sg_end_pass();
    sg_commit();

    reset_temporary_storage();
}

cleanup :: () {
    sdtx_shutdown();
    sg_shutdown();
}

print_font :: (font_index: int, title: string, r: u8, g: u8, b: u8) {
    sdtx_font(xx font_index);
    sdtx_color3b(r, g, b);

    sdtx_puts(temp_c_string(title));

    for 32..255 {
        sdtx_putc(xx it);

        if ((it + 1) & 63) == 0 {
            sdtx_crlf();
        }
    }

    sdtx_crlf();
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
