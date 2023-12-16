draw_sprite_deferred :: #bake_arguments draw_sprite_with_trs(deferred = true);
draw_sprite_deferred :: #bake_arguments draw_sprite_with_pos(deferred = true);
draw_rect_deferred :: #bake_arguments draw_rect(deferred = true);
draw_sprite :: draw_sprite_with_trs;
draw_sprite :: draw_sprite_with_pos;

draw_sprite_with_transform :: (
	  sprite_id: SpriteID
	, transform: Matrix4
	, z_layer: float = 0	
	, animation_index: int = 0
	, col: Vector4 = WHITE
	, colour_override: Vector4 = .{}
	, white_override: float = 0.0
	, flags: QuadFlags=0
	, $deferred: bool = false
) -> *DeferredQuadCommand
{
	sprite := get_resource(sprite_id);
	if !(sprite.flags & .sprite)
		sprite = get_resource(get_display_sprite_id(sprite));
	texture := texture_from_sprite(sprite);
		
	// uvs
	uv_rect := sprite.rect;
	uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * animation_index, 0.0));
	uv_rect.min.x /= texture.width;
	uv_rect.min.y /= texture.height;
	uv_rect.max.x /= texture.width;
	uv_rect.max.y /= texture.height;
	
	// if flags & .x_flipped
	// 	Swap(*uv_rect.min.x, *uv_rect.max.x);
	if !(flags & .inverse_y) {
		uv_rect.min.y = 1.0 - uv_rect.min.y;
		uv_rect.max.y = 1.0 - uv_rect.max.y;
	}
	
	// local rect, inferred from sprite
	rect := range_normalise(sprite.rect);
	
	/*
	// transform, incorporating offset from the sprite 
	flipped_dir := (ifx flags & .x_flipped then -1.0 else 1.0);
	local_trs: Transform2;
	local_trs.translate.x += flipped_dir * (sprite.offset.x + offset_trs.translate.x);
	local_trs.translate.y += sprite.offset.y + offset_trs.translate.y;
	local_trs.pivot_offset += sprite.offset + offset_trs.pivot_offset * xy(flipped_dir, 1.0);
	local_trs.rotate = offset_trs.rotate * flipped_dir;
	local_trs.scale = offset_trs.scale;
	local_trs = merge_transform(local_trs, trs);
	local_trs = merge_transform(render_st.stack_transform, local_trs);
	
	if flags & .slice_x_from_right {
		local_trs.scale.x *= slice_pct;
		local_trs.pivot_offset.x += range_size(rect).x * 0.5;
	} else if flags & .slice_x_from_left {
		local_trs.scale.x *= slice_pct;
		local_trs.pivot_offset.x -= range_size(rect).x * 0.5;
	}
	*/
	
	batch_set_texture(texture);
	corners := transformed_corners_from_rect(rect, transform);
	corners_uv := ifx texture uv_corners_from_rect(uv_rect) else DEFAULT_UV_CORNERS;
	#if deferred
	{
		return deferred_draw_append(corners, z_layer, col, corners_uv, colour_override, white_override);
	}
	else
	{
		batch_append_quad(corners, z_layer, col, corners_uv, colour_override, white_override);
		return null;
	}
}

