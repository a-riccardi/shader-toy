Shader "ShaderToy/DeformableSnow/DeformableSnow"
{
	Properties
	{
		[Header(Snow)]
		_SnowColor ("Soft Snow Color", Color) = (1,1,1,1)
		_SnowTilingF("Tiling Factor", Range(0.01, 10)) = 0.2
		[NoScaleOffset]_HSnowMixMap ("Specular (R) Roughness (G) Height (B)", 2D) = "bump" {}
		[NoScaleOffset]_HSnowNormalMap ("Soft Snow Normal", 2D) = "bump" {}
		[NoScaleOffset]_NoiseTex("Noise Texture", 2D) = "bump" {}
		_SnowSpecularF("Specular Intensity", Range(0.0, 10.0)) = 0.235
		_SnowRoughnessF("Roughness Intensity", Range(0.0, 2.0)) = 0.05
		_SnowNormalF("Normal Intensity", Range(0.0, 10.0)) = 1.0
		_TsnowGradientF("Trampled Snow Height", Range(0.0, 1.0)) = 0.5
		[Space(20)]
		_EmissiveF("Icy Cristals Emissive Factor", Range(1.0, 24.0)) = 8
		_EmissiveFallofF("Icy Cristals Fallof Range", Range(0.0, 1.0)) = 0.3
		[Space(20)]
		[Header(Roof)]
		_RoofTex ("Roof Albedo (RGB), Emissive (A)", 2D) = "white" {}
		[NoScaleOffset]_RoofNormal("Roof Normal", 2D) = "bump" {}
		[NoScaleOffset]_RoofMixmap("Roughness(R) Specular(A) AO(B)", 2D) = "bump" {}
		_RoofRoughnessF("Roughness Intensity", Range(0.0, 2.0)) = 1.0
		_RoofNormalF("Normal Intensity", Range(0.0, 10.0)) = 1.0
		_RoofAOF("Ambient Occlusion Intensity", Range(0, 2)) = 1.0
		_RoofEmissiveF("Emissive Intensity", Range(0.0, 100.0)) = 1.0
		_RoofEmissiveColor("Emissive Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_SnowRoofBlendSoftnessF("Snow to Roof Blend Softness", Range(0.0, 1.0)) = 0.5
		[Space(20)]
		[Header(Displacement)]
		_Displacement ("Displacement", Range(0.0, 1.0)) = 0.3
		_NoiseOffset("Noise Offset", Range(0.1, 10)) = 1
		_SnowBumpinessF("Snow Bumpiness", Range(0,1)) = 0.1
		_SnowBumpTileF("Bump Tile Factor", Range(0.1, 10)) = 3
		_TessellationF ("Tassellation Factor", Range(0.0, 100.0)) = 5
		_TessellationMin ("Tessellation Minimum Distance", Float) = 5
		_TessellationMax ("Tessellation Maximum Distance", Float) = 50	
		
		[HideInInspector] _HeightTex("_HeightTex", 2D) = "white" {}
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		
		CGPROGRAM

		#pragma surface surf StandardSpecular addshadow vertex:vert tessellate:distance_based_tessellation
		#pragma target 5.0
		#pragma multi_compile ______ FALLBACK_ARGB
		#include "../../../Shaders/SamplerTools.cginc"
		#include "Tessellation.cginc"
		#include "UnityStandardUtils.cginc"
		#define OFFSET_CONST 0.0025

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
			float2 uv_RoofTex;
			float2 uv_HeightTex;
			float3 viewDir;
			float3 worldPos;
			float3 worldNormal;
			float3 objSpaceNormal;
			INTERNAL_DATA
		};

		uniform fixed4 _SnowColor;
		uniform float _SnowTilingF;

		uniform sampler2D _HSnowMixMap; // .r -> specular | .g -> roughness | .b -> height
		uniform sampler2D _HSnowNormalMap;
		uniform sampler2D _NoiseTex;
		uniform float _SnowSpecularF;
		uniform float _SnowRoughnessF;
		uniform float _SnowNormalF;
		uniform float _TsnowGradientF;
		uniform float _EmissiveF;
		uniform float _EmissiveFallofF;

		uniform sampler2D _RoofTex;
		uniform sampler2D _RoofNormal;
		uniform sampler2D _RoofMixMap;
		uniform float _RoofRoughnessF;
		uniform float _RoofNormalF;
		uniform float _RoofAOF;
		uniform float _RoofEmissiveF;
		uniform fixed4 _RoofEmissiveColor;
		uniform float _SnowRoofBlendSoftnessF;

		uniform float _Displacement;
		uniform float _NoiseOffset;
		uniform float _SnowBumpinessF;
		uniform float _SnowBumpTileF;
		uniform float _TessellationF;
		uniform float _TessellationMin;
		uniform float _TessellationMax;

		uniform sampler2D _HeightTex;

		//TODO: modulate tessellation upon _HeightTex?
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
			
			float2 worldSpaceUV = v0.xz * _SnowTilingF;
			fixed4 h_mixmap = texture_tiler_lod(_HSnowMixMap, worldSpaceUV, _NoiseOffset, _NoiseTex, 0);
			float min_snow_height = clamp01(remap_01(h_mixmap.b, 0.0, 1.0 - _TsnowGradientF)) * 0.15;

			//account for minimum desired show height
			d += min_snow_height * (1.0 - d);
			
			//get the correct height for the three point needed for analytical normal reconstruction
			v0.y += d.x * lerp(0.5, tex2Dlod(_HSnowMixMap, float4(v.texcoord.xy * _SnowBumpTileF, 0, 0)).b, _SnowBumpinessF) * _Displacement;
			v1.y += d.y * lerp(0.5, tex2Dlod(_HSnowMixMap, float4((v.texcoord.x + OFFSET_CONST) * _SnowBumpTileF, v.texcoord.y * _SnowBumpTileF, 0, 0)).b, _SnowBumpinessF) * _Displacement;
			v2.y += d.z * lerp(0.5, tex2Dlod(_HSnowMixMap, float4(v.texcoord.x * _SnowBumpTileF, (v.texcoord.y + OFFSET_CONST) * _SnowBumpTileF, 0, 0)).b, _SnowBumpinessF) * _Displacement;

			//compute the world space normal as the cross product of the Z and the X vector
			float3 wsn = normalize(cross((v2 - v0).xyz, (v1 - v0).xyz));
			//accounting for roof rotation (-90° on x axis)
			wsn.z *= -1.0;

			//normalize and store the computed object space normal for this vertex
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
			//compute world space uv as the vertex world position modulated by the _SnowTilingF factor
			float2 worldSpaceUV = IN.worldPos.xz * _SnowTilingF;

			//sample the mixmap
			fixed4 h_mixmap = texture_tiler(_HSnowMixMap, worldSpaceUV, _NoiseOffset, _NoiseTex);
			
			float min_snow_height = clamp01(remap01(h_mixmap.b, 0.0, 1.0 - _TsnowGradientF)); 

			float3 distance_worldspace = abs(IN.worldPos - _WorldSpaceCameraPos); 

			//compute snow material parameters
			fixed3 snow_albedo = _SnowColor.rgb;
			fixed3 snow_specular = h_mixmap.r * _SnowColor.rgb * _SnowSpecularF;
			half3 snow_normal = UnpackNormal(texture_tiler(_HSnowNormalMap, worldSpaceUV, _NoiseOffset, _NoiseTex));
			snow_normal.rg *= _SnowNormalF;
			fixed3 snow_emissive = fixed3(h_mixmap.g, h_mixmap.g, h_mixmap.g) * clamp01(abs(1.0 - dot(IN.viewDir, o.Normal)) * clamp01(dot(distance_worldspace, distance_worldspace) / lerp(5, 500, _EmissiveFallofF))) * _EmissiveF * step(0.05, amount);
			float snow_smoothness = (1.0 - h_mixmap.g) * _SnowRoughnessF;

			//sample roof data
			fixed4 roof_baseColor = tex2D(_RoofTex, IN.uv_RoofTex); 
			fixed3 roof_normalColor = UnpackNormal(tex2D(_RoofNormal, IN.uv_RoofTex));
			fixed4 roof_mixColor = tex2D(_RoofMixMap, IN.uv_RoofTex);

			//compute roof material parameters blending with trampled snow
			fixed3 roof_albedo = lerp(roof_baseColor.rgb, snow_albedo, min_snow_height);
			fixed3 roof_specular = lerp(roof_mixColor.g * _RoofRoughnessF, snow_specular, min_snow_height);
			half3 roof_normal = lerp(float3(roof_normalColor.rg * _RoofNormalF, 1.0), snow_normal, min_snow_height);
			fixed3 roof_emissive = roof_baseColor.a * _RoofEmissiveColor * _RoofEmissiveF;
			float roof_smoothness = lerp(((1.0 - roof_mixColor.r) * _RoofRoughnessF), snow_smoothness, min_snow_height);
			float roof_ao = roof_mixColor.b * (2.0 - _RoofAOF);

			//get blend factor between snow and roof
			float blend_amount = clamp01(remap01(amount, 0.0,_SnowRoofBlendSoftnessF));

			//fill in material structure lerping between different material properties based on blend_amount
			o.Albedo = lerp(roof_albedo, snow_albedo, blend_amount);
			o.Specular = lerp(roof_specular, snow_specular, blend_amount);
			o.Normal = lerp(roof_normal, snow_normal, blend_amount);
			o.Emission = lerp(roof_emissive, snow_emissive, blend_amount);
			o.Smoothness = (1.0 - lerp(roof_smoothness, snow_smoothness, blend_amount));
			o.Occlusion = lerp(roof_ao, amount, blend_amount);
			o.Alpha = 1.0;
		}
		ENDCG
	} 
	FallBack "Diffuse"
}