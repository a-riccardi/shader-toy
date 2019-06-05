Shader "ShaderToy/DeformableSnow/DeformableSnow"
{
	Properties
	{
		_Color ("Soft Snow Color", Color) = (1,1,1,1)
		_TilingF("Tiling Factor", Range(0.01, 10)) = 0.2 
		_HSnowTex ("Soft Snow Mixmap", 2D) = "white" {}
		_HSnowNormalTex ("Soft Snow Normal", 2D) = "bump" {}
		_RoofTex ("Roof Albedo (RGB), Roughness (A)", 2D) = "white" {}
		_RoofNormal("_RoofNormal", 2D) = "gray" {}
		_RoofSpecularF("_RoofSpecularF", Range(0,1)) = 0.5

		_SpecularF ("Specular Factor", Range(0.0, 1.0)) = 0.235
		_SmoothnessF ("Smoothness Factor", Range(0.0, 1.0)) = 0.05

		_EmissiveF ("Icy Cristals Emissive Factor", Range(1.0, 24.0)) = 8
		_EmissiveFallofF ("Icy Cristals Fallof Range", Range(0.0, 1.0)) = 0.3

		_SSSColor ("SSS Color", Color) = (0.5, 0.7, 0.7, 1.0)
		_SSScaleF ("SSS Scale Factor", Range(0.5, 5)) = 3

		_TsnowCompactnessF ("Trampled Snow Compactness Factor", Range(0.0, 3.0)) = 1.0
		_TsnowMinHeight ("Trampled Snow Min Height", Range(0.0, 1.0)) = 0.5 //Range(0.001, 0.2)) = 0.1
		_TsnowGradientF ("Trampled Snow Gradient", Range(1, 12)) = 6

		_Displacement ("Displacement", Range(0.0, 1.0)) = 0.3
		_TessellationF ("Tassellation Factor", Range(0.0, 100.0)) = 5
		_TessellationMin ("Tessellation Minimum Distance", Float) = 5
		_TessellationMax ("Tessellation Maximum Distance", Float) = 50	

		_CrunchedSpecularF("_CrunchedSpecularF", Range(0,1)) = 0.2
		_NoiseScale("_NoiseScale", Range(0.1, 10)) = 1
		_NoiseTex("NoiseTex", 2D) = "bump" {}
		_SnowBumpinessF("_SnowBumpinessF", Range(0,1)) = 0.1
		_SnowBumpTileF("_SnowBumpTileF", Range(0.1, 10)) = 3
		_CrunchedRoughnessF("_CrunchedRoughnessF", Range(0.0, 1.0)) = 0.9
		[HideInInspector] _HeightTex("_HeightTex", 2D) = "white" {} // "white" {}
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		
		CGPROGRAM

		#pragma surface surf StandardSpecular addshadow vertex:vert tessellate:distance_based_tessellation
		#pragma target 5.0
		#pragma multi_compile ______ FALLBACK_ARGB
		#include "../../Shaders/SamplerTools.cginc"
		#include "Tessellation.cginc"
		#include "UnityStandardUtils.cginc"
		#define OFFSET_CONST 0.005

		struct appdata
		{
			float4 vertex : POSITION;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			float2 texcoord : TEXCOORD0;
			float2 texcoord1 : TEXCOORD1;
			float2 texcoord2 : TEXCOORD2; //for dynamic GI and meta pass generation (Unity)
		};

		struct Input
		{
			float2 uv_HSnowTex;
			float2 uv_HeightTex;
			float3 viewDir;
			float3 worldPos;
			float3 worldNormal;
			float3 objSpaceNormal;
			//float2 uv_Lightmap;
			INTERNAL_DATA
		};

		fixed4 _Color;

		sampler2D _HeightTex;
		sampler2D _HSnowTex; // .r -> specular | .g -> roughness | .b -> displacement
		sampler2D _HSnowNormalTex;
		sampler2D _RoofTex;
		sampler2D _RoofNormal;
		float _RoofSpecularF;

		float _TilingF;

		float _SpecularF;
		float _SmoothnessF;

		float _EmissiveF;
		float _EmissiveFallofF;

		fixed4 _SSSColor;
		float _SSScaleF;

		float _TsnowCompactnessF;
		float _TsnowMinHeight;
		float _TsnowGradientF;

		float _Displacement;
		float _TessellationF;
		float _Smoothness;

		float _TessellationMin;
		float _TessellationMax;

		float _CrunchedSpecularF;
		float _NoiseScale;
		sampler2D _NoiseTex;
		float _SnowBumpinessF;
		float _SnowBumpTileF;
		float _CrunchedRoughnessF;
		//encapsulate UnityDistanceBasedTess with our parameter; TODO: modulate tessellation upon _HeightTex?
		float4 distance_based_tessellation(appdata v0, appdata v1, appdata v2)
		{
			return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, _TessellationMin, _TessellationMax, _TessellationF);
		}

		//adapted UnpackNormalDX5nm function to return normal in [0..1] range
		inline fixed3 UnpackNormalDXT5nmObjSpace(fixed4 packednormal)
		{
			fixed3 normal;
			normal.xy = packednormal.wy * 2 - 1;
			normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
			return normal* 0.5 + 0.5;
		}

		//adapted UpackNormal function to return normal in [0..1] range
		inline fixed3 UnpackNormalObjSpace(fixed4 packednormal)
		{
		#if defined(UNITY_NO_DXT5nm)
			return packednormal.xyz;
		#else
			return UnpackNormalDXT5nmObjSpace(packednormal);
		#endif
		}

		void vert(inout appdata v)
		{
			float3 d;
		
#ifdef FALLBACK_ARGB
			//if we're encoding the float in ARGB texture, sample with a slight offset along the +X/+Z direction and decode it; modulate by _Displacement
			d.x = DecodeFloatRGBA(tex2Dlod(_HeightTex, float4(v.texcoord.xy, 0, 0))).r;
			d.y = DecodeFloatRGBA(tex2Dlod(_HeightTex, float4(v.texcoord.x + OFFSET_CONST, v.texcoord.y, 0, 0))).r;
			d.z = DecodeFloatRGBA(tex2Dlod(_HeightTex, float4(v.texcoord.x, v.texcoord.y + OFFSET_CONST, 0, 0))).r;
#else
			//if we're not encoding the float in ARGB texture, just sample it sample with a slight offset along the +X/+Z direction, modulate by _Displacement
			d.x = tex2Dlod(_HeightTex, float4(v.texcoord.xy, 0, 0)).r;
			d.y = tex2Dlod(_HeightTex, float4(v.texcoord.x + OFFSET_CONST, v.texcoord.y, 0, 0)).r;
			d.z = tex2Dlod(_HeightTex, float4(v.texcoord.x, v.texcoord.y + OFFSET_CONST, 0, 0)).r;
#endif

			//v0 is the current vertex, v1 and v2 are fake neighbour vertices used to compute the normal
			float4 v0 = mul(unity_ObjectToWorld, v.vertex);
			float4 v1 = v0 + float4(OFFSET_CONST, 0, 0, 0);
			float4 v2 = v0 + float4(0, 0, OFFSET_CONST, 0);
			
			float2 worldSpaceUV = v0.xz * _TilingF;
			fixed4 h_mixmap = texture_tiler_lod(_HSnowTex, worldSpaceUV, _NoiseScale, _NoiseTex, 0);
			//float min_snow_height = clamp01(cheap_contrast(_TsnowMinHeight - h_mixmap.b, _TsnowGradientF)) * 0.5;
			float min_snow_height = clamp01(remap01(h_mixmap.b, 0.0, _TsnowGradientF / 12)) * 0.15;

			d += min_snow_height * (1.0 - d);
			
			//TODO fix
			v0.y += d.x * lerp(0.5, tex2Dlod(_HSnowTex, float4(v.texcoord.xy * _SnowBumpTileF, 0, 0)).b, _SnowBumpinessF) * _Displacement;
			v1.y += d.y * lerp(0.5, tex2Dlod(_HSnowTex, float4((v.texcoord.x + OFFSET_CONST) * _SnowBumpTileF, v.texcoord.y * _SnowBumpTileF, 0, 0)).b, _SnowBumpinessF) * _Displacement;
			v2.y += d.z * lerp(0.5, tex2Dlod(_HSnowTex, float4(v.texcoord.x * _SnowBumpTileF, (v.texcoord.y + OFFSET_CONST) * _SnowBumpTileF, 0, 0)).b, _SnowBumpinessF) * _Displacement;

			//compute the world space normal as the cross product of the Z and the X vector
			float3 wsn = normalize(cross((v2 - v0).xyz, (v1 - v0).xyz));

			/*float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			float3 tangentWorld = UnityObjectToWorldDir(v.tangent.xyz);
			float3 bitangentWorld = cross(normalWorld, tangentWorld);

			float3x3 local2WorldTranspose = float3x3(
				tangentWorld,
				bitangentWorld,
				normalWorld
				);
*/
			//normalize and store the computed object space normal for this vertex
			//v.normal = mul(local2WorldTranspose, wsn);
			v.normal = mul((float3x3)unity_WorldToObject, wsn);
			//transform the position of the offsetted vertex back to object space and store it
			v.vertex = mul(unity_WorldToObject, v0);
		}

		void surf (Input IN, inout SurfaceOutputStandardSpecular o)
		{
			float amount;

		#ifdef FALLBACK_ARGB
			//if we're encoding the height in an ARGB texture, sample and decode the value
			amount = DecodeFloatRGBA(tex2D(_HeightTex, IN.uv_HeightTex));
		#else
			//if we're not encoding, just sample the texture
			amount = tex2D(_HeightTex, IN.uv_HeightTex).r;
		#endif
			//compute world space uv as the vertex world position modulated by the _TilingF factor
			float2 worldSpaceUV = IN.worldPos.xz * _TilingF;

			//sample the mixmap
			fixed4 h_mixmap = texture_tiler(_HSnowTex, worldSpaceUV, _NoiseScale, _NoiseTex);
			
			float min_snow_height = clamp01(remap01(h_mixmap.b, 0.0, _TsnowGradientF/12)); // clamp01(remap01(_TsnowMinHeight - h_mixmap.b, 0.0, _TsnowGradientF / 12));

			float3 distance_worldspace = abs(IN.worldPos - _WorldSpaceCameraPos); 
			//fixed3 ambient_light = ShadeSHPerPixel(IN.worldNormal, fixed3(0,0,0), IN.worldPos);

			fixed3 snow_albedo = _Color.rgb; // lerp(_Color.rgb, ambient_light * 50, 1.0 - amount);
			fixed3 snow_specular = h_mixmap.r * _Color.rgb * _SpecularF;
			half3 snow_normal = UnpackNormal(texture_tiler(_HSnowNormalTex, worldSpaceUV, _NoiseScale, _NoiseTex));
			fixed3 snow_emissive = fixed3(h_mixmap.g, h_mixmap.g, h_mixmap.g) * clamp01(abs(1.0 - dot(IN.viewDir, o.Normal)) * clamp01(dot(distance_worldspace, distance_worldspace) / lerp(5, 500, _EmissiveFallofF))) * _EmissiveF * 1/*00*/ * step(0.05, amount);
			float snow_smoothness = h_mixmap.g;

			fixed3 roof_albedo = lerp(tex2D(_RoofTex, worldSpaceUV).rgb, _Color.rgb , min_snow_height);
			fixed3 roof_specular = lerp(tex2D(_RoofTex, worldSpaceUV).rgb, h_mixmap.r * _Color.rgb, min_snow_height);
			half3 roof_normal = lerp(UnpackNormal(tex2D(_RoofNormal, worldSpaceUV)), snow_normal, min_snow_height);
			fixed3 roof_emissive = fixed3(0.0 ,0.0, 0.0);
			float roof_smoothness = lerp((tex2D(_RoofTex, worldSpaceUV).a * _RoofSpecularF * 2), snow_smoothness, min_snow_height);
			float roof_occlusion = 1.0;

			float blend_amount = clamp01(amount * 2.0);

			o.Albedo = lerp(roof_albedo, snow_albedo, blend_amount);
			o.Specular = lerp(roof_specular, snow_specular, blend_amount);
			o.Normal = lerp(roof_normal, snow_normal, blend_amount);
			o.Emission = lerp(float3(0, 0, 0), snow_emissive, blend_amount);
			o.Smoothness = (1.0 - lerp(roof_smoothness, snow_smoothness, blend_amount)) * _SmoothnessF;
			o.Occlusion = 1.0;
			o.Alpha = 1.0;
		}
		ENDCG
	} 
	FallBack "Diffuse"
}