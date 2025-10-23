#version 450

// SPDX-License-Identifier: MIT

layout(set = 0, binding = 0, std140) uniform UBO {
    mat4 MVP;
};

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OriginalSize;
    float LumaBandwidth;
    float ChromaBandwidth;
    float System;
    uint FrameCount;
} params;

#pragma format R16_SFLOAT

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
#include "filter.inc"

void main() {
    // TODO use line time per system
    vec3 L = 1.0 / (vec3(params.LumaBandwidth, params.ChromaBandwidth, params.ChromaBandwidth) * 52.5 * 2.0);
    vec3 filtered = low_pass(L, vTexCoord, params.SourceSize, Source);
    ivec2 texel_loc = ivec2(floor(vTexCoord * params.SourceSize.xy));
    float carrier = chroma_carrier(vTexCoord.x, texel_loc.y, params.FrameCount, params.OriginalSize, params.System);
    FragColor.r = dot(filtered, vec3(1.0, cos(carrier), sin(carrier)));
}
