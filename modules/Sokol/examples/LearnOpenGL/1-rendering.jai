c_context: Context;

state: struct {
    pass_action: sg_pass_action;
};

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
        event_cb = (e: *sapp_event) #c_call {
            push_context c_context { event(e); }
        },

        width =  800,
        height = 600,
        gl_force_gles2 = true,
        window_title = "Rendering - LearnOpenGL"
    };

    sapp_run(*desc);
}

init :: () {
    desc: sg_desc;
    desc._context = sapp_sgcontext();
    sg_setup(*desc);

    state.pass_action = .{
        colors[0] = .{
            action = .CLEAR,
            value  = .{ 0.2, 0.3, 0.3, 1.0 }
        }
    };
}

cleanup :: () {
    sg_shutdown();
}

frame :: () {
    sg_begin_default_pass(*state.pass_action, sapp_width(), sapp_height());
    sg_end_pass();
    sg_commit();
}

event :: (e: *sapp_event) {
    if e.type == .KEY_DOWN {
        if e.key_code == .KEYCODE_ESCAPE {
            sapp_request_quit();
        }
    }
}

#load "../../module.jai";
#import "Basic";
