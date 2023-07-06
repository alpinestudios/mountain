DEBUG :: true;
app_title :: "balls";
WORLD_RENDER :: true;
DEFAULT_WORLD  :: "main";
DEFAULT_UV :: Range2.{0.0, 0.0, 1.0, 1.0};
ENTITY_MAX :: 1024; // the initial guess of the entity count. Increase this if a resize warning is thrown.

DEFAULT_ZOOM :: 4;
WINDOW_X :: 1280;
WINDOW_Y :: 720;
// WINDOW_X :: 1920;
// WINDOW_Y :: 1080;
VSYNC :: true;
CLEAR_COL :: BLACK;

FONT_RANDY :: "RandyGG.ttf";
FONT_BEGGARS :: "BeggarsExtended.ttf";
FONT_FLAGSTAFF :: "FlagstaffExtended.ttf";
FONT_INEXPUGNABLE :: "InexpugnableExtended.ttf";
FONT_QUATERSTAFF :: "QuarterstaffExtended.ttf";
FONT_REBUTTAL :: "RebuttalExtended.ttf";
FONT_REMANANT :: "RemnantExtended.ttf";
FONT_RHYME :: "RhymeExtended.ttf";
FONT_SAFEGUARD :: "SafeguardExtended.ttf";
FONT_SUFFERING :: "SufferingExtended.ttf";
FONT_WARPATH :: "WarpathExtended.ttf";
FONT_1980 :: "1980.ttf";
FONT_MAIN :: FONT_RHYME;
FONT_SUB :: FONT_SUFFERING;
FONT_SIZE :: 32;

ASSET_PATH :: "res/";
SHADER_PATH :: "res/shaders/";

world_radius : u64 : 1000;
DAY_LENGTH :: 480.0;
NIGHT_LENGTH :: 300.0;
CYCLE_LENGTH :: DAY_LENGTH + NIGHT_LENGTH;
CYCLE_START_TIME :: 600;



LAYER_GROUND :: 20;
LAYER_TREE :: -10;
LAYER_ROOTS :: -8;


camera_offset :: Vector2.{0, -20};
max_player_move_speed :: 60.0;
player_move_tilt :: 4.0;
scuffed_player_scale :: 0.6;
PLAYER_ACCEL :: 800.0;
PLAYER_DECEL :: 500.0;

fun_val := 1.0;
SHOW_UI := false;
DEBUG_RESTART :: true;
START_APP_STATE :: AppState.world;
IGNORE_MATERIAL_COST :: true;
DEBUG_SPRINT_MULT :: 4.0;
LOG_VERBOSE :: false;

MOUSE_CYCLE_OVERRIDE :: false;
DISABLE_CYCLE_LUTS :: true;