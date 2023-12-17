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

Z_FARBG :: 96;
Z_MIDBG :: 90;
Z_NEARBG :: 80;

Z_BACK_WALL :: 23;
Z_BASE_STONE :: 22.8;
Z_PORTAL :: 22.75;
Z_SIDE_WALL :: 22.5;
Z_WORLD_STRUCTURE :: 22.3;
Z_TREE :: 22;
Z_ROOTS :: 21;
Z_TALL_GRASS :: 20;
Z_PLANTS :: 16;
Z_STRUCTURES :: 15;
Z_ENTITY_VFX :: 12.0;
Z_TRAPS :: 11;
Z_PLAYER :: 10;
Z_MONSTER :: 9;
Z_PROJECTILES :: 8;
Z_ENTITY_PFX ::7.0;
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
// randy: NOTE - I put this in here because it feels kinda weird now that
// we have an open world and aren't just moving to one side.
// Could defs add it back in and adjust it better, but idk how to tune it properly.
// I need variables to tune the parameters. 06-12-2023-143401
DISABLE_LOOK_AHEAD :: true;

max_player_move_speed :: 100.0;
player_move_tilt :: 4.0;
scuffed_player_scale :: 0.6;
PLAYER_ACCEL :: 1600.0;
PLAYER_DECEL :: 1000.0;
DASH_DURATION :: 0.1;
DASH_COOLDOWN :: 1;
DASHING_MULT :: 8.0;
PLAYER_MAX_HUNGER :: 12;
HUNGER_TIMER_DURATION :: 30.0;
DASH_BASE_COUNT :: 1;

DAMAGE_TIMER_LENGTH :: 0.3;

STRUCTURE_REPAIR_AMOUNT :: 10;

// todo - tweak variables
HIT_SQUISH_TIMER_LENGTH :: 0.2;
LAND_ANIM_LENGTH :: 0.2;

ENTITY_MAX :: 2048;
DEFAULT_STACK_SIZE :: 16;

WORLD_LENGTH :: 4000.0;
WORLD_CENTER :: WORLD_LENGTH / 2.0;
DAY_LENGTH :: 300.0;
NIGHT_LENGTH :: 120.0;
CYCLE_LENGTH :: DAY_LENGTH + NIGHT_LENGTH;

LOG_VERBOSE :: false;
WORLD_RENDER :: true;
RENDER_BACKGROUND :: true;
RENDER_PARALLAX :: true;
RENDER_SKY :: true;
DO_WORLD_GEN :: true;
DISABLE_BLOCK :: true;

VSYNC :: false;

DEBUG_UI_BOXES :: false;
CHECK_FOR_FUNNY_BUSINESS :: false;

START_SEED :: 3;

fun_val := 1.0;
show_debug_ui := false;
show_player_coords := false;

TILE_WIDTH :: 16;
BASE_BASE_RADIUS :: TILE_WIDTH * 10.0;
// BASE_OUTER_RADIUS :: TILE_WIDTH * 10.0;
LOW_HEALTH_THRESHOLD :: GOBBY_DAMAGE * 2.0;

SAVE_FILE :: "save.txt"; // let's not sugar coat this lol, it's a text file
SETTINGS_FILE :: "settings.txt";
DEBUG_CONSOLE :: false;

VERSION :: "v0.8.3";

test_release :: false;
#if RELEASE || test_release
{
	DEBUG :: false;
	LOG_ERRORS_BREAK :: false;
	START_APP_STATE :: AppMode.main_menu;
	GAMEANALYTICS :: true;
}
else
{
	// change this to be whatever you want
	DEBUG :: true;
	LOG_ERRORS_BREAK :: false;
	START_APP_STATE :: AppMode.world;
	GAMEANALYTICS :: false;
}

SHOW_DIAGNOSTICS :: true;
RANDOMIZE_SEED :: true;
SKIP_INTRO :: false;
DISABLE_HUNGER_TICK :: false;
	

// randy: LESSON
// HAVE AS LITTLE COMPLEXITY IN THE RELEASE OVERRIDES AS POSSIBLE.
// If you want to override shipping values, do it via debug tooling in the game. Otherwise there will be too many untested paths if things can get completely disabled. The prime example was in the earlier DISABLE_RECIPE_COST, it adds an extra layer of complexity since we had a bunch of overrides in the implementation of taking away the items when crafting shit.
// The better solution to this problem, is to just spawn in a bunch of items. That way we can actually test the path properly every single time and there's no nasty untested bugs lurking around in the release override.

MAX_FUEL_TIME :: 90.0;
BASE_HOTBAR_COUNT :: 5;
BASE_INVENTORY_COUNT :: 10;
BASE_MAX_HEALTH :: 30;
INITIAL_DAY_START_TIME :: 60;
INITIAL_DAYS_SURVIVED :: 0;
MONSTER_SPAWN_RADIUS :: 800.0;
MONSTER_AGGRO_RANGE :: WORLD_LENGTH;
RESPAWN_LENGTH :: 10.0;
TREE_HEALTH :: 60;
DEFAULT_COOK_TIME :: 30.0;
DEFAULT_FUEL_TIME :: 30.0;
HIT_DAMAGE :: 10;
ROCK_GROWTH_TIME :: 120.0;
GOBBY_DAMAGE :: 10;
DISABLE_DASH_COOLDOWN :: false;
DEFAULT_CRAFT_TIME :: 10.0;