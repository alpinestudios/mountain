// just a dump for old code. fuck looking thru soruce control


	// we probably want these to be static and stored out in a data file
	// will do that with the upcoming @data-rework
	/*
	sprite = get_sprite("char_walk");
	sprite.hand_sockets = newarray(sprite.frame_count, transform2, allocator=permanent_allocator);
	sprite.hand_sockets[0] = make_transform(xy(-5, 10), 10);
	sprite.hand_sockets[1] = make_transform(xy(6, 11), -20);
	sprite.hand_sockets[2] = make_transform(xy(9, 11), -30);
	sprite.hand_sockets[3] = make_transform(xy(9, 10), -30);
	sprite.hand_sockets[4] = make_transform(xy(5, 9), -20);
	sprite.hand_sockets[5] = make_transform(xy(-3, 11), 10);
	sprite.hand_sockets[6] = make_transform(xy(-9, 11), 20);
	sprite.hand_sockets[7] = make_transform(xy(-8, 10), 30);
	
	sprite = get_sprite("char_idle");
	sprite.hand_sockets = newarray(sprite.frame_count, transform2, allocator=permanent_allocator);
	sprite.hand_sockets[0] = make_transform(xy(-6, 11), -20);
	sprite.hand_sockets[1] = make_transform(xy(-6, 10), -20);
	sprite.hand_sockets[2] = make_transform(xy(-6, 9), -20);
	sprite.hand_sockets[3] = make_transform(xy(-6, 9), -20);
	sprite.hand_sockets[4] = make_transform(xy(-6, 9), -20);
	sprite.hand_sockets[5] = make_transform(xy(-6, 10), -20);
	sprite.hand_sockets[6] = make_transform(xy(-6, 11), -20);
	sprite.hand_sockets[7] = make_transform(xy(-6, 11), -20);
	sprite.hand_sockets[8] = make_transform(xy(-6, 11), -20);
	sprite.hand_sockets[9] = make_transform(xy(-6, 11), -20);
	
	sprite = get_sprite("char_slash1");
	sprite.hand_sockets = newarray(sprite.frame_count, transform2, allocator=permanent_allocator);
	sprite.hand_sockets[0] = make_transform(xy(-13, 21), 130);
	sprite.hand_sockets[1] = make_transform(xy(-4, 30), 180);
	sprite.hand_sockets[2] = make_transform(xy(10, 27), 225);
	sprite.hand_sockets[3] = make_transform(xy(15, 8), 20);
	sprite.hand_sockets[4] = make_transform(xy(11, 4), 10);
	sprite.hand_sockets[5] = make_transform(xy(0, 11), 45);
	
	sprite = get_sprite("char_stab1");
	sprite.hand_sockets = newarray(sprite.frame_count, transform2, allocator=permanent_allocator);
	sprite.hand_sockets[0] = make_transform(xy(-10, 10), 0);
	sprite.hand_sockets[1] = make_transform(xy(-11, 9), 0);
	sprite.hand_sockets[2] = make_transform(xy(23, 14), 0);
	sprite.hand_sockets[3] = make_transform(xy(25, 14), 0);
	sprite.hand_sockets[4] = make_transform(xy(11, 12), 0);
	
	sprite = get_sprite("char_punch");
	sprite.hand_sockets = newarray(sprite.frame_count, transform2, allocator=permanent_allocator);
	sprite.hand_sockets[0] = make_transform(xy(-11, 14), -60);
	sprite.hand_sockets[1] = make_transform(xy(-15, 12), -90);
	sprite.hand_sockets[2] = make_transform(xy(-14, 13), -90);
	sprite.hand_sockets[3] = make_transform(xy(31, 17), 0);
	sprite.hand_sockets[4] = make_transform(xy(24, 9), 20);
	sprite.hand_sockets[5] = make_transform(xy(19, 10), 10);
	sprite.hand_sockets[6] = make_transform(xy(11, 13), -10);
	*/


