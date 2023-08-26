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
        window_title = "Quad - LearnOpenGL"
    };

    sapp_run(*desc);
}

init :: () {
    desc: sg_desc;
    desc._context = sapp_sgcontext();
    sg_setup(*desc);

    shd := sg_make_shader(*simple_shader_desc());

    vertices := float.[
         0.5,  0.5, 0.0, // Top right
         0.5, -0.5, 0.0, // Bottom right
        -0.5, -0.5, 0.0, // Bottom left
        -0.5,  0.5, 0.0, // Top left
    ];

    {
        range: sg_range;
        range.ptr  = vertices.data;
        range.size = vertices.count * size_of(float);

        desc: sg_buffer_desc;
        desc.data  = range;
        desc.label = "quad-vertices";

        state.bindings.vertex_buffers[0] = sg_make_buffer(*desc);
    }

    {
        indices := u16.[
            0, 1, 3, // First triangle
            1, 2, 3  // Second triangle
        ];

        range: sg_range;
        range.ptr  = indices.data;
        range.size = indices.count * size_of(u16);

        desc: sg_buffer_desc;
        desc.type  = .INDEXBUFFER;
        desc.data  = range;
        desc.label = "quad-indices";

        state.bindings.index_buffer = sg_make_buffer(*desc);
    }

    {
        desc: sg_pipeline_desc;
        desc.shader     = shd;
        desc.index_type = .UINT16;
        desc.label      = "quad-pipeline";

        desc.layout = .{
            attrs[0].format = .FLOAT3,
        };

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
    sg_draw(0, 6, 1);
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
