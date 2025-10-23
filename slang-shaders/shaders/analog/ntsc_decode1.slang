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

void main() {
    ivec2 texel_loc = ivec2(floor(vTexCoord * params.SourceSize.xy));
    float carrier = chroma_carrier(vTexCoord.x, texel_loc.y, params.FrameCount, params.OriginalSize, params.System);

    float middle = texelFetch(Source, texel_loc, 0).r;

    vec2 chroma = vec2(0.0);
    if (params.FilterType < 0.5) {
        // Notch filter
        chroma = middle * vec2(2.0 * cos(carrier), 2.0 * sin(carrier));
    } else {
        // 3 line comb filter
        // TODO line offset
        float offset = 0.0;
        // float offset = 7.5 / (8.0 * params.OriginalSize.x);  // Genesis
        // float offset = -2.0 / (6.0 * params.OriginalSize.x);  // SNES
        float upper = textureLod(Source, vTexCoord + vec2(-offset, params.SourceSize.w), 0).r;
        float lower = textureLod(Source, vTexCoord + vec2(offset, -params.SourceSize.w), 0).r;

        float combed_chroma = 0.5 * (middle - 0.5 * (upper + lower));
        chroma = combed_chroma * vec2(2.0 * cos(carrier), 2.0 * sin(carrier));
    }

    FragColor.rgb = vec3(middle, chroma.r, chroma.g);
}
