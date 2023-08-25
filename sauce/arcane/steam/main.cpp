#include "steam_gameserver.h"
#include "stddef.h"
#include "stdlib.h"

#define function static

#define VERSION "0.0.0.0"

#define assert(condition, message) if (!(condition)) { fprintf(stderr, "\nAssertion failed: %s\n%s - in %s:%d\n", (#condition), message, __FILE__, __LINE__); __debugbreak(); (*(volatile int *)0 = 0); }

#define log(str, ...) printf(str, __VA_ARGS__); printf("\n");

extern "C" void __cdecl SteamAPIDebugTextHook( int nSeverity, const char *pchDebugText )
{
	// if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
	// if you add -debug_steamapi to the command-line, a lot of extra informational messages will also be sent
	assert(nSeverity < 1, pchDebugText);
}

// manual dispatch example
/*
static void run_steam_callbacks()
{
	HSteamPipe pipe = SteamGameServer_GetHSteamPipe();
	SteamAPI_ManualDispatch_RunFrame(pipe);
	CallbackMsg_t callback;
	while (SteamAPI_ManualDispatch_GetNextCallback(pipe, &callback))
	{
		// Check for dispatching API call results
		if ( callback.m_iCallback == SteamAPICallCompleted_t::k_iCallback )
		{
			log("CALL RESULT!");
			
			SteamAPICallCompleted_t *pCallCompleted = (SteamAPICallCompleted_t *)callback.m_pubParam;
			void *pTmpCallResult = malloc( pCallCompleted->m_cubParam );
			bool bFailed;
			if ( SteamAPI_ManualDispatch_GetAPICallResult( pipe, pCallCompleted->m_hAsyncCall, pTmpCallResult, pCallCompleted->m_cubParam, pCallCompleted->m_iCallback, &bFailed ) )
			{
				// Dispatch the call result to the registered handler(s) for the
				// call identified by pCallCompleted->m_hAsyncCall
			}
			free( pTmpCallResult );
		}
		else
		{
			log("CALLBACK YEEEEEEEET");
			// Look at callback.m_iCallback to see what kind of callback it is,
			// and dispatch to appropriate handler(s)
			switch (k_iCallback)callback.m_iCallback
			{
				
			}
		}
		
		SteamAPI_ManualDispatch_FreeLastCallback( pipe );
	}
}
*/

class BullshitClass
{
public:
	
	STEAM_GAMESERVER_CALLBACK(BullshitClass, network_status_change, SteamRelayNetworkStatus_t);
};

void BullshitClass::network_status_change(SteamRelayNetworkStatus_t* info)
{
	log("relay_status: %d - %s", info->m_eAvail, info->m_debugMsg);
}


int main(int argc, const char **argv)
{
	
	// cmdline args
	bool is_server = false;
	for (int idx_arg = 1; idx_arg < argc; ++idx_arg)
	{
		const char *arg = argv[idx_arg];
		
		if (!strcmp(arg, "--server"))
		{
			is_server = true;
		}
	}
	
	// STEAM TIME BAYBEE
	if (is_server)
	{
		log("Starting up server...\n");
		
		assert(SteamAPI_Init(), "Failed to init SteamAPI");
		
		assert(SteamGameServer_Init(0, 0, 0, eServerModeNoAuthentication, VERSION), "Failed to init server");
		
		//SteamAPI_ManualDispatch_Init();
		
		SteamGameServer()->LogOnAnonymous();
		SteamNetworkingUtils()->InitRelayNetworkAccess();
		
		auto m_hListenSocket = SteamGameServerNetworkingSockets()->CreateListenSocketP2P(0, 0, nullptr);
		auto m_hNetPollGroup = SteamGameServerNetworkingSockets()->CreatePollGroup();
		
		new BullshitClass();
		
		while (true)
		{
			//run_steam_callbacks();
			SteamAPI_RunCallbacks();
			SteamGameServer_RunCallbacks();
			
		}
		
		SteamGameServer_Shutdown();
	}
	else
	{
		// SteamClient()->SetWarningMessageHook( &SteamAPIDebugTextHook );
	}
	
	log("Exiting...");
	return 0;
}