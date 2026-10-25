#include "match_node.h"
#include "procedural_pitch.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/plane_mesh.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;
using namespace PitchConstants;

MatchNode::MatchNode() {
}

MatchNode::~MatchNode() {
}

void MatchNode::_bind_methods() {
}

void MatchNode::_ready() {
    UtilityFunctions::print("MatchNode::_ready() called");
    
    // Create pitch mesh
    create_pitch();
    
    UtilityFunctions::print("MatchNode initialized successfully");
}

void MatchNode::create_pitch() {
    // Generate procedural pitch texture
    Ref<Image> pitch_image = ProceduralPitch::generate(1024, 1024);
    Ref<ImageTexture> pitch_texture;
    pitch_texture.instantiate();
    pitch_texture->set_image(pitch_image);
    
    // Create material with alpha scissor
    Ref<StandardMaterial3D> material;
    material.instantiate();
    material->set_texture(StandardMaterial3D::TEXTURE_ALBEDO, pitch_texture);
    material->set_transparency(StandardMaterial3D::TRANSPARENCY_ALPHA);
    material->set_alpha_scissor_threshold(ALPHA_SCISSOR_THRESHOLD);
    
    // A plane has clean 0..1 UVs; BoxMesh packs every face into a 1/3 UV
    // atlas, which cropped the center circle and stretched the markings.
    Ref<PlaneMesh> mesh;
    mesh.instantiate();
    mesh->set_size(Vector2(PITCH_LENGTH, PITCH_WIDTH));
    
    // Create MeshInstance3D
    pitch_mesh = memnew(MeshInstance3D);
    pitch_mesh->set_mesh(mesh);
    pitch_mesh->set_surface_override_material(0, material);
    add_child(pitch_mesh);
    
    UtilityFunctions::print("Pitch mesh created");
}

void MatchNode::_process(double delta) {
    // Empty for now - will be filled in later tickets
}
