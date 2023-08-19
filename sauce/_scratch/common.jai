#import "Basic";
#import "Socket";
#import "String";
System :: #import "System";

#import,file "../recycle.jai";

ARC_PORT :: "69420";
SERVER_IP :: "2001:44c8:45ca:1e59:dc07:197e:b61b:6628";

error_string :: () -> string
{
	err := get_last_socket_error();
	return tprint("Error % %", err, System.get_error_string(err));
}

error_assert :: ()
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
	error_assert();
	
	return tprint("%", to_string(ip_str.data));
}