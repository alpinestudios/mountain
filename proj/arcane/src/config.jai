app_title :: "balls";
DEFAULT_WORLD  :: "main";
DEFAULT_UV :: Range2.{0.0, 0.0, 1.0, 1.0};
ENTITY_MAX :: 1024; // the initial guess of the entity count. Increase this if a resize warning is thrown.

WINDOW_X :: 1280;
WINDOW_Y :: 720;
// WINDOW_X :: 1920;
// WINDOW_Y :: 1080;

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
FONT_MAIN :: FONT_1980; // FONT_RHYME
FONT_SUB :: FONT_1980; // FONT_SUFFERING

ASSET_PATH :: "res/";
SHADER_PATH :: "res/shaders/";

// 1 -> 100
Z_BACKDROP :: 100;
Z_CELESTIAL :: 99;
Z_MOUNTAIN :: 98;

Z_TREES_3 :: 90;
Z_TREES_2 :: 80;
Z_HILLS_1 :: 60;
Z_TREES_1 :: 50;

Z_TREE :: 22;
Z_ROOTS :: 21;
Z_TALL_GRASS :: 20;
Z_STRUCTURES :: 15;
Z_ENTITY_VFX :: 12;
Z_PLAYER :: 10;
Z_MONSTER :: 9;
Z_ITEMS :: 8;
Z_GROUND :: 5;

Z_UI :: 2;


GROUND_COL :: 0x5e3928FF;

COL_UI_BG :: BLACK;
COL_UI_BORDERS :: WHITE;
COL_UI_TEXT :: WHITE;
COL_UI_FILL :: #run hex_to_rgba(0x4d8391FF);
UI_ANIMATE_RATE :: 30.0;


DEFAULT_ZOOM :: 4.0;
MAX_CAMERA_SHAKE_TRANS :: 5.0;
MAX_CAMERA_SHAKE_ROT :: 5.0;

max_player_move_speed :: 60.0;
player_move_tilt :: 4.0;
scuffed_player_scale :: 0.6;
PLAYER_ACCEL :: 800.0;
PLAYER_DECEL :: 500.0;




world_radius : u64 : 1000;
DAY_LENGTH :: 180.0;

VSYNC :: true;

DEBUG_UI_BOXES :: false;
DEBUG :: true;

fun_val := 1.0;
show_debug_ui := false;
DEBUG_RESTART :: true;

TOOLING :: true;

TESTING :: true;
#if TESTING
{
	START_APP_STATE :: AppMode.world;
	IGNORE_MATERIAL_COST :: true;
	DEBUG_UNLOCK_RECIPES :: true;
	BASE_MAX_HEALTH :: 3;
	BASE_WEIGHT :: 100;
	BASE_HOTBAR_COUNT :: 3;
	SPRINT_MULT :: 1.0;
	INITIAL_DAY_START_TIME :: DAY_LENGTH;
	RISER_SOUND :: true;
	RANDOMIZE_SEED :: true;
	MONSTER_SPAWN_RADIUS :: 200.0;
	RESPAWN_LENGTH :: 3.0;
}
else
{
	START_APP_STATE :: AppMode.main_menu;
	IGNORE_MATERIAL_COST :: false;
	DEBUG_UNLOCK_RECIPES :: false;
	BASE_MAX_HEALTH :: 3;
	BASE_WEIGHT :: 10;
	BASE_HOTBAR_COUNT :: 1;
	SPRINT_MULT :: 1.0;
	INITIAL_DAY_START_TIME :: DAY_LENGTH;
	RISER_SOUND :: true;
	RANDOMIZE_SEED :: true;
	MONSTER_SPAWN_RADIUS :: 800.0;
	RESPAWN_LENGTH :: 10.0;
}

LOG_VERBOSE :: false;

WORLD_RENDER :: true;
RENDER_BACKGROUND :: true;
DO_WORLD_GEN :: true;