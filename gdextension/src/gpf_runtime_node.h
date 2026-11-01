#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <boost/shared_ptr.hpp>

#include <map>
#include <vector>

#include "data/teamdata.hpp"
#include "onthepitch/net/netsim.hpp"

class Match;
class Player;
class NetServer;
class NetClient;

namespace godot {

class GpfRuntimeNode : public Node3D {
    GDCLASS(GpfRuntimeNode, Node3D)

private:
    bool runtime_ready = false;
    bool runtime_failed = false;
    bool manual_step = false;
    // Menu/LAN sessions start the runtime without a match: the lobby needs the
    // original MenuTask/NetServer before a package exists.
    bool auto_start_match = true;
    bool game_over_seen = false;
    bool ended_in_regular_time = false;
    bool phase_break_pending = false;
    int phase_break_next_phase = 0;
    bool park_opponents = false;
    bool replay_active = false;
    bool replay_moment_pending = false;
    int last_match_phase = 0;
    bool human_control = true;
    float match_duration = 1.0f;
    double accumulator_ms = 0.0;
    unsigned long sim_time_ms = 0;
    int seed = 42;
    String data_root;
    String last_error;

    // Shell-built match package (teams, players, final stats, formation). The
    // match is built from this; the C++ side does not read the database.
    bool match_package_ready = false;
    TeamDataRaw match_package[2];
    // Designated team roles (captain / set-piece takers), by starting slot.
    // Parsed from the shell package and applied to MatchData before the match.
    int package_roles[2][6];
    float package_duration = 1.0f;
    float package_difficulty = 0.8f;

    // Shell-owned controller setup. The shell (Godot) enumerates its input devices,
    // registers gamepads here and routes their raw buttons/axes. C++ keeps the
    // mapping from side to device and hands it to the original Match as
    // SideSelection entries. Gamepads are extension-owned SDL virtual joysticks,
    // so the original GameplayFootball checkout stays unmodified.
    struct ShellController {
        int side = -1;              // -1 home, +1 away
        bool keyboard = true;
        int slot = -1;              // SDL virtual joystick id (0 = keyboard)
        unsigned int stable_id = 0; // SideSelection.joystickID (0 = keyboard)
    };
    std::vector<ShellController> shell_controllers;
    std::map<int, int> gamepad_virtual_ids; // Godot device id -> SDL virtual joystick id

    Match *match = nullptr;

    // LAN session. The original MenuTask owns the pointers the C++ runtime
    // checks; this node holds the same objects so the Godot shell can drive the
    // lobby before and during a match.
    boost::shared_ptr<NetServer> net_server;
    boost::shared_ptr<NetClient> net_client;

    netsim::Net goal_nets[2];
    netsim::Params goal_net_params;
    blunted::Vector3 goal_net_prev_ball;
    unsigned long goal_net_prev_time_ms = 0;
    bool goal_nets_ready = false;

    bool start_runtime();
    void step_one_tick();
    void put_frame(unsigned long put_time_ms);
    void update_goal_nets(unsigned long put_time_ms);
    Dictionary build_player(int player_id) const;
    // Host: the team's HumanGamer selection. Thin client: the player the host
    // snapshot marks as owned by this peer (remoteOwnerId).
    bool is_local_human_player(Player *player) const;
    int player_owner_id(Player *player, int team_id) const;
    void apply_controller_setup();

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
    void set_auto_start_match(bool value);
    bool get_auto_start_match() const;
    void set_human_control(bool value);
    bool get_human_control() const;
    void set_match_duration(float value);
    float get_match_duration() const;
    bool is_runtime_ready() const;
    String get_last_error() const;

    void start_runtime_now();
    bool start_match();
    void stop_match();
    bool restart_match();
    bool set_match_package(const Dictionary &package);
    bool has_match_package() const;

