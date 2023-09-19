#import "d3d11"()(INCLUDE_DEBUG_BINDINGS = false);
#import "d3d_compiler";
#import "dxgi";
#import "Windows";
#import "Windows_Utf8";
#import "Math";
#import "Hash";
#import "Hash_Table";
#import "File_Utilities";

// for bitmap stuff
#load "../../../external/Simp/bitmap.jai";
#load "../../../external/Simp/texture_format.jai";
#import "stb_image";
#import "stb_image_write";
#import "stb_image_resize";
// for fonts lol
#load "../../../external/Simp/font.jai";

RenderState :: struct
{
	current_render_w: s32;
	current_render_h: s32;
	
	driver_type := D3D_DRIVER_TYPE.NULL;
	feature_level := D3D_FEATURE_LEVEL._11_0;
	d3d_device: *ID3D11Device;
	d3d_context: *ID3D11DeviceContext;
	swap_chain: *IDXGISwapChain1;
	render_target_view: *ID3D11RenderTargetView;
	vertex_shader: *ID3D11VertexShader;
	pixel_shader: *ID3D11PixelShader;
	ilay_quad: *ID3D11InputLayout;
	vertex_buffer: *ID3D11Buffer;
	rasterizer: *ID3D11RasterizerState;
	
	player_rtv: *ID3D11RenderTargetView;
	player_tex: *ID3D11Texture2D;
	
	scratch_buffer: *ID3D11Buffer;
	blend_state: *ID3D11BlendState;
	sampler: *ID3D11SamplerState;
	
	const_buffer_resource: *ID3D11Buffer;
	cbuffer: GlobalConstBuffer;
	layer_cbuffer_resource: *ID3D11Buffer;
	layer_cbuffer: LayerConstBuffer;
	
	lut_sampler: *ID3D11SamplerState;
	lut1: ResourceID = .day_lut;
	lut2: ResourceID = .early_night_lut;
	
	stack_transform: Transform2;

	quads: LinkedList(Quad, frame_allocator);
	// quads: [..]Quad;
	
	// frame data
	active_texture: *Texture;
}
render_st: RenderState;

MAX_LIGHTS :: 64;
GlobalConstBuffer :: struct
{
	params: Vector4;
	window_size: Vector2;
	cam_zoom: float;
	lut_blend_alpha: float;
	
	// posx, posy, none, none
	lights: [MAX_LIGHTS]Vector4;
	light_count: int;
	debug_val: bool;
}
get_global_const_buff :: () -> *GlobalConstBuffer
{
	return *render_st.cbuffer;
}

