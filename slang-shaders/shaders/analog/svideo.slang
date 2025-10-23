#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    float LumaBandwidth;
    float ChromaBandwidth;
} params;

#pragma format R16G16B16A16_SFLOAT

#pragma parameter LumaBandwidth "Luma bandwidth (MHz)" 4.0 0.6 6.0 0.2
#pragma parameter ChromaBandwidth "Chroma bandwidth (MHz, each channel)" 0.8 0.6 6.0 0.2

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main() {
    gl_Position = MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;

#include "filter.inc"

#define CRT_GAMMA 2.4
// Inverse of GAMMA_YIQ_MAT from transform.slang
#define YIQ_GAMMA_MAT mat3x3(1.0, 1.0, 1.0, 0.946882217090069, -0.274787646298978, -1.108545034642032, 0.623556581986143, -0.63569107918738, 1.709006928406467)

vec3 gamma_to_linear(vec3 rgb) {
    // Floating point inaccuracies or out-of-gamut colors from the YIQ
    // to RGB transform could result in negative values, so we'll clamp
    // here to avoid NaNs.
    return pow(clamp(rgb, 0.0, 1.0), vec3(CRT_GAMMA));
}

vec3 yiq_to_linear(vec3 rgb) {
    return gamma_to_linear(YIQ_GAMMA_MAT * rgb);
}

void main() {
    vec3 L = 1.0 / (vec3(params.LumaBandwidth, params.ChromaBandwidth, params.ChromaBandwidth) * 52.5 * 2.0);
    vec3 filtered = low_pass(L, vTexCoord, params.SourceSize, Source);
    FragColor.rgb = yiq_to_linear(filtered);
}
