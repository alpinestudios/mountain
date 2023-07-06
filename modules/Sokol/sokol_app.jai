_SAPP_MAX_TITLE_LENGTH          :: 128;

/* NOTE: the pixel format values *must* be compatible with sg_pixel_format */
_SAPP_PIXELFORMAT_RGBA8         :: 23;
_SAPP_PIXELFORMAT_BGRA8         :: 27;
_SAPP_PIXELFORMAT_DEPTH         :: 41;
_SAPP_PIXELFORMAT_DEPTH_STENCIL :: 42;

SAPP_MAX_TOUCHPOINTS  :: 8;
SAPP_MAX_MOUSEBUTTONS :: 3;
SAPP_MAX_KEYCODES     :: 512;
SAPP_MAX_ICONIMAGES   :: 8;

sapp_desc :: struct {
    init_cb    : () #c_call;
    frame_cb   : () #c_call;
    cleanup_cb : () #c_call;
    event_cb   : (*sapp_event) #c_call;
    fail_cb    : (*u8) #c_call;

    user_data: *void;

    init_userdata_cb    : (*void) #c_call;
    frame_userdata_cb   : (*void) #c_call;
    cleanup_userdata_cb : (*void) #c_call;
    event_userdata_cb   : (*sapp_event, *void) #c_call;
    fail_userdata_cb    : (*u8, *void) #c_call;

    width         : s32;                // the preferred width of the window / canvas
    height        : s32;                // the preferred height of the window / canvas
    sample_count  : s32;                // MSAA sample count
    swap_interval : s32;                // the preferred swap interval (ignored on some platforms)

    high_dpi   : bool;                  // whether the rendering canvas is full-resolution on HighDPI displays
    fullscreen : bool;                  // whether the window should be created in fullscreen mode
    alpha      : bool;                  // whether the framebuffer should have an alpha channel (ignored on some platforms)

    window_title     : *u8;             // the window title as UTF-8 encoded string
    user_cursor      : bool;            // if true, user is expected to manage cursor image in SAPP_EVENTTYPE_UPDATE_CURSOR
    enable_clipboard : bool;            // enable clipboard access, default is false
    clipboard_size   : s32;             // max size of clipboard content in bytes
    enable_dragndrop : bool;            // enable file dropping (drag'n'drop), default is false

    max_dropped_files: s32;             // max number of dropped files to process (default: 1)
    max_dropped_file_path_length: s32;  // max length in bytes of a dropped UTF-8 file path (default: 2048)
    icon: sapp_icon_desc;               // the initial window icon to set

    /* backend-specific options */
    gl_force_gles2                : bool;           // if true, setup GLES2/WebGL even if GLES3/WebGL2 is available
    win32_console_utf8            : bool;           // if true, set the output console codepage to UTF-8
    win32_console_create          : bool;           // if true, attach stdout/stderr to a new console window
    win32_console_attach          : bool;           // if true, attach stdout/stderr to parent process
    html5_canvas_name             : *u8 = "canvas"; // the name (id) of the HTML5 canvas element, default is "canvas"
    html5_canvas_resize           : bool;           // if true, the HTML5 canvas size is set to sapp_desc.width/height, otherwise canvas size is tracked
    html5_preserve_drawing_buffer : bool;           // HTML5 only: whether to preserve default framebuffer content between frames
    html5_premultiplied_alpha     : bool;           // HTML5 only: whether the rendered pixels use premultiplied alpha convention
    html5_ask_leave_site          : bool;           // initial state of the internal html5_ask_leave_site flag (see sapp_html5_ask_leave_site())
    ios_keyboard_resizes_canvas   : bool;           // if true, showing the iOS keyboard shrinks the canvas
}

sapp_image_desc :: struct {
    width  : s32;
    height : s32;
    pixels : sapp_range;
}

sapp_icon_desc :: struct {
    sokol_default : bool;
    images        : [SAPP_MAX_ICONIMAGES]sapp_image_desc;
}

sapp_event_type :: enum u32 {
    INVALID;
    KEY_DOWN;
    KEY_UP;
    CHAR;
    MOUSE_DOWN;
    MOUSE_UP;
    MOUSE_SCROLL;
    MOUSE_MOVE;
    MOUSE_ENTER;
    MOUSE_LEAVE;
    TOUCHES_BEGAN;
    TOUCHES_MOVED;
    TOUCHES_ENDED;
    TOUCHES_CANCELLED;
    RESIZED;
    ICONIFIED;
    RESTORED;
    SUSPENDED;
    RESUMED;
    UPDATE_CURSOR;
    QUIT_REQUESTED;
    CLIPBOARD_PASTED;
    FILES_DROPPED;
    _NUM;
    _FORCE_U32 :: 0x7FFFFFFF;
}

