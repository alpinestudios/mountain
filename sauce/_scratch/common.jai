#import "Basic";
#import "Socket";
#import "String";
System :: #import "System";

#import,file "../recycle.jai";

ARC_PORT :: "69420";
SERVER_IP :: "2001:44c8:422e:a80f:26c5:18a6:c669:178f";

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