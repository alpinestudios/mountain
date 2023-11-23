#include "ga_include/GameAnalytics.h"

#define GAME_KEY "606a006e99f35866c0ad1cfe4389de41"
#define SECRET_KEY "70622be97ffc5d53ac1b3793697cae00702d2a93"

void ga_init()
{
	//gameanalytics::GameAnalytics::configureUserId("Fix");
	gameanalytics::GameAnalytics::configureBuild("alpha 0.9.0");
	gameanalytics::GameAnalytics::initialize(GAME_KEY, SECRET_KEY);
	gameanalytics::GameAnalytics::startSession();
	//gameanalytics::GameAnalytics::addDesignEvent("testEvent");
}

/*
void ga_send_game_start()
{
	s
}
*/
void ga_shutdown()
{
	gameanalytics::GameAnalytics::endSession();
}
