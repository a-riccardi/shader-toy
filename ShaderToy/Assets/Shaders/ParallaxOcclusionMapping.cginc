#ifndef POM_HUB
#define POM_HUB

//remember to define one or more of this keyworkds if you want to select the number of steps for your shader. It will default to 10 for each cycle otherwise
//just add "#pragma multi_compile _QUALITY_ULTRA _QUALITY_HIGH _QUALITY_MEDIUM _QUALITY_LOW" to your shader to enable the multi compiling feature
//and "[KeywordEnum(Low, Medium, High, Ultra)] _Quality("Parallax Quality", Float) = 0" to display an enum that allows you to select the quality at runtime

//if you whish to use the height map as a depth map, just define DEPTH_MAP keyword somewhere in your shader
//or just add "#pragma shader_feature DEPTH_MAP" and "[Toggle(DEPTH_MAP)] _DepthMap("Use heightmap as depthmap", Float) = 0" to display a toggle that allows you
//to enable this feature at runtime

inline float get_depth(float min_depth, float max_depth, float depth)
{
	return lerp(min_depth, max_depth, depth);
}

inline float sample_depth(sampler2D depth_texture, float4 depth_texture_channel_mask, float2 uv, float4 dd)
{
#ifdef DEPTH_MAP
	return dot(tex2D(depth_texture, uv, dd.xy, dd.zw), depth_texture_channel_mask);
#else
	return 1.0 - dot(tex2D(depth_texture, uv, dd.xy, dd.zw), depth_texture_channel_mask);
#endif
}

inline float sample_depth_lod(sampler2D depth_texture, float4 depth_texture_channel_mask, float4 uv)
{
#ifdef DEPTH_MAP
	return dot(tex2Dlod(depth_texture, uv), depth_texture_channel_mask);
#else
	return 1.0 - dot(tex2Dlod(depth_texture, uv), depth_texture_channel_mask);
#endif
}

inline float sample_depth_value(sampler2D depth_texture, float4 depth_texture_channel_mask, float2 uv, in float4 dd, float min_depth, float max_depth, float depth)
{
#ifdef SAMPLE_DEPTH_VALUE_LOD
	return sample_depth_lod(depth_texture, depth_texture_channel_mask, float4(uv, 0.0, 0.0)) * get_depth(min_depth, max_depth, depth);
#else
	return sample_depth(depth_texture, depth_texture_channel_mask, uv, dd) * get_depth(min_depth, max_depth, depth);
#endif
}
//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//min_depth = minimum depth value (aka maxim height), usually 0.0
//max_depth = maximum depth value (aka minimum height), usually 1.0
//depth = [0..1] value used to lerp between the two previous parameters
//current_uv = uv at ray-surface intersection point
//delte_uv = how much the uv offset for each layer
//current_depth = depth at intersection point. use sample_depth(depth_texture, depth_texture_channel_mask, uv, dd) function to get it
//current_layer_depth = how deep is the current layer. usually starts at 0.0
//layer_depth = how deep each layer goes, usually surface depth / layer number
inline float2 raytrace_loop_uv(in float layerN, in sampler2D depth_texture, in float4 depth_texture_channel_mask, in float4 dd, in float min_depth, in float max_depth, in float depth, in float2 current_uv, in float2 delta_uv, inout float current_depth, inout float current_layer_depth, in float layer_depth)
{
	[loop]
	for (float j = 0.0; j < layerN; j++)
	{
		if (current_layer_depth >= current_depth)
		{
			break;
		}

		current_uv -= delta_uv;
		current_depth = sample_depth_value(depth_texture, depth_texture_channel_mask, current_uv, dd, min_depth, max_depth, depth);
		current_layer_depth += layer_depth;
	}

	return current_uv;
}

inline float raytrace_loop_shadows(in float layerN, in sampler2D depth_texture, in float4 depth_texture_channel_mask, in float4 dd, in float min_depth, in float max_depth, in float depth, in float2 current_uv, in float2 delta_uv, in float current_depth, inout float current_layer_depth, in float layer_depth)
{
	float shadow_samples = 0.0;
	float shadow_factor = 0.0;

	[loop]
	for (float j = 0.0; j < layerN; j++)
	{
		if (current_layer_depth <= 0.0)
			break;

		if (current_layer_depth < current_depth)
		{
			shadow_samples++;
			shadow_factor = max(shadow_factor, (current_depth - current_layer_depth) * (1.0 - (j+1.0) / layerN));
		}

		current_uv -= delta_uv;
		current_depth = sample_depth_value(depth_texture, depth_texture_channel_mask, current_uv, dd, min_depth, max_depth, depth);
		current_layer_depth -= layer_depth;
	}

	return lerp(1.0, 1.0 - shadow_factor, sign(shadow_samples));
}

