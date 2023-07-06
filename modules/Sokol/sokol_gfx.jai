SG_DEFAULT_CLEAR_RED     :: 0.5;
SG_DEFAULT_CLEAR_GREEN   :: 0.5;
SG_DEFAULT_CLEAR_BLUE    :: 0.5;
SG_DEFAULT_CLEAR_ALPHA   :: 1.0;
SG_DEFAULT_CLEAR_DEPTH   :: 1.0;
SG_DEFAULT_CLEAR_STENCIL :: 0;

SG_INVALID_ID              :: 0;
SG_NUM_SHADER_STAGES       :: 2;
SG_NUM_INFLIGHT_FRAMES     :: 2;
SG_MAX_COLOR_ATTACHMENTS   :: 4;
SG_MAX_SHADERSTAGE_BUFFERS :: 8;
SG_MAX_SHADERSTAGE_IMAGES  :: 12;
SG_MAX_SHADERSTAGE_UBS     :: 4;
SG_MAX_UB_MEMBERS          :: 16;
SG_MAX_VERTEX_ATTRIBUTES   :: 16; /* NOTE: actual max vertex attrs can be less on GLES2, see sg_limits! */
SG_MAX_MIPMAPS             :: 16;
SG_MAX_TEXTUREARRAY_LAYERS :: 128;

sg_buffer   :: struct { id: u32; }
sg_image    :: struct { id: u32; }
sg_shader   :: struct { id: u32; }
sg_pipeline :: struct { id: u32; }
sg_pass     :: struct { id: u32; }
sg_context  :: struct { id: u32; }

sg_range :: struct {
    ptr  : *void;
    size : s64;
}

sg_color :: struct { r, g, b, a: float32; }

sg_backend :: enum u32 {
    GLCORE33;
    GLES2;
    GLES3;
    D3D11;
    METAL_IOS;
    METAL_MACOS;
    METAL_SIMULATOR;
    WGPU;
    DUMMY;
}

sg_pixel_format :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    NONE;

    R8;
    R8SN;
    R8UI;
    R8SI;

    R16;
    R16SN;
    R16UI;
    R16SI;
    R16F;
    RG8;
    RG8SN;
    RG8UI;
    RG8SI;

    R32UI;
    R32SI;
    R32F;
    RG16;
    RG16SN;
    RG16UI;
    RG16SI;
    RG16F;
    RGBA8;
    RGBA8SN;
    RGBA8UI;
    RGBA8SI;
    BGRA8;
    RGB10A2;
    RG11B10F;

    RG32UI;
    RG32SI;
    RG32F;
    RGBA16;
    RGBA16SN;
    RGBA16UI;
    RGBA16SI;
    RGBA16F;

    RGBA32UI;
    RGBA32SI;
    RGBA32F;

    DEPTH;
    DEPTH_STENCIL;

    BC1_RGBA;
    BC2_RGBA;
    BC3_RGBA;
    BC4_R;
    BC4_RSN;
    BC5_RG;
    BC5_RGSN;
    BC6H_RGBF;
    BC6H_RGBUF;
    BC7_RGBA;
    PVRTC_RGB_2BPP;
    PVRTC_RGB_4BPP;
    PVRTC_RGBA_2BPP;
    PVRTC_RGBA_4BPP;
    ETC2_RGB8;
    ETC2_RGB8A1;
    ETC2_RGBA8;
    ETC2_RG11;
    ETC2_RG11SN;

    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_pixelformat_info :: struct {
    sample : bool; // pixel format can be sampled in shaders
    filter : bool; // pixel format can be sampled with filtering
    render : bool; // pixel format can be used as render target
    blend  : bool; // alpha-blending is supported
    msaa   : bool; // pixel format can be used as MSAA render target
    depth  : bool; // pixel format is a depth format
    // #if defined(SOKOL_ZIG_BINDINGS)
    // uint32_t __pad[3];
    // #endif
}

sg_features :: struct {
    instancing                  : bool; // hardware instancing supported
    origin_top_left             : bool; // framebuffer and texture origin is in top left corner
    multiple_render_targets     : bool; // offscreen render passes can have multiple render targets attached
    msaa_render_targets         : bool; // offscreen render passes support MSAA antialiasing
    imagetype_3d                : bool; // creation of SG_IMAGETYPE_3D images is supported
    imagetype_array             : bool; // creation of SG_IMAGETYPE_ARRAY images is supported
    image_clamp_to_border       : bool; // border color and clamp-to-border UV-wrap mode is supported
    mrt_independent_blend_state : bool; // multiple-render-target rendering can use per-render-target blend state
    mrt_independent_write_mask  : bool; // multiple-render-target rendering can use per-render-target color write masks
    // #if defined(SOKOL_ZIG_BINDINGS)
    // uint32_t __pad[3];
    // #endif
}

