#import "Basic";
#import "String";
#import,file "../recycle.jai";
#import "Windows";

#import "Steam"(verbose=true, use_flat_api=true);

	/*
	assert(GameNetworkingSockets.Initialize(), "Failed to init GameNetworkingSockets.");
	defer GameNetworkingSockets.Finalize();
	
	// Start listening socket
	serverLocalAddr : IPAddr;
	IPAddr.Clear(*serverLocalAddr);
	serverLocalAddr.m_port = PORT;
	
	options : [1] ConfigValue;

	// Set callback handler
	ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx server_connection_status_changed);

	// Create Listen Socket
	listen_socket := Sockets.CreateListenSocketIP(*serverLocalAddr, options.count, options.data);
	if listen_socket == .Invalid
	{
		log_error("CreateListenSocketIP() failed!");
		assert(false);
		return;
	}

	// Create Poll Group
	server.poll_group = Sockets.CreatePollGroup();
	if server.poll_group == .Invalid
	{
		Sockets.CloseListenSocket(listen_socket);
		log_error("CreatePollGroup() failed!");
		assert(false);
		return;
	}

	log("Server listening on port %", PORT);
	
	
	*/

Server :: struct
{
	//poll_group: PollGroup;
}
server : Server;

APP_ID :u32: 2571560;
VERSION :: "0.0.0.0";

// k_steamIDNonSteamGS CSteamID( 2, 0, k_EUniverseInvalid, k_EAccountTypeInvalid )
steam_id 

main :: ()
{
	// assert(SteamAPI_Init(), "Failed to init Steam");
	// defer SteamAPI_Shutdown();
	
	// k_ESteamNetworkingConfig_IP_AllowWithoutAuth
	
	// socket for listening for incoming connections
	
	// SteamAPI_ManualDispatch_Init
	
	
	// init game sever n shit
	SteamGameServer_Init(0, 0, 24069, 24000, 1, VERSION);
	assert(SteamGameServer() != null, "Failed to init game server.");
	SteamAPI_ManualDispatch_Init();
	
	LogOnAnonymous(SteamGameServer());
	InitRelayNetworkAccess(SteamNetworkingUtils());
	
	id := GetSteamID(SteamGameServer());
	log("%", id);
	
	sock := CreateListenSocketP2P(SteamGameServerNetworkingSockets(), 0, 0, null);
	// defer CloseListenSocket(SteamGameServerNetworkingSockets(), sock);
	assert(sock != k_HSteamListenSocket_Invalid);
	
	poll_group := CreatePollGroup(SteamGameServerNetworkingSockets());
	
	
	// id_local: SteamNetworkingIdentity;
	// Clear(*id_local);
	// SetLocalHost(*id_local);
	
	// connection := ConnectP2P(*id_local, 0, 0, null);
	// if connection == k_HSteamNetConnection_Invalid
	// {
	// 	assert(false, "invalid connection");
	// }
	
	incoming_msgs : [1024] *SteamNetworkingMessage_t;
	while true
	{
		SteamMessageLoop();
		
		// msg_count := ReceiveMessagesOnConnection(connection, incoming_msgs.data, incoming_msgs.count);
		// assert(msg_count != -1, "a fuckie wuckie happen");
		
		// for 0..msg_count-1
		// {   
		// 	message : *SteamNetworkingMessage_t = incoming_msgs[it];
		// 	defer Release(message);

		// 	msg : string;
		// 	msg.data  = message.m_pData;
		// 	msg.count = message.m_cbSize;
			
		// 	log(msg);
		// }
		
		// memset(incoming_msgs.data, 0, msg_count * size_of(*SteamNetworkingMessage_t));
	}
}

SteamMessageLoop :: ()
{
	// this shouldn't do anything since we're the server
	// for message: SteamAPI_Callbacks
	// {
	// 	assert(false);
	// }

	// SteamGameServer_Callbacks
	for msg, is_call_result: SteamGameServer_Callbacks
	{
		log("\nCB: callback_id: % | result_id: % - %", msg.callback_id, msg.call_result_id, is_call_result);
		
		// if false
		// {
		// 	log("\nGameServer: Handling call result %", formatInt(message.caller, base=16));
		// 	if message.call_result_id ==
		// 	{
		// 		case .NumberOfCurrentPlayers_t;
				
		// 	}
		// }
		// else
		// {
		// 	log("\nGameServer: Callback %", message.callback_id);
		// 	if message.callback_id ==
		// 	{
		// 		case .GameOverlayActivated_t;
				
		// 	}
		// }
	}
}

/*
relay_status :: (info: SteamRelayNetworkStatus_t)
{
	log("relay_status: % - %", info.m_eAvail, to_string(info.DebugMsg.data));
	// if info.m_eAvail == .k_ESteamNetworkingAvailability_Current
	// {
	// 	st.network_active = true;
	// }
}
@SteamCallback

client_connection_status_changed :: (info : SteamNetConnectionStatusChangedCallback_t)
{
	log("%", info.m_info.m_eState);
	if info.m_info.m_eState ==
	{
		case .k_ESteamNetworkingConnectionState_Connecting;
		{
			viewOfConnectionDecription := to_string(info.m_info.m_szConnectionDescription.data);
 		print("Connection request from %\n", viewOfConnectionDecription);
 		
 		res := AcceptConnection(info.Conn);
 		if res != .k_EResultOK
 		{
 			CloseConnection(info.Conn, 0, null, false);
 			log("Can't accept connection: %", res);
 			return;
 		}
 		
 		
		}
	}
}
@SteamCallback
*/

/*
server_connection_status_changed :: (info : *ConnectionStatusChanged) -> void #c_call
{
	cont : Context;
 push_context cont
 {
 	log("%", info.m_info.m_eState);
 	if info.m_info.m_eState ==
 	{
 		case .Connecting;
 		// todo in future - assert that we aren't already in the client list
 		
 		viewOfConnectionDecription := to_string(info.m_info.m_szConnectionDescription.data);
 		print("Connection request from %\n", viewOfConnectionDecription);

 		// A client is attempting to connect
 		// Try to accept the connection.
 		if (Sockets.AcceptConnection(info.m_conn) != .OK)
 		{
 			// This could fail.  If the remote host tried to connect, but
 			// then disconnected, the connection may already be half closed.
 			// Just destroy whatever we have on our side.
 			Sockets.CloseConnection(info.m_conn, 0, null, false);
 			print("Can't accept connection.  (It was already closed?)\n");
 			return;
 		}

 		// Assign to the poll group
 		if (!Sockets.SetConnectionPollGroup(info.m_conn, server.poll_group))
 		{
 			Sockets.CloseConnection(info.m_conn, 0, null, false);
 			print("Failed to set poll group\n");
 			return;
 		}
 	}
 }
} @SteamCallback
*/