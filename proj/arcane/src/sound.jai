// helpers for playing sounds via FMOD studio v2.02.10

// randy: NOTE
// This won't actually play globally, it's just assuming the sound has no spatialiser in FMOD,
// so it's a helper for not passing in the position. Kinda confusing and error prone, tbh. Oh well
play_sound_global :: (event_name: string)
{
	play_sound(event_name, pos=.{});
}

play_sound :: (event_name: string, pos: Vector2)
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

play_sound_loop :: (event_path: string) -> *FMOD_STUDIO_EVENTINSTANCE
{
	// desc : *FMOD_STUDIO_EVENTDESCRIPTION;
	// FMOD_Studio_EventInstance_GetDescription(it, *desc);
	// FMOD_Studio_EventDescription_GetPath();
	
	event_desc : *FMOD_STUDIO_EVENTDESCRIPTION;
	result := FMOD_Studio_System_GetEvent(sound_st.system, to_c_string(event_path), *event_desc);
	assert(result == .FMOD_OK, "FMOD error getting event '%' - %", event_path, FMOD_ErrorString(result));
 
 instance : *FMOD_STUDIO_EVENTINSTANCE;
 fmod_error_check(FMOD_Studio_EventDescription_CreateInstance(event_desc, *instance));
 
 fmod_error_check(FMOD_Studio_EventInstance_Start(instance));
 
 return instance;
}

setup_snapshot :: (snapshot_path: string) -> *FMOD_STUDIO_EVENTINSTANCE #must
{
	event_desc : *FMOD_STUDIO_EVENTDESCRIPTION;
	result := FMOD_Studio_System_GetEvent(sound_st.system, to_c_string(snapshot_path), *event_desc);
	assert(result == .FMOD_OK, "FMOD error getting event '%' - %", snapshot_path, FMOD_ErrorString(result));
 
 instance : *FMOD_STUDIO_EVENTINSTANCE;
 fmod_error_check(FMOD_Studio_EventDescription_CreateInstance(event_desc, *instance));
 
 return instance;
}

play_fmod_instance :: (event_instance: *FMOD_STUDIO_EVENTINSTANCE)
{
	// randy: TODO, make these things not fragile asf on entry/exit.
	// a reentry should do nothing.
	// FUCK YOU FMOD
	fmod_error_check(FMOD_Studio_EventInstance_Start(event_instance));
}

stop_fmod_instance :: (event_instance: *FMOD_STUDIO_EVENTINSTANCE)
{
	fmod_error_check(FMOD_Studio_EventInstance_Stop(event_instance, 0));
}

SoundState :: struct
{
 system: *FMOD_STUDIO_SYSTEM;
 core_system: *FMOD_SYSTEM;
 bank: *FMOD_STUDIO_BANK;
 strings_bank: *FMOD_STUDIO_BANK;
 
 master_ch_group : *FMOD_CHANNELGROUP;
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
 
 // store core system
 FMOD_Studio_System_GetCoreSystem(sound_st.system, *sound_st.core_system);
 
 // grab master channel
	fmod_error_check(FMOD_System_GetMasterChannelGroup(sound_st.core_system, *sound_st.master_ch_group));
}

sound_update :: ()
{
	player := get_player();
	
	// set master volume
	fmod_error_check(FMOD_ChannelGroup_SetVolume(sound_st.master_ch_group, app.settings.volume));
	
	// update listener pos
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