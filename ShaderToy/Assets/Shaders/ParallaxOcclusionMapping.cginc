#ifndef PM_HUB
#define PM_HUB

//-----------------------------------------------------------README-----------------------------------------------------------
//this library makes use of #defines to optimize away pieces of code you don't need. Please take some time to read which symbols you should define and why

//if you whish to enable the contact refinement technique, just define _PTHQ_CONTACT_REFINEMENT keyword somewhere in your shader
//or just add "#pragma shader_feature _PTHQ_CONTACT_REFINEMENT" and "[Toggle(_PTHQ_CONTACT_REFINEMENT)] _CRPOM("Enable Contact Refinement POM?", Float) = 0" to display a toggle that allows you
//to enable this feature at runtime

//if you whish to enable the computation of soft shadows, just define SELFSHADOWS_SOFT keyword somewhere in your shader
//or just add "#pragma shader_feature SELFSHADOWS_SOFT" and "[Toggle(SELFSHADOWS_SOFT)] _SShadowsSoft("Enable Soft Self-Shadowing?", Float) = 0" to display a toggle that allows you
//to enable this feature at runtime

//if you whish to enable the output of computed depth value per fragment, just define OUTPUT_DEPTH keyword somewhere in your shader
//or just add "#pragma shader_feature OUTPUT_DEPTH" and "[Toggle(OUTPUT_DEPTH)] _OutputDepth("Output Depth in BaseColor? (for debug purposes)", Float) = 0" to display a toggle that allows you
//to enable this feature at runtime

//if you whish to enable the linear interpolation between samples, just define _PTHQ_OCCLUSION_MAPPING keyword somewhere in your shader
//or just add "#pragma shader_feature _PTHQ_OCCLUSION_MAPPING" and "[Toggle(_PTHQ_OCCLUSION_MAPPING)] _ILI("Enable Intersection Linear Interpolation?", Float) = 0" to display a toggle that allows you
//to enable this feature at runtime

//if you whish to use the height map as a depth map, just define DEPTH_MAP keyword somewhere in your shader
//or just add "#pragma shader_feature DEPTH_MAP" and "[Toggle(DEPTH_MAP)] _DepthMap("Use heightmap as depthmap", Float) = 0" to display a toggle that allows you
//to enable this feature at runtime
//----------------------------------------------------------!README-----------------------------------------------------------

//function used to get the scaled depth value.

//params:

//min_depth = minimum depth value, usually 0.0
//max_depth = maximum depth value, usually 1.0
//depth = [0..1] float used to lerp between min and max
inline float get_depth(float min_depth, float max_depth, float depth)
{
	return lerp(min_depth, max_depth, depth);
}

//function used to actually sample the heightmap.

//params:

//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//uv = uv at which sample the heightmap
inline float sample_depth(sampler2D depth_texture, float4 depth_texture_channel_mask, float2 uv, float4 dd)
{
#ifdef DEPTH_MAP
	return dot(tex2D(depth_texture, uv, dd.xy, dd.zw), depth_texture_channel_mask);
#else
	//since we need the depth of the surface (and not the height), if DEPTH_MAP is not defined invert the sampled value
	return 1.0 - dot(tex2D(depth_texture, uv, dd.xy, dd.zw), depth_texture_channel_mask);
#endif
}

//function used to actually sample the heightmap.

//params:

//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//uv = uv at which sample the heightmap
inline float sample_depth_lod(sampler2D depth_texture, float4 depth_texture_channel_mask, float4 uv)
{
#ifdef DEPTH_MAP
	return dot(tex2Dlod(depth_texture, uv), depth_texture_channel_mask);
#else
	//since we need the depth of the surface (and not the height), if DEPTH_MAP is not defined invert the sampled value
	return 1.0 - dot(tex2Dlod(depth_texture, uv), depth_texture_channel_mask);
#endif
}

//function used to sample heightmap value. It returns the sampled value scaled by the global depth of the surface.

//params:

