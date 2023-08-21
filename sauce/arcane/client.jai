#import "Basic";
#import "String";
#import,file "../recycle.jai";
#import,file "GameNetworkingSockets.jai";
#import "Windows";

PORT :u16: 42069;

loopbackIPv4 : u32 = 0x7F_00_00_01;

main :: ()
{
	assert(GameNetworkingSockets.Initialize(), "Failed to init GameNetworkingSockets.");
	defer GameNetworkingSockets.Finalize();
	
	endpoint : IPAddr;
	IPAddr.SetIPv4(*endpoint, loopbackIPv4, PORT);
	
	// Start connecting
	connectionAddr : [ IPAddr.MaxStringIPAddrSize ] s8;
	IPAddr.ToString(*endpoint, connectionAddr.data, connectionAddr.count, true);
	connectionAddrView := to_string(connectionAddr.data);
	print("Connecting to chat server at %\n", connectionAddrView);

	options : [1] ConfigValue;
	ConfigValue.SetPtr(*options[0], .Callback_ConnectionStatusChanged, xx client_connection_status_changed);

	connection := Sockets.ConnectByIPAddress(*endpoint, options.count, options.data);

	if connection == .Invalid 
	{
		print("Client: ConnectByIPAddress() failed!\n");
		return;
	}
	
	Sockets.SendStringToConnection(connection, "ligma", .Reliable, null);

	incoming_msgs : [1024] *NetworkingMessage;
	while true
	{
		msg_count := Sockets.ReceiveMessagesOnConnection(connection, incoming_msgs.data, incoming_msgs.count);
		assert(msg_count != -1, "a fuckie wuckie happen");
		
		for 0..msg_count-1
		{   
			message : *NetworkingMessage = incoming_msgs[it];
			defer NetworkingMessage.Release(message);

			msg : string;
			msg.data  = message.m_pData;
			msg.count = message.m_cbSize;
			
			log(msg);
		}
		memset(incoming_msgs.data, 0, msg_count * size_of(*NetworkingMessage));
		
		Sockets.RunCallbacks();
	}
}

client_connection_status_changed :: (info : *ConnectionStatusChanged) -> void #c_call
{
	cont : Context;
 push_context cont
 {
 	log("%", info.m_info.m_eState);
 }
}