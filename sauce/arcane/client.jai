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

[x] merge into one .exe
[x] get the connection coming thru
[x] abstract out the server so it can be internal or external
[x] connect accept
[x] exchange a packet :)

*/




GameState :: struct
{
	connection: HSteamNetConnection;
	internal_server: bool;
	server: Server;
}
st : GameState;

client_networking_sockets : *ISteamNetworkingSockets;

hook :: (severity: int, debug_text: *u8) -> void #c_call
{
	cont : Context;
 push_context cont
 {
 	log("WARNING HOOK: %", to_string(debug_text));
 	//assert(severity < 1, "Fatal Steam Error");
 }
}

APP_ID :u32: 2571560;


// arc_steam :: #library "main";
// non_steam_gs :: () -> u64 #foreign arc_steam;

// this is like a test app, we handle our own loop and shit but call out to client/server stuff
main :: ()
{
	connect_to_server_id : u64;
	args := get_command_line_arguments();
	for args
	{
		if it == "--internal" then st.internal_server = true;
		
		if !st.internal_server && it_index == 1
		{
			connect_to_server_id = xx string_to_int(it);
		}
	}
	
	assert(SteamAPI_Init(), "Failed to init Steam");
	defer SteamAPI_Shutdown();
	SteamAPI_ManualDispatch_Init();
	
	client_networking_sockets = SteamNetworkingSockets();
	
	SetWarningMessageHook(SteamClient(), xx hook);
	
	InitRelayNetworkAccess(SteamNetworkingUtils());
	
	// init game sever
	if st.internal_server then server_create(*st.server);
	
	// client listening sock
	sock := CreateListenSocketP2P(client_networking_sockets, 0, 0, null);
	assert(sock != k_HSteamListenSocket_Invalid);
	
	incoming_msgs : [1024] *SteamNetworkingMessage_t;
	while true
	{
		client_update();
		if st.internal_server then server_update(*st.server);
		
		// connect to internal server
		if st.server.server_ready && st.connection == k_HSteamNetConnection_Invalid
		{
			id_local: SteamNetworkingIdentity;
			log("Connecting to id: %", st.server.server_id);
			SetSteamID(*id_local, st.server.server_id);
			
			st.connection = ConnectP2P(client_networking_sockets, *id_local, 0, 0, null);
			assert(st.connection != k_HSteamNetConnection_Invalid, "invalid connection");
		}
		
		if st.connection != k_HSteamNetConnection_Invalid
		{
			msg_count := ReceiveMessagesOnConnection(client_networking_sockets, st.connection, incoming_msgs.data, incoming_msgs.count);
			assert(msg_count != -1, "a fuckie wuckie happen");
			for 0..msg_count-1
			{   
				message : *SteamNetworkingMessage_t = incoming_msgs[it];
				defer Release(message);

				msg : string;
				msg.data  = message.m_pData;
				msg.count = message.m_cbSize;
				
				log("\nReceived message from server:");
				log(msg);
			}
			
			memset(incoming_msgs.data, 0, msg_count * size_of(*SteamNetworkingMessage_t));
		}
	}
}

client_update :: ()
{
	assert(client_networking_sockets == SteamNetworkingSockets(), "Object mismatch? This should always be equal");
	
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
			client_callback(callback);
		}
	}
}

client_callback :: (cb: CallbackMsg_t)
{
	print("CLIENT | ");
	
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
	}
}

#import "Basic";
#import "String";
#import,file "../recycle.jai";
#import "Windows";

#import "Steam"(verbose=true, use_flat_api=true);

#import,file "server.jai";