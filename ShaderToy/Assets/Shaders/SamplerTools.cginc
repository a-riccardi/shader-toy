#ifndef SAMPLER_TOOLS
#define SAMPLER_TOOLS

#include "Utils.cginc"

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

	float2 off_a = sin(float2(3.0, 7.0)*(i + 0.0)); // can replace with any other hash
	float2 off_b = sin(float2(3.0, 7.0)*(i + 1.0)); // can replace with any other hash

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

	float2 off_a = sin(float2(3.0, 7.0)*(i + 0.0)); // can replace with any other hash
	float2 off_b = sin(float2(3.0, 7.0)*(i + 1.0)); // can replace with any other hash

	float4 col_a = tex2D(_Tex, uv + scale * off_a);
	float4 col_b = tex2D(_Tex, uv + scale * off_b);

	return lerp(col_a, col_b, smoothstep(0.2, 0.8, f - 0.1 * vec_sum(col_a - col_b)));
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
#endif