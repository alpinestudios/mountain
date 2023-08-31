
/*

MULTIPLAYER CONTEXT FROM LAST ATTEMPT:

bake the ui down into actions

just get the gameplay in. get the player moving around
 
you click on an item in a chest, that action gets sent to the server
the server then does it, applying it to the game state, and you recieve
it back


-------- multiplayer structure advice from cdawg

serialize_gamestate_to_bytes();
update_gamestate_from_bytes();

update(dt)
{
	only_sim_player_path
}

#1 - dead simple startup
client:
deadass just read state from server
send inputs to server

server:
recieve inputs from client
sim everything lol
send world state to all clients

^ DO THIS FIRST!
crawl before walk.



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


// #2 (pseudo)
// simulate only local player
	// step him thru the world
	// build the UI from inputs n shit

// send player state & inputs to server

// server is always simulating
// server recieves update packet from player1
	// overrides the player's state
	// applies inputs based on now correctly position state
		// build UI as well, with applied inputs

// server sends now fullied updated game state to all players

// recieves GS from server
	// copy in game state (except for our player)


*/




// compile this file into a .exe for a dedicated server
// otherwise, just import as a module and use it as an internal server that spins up alongside the SteamAPI

VERSION :: "0.0.0.0";

Server :: struct
{
	server_ready: bool;
	listen_sock: HSteamListenSocket;
	server_id: u64;
	poll_group: HSteamNetPollGroup;
	
	connected_clients: [8]HSteamNetConnection;
}

server_create :: (server: *Server)
{
	SteamGameServer_Init(0, 0, 0, 0, 1, VERSION);
	assert(SteamGameServer() != null, "Failed to init game server.");
	
	server_networking_sockets = SteamGameServerNetworkingSockets();
	
	SetModDir(SteamGameServer(), "");
	SetProduct(SteamGameServer(), "ArcaneSurvival");
	SetGameDescription(SteamGameServer(), "Arcane Survival");
	
	LogOnAnonymous(SteamGameServer());
	
	InitRelayNetworkAccess(SteamNetworkingUtils());
	
	server.listen_sock = CreateListenSocketP2P(server_networking_sockets, 0, 0, null);
	assert(server.listen_sock != k_HSteamListenSocket_Invalid, "Invalid listen socket");
	
	server.poll_group = CreatePollGroup(server_networking_sockets);
	assert(server.poll_group != k_HSteamNetPollGroup_Invalid, "Invalid poll group");
}

server_destroy :: (server: *Server)
{
	CloseListenSocket(server_networking_sockets, server.listen_sock);
}

server_update :: (server: *Server)
{
	assert(server_networking_sockets == SteamGameServerNetworkingSockets(), "Object mismatch? This should always be equal");
	
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

server_networking_sockets : *ISteamNetworkingSockets;

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
		
		// is there enough slots?
		connection_slot := get_free_connection_slot(server);
		if connection_slot == null
		{
			CloseConnection(server_networking_sockets, connection, 0, null, false);
			log("Not enough server slots");
			return;
		}
		
		// attempt connection
		result : EResult = AcceptConnection(server_networking_sockets, connection);
		if result != .k_EResultOK
		{
			CloseConnection(server_networking_sockets, connection, 0, null, false);
			log("Can't accept connection. Already closed?");
			return;
		}
		
		// assign to the poll group
		if !SetConnectionPollGroup(server_networking_sockets, connection, server.poll_group)
		{
			CloseConnection(server_networking_sockets, connection, 0, null, false);
			log("Failed to set poll group");
			return;
		}
		
		// we're connected!
		<<connection_slot = connection;
		
		msg := "!! LIGMA !!\n\n";
		SendMessageToConnection(server_networking_sockets, connection, msg.data, xx msg.count, xx k_nSteamNetworkingSend_Reliable, null);
	}
}

get_free_connection_slot :: (server: *Server) -> *HSteamNetConnection
{
	for * server.connected_clients
		if <<it == 0 then return it;
	return null;
}

#import "Basic";
// #import "String";
// #import,file "../recycle.jai";
// #import "Windows";

#import "Steam"(verbose=true, use_flat_api=true);

//
// DEDICATED SERVER
//

main :: ()
{
	log("balls");
}