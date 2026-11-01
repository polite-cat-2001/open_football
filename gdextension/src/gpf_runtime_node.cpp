#include "gpf_runtime_node.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "blunted.hpp"
#include "gamecontext.hpp"
#include "gametask.hpp"
#include "hid/ihidevice.hpp"
#include "main.hpp"
#include "menu/menutask.hpp"
#include "menu/pagefactory.hpp"
#include "menu/tacticschemes.hpp"
#include "net/netbuffer.hpp"
#include "net/netclient.hpp"
#include "net/netmessages.hpp"
#include "net/netserver.hpp"
#include "data/matchdata.hpp"
#include "onthepitch/match.hpp"
#include "onthepitch/player/player.hpp"
#include "onthepitch/referee.hpp"
#include "onthepitch/setpiece/setpiecepresentation.hpp"
#include "onthepitch/team.hpp"
#include "procedural_pitch.h"
#include "scene/scene3d/scene3d.hpp"
#include "base/math/bluntmath.hpp"
#include "managers/usereventmanager.hpp"
#include "gamedefines.hpp"

#include "SDL3_ttf/SDL_ttf.h"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <list>
#include <string>
#include <vector>

using namespace godot;

namespace {

constexpr unsigned long TICK_MS = 10;

godot::Vector3 to_godot(const blunted::Vector3 &v) {
    return godot::Vector3(v.coords[0], v.coords[1], v.coords[2]);
}

godot::Quaternion to_godot(const blunted::Quaternion &q) {
    return godot::Quaternion(q.elements[0], q.elements[1], q.elements[2], q.elements[3]);
}

blunted::Vector3 goal_net_ball_to_local(int goal, const blunted::Vector3 &world) {
    return (goal == 0) ? blunted::Vector3(world.coords[1], world.coords[2], -world.coords[0] - pitchHalfW)
                       : blunted::Vector3(world.coords[1], world.coords[2],  world.coords[0] - pitchHalfW);
}

blunted::Vector3 goal_net_dir_to_local(int goal, const blunted::Vector3 &world) {
    return (goal == 0) ? blunted::Vector3(world.coords[1], world.coords[2], -world.coords[0])
                       : blunted::Vector3(world.coords[1], world.coords[2],  world.coords[0]);
}

// The Godot scene places its goals directly in scene space: +X is the raw -X goal,
// Y is up and Z is pitch width.
godot::Vector3 goal_net_local_to_scene(int goal, const blunted::Vector3 &p) {
    return (goal == 0) ? godot::Vector3(pitchHalfW + p.coords[2], p.coords[1], p.coords[0])
                       : godot::Vector3(-pitchHalfW - p.coords[2], p.coords[1], p.coords[0]);
}

bool is_nonempty_file(const std::filesystem::path &path) {
    std::error_code ec;
    return std::filesystem::is_regular_file(path, ec) && std::filesystem::file_size(path, ec) > 0;
}

Variant value_or(const Dictionary &source, const char *key, const Variant &fallback = Variant()) {
    const String name(key);
    if (source.has(name)) {
        return source[name];
    }
    return fallback;
}

std::string to_std_string(const Variant &value) {
    const String text = value;
    return std::string(text.utf8().get_data());
}

// Godot lobby screens can name the action (faithful to e_NetLobbyAction_*) or
// pass the raw enum value; tests use both.
int lobby_action_from_variant(const Variant &value) {
    if (value.get_type() == Variant::INT) {
        return (int)value;
    }
    if (value.get_type() != Variant::STRING) {
        return -1;
    }
    const String name = String(value).to_lower().replace("_", "");
    if (name == "setside") return e_NetLobbyAction_SetSide;
    if (name == "setready") return e_NetLobbyAction_SetReady;
    if (name == "movecursor") return e_NetLobbyAction_MoveCursor;
    if (name == "committeam") return e_NetLobbyAction_CommitTeam;
    if (name == "setselection") return e_NetLobbyAction_SetSelection;
    if (name == "setteamready") return e_NetLobbyAction_SetTeamReady;
    if (name == "setdevice") return e_NetLobbyAction_SetDevice;
    if (name == "devicelost") return e_NetLobbyAction_DeviceLost;
    if (name == "requestsideselect") return e_NetLobbyAction_RequestSideSelect;
    if (name == "setresumeready") return e_NetLobbyAction_SetResumeReady;
    if (name == "setmatchoptions") return e_NetLobbyAction_SetMatchOptions;
    if (name == "backtoteams") return e_NetLobbyAction_BackToTeams;
    if (name == "requestsubstitution") return e_NetLobbyAction_RequestSubstitution;
    if (name == "cancelsubstitution") return e_NetLobbyAction_CancelSubstitution;
    if (name == "planswap") return e_NetLobbyAction_PlanSwap;
    if (name == "hubvote") return e_NetLobbyAction_HubVote;
    if (name == "planscheme") return e_NetLobbyAction_PlanScheme;
    if (name == "planrole") return e_NetLobbyAction_PlanRole;
    return -1;
}

blunted::Vector3 to_blunted(const godot::Vector3 &value) {
    return blunted::Vector3((float)value.x, (float)value.y, (float)value.z);
}

blunted::Vector3 to_blunted_plane(const godot::Vector2 &value) {
    return blunted::Vector3((float)value.x, (float)value.y, 0.0f);
}

bool read_package_player(const Dictionary &source, PlayerDataRaw &player, String &error) {
    player.databaseID = (int)value_or(source, "database_id");
    player.firstName = to_std_string(value_or(source, "first_name"));
    player.lastName = to_std_string(value_or(source, "last_name"));
    player.roleString = to_std_string(value_or(source, "role"));
    player.skinColor = (int)value_or(source, "skin_color", 1);
    player.hairStyle = to_std_string(value_or(source, "hair_style", "short01"));
    player.hairColor = to_std_string(value_or(source, "hair_color", "darkblonde"));
    const double height = (double)value_or(source, "height", 1.8);
    // Same plausibility guard as the database loader: a broken height collapses
    // the fullbody model, so keep the default instead.
    player.height = (height >= 1.4 && height <= 2.3) ? (float)height : 1.8f;
    player.strongFoot = (int)value_or(source, "strong_foot", 0);
    player.tmId = (int)value_or(source, "tm_id", 0);

    const Variant stats_value = value_or(source, "stats");
    if (stats_value.get_type() != Variant::DICTIONARY) {
        error = "player " + String::num_int64(player.databaseID) + " has no stats dictionary";
        return false;
    }
    const Dictionary stats = stats_value;
    const Array keys = stats.keys();
    for (int i = 0; i < keys.size(); ++i) {
        const Variant &key = keys[i];
        player.stats[to_std_string(key)] = (float)(double)stats[key];
    }
    if (player.stats.empty()) {
        error = "player " + String::num_int64(player.databaseID) + " has no stats";
        return false;
    }
    return true;
}

bool read_package_team(const Dictionary &source, TeamDataRaw &team, String &error) {
    team.databaseID = (int)value_or(source, "database_id");
    team.name = to_std_string(value_or(source, "name"));
    team.shortName = to_std_string(value_or(source, "short_name"));
    team.logoUrl = to_std_string(value_or(source, "logo_url"));
    team.kitUrl = to_std_string(value_or(source, "kit_url"));
    team.formationXml = to_std_string(value_or(source, "formation_xml"));
    team.formationFactoryXml = to_std_string(value_or(source, "formation_factory_xml"));
    team.tacticsXml = to_std_string(value_or(source, "tactics_xml"));
    team.tacticsFactoryXml = to_std_string(value_or(source, "tactics_factory_xml"));
    team.color1 = to_blunted((godot::Vector3)value_or(source, "color1", godot::Vector3(0.0, 0.0, 0.0)));
    team.color2 = to_blunted((godot::Vector3)value_or(source, "color2", godot::Vector3(1.0, 1.0, 1.0)));

    const Variant formation_value = value_or(source, "formation");
    if (formation_value.get_type() != Variant::ARRAY) {
        error = "team " + String::num_int64(team.databaseID) + " has no formation";
        return false;
    }
    const Array formation = formation_value;
    if (formation.size() != 11) {
        error = "team " + String::num_int64(team.databaseID) + " formation must have 11 slots";
        return false;
    }
    for (int i = 0; i < formation.size(); ++i) {
        const Variant &slot_value = formation[i];
        if (slot_value.get_type() != Variant::DICTIONARY) {
            error = "team " + String::num_int64(team.databaseID) + " has a broken formation slot";
            return false;
        }
        const Dictionary slot = slot_value;
        FormationEntry entry;
        entry.role = GetRoleFromString(to_std_string(value_or(slot, "role", "CM")));
        entry.databasePosition = to_blunted_plane(
            (Vector2)value_or(slot, "database_position", Vector2(0.0, 0.0)));
        entry.position = to_blunted_plane(
            (Vector2)value_or(slot, "position", Vector2(0.0, 0.0)));
        team.formation.push_back(entry);
    }

    const Variant players_value = value_or(source, "players");
    if (players_value.get_type() != Variant::ARRAY) {
        error = "team " + String::num_int64(team.databaseID) + " has no players";
        return false;
    }
    const Array players = players_value;
    if (players.size() < 11) {
        error = "team " + String::num_int64(team.databaseID) + " has fewer than 11 players";
        return false;
    }
    for (int i = 0; i < players.size(); ++i) {
        const Variant &player_value = players[i];
        if (player_value.get_type() != Variant::DICTIONARY) {
            error = "team " + String::num_int64(team.databaseID) + " has a broken player entry";
            return false;
        }
        PlayerDataRaw player;
        if (!read_package_player(player_value, player, error)) {
            return false;
        }
        team.players.push_back(player);
    }
    return true;
}

} // namespace

GpfRuntimeNode::GpfRuntimeNode() {
}

GpfRuntimeNode::~GpfRuntimeNode() {
    // The original runtime is intentionally one-shot: do not call Exit/Shutdown.
}