// for drawing a sprite with inferred rect 
draw_sprite_with_trs :: (
	  sprite_id: SpriteID
	, trs: Transform2
	, offset_trs: Transform2 = .{}
	, z_layer: float = 0	
	, animation_index: int = 0
	, sprite_pivot: Pivot = .bottom_center
	, slice_pct :float= 1.0 // only used from 1 place currently :(
	, col: Vector4 = WHITE
	, colour_override: Vector4 = .{}
	, white_override: float = 0.0
	, flags: QuadFlags=0
	, $deferred: bool = false
	, sortingTiebreaker: u64 = 0
){
	sprite := get_resource(sprite_id);
	if !(sprite.flags & .sprite)
		sprite = get_resource(get_display_sprite_id(sprite));
	texture := texture_from_sprite(sprite);
		
	// uvs
	uv_rect := sprite.rect;
	uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * animation_index, 0.0));
	uv_rect.min.x /= texture.width;
	uv_rect.min.y /= texture.height;
	uv_rect.max.x /= texture.width;
	uv_rect.max.y /= texture.height;
	
	if flags & .slice_x_from_right
		uv_rect.max.x *= slice_pct;
	else if flags & .slice_x_from_left
		uv_rect.min.x += (1-slice_pct) * range_size(uv_rect).x;
		
	if flags & .x_flipped
		Swap(*uv_rect.min.x, *uv_rect.max.x);
	if !(flags & .inverse_y) {
		uv_rect.min.y = 1.0 - uv_rect.min.y;
		uv_rect.max.y = 1.0 - uv_rect.max.y;
	}
	
	// local rect, inferred from sprite
	rect := range_normalise(sprite.rect);
	rect = range_pivot(rect, sprite_pivot);
	rect = range_correct(rect); // maybe not needed?
	
	// transform, incorporating offset from the sprite 
	flipped_dir := (ifx flags & .x_flipped then -1.0 else 1.0);
	local_trs: Transform2;
	local_trs.translate.x += flipped_dir * (sprite.offset.x + offset_trs.translate.x);
	local_trs.translate.y += sprite.offset.y + offset_trs.translate.y;
	local_trs.pivot_offset += sprite.offset + offset_trs.pivot_offset * xy(flipped_dir, 1.0);
	local_trs.rotate = offset_trs.rotate * flipped_dir;
	local_trs.scale = offset_trs.scale;
	local_trs = merge_transform(local_trs, trs);
	
	if flags & .slice_x_from_right {
		local_trs.scale.x *= slice_pct;
		local_trs.pivot_offset.x += range_size(rect).x * 0.5;
	} else if flags & .slice_x_from_left {
		local_trs.scale.x *= slice_pct;
		local_trs.pivot_offset.x -= range_size(rect).x * 0.5;
	}
	
	batch_set_texture(texture);
	corners := transformed_corners_from_rect(rect, local_trs);
	corners_uv := ifx texture uv_corners_from_rect(uv_rect) else DEFAULT_UV_CORNERS;
	#if deferred deferred_draw_append(corners, z_layer, col, corners_uv, colour_override, white_override);
	else         batch_append_quad(corners, z_layer, col, corners_uv, colour_override, white_override);
}

// version with just position instead of full transform
draw_sprite_with_pos :: inline (
	  sprite_id: SpriteID
	, pos: Vector2
	, offset_trs: Transform2 = .{}
	, z_layer: float = 0	
	, animation_index: int = 0
	, sprite_pivot: Pivot = .bottom_center
	, slice_pct :float= 1.0 // only used from 1 place currently :(
	, col: Vector4 = WHITE
	, colour_override: Vector4 = .{}
	, white_override: float = 0.0
	, flags: QuadFlags=0
	, $deferred: bool = false
	, sortingTiebreaker: u64 = 0
){
	draw_sprite(
		  sprite_id
		, Transform2.{translate = pos}
		, offset_trs = offset_trs
		, z_layer = z_layer
		, animation_index = animation_index
		, sprite_pivot = sprite_pivot
		, slice_pct  = slice_pct 
		, col = col
		, colour_override = colour_override
		, white_override = white_override
		, flags = flags
		, deferred = deferred
		, sortingTiebreaker = sortingTiebreaker
	);
}

