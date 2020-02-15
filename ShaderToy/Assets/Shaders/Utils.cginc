#ifndef UTILS
#define UTILS

#include "Hash.cginc"
#include "SamplerTools.cginc"

#define PI (3.14159265)
#define PI_2 (6.2831853)
#define PI_INVERSE (0.3183098)

#define GRAYSCALE_3 float3(0.2126, 0.7152, 0.0722)
#define GRAYSCALE float4(0.2126, 0.7152, 0.0722, 1.0)

#define UV_CENTER (float2(0.5, 0.5))

inline float remap(float value, float oldMin, float oldMax, float newMin, float newMax)
{
	return newMin + (value - oldMin) / (newMax - newMin) * (oldMax - oldMin);
}

inline float remap01(float value, float oldMin, float oldMax)
{
	return (value - oldMin) / (oldMax - oldMin);
}

inline float remap_from_01(float value, float newMin, float newMax)
{
	return newMin + value / (newMax - newMin);
}

inline float clamp01(float val)
{
	return clamp(val, 0, 1);
}

inline float2 clamp01(float2 vec)
{
	return clamp(vec, 0, 1);
}

inline float3 clamp01(float3 vec)
{
	return clamp(vec, 0, 1);
}

inline float4 clamp01(float4 vec)
{
	return clamp(vec, 0, 1);
}

