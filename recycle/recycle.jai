#import "Basic";
#import "Math";
#import "String";

/* handy dump
path := path_strip_filename(get_path_of_running_executable());

*/

float_to_string :: (v: float, decimals:=2, remove_zeros:=false) -> string
{
	builder: String_Builder;
	format := formatFloat(v, trailing_width=decimals, zero_removal=ifx remove_zeros then .YES else .NO);
	print_float(*builder, format=format);
	return builder_to_string(*builder, temp);
}

is_power_of_two :: (x: s64) -> bool
{
 return (x & (x - 1)) == 0;
}

Range2 :: struct
{
 x, y, z, w: float;
 
 #place x; min: Vector2;
 #place z; max: Vector2;
}

Range1 :: struct
{
 min: float;
 max: float;
}

range_size :: (r: Range1) -> float
{
 return abs(r.max - r.min);
}

Quaternion_Identity :: Quaternion.{0, 0, 0, 1};

RED :: Vector4.{1, 0, 0, 1};
GREEN :: Vector4.{0, 1, 0, 1};
BLUE :: Vector4.{0, 0, 1, 1};
WHITE :: Vector4.{1, 1, 1, 1};
BLACK :: Vector4.{0, 0, 0, 1};
GRAY :: Vector4.{0.5, 0.5, 0.5, 1};

rbg_helper :: (r: float, g: float, b: float, a: = 1.0) -> Vector4
{
 return xyzw(r/255.0, g/255.0, b/255.0, a);
}

hex_to_rgba :: (hex: s64) -> Vector4
{
	r : u8 = xx(hex >> 24) & 0x000000FF;
	g : u8 = xx(hex >> 16) & 0x000000FF;
	b : u8 = xx(hex >> 8) & 0x000000FF;
	a : u8 = xx(hex >> 0) & 0x000000FF;
	return .{r/255.0, g/255.0, b/255.0, a/255.0};
}

highlight_colour :: (col: Vector4, strength: float) -> Vector4
{
	if (col.x + col.y + col.z) / 3.0 < 0.5
	{
		return col + xyzw(0.2, 0.2, 0.2, 0.2) * strength;
	}
	else
	{
		return col - xyzw(0.1, 0.1, 0.1, 0.1) * strength;
	}
}

