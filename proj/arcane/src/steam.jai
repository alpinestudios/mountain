
SteamState :: struct
{
	initialized: bool;
	logged_in: bool;
	sockets: *ISteamNetworkingSockets;
	user_stats: *ISteamUserStats;
	user_id: CSteamID;
}

g_steamState: SteamState;

steam_init :: ()
{
	if !SteamAPI_Init() then return;
	SteamAPI_ManualDispatch_Init();

	g_steamState.initialized = true;
	g_steamState.sockets = SteamNetworkingSockets();

	SetWarningMessageHook(SteamClient(), xx steam_warning_hook);


	g_steamState.user_stats = SteamUserStats();
	g_steamState.logged_in = RequestCurrentStats(g_steamState.user_stats);
}

steam_shutdown :: ()
{
	SteamAPI_Shutdown();
}

steam_client_update :: ()
{
	assert(g_steamState.sockets == SteamNetworkingSockets(), "Steam Sockets Object mismatch? This should always be equal");
	
	steam_pipe := SteamAPI_GetHSteamPipe();
	SteamAPI_ManualDispatch_RunFrame(steam_pipe);

	callback: CallbackMsg_t;

	while SteamAPI_ManualDispatch_GetNextCallback(steam_pipe, *callback)
	{
		defer SteamAPI_ManualDispatch_FreeLastCallback(steam_pipe);
		
		is_call_result := callback.m_iCallback == SteamAPICallCompleted_t.k_iCallback;
		if is_call_result
		{
			log("call result");
		}
		else
		{
			steam_client_callback(callback);
		}
	}
}

steam_client_callback :: (cb: CallbackMsg_t)
{
	print("STEAM CLIENT | ");
	
	callback_id : CallbackID = xx cb.m_iCallback;
	callback_data : *u8 = cb.m_pubParam;
	if callback_id ==
	{
		case .SteamRelayNetworkStatus_t;
		info := cast(*SteamRelayNetworkStatus_t) callback_data;
		log("relay_status: % - %", info.m_eAvail, to_string(info.DebugMsg.data));
		
		if info.m_eAvail == .k_ESteamNetworkingAvailability_Current
		{
			// st.connected_to_steam = true;
			log("client connected_to_steam");
		}
		
		case .SteamNetConnectionStatusChangedCallback_t;
		info := cast(*SteamNetConnectionStatusChangedCallback_t) callback_data;
		log("connection_status_changed: %", info.m_info.m_eState);
		
		case;
		log("callback_id: %", callback_id);

		case .UserStatsReceived_t;
		{
			ustats := cast(*UserStatsReceived_t) callback_data;
			log("User stats recieved!");
			g_steamState.user_id = ustats.SteamIDUser;
		}
	}
}

steam_warning_hook :: (severity: int, debug_text: *u8) -> void #c_call
{
	cont : Context;
	push_context cont
	{
 		log("WARNING HOOK: %", to_string(debug_text));
 		//assert(severity < 1, "Fatal Steam Error");
	}
}

steam_unlock_achievement :: (achievement_id: string)
{
	SetAchievement(g_steamState.user_stats, xx achievement_id.data);
	StoreStats(g_steamState.user_stats);
}

#import "Steam"(verbose=true, use_flat_api=true);

ACH_ID_BASE_TOTEM_ACTIVATED :: "base_totem_activated";