inline float get_intersection_interpolation(float current_depth, float layer_depth, float current_layer_depth, float2 current_uv, float2 delta_uv, sampler2D depth_texture, float4 depth_texture_channel_mask, float2 uv, in float4 dd, float min_depth, float max_depth, float depth)
{
	float h_diff = current_depth - current_layer_depth;
	float prev_h_diff = sample_depth(depth_texture, depth_texture_channel_mask, current_uv + delta_uv, dd) - current_layer_depth + layer_depth;
	return prev_h_diff / (prev_h_diff - h_diff);
}

//contact refinement parallax uv mapping approaches the parallax uv problem in two steps.
//1) using a low number of steps, it computes a rough approximation of the intersection point between the ray and the surface
//2) rolling back to the previous step along the ray, it uses another loop with the same step numbers but this times it only covers
//the distance between the previous point and the rough intersection point, obtaining a much better approximation of the surface
//using only 4 more instruction than the vanilla technique
//eye_ray = tangent space view direction vector (normalized)
//uv = uv at ray/surface intersection point
//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//min_depth = minimum depth value (aka maxim height), usually 0.0
//max_depth = maximum depth value (aka minimum height), usually 1.0
//depth = [0..1] value used to lerp between the two previous parameters
inline float2 get_parallax_offset_uv(in float4 dd, in float layerN, in float3 eye_ray, in float2 uv_eye, in sampler2D depth_texture, in float4 depth_texture_channel_mask, in float min_depth, in float max_depth, in float depth
#ifdef SELFSHADOWS_SOFT
	, in float3 ts_light_pos, out float shadow_attenuation
#endif
#ifdef OUTPUT_DEPTH
	, out float depth_value
#endif
	)
{
	float layer_depth = 1.0 / layerN;
	float current_layer_depth = 0.0;

	float2 P = (eye_ray.xy / eye_ray.z) * get_depth(min_depth, max_depth, depth);
	float2 delta_uv = P / 256.0; //STR_LAYER; // 256.0;

	float2 current_uv = uv_eye;
	float current_depth = sample_depth(depth_texture, depth_texture_channel_mask, current_uv, dd);

	current_uv = raytrace_loop_uv(layerN, depth_texture, depth_texture_channel_mask, dd, min_depth, max_depth, depth, current_uv, delta_uv, current_depth, current_layer_depth, layer_depth);

#ifdef CONTACT_REFINEMENT
	current_uv += delta_uv;
	current_depth = sample_depth(depth_texture, depth_texture_channel_mask, current_uv, dd);
	delta_uv /= layerN;
	layer_depth /= layerN;
	
	current_uv = raytrace_loop_uv(layerN, depth_texture, depth_texture_channel_mask, dd, min_depth, max_depth, depth, current_uv, delta_uv, current_depth, current_layer_depth, layer_depth);
#endif

#ifdef OUTPUT_DEPTH
	depth_value = current_depth;
#endif

#ifdef SELFSHADOWS_SOFT
	float2 shadow_uv = current_uv;
	layerN = round(current_layer_depth * layerN);
	float2 shadow_delta_uv = ((ts_light_pos.xy / ts_light_pos.z) * get_depth(min_depth, max_depth, depth)) / 256.0;
#ifdef CONTACT_REFINEMENT
	layer_depth *= layerN;
#endif
	shadow_attenuation = raytrace_loop_shadows(layerN, depth_texture, depth_texture_channel_mask, dd, min_depth, max_depth, depth, shadow_uv, shadow_delta_uv, current_depth, current_layer_depth, layer_depth);
#endif

#ifdef INTERSECTION_LINEAR_INTERPOLATION
	return lerp(current_uv + delta_uv, current_uv, get_intersection_interpolation(current_depth, layer_depth, current_layer_depth, current_uv, delta_uv, depth_texture, depth_texture_channel_mask, uv_eye, dd, min_depth, max_depth, depth));
#else
	return current_uv;
#endif
}
#endif