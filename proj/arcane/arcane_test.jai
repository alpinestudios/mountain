/*

STEAM NETWORKING SETUP TIME

[x] merge into one .exe
[x] get the connection coming thru
[x] abstract out the server so it can be internal or external
[x] connect accept
[x] exchange a packet :)
[x] spin up the dedicated server on my lappy and connect to it from a client on my desktop

* I'm currently taking what I learnt here and integrating it into arcane.jai

*/


GameState :: struct
{
	connection: HSteamNetConnection;
	
	external_server_id: u64;
	
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

main :: ()
{
	args := get_command_line_arguments();
	for args
	{
		if it == "--internal" then st.internal_server = true;
		
		if !st.internal_server && it_index == 1
		{
			st.external_server_id = xx string_to_int(it);
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
		
		if st.connection == k_HSteamNetConnection_Invalid
		{
			attempt_connection();
		}
		
		// msgs from connection
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

attempt_connection :: ()
{
	if st.internal_server
	{
		if !st.server.server_ready
		{
			return;
		}
		
		id_local: SteamNetworkingIdentity;
		log("Connecting to internal server: %", st.server.server_id);
		SetSteamID(*id_local, st.server.server_id);
		
		st.connection = ConnectP2P(client_networking_sockets, *id_local, 0, 0, null);
		assert(st.connection != k_HSteamNetConnection_Invalid, "invalid connection");
	}
	else
	{
		id_local: SteamNetworkingIdentity;
		log("Connecting to external server: %", st.external_server_id);
		SetSteamID(*id_local, st.external_server_id);
		
		st.connection = ConnectP2P(client_networking_sockets, *id_local, 0, 0, null);
		assert(st.connection != k_HSteamNetConnection_Invalid, "invalid connection");
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
#import,file "../../recycle/recycle.jai"; // bruh
#import "Windows";

#import "Steam"(verbose=true, use_flat_api=true);

#import,file "server.jai";