stm_setup                        :: () -> void                              #foreign sokol_time;
stm_now                          :: () -> u64                               #foreign sokol_time;
stm_diff                         :: (new_ticks: u64, old_ticks: u64) -> u64 #foreign sokol_time;
stm_since                        :: (start_ticks: u64) -> u64               #foreign sokol_time;
stm_laptime                      :: (last_time: *u64) -> u64                #foreign sokol_time;
stm_round_to_common_refresh_rate :: (frame_ticks: u64) -> u64               #foreign sokol_time;
stm_sec                          :: (ticks: u64) -> float64                 #foreign sokol_time;
stm_ms                           :: (ticks: u64) -> float64                 #foreign sokol_time;
stm_us                           :: (ticks: u64) -> float64                 #foreign sokol_time;
stm_ns                           :: (ticks: u64) -> float64                 #foreign sokol_time;

#if OS == .WINDOWS {
    sokol_time :: #foreign_library,no_dll "win/sokol_time";
}