#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    float FilterType;
    float System;
    uint FrameCount;
} params;

#pragma format R16G16B16A16_SFLOAT

#include "parameters_ntsc.inc"

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

#include "chroma_carrier.inc"

#define CRT_GAMMA 2.4
#define YIQ_GAMMA_MAT mat3x3(1.0, 1.0, 1.0, 0.946882217090069, -0.274787646298978, -1.108545034642032, 0.623556581986143, -0.63569107918738, 1.709006928406467)

const float[9] LP_COEFFS = float[9](
1.898600916e-04,
1.962144239e-03,
8.095912694e-03,
2.223355473e-02,
4.689508441e-02,
8.069356073e-02,
1.168992780e-01,
1.451214216e-01,
1.558183670e-01
);

vec3 gamma_to_linear(vec3 rgb) {
    // Floating point inaccuracies or out-of-gamut colors from the YIQ
    // to RGB transform could result in negative values, so we'll clamp
    // here to avoid NaNs.
    return pow(clamp(rgb, 0.0, 1.0), vec3(CRT_GAMMA));
}

// TODO rgb -> yiq
vec3 yiq_to_linear(vec3 rgb) {
    return gamma_to_linear(YIQ_GAMMA_MAT * rgb);
}

void main() {
    ivec2 texel_loc = ivec2(floor(vTexCoord * params.SourceSize.xy));

    vec2 iq = vec2(0.0);
    for (int i = -(LP_COEFFS.length() - 1); i <= LP_COEFFS.length() - 1; i++) {
        float coeff = LP_COEFFS[LP_COEFFS.length() - 1 - abs(i)];
        // TODO use textureLod because texelFetch is undefined outside of bounds
        iq += coeff * texelFetch(Source, texel_loc + ivec2(i, 0), 0).gb;
    }

    float composite = texelFetch(Source, texel_loc, 0).r;
    chroma_info ci = get_chroma_info(params.System, params.OriginalSize, params.FrameCount);
    float carrier = chroma_carrier(vTexCoord.x, texel_loc.y, params.FrameCount, ci);
    float luma = composite - iq.r * cos(carrier) - iq.g * sin(carrier);

    FragColor.rgb = yiq_to_linear(vec3(luma, iq.r, iq.g));
}
