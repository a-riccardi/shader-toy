Shader "ShaderToy/FreezePostProcess"
{
	Properties
	{ 
		[HideInInspector]
		_MainTex ("Frame Texture", 2D) = "white" {}
		[NoScaleOffset]
		[Header(General Settings)]
		_MixMap("Normal(RG), Density(B), GradientMap(A)", 2D) = "white" {}
		_Amount("Amount", Range(0.0, 1.0)) = 0.3
		_Steepness("Gradient Steepness", Range(1.0, 50.0)) = 5.0
		_Strenght("Normal Strenght", Range(0.01, 0.5)) = 0.3
		[Space(5)]
		[Header(Thick ice)]
		[NoScaleOffset]
		_IceTex("Thick Ice Normal(RGB), Density(A)", 2D) = "white" {}
		[NoScaleOffset]
		_NoiseTex("Tile Noise Texture", 2D) = "gray" {}
		_Color("Ice Color", Color) = (0.8, 0.82, 0.9, 1.0)
		_IceTiling("Ice Tiling", Range(0.1, 10)) = 1
		_ThicknessF("Thickness Modifier", Range(0.0, 1.0)) = 0.5
		_SpecularF("Thick Ice Specular Power", Range(0.1,5)) = 2
	}
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "../../../Shaders/Utils.cginc"

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
	
			uniform sampler2D _MainTex;
			uniform sampler2D _MixMap;
			uniform sampler2D _IceTex;
			uniform sampler2D _NoiseTex;
			uniform float _Amount;
			uniform float _Steepness;
			uniform float _Strenght;
			uniform float _SpecularF;
			uniform float _IceTiling;
			uniform float _ThicknessF;
			uniform fixed4 _Color;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			//CG porting of an awesome tiling technique from Inigo Quilez
			//taken from https://www.shadertoy.com/view/Xtl3zf
			inline float4 ice_tiler(float2 uv, float scale)
			{
				float k = tex2D(_NoiseTex, 0.1*uv).x; // cheap (cache friendly) lookup

				float l = k * 8.0;
				float i = floor(l);
				float f = l - i; //getting the fractional part without using frac(l)

				float2 off_a = sin(float2(3.0, 7.0)*(i + 0.7)); // can replace with any other hash
				float2 off_b = sin(float2(3.0, 7.0)*(i + 1.3)); // can replace with any other hash

				float4 col_a = tex2D(_IceTex, uv + scale * off_a);
				float4 col_b = tex2D(_IceTex, uv + scale * off_b);

				return lerp(col_a, col_b, smoothstep(0.2, 0.8, f - 0.1 * vec_sum(col_a - col_b)));
			}


			fixed4 frag (v2f i) : SV_Target
			{
				//sample the mixmap
				float4 mixmap = tex2D(_MixMap, i.uv); //rg -> normal, b -> density, a -> gradient

				//extract the data from the mixmap
				float2 normal = mixmap.rg * 2.0 - 1.0; //expand normal range from [0..1] to [-1..1]
				float density = mixmap.b;
				float opacity = mixmap.a;

				//compute the gradient that will control the progression of the freeze effect
				float gradient = pow(opacity, _Steepness - (_Amount * _Steepness)) * _Amount; //multiply all for _Amount to avoid artifacts when_ Amount = 0

				//normalize the normal vector to avoid artifacts
				normal = normalize(normal);
				//modulate density & opacity by the gradient
				density *= gradient; 
				opacity *= gradient;

				//modulating density using the _ThicknessF exposed parameter
				density = lerp(density*density*density*density*density, density, _ThicknessF); //avoiding a pow() operation, which tends to be quite computationally expensive
				density = remap(density, 0.0, 1.0, 0.0, lerp(3.0, 0.75, _ThicknessF));

				//modulate the normal strength by the ice _ThicknessF
				normal *= lerp(0.2, 1.0, _ThicknessF);
				//modulate the normal by the opacity mask in order to avoid linear increasing in normal strength, and making them follow the ice veins instead
				normal *= opacity; 

				//compute uv offset modulating the normal by the _Strength parameter
				float2 uv_offset = normal * _Strenght;
				//getting the light color using the main texture, sampled with uv_offset to simulate ice distortion
				fixed4 light_color = tex2D(_MainTex, i.uv + uv_offset);

				//sample _IceTex using a non-uniform tiling function taken from inigo quilez
				float4 ice_texture_color = ice_tiler(i.uv * _IceTiling, 1.05); //TODO parameterize noise factor
				//expanding the .xy component of the normal map. z is always pointing forward
				ice_texture_color.rg = ice_texture_color.rg * 2.0 - 1.0;

				//computing a fake light source position, using uv to add a "round" effect and avoid linearity
				float3 light_source = normalize(float3(i.uv * 2.0 - 1.0, 1.0));
				//standard diffuse lighting computation, using the fake light source computed above
				//computing the diffuse lighting factor
				float NdotL = saturate(dot(ice_texture_color.xyz, light_source));
				//computing the specular lighting factor
				float NdotV = pow(max(dot(reflect(light_source, ice_texture_color.xyz), float3(0.0, 0.0, -1)), 0.0), _SpecularF);

				//thick ice color is computed with a standard illumination equation: diffuse + specular + ambient
				fixed4 thick_ice_color = _Color * NdotL + _Color * NdotV + _Color * 0.05;
				
				//final color is computed as a lerp between the thick ice color & the light color behind, based on the ice density and the overall opacity of the mask, both modulated by the thickness of the _IceTex alpha
				return saturate(lerp(light_color, thick_ice_color, clamp01(density * opacity * lerp(1.1, 0.8, ice_texture_color.a * 3))));
			}
			ENDCG
		}
	}
}
