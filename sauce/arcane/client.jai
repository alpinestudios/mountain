#import "Basic";
#import "String";
#import,file "../recycle.jai";
#import "Windows";

#import "Steam"(verbose=true);

PORT :u16: 42069;

loopbackIPv4 : u32 = 0x7F_00_00_01;



main :: ()
{
	assert(InitSteam(), "Failed to init Steam");
	defer ShutdownSteam();
	
	
	
	// 2001:44c8:4655:9c0b:8038:703f:b188:e17a
	ip := "27.55.65.162:42069";
	
	endpoint : SteamNetworkingIPAddr;
	//IPAddr.ParseString(*endpoint, xx ip.data);
	SetIPv4(*endpoint, loopbackIPv4, PORT);
	
	// Start connecting
	connectionAddr : [128]u8;
	ToString(*endpoint, connectionAddr.data, connectionAddr.count, true);
	connectionAddrView := to_string(connectionAddr.data);
	print("Connecting to chat server at %\n", connectionAddrView);

	options : [1] SteamNetworkingConfigValue_t;
	//SetPtr(self: *SteamNetworkingConfigValue_t, eVal: ESteamNetworkingConfigValue, data: *void)
	SetPtr(*options[0], .k_ESteamNetworkingConfig_Callback_ConnectionStatusChanged, xx client_connection_status_changed);

	connection := ConnectByIPAddress(*endpoint, options.count, options.data);

	if connection == k_HSteamNetConnection_Invalid 
	{
		print("Client: ConnectByIPAddress() failed!\n");
		return;
	}
	
	str :: "ligma";
	SendMessageToConnection(connection, str.data, 0, xx k_nSteamNetworkingSend_Reliable, null);

	

	incoming_msgs : [1024] *SteamNetworkingMessage_t;
	while true
	{
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
		
		RunCallbacks();
	}
}

client_connection_status_changed :: (info : *SteamNetConnectionStatusChangedCallback_t) -> void #c_call
{
	cont : Context;
 push_context cont
 {
 	log("%", info.m_info.m_eState);
 }
}
