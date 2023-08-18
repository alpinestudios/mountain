#load "common.jai";

main :: ()
{
	assert(socket_init());
	
	hints: addrinfo;
	hints.ai_family = AF_INET6;
	hints.ai_socktype = .DGRAM;
	
	info: *addrinfo;
	getaddrinfo(SERVER_IP, ARC_PORT, *hints, *info);
	defer freeaddrinfo(info);
	error_assert();
	
	sock: u64;
	while info != null
	{
		sock = socket(info.ai_family, info.ai_socktype, info.ai_protocol);
		if sock == INVALID_SOCKET
		{
			log(error_string());
			info = info.ai_next;
			continue;
		}
		log("successfully created socket %", sock);
		break;
	}
	assert(sock != INVALID_SOCKET, "Failed to bind socket");
	
	msg := "ligma";
	byte_count := sendto(sock, msg.data, xx msg.count, 0, info.ai_addr, xx info.ai_addrlen);
	error_assert();
}