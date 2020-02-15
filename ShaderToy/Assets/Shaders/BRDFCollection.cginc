#ifndef BRDF_COLLECTION
#define BRDF_COLLECTION

#include "Utils.cginc"

//this code has been taken from this amazing article by Jordan Stevens: https://www.jordanstevenstechart.com/physically-based-rendering
//the functions have been renamed and optimized where possible

//---Normal Distribution Functions-------------------------------------------------------------------
inline float distribution_phong(float RdotV, float specular_power, float specular_glossiness)
{
	float distr = pow(RdotV, specular_glossiness) * specular_power;
	return distr * (2.0 + specular_power) / PI_2;
}

inline float distribution_blinn_phong(float NdotH, float specular_power, float specular_glossiness)
{
	float distr = pow(NdotH, specular_glossiness) * specular_power;
	return distr * (2.0 + specular_power) / PI_2;
}

inline float distribution_beckmann(float roughness_squared, float NdotH)
{
	float NdotHSqr = NdotH * NdotH;
	return max(0.000001, (1.0 / (PI*roughness_squared*NdotHSqr*NdotHSqr))* exp((NdotHSqr - 1.0) / (roughness_squared*NdotHSqr)));
}

inline float distribution_gaussian(float roughness_squared, float NdotH)
{
	float thetaH = acos(NdotH);
	return exp(-thetaH * thetaH / roughness_squared);
}

inline float distribution_ggx(float roughness, float NdotH)
{
	float NdotHSqr = NdotH * NdotH;
	float TanNdotHSqr = (1 - NdotHSqr) / NdotHSqr;
	return PI_INVERSE * sqr(roughness / (NdotHSqr * (sqr(roughness) + TanNdotHSqr)));
}

inline float distribution_trowbridge_reitz(float NdotH, float roughness_squared)
{
	float distr = NdotH * NdotH * (roughness_squared - 1.0) + 1.0;
	return roughness_squared / (PI * distr * distr);
}

inline float distribution_trowbridge_reitz_anisotropic(float anisotropy, float roughness_squared, float NdotH, float HdotX, float HdotY)
{
	float aspect = sqrt(1.0 - anisotropy * 0.9);
	float X = max(0.001, roughness_squared / aspect) * 5.0;
	float Y = max(0.001, roughness_squared*aspect) * 5.0;
	return 1.0 / (PI * X * Y * sqr(sqr(HdotX / X) + sqr(HdotY / Y) + NdotH * NdotH));
}

inline float distribution_ward_anisotropic(float anisotropy, float roughness_squared, float NdotL, float NdotV, float NdotH, float HdotX, float HdotY)
{
	float aspect = sqrt(1.0 - anisotropy * 0.9);
	float X = max(0.001, roughness_squared / aspect) * 5.0;
	float Y = max(0.001, roughness_squared * aspect) * 5.0;
	float exponent = -(sqr(HdotX / X) + sqr(HdotY / Y)) / sqr(NdotH);
	float distr = 1.0 / (PI * X * Y * sqrt(NdotL * NdotV));
	return distr * exp(exponent);
}
//---------------------------------------------------------------------------------------------------------------------

//---Geometric Shadowing Functions-------------------------------------------------------------------------------------

inline float geometric_implicit(float NdotL, float NdotV)
{
	return NdotL * NdotV;
}

inline float geometric_ashikhmin_shirley(float NdotL, float NdotV, float LdotH)
{
	return NdotL * NdotV / (LdotH * max(NdotL, NdotV));
}

inline float geometric_ashikhmin_premoze(float NdotL, float NdotV)
{
	return NdotL * NdotV / (NdotL + NdotV - NdotL * NdotV);
}

inline float geometric_duer(float3 half_vector, float NdotL, float NdotV, float NdotH)
{
	return sqr_magnitude(half_vector) * pow(NdotH, -4.0);
}

inline float geometric_neumann(float NdotL, float NdotV)
{
	return (NdotL*NdotV) / max(NdotL, NdotV);
}

inline float geometric_kelemen(float NdotL, float NdotV, float LdotH, float VdotH)
{
	//	float Gs = (NdotL*NdotV)/ (LdotH * LdotH);           //this
	return (NdotL*NdotV) / (VdotH * VdotH);       //or this?
}

inline float geometric_kelemen_modified(float NdotV, float NdotL, float roughness_squared)
{
	float c = 0.797884560802865; // c = sqrt(2 / Pi)
	float k = roughness_squared * c;
	float gH = NdotV * k + (1 - k);
	return gH * gH * NdotL;
}

inline float geometric_cook_torrance(float NdotL, float NdotV, float VdotH, float NdotH)
{
	return min(1.0, min(2 * NdotH*NdotV / VdotH, 2 * NdotH*NdotL / VdotH));
}

inline float geometric_ward(float NdotL, float NdotV, float VdotH, float NdotH)
{
	return pow(NdotL * NdotV, 0.5);
}

inline float geometric_kurt(float NdotL, float NdotV, float VdotH, float roughness)
{
	return (VdotH*pow(NdotL*NdotV, roughness)) / NdotL * NdotV;
}

//SmithModelsBelow
//Gs = F(NdotL) * F(NdotV);

inline float geometric_walter_et_al(float NdotL, float NdotV, float roughness_squared)
{
	float NdotLSqr = NdotL * NdotL;
	float NdotVSqr = NdotV * NdotV;
	float SmithL = 2.0 / (1.0 + sqrt(1.0 + roughness_squared * (1.0 - NdotLSqr) / (NdotLSqr)));
	float SmithV = 2.0 / (1.0 + sqrt(1.0 + roughness_squared * (1.0 - NdotVSqr) / (NdotVSqr)));
	return SmithL * SmithV;
}

