#ifndef SAMPLER_TOOLS
#define SAMPLER_TOOLS

static const float2 kernel_16[16] =
{
	//small-----------
	float2(-1.5, -0.5),
	float2(-0.5, +1.5),
	float2(+0.5, -1.5),
	float2(+1.5, +0.5),
	//medium----------
	float2(-2.5, +1.5),
	float2(-1.5, -2.5),
	float2(+1.5, +2.5),
	float2(+2.5, +1.5),
	//large-----------
	float2(-3.5, -2.5),
	float2(-3.5, -0.5),
	float2(-2.5, +3.5),
	float2(-1.5, +3.5),
	float2(+0.5, -3.5),
	float2(+2.5, -3.5),
	float2(+3.5, +0.5),
	float2(+3.5, +2.5)
};

static const float2 poisson_kernel_4[4] =
{
	float2(0.4247072, -0.4262313),
	float2(-0.3010053,  0.3568736),
	float2(0.8125032,  0.3971981),
	float2(-0.4083271, -0.8709177)
};

static const float2 gaussian_kernel_3[3] =
{
	float2(0.250838, 0.0),
	float2(0.498323, 0.0),
	float2(0.250838, 0.0)
};

static const float2 gaussian_kernel_5[5] =
{
	float2(0.130598, 0.0),
	float2(0.230293, 0.0),
	float2(0.278216, 0.0),
	float2(0.230293, 0.0),
	float2(0.130598, 0.0)
};

static const float2 gaussian_kernel_9[9] =
{
	float2(0.068076, -4.0),
	float2(0.095550, -3.0),
	float2(0.121731, -2.0),
	float2(0.140767, -1.0),
	float2(0.147753,  0.0),
	float2(0.140767,  1.0),
	float2(0.121731,  2.0),
	float2(0.095550,  3.0),
	float2(0.068076,  4.0)
};

static const float3 laplacian_edge_kernel[9] =
{
	float3(-1.0,  1.0, -1.0),
	float3(0.0,  1.0,  2.0),
	float3(1.0,  1.0, -1.0),
	float3(-1.0,  0.0,  2.0),
	float3(0.0,  0.0, -4.0),
	float3(1.0,  0.0,  2.0),
	float3(-1.0, -1.0, -1.0),
	float3(0.0, -1.0,  2.0),
	float3(1.0, -1.0, -1.0)
};

static const float3 sobel_edge_kernel_x[6] =
{
	float3(-1.0,  1.0,  1.0),
	float3(1.0,  1.0, -1.0),
	float3(-1.0,  0.0,  2.0),
	float3(1.0,  0.0, -2.0),
	float3(-1.0, -1.0,  1.0),
	float3(-1.0, -1.0, -1.0)
};

static const float3 sobel_edge_kernel_y[6] =
{
	float3(-1.0,  1.0,  1.0),
	float3(0.0,  1.0,  2.0),
	float3(1.0,  1.0,  1.0),
	float3(-1.0, -1.0, -1.0),
	float3(0.0, -1.0, -2.0),
	float3(1.0, -1.0, -1.0)
};

static const float3 sharr_edge_kernel_x[6] =
{
	float3(-1.0,  1.0,  3.0),
	float3(-1.0,  0.0,  10.0),
	float3(-1.0, -1.0,  3.0),
	float3(1.0,  1.0, -3.0),
	float3(1.0,  0.0, -10.0),
	float3(1.0, -1.0, -3.0)
};

static const float3 sharr_edge_kernel_y[6] =
{
	float3(-1.0,  1.0,  3.0),
	float3(0.0,  1.0,  10.0),
	float3(1.0,  1.0,  3.0),
	float3(-1.0, -1.0, -3.0),
	float3(0.0, -1.0, -10.0),
	float3(1.0, -1.0, -3.0)
};

static const float2 box_blur_kernel_3[4] =
{
	float2(-0.5, 0.5),
	float2(0.5, 0.5),
	float2(-0.5,-0.5),
	float2(0.5,-0.5)
};

