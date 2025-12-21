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

float lanczos3(float x) {
    // We don't need to check the outer bounds, just don't call with x > 3
    if (x == 0.0) {
        return 1;
    }
    // TODO or x = PI * x; return (sin(x) * sin(x / 3.0)) / (x * x); ?
    return (sin(PI * x) * sin(PI / 3.0 * x)) / (PI * PI * x * x);
}

float lanczos3_interpolate(vec2 coord, sampler2D Source, vec4 SourceSize) {
    // When we look backwards or forwards 227.5 chroma subcarrier periods for
    // our comb filter, we may end up between samples on the previous or next
    // line. If we just use simple hardware bilinear sampling, we end up with
    // aliasing that looks like the chroma subcarrier contaminating the luma.
    // One option to fix this would be to use a higher sampling rate, but the
    // more efficient option is to use a better interpolation method.
    //
    // We can use a Lanczos kernel with a = 3. We only need to interpolate on
    // the horizontal axis.
    float texel_coord = coord.x * SourceSize.x;
	float texel_floor = floor(texel_coord - 0.5);
	float f = (texel_floor + 0.5) - texel_coord;
    float center = (texel_floor + 0.5) * SourceSize.z;

    float result = 0.0;
    float weightSum = 0.0;

    float weight = lanczos3(f - 2.0);
    result += weight * textureLodOffset(Source, vec2(center, coord.y), 0.0, ivec2(-2, 0)).r;
    weightSum += weight;

    weight = lanczos3(f - 1.0);
    result += weight * textureLodOffset(Source, vec2(center, coord.y), 0.0, ivec2(-1, 0)).r;
    weightSum += weight;

    weight = lanczos3(f);
    result += weight * textureLodOffset(Source, vec2(center, coord.y), 0.0, ivec2(0, 0)).r;
    weightSum += weight;

    weight = lanczos3(f + 1.0);
    result += weight * textureLodOffset(Source, vec2(center, coord.y), 0.0, ivec2(1, 0)).r;
    weightSum += weight;

    weight = lanczos3(f + 2.0);
    result += weight * textureLodOffset(Source, vec2(center, coord.y), 0.0, ivec2(2, 0)).r;
    weightSum += weight;

    weight = lanczos3(f + 3.0);
    result += weight * textureLodOffset(Source, vec2(center, coord.y), 0.0, ivec2(3, 0)).r;
    weightSum += weight;

    return result / weightSum;
}

void main() {
    ivec2 texel_loc = ivec2(floor(vTexCoord * params.SourceSize.xy));
    chroma_info ci = get_chroma_info(params.System, params.OriginalSize, params.FrameCount);
    float carrier = chroma_carrier(vTexCoord.x, texel_loc.y, params.FrameCount, ci);

    float middle = texelFetch(Source, texel_loc, 0).r;

    vec2 chroma = vec2(0.0);
    if (params.FilterType < 0.5) {
        // Notch filter
        // Rather than notching and then demodulating, we will demodulate first
        // and then low pass filter.
        chroma = middle * vec2(2.0 * cos(carrier), 2.0 * sin(carrier));
    } else {
        // 3 line comb filter
        // First we need to find the positions on the previous and next lines
        // that are 227.5 chroma periods before and after the current position.
        // In standard NTSC, these would be directly above and below the
        // current position, but many consoles had non-standard line lengths.
        // We'll use the values here for our comb filter.
        float offset = (227.5 - ci.periods_per_line) / ci.periods_per_active_line;
        float upper = lanczos3_interpolate(vTexCoord + vec2(offset, params.SourceSize.w), Source, params.SourceSize);
        float lower = lanczos3_interpolate(vTexCoord - vec2(offset, params.SourceSize.w), Source, params.SourceSize);

        float combed_chroma = 0.5 * (middle - 0.5 * (upper + lower));

        chroma = combed_chroma * vec2(2.0 * cos(carrier), 2.0 * sin(carrier));
    }

    FragColor.rgb = vec3(middle, chroma.r, chroma.g);
}
