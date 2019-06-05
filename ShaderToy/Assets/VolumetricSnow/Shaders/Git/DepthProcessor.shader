Shader "ShaderToy/DeformableSnow/DepthProcessor"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_PersistenceF("Persistence Factor", Float) = 5000
		[Enum(None,0,Small,4,Medium,8,Large,16)] _KernelSize ("Blur Kernel Size", Float) = 0.0
	}
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		//Pass 0: accumulate current depth texture into the depth buffer
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			//#pragma target 4.0
			#pragma multi_compile ______ FALLBACK_ARGB

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			sampler2D _MainTex;
			sampler2D _CameraDepthTexture;
			float _PersistenceF;

			#ifdef FALLBACK_ARGB
			//fallback frag function that outputs to an argb texture
			fixed4 frag(v2f i) : SV_Target
			{
				//sample previous accumulated depth
				//NOTE the value is encoded, so decode from ARGB texture
				float accumulatedDepth = DecodeFloatRGBA(tex2D(_MainTex, i.uv));
				//invert x component of uv because camera is flipped 
				i.uv.x = 1.0 - i.uv.x;
				//sample current depth value from depth texture
				float depthValue = Linear01Depth(tex2D(_CameraDepthTexture, i.uv).r);
				//compute time factor as 1.0 / persistence if persistence > 0.0, or 0.0 otherwise
				float timeF = lerp(0.0, clamp((1.0 / _PersistenceF), 0.0, 1.0), sign(_PersistenceF));
				//sum the time factor to the accumulated depth, multiply for the current depth value to keep zone flat
				//NOTE: clamping [0.0, 1.0) because the float encoding function relies on frac(n),
				//which will return the number we need UNLESS the float is 1.0 --> frac(1.0) = 0
				float actualDepth = clamp((accumulatedDepth + timeF) * depthValue, 0.0, 0.9999999999);
				//encode the actual depth for the frame value to ARGB and return it
				return EncodeFloatRGBA(actualDepth);
			}

			#else
			//default frag function, outputs to a RFloat texture
			float4 frag(v2f i) : SV_Target
			{
				//sample previous accumulated depth
				float accumulatedDepth = tex2D(_MainTex, i.uv).r;
				//invert x component of uv because camera is flipped 
				i.uv.x = 1.0 - i.uv.x;
				//sample current depth value from depth texture
				float depthValue = Linear01Depth(tex2D(_CameraDepthTexture, i.uv).r);
				//compute time factor as 1.0 / persistence if persistence > 0.0, or 0.0 otherwise
				float timeF = lerp(0.0, clamp((1.0 / _PersistenceF), 0.0, 1.0), sign(_PersistenceF));
				//sum the time factor to the accumulated depth, multiply for the current depth value to keep zone flat
				float actualDepth = clamp((accumulatedDepth + timeF) * depthValue, 0.0, 1.0);
				//return the actual depth for the frame
				return float4(actualDepth, 0.0, 0.0, 0.0);
			}
			#endif
			ENDCG
		}

		//Pass 1: optionally blurs depth texture to soften transition 
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile ______ FALLBACK_ARGB

			#include "UnityCG.cginc"
			#include "../../Shaders/Utils.cginc"
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			sampler2D _MainTex;
			float4 _MainTex_TexelSize; //.x -> 1.0/width | .y -> 1.0/height | .z -> width | .w -> height
			//NOTE: only choosing between blur/no blur for now, removing unused variables
			//float _KernelSize;

			#ifdef FALLBACK_ARGB
			//fallback frag function that outputs to a ARGB texture
			fixed4 frag(v2f i) : SV_Target
			{
				//initialize col value with the current pixel value
				//NOTE the color is encoded, so decode from ARGB texture
				float col = DecodeFloatRGBA(tex2D(_MainTex, i.uv));
			
				//loop trough a small poisson kernel, sample and add
				for (uint j = 0u; j < 4u; j++)
				{
					//the kernel is modulated for the texel size to sample around the current pixel
					col += tex2D(_MainTex, i.uv + (poisson_kernel_4[j] * _MainTex_TexelSize.xy));
				}

				//get the mean of the sampled values
				col /= 5.0;

				//NOTE: clamping [0.0, 1.0) because the float encoding function relies on frac(n),
				//which will return the number we need UNLESS the float is 1.0 --> frac(1.0) = 0
				return EncodeFloatRGBA(clamp(col, 0.0, 0.9999999999));
			}
			#else
			//default frag function, outputs to a RFloat texture
			float4 frag(v2f i) : SV_Target
			{
				//initialize col value
				float col = 0.0;
			
				//loop trough a small poisson kernel, sample and add
				for (uint j = 0u; j < 4u; j++)
				{
					//the kernel is modulated for the texel size to sample around the current pixel
					col += tex2D(_MainTex, i.uv + (poisson_kernel_4[j] * _MainTex_TexelSize.xy));
				}

				//get the mean of the sampled values
				col /= 4.0;

				//return color value, clamped to preserve value
				return float4(clamp(col, 0.0, 1.0), 0.0, 0.0, 0.0);
			}
			#endif
			ENDCG
		}
	}
}
