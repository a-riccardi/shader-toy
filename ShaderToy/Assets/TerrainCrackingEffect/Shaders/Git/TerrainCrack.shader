Shader "ShaderToy/TerrainCrackEffect/TerrainCrack"
{
	Properties
	{
		_CrackWallMap("Crack Walls Map (RGB) Depth (A)", 2D) = "white" {}
		_Height ("Crack Depth", Range(0.0, 0.15)) = 0.08
		_BelowDepth("UnderneathDepth", Range(0.0, 0.7)) = 0.3
		_MixMap("Below Map (RG) Border Mask (BA)", 2D) = "white" {}
		[HDR]_TintColor("Magic Color", Color) = (0.15, 0.35, 0.85, 1.0)
		_DeformationIntensity("Magic Waving Intensity", Range(0.1, 1.0)) = 0.5
		_AnimationIntensity("Magic Animation Intensity", Range(0.1, 1.0)) = 0.5
		_WaveHeight("Magic Wave Height", Range(0.0, 1.0)) = 0.5
		_RampMap("Shadow Ramp Map", 2D) = "gray" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile ULTRA_QUALITY HIGH_QUALITY MEDIUM_QUALITY LOW_QUALITY

			#include "UnityCG.cginc"
			#include "../../../Shaders/Utils.cginc"
			
			#ifdef ULTRA_QUALITY
			#define MAX_LAYER (128.0)
			#define MIN_LAYER (64.0)
			#elif  HIGH_QUALITY
			#define MAX_LAYER (64.0)			
			#define MIN_LAYER (32.0)
			#elif MEDIUM_QUALITY
			#define MAX_LAYER (32.0)			
			#define MIN_LAYER (16.0)
			#elif LOW_QUALITY
			#define MAX_LAYER (16.0)			
			#define MIN_LAYER (8.0)
			#else
			#define MAX_LAYER (32.0)			
			#define MIN_LAYER (16.0)
			#endif

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 tangent : TANGENT;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv_Main : TEXCOORD0;
				float2 uv_CrackWall : TEXCOOORD1;
				float2 uv_Below : TEXCOORD2;
				float3 tangentViewDir : TANGENT;
			};

			uniform sampler2D _CrackWallMap;
			uniform sampler2D _MixMap;
			uniform sampler2D _RampMap;
			uniform float4 _CrackWallMap_ST;
			uniform float4 _MixMap_ST;
			uniform float4 _TintColor;
			uniform float _Height;
			uniform float _BelowDepth;
			uniform float _DeformationIntensity;
			uniform float _AnimationIntensity;
			uniform float _WaveHeight;

			inline float3 getTangentViewDir(float3 normal, float4 tangent, float3 worldViewDir)
			{
				float3 worldNormal = UnityObjectToWorldNormal(normal);
				float3 worldTangent = UnityObjectToWorldDir(tangent.xyz);
				float3 worldBitangent = cross(worldNormal, worldTangent) * (tangent.w * unity_WorldTransformParams.w);

				//NOTE: unity_WorldTransformParams.w stores +1 or -1 depending if the object is mirrored via scaling,
				//meaning if an odd number of scale vector values is negative

				//since we'll not use the worldToTangent matrix aniwhere else,
				//directly return the transformed vector instead of building the matrix
				return float3(
					dot(worldViewDir, worldTangent),
					dot(worldViewDir, worldBitangent),
					dot(worldViewDir, worldNormal)
					);
			}

			inline float getcurrentDepth(float depth, float2 mask)
			{
				//mask the current depth using a mask
				//NOTE: the mask should be black-ish to allow the parallax effect
				//to be still present on the borders
				return lerp(depth * mask.y, depth, mask.y);
			}

			inline float2 getParallaxMappedUV(float2 texcoord, float2 constCoord, float3 viewDir, out float underneathWeight, out float rampCoord)
			{
				//compute partial derivatives to be able to use gradient instruction in loop
				float4 dd = float4(0, 0, 0, 0);
				dd.xy = ddx(texcoord);
				dd.zw = ddy(texcoord);

				//choose the layerN based on the camera position: a view perpendicular to the surface
				//will need less layers then a parallel look
				float layerN = ceil(lerp(MAX_LAYER, MIN_LAYER, abs(dot(float3(0.0, 0.0, 1.0), viewDir))));
				float layerDepth = 1.0 / layerN;
				//save max depth value, the effective depth value will change in the loop
				float maxDepth = layerDepth;
				float currentLayerDepth = 0.0;

				//compute the deltaUV to add in every cycle iteration
				float2 P = viewDir.xy / viewDir.z * _Height;
				float2 deltaUV = P / layerN;

				float2 currentTexcoord = texcoord;
				float2 mask = tex2D(_MixMap, constCoord).ba;
				float currentDepth = getcurrentDepth(tex2D(_CrackWallMap, currentTexcoord).a, mask);

				rampCoord = layerN;

				[loop]
				for (float j = 0.0; j < layerN; j++)
				{
					//if the current layer depth is >= then the depth sampled from the texture,
					//then we've hit something and we should return
					if (currentLayerDepth >= currentDepth)
					{
						//save the current depth to sample the color ramp
						rampCoord = currentLayerDepth;
						break;
					}	

					//move the texcoord
					currentTexcoord -= deltaUV;
					//check the current depth from the depth texture
					currentDepth = getcurrentDepth(tex2D(_CrackWallMap, currentTexcoord, dd.xy, dd.zw).a, mask);
					//progressively reduce the layerDepth value
					layerDepth = maxDepth - (maxDepth / float(j+1));
					//add the layerDepth to the current layer depth
					currentLayerDepth += layerDepth;
				}

				//retrieve the coords for the previous layer
				float2 previousTexcoord = currentTexcoord + deltaUV;
				//compute the delta between the current sampled depth and the two enclosing layer depths 
				float belowDepthDelta = currentDepth - currentLayerDepth;
				float overDepthDelta = tex2D(_CrackWallMap, previousTexcoord).a - currentLayerDepth + layerDepth;

				//compute the underneath blend weight subtracting _BelowDepth to the currentDepth
				//and remap the value to augment the steepness of the blend gradient
				//underneathWeight = 1.0 - step(currentDepth + (_SinTime.w * lerp(0.0, 0.1, _WaveHeight)), _BelowDepth);
				underneathWeight = clamp(remap01(currentDepth - _BelowDepth, 0.25, 0.4), 0.0, 1.0);

				//return currentTexcoord;

				//get a [0..1] weight to blend the texcoord
				float weight = overDepthDelta / (overDepthDelta - belowDepthDelta);
				return lerp(previousTexcoord, currentTexcoord, weight);
			}

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv_Main = v.uv;
				o.uv_Below = TRANSFORM_TEX(v.uv, _MixMap);
				o.uv_CrackWall = TRANSFORM_TEX(v.uv, _CrackWallMap);

				float3 worldSpaceVertexPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - worldSpaceVertexPos);

				o.tangentViewDir = normalize(getTangentViewDir(v.normal, v.tangent, worldViewDir));

				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float4 color = float4(0.0, 0.0, 0.0, 1.0);
				float underneathWeight = 0.0;
				float rampCoord = 0.0;
				float2 texcoord = getParallaxMappedUV(i.uv_CrackWall, i.uv_Main, i.tangentViewDir, underneathWeight, rampCoord);

				//sample the ramp to get a smooth color blend
				float4 rampColor = tex2D(_RampMap, float2(rampCoord, 0.5));
				//scale the _Height value to get a [0..1] value
				float alphaHeight = remap01(_Height, 0.0, 0.15);

				//compute a deformation factor for the underneath uv.
				//this gives the "wavy" look to the texture
				float2 deformationF = _MixMap_ST.xy * 15 * (i.uv_CrackWall + _Time.x * 0.001);
				deformationF.x = cos(deformationF.x * (_SinTime.x * _AnimationIntensity));
				deformationF.y = sin(deformationF.y * (_CosTime.x * _AnimationIntensity));
				i.uv_Below += (deformationF * _DeformationIntensity) * (0.005 * _MixMap_ST.xy);

				//scale _SinTime and _CosTime in [0..1] range since tey'll be used a lot after
				float4 _SinTimeN = _SinTime * 0.5 + 0.5;
				float4 _CosTimeN = _CosTime * 0.5 + 0.5;

				//sample the _Mixmap with different uv scales, scale the value using sin and cos time
				float4 underneathColor = tex2D(_MixMap, i.uv_Below + i.tangentViewDir.xy * 0.02).rrgg * lerp(0.7, 1.0, _SinTimeN.y);
				underneathColor += tex2D(_MixMap, i.uv_Below * (_SinTime.x * _CosTime.x * _AnimationIntensity * 0.1) * 0.6 + i.tangentViewDir.xy * 0.08).rrgg * lerp(0.4, 0.7, _CosTimeN.w);
				//change the contrast of underneathColor based on time & uv position
				underneathColor = cheap_contrast(underneathColor, lerp(1.5, 3.5, (cos(i.uv_CrackWall.x * 5 * _CosTime.w + i.uv_CrackWall.y * 5 * _SinTime.w))*0.5 + 0.5)) * _TintColor;
				//lerp with rampColor to smooth the transition //rampColor.rgb * 
				underneathColor.rgb = lerp(rampColor.rgb * _TintColor, underneathColor.rgb, abs(underneathWeight * 2 - 1));

				//sample the ground color
				float4 wallColor = tex2D(_CrackWallMap, texcoord);
				//blend the ground color with the ramp color to smooth the transition
				wallColor = lerp(wallColor, wallColor * (1.0 - rampColor.a) + float4(rampColor.rgb * _TintColor * rampColor.a, 1.0), alphaHeight);
				//lerp the underneath color with the wallColor to eliminate the depth effect when the height is zero
				underneathColor = lerp(wallColor, underneathColor, alphaHeight);

				return lerp(wallColor, underneathColor, underneathWeight);
			}
			ENDCG
		}
	}
}