inline float vec_sum(float2 vec)
{
	return vec.x + vec.y;
}

inline float vec_sum(float3 vec)
{
	return vec.x + vec.y + vec.z;
}

inline float vec_sum(float4 vec)
{
	return vec.x + vec.y + vec.z + vec.w;
}

//CG porting of an awesome tiling technique from Inigo Quilez
//taken from https://www.shadertoy.com/view/Xtl3zf
inline float4 texture_tiler(sampler2D _Tex, float2 uv, float scale, sampler2D _NoiseTex)
{
	float k = tex2D(_NoiseTex, 0.1*uv).x; // cheap (cache friendly) lookup

	float l = k * 8.0;
	float i = floor(l);
	float f = l - i; //getting the fractional part without using frac(l)

	float2 off_a = sin(float2(3.0, 7.0) * i); // can replace with any other hash
	float2 off_b = sin(float2(3.0, 7.0) * (i + 1.0)); // can replace with any other hash

	float4 col_a = tex2D(_Tex, uv + scale * off_a);
	float4 col_b = tex2D(_Tex, uv + scale * off_b);

	return lerp(col_a, col_b, smoothstep(0.2, 0.8, f - 0.1 * vec_sum(col_a - col_b)));
}

inline float4 texture_tiler(sampler2D _Tex, float2 uv, float scale, float4 noise_mask)
{
	float k = dot(tex2D(_Tex, 0.1*uv), noise_mask); // cheap (cache friendly) lookup

	float l = k * 8.0;
	float i = floor(l);
	float f = l - i; //getting the fractional part without using frac(l)

	float2 off_a = sin(float2(3.0, 7.0)*(i + 0.7)); // can replace with any other hash
	float2 off_b = sin(float2(3.0, 7.0)*(i + 1.3)); // can replace with any other hash

	float4 col_a = tex2D(_Tex, uv + scale * off_a);
	float4 col_b = tex2D(_Tex, uv + scale * off_b);

	return lerp(col_a, col_b, smoothstep(0.2, 0.8, f - 0.1 * vec_sum(col_a - col_b)));
}

//noise_uv_scale: defaults to 0.005
inline float4 texture_tiler(sampler2D _Tex, float2 uv, float scale, sampler2D _NoiseTex, float2 noise_uv_scale, float2 noise_uv_offset, float4 noise_mask)
{
	float k = dot(tex2D(_NoiseTex, uv * noise_uv_scale + noise_uv_offset), noise_mask); // cheap (cache friendly) lookup

	float l = k * 8.0;
	float i = floor(l);
	float f = l - i; //getting the fractional part without using frac(l)

	float2 off_a = sin(float2(3.0, 7.0)*(i + 0.0)); // can replace with any other hash
	float2 off_b = sin(float2(3.0, 7.0)*(i + 1.0)); // can replace with any other hash

	float4 col_a = tex2D(_Tex, uv + scale * off_a);
	float4 col_b = tex2D(_Tex, uv + scale * off_b);

	return float4(1,0,0,0);

	return lerp(col_a, col_b, smoothstep(0.2, 0.8, (f - 0.1 * vec_sum(col_a - col_b))));
}


//noise_uv_scale: defaults to 0.005
inline float4 texture_tiler(sampler2D _Tex, float2 uv, float scale, sampler2D _NoiseTex, float2 noise_uv, float4 noise_mask, float2 noise_hash)
{
	float k = dot(tex2D(_NoiseTex, noise_uv), noise_mask); // cheap (cache friendly) lookup

	float l = k * 8.0;
	float i = floor(l);
	float f = l - i; //getting the fractional part without using frac(l)

	float2 off_a = sin(noise_hash * i); // can replace with any other hash
	float2 off_b = sin(noise_hash * (i + 1.0)); // can replace with any other hash

	float4 col_a = tex2D(_Tex, uv + scale * off_a);
	float4 col_b = tex2D(_Tex, uv + scale * off_b);

	return lerp(col_a, col_b, smoothstep(0.2, 0.8, (f - 0.1 * vec_sum(col_a - col_b))));
}

