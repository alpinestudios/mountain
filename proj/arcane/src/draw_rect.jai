// - no longer return quad from draw_rect, and make things work assuming that
// - eliminate sorting temporarily
// - remove quad buffer, replace with a vertex buffer, update draw_rect to write geometry directly
// - draw entities in z order using a sorted array of *Entity
// - clean up 'draw options' and the topology of draw-related procs (ie: make_draw_opts_for_entity)
// - try to reduce the amount of work happening in draw_rect
//		- remove trs for non-worldspace things
//		- try to replace the memcmp



DrawRectOptions :: struct {
	rect:= Range2.{};
	sprite_pivot:= Pivot.bottom_center;
	uv_rect: Range2 = DEFAULT_UV;
	sprite_id:= SpriteID.blank_tex;
	texture:*ArcResource= null;
	col:= WHITE;
	z_layer:= 0.0;
	slice_pct:= 1.0;
	flags:QuadFlags=0;
	trs:= Transform2.{};
	white_override: float;
	colour_override: Vector4;
	colour_override_amount: float;
}

make_draw_opts :: (
	rect:= Range2.{},
	sprite_pivot:= Pivot.bottom_center,
	uv_rect: Range2 = DEFAULT_UV,
	sprite_id:= SpriteID.blank_tex,
	texture:*ArcResource= null,
	col:= WHITE,
	z_layer:= 0.0,
	slice_pct:= 1.0,
	flags:QuadFlags=0,
	trs:= Transform2.{},
	colour_override: Vector4 = .{},
	colour_override_amount: float = 0
) -> DrawRectOptions 
{
	return DrawRectOptions.{
		rect = rect,
		sprite_pivot = sprite_pivot,
		uv_rect = uv_rect,
		sprite_id = sprite_id,
		texture = texture,
		col = col,
		z_layer = z_layer,
		slice_pct = slice_pct,
		flags = flags,
		trs = trs,
		colour_override = colour_override,
		colour_override_amount = colour_override_amount,
	};
}

draw_rect :: (opts: DrawRectOptions)
{
	draw_rect(
		rect = opts.rect,
		sprite_pivot = opts.sprite_pivot,
		uv_rect = opts.uv_rect,
		sprite_id = opts.sprite_id,
		texture = opts.texture,
		col = opts.col,
		z_layer = opts.z_layer,
		slice_pct = opts.slice_pct,
		flags = opts.flags,
		trs = opts.trs
	);
}

// this is the big daddy
draw_rect :: (
	rect:= Range2.{},
	sprite_pivot:= Pivot.bottom_center,
	uv_rect: Range2 = DEFAULT_UV,
	sprite_id:= SpriteID.blank_tex,
	texture:*ArcResource= null,
	col:= WHITE,
	z_layer:= 0.0,
	slice_pct:= 1.0,
	flags:QuadFlags=0,
	trs:= Transform2.{},
	colour_override: Vector4 = .{},
	colour_override_amount: float = 0
){
	assert(z_layer != 0.0, "Z_LAYER not provided");
	
	// do we use the sprite or texture?
	sprite : *Sprite = null;
	_texture : *ArcResource = texture;
	if _texture == null
	{
		sprite = get_resource(sprite_id);
		assert(!!(sprite.flags & .sprite), "% doesn't have a sprite, set the display_sprite_id instead?", sprite_id);
		_texture = texture_from_sprite(sprite);
	}
	
	// infer the rect from sprite
	_rect := rect;
	if _rect.min == .{} && _rect.max == .{}
	{
		if sprite_id == .blank_tex then log("No rect size, yet can't infer from sprite either?");
		
		_rect = range_normalise(sprite.rect);
		_rect = range_pivot(_rect, sprite_pivot);
	}
	
	r := range_correct(_rect);
	p0 := xyzw(r.min.x, r.min.y, 0, 1);
	p1 := xyzw(r.max.x, r.min.y, 0, 1);
	p2 := xyzw(r.max.x, r.max.y, 0, 1);
	p3 := xyzw(r.min.x, r.max.y, 0, 1);

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
	trs_matrix := matrix_from_transform(final_trs);
	p0 = trs_matrix * p0;
	p1 = trs_matrix * p1;
	p2 = trs_matrix * p2;
	p3 = trs_matrix * p3;
	p0.z = -z_layer;
	p1.z = -z_layer;
	p2.z = -z_layer;
	p3.z = -z_layer;
	
	_uv_rect := uv_rect;
	if flags & .slice_x_from_right
	{
		_uv_rect.max.x *= slice_pct;
	}
	else if flags & .slice_x_from_left
	{
		_uv_rect.min.x += (1-slice_pct) * range_size(_uv_rect).x;
	}
	
	if flags & .x_flipped
	{
		Swap(*_uv_rect.min.x, *_uv_rect.max.x);
	}

	uv0 := _uv_rect.min;
	uv1 := xy(_uv_rect.max.x, _uv_rect.min.y);
	uv2 := _uv_rect.max;
	uv3 := xy(_uv_rect.min.x, _uv_rect.max.y);

	if !(flags & .inverse_y)
	{
		uv0.y = 1.0 - uv0.y;
		uv1.y = 1.0 - uv1.y;
		uv2.y = 1.0 - uv2.y;
		uv3.y = 1.0 - uv3.y;
	}

	quad: *Quad = push_back(*render_st.quads);
	quad.p0 = p0;
	quad.p1 = p1;
	quad.p2 = p2;
	quad.p3 = p3;
	quad.uv0 = uv0;
	quad.uv1 = uv1;
	quad.uv2 = uv2;
	quad.uv3 = uv3;
	quad.col = col;
	quad.texture = _texture;
	quad.z_layer = z_layer;
	quad.flags = flags;
	quad.layer_cbuffer = render_st.layer_cbuffer;
    
    quad.layer_cbuffer.colour_override = colour_override;
	quad.layer_cbuffer.colour_override_amount = colour_override_amount;
}

// a sprite is auto-sized and could be animated
make_draw_opts_for_sprite :: (
	sprite_id: SpriteID
	, pos: Vector2
	, offset_trs:= Transform2.{}
	, flags:QuadFlags=0
	, slice_pct:=1.0
	, col:= WHITE
	, z_layer:= 0.0
	, animation_index: int = 0
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
	
	opts := make_draw_opts(sprite_id=sprite.id, uv_rect=uv_rect, col=col, z_layer=z_layer, slice_pct=slice_pct, flags=flags, trs=render_trs);
	return opts;
}

draw_sprite :: (
	  sprite_id: SpriteID
	, pos: Vector2
	, offset_trs:= Transform2.{}
	, flags:QuadFlags=0
	, slice_pct:=1.0
	, col:= WHITE
	, z_layer:= 0.0
	, animation_index: int = 0
){
    opts := make_draw_opts_for_sprite(
        sprite_id,
        pos,
        offset_trs,
        flags,
        slice_pct,
        col,
        z_layer,
        animation_index
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
	
	// player-specific
	cbuff := render_st.layer_cbuffer;
	if en.id == get_player().id && contains(sprite.name, "char_")
	{
		cbuff.colour_override_amount = 1;
		cbuff.colour_override = hex_to_rgba(0xffe2c3ff);
	}
	push_layer_cbuff(cbuff);
	
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
	
    opts := make_draw_opts(sprite_id=sprite.id, sprite_pivot=.bottom_center, z_layer=en.z_layer, col=col, uv_rect=uv_rect, flags=flags, trs=trs);
	apply_quad_adjustments_from_entity(*opts, en);
	return opts, false;
}