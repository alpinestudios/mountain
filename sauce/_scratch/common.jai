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