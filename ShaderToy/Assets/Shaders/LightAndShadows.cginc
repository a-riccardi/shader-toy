#if !defined(LIGHT_AND_SHADOWS_INCLUDED)
#define LIGHT_AND_SHADOWS_INCLUDED

#include "Lighting.cginc"
#include "AutoLight.cginc"

float get_light_attenuation(float3 worldPos) {
#if defined(POINT)
	{
		unityShadowCoord3 lightCoord = mul(unity_WorldToLight, float4(worldPos, 1.0)).xyz;
		float result = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
		return result;
	}
#elif defined(SPOT)
	{
		unityShadowCoord4 lightCoord = mul(unity_WorldToLight, float4(worldPos, 1.0));
		float result = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz);
		return result;
	}
#elif defined(DIRECTIONAL)
	{
		return 1.0;
	}
#elif defined(POINT_COOKIE)
	{
		unityShadowCoord3 lightCoord = mul(unity_WorldToLight, float4(worldPos, 1.0)).xyz;
		float result = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL * texCube(_LightTexture0, lightCoord).w;
		return result;
	}
#elif defined(DIRECTIONAL_COOKIE)
	{
		unityShadowCoord2 lightCoord = mul(unity_WorldToLight, float4(worldPos, 1.0)).xy;
		float result = tex2D(_LightTexture0, lightCoord).w;
		return result;
	}
#else
	return 1.0;
#endif
}

float get_shadow_attenuation(float3 worldPos) {
#if defined(SHADOWS_CUBE)
	{
		unityShadowCoord3 shadowCoord = worldPos - _LightPositionRange.xyz;
		float result = UnitySampleShadowmap(shadowCoord);
		return result;
	}
#elif defined(SHADOWS_SCREEN)
	{
#ifdef UNITY_NO_SCREENSPACE_SHADOWS
		unityShadowCoord4 shadowCoord = mul(unity_WorldToShadow[0], worldPos);
#else
		unityShadowCoord4 shadowCoord = ComputeScreenPos(mul(UNITY_MATRIX_VP, float4(worldPos, 1.0)));
#endif
		float result = unitySampleShadow(shadowCoord);
		return result;
	}
#elif defined(SHADOWS_DEPTH) && defined(SPOT)
	{
		unityShadowCoord4 shadowCoord = mul(unity_WorldToShadow[0], float4(worldPos, 1.0));
		float result = UnitySampleShadowmap(shadowCoord);
		return result;
	}
#else
	return 1.0;
#endif  
}

#include "UnityCG.cginc"

//#ifndef CUSTOM_DEPTH_TEXTURE
	#define GET_DEPTH_TEXTURE(tex) sampler2D tex;
//#endif

struct appdata_shadow
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
};

struct v2f_shadow
{
	float4 pos : SV_POSITION;
	float4 vertex : NORMAL;
	float2 uv : TEXCOORD0;
	float3 eye_ray: CUSTOMDATA0;
	float3 world_pos: CUSTOMDATA1;
};
/*
struct depth_frag_out
{
	float depth : SV_Depth;
};
*/
/*
float compute_frag_depth(float3 world_pos) {
	float4 depth_vec = mul(UNITY_MATRIX_VP, float4(world_pos, 1.0));
	return depth_vec.z / depth_vec.w;
}
*/
float compute_frag_depth(float clip_space_z)
{
	return (1.0 / clip_space_z - 1.0 / _ProjectionParams.y) / (_ProjectionParams.w - 1.0 / _ProjectionParams.y);
}
//
//float compute_frag_depth(float4 obj_pos) {
//	return -UnityObjectToViewPos(obj_pos).z;  //-(UnityObjectToViewPos(obj_pos).z * _ProjectionParams.w); // 
//}

float3 get_ray_to_camera(float3 worldPos) {
	if (unity_OrthoParams.w > 0) {
		return -UNITY_MATRIX_V[2].xyz;;
	}
	else
		return worldPos - _WorldSpaceCameraPos;
}