draw_rect :: (
	  rect: Range2
	, trs: Transform2 = .{}
	, texture: *ArcResource = null
	, uv_rect: Range2 = DEFAULT_UV
	, slice_pct: float = 1.0
	, z_layer: float = 0	
	, col: Vector4 = WHITE
	, colour_override: Vector4 = .{}
	, white_override: float = 0.0
	, flags: QuadFlags=0
	, $deferred: bool = false
	, sortingTiebreaker: u64 = 0
){
	
	// transform, incorporating offset from the sprite 
	local_trs := trs;
	if flags & .slice_x_from_right {
		local_trs.scale.x *= slice_pct;
		local_trs.pivot_offset.x += range_size(rect).x * 0.5;
	} else if flags & .slice_x_from_left {
		local_trs.scale.x *= slice_pct;
		local_trs.pivot_offset.x -= range_size(rect).x * 0.5;
	}
	
	// uvs
	corners_uv := DEFAULT_UV_CORNERS;
	if texture {
		_uv_rect := uv_rect;
		if flags & .slice_x_from_right
			_uv_rect.max.x *= slice_pct;
		else if flags & .slice_x_from_left
			_uv_rect.min.x += (1-slice_pct) * range_size(_uv_rect).x;
			
		if flags & .x_flipped
			Swap(*_uv_rect.min.x, *_uv_rect.max.x);
		if !(flags & .inverse_y) {
			_uv_rect.min.y = 1.0 - _uv_rect.min.y;
			_uv_rect.max.y = 1.0 - _uv_rect.max.y;
		}
		corners_uv = uv_corners_from_rect(_uv_rect);
	}

	batch_set_texture(texture);
	corners := transformed_corners_from_rect(rect, local_trs);
	#if deferred deferred_draw_append(corners, z_layer, col, corners_uv, colour_override, white_override);
	else         batch_append_quad(corners, z_layer, col, corners_uv, colour_override, white_override);
}

transformed_corners_from_rect :: inline (rect: Range2, transform: Matrix4) -> [4]Vector2
{
	// randy: I cbf doing this properly with a single 2D point lol
	return Vector2.[
		multiply(transform, Vector4.{rect.min.x, rect.min.y, 0.0, 1.0}).xy,
		multiply(transform, Vector4.{rect.min.x, rect.max.y, 0.0, 1.0}).xy,
		multiply(transform, Vector4.{rect.max.x, rect.max.y, 0.0, 1.0}).xy,
		multiply(transform, Vector4.{rect.max.x, rect.min.y, 0.0, 1.0}).xy,
	];
}

transformed_corners_from_rect :: inline (rect: Range2, trs: Transform2) -> [4]Vector2
{
	return Vector2.[
		transform_point(trs, Vector2.{rect.min.x, rect.min.y}),
		transform_point(trs, Vector2.{rect.min.x, rect.max.y}),
		transform_point(trs, Vector2.{rect.max.x, rect.max.y}),
		transform_point(trs, Vector2.{rect.max.x, rect.min.y}),
	];
}

uv_corners_from_rect :: inline (rect: Range2) -> [4]Vector2
{
	return Vector2.[
		rect.min,
		xy(rect.min.x, rect.max.y),
		rect.max,
		xy(rect.max.x, rect.min.y),
	];
}

/*
adjust_colors_for_entity :: (en: Entity, base_color: *Vector4, colour_override: *Vector4, white_override: *float)
{
	base_color.* *= en.frame.colour_multiplier;
	if has_prop(en.props, .petrified) {
		STONE_GRAY :: Vector4.{0.5, 0.5, 0.6, 1.0};
		colour_override.* = Vector4.{xyz = STONE_GRAY.xyz, w = 0.9};
	}
	white_override.* = en.white_override;
	white_override.* += en.interactable_alpha * 0.2;
	if en.damage_alpha != 0
		white_override.* = 1.0;
}
*/

apply_entity_adjustments_to_cmd :: (en: Entity, cmd: *DeferredQuadCommand)
{
	cmd.col = en.col * en.frame.colour_multiplier;
	
	cmd.white_override = en.white_override;
	cmd.white_override += en.interactable_alpha * 0.2;
	if en.damage_timer != 0 // dmg flash
	{
		// randy: TODO - proper math function :) 
		if en.damage_timer > DAMAGE_TIMER_LENGTH * 0.5
		{
			cmd.white_override = 1.0;
		}
	}
	
	if has_prop(en.props, .petrified)
	{
		STONE_GRAY :: Vector4.{0.5, 0.5, 0.6, 1.0};
		cmd.col_override = STONE_GRAY;
		cmd.col_override.w = 0.9;
	}
}

