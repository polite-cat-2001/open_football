#include "procedural_pitch.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <misc/perlin.h> // original flipcode Perlin used by GameplayFootball

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <vector>

using namespace godot;
using namespace PitchConstants;

float ProceduralPitch::fade(float t) {
    return t * t * t * (t * (t * 6 - 15) + 10);
}

float ProceduralPitch::lerp(float a, float b, float t) {
    return a + t * (b - a);
}

float ProceduralPitch::grad(int hash, float x, float y) {
    int h = hash & 3;
    float u = h < 2 ? x : y;
    float v = h < 2 ? y : x;
    return ((h & 1) ? -u : u) + ((h & 2) ? -v : v);
}

float ProceduralPitch::perlin(float x, float y, int seed) {
    int xi = (int)floor(x) & 255;
    int yi = (int)floor(y) & 255;
    float xf = x - floor(x);
    float yf = y - floor(y);

    float u = fade(xf);
    float v = fade(yf);

    int aa = (xi + yi * 57 + seed) & 255;
    int ab = (xi + (yi + 1) * 57 + seed) & 255;
    int ba = ((xi + 1) + yi * 57 + seed) & 255;
    int bb = ((xi + 1) + (yi + 1) * 57 + seed) & 255;

    float x1 = lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u);
    float x2 = lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u);

    return lerp(x1, x2, v);
}

