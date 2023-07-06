c_context: Context;

state: struct {
    pipeline    : sg_pipeline;
    bindings    : sg_bindings;
    pass_action : sg_pass_action;
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
        window_title = "Triangle - LearnOpenGL"
    };

    sapp_run(*desc);
}

init :: () {
    desc: sg_desc;
    desc._context = sapp_sgcontext();
    sg_setup(*desc);

    shd := sg_make_shader(*simple_shader_desc());

    vertices := float.[
        -0.5, -0.5, 0.0,
         0.5, -0.5, 0.0,
         0.0,  0.5, 0.0,
    ];

    {
        range: sg_range;
        range.ptr  = vertices.data;
        range.size = vertices.count * size_of(float);

        desc: sg_buffer_desc;
        desc.data  = range;
        desc.size  = range.size;
        desc.label = "triangle-vertices";

        state.bindings.vertex_buffers[0] = sg_make_buffer(*desc);
    }

    {
        layout: sg_layout_desc;
        layout.attrs[0].format = .FLOAT3;

        desc: sg_pipeline_desc;
        desc.shader = shd;
        desc.layout = layout;
        desc.label  = "triangle-pipeline";

        state.pipeline = sg_make_pipeline(*desc);
    }

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
    sg_apply_pipeline(state.pipeline);
    sg_apply_bindings(*state.bindings);
    sg_draw(0, 3, 1);
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
#load "simple_shader.jai";

#import "Basic";
