Shader "ShaderToy/CyberpunkPixelFade/PixelFade_Base"
{
	Properties{
		_MainTex("Main Texture", 2D) = "grey" {}
		_TessEdge("Tessellation Factor", Range(1,30)) = 20
		_PointCloudDensity("Minimum Pointcloud Density", Range(0,5)) = 0.1
		_Size("Fragment Size", Range(0.001, 0.4)) = 0.01
		[KeywordEnum(Triangle, Quad)] _Shape("Point Shape", Float) = 0
		_CameraOffset("Cloud Density Offset", Range(0, 15)) = 8.0
		_CameraDistance("Maximum Point Distance", Range(0, 50)) = 12
		_PointFloatF("Point Floating Amount", Range(0, 0.5)) = 0.05
		_FadeRamp("Point Fade Ramp", 2D) = "grey" {}
		_GlitchTex("Glitch Intensity Texture", 2D) = "black" {}
		_GlitchPeak("Glich Peak Height (pixel)", Range(50, 500)) = 250
		_GlitchPanSpeed("Glitch Pan Speed", Range(0, 5)) = 1
		_GlitchIntensity("Glitch Intensity", Range(0,1)) = 1
    }
    SubShader {
    	Pass {
			Tags { "LightMode"="Deferred" }
			Cull Off
			
    		CGPROGRAM
    		#pragma target 5.0
     
    		#pragma vertex vertex_shader
    		#pragma fragment fragment_shader
    		#pragma hull hull_shader
    		#pragma domain domain_shader
			#pragma geometry geometry_shader

    		#pragma enable_d3d11_debug_symbols

			#pragma multi_compile _SHAPE_TRIANGLE _SHAPE_QUAD

    		#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "../../../Shaders/Utils.cginc"

			#define INV_SCREEN_RATIO (0.5625)

			uniform sampler2D _MainTex;
			uniform sampler2D _FadeRamp;
			uniform sampler2D _GlitchTex;
			uniform float4 _MainTex_ST;
			uniform float4 _MainTex_TexelSize;

    		uniform float _TessEdge;
			uniform float _PointCloudDensity;
			uniform float _Size;
			uniform float _CameraDistance;
			uniform float _CameraOffset;
			uniform float _PointFloatF;
			uniform float _GlitchPanSpeed;
			uniform float _GlitchPeak;

			uniform float _GlitchIntensity; //updated via code

    		struct appdata
    		{
        		float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv1 : TEXCOORD1;
				//float4 color : COLOR;
				float3 normal : NORMAL;
    		};
     
    		struct v2h
    		{
        		float4 pos   : POS;
				float4 uv : TEXCOORD0;
				float4 params : TEXCOORD1;
				//float4 color : COLOR;
				float4 normal_d : NORMAL;
			};
     
    		struct h2d
    		{
       			float TessFactor[3]    : SV_TessFactor;
        		float InsideTessFactor : SV_InsideTessFactor;
    		};
     
    		struct hCP
    		{
        		float4 pos    : POS;
				float4 uv : TEXCOORD0;
				float4 params : TEXCOORD1;
				//float4 color : COLOR;
				float4 normal_d : NORMAL;
    		};
     
    		struct d2g
    		{
        		float4 pos   : SV_Position;
				float4 uv : TEXCOORD0;
				float4 params : TEXCOORD1;
				//float4 color : COLOR;
				float4 normal_d : NORMAL;
			};
     
    		struct g2f
    		{
        		float4 pos   : SV_Position;
				float4 uv : TEXCOORD0;
				//float4 color : COLOR;
				float4 normal_d : NORMAL;
    		};

    		v2h vertex_shader( appdata v )
    		{
				float noiseF = (hash31(v.vertex.xyz)) * 15;

        		v2h o;

				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
				//o.color = v.color;
				o.normal_d.xyz = UnityObjectToWorldNormal(v.normal)*0.5+0.5;
				o.normal_d.w = /*sqr_magnitude*/distance(UnityObjectToViewPos(v.vertex.xyz) + float3(0, 0, _CameraOffset), float3(0,0,0));
				o.normal_d.w = clamp(remap01(o.normal_d.w, 0.0, _CameraDistance), 0, 1);

				o.params = float4(0,0,0,0);
				o.params.x = tex2Dlod(_GlitchTex, float4((v.vertex.yx * 0.1)/* + _Time.x * _GlitchPanSpeed*/, 0, 0)).r * (1.0 - (o.normal_d.w * o.normal_d.w)) * _GlitchPeak * _GlitchIntensity;

				v.vertex.z += hash13(v.vertex.xyz) * sin(_Time.w * hash13(v.vertex.zxy)) * lerp(0.0, _PointFloatF, o.normal_d.w);
				o.pos = UnityObjectToClipPos(v.vertex);
		
        		return o;
    		}
			
			float tessellation_screenspace_edge(v2h cp0, v2h cp1)
			{
				float edgeLength = sqr_magnitude(cp0.pos - cp1.pos); // distance(cp0.pos, cp1.pos);
				edgeLength *= _ScreenParams.y;
				edgeLength /= _TessEdge;

				return lerp(edgeLength, _PointCloudDensity, (cp0.normal_d.w + cp0.normal_d.w) * 0.5);
			}

			h2d HSConstant(InputPatch<v2h, 3> i)
			{
				h2d o = (h2d)0;

				o.TessFactor[0] = tessellation_screenspace_edge(i[1], i[2]);
				o.TessFactor[1] = tessellation_screenspace_edge(i[2], i[0]);
				o.TessFactor[2] = tessellation_screenspace_edge(i[0], i[1]);
				o.InsideTessFactor = (o.TessFactor[0] + o.TessFactor[1] + o.TessFactor[2]) * 0.33333; //_TessEdge;

				return o;
			}

    		[domain("tri")]
    		[partitioning("fractional_odd")]
    		[outputtopology("triangle_cw")]
    		[patchconstantfunc("HSConstant")]
    		[outputcontrolpoints(3)]
    		hCP hull_shader( InputPatch<v2h, 3> i, uint uCPID : SV_OutputControlPointID )
    		{
        		hCP o = (hCP)0;

				o.pos = i[uCPID].pos;
				//o.color = i[uCPID].color;
				o.uv = i[uCPID].uv;
				o.normal_d = i[uCPID].normal_d;
				o.params = i[uCPID].params;

        		return o;
    		}
    
    		[domain("tri")]
    		d2g domain_shader( h2d HSConstantData, const OutputPatch<hCP, 3> i, float3 BarycentricCoords : SV_DomainLocation)
    		{
        		d2g o = (d2g)0;
     
        		float fU = BarycentricCoords.x;
        		float fV = BarycentricCoords.y;
        		float fW = BarycentricCoords.z; 
      
				o.pos =      i[0].pos      * fU + i[1].pos      * fV + i[2].pos      * fW;
				//o.color = i[0].color * fU + i[1].color * fV + i[2].color * fW;
				o.uv =       i[0].uv       * fU + i[1].uv       * fV + i[2].uv       * fW;
				o.normal_d = i[0].normal_d * fU + i[1].normal_d * fV + i[2].normal_d * fW;
				o.params =   i[0].params   * fU + i[1].params   * fV + i[2].params   * fW;

        		return o;
    		}
     
			[maxvertexcount(4)]
			void geometry_shader(point d2g p[1], inout TriangleStream<g2f> triStream)
			{
				_Size = lerp(_Size, _Size * 3.0, p[0].normal_d.w);
				float halfS = 0.5 * _Size;
				float halfS_S = halfS * INV_SCREEN_RATIO;

				float glitchF = -halfS * p[0].params.x;
				glitchF = lerp(glitchF, -halfS, step(-halfS , glitchF));

#if _SHAPE_QUAD
				float4 v[4];
				v[0] = p[0].pos + float4( halfS_S, glitchF, 0, 0);
				v[1] = p[0].pos + float4( halfS_S, halfS, 0, 0);
				v[2] = p[0].pos + float4(-halfS_S, glitchF, 0, 0);
				v[3] = p[0].pos + float4(-halfS_S, halfS, 0, 0);
#elif _SHAPE_TRIANGLE
				float4 v[3];
				//DOWN FACING TRIANGLES
				/*v[0] = p[0].pos + float4(halfS_S, glitchF * 0.5, 0, 0);
				v[1] = p[0].pos + float4(0, halfS, 0, 0);
				v[2] = p[0].pos + float4(-halfS_S, glitchF * 0.5, 0, 0);*/
				v[0] = p[0].pos + float4(0, glitchF * 0.5, 0, 0);
				v[1] = p[0].pos + float4(halfS_S, halfS, 0, 0);
				v[2] = p[0].pos + float4(-halfS_S, halfS, 0, 0);
#endif
				g2f pIn;
#if _SHAPE_QUAD
				for (uint i = 0; i < 4; i++)
#elif _SHAPE_TRIANGLE
				for (uint i = 0; i < 3; i++)
#endif
				{
					pIn.pos = v[i];
					pIn.uv = p[0].uv;
					//pIn.uv.xy += (i == 0 ? _MainTex_TexelSize.xy * (_GlitchIntensity > 0 ? float2(_test, 1) : float2(1,1)) * 5 : float2(0,0));
					//pIn.color = p[0].color;
					pIn.normal_d = p[0].normal_d;

					triStream.Append(pIn);
				}
			}
			/*
    		float4 fragment_shader( g2f i ) : SV_Target
    		{
				float nDl = max(0.0, dot(-_WorldSpaceLightPos0.xyz, i.normal_d.xyz));
				float4 point_color = tex2D(_MainTex, i.uv);
				point_color.rgb *=_LightColor0 * nDl + ShadeSH9(float4(i.normal_d.xyz, 1));
				//return float4(i.normal_d.w, 0, 0, 1);
				return point_color;
    		}
			*/

			void fragment_shader(g2f i, out float4 albedo : SV_Target0, out float4 specular : SV_Target1, out float4 normal : SV_Target2, out float4 emissive : SV_Target3)
			{
				albedo = float4(tex2D(_MainTex, i.uv.xy).xyz, 1.0)*0.5;
				specular = float4(0,0,0, 0);
				normal = float4(i.normal_d.xyz, 0.0);
				emissive = albedo*0.5 + float4(DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw)), 0.0)*0.5;
			}

    		ENDCG
    	}

    }
}
