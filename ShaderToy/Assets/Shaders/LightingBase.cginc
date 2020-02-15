#if !defined(LIGHTING_BASE)
#define LIGHTING_BASE

inline fixed3 diffuse_reflections(fixed3 light_color, fixed3 diffuse_color, float3 light_dir, float3 normal_dir, float attenuation)
{
	return attenuation * light_color * diffuse_color * max(0.0, dot(light_dir, normal_dir));
}

inline fixed3 specular_reflections(fixed3 light_color, fixed3 specular_color, float3 light_dir, float3 normal_dir, float3 view_dir, float glossiness, float attenuation)
{
	return attenuation * light_color * specular_color * pow(max(0.0, dot(reflect(light_dir, normal_dir), view_dir)), glossiness);
}

float4 litFct(float NdotL, float NdotH, float specExp)
{
	float ambient = 1.0;
	float diffuse = max(NdotL, 0.0);
	float specular = step(0.0, NdotL) * pow(max(0.0, NdotH), specExp);
	return float4(ambient, diffuse, specular, 1.0);
}

void phong_shading(float3 LightColor, float3 normalWS, float3 pointToLightDirWS, float3 pointToCameraDirWS, float SpecExpon, float Ks, out float3 DiffuseContrib, out float3 SpecularContrib)
{
	float3 Hn = normalize(pointToCameraDirWS + pointToLightDirWS);
	float4 litV = litFct(dot(normalWS, pointToLightDirWS), dot(normalWS, Hn), SpecExpon);
	DiffuseContrib = litV.y * LightColor;
	SpecularContrib = litV.y * litV.z * Ks * LightColor;
}


#endif