sg_limits :: struct {
    max_image_size_2d             : s32; // max width/height of SG_IMAGETYPE_2D images
    max_image_size_cube           : s32; // max width/height of SG_IMAGETYPE_CUBE images
    max_image_size_3d             : s32; // max width/height/depth of SG_IMAGETYPE_3D images
    max_image_size_array          : s32; // max width/height of SG_IMAGETYPE_ARRAY images
    max_image_array_layers        : s32; // max number of layers in SG_IMAGETYPE_ARRAY images
    max_vertex_attrs              : s32; // <= SG_MAX_VERTEX_ATTRIBUTES or less (on some GLES2 impls)
    gl_max_vertex_uniform_vectors : s32; // <= GL_MAX_VERTEX_UNIFORM_VECTORS (only on GL backends)
}

sg_resource_state :: enum u32 {
    INITIAL;
    ALLOC;
    VALID;
    FAILED;
    INVALID;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_usage :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    IMMUTABLE;
    DYNAMIC;
    STREAM;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_buffer_type :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    VERTEXBUFFER;
    INDEXBUFFER;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_index_type :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    NONE;
    UINT16;
    UINT32;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_image_type :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    _2D;
    CUBE;
    _3D;
    ARRAY;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_sampler_type :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    FLOAT;
    SINT;
    UINT;
}

