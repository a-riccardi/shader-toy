#ifndef BDRF_COLLECTION
#define BDRF_COLLECTION

inline float ChiGGX(float v)
{
	return v > 0.0 ? 1.0 : 0.0;
}

float Distribution_GGX(float3 normalVector, float3 halfVector, float alpha)
{
	float NdotH = dot(normalVector, halfVector);
	float alpha2 = alpha * alpha;
	float NdotH2 = NdotH * NdotH;
	float den = NdotH2 * alpha2 + (1.0 - NdotH2);
	return (ChiGGX(NdotH2) * alpha2) / (PI * den * den);
}

float GeometryPartialTerm_GGX(float3 viewVector, float3 normalVector, float halfVector, float alpha)
{
	float NdotV = saturate(dot(normalVector, viewVector));
	float alpha2 = alpha * alpha;

	return (2.0 * NdotV) / max(0.0, (NdotV + sqrt(alpha2 + (1.0 - alpha2)*(NdotV*NdotV))));
}

inline float GetF0(float indexOfRefraction, float3 diffuse, float metallicValue)
{
	float3 f0 = (1.0 - indexOfRefraction) / (1.0 + indexOfRefraction);
	f0 *= f0;
	return lerp(f0, diffuse, metallicValue);
}

inline float3 Fresnel_Schlick(float3 viewVector, float3 halfVector, float3 f0)
{
	return f0 + (1.0 - f0) * pow(1.0 - dot(viewVector, halfVector), 5.0);
}

inline float CookTorrance_GGX(float3 viewVector, float3 normalVector, float3 lightVector, float F0, float alpha)
{
	float3 halfVector = normalize(viewVector + lightVector);

	return Distribution_GGX(normalVector, halfVector, alpha) *
		   GeometryPartialTerm_GGX(viewVector, normalVector, halfVector, alpha) * GeometryPartialTerm_GGX(lightVector, normalVector, halfVector, alpha) *
		   Fresnel_Schlick(viewVector, halfVector, F0);
}
#endif