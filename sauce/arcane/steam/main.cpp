#include "steam_gameserver.h"
#include "stddef.h"
#include "stdlib.h"

#define function extern "C" __declspec(dllexport)

#define VERSION "0.0.0.0"

// this shouldn't be needed, we're an API, the caller handles dis shit
//#define assert(condition, message) if (!(condition)) { fprintf(stderr, "\nAssertion failed: %s\n%s - in %s:%d\n", (#condition), message, __FILE__, __LINE__); __debugbreak(); (*(volatile int *)0 = 0); }

#define log(str, ...) printf(str, __VA_ARGS__); printf("\n");


function uint64_t non_steam_gs()
{
	return k_steamIDNonSteamGS.ConvertToUint64();
}