//noise_uv_scale: defaults to 0.005
inline float4 texture_tiler_lod(sampler2D _Tex, float2 uv, float tex_lod, float global_offset, sampler2D _NoiseTex, float2 noise_uv, float noise_lod, float4 noise_mask, float2 noise_hash)
{
	float k = dot(tex2Dlod(_NoiseTex, float4(noise_uv, 0.0, noise_lod)), noise_mask); // cheap (cache friendly) lookup

	float l = k * 8.0;
	float i = floor(l);
	float f = l - i; //getting the fractional part without using frac(l)

	float2 off_a = sin(noise_hash * i); // can replace with any other hash
	float2 off_b = sin(noise_hash * (i + 1.0)); // can replace with any other hash

	float4 col_a = tex2Dlod(_Tex, float4(uv + global_offset * off_a, 0, tex_lod));
	float4 col_b = tex2Dlod(_Tex, float4(uv + global_offset * off_b, 0, tex_lod));

	return lerp(col_a, col_b, smoothstep(0.1, 0.9, (f - 0.1 * vec_sum(col_a - col_b))));
}

//CG porting of an awesome tiling technique from Inigo Quilez
//taken from https://www.shadertoy.com/view/Xtl3zf
inline float4 texture_tiler_lod(sampler2D _Tex, float2 uv, float scale, sampler2D _NoiseTex, float lod)
{
	float k = tex2Dlod(_NoiseTex,float4( 0.1*uv, 0, lod)).x; // cheap (cache friendly) lookup

	float l = k * 8.0;
	float i = floor(l);
	float f = l - i; //getting the fractional part without using frac(l)

	float2 off_a = sin(float2(3.0, 7.0)*(i + 0.0)); // can replace with any other hash
	float2 off_b = sin(float2(3.0, 7.0)*(i + 1.0)); // can replace with any other hash

	float4 col_a = tex2Dlod(_Tex, float4(uv + scale * off_a, 0, lod));
	float4 col_b = tex2Dlod(_Tex, float4(uv + scale * off_b, 0, lod));

	return lerp(col_a, col_b, smoothstep(0.2, 0.8, f - 0.1 * vec_sum(col_a - col_b)));
}

inline float4 texture_tiler_lod(sampler2D _Tex, float2 uv, float scale, float lod, float4 noise_mask)
{
	float k = dot(tex2Dlod(_Tex, float4(0.1*uv, 0, lod)), noise_mask); // cheap (cache friendly) lookup

	float l = k * 8.0;
	float i = floor(l);
	float f = l - i; //getting the fractional part without using frac(l)

	float2 off_a = sin(float2(3.0, 7.0)*(i + 0.0)); // can replace with any other hash
	float2 off_b = sin(float2(3.0, 7.0)*(i + 1.0)); // can replace with any other hash

	float4 col_a = tex2Dlod(_Tex, float4(uv + scale * off_a, 0, lod));
	float4 col_b = tex2Dlod(_Tex, float4(uv + scale * off_b, 0, lod));

	return lerp(col_a, col_b, smoothstep(0.2, 0.8, f - 0.1 * vec_sum(col_a - col_b)));
}

inline float box_blur_3(sampler2D tex, float2 uv, float2 texel_size, float4 tex_mask)
{
	float result = 0.0;

	UNITY_UNROLL
	for (float index = 0.0; index < 4.0; index++)
	{
		result += dot(tex2D(tex, uv + box_blur_kernel_3[index] * texel_size), tex_mask);
	}

	return result / 4.0;
}

inline float box_blur_3(sampler2D tex, float2 uv, float2 texel_size, float4 tex_mask, float lod)
{	
	float result = 0.0;

	UNITY_UNROLL
	for (float index = 0.0; index < 4.0; index++)
	{
		result += dot(tex2Dlod(tex, float4(uv + box_blur_kernel_3[index] * texel_size, 0, lod)), tex_mask);
	}

	return result / 4.0;
}
#endif