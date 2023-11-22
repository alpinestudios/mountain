// - try to reduce the amount of work happening in draw_rect
//		- remove trs for non-worldspace things
//		- cache non-dynamic world vertex data, avoid trs multiplies
// - unwind drawing api, then recompress, cleaning up this horrific api
// - atlas all of the textures to achieve actual batching (should save a bit less than a ms)
// - re-introduce color override

// draw_rect is still the chungus, 1-2ms, so we can maybe get down to ~4ms with atlased textures, but that's without the sort... yikes...


DrawRectOptions :: struct {
	rect:= Range2.{};
	sprite_pivot:= Pivot.bottom_center;
	uv_rect: Range2 = DEFAULT_UV;
	sprite_id:= SpriteID.blank_tex;
	texture:*ArcResource= null;
	col:= WHITE;
	slice_pct:= 1.0;
	flags:QuadFlags=0;
	trs:= Transform2.{};
	white_override: float;
	colour_override: Vector4;
	colour_override_amount: float;
	z_layer: float = 0;
}

make_draw_opts :: (
	rect:= Range2.{},
	sprite_pivot:= Pivot.bottom_center,
	uv_rect: Range2 = DEFAULT_UV,
	sprite_id:= SpriteID.blank_tex,
	texture:*ArcResource= null,
	col:= WHITE,
	slice_pct:= 1.0,
	flags:QuadFlags=0,
	trs:= Transform2.{},
	white_override: float = 0,
	colour_override: Vector4 = .{},
	colour_override_amount: float = 0,
	z_layer: float = 0
) -> DrawRectOptions 
{
	return DrawRectOptions.{
		rect = rect,
		sprite_pivot = sprite_pivot,
		uv_rect = uv_rect,
		sprite_id = sprite_id,
		texture = texture,
		col = col,
		slice_pct = slice_pct,
		flags = flags,
		trs = trs,
		white_override = white_override,
		colour_override = colour_override,
		colour_override_amount = colour_override_amount,
		z_layer = z_layer,
	};
}

draw_rect :: (
	rect:= Range2.{},
	sprite_pivot:= Pivot.bottom_center,
	uv_rect: Range2 = DEFAULT_UV,
	sprite_id:= SpriteID.blank_tex,
	texture:*ArcResource= null,
	col:= WHITE,
	slice_pct:= 1.0,
	flags:QuadFlags=0,
	trs:= Transform2.{},
	white_override: float = 0,
	colour_override: Vector4 = .{},
	colour_override_amount: float = 0,
	z_layer: float = 0
	)
{
	opts := make_draw_opts(
		rect,
		sprite_pivot,
		uv_rect,
		sprite_id,
		texture,
		col,
		slice_pct,
		flags,
		trs,
		white_override,
		colour_override,
		colour_override_amount,
		z_layer,
	);
	draw_rect(opts);
}

draw_rect :: (using opts: DrawRectOptions)
{
	// do we use the sprite or texture?
	sprite : *Sprite = null;
	_texture := texture;
	_rect := rect;
	if _texture == null && sprite_id != 0
	{
		sprite = get_resource(sprite_id);
		assert(!!(sprite.flags & .sprite), "% doesn't have a sprite, set the display_sprite_id instead?", sprite_id);
		_texture = texture_from_sprite(sprite);
		
		// infer the rect from sprite
		if _rect.min == .{} && _rect.max == .{} 
		{
			if sprite_id == .blank_tex then log("No rect size, yet can't infer from sprite either?");
			_rect = range_normalise(sprite.rect);
			_rect = range_pivot(_rect, sprite_pivot);
		}
	}
	
	r := range_correct(_rect);
	final_trs := merge_transform(render_st.stack_transform, trs);
	if flags & .slice_x_from_right
	{
		final_trs.scale.x *= slice_pct;
		final_trs.pivot_offset.x += range_size(r).x * 0.5;
	}
	else if flags & .slice_x_from_left
	{
		final_trs.scale.x *= slice_pct;
		final_trs.pivot_offset.x -= range_size(r).x * 0.5;
	}
	
	assert(z_layer != 0.0, "Z_LAYER not provided");
	
	_uv_rect := uv_rect;
	if flags & .slice_x_from_right
		_uv_rect.max.x *= slice_pct;
	else if flags & .slice_x_from_left
		_uv_rect.min.x += (1-slice_pct) * range_size(_uv_rect).x;
		
	if flags & .x_flipped
		Swap(*_uv_rect.min.x, *_uv_rect.max.x);
	

	uvs := Vector2.[
		_uv_rect.min,
		xy(_uv_rect.min.x, _uv_rect.max.y),
		_uv_rect.max,
		xy(_uv_rect.max.x, _uv_rect.min.y),
	];
	if !(flags & .inverse_y) {
		uvs[0].y = 1.0 - uvs[0].y;
		uvs[1].y = 1.0 - uvs[1].y;
		uvs[2].y = 1.0 - uvs[2].y;
		uvs[3].y = 1.0 - uvs[3].y;
	}
	
	batch_set_texture(_texture);
	// trs_matrix := matrix_from_transform(final_trs);
	draw_transformed_rect(r, final_trs, -z_layer, col, uvs, Vector4.{xyz = colour_override.xyz, w = colour_override_amount}, white_override);

	// quad: Quad;
	// quad.flags = flags;
	// batch_render_quad :: (it: Quad)
	// {
	// 	batch := *render_st.batch;
	// 	batch_set_texture(it.texture);
	// 	verts := batch_reserve_verts(batch, 6);
	// 	verts[0] = .{it.p0.xyz, it.uv0, it.col, it.col_override, it.white_override};
	// 	verts[1] = .{it.p2.xyz, it.uv2, it.col, it.col_override, it.white_override};
	// 	verts[2] = .{it.p1.xyz, it.uv1, it.col, it.col_override, it.white_override};
	// 	verts[3] = verts[0];
	// 	verts[4] = .{it.p3.xyz, it.uv3, it.col, it.col_override, it.white_override};
	// 	verts[5] = verts[1];
	// }
	// batch_render_quad(quad);
}

