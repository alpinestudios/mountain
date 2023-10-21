app_title :: "Arcane Survival";
DEFAULT_WORLD  :: "main";
DEFAULT_UV :: Range2.{0.0, 0.0, 1.0, 1.0};

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

Z_BACK_WALL :: 23;
Z_PORTAL :: 22.75;
Z_SIDE_WALL :: 22.5;
Z_WORLD_STRUCTURE :: 22.3;
Z_TREE :: 22;
Z_ROOTS :: 21;
Z_TALL_GRASS :: 20;
Z_PLANTS :: 16;
Z_STRUCTURES :: 15;
Z_ENTITY_VFX :: 12;
Z_TRAPS :: 11;
Z_PLAYER :: 10;
Z_MONSTER :: 9;
Z_PROJECTILES :: 8;
Z_ENTITY_PFX ::7;
Z_ITEMS :: 6;
Z_GROUND :: 5;
Z_BASE_TOTEM :: 4.8;
Z_START_CLIFF_CORE :: 4.7;
Z_FRONT_PARALLAX :: 4.5;
Z_FRONT_VFX :: 4;

Z_EDGE_FADE :: 3;
Z_UI :: 2;

GRAVITY :: 980.0;

GROUND_COL :: 0x5e3928FF;

COL_UI_BG :: BLACK;
COL_UI_BORDERS :: WHITE;
COL_UI_TEXT :: WHITE;
COL_UI_FILL :: #run hex_to_rgba(0x4d8391FF);
UI_ANIMATE_RATE :: 30.0;

UI_SLOT_SIZE :: 1.7;
UI_SLOT_SPACING :: 0.1;
UI_SLOT_ICON_PADDING :: 0.3;
UI_EDGE_PADDING :: 0.5;
UI_MARGIN :: 0.5;

DEFAULT_ZOOM :: 4.0;
MAX_CAMERA_SHAKE_TRANS :: 20.0;
MAX_CAMERA_SHAKE_ROT :: 10.0;

max_player_move_speed :: 50.0;
player_move_tilt :: 4.0;
scuffed_player_scale :: 0.6;
PLAYER_ACCEL :: 800.0;
PLAYER_DECEL :: 500.0;
DASH_DURATION :: 0.1;
DASH_COOLDOWN :: 1;
DASHING_MULT :: 8.0;
PLAYER_MAX_HUNGER :: 10;
HUNGER_TIMER_DURATION :: 6;


STRUCTURE_REPAIR_AMOUNT :: 10;

ENTITY_MAX :: 2048;
DEFAULT_STACK_SIZE :: 16;

WORLD_DIAMETER :: WORLD_RADIUS * 2;
DAY_LENGTH :: 300.0;
NIGHT_LENGTH :: 120.0;
CYCLE_LENGTH :: DAY_LENGTH + NIGHT_LENGTH;

LOG_VERBOSE :: false;

WORLD_RENDER :: true;
RENDER_BACKGROUND :: true;
DO_WORLD_GEN :: true;

VSYNC :: false;

DEBUG_UI_BOXES :: false;

START_SEED :: 3;

fun_val := 1.0;
show_debug_ui := false;
show_player_coords := false;

TILE_WIDTH :: 16;
BASE_BASE_RADIUS :: TILE_WIDTH * 10.0;
// BASE_OUTER_RADIUS :: TILE_WIDTH * 10.0;

SAVE_FILE :: "save.abs"; //Arcane Binary Save

VERSION :: "v0.8.0";

ConfigMode :: enum
{
	TEST;
	TEST_RELEASE;
	RELEASE;
}

#if !RELEASE
{
	// change this to be whatever you want
	CONFIG_MODE :ConfigMode: .TEST_RELEASE;
}
else
{
	// this forces us into .RELEASE when compiling in release mode
	CONFIG_MODE :ConfigMode: .RELEASE;
}

#if TESTING
{
	TEST_NIGHT_ATTACK :: true;
}