Ref<Image> ProceduralPitch::generate(int width, int height) {
    PackedByteArray data;
    data.resize(width * height * 4);

    Color base_green(BASE_GREEN_R, BASE_GREEN_G, BASE_GREEN_B, 1.0f);
    float stripe_width = width / 20.0f;
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            float nx = (float)x / width;
            float ny = (float)y / height;
            float stripe = fmod((float)x, stripe_width * 2.0f) < stripe_width ? 0.9f : 1.0f;
            float noise = perlin(nx * NOISE_SCALE, ny * NOISE_SCALE, NOISE_SEED) * NOISE_INTENSITY + 1.0f;
            Color pixel = base_green;
            pixel.r *= stripe * noise;
            pixel.g *= stripe * noise;
            pixel.b *= stripe * noise;
            int idx = (y * width + x) * 4;
            data[idx + 0] = (uint8_t)(pixel.r * 255);
            data[idx + 1] = (uint8_t)(pixel.g * 255);
            data[idx + 2] = (uint8_t)(pixel.b * 255);
            data[idx + 3] = 255;
        }
    }

    const float px_per_m = (float)width / 120.0f;
    const float half_line_px = 0.06f * px_per_m;
    auto px_x = [&](float raw_x) {
        return (raw_x + 60.0f) * (float)width / 120.0f;
    };
    auto px_y = [&](float raw_y) {
        return (40.0f - raw_y) * (float)height / 80.0f;
    };
    auto clamp01 = [](float value) {
        return std::min(1.0f, std::max(0.0f, value));
    };
    auto blend_white = [&](int x, int y, float alpha) {
        if (alpha <= 0.0f || x < 0 || x >= width || y < 0 || y >= height) {
            return;
        }
        int idx = (y * width + x) * 4;
        for (int channel = 0; channel < 3; channel++) {
            float current = (float)data[idx + channel];
            data[idx + channel] = (uint8_t)lrintf(current * (1.0f - alpha) + 255.0f * alpha);
        }
        data[idx + 3] = 255;
    };
    auto draw_segment = [&](float ax, float ay, float bx, float by) {
        float x0 = px_x(ax);
        float y0 = px_y(ay);
        float x1 = px_x(bx);
        float y1 = px_y(by);
        float abx = x1 - x0;
        float aby = y1 - y0;
        float len_sq = abx * abx + aby * aby;
        int min_x = std::max(0, (int)floorf(std::min(x0, x1) - half_line_px - 1.0f));
        int max_x = std::min(width - 1, (int)ceilf(std::max(x0, x1) + half_line_px + 1.0f));
        int min_y = std::max(0, (int)floorf(std::min(y0, y1) - half_line_px - 1.0f));
        int max_y = std::min(height - 1, (int)ceilf(std::max(y0, y1) + half_line_px + 1.0f));
        for (int y = min_y; y <= max_y; y++) {
            for (int x = min_x; x <= max_x; x++) {
                float px = (float)x + 0.5f;
                float py = (float)y + 0.5f;
                float t = len_sq > 0.0001f
                        ? ((px - x0) * abx + (py - y0) * aby) / len_sq
                        : 0.0f;
                t = std::min(1.0f, std::max(0.0f, t));
                float dx = px - (x0 + abx * t);
                float dy = py - (y0 + aby * t);
                float dist = sqrtf(dx * dx + dy * dy);
                blend_white(x, y, clamp01(half_line_px + 0.5f - dist));
            }
        }
    };
    auto draw_arc = [&](float raw_cx, float raw_cy, float radius_m, int quadrant_x, int quadrant_y) {
        float cx = px_x(raw_cx);
        float cy = px_y(raw_cy);
        float radius = radius_m * px_per_m;
        int min_x = std::max(0, (int)floorf(cx - radius - half_line_px - 1.0f));
        int max_x = std::min(width - 1, (int)ceilf(cx + radius + half_line_px + 1.0f));
        int min_y = std::max(0, (int)floorf(cy - radius - half_line_px - 1.0f));
        int max_y = std::min(height - 1, (int)ceilf(cy + radius + half_line_px + 1.0f));
        for (int y = min_y; y <= max_y; y++) {
            for (int x = min_x; x <= max_x; x++) {
                float px = (float)x + 0.5f;
                float py = (float)y + 0.5f;
                if ((quadrant_x > 0 && px < cx) || (quadrant_x < 0 && px > cx)
                        || (quadrant_y > 0 && py < cy) || (quadrant_y < 0 && py > cy)) {
                    continue;
                }
                float dx = px - cx;
                float dy = py - cy;
                float dist = fabsf(sqrtf(dx * dx + dy * dy) - radius);
                blend_white(x, y, clamp01(half_line_px + 0.5f - dist));
            }
        }
    };
    auto draw_disc = [&](float raw_cx, float raw_cy, float radius_m) {
        float cx = px_x(raw_cx);
        float cy = px_y(raw_cy);
        float radius = radius_m * px_per_m;
        int min_x = std::max(0, (int)floorf(cx - radius - 1.0f));
        int max_x = std::min(width - 1, (int)ceilf(cx + radius + 1.0f));
        int min_y = std::max(0, (int)floorf(cy - radius - 1.0f));
        int max_y = std::min(height - 1, (int)ceilf(cy + radius + 1.0f));
        for (int y = min_y; y <= max_y; y++) {
            for (int x = min_x; x <= max_x; x++) {
                float px = (float)x + 0.5f;
                float py = (float)y + 0.5f;
                float dx = px - cx;
                float dy = py - cy;
                float dist = sqrtf(dx * dx + dy * dy);
                blend_white(x, y, clamp01(radius + 0.5f - dist));
            }
        }
    };

    // The mesh is 120 x 80; the 110 x 72 playing field is inset by 5 m / 4 m.
    draw_segment(-55.0f, -36.0f, 55.0f, -36.0f);
    draw_segment(-55.0f, 36.0f, 55.0f, 36.0f);
    draw_segment(-55.0f, -36.0f, -55.0f, 36.0f);
    draw_segment(55.0f, -36.0f, 55.0f, 36.0f);
    draw_segment(0.0f, -36.0f, 0.0f, 36.0f);

    for (int side : {-1, 1}) {
        float goal_x = 55.0f * (float)side;
        float penalty_x = 38.5f * (float)side;
        float goal_area_x = 49.5f * (float)side;
        draw_segment(goal_x, 20.16f, penalty_x, 20.16f);
        draw_segment(goal_x, -20.16f, penalty_x, -20.16f);
        draw_segment(penalty_x, 20.16f, penalty_x, -20.16f);
        draw_segment(goal_x, 9.16f, goal_area_x, 9.16f);
        draw_segment(goal_x, -9.16f, goal_area_x, -9.16f);
        draw_segment(goal_area_x, 9.16f, goal_area_x, -9.16f);
        draw_disc(44.0f * (float)side, 0.0f, 0.15f);
    }

    draw_arc(0.0f, 0.0f, 9.15f, 0, 0);
    draw_disc(0.0f, 0.0f, 0.15f);

    for (int side_x : {-1, 1}) {
        for (int side_y : {-1, 1}) {
            draw_arc(55.0f * (float)side_x, 36.0f * (float)side_y, 1.0f,
                    side_x > 0 ? -1 : 1, side_y > 0 ? 1 : -1);
        }
    }

    Ref<Image> image = Image::create_from_data(width, height, false, Image::FORMAT_RGBA8, data);
    UtilityFunctions::print("ProceduralPitch: generated ", width, "x", height, " texture");
    return image;
}