// a sprite is auto-sized and could be animated
make_draw_opts_for_sprite :: (
	sprite_id: SpriteID
	, pos: Vector2
	, offset_trs:= Transform2.{}
	, flags:QuadFlags=0
	, slice_pct:=1.0
	, col:= WHITE
	, animation_index: int = 0
	, z_layer: float = 0
) -> DrawRectOptions
{
	sprite := get_resource(sprite_id);
	if !(sprite.flags & .sprite)
	{
		sprite = get_resource(get_display_sprite_id(sprite));
	}
	texture := texture_from_sprite(sprite);
	
	uv_rect := sprite.rect;
	uv_rect = range_shift(uv_rect, xy(range_size(uv_rect).x * animation_index, 0.0));
	uv_rect.min.x /= texture.width;
	uv_rect.min.y /= texture.height;
	uv_rect.max.x /= texture.width;
	uv_rect.max.y /= texture.height;
	
	render_trs := make_transform(pos);
	
	flipped_dir := (ifx flags & .x_flipped then -1.0 else 1.0);
	
	// this is kinda fucked, probs need to simplify transforms somehow...
	local_trs : Transform2;
	local_trs.translate.x += flipped_dir * (sprite.offset.x + offset_trs.translate.x);
	local_trs.translate.y += sprite.offset.y + offset_trs.translate.y;
	local_trs.pivot_offset += sprite.offset + offset_trs.pivot_offset * xy(flipped_dir, 1.0);
	local_trs.rotate = offset_trs.rotate * flipped_dir;
	local_trs.scale = offset_trs.scale;
	
	render_trs = merge_transform(local_trs, render_trs);
	
	opts := make_draw_opts(sprite_id=sprite.id, uv_rect=uv_rect, col=col, slice_pct=slice_pct, flags=flags, trs=render_trs, z_layer = z_layer);
	return opts;
}

draw_sprite :: (
	  sprite_id: SpriteID
	, pos: Vector2
	, offset_trs:= Transform2.{}
	, flags:QuadFlags=0
	, slice_pct:=1.0
	, col:= WHITE
	, animation_index: int = 0
	, z_layer: float = 0	
){
    opts := make_draw_opts_for_sprite(
        sprite_id,
        pos,
        offset_trs,
        flags,
        slice_pct,
        col,
        animation_index,
		z_layer,
    );
    draw_rect(opts);
}

make_draw_opts_for_entity :: (en: Entity, trs_adjust:Transform2=.{}) -> DrawRectOptions, hidden: bool
{
	local_trs: Transform2;
	render_trs: Transform2;
	
	// skip the big stuff in hands
	if get_held_entity().id == en.id && has_prop(en.props, .reduce_render_scale)
		return .{}, true;
	
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
	
	// apply the local render offset
	local_trs = en.render_offset;
	ifx en.x_dir == -1 then local_trs.translate.x *= -1;
	
	// apply the resource's sprite offsets
	local_trs.translate.x += en.x_dir * sprite.offset.x;
	local_trs.translate.y += sprite.offset.y;
	local_trs.pivot_offset += sprite.offset;
	
	// final rendering position
	render_trs.translate = en.pos;
	
	// apply parallax
	if en.parallax.x != 0 then render_trs.translate.x += app.camera.position.x * en.parallax.x;
	
	col := en.col;
	
	trs:= merge_transform(local_trs, render_trs);
	trs= merge_transform(trs, trs_adjust);
	
	flags := ifx flip_x then QuadFlags.x_flipped else 0;
	
    opts := make_draw_opts(sprite_id=sprite.id, sprite_pivot=.bottom_center, col=col, uv_rect=uv_rect, flags=flags, trs=trs, z_layer=en.z_layer);
	
	// player-specific
	if en.id == get_player().id && contains(sprite.name, "char_")
	{
		opts.colour_override_amount = 1;
		opts.colour_override = hex_to_rgba(0xffe2c3ff);
	}
	
	apply_quad_adjustments_from_entity(*opts, en);
	return opts, false;
}

draw_transformed_rect :: (localRect: Range2, transform: Transform2, zpos: float, col: Vector4, uvs: [4]Vector2 = DEFAULT_UV_CORNERS, col_override: Vector4 = .{}, white_override: float = 0.0)
{
	// trs_matrix := matrix_from_transform(transform);
	corners := Vector2.[
		transform_point(transform, Vector2.{localRect.min.x, localRect.min.y}),
		transform_point(transform, Vector2.{localRect.min.x, localRect.max.y}),
		transform_point(transform, Vector2.{localRect.max.x, localRect.max.y}),
		transform_point(transform, Vector2.{localRect.max.x, localRect.min.y}),
	];
	batch_append_quad(corners, zpos, col, uvs, col_override, white_override);
}


transform_point :: (m: $T/interface AnyMatrix4x3, v: Vector2) -> Vector2 {
    result: Vector2 = ---;
    result.x = m._11 * v.x + m._12 * v.y + m._14;
    result.y = m._21 * v.x + m._22 * v.y + m._24;
    return result;
} @NoProfile