// TODO - multithread this
	// load from disk if not in cache
	/*
	if !texture
	{
		bitmap : Bitmap;
		success := bitmap_load(*bitmap, path);
		if success
		{
			if bitmap.format == .RGBA8
			{
				tex := texture_alloc(xx bitmap.width, xx bitmap.height, bitmap.data.data);
				texture = cache_texture(tex, key);
				
				modtime, size, success := file_modtime_and_size(path);
				assert(success);
				texture.last_modified = modtime;
				if LOG_VERBOSE then log("texture % created", key); 
			}
			else
			{
				log("Texture % is format %. Expected %", key, bitmap.format, Texture_Format.RGBA8);
			}
		}
	}
	*/

	// hot reload
	// todo - use file_watcher instead
	/*
	if texture && texture.last_modified != APOLLO_TIME_INVALID
	{
		modtime, size, success := file_modtime_and_size(path);
		if success && modtime != texture.last_modified
		{
			texture.last_modified = modtime;
			texture.modify_cooldown_timer = 0.1;
		}
		// had to put a cooldown on the modify because aesprite modifies files twice when saving lol - randy
		if tick_timer(*texture.modify_cooldown_timer)
		{
			bitmap : Bitmap;
			success := bitmap_load(*bitmap, path);
			assert(success); // todo - abstract this loading of the bitmap out into own function, proper error checks
			assert(bitmap.width == texture.width && bitmap.height == texture.height && bitmap.format == .RGBA8);

			// copy new data into existing texture
			res : D3D11_MAPPED_SUBRESOURCE;
			ID3D11DeviceContext_Map(render_st.d3d_context, texture.texture, 0, .WRITE_DISCARD, 0, *res);
			memcpy(res.pData, bitmap.data.data, 4 * texture.width * texture.height);
			ID3D11DeviceContext_Unmap(render_st.d3d_context, texture.texture, 0);

			log("hot-reloaded %", key);
		}
	}
	*/

// lambda



   
   // example of an auto-freeing dynamic array across the frame boundary
    player.frame.hit_entities.allocator = frame_allocator;
    if player.last_frame.hit_entities.data
    {
     array_copy(*player.frame.hit_entities, player.last_frame.hit_entities);
     // this'll basically expire for free the moment our chopping state is done,
     // since last frame's hit entities wil get nulled if we don't put in a fresh array
     // LOOK HOW FKING LOCALISED THIS SHIT IS!!! memory arenas lesgoooooo
    }
    
    
    
    
 // meta dumping out mebers
 info := type_info(Stack);
 for info.members
 {
 log("%", it);
 }    
    
    
    
// old manual fixed arena
PERMANENT_SIZE :: #run gigabytes(1);
   WORLD_SIZE :: #run gigabytes(1);
   FRAME_SIZE :: #run megabytes(512);
   TOTAL_SIZE :: PERMANENT_SIZE + WORLD_SIZE + FRAME_SIZE * 2;
   
   // grab one massive ol' buffer
   base_memory := alloc(TOTAL_SIZE, context.default_allocator);
   memory_state.backing_buffer = base_memory;
   memory_state.backing_buffer_size = TOTAL_SIZE;
   
   // init arenas, giving each its own chunk from the backing buffer
   arena_init :: (arena : *Arena, base_memory : *void, size : u64, name : string)
   {
      arena.name = name;
      arena.buffer = base_memory;
      arena.buffer_size = size;
   }
   arena_init(*memory_state.permanent_arena, base_memory, PERMANENT_SIZE, "PERMANENT");
   base_memory += PERMANENT_SIZE;
   arena_init(*memory_state.world_arena, base_memory, WORLD_SIZE, "WORLD");
   base_memory += WORLD_SIZE;
   arena_init(*memory_state.frame_arena[0], base_memory, FRAME_SIZE, "FRAME1");
   base_memory += FRAME_SIZE;
   arena_init(*memory_state.frame_arena[1], base_memory, FRAME_SIZE, "FRAME2");
   base_memory += FRAME_SIZE;
   assert(base_memory - TOTAL_SIZE == memory_state.backing_buffer);
   

 // player damage
 /*
 if being_damaged
 && state != damaged
 {
  entity_set_state(player, damaged);
  health -= 1;
  health = max(0, health);
  if health == 0
  {
   being_damaged = false;
   entity_set_state(player, dead);
   timer1 = 1.0;
  }
  else
  {
   // todo - velocity dir override
   velocity.x = -x_dir * 200.0;
   velocity.y = 100.0;
  }
 }

 // death animation
 if state == dead && timer1
 {
  if tick_timer(*timer1)
  {
   log("Balls.\n");
  }
 }

 // exit damage
 if state == damaged
 {
  down_time :: 1.0;
  if timer1 == 0 then timer1 = down_time;
  if tick_timer(*timer1)
  {
   being_damaged = false;
   entity_set_state(player, idle);
  }
 }
 */