inline float cheap_contrast(float val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float2 cheap_contrast(float2 val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float3 cheap_contrast(float3 val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float4 cheap_contrast(float4 val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float sqr_magnitude(float2 vec)
{
	return dot(vec, vec);
}

inline float sqr_magnitude(float3 vec)
{
	return dot(vec, vec);
}

inline float sqr_magnitude(float4 vec)
{
	return dot(vec, vec);
}

inline float saturated_dot(float2 vec1, float2 vec2)
{
	return saturate(dot(vec1, vec2));
}

inline float saturated_dot(float3 vec1, float3 vec2)
{
	return saturate(dot(vec1, vec2));
}

inline float saturated_dot(float4 vec1, float4 vec2)
{
	return saturate(dot(vec1, vec2));
}

inline float grayscale_3(float3 col)
{
	return col.x * GRAYSCALE_3.x + col.y * GRAYSCALE_3.y + col.z * GRAYSCALE_3.z;
}

inline float grayscale(float4 col)
{
	return col.x * GRAYSCALE_3.x + col.y * GRAYSCALE_3.y + col.z * GRAYSCALE_3.z;
}

inline float2 uv_scale_transform(float2 uv, float4 sampler_ST)
{
	return uv * sampler_ST.xy + sampler_ST.zw;
}

inline float2 uv_scale_transform(float2 uv, float4 sampler_ST, float global_scaler)
{
	return uv * sampler_ST.xy * global_scaler + sampler_ST.zw;
}

inline float expand_range(float f)
{
	return f * 2.0 - 1.0;
}

inline float2 expand_range(float2 f)
{
	return f * 2.0 - 1.0;
}

inline float3 expand_range(float3 f)
{
	return f * 2.0 - 1.0;
}

inline float4 expand_range(float4 f)
{
	return f * 2.0 - 1.0;
}

inline float compress_range(float f)
{
	return f * 0.5 + 0.5;
}

inline float2 compress_range(float2 f)
{
	return f * 0.5 + 0.5;
}

inline float3 compress_range(float3 f)
{
	return f * 0.5 + 0.5;
}

inline float4 compress_range(float4 f)
{
	return f * 0.5 + 0.5;
}

inline float sqr(float f)
{
	return f * f;
}

inline float2 sqr(float2 f)
{
	return f * f;
}

inline float3 sqr(float3 f)
{
	return f * f;
}

inline float4 sqr(float4 f)
{
	return f * f;
}

//taken from http://blog.selfshadow.com/publications/blending-in-detail/, reorient detail normal map to follow the base normal map direction
inline float3 reorient_normal_map(float3 base_normal, float3 detail_normal)
{
	float3 t = base_normal * float3(2, 2, 2) + float3(-1, -1, 0);
	float3 u = detail_normal * float3(-2, -2, 2) + float3(1, 1, -1);
	return normalize(t * dot(t, u) - u * t.z);
}

//inline float3 analytical_normal_extraction(sampler2D heightmap, float3 base_normal, float vertex_offset, float4 heightmap_mask, float4 world_space_vertex, float2 world_space_uv, float lod, float displacement, out float4 position)
//{
//	//v0 is the current vertex, v1 and v2 are fake neighbour vertices used to compute the normal
//	float4 v0 = world_space_vertex;
//	float4 v1 = v0 + float4(vertex_offset, 0, 0, 0);
//	float4 v2 = v0 + float4(0, 0, vertex_offset, 0);
//
//	//get the correct height for the three point needed for analytical normal reconstruction
//	v0.y += expand_range(dot(tex2Dlod(heightmap, float4(world_space_uv, 0, lod)), heightmap_mask)) * displacement;
//	v1.y += expand_range(dot(tex2Dlod(heightmap, float4((world_space_uv.x + vertex_offset), world_space_uv.y, 0, lod)), heightmap_mask)) * displacement;
//	v2.y += expand_range(dot(tex2Dlod(heightmap, float4(world_space_uv.x, (world_space_uv.y + vertex_offset), 0, lod)), heightmap_mask)) * displacement;
//
//	position = mul(unity_WorldToObject, v0);
//
//	//compute the world space normal as the cross product of the Z and the X vector
//	float3 wsn = normalize(cross((v1 - v0).xyz, (v2 - v0).xyz));
//	wsn.y *= -1;
//	//return the computed object space normal for this vertex
//	return mul((float3x3)unity_WorldToObject, wsn);
//
//	//normalize and store the computed object space normal for this vertex, accounting for object_space normal direction
//	//float3 normal = reorient_normal_map(float3(0,0,1), mul((float3x3)unity_WorldToObject, wsn));
//
//	//retutn normal;
//}

inline float3 analytical_normal_extraction(sampler2D heightmap, float3 base_normal, float vertex_offset, float4 heightmap_mask, float4 world_space_vertex, float2 world_space_uv, float lod, float displacement, out float4 position)
{
	//v0 is the current vertex, v1 and v2 are fake neighbour vertices used to compute the normal
	float4 v0 = world_space_vertex;
	float4 v1 = v0 + float4(vertex_offset, 0, 0, 0);
	float4 v2 = v0 + float4(0, 0, vertex_offset, 0);

	//get the correct height for the three point needed for analytical normal reconstruction
	v0.y += /*expand_range*/(box_blur_3(heightmap, world_space_uv, float2(vertex_offset, vertex_offset), heightmap_mask, lod)) * displacement;
	v1.y += /*expand_range*/(box_blur_3(heightmap, float2((world_space_uv.x + vertex_offset), world_space_uv.y), float2(vertex_offset, vertex_offset), heightmap_mask, lod)) * displacement;
	v2.y += /*expand_range*/(box_blur_3(heightmap, float2(world_space_uv.x, (world_space_uv.y + vertex_offset)), float2(vertex_offset, vertex_offset), heightmap_mask, lod)) * displacement;

	position = mul(unity_WorldToObject, v0);

	//compute the world space normal as the cross product of the Z and the X vector
	float3 wsn = cross((v2 - v0).xyz, (v1 - v0).xyz);
	//float3 wsn = cross((v1 - v0).xyz, (v2 - v0).xyz);
	//wsn.y *= -1;
	//return the computed object space normal for this vertex
	return normalize(mul((float3x3)unity_WorldToObject, wsn));

	//normalize and store the computed object space normal for this vertex, accounting for object_space normal direction
	//float3 normal = reorient_normal_map(float3(0,0,1), mul((float3x3)unity_WorldToObject, wsn));

	//retutn normal;
}

//NOTE: this function assumes coord param as a direction, thus pre-normalized
//in order to save a sqrt(x*x + y*y + z*z) instruction
//Conversion taken from https://en.wikipedia.org/wiki/Spherical_coordinate_system
float3 CartesianToSphericalCoordConversion_Direction(float3 coord)
{
	//spherical coords are espressed as radius, inclination, azimuth as x,y,z of a float3
	//since it's a direction of length 1, radius is directly setted to 1 instead of being computed
	float3 sphericalCoord = float3(1.0, 0.0, 0.0);

	sphericalCoord.y = acos(coord.z);
	sphericalCoord.z = atan2(coord.y, coord.x);

	return sphericalCoord;
}

#endif