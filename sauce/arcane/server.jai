/*

## structure advice from cdawg

#1 - dead simple startup
client:
deadass just read state from server
send inputs to server

server:
recieve inputs from client
sim everything lol
send world state to all clients


#2 - slightly more foolproof version
client:
simulate only local player
sends player state and inputs

server:
Simulates
Applies received player state, simulates
Sends the full gamestate 60 times per second.
Client:
on receive state from server:
    my_state = gameworld.player;
    update_game_state(server_state);
    gameworld.player = my_state;




serialize_gamestate_to_bytes();
update_gamestate_from_bytes();

update(dt)
{
	only_sim_player_path
}

---------

STEAM NETWORKING SETUP TIME

[ ] merge into one
[ ] 

*/


GameState :: struct
{
	connected_to_steam: bool;
	connection: HSteamNetConnection;
	//poll_group: PollGroup;
}
st : GameState;

APP_ID :u32: 2571560;
VERSION :: "0.0.0.0";

// arc_steam :: #library "main";
// non_steam_gs :: () -> u64 #foreign arc_steam;

HostState :: enum
{
	dual;
	server;
	client;
}

// this is like a test app, we handle our own loop and shit but call out to client/server stuff
main :: ()
{
	host_state := HostState.server;
	
	server_id : u64;
	
	args := get_command_line_arguments();
	for args
	{
		if it == "--server" then host_state = .server;
		if it == "--client" then host_state = .client;
		
		if host_state == .client && it_index == 2
		{
			server_id = xx string_to_int(it);
		}
	}
	
	is_server := host_state == .dual || host_state == .server;
	is_client := host_state == .dual || host_state == .client;
	
	assert(SteamAPI_Init(), "Failed to init Steam");
	defer SteamAPI_Shutdown();
	SteamAPI_ManualDispatch_Init();
	
	InitRelayNetworkAccess(SteamNetworkingUtils());
	
	// init game sever
	if is_server
	{
		SteamGameServer_Init(0, 0, 0, 0, 1, VERSION);
		assert(SteamGameServer() != null, "Failed to init game server.");
		
		SetModDir(SteamGameServer(), "");
		SetProduct(SteamGameServer(), "ArcaneSurvival");
		SetGameDescription(SteamGameServer(), "Arcane Survival");
		
		LogOnAnonymous(SteamGameServer());
		
		sock := CreateListenSocketP2P(SteamGameServerNetworkingSockets(), 0, 0, null);
		// defer CloseListenSocket(SteamGameServerNetworkingSockets(), sock);
		assert(sock != k_HSteamListenSocket_Invalid);
		
		poll_group := CreatePollGroup(SteamGameServerNetworkingSockets());
	}
	
	if is_client
	{
		sock := CreateListenSocketP2P(SteamNetworkingSockets(), 0, 0, null);
		assert(sock != k_HSteamListenSocket_Invalid);
	}
	
	
	// incoming_msgs : [1024] *SteamNetworkingMessage_t;
	while true
	{
		if is_client then ClientUpdate();
		if is_server then ServerUpdate();
		
		// connect
		if st.connection == k_HSteamNetConnection_Invalid
		if host_state ==
		{
			case .dual;
			if st.connected_to_steam
			{
				id_local: SteamNetworkingIdentity;
				id := GetSteamID(SteamGameServer());
				log("Connecting to id: %", id);
				SetSteamID(*id_local, id);
				
				st.connection = ConnectP2P(SteamNetworkingSockets(), *id_local, 0, 0, null);
				assert(st.connection != k_HSteamNetConnection_Invalid, "invalid connection");
			}
			
			case .client;
			if st.connected_to_steam
			{
				id_local: SteamNetworkingIdentity;
				log("Connecting to id: %", server_id);
				SetSteamID(*id_local, server_id);
				
				st.connection = ConnectP2P(SteamNetworkingSockets(), *id_local, 0, 0, null);
				assert(st.connection != k_HSteamNetConnection_Invalid, "invalid connection");
			}
		}
	}
}

ClientUpdate :: ()
{
	/*
	// todo - out with the for expansion!
	
	steam_pipe := SteamAPI_GetHSteamPipe();
	SteamAPI_ManualDispatch_RunFrame(steam_pipe);
	
	callback: CallbackMsg_t;
	
	while SteamAPI_ManualDispatch_GetNextCallback(steam_pipe, *callback)
	{
		defer SteamAPI_ManualDispatch_FreeLastCallback(steam_pipe);
		
		is_call_result := callback.m_iCallback == SteamAPICallCompleted_t.k_iCallback
		if is_call_result
		{
			
		}
		else
		{
			
		}
	}
	*/
	
	for msg, is_call_result: SteamAPI_Callbacks
	{
		assert(!is_call_result);
		
		print("CLIENT | ");
		
		if msg.callback_id ==
		{
			case .SteamRelayNetworkStatus_t;
			info := cast(*SteamRelayNetworkStatus_t) msg.data;
			log("relay_status: % - %", info.m_eAvail, to_string(info.DebugMsg.data));
			
			if info.m_eAvail == .k_ESteamNetworkingAvailability_Current
			{
				st.connected_to_steam = true;
				log("connected_to_steam");
			}
			
			case .SteamNetConnectionStatusChangedCallback_t;
			info := cast(*SteamNetConnectionStatusChangedCallback_t) msg.data;
			log("connection_status_changed: %", info.m_info.m_eState);
			
			case;
			log("callback_id: %", msg.callback_id);
		}
	}
}

ServerUpdate :: ()
{
	for msg, is_call_result: SteamGameServer_Callbacks
	{
		assert(!is_call_result);
		
		print("SERVER | ");
		
		if msg.callback_id ==
		{
			case .SteamServersConnected_t;
			st.connected_to_steam = true;
			
			id := GetSteamID(SteamGameServer());
			log("SteamServersConnected with id: %", id);
			
			case .SteamNetConnectionStatusChangedCallback_t;
			log("\n!!!WE WANT THIS!!!!\n");
			
			case;
			log("callback_id: %", msg.callback_id);
		}
	}
}

#import "Basic";
#import "String";
#import,file "../recycle.jai";
#import "Windows";

#import "Steam"(verbose=true, use_flat_api=true);


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