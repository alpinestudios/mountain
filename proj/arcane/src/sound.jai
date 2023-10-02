// helpers for playing sounds via FMOD studio v2.02.10

play_sound :: (event_name: string, pos:=Vector2.{})
{
	event_desc : *FMOD_STUDIO_EVENTDESCRIPTION;
	event_str := tprint("event:/%", event_name);
	result := FMOD_Studio_System_GetEvent(sound_st.system, to_c_string(event_str), *event_desc);
	assert(result == .FMOD_OK, "FMOD error playing '%' - %", event_name, FMOD_ErrorString(result));
 
 instance : *FMOD_STUDIO_EVENTINSTANCE;
 fmod_error_check(FMOD_Studio_EventDescription_CreateInstance(event_desc, *instance));
 
 fmod_error_check(FMOD_Studio_EventInstance_Start(instance));
 
 // 3D
 attributes : FMOD_3D_ATTRIBUTES;
	attributes.position = .{pos.x, pos.y, 0};
	attributes.forward = .{0, 0, 1};
	attributes.up = .{0, 1, 0};
 FMOD_Studio_EventInstance_Set3DAttributes(instance, *attributes);
 
 // auto-release when sound finished
 fmod_error_check(FMOD_Studio_EventInstance_Release(instance));
}

SoundState :: struct
{
 system: *FMOD_STUDIO_SYSTEM;
 bank: *FMOD_STUDIO_BANK;
 strings_bank: *FMOD_STUDIO_BANK;
}
sound_st: SoundState;

sound_init :: ()
{
 fmod_error_check(FMOD_Studio_System_Create(*sound_st.system, FMOD_VERSION));
 
 fmod_error_check(FMOD_Studio_System_Initialize(sound_st.system, 512, xx FMOD_STUDIO_INIT.NORMAL, xx FMOD_INIT.NORMAL, null));
 
 // load bank files
 fmod_error_check(FMOD_Studio_System_LoadBankFile(sound_st.system, "res/fmod/Master.bank", xx FMOD_STUDIO_LOAD_BANK.NORMAL, *sound_st.bank));
 // pretty sure the strings are used so we can have a handle when playing events, idk tho
 fmod_error_check(FMOD_Studio_System_LoadBankFile(sound_st.system, "res/fmod/Master.strings.bank", xx FMOD_STUDIO_LOAD_BANK.NORMAL, *sound_st.strings_bank));
}

sound_update :: ()
{
	player := get_player();
	
	attributes : FMOD_3D_ATTRIBUTES;
	attributes.position = .{player.pos.x, player.pos.y, 0};
	attributes.forward = .{0, 0, 1};
	attributes.up = .{0, 1, 0};
	fmod_error_check(FMOD_Studio_System_SetListenerAttributes(sound_st.system, 0, *attributes, null));
	
	fmod_error_check(FMOD_Studio_System_Update(sound_st.system));
}

sound_shutdown :: ()
{
 result := FMOD_Studio_System_Release(sound_st.system);
	fmod_error_check(result);
}

fmod_error_check :: (result: FMOD_RESULT)
{
	assert(result == .FMOD_OK, "FMOD Error: %", FMOD_ErrorString(result));
}

#import "fmod";

// deprecated api
play_random_sound_old :: (name: string, count: int, volume: float = 1.0, pitch: float = 1.0, $random_spread := true)
{
}
play_sound_old :: (sound_id: ResourceID, volume: float = 1.0, v_left:= 1.0, v_right := 1.0, pitch:= 1.0, delay:=0.0, $random_spread := true)
{
}