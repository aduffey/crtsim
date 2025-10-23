// SPDX-License-Identifier: MIT

#define PI 3.141592653589793

// TODO handle interlacing
//
// NOTE: The chroma phases may not be accurate in an absolute sense. We can't
// we can't really tell when the chroma clock started, so we just set 0 to be
// the first input sample. So the phase may be off by some amount. This won't
// affect the patterns that are seen, but it may affect the actual colors.
// TODO better explanation.

float chroma_carrier_standard(float t, float line, uint frame_count) {
    // We'll just assume that the active line time is 52.5 microseconds. We
    // don't have any way to figure this out from the input, but this should
    // be pretty close.
    const float carrier_normalized = 3579545 * 52.5e-6;
    // Chroma phase should flip every line and field (227.5 chroma periods per
    // line, 263 lines per field non-interlaced).
    return PI * (2.0 * carrier_normalized * t + mod(line, 2.0) + float(frame_count % 2));
}

float chroma_carrier_sms(float t, vec4 original_size) {
    // Same as Genesis in H32 mode.
    // TODO handle if upscaled
    float carrier_normalized = 10.0 / 15.0 * original_size.x;
    return PI * 2.0 * carrier_normalized * t;
}

float chroma_carrier_genesis(float t, vec4 original_size) {
    // The Genesis master clock (MCLK) is 53693175 Hz, and the chroma clock is
    // MCLK/15 (3579545 Hz). In H40 mode (320 pixel width), each pixel in the
    // active area is 8 cycles long[1]. In H32 mode (256 pixel width), each
    // pixel is 10 cycles long.
    //
    // In both modes, a full line is 3420 cycles long. Because 3420 % 15 == 0,
    // there is no phase offset between lines. With 262 lines per field[2],
    // there is also no phase offset between fields. When interlacing, there
    // are 262.5 lines per field. (3420 / 2) % 15 == 0, so there is no phase
    // offset between fields when interlacing, either.
    //
    // [1] Note that in the blanking area, some pixels in H40 mode are
    // different sizes. We can ignore that for our purposes.
    // [2] There are some half lines in the blanking area which add to full
    // lines.
    //
    // See: http://gendev.spritesmind.net/forum/viewtopic.php?f=2&t=3221

    float carrier_normalized;
    // TODO handle if upscaled
    if (original_size.x > 300) { // H40
        carrier_normalized = 8.0 / 15.0 * original_size.x;
    } else { // H32
        carrier_normalized = 10.0 / 15.0 * original_size.x;
    }
    return PI * 2.0 * carrier_normalized * t;
}

float chroma_carrier_snes(float t, float line, uint frame_count, vec4 original_size) {
    // The SNES master clock (MCLK) is 21477270 Hz (6 * 3579545 Hz). When
    // outputting 256 pixels, there are 4 cycles per pixel[1].
    //
    // A full line is usually 1364 cycles long. A line is 227.33... chroma
    // periods long.
    //
    // A field is 262 lines. So a field is 1364 / 6 * 262 = 59561.33...
    // chroma periods long. Every other field has one line that is 1360 cycles
    // long, so every other field is 1364 / 6 * 261 + 1360 / 6 = 59560.66...
    // chroma periods long. It may be possible for a game to disable this, but
    // it seems unlikely that it happened commonly.
    //
    // [1] Note that two pixels (outside the active area) are actually 6 cycles
    // long.
    //
    // See: https://wiki.superfamicom.org/timing

    float carrier_normalized;
    // TODO handle if upscaled
    if (original_size.x > 300) { // 512
        carrier_normalized = 2.0 / 6.0 * original_size.x;
    } else { // 256
        carrier_normalized = 4.0 / 6.0 * original_size.x;
    }
    return PI * (2.0 * carrier_normalized * t + 2.0 / 3.0 * mod(float(line), 3.0) + 2.0 / 3.0 * float(params.FrameCount % 2 + 1));
}

float chroma_carrier_n64(float t, float line, uint frame_count) {
    // The N64 is mostly standard NTSC timings. There are 773.5 pixels per
    // line. There are 227.5 chroma periods per line. The progressive scan
    // output is 263 lines, which flips the phase every field.
    //
    // See: https://n64brew.dev/wiki/Video_Interface

    // We will assume that the input is the full 640 pixel width. The N64
    // framebuffer is always 640 pixels. This should be fine for upscaled
    // content as well, as long as the full framebuffer is used.
    float carrier_normalized = (640 * 227.5) / 773.5;
    return PI * (2.0 * carrier_normalized * t + mod(line, 2.0) + float(frame_count % 2));
}

float chroma_carrier(float t, float line, uint frame_count, vec4 original_size, float system) {
    if (system < 0.5) {
        // Standard
        return chroma_carrier_standard(t, line, frame_count);
    } else if (system < 1.5) {
        // C64
        // TODO
        return chroma_carrier_standard(t, line, frame_count);
    } else if (system < 2.5) {
        // NES
        // TODO
        // This one is complicated...
        return chroma_carrier_standard(t, line, frame_count);
    } else if (system < 3.5) {
        // SMS
        return chroma_carrier_sms(t, original_size);
    } else if (system < 4.5) {
        // TurboGrafx-16
        // TODO
        // See: https://pcengine.proboards.com/thread/639/screen-resolution-setup-sprite-limits?page=2
        return chroma_carrier_standard(t, line, frame_count);
    } else if (system < 5.5) {
        // Genesis
        return chroma_carrier_genesis(t, original_size);
    } else if (system < 6.5) {
        // SNES
        return chroma_carrier_snes(t, line, frame_count, original_size);
    } else if (system < 7.5) {
        // Saturn
        // TODO
        return chroma_carrier_standard(t, line, frame_count);
    } else if (system < 8.5) {
        // PS1
        // TODO
        // See: https://problemkaputt.de/psx-spx.htm#gputimings
        // https://psx-spx.consoledev.net/graphicsprocessingunitgpu/#gpu-timings
        return chroma_carrier_standard(t, line, frame_count);
    } else if (system < 9.5) {
        // N64
        return chroma_carrier_n64(t, line, frame_count);
    }
}
