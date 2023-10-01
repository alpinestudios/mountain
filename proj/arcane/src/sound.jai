// helpers for playing sounds via FMOD studio v2.02.10

play_random_sound :: (name: string, count: int, volume: float = 1.0, pitch: float = 1.0, $random_spread := true)
{
 
}

play_sound :: (sound_id: ResourceID, volume: float = 1.0, v_left:= 1.0, v_right := 1.0, pitch:= 1.0, delay:=0.0, $random_spread := true)
{
 
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
 result := FMOD_Studio_System_Create(*sound_st.system, FMOD_VERSION);
 fmod_error_check(result);
 
 result = FMOD_Studio_System_Initialize(sound_st.system, 512, xx FMOD_STUDIO_INIT.NORMAL, xx FMOD_INIT.NORMAL, null);
 fmod_error_check(result);
 
 // load bank files
 result = FMOD_Studio_System_LoadBankFile(sound_st.system, "res/fmod/Master.bank", xx FMOD_STUDIO_LOAD_BANK.NORMAL, *sound_st.bank);
 fmod_error_check(result);
 // pretty sure the strings are used so we can have a handle when playing events, idk tho
 result = FMOD_Studio_System_LoadBankFile(sound_st.system, "res/fmod/Master.strings.bank", xx FMOD_STUDIO_LOAD_BANK.NORMAL, *sound_st.strings_bank);
 fmod_error_check(result);
}

sound_update :: ()
{
	result := FMOD_Studio_System_Update(sound_st.system);
	fmod_error_check(result);
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