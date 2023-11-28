//
// This file was auto-generated using the following command:
//
// jai first.jai
//



ga_init :: () -> void #foreign libga "?ga_init@@YAXXZ";
ga_shutdown :: () -> void #foreign libga "?ga_shutdown@@YAXXZ";
ga_design_event :: (event_id: *u8, value: float64) -> void #foreign libga "?ga_design_event@@YAXPEBDN@Z";

#scope_file

#import "Basic"; // For assert

libga :: #library "./libga";