//
// A reusable field of properties/flags that can grow past the 64-bit limitation
// BYO enum list of properties with a COUNT at the end.
//
Properties :: struct(enum_type: $T)
{
 props: [(#run enum_highest_value(enum_type)+63)/64]u64;
}

make_props :: (props: .. $T) -> Properties(T)
{
 properties: Properties(T);
 for props
 {
  add_props(*properties, it);
 }
 return properties;
}

// returns true if any of the properties match
match_props_any :: (a: Properties, b: Properties) -> bool
{
 #assert a.enum_type == b.enum_type;
 match := false;
 for a.props
 {
  if it & b.props[it_index] != 0
  {
   match = true;
   break;
  }
 }
 return match;
}

// returns true if properties are identical
match_props_all :: (a: Properties, b: Properties) -> bool
{
 #assert a.enum_type == b.enum_type;
 match := true;
 for a.props
 {
  if it != b.props[it_index]
  {
   match = false;
   break;
  }
 }
 return match;
}

has_any_props :: (properties: Properties, any: .. properties.enum_type) -> bool
{
 assert(false, "this is broken lol");
 match := false;
 for prop_it: properties.props
 {
  for any
  {
   match = match || !!(prop_it & xx it);
  }
 }
 return match;
}

merge_props :: (dest: *Properties, source: Properties)
{
 #assert dest.enum_type == source.enum_type;
 for * dest.props
 {
  <<it |= source.props[it_index];
 }
}

add_props :: (properties: *Properties, to_add: .. properties.enum_type)
{
 for to_add
 {
  slot := it / 64;
  properties.props[slot] |= cast(u64)1 << (it % 64);
 }
}

remove_props :: (properties: *Properties, to_remove: .. properties.enum_type)
{
 for to_remove
 {
  slot := it / 64;
  properties.props[slot] &= ~(cast(u64)1 << (it % 64));
 }
}

remove_props :: (properties: *Properties, to_remove: Properties)
{
	for to_remove.props
	{
		properties.props[it_index] &= ~it;
	}
}

has_prop :: (properties: Properties, prop: properties.enum_type) -> bool
{
 slot := cast(u64)prop / 64;
 return xx (properties.props[slot] & (cast(u64)1 << (prop % 64)));
}

props_to_string :: (properties: Properties) -> string
{
	builder: String_Builder;
	for 0..properties.enum_type.max-1
 {
 	prop := cast(properties.enum_type)it;
 	if has_prop(properties, prop)
 	{
 		print_to_builder(*builder, "%, ", prop);
 	}
 }
	return builder_to_string(*builder);
}

//

is_any :: (state: $T, any: .. T) -> bool
{
	for any
		if it == state then return true;
	return false;
}

get_cardinal_projection :: () -> Matrix4 #expand
{
 w := `app.window_w;
 h := `app.window_h;
 return orthographic_projection_matrix(w * -0.5, w * 0.5, h * -0.5, h * 0.5, 1, 100, depth_range_01=true);
}

get_screen_projection :: (window_w: float, window_h: float) -> Matrix4
{
 return orthographic_projection_matrix(0, window_w, window_h, 0, 1, 100, depth_range_01=true);
}



screen_mouse_to_cardinal :: (right_handed: bool = true) -> Vector2 #expand
{
 w := `app.window_w;
 h := `app.window_h;
 result := `app.mouse_pos;
 result.x -= w * 0.5;
 if right_handed
 {
  result.y -= h * 0.5;
 }
 else
 {
  result.y += h * 0.5;
  result.y = h - result.y;
 }
 return result;
}

mouse_pos_for_ui :: () -> Vector2 #expand
{
	
}

mouse_pos_in_world :: () -> Vector2 #expand
{
 w := `app.window_w;
 h := `app.window_h;
 pos := `app.mouse_pos; // assuming this is right handed
 pos.x -= w * 0.5;
 pos.y -= h * 0.25;
 
 pos /= `app.camera.zoom;
 pos += `app.camera.position;
 return pos;
}

s16_to_float :: (v: s16) -> float
{
 return v / cast(float) S16_MAX;
}

// enum_highest_value - already exists ya silly goose
// enum_count :: ($enumeration: $T) -> int
// {
// 	enum_info : Type_Info_Enum = type_info(enumeration);
// 	return enum_info.names.count;
// }

// inserts at [0] by shifting array down one, removing the last index
array_insert_start :: (array: []$T, element: T)
{
 t_size :: size_of(T);
 temp := NewArray(array.count, T); // store copy of array
 memcpy(temp.data, array.data, t_size * array.count);
 
 memcpy(*array[1], *temp[0], t_size * (array.count - 1));
 array[0] = element;
}

make_array :: ($size: int, $items: .. $T) -> [size]T
{
 #assert items.count <= size;
 arr: [size]T;
 for items
 {
  arr[it_index] = it;
 }
 return arr;
}

memory_zero :: (data: *$T)
{
	memset(data, 0, size_of(T));
}

array_shuffle :: (arr: *[..]$T)
{
	for < arr.count-1 .. 1
	{
		i := random_int_range(0, it);
		Swap(*(<<arr)[it], *(<<arr)[i]);
	}
}

// randy: Returns a temporary array with pointers to the valid non-empty elements of the flat array
// Seems kinda error-prone, but might be useful? Idk bro, I didn't even end up using it lol.
flat_array_valid_elements :: (flat_array: []$T) -> []*T
{
	count := array_count(flat_array);
	array := NewArray(count, *T, allocator=temp);
	
	empty := T.{};
	index := 0;
	for * flat_array
		if memcmp(it, *empty, size_of(T)) != 0
	{
		array[index] = it;
	}
	
	return array;
}

array_count :: (flat_array: []$T) -> int
{
	count := 0;
	empty := T.{};
	for * flat_array
		if memcmp(it, *empty, size_of(T)) != 0
	{
		count += 1;
	}
	return count;
}

// I'd like to have these flat array helpers as pointers so it's clear we're mutating
// data, but the compiler doesn't like that and idk how to get around it.
array_reset :: (flat_array: []$T)
{
	for * flat_array
	{
		<<it = T.{};
	}
}
array_add :: (flat_array: []$T, element: T)
{
	empty := T.{};
	for * flat_array
		if memcmp(it, *empty, size_of(T)) == 0
	{
		<<it = element;
		return;
	}
}
array_copy :: (dest: []$T, source: []T)
{
 memcpy(dest.data, source.data, size_of(T) * min(dest.count, source.count));
}
string_copy :: (dest: []u8, source: string)
{
 memcpy(dest.data, source.data, min(dest.count, source.count));
}

snake_to_pretty_string :: (snake_string: string) -> string
{
	name := copy_string(snake_string, temp);
	for 0..name.count
	{
		c := *name.data[it];
		if <<c == #char "_"
		{
			<<c = #char " ";
			first_letter := *name.data[it+1];
			<<first_letter = to_upper(<<first_letter);
		}
	}
	if name.count > 0
	{
		name.data[0] = to_upper(name.data[0]);
	}
	return name;
}

from_c_string :: (c_string: *u8) -> string
{
	if c_string == null return "";

 s: string = ---;
 s.data = xx c_string;
 s.count = xx c_style_strlen(xx c_string);
 
 return s;
}

// s8 version
from_c_string :: (c_string: *s8) -> string
{
 if c_string == null return "";

 s: string = ---;
 s.data = xx c_string;
 s.count = xx c_style_strlen(xx c_string);

 return s;
}

find_substring :: (haystack: string, needle: string, start_pos: int = 0) -> s64
{
 found: s64 = -1;
 remaining := haystack;
 for 0..haystack.count-1
 {
  potential := remaining;
  potential.count = needle.count;
  if potential == needle
  {
   found = it;
   break;
  }
  remaining = advance(remaining);
 }
 return found;
}

// has_extension :: (name: string, extension: string) -> bool
// {
//  if name.count < extension.count  return false;
//  test := name;
//  advance(*test, name.count - extension.count);
//  return test == extension;
// }

// get_extension :: (path: string) -> string
// {
//  extension: string;
//  for 0..path.count-1
//  {
//   from_end := path.count-1 - it;
//   extension.count += 1;
//   extension.data = *path[from_end];
//   if path[from_end] == #char "." then break;
//  }
//  return extension;
// }

offset_of :: ($struct_type: Type, name: string) -> int
{
 info := type_info(struct_type);
 for info.members if it.name == name return it.offset_in_bytes;
 log_error("member % not found!", name);
 assert(false);
 return 0;
}

get_window_rect :: () -> s32, s32 #expand // lol
{
 rc: `RECT;
 `GetClientRect(`hwnd, *rc); 
 width := rc.right - rc.left; 
 height := rc.bottom - rc.top;
 return width, height;
}

kilobytes :: (n: u32) -> u32 { return n << 10; }
megabytes :: (n: u32) -> u32 { return n << 20; }
gigabytes :: (n: u64) -> u64 { return n << 30; }
terabytes :: (n: u64) -> u64 { return n << 40; }

Axis2 :: enum
{
 INVALID :: -1;
 X :: 0;
 Y :: 1;
 COUNT :: 2;
}

Axis3 :: enum
{
 INVALID :: -1;
 X :: 0;
 Y :: 1;
 Z :: 3;
 COUNT :: 4;
}

axis_flip :: (axis: Axis2) -> Axis2
{
 return ifx axis == .X then Axis2.Y else Axis2.X;
}

degrees_to_radians :: (degrees: float) -> float
{
 return degrees * PI / 180.0;
}

degrees_to_radians :: (degree_vec: Vector3) -> Vector3
{
 result := degree_vec;
 result.x = degrees_to_radians(result.x);
 result.y = degrees_to_radians(result.y);
 result.z = degrees_to_radians(result.z);
 return result;
}


radians_to_degrees :: (radians: float) -> float
{
 return radians * 180.0 / PI;
}

// milliseconds to seconds
ms_to_s :: inline (seconds: float) -> float
{
	return seconds / 1000.0;
}

tick_timer :: (timer: *float, delta_t: float, zero_counts_as_complete := false) -> bool #must #expand
{
 did_complete: bool;
 if <<timer != 0
 {
  <<timer -= delta_t;
  if <<timer < 0
  {
   <<timer = 0;
   did_complete = true;
  }
 }
 else if zero_counts_as_complete then did_complete = true;
 return did_complete;
}

// randy: NOTE
// this will get fucked on low frame counts
tick_on_app_frequency :: (frequency_in_seconds: float) -> bool #expand
{
	return (`app.frame_count % max(cast(u64)(`app.refresh_rate * frequency_in_seconds), 1)) == 0;
}

tick_on_world_frequency :: (frequency_in_seconds: float) -> bool #expand
{
	// TODO - this is hard :(
	fmod_cycling(app.world.time_elapsed, frequency_in_seconds);
	
	return (`app.frame_count % cast(u64)(`app.refresh_rate * frequency_in_seconds)) == 0;
}

// copied from Array.jai - modified to take in a [..] since the autocast has something fuckie going on
array_find :: (array: [..] $T, item: T) -> bool, s64 {
 for array if it == item return true, it_index; 
 return false, -1;  // Not found.
}

// :windows
#import "Windows";
#import "Machine_X64";

get_rdtsc_frequency :: () -> u64
{
	frequency: s64 = ---; QueryPerformanceFrequency(*frequency);
	
	qpc_begin: s64 = ---; QueryPerformanceCounter(*qpc_begin);
	tsc_begin:= rdtsc();
	Sleep(2);
	qpc_end: s64 = ---; QueryPerformanceCounter(*qpc_end);
	tsc_end:= rdtsc();
	
	tsc_freq := (tsc_end - tsc_begin) * xx frequency / xx (qpc_end - qpc_begin);
	return tsc_freq;
}


// :RANDOM STUFF
#import "Random";
// random_get();

get_chaos_seed :: () -> u64
{
	apollo := current_time_consensus(); 
	return apollo.low * xx apollo.high;
}

push_random_seed :: (new_seed: u64) #expand
{
	prev_state := context.random_state;
	random_seed(new_seed);
	`defer context.random_state = prev_state;
}

random_pct :: (percent_chance: float) -> bool
{
	return random_get_within_range(0.0, 1.0) <= percent_chance;
}

random_bool :: () -> bool
{
	return random_get() % 2 == 0;
}

random_sign :: () -> float
{
	return ifx random_get() % 2 == 0 then -1.0 else 1.0;
}

random_int_range :: (minimum: int, maximum: int) -> int
{
	range:u64= xx abs(maximum-minimum);
	return min(minimum, maximum) + cast(int)(random_get() % (range+1));
}



// returns -1, 0, or 1
sign :: (f: float) -> s8
{
 return (cast(s8) (f > 0) - cast(s8) (f < 0));
}

FloatInt32 :: union {
 _u32:     u32;
 _s32:     s32;
 _float: float;
}

sign_from_bit :: (f: float) -> float
{
	value: FloatInt32 = ---;
	value._float = f;
	return ifx (value._u32 & 0x8000_0000) == 0 then 1.0 else -1.0;
}

// returns -1 or 1 (0 gets forced into 1)
sign_positive :: (f: float) -> s8
{
 v:= sign(f);
 return ifx v == 0 then 1 else v;
}

almost_zero :: (a: float, epsilon: float = 0.001) -> bool
{
 return almost_equals(a, 0, epsilon);
}

almost_equals :: (a: float, b: float, epsilon: float = 0.001) -> bool
{
 return abs(a - b) <= epsilon;
}

almost_equals :: (a: Vector2, b: Vector2, epsilon: float = 0.001) -> bool
{
 return almost_equals(a.x, b.x, epsilon) && almost_equals(a.y, b.y, epsilon);
}

clamp_bottom :: inline (a: $T, b: T) -> T
{
	return max(a, b);
}
clamp_top :: inline (a: $T, b: T) -> T
{
	return min(a, b);
}

float_alpha :: (x: float, min: float, max: float, $clamp_result: bool = true) -> float
{
	res := (x - min) / (max - min);
	#if clamp_result then res = clamp(res, 0, 1);
	return res;
}

float_map :: (x: float, x_min: float, x_max: float, to_min: float, to_max: float, $clamp_result:= true) -> float
{
	res := ((x - x_min) / (x_max - x_min) * (to_max - to_min) + to_min);
	// clamp the result, swapping min/max if necessary
	#if clamp_result then res = clamp(res, min(to_min, to_max), max(to_max, to_min));
 return res;
}

// true if the same, false if different
compare_memory :: (a: $T, b: T) -> bool
{
	return memcmp(*a, *b, size_of(T)) == 0;
}

make_range :: (min: float, max: float, $auto_correct:=true) -> Range1
{
	r := Range1.{min, max};
	#if auto_correct then if r.min > r.max then Swap(*r.min, *r.max);
	return r;
}

make_range :: (size: Vector2, pivot: Pivot = .center_center, shifter: Vector2 = .{}) -> Range2
{
 return make_range(.{}, size, pivot, shifter);
}

make_range :: (min: Vector2, max: Vector2, pivot: Pivot = .bottom_left, shifter: Vector2 = .{}, $auto_correct:=true) -> Range2
{
 result := Range2.{min.x, min.y, max.x, max.y};
 result = range_pivot(result, pivot);
 result = range_shift(result, shifter);
 #if auto_correct then result = range_correct(result);
 return result;
}

PivotX :: enum
{
 left;
 center;
 right;
}

PivotY :: enum
{
 bottom;
 center;
 top;
}

Pivot :: enum
{
 bottom_left;
 center_center;
 bottom_center;
 center_left;
 center_right;
 top_center;
 top_right;
}

range_pivot :: (range: Range2, pivot: Pivot) -> Range2
{
 result := range;
 if pivot ==
 {
  case .bottom_left;
  return result;

  case .center_center;
  return range_center_center(result);

  case .bottom_center;
  return range_bottom_center(result);
  
  case .center_left;
  return range_center_left(result);
  
  case .top_center;
  return range_top_center(result);
  
  case .top_right;
  return range_top_right(result);

  case;
  assert(false);
  return result;
 }
}

range_pad :: (r: Range2, v: Vector2) -> Range2
{
 result := r;
 result.min -= v;
 result.max += v;
 return result;
}

range_correct :: (r: Range2) -> Range2
{
 result := r;
 if result.min.x > result.max.x then Swap(*result.min.x, *result.max.x);
 if result.min.y > result.max.y then Swap(*result.min.y, *result.max.y);
 return result;
}
range_correct :: (r: Range1) -> Range1
{
 result := r;
 if result.min > result.max then Swap(*result.min, *result.max);
 return result;
}

range_contains :: (r: Range2, p: Vector2) -> bool
{
 result := r.min.x <= p.x && p.x <= r.max.x;
 result &= r.min.y <= p.y && p.y <= r.max.y;
 return result;
}
range_contains :: (r: Range1, p: float) -> bool
{
 return r.min <= p && p <= r.max;
}

range_overlaps :: range_collide;
range_collide :: (a: Range1, b: Range1) -> bool
{
	result := range_contains(a, b.min);
 result |= range_contains(a, b.max);
 result |= range_contains(b, a.min);
 result |= range_contains(b, a.max);
 return result;
}

range_collide :: (a: Range2, b: Range2) -> bool
{
 result := range_contains(b, a.min);
 result |= range_contains(b, a.max);
 result |= range_contains(a, b.min);
 result |= range_contains(a, b.max);
 return result;
}

range_size :: (r: Range2) -> Vector2
{
 return xy(abs(r.max.x - r.min.x), abs(r.max.y - r.min.y));
}

range_normalise :: (r: Range2) -> Range2
{
 result: Range2;
 result.max = range_size(r);
 return result;
}

range_shift :: (r: Range2, v: Vector2) -> Range2
{
 result:= r;
 result.min += v;
 result.max += v;
 return result;
}
range_shift :: (r: Range1, v: float) -> Range1
{
 result:= r;
 result.min += v;
 result.max += v;
 return result;
}

range_scale :: (r: Range2, s: float) -> Range2
{
 result := r;
 result.min *= s;
 result.max *= s;
 return result;
}
operator* :: (r: Range2, s: float) -> Range2
{
 return range_scale(r, s);
}

range_scale :: (r: Range2, s: Vector2) -> Range2
{
 result := r;
 result.min.x *= s.x;
 result.min.y *= s.y;
 result.max.x *= s.x;
 result.max.y *= s.y;
 return result;
}
operator* :: (r: Range2, s: Vector2) -> Range2
{
 return range_scale(r, s);
}

// flips rect horizontally, around 0
range_flip_x :: (r: Range2) -> Range2
{
 result:= r;
 result.min.x *= -1;
 result.max.x *= -1;
 Swap(*result.min.x, *result.max.x);
 return result;
}

range_bottom_center :: (r: Range2) -> Range2
{
 result:= r;
 size:= range_size(r);
 result.min.x -= size.x * 0.5;
 result.max.x -= size.x * 0.5;
 return result;
}

range_center_left :: (r: Range2) -> Range2
{
 result:= r;
 size:= range_size(r);
 result.min.y -= size.y * 0.5;
 result.max.y -= size.y * 0.5;
 return result;
}

range_center_center :: (r: Range2) -> Range2
{
 size:= range_size(r);
 result:= r;
 result.min.x -= size.x * 0.5;
 result.max.x -= size.x * 0.5;
 result.min.y -= size.y * 0.5;
 result.max.y -= size.y * 0.5;
 return result;
}

range_top_center :: (r: Range2) -> Range2
{
 size:= range_size(r);
 result:= r;
 result.min.x -= size.x * 0.5;
 result.max.x -= size.x * 0.5;
 result.min.y -= size.y;
 result.max.y -= size.y;
 return result;
}

range_top_right :: (r: Range2) -> Range2
{
 size:= range_size(r);
 result:= r;
 result.min.x -= size.x;
 result.max.x -= size.x;
 result.min.y -= size.y;
 result.max.y -= size.y;
 return result;
}


make_rotation_matrix :: (rot: float) -> Matrix4
{
	return rotation_matrix(Matrix4, quaternion_pitch(rot));
}


// I think maybe I should start thinking of this as a chain of transform matricies
// because that's really what it is at the end of the day, a transform chain
// translate -> rotate -> pivot -> scale -> camera -> projection
// This'll solve a lot of issues if I can go in and swap around the order at will instead of guessing.

// randy: alright, so most of my issues stem from there actually not being a fine division between
// local / world / camera
// We needa have clear boundaries for this, so we can adjust local (even after we've submitted the world)
// and not have to worry about ordering, because they get multiplied afterwards at render-time.
// - 18-11-2023-074902

Transform2 :: struct
{
 translate: Vector2;
 rotate: float;
 scale: Vector2 = .{1, 1};
 pivot_offset: Vector2;
}

operator == :: (a: Transform2, b: Transform2) -> bool
{
 return a.translate == b.translate && a.rotate == b.rotate && a.scale == b.scale && a.pivot_offset == b.pivot_offset;
}

make_transform :: (translate: Vector2, rotate: float = 0, scale: float = 1, pivot: Vector2 = .{0, 0}) -> Transform2
{
 result: Transform2;
 result.translate = translate;
 result.rotate = rotate;
 result.scale = xy(scale);
 result.pivot_offset = pivot;
 return result;
}

blend_transforms :: (t1: Transform2, t2: Transform2, alpha: float) -> Transform2
{
	result: Transform2;
	result.translate = lerp(t1.translate, t2.translate, alpha);
	result.rotate = lerp(t1.rotate, t2.rotate, alpha);
	result.scale = lerp(t1.scale, t2.scale, alpha);
	result.pivot_offset = lerp(t1.pivot_offset, t2.pivot_offset, alpha);
	return result;
}

matrix_from_transform :: (trs: Transform2) -> Matrix4
{
 result: Matrix4;
 offset := make_translation_matrix4(make_vector3(trs.pivot_offset, 0));
 result = make_translation_matrix4(make_vector3(trs.translate, 0)) * inverse(offset) * rotation_matrix(Matrix4, quaternion_pitch(trs.rotate)) * make_scale_matrix4(xyz(trs.scale, 1)) * offset;
 return result;
}

merge_transform :: (a: Transform2, b: Transform2) -> Transform2
{
 result := a;
 result.translate += b.translate;
 result.scale *= b.scale;
 result.rotate += b.rotate; // not too sure what this should be...
 result.pivot_offset += b.pivot_offset;
 return result;
}


Transform3 :: struct
{
 translate: Vector3;
 rotate: Quaternion = Quaternion_Identity;
 scale: Vector3 = .{1, 1, 1};
 pivot_offset: Vector3;
}

/*
matrix_from_transform :: (trs: Transform3) -> Matrix4
{
 result: Matrix4;
 offset := make_translation_matrix4(trs.pivot_offset);
 result = make_translation_matrix4(make_vector3(trs.translate, 0)) * inverse(offset) * rotation_matrix(Matrix4, quaternion_pitch(trs.rotate)) * make_scale_matrix4(xyz(trs.scale, 1)) * offset;
 return result;
}
*/
merge_transform :: (a: Transform3, b: Transform3) -> Transform3
{
 result := a;
 result.translate += b.translate;
 result.scale *= b.scale;
 result.rotate *= b.rotate;
 result.pivot_offset += b.pivot_offset;
 return result;
}
quaternion_pitch :: (degrees: float) -> Quaternion
{
 quat: Quaternion;
 set_from_axis_and_angle(*quat, xyz(0, 0, 1), degrees_to_radians(degrees));
 return quat;
}

// why the fuck doesn't jai having rounding?
// am I just really stupid or something??
round :: (v: float) -> float
{
 decimals := v - floor(v);
 return floor(v) + ifx decimals >= 0.5 then 1 else 0;
}

// found this in the juicing / camera shake talk
// not sure what the difference is between this and my regular animate to target
// If I wanna figure it out -> https://www.desmos.com/calculator
/*
parametric_to_target :: (value: *float, target: float, pct:= 0.5, good_enough:= 0.001) -> bool #expand
{
	<<value += (target - value) * pct * delta_t_scaled();
	if almost_equals(<<value, target, good_enough)
 {
 	<<value = target;
 	return true; // reached
 }
 return false;
}
*/

animate_to_target :: (value: *float, target: float, delta_t: float, rate:= 15.0, good_enough:= 0.001) -> bool
{
 <<value += (target - <<value) * (1.0 - pow(2.0, -rate * delta_t));
 if almost_equals(<<value, target, good_enough)
 {
 	<<value = target;
 	return true; // reached
 }
 return false;
}

animate_to_target :: (value: *Vector2, target: Vector2, delta_t: float, rate := 15.0)
{
 value.x += (target.x - value.x) * (1.0 - pow(2.0, -rate * delta_t));
 value.y += (target.y - value.y) * (1.0 - pow(2.0, -rate * delta_t));
}

animate_to_target :: (value: *Vector4, target: Vector4, delta_t: float, rate := 15.0)
{
 value.x += (target.x - value.x) * (1.0 - pow(2.0, -rate * delta_t));
 value.y += (target.y - value.y) * (1.0 - pow(2.0, -rate * delta_t));
 value.z += (target.z - value.z) * (1.0 - pow(2.0, -rate * delta_t));
 value.w += (target.w - value.w) * (1.0 - pow(2.0, -rate * delta_t));
}

timer_to_target :: (value: *float, target: float, delta_t: float, rate := 1.0) -> bool
{
 if <<value != target
 {
  dir := sign(target - <<value);
  <<value += delta_t * rate * dir;
  
  new_dir := sign(target - <<value);
  if new_dir != dir // we've gone past the target
  {
   <<value = target;
   return true;
  }
 }
 return false;
}

sin_breathe :: (rate: float) -> float #expand
{
	return sin(cast(float)`g_world.time_elapsed * rate);
}

sin_alpha_from_time :: inline (time: float) -> float
{
	return (sin(time) + 1.0) / 2.0;
}

// EASINGS - https://easings.net/
// all designed to operate on alpha values, 0.0 -> 1.0

ease_sin_breathe :: (alpha: float) -> float
{
 return (sin((alpha - .25) * 2.0 * PI) / 2.0) + 0.5;
}

ease_in_out_cubic :: (alpha: float) -> float
{
 return ifx alpha < 0.5 then 4.0 * alpha * alpha * alpha else 1.0 - pow(-2.0 * alpha + 2.0, 3.0) / 2.0;
}

ease_in_cubic :: (alpha: float) -> float
{
 return alpha * alpha * alpha;
}

ease_out_exp :: (alpha: float, rate := 15.0) -> float
{
 return ifx alpha == 1.0 then 1.0 else 1.0 - pow(2, -rate * alpha);
}

ease_in_exp :: (alpha: float, rate := 15.0) -> float
{
 return ifx alpha == 0.0 then 0.0 else pow(2, rate * alpha - rate);
}




// :NOISE SHIT

// https://adrianb.io/2014/08/09/perlinnoise.html - figure out how this actually works lol

// goes from 0 -> 1
generate_perlin_noise_buffer :: (length: int, persistance: float, octave_count: int) -> []float #expand
{
	push_allocator(temp);
	gradients := NewArray(length, float);
	for * gradients
	{
		<<it = random_get_within_range(-1.0, 1.0);
	}
	
	frequency := `app.world_gen.freq;
	amp := 1.0;
	total_amp : float;
	noise := NewArray(length, float);
	
	for octave : 0..octave_count-1
	{
		for 0..length-1
		{
			sample_index : float = it * frequency;
			left : int = xx floor(sample_index);
			right : int = left + 1;
			frac := sample_index - left;
			
			interpolated := (1.0 - frac) * gradients[left % length] + frac * gradients[right % length];
			
			noise[it] += interpolated * amp;
		}
		
		frequency *= 2.0;
		total_amp += amp;
		amp *= persistance;
	}
	
	for * noise
	{
		<<it = (<<it / total_amp + 1.0) / 2.0;
	}
	
	return noise;
}