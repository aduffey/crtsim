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

// Half (+1) of the coefficients of a Type I FIR filter that low passes at 0.6MHz.
const float[16] LP_COEFFS1 = float[16](
    2.528743304e-05,
    1.981118350e-04,
    7.091440156e-04,
    1.822671466e-03,
    3.873263275e-03,
    7.230520334e-03,
    1.223114325e-02,
    1.908867741e-02,
    2.780094775e-02,
    3.808020190e-02,
    4.932931453e-02,
    6.067887129e-02,
    7.108634513e-02,
    7.948327299e-02,
    8.494338907e-02,
    8.683767662e-02
);

// Hamming
const float[17] LP_COEFFS2 = float[17](
    9.329808753e-05,
    5.405492348e-04,
    1.318402470e-03,
    2.710789589e-03,
    4.985624987e-03,
    8.355812597e-03,
    1.294387967e-02,
    1.875488234e-02,
    2.566139223e-02,
    3.340303109e-02,
    4.160132833e-02,
    4.978884084e-02,
    5.744972279e-02,
    6.406748647e-02,
    6.917473908e-02,
    7.239934103e-02,
    7.350175833e-02
);

// Lanczos
const float[16] LP_COEFFS3 = float[16](
    3.766670767e-04,
    1.491365396e-03,
    3.500460923e-03,
    6.511924239e-03,
    1.056904435e-02,
    1.563867410e-02,
    2.160550292e-02,
    2.827332908e-02,
    3.537365288e-02,
    4.258120026e-02,
    4.953528594e-02,
    5.586531141e-02,
    6.121823352e-02,
    6.528558483e-02,
    6.782760986e-02,
    6.869230644e-02
);

// Hann
const float[33] LP_COEFFS4 = float[33](
    -0.000000000e+00,
    -7.015212513e-06,
    -4.690844401e-05,
    -1.463823747e-04,
    -3.269444862e-04,
    -6.011529669e-04,
    -9.693000270e-04,
    -1.416850051e-03,
    -1.912907448e-03,
    -2.409923245e-03,
    -2.844764560e-03,
    -3.141172987e-03,
    -3.213533450e-03,
    -2.971771981e-03,
    -2.327106803e-03,
    -1.198299395e-03,
    4.820029666e-04,
    2.761269471e-03,
    5.661866737e-03,
    9.177019067e-03,
    1.326828584e-02,
    1.786480537e-02,
    2.286444606e-02,
    2.813688373e-02,
    3.352849806e-02,
    3.886885821e-02,
    4.397845796e-02,
    4.867727108e-02,
    5.279363483e-02,
    5.617293826e-02,
    5.868559480e-02,
    6.023381575e-02,
    6.075677049e-02
);

// blackman 0.8MHz
const float[13] LP_COEFFS5 = float[13](
    9.331585071e-06,
    2.652784909e-04,
    1.260344128e-03,
    3.725553627e-03,
    8.571971938e-03,
    1.667434874e-02,
    2.853048789e-02,
    4.390723697e-02,
    6.162341044e-02,
    7.959657445e-02,
    9.519649621e-02,
    1.058334506e-01,
    1.096110299e-01
);

// lanczos 1.1MHz
const float[8] LP_COEFFS = float[8](
    4.553361615e-03,
    1.584799805e-02,
    3.438364298e-02,
    5.864825674e-02,
    8.517470046e-02,
    1.092467811e-01,
    1.260809751e-01,
    1.321285678e-01
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
        iq += coeff * texelFetch(Source, texel_loc + ivec2(i, 0), 0).gb;
    }

    float composite = texelFetch(Source, texel_loc, 0).r;
    float carrier = chroma_carrier(vTexCoord.x, texel_loc.y, params.FrameCount, params.OriginalSize, params.System);
    float luma = composite - iq.r * cos(carrier) - iq.g * sin(carrier);

    FragColor.rgb = yiq_to_linear(vec3(luma, iq.r, iq.g));
}