//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//uv = uv at which sample the heightmap
//dd = partial uv derivatives on u and v. used to sample heightmap in a branched loop
//min_depth = minimum depth value (aka maxim height), usually 0.0
//max_depth = maximum depth value (aka minimum height), usually 1.0
//depth = [0..1] value used to lerp between the two previous parameters
inline float sample_depth_value(sampler2D depth_texture, float4 depth_texture_channel_mask, float2 uv, in float4 dd, float min_depth, float max_depth, float depth)
{
//#ifdef SAMPLE_DEPTH_VALUE_LOD
//	return sample_depth_lod(depth_texture, depth_texture_channel_mask, float4(uv, 0.0, 0.0)) * get_depth(min_depth, max_depth, depth);
//#else
	return sample_depth(depth_texture, depth_texture_channel_mask, uv, dd) * get_depth(min_depth, max_depth, depth);
//#endif
}

//function used to refine the parallax-offsetted uv computed through binary searching around the naive intersection point. Returns the corrected uvs.

//params:

//dd = partial uv derivatives on u and v. used to sample heightmap in a branched loop
//layerN = the maximum number of layers to divide the heightmap into. Note that usually less steps will be taken 
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
inline float2 binary_search_loop_uv(in float4 dd, in float layerN, in sampler2D depth_texture, in float4 depth_texture_channel_mask, in float min_depth, in float max_depth, in float depth, in float2 current_uv, in float2 delta_uv, inout float current_depth, inout float current_layer_depth, in float layer_depth)
{
	//initialize depth sign, used to increase or decrease delta_uv and layer_depth
	float depth_sign = -1.0;
	//since there's no comparison, unroll this loop to avoid branching 
	[unroll]
	for (float j = 0.0; j < layerN; j++)
	{
		//each iteration, halve the delta_uv and the layer_depth
		delta_uv *= 0.5;
		layer_depth *= 0.5;

		//optimization to avoid branching
		depth_sign = sign(current_depth - current_layer_depth);

		//increase or decrease the current_uv and the current_layer_depth if we're over or under the surface
		current_uv += delta_uv * depth_sign;
		current_layer_depth += layer_depth * depth_sign;

		//adjust current_depth value by sampling the heightmap
		current_depth = sample_depth_value(depth_texture, depth_texture_channel_mask, current_uv, dd, min_depth, max_depth, depth);
	}

	return current_uv;
}

//function used to raytrace along the height map. Returns the parallax-offsetted uvs.

//params:

//dd = partial uv derivatives on u and v. used to sample heightmap in a branched loop
//layerN = the maximum number of layers to divide the heightmap into. Note that usually less steps will be taken 
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
inline float2 raytrace_loop_uv(in float4 dd, in float layerN, in sampler2D depth_texture, in float4 depth_texture_channel_mask, in float min_depth, in float max_depth, in float depth, in float2 current_uv, in float2 delta_uv, inout float current_depth, inout float current_layer_depth, in float layer_depth)
{
	//tell the compiler to dinamically branch this loop
	[loop]
	for (float j = 0.0; j < layerN; j++)
	{
		//if we're beneath the surface, exit the loop
		if (current_layer_depth >= current_depth)
		{
			break;
		}

		//update current_uv
		current_uv -= delta_uv;
		//resample height map
		current_depth = sample_depth_value(depth_texture, depth_texture_channel_mask, current_uv, dd, min_depth, max_depth, depth);
		//update current_layer_depth
		current_layer_depth += layer_depth;
	}

	return current_uv;
}

//function used to raytrace from found parallax-offsettted point to the light. Outputs a [0..1] float that represents how much the current point is shadowed.
//see https://github.com/UPBGE/blender/issues/1009 for more details.

//params:

//layerN = the maximum number of layers to divide the heightmap into. Note that usually less steps will be taken 
//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//dd = partial uv derivatives on u and v. used to sample heightmap in a branched loop
//min_depth = minimum depth value (aka maxim height), usually 0.0
//max_depth = maximum depth value (aka minimum height), usually 1.0
//depth = [0..1] value used to lerp between the two previous parameters
//current_uv = parallax-offsetted uvs
//delta_uv = delta uv used for raytrace loop
//current_depth = current heightmap value [0..1]
//current_layer_depth = current layer depth [0..1]
//layer_depth = how deep is each layer?
inline float raytrace_loop_shadows(in float layerN, in sampler2D depth_texture, in float4 depth_texture_channel_mask, in float4 dd, in float min_depth, in float max_depth, in float depth, in float2 current_uv, in float2 delta_uv, in float current_depth, inout float current_layer_depth, in float layer_depth)
{
	//initialize loop variables
	//shadow_samples hold the number of steps beneath the surface, shadow_factor will return the soft shadow amount
	float shadow_samples = 0.0;
	float shadow_factor = 0.0;

	//allow the loop to branch dynamically based on conditions, othwewise it will unroll
	[loop]
	for (float j = 0.0; j < layerN; j++)
	{
		//if we're over the surface, exit the loop
		//this condition could be avoided since we already computed the layerN we need to get ot of the surface
		//if (current_layer_depth <= 0.0)
			//break;

		//if the current ray depth is beneath the surface, update the loop variables
		if (current_layer_depth < current_depth)
		{
			//increment shadow_samples variable
			shadow_samples++;
			//shadow_factor is the maximum possible height covering the current point scaled by the distance from the point
			shadow_factor = max(shadow_factor, (current_depth - current_layer_depth) * (1.0 - (j+1.0) / layerN));
		}

		//update current_uv
		current_uv -= delta_uv;
		//resample the height map
		current_depth = sample_depth_value(depth_texture, depth_texture_channel_mask, current_uv, dd, min_depth, max_depth, depth);
		//update current_layer_depth
		current_layer_depth -= layer_depth;
	}

	//if we took any sample beneath the surface, return the shadow factor. Else return 1
	return lerp(1.0, 1.0 - shadow_factor, sign(shadow_samples));
}

//get a [0..1] weight to interpolate between previous_uv and current_uv to mitigate the step effect.
//this weight is computed as the difference between the heightmap and the layer depth at previous step divided by the difference between the previous height difference and the current difference.
//see https://catlikecoding.com/unity/tutorials/rendering/part-20/ for more details.

//params:

//dd = partial uv derivatives on u and v. used to sample heightmap in a branched loop
//current_depth = current heightmap value [0..1]
//current_layer_depth = current layer depth [0..1]
//layer_depth = how deep is each layer?
//current_uv = parallax-offsetted uvs
//delta_uv = delta uv used for raytrace loop
//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//min_depth = minimum depth value (aka maxim height), usually 0.0
//max_depth = maximum depth value (aka minimum height), usually 1.0
//depth = [0..1] value used to lerp between the two previous parameters
inline float get_intersection_interpolation(in float4 dd, float current_depth, float current_layer_depth, float layer_depth, float2 current_uv, float2 delta_uv, sampler2D depth_texture, float4 depth_texture_channel_mask, float min_depth, float max_depth, float depth)
{
	//at final step, the current_depth is > than the current_layer_depth (the ray is beneath the surface)
	float h_diff = current_depth - current_layer_depth;
	//at (final step - 1), the layer depth is > than the current depth
	float prev_h_diff = (current_layer_depth - layer_depth) - sample_depth(depth_texture, depth_texture_channel_mask, current_uv + delta_uv, dd);
	//return the intersection point
	return prev_h_diff / (prev_h_diff + h_diff);
}

//get the parallax-offsetted uv.

//params:

