#ifndef BLEND_MODES
#define BLEND_MODES

inline float3 soft_light(float3 base_color, float3 layer_color)
{
	return (float3(1.0, 1.0, 1.0) - 2.0 * layer_color) * (base_color * base_color) + 2.0 * base_color * layer_color;
}

inline float4 soft_light(float4 base_color, float4 layer_color)
{
	return (float4(1.0, 1.0, 1.0, 1.0) - 2.0 * layer_color) * (base_color * base_color) + 2.0 * base_color * layer_color;
}

inline float3 overlay(float3 base_color, float3 layer_color)
{
	return lerp( float3(1.0, 1.0, 1.0) - 2.0 * (float3(1.0, 1.0, 1.0) - base_color) * (float3(1.0, 1.0, 1.0) - layer_color), 2.0 * base_color * layer_color, base_color < float3(0.5, 0.5, 0.5));
}

inline float4 overlay(float4 base_color, float4 layer_color)
{
	return lerp(float4(1.0, 1.0, 1.0, 1.0) - 2.0 * (float4(1.0, 1.0, 1.0, 1.0) - base_color) * (float4(1.0, 1.0, 1.0, 1.0) - layer_color), 2.0 * base_color * layer_color, base_color < float4(0.5, 0.5, 0.5, 0.5));
}

#endif