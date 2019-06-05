Shader "ShaderToy/FrameAnimator2D/FrameAnimator"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Rows("Animation Sheet Rows", Float) = 4
		_Columns("Animation Sheet Columns", Float) = 4
		_Frame("Animation Frame", Float) = 0
		[Enum(DownToUp,0,UpToDown,1)] _DirectionY("Animation packing order", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
		LOD 100
		Blend SrcAlpha OneMinusSrcAlpha
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			float _Rows;
			float _Columns;
			float _Frame;
			float _DirectionY;

			void SetupFrameParameter()
			{
				float frame_offset_y = floor(_Frame / _Rows);
				_MainTex_ST.xy = float2(1.0 / _Columns, 1.0 / _Rows);
				_MainTex_ST.zw = float2(_MainTex_ST.x * _Frame, _MainTex_ST.y * lerp(frame_offset_y, (_Rows - 1.0) - frame_offset_y, _DirectionY));
			}

			v2f vert (appdata v)
			{
				SetupFrameParameter();

				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
