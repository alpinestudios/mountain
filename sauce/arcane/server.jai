#import "Basic";
#import "String";
#import,file "../recycle.jai";
#import "Steam";

PORT :u16: 42069;

Server :: struct
{
	poll_group: PollGroup;
}
server : Server;

main :: ()
{
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
	
	incoming_msgs : [1024] *NetworkingMessage;
	while true
	{
		msg_count := Sockets.ReceiveMessagesOnPollGroup(server.poll_group, incoming_msgs.data, incoming_msgs.count);
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

// this might needa be a #c_call ...
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
}