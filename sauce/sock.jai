// Just some helpers for Socket

#import "Socket";
System :: #import "System";

get_socket_error_string :: () -> string
{
	err := get_last_socket_error();
	return tprint("Error % %", err, System.get_error_string(err));
}

assert_socket_error :: ()
{
	err := get_last_socket_error();
	assert(err == 0, "Error % %", err, System.get_error_string(err));
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
	assert_socket_error();
	
	return tprint("%", to_string(ip_str.data));
}