#include "procedural_pitch.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <cmath>
#include <cstdlib>

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
