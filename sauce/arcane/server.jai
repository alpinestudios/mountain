#import "Basic";

// TODO - @bounty ????
// I'd really like to figure out how I can get this running without all the .dll nonsense
//
// Also, how hard would it be to just forego this library for the time being??
// I need to test if it works across computers / networks, if not, then there's no point in me using it
// since there's no p2p in these Jai bindings
//
#import,file "GameNetworkingSockets.jai";

PORT :u16: 42069;

main :: ()
{
	assert(GameNetworkingSockets.Initialize(), "Failed to init GameNetworkingSockets.");
	
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
	poll_group := Sockets.CreatePollGroup();
	if poll_group == .Invalid
	{
		Sockets.CloseListenSocket(listen_socket);
		log_error("CreatePollGroup() failed!");
		assert(false);
		return;
	}

	log("Server listening on port %", PORT);
	
	while true
	{
		// POLL n shit
	}
}

// this might needa be a #c_call ...
server_connection_status_changed :: (info : *ConnectionStatusChanged)
{
	log("%", <<info);
}