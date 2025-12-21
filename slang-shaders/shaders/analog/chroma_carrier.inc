// SPDX-License-Identifier: MIT

#define PI 3.141592653589793
#define CHROMA_SUBCARRIER ((315.0 / 88.0) * 1e6)

struct chroma_info {
    float periods_per_active_line;
    float periods_per_line;
    float offset_per_frame;
};

// TODO handle interlacing
//
// NOTE: The chroma phases may not be accurate in an absolute sense. We can't
// we can't really tell when the chroma clock started, so we just set 0 to be
// the first input sample. So the phase may be off by some amount. This won't
// affect the patterns that are seen, but it may affect the actual colors.
// TODO better explanation.

chroma_info chroma_info_standard() {
    // We'll just assume that the active line time is 52.5 microseconds. We
    // don't have any way to figure this out from the input, but this should
    // be pretty close.
    const float periods_per_active_line = CHROMA_SUBCARRIER * 52.5e-6;
    return chroma_info(periods_per_active_line, 227.5, 0.5);
}

chroma_info chroma_info_nes(vec4 original_size, uint frame_count) {
    // The NES master clock (MCLK) is 21477270 Hz (6 * 3579545 Hz). There are 4
    // cycles per pixel.
    //
    // A full line is usually 1364 cycles long. A line is 227.33... chroma
    // periods long.
    //
    // A field is 262 lines. So a field is 1364 / 6 * 262 = 59561.33...
    // chroma periods long. Every other field has one line that is 1360 cycles
    // long, so every other field is 1364 / 6 * 261 + 1360 / 6 = 59560.66...
    // chroma periods long. It may be possible for a game to disable this, but
    // it seems unlikely that it happened commonly (Battletoads is one
    // exception that I have seen referenced).
    //
    // Note that this is essentially the same as the SNES.
    //
    // The NES is interesting in that it generates composite video directly. To
    // truly simulate this aspect, we would need a special encoder and to use
    // an emulator with a "raw" output.
    //
    // See: https://www.nesdev.org/wiki/NTSC_video

    // TODO handle if upscaled
    float periods_per_active_line = 4.0 / 6.0 * original_size.x;
    return chroma_info(periods_per_active_line, 682.0 / 3.0, 1.0 / 3.0);
}

chroma_info chroma_info_sms(vec4 original_size) {
    // Same as Genesis in H32 mode.
    // TODO handle if upscaled
    float periods_per_active_line = 10.0 / 15.0 * original_size.x;
    return chroma_info(periods_per_active_line, 228.0, 0.0);
}

chroma_info chroma_info_genesis(vec4 original_size) {
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

    float periods_per_active_line;
    // TODO handle if upscaled
    if (original_size.x > 300) { // H40
        periods_per_active_line = 8.0 / 15.0 * original_size.x;
    } else { // H32
        periods_per_active_line = 10.0 / 15.0 * original_size.x;
    }
    return chroma_info(periods_per_active_line, 228.0, 0.0);
}

chroma_info chroma_info_snes(vec4 original_size, uint frame_count) {
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

    float periods_per_active_line;
    // TODO handle if upscaled
    if (original_size.x > 300) { // 512
        periods_per_active_line = 2.0 / 6.0 * original_size.x;
    } else { // 256
        periods_per_active_line = 4.0 / 6.0 * original_size.x;
    }
    return chroma_info(periods_per_active_line, 682.0 / 3.0, 1.0 / 3.0);
}

chroma_info chroma_info_saturn(vec4 original_size) {
    // The Saturn has 427 dots per line in 320px mode, and 455 dots per line in
    // 352px mode. The dot clock in 352px mode is 2 * subcarrier, while the dot
    // clock in 320px mode is created with a 1708/1820 divider (i.e. 61/65).
    // 640px and 704px modes double the dot clock to 61/65 * 4 * subcarrier and
    // 4 * subcarrier, respectively.
    //
    // Therefore, there are 227.5 chroma periods per line.
    //
    // There are 263 lines per field in progressive mode, so the phase flips on
    // each field.
    //
    // It's possible that, in some cases, the higher clock rate may be used
    // 320 pixels per line. In this case the Saturn may add extra border
    // padding. If it is possible, it's unclear what emulators do in this case.
    //
    // See:
    // https://wiki.console5.com/wiki/315-5746
    // https://web.archive.org/web/20151218032848/http://dreamjam.co.uk/emuviews/sat/sattech.txt
    // https://junkerhq.net/xrgb/index.php?title=Optimal_timings

    float periods_per_active_line;
    // TODO handle if upscaled
    if (original_size.x < 352) { // 320px mode? TODO border?
        periods_per_active_line = 65.0 / (2.0 * 61.0) * original_size.x;
    } else if (original_size.x < 640) { // 352px mode
        periods_per_active_line = original_size.x / 2.0;
    } else if (original_size.x < 704) { // 640px mode TODO border?
        periods_per_active_line = 65.0 / (4.0 * 61.0) * original_size.x;
    } else { // 704px mode
        periods_per_active_line = original_size.x / 4.0;
    }
    return chroma_info(periods_per_active_line, 227.5, 0.5);
}

