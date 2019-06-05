Shader "ShaderToy/DeformableSnow/SimpleSnowShader"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_HSnowTex("Soft snow mixmap", 2D) = "white" {}
		_HSnowNormalTex("Soft snow normal", 2D) = "bump" {}

		_TilingF("Tiling Factor", Range(0.01, 30)) = 10

		_SpecularF("Specular Factor", Range(0.0, 1.0)) = 0.235
		_SmoothnessF("Smoothness Factor", Range(0.0, 1.0)) = 0.05

		_Displacement("Displacement", Range(0, 1.0)) = 0.353
		_TessellationF("Tassellation Factor", Range(0, 100)) = 5
		_TessellationMin("Tessellation Minimum Distance", Float) = 5
		_TessellationMax("Tessellation Maximum Distance", Float) = 50
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }
		//LOD 200

		CGPROGRAM

		#pragma surface surf StandardSpecular addshadow vertex:vert tessellate:distance_based_tessellation
		#pragma target 5.0
		#include "Tessellation.cginc"

		struct appdata
		{
			float4 vertex : POSITION;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			float2 texcoord : TEXCOORD0;
			float2 texcoord1 : TEXCOORD1;
			float2 texcoord2 : TEXCOORD2; //for dynamic GI and meta pass generation (Unity)
		};

		fixed4 _Color;

		sampler2D _HSnowTex; // .r -> specular | .g -> roughness | .b -> displacement
		sampler2D _HSnowNormalTex;
		sampler2D _HeightTex;

		float _TilingF;

		float _SpecularF;
		float _SmoothnessF;

		float _Displacement;
		float _TessellationF;

		float _TessellationMin;
		float _TessellationMax;

		float4 distance_based_tessellation(appdata v0, appdata v1, appdata v2)
		{
			return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, _TessellationMin, _TessellationMax, _TessellationF);
		}

		inline fixed3 UnpackNormalDXT5nmObjSpace(fixed4 packednormal)
		{
			fixed3 normal;
			normal.xy = packednormal.wy * 2 - 1;
			normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
			return normal* 0.5 + 0.5;
		}

		inline fixed3 UnpackNormalObjSpace(fixed4 packednormal)
		{
		#if defined(UNITY_NO_DXT5nm)
			return packednormal.xyz;
		#else
			return UnpackNormalDXT5nmObjSpace(packednormal);
		#endif
		}

		inline float3 ReorientNormalMap(float3 baseNormal, float3 detailNormal)
		{
			float3 t = baseNormal*float3(2, 2, 2) + float3(-1, -1, 0);
			float3 u = detailNormal*float3(-2, -2, 2) + float3(1, 1, -1);
			float3 r = normalize(t*dot(t, u) - u*t.z);
			return r;
		}

		void vert(inout appdata v)
		{
			float4 worldSpaceTexcoord = mul(unity_ObjectToWorld, v.vertex) * _TilingF;
			//v.vertex.xyz += (v.normal * (tex2Dlod(_HSnowNormalTex, float4(worldSpaceTexcoord.xz, 0, 0)))) * _Displacement;
			v.vertex.xyz += (float3(0,0,1) * (tex2Dlod(_HSnowNormalTex, float4(v.texcoord.xy, 0, 0)))) * _Displacement;
		}

		struct Input
		{
			float3 worldPos;
			float3 viewDir;
			float2 uv_HSnowTex;
			float2 uv_HeightTex;
		};

		void surf(Input IN, inout SurfaceOutputStandardSpecular o)
		{
			//fixed4 h_mixmap = tex2D(_HSnowTex, IN.worldPos.xz * _TilingF); // IN.uv_HSnowTex);
			fixed4 h_mixmap = tex2D(_HSnowTex, IN.uv_HSnowTex);
			
			float hs_smoothness = (1.0 - h_mixmap.r);

			o.Alpha = 1.0;
			//o.Normal = ReorientNormalMap(/*low frequency*/ UnpackNormalObjSpace(tex2D(_HSnowNormalTex, IN.worldPos.xz * _TilingF * 3)), /*high frequency*/ UnpackNormalObjSpace(tex2D(_HSnowNormalTex, IN.worldPos.xz * _TilingF)));
			o.Normal = ReorientNormalMap(/*low frequency*/ UnpackNormalObjSpace(tex2D(_HSnowNormalTex, IN.uv_HeightTex * 3)), /*high frequency*/ UnpackNormalObjSpace(tex2D(_HSnowNormalTex, IN.uv_HSnowTex)));
			o.Specular = _SpecularF;
			o.Smoothness = hs_smoothness * _SmoothnessF;
			o.Albedo = _Color.xyz;
			o.Emission = (float3(h_mixmap.g, h_mixmap.g, h_mixmap.g) * clamp(abs(1.0 - dot(IN.viewDir, o.Normal)) - 0.3, 0.0, 1.0)) * 8.0;
		}
	ENDCG
	}
	FallBack "Diffuse"
}