// player attack stuff
 // start attack
 if (state == idle || state == walk) && gsf.key_pressed[Input.Key_Code.MOUSE_BUTTON_LEFT]
 {
  last_state, time_ago:= entity_get_first_last_state(player, .[attack1, attack2]);

  if last_state == attack1 && time_ago < 0.5
  {
   entity_set_state(player, attack2);
   entity_set_sprite(player, SpriteID.player_attack2); 
  }
  else
  {
   entity_set_state(player, attack1);
   entity_set_sprite(player, SpriteID.player_attack1);
  }
 }

 // attack keyframe
 if (state == attack1 || state == attack2) && !has_attacked
 {
  has_attacked = true;
  ogre_hitbox: Range2;
  ogre_hitbox.max = xy(60, 90);
  ogre_hitbox = range_bottom_center(ogre_hitbox);

  for * st.entities if it.flags & .recieve_damage && it != player
  {
   against_rect:= range_shift(ogre_hitbox, it.position);
   //debug_rect(against_rect, 200);
   if range_collide(attack_hitbox, against_rect)
   {
    // play damage state
    //it.being_damaged = true;
   }
  }

  //debug_rect(hitbox, 200);
 }

 // end attac
 if (state == attack1 || state == attack2) && frame.did_anim_finish
 {
  entity_set_state(player, idle);
  entity_set_sprite(player, SpriteID.player_idle);
  has_attacked = false;
 }



 // old timer dodgeroll
 /*
 if state == roll && time_left
 {
  if tick_timer(*time_left)
  {
   entity_set_sprite(player, SpriteID.player_idle);
   entity_set_state(player, idle);
  }
  alpha := 1-time_left / dodgeroll_length;

  end_position := start_position + xy(x_dir * 50.0, 0);

  position = lerp(start_position, end_position, alpha);
  rotation = 360 * alpha * -x_dir;
  rotation_offset = xy(0, range_size(rect).y / -2.0);
  // TODO - curves :)

  KeyFrameRot :: struct
  {
   alpha : float;
   rotation : float;
  }
  key_rot : [] KeyFrameRot = .[
  .{0, 0},
  .{0.4, 45.0},
  .{0.6, 135.0},
  .{1, 360}
  ];

  // todo - sample keyframe

  // immediate mode animation keyframes
 }
 */
 
  // start dodgeroll
 //dodgeroll_length :: 0.2;
 // if (state == walk || state == idle)
 // && st.key_down[Input.Key_Code.SHIFT] && input_axis.x != 0.0
 // {
 //  entity_set_state(player, roll);
 //  entity_set_sprite(player, SpriteID.player_roll);
 //  velocity.x = x_dir * 400.0;
 //  //time_left = dodgeroll_length;
 //  //start_position = position;
 // }

 // if state == roll
 // && sprite_id == SpriteID.player_roll
 // && frame.did_anim_finish
 // {
 //  entity_set_sprite(player, SpriteID.player_idle);
 //  entity_set_state(player, idle);
 // }


