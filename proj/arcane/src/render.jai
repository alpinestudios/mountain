#import "d3d11"()(INCLUDE_DEBUG_BINDINGS = DEBUG);
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
	swap_chain_desc: DXGI_SWAP_CHAIN_DESC1;
	swap_chain: *IDXGISwapChain1;
	
	back_buffer: *ID3D11Texture2D;
	render_target_view: *ID3D11RenderTargetView;
	vertex_shader: *ID3D11VertexShader;
	vertex_shader_input_layout: *ID3D11InputLayout;
	pixel_shader: *ID3D11PixelShader;
	
	rasterizer: *ID3D11RasterizerState;
	
	player_rtv: *ID3D11RenderTargetView;
	player_tex: *ID3D11Texture2D;
	
	blend_state: *ID3D11BlendState;
	sampler: *ID3D11SamplerState;
	
	const_buffer_resource: *ID3D11Buffer;
	cbuffer: GlobalConstBuffer;
	
	lut_sampler: *ID3D11SamplerState;
	lut1: ResourceID = .day_lut;
	lut2: ResourceID = .early_night_lut;
	
	stack_transform: Transform2;

	batch: Batch;
	
}
render_st: RenderState;




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
	
	render_update_window();	

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
		ID3D11DeviceContext_OMSetBlendState(render_st.d3d_context, render_st.blend_state, null, 0xffffffff);
	}
	
	// RASTERIZER
	{
		desc: D3D11_RASTERIZER_DESC;
		desc.FillMode = .SOLID;
		desc.CullMode = .BACK;
		desc.FrontCounterClockwise = .FALSE;
		desc.DepthClipEnable = .FALSE;
		desc.CullMode = .NONE;
		ID3D11Device_CreateRasterizerState(render_st.d3d_device, *desc, *render_st.rasterizer);
		ID3D11DeviceContext_RSSetState(render_st.d3d_context, render_st.rasterizer);
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
			ByteWidth = xx align_forward(size_of(BatchUniforms), 16),
			Usage = .DYNAMIC,
			BindFlags = .CONSTANT_BUFFER,
			CPUAccessFlags = .WRITE,
		};
		ID3D11Device_CreateBuffer(render_st.d3d_device, *bd, null, *render_st.batch.uniforms_gpu);
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
			// randy: change to .WRAP to see texture edge bleed issues in some cases
			sd.AddressU = .CLAMP;
			sd.AddressV = .CLAMP;
			sd.AddressW = .CLAMP;
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
		assert_d3d_result(hr, "CreateVertexShader");
		
		// pixel
		ps := read_entire_file(tprint("%ps", SHADER_PATH));;
		hr = ID3D11Device_CreatePixelShader(render_st.d3d_device, ps.data, cast(u64) ps.count, null, *render_st.pixel_shader);
		assert_d3d_result(hr, "CreatePixelShader");

		// INPUT LAYOUT
		layout := D3D11_INPUT_ELEMENT_DESC.
		[
			.{ "POS", 0, .R32G32B32_FLOAT, 0, #run offset_of(QuadVertex, "pos"), .VERTEX_DATA, 0 },
			.{ "UV", 0, .R32G32_FLOAT, 0, #run offset_of(QuadVertex, "uv"), .VERTEX_DATA, 0 },
			.{ "COL", 0, .R32G32B32A32_FLOAT, 0, #run offset_of(QuadVertex, "col"), .VERTEX_DATA, 0 },
			.{ "COL_OVERRIDE", 0, .R32G32B32A32_FLOAT, 0, #run offset_of(QuadVertex, "col_override"), .VERTEX_DATA, 0 },
			.{ "WHITE_OVERRIDE", 0, .R32_FLOAT, 0, #run offset_of(QuadVertex, "white_override"), .VERTEX_DATA, 0 },
		];
		hr = ID3D11Device_CreateInputLayout(render_st.d3d_device, layout.data, cast(u32) layout.count, vs.data, cast(u64) vs.count, *render_st.vertex_shader_input_layout);
		assert_d3d_result(hr, "CreateInputLayout");
	}
	
	batch_init(*render_st.batch, render_st.vertex_shader_input_layout);
}

render_update_window :: ()
{
	hr: HRESULT;	
	window_w, window_h := get_window_size(app.window);
	
    create_swap_chain := render_st.swap_chain == null;
	if (create_swap_chain || window_w != render_st.current_render_w && window_h != render_st.current_render_h) 
	&& (window_w > 0 && window_h > 0)
	{
        // create or resize swap chain
		if create_swap_chain {
			// init swap chain description
			scd: DXGI_SWAP_CHAIN_DESC1;
			scd.Format = .R8G8B8A8_UNORM; 
			// probs don't need these
			//scd.BufferDesc.RefreshRate.Numerator = xx st.refresh_rate;
			//scd.BufferDesc.RefreshRate.Denominator = 1;
			scd.BufferCount = 2;
			scd.BufferUsage = .RENDER_TARGET_OUTPUT;
			scd.SampleDesc.Count = 1; 
			scd.SampleDesc.Quality = 0;
			// we don't want any automatic scaling of window content
			// this is supported only on FLIP presentation model
			// scd.Scaling = .DXGI_SCALING_NONE;
			scd.Scaling = .STRETCH; // for compatability with 7
			// use more efficient FLIP presentation model
			// Windows 10 allows to use DXGI_SWAP_EFFECT_FLIP_DISCARD
			// for Windows 8 compatibility use DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL
			// for Windows 7 compatibility use DXGI_SWAP_EFFECT_DISCARD
			scd.SwapEffect = .DXGI_SWAP_EFFECT_DISCARD;
			
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

			hr = IDXGIFactory2_CreateSwapChainForHwnd(dxgi_factory, render_st.d3d_device, app.window, *scd, null, null, *render_st.swap_chain); 	
			assert_d3d_result(hr, "CreateSwapChain");
			
			// store the swap chain description, as created by CreateSwapChainForHwnd
			hr = IDXGISwapChain1_GetDesc1(render_st.swap_chain, *render_st.swap_chain_desc);
			assert_d3d_result(hr, "SwapChain GetDesc");
			
			// disable alt enter
			IDXGIFactory_MakeWindowAssociation(dxgi_factory, app.window, cast (u32) DXGI_MWA.NO_ALT_ENTER); 
		} else {
			// release backbuffer, we're about to replace it. This must be done before SwapChain_ResizeBuffers
			safe_release(render_st.back_buffer);
            safe_release(render_st.render_target_view);
			
			hr = IDXGISwapChain_ResizeBuffers(
                  render_st.swap_chain
                , render_st.swap_chain_desc.BufferCount
                , xx window_w
                , xx window_h
                , render_st.swap_chain_desc.Format
                , render_st.swap_chain_desc.Flags
            );
			assert_d3d_result(hr, "SwapChain ResizeBuffers");
			
			// update swap chain description
			hr = IDXGISwapChain1_GetDesc1(render_st.swap_chain, *render_st.swap_chain_desc);
			assert_d3d_result(hr, "SwapChain GetDesc");
		}
		
		// set the render target
        // get the back buffer as a texture object, use it to create a render target, and set that as the render target
		hr = IDXGISwapChain_GetBuffer(render_st.swap_chain, 0, *uid(ID3D11Texture2D_UUID), xx *render_st.back_buffer);
		assert_d3d_result(hr, "GetBuffer");
		hr = ID3D11Device_CreateRenderTargetView(render_st.d3d_device, render_st.back_buffer, null, *render_st.render_target_view); 
		assert_d3d_result(hr, "CreateRenderTargetView");
		ID3D11DeviceContext_OMSetRenderTargets(render_st.d3d_context, 1, *render_st.render_target_view, null); 
		
		// update the viewport
		viewport: D3D11_VIEWPORT;
		viewport.Width = xx window_w;
		viewport.Height = xx window_h;
		viewport.MaxDepth = 1.0;
		ID3D11DeviceContext_RSSetViewports(render_st.d3d_context, 1, *viewport);	
        // ID3D11DeviceContext_RSSetScissorRects(bc.deviceContext, 1, *D3D11_RECT.{0,0, xx windowSize.x, xx windowSize.y});
		
		render_st.current_render_w = window_w;
		render_st.current_render_h = window_h;
	}
}

render_begin_frame :: ()
{
	render_update_window();
	
	// Clear the back buffer
	ID3D11DeviceContext_ClearRenderTargetView(render_st.d3d_context, render_st.render_target_view, *CLEAR_COL.component);
	
	// apply transform to the lights
	cbuff := get_global_const_buff();
	for 0..cbuff.light_count-1
	{
		light := *cbuff.lights[it];
		point := xyzw(light.x, light.y, 0, 1);
		point = app.world_to_camera * point;
		// shift into screen pixel space
		point.x = (point.x / cast(float)app.window_w + 0.5) * cast(float)app.window_w;
		point.y = (point.y / cast(float)app.window_h - 0.5) * -cast(float)app.window_h;
		
		light.xy = point.xy;
		light.z *= app.camera.zoom;
		
		//log("% -> %", light, cbuff.lights[it].xy);
	}
	
	// fill in some other cbuffer values
	window_w, window_h := get_window_size(app.window);
	cbuff.window_size = .{xx window_w, xx window_h};
	cbuff.debug_val = key_down(#char "H");
	cbuff.cam_zoom = app.camera.zoom;
	cbuff.params.x = get_night_darkness_alpha();
	
	// upload global shader constants
	{
		res: D3D11_MAPPED_SUBRESOURCE;
		ID3D11DeviceContext_Map(render_st.d3d_context, render_st.const_buffer_resource, 0, .WRITE_DISCARD, 0, *res);
		memcpy(res.pData, *render_st.cbuffer, size_of(GlobalConstBuffer));
		ID3D11DeviceContext_Unmap(render_st.d3d_context, render_st.const_buffer_resource, 0);
	}
}

render_end_frame :: ()
{
	batch_flush();
	hr := IDXGISwapChain_Present(render_st.swap_chain, xx ifx VSYNC then 1 else 0, 0);
	if !SUCCEEDED(hr) then log_error("Present failed: %", hr);
}

Batch :: struct {
	verts: []QuadVertex;
	verts_gpu: GPUVertexBuffer;
	vertexCount: u32;
	uniforms: BatchUniforms;
	uniforms_gpu: *ID3D11Buffer;
	texture: *Texture;
	MAX_VERTS_PER_BATCH :: 6 * 400; // 400 quads == 2400 verts
}

BatchUniforms :: struct
{
	localToClip: Matrix4;
	haze: Vector4;
	lut_strength: float = 1.0;
	light_strength: float = 1.0;
}

batch_init :: (batch: *Batch, vertInputLayout: *ID3D11InputLayout)
{
    // make vertex buffers
    batch.verts = NewArray(Batch.MAX_VERTS_PER_BATCH, QuadVertex, false);
    batch.verts_gpu = make_vertex_buffer(size_of(QuadVertex), batch.verts.count, vertInputLayout);
    
	ceil_to_multiple_of_16 :: inline (x: int) -> int { return (x + 0xf) & 0xfffffff0; }
	
    // uniforms cbuffer
	bufferDesc: D3D11_BUFFER_DESC;
	bufferDesc.ByteWidth      = xx ceil_to_multiple_of_16(size_of(BatchUniforms));
	bufferDesc.Usage          = D3D11_USAGE.DYNAMIC;
	bufferDesc.BindFlags      = D3D11_BIND_FLAG.CONSTANT_BUFFER;
	bufferDesc.CPUAccessFlags = D3D11_CPU_ACCESS_FLAG.WRITE;
	ID3D11Device_CreateBuffer(render_st.d3d_device, *bufferDesc, null, *batch.uniforms_gpu);
}

batch_set_texture :: (texture: *Texture)
{
	batch := *render_st.batch;	
	if batch.texture != texture {
		batch_flush();
		batch.texture = texture;
	}
}

batch_set_projection_for_scope :: (val: Matrix4) #expand
{
	batch := *render_st.batch;
	orig := batch.uniforms.localToClip;
	batch_set_projection(val);
	`defer batch_set_projection(orig);
}

batch_set_lut_strength_for_scope :: (val: float) #expand
{
	batch := *render_st.batch;
	orig := batch.uniforms.lut_strength;
	batch_set_lut_strength(val);
	`defer batch_set_lut_strength(orig);
}

batch_set_projection :: (val: Matrix4)
{
	batch := *render_st.batch;
	if batch.uniforms.localToClip != val{
		batch_flush();
		batch.uniforms.localToClip = val;
	}
}

batch_set_haze :: (val: Vector4)
{
	batch := *render_st.batch;
	if batch.uniforms.haze != val {
		batch_flush();
		batch.uniforms.haze = val;
	}
}

batch_set_lut_strength :: (val: float)
{
	batch := *render_st.batch;
	if batch.uniforms.lut_strength != val {
		batch_flush();
		batch.uniforms.lut_strength = val;
	}
}

batch_set_light_strength :: (val: float)
{
	batch := *render_st.batch;
	if batch.uniforms.lut_strength != val {
		batch_flush();
		batch.uniforms.light_strength = val;
	}
}


// NOTE :: all append procs taking corners expect clockwise order, starting from bottom left
DEFAULT_UV_CORNERS :: Vector2.[ .{0, 0}, .{0, 1}, .{1, 1}, .{1, 0} ];

batch_append_quad :: (corners: [4]Vector3, col: Vector4, uvs: [4]Vector2 = DEFAULT_UV_CORNERS, col_override: Vector4 = .{}, white_override: float = 0.0)
{
	batch := *render_st.batch;
	verts := batch_reserve_verts(batch, 6);
	verts[0] = .{corners[0], uvs[0], col, col_override, white_override };
    verts[1] = .{corners[1], uvs[1], col, col_override, white_override };
    verts[2] = .{corners[2], uvs[2], col, col_override, white_override };
    verts[3] = verts[2];
    verts[4] = .{corners[3], uvs[3], col, col_override, white_override };
    verts[5] = verts[0];
}

batch_append_quad :: (corners: [4]Vector2, zpos: float, col: Vector4, uvs: [4]Vector2 = DEFAULT_UV_CORNERS, col_override: Vector4 = .{}, white_override: float = 0.0)
{
	batch := *render_st.batch;
	verts := batch_reserve_verts(batch, 6);
	verts[0] = .{ Vector3.{corners[0].x, corners[0].y, zpos}, uvs[0], col, col_override, white_override };
    verts[1] = .{ Vector3.{corners[1].x, corners[1].y, zpos}, uvs[1], col, col_override, white_override };
    verts[2] = .{ Vector3.{corners[2].x, corners[2].y, zpos}, uvs[2], col, col_override, white_override };
    verts[3] = verts[2];
    verts[4] = .{ Vector3.{corners[3].x, corners[3].y, zpos}, uvs[3], col, col_override, white_override };
    verts[5] = verts[0];
}

batch_append_rect :: (using rect: Range2, zpos: float, col: Vector4, col_override: Vector4 = .{}, white_override: float = 0.0)
{
	batch := *render_st.batch;
	verts := batch_reserve_verts(batch, 6);
	verts[0] = .{ Vector3.{min.x, min.y, zpos}, .{}, col, col_override, white_override };
    verts[1] = .{ Vector3.{min.x, max.y, zpos}, .{}, col, col_override, white_override };
    verts[2] = .{ Vector3.{max.x, max.y, zpos}, .{}, col, col_override, white_override };
    verts[3] = verts[2];
    verts[4] = .{ Vector3.{max.x, min.y, zpos}, .{}, col, col_override, white_override };
    verts[5] = verts[0];
}

batch_reserve_verts :: (batch: *Batch, count: u32) -> []QuadVertex
{
    assert(count > 0);
    // if there's not enough space remaining in the vertex buffer, flush
    if batch.vertexCount + count > batch.verts.count
        batch_flush();
    // then bump the vertex count
	assert(batch.vertexCount + count <= batch.verts.count);
    res := array_view(batch.verts, batch.vertexCount, count);
    batch.vertexCount += count;
    return res;
}

batch_flush :: ()
{
	using render_st;
	if batch.vertexCount == 0 return;

	{ // upload uniforms
		mappedResource: D3D11_MAPPED_SUBRESOURCE;
		ID3D11DeviceContext_Map(d3d_context, batch.uniforms_gpu, 0, D3D11_MAP.WRITE_DISCARD, 0, *mappedResource);
		memcpy(mappedResource.pData, *batch.uniforms, size_of(type_of(batch.uniforms)));
		ID3D11DeviceContext_Unmap(d3d_context, batch.uniforms_gpu, 0);
	}
	
	// upload geo
	{
		mappedResource: D3D11_MAPPED_SUBRESOURCE;
		ID3D11DeviceContext_Map(d3d_context, batch.verts_gpu.buffer, 0, D3D11_MAP.WRITE_DISCARD, 0, *mappedResource);
		memcpy(mappedResource.pData, batch.verts.data, batch.vertexCount * size_of(QuadVertex));
		ID3D11DeviceContext_Unmap(d3d_context, batch.verts_gpu.buffer, 0);
	}
	
	// bind shaders
	ID3D11DeviceContext_VSSetShader(d3d_context, vertex_shader, null, 0);
	ID3D11DeviceContext_PSSetShader(d3d_context, pixel_shader, null, 0);

	// bind uniforms
	ID3D11DeviceContext_VSSetConstantBuffers(d3d_context, 0, 1, *const_buffer_resource);
	ID3D11DeviceContext_VSSetConstantBuffers(d3d_context, 1, 1, *batch.uniforms_gpu);
	ID3D11DeviceContext_PSSetConstantBuffers(d3d_context, 0, 1, *const_buffer_resource);
	ID3D11DeviceContext_PSSetConstantBuffers(d3d_context, 1, 1, *batch.uniforms_gpu);
	
	// bind texture
	if batch.texture {
		ID3D11DeviceContext_PSSetSamplers(d3d_context, 0, 1, *sampler);
		ID3D11DeviceContext_PSSetShaderResources(d3d_context, 0, 1, *batch.texture.view);
	} else {
		ID3D11DeviceContext_PSSetShaderResources(d3d_context, 0, 1, *get_texture(.blank_tex).view);
	}

	// luts
	ID3D11DeviceContext_PSSetSamplers(d3d_context, 1, 1, *lut_sampler);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 1, 1, *get_texture(lut1).view);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 2, 1, *get_texture(lut2).view);
	ID3D11DeviceContext_PSSetShaderResources(d3d_context, 3, 1, *get_texture(.fire_lut).view);
	
	// bind verts
	ID3D11DeviceContext_IASetInputLayout(d3d_context, batch.verts_gpu.layout);
	ID3D11DeviceContext_IASetPrimitiveTopology(d3d_context, .TRIANGLELIST);
	offsets: u32 = 0;
	ID3D11DeviceContext_IASetVertexBuffers(d3d_context, 0, 1, *batch.verts_gpu.buffer, *batch.verts_gpu.stride, *offsets);

	// draw
	ID3D11DeviceContext_Draw(d3d_context, xx batch.vertexCount, 0);
	
	batch.vertexCount = 0;
    batch.texture = null;
}


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

QuadFlags :: enum_flags
{
	x_flipped;
	inverse_y;
	slice_x_from_right;
	slice_x_from_left;
	slice_x :: slice_x_from_right;
}

QuadVertex :: struct
{
	pos: Vector3;
	uv: Vector2;
	col: Vector4;
	col_override: Vector4;
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
	assert(pixel_height > 0, "Invalid pixel height %", pixel_height);
	
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
		draw_rect(rect, trs=new_trs, texture=*page.texture, uv_rect=uv_rect, col=col, z_layer = z_layer, flags=flags | .inverse_y);
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


GPUVertexBuffer :: struct {
    desc: D3D11_BUFFER_DESC;
    topology: D3D11_PRIMITIVE_TOPOLOGY;
    layout: *ID3D11InputLayout;
    buffer: *ID3D11Buffer;
    stride: u32;
    capacity: int;
}

make_vertex_buffer :: (stride: int, capacity: int, layout: *ID3D11InputLayout) -> GPUVertexBuffer
{
    assert(stride > 0);
    assert(capacity > 0);
    res: GPUVertexBuffer;
	res.stride = xx stride;
	res.capacity = xx capacity;
	res.layout = layout;
    res.desc.Usage = .DYNAMIC; 
    res.desc.CPUAccessFlags = .WRITE; // either read or write or neither, in alignment with .Usage
    res.desc.ByteWidth = cast(u32) (res.stride * res.capacity);
    res.desc.BindFlags = .VERTEX_BUFFER;
    hr := ID3D11Device_CreateBuffer(render_st.d3d_device, *res.desc, null, *res.buffer);
	assert_d3d_result(hr, "CreateBuffer (vertex buffer)");
	return res;
}

assert_d3d_result :: inline (hr: HRESULT, userMsg: string = "")
{
    if FAILED(hr) {
		#if DEBUG log_dx_messages();
        orig := context.print_style;
        defer context.print_style = orig;
        context.print_style.default_format_int.base = 16;
        assert(false, "D3D fail: %, %: %", userMsg, cast(D3D_RESULT)hr, get_d3d_result_description(cast(D3D_RESULT)hr));
    }
}

#if DEBUG {
    log_dx_messages :: () {
        pInfoQueue: *ID3D11InfoQueue;
        hr :HRESULT = vtable(render_st.d3d_device).QueryInterface(xx render_st.d3d_device, *uid(ID3D11InfoQueue_UUID), cast(**void)*pInfoQueue);
        if SUCCEEDED(hr) {
            ID3D11InfoQueue_SetBreakOnSeverity(pInfoQueue, D3D11_MESSAGE_SEVERITY.CORRUPTION, 1);
            ID3D11InfoQueue_SetBreakOnSeverity(pInfoQueue, D3D11_MESSAGE_SEVERITY.ERROR, 1);

            messageCount := cast(int) ID3D11InfoQueue_GetNumStoredMessages(pInfoQueue);
            messageBuffer: [..]u8;
            messageBuffer.allocator = temp;
            for 0..messageCount-1 {
                messageLength: u64;
                hr = ID3D11InfoQueue_GetMessageA(pInfoQueue, xx it, null, *messageLength);
                array_reserve(*messageBuffer, cast(int)messageLength);
                array_reset_keeping_memory(*messageBuffer);
                hr = ID3D11InfoQueue_GetMessageA(pInfoQueue, xx it, cast(*D3D11_MESSAGE)messageBuffer.data, *messageLength);
                log(to_string((cast(*D3D11_MESSAGE)messageBuffer.data).pDescription));
            }

            ID3D11InfoQueue_ClearStoredMessages(pInfoQueue);
            safe_release(pInfoQueue);
        }
    }
}

D3D_RESULT :: enum s32 {
	D3D11_ERROR_FILE_NOT_FOUND :: -2005139454; // 0x887C0002; // The file was not found.
	D3D11_ERROR_TOO_MANY_UNIQUE_STATE_OBJECTS :: -2005139455; // 0x887C0001; // There are too many unique instances of a particular type of state object.
	D3D11_ERROR_TOO_MANY_UNIQUE_VIEW_OBJECTS :: -2005139453; // 0x887C0003; // There are too many unique instances of a particular type of view object.
	D3D11_ERROR_DEFERRED_CONTEXT_MAP_WITHOUT_INITIAL_DISCARD :: -2005139452; // 0x887C0004; // The first call to ID3D11DeviceContext::Map after either ID3D11Device::CreateDeferredContext or ID3D11DeviceContext::FinishCommandList per Resource was not D3D11_MAP_WRITE_DISCARD.
	DXGI_ERROR_INVALID_CALL :: -2005270527; // 0x887A0001; // The method call is invalid. For example, a method's parameter may not be a valid pointer.
	DXGI_ERROR_WAS_STILL_DRAWING :: -2005270518; // 0x887A000A; // The previous blit operation that is transferring information to or from this surface is incomplete.
	E_FAIL :: -2147467259; // 0x80004005; // Attempted to create a device with the debug layer enabled and the layer is not installed.
	E_INVALIDARG :: -2147024809; // 0x80070057; // An invalid parameter was passed to the returning function.
	E_OUTOFMEMORY :: -2147024882; // 0x8007000E; // Direct3D could not allocate sufficient memory to complete the call.
	E_NOTIMPL :: -2147467263; // 0x80004001; // The method call isn't implemented with the passed parameter combination.
	S_FALSE :: 1; // Alternate success value, indicating a successful but nonstandard completion (the precise meaning depends on context).
	S_OK :: 0;
}

get_d3d_result_description :: (res: D3D_RESULT) -> string
{
	if #complete res == {
		case .D3D11_ERROR_FILE_NOT_FOUND; return "The file was not found.";
		case .D3D11_ERROR_TOO_MANY_UNIQUE_STATE_OBJECTS; return "There are too many unique instances of a particular type of state object.";
		case .D3D11_ERROR_TOO_MANY_UNIQUE_VIEW_OBJECTS; return "There are too many unique instances of a particular type of view object.";
		case .D3D11_ERROR_DEFERRED_CONTEXT_MAP_WITHOUT_INITIAL_DISCARD; return "The first call to ID3D11DeviceContext::Map after either ID3D11Device::CreateDeferredContext or ID3D11DeviceContext::FinishCommandList per Resource was not D3D11_MAP_WRITE_DISCARD.";
		case .DXGI_ERROR_INVALID_CALL; return "The method call is invalid. For example, a method's parameter may not be a valid pointer.";
		case .DXGI_ERROR_WAS_STILL_DRAWING; return "The previous blit operation that is transferring information to or from this surface is incomplete.";
		case .E_FAIL; return "Attempted to create a device with the debug layer enabled and the layer is not installed.";
		case .E_INVALIDARG; return "An invalid parameter was passed to the returning function.";
		case .E_OUTOFMEMORY; return "Direct3D could not allocate sufficient memory to complete the call.";
		case .E_NOTIMPL; return "The method call isn't implemented with the passed parameter combination.";
		case .S_FALSE; return "Alternate success value, indicating a successful but nonstandard completion (the precise meaning depends on context).";
		case .S_OK; return "OK";
	}
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
	assert(texture != global_nil_texture, "Texture % not found", name);
	sprite.texture_key = sprite.name;
	
	sprite.rect = Range2.{max=.{xx texture.width, xx texture.height}};
	// offset
	// grip offset
	// frame count, etc
	// todo - grab these metadata from somewhere
	
	return sprite;
}
*/