sapp_keycode :: enum u32 {
    KEYCODE_INVALID          ::  0;
    KEYCODE_SPACE            :: 32;
    KEYCODE_APOSTROPHE       :: 39;  /* ' */
    KEYCODE_COMMA            :: 44;  /* , */
    KEYCODE_MINUS            :: 45;  /* - */
    KEYCODE_PERIOD           :: 46;  /* . */
    KEYCODE_SLASH            :: 47;  /* / */
    KEYCODE_0                :: 48;
    KEYCODE_1                :: 49;
    KEYCODE_2                :: 50;
    KEYCODE_3                :: 51;
    KEYCODE_4                :: 52;
    KEYCODE_5                :: 53;
    KEYCODE_6                :: 54;
    KEYCODE_7                :: 55;
    KEYCODE_8                :: 56;
    KEYCODE_9                :: 57;
    KEYCODE_SEMICOLON        :: 59;  /* ; */
    KEYCODE_EQUAL            :: 61;  /* = */
    KEYCODE_A                :: 65;
    KEYCODE_B                :: 66;
    KEYCODE_C                :: 67;
    KEYCODE_D                :: 68;
    KEYCODE_E                :: 69;
    KEYCODE_F                :: 70;
    KEYCODE_G                :: 71;
    KEYCODE_H                :: 72;
    KEYCODE_I                :: 73;
    KEYCODE_J                :: 74;
    KEYCODE_K                :: 75;
    KEYCODE_L                :: 76;
    KEYCODE_M                :: 77;
    KEYCODE_N                :: 78;
    KEYCODE_O                :: 79;
    KEYCODE_P                :: 80;
    KEYCODE_Q                :: 81;
    KEYCODE_R                :: 82;
    KEYCODE_S                :: 83;
    KEYCODE_T                :: 84;
    KEYCODE_U                :: 85;
    KEYCODE_V                :: 86;
    KEYCODE_W                :: 87;
    KEYCODE_X                :: 88;
    KEYCODE_Y                :: 89;
    KEYCODE_Z                :: 90;
    KEYCODE_LEFT_BRACKET     :: 91;  /* [ */
    KEYCODE_BACKSLASH        :: 92;  /* \ */
    KEYCODE_RIGHT_BRACKET    :: 93;  /* ] */
    KEYCODE_GRAVE_ACCENT     :: 96;  /* ` */
    KEYCODE_WORLD_1          :: 161; /* non-US #1 */
    KEYCODE_WORLD_2          :: 162; /* non-US #2 */
    KEYCODE_ESCAPE           :: 256;
    KEYCODE_ENTER            :: 257;
    KEYCODE_TAB              :: 258;
    KEYCODE_BACKSPACE        :: 259;
    KEYCODE_INSERT           :: 260;
    KEYCODE_DELETE           :: 261;
    KEYCODE_RIGHT            :: 262;
    KEYCODE_LEFT             :: 263;
    KEYCODE_DOWN             :: 264;
    KEYCODE_UP               :: 265;
    KEYCODE_PAGE_UP          :: 266;
    KEYCODE_PAGE_DOWN        :: 267;
    KEYCODE_HOME             :: 268;
    KEYCODE_END              :: 269;
    KEYCODE_CAPS_LOCK        :: 280;
    KEYCODE_SCROLL_LOCK      :: 281;
    KEYCODE_NUM_LOCK         :: 282;
    KEYCODE_PRINT_SCREEN     :: 283;
    KEYCODE_PAUSE            :: 284;
    KEYCODE_F1               :: 290;
    KEYCODE_F2               :: 291;
    KEYCODE_F3               :: 292;
    KEYCODE_F4               :: 293;
    KEYCODE_F5               :: 294;
    KEYCODE_F6               :: 295;
    KEYCODE_F7               :: 296;
    KEYCODE_F8               :: 297;
    KEYCODE_F9               :: 298;
    KEYCODE_F10              :: 299;
    KEYCODE_F11              :: 300;
    KEYCODE_F12              :: 301;
    KEYCODE_F13              :: 302;
    KEYCODE_F14              :: 303;
    KEYCODE_F15              :: 304;
    KEYCODE_F16              :: 305;
    KEYCODE_F17              :: 306;
    KEYCODE_F18              :: 307;
    KEYCODE_F19              :: 308;
    KEYCODE_F20              :: 309;
    KEYCODE_F21              :: 310;
    KEYCODE_F22              :: 311;
    KEYCODE_F23              :: 312;
    KEYCODE_F24              :: 313;
    KEYCODE_F25              :: 314;
    KEYCODE_KP_0             :: 320;
    KEYCODE_KP_1             :: 321;
    KEYCODE_KP_2             :: 322;
    KEYCODE_KP_3             :: 323;
    KEYCODE_KP_4             :: 324;
    KEYCODE_KP_5             :: 325;
    KEYCODE_KP_6             :: 326;
    KEYCODE_KP_7             :: 327;
    KEYCODE_KP_8             :: 328;
    KEYCODE_KP_9             :: 329;
    KEYCODE_KP_DECIMAL       :: 330;
    KEYCODE_KP_DIVIDE        :: 331;
    KEYCODE_KP_MULTIPLY      :: 332;
    KEYCODE_KP_SUBTRACT      :: 333;
    KEYCODE_KP_ADD           :: 334;
    KEYCODE_KP_ENTER         :: 335;
    KEYCODE_KP_EQUAL         :: 336;
    KEYCODE_LEFT_SHIFT       :: 340;
    KEYCODE_LEFT_CONTROL     :: 341;
    KEYCODE_LEFT_ALT         :: 342;
    KEYCODE_LEFT_SUPER       :: 343;
    KEYCODE_RIGHT_SHIFT      :: 344;
    KEYCODE_RIGHT_CONTROL    :: 345;
    KEYCODE_RIGHT_ALT        :: 346;
    KEYCODE_RIGHT_SUPER      :: 347;
    KEYCODE_MENU             :: 348;
}

