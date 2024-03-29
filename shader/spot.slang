#version 450

layout(set = 0, binding = 0, std140) uniform UBO
{
    mat4 MVP;
};

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float MaxSpotSize;
    float MinSpotSize;
    float OddFieldFirst;
} params;

#pragma parameter MaxSpotSize "Maximum spot size" 1.0 0.6 1.0 0.05
#pragma parameter MinSpotSize "Minimum spot size" 0.5 0.3 1.0 0.1
#pragma parameter OddFieldFirst "Interlacing - display odd field first" 0.0 0.0 1.0 1.0

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void main()
{
   gl_Position = MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(binding = 1) uniform sampler2D Source;

#define PI 3.1415926535897932384626433832795

vec3 linear_to_srgb(vec3 rgb) {
    bvec3 cutoff = lessThan(rgb, vec3(0.0031308));
    vec3 higher = vec3(1.055) * pow(rgb, vec3(1.0 / 2.4)) - vec3(0.055);
    vec3 lower = rgb * vec3(12.92);

    return mix(higher, lower, cutoff);
}

void main() {
    const float aspect_ratio = params.OutputSize.x / params.OutputSize.y;

    int lower_sample_y, upper_sample_y;
    float delta, lower_distance_y, upper_distance_y;
    // Check if we should be deinterlacing.
    if (params.SourceSize.y > 300) {
        if ((params.FrameCount + int(params.OddFieldFirst)) % 2 == 0) {
            lower_sample_y = int(ceil(vTexCoord.y * params.SourceSize.y + 0.5) * 0.5) * 2 - 2;
            upper_sample_y = int(ceil(vTexCoord.y * params.SourceSize.y + 0.5) * 0.5) * 2;
        } else {
            lower_sample_y = int(floor(vTexCoord.y * params.SourceSize.y + 0.5) * 0.5) * 2 - 1;
            upper_sample_y = int(floor(vTexCoord.y * params.SourceSize.y + 0.5) * 0.5) * 2 + 1;
        }
        // TODO 0.5 doesn't quite work with an odd number of lines. Does that ever happen?
        delta = 0.5 * aspect_ratio * params.SourceSize.y * params.SourceSize.z;
        lower_distance_y = 0.5 * ((lower_sample_y + 0.5) - vTexCoord.y * params.SourceSize.y);
        upper_distance_y = 0.5 * ((upper_sample_y + 0.5) - vTexCoord.y * params.SourceSize.y);
    } else {
        lower_sample_y = int(round(vTexCoord.y * params.SourceSize.y)) - 1;
        upper_sample_y = int(round(vTexCoord.y * params.SourceSize.y));
        delta = aspect_ratio * params.SourceSize.y * params.SourceSize.z;
        lower_distance_y = (lower_sample_y + 0.5) - vTexCoord.y * params.SourceSize.y;
        upper_distance_y = (upper_sample_y + 0.5) - vTexCoord.y * params.SourceSize.y;
    }

    vec3 value = vec3(0.0);
    for (int sample_x = int(round(vTexCoord.x * params.SourceSize.x - (params.MaxSpotSize / delta)));
             sample_x < int(round(vTexCoord.x * params.SourceSize.x + (params.MaxSpotSize / delta)));
             sample_x++) {
        vec3 lower_sample = texelFetch(Source, ivec2(sample_x, lower_sample_y), 0).rgb;
        vec3 upper_sample = texelFetch(Source, ivec2(sample_x, upper_sample_y), 0).rgb;
        // Find reciprocal of widths to save divisions later.
        vec3 lower_width_rcp = 1.0 / (params.MaxSpotSize * ((1.0 - params.MinSpotSize) * sqrt(lower_sample) + params.MinSpotSize));
        vec3 upper_width_rcp = 1.0 / (params.MaxSpotSize * ((1.0 - params.MinSpotSize) * sqrt(upper_sample) + params.MinSpotSize));
        // Distance units are *scanlines heights*, so we have to adjust x
        // distance with the aspect ratio.
        float distance_x = delta * ((sample_x + 0.5) - vTexCoord.x * params.SourceSize.x);
        vec3 lower_output = (lower_sample * lower_width_rcp * 0.25) *
            (1.0 + cos(PI * clamp(distance_x * lower_width_rcp, -1.0, 1.0))) *
            (1.0 + cos(PI * clamp(lower_distance_y * lower_width_rcp, -1.0, 1.0)));
        vec3 upper_output = (upper_sample * upper_width_rcp * 0.25) *
            (1.0 + cos(PI * clamp(distance_x * upper_width_rcp, -1.0, 1.0))) *
            (1.0 + cos(PI * clamp(upper_distance_y * upper_width_rcp, -1.0, 1.0)));
        value += lower_output + upper_output;
    }
    // We shouldn't have any values over 1.0, but we'll clamp just in case
    // there are small floating point errors.
    FragColor = vec4(linear_to_srgb(clamp(delta * value, 0.0, 1.0)), 1.0);
}