// ---------------------------------------------------------------------------
// Original pitch maps, ported 1:1 from src/onthepitch/proceduralpitch.cpp
// ---------------------------------------------------------------------------

namespace {

constexpr float PITCH_PI = 3.14159265358979323846f;
constexpr float FULL_HALF_W = 60.0f; // pitchFullHalfW, including the rim
constexpr float FULL_HALF_H = 40.0f;
constexpr float HALF_W = 55.0f; // pitchHalfW, inside the lines
constexpr float HALF_H = 36.0f;
constexpr int PERLIN_W = 1600; // GeneratePitch(): perlinTexW
constexpr int PERLIN_H = 1000;
constexpr float PITCH_TEX_SCALE = 0.32f; // GetPitchDiffuseColor(): texScale

inline float pitch_clamp(float value, float lo, float hi) {
    return value < lo ? lo : (value > hi ? hi : value);
}

// blunted::NormalizedClamp (bluntmath.cpp).
inline float normalized_clamp(float value, float lo, float hi) {
    return (pitch_clamp(value, lo, hi) - lo) / (hi - lo);
}

// blunted::curve (bluntmath.hpp): linear -> sine S-curve.
inline float pitch_curve(float source, float bias = 1.0f) {
    return (std::sin((source - 0.5f) * PITCH_PI) * 0.5f + 0.5f) * bias + source * (1.0f - bias);
}

// blunted::fastrandom's LCG, kept on a local stream so pitch generation does
// not disturb the gameplay RNG.
struct PitchRandom {
    uint32_t seed;
    explicit PitchRandom(uint32_t initial) : seed(initial) {}

