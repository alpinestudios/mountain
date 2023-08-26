saudio_desc :: struct {
    sample_rate        : s32;                               /* requested sample rate */
    num_channels       : s32;                               /* number of channels, default: 1 (mono) */
    buffer_frames      : s32;                               /* number of frames in streaming buffer */
    packet_frames      : s32;                               /* number of frames in a packet */
    num_packets        : s32;                               /* number of packets in packet queue */
    stream_cb          : (*float, s32, s32) #c_call;        /* optional streaming callback (no user data) */
    stream_userdata_cb : (*float, s32, s32, *void) #c_call; /*... and with user data */
    user_data          : *void;                             /* optional user data argument for stream_userdata_cb */
}

saudio_setup         :: (desc: *saudio_desc) -> void             #foreign sokol_audio; /* setup sokol-audio */
saudio_shutdown      :: ()                                       #foreign sokol_audio; /* shutdown sokol-audio */
saudio_isvalid       :: () -> bool                               #foreign sokol_audio; /* true after setup if audio backend was successfully initialized */
saudio_userdata      :: () -> *void                              #foreign sokol_audio; /* return the saudio_desc.user_data pointer */
saudio_query_desc    :: () -> saudio_desc                        #foreign sokol_audio; /* return a copy of the original saudio_desc struct */
saudio_sample_rate   :: () -> s32                                #foreign sokol_audio; /* actual sample rate */
saudio_buffer_frames :: () -> s32                                #foreign sokol_audio; /* return actual backend buffer size in number of frames */
saudio_channels      :: () -> s32                                #foreign sokol_audio; /* actual number of channels */
saudio_expect        :: () -> s32                                #foreign sokol_audio; /* get current number of frames to fill packet queue */
saudio_push          :: (frames: *float, num_frames: s32) -> s32 #foreign sokol_audio; /* push sample frames from main thread, returns number of frames actually pushed */

#if OS == .WINDOWS {
    #import "Windows_Resources";
    sokol_audio :: #library,no_dll "win/sokol_audio";
}