// NOTE :: draw_entity always goes to the deferred draw list
// this can be compressed now with the other procs now... but I aint doin it rn (Stef)
draw_entity :: (
	en: Entity
	, trs_adjust:Transform2=.{}
	, colorMultuply: Vector4 = WHITE
	, _colour_override: Vector4 = .{}
	)
{
	// skip the big stuff in hands
	if get_held_entity().id == en.id && has_prop(en.props, .reduce_render_scale)
		return;
		
	colour_override := _colour_override;
	
	local_trs: Transform2;
	render_trs: Transform2;
	
	sprite := get_sprite(en.sprite_id);
	texture := texture_from_sprite(sprite);
	
	// grab the UV coords, apply animation frame as well
	uv_rect := sprite.rect;
	uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * en.sprite_anim.frame, 0.0));
	uv_rect.min.x /= texture.width;
	uv_rect.min.y /= texture.height;
	uv_rect.max.x /= texture.width;
	uv_rect.max.y /= texture.height;
	
	flip_x := en.x_dir == -1;
	if en.flip_sprite then flip_x = !flip_x;
	
	flags: QuadFlags;
	flags = ifx flip_x then QuadFlags.x_flipped else 0;
	
	
	// apply the local render offset
	local_trs = en.render_offset;
	ifx en.x_dir == -1 then local_trs.translate.x *= -1;
	
	// apply the resource's sprite offsets
	local_trs.translate.x += en.x_dir * sprite.offset.x;
	local_trs.translate.y += sprite.offset.y;
	local_trs.pivot_offset += sprite.offset;
	
	// final rendering position
	render_trs.translate = en.pos;
	
	// if en.parallax.x != 0 then render_trs.translate.x += app.camera.position.x * en.parallax.x;
	
	col := en.col;
	col *= colorMultuply;
	col *= en.frame.colour_multiplier;
	
	trs:= merge_transform(local_trs, render_trs);
	trs= merge_transform(trs, trs_adjust);
	
	
	sprite_pivot := Pivot.bottom_center;
	
	// player-specific
	if en.id == get_player().id && contains(sprite.name, "char_")
	{
		colour_override = hex_to_rgba(0xffe2c3ff);
		colour_override.w = 1; // redundant
	}
	
	// infer the rect from sprite
	rect: Range2;
	rect = range_normalise(sprite.rect);
	rect = range_pivot(rect, sprite_pivot);
	rect = range_correct(rect);
	
	
	slice_pct :float= 1.0;
	
	if flags & .slice_x_from_right
	{
		trs.scale.x *= slice_pct;
		trs.pivot_offset.x += range_size(rect).x * 0.5;
	}
	else if flags & .slice_x_from_left
	{
		trs.scale.x *= slice_pct;
		trs.pivot_offset.x -= range_size(rect).x * 0.5;
	}


	if flags & .slice_x_from_right
		uv_rect.max.x *= slice_pct;
	else if flags & .slice_x_from_left
		uv_rect.min.x += (1-slice_pct) * range_size(uv_rect).x;
		
	if flags & .x_flipped
		Swap(*uv_rect.min.x, *uv_rect.max.x);
	if !(flags & .inverse_y) {
		uv_rect.min.y = 1.0 - uv_rect.min.y;
		uv_rect.max.y = 1.0 - uv_rect.max.y;
	}

	batch_set_texture(texture);
	corners := transformed_corners_from_rect(rect, trs);
	corners_uv := ifx texture uv_corners_from_rect(uv_rect) else DEFAULT_UV_CORNERS;
	cmd := deferred_draw_append(corners, en.z_layer, col, corners_uv, colour_override, 0.0, sortingTiebreaker = en.id);
	
	apply_entity_adjustments_to_cmd(en, cmd);
}