    float next(float lo, float hi) {
        const float t = (float)seed / 4294967295.0f;
        seed = 214013u * seed + 2531011u;
        return t * (hi - lo) + lo;
    }
};

struct RgbaSample {
    float r, g, b, a;
};

// BilinearSample(): the original wraps x2/y2 through the texture size.
inline RgbaSample sample_rgba(const uint8_t *tex, int w, int h, float x, float y) {
    const float cx = pitch_clamp(x, 0.0f, (float)w - 0.001f);
    const float cy = pitch_clamp(y, 0.0f, (float)h - 0.001f);
    const int x0 = (int)cx;
    const int y0 = (int)cy;
    const int x1 = (x0 + 1) % w;
    const int y1 = (y0 + 1) % h;
    const float bx = cx - (float)x0;
    const float by = cy - (float)y0;
    const uint8_t *p00 = tex + ((size_t)y0 * w + x0) * 4;
    const uint8_t *p10 = tex + ((size_t)y0 * w + x1) * 4;
    const uint8_t *p01 = tex + ((size_t)y1 * w + x0) * 4;
    const uint8_t *p11 = tex + ((size_t)y1 * w + x1) * 4;
    RgbaSample out;
    out.r = (p00[0] * (1.0f - bx) + p10[0] * bx) * (1.0f - by) + (p01[0] * (1.0f - bx) + p11[0] * bx) * by;
    out.g = (p00[1] * (1.0f - bx) + p10[1] * bx) * (1.0f - by) + (p01[1] * (1.0f - bx) + p11[1] * bx) * by;
    out.b = (p00[2] * (1.0f - bx) + p10[2] * bx) * (1.0f - by) + (p01[2] * (1.0f - bx) + p11[2] * bx) * by;
    out.a = (p00[3] * (1.0f - bx) + p10[3] * bx) * (1.0f - by) + (p01[3] * (1.0f - bx) + p11[3] * bx) * by;
    return out;
}

inline float sample_channel(const std::vector<float> &tex, int w, int h, float x, float y) {
    const float cx = pitch_clamp(x, 0.0f, (float)w - 0.001f);
    const float cy = pitch_clamp(y, 0.0f, (float)h - 0.001f);
    const int x0 = (int)cx;
    const int y0 = (int)cy;
    const int x1 = (x0 + 1) % w;
    const int y1 = (y0 + 1) % h;
    const float bx = cx - (float)x0;
    const float by = cy - (float)y0;
    const float x1y1 = tex[(size_t)y0 * w + x0];
    const float x2y1 = tex[(size_t)y0 * w + x1];
    const float x1y2 = tex[(size_t)y1 * w + x0];
    const float x2y2 = tex[(size_t)y1 * w + x1];
    return (x1y1 * (1.0f - bx) + x2y1 * bx) * (1.0f - by) + (x1y2 * (1.0f - bx) + x2y2 * bx) * by;
}

// GetPitchDiffuseColor()/GetPitchSpecularColor(): sample the 1600x1000 perlin
// texture with the original +-2.5 px random spread.
inline float sample_perlin(const std::vector<float> &tex, float u, float v, PitchRandom &random) {
    const float x = pitch_clamp(u * PERLIN_W + random.next(-1.0f, 1.0f) * 2.5f, 0.0f, (float)PERLIN_W - 1.0f);
    const float y = pitch_clamp(v * PERLIN_H + random.next(-1.0f, 1.0f) * 2.5f, 0.0f, (float)PERLIN_H - 1.0f);
    return sample_channel(tex, PERLIN_W, PERLIN_H, x, y);
}

std::vector<float> build_perlin_texture() {
    const int seed = (int)std::time(nullptr);
    Perlin perlin_low(4, 0.06f * 0.06f, 0.5f, seed); // low freq
    Perlin perlin_mid(4, 0.14f * 0.06f, 0.5f, seed + 139882); // mid freq

    const float noise_factor = 0.15f; // 'random grid of canals'
    const float sin_scale = 4.0f; // smaller is larger (heh)
    std::vector<float> ynoise(PERLIN_H);
    for (int y = 0; y < PERLIN_H; y++) {
        ynoise[y] = (std::sin(y / (float)PERLIN_H * 13 * sin_scale) +
                     std::sin(y / (float)PERLIN_H * 43 * sin_scale) +
                     std::sin(y / (float)PERLIN_H * 107 * sin_scale) +
                     std::sin(y / (float)PERLIN_H * 245 * sin_scale)) * 0.25f;
    }

    std::vector<float> tex((size_t)PERLIN_W * PERLIN_H);
    for (int x = 0; x < PERLIN_W; x++) {
        const float xnoise = (std::sin(x / (float)PERLIN_W * 15 * sin_scale) +
                              std::sin(x / (float)PERLIN_W * 41 * sin_scale) +
                              std::sin(x / (float)PERLIN_W * 109 * sin_scale) +
                              std::sin(x / (float)PERLIN_W * 241 * sin_scale)) * 0.25f;
        for (int y = 0; y < PERLIN_H; y++) {
            float noise = xnoise * 0.65f + ynoise[y] * 0.35f;
            noise = pitch_curve(noise * 0.5f + 0.5f, 0.4f) * 2.0f - 1.0f; // compress
            float value = perlin_low.Get((float)x, (float)y) * 0.4f +
                          perlin_mid.Get((float)x, (float)y) * 0.6f;
            value = value * 1.7f + 0.5f; // expand a bit
            value += (normalized_clamp(noise, -0.9f, 0.9f) * 2.0f - 1.0f) * noise_factor;
            value = pitch_clamp(value, 0.2f, 0.8f);
            tex[(size_t)y * PERLIN_W + x] = pitch_curve(value, 0.4f);
        }
    }
    return tex;
}

// GetSmoothGrassDirection(): fractional part of coord/repeat through a sharply
// curved sine, returning -1..1 over two bands.
float smooth_grass_direction(float coord, float repeat, int sharpness) {
    const float iteration = std::floor(coord / repeat);
    float bias = coord - repeat * iteration;
    bias = std::sin(bias * 2.0f * PITCH_PI) * 0.5f + 0.5f;
    for (int i = 0; i < sharpness; i++) {
        bias = pitch_curve(bias, 1.0f);
    }
    return bias * 2.0f - 1.0f;
}

Ref<Image> as_rgba8(const Ref<Image> &source) {
    if (source.is_null() || source->is_empty()) {
        return Ref<Image>();
    }
    if (source->get_format() == Image::FORMAT_RGBA8) {
        return source;
    }
    Ref<Image> converted = Image::create_from_data(source->get_width(), source->get_height(),
            false, source->get_format(), source->get_data());
    converted->convert(Image::FORMAT_RGBA8);
    return converted;
}

Ref<Image> build_albedo(int width, int height, const Ref<Image> &grass, const Ref<Image> &overlay,
        const std::vector<float> &perlin_tex) {
    const int grass_w = grass->get_width();
    const int grass_h = grass->get_height();
    const int overlay_w = overlay->get_width();
    const int overlay_h = overlay->get_height();
    const PackedByteArray grass_data = grass->get_data();
    const PackedByteArray overlay_data = overlay->get_data();
    const uint8_t *grass_pixels = grass_data.ptr();
    const uint8_t *overlay_pixels = overlay_data.ptr();

    PackedByteArray pixels;
    pixels.resize(width * height * 4);
    uint8_t *out = pixels.ptrw();

    // graphics_pitchredtoblueratio defaults to 0.5, contrast to 0.4, brightness to 2.
    const float base_r = (35.0f - 0.4f * 10.0f) * 2.0f; // 62
    const float base_g = 46.0f * 2.0f; // 92
    const float base_b = (25.0f - 0.4f * 10.0f) * 2.0f; // 42
    PitchRandom random((uint32_t)std::time(nullptr) ^ 0x9e3779b9u);

    for (int py = 0; py < height; py++) {
        const float v = (py + 0.5f) / height;
        const float raw_y = FULL_HALF_H - v * (FULL_HALF_H * 2.0f);
        const float grass_y = std::fmod(v * grass_h * 12.0f * PITCH_TEX_SCALE, (float)grass_h);
        const float overlay_y = v * (float)overlay_h;
        const float ao_y = raw_y / HALF_H;
        for (int px = 0; px < width; px++) {
            const float u = (px + 0.5f) / width;
            const float raw_x = u * (FULL_HALF_W * 2.0f) - FULL_HALF_W;
            const float grass_x = std::fmod(u * grass_w * 18.0f * PITCH_TEX_SCALE, (float)grass_w);

            const RgbaSample tile = sample_rgba(grass_pixels, grass_w, grass_h, grass_x, grass_y);
            float r = base_r * 0.7f + tile.r * 0.3f; // texMultiplier 0.3
            float g = base_g * 0.7f + tile.g * 0.3f;
            float b = base_b * 0.7f + tile.b * 0.3f;

            const float noise = sample_perlin(perlin_tex, u, v, random) - 0.5f;
            r += noise * 0.4f * 40.0f; // perlinNoiseMultiplier
            g += noise * 0.4f * 40.0f;
            b += noise * 0.4f * 40.0f;

            // fake ambient occlusion
            const float ao_len = std::sqrt((raw_x / HALF_W) * (raw_x / HALF_W) + ao_y * ao_y);
            const float ao = pitch_clamp(ao_len * 0.7f, 0.0f, 1.0f);
            const float darkness = 1.0f - ao * std::sqrt(ao) * 0.18f; // pow(ao, 1.5)
            r *= darkness;
            g *= darkness;
            b *= darkness;

            const RgbaSample line = sample_rgba(overlay_pixels, overlay_w, overlay_h,
                    u * (float)overlay_w, overlay_y);
            const float alpha = line.a / 256.0f;
            r = pitch_clamp(r * (1.0f - alpha) + line.r * alpha, 0.0f, 255.0f);
            g = pitch_clamp(g * (1.0f - alpha) + line.g * alpha, 0.0f, 255.0f);
            b = pitch_clamp(b * (1.0f - alpha) + line.b * alpha, 0.0f, 255.0f);

            const int idx = (py * width + px) * 4;
            out[idx + 0] = (uint8_t)r;
            out[idx + 1] = (uint8_t)g;
            out[idx + 2] = (uint8_t)b;
            out[idx + 3] = 255;
        }
    }
    return Image::create_from_data(width, height, false, Image::FORMAT_RGBA8, pixels);
}

// GetPitchNormalColor(): the mow stripes live in the normal map only.
Ref<Image> build_normal(int width, int height) {
    // The original rolls the mow width every match: 11 m or 5.5 m bands, with
    // sharper transitions on the wide ones (proceduralpitch.cpp:455). F7 re-calls
    // this and gets a fresh roll.
    PitchRandom band_random((uint32_t)std::time(nullptr) ^ 0x2f6e2b1u);
    const float repeat_multiplier = band_random.next(0.0f, 1.0f) > 0.5f ? 1.0f : 0.5f;
    const float repeat = 11.0f * repeat_multiplier;
    const int sharpness = repeat_multiplier > 0.75f ? 7 : 5;
    std::vector<float> stripe_x(width); // normal.y, bands along x
    std::vector<float> stripe_y(height); // normal.x, bands along y
    for (int px = 0; px < width; px++) {
        const float u = (px + 0.5f) / width;
        const float raw_x = u * (FULL_HALF_W * 2.0f) - FULL_HALF_W;
        stripe_x[px] = smooth_grass_direction(raw_x / repeat, 1.0f, sharpness) * 0.12f; // xStrength
    }
    for (int py = 0; py < height; py++) {
        const float v = (py + 0.5f) / height;
        const float raw_y = FULL_HALF_H - v * (FULL_HALF_H * 2.0f);
        stripe_y[py] = smooth_grass_direction(raw_y / repeat, 1.0f, sharpness) * 0.10f; // yStrength
    }

    PackedByteArray pixels;
    pixels.resize(width * height * 4);
    uint8_t *out = pixels.ptrw();
    const float noise = 0.06f;
    PitchRandom random((uint32_t)std::time(nullptr) ^ 0x51ed270bu);

    for (int py = 0; py < height; py++) {
        const float v = (py + 0.5f) / height;
        const float raw_y = FULL_HALF_H - v * (FULL_HALF_H * 2.0f);
        for (int px = 0; px < width; px++) {
            const float u = (px + 0.5f) / width;
            const float raw_x = u * (FULL_HALF_W * 2.0f) - FULL_HALF_W;
            const bool inside = std::fabs(raw_x) < HALF_W && std::fabs(raw_y) < HALF_H;
            float nx = inside ? stripe_y[py] : 0.0f;
            float ny = inside ? stripe_x[px] : 0.0f;
            nx += random.next(-1.0f, 1.0f) * noise; // grass grain
            ny += random.next(-1.0f, 1.0f) * noise;
            const float inv_len = 1.0f / std::sqrt(nx * nx + ny * ny + 1.0f);
            nx *= inv_len;
            ny *= inv_len;
            const float nz = inv_len;
            const int idx = (py * width + px) * 4;
            out[idx + 0] = (uint8_t)((nx * 0.5f + 0.5f) * 255.0f);
            out[idx + 1] = (uint8_t)((ny * 0.5f + 0.5f) * 255.0f);
            out[idx + 2] = (uint8_t)((nz * 0.5f + 0.5f) * 255.0f);
            out[idx + 3] = 255;
        }
    }
    return Image::create_from_data(width, height, false, Image::FORMAT_RGBA8, pixels);
}

// GetPitchSpecularColor() -> roughness. The original specular texture is only
// 2..20 of 255; the x4.5 gain keeps the perlin patches visible under PBR.
Ref<Image> build_roughness(int width, int height, const std::vector<float> &perlin_tex) {
    PackedByteArray pixels;
    pixels.resize(width * height * 4);
    uint8_t *out = pixels.ptrw();
    PitchRandom random((uint32_t)std::time(nullptr) ^ 0x2545f491u);

    for (int py = 0; py < height; py++) {
        const float v = (py + 0.5f) / height;
        for (int px = 0; px < width; px++) {
            const float u = (px + 0.5f) / width;
            const float spec = 2.0f + sample_perlin(perlin_tex, u, v, random) * 18.0f;
            const float rough = pitch_clamp(1.0f - spec * (4.5f / 255.0f), 0.0f, 1.0f);
            const uint8_t value = (uint8_t)(rough * 255.0f);
            const int idx = (py * width + px) * 4;
            out[idx + 0] = value;
            out[idx + 1] = value;
            out[idx + 2] = value;
            out[idx + 3] = 255;
        }
    }
    return Image::create_from_data(width, height, false, Image::FORMAT_RGBA8, pixels);
}

} // namespace

