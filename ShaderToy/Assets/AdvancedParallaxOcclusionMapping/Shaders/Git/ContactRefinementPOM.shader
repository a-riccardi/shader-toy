﻿Shader "ShaderToy/AdvancedPOM/ContactRefinementPOM" {
	Properties {
		_TintColor ("Tint Color", Color) = (.5, .5, .5, .5)
		_BaseColorMap ("Base Color", 2D) = "white" {}
		_NormalMap("Normal", 2D) = "bump" {}
		_MixMap("Roughness(R) Height(G) AO (B) Metalness (A)", 2D) = "bump" {}
		_RoughnessF ("Roughness Intensity", Range(0,2)) = 1.0
		_NormalF ("Normal Intensity", Range(0,10)) = 1.0
		_AOF ("Ambient Occlusion Intensity", Range(0, 2)) = 1.0
		[Toggle(METALLIC)]
		_Metallic("Use Metalness map?", Float) = 0
		[Toggle(CONTACT_REFINEMENT)]
		_CRPOM("Enable Contact Refinement POM?", Float) = 0
		[Toggle(INTERSECTION_LINEAR_INTERPOLATION)]
		_ILI("Enable Intersection Linear Interpolation?", Float) = 0
		[Toggle(SELFSHADOWS_SOFT)]
		_SShadowsSoft("Enable Soft Self-Shadowing?", Float) = 0
		_SSPow("Soft Shadows Amount", Range(0.0, 15.0)) = 1.0
		[KeywordEnum(Low, Medium, High, Ultra)]
		_Quality("Parallax Quality", Float) = 0
		[Toggle(DEPTH_MAP)]
		_DepthMap("Use Heightmap as Depthmap?", Float) = 0
		[Toggle(OUTPUT_DEPTH)]
		_OutputDepth("Output Depth in BaseColor? (for debug purposes)", Float) = 0
		_Depth("Depth Scale", Range(0.0, 1.0)) = 0.5
		_MaxDepth("Max Depth Value", Float) = 1.0
		//_HeightMask("Mixmap Height Channel", Vector)  = (0.0, 1.0, 0.0 ,0.0)
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 100

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows vertex:vert
		#pragma target 3.5
		#pragma shader_feature DEPTH_MAP
		#pragma shader_feature METALLIC
		#pragma shader_feature INTERSECTION_LINEAR_INTERPOLATION
		#pragma shader_feature CONTACT_REFINEMENT
		#pragma shader_feature SELFSHADOWS_SOFT
		#pragma shader_feature OUTPUT_DEPTH
		#pragma multi_compile _QUALITY_ULTRA _QUALITY_HIGH _QUALITY_MEDIUM _QUALITY_LOW

		#include "UnityCG.cginc"
		#include "AutoLight.cginc"
		#include "../../../Shaders/ParallaxOcclusionMapping.cginc"
		#include "UnityShadowLibrary.cginc"

		#ifdef _QUALITY_ULTRA
		#define CR_LAYER (64.0)
		#define STR_LAYER (128.0)
		#elif  _QUALITY_HIGH
		#define CR_LAYER (32.0)
		#define STR_LAYER (64.0)
		#elif _QUALITY_MEDIUM
		#define CR_LAYER (16.0)
		#define STR_LAYER (32.0)
		#elif _QUALITY_LOW
		#define CR_LAYER (8.0)
		#define STR_LAYER (16.0)
		#else
		#define CR_LAYER (10.0)
		#define STR_LAYER (20.0)
		#endif

		#define HEIGHT_MASK float4(0.0, 1.0, 0.0, 0.0)

		struct Input
		{
			float2 uv_BaseColorMap;
			float3 viewDir;
			float3 worldPos;
			float3 worldToTangent0;
			float3 worldToTangent1;
			float3 worldToTangent2;
		};

		//UNITY_DECLARE_SHADOWMAP(_ShadowMapTex);

		sampler2D _BaseColorMap;
		sampler2D _NormalMap;
		sampler2D _MixMap;

		half _RoughnessF;
		half _NormalF;
		half _AOF;
		half _Metallic;
		float _DepthMap;
		float _CRPOM;
		float _ILI;
		float _SShadowsSoft;
		float _SSPow;
		float _Depth;
		float _MaxDepth;
		float _Quality;
		float4 _HeightMask;

		fixed4 _TintColor;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		//UNITY_INSTANCING_BUFFER_START(Props)
			// put more per-instance properties here
		//UNITY_INSTANCING_BUFFER_END(Props)

		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);

			// really shouldn't have to do this, but looks like surface shaders are bugged
			// and aren't passing the world normal to the surface shader with using:
			// struct Input { float3 worldNormal; }
			// luckily we have free float3 so we don't need another interpolator
			float3 worldNormal = UnityObjectToWorldNormal(v.normal);

			TANGENT_SPACE_ROTATION;

			// calculate the full world to tangent matrix
			float3x3 worldToTangent = mul(rotation, (float3x3)unity_WorldToObject);
			o.worldToTangent0 = worldToTangent[0];
			o.worldToTangent1 = worldToTangent[1];
			o.worldToTangent2 = worldToTangent[2];
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			float4 dd = float4(ddx(IN.uv_BaseColorMap), ddy(IN.uv_BaseColorMap));
			float layerN = 1.0;

#ifdef CONTACT_REFINEMENT
			layerN = CR_LAYER;
#else
			layerN = STR_LAYER;
			_Depth *= 0.65;
#endif
			layerN = ceil(lerp(layerN * 2.0, layerN, abs(dot(float3(0.0, 0.0, 1.0), IN.viewDir))));

#ifdef SELFSHADOWS_SOFT
			float3 light_ray = normalize(mul(float3x3(IN.worldToTangent0, IN.worldToTangent1, IN.worldToTangent2), _WorldSpaceLightPos0.xyz));
			float self_shadow_attenuation = 1.0;
#endif
#ifdef OUTPUT_DEPTH
			float depth_value = 0.0;
#endif
			float2 parallax_uv = get_parallax_offset_uv(dd, layerN, IN.viewDir, IN.uv_BaseColorMap, _MixMap, HEIGHT_MASK, 0.0, _MaxDepth, _Depth
#ifdef SELFSHADOWS_SOFT
				, light_ray, self_shadow_attenuation
#endif
#ifdef OUTPUT_DEPTH
				, depth_value
#endif
		);

			fixed4 baseColor = tex2D(_BaseColorMap, parallax_uv) * _TintColor * 2.0;
			fixed3 normalColor = UnpackNormal(tex2D(_NormalMap, parallax_uv));
			fixed4 mixColor = tex2D(_MixMap, parallax_uv);

#ifdef SELFSHADOWS_SOFT			
			self_shadow_attenuation = pow(self_shadow_attenuation, _SSPow);
			
			o.Albedo = baseColor.rgb * self_shadow_attenuation;
#elif OUTPUT_DEPTH
			o.Albedo = float3(depth_value, depth_value, depth_value);
#else
			o.Albedo = baseColor.rgb;
#endif
			o.Normal = fixed3(normalColor.rg * _NormalF, normalColor.b);
#ifdef METALLIC
			o.Metallic = mixColor.a;
#else
			o.Metallic = 0.0;
#endif
			o.Smoothness = 1.0 - (mixColor.r * _RoughnessF);
			o.Occlusion = mixColor.b * (2.0 - _AOF);
			o.Alpha = baseColor.a;
		}
		ENDCG
		/*
		Pass {
			Tags { "LightMode" = "ShadowCaster"	}

			CGPROGRAM

			#pragma target 3.0

			#pragma skip_variants SHADOWS_SOFT
			#pragma multi_compile_shadowcaster

			#pragma vertex vertShadowCaster_contactRefinementPOM
			#pragma fragment fragShadowCaster_contactRefinementPOM
			
			#include "UnityCG.cginc"
			#include "UnityStandardShadow.cginc"
			#include "../../Shaders/ParallaxOcclusionMapping.cginc"
			#define SAMPLE_DEPTH_VALUE_LOD

			struct VertexInput_contactRefinementPOM
			{
				float4 vertex   : POSITION;
				float3 normal   : NORMAL;
				float2 uv0      : TEXCOORD0;
				half4 tangent   : TANGENT;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutputShadowCaster_contactRefinementPOM
			{
				V2F_SHADOW_CASTER_NOPOS
				float2 tex : TEXCOORD1;
				half3 viewDirForParallax : TEXCOORD2;
			};

			sampler2D _NormalMap;
			sampler2D _MixMap;

			float _DepthMap;
			float _CRPOM;
			float _Depth;
			float _MaxDepth;
			float _Quality;

			void vertShadowCaster_contactRefinementPOM(VertexInput_contactRefinementPOM v, out float4 opos : SV_POSITION, out VertexOutputShadowCaster_contactRefinementPOM o
				#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
				, out VertexOutputStereoShadowCaster os
				#endif
			)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(os);
				#endif

				o.tex = TRANSFORM_TEX(v.uv0, _MainTex);
				float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
				float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
				o.viewDirForParallax = mul(rotation, ObjSpaceViewDir(v.vertex));

				half3 viewDirForParallax = normalize(o.viewDirForParallax);
				float2 parallax_uv = get_contact_refinement_parallax_offset_uv_lod(viewDirForParallax, o.tex.xy, _MixMap, float4(0, 1, 0, 0), 0.0, _MaxDepth, _Depth);

				//TRANSFER_SHADOW_CASTER_NOPOS(o,opos)

				float offset = sample_depth_lod(_MixMap, float4(0, 1, 0, 0), float4(parallax_uv, 0, 0)); // tex2Dlod(_MixMap, float4(o.tex.xy, 0, 0)).g * get_depth(0.0, _MaxDepth, _Depth);
				float3 normal = tex2Dlod(_NormalMap, float4(parallax_uv, 0, 0));
				opos = UnityClipSpaceShadowCasterPos(v.vertex, v.normal); // float4(v.vertex.x, v.vertex.y - offset * 0.1, v.vertex.z, v.vertex.w), normal);
				opos = UnityApplyLinearShadowBias(opos);
			}

			half4 fragShadowCaster_contactRefinementPOM(UNITY_POSITION(vpos), VertexOutputShadowCaster_contactRefinementPOM i) : SV_Target
			{
	//#if defined(UNITY_STANDARD_USE_SHADOW_UVS)
				half3 viewDirForParallax = normalize(i.viewDirForParallax);
				i.tex.xy = get_contact_refinement_parallax_offset_uv(viewDirForParallax, i.tex.xy, _MixMap, float4(0, 1, 0, 0), 0.0, _MaxDepth, _Depth);

			#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
				half alpha = _Color.a;
			#else
				half alpha = tex2D(_MainTex, i.tex.xy).a * _Color.a;
			#endif
			#if defined(_ALPHATEST_ON)
				clip (alpha - _Cutoff);
			#endif
			#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
				#if defined(_ALPHAPREMULTIPLY_ON)
					half outModifiedAlpha;
					PreMultiplyAlpha(half3(0, 0, 0), alpha, SHADOW_ONEMINUSREFLECTIVITY(i.tex), outModifiedAlpha);
					alpha = outModifiedAlpha;
				#endif
				#if defined(UNITY_STANDARD_USE_DITHER_MASK)
					// Use dither mask for alpha blended shadows, based on pixel position xy
					// and alpha level. Our dither texture is 4x4x16.
					#ifdef LOD_FADE_CROSSFADE
						#define _LOD_FADE_ON_ALPHA
						alpha *= unity_LODFade.y;
					#endif
					half alphaRef = tex3D(_DitherMaskLOD, float3(vpos.xy*0.25,alpha*0.9375)).a;
					clip (alphaRef - 0.01);
				#else
					clip (alpha - _Cutoff);
				#endif
			#endif
				//#endif // #if defined(UNITY_STANDARD_USE_SHADOW_UVS)

				#ifdef LOD_FADE_CROSSFADE
					#ifdef _LOD_FADE_ON_ALPHA
						#undef _LOD_FADE_ON_ALPHA
					#else
						UnityApplyDitherCrossFade(vpos.xy);
					#endif
				#endif

				SHADOW_CASTER_FRAGMENT(i)
			}

			ENDCG
		}
		*/
	}

	Fallback "Diffuse"
}