// ogre update
for * ogre: st.entities if ogre.flags & .valid && ogre.kind == EntityKind.ogre
{
 using ogre;
 using EntityState;
 x_speed_target = 0.0;
 pos_diff:= player.position - position;
 dist_to_player:= abs(pos_diff.x);

 // recieve damage animation thing
 /*
 if being_damaged
 {
  flash_length :: 0.2;
  if timer1 == 0 then timer1 = flash_length;
  col.w = timer1 / flash_length + 2.0;

  if tick_timer(*timer1)
  {
   log("yeetus\n");
  }
 }
 */

 // ogre attacc
 if !has_attacked
 && (state == attack1 && animation_frame == 18) || (state == attack2 && animation_frame == 10)
 {
  has_attacked = true;

  hitbox: Range2;
  hitbox.max = ifx state == attack1 then xy(88, 152) else xy(40, 20);
  if x_dir == -1 then hitbox = range_flip_x(hitbox);
  hitbox = range_shift(hitbox, position);
  debug_rect(hitbox, 200);

  player_hitbox := player.collision_rect;
  player_hitbox = range_bottom_center(player_hitbox);

  for * st.entities if it.flags & .recieve_damage && it != ogre
  {
   against_rect:= range_shift(player_hitbox, it.position);
   //debug_rect(against_rect, 200);
   if range_collide(hitbox, against_rect)
   {
    it.being_damaged = true;
    it.x_dir = -x_dir;
   }
  }
 }

 // finish attacc
 if (state == attack1 || state == attack2) && frame.did_anim_finish
 {
  has_attacked = false;
  entity_set_state(ogre, idle);
  entity_set_sprite(ogre, SpriteID.ogre_idle);
 }

 // should start walk
 if state == idle
 && dist_to_player < 200.0
 && player.state != dead
 {
  entity_set_state(ogre, walk);
  entity_set_sprite(ogre, SpriteID.ogre_walk);
 }

 // change direction
 if !(state == attack1 || state == attack2)
 || state == attack1 && animation_frame < 12
 || state == attack2 && animation_frame < 8
 {
  x_dir = sign(pos_diff.x); 
 }

 // move to player
 if state == walk
 {
  if dist_to_player < 40.0
  {
   entity_set_state(ogre, attack2);
   entity_set_sprite(ogre, SpriteID.ogre_attack2);
  }
  else if dist_to_player < 70.0
  {
   entity_set_state(ogre, attack1);
   entity_set_sprite(ogre, SpriteID.ogre_attack1);
  }
  else
  {
   x_speed_target = 30.0;
  }
 }
}


/*


 // sine wave example
 hertz := 40;
 wave_period := sample_rate / hertz;
 val := sin(5.0 * PI * st.temp_counter / wave_period);
 val *= 0.1; // hearing protection lol
 st.buffer[st.buffer_pos] = val;
 st.buffer[st.buffer_pos+1] = val;
 st.buffer_pos += 2;
 st.temp_counter += 1;
 

callback model example

audio_stream_callback :: (buffer : *float, num_frames : s32, num_channels : s32) -> void #c_call
{
 new_context : Context;
 push_context new_context
 {
  assert(num_channels == 1);
  sample_rate := saudio_sample_rate();
  hertz := 40;
  wave_period := sample_rate / hertz;

  for 0..num_frames-1
  {
   val := sin(5.0 * PI * st.counter / wave_period);
   val *= 0.1;
   buffer[it] = val;
   st.counter += 1;
  }
 }
}
*/

