TESTING :: true;
TOOLING :: true;
DEBUG :: true;

app_title :: "balls";
DEFAULT_WORLD  :: "main";
DEFAULT_UV :: Range2.{0.0, 0.0, 1.0, 1.0};
ENTITY_MAX :: 1024; // the initial guess of the entity count. Increase this if a resize warning is thrown.

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

ASSET_PATH :: "res/";
SHADER_PATH :: "res/shaders/";

world_radius : u64 : 1000;
DAY_LENGTH :: 480.0;
NIGHT_LENGTH :: 300.0;
CYCLE_LENGTH :: DAY_LENGTH + NIGHT_LENGTH;


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
Z_ITEMS :: 8;
Z_GROUND :: 5;
Z_UI :: 2;

// TODO - try merging this in with the parallax, see what happens??


GROUND_COL :: 0x5e3928FF;

BASE_HOTBAR_COUNT :: 2;
BASE_INVENTORY_COUNT :: 9;
DEFAULT_MAX_HEALTH :: 3;


camera_offset :: Vector2.{0, -40};
DEFAULT_ZOOM :: 3.2;
max_player_move_speed :: 60.0;
player_move_tilt :: 4.0;
scuffed_player_scale :: 0.6;
PLAYER_ACCEL :: 800.0;
PLAYER_DECEL :: 500.0;

fun_val := 1.0;
show_debug_ui := false;
DEBUG_RESTART :: true;

#if TESTING
{
	START_APP_STATE :: AppState.world;
	CYCLE_START_TIME :: 600;
	IGNORE_MATERIAL_COST :: true;
	DEBUG_UNLOCK_RECIPES :: true;
	IGNORE_WEIGHT :: true;
	SPRINT_MULT :: 4.0;
}
else
{
	START_APP_STATE :: AppState.main_menu;
	CYCLE_START_TIME :: 60;
	IGNORE_MATERIAL_COST :: false;
	DEBUG_UNLOCK_RECIPES :: false;
	IGNORE_WEIGHT :: false;
	SPRINT_MULT :: 1.0;
}

LOG_VERBOSE :: false;
SPAWN_GOBBY :: false;

WORLD_RENDER :: true;
RENDER_BACKGROUND :: true;
DO_WORLD_GEN :: true;