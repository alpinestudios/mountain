ga_test :: ()
{
	k := "16813a12f718bc5c620f56944e1abc3ea13ccbac";
	body_string := "{\"test\": \"test\"}";
	b := ga_hmac_auth_hash(body_string, k);
	print("%\n", b);
}

// randy: just being super paranoid at this point lol
payload :: "{\"platform\":\"Windows\",\"os_version\":\"Windows 10\",\"sdk_version\":\"rest api v2\"}";
// payload :: #string POST_DATA
// {
// 	"platform":"Windows",
// 	"os_version":"Windows 10",
// 	"sdk_version":"rest api v2"
// }
// POST_DATA

ga_post_init :: ()
{
	request_result: string;

	curl := curl_easy_init();
	if !curl 
	{
		print("Could not init Curl!\n");
		return;
	}
	defer curl_easy_cleanup(curl);

	header: *curl_slist;
	
	header = curl_slist_append(header, "Content-Type: application/json");
	
	authorisation := ga_auth_hash(payload);
	tstr_auth := tprint("Authorization: %", authorisation);
	log("%", tstr_auth);
	header = curl_slist_append(header, temp_c_string(tstr_auth)); // randy: idk how  necessary the temp_s_string is, but I just put it there incase?
	
	// randy: just put this in for good measure?
	test := tprint("Content-Length: %", payload.count);
	log("%", test);
	header = curl_slist_append(header, temp_c_string(test));

	curl_easy_setopt(curl, .URL, GAMEANALYTICS_INIT_URL);

	curl_easy_setopt(curl, .POST, 1);
	//if data  curl_easy_setopt(curl, .POSTFIELDS, temp_c_string(data));

	builder: String_Builder;
	builder.allocator = temp; // We are not planning to keep the string long term, so we will use temp allocator, in a real application that decision has to be made for yourself
	curl_easy_setopt(curl, .WRITEDATA, *builder);
	curl_easy_setopt(curl, .POSTFIELDS, temp_c_string(payload));

	curl_easy_setopt(curl, .HTTPHEADER, header);
	curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);

	// Perform the "easy" action
	error_code := curl_easy_perform(curl);
	if error_code != .OK {
		error_message := to_string(curl_easy_strerror(error_code));
		print("Curl Error: %\n", error_message);
		return;
	}
	
	// randy: logging directly in the writefunction callback
	// log("\n%", builder_to_string(*builder));

	// ga_send_test_event();
}

ga_send_test_event :: ()
{
	request_result: string;

	curl := curl_easy_init();
	if !curl 
	{
		print("Could not init Curl!\n");
		return;
	}
	defer curl_easy_cleanup(curl);

	header: *curl_slist;
	header = curl_slist_append(header, "Content-Type: application/json");
	authorisation := ga_auth_hash(TEST_EVENT);
	tstr_auth := tprint("Authorization: %", authorisation);
	tstr_cstr := temp_c_string(tstr_auth);
	header = curl_slist_append(header, tstr_auth.data);

	curl_easy_setopt(curl, .URL, GAMEANALYTICS_EVENT_URL);

	curl_easy_setopt(curl, .POST, 1);
	//if data  curl_easy_setopt(curl, .POSTFIELDS, temp_c_string(data));

	builder: String_Builder;
	builder.allocator = temp; // We are not planning to keep the string long term, so we will use temp allocator, in a real application that decision has to be made for yourself
	curl_easy_setopt(curl, .WRITEDATA, *builder);
	curl_easy_setopt(curl, .POSTFIELDS, temp_c_string(TEST_EVENT));

	curl_easy_setopt(curl, .HTTPHEADER, header);
	curl_easy_setopt(curl, .WRITEFUNCTION, write_callback);

	// Perform the "easy" action
	error_code := curl_easy_perform(curl);

	if error_code != .OK {
		error_message := to_string(curl_easy_strerror(error_code));
		//defer free(error_message);
		print("Curl Error: %\n", error_message);
		return;
	}
}

ga_gen_hmac :: (body: string) -> string
{
	return hmac_sha256(GAMEANALYTICS_SECRET_KEY, body);
}

ga_auth_hash ::(body: string) -> string
{
	return base64_encode(ga_gen_hmac(body));
}

ga_hmac_auth_hash :: (body_string: string, secret_key: string) -> string
{
	return base64_encode(hmac_sha256(secret_key, body_string));
}

write_callback :: (contents: *u8, count: u64, size: u64, builder: *String_Builder) -> u64 #c_call {
	total_size := count * size;
	new_context: Context;
	push_context new_context {
		// Append to the builder
		append(builder, contents, cast(s64) total_size);
		log("%", to_string(contents));
	}
	return total_size;
}

#scope_module

TEST_EVENT :: #string TESTEV 
[
	{
		"category": "user",
		"event_id": 1
		"events": "["what"]"
	}
]
TESTEV

GAMEANALYTICS_ENDPOINT :: "https://sandbox-api.gameanalytics.com"; //TODO: change for release mode

//GAMEANALYTICS_INIT_URL :: GAMEANALYTICS_ENDPOINT + "/v2/" + GAMEANALYTICS_GAME_KEY + "/init";


#load "env.jai";
jaison :: #import "jaison";
#import "Curl";
#import "crypto";
#import "Base64";