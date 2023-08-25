#import "Basic";
#import "String";
#import,file "../recycle.jai";
#import "Windows";

#import "Steam"(verbose=false, expose_raw_calls=true);

// PORT :u16: 42069;

State :: struct
{
	network_active: bool;
}
st : State;

hook :: (severity: int, debug_text: *u8) -> void #c_call
{
	cont : Context;
 push_context cont
 {
 	log("YEEEEEEEET");
 	log("%", debug_text);
 	assert(severity < 1, "Fatal Steam Error");
 }
}

	// endpoint : SteamNetworkingIPAddr;
	//IPAddr.ParseString(*endpoint, xx ip.data);
	// SetIPv4(*endpoint, loopbackIPv4, PORT);
	
	// connectionAddr : [128]u8;
	// ToString(*endpoint, connectionAddr.data, connectionAddr.count, true);
	// connectionAddrView := to_string(connectionAddr.data);
	// print("Connecting to server at %\n", connectionAddrView);
	// connection := ConnectByIPAddress(*endpoint, options.count, options.data);

	// connection status callback
	// options : [1] SteamNetworkingConfigValue_t;
	// SetPtr(*options[0], .k_ESteamNetworkingConfig_Callback_ConnectionStatusChanged, xx client_connection_status_changed);

	// SetLocalHost(*id_local);
	// addr : SteamNetworkingIPAddr;
	// ParseString(*addr, "127.0.0.1:0");
	// SetIPAddr(*id_local, *addr);

arc_steam :: #library "main";
non_steam_gs :: () -> u64 #foreign arc_steam;

non_steam_gs_id :: #run non_steam_gs();

main :: ()
{
	assert(InitSteam(), "Failed to init Steam");
	defer ShutdownSteam();
	//InitRelayNetworkAccess();
	
	// I'm not too sure how to check for steam errors here, but it seems like shit's just being auto-dumped to the console output
	SetWarningMessageHook(xx hook); // not working?
	
	// setup socket
	//sock := CreateListenSocketP2P(0, 0, null);
	//assert(sock != k_HSteamListenSocket_Invalid);
	
	id_server: SteamNetworkingIdentity;
	SetSteamID(*id_server, 90071992547409920);
	// log("%", yeet);
	// SetSteamID(*id_server, yeet);
	
	connection := ConnectP2P(*id_server, 0, 0, null);
	if connection == k_HSteamNetConnection_Invalid
	{
		assert(false, "invalid connection");
	}

	while true
	{
		RunCallbacks();
	}
	
	/*

	if connection == k_HSteamNetConnection_Invalid 
	{
		print("Connection failed.\n");
		return;
	}
	
	str :: "ligma";
	SendMessageToConnection(connection, str.data, 0, xx k_nSteamNetworkingSend_Reliable, null);

	

	incoming_msgs : [1024] *SteamNetworkingMessage_t;
	while true
	{
		RunCallbacks();
		
		msg_count := ReceiveMessagesOnConnection(connection, incoming_msgs.data, incoming_msgs.count);
		assert(msg_count != -1, "a fuckie wuckie happen");
		
		for 0..msg_count-1
		{   
			message : *SteamNetworkingMessage_t = incoming_msgs[it];
			defer Release(message);

			msg : string;
			msg.data  = message.m_pData;
			msg.count = message.m_cbSize;
			
			log(msg);
		}
		memset(incoming_msgs.data, 0, msg_count * size_of(*SteamNetworkingMessage_t));
	}
	*/
}

relay_status :: (info: SteamRelayNetworkStatus_t)
{
	log("relay_status: % - %", info.m_eAvail, to_string(info.DebugMsg.data));
	// if info.m_eAvail == .k_ESteamNetworkingAvailability_Current
	// {
	// 	st.network_active = true;
	// }
}
@SteamCallback

connection_status_changed :: (info : SteamNetConnectionStatusChangedCallback_t)
{
	log("connection_status_changed: %", info.m_info.m_eState);
}
@SteamCallback