Dictionary ProceduralPitch::generate_maps(int width, int height, const Ref<Image> &grass,
        const Ref<Image> &overlay) {
    Dictionary maps;
    const Ref<Image> grass_image = as_rgba8(grass);
    const Ref<Image> overlay_image = as_rgba8(overlay);
    if (width <= 0 || height <= 0 || grass_image.is_null() || overlay_image.is_null()) {
        UtilityFunctions::push_error("ProceduralPitch: generate_maps needs positive sizes and both source images");
        return maps;
    }

    const std::clock_t started = std::clock();
    const std::vector<float> perlin_tex = build_perlin_texture();

    const int normal_w = std::max(1, (int)std::lround(width * 2.0 / 3.0));
    const int normal_h = std::max(1, (int)std::lround(height * 2.0 / 3.0));
    const int rough_w = std::max(1, (int)std::lround(width / 3.0));
    const int rough_h = std::max(1, (int)std::lround(height / 3.0));

    maps["albedo"] = build_albedo(width, height, grass_image, overlay_image, perlin_tex);
    maps["normal"] = build_normal(normal_w, normal_h);
    maps["roughness"] = build_roughness(rough_w, rough_h, perlin_tex);

    UtilityFunctions::print("ProceduralPitch: maps ", width, "x", height, " albedo, ",
            normal_w, "x", normal_h, " normal, ", rough_w, "x", rough_h, " roughness in ",
            (double)(std::clock() - started) / (double)CLOCKS_PER_SEC, " s");
    return maps;
}