LayerConstBuffer :: struct
{
	haze: Vector4; // todo
	colour_override: Vector4;
	colour_override_amount: float;
	lut_strength: float = 1.0;
	light_strength: float = 1.0;
}
push_layer_cbuff :: (cbuff: LayerConstBuffer) #expand
{
	temp := render_st.layer_cbuffer;
	render_st.layer_cbuffer = cbuff;
	`defer render_st.layer_cbuffer = temp;
}

QuadFlags :: enum
{
	SKIP_CAMERA_TRANSFORM :: 1<<0;
}

Quad :: struct
{
	next: *Quad;
	flags: QuadFlags;
	p0, p1, p2, p3: Vector4;
	uv0, uv1, uv2, uv3: Vector2;
	col: Vector4;
	texture: *Texture;
	z_layer: float;
	white_override: float;
	layer_cbuffer: LayerConstBuffer;
}

QuadVertex :: struct
{
	pos: Vector3;
	uv: Vector2;
	col: Vector4;
	white_override: float;
}

fill_texture :: (texture: *Texture, width: u32, height: u32, initial_data: *void)
{
	td: D3D11_TEXTURE2D_DESC;
	td.Width = width;
	td.Height = height;
	td.MipLevels = 1;
	td.ArraySize = 1;
	td.Format = .R8G8B8A8_UNORM;
	td.SampleDesc.Count = 1;
	td.Usage = .DYNAMIC;
	td.BindFlags = .SHADER_RESOURCE;
	td.CPUAccessFlags = .WRITE;
	
	sub_res_data: D3D11_SUBRESOURCE_DATA;
	sub_res_data.pSysMem = initial_data;
	sub_res_data.SysMemPitch = 4 * width;

	ID3D11Device_CreateTexture2D(render_st.d3d_device, *td, *sub_res_data, *texture.texture);
	ID3D11Device_CreateShaderResourceView(render_st.d3d_device, texture.texture, null, *texture.view);
	texture.width = td.Width;
	texture.height = td.Height;
	texture.flags |= .texture;
}

render_init :: ()
{
	hwnd: HWND = app.window;
	hr: HRESULT = S_OK;

	flags: D3D11_CREATE_DEVICE_FLAG; 
	#if DEBUG flags |= .DEBUG;
	
	// create the device
	// prioritising the best driver/feature level
	{
		driver_types := D3D_DRIVER_TYPE.[.HARDWARE, .WARP, .REFERENCE];
		feature_levels := D3D_FEATURE_LEVEL.[._11_1, ._11_0, ._10_1, ._10_0];
		for 0..driver_types.count-1
		{
			render_st.driver_type = driver_types[it]; 
			hr = D3D11CreateDevice(null, render_st.driver_type, null, flags, feature_levels.data, feature_levels.count, D3D11_SDK_VERSION, *render_st.d3d_device, *render_st.feature_level, *render_st.d3d_context);
		
			if hr == E_INVALIDARG
			{
				// DirectX 11.0 platforms will not recognize D3D_FEATURE_LEVEL_11_1 so we need to retry without it.
				hr = D3D11CreateDevice(null, render_st.driver_type, null, flags, feature_levels.data + 1, feature_levels.count - 1, D3D11_SDK_VERSION, *render_st.d3d_device, *render_st.feature_level, *render_st.d3d_context);
			}
		
			if SUCCEEDED(hr) break;
		}
		assert(render_st.d3d_device != null && SUCCEEDED(hr), "D3D11CreateDevice failed.");
		log("Created D3D11 device % with feature level %", render_st.driver_type, render_st.feature_level);
	}

	// CREATE SWAPCHAIN
	{
		// Obtain DXGI factory from device
		dxgi_device: *IDXGIDevice;
		hr = IUnknown_QueryInterface(render_st.d3d_device, *uid(IDXGIDevice_UUID), xx *dxgi_device);
		assert(SUCCEEDED(hr));
		defer IUnknown_Release(dxgi_device);
		
		adapter: *IDXGIAdapter;
		hr = IDXGIDevice_GetAdapter(dxgi_device, *adapter);
		assert(SUCCEEDED(hr));
		defer IUnknown_Release(adapter);
		
		dxgi_factory: *IDXGIFactory2;
		hr = IDXGIObject_GetParent(adapter, *uid(IDXGIFactory1_UUID), xx *dxgi_factory); 
		assert(SUCCEEDED(hr));
		defer IUnknown_Release(dxgi_factory);

		width, height := get_window_rect();

		sd: DXGI_SWAP_CHAIN_DESC1;
		sd.Format = .R8G8B8A8_UNORM; 
		// probs don't need these
		//sd.BufferDesc.RefreshRate.Numerator = xx st.refresh_rate;
		//sd.BufferDesc.RefreshRate.Denominator = 1;
		sd.BufferCount = 2;
		sd.BufferUsage = .RENDER_TARGET_OUTPUT;
		sd.SampleDesc.Count = 1; 
		sd.SampleDesc.Quality = 0;
		// we don't want any automatic scaling of window content
		// this is supported only on FLIP presentation model
		// sd.Scaling = .DXGI_SCALING_NONE;
		sd.Scaling = .STRETCH; // for compatability with 7
		// use more efficient FLIP presentation model
		// Windows 10 allows to use DXGI_SWAP_EFFECT_FLIP_DISCARD
		// for Windows 8 compatibility use DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL
		// for Windows 7 compatibility use DXGI_SWAP_EFFECT_DISCARD
		sd.SwapEffect = .DXGI_SWAP_EFFECT_DISCARD;

		hr = IDXGIFactory2_CreateSwapChainForHwnd(dxgi_factory, render_st.d3d_device, hwnd, *sd, null, null, *render_st.swap_chain); 
		assert(SUCCEEDED(hr), tprint("CreateSwapChain failed: %", hr));

		// disable alt enter
		IDXGIFactory_MakeWindowAssociation(dxgi_factory, hwnd, cast (u32) DXGI_MWA.NO_ALT_ENTER); 
	}

	// CONSTANTS BUFFER
	{
		bd := D3D11_BUFFER_DESC.
		{
			ByteWidth = xx align_forward(size_of(GlobalConstBuffer), 16),
			Usage = .DYNAMIC,
			BindFlags = .CONSTANT_BUFFER,
			CPUAccessFlags = .WRITE,
		};
		ID3D11Device_CreateBuffer(render_st.d3d_device, *bd, null, *render_st.const_buffer_resource);
	}
	{
		bd := D3D11_BUFFER_DESC.
		{
			ByteWidth = xx align_forward(size_of(LayerConstBuffer), 16),
			Usage = .DYNAMIC,
			BindFlags = .CONSTANT_BUFFER,
			CPUAccessFlags = .WRITE,
		};
		ID3D11Device_CreateBuffer(render_st.d3d_device, *bd, null, *render_st.layer_cbuffer_resource);
	}

	// SCRATCH BUFFER
	{
		bd := D3D11_BUFFER_DESC.
		{
			ByteWidth = megabytes(8),
			Usage = .DYNAMIC,
			BindFlags = .VERTEX_BUFFER,
			CPUAccessFlags = .WRITE,
		};
		ID3D11Device_CreateBuffer(render_st.d3d_device, *bd, null, *render_st.scratch_buffer);
	}

	// BLEND STATE
	{
		bd: D3D11_BLEND_DESC;
		bd.RenderTarget[0].BlendEnable = 1;
		bd.RenderTarget[0].SrcBlend = .SRC_ALPHA;
		bd.RenderTarget[0].DestBlend = .INV_SRC_ALPHA;
		bd.RenderTarget[0].BlendOp = .ADD;
		bd.RenderTarget[0].SrcBlendAlpha = .ONE;
		bd.RenderTarget[0].DestBlendAlpha = .ZERO;
		bd.RenderTarget[0].BlendOpAlpha = .ADD;
		bd.RenderTarget[0].RenderTargetWriteMask = xx D3D11_COLOR_WRITE_ENABLE.ALL;
		ID3D11Device_CreateBlendState(render_st.d3d_device, *bd, *render_st.blend_state);
	}
	
	// RASTERIZER
	{
		desc: D3D11_RASTERIZER_DESC;
		desc.FillMode = .SOLID;
		desc.CullMode = .BACK;
		ID3D11Device_CreateRasterizerState(render_st.d3d_device, *desc, *render_st.rasterizer);
	}

	// TEXTURE SHIT
	{
		// blank texture
		white_tex_data: u32 = 0xffffffff;
		white_tex := get_resource(.blank_tex);
		fill_texture(white_tex, 1, 1, *white_tex_data);
		white_tex.flags |= .sprite;
		white_tex.rect.max = xy(1, 1);

		// nil texture
		nil_tex_data: []u8 = .[
			255, 0, 255, 255,
			20, 20, 20, 255,
			20, 20, 20, 255,
			255, 0, 255, 255,
		];
		fill_texture(nil_resource, 2, 2, nil_tex_data.data);
		nil_resource.flags |= .sprite;
		nil_resource.rect.max = xy(2, 2);

		// Filter:         D3D11_FILTER;
		// AddressU:       D3D11_TEXTURE_ADDRESS_MODE;
		// AddressV:       D3D11_TEXTURE_ADDRESS_MODE;
		// AddressW:       D3D11_TEXTURE_ADDRESS_MODE;
		// MipLODBias:     float;
		// MaxAnisotropy:  u32;
		// ComparisonFunc: D3D11_COMPARISON_FUNC;
		// BorderColor:    [4] float;
		// MinLOD:         float;
		// MaxLOD:         float;

		// SAMPLER
		{
			sd: D3D11_SAMPLER_DESC;
			sd.Filter = .MIN_MAG_MIP_POINT;
			sd.AddressU = .WRAP;
			sd.AddressV = .WRAP;
			sd.AddressW = .WRAP;
			sd.ComparisonFunc = .NEVER;
			ID3D11Device_CreateSamplerState(render_st.d3d_device, *sd, *render_st.sampler);
		}
		
		// lut_sampler
		{
			sd: D3D11_SAMPLER_DESC;
			sd.Filter = .MIN_MAG_MIP_LINEAR;
			sd.AddressU = .CLAMP;
			sd.AddressV = .CLAMP;
			sd.AddressW = .CLAMP;
			sd.ComparisonFunc = .NEVER;
			ID3D11Device_CreateSamplerState(render_st.d3d_device, *sd, *render_st.lut_sampler);
		}
	}

	// SHADERS
	{
		// vertex
		vs := read_entire_file(tprint("%vs", SHADER_PATH));
		hr = ID3D11Device_CreateVertexShader(render_st.d3d_device, vs.data, cast(u64) vs.count, null, *render_st.vertex_shader);
		assert(SUCCEEDED(hr), tprint("CreateVertexShader failed: %", hr));
		
		// pixel
		ps := read_entire_file(tprint("%ps", SHADER_PATH));;
		hr = ID3D11Device_CreatePixelShader(render_st.d3d_device, ps.data, cast(u64) ps.count, null, *render_st.pixel_shader);
		assert(SUCCEEDED(hr), tprint("CreatePixelShader failed: %", hr));

		// INPUT LAYOUT
		layout := D3D11_INPUT_ELEMENT_DESC.
		[
		.{ "POS", 0, .R32G32B32_FLOAT, 0, #run offset_of(QuadVertex, "pos"), .VERTEX_DATA, 0 },
		.{ "UV", 0, .R32G32_FLOAT, 0, #run offset_of(QuadVertex, "uv"), .VERTEX_DATA, 0 },
		.{ "COL", 0, .R32G32B32A32_FLOAT, 0, #run offset_of(QuadVertex, "col"), .VERTEX_DATA, 0 },
		.{ "WHITE_OVERRIDE", 0, .R32_FLOAT, 0, #run offset_of(QuadVertex, "white_override"), .VERTEX_DATA, 0 },
		];

		hr = ID3D11Device_CreateInputLayout(render_st.d3d_device, layout.data, cast(u32) layout.count, vs.data, cast(u64) vs.count, *render_st.ilay_quad);
		assert(SUCCEEDED(hr), tprint("CreateInputLayout failed: %", hr));
	}
}

custom_render_player :: ()
{
	
	// setup texture / RTV
	if render_st.player_rtv == null
	{
		td: D3D11_TEXTURE2D_DESC;
		td.Width = 128;
		td.Height = 128;
		td.MipLevels = 1;
		td.ArraySize = 1;
		td.Format = .R8G8B8A8_UNORM;
		td.SampleDesc.Count = 1;
		td.Usage = .DEFAULT;
		td.BindFlags = .SHADER_RESOURCE | .RENDER_TARGET;
		ID3D11Device_CreateTexture2D(render_st.d3d_device, *td, null, *render_st.player_tex);
		
		rtv_desc: D3D11_RENDER_TARGET_VIEW_DESC;
		rtv_desc.Format = td.Format;
		rtv_desc.ViewDimension = .TEXTURE2D;
		ID3D11Device_CreateRenderTargetView(render_st.d3d_device, render_st.player_tex, *rtv_desc, *render_st.player_rtv);
	}
	
	// TODO - continue dis
	// basically render the player into this texture rtv
	// then use that texture handle to push into the main pipeline
	
	
}

actually_render :: () #expand
{
	hwnd: HWND = app.window;
	window_w, window_h := get_window_rect();
	hr: HRESULT;
	
	// NOTE - I've got some kinda stateful bug going on with the textures lol. Clearing it seems to fix hehe - randy
	// will probs need to crack down on this for @speed ?
	ID3D11DeviceContext_ClearState(render_st.d3d_context);
	
	// resize buffer & create RTV
	if render_st.render_target_view == null
		|| window_w != render_st.current_render_w || window_h != render_st.current_render_h
	{
		if render_st.render_target_view
		{
			// yeet exisitng rtv
			IUnknown_Release(render_st.render_target_view);
			render_st.render_target_view = null;
		}
		
		// new window for a non-zero size
		if window_w != 0 && window_h != 0
		{
			hr = IDXGISwapChain_ResizeBuffers(render_st.swap_chain, 0, xx window_w, xx window_h, .UNKNOWN, 0);
			assert(SUCCEEDED(hr), tprint("ResizeBuffers failed %", hr));
			
			// create RenderTarget view for new backbuffer texture
			back_buffer: *ID3D11Texture2D;
			IDXGISwapChain_GetBuffer(render_st.swap_chain, 0, *uid(ID3D11Texture2D_UUID), xx *back_buffer);
			assert(SUCCEEDED(hr), tprint("GetBuffer failed %", hr));
			defer IUnknown_Release(back_buffer);
			
			hr = ID3D11Device_CreateRenderTargetView(render_st.d3d_device, back_buffer, null, *render_st.render_target_view); 
			assert(SUCCEEDED(hr), tprint("CreateRenderTargetView failed: %", hr));
			
			render_st.current_render_w = window_w;
			render_st.current_render_h = window_h;
		}
	}
	
	if render_st.render_target_view
	{
		ID3D11DeviceContext_OMSetRenderTargets(render_st.d3d_context, 1, *render_st.render_target_view, null); 

		// VIEWPORT
		vp: D3D11_VIEWPORT; 
		vp.Width = xx window_w; 
		vp.Height = xx window_h; 
		vp.MinDepth = 0.0;
		vp.MaxDepth = 1.0;
		vp.TopLeftX = 0;
		vp.TopLeftY = 0;
		ID3D11DeviceContext_RSSetViewports(render_st.d3d_context, 1, *vp);

		// Clear the back buffer
		ID3D11DeviceContext_ClearRenderTargetView(render_st.d3d_context, render_st.render_target_view, *CLEAR_COL.component);

		render_st.active_texture = get_texture(.blank_tex);
	}
	else
	{
		return;
	}
	
	// apply transform to the lights
	cbuff := get_global_const_buff();
	for 0..cbuff.light_count-1
	{
		light := *cbuff.lights[it];
		point := xyzw(light.x, light.y, 0, 1);
		point = app.view_matrix * point;
		// shift into screen pixel space
		point.x = (point.x / cast(float)app.window_w + 0.5) * cast(float)app.window_w;
		point.y = (point.y / cast(float)app.window_h - 0.5) * -cast(float)app.window_h;
		
		light.xy = point.xy;
		light.z *= app.camera.zoom;
		
		//log("% -> %", light, cbuff.lights[it].xy);
	}
	
	// fill in some other cbuffer values
	cbuff.window_size = .{xx window_w, xx window_h};
	cbuff.debug_val = key_down(#char "H");
	cbuff.cam_zoom = app.camera.zoom;
	cbuff.params.x = get_night_alpha();
	
	// CONSTANT BUFFER uplaod
	{
		res: D3D11_MAPPED_SUBRESOURCE;
		ID3D11DeviceContext_Map(render_st.d3d_context, render_st.const_buffer_resource, 0, .WRITE_DISCARD, 0, *res);
		memcpy(res.pData, *render_st.cbuffer, size_of(GlobalConstBuffer));
		ID3D11DeviceContext_Unmap(render_st.d3d_context, render_st.const_buffer_resource, 0);
	}

	// sort the quads by z_layer
	sorted_quads: [..] *Quad;
	sorted_quads.allocator = temp;
	next_quad := render_st.quads.first;
	while next_quad
	{
		array_add(*sorted_quads, next_quad);
		next_quad = next_quad.next;
	}
	bubble_sort(sorted_quads, (a, b) => compare_floats(b.z_layer, a.z_layer));
	
	// fill & flush verticies from sorted quads
	verticies: [..]QuadVertex;
	verticies.allocator = temp;
	for sorted_quads
	{
		
		// flush the existing vertices if we've got a new tex or cbuf
		new_texture := it.texture != render_st.active_texture;
		new_cbuff := !compare_memory(it.layer_cbuffer, render_st.layer_cbuffer);
		if new_texture || new_cbuff
		{
			flush_verticies(*verticies);
			array_reset_keeping_memory(*verticies);
		}
		if new_texture then render_st.active_texture = it.texture;
		if new_cbuff then render_st.layer_cbuffer = it.layer_cbuffer;
		
		// apply view & proj matrix
		projection_matrix := get_cardinal_projection();
		view := Matrix4_Identity;
		if !(it.flags & .SKIP_CAMERA_TRANSFORM)
		{
			view = app.view_matrix;
		}
		it.p0 = projection_matrix * view * it.p0;
		// it.p0.z = 0;
		it.p1 = projection_matrix * view * it.p1;
		// it.p1.z = 0;
		it.p2 = projection_matrix * view * it.p2;
		// it.p2.z = 0;
		it.p3 = projection_matrix * view * it.p3;
		// it.p3.z = 0;

		// dump verticies
		vert := array_add(*verticies);
		vert.pos = it.p0.xyz;
		vert.uv = it.uv0;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p2.xyz;
		vert.uv = it.uv2;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p1.xyz;
		vert.uv = it.uv1;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p0.xyz;
		vert.uv = it.uv0;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p3.xyz;
		vert.uv = it.uv3;
		vert.col = it.col;
		vert.white_override = it.white_override;

		vert = array_add(*verticies);
		vert.pos = it.p2.xyz;
		vert.uv = it.uv2;
		vert.col = it.col;
		vert.white_override = it.white_override;
	}
	flush_verticies(*verticies);

	hr = IDXGISwapChain_Present(render_st.swap_chain, xx ifx VSYNC then 1 else 0, 0);
	assert(SUCCEEDED(hr), tprint("Present failed: %", hr));
}

flush_verticies :: (quad_verticies: *[..]QuadVertex)
{
	if quad_verticies.count == 0 then return;

	using render_st;
	hwnd: HWND = app.window;
	window_w, window_h := get_window_rect();

	// log("flushed with %", active_texture);

	// QUAD RENDER
	
	// copy vert data to scratch buffer
	sub_res: D3D11_MAPPED_SUBRESOURCE;
	ID3D11DeviceContext_Map(d3d_context, scratch_buffer, 0, .WRITE_DISCARD, 0, *sub_res);
	memcpy(sub_res.pData, quad_verticies.data, size_of(QuadVertex) * quad_verticies.count);
	ID3D11DeviceContext_Unmap(d3d_context, scratch_buffer, 0);

	// layer cbuffer upload
	{
		res: D3D11_MAPPED_SUBRESOURCE;
		ID3D11DeviceContext_Map(d3d_context, layer_cbuffer_resource, 0, .WRITE_DISCARD, 0, *res);
		memcpy(res.pData, *render_st.layer_cbuffer, size_of(LayerConstBuffer));
		ID3D11DeviceContext_Unmap(d3d_context, layer_cbuffer_resource, 0);
	}

	// rasterizer stage
	viewport: D3D11_VIEWPORT;
	viewport.Width = xx window_w;
	viewport.Height = xx window_h;
	viewport.MaxDepth = 1.0;
	ID3D11DeviceContext_RSSetViewports(d3d_context, 1, *viewport);
	
	ID3D11DeviceContext_RSSetState(d3d_context, rasterizer);

	// INPUT ASSEMBLER
	ID3D11DeviceContext_IASetInputLayout(d3d_context, ilay_quad);
	ID3D11DeviceContext_IASetPrimitiveTopology(d3d_context, .TRIANGLELIST);
	stride: u32 = size_of(QuadVertex);
	offset: u32 = 0;
	ID3D11DeviceContext_IASetVertexBuffers(d3d_context, 0, 1, *scratch_buffer, *stride, *offset);

	// scissorrr
	scissor_rect: D3D11_RECT;
	scissor_rect.right = window_w;
	scissor_rect.bottom = window_h;
	// todo - actually do this?

	// VSHADER
	ID3D11DeviceContext_VSSetShader(d3d_context, vertex_shader, null, 0);
	ID3D11DeviceContext_VSSetConstantBuffers(d3d_context, 0, 1, *const_buffer_resource);
	ID3D11DeviceContext_VSSetConstantBuffers(d3d_context, 1, 1, *layer_cbuffer_resource);

	// PSHADER
	ID3D11DeviceContext_PSSetSamplers(d3d_context, 0, 1, *sampler);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 0, 1, *active_texture.view);
	ID3D11DeviceContext_PSSetShader(d3d_context, pixel_shader, null, 0); 
	ID3D11DeviceContext_PSSetConstantBuffers(d3d_context, 0, 1, *const_buffer_resource);
	ID3D11DeviceContext_PSSetConstantBuffers(d3d_context, 1, 1, *layer_cbuffer_resource);
	// lut lut lut lut lut
	ID3D11DeviceContext_PSSetSamplers(d3d_context, 1, 1, *lut_sampler);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 1, 1, *get_texture(render_st.lut1).view);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 2, 1, *get_texture(render_st.lut2).view);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 3, 1, *get_texture(.fire_lut).view);

	// OUTPUT MERGER
	ID3D11DeviceContext_OMSetBlendState(d3d_context, blend_state, null, 0xffffffff);

	// DRAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAW
	ID3D11DeviceContext_Draw(d3d_context, xx quad_verticies.count, 0);
}

draw_rect :: (rect:= Range2.{},
              sprite_pivot:= Pivot.bottom_center,
              uv_rect: Range2 = DEFAULT_UV,
              sprite_id:= SpriteID.blank_tex,
              texture:*ArcResource= null,
              col:= WHITE,
              z_layer:= 0.0,
              flip_x:= false,
              inverse_y:= true,
              flags:QuadFlags = 0,
              trs:= Transform2.{}) -> *Quad
{
	
	// do we use the sprite or texture?
	sprite : *Sprite = null;
	_texture : *ArcResource = texture;
	if _texture == null
	{
		sprite = get_sprite(sprite_id);
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
	trs_matrix := matrix_from_transform(final_trs);
	p0 = trs_matrix * p0;
	p1 = trs_matrix * p1;
	p2 = trs_matrix * p2;
	p3 = trs_matrix * p3;
	p0.z = -z_layer;
	p1.z = -z_layer;
	p2.z = -z_layer;
	p3.z = -z_layer;
	
	// for fitting it onto the texel
	// TODO
	//texture_size := xy(xx tex.width, xx tex.height);
	half_pixel := xy(0, 0);//1.0/texture_size/2.0;

	// this is all so scuffed lol
	
	_uv_rect := uv_rect;
	if flip_x
	{
		Swap(*_uv_rect.min.x, *_uv_rect.max.x);
		half_pixel.x *= -1;
	}

	uv0 := _uv_rect.min;
	uv1 := xy(_uv_rect.max.x - half_pixel.x, _uv_rect.min.y);
	uv2 := _uv_rect.max - half_pixel;
	uv3 := xy(_uv_rect.min.x, _uv_rect.max.y - half_pixel.y);

	if inverse_y
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
	return quad;
}

push_text :: (text: string, pixel_height: int, font_name: string = "", col: Vector4 = WHITE,
														size_box: Vector2 = .{}, edge_pad: float = 0, pivot_x: PivotX = .center, pivot_y: PivotY = .center,
														z_layer: float = 0.0, flags: QuadFlags = 0,
														trs: Transform2 = .{})
{
	_font_name := font_name;
	if _font_name == "" then _font_name = FONT_MAIN;
	
	// @allocator jank, font subsystem is using dynamic arrays...
	push_allocator(context.default_allocator);
	// @stability - getting a lot of different pixel heights will cause baaad things to happen. New texture is created for each.
	assert(pixel_height > 0, tprint("Invalid pixel height %", pixel_height));
	
	// using a fixed height because we're just rendering pixel fonts.
	FIXED_HEIGHT :: 16;
	font := get_font_at_size("res/font/", _font_name, FIXED_HEIGHT); // TODO - change this to the resource startup gen
	font_scaling := cast(float)pixel_height / cast(float)FIXED_HEIGHT;
	
	width := prepare_text(font, text);
	generate_quads_for_prepared_text(font, 0, 0, 0);

	last_page: *Font_Page;
	quads := font.current_quads;
	for quad, i: quads
	{
		page := quad.glyph.page;
		if !last_page then last_page = page;

		if page.dirty
		{
			page.dirty = false;
			fill_texture(*page.texture, xx page.bitmap_data.width, xx page.bitmap_data.height, page.bitmap_data.data.data);
		}

		uv_rect: Range2;
		uv_rect.min.x = quad.u1;
		uv_rect.min.y = quad.v1;
		uv_rect.max.x = quad.u0;
		uv_rect.max.y = quad.v0;

		rect: Range2;
		rect.min = quad.p0;
		rect.max = quad.p2;

		new_trs := trs;
		new_trs.scale *= xy(font_scaling, font_scaling);
		if pivot_x ==
		{
			case .left;
			new_trs.translate.x += edge_pad;
			
			case .center;
			new_trs.translate.x += size_box.x * 0.5;
			new_trs.translate.x += width * -0.5;
			new_trs.pivot_offset.x = width * -0.5;
			
			case .right;
			new_trs.translate.x += size_box.x;
			new_trs.translate.x += xx -width - edge_pad;
			new_trs.pivot_offset.x = xx -width;
		}
		if pivot_y ==
		{
			case .center;
			new_trs.translate.y += size_box.y * 0.5;
			new_trs.translate.y -= font.y_offset_for_centering;
			new_trs.pivot_offset.y -= xx font.y_offset_for_centering;
			
			case .top;
			new_trs.translate.y += size_box.y;
			new_trs.translate.y -= font.max_ascender; // TODO - this isn't right
			new_trs.pivot_offset.y -= xx font.max_ascender;
		}

		//push_quad(rect, col=BLACK, trs=new_trs);
		draw_rect(rect, col=col, uv_rect=uv_rect, texture=*page.texture, inverse_y=false, z_layer=z_layer, flags=flags, trs=new_trs);
	}
}

CompileShader :: (source: string, entry_point: string, shader_model: string) -> string, HRESULT {
	flags := D3DCOMPILE.ENABLE_STRICTNESS; 

	#if DEBUG {
		// Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders. 
		// Setting this flag improves the shader debugging experience, but still allows  
		// the shaders to be optimized and to run exactly the way they will run in  
		// the release configuration of this program. 
		flags |= .DEBUG; 
		
		// Disable optimizations to further improve shader debugging 
		flags |= .SKIP_OPTIMIZATION; 
	}
	
	defines: [] string;
	push_allocator(frame_allocator);
	bytecode, errors, hr := D3DCompile(source, "source", defines, null, entry_point, shader_model, xx flags, 0);
	//defer free(errors);

	if FAILED(hr) { 
		//free(bytecode);
		if errors print ("Error msg: %\n", errors);
		return "", hr;
	} 
	
	return bytecode, hr;
}

// why would I need to cleanup, surely windows does it for me?
/*
cleanup_device :: ()
{
	using render_st;
	if render_st.d3d_context ID3D11DeviceContext_ClearState(render_st.d3d_context);
	
	if vertex_buffer IUnknown_Release(vertex_buffer);
	if ilay_quad IUnknown_Release(ilay_quad);
	if vertex_shader IUnknown_Release(vertex_shader);
	if pixel_shader IUnknown_Release(pixel_shader);
	if render_target_view IUnknown_Release(render_target_view);
	//if swap_chain1 swap_chain1.Release(swap_chain1);
	if swap_chain IUnknown_Release(swap_chain);
	//if render_st.d3d_context1 render_st.d3d_context1.Release(render_st.d3d_context1);
	if render_st.d3d_context IUnknown_Release(render_st.d3d_context);
	//if d3d_device1 d3d_device1.Release(d3d_device1);
	if d3d_device IUnknown_Release(d3d_device);
}
*/

//
// :SPRITES
//

// random sprite from folder..
// load all sprites in folder, cache into with their names n shit
//
// I'm thinking we remove the idea of having slices into textures and just enforce everything being its own png
// at runtime we can grab all .pngs and pack them into a single texture
// For offsets we can just use constants or pack in some metadata via aesprite

/*
nil_sprite: *Sprite;

is_valid :: (sprite: *Sprite) -> bool
{
	return sprite != nil_sprite;
}

find_sprite :: (name: string) -> *Sprite
{
	for * render_st.sprites
	{
		if it.name == name then return it;
	}
	return nil_sprite;
}

create_sprite_from_name :: (name: string) -> *Sprite
{
	sprite := find_sprite(name);
	assert(!is_valid(sprite));
	render_st.sprite_id_gen += 1;
	sprite = *render_st.sprites[render_st.sprite_id_gen];
	
	sprite.name = copy_string(name, permanent_allocator);
	sprite.id = render_st.sprite_id_gen;
	
	texture := get_texture_from_name(name);
	assert(texture != global_nil_texture, tprint("Texture % not found", name));
	sprite.texture_key = sprite.name;
	
	sprite.rect = Range2.{max=.{xx texture.width, xx texture.height}};
	// offset
	// grip offset
	// frame count, etc
	// todo - grab these metadata from somewhere
	
	return sprite;
}
*/