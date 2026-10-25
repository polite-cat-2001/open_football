#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

class Match;

namespace godot {

class GpfRuntimeNode : public Node3D {
    GDCLASS(GpfRuntimeNode, Node3D)

private:
    bool runtime_ready = false;
    bool runtime_failed = false;
    bool manual_step = false;
    bool game_over_seen = false;
    double accumulator_ms = 0.0;
    unsigned long sim_time_ms = 0;
    int seed = 42;
    String data_root;
    String last_error;

    Match *match = nullptr;

    bool start_runtime();
    void step_one_tick();
    void put_frame(unsigned long put_time_ms);
    Dictionary build_player(int player_id) const;

protected:
    static void _bind_methods();

public:
    GpfRuntimeNode();
    ~GpfRuntimeNode();

    void _ready() override;
    void _process(double delta) override;

    void set_data_root(const String &value);
    String get_data_root() const;
    void set_seed(int value);
    int get_seed() const;
    void set_manual_step(bool value);
    bool get_manual_step() const;
    bool is_runtime_ready() const;
    String get_last_error() const;

    void start_runtime_now();
    void step_fixed(int ticks);
    Dictionary get_snapshot() const;
    Dictionary get_player_pose(int player_id) const;
    Array get_player_ids() const;
    int get_human_player_id() const;
    void select_player(int player_id);
    void start_open_play(int player_id);
    int get_tick() const;
    void set_button(int index, bool pressed);
    void set_move(double x, double y);

    // Debug/test hooks. Positions and momentum are in the original C++ (raw) space:
    // raw X = pitch length, raw Y = pitch width, raw Z = up.
    void debug_set_ball(const Vector3 &position, const Vector3 &momentum);
    void debug_set_last_touch_team(int team_id);
};

} // namespace godot
