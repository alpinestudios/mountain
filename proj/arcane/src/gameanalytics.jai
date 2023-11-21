

ga_gen_hmac :: (body: string) -> string
{
	return hmac_sha256(GAMEANALYTICS_SECRET_KEY, body);
}
}

#scope_module

//There's a few things here I have not pushed, since they are not to be shared:
//GAMEANALYTICS_SECRET_KEY
//GAMEANALYTICS_GAME_KEY

GAMEANALYTICS_ENDPOINT :: "sandbox-api.gameanalytics.com"; //TODO: change for release mode

//GAMEANALYTICS_INIT_URL :: GAMEANALYTICS_ENDPOINT + "/v2/" + GAMEANALYTICS_GAME_KEY + "/init";

jaison :: #import "jaison";
#import "Curl";
#import "crypto";
#import "Base64";