chroma_info chroma_info_psx() {
    // The PSX timings are not entirely clear, and different hardware revisions
    // derived the clocks differently. What follows is some conjecture and
    // estimation that may result in something close enough.
    //
    // The earlier PSX seemed to have a video clock at 15x the subcarrier
    // frequency. To achieve 227.5 subcarrier periods per line, a line would be
    // 3412.5 cycles long. This is very close to the 3413 cycles listed on the
    // page below, which seems to have some uncertainty itself. If the correct
    // value was 3413, we'd have 227.5333... chroma periods per line, which
    // would complicate things significantly. For now, let's assume the correct
    // value is 3412.5 and we have the standard NTSC line length.
    //
    // There are 263 lines per frame, so we flip the phase each frame. This
    // might give us a hint regarding the line length as well, because if the
    // line length was 227.5333..., there would be no point using 263 lines
    // instead of 262. Either way, you'd get around a quarter period offset per
    // frame instead of the standard half a period.
    //
    // Each mode uses a different divider for the dot clock:
    //
    //     256 px: /10
    //     320 px: /8
    //     368 px: /7
    //     512 px: /5
    //     640 px: /4
    //
    // All of these work out to an active line time of *around* 171 chroma
    // periods, although all are very slightly different. We'll just assume
    // that 171 is close enough.
    //
    // https://psx-spx.consoledev.net/graphicsprocessingunitgpu/#gpu-timings

    return chroma_info(171, 227.5, 0.5);
}

chroma_info chroma_info_n64() {
    // The N64 is mostly standard NTSC timings. There are 773.5 pixels per
    // line. There are 227.5 chroma periods per line. The progressive scan
    // output is 263 lines, which flips the phase every field.
    //
    // See: https://n64brew.dev/wiki/Video_Interface

    // We will assume that the input is the full 640 pixel width. The N64
    // framebuffer is always 640 pixels. This should be fine for upscaled
    // content as well, as long as the full framebuffer is used.
    float periods_per_active_line = (640 * 227.5) / 773.5;
    return chroma_info(periods_per_active_line, 227.5, 0.5);
}

chroma_info get_chroma_info(float system, vec4 original_size, uint frame_count) {
    if (system < 0.5) {
        // Standard
        return chroma_info_standard();
    } else if (system < 1.5) {
        // NES
        return chroma_info_nes(original_size, frame_count);
    } else if (system < 2.5) {
        // SMS
        return chroma_info_sms(original_size);
    } else if (system < 3.5) {
        // TurboGrafx-16
        // TODO
        // See: https://pcengine.proboards.com/thread/639/screen-resolution-setup-sprite-limits?page=2
        return chroma_info_standard();
    } else if (system < 4.5) {
        // Genesis
        return chroma_info_genesis(original_size);
    } else if (system < 5.5) {
        // SNES
        return chroma_info_snes(original_size, frame_count);
    } else if (system < 6.5) {
        // Saturn
        return chroma_info_saturn(original_size);
    } else if (system < 7.5) {
        // PS1
        return chroma_info_psx();
    } else if (system < 8.5) {
        // N64
        return chroma_info_n64();
    }
    // Default to standard
    return chroma_info_standard();
}

float chroma_carrier(float t, float line, uint frame_count, chroma_info info) {
    float position_offset = fract(info.periods_per_active_line * t);
    float line_offset = fract(info.periods_per_line) * line;
    float frame_offset = info.offset_per_frame * (frame_count % 2);
    return 2.0 * PI * (position_offset + line_offset + frame_offset);
}