// push model example
 /*
 expected_samples := saudio_expect();
 for 0..expected_samples-1
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
  output.x *= HEARING_PROTECTION;
  output.y *= HEARING_PROTECTION;
  
  // write value to the sound buffer
  st.buffer[st.buffer_pos]   = output.x;
  st.buffer[st.buffer_pos+1] = output.y;
  st.buffer_pos += 2;
  
  // flush intermediate buffer to the actual sound buffer
  if st.buffer_pos >= st.buffer.count
  {
   pushed := saudio_push(st.buffer.data, st.buffer.count / 2);
   assert(pushed == st.buffer.count / 2);
   memset(st.buffer.data, 0, size_of(float) * st.buffer.count);
   st.buffer_pos = 0;
  }
 }
 */



/*
old sound player example

#import "Sound_Player";
WAV :: "wav";
OGG :: "ogg";

SoundState :: struct
{
 sound_player : *Sound_Player; 
}
st : SoundState;

sound_init :: ()
{
 st.sound_player = New(Sound_Player);
 st.sound_player.update_history = true;

 success := init(st.sound_player, xx st.window, true, true);
 assert(success);
}

play_sound :: (name : string)
{
 
}

// ---

update_sound_player :: (dt: float)
{
 // Move sound streams forward by dt.
 lock(*st.sound_player.sound_mutex);
 defer unlock(*st.sound_player.sound_mutex);

 pre_entity_update(st.sound_player);

 // @Incomplete We're not removing sound streams once they're consumed.
 for st.sound_player.streams {
  it.marked = true;
 }

 post_entity_update(st.sound_player, dt);
}

play_sound :: (data: *Mixer_Sound_Data, perturb: bool = true) -> *stream {
 stream := make_stream(st.sound_player, data);

 if stream {
  stream.sound_data = data;
 }

 if perturb && stream {
  stream.user_volume_scale = random_get_within_range(0.7, 1);
  stream.desired_rate = random_get_within_range(0.7, 1.22);
 }

 stream.repeat_end_position = cast(int)(data.sampling_rate * 234.475);  // @Temporary @Hack! We do not get the duration by default from an ogg file...
 
 return stream;
}

load_sound :: (basename: string) -> *Mixer_Sound_Data {
 name := tprint("res/%.wav", basename);
 data := load_audio_file(name);

 if !data {
  print("Error: Could not load wav file: %\n", name);
  assert(false); 
  return null;
 }

 return data;
}

load_audio_file :: (name : string) -> *Mixer_Sound_Data {
 data : *Mixer_Sound_Data = null;

 file_data, success := read_entire_file(name);
 if !success return data;

 has_extension :: (name: string, extension: string) -> bool {
  if name.count < extension.count  return false;
  test := name;
  advance(*test, name.count - extension.count);
  return test == extension;
 }

 if has_extension(name, WAV) {
  data = New(Mixer_Sound_Data);
  data.name = copy_string(name);
  data.buffer = file_data;

  format, samples, success2, extra := get_wav_header(data.buffer);
  if !success2 {
   log_error("Unable to parse '%' as wav.\n", data.full_path);
   return data;
  }

 if format.wFormatTag == WAVE_FORMAT_PCM {
  data.type                     = .LINEAR_SAMPLE_ARRAY;
  data.nchannels                = cast(u16) format.nChannels;
  data.nsamples_times_nchannels = samples.count/2;
  } else if format.wFormatTag == WAVE_FORMAT_DVI_ADPCM {
   data.type             = .ADPCM_COMPRESSED;
   data.wSamplesPerBlock = extra.wSamplesPerBlock;
   data.nBlockAlign      = format.nBlockAlign;

   data.nchannels = cast(u16) format.nChannels;
   // The value in the FACT chunk is number of samples by time. 
   data.nsamples_times_nchannels = extra.wSamplesAccordingToFactChunk * data.nchannels;
  } else {
   assert(false);
  }

  data.samples       = cast(*s16) samples.data;
  data.sampling_rate = cast(u32) format.nSamplesPerSec;
  } else if has_extension(name, OGG) {
  data = New(Mixer_Sound_Data);
  data.name   = copy_string(name);
  data.buffer = file_data;
  data.type   = .OGG_COMPRESSED;
  } else {
   // Unsupported format.
  }

 return data;
}
*/