float3 get_ray_to_light(float3 worldPos) {
	float3 result;
	if (_WorldSpaceLightPos0.w > 0) {
		result = worldPos.xyz - _WorldSpaceLightPos0.xyz;
	}
	else {
#if defined(DIRECTIONAL)
		if ((UNITY_MATRIX_P[3].x == 0.0)
			&& (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0)) {
			result = -UNITY_MATRIX_V[2].xyz;
		}
		else {
			result = get_ray_to_camera(worldPos);
		}
#else
		result = get_ray_to_camera(worldPos);
#endif
	}
	return result;
}

float3 get_view_ray(float3 worldPos) {
//#if defined(RAYCAST_WITHIN_SHADOWCASTER_PASS)
	return get_ray_to_light(worldPos);
//#else
	//return get_ray_to_camera(worldPos);
//#endif
}

v2f_shadow vert_shadows(appdata_shadow v)
{
	TANGENT_SPACE_ROTATION;

	v2f_shadow o;
	o.vertex = UnityObjectToClipPos(v.vertex);
	o.uv = v.uv;
	o.world_pos = mul(unity_ObjectToWorld, v.vertex);
	o.eye_ray = mul(rotation, mul(unity_WorldToObject, get_view_ray(o.world_pos)));
	return o;
}
/*/
float frag_shadows(v2f i) : SV_Depth
{
	i.eye_ray = normalize(i.eye_ray);

	float4 dd = float4(0, 0, 0, 0);
	dd.xy = ddx(i.uv);
	dd.zw = ddy(i.uv);

	float layerN = 1.0;

#ifdef CONTACT_REFINEMENT
	layerN = 64.0;
#else
	layerN = 128.0;
#endif

	float depth_value = 0.0;

	sampler2D _DepthMap = GET_DEPTH_TEXTURE(_MainTex);

#ifdef CONTACT_REFINEMENT
	float2 parallax_uv = get_contact_refinement_parallax_offset_uv(layerN, i.eye_ray, float3(0,0,1), i.uv, _DepthMap, float4(0, 0, 0, 1), 0.0, _MaxDepth, _Depth, depth_value, shadow_attenuation);
#else
	float2 parallax_uv = get_standard_parallax_offset_uv(layerN, i.eye_ray, float3(0, 0, 1), i.uv, _DepthMap, float4(0, 0, 0, 1), 0.0, _MaxDepth, _Depth*0.65, depth_value, shadow_attenuation);
#endif

	return float4(i.world_pos.x, i.world_pos.y - depth_value, i.world_pos.z, 1);

	*//*
	float3 worldPos = i.world_pos + eye_ray * t;

	ContactInfo sphereContact = calculateSphereContact(worldPos, spherePos, sphereRadius);

	float4 col = 0.0;
#ifdef RAYCAST_NO_TEXTURE
	float4 baseColor = 1.0;

#ifdef RAYCAST_USE_AMBIENT
	float4 ambColor = UNITY_LIGHTMODEL_AMBIENT;
	col = col + baseColor * ambColor;
#endif
#ifdef RAYCAST_USE_LIGHT
	float3 lightDir = _WorldSpaceLightPos0.xyz - worldPos * _WorldSpaceLightPos0.w;
	lightDir = normalize(lightDir);

	float shadowAtten = get_shadow_attenuation(worldPos);
	float lightAtten = get_light_attenuation(worldPos);
	float lightDot = dot(lightDir, sphereContact.n);
	float lightFactor = max(0.0, lightDot);
	col = col + baseColor * lightFactor * _LightColor0 * shadowAtten * lightAtten;
#ifdef RAYCAST_USE_SPECULAR
	float3 reflectedLight = reflect(lightDir, sphereContact.n);
	float specFactor = max(dot(reflectedLight, eye_ray), 0.0);
	specFactor = pow(specFactor, _SpecularPower);
	col = col + _LightColor0 * lightAtten * _SpecularColor * specFactor * shadowAtten;
#endif
#endif
#ifdef RAYCAST_USE_UNLIT_TEXTURE
	col = baseColor;
#endif

	return computeOutputFragment(worldPos, col);
	*/
/*}*/


#endif