sapp_mousebutton :: enum u32 {
    MOUSEBUTTON_LEFT    :: 0x0;
    MOUSEBUTTON_RIGHT   :: 0x1;
    MOUSEBUTTON_MIDDLE  :: 0x2;
    MOUSEBUTTON_INVALID :: 0x100;
}

sapp_touchpoint :: struct {
    identifier : *void;
    pos_x      : float;
    pos_y      : float;
    changed    : bool;
}

sapp_event :: struct {
    frame_count        : u64;                                   // current frame counter, always valid, useful for checking if two events were issued in the same frame
    type               : sapp_event_type;                       // the event type, always valid
    key_code           : sapp_keycode;                          // the virtual key code, only valid in KEY_UP, KEY_DOWN
    char_code          : u32;                                   // the UTF-32 character code, only valid in CHAR events
    key_repeat         : bool;                                  // true if this is a key-repeat event, valid in KEY_UP, KEY_DOWN and CHAR
    modifiers          : u32;                                   // current modifier keys, valid in all key-, char- and mouse-events
    mouse_button       : sapp_mousebutton;                      // mouse button that was pressed or released, valid in MOUSE_DOWN, MOUSE_UP
    mouse_x            : float;                                 // current horizontal mouse position in pixels, always valid except during mouse lock
    mouse_y            : float;                                 // current vertical mouse position in pixels, always valid except during mouse lock
    mouse_dx           : float;                                 // relative horizontal mouse movement since last frame, always valid
    mouse_dy           : float;                                 // relative vertical mouse movement since last frame, always valid
    scroll_x           : float;                                 // horizontal mouse wheel scroll distance, valid in MOUSE_SCROLL events
    scroll_y           : float;                                 // vertical mouse wheel scroll distance, valid in MOUSE_SCROLL events
    num_touches        : s32;                                   // number of valid items in the touches[] array
    touches            : [SAPP_MAX_TOUCHPOINTS]sapp_touchpoint; // current touch points, valid in TOUCHES_BEGIN, TOUCHES_MOVED, TOUCHES_ENDED
    window_width       : s32;                                   // current window- and framebuffer sizes in pixels, always valid
    window_height      : s32;
    framebuffer_width  : s32;                                   // = window_width * dpi_scale
    framebuffer_height : s32;                                   // = window_height * dpi_scale 
}

sapp_range :: struct {
    ptr  : *void;
    size : s64;
}

sapp_html5_fetch_error :: enum u32 {
    FETCH_ERROR_NO_ERROR;
    FETCH_ERROR_BUFFER_TOO_SMALL;
    FETCH_ERROR_OTHER;
}

sapp_html5_fetch_response :: struct {
    succeeded    : bool;                    /* true if the loading operation has succeeded */
    error_code   : sapp_html5_fetch_error;
    file_index   : s32;                     /* index of the dropped file (0..sapp_get_num_dropped_filed()-1) */
    fetched_size : u32;                     /* size in bytes of loaded data */
    buffer_ptr   : *void;                   /* pointer to user-provided buffer which contains the loaded data */
    buffer_size  : u32;                     /* size of user-provided buffer (buffer_size >= fetched_size) */
    user_data    : *void;                   /* user-provided user data pointer */
}