sg_cube_face :: enum u32 {
    POS_X;
    NEG_X;
    POS_Y;
    NEG_Y;
    POS_Z;
    NEG_Z;
    _NUM;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_shader_stage :: enum u32 {
    VS;
    FS;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_primitive_type :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    POINTS;
    LINES;
    LINE_STRIP;
    TRIANGLES;
    TRIANGLE_STRIP;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_filter :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    NEAREST;
    LINEAR;
    NEAREST_MIPMAP_NEAREST;
    NEAREST_MIPMAP_LINEAR;
    LINEAR_MIPMAP_NEAREST;
    LINEAR_MIPMAP_LINEAR;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_wrap :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    REPEAT;
    CLAMP_TO_EDGE;
    CLAMP_TO_BORDER;
    MIRRORED_REPEAT;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_border_color :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    TRANSPARENT_BLACK;
    OPAQUE_BLACK;
    OPAQUE_WHITE;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_vertex_format :: enum u32 {
    INVALID;
    FLOAT;
    FLOAT2;
    FLOAT3;
    FLOAT4;
    BYTE4;
    BYTE4N;
    UBYTE4;
    UBYTE4N;
    SHORT2;
    SHORT2N;
    USHORT2N;
    SHORT4;
    SHORT4N;
    USHORT4N;
    UINT10_N2;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_vertex_step :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    PER_VERTEX;
    PER_INSTANCE;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_uniform_type :: enum u32 {
    INVALID;
    FLOAT;
    FLOAT2;
    FLOAT3;
    FLOAT4;
    MAT4;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_cull_mode :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    NONE;
    FRONT;
    BACK;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_face_winding :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    CCW;
    CW;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_compare_func :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    NEVER;
    LESS;
    EQUAL;
    LESS_EQUAL;
    GREATER;
    NOT_EQUAL;
    GREATER_EQUAL;
    ALWAYS;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_stencil_op :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    KEEP;
    ZERO;
    REPLACE;
    INCR_CLAMP;
    DECR_CLAMP;
    INVERT;
    INCR_WRAP;
    DECR_WRAP;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_blend_factor :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    ZERO;
    ONE;
    SRC_COLOR;
    ONE_MINUS_SRC_COLOR;
    SRC_ALPHA;
    ONE_MINUS_SRC_ALPHA;
    DST_COLOR;
    ONE_MINUS_DST_COLOR;
    DST_ALPHA;
    ONE_MINUS_DST_ALPHA;
    SRC_ALPHA_SATURATED;
    BLEND_COLOR;
    ONE_MINUS_BLEND_COLOR;
    BLEND_ALPHA;
    ONE_MINUS_BLEND_ALPHA;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_blend_op :: enum u32 {
    _DEFAULT; /* value 0 reserved for default-init */
    ADD;
    SUBTRACT;
    REVERSE_SUBTRACT;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_color_mask :: enum u32 {
    _DEFAULT   :: 0;     /* value 0 reserved for default-init */
    NONE       :: 0x10;  /* special value for 'all channels disabled */
    R          :: 0x1;
    G          :: 0x2;
    RG         :: 0x3;
    B          :: 0x4;
    RB         :: 0x5;
    GB         :: 0x6;
    RGB        :: 0x7;
    A          :: 0x8;
    RA         :: 0x9;
    GA         :: 0xA;
    RGA        :: 0xB;
    BA         :: 0xC;
    RBA        :: 0xD;
    GBA        :: 0xE;
    RGBA       :: 0xF;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_action :: enum u32 {
    _DEFAULT;
    CLEAR;
    LOAD;
    DONTCARE;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sg_color_attachment_action :: struct {
    action : sg_action;
    value  : sg_color;
}

sg_depth_attachment_action :: struct {
    action : sg_action;
    value  : float32;
}

sg_stencil_attachment_action :: struct {
    action : sg_action;
    value  : u8;
}

sg_pass_action :: struct {
    _start_canary : u32;
    colors        : [SG_MAX_COLOR_ATTACHMENTS]sg_color_attachment_action;
    depth         : sg_depth_attachment_action;
    stencil       : sg_stencil_attachment_action;
    _end_canary   : u32;
}

sg_bindings :: struct {
    _start_canary         : u32;
    vertex_buffers        : [SG_MAX_SHADERSTAGE_BUFFERS]sg_buffer;
    vertex_buffer_offsets : [SG_MAX_SHADERSTAGE_BUFFERS]s32;
    index_buffer          : sg_buffer;
    index_buffer_offset   : s32;
    vs_images             : [SG_MAX_SHADERSTAGE_IMAGES]sg_image;
    fs_images             : [SG_MAX_SHADERSTAGE_IMAGES]sg_image;
    _end_canary           : u32;
}

sg_buffer_desc :: struct {
    _start_canary : u32;
    size          : s64;
    type          : sg_buffer_type;
    usage         : sg_usage;
    data          : sg_range;
    label         : *u8;
    gl_buffers    : [SG_NUM_INFLIGHT_FRAMES]u32;   /* GL specific */
    mtl_buffers   : [SG_NUM_INFLIGHT_FRAMES]*void; /* Metal specific */
    d3d11_buffer  : *void;                         /* D3D11 specific */
    wgpu_buffer   : *void;                         /* WebGPU specific */
    _end_canary   : u32;
}

sg_image_data :: struct {
    // Might need to be defined as subimage: [sg_cube_face._NUM * SG_MAX_MIPMAPS]sg_range.
    subimage: [sg_cube_face._NUM][SG_MAX_MIPMAPS]sg_range;
}

sg_image_desc :: struct {
    _start_canary  : u32;
    type           : sg_image_type;
    render_target  : bool;
    width          : s32;
    height         : s32;
    num_slices     : s32;
    num_mipmaps    : s32;
    usage          : sg_usage;
    pixel_format   : sg_pixel_format;
    sample_count   : s32;
    min_filter     : sg_filter;
    mag_filter     : sg_filter;
    wrap_u         : sg_wrap;
    wrap_v         : sg_wrap;
    wrap_w         : sg_wrap;
    border_color   : sg_border_color;
    max_anisotropy : u32;
    min_lod        : float32;
    max_lod        : float32;
    data           : sg_image_data;
    label          : *u8;

    /* GL specific */
    gl_textures       : [SG_NUM_INFLIGHT_FRAMES]u32;
    gl_texture_target : u32;

    /* Metal specific */
    mtl_textures: [SG_NUM_INFLIGHT_FRAMES]*void;

    /* D3D11 specific */
    d3d11_texture              : *void;
    d3d11_shader_resource_view : *void;

    /* WebGPU specific */
    wgpu_texture : *void;
    _end_canary  : u32;
}

sg_shader_attr_desc :: struct {
    name      : *u8; // GLSL vertex attribute name (only strictly required for GLES2)
    sem_name  : *u8; // HLSL semantic name
    sem_index : s32; // HLSL semantic index
}

sg_shader_uniform_desc :: struct {
    name        : *u8;
    type        : sg_uniform_type;
    array_count : s32;
}

sg_shader_uniform_block_desc :: struct {
    size     : s64;
    uniforms : [SG_MAX_UB_MEMBERS]sg_shader_uniform_desc;
}

sg_shader_image_desc :: struct {
    name         : *u8;
    image_type   : sg_image_type;
    sampler_type : sg_sampler_type;
}

sg_shader_stage_desc :: struct {
    source         : *u8;
    bytecode       : sg_range;
    entry          : *u8;
    d3d11_target   : *u8;
    uniform_blocks : [SG_MAX_SHADERSTAGE_UBS]sg_shader_uniform_block_desc;
    images         : [SG_MAX_SHADERSTAGE_IMAGES]sg_shader_image_desc;
}

sg_shader_desc :: struct {
    _start_canary : u32;
    attrs         : [SG_MAX_VERTEX_ATTRIBUTES]sg_shader_attr_desc;
    vs            : sg_shader_stage_desc;
    fs            : sg_shader_stage_desc;
    label         : *u8;
    _end_canary   : u32;
}

sg_buffer_layout_desc :: struct {
    stride    : s32;
    step_func : sg_vertex_step;
    step_rate : s32;
    // #if defined(SOKOL_ZIG_BINDINGS)
    // uint32_t __pad[2];
    // #endif
}

sg_vertex_attr_desc :: struct {
    buffer_index : s32;
    offset       : s32;
    format       : sg_vertex_format;
    // #if defined(SOKOL_ZIG_BINDINGS)
    // uint32_t __pad[2];
    // #endif
}

sg_layout_desc :: struct {
    buffers : [SG_MAX_SHADERSTAGE_BUFFERS]sg_buffer_layout_desc;
    attrs   : [SG_MAX_VERTEX_ATTRIBUTES]sg_vertex_attr_desc;
}

sg_stencil_face_state :: struct {
    compare       : sg_compare_func;
    fail_op       : sg_stencil_op;
    depth_fail_op : sg_stencil_op;
    pass_op       : sg_stencil_op;
}

sg_stencil_state :: struct {
    enabled    : bool;
    front      : sg_stencil_face_state;
    back       : sg_stencil_face_state;
    read_mask  : u8;
    write_mask : u8;
    ref        : u8;
}

sg_depth_state :: struct {
    pixel_format     : sg_pixel_format;
    compare          : sg_compare_func;
    write_enabled    : bool;
    bias             : float32;
    bias_slope_scale : float32;
    bias_clamp       : float32;
}

sg_blend_state :: struct {
    enabled          : bool;
    src_factor_rgb   : sg_blend_factor;
    dst_factor_rgb   : sg_blend_factor;
    op_rgb           : sg_blend_op;
    src_factor_alpha : sg_blend_factor;
    dst_factor_alpha : sg_blend_factor;
    op_alpha         : sg_blend_op;
}

sg_color_state :: struct {
    pixel_format : sg_pixel_format;
    write_mask   : sg_color_mask;
    blend        : sg_blend_state;
}

sg_pipeline_desc :: struct {
    _start_canary             : u32;
    shader                    : sg_shader;
    layout                    : sg_layout_desc;
    depth                     : sg_depth_state;
    stencil                   : sg_stencil_state;
    color_count               : s32;
    colors                    : [SG_MAX_COLOR_ATTACHMENTS]sg_color_state;
    primitive_type            : sg_primitive_type;
    index_type                : sg_index_type;
    cull_mode                 : sg_cull_mode;
    face_winding              : sg_face_winding;
    sample_count              : s32;
    blend_color               : sg_color;
    alpha_to_coverage_enabled : bool;
    label                     : *u8;
    _end_canary               : u32;
}

sg_pass_attachment_desc :: struct {
    image     : sg_image;
    mip_level : s32;
    slice     : s32; /* cube texture: face; array texture: layer; 3D texture: slice */
}

sg_pass_desc :: struct {
    _start_canary            : u32;
    color_attachments        : [SG_MAX_COLOR_ATTACHMENTS]sg_pass_attachment_desc;
    depth_stencil_attachment : sg_pass_attachment_desc;
    label                    : *u8;
    _end_canary              : u32;
}

sg_trace_hooks :: struct {
    user_data: *void;
    reset_state_cache           : (*void)                                    #c_call;
    make_buffer                 : (*sg_buffer_desc, sg_buffer, *void)        #c_call;
    make_image                  : (*sg_image_desc, sg_image, *void)          #c_call;
    make_shader                 : (*sg_shader_desc, sg_shader, *void)        #c_call;
    make_pipeline               : (*sg_pipeline_desc, sg_pipeline, *void)    #c_call;
    make_pass                   : (*sg_pass_desc, sg_pass, *void)            #c_call;
    destroy_buffer              : (sg_buffer, *void)                         #c_call;
    destroy_image               : (sg_image, *void)                          #c_call;
    destroy_shader              : (sg_shader, *void)                         #c_call;
    destroy_pipeline            : (sg_pipeline, *void)                       #c_call;
    destroy_pass                : (sg_pass, *void)                           #c_call;
    update_buffer               : (sg_buffer, *sg_range, *void)              #c_call;
    update_image                : (sg_image, *sg_image_data, *void)          #c_call;
    append_buffer               : (sg_buffer, *sg_range, s32, *void)         #c_call;
    begin_default_pass          : (*sg_pass_action, s32, s32, *void)         #c_call;
    begin_pass                  : (sg_pass, *sg_pass_action, *void)          #c_call;
    apply_viewport              : (s32, s32, s32, s32, bool, *void)          #c_call;
    apply_scissor_rect          : (s32, s32, s32, s32, bool, *void)          #c_call;
    apply_pipeline              : (sg_pipeline, *void)                       #c_call;
    apply_bindings              : (*sg_bindings, *void)                      #c_call;
    apply_uniforms              : (sg_shader_stage, s32, *sg_range, *void)   #c_call;
    draw                        : (s32, s32, s32, *void)                     #c_call;
    end_pass                    : (*void)                                    #c_call;
    commit                      : (*void)                                    #c_call;
    alloc_buffer                : (sg_buffer, *void)                         #c_call;
    alloc_image                 : (sg_image, *void)                          #c_call;
    alloc_shader                : (sg_shader, *void)                         #c_call;
    alloc_pipeline              : (sg_pipeline, *void)                       #c_call;
    alloc_pass                  : (sg_pass, *void)                           #c_call;
    dealloc_buffer              : (sg_buffer, *void)                         #c_call;
    dealloc_image               : (sg_image, *void)                          #c_call;
    dealloc_shader              : (sg_shader, *void)                         #c_call;
    dealloc_pipeline            : (sg_pipeline, *void)                       #c_call;
    dealloc_pass                : (sg_pass, *void)                           #c_call;
    init_buffer                 : (sg_buffer, *sg_buffer_desc, *void)        #c_call;
    init_image                  : (sg_image, *sg_image_desc, *void)          #c_call;
    init_shader                 : (sg_shader, *sg_shader_desc, *void)        #c_call;
    init_pipeline               : (sg_pipeline, *sg_pipeline_desc, *void)    #c_call;
    init_pass                   : (sg_pass, *sg_pass_desc, *void)            #c_call;
    uninit_buffer               : (sg_buffer, *void)                         #c_call;
    uninit_image                : (sg_image, *void)                          #c_call;
    uninit_shader               : (sg_shader, *void)                         #c_call;
    uninit_pipeline             : (sg_pipeline, *void)                       #c_call;
    uninit_pass                 : (sg_pass, *void)                           #c_call;
    fail_buffer                 : (sg_buffer, *void)                         #c_call;
    fail_image                  : (sg_image, *void)                          #c_call;
    fail_shader                 : (sg_shader, *void)                         #c_call;
    fail_pipeline               : (sg_pipeline, *void)                       #c_call;
    fail_pass                   : (sg_pass, *void)                           #c_call;
    push_debug_group            : (*u8, *void)                               #c_call;
    pop_debug_group             : (*void)                                    #c_call;
    err_buffer_pool_exhausted   : (*void)                                    #c_call;
    err_image_pool_exhausted    : (*void)                                    #c_call;
    err_shader_pool_exhausted   : (*void)                                    #c_call;
    err_pipeline_pool_exhausted : (*void)                                    #c_call;
    err_pass_pool_exhausted     : (*void)                                    #c_call;
    err_context_mismatch        : (*void)                                    #c_call;
    err_pass_invalid            : (*void)                                    #c_call;
    err_draw_invalid            : (*void)                                    #c_call;
    err_bindings_invalid        : (*void)                                    #c_call;
}

sg_slot_info :: struct {
    state  : sg_resource_state; /* the current state of this resource slot */
    res_id : u32;               /* type-neutral resource if (e.g. sg_buffer.id) */
    ctx_id : u32;               /* the context this resource belongs to */
}

sg_buffer_info :: struct {
    slot               : sg_slot_info; /* resource pool slot info */
    update_frame_index : u32;          /* frame index of last sg_update_buffer() */
    append_frame_index : u32;          /* frame index of last sg_append_buffer() */
    append_pos         : s32;          /* current position in buffer for sg_append_buffer() */
    append_overflow    : bool;         /* is buffer in overflow state (due to sg_append_buffer) */
    num_slots          : s32;          /* number of renaming-slots for dynamically updated buffers */
    active_slot        : s32;          /* currently active write-slot for dynamically updated buffers */
}

sg_image_info :: struct {
    slot            : sg_slot_info; /* resource pool slot info */
    upd_frame_index : u32;          /* frame index of last sg_update_image() */
    num_slots       : s32;          /* number of renaming-slots for dynamically updated images */
    active_slot     : s32;          /* currently active write-slot for dynamically updated images */
    width           : s32;          /* image width */
    height          : s32;          /* image height */
}

sg_shader_info :: struct {
    slot: sg_slot_info; /* resoure pool slot info */
}

sg_pipeline_info :: struct {
    slot: sg_slot_info; /* resource pool slot info */
}

sg_pass_info :: struct {
    slot: sg_slot_info; /* resource pool slot info */
}

sg_gl_context_desc :: struct {
    force_gles2: bool;
}

sg_metal_context_desc :: struct {
    device                            : *void;
    renderpass_descriptor_cb          : ()      -> *void #c_call;
    renderpass_descriptor_userdata_cb : (*void) -> *void #c_call;
    drawable_cb                       : ()      -> *void #c_call;
    drawable_userdata_cb              : (*void) -> *void #c_call;
    user_data                         : *void;
}

sg_d3d11_context_desc :: struct {
    device                         : *void;
    device_context                 : *void;
    render_target_view_cb          : ()      -> *void #c_call;
    render_target_view_userdata_cb : (*void) -> *void #c_call;
    depth_stencil_view_cb          : ()      -> *void #c_call;
    depth_stencil_view_userdata_cb : (*void) -> *void #c_call;
    user_data                      : *void;
}

sg_wgpu_context_desc :: struct {
    device                         : *void;                    /* WGPUDevice */
    render_view_cb                 : ()      -> *void #c_call; /* returns WGPUTextureView */
    render_view_userdata_cb        : (*void) -> *void #c_call;
    resolve_view_cb                : ()      -> *void #c_call; /* returns WGPUTextureView */
    resolve_view_userdata_cb       : (*void) -> *void #c_call;
    depth_stencil_view_cb          : ()      -> *void #c_call; /* returns WGPUTextureView, must be WGPUTextureFormat_Depth24Plus8 */
    depth_stencil_view_userdata_cb : (*void) -> *void #c_call;
    user_data                      : *void;
}

sg_context_desc :: struct {
    color_format : sg_pixel_format;
    depth_format : sg_pixel_format;
    sample_count : s32;
    gl           : sg_gl_context_desc;
    metal        : sg_metal_context_desc;
    d3d11        : sg_d3d11_context_desc;
    wgpu         : sg_wgpu_context_desc;
}

sg_desc :: struct {
    _start_canary       : u32;
    buffer_pool_size    : s32;
    image_pool_size     : s32;
    shader_pool_size    : s32;
    pipeline_pool_size  : s32;
    pass_pool_size      : s32;
    context_pool_size   : s32;
    uniform_buffer_size : s32;
    staging_buffer_size : s32;
    sampler_cache_size  : s32;
    _context            : sg_context_desc;
    _end_canary         : u32;
}

sg_setup               :: (desc: *sg_desc)                                 #foreign sokol_gfx;
sg_shutdown            :: ()                                               #foreign sokol_gfx;
sg_isvalid             :: () -> bool                                       #foreign sokol_gfx;
sg_reset_state_cache   :: ()                                               #foreign sokol_gfx;
sg_install_trace_hooks :: (trace_hooks: *sg_trace_hooks) -> sg_trace_hooks #foreign sokol_gfx;
sg_push_debug_group    :: (name: *u8)                                      #foreign sokol_gfx;
sg_pop_debug_group     :: ()                                               #foreign sokol_gfx;

/* resource creation, destruction and updating */
sg_make_buffer           :: (desc: *sg_buffer_desc) -> sg_buffer       #foreign sokol_gfx;
sg_make_image            :: (desc: *sg_image_desc) -> sg_image         #foreign sokol_gfx;
sg_make_shader           :: (desc: *sg_shader_desc) -> sg_shader       #foreign sokol_gfx;
sg_make_pipeline         :: (desc: *sg_pipeline_desc) -> sg_pipeline   #foreign sokol_gfx;
sg_make_pass             :: (desc: *sg_pass_desc) -> sg_pass           #foreign sokol_gfx;
sg_destroy_buffer        :: (buf: sg_buffer)                           #foreign sokol_gfx;
sg_destroy_image         :: (img: sg_image)                            #foreign sokol_gfx;
sg_destroy_shader        :: (shd: sg_shader)                           #foreign sokol_gfx;
sg_destroy_pipeline      :: (pip: sg_pipeline)                         #foreign sokol_gfx;
sg_destroy_pass          :: (pass: sg_pass)                            #foreign sokol_gfx;
sg_update_buffer         :: (buf: sg_buffer, data: *sg_range)          #foreign sokol_gfx;
sg_update_image          :: (img: sg_image, data: *sg_image_data)      #foreign sokol_gfx;
sg_append_buffer         :: (buf: sg_buffer, data: *sg_range) -> s32   #foreign sokol_gfx;
sg_query_buffer_overflow :: (buf: sg_buffer) -> bool                   #foreign sokol_gfx;

/* rendering functions */
sg_begin_default_pass  :: (pass_action: *sg_pass_action, width: s32, height: s32)                          #foreign sokol_gfx;
sg_begin_default_passf :: (pass_action: *sg_pass_action, width: float32, height: float32)                  #foreign sokol_gfx;
sg_begin_pass          :: (pass: sg_pass, pass_action: *sg_pass_action)                                    #foreign sokol_gfx;
sg_apply_viewport      :: (x: s32, y: s32, width: s32, height: s32, origin_top_left: bool)                 #foreign sokol_gfx;
sg_apply_viewportf     :: (x: float32, y: float32, width: float32, height: float32, origin_top_left: bool) #foreign sokol_gfx;
sg_apply_scissor_rect  :: (x: s32, y: s32, width: s32, height: s32, origin_top_left: bool)                 #foreign sokol_gfx;
sg_apply_scissor_rectf :: (x: float32, y: float32, width: float32, height: float32, origin_top_left: bool) #foreign sokol_gfx;
sg_apply_pipeline      :: (pip: sg_pipeline)                                                               #foreign sokol_gfx;
sg_apply_bindings      :: (bindings: *sg_bindings)                                                         #foreign sokol_gfx;
sg_apply_uniforms      :: (stage: sg_shader_stage, ub_index: s32, data: *sg_range)                         #foreign sokol_gfx;
sg_draw                :: (base_element: s32, num_elements: s32, num_instances: s32)                       #foreign sokol_gfx;
sg_end_pass            :: ()                                                                               #foreign sokol_gfx;
sg_commit              :: ()                                                                               #foreign sokol_gfx;

/* getting information */
sg_query_desc        :: () -> sg_desc                                 #foreign sokol_gfx;
sg_query_backend     :: () -> sg_backend                              #foreign sokol_gfx;
sg_query_features    :: () -> sg_features                             #foreign sokol_gfx;
sg_query_limits      :: () -> sg_limits                               #foreign sokol_gfx;
sg_query_pixelformat :: (fmt: sg_pixel_format) -> sg_pixelformat_info #foreign sokol_gfx;

/* get current state of a resource (INITIAL, ALLOC, VALID, FAILED, INVALID) */
sg_query_buffer_state   :: (buf: sg_buffer) -> sg_resource_state   #foreign sokol_gfx;
sg_query_image_state    :: (img: sg_image) -> sg_resource_state    #foreign sokol_gfx;
sg_query_shader_state   :: (shd: sg_shader) -> sg_resource_state   #foreign sokol_gfx;
sg_query_pipeline_state :: (pip: sg_pipeline) -> sg_resource_state #foreign sokol_gfx;
sg_query_pass_state     :: (pass: sg_pass) -> sg_resource_state    #foreign sokol_gfx;

/* get runtime information about a resource */
sg_query_buffer_info   :: (buf: sg_buffer) -> sg_buffer_info     #foreign sokol_gfx;
sg_query_image_info    :: (img: sg_image) -> sg_image_info       #foreign sokol_gfx;
sg_query_shader_info   :: (shd: sg_shader) -> sg_shader_info     #foreign sokol_gfx;
sg_query_pipeline_info :: (pip: sg_pipeline) -> sg_pipeline_info #foreign sokol_gfx;
sg_query_pass_info     :: (pass: sg_pass) -> sg_pass_info        #foreign sokol_gfx;

/* get resource creation desc struct with their default values replaced */
sg_query_buffer_defaults   :: (desc: *sg_buffer_desc) -> sg_buffer_desc     #foreign sokol_gfx;
sg_query_image_defaults    :: (desc: *sg_image_desc) -> sg_image_desc       #foreign sokol_gfx;
sg_query_shader_defaults   :: (desc: *sg_shader_desc) -> sg_shader_desc     #foreign sokol_gfx;
sg_query_pipeline_defaults :: (desc: *sg_pipeline_desc) -> sg_pipeline_desc #foreign sokol_gfx;
sg_query_pass_defaults     :: (desc: *sg_pass_desc) -> sg_pass_desc         #foreign sokol_gfx;

/* separate resource allocation and initialization (for async setup) */
sg_alloc_buffer     :: () -> sg_buffer                                #foreign sokol_gfx;
sg_alloc_image      :: () -> sg_image                                 #foreign sokol_gfx;
sg_alloc_shader     :: () -> sg_shader                                #foreign sokol_gfx;
sg_alloc_pipeline   :: () -> sg_pipeline                              #foreign sokol_gfx;
sg_alloc_pass       :: () -> sg_pass                                  #foreign sokol_gfx;
sg_dealloc_buffer   :: (buf_id: sg_buffer)                            #foreign sokol_gfx;
sg_dealloc_image    :: (img_id: sg_image)                             #foreign sokol_gfx;
sg_dealloc_shader   :: (shd_id: sg_shader)                            #foreign sokol_gfx;
sg_dealloc_pipeline :: (pip_id: sg_pipeline)                          #foreign sokol_gfx;
sg_dealloc_pass     :: (pass_id: sg_pass)                             #foreign sokol_gfx;
sg_init_buffer      :: (buf_id: sg_buffer, desc: *sg_buffer_desc)     #foreign sokol_gfx;
sg_init_image       :: (img_id: sg_image, desc: *sg_image_desc)       #foreign sokol_gfx;
sg_init_shader      :: (shd_id: sg_shader, desc: *sg_shader_desc)     #foreign sokol_gfx;
sg_init_pipeline    :: (pip_id: sg_pipeline, desc: *sg_pipeline_desc) #foreign sokol_gfx;
sg_init_pass        :: (pass_id: sg_pass, desc: *sg_pass_desc)        #foreign sokol_gfx;
sg_uninit_buffer    :: (buf_id: sg_buffer) -> bool                    #foreign sokol_gfx;
sg_uninit_image     :: (img_id: sg_image) -> bool                     #foreign sokol_gfx;
sg_uninit_shader    :: (shd_id: sg_shader) -> bool                    #foreign sokol_gfx;
sg_uninit_pipeline  :: (pip_id: sg_pipeline) -> bool                  #foreign sokol_gfx;
sg_uninit_pass      :: (pass_id: sg_pass) -> bool                     #foreign sokol_gfx;
sg_fail_buffer      :: (buf_id: sg_buffer)                            #foreign sokol_gfx;
sg_fail_image       :: (img_id: sg_image)                             #foreign sokol_gfx;
sg_fail_shader      :: (shd_id: sg_shader)                            #foreign sokol_gfx;
sg_fail_pipeline    :: (pip_id: sg_pipeline)                          #foreign sokol_gfx;
sg_fail_pass        :: (pass_id: sg_pass)                             #foreign sokol_gfx;

/* rendering contexts (optional) */
sg_setup_context    :: () -> sg_context     #foreign sokol_gfx;
sg_activate_context :: (ctx_id: sg_context) #foreign sokol_gfx;
sg_discard_context  :: (ctx_id: sg_context) #foreign sokol_gfx;

/* D3D11: return ID3D11Device */
sg_d3d11_device :: () -> *void #foreign sokol_gfx;

/* Metal: return __bridge-casted MTLDevice */
sg_mtl_device :: () -> *void #foreign sokol_gfx;

/* Metal: return __bridge-casted MTLRenderCommandEncoder in current pass (or zero if outside pass) */
sg_mtl_render_command_encoder :: () -> *void #foreign sokol_gfx;

#if OS == .WINDOWS {
    sokol_gfx :: #foreign_library,no_dll "win/sokol_gfx";
}