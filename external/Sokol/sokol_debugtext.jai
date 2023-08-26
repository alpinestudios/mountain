SDTX_MAX_FONTS :: 8;

sdtx_context :: struct {
    id: u32;
}

// the default context handle
SDTX_DEFAULT_CONTEXT :: sdtx_context.{ 0x00010001 };

sdtx_range :: struct {
    ptr  : *void;
    size : c.size_t;
};

sdtx_font_desc_t :: struct {
    data       : sdtx_range;
    first_char : u8;
    last_char  : u8;
}

sdtx_context_desc_t :: struct {
    char_buf_size : c.int = 4096;  
    canvas_width  : c.float = 640;  
    canvas_height : c.float = 400; 
    tab_width     : c.int = 4;         
    color_format  : sg_pixel_format;
    depth_format  : sg_pixel_format;
    sample_count  : c.int;          
}

sdtx_desc_t :: struct {
    context_pool_size : c.int = 8;                        // max number of rendering contexts that can be created, default: 8
    printf_buf_size   : c.int = 4096;                     // size of internal buffer for snprintf(), default: 4096
    fonts             : [SDTX_MAX_FONTS]sdtx_font_desc_t; // up to 8 fonts descriptions
    _context          : sdtx_context_desc_t;              // the default context creation parameters
}

// initialization/shutdown
sdtx_setup    :: (desc: *sdtx_desc_t) #foreign sokol_debugtext;
sdtx_shutdown :: ()                   #foreign sokol_debugtext;

// builtin font data (use to populate sdtx_desc.font[])
sdtx_font_kc853 :: () -> sdtx_font_desc_t #foreign sokol_debugtext;
sdtx_font_kc854 :: () -> sdtx_font_desc_t #foreign sokol_debugtext;
sdtx_font_z1013 :: () -> sdtx_font_desc_t #foreign sokol_debugtext;
sdtx_font_cpc   :: () -> sdtx_font_desc_t #foreign sokol_debugtext;
sdtx_font_c64   :: () -> sdtx_font_desc_t #foreign sokol_debugtext;
sdtx_font_oric  :: () -> sdtx_font_desc_t #foreign sokol_debugtext;

// context functions
sdtx_make_context    :: (desc: *sdtx_context_desc_t) -> sdtx_context #foreign sokol_debugtext;
sdtx_destroy_context :: (ctx: sdtx_context)                          #foreign sokol_debugtext;
sdtx_set_context     :: (ctx: sdtx_context)                          #foreign sokol_debugtext;
sdtx_get_context     :: () -> sdtx_context                           #foreign sokol_debugtext;

sdtx_draw   :: ()                       #foreign sokol_debugtext; // draw and rewind the current context 
sdtx_font   :: (font_index: c.int)      #foreign sokol_debugtext; // switch to a different font 
sdtx_canvas :: (w: c.float, h: c.float) #foreign sokol_debugtext; // set a new virtual canvas size in screen pixels 
sdtx_origin :: (x: c.float, y: c.float) #foreign sokol_debugtext; // set a new origin in character grid coordinates 

// cursor movement functions (relative to origin in character grid coordinates) 
sdtx_home   :: ()                        #foreign sokol_debugtext;
sdtx_pos    :: (x: c.float, y: c.float)  #foreign sokol_debugtext;
sdtx_pos_x  :: (x: c.float)              #foreign sokol_debugtext;
sdtx_pos_y  :: (y: c.float)              #foreign sokol_debugtext;
sdtx_move   :: (dx: c.float, y: c.float) #foreign sokol_debugtext;
sdtx_move_x :: (dx: c.float)             #foreign sokol_debugtext;
sdtx_move_y :: (dy: c.float)             #foreign sokol_debugtext;
sdtx_crlf   :: ()                        #foreign sokol_debugtext;

// set the current text color
sdtx_color3b :: (r: u8, g: u8, b: u8)                            #foreign sokol_debugtext; // RGB 0..255, A=255
sdtx_color3f :: (r: c.float, g: c.float, b: c.float)             #foreign sokol_debugtext; // RGB 0.0f..1.0f, A=1.0f
sdtx_color4b :: (r: u8, g: u8, b: u8, a: u8)                     #foreign sokol_debugtext; // RGBA 0..255
sdtx_color4f :: (r: c.float, g: c.float, b: c.float, a: c.float) #foreign sokol_debugtext; // RGBA 0.0f..1.0f
sdtx_color1i :: (rgba: u32)                                      #foreign sokol_debugtext; // ABGR 0xAABBGGRR

// text rendering
sdtx_putc :: (chr: c.char)              #foreign sokol_debugtext;
sdtx_puts :: (str: *c.char)             #foreign sokol_debugtext; // does NOT append newline!
sdtx_putr :: (str: *c.char, len: c.int) #foreign sokol_debugtext; // 'put range', also stops at zero-char

// @Todo(Judah): Not sure how to bind these right now.
// sdtx_printf  :: (const char* fmt, ...) SOKOL_DEBUGTEXT_PRINTF_ATTR -> c.int;
// sdtx_vprintf :: (const char* fmt, va_list args) -> c.int;

// Utilities

sdtx_desc_with_all_fonts :: () -> sdtx_desc_t {
    desc: sdtx_desc_t;

    desc.fonts[FONT_KC853] = sdtx_font_kc853();
    desc.fonts[FONT_KC854] = sdtx_font_kc854();
    desc.fonts[FONT_Z1013] = sdtx_font_z1013();
    desc.fonts[FONT_CPC]   = sdtx_font_cpc();
    desc.fonts[FONT_C64]   = sdtx_font_c64();
    desc.fonts[FONT_ORIC]  = sdtx_font_oric();

    return desc;
}

FONT_KC853 :: 0;
FONT_KC854 :: 1;
FONT_Z1013 :: 2;
FONT_CPC   :: 3;
FONT_C64   :: 4;
FONT_ORIC  :: 5; 

#if OS == .WINDOWS {
    sokol_debugtext :: #foreign_library,no_dll "win/sokol_gfx";
}
