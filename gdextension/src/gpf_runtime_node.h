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
    bool ended_in_regular_time = false;
    bool phase_break_pending = false;
    int phase_break_next_phase = 0;
    int last_match_phase = 0;
    bool human_control = true;
    float match_duration = 1.0f;
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
    void set_human_control(bool value);
    bool get_human_control() const;
    void set_match_duration(float value);
    float get_match_duration() const;
    bool is_runtime_ready() const;
    String get_last_error() const;

    void start_runtime_now();
    void step_fixed(int ticks);
    Dictionary get_snapshot() const;
    Dictionary get_player_pose(int player_id) const;
    Array get_player_ids() const;
    int get_human_player_id() const;
    int get_human_team_id() const;
    void select_player(int player_id);
    void start_open_play(int player_id);
    bool begin_phase_break();
    void continue_after_phase_break();
    bool is_set_piece_taker_menu_available() const;
    bool is_set_piece_taker_menu_open() const;
    bool open_set_piece_taker_menu();
    void close_set_piece_taker_menu();
    void request_set_piece_taker(int player_id);
    Array get_set_piece_taker_candidates() const;
    int get_tick() const;
    void set_button(int index, bool pressed);
    void set_move(double x, double y);

    // Debug/test hooks. Positions and momentum are in the original C++ (raw) space:
    // raw X = pitch length, raw Y = pitch width, raw Z = up.
    void debug_set_ball(const Vector3 &position, const Vector3 &momentum);
    void debug_set_last_touch_team(int team_id);
    void debug_force_set_piece(int set_piece_type, int team_id);
    void debug_force_phase_break(int next_phase);
    void debug_force_game_over();
};

} // namespace godot
