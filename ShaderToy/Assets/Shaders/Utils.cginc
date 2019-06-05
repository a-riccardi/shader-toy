#ifndef UTILS
#define UTILS

#define PI (3.14159265)
#define PI_2 (6.2831853)

#define GRAYSCALE_3 float3(0.2126, 0.7152, 0.0722)
#define GRAYSCALE float4(0.2126, 0.7152, 0.0722, 1.0)

#define UV_CENTER (float2(0.5, 0.5))

#include "Hash.cginc"
#include "SamplerTools.cginc"

static const float2 kernel_16[16] =
{
	//small-----------
	float2(-1.5, -0.5),
	float2(-0.5, +1.5),
	float2(+0.5, -1.5),
	float2(+1.5, +0.5),
	//medium----------
	float2(-2.5, +1.5),
	float2(-1.5, -2.5),
	float2(+1.5, +2.5),
	float2(+2.5, +1.5),
	//large-----------
	float2(-3.5, -2.5),
	float2(-3.5, -0.5),
	float2(-2.5, +3.5),
	float2(-1.5, +3.5),
	float2(+0.5, -3.5),
	float2(+2.5, -3.5),
	float2(+3.5, +0.5),
	float2(+3.5, +2.5)
};

static const float2 poisson_kernel_4[4] =
{
	float2( 0.4247072, -0.4262313),
	float2(-0.3010053,  0.3568736),
	float2( 0.8125032,  0.3971981),
	float2(-0.4083271, -0.8709177)
};

static const float2 gaussian_kernel_3[3] =
{
	float2(0.250838, 0.0),
	float2(0.498323, 0.0),
	float2(0.250838, 0.0)
};

static const float2 gaussian_kernel_5[5] =
{
	float2(0.130598, 0.0),
	float2(0.230293, 0.0),
	float2(0.278216, 0.0),
	float2(0.230293, 0.0),
	float2(0.130598, 0.0)
};

static const float2 gaussian_kernel_9[9] =
{
	float2(0.068076, -4.0),
	float2(0.095550, -3.0),
	float2(0.121731, -2.0),
	float2(0.140767, -1.0),
	float2(0.147753,  0.0),
	float2(0.140767,  1.0),
	float2(0.121731,  2.0),
	float2(0.095550,  3.0),
	float2(0.068076,  4.0)
};

static const float3 laplacian_edge_kernel[9] =
{
	float3(-1.0,  1.0, -1.0),
	float3( 0.0,  1.0,  2.0),
	float3( 1.0,  1.0, -1.0),
	float3(-1.0,  0.0,  2.0),
	float3( 0.0,  0.0, -4.0),
	float3( 1.0,  0.0,  2.0),
	float3(-1.0, -1.0, -1.0),
	float3( 0.0, -1.0,  2.0),
	float3( 1.0, -1.0, -1.0)
};

static const float3 sobel_edge_kernel_x[6] =
{
	float3(-1.0,  1.0,  1.0),
	float3( 1.0,  1.0, -1.0),
	float3(-1.0,  0.0,  2.0),
	float3( 1.0,  0.0, -2.0),
	float3(-1.0, -1.0,  1.0),
	float3(-1.0, -1.0, -1.0)
};

static const float3 sobel_edge_kernel_y[6] =
{
	float3(-1.0,  1.0,  1.0),
	float3( 0.0,  1.0,  2.0),
	float3( 1.0,  1.0,  1.0),
	float3(-1.0, -1.0, -1.0),
	float3( 0.0, -1.0, -2.0),
	float3( 1.0, -1.0, -1.0)
};

static const float3 sharr_edge_kernel_x[6] =
{
	float3(-1.0,  1.0,  3.0),
	float3(-1.0,  0.0,  10.0),
	float3(-1.0, -1.0,  3.0),
	float3( 1.0,  1.0, -3.0),
	float3( 1.0,  0.0, -10.0),
	float3( 1.0, -1.0, -3.0)
};

