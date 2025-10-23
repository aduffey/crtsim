#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    float Bandwidth;
} params;

#pragma format R16G16B16A16_SFLOAT

#pragma parameter Bandwidth "Video bandwidth (MHz)" 4.0 0.6 6.0 0.2

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

vec3 gamma_to_linear(vec3 rgb) {
    // Floating point inaccuracies or out-of-gamut colors from the YIQ
    // to RGB transform could result in negative values, so we'll clamp
    // here to avoid NaNs.
    return pow(clamp(rgb, 0.0, 1.0), vec3(CRT_GAMMA));
}

void main() {
    vec3 L = 1.0 / (vec3(params.Bandwidth) * 52.5 * 2.0);
    vec3 filtered = low_pass(L, vTexCoord, params.SourceSize, Source);
    FragColor.rgb = gamma_to_linear(filtered);
}