    // LAN session (ticket 18). Host/join start the original NetServer/NetClient
    // and install them into MenuTask; the lobby itself is host-authoritative C++.
    bool net_host(int port, const String &name);
    bool net_join(const String &address, int port, const String &name);
    bool net_leave();
    Dictionary net_lobby() const;
    // An e_NetLobbyAction type (int) or its name ("set_side", "set_ready", ...).
    bool net_action(const Variant &action_type, int side, int value, int value2);
    // Host only: broadcast the lobby's teams, then build and start the match.
    bool net_start();
    // Client only: consume the host's NetMatchSetup; {} when none is pending.
    Dictionary net_take_match_setup();
    bool is_net_active() const;
    bool is_net_host() const;
    bool is_net_client() const;

    int debug_get_scene_object_count() const;
    // Test hook: which device kind the human is actually bound to.
    String debug_human_device() const;
    Array debug_human_state() const;
    void step_fixed(int ticks);
    Dictionary get_snapshot() const;
    PackedVector3Array get_goal_net_positions(int goal) const;
    PackedInt32Array get_goal_net_edges() const;
    Ref<Image> generate_pitch_texture(int width, int height) const;
    Dictionary get_player_pose(int player_id) const;
    Array get_player_ids() const;
    Array debug_get_formation(int team_id) const;
    int get_human_player_id() const;
    Array get_human_player_ids() const;
    int get_human_team_id() const;
    void select_player(int player_id);
    void start_open_play(int player_id);
    bool toggle_debug_park_opponents();
    bool begin_phase_break();
    void continue_after_phase_break();
    // LAN break: the host and clients resume by vote; this only drops the
    // bridge's local "break pending" latch once the paused snapshot is gone.
    void clear_phase_break_pending();
    void set_replay_active(bool active);
    void pause_match();
    void resume_match();
    // Runtime substitutions (the shell decides, C++ applies at the next restart).
    bool queue_substitution(int team_id, int out_player_id, int in_player_id);
    bool cancel_substitution(int team_id, int out_slot);
    Array get_pending_substitutions() const;
    Array get_substitution_notices() const;
    int get_substitution_notice_counter() const;
    // Full squad of a team in match terms: id, name, display role, pitch
    // position, active/bench/left-pitch and pending substitution marks.
    Dictionary get_squad(int team_id) const;
    // Tactics / roles from the Game Plan screen.
    void apply_tactical_scheme(int team_id, int scheme_index);
    bool set_team_role(int team_id, int role, int slot);
    // Swap two active players' formation entries (roles + positions) without
    // counting as a substitution. Bench order is a shell-only concern.
    bool swap_squad_players(int team_id, int first_player_id, int second_player_id);
    bool is_set_piece_taker_menu_available() const;
    bool is_set_piece_taker_menu_open() const;
    bool open_set_piece_taker_menu();
    void close_set_piece_taker_menu();
    void request_set_piece_taker(int player_id);
    Array get_set_piece_taker_candidates() const;
    int get_tick() const;
    void set_button(int index, bool pressed);
    void set_move(double x, double y);

    // Shell input devices. `register_gamepad` creates an extension-owned SDL
    // virtual joystick for a Godot joypad id and returns its id (-1 if none).
    // `set_controller_setup` takes entries {side: -1|1, kind: "keyboard"|"gamepad",
    // slot: virtual joystick id}. The setup is applied at the next match
    // start/restart and re-applied on every tick.
    int register_gamepad(int godot_device_id);
    void set_controller_setup(const Array &setup);
    Array get_controller_setup() const;
    void set_gamepad_button(int slot, int button, bool pressed);
    void set_gamepad_axis(int slot, int axis, double value);

    // Debug/test hooks. Positions and momentum are in the original C++ (raw) space:
    // raw X = pitch length, raw Y = pitch width, raw Z = up.
    void debug_set_ball(const Vector3 &position, const Vector3 &momentum);
    void debug_set_last_touch_team(int team_id);
    void debug_force_set_piece(int set_piece_type, int team_id);
    // F3: start the penalty shootout series from a clean play state.
    void debug_force_shootout();
    void debug_force_phase_break(int next_phase);
    void debug_force_game_over();
};

} // namespace godot
