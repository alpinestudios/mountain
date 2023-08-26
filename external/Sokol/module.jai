#scope_export;
Sokol_Modules :: enum_flags {
    App;
    Gfx;
    Time;
    Audio;
    Color;
    DebugText;
}

#module_parameters(modules := Sokol_Modules.App | .Gfx | .Time | .Audio | .Color | .DebugText);

#scope_module;
#if modules & .App       #load "sokol_app.jai";
#if modules & .Time      #load "sokol_time.jai";
#if modules & .Audio     #load "sokol_audio.jai";
#if modules & .DebugText #load "sokol_debugtext.jai";
#if modules & .Color     #load "sokol_color.jai";

#if modules & .Gfx {
    #load "sokol_gfx.jai";

    #if modules & .App {
        sapp_sgcontext :: () -> sg_context_desc {
            desc: sg_context_desc;

            {
                using desc;
                color_format                   = xx sapp_color_format();
                depth_format                   = xx sapp_depth_format();
                sample_count                   = sapp_sample_count();
                gl.force_gles2                 = sapp_gles2();
                metal.device                   = sapp_metal_get_device();
                metal.renderpass_descriptor_cb = sapp_metal_get_renderpass_descriptor;
                metal.drawable_cb              = sapp_metal_get_drawable;
                d3d11.device                   = sapp_d3d11_get_device();
                d3d11.device_context           = sapp_d3d11_get_device_context();
                d3d11.render_target_view_cb    = sapp_d3d11_get_render_target_view;
                d3d11.depth_stencil_view_cb    = sapp_d3d11_get_depth_stencil_view;
                wgpu.device                    = sapp_wgpu_get_device();
                wgpu.render_view_cb            = sapp_wgpu_get_render_view;
                wgpu.resolve_view_cb           = sapp_wgpu_get_resolve_view;
                wgpu.depth_stencil_view_cb     = sapp_wgpu_get_depth_stencil_view;
            }

            return desc;
        }
    }
}

#load "c.jai";