inline float geometric_beckmann(float NdotL, float NdotV, float roughness_squared)
{
	float NdotLSqr = NdotL * NdotL;
	float NdotVSqr = NdotV * NdotV;
	float calulationL = (NdotL) / (roughness_squared * sqrt(1.0 - NdotLSqr));
	float calulationV = (NdotV) / (roughness_squared * sqrt(1.0 - NdotVSqr));
	float SmithL = calulationL < 1.6 ? (((3.535 * calulationL) + (2.181 * calulationL * calulationL)) / (1.0 + (2.276 * calulationL) + (2.577 * calulationL * calulationL))) : 1.0;
	float SmithV = calulationV < 1.6 ? (((3.535 * calulationV) + (2.181 * calulationV * calulationV)) / (1.0 + (2.276 * calulationV) + (2.577 * calulationV * calulationV))) : 1.0;
	return SmithL * SmithV;
}

inline float geometric_ggx(float NdotL, float NdotV, float roughness_squared)
{
	float NdotLSqr = NdotL * NdotL;
	float NdotVSqr = NdotV * NdotV;
	float SmithL = (2.0 * NdotL) / (NdotL + sqrt(roughness_squared + (1.0 - roughness_squared) * NdotLSqr));
	float SmithV = (2.0 * NdotV) / (NdotV + sqrt(roughness_squared + (1.0 - roughness_squared) * NdotVSqr));
	return SmithL * SmithV;
}

inline float geometric_schlick(float NdotL, float NdotV, float roughness_squared)
{
	float SmithL = (NdotL) / (NdotL * (1.0 - roughness_squared) + roughness_squared);
	float SmithV = (NdotV) / (NdotV * (1.0 - roughness_squared) + roughness_squared);
	return SmithL * SmithV;
}

inline float geometric_schlick_beckmann(float NdotL, float NdotV, float roughness_squared)
{
	float k = roughness_squared * 0.797884560802865;
	float SmithL = (NdotL) / (NdotL * (1.0 - k) + k);
	float SmithV = (NdotV) / (NdotV * (1.0 - k) + k);
	return SmithL * SmithV;
}

inline float geometric_schlick_ggx(float NdotL, float NdotV, float roughness)
{
	float k = roughness / 2.0;
	float SmithL = (NdotL) / (NdotL * (1.0 - k) + k);
	float SmithV = (NdotV) / (NdotV * (1.0 - k) + k);
	return SmithL * SmithV;
}

//----------------------------------------------------------------------------------------------------

//---Fresnel Functions--------------------------------------------------------------------------------
inline float fresnel_schlick_factor(float f)
{
	float x = clamp01(1.0 - f);
	float x2 = x * x;
	return x2 * x2 * x;
}

inline float fresnel_schlick_ior(float ior, float LdotH)
{
	float f0 = (ior - 1.0) / (ior + 1.0);
	f0 = sqr(f0);
	return f0 + (1.0 - f0) * fresnel_schlick_factor(LdotH);
}

inline float3 fresnel_lerp(float3 base_color, float3 fresnel_color, float d)
{
	float f = fresnel_schlick_factor(d);
	return lerp(base_color, fresnel_color, f);
}

inline float3 fresnel_lerp(float3 base_color, float3 fresnel_color, float d, float ior)
{
	float f = fresnel_schlick_ior(ior, d);
	return lerp(base_color, fresnel_color, f);
}

inline float3 fresnel_schlick_function(float3 specular_color, float LdotH)
{
	return specular_color + (1.0 - specular_color) * fresnel_schlick_factor(LdotH);
}

inline float3 fresnel_spherical_gaussian(float LdotH, float3 specular_color)
{
	float power = ((-5.55473 * LdotH) - 6.98316) * LdotH;
	return specular_color + (1.0 - specular_color)  * pow(2.0, power);
}

//-----------------------------------------------

//normal incidence reflection calculation
inline fixed3 diffuse_fresnel_attenuation(fixed3 diffuse_color, float NdotL, float NdotV, float LdotH, float roughness)
{
	float fresnel_light = fresnel_schlick_factor(NdotL);
	float fresnel_view = fresnel_schlick_factor(NdotV);
	float fresnel_diffuse_90 = 0.5 + 2.0 * LdotH * LdotH * roughness;
	return diffuse_color * (lerp(1.0, fresnel_diffuse_90, fresnel_light) * lerp(1.0, fresnel_diffuse_90, fresnel_view));
}

inline float brdf_ggx_ior(float NdotL, float NdotV, float NdotH, float LdotH, float roughness, float ior)
{
	return distribution_ggx(roughness, NdotH) * geometric_ggx(NdotL, NdotV, roughness * roughness) * fresnel_schlick_ior(ior, LdotH) * (1.0 / 4.0 * (NdotL * NdotV));
}

inline float brdf_ggx_ior(float3 normal_vector, float3 view_vector, float3 light_vector, float roughness, float ior)
{
	float3 half_vector = normalize(view_vector + light_vector);

	float NdotL = clamp01(dot(normal_vector, light_vector));
	float NdotV = clamp01(dot(normal_vector, view_vector));
	float NdotH = clamp01(dot(normal_vector, half_vector));
	float LdotH = clamp01(dot(light_vector, half_vector));

	return distribution_ggx(roughness, NdotH) * geometric_ggx(NdotL, NdotV, roughness * roughness) * fresnel_schlick_ior(ior, LdotH) * (1.0 / 4.0 * (NdotL * NdotV));
}

#endif