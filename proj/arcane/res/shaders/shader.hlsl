sampler sampler0: register(s0);
Texture2D<float4> texture0: register(t0);

sampler lut_sampler: register(s1);
Texture2D<float4> lut1_tex: register(t1);
Texture2D<float4> lut2_tex: register(t2);
Texture2D<float4> fire_lut: register(t3);

//
// HELPERS
//

float3 col_lookup(Texture2D<float4> lut, float3 col)
{
	float b1 = floor(col.b*15) / 16.0;
	float b2 = ceil(col.b*15) / 16.0;
	float alpha = frac(col.b*15);
	
	float x = (col.r * 15.0 + 0.5) / 256.0;
	float y = (col.g * 15.0 + 0.5) / 16.0;
	
	float2 xy1 = float2(x + b1, y);
	float2 xy2 = float2(x + b2, y);
	
	float4 lut_col1 = lut.Sample(lut_sampler, xy1);
	float4 lut_col2 = lut.Sample(lut_sampler, xy2);
	float3 lut_col = lerp(lut_col1.xyz, lut_col2.xyz, alpha);
	
	return lut_col;
}

float square(float s)
{
	return s * s;
}

// taken from: https://lisyarus.github.io/blog/graphics/2022/07/30/point-light-attenuation.html
float attenuate(float dist, float radius, float max_intensity, float falloff)
{
	float s = dist / radius;

	if (s >= 1.0)
		return 0.0;

	float s2 = square(s);

	return max_intensity * square(1 - s2) / (1 + falloff * s); // change this last s to s2 for no initial cusp
}

// maps x in range start -> end onto 0 -> 1
float alpha_map(float x, float start, float end)
{
	return clamp((x - start) / (end - start), 0, 1);
}

//
// CBUFFs
//

// https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-packing-rules

#define MAX_LIGHTS 64

cbuffer cbuf : register(b0)
{
	float4 params; // night_alpha, 
 	float2 window_size;
 	float cam_zoom;
 	float lut_blend_alpha;
 	float4 lights[64];
 	int light_count;
 	bool debug_val;
}

cbuffer batch_uniforms : register(b1)
{
	row_major float4x4 localToClip;
	float4 haze;
 	float lut_strength;
 	float light_strength;
}

//
// MAIN
//

struct QuadIn
{
	float3 pos: POS;
	float2 uv: UV;
	float4 col: COL;
};

struct QuadOut
{
	float4 pos: SV_POSITION;
	float2 uv: TEXCOORD2;
	float4 col: COLOR4;
};

QuadOut quad_vs(QuadIn input)
{
	QuadOut output;
	output.pos = mul(localToClip, float4(input.pos.xyz, 1.0f));
	output.uv = input.uv;
	output.col = input.col;
	return output;
}

float4 quad_ps(QuadOut input): SV_Target
{
	float night_alpha = params.x;
	
	float2 screen_alpha = input.pos / window_size;
	float depth = input.pos.z;
	depth = alpha_map(depth, 0.1, 0.9); // stretch it in so the near / far are less fuzzy and more concrete
	float bg_depth = alpha_map(input.pos.z, 0.4, 1.2); // depth that focuses on the background
	
	// yeah this ain't gonna work brother, gotta actually get the pixel size right, it's too high-res
	// matrix rot ={
	// 	cos(angle), -sin(angle), 0, 0,
	// 	sin(angle), cos(angle), 0, 0,
	// 	0, 0, 1, 0,
	// 	0, 0, 0, 1,
	// };
	// float4 tex_coords = float4(input.uv, 0, 1);
	// tex_coords = mul(tex_coords, rot);
	
	// float angle = degrees(45);
	// float2 tex_coords = input.uv * window_size;
	// tex_coords.x -= floor(tan(angle/2.0)*tex_coords.y);
	// tex_coords.y += floor(sin(angle)*tex_coords.x);
	// tex_coords.x -= floor(tan(angle/2.0)*tex_coords.y);
	// tex_coords = tex_coords / window_size;
	
	
	float4 albedo = texture0.Sample(sampler0, input.uv);
	albedo *= input.col;
	
	float3 lut1_col = col_lookup(lut1_tex, albedo);
	float3 lut2_col = col_lookup(lut2_tex, albedo);
	float3 lut_albedo = lerp(lut1_col, lut2_col, lut_blend_alpha);
	
	float litness;
	for (int i = 0; i < light_count; i++)
	{
		float2 light_pos = lights[i].xy;
		litness += attenuate(distance(light_pos, input.pos), lights[i].z, 1, lights[i].w);
	}
	litness = min(litness, 1.0);
	litness *= 1-depth;
	
	float3 lut_applied = lerp(albedo.rgb, lut_albedo.xyz, lut_strength * (1-litness));
	// apply the fire lut where lit
	lut_applied = lerp(lut_applied, col_lookup(fire_lut, albedo), litness);
	
	// 
	// float haze_layer = (1-step(input.pos.z, 0.3)) ;
	
	// black haze
	// TODO - proper haze for the bg layers during the day time to seperate the playspce
	float3 haze_col = float3(0.0, 0.0, 0.0);
	lut_applied = lerp(lut_applied, haze_col, bg_depth * clamp(0.5 + night_alpha.x, 0, 1));
	
	
	float4 final_col = float4(lut_applied, albedo.a);
	// final_col = albedo;
	return final_col;
	// return float4(params.x, params.x, params.x, albedo.a);
	// return float4(haze_layer, haze_layer, haze_layer, albedo.a);
	// return float4(screen_alpha.xy, 0, 1);
}