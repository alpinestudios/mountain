HEARING_PROTECTION :: 0.2;
master_vol := 1.0;

play_random_sound :: (key : string, count : int, volume : float = 1.0, pitch : float = 1.0, $random_spread := true)
{
 play_sound(tprint("%_%", key, cast(int)random_get_within_range(0, xx count)), volume, pitch, random_spread);
}

play_sound :: (key : string, volume : float = 1.0, pitch : float = 1.0, $random_spread := true)
{
 lock(*st.sound_mutex);
 defer unlock(*st.sound_mutex);
 
 wave := table_find_pointer(*st.sound_wave_table, key);
 if !wave then wave = sound_wave_create(key);

 _volume := volume;
 _pitch := pitch;
 #if random_spread
 {
  volume_spread :: 0.2;
  pitch_spread :: 0.05;
  _volume += random_get_within_range(-volume_spread, volume_spread);
  _pitch += random_get_within_range(-pitch_spread, pitch_spread);
 }
 
 // create a new sound instance
 sound := sound_instance_create();
 sound.wave_key = wave.key;
 sound.volume.x = _volume;
 sound.volume.y = _volume;
 sound.pitch = _pitch;
 
 if LOG_VERBOSE then log("played %", key);
}

SoundState :: struct
{
 buffer : [16]float;
 buffer_pos : int;
 
 sound_mutex : Mutex;
 
 sound_wave_table : Table(string, SoundWave, djb2_hash); // @memory - arena refactor
 sound_instance_first : *SoundInstance; // TODO - stack, queue, dll structures
 sound_instance_last : *SoundInstance;
 sound_instance_first_free : *SoundInstance;
 
 temp_counter : int;
 sound_instance_id_gen : u64;
}
sound_st : SoundState;

// base resource with a 16-bit PCM buffer, loaded from disk
SoundWave :: struct
{
 key : string;
 path : string;
 sample_buffer : string;
 channels : int;
}
nil_sound_wave : SoundWave;

SoundInstance :: struct
{
 next : *SoundInstance;
 prev : *SoundInstance;
 id : u64;
 wave_key : string;
 volume : Vector2 = .{1, 1};
 pitch := 1.0;
 loop_count := 1; // -1 for infinite 
 samples_played : float64;
}

sound_instance_create :: () -> *SoundInstance
{
 sound : *SoundInstance;
 if st.sound_instance_first_free != null
 {
  // grab from existing free list
  sound = st.sound_instance_first_free;
  stack_pop(*st.sound_instance_first_free);
 }
 else
 {
  // alloc new sound
  sound = New(SoundInstance, true, permanent_allocator);
 }
 
 st.sound_instance_id_gen += 1;
 sound.id = st.sound_instance_id_gen;
 
 dll_push_front(*st.sound_instance_first, *st.sound_instance_last, sound);
 return sound;
}

sound_instance_destroy :: (sound : *SoundInstance)
{
 dll_remove(*st.sound_instance_first, *st.sound_instance_last, sound);
 stack_push(*st.sound_instance_first_free, sound);
 next := sound.next;
 prev := sound.prev;
 <<sound = .{};
 sound.next = next;
 sound.prev = prev;
}

sound_wave_create :: (key : string) -> *SoundWave
{
 assert(!table_find_pointer(*st.sound_wave_table, key));

 push_allocator(permanent_allocator);
 
 file_path := sprint("%0%.wav", ASSET_PATH, key);
 file_data, success := read_entire_file(file_path);
 assert(success);
 
 format, samples, success2, extra := get_wav_header(file_data);
 // I am a dictator.
 assert(success2);
 assert(format.wFormatTag == WAVE_FORMAT_PCM);
 assert(format.nSamplesPerSec == SAMPLE_RATE);
 assert(format.nChannels == 2);
 assert(format.wBitsPerSample == 16);
 
 new_wave : SoundWave;
 new_wave.path = file_path;
 new_wave.key = copy_string(key);
 new_wave.sample_buffer = samples;
 new_wave.channels = format.nChannels;
 wave := table_add(*st.sound_wave_table, new_wave.key, new_wave);
 assert(wave != null);
 return wave;
}

sound_wave_from_key :: (key : string) -> *SoundWave
{
 wave := table_find_pointer(*st.sound_wave_table, key);
 if !wave
 {
  assert(false, tprint("sound_wave % not found", key));
  wave = *nil_sound_wave;
 }
 return wave;
}

sound_init :: ()
{
 // todo - get rid of reliance on default allocator by creating my own hash table
 // Jai's one relies on a resizable array that can be freed or some shit
 push_allocator(context.default_allocator);
 init(*st.sound_wave_table, 128); // init table to a decent size
 init(*st.sound_mutex);
 
 // SOKOL SETUP
 sd : saudio_desc;
 sd.num_channels = 2;
 sd.stream_cb = audio_stream_callback;
 saudio_setup(*sd);
 assert(saudio_isvalid());
}

sound_update :: ()
{
 assert(saudio_sample_rate() == SAMPLE_RATE);
 assert(saudio_channels() == 2);
}

audio_stream_callback :: (buffer : *float, num_frames : s32, num_channels : s32) -> void #c_call
{
 new_context : Context;
 push_context new_context {
  assert(saudio_sample_rate() == SAMPLE_RATE);
  assert(num_channels == 2);
  
  lock(*st.sound_mutex);
  defer unlock(*st.sound_mutex);
  
  for 0..num_frames-1
  {
   output : Vector2;
   sound := st.sound_instance_first;
   next_sound : SoundInstance;
   while sound
   {
    next_sound := sound.next; // grab it straight away to prevent destroy fuckery
    defer sound = next_sound;
    
    wave := sound_wave_from_key(sound.wave_key);
    assert(wave.channels == 2);
    
    samp : *s16 = xx wave.sample_buffer.data;
    sample_index : int = xx floor(sound.samples_played * 2.0);
    sample_index = sample_index - sample_index % 2;
    sample_frac : float = xx frac(sound.samples_played);
    for 0..1
    {
     a := s16_to_float(samp[sample_index]);
     b := s16_to_float(samp[sample_index+2]);
     // this is kinda sketch, but it was overruning the buffer without it. Probs just me having dodgey math... - randy
     has_next_sample : bool = sample_index + 2 < wave.sample_buffer.count / 2;
     value : float = ifx has_next_sample then lerp(a, b, sample_frac) else a;
     
     output.component[it] += master_vol * value * sound.volume.component[it];
     sample_index += 1;
    }
    
    // advance sample   
    sound.samples_played += sound.pitch;
    if sound.samples_played * 2 >= xx wave.sample_buffer.count / 2.0
    {
     sound.samples_played = 0;
     if sound.loop_count > 0 then sound.loop_count -= 1;
     if sound.loop_count == 0 then sound_instance_destroy(sound);
    }
   }
   output.x = clamp(output.x, -1, 1);
   output.y = clamp(output.y, -1, 1);
   output *= HEARING_PROTECTION;
   
   buffer[it*2]   = output.x;
   buffer[it*2+1] = output.y;
  }
 }
}

sound_shutdown :: ()
{
 saudio_shutdown();
}

#scope_file

st := *sound_st;
SAMPLE_RATE :: 44100;

#import "Sokol"(.Audio);
#import "Thread";