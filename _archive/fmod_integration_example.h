#ifndef ANVIL_AUDIO_H
#define ANVIL_AUDIO_H

// Just helpers for audio with FMOD

typedef struct AnvilAudio AnvilAudio;
struct AnvilAudio
{
	FMOD_STUDIO_SYSTEM* studio_system;
	FMOD_STUDIO_BANK* bank;
	FMOD_STUDIO_BANK* string_bank;
};
global AnvilAudio anvil_audio = { 0 };

#define FMOD_Err(x) FMOD_ResultCheck(x)

function void FMOD_ResultCheck(FMOD_RESULT result)
{
	if (result != FMOD_OK)
	{
		Log("FMOD error! (%d) %s\n", result, FMOD_ErrorString(result));
		Assert(0);
	}
}

function void AUDIO_Init()
{
	FMOD_Err(FMOD_Studio_System_Create(&anvil_audio.studio_system, FMOD_VERSION));

	FMOD_Err(FMOD_Studio_System_Initialize(anvil_audio.studio_system, 512, FMOD_STUDIO_INIT_NORMAL, FMOD_INIT_NORMAL, 0));

	// FMOD/ needs to exist because that's where fmod builds into smh
	FMOD_Err(FMOD_Studio_System_LoadBankFile(anvil_audio.studio_system, "FMOD/Master.bank", FMOD_STUDIO_LOAD_BANK_NORMAL, &anvil_audio.bank));

	FMOD_Err(FMOD_Studio_System_LoadBankFile(anvil_audio.studio_system, "FMOD/Master.strings.bank", FMOD_STUDIO_LOAD_BANK_NORMAL, &anvil_audio.string_bank));
}

function void AUDIO_Exit()
{
	FMOD_Studio_Bank_Unload(anvil_audio.bank);
	FMOD_Studio_System_Release(anvil_audio.studio_system);
}

function void AUDIO_Update()
{
	FMOD_Studio_System_Update(anvil_audio.studio_system);
}

function void AUDIO_PlayEventSound(char* event_path)
{
	FMOD_STUDIO_EVENTDESCRIPTION* event_desc = 0;
	FMOD_Err(FMOD_Studio_System_GetEvent(anvil_audio.studio_system, event_path, &event_desc));

	// Create a new instance of this sound
	FMOD_STUDIO_EVENTINSTANCE* event_inst = 0;
	FMOD_Err(FMOD_Studio_EventDescription_CreateInstance(event_desc, &event_inst));

	FMOD_Err(FMOD_Studio_EventInstance_Start(event_inst));
	FMOD_Err(FMOD_Studio_EventInstance_Release(event_inst));
	// ^ will release the sound as soon as it stops playing
}

function UI_Signal UI_ButtonFSound(char* str, const B8 enabled)
{
	UI_Signal sig = UI_ButtonParams(str, enabled);
	if (sig.hover_on)
	{
		// AUDIO_PlayEventSound("event:/hover");
	}
	if (sig.pressed)
	{
		AUDIO_PlayEventSound("event:/click");
	}
	return sig;
}

#endif