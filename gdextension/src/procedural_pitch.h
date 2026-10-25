#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/templates/vector.hpp>

namespace godot {

// Constants (mirrors GDScript FootballConstants autoload)
namespace PitchConstants {
    const float ALPHA_SCISSOR_THRESHOLD = 0.12f;
    const int PITCH_LENGTH = 105;
    const int PITCH_WIDTH = 68;
    const float NOISE_SCALE = 10.0f;
    const float NOISE_INTENSITY = 0.1f;
    const int NOISE_SEED = 42;
    const int LINE_THICKNESS = 1;
    const float BASE_GREEN_R = 0.2f;
    const float BASE_GREEN_G = 0.5f;
    const float BASE_GREEN_B = 0.15f;
}

class ProceduralPitch {
public:
    static Ref<Image> generate(int width = 2048, int height = 2048);
    
private:
    static float perlin(float x, float y, int seed = 0);
    static float fade(float t);
    static float lerp(float a, float b, float t);
    static float grad(int hash, float x, float y);
};

} // namespace godot