// NOTE (Stef) :: This deferred drawing api uses the current state of the batch api to set the texture and projection etc, which is a little gross
//                  but it is what it is for now, and it shouldnt actually result in more batches with the current usage code.
//                Also, it's is a little chungus but you still have the option of the non-deferred procs for things that dont need to be sorted
//                  Maybe there is a solution with flexible sorting that is not chungus, but it aint happening in this project
deferred_draw_append :: (
	  corners: [4]Vector2
	, zpos: float
	, col: Vector4
	, uvs: [4]Vector2 = DEFAULT_UV_CORNERS
	, col_override: Vector4 = .{}
	, white_override: float = 0.0
	, sortingTiebreaker: u64 = 0
) -> *DeferredQuadCommand
{
	group := *render_st.deferred_draw_group;
	cmd := array_add(*group.commands);
	cmd.corners = corners;
	cmd.zpos = zpos;
	cmd.col = col;
	cmd.uvs = uvs;
	cmd.col_override = col_override;
	cmd.white_override = white_override;
	cmd.tiebreaker = sortingTiebreaker;
	cmd.uniformsIndex = get_or_add_uniforms(group, render_st.batch.uniforms);
	cmd.texture = render_st.batch.texture;
	return cmd;
}
 
DeferredDrawGroup :: struct {
	uniforms: [..]BatchUniforms;
	commands: [..]DeferredQuadCommand;
	initted: bool;
}

// this is pretty chungus!
DeferredQuadCommand :: struct {
	corners: [4]Vector2;
	uvs: [4]Vector2;
	col: Vector4;
	col_override: Vector4;
	white_override: float;
	zpos: float;
	tiebreaker: u64;
	uniformsIndex: u32;
	texture: *Texture;
}

init_deferred_draw_group :: (using group: *DeferredDrawGroup)
{
	uniforms.allocator = context.default_allocator;
	commands.allocator = context.default_allocator;
	initted = true;
}

render_and_reset_deferred_draw_group :: (group: *DeferredDrawGroup)
{
	assert(group.initted);
	compare_proc :: (a: DeferredQuadCommand, b: DeferredQuadCommand) -> int
	{
		if a.zpos == b.zpos {
			if a.tiebreaker == b.tiebreaker return 0;
			else if a.tiebreaker > b.tiebreaker return 1;
			else return -1;
		}
		else if a.zpos < b.zpos return 1;
		else return -1;
	}
	quick_sort(group.commands, compare_proc);
	
	current_uniforms_index: int = -1;
	batch_flush();
	for group.commands {
		batch_set_texture(it.texture);
		if current_uniforms_index != xx it.uniformsIndex {
			batch_flush();
			current_uniforms_index = xx it.uniformsIndex;
			render_st.batch.uniforms = group.uniforms[current_uniforms_index];
			render_st.batch.texture = it.texture; // batch_flush nulls this out
		}
		
		batch_append_quad(
			it.corners,
			it.zpos,
			it.col,
			it.uvs,
			it.col_override,
			it.white_override,
		);
	}
	
	array_reset_keeping_memory(*group.uniforms);
	array_reset_keeping_memory(*group.commands);
}

get_or_add_uniforms :: (group: *DeferredDrawGroup, uniforms: BatchUniforms) -> index: u32
{
	existing: *BatchUniforms;
	for group.uniforms {
		if memcmp(*uniforms, *it, size_of(BatchUniforms)) == 0
			return cast(u32)it_index;
	}
	array_add(*group.uniforms, uniforms);
	// assert(uniforms.lut_strength <= 1); // TODO :: remove once we're certain this isn't an issue anymore
	// for group.uniforms assert(it.lut_strength <= 1); // TODO :: remove once we're certain this isn't an issue anymore
	return cast(u32)(group.uniforms.count-1);
}