void GpfRuntimeNode::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_data_root", "value"), &GpfRuntimeNode::set_data_root);
    ClassDB::bind_method(D_METHOD("get_data_root"), &GpfRuntimeNode::get_data_root);
    ClassDB::bind_method(D_METHOD("set_seed", "value"), &GpfRuntimeNode::set_seed);
    ClassDB::bind_method(D_METHOD("get_seed"), &GpfRuntimeNode::get_seed);
    ClassDB::bind_method(D_METHOD("set_manual_step", "value"), &GpfRuntimeNode::set_manual_step);
    ClassDB::bind_method(D_METHOD("get_manual_step"), &GpfRuntimeNode::get_manual_step);
    ClassDB::bind_method(D_METHOD("set_auto_start_match", "value"), &GpfRuntimeNode::set_auto_start_match);
    ClassDB::bind_method(D_METHOD("get_auto_start_match"), &GpfRuntimeNode::get_auto_start_match);
    ClassDB::bind_method(D_METHOD("set_human_control", "value"), &GpfRuntimeNode::set_human_control);
    ClassDB::bind_method(D_METHOD("get_human_control"), &GpfRuntimeNode::get_human_control);
    ClassDB::bind_method(D_METHOD("set_match_duration", "value"), &GpfRuntimeNode::set_match_duration);
    ClassDB::bind_method(D_METHOD("get_match_duration"), &GpfRuntimeNode::get_match_duration);
    ClassDB::bind_method(D_METHOD("is_runtime_ready"), &GpfRuntimeNode::is_runtime_ready);
    ClassDB::bind_method(D_METHOD("get_last_error"), &GpfRuntimeNode::get_last_error);
    ClassDB::bind_method(D_METHOD("start_runtime_now"), &GpfRuntimeNode::start_runtime_now);
    ClassDB::bind_method(D_METHOD("start_match"), &GpfRuntimeNode::start_match);
    ClassDB::bind_method(D_METHOD("stop_match"), &GpfRuntimeNode::stop_match);
    ClassDB::bind_method(D_METHOD("restart_match"), &GpfRuntimeNode::restart_match);
    ClassDB::bind_method(D_METHOD("set_match_package", "package"), &GpfRuntimeNode::set_match_package);
    ClassDB::bind_method(D_METHOD("has_match_package"), &GpfRuntimeNode::has_match_package);
    ClassDB::bind_method(D_METHOD("net_host", "port", "name"), &GpfRuntimeNode::net_host);
    ClassDB::bind_method(D_METHOD("net_join", "address", "port", "name"), &GpfRuntimeNode::net_join);
    ClassDB::bind_method(D_METHOD("net_leave"), &GpfRuntimeNode::net_leave);
    ClassDB::bind_method(D_METHOD("net_lobby"), &GpfRuntimeNode::net_lobby);
    ClassDB::bind_method(D_METHOD("net_action", "action_type", "side", "value", "value2"),
                         &GpfRuntimeNode::net_action);
    ClassDB::bind_method(D_METHOD("net_start"), &GpfRuntimeNode::net_start);
    ClassDB::bind_method(D_METHOD("net_take_match_setup"), &GpfRuntimeNode::net_take_match_setup);
    ClassDB::bind_method(D_METHOD("net_side_select_open"), &GpfRuntimeNode::net_side_select_open);
    ClassDB::bind_method(D_METHOD("net_side_select_commit"), &GpfRuntimeNode::net_side_select_commit);
    ClassDB::bind_method(D_METHOD("net_side_select_cancel"), &GpfRuntimeNode::net_side_select_cancel);
    ClassDB::bind_method(D_METHOD("is_net_active"), &GpfRuntimeNode::is_net_active);
    ClassDB::bind_method(D_METHOD("is_net_host"), &GpfRuntimeNode::is_net_host);
    ClassDB::bind_method(D_METHOD("is_net_client"), &GpfRuntimeNode::is_net_client);
    ClassDB::bind_method(D_METHOD("debug_get_scene_object_count"), &GpfRuntimeNode::debug_get_scene_object_count);
    ClassDB::bind_method(D_METHOD("debug_human_device"), &GpfRuntimeNode::debug_human_device);
    ClassDB::bind_method(D_METHOD("debug_human_state"), &GpfRuntimeNode::debug_human_state);
    ClassDB::bind_method(D_METHOD("step_fixed", "ticks"), &GpfRuntimeNode::step_fixed);
    ClassDB::bind_method(D_METHOD("get_snapshot"), &GpfRuntimeNode::get_snapshot);
    ClassDB::bind_method(D_METHOD("get_goal_net_positions", "goal"), &GpfRuntimeNode::get_goal_net_positions);
    ClassDB::bind_method(D_METHOD("get_goal_net_edges"), &GpfRuntimeNode::get_goal_net_edges);
    ClassDB::bind_method(D_METHOD("generate_pitch_texture", "width", "height"), &GpfRuntimeNode::generate_pitch_texture);
    ClassDB::bind_method(D_METHOD("get_player_pose", "player_id"), &GpfRuntimeNode::get_player_pose);
    ClassDB::bind_method(D_METHOD("get_player_ids"), &GpfRuntimeNode::get_player_ids);
    ClassDB::bind_method(D_METHOD("debug_get_formation", "team_id"), &GpfRuntimeNode::debug_get_formation);
    ClassDB::bind_method(D_METHOD("get_human_player_id"), &GpfRuntimeNode::get_human_player_id);
    ClassDB::bind_method(D_METHOD("get_human_player_ids"), &GpfRuntimeNode::get_human_player_ids);
    ClassDB::bind_method(D_METHOD("get_human_team_id"), &GpfRuntimeNode::get_human_team_id);
    ClassDB::bind_method(D_METHOD("select_player", "player_id"), &GpfRuntimeNode::select_player);
    ClassDB::bind_method(D_METHOD("start_open_play", "player_id"), &GpfRuntimeNode::start_open_play);
    ClassDB::bind_method(D_METHOD("toggle_debug_park_opponents"), &GpfRuntimeNode::toggle_debug_park_opponents);
    ClassDB::bind_method(D_METHOD("begin_phase_break"), &GpfRuntimeNode::begin_phase_break);
    ClassDB::bind_method(D_METHOD("continue_after_phase_break"), &GpfRuntimeNode::continue_after_phase_break);
    ClassDB::bind_method(D_METHOD("clear_phase_break_pending"), &GpfRuntimeNode::clear_phase_break_pending);
    ClassDB::bind_method(D_METHOD("set_replay_active", "active"), &GpfRuntimeNode::set_replay_active);
    ClassDB::bind_method(D_METHOD("pause_match"), &GpfRuntimeNode::pause_match);
    ClassDB::bind_method(D_METHOD("resume_match"), &GpfRuntimeNode::resume_match);
    ClassDB::bind_method(D_METHOD("queue_substitution", "team_id", "out_player_id", "in_player_id"),
                         &GpfRuntimeNode::queue_substitution);
    ClassDB::bind_method(D_METHOD("cancel_substitution", "team_id", "out_slot"), &GpfRuntimeNode::cancel_substitution);
    ClassDB::bind_method(D_METHOD("get_pending_substitutions"), &GpfRuntimeNode::get_pending_substitutions);
    ClassDB::bind_method(D_METHOD("get_substitution_notices"), &GpfRuntimeNode::get_substitution_notices);
    ClassDB::bind_method(D_METHOD("get_substitution_notice_counter"), &GpfRuntimeNode::get_substitution_notice_counter);
    ClassDB::bind_method(D_METHOD("get_squad", "team_id"), &GpfRuntimeNode::get_squad);
    ClassDB::bind_method(D_METHOD("apply_tactical_scheme", "team_id", "scheme_index"),
                         &GpfRuntimeNode::apply_tactical_scheme);
    ClassDB::bind_method(D_METHOD("set_team_role", "team_id", "role", "slot"),
                         &GpfRuntimeNode::set_team_role);
    ClassDB::bind_method(D_METHOD("swap_squad_players", "team_id", "first_player_id", "second_player_id"),
                         &GpfRuntimeNode::swap_squad_players);
    ClassDB::bind_method(D_METHOD("is_set_piece_taker_menu_available"), &GpfRuntimeNode::is_set_piece_taker_menu_available);
    ClassDB::bind_method(D_METHOD("is_set_piece_taker_menu_open"), &GpfRuntimeNode::is_set_piece_taker_menu_open);
    ClassDB::bind_method(D_METHOD("open_set_piece_taker_menu"), &GpfRuntimeNode::open_set_piece_taker_menu);
    ClassDB::bind_method(D_METHOD("close_set_piece_taker_menu"), &GpfRuntimeNode::close_set_piece_taker_menu);
    ClassDB::bind_method(D_METHOD("request_set_piece_taker", "player_id"), &GpfRuntimeNode::request_set_piece_taker);
    ClassDB::bind_method(D_METHOD("get_set_piece_taker_candidates"), &GpfRuntimeNode::get_set_piece_taker_candidates);
    ClassDB::bind_method(D_METHOD("get_tick"), &GpfRuntimeNode::get_tick);
    ClassDB::bind_method(D_METHOD("set_button", "index", "pressed"), &GpfRuntimeNode::set_button);
    ClassDB::bind_method(D_METHOD("set_move", "x", "y"), &GpfRuntimeNode::set_move);
    ClassDB::bind_method(D_METHOD("register_gamepad", "godot_device_id"), &GpfRuntimeNode::register_gamepad);
    ClassDB::bind_method(D_METHOD("set_controller_setup", "setup"), &GpfRuntimeNode::set_controller_setup);
    ClassDB::bind_method(D_METHOD("get_controller_setup"), &GpfRuntimeNode::get_controller_setup);
    ClassDB::bind_method(D_METHOD("set_gamepad_button", "slot", "button", "pressed"), &GpfRuntimeNode::set_gamepad_button);
    ClassDB::bind_method(D_METHOD("set_gamepad_axis", "slot", "axis", "value"), &GpfRuntimeNode::set_gamepad_axis);
    ClassDB::bind_method(D_METHOD("debug_set_ball", "position", "momentum"), &GpfRuntimeNode::debug_set_ball);
    ClassDB::bind_method(D_METHOD("debug_set_last_touch_team", "team_id"), &GpfRuntimeNode::debug_set_last_touch_team);
    ClassDB::bind_method(D_METHOD("debug_force_set_piece", "set_piece_type", "team_id"), &GpfRuntimeNode::debug_force_set_piece);
    ClassDB::bind_method(D_METHOD("debug_force_shootout"), &GpfRuntimeNode::debug_force_shootout);
    ClassDB::bind_method(D_METHOD("debug_force_phase_break", "next_phase"), &GpfRuntimeNode::debug_force_phase_break);
    ClassDB::bind_method(D_METHOD("debug_force_game_over"), &GpfRuntimeNode::debug_force_game_over);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "data_root"), "set_data_root", "get_data_root");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "seed"), "set_seed", "get_seed");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "manual_step"), "set_manual_step", "get_manual_step");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "auto_start_match"), "set_auto_start_match", "get_auto_start_match");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "human_control"), "set_human_control", "get_human_control");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "match_duration"), "set_match_duration", "get_match_duration");
}

void GpfRuntimeNode::_ready() {
    if (!manual_step) {
        start_runtime();
    }
}

void GpfRuntimeNode::_process(double delta) {
    if (!runtime_ready || manual_step || game_over_seen || !match) {
        return;
    }
    const bool network_match = is_net_active();
    if (match->GetPause() && !network_match) {
        accumulator_ms = 0.0;
        return;
    }

    accumulator_ms += delta * 1000.0;
    accumulator_ms = std::min(accumulator_ms, 250.0);

    int steps = 0;
    while (accumulator_ms >= (double)TICK_MS && steps < 10) {
        accumulator_ms -= (double)TICK_MS;
        step_one_tick();
        ++steps;
        if (game_over_seen) break;
    }

    if (match->GetPause()) {
        accumulator_ms = 0.0;
        // Keep the paused network frame rendered while the session ticks.
        if (network_match) {
            put_frame(sim_time_ms);
        }
        return;
    }

    double alpha = std::clamp(accumulator_ms / (double)TICK_MS, 0.0, 0.999);
    unsigned long put_time = sim_time_ms + (unsigned long)(alpha * (double)TICK_MS);
    put_frame(put_time);
}

void GpfRuntimeNode::set_data_root(const String &value) {
    data_root = value;
}

String GpfRuntimeNode::get_data_root() const {
    return data_root;
}

void GpfRuntimeNode::set_seed(int value) {
    seed = value;
}

int GpfRuntimeNode::get_seed() const {
    return seed;
}