static const float3 sharr_edge_kernel_y[6] =
{
	float3(-1.0,  1.0,  3.0),
	float3( 0.0,  1.0,  10.0),
	float3( 1.0,  1.0,  3.0),
	float3(-1.0, -1.0, -3.0),
	float3( 0.0, -1.0, -10.0),
	float3( 1.0, -1.0, -3.0)
};

static const float2 box_blur_3[4] =
{
	float2(-0.5, 0.5),
	float2( 0.5, 0.5),
	float2(-0.5,-0.5),
	float2( 0.5,-0.5)
};

inline float remap(float value, float oldMin, float oldMax, float newMin, float newMax)
{
	return newMin + (value - oldMin) / (newMax - newMin) * (oldMax - oldMin);
}

inline float remap01(float value, float oldMin, float oldMax)
{
	return (value - oldMin) / (oldMax - oldMin);
}

inline float remap_from_01(float value, float newMin, float newMax)
{
	return newMin + value / (newMax - newMin);
}

inline float clamp01(float val)
{
	return clamp(val, 0, 1);
}

inline float2 clamp01(float2 vec)
{
	return clamp(vec, 0, 1);
}

inline float3 clamp01(float3 vec)
{
	return clamp(vec, 0, 1);
}

inline float4 clamp01(float4 vec)
{
	return clamp(vec, 0, 1);
}

inline float cheap_contrast(float val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float2 cheap_contrast(float2 val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float3 cheap_contrast(float3 val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float4 cheap_contrast(float4 val, float contrastF)
{
	return (val - 0.5) * contrastF + 0.5;
}

inline float sqr_magnitude(float2 vec)
{
	return dot(vec, vec);
}

inline float sqr_magnitude(float3 vec)
{
	return dot(vec, vec);
}

inline float sqr_magnitude(float4 vec)
{
	return dot(vec, vec);
}

inline float saturated_dot(float2 vec1, float2 vec2)
{
	return saturate(dot(vec1, vec2));
}

inline float saturated_dot(float3 vec1, float3 vec2)
{
	return saturate(dot(vec1, vec2));
}

inline float saturated_dot(float4 vec1, float4 vec2)
{
	return saturate(dot(vec1, vec2));
}

inline float grayscale_3(float3 col)
{
	return col.x * GRAYSCALE_3.x + col.y * GRAYSCALE_3.y + col.z * GRAYSCALE_3.z;
}

inline float grayscale(float4 col)
{
	return col.x * GRAYSCALE_3.x + col.y * GRAYSCALE_3.y + col.z * GRAYSCALE_3.z;
}

//taken from http://blog.selfshadow.com/publications/blending-in-detail/, reorient detail normal map to follow the base normal map direction
inline float3 reorient_normal_map(float3 base_normal, float3 detail_normal)
{
	float3 t = base_normal * float3(2, 2, 2) + float3(-1, -1, 0);
	float3 u = detail_normal * float3(-2, -2, 2) + float3(1, 1, -1);
	return normalize(t * dot(t, u) - u * t.z);
}

#ifndef SAMPLER_TOOLS
inline float vec_sum(float2 vec)
{
	return vec.x + vec.y;
}

inline float vec_sum(float3 vec)
{
	return vec.x + vec.y + vec.z;
}

inline float vec_sum(float4 vec)
{
	return vec.x + vec.y + vec.z + vec.w;
}
#endif

//NOTE: this function assumes coord param as a direction, thus pre-normalized
//in order to save a sqrt(x*x + y*y + z*z) instruction
//Conversion taken from https://en.wikipedia.org/wiki/Spherical_coordinate_system
float3 CartesianToSphericalCoordConversion_Direction(float3 coord)
{
	//spherical coords are espressed as radius, inclination, azimuth as x,y,z of a float3
	//since it's a direction of length 1, radius is directly setted to 1 instead of being computed
	float3 sphericalCoord = float3(1.0, 0.0, 0.0);

	sphericalCoord.y = acos(coord.z);
	sphericalCoord.z = atan2(coord.y, coord.x);

	return sphericalCoord;
}

#endif