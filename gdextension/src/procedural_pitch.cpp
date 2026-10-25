#include "procedural_pitch.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>
#include <cstdlib>

using namespace godot;
using namespace PitchConstants;

// Perlin noise implementation (fixed hash mixing)
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
    // Fixed: proper hash mixing of x and y coordinates
    int xi = (int)floor(x) & 255;
    int yi = (int)floor(y) & 255;
    float xf = x - floor(x);
    float yf = y - floor(y);
    
    float u = fade(xf);
    float v = fade(yf);
    
    // Hash coordinates — proper 2D mixing
    int aa = (xi + yi * 57 + seed) & 255;
    int ab = (xi + (yi + 1) * 57 + seed) & 255;
    int ba = ((xi + 1) + yi * 57 + seed) & 255;
    int bb = ((xi + 1) + (yi + 1) * 57 + seed) & 255;
    
    float x1 = lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u);
    float x2 = lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u);
    
    return lerp(x1, x2, v);
}

Ref<Image> ProceduralPitch::generate(int width, int height) {
    // Create image data buffer
    PackedByteArray data;
    data.resize(width * height * 4); // RGBA
    
    // Base grass color
    Color base_green(BASE_GREEN_R, BASE_GREEN_G, BASE_GREEN_B, 1.0f);
    
    // Generate mowing stripes
    float stripe_width = width / 20.0f;
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            float nx = (float)x / width;
            float ny = (float)y / height;
            
            // Mowing stripes
            float stripe = fmod((float)x, stripe_width * 2.0f) < stripe_width ? 0.9f : 1.0f;
            
            // Perlin noise for variation
            float noise = perlin(nx * NOISE_SCALE, ny * NOISE_SCALE, NOISE_SEED) * NOISE_INTENSITY + 1.0f;
            
            // Combine
            Color pixel = base_green;
            pixel.r *= stripe * noise;
            pixel.g *= stripe * noise;
            pixel.b *= stripe * noise;
            
            // Alpha: transparent edges (fade out at borders)
            float edge_dist = 1.0f;
            int margin = width / 10;
            if (x < margin) edge_dist = (float)x / margin;
            else if (x > width - margin) edge_dist = (float)(width - x) / margin;
            if (y < margin) edge_dist = fminf(edge_dist, (float)y / margin);
            else if (y > height - margin) edge_dist = fminf(edge_dist, (float)(height - y) / margin);
            
            pixel.a = edge_dist;
            
            // Write to buffer
            int idx = (y * width + x) * 4;
            data[idx + 0] = (uint8_t)(pixel.r * 255);
            data[idx + 1] = (uint8_t)(pixel.g * 255);
            data[idx + 2] = (uint8_t)(pixel.b * 255);
            data[idx + 3] = (uint8_t)(pixel.a * 255);
        }
    }
    
    // Draw field markings (white lines)
    Color white(1.0f, 1.0f, 1.0f, 1.0f);
    
    // Center line
    int center_x = width / 2;
    for (int y = 0; y < height; y++) {
        for (int t = -LINE_THICKNESS; t <= LINE_THICKNESS; t++) {
            int x = center_x + t;
            if (x >= 0 && x < width) {
                int idx = (y * width + x) * 4;
                data[idx + 0] = 255;
                data[idx + 1] = 255;
                data[idx + 2] = 255;
                data[idx + 3] = 255;
            }
        }
    }
    
    // Center circle
    int radius = width / 10;
    int cx = width / 2;
    int cy = height / 2;
    for (int y = cy - radius; y <= cy + radius; y++) {
        for (int x = cx - radius; x <= cx + radius; x++) {
            if (x >= 0 && x < width && y >= 0 && y < height) {
                float dist = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
                if (fabs(dist - radius) < LINE_THICKNESS) {
                    int idx = (y * width + x) * 4;
                    data[idx + 0] = 255;
                    data[idx + 1] = 255;
                    data[idx + 2] = 255;
                    data[idx + 3] = 255;
                }
            }
        }
    }
    
    // Border (consolidated)
    for (int t = 0; t < LINE_THICKNESS; t++) {
        // Top and bottom
        for (int x = 0; x < width; x++) {
            int idx1 = (t * width + x) * 4;
            data[idx1 + 0] = 255;
            data[idx1 + 1] = 255;
            data[idx1 + 2] = 255;
            data[idx1 + 3] = 255;
            
            int idx2 = ((height - 1 - t) * width + x) * 4;
            data[idx2 + 0] = 255;
            data[idx2 + 1] = 255;
            data[idx2 + 2] = 255;
            data[idx2 + 3] = 255;
        }
        // Left and right
        for (int y = 0; y < height; y++) {
            int idx1 = (y * width + t) * 4;
            data[idx1 + 0] = 255;
            data[idx1 + 1] = 255;
            data[idx1 + 2] = 255;
            data[idx1 + 3] = 255;
            
            int idx2 = (y * width + (width - 1 - t)) * 4;
            data[idx2 + 0] = 255;
            data[idx2 + 1] = 255;
            data[idx2 + 2] = 255;
            data[idx2 + 3] = 255;
        }
    }
    
    // Create image from data
    Ref<Image> image = Image::create_from_data(width, height, false, Image::FORMAT_RGBA8, data);
    
    UtilityFunctions::print("ProceduralPitch: generated ", width, "x", height, " texture");
    
    return image;
}
