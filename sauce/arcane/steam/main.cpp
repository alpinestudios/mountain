#include "steam_gameserver.h"
#include "stddef.h"

#define function static

#define VERSION "0.0.0.0"

#define assert(condition, message) if (!(condition)) { fprintf(stderr, "\nAssertion failed: %s\n%s - in %s:%d\n", (#condition), message, __FILE__, __LINE__); __debugbreak(); (*(volatile int *)0 = 0); }

#define log(str, ...) printf("%\n", str, __VA_ARGS__)


class BullshitClass
{
public:
	
	BullshitClass()
	{
		assert(SteamGameServer_Init(0, 0, 0, eServerModeNoAuthentication, VERSION), "Failed to init");
		
		SteamGameServer()->LogOnAnonymous();
		SteamNetworkingUtils()->InitRelayNetworkAccess();
		
		auto m_hListenSocket = SteamGameServerNetworkingSockets()->CreateListenSocketP2P(0, 0, nullptr);
		auto m_hNetPollGroup = SteamGameServerNetworkingSockets()->CreatePollGroup();
	}
	
	void Update()
	{
		SteamGameServer_RunCallbacks();
	}
	
	STEAM_GAMESERVER_CALLBACK(BullshitClass, net_status, SteamRelayNetworkStatus_t);
	STEAM_GAMESERVER_CALLBACK(BullshitClass, OnNetConnectionStatusChanged, SteamNetConnectionStatusChangedCallback_t);
};

void BullshitClass::net_status(SteamRelayNetworkStatus_t* status)
{
	log("YEET");
}

void BullshitClass::OnNetConnectionStatusChanged(SteamNetConnectionStatusChangedCallback_t* pCallback)
{
	log("YEET");
}


// todo - manual callbacks
// FUCK I HATE THIS FUCKING CUNTING OOP STEAM API SUCK MY FUCKING LEFT KNUT YOU FUCK


extern "C" void __cdecl SteamAPIDebugTextHook( int nSeverity, const char *pchDebugText )
{
	// if you're running in the debugger, only warnings (nSeverity >= 1) will be sent
	// if you add -debug_steamapi to the command-line, a lot of extra informational messages will also be sent
	assert(nSeverity < 1, pchDebugText);
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
		
		auto test = new BullshitClass();
		
		while (true)
		{
			test->Update();
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