void GpfRuntimeNode::set_manual_step(bool value) {
    manual_step = value;
}

bool GpfRuntimeNode::get_manual_step() const {
    return manual_step;
}

void GpfRuntimeNode::set_auto_start_match(bool value) {
    auto_start_match = value;
}

bool GpfRuntimeNode::get_auto_start_match() const {
    return auto_start_match;
}

void GpfRuntimeNode::set_human_control(bool value) {
    human_control = value;
}

bool GpfRuntimeNode::get_human_control() const {
    return human_control;
}

void GpfRuntimeNode::set_match_duration(float value) {
    match_duration = value;
}

bool GpfRuntimeNode::has_match_package() const {
    return match_package_ready;
}

bool GpfRuntimeNode::is_net_active() const {
    return net_server != nullptr || net_client != nullptr;
}

bool GpfRuntimeNode::is_net_host() const {
    return net_server != nullptr;
}

bool GpfRuntimeNode::is_net_client() const {
    return net_client != nullptr;
}

bool GpfRuntimeNode::net_host(int port, const String &name) {
    if (!runtime_ready || !menuTask) {
        last_error = "net_host called before the runtime started";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (is_net_active()) {
        last_error = "a network session is already active";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (port <= 0 || port > 65535) {
        last_error = "invalid port";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    boost::shared_ptr<NetServer> server(new NetServer((uint16_t)port));
    if (!server->Start()) {
        last_error = "could not bind port " + String::num_int64(port);
        UtilityFunctions::printerr(last_error);
        return false;
    }
    const String host_name = name.is_empty() ? String("Host") : name;
    server->SetHostName(to_std_string(host_name));

    net_server = server;
    net_client.reset();
    menuTask->SetNetClient(boost::shared_ptr<NetClient>());
    menuTask->SetNetServer(server);
    last_error = "";
    return true;
}

bool GpfRuntimeNode::net_join(const String &address, int port, const String &name) {
    if (!runtime_ready || !menuTask) {
        last_error = "net_join called before the runtime started";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (is_net_active()) {
        last_error = "a network session is already active";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (address.is_empty()) {
        last_error = "invalid address";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (port <= 0 || port > 65535) {
        last_error = "invalid port";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    boost::shared_ptr<NetClient> client(new NetClient());
    client->SetPlayerName(to_std_string(name.is_empty() ? String("Player") : name));
    if (!client->Connect(NetAddress(to_std_string(address), (uint16_t)port))) {
        last_error = "could not start the network client";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    net_client = client;
    net_server.reset();
    menuTask->SetNetServer(boost::shared_ptr<NetServer>());
    menuTask->SetNetClient(client);
    last_error = "";
    return true;
}

bool GpfRuntimeNode::net_leave() {
    const bool was_active = is_net_active();
    if (match) {
        stop_match();
    }
    if (net_server) {
        net_server->Stop();
        net_server.reset();
    }
    if (net_client) {
        net_client->Disconnect();
        net_client.reset();
    }
    if (menuTask) {
        menuTask->SetNetServer(boost::shared_ptr<NetServer>());
        menuTask->SetNetClient(boost::shared_ptr<NetClient>());
    }
    last_error = "";
    return was_active;
}

Dictionary GpfRuntimeNode::net_lobby() const {
    Dictionary result;
    const bool host = net_server != nullptr;
    const bool client = net_client != nullptr;
    result["active"] = host || client;
    result["is_host"] = host;
    result["is_client"] = client;
    result["local_id"] = host ? 0 : (client ? (int)net_client->GetPlayerId() : -1);

    int connection = (int)e_NetConnectionState_Disconnected;
    if (host) {
        connection = net_server->IsRunning() ? (int)e_NetConnectionState_Connected
                                             : (int)e_NetConnectionState_Disconnected;
    } else if (client) {
        connection = (int)net_client->GetState();
    }
    result["connection"] = connection;

    int rtt_ms = -1;
    if (host) {
        rtt_ms = net_server->GetMaxClientRtt_ms();
    } else if (client) {
        rtt_ms = net_client->GetRtt_ms();
    }
    result["rtt_ms"] = rtt_ms;

    bool accepted = false;
    int reject_reason = (int)e_NetReject_None;
    String reject_text;
    if (host) {
        accepted = net_server->IsRunning();
    } else if (client) {
        const NetServerHello hello = net_client->GetServerHello();
        accepted = hello.accepted;
        reject_reason = (int)hello.reason;
        reject_text = String::utf8(hello.reasonText.c_str());
    }
    result["accepted"] = accepted;
    result["reject_reason"] = reject_reason;
    result["reject_text"] = reject_text;

    NetLobbyState state;
    if (host) {
        state = net_server->GetLobbyState();
    } else if (client) {
        state = net_client->GetLobbyState();
    }

    Dictionary lobby;
    lobby["revision"] = (int)state.revision;
    lobby["phase"] = state.phase;
    lobby["side_select"] = state.sideSelect;
    lobby["hub_vote"] = state.hubVote;

    Array players;
    for (size_t i = 0; i < state.players.size(); ++i) {
        const NetLobbyPlayer &player = state.players[i];
        Dictionary entry;
        entry["id"] = (int)player.id;
        entry["name"] = String::utf8(player.name.c_str());
        entry["side"] = player.side;
        entry["ready"] = player.ready;
        entry["is_host"] = player.isHost;
        entry["ping_ms"] = player.ping_ms;
        entry["device"] = player.device;
        entry["resume_ready"] = player.resumeReady;
        entry["hub_vote"] = player.hubVote;
        players.append(entry);
    }
    lobby["players"] = players;

    Array team_ids;
    Array country_ids;
    Array league_ids;
    Array team_ready;
    Array chooser;
    Array team_cursor;
    Array list_scroll;
    for (int side = 0; side < 2; ++side) {
        team_ids.append(state.teamId[side]);
        country_ids.append(state.countryId[side]);
        league_ids.append(state.leagueId[side]);
        team_ready.append(state.teamReady[side]);
        chooser.append((int)state.chooser[side]);
        team_cursor.append(state.teamCursor[side]);
        list_scroll.append(state.listScroll[side]);
    }
    lobby["team_ids"] = team_ids;
    lobby["country_ids"] = country_ids;
    lobby["league_ids"] = league_ids;
    lobby["team_ready"] = team_ready;
    lobby["chooser"] = chooser;
    lobby["team_cursor"] = team_cursor;
    lobby["list_scroll"] = list_scroll;
    lobby["match_difficulty"] = state.matchDifficulty;
    lobby["match_duration"] = state.matchDuration;
    result["lobby"] = lobby;
    return result;
}

bool GpfRuntimeNode::net_action(const Variant &action_type, int side, int value, int value2) {
    const int type = lobby_action_from_variant(action_type);
    if (type < 0) {
        last_error = "unknown lobby action";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    NetLobbyAction action;
    action.type = type;
    action.side = side;
    action.value = value;
    action.value2 = value2;
    // The server attributes the action to the sending connection; the host is
    // always player 0.
    action.playerId = 0;
    if (net_server) {
        net_server->ApplyLobbyAction(action);
        return true;
    }
    if (net_client) {
        net_client->SendLobbyAction(action);
        return true;
    }
    last_error = "no network session";
    return false;
}

bool GpfRuntimeNode::net_start() {
    if (!runtime_ready || !menuTask || !gameTask) {
        last_error = "net_start called before the runtime started";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (!net_server) {
        last_error = "net_start is a host action";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (match) {
        last_error = "a match is already running";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    const NetLobbyState state = net_server->GetLobbyState();
    if (state.teamId[0] <= 0 || state.teamId[1] <= 0) {
        last_error = "the lobby has not chosen both teams";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (!match_package_ready ||
        match_package[0].databaseID != state.teamId[0] ||
        match_package[1].databaseID != state.teamId[1]) {
        last_error = "the match package teams differ from the lobby";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    // The kickoff options are host-authoritative (see NetLobbyState).
    if (state.matchDuration > 0.0f) {
        package_duration = state.matchDuration;
    }
    if (state.matchDifficulty > 0.0f) {
        package_difficulty = state.matchDifficulty;
    }

    NetMatchSetup setup;
    setup.teamId[0] = state.teamId[0];
    setup.teamId[1] = state.teamId[1];
    NetBuffer buffer;
    WriteMatchSetup(buffer, setup);
    net_server->BroadcastMessage(e_NetMessage_MatchSetup, buffer);

    menuTask->SetTeamIDs(std::to_string(setup.teamId[0]), std::to_string(setup.teamId[1]));
    if (!start_match()) {
        return false;
    }
    return true;
}

Dictionary GpfRuntimeNode::net_take_match_setup() {
    Dictionary result;
    if (!net_client) {
        return result;
    }
    NetMatchSetup setup;
    if (!net_client->ConsumeMatchSetup(setup)) {
        return result;
    }
    Array team_ids;
    team_ids.append(setup.teamId[0]);
    team_ids.append(setup.teamId[1]);
    result["team_ids"] = team_ids;
    return result;
}

bool GpfRuntimeNode::net_side_select_open() {
    if (!runtime_ready || !menuTask || !gameTask || !match) {
        last_error = "net_side_select_open called before the match started";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (net_server) {
        // Resets every player's ready/resume vote and mirrors the state.
        net_server->SetSideSelectMode(true);
        last_error = "";
        return true;
    }
    if (net_client) {
        return net_action("request_side_select", 0, 1, 0);
    }
    last_error = "net_side_select_open needs a network match";
    UtilityFunctions::printerr(last_error);
    return false;
}

bool GpfRuntimeNode::net_side_select_commit() {
    if (!runtime_ready || !menuTask || !gameTask || !match) {
        last_error = "net_side_select_commit called before the match started";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (!net_server) {
        last_error = "net_side_select_commit is a host action";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    // RebindControllers applies the chosen sides and resumes the match.
    net_server->SetSideSelectMode(false);
    gameTask->RebindNetworkControllers();
    last_error = "";
    return true;
}

bool GpfRuntimeNode::net_side_select_cancel() {
    if (!runtime_ready || !menuTask || !gameTask || !match) {
        last_error = "net_side_select_cancel called before the match started";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (net_server) {
        // Apply the chosen sides but keep the paused match (back to the pause
        // menu); resuming is a separate Continue vote.
        net_server->SetSideSelectMode(false);
        gameTask->ApplyNetworkControllers();
        last_error = "";
        return true;
    }
    if (net_client) {
        return net_action("request_side_select", 0, 0, 0);
    }
    last_error = "net_side_select_cancel needs a network match";
    UtilityFunctions::printerr(last_error);
    return false;
}

bool GpfRuntimeNode::set_match_package(const Dictionary &package) {
    if (match) {
        last_error = "cannot replace the match package while a match is running";
        return false;
    }

    last_error = "";
    const Variant home_value = value_or(package, "home");
    const Variant away_value = value_or(package, "away");
    if (home_value.get_type() != Variant::DICTIONARY || away_value.get_type() != Variant::DICTIONARY) {
        last_error = "match package needs home and away team dictionaries";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    TeamDataRaw home;
    TeamDataRaw away;
    if (!read_package_team(home_value, home, last_error)) {
        last_error = "match package home: " + last_error;
        UtilityFunctions::printerr(last_error);
        return false;
    }
    if (!read_package_team(away_value, away, last_error)) {
        last_error = "match package away: " + last_error;
        UtilityFunctions::printerr(last_error);
        return false;
    }

    float duration = 1.0f;
    float difficulty = 0.8f;
    const Variant options_value = value_or(package, "options");
    if (options_value.get_type() == Variant::DICTIONARY) {
        const Dictionary options = options_value;
        duration = (float)(double)value_or(options, "duration", 1.0);
        difficulty = (float)(double)value_or(options, "difficulty", 0.8);
    }

    match_package[0] = home;
    match_package[1] = away;
    for (int team = 0; team < 2; ++team) {
        for (int role = 0; role < 6; ++role) package_roles[team][role] = -1;
        const Dictionary team_dict = (team == 0) ? Dictionary(home_value) : Dictionary(away_value);
        const Variant roles_value = value_or(team_dict, "roles");
        if (roles_value.get_type() != Variant::ARRAY) continue;
        const Array roles = roles_value;
        for (int role = 0; role < 6 && role < (int)roles.size(); ++role) {
            package_roles[team][role] = (int)roles[role];
        }
    }
    package_duration = std::clamp(duration, 0.0f, 2.0f);
    package_difficulty = std::clamp(difficulty, 0.0f, 1.0f);
    match_package_ready = true;
    return true;
}



float GpfRuntimeNode::get_match_duration() const {
    return match_duration;
}

bool GpfRuntimeNode::is_runtime_ready() const {
    return runtime_ready;
}

String GpfRuntimeNode::get_last_error() const {
    return last_error;
}

void GpfRuntimeNode::start_runtime_now() {
    start_runtime();
}

bool GpfRuntimeNode::start_runtime() {
    if (runtime_ready) {
        return true;
    }
    if (runtime_failed) {
        return false;
    }

    last_error = "";
    String root = data_root;
    if (root.is_empty()) {
        root = OS::get_singleton()->get_environment("GPF_DATA_ROOT");
    }
    if (root.is_empty()) {
        root = "C:/Users/Egor/Desktop/projects/GameplayFootball-of_port/data";
    }
    std::filesystem::path data_path(root.utf8().get_data());
    if (!is_nonempty_file(data_path / "databases" / "default" / "database.sqlite")) {
        runtime_failed = true;
        last_error = "GPF data root not found: " + root;
        UtilityFunctions::printerr(last_error);
        return false;
    }

    std::error_code ec;
    std::filesystem::current_path(data_path, ec);
    if (ec) {
        runtime_failed = true;
        last_error = "cannot chdir to GPF data root: " + root;
        UtilityFunctions::printerr(last_error);
        return false;
    }

    UtilityFunctions::print("GpfRuntimeNode: initializing original runtime at ", root);
    Properties *config = new Properties();
    config->LoadFile("football.config");
    config->Set("graphics3d_renderer", "mock");
    config->Set("audio_renderer", "mock");
    config->Set("match_difficulty", 0.8f);
    config->Set("match_duration", match_duration);
    config->Set("debug", false);

    blunted::Initialize(*config);
    if (!InitGameContext(*config)) {
        runtime_failed = true;
        last_error = "InitGameContext failed";
        UtilityFunctions::printerr(last_error);
        return false;
    }

    gameTask = boost::shared_ptr<GameTask>(new GameTask());

    std::string font_file = config->Get("font_filename", "media/fonts/alegreya/AlegreyaSansSC-ExtraBold.ttf");
    TTF_Font *font = TTF_OpenFont(font_file.c_str(), 32);
    if (!font) {
        runtime_failed = true;
        last_error = "cannot open GPF font: " + String(font_file.c_str());
        UtilityFunctions::printerr(last_error);
        return false;
    }
    TTF_Font *outline = TTF_OpenFont(font_file.c_str(), 32);
    TTF_SetFontOutline(outline, 2);
    menuTask = boost::shared_ptr<MenuTask>(new MenuTask(5.0f / 4.0f, 0, font, outline));

    boost::shared_ptr<TaskSequence> game_sequence(new TaskSequence("game", 10, false));
    game_sequence->AddUserTaskEntry(menuTask, e_TaskPhase_Get);
    GetScheduler()->RegisterTaskSequence(game_sequence);

    menuTask->SetTeamIDs("3", "8");
    runtime_ready = true;

    // The menu/LAN lobby only needs the original singletons (MenuTask, game
    // task, input/audio) and creates the match later from the shell package.
    if (!auto_start_match) {
        UtilityFunctions::print("GpfRuntimeNode: runtime ready for the menu (no match)");
        return true;
    }
    if (!start_match()) {
        runtime_failed = true;
        runtime_ready = false;
        return false;
    }
    UtilityFunctions::print("GpfRuntimeNode: original match ready");
    return true;
}

bool GpfRuntimeNode::start_match() {
    if (!runtime_ready || !gameTask || !menuTask) {
        return false;
    }
    // Starting a second match on top of a live one would trip GameTask's
    // assert(!match). The caller must stop_match() first.
    if (match) {
        return false;
    }

    last_error = "";
    if (!match_package_ready) {
        last_error = "no match package: the shell must call set_match_package() first";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    sim_time_ms = 0;
    accumulator_ms = 0.0;
    game_over_seen = false;
    ended_in_regular_time = false;
    phase_break_pending = false;
    phase_break_next_phase = 0;
    park_opponents = false;
    replay_active = false;
    replay_moment_pending = false;
    goal_nets_ready = false;
    last_match_phase = 0;

    // Apply the shell's prematch options before Match reads them.
    GetConfiguration()->Set("match_duration", package_duration);
    GetConfiguration()->Set("match_difficulty", package_difficulty);

    // Everything the match needs is in the package: construct the match model
    // straight from it (no database queries).
    menuTask->SetTeamIDs(std::to_string(match_package[0].databaseID),
                         std::to_string(match_package[1].databaseID));
    MatchData *match_data = new MatchData(match_package[0], match_package[1]);
    for (int team = 0; team < 2; ++team) {
        for (int role = 0; role < e_TeamRole_SIZE; ++role) {
            if (package_roles[team][role] >= 0) {
                match_data->SetRolePlayer(team, (e_TeamRole)role, package_roles[team][role]);
            }
        }
    }
    menuTask->SetMatchData(match_data);
    UtilityFunctions::print("GpfRuntimeNode: match built from package: ",
        String::utf8(match_package[0].name.c_str()), " vs ",
        String::utf8(match_package[1].name.c_str()));

    // Match's constructor assumes the most recently created page is its
    // LoadingMatchPage and closes it; create a fresh one for every match.
    Properties loading_props;
    menuTask->GetWindowManager()->GetPageFactory()->CreatePage(
        (int)e_PageID_LoadingMatch, loading_props, 0);

    // The match reads the queued fixture in its constructor, so set it last.
    // It is re-applied every tick too: the original menu pages clear this
    // fixture, and the shell owns the setup for the whole match.
    // A network match must be born without local gamers: the host binds the
    // lobby devices in NetMatchSession::StartMatch, while a thin client keeps
    // none (the host is authoritative).
    if (is_net_active()) {
        menuTask->ClearControllerSetup();
    }
    apply_controller_setup();

    blunted::randomize(seed);
    gameTask->Action(e_GameTaskMessage_StartMatch);
    match = gameTask->GetMatch();
    if (!match) {
        last_error = "Match was not created";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    match->SetAutoUpdateIngameCamera(true);

    // The original game pauses for an extended replay six seconds after a goal
    // and unpauses when the replay page closes. The Godot scene consumes this
    // moment with its own replay. Headless tests have no consumer, so keep the
    // original auto-resume behaviour when no replay is active.
    last_match_phase = (int)match->GetMatchPhase();
    match->sig_OnExtendedReplayMoment.connect([this](Match *m) {
        if (!m) return;
        replay_moment_pending = true;
        if (!replay_active) m->Pause(false);
    });
    match->sig_OnGameOver.connect([this](Match *m) {
        game_over_seen = true;
        if (m) m->Pause(true);
    });
    // The original UI opens its phase menu from sig_OnMatchPhaseChange. The
    // runtime only records the request here: the Godot presentation decides
    // when to show the overlay and calls begin_phase_break(). Headless tests
    // must keep simulating straight through the break.
    match->sig_OnMatchPhaseChange.connect([this](Match *m) {
        if (!m) return;
        phase_break_pending = true;
        phase_break_next_phase = (int)m->GetMatchPhase();
    });

    goal_net_params.gravity = NET_GRAVITY;
    goal_net_params.damping = NET_DAMPING;
    goal_net_params.stiffness = NET_SPRING_STIFFNESS;
    goal_net_params.shapeReturn = NET_SHAPE_RETURN;
    goal_net_params.ballRadius = NET_BALL_RADIUS;
    goal_net_params.ballVelScale = NET_BALL_VEL_SCALE;
    goal_net_params.ballForce = NET_BALL_FORCE;
    goal_net_params.ballMinSpeed = NET_BALL_MIN_SPEED;
    goal_net_params.ballMaxImpact = NET_BALL_MAX_IMPACT;
    goal_net_params.constraintIterations = NET_CONSTRAINT_ITERATIONS;
    goal_net_params.constraintStiffness = NET_STIFFNESS;
    for (int goal = 0; goal < 2; ++goal) {
        goal_nets[goal] = netsim::BuildBoxNet(goalHalfWidth * 2.0f, goalHeight, NET_DEPTH,
                                              NET_WIDTH_DIV, NET_HEIGHT_DIV, NET_DEPTH_DIV, NET_SLACK);
    }
    goal_net_prev_ball = match->GetBall()->GetBallGeom()->GetPosition();
    goal_net_prev_time_ms = 0;
    goal_nets_ready = true;

    match->SetPresentationClock(true, TICK_MS, TICK_MS);
    return true;
}

void GpfRuntimeNode::stop_match() {
    if (!runtime_ready || !gameTask) {
        return;
    }
    // Safe to call repeatedly: GameTask only tears down when a match exists.
    gameTask->Action(e_GameTaskMessage_StopMatch);
    match = nullptr;
    sim_time_ms = 0;
    accumulator_ms = 0.0;
    game_over_seen = false;
    ended_in_regular_time = false;
    phase_break_pending = false;
    phase_break_next_phase = 0;
    park_opponents = false;
    replay_active = false;
    replay_moment_pending = false;
    goal_nets_ready = false;
    last_match_phase = 0;
}

bool GpfRuntimeNode::restart_match() {
    if (!runtime_ready) {
        return start_runtime();
    }
    stop_match();
    return start_match();
}

void GpfRuntimeNode::apply_controller_setup() {
    if (!runtime_ready || !menuTask) {
        return;
    }
    // A network match binds controllers from the lobby (NetMatchSession); the
    // shell's local device mapping would overwrite the host's DelayedHIDDevice
    // and NetHIDDevice bindings on every tick.
    if (is_net_active()) {
        return;
    }
    std::vector<SideSelection> sides;
    if (human_control) {
        if (shell_controllers.empty()) {
            // No shell selection (headless default): the keyboard plays home.
            SideSelection keyboard;
            keyboard.controllerID = 0;
            keyboard.joystickID = 0;
            keyboard.controllerImage = 0;
            keyboard.side = -1;
            keyboard.confirmed = true;
            sides.push_back(keyboard);
        } else {
            for (size_t i = 0; i < shell_controllers.size(); ++i) {
                const ShellController &entry = shell_controllers[i];
                SideSelection selection;
                selection.controllerID = (int)i;
                selection.joystickID = (SDL_JoystickID)entry.stable_id;
                selection.controllerImage = 0;
                selection.side = entry.side;
                selection.confirmed = true;
                sides.push_back(selection);
            }
        }
    }
    menuTask->SetControllerSetup(sides);
}

void GpfRuntimeNode::step_one_tick() {
    if (!runtime_ready || !match || game_over_seen) {
        return;
    }
    const bool network_match = is_net_active();
    // A paused network match still needs its tick: pause/resume votes, roster
    // changes and snapshots are processed by NetMatchSession inside GameTask.
    if (!network_match && match->GetPause()) {
        return;
    }
    if (!match->GetPause()) {
        sim_time_ms += TICK_MS;
    }
    match->SetPresentationClock(true, sim_time_ms, sim_time_ms);
    // The original menu task owns the queued fixture; pages clear it, so the
    // shell re-applies its own setup before every processed tick.
    apply_controller_setup();
    gameTask->ProcessPhase();
    // F2 debug, matching Match::Process: keep the non-human outfield team
    // parked off the pitch for every processed tick while the toggle is on.
    if (park_opponents && !match->GetPause()) {
        match->DebugParkOpponents(true);
    }

    // The original Referee switches to the next phase at the end of a period
    // and only checks for a winner three seconds later, when the kickoff is
    // prepared. That briefly exposes EXTRA TIME to the HUD even when the match
    // is already decided. End such a match immediately, before that phase is
    // ever played.
    const e_MatchPhase phase = match->GetMatchPhase();
    if ((int)phase != last_match_phase) {
        const bool decisive = match->GetScore(0) != match->GetScore(1);
        const bool ended_regular = phase == e_MatchPhase_1stExtraTime &&
                                   last_match_phase == (int)e_MatchPhase_2ndHalf;
        const bool ended_extra = phase == e_MatchPhase_2ndExtraTime &&
                                 last_match_phase == (int)e_MatchPhase_1stExtraTime;
        // A thin client never decides the match: the host's snapshot carries the
        // final state.
        if (decisive && (ended_regular || ended_extra) && !match->IsShootoutActive() &&
            !is_net_client()) {
            ended_in_regular_time = ended_regular;
            game_over_seen = true;
            match->Pause(true);
            match->GameOver();
        }
        last_match_phase = (int)phase;
    }
}

void GpfRuntimeNode::put_frame(unsigned long put_time_ms) {
    if (!runtime_ready || !match) {
        return;
    }
    match->SetPresentationClock(true, sim_time_ms, put_time_ms);
    gameTask->PutPhase();
    update_goal_nets(put_time_ms);
}

void GpfRuntimeNode::update_goal_nets(unsigned long put_time_ms) {
    if (!goal_nets_ready) {
        return;
    }
    const blunted::Vector3 ball_world = match->GetBall()->GetBallGeom()->GetPosition();
    blunted::Vector3 motion = ball_world - goal_net_prev_ball;
    if (motion.GetLength() > 2.0f) {
        motion = blunted::Vector3(0.0f);
    }
    const blunted::Vector3 ball_prev = ball_world - motion;
    const unsigned long elapsed = put_time_ms > goal_net_prev_time_ms
        ? put_time_ms - goal_net_prev_time_ms : 1;
    const float dt = std::max(0.001f, std::min(0.1f, (float)elapsed * 0.001f));
    const blunted::Vector3 ball_vel = motion * (1.0f / dt);
    for (int goal = 0; goal < 2; ++goal) {
        netsim::Integrate(goal_nets[goal],
                          goal_net_ball_to_local(goal, ball_world),
                          goal_net_ball_to_local(goal, ball_prev),
                          goal_net_dir_to_local(goal, ball_vel),
                          goal_net_params, NET_SIM_STEP);
    }
    goal_net_prev_ball = ball_world;
    goal_net_prev_time_ms = put_time_ms;
}

void GpfRuntimeNode::step_fixed(int ticks) {
    if (!runtime_ready || !match) {
        return;
    }
    for (int i = 0; i < ticks; ++i) {
        step_one_tick();
        put_frame(sim_time_ms);
    }
}

int GpfRuntimeNode::get_tick() const {
    return (int)(sim_time_ms / TICK_MS);
}

int GpfRuntimeNode::debug_get_scene_object_count() const {
    boost::shared_ptr<blunted::Scene3D> scene = GetScene3D();
    if (!scene) {
        return -1;
    }
    std::list<boost::intrusive_ptr<blunted::Object> > objects;
    scene->GetObjects(objects);
    return (int)objects.size();
}

String GpfRuntimeNode::debug_human_device() const {
    if (!runtime_ready || !match) {
        return String();
    }
    for (int team_id = 0; team_id < 2; ++team_id) {
        Team *team = match->GetTeam(team_id);
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (!team->IsHumanControlled(players[i]->GetID())) {
                continue;
            }
            HumanGamer *gamer = team->GetHumanGamerControllingPlayer(players[i]);
            if (!gamer || !gamer->GetHIDevice()) {
                return String();
            }
            const IHIDevice *device = gamer->GetHIDevice();
            // 0 = e_HIDDeviceType_Keyboard in the original enum order.
            return String((int)device->GetDeviceType() == 0 ? "keyboard" : "gamepad");
        }
    }
    return String();
}

Array GpfRuntimeNode::debug_human_state() const {
    Array result;
    if (!runtime_ready || !match) {
        return result;
    }
    for (int team_id = 0; team_id < 2; ++team_id) {
        Team *team = match->GetTeam(team_id);
        Dictionary item;
        item["team"] = team_id;
        item["gamers"] = (int)team->GetHumanGamerCount();
        int controlled = 0;
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (team->IsHumanControlled(players[i]->GetID())) {
                ++controlled;
            }
        }
        item["controlled"] = controlled;
        result.append(item);
    }
    return result;
}

bool GpfRuntimeNode::is_local_human_player(Player *player) const {
    if (!match || !player) {
        return false;
    }
    if (match->IsRemotePresentation()) {
        return player->GetRemoteOwnerId() >= 0 &&
               player->GetRemoteOwnerId() == match->GetLocalPeerId();
    }
    Team *team = player->GetTeam();
    if (!team) {
        return false;
    }
    // Local peer id is 0. Local 2P has both gamers owned by 0, so both teams'
    // selected players show; a LAN host only shows its own 0-owned selected
    // player and hides the client's NetHIDDevice-owned one.
    const int owner = team->GetControllingPeerId(player->GetID());
    return owner >= 0 && owner == match->GetLocalPeerId();
}

int GpfRuntimeNode::player_owner_id(Player *player, int team_id) const {
    if (!match || !player) {
        return -1;
    }
    if (match->IsRemotePresentation()) {
        return player->GetRemoteOwnerId();
    }
    Team *team = match->GetTeam(team_id);
    return team ? team->GetControllingPeerId(player->GetID()) : -1;
}

int GpfRuntimeNode::get_human_player_id() const {
    if (!runtime_ready || !match) {
        return -1;
    }
    // The human can play either side: scan both rosters. A thin client has no
    // local HumanGamer, so ownership comes from the host snapshot instead.
    for (int team_id = 0; team_id < 2; ++team_id) {
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (is_local_human_player(players[i])) {
                return players[i]->GetID();
            }
        }
    }
    // -1, not the first player: when nobody is selected (goal celebration,
    // opponent set piece) the caller must keep the last real selection.
    return -1;
}

Array GpfRuntimeNode::get_human_player_ids() const {
    Array result;
    if (!runtime_ready || !match) {
        return result;
    }
    // Local 2P: every team may have one human-controlled player at a time.
    // Thin client: every player the host marks as owned by this peer.
    for (int team_id = 0; team_id < 2; ++team_id) {
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (is_local_human_player(players[i])) {
                result.append(players[i]->GetID());
            }
        }
    }
    return result;
}

int GpfRuntimeNode::get_human_team_id() const {
    if (!runtime_ready || !match) {
        return -1;
    }
    for (int team_id = 0; team_id < 2; ++team_id) {
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (is_local_human_player(players[i])) {
                return team_id;
            }
        }
    }
    return -1;
}

bool GpfRuntimeNode::is_set_piece_taker_menu_available() const {
    if (!runtime_ready || !match) {
        return false;
    }
    SetPiecePresentation *presentation = match->GetSetPiecePresentation();
    return presentation && presentation->IsLocalTaker() &&
           presentation->GetType() != e_SetPiece_KickOff &&
           !match->IsSetPieceTakerMenuInputBlocked();
}

bool GpfRuntimeNode::is_set_piece_taker_menu_open() const {
    return runtime_ready && match && match->IsSetPieceTakerMenuOpen();
}

bool GpfRuntimeNode::open_set_piece_taker_menu() {
    if (!is_set_piece_taker_menu_available()) {
        return false;
    }
    match->SetSetPieceTakerMenuOpen(true);
    return true;
}

void GpfRuntimeNode::close_set_piece_taker_menu() {
    if (match) {
        match->SetSetPieceTakerMenuOpen(false);
    }
}

void GpfRuntimeNode::request_set_piece_taker(int player_id) {
    if (!runtime_ready || !match) {
        return;
    }
    SetPiecePresentation *presentation = match->GetSetPiecePresentation();
    Player *taker = presentation ? presentation->GetTaker() : nullptr;
    if (!taker) {
        taker = match->GetRefereeBuffer().taker;
    }
    if (!taker) {
        return;
    }
    std::vector<Player *> players;
    taker->GetTeam()->GetActivePlayers(players);
    for (size_t i = 0; i < players.size(); ++i) {
        if (players[i]->GetID() == player_id) {
            match->RequestSetPieceTaker(players[i]);
            return;
        }
    }
}

Array GpfRuntimeNode::get_set_piece_taker_candidates() const {
    Array result;
    if (!runtime_ready || !match) {
        return result;
    }
    SetPiecePresentation *presentation = match->GetSetPiecePresentation();
    Player *taker = presentation ? presentation->GetTaker() : nullptr;
    if (!taker) {
        taker = match->GetRefereeBuffer().taker;
    }
    if (!taker) {
        return result;
    }
    std::vector<Player *> players;
    taker->GetTeam()->GetActivePlayers(players);
    for (size_t i = 0; i < players.size(); ++i) {
        Player *player = players[i];
        if (!player || !player->IsActive()) {
            continue;
        }
        Dictionary entry;
        entry["id"] = player->GetID();
        entry["team"] = player->GetTeamID();
        entry["name"] = String::utf8(player->GetPlayerData()->GetLastName().c_str());
        entry["role"] = player == taker->GetTeam()->GetGoalie() ? "goalkeeper" : "player";
        entry["current"] = player == taker;
        result.append(entry);
    }
    return result;
}

void GpfRuntimeNode::select_player(int player_id) {
    if (!runtime_ready || !match) {
        return;
    }
    for (int team_id = 0; team_id < 2; ++team_id) {
        Team *team = match->GetTeam(team_id);
        if (team->GetHumanGamerCount() == 0) {
            continue;
        }
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (players[i]->GetID() == player_id) {
                // Force the switch on the human's team: Team::SelectPlayer moves
                // the gamer's selection (the old implementation only re-selected
                // a player that was already controlled).
                team->SelectPlayer(players[i]);
                return;
            }
        }
    }
}

Array GpfRuntimeNode::get_player_ids() const {
    Array result;
    if (!runtime_ready || !match) {
        return result;
    }
    for (int team_id = 0; team_id < 2; ++team_id) {
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            Dictionary entry;
            entry["id"] = players[i]->GetID();
            entry["team"] = team_id;
            entry["role"] = players[i] == match->GetTeam(team_id)->GetGoalie()
                ? "goalkeeper" : "player";
            entry["name"] = String::utf8(players[i]->GetPlayerData()->GetLastName().c_str());
            // Host: the HumanGamer owner. Client: the ownerId relayed by the
            // host snapshot. -1 = AI.
            entry["owner_id"] = player_owner_id(players[i], team_id);
            result.append(entry);
        }
    }
    std::vector<PlayerBase *> officials;
    match->GetOfficialPlayers(officials);
    for (size_t i = 0; i < officials.size(); ++i) {
        Dictionary entry;
        entry["id"] = officials[i]->GetID();
        entry["team"] = -1;
        entry["role"] = "official";
        result.append(entry);
    }
    return result;
}

Array GpfRuntimeNode::debug_get_formation(int team_id) const {
    Array result;
    if (!runtime_ready || !match || team_id < 0 || team_id > 1) {
        return result;
    }
    Team *team = match->GetTeam(team_id);
    if (!team || !team->GetTeamData()) {
        return result;
    }
    TeamData *team_data = team->GetTeamData();
    int count = team_data->GetPlayerNum();
    if (count > playerNum) count = playerNum;
    for (int slot = 0; slot < count; ++slot) {
        const FormationEntry entry = team_data->GetFormationEntry(slot);
        Dictionary item;
        item["slot"] = slot;
        item["role"] = String(GetRoleName(entry.role).c_str());
        item["database_position"] = to_godot(entry.databasePosition);
        item["position"] = to_godot(entry.position);
        result.append(item);
    }
    return result;
}

Dictionary GpfRuntimeNode::build_player(int player_id) const {
    Dictionary result;
    if (!runtime_ready || !match) {
        return result;
    }
    PlayerBase *actor = nullptr;
    int team_id = -1;
    String role = "player";
    for (int t = 0; t < 2 && !actor; ++t) {
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(t, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (players[i]->GetID() == player_id) {
                actor = players[i];
                team_id = t;
                break;
            }
        }
    }
    if (!actor) {
        std::vector<PlayerBase *> officials;
        match->GetOfficialPlayers(officials);
        for (size_t i = 0; i < officials.size(); ++i) {
            if (officials[i]->GetID() == player_id) {
                actor = officials[i];
                role = "official";
                break;
            }
        }
    }
    if (!actor) {
        return result;
    }
    if (team_id >= 0 && actor == match->GetTeam(team_id)->GetGoalie()) {
        role = "goalkeeper";
    }

    result["id"] = actor->GetID();
    result["team"] = team_id;
    result["role"] = role;
    result["owner_id"] = team_id >= 0
        ? player_owner_id(static_cast<Player *>(actor), team_id) : -1;
    result["pos"] = to_godot(actor->GetGeomPosition());
    result["anim"] = String(actor->GetCurrentAnim()->anim->GetName().c_str());
    result["frame"] = actor->GetFrameNum();
    result["function"] = (int)actor->GetCurrentFunctionType();

    Array bones;
    const auto &node_map = actor->GetNodeMap();
    for (auto it = node_map.begin(); it != node_map.end(); ++it) {
        Dictionary bone;
        bone["name"] = String(it->first.c_str());
        bone["pos"] = to_godot(it->second->GetPosition());
        bone["rot"] = to_godot(it->second->GetRotation());
        bones.append(bone);
    }
    result["bones"] = bones;
    return result;
}

Dictionary GpfRuntimeNode::get_snapshot() const {
    Dictionary result;
    if (!runtime_ready || !match) {
        return result;
    }

    result["tick"] = get_tick();
    result["net_active"] = is_net_active();
    result["net_is_host"] = net_server != nullptr;
    result["net_is_client"] = net_client != nullptr;
    result["net_phase_state"] = is_net_active() && gameTask
        ? (int)gameTask->GetNetSession()->GetState() : (int)e_NetMatchPhaseState_Playing;
    result["net_local_id"] = net_server ? 0 : (net_client ? (int)net_client->GetPlayerId() : -1);
    int net_connection = (int)e_NetConnectionState_Disconnected;
    if (net_server) {
        net_connection = net_server->IsRunning() ? (int)e_NetConnectionState_Connected
                                                 : (int)e_NetConnectionState_Disconnected;
    } else if (net_client) {
        net_connection = (int)net_client->GetState();
    }
    result["net_connection"] = net_connection;
    result["match_time_ms"] = (int)match->GetMatchTime_ms();
    result["in_play"] = match->IsInPlay();
    result["in_set_piece"] = match->IsInSetPiece();
    result["match_phase"] = ended_in_regular_time
        ? (int)e_MatchPhase_2ndHalf
        : (int)match->GetMatchPhase();
    result["ended_in_regular_time"] = ended_in_regular_time;
    result["team0_side"] = (int)match->GetTeam(0)->GetSide();
    result["team1_side"] = (int)match->GetTeam(1)->GetSide();
    Player *taker = match->GetTeam(0)->GetController()->GetPieceTaker();
    result["set_piece_taker"] = taker ? taker->GetID() : -1;
    result["set_piece_type"] = (int)match->GetTeam(0)->GetController()->GetSetPieceType();
    SetPiecePresentation *presentation = match->GetSetPiecePresentation();
    // 2P: the HUD/aim data must describe the human whose team takes this set
    // piece, not always the first human on the pitch.
    Player *hud_player = nullptr;
    Player *set_piece_taker = presentation ? presentation->GetTaker() : nullptr;
    if (!set_piece_taker) set_piece_taker = match->GetRefereeBuffer().taker;
    if (set_piece_taker) {
        Team *taker_team = set_piece_taker->GetTeam();
        if (taker_team) {
            std::vector<Player *> team_players;
            match->GetActiveTeamPlayers(taker_team->GetID(), team_players);
            for (size_t i = 0; i < team_players.size(); ++i) {
                if (taker_team->IsHumanControlled(team_players[i]->GetID())) {
                    hud_player = team_players[i];
                    break;
                }
            }
        }
    }
    if (!hud_player) {
        const int selected_id = get_human_player_id();
        if (selected_id >= 0) hud_player = match->GetPlayer(selected_id);
    }
    SetPieceHudState set_piece_hud;
    if (presentation && hud_player) {
        set_piece_hud = presentation->GetHudState(hud_player);
    }
    result["set_piece_hud_player"] = hud_player ? hud_player->GetID() : -1;
    result["set_piece_human_taker"] = presentation && hud_player &&
        presentation->GetTaker() == hud_player;
    result["presentation_type"] = presentation ? (int)presentation->GetType() : 0;
    result["set_piece_role"] = (int)set_piece_hud.role;
    result["set_piece_aim_point"] = to_godot(set_piece_hud.aimPoint);
    result["set_piece_charge"] = set_piece_hud.chargeRatio;
    result["set_piece_local_taker"] = presentation && presentation->IsLocalTaker() &&
        presentation->GetType() != e_SetPiece_KickOff;
    result["set_piece_taker_menu_available"] = is_set_piece_taker_menu_available();
    result["set_piece_taker_menu_open"] = match->IsSetPieceTakerMenuOpen();
    const RefereeBuffer &referee_buffer = match->GetRefereeBuffer();
    result["referee_active"] = referee_buffer.active;
    result["referee_set_piece"] = (int)referee_buffer.desiredSetPiece;
    result["referee_team"] = (int)referee_buffer.teamID;
    result["referee_end_phase"] = referee_buffer.endPhase;
    result["referee_stop_time"] = (int)referee_buffer.stopTime;
    result["referee_prepare_time"] = (int)referee_buffer.prepareTime;
    result["referee_start_time"] = (int)referee_buffer.startTime;
    result["referee_taker"] = referee_buffer.taker ? referee_buffer.taker->GetID() : -1;
    result["score0"] = match->GetScore(0);
    result["score1"] = match->GetScore(1);
    result["team0_name"] = String::utf8(match->GetTeam(0)->GetTeamData()->GetName().c_str());
    result["team1_name"] = String::utf8(match->GetTeam(1)->GetTeamData()->GetName().c_str());
    MatchData *match_data = match->GetMatchData();
    result["possession0_ms"] = (int)match_data->GetPossessionTime_ms(0);
    result["possession1_ms"] = (int)match_data->GetPossessionTime_ms(1);
    result["shots0"] = match_data->GetShots(0);
    result["shots1"] = match_data->GetShots(1);
    result["substitutions0"] = match->GetTeam(0)->GetSubstitutionCount();
    result["substitutions1"] = match->GetTeam(1)->GetSubstitutionCount();
    result["substitutions_max"] = maxSubstitutions;
    result["substitution_notice_counter"] = (int)match->GetSubstitutionNoticeCounter();
    Array substitution_notices;
    const std::vector<SubstitutionNotice> &notices = match->GetSubstitutionNotices();
    for (size_t i = 0; i < notices.size(); ++i) {
        Team *notice_team = match->GetTeam(notices[i].teamID);
        Player *notice_out = notice_team ? notice_team->GetPlayer(notices[i].outPlayerID) : nullptr;
        Player *notice_in = notice_team ? notice_team->GetPlayer(notices[i].inPlayerID) : nullptr;
        const std::string out_name = notice_out ? notice_out->GetPlayerData()->GetLastName() : std::string("?");
        const std::string in_name = notice_in ? notice_in->GetPlayerData()->GetLastName() : std::string("?");
        substitution_notices.append(String::utf8((out_name + " off, " + in_name + " on").c_str()));
    }
    result["substitution_notices"] = substitution_notices;
    result["actual_time_ms"] = (int)match->GetActualTime_ms();
    result["match_duration_factor"] = match->GetMatchDurationFactor();
    result["paused"] = match->GetPause();
    result["replay_moment"] = replay_moment_pending;
    result["phase_break_pending"] = phase_break_pending;
    result["phase_break"] = match->IsPhaseBreak();
    result["phase_break_next_phase"] = phase_break_next_phase;
    result["debug_park_opponents"] = park_opponents;
    result["game_over"] = game_over_seen;
    result["goal_scored"] = match->IsGoalScored();
    result["ball_in_goal"] = match->IsBallInGoal();
    result["last_goal_team"] = match->GetLastGoalTeamID();
    result["last_touch_team"] = match->GetLastTouchTeamID();
    result["ball_retainer"] = match->GetBallRetainer() ? match->GetBallRetainer()->GetID() : -1;
    result["restart_pos"] = to_godot(referee_buffer.restartPos);

    // Penalty shootout state (the series HUD). Always present so GDScript needs no guards.
    result["shootout_active"] = match->IsShootoutActive();
    result["shootout_phase"] = match->GetShootoutPhase();
    result["shootout_score0"] = match->GetShootoutScore(0);
    result["shootout_score1"] = match->GetShootoutScore(1);
    Array shootout_kicks0;
    Array shootout_kicks1;
    for (int i = 0; i < 16; ++i) {
        shootout_kicks0.append(match->GetShootoutKickResult(0, i));
        shootout_kicks1.append(match->GetShootoutKickResult(1, i));
    }
    result["shootout_kicks0"] = shootout_kicks0;
    result["shootout_kicks1"] = shootout_kicks1;
    result["shootout_outcome"] = match->GetShootoutLastOutcome();
    result["shootout_outcome_counter"] = (int)match->GetShootoutOutcomeCounter();
    result["shootout_outcome_kicker"] = match->GetShootoutLastOutcomeKickerID();
    result["shootout_decisive"] = match->IsShootoutDecisive();
    result["shootout_winner"] = match->GetShootoutWinner();
    result["shootout_celebrating"] = match->IsShootoutCelebrating();
    result["shootout_taker_team"] = match->GetShootoutTakerTeam();
    result["shootout_goal_x"] = match->GetShootoutGoalX();

    boost::intrusive_ptr<blunted::Geometry> ball_geom = match->GetBall()->GetBallGeom();
    result["ball_pos"] = to_godot(ball_geom->GetDerivedPosition());
    result["ball_rot"] = to_godot(ball_geom->GetDerivedRotation());
    result["ball_vel"] = to_godot(match->GetBall()->GetMovement());
    result["ball_sim_pos"] = to_godot(match->GetBall()->Predict(0));

    result["camera_pos"] = to_godot(match->GetPresentationCameraPosition());
    result["camera_rot"] = to_godot(match->GetPresentationCameraRotation());
    result["camera_fov"] = match->GetPresentationCameraFOV();
    float camera_near = 1.0f;
    float camera_far = 200.0f;
    match->GetPresentationCameraCapping(camera_near, camera_far);
    result["camera_near"] = camera_near;
    result["camera_far"] = camera_far;

    int player_id = get_human_player_id();
    result["player_id"] = player_id;
    if (player_id >= 0) {
        result["player"] = build_player(player_id);
    }
    return result;
}

void GpfRuntimeNode::start_open_play(int player_id) {
    if (!runtime_ready || !match) {
        return;
    }
    blunted::Vector3 ball_pos(0.0f, 0.0f, 0.11f);
    match->SetMatchPhase(e_MatchPhase_1stHalf);
    match->StartPlay();
    match->StopSetPiece();
    match->ResetSituation(ball_pos);
    match->GetBall()->SetPosition(ball_pos);
    match->GetBall()->SetMomentum(blunted::Vector3(0.0f));
    match->SetBallRetainer(nullptr);

    Team *home = match->GetTeam(0);
    std::vector<Player *> players;
    match->GetActiveTeamPlayers(0, players);
    for (size_t i = 0; i < players.size(); ++i) {
        if (players[i]->GetID() == player_id) {
            blunted::Vector3 player_pos(ball_pos.coords[0] - 0.35f, ball_pos.coords[1], 0.0f);
            players[i]->ResetPosition(player_pos, ball_pos);
            home->SelectPlayer(players[i]);
            break;
        }
    }
}

bool GpfRuntimeNode::toggle_debug_park_opponents() {
    if (!runtime_ready || !match) {
        return false;
    }
    park_opponents = !park_opponents;
    match->DebugParkOpponents(park_opponents);
    return park_opponents;
}

bool GpfRuntimeNode::begin_phase_break() {
    if (!runtime_ready || !match || game_over_seen || !phase_break_pending) {
        return false;
    }
    match->SetPhaseBreak(true);
    match->Pause(true);
    return true;
}

void GpfRuntimeNode::continue_after_phase_break() {
    if (!runtime_ready || !match || game_over_seen) {
        return;
    }
    phase_break_pending = false;
    phase_break_next_phase = 0;
    match->SetPhaseBreak(false);
    match->Pause(false);
}

void GpfRuntimeNode::clear_phase_break_pending() {
    phase_break_pending = false;
    phase_break_next_phase = 0;
}

void GpfRuntimeNode::set_replay_active(bool active) {
    replay_active = active;
    replay_moment_pending = false;
    if (!runtime_ready || !match) {
        return;
    }
    match->Pause(active);
}

void GpfRuntimeNode::pause_match() {
    if (runtime_ready && match) {
        match->Pause(true);
    }
}

void GpfRuntimeNode::resume_match() {
    if (runtime_ready && match) {
        match->Pause(false);
    }
}

bool GpfRuntimeNode::queue_substitution(int team_id, int out_player_id, int in_player_id) {
    if (!runtime_ready || !match) {
        return false;
    }
    return match->QueueSubstitution(team_id, out_player_id, in_player_id);
}

bool GpfRuntimeNode::cancel_substitution(int team_id, int out_slot) {
    if (!runtime_ready || !match) {
        return false;
    }
    return match->CancelSubstitution(team_id, out_slot);
}

Array GpfRuntimeNode::get_pending_substitutions() const {
    Array result;
    if (!runtime_ready || !match) {
        return result;
    }
    const std::vector<Substitution> &pending = match->GetPendingSubstitutions();
    for (size_t i = 0; i < pending.size(); ++i) {
        Dictionary entry;
        entry["team"] = pending[i].teamID;
        entry["out_id"] = pending[i].outPlayerID;
        entry["in_id"] = pending[i].inPlayerID;
        entry["out_slot"] = pending[i].outSlot;
        entry["in_slot"] = pending[i].inSlot;
        result.append(entry);
    }
    return result;
}

Array GpfRuntimeNode::get_substitution_notices() const {
    Array result;
    if (!runtime_ready || !match) {
        return result;
    }
    const std::vector<SubstitutionNotice> &notices = match->GetSubstitutionNotices();
    for (size_t i = 0; i < notices.size(); ++i) {
        Team *team = match->GetTeam(notices[i].teamID);
        Player *out = team ? team->GetPlayer(notices[i].outPlayerID) : nullptr;
        Player *in = team ? team->GetPlayer(notices[i].inPlayerID) : nullptr;
        const std::string out_name = out ? out->GetPlayerData()->GetLastName() : std::string("?");
        const std::string in_name = in ? in->GetPlayerData()->GetLastName() : std::string("?");
        Dictionary entry;
        entry["team"] = notices[i].teamID;
        entry["out_id"] = notices[i].outPlayerID;
        entry["in_id"] = notices[i].inPlayerID;
        entry["out_slot"] = notices[i].outSlot;
        entry["in_slot"] = notices[i].inSlot;
        entry["time_ms"] = (int)notices[i].time_ms;
        entry["text"] = String::utf8((out_name + " off, " + in_name + " on").c_str());
        result.append(entry);
    }
    return result;
}

int GpfRuntimeNode::get_substitution_notice_counter() const {
    if (!runtime_ready || !match) {
        return 0;
    }
    return (int)match->GetSubstitutionNoticeCounter();
}

Dictionary GpfRuntimeNode::get_squad(int team_id) const {
    Dictionary result;
    if (!runtime_ready || !match || team_id < 0 || team_id > 1) {
        return result;
    }
    Team *team = match->GetTeam(team_id);
    TeamData *team_data = team ? team->GetTeamData() : nullptr;
    if (!team || !team_data) {
        return result;
    }

    result["team_id"] = team_id;
    result["name"] = String::utf8(team_data->GetName().c_str());
    result["substitutions"] = team->GetSubstitutionCount();
    result["max_substitutions"] = maxSubstitutions;

    const std::vector<Substitution> &pending = match->GetPendingSubstitutions();
    Array players;
    const std::vector<Player *> &all = team->GetAllPlayers();
    for (size_t slot = 0; slot < all.size(); ++slot) {
        Player *player = all[slot];
        if (!player) continue;
        PlayerData *player_data = player->GetPlayerData();
        if (!player_data) continue;

        const bool active = player->IsActive();
        FormationEntry formation;
        std::string role_name;
        Vector2 position;
        if (active) {
            formation = team->GetFormationEntry(player->GetID());
            role_name = GetRoleName(formation.role);
            position = Vector2(formation.databasePosition.coords[0], formation.databasePosition.coords[1]);
        } else {
            const std::vector<e_PlayerRole> &roles = player_data->GetRoles();
            role_name = GetRoleName(roles.empty() ? e_PlayerRole_CM : roles.front());
        }

        bool pending_out = false;
        bool pending_in = false;
        for (size_t i = 0; i < pending.size(); ++i) {
            if (pending[i].teamID != team_id) continue;
            if (pending[i].outPlayerID == player->GetID()) pending_out = true;
            if (pending[i].inPlayerID == player->GetID()) pending_in = true;
        }

        const float base_stat = player_data->GetRaw().baseStat;
        const int rating = base_stat > 0.0f ? (int)(base_stat * 100.0f + 0.5f) : -1;
        const int fatigue = (int)(std::clamp(player->GetFatigueFactorInv(), 0.0f, 1.0f) * 100.0f + 0.5f);

        Dictionary entry;
        entry["id"] = player->GetID();
        entry["slot"] = (int)slot;
        entry["name"] = String::utf8(player_data->GetLastName().c_str());
        entry["role"] = String(role_name.c_str());
        entry["position"] = position;
        entry["active"] = active;
        entry["left_pitch"] = team->HasLeftPitch(player->GetID());
        entry["pending_out"] = pending_out;
        entry["pending_in"] = pending_in;
        entry["rating"] = rating;
        entry["fatigue"] = fatigue;
        players.append(entry);
    }
    result["players"] = players;

    MatchData *match_data = match->GetMatchData();
    Array roles;
    for (int role = 0; role < e_TeamRole_SIZE; ++role) {
        const int designated = match_data ? match_data->GetRolePlayer(team_id, (e_TeamRole)role) : -1;
        const int slot = team->GetRoleSlot((e_TeamRole)role);
        Dictionary entry;
        entry["role"] = role;
        entry["slot"] = slot;
        entry["designated"] = designated;
        if (slot >= 0 && slot < (int)all.size()) {
            Player *role_player = all[slot];
            entry["player_id"] = role_player->GetID();
            entry["name"] = String::utf8(role_player->GetPlayerData()->GetLastName().c_str());
        } else {
            entry["player_id"] = -1;
            entry["name"] = "";
        }
        roles.append(entry);
    }
    result["roles"] = roles;
    return result;
}


void GpfRuntimeNode::apply_tactical_scheme(int team_id, int scheme_index) {
    if (!runtime_ready || !match || team_id < 0 || team_id > 1) {
        return;
    }
    ApplySchemeToTeam(match->GetTeam(team_id), scheme_index);
}


bool GpfRuntimeNode::set_team_role(int team_id, int role, int slot) {
    if (!runtime_ready || !match || team_id < 0 || team_id > 1) {
        return false;
    }
    if (role < 0 || role >= e_TeamRole_SIZE) {
        return false;
    }
    Team *team = match->GetTeam(team_id);
    MatchData *match_data = match->GetMatchData();
    if (!team || !match_data) {
        return false;
    }
    if (slot < 0 || slot >= (int)team->GetAllPlayers().size()) {
        return false;
    }
    match_data->SetRolePlayer(team_id, (e_TeamRole)role, slot);
    return true;
}


bool GpfRuntimeNode::swap_squad_players(int team_id, int first_player_id, int second_player_id) {
    if (!runtime_ready || !match || team_id < 0 || team_id > 1) {
        return false;
    }
    Team *team = match->GetTeam(team_id);
    if (!team) return false;
    Player *first = team->GetPlayer(first_player_id);
    Player *second = team->GetPlayer(second_player_id);
    if (!first || !second || first == second) return false;
    if (!first->IsActive() || !second->IsActive()) return false;

    const FormationEntry first_entry = team->GetFormationEntry(first_player_id);
    const FormationEntry second_entry = team->GetFormationEntry(second_player_id);
    team->SetRuntimeFormationEntry(first_player_id, second_entry);
    team->SetRuntimeFormationEntry(second_player_id, first_entry);
    return true;
}

PackedVector3Array GpfRuntimeNode::get_goal_net_positions(int goal) const {
    PackedVector3Array positions;
    if (!goal_nets_ready || goal < 0 || goal > 1) {
        return positions;
    }
    const netsim::Net &net = goal_nets[goal];
    positions.resize((int)net.pos.size());
    for (int i = 0; i < (int)net.pos.size(); ++i) {
        positions[i] = goal_net_local_to_scene(goal, net.pos[i]);
    }
    return positions;
}

PackedInt32Array GpfRuntimeNode::get_goal_net_edges() const {
    PackedInt32Array edges;
    if (!goal_nets_ready) {
        return edges;
    }
    const std::vector<int> &source = goal_nets[0].edges;
    edges.resize((int)source.size());
    for (int i = 0; i < (int)source.size(); ++i) {
        edges[i] = source[i];
    }
    return edges;
}

Ref<Image> GpfRuntimeNode::generate_pitch_texture(int width, int height) const {
    return ProceduralPitch::generate(width, height);
}

Dictionary GpfRuntimeNode::get_player_pose(int player_id) const {
    return build_player(player_id);
}

void GpfRuntimeNode::set_button(int index, bool pressed) {
    if (index < 0 || index >= e_ButtonFunction_Size) {
        return;
    }
    UserEventManager::GetInstance().SetKeyboardState(defaultKeyIDs[index], pressed);
}

void GpfRuntimeNode::set_move(double x, double y) {
    const double threshold = 0.3;
    set_button(e_ButtonFunction_Left, x < -threshold);
    set_button(e_ButtonFunction_Right, x > threshold);
    set_button(e_ButtonFunction_Up, y > threshold);
    set_button(e_ButtonFunction_Down, y < -threshold);
}

int GpfRuntimeNode::register_gamepad(int godot_device_id) {
    if (!runtime_ready) {
        last_error = "register_gamepad called before the runtime started";
        UtilityFunctions::printerr(last_error);
        return -1;
    }
    if (godot_device_id < 0) {
        last_error = "invalid Godot gamepad device id";
        return -1;
    }
    const std::map<int, int>::const_iterator found = gamepad_virtual_ids.find(godot_device_id);
    if (found != gamepad_virtual_ids.end()) {
        return found->second;
    }

    // Extension-owned virtual joystick: the original runtime already knows how
    // to enumerate SDL gamepads, so no GameplayFootball source change is needed.
    SDL_VirtualJoystickDesc desc;
    SDL_INIT_INTERFACE(&desc);
    desc.type = SDL_JOYSTICK_TYPE_GAMEPAD;
    desc.naxes = SDL_GAMEPAD_AXIS_COUNT;
    desc.nbuttons = SDL_GAMEPAD_BUTTON_COUNT;
    desc.button_mask = (1u << SDL_GAMEPAD_BUTTON_COUNT) - 1u;
    desc.axis_mask = (1u << SDL_GAMEPAD_AXIS_COUNT) - 1u;
    desc.vendor_id = 0x1209;
    desc.product_id = 0x0001;
    desc.name = "OpenFootball Shell Gamepad";
    const SDL_JoystickID virtual_id = SDL_AttachVirtualJoystick(&desc);
    if (virtual_id == 0) {
        last_error = "SDL_AttachVirtualJoystick failed: ";
        last_error += String(SDL_GetError());
        UtilityFunctions::printerr(last_error);
        return -1;
    }
    gamepad_virtual_ids[godot_device_id] = (int)virtual_id;

    // The original input manager rescans on SDL's gamepad-added event; then
    // RefreshGamepads creates the HIDGamepad wrapper. Do both immediately: the
    // match reads its controllers on construction, not on the next game tick.
    SDL_UpdateJoysticks();
    SDL_Event event;
    SDL_zero(event);
    event.type = SDL_EVENT_GAMEPAD_ADDED;
    event.gdevice.which = virtual_id;
    UserEventManager::GetInstance().InputSDLEvent(event);
    RefreshGamepads();
    return (int)virtual_id;
}

void GpfRuntimeNode::set_controller_setup(const Array &setup) {
    shell_controllers.clear();
    for (int i = 0; i < setup.size(); ++i) {
        const Variant &item = setup[i];
        if (item.get_type() != Variant::DICTIONARY) {
            continue;
        }
        const Dictionary entry = item;
        int side = (int)value_or(entry, "side", -1);
        if (side == 0) {
            continue;
        }
        side = side > 0 ? 1 : -1;

        ShellController controller;
        controller.side = side;
        const String kind = (String)value_or(entry, "kind", "keyboard");
        const int handle = (int)value_or(entry, "slot", -1);
        bool known_virtual_gamepad = false;
        for (std::map<int, int>::const_iterator it = gamepad_virtual_ids.begin();
                it != gamepad_virtual_ids.end(); ++it) {
            if (it->second == handle) {
                known_virtual_gamepad = true;
                break;
            }
        }
        if (kind == String("gamepad") && handle > 0 && known_virtual_gamepad) {
            controller.keyboard = false;
            controller.slot = handle;
            controller.stable_id = (unsigned int)handle;
        }
        shell_controllers.push_back(controller);
    }
}

Array GpfRuntimeNode::get_controller_setup() const {
    Array result;
    for (size_t i = 0; i < shell_controllers.size(); ++i) {
        const ShellController &entry = shell_controllers[i];
        Dictionary item;
        item["side"] = entry.side;
        item["kind"] = entry.keyboard ? String("keyboard") : String("gamepad");
        item["slot"] = entry.slot;
        item["stable_id"] = (int)entry.stable_id;
        result.append(item);
    }
    return result;
}

void GpfRuntimeNode::set_gamepad_button(int slot, int button, bool pressed) {
    if (!runtime_ready || slot <= 0 || button < 0 || button >= SDL_GAMEPAD_BUTTON_COUNT) {
        return;
    }
    // Feed the original input manager through its public SDL event path, exactly
    // like a real gamepad event. `slot` here is the virtual joystick id.
    SDL_Event event;
    SDL_zero(event);
    event.type = pressed ? SDL_EVENT_GAMEPAD_BUTTON_DOWN : SDL_EVENT_GAMEPAD_BUTTON_UP;
    event.gbutton.which = (SDL_JoystickID)slot;
    event.gbutton.button = (Uint8)button;
    event.gbutton.down = pressed;
    UserEventManager::GetInstance().InputSDLEvent(event);
}

void GpfRuntimeNode::set_gamepad_axis(int slot, int axis, double value) {
    if (!runtime_ready || slot <= 0 || axis < 0 || axis >= SDL_GAMEPAD_AXIS_COUNT) {
        return;
    }
    const bool trigger = axis == SDL_GAMEPAD_AXIS_LEFT_TRIGGER ||
                         axis == SDL_GAMEPAD_AXIS_RIGHT_TRIGGER;
    const double clamped = trigger ? std::clamp(value, 0.0, 1.0)
                                   : std::clamp(value, -1.0, 1.0);
    SDL_Event event;
    SDL_zero(event);
    event.type = SDL_EVENT_GAMEPAD_AXIS_MOTION;
    event.gaxis.which = (SDL_JoystickID)slot;
    event.gaxis.axis = (Uint8)axis;
    event.gaxis.value = (Sint16)std::lround(clamped * 32767.0);
    UserEventManager::GetInstance().InputSDLEvent(event);
}

void GpfRuntimeNode::debug_set_ball(const Vector3 &position, const Vector3 &momentum) {
    if (!runtime_ready || !match) {
        return;
    }
    match->SetBallRetainer(nullptr);
    Ball *ball = match->GetBall();
    ball->SetPosition(blunted::Vector3((float)position.x, (float)position.y, (float)position.z));
    ball->SetMomentum(blunted::Vector3((float)momentum.x, (float)momentum.y, (float)momentum.z));
    match->UpdateLatestMentalImageBallPredictions();
}

void GpfRuntimeNode::debug_set_last_touch_team(int team_id) {
    if (!runtime_ready || !match || team_id < 0 || team_id > 1) {
        return;
    }
    match->SetLastTouchTeamID(team_id);
}

void GpfRuntimeNode::debug_force_set_piece(int set_piece_type, int team_id) {
    if (!runtime_ready || !match || team_id < 0 || team_id > 1) {
        return;
    }
    if (!match->IsInPlay() || match->IsInSetPiece()) {
        return;
    }
    const e_SetPiece type = (e_SetPiece)set_piece_type;
    if (type == e_SetPiece_None) {
        return;
    }

    Team *team = match->GetTeam(team_id);
    const float side = (float)team->GetSide();
    blunted::Vector3 restart(0.0f);
    switch (type) {
    case e_SetPiece_Penalty:
        restart = blunted::Vector3(-side * (pitchHalfW - 11.0f), 0.0f, 0.0f);
        break;
    case e_SetPiece_FreeKick:
        restart = match->GetBall()->Predict(0).Get2D();
        break;
    case e_SetPiece_Corner: {
        const float y = match->GetBall()->Predict(0).coords[1];
        restart = blunted::Vector3(-side * pitchHalfW, y > 0 ? pitchHalfH : -pitchHalfH, 0.0f);
        break;
    }
    case e_SetPiece_GoalKick:
        restart = blunted::Vector3(side * (pitchHalfW - 5.5f), 0.0f, 0.0f);
        break;
    case e_SetPiece_KickOff:
        restart = blunted::Vector3(0.0f);
        break;
    case e_SetPiece_ThrowIn: {
        const blunted::Vector3 ballPos = match->GetBall()->Predict(0).Get2D();
        float x = ballPos.coords[0];
        if (x < -pitchHalfW + 1.0f) x = -pitchHalfW + 1.0f;
        if (x > pitchHalfW - 1.0f) x = pitchHalfW - 1.0f;
        restart = blunted::Vector3(x, ballPos.coords[1] >= 0.0f ? pitchHalfH : -pitchHalfH, 0.0f);
        break;
    }
    default:
        break;
    }
    match->GetReferee()->DebugForceSetPiece(type, team_id, restart);
}

void GpfRuntimeNode::debug_force_shootout() {
    if (!runtime_ready || !match) {
        return;
    }
    match->StartShootout(false);
}

void GpfRuntimeNode::debug_force_phase_break(int next_phase) {
    if (!runtime_ready || !match || game_over_seen) {
        return;
    }
    phase_break_pending = true;
    phase_break_next_phase = next_phase;
}

void GpfRuntimeNode::debug_force_game_over() {
    if (!runtime_ready || !match) {
        return;
    }
    game_over_seen = true;
    match->GameOver();
    match->Pause(true);
}
