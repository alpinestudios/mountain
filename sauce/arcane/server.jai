VERSION :: "0.0.0.0";

Server :: struct
{
	server_ready: bool;
	listen_sock: HSteamListenSocket;
	server_id: u64;
	poll_group: HSteamNetPollGroup;
}

server_create :: (server: *Server)
{
	SteamGameServer_Init(0, 0, 0, 0, 1, VERSION);
	assert(SteamGameServer() != null, "Failed to init game server.");
	
	networking_sockets = SteamGameServerNetworkingSockets();
	
	SetModDir(SteamGameServer(), "");
	SetProduct(SteamGameServer(), "ArcaneSurvival");
	SetGameDescription(SteamGameServer(), "Arcane Survival");
	
	LogOnAnonymous(SteamGameServer());
	
	InitRelayNetworkAccess(SteamNetworkingUtils());
	
	server.listen_sock = CreateListenSocketP2P(networking_sockets, 0, 0, null);
	assert(server.listen_sock != k_HSteamListenSocket_Invalid, "Invalid listen socket");
	
	server.poll_group = CreatePollGroup(networking_sockets);
	assert(server.poll_group != k_HSteamNetPollGroup_Invalid, "Invalid poll group");
}

server_destroy :: (server: *Server)
{
	CloseListenSocket(networking_sockets, server.listen_sock);
}

server_update :: (server: *Server)
{
	assert(networking_sockets == networking_sockets, "Object mismatch? This should always be equal");
	
	steam_pipe := SteamGameServer_GetHSteamPipe();
	SteamAPI_ManualDispatch_RunFrame(steam_pipe);
	
	callback: CallbackMsg_t;
	
	while SteamAPI_ManualDispatch_GetNextCallback(steam_pipe, *callback)
	{
		defer SteamAPI_ManualDispatch_FreeLastCallback(steam_pipe);
		
		is_call_result := callback.m_iCallback == SteamAPICallCompleted_t.k_iCallback;
		if is_call_result
		{
			//log("call result");
		}
		else
		{
			server_callback(server, callback);
		}
	}
}

#scope_module

networking_sockets : *ISteamNetworkingSockets;

server_callback :: (server: *Server, cb: CallbackMsg_t)
{
	print("SERVER | ");
		
	callback_id : CallbackID = xx cb.m_iCallback;
	callback_data : *u8 = cb.m_pubParam;
	if callback_id ==
	{
		case .SteamServersConnected_t;
		server.server_ready = true;
		server.server_id = GetSteamID(SteamGameServer());
		log("SteamServersConnected with id: %", server.server_id);
		
		
		case .SteamNetConnectionStatusChangedCallback_t;
		connection_status_changed(server, xx callback_data);
		
		case;
		log("callback_id: %", callback_id);
	}
}

connection_status_changed :: (server: *Server, info: *SteamNetConnectionStatusChangedCallback_t)
{
	state : ESteamNetworkingConnectionState = info.m_info.State;
	log("%", state);
	if state ==
	{
		// CONNECTING
		case .k_ESteamNetworkingConnectionState_Connecting;
		desc := to_string(info.m_info.m_szConnectionDescription.data);
		log("connection request from %", desc);
		
		connection : HSteamNetConnection = info.Conn;
		
		// attempt connection
		result : EResult = AcceptConnection(networking_sockets, connection);
		if result != .k_EResultOK
		{
			CloseConnection(networking_sockets, connection, 0, null, false);
			log("Can't accept connection. Already closed?");
			return;
		}
		
		// assign to the poll group
		if !SetConnectionPollGroup(networking_sockets, connection, server.poll_group)
		{
			CloseConnection(networking_sockets, connection, 0, null, false);
			log("Failed to set poll group");
			return;
		}
	}
}



#import "Basic";
// #import "String";
// #import,file "../recycle.jai";
// #import "Windows";

#import "Steam"(verbose=true, use_flat_api=true);