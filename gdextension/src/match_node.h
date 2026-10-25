#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/plane_mesh.hpp>

namespace godot {

class MatchNode : public Node3D {
    GDCLASS(MatchNode, Node3D)

private:
    MeshInstance3D *pitch_mesh = nullptr;

    void create_pitch();

protected:
    static void _bind_methods();

public:
    MatchNode();
    ~MatchNode();

    void _ready() override;
    void _process(double delta) override;
};

} // namespace godot