#if CONFIG_MODE == .TEST
{
	// randy: for sicko mode testing, things are quick
	SHIPPING_VALUES :: false;
	DEBUG :: true;
	LOG_ERRORS_BREAK :: true; // TODO
	SHOW_DIAGNOSTICS :: true;
	START_APP_STATE :: AppMode.world;
	IGNORE_MATERIAL_COST :: true;
	DEBUG_UNLOCK_RECIPES :: true;
	SPRINT_MULT :: 1.0;
	DISABLE_NIGHT :: false;
	RANDOMIZE_SEED :: true;
	SKIP_INTRO :: true;
	DISABLE_MONSTERS :: false;
	INVINCIBLE_COREFIRE :: false;
	INVINCIBLE_PLAYER :: false;
	ROB_TESTING :: false;
	AUTO_PICKUP_ITEMS :: true;
	
	TESTING :: true;
}
else #if CONFIG_MODE == .TEST_RELEASE
{
	// randy: used for testing the release mode, but still
	// retaining some helpful test overrides
	//
	SHIPPING_VALUES :: true;
	DEBUG :: true;
	LOG_ERRORS_BREAK :: false;
	SHOW_DIAGNOSTICS :: true;
	START_APP_STATE :: AppMode.world;
	IGNORE_MATERIAL_COST :: false;
	DEBUG_UNLOCK_RECIPES :: false;
	SPRINT_MULT :: 1.0;
	DISABLE_NIGHT :: false;
	RANDOMIZE_SEED :: true;
	SKIP_INTRO :: false;
	DISABLE_MONSTERS :: false;
	INVINCIBLE_COREFIRE :: false;
	INVINCIBLE_PLAYER :: false;
	ROB_TESTING :: false;
	AUTO_PICKUP_ITEMS :: true;
	
	TESTING :: true;
}
else #if CONFIG_MODE == .RELEASE
{
	SHIPPING_VALUES :: true;
	DEBUG :: false;
	LOG_ERRORS_BREAK :: false;
	SHOW_DIAGNOSTICS :: true;
	START_APP_STATE :: AppMode.main_menu;
	IGNORE_MATERIAL_COST :: false;
	DEBUG_UNLOCK_RECIPES :: false;
	SPRINT_MULT :: 1.0;
	DISABLE_NIGHT :: false;
	RANDOMIZE_SEED :: true;
	SKIP_INTRO :: false;
	DISABLE_MONSTERS :: false;
	INVINCIBLE_COREFIRE :: false;
	INVINCIBLE_PLAYER :: false;
	ROB_TESTING :: false;
	AUTO_PICKUP_ITEMS :: true;
	
	TESTING :: false;
}

MAX_FUEL_TIME :: 90.0;

#if !SHIPPING_VALUES
{
	WORLD_RADIUS :: 2000.0;
	BASE_MAX_HEALTH :: 30;
	BASE_WEIGHT :: 100;
	BASE_HOTBAR_COUNT :: 5;
	BASE_INVENTORY_COUNT :: 20;
	INITIAL_DAY_START_TIME :: 60;
	INITIAL_DAYS_SURVIVED :: 0;
	MONSTER_SPAWN_RADIUS :: 200.0;
	MONSTER_AGGRO_RANGE :: WORLD_DIAMETER;
	RESPAWN_LENGTH :: 5.0;
	TREE_HEALTH :: 20;
	DEFAULT_COOK_TIME :: 1.0;
	DEFAULT_FUEL_TIME :: 30.0;
	HIT_DAMAGE :: 10;
	ROCK_GROWTH_TIME :: 0.1;
	GOBBY_DAMAGE :: 10;
	DISABLE_DASH_COOLDOWN :: true;
}
else
{
	// Shipping values!
	//
	// DON'T EDIT THESE FOR TESTING
	//
	WORLD_RADIUS :: 2000.0;
	BASE_MAX_HEALTH :: 30;
	BASE_WEIGHT :: 10;
	BASE_HOTBAR_COUNT :: 5;
	BASE_INVENTORY_COUNT :: 20;
	INITIAL_DAY_START_TIME :: 60;
	INITIAL_DAYS_SURVIVED :: 0;
	MONSTER_SPAWN_RADIUS :: 800.0;
	MONSTER_AGGRO_RANGE :: WORLD_DIAMETER;
	RESPAWN_LENGTH :: 10.0;
	TREE_HEALTH :: 60;
	DEFAULT_COOK_TIME :: 30.0;
	DEFAULT_FUEL_TIME :: 30.0;
	HIT_DAMAGE :: 10;
	ROCK_GROWTH_TIME :: 200.0;
	GOBBY_DAMAGE :: 10;
	DISABLE_DASH_COOLDOWN :: false;
	//
	// DON'T EDIT THESE FOR TESTING
	//
}