//dd = partial uv derivatives on u and v. used to sample heightmap in a branched loop
//layerN = the maximum number of layers to divide the heightmap into. Note that usually less steps will be taken 
//eye_ray = tangent space view direction vector (normalized)
//uv_eye = uv at ray/surface intersection point
//depth texture = the texture that contains the height(or depth)map
//depth_texture_channel_mask = which channel actually contains the height information
//min_depth = minimum depth value (aka maxim height), usually 0.0
//max_depth = maximum depth value (aka minimum height), usually 1.0
//depth = [0..1] value used to lerp between the two previous parameters
//ts_light_ray = if you whish to use self shadows, provide a tangent-space ray to the light source
//shadow_attenuation = this out parameter will hold the shadow attenuation amount for this pixel. Just multiply your baseColor for it
//depth_value = mostly for debug purposes. This out parameter will return the depth of the fragment. 0 = maximum height, 1 = minimum height
inline float2 get_parallax_offset_uv(in float4 dd, in float layerN, in float3 eye_ray, in float2 uv_eye, in sampler2D depth_texture, in float4 depth_texture_channel_mask, in float min_depth, in float max_depth, in float depth
#ifdef SELFSHADOWS_SOFT
	, in float3 ts_light_ray, out float shadow_attenuation
#endif
#ifdef OUTPUT_DEPTH
	, out float depth_value
#endif
	)
{
	//compute layer depth and initialize current_layer_depth as 0.0
	float layer_depth = 1.0 / layerN;
	float current_layer_depth = 0.0;

	//compute the delta_uv used to offset each cycle
	float2 P = (eye_ray.xy / eye_ray.z) * get_depth(min_depth, max_depth, depth);
	float2 delta_uv = P / 256.0; //STR_LAYER; // 256.0;

	//initialize current_uv parameter, which will return the offsetted uv
	float2 current_uv = uv_eye;
	//initialize current_depth parameter, which will hold the depth at current sample loop
	float current_depth = sample_depth(depth_texture, depth_texture_channel_mask, current_uv, dd);
	//get parallax-offsetted uv (see raytrace_uv_loop function before for more details)
	current_uv = raytrace_loop_uv(dd, layerN, depth_texture, depth_texture_channel_mask, min_depth, max_depth, depth, current_uv, delta_uv, current_depth, current_layer_depth, layer_depth);

//contact refinement parallax uv mapping approaches the parallax uv problem in two steps.
//1) using a low number of steps, it computes a rough approximation of the intersection point between the ray and the surface
//2) rolling back to the previous step along the ray, it uses another loop with the same step numbers but this times it only covers
//the distance between the previous point and the rough intersection point, obtaining a much better approximation of the surface
//using only 5 more assignement than the vanilla parallax technique
//standard technique = 1/layerN approximation error
//contact refinement technique = 1/(layerN * layerN) approximation error
#if _PTHQ_CONTACT_REFINEMENT && !(_PTHQ_BINARY_SEARCH)
	//if contact refinement technique is enabled, roll back the computation one step to get out of the heightmap
	current_uv += delta_uv;
	current_depth = sample_depth(depth_texture, depth_texture_channel_mask, current_uv, dd);
	//adjust the precision of delta_uv and layer_depth 
	delta_uv /= layerN;
	layer_depth /= layerN;
	//get contact refinement uv by raytrace again with better precision
	current_uv = raytrace_loop_uv(dd, layerN, depth_texture, depth_texture_channel_mask, min_depth, max_depth, depth, current_uv, delta_uv, current_depth, current_layer_depth, layer_depth);
#elif _PTHQ_BINARY_SEARCH && !(_PTHQ_CONTACT_REFINEMENT)
	current_uv = binary_search_loop_uv(dd, layerN, depth_texture, depth_texture_channel_mask, min_depth, max_depth, depth, current_uv, delta_uv, current_depth, current_layer_depth, layer_depth);
#endif

#ifdef OUTPUT_DEPTH
	//if output depth is enabled, save the current depth in the out variable
	depth_value = current_depth;
#endif

#ifdef SELFSHADOWS_SOFT
	//if self shadows are enabled, setup shadows variables
	float2 shadow_uv = current_uv;
	//since we're raytracing back from the found point up to the light, compute the number of layers we will have to cross before reaching the surface
	layerN = round(current_layer_depth * layerN);
	//compute shadow_delta_uv in a similar fashon as delta_uv before
	float2 shadow_delta_uv = ((ts_light_ray.xy / ts_light_ray.z) * get_depth(min_depth, max_depth, depth)) / 256.0;

	//compute soft self shadows attenuation (see raytrace_loop_shadows before for more info)
	//if _PTHQ_CONTACT_REFINEMENT is on, reset layer_depth to it's original value
	shadow_attenuation = raytrace_loop_shadows(layerN, depth_texture, depth_texture_channel_mask, dd, min_depth, max_depth, depth, shadow_uv, shadow_delta_uv, current_depth, current_layer_depth,
	#if _PTHQ_CONTACT_REFINEMENT && !(_PTHQ_BINARY_SEARCH)
		layer_depth *= layerN
	#else
		layer_depth
	#endif
		);
#endif

#if _PTHQ_OCCLUSION_MAPPING && !(_PTHQ_BINARY_SEARCH)
	//if _PTHQ_OCCLUSION_MAPPING is on, lerp between the previous uv and the current uv by computing a weight.
	//see https://catlikecoding.com/unity/tutorials/rendering/part-20/ for more info
	return lerp(current_uv + delta_uv, current_uv, get_intersection_interpolation(dd, current_depth, current_layer_depth, layer_depth, current_uv, delta_uv, depth_texture, depth_texture_channel_mask, min_depth, max_depth, depth));
#else
	//else, just return the computed current_uv
	return current_uv;
#endif
}
#endif