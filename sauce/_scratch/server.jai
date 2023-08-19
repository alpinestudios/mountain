#load "common.jai";

main :: ()
{
	assert(socket_init());
	
	hints: addrinfo;
	hints.ai_family = AF_INET6;
	hints.ai_socktype = .DGRAM;
	hints.ai_flags = .PASSIVE; // use this ip
	
	info: *addrinfo;
	getaddrinfo(null, ARC_PORT, *hints, *info);
	defer freeaddrinfo(info);
	error_assert();
	
	sock: u64;
	while info != null
	{
		defer info = info.ai_next;
		
		// grab a socket
		sock = socket(info.ai_family, info.ai_socktype, info.ai_protocol);
		if sock == INVALID_SOCKET
		{
			log(error_string());
			continue;
		}
		
		// attempt to bind it
		bound := bind(sock, info.ai_addr, xx info.ai_addrlen);
		if bound == -1
		{
			log("failed to bind socket %", sock);
			log(error_string());
			close_and_reset(*sock);
			continue;
		}
		
		log("successfully bound socket %", sock);
		break;
	}
	assert(sock != INVALID_SOCKET, "Failed to bind socket");
	
	log("Waiting for recvfrom...");
	
	buff: [512]u8;
	
	their_addr: sockaddr_storage;
	their_addr_len: s32 = size_of(type_of(their_addr));
	
	byte_count := recvfrom(sock, buff.data, buff.count, 0, xx *their_addr, *their_addr_len);
	error_assert();
	
	log("Recieved % byte packet:", byte_count);
	// log("FROM %", get_internet_address(xx *their_addr));
	log("\n");
	buff[byte_count] = 0;
	log("%", to_string(buff.data));
	
	close_and_reset(*sock);
}

get_internet_address :: (addr: *sockaddr) -> string
{
	address : *void;
	if addr.sa_family == AF_INET
	{
		ipv4 : *sockaddr_in = xx addr;
		address = *ipv4.sin_addr;
	}
	else
	{
		ipv6 : *sockaddr_in6 = xx addr;
		address = *ipv6.sin6_addr;
	}
	
	ip_str : [INET6_ADDRSTRLEN]u8;
	inet_ntop(addr.sa_family, address, ip_str.data, ip_str.count);
	error_assert();
	
	return tprint("%", to_string(ip_str.data));
}