sapp_html5_fetch_request :: struct {
    dropped_file_index : s32;                                  /* 0..sapp_get_num_dropped_files()-1 */
    callback           : (*sapp_html5_fetch_response) #c_call; /* response callback function pointer (required) */
    buffer_ptr         : *void;                                /* pointer to buffer to load data into */
    buffer_size        : u32;                                  /* size in bytes of buffer */
    user_data          : *void;                                /* optional userdata pointer */
}

sapp_isvalid      :: () -> bool  #foreign sokol_app;
sapp_width        :: () -> s32   #foreign sokol_app;
sapp_widthf       :: () -> float #foreign sokol_app;
sapp_height       :: () -> s32   #foreign sokol_app;
sapp_heightf      :: () -> float #foreign sokol_app;
sapp_color_format :: () -> s32   #foreign sokol_app;
sapp_depth_format :: () -> s32   #foreign sokol_app;
sapp_sample_count :: () -> s32   #foreign sokol_app;

sapp_high_dpi          :: () -> bool   #foreign sokol_app;
sapp_dpi_scale         :: () -> float  #foreign sokol_app;
sapp_show_keyboard     :: (show: bool) #foreign sokol_app;
sapp_keyboard_shown    :: () -> bool   #foreign sokol_app;
sapp_is_fullscreen     :: () -> bool   #foreign sokol_app;
sapp_toggle_fullscreen :: ()           #foreign sokol_app;
sapp_show_mouse        :: (show: bool) #foreign sokol_app;
sapp_mouse_shown       :: () -> bool   #foreign sokol_app;
sapp_lock_mouse        :: (lock: bool) #foreign sokol_app;
sapp_mouse_locked      :: () -> bool   #foreign sokol_app;

sapp_userdata      :: () -> *void     #foreign sokol_app;
sapp_query_desc    :: () -> sapp_desc #foreign sokol_app;
sapp_request_quit  :: ()              #foreign sokol_app;
sapp_cancel_quit   :: ()              #foreign sokol_app;
sapp_quit          :: ()              #foreign sokol_app;
sapp_consume_event :: ()              #foreign sokol_app;

sapp_frame_count           :: () -> u64                    #foreign sokol_app;
sapp_set_clipboard_string  :: (str: *u8)                   #foreign sokol_app;
sapp_get_clipboard_string  :: () -> *u8                    #foreign sokol_app;
sapp_set_window_title      :: (str: *u8)                   #foreign sokol_app;
sapp_set_icon              :: (icon_desc: *sapp_icon_desc) #foreign sokol_app;
sapp_get_num_dropped_files :: () -> s32                    #foreign sokol_app;
sapp_get_dropped_file_path :: (index: s32) -> *u8          #foreign sokol_app;

sapp_run   :: (desc: *sapp_desc) #foreign sokol_app;
sapp_gles2 :: () -> bool         #foreign sokol_app;

sapp_html5_ask_leave_site        :: (ask: bool)                          #foreign sokol_app;
sapp_html5_get_dropped_file_size :: (index: s32) -> u32                  #foreign sokol_app;
sapp_html5_fetch_dropped_file    :: (request: *sapp_html5_fetch_request) #foreign sokol_app;

sapp_metal_get_device                :: () -> *void #foreign sokol_app;
sapp_metal_get_renderpass_descriptor :: () -> *void #foreign sokol_app;
sapp_metal_get_drawable              :: () -> *void #foreign sokol_app;
sapp_macos_get_window                :: () -> *void #foreign sokol_app;
sapp_ios_get_window                  :: () -> *void #foreign sokol_app;

sapp_d3d11_get_device             :: () -> *void #foreign sokol_app;
sapp_d3d11_get_device_context     :: () -> *void #foreign sokol_app;
sapp_d3d11_get_swap_chain         :: () -> *void #foreign sokol_app;
sapp_d3d11_get_render_target_view :: () -> *void #foreign sokol_app;
sapp_d3d11_get_depth_stencil_view :: () -> *void #foreign sokol_app;
sapp_win32_get_hwnd               :: () -> *void #foreign sokol_app;

sapp_wgpu_get_device             :: () -> *void #foreign sokol_app;
sapp_wgpu_get_render_view        :: () -> *void #foreign sokol_app;
sapp_wgpu_get_resolve_view       :: () -> *void #foreign sokol_app;
sapp_wgpu_get_depth_stencil_view :: () -> *void #foreign sokol_app;

sapp_android_get_native_activity :: () -> *void #foreign sokol_app;

#if OS == .WINDOWS {
    #foreign_system_library "d3d11";
    #foreign_system_library "gdi32";
    #foreign_system_library "dxguid";
    #foreign_system_library "user32";
    #foreign_system_library "shell32";
    sokol_app :: #foreign_library,no_dll "win/sokol_app";
}