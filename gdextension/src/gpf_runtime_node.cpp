#include "gpf_runtime_node.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "blunted.hpp"
#include "gamecontext.hpp"
#include "gametask.hpp"
#include "main.hpp"
#include "menu/menutask.hpp"
#include "menu/pagefactory.hpp"
#include "data/matchdata.hpp"
#include "onthepitch/match.hpp"
#include "onthepitch/player/player.hpp"
#include "onthepitch/referee.hpp"
#include "onthepitch/setpiece/setpiecepresentation.hpp"
#include "onthepitch/team.hpp"
#include "procedural_pitch.h"
#include "base/math/bluntmath.hpp"
#include "managers/usereventmanager.hpp"
#include "gamedefines.hpp"

#include "SDL3_ttf/SDL_ttf.h"

#include <algorithm>
#include <cmath>
#include <filesystem>
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
    ClassDB::bind_method(D_METHOD("set_human_control", "value"), &GpfRuntimeNode::set_human_control);
    ClassDB::bind_method(D_METHOD("get_human_control"), &GpfRuntimeNode::get_human_control);
    ClassDB::bind_method(D_METHOD("set_match_duration", "value"), &GpfRuntimeNode::set_match_duration);
    ClassDB::bind_method(D_METHOD("get_match_duration"), &GpfRuntimeNode::get_match_duration);
    ClassDB::bind_method(D_METHOD("is_runtime_ready"), &GpfRuntimeNode::is_runtime_ready);
    ClassDB::bind_method(D_METHOD("get_last_error"), &GpfRuntimeNode::get_last_error);
    ClassDB::bind_method(D_METHOD("start_runtime_now"), &GpfRuntimeNode::start_runtime_now);
    ClassDB::bind_method(D_METHOD("step_fixed", "ticks"), &GpfRuntimeNode::step_fixed);
    ClassDB::bind_method(D_METHOD("get_snapshot"), &GpfRuntimeNode::get_snapshot);
    ClassDB::bind_method(D_METHOD("get_goal_net_positions", "goal"), &GpfRuntimeNode::get_goal_net_positions);
    ClassDB::bind_method(D_METHOD("get_goal_net_edges"), &GpfRuntimeNode::get_goal_net_edges);
    ClassDB::bind_method(D_METHOD("generate_pitch_texture", "width", "height"), &GpfRuntimeNode::generate_pitch_texture);
    ClassDB::bind_method(D_METHOD("get_player_pose", "player_id"), &GpfRuntimeNode::get_player_pose);
    ClassDB::bind_method(D_METHOD("get_player_ids"), &GpfRuntimeNode::get_player_ids);
    ClassDB::bind_method(D_METHOD("get_human_player_id"), &GpfRuntimeNode::get_human_player_id);
    ClassDB::bind_method(D_METHOD("get_human_team_id"), &GpfRuntimeNode::get_human_team_id);
    ClassDB::bind_method(D_METHOD("select_player", "player_id"), &GpfRuntimeNode::select_player);
    ClassDB::bind_method(D_METHOD("start_open_play", "player_id"), &GpfRuntimeNode::start_open_play);
    ClassDB::bind_method(D_METHOD("toggle_debug_park_opponents"), &GpfRuntimeNode::toggle_debug_park_opponents);
    ClassDB::bind_method(D_METHOD("begin_phase_break"), &GpfRuntimeNode::begin_phase_break);
    ClassDB::bind_method(D_METHOD("continue_after_phase_break"), &GpfRuntimeNode::continue_after_phase_break);
    ClassDB::bind_method(D_METHOD("is_set_piece_taker_menu_available"), &GpfRuntimeNode::is_set_piece_taker_menu_available);
    ClassDB::bind_method(D_METHOD("is_set_piece_taker_menu_open"), &GpfRuntimeNode::is_set_piece_taker_menu_open);
    ClassDB::bind_method(D_METHOD("open_set_piece_taker_menu"), &GpfRuntimeNode::open_set_piece_taker_menu);
    ClassDB::bind_method(D_METHOD("close_set_piece_taker_menu"), &GpfRuntimeNode::close_set_piece_taker_menu);
    ClassDB::bind_method(D_METHOD("request_set_piece_taker", "player_id"), &GpfRuntimeNode::request_set_piece_taker);
    ClassDB::bind_method(D_METHOD("get_set_piece_taker_candidates"), &GpfRuntimeNode::get_set_piece_taker_candidates);
    ClassDB::bind_method(D_METHOD("get_tick"), &GpfRuntimeNode::get_tick);
    ClassDB::bind_method(D_METHOD("set_button", "index", "pressed"), &GpfRuntimeNode::set_button);
    ClassDB::bind_method(D_METHOD("set_move", "x", "y"), &GpfRuntimeNode::set_move);
    ClassDB::bind_method(D_METHOD("debug_set_ball", "position", "momentum"), &GpfRuntimeNode::debug_set_ball);
    ClassDB::bind_method(D_METHOD("debug_set_last_touch_team", "team_id"), &GpfRuntimeNode::debug_set_last_touch_team);
    ClassDB::bind_method(D_METHOD("debug_force_set_piece", "set_piece_type", "team_id"), &GpfRuntimeNode::debug_force_set_piece);
    ClassDB::bind_method(D_METHOD("debug_force_phase_break", "next_phase"), &GpfRuntimeNode::debug_force_phase_break);
    ClassDB::bind_method(D_METHOD("debug_force_game_over"), &GpfRuntimeNode::debug_force_game_over);

    ADD_PROPERTY(PropertyInfo(Variant::STRING, "data_root"), "set_data_root", "get_data_root");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "seed"), "set_seed", "get_seed");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "manual_step"), "set_manual_step", "get_manual_step");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "human_control"), "set_human_control", "get_human_control");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "match_duration"), "set_match_duration", "get_match_duration");
}

void GpfRuntimeNode::_ready() {
    if (!manual_step) {
        start_runtime();
    }
}

void GpfRuntimeNode::_process(double delta) {
    if (!runtime_ready || manual_step || game_over_seen) {
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

void GpfRuntimeNode::set_human_control(bool value) {
    human_control = value;
}

bool GpfRuntimeNode::get_human_control() const {
    return human_control;
}

void GpfRuntimeNode::set_match_duration(float value) {
    match_duration = value;
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
    Properties loading_props;
    menuTask->GetWindowManager()->GetPageFactory()->CreatePage((int)e_PageID_LoadingMatch, loading_props, 0);
    MatchData *match_data = new MatchData(menuTask->GetTeamID(0), menuTask->GetTeamID(1));
    menuTask->SetMatchData(match_data);

    std::vector<SideSelection> sides;
    if (human_control) {
        SideSelection keyboard;
        keyboard.controllerID = 0;
        keyboard.joystickID = 0;
        keyboard.controllerImage = 0;
        keyboard.side = -1;
        keyboard.confirmed = true;
        sides.push_back(keyboard);
    }
    menuTask->SetControllerSetup(sides);

    blunted::randomize(seed);
    gameTask->Action(e_GameTaskMessage_StartMatch);
    match = gameTask->GetMatch();
    if (!match) {
        runtime_failed = true;
        last_error = "Match was not created";
        UtilityFunctions::printerr(last_error);
        return false;
    }
    match->SetAutoUpdateIngameCamera(true);

    // The original game pauses for an extended replay six seconds after a goal and
    // unpauses when the replay page closes. This slice has no replay UI, so resume
    // immediately; otherwise the whole match freezes forever after the first goal.
    game_over_seen = false;
    ended_in_regular_time = false;
    phase_break_pending = false;
    phase_break_next_phase = 0;
    park_opponents = false;
    goal_nets_ready = false;
    last_match_phase = (int)match->GetMatchPhase();
    match->sig_OnExtendedReplayMoment.connect([](Match *m) { if (m) m->Pause(false); });
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

    sim_time_ms = 0;
    match->SetPresentationClock(true, TICK_MS, TICK_MS);
    runtime_ready = true;
    UtilityFunctions::print("GpfRuntimeNode: original match ready");
    return true;
}

void GpfRuntimeNode::step_one_tick() {
    if (!runtime_ready || !match || game_over_seen) {
        return;
    }
    sim_time_ms += TICK_MS;
    match->SetPresentationClock(true, sim_time_ms, sim_time_ms);
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
        if (decisive && (ended_regular || ended_extra)) {
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

int GpfRuntimeNode::get_human_player_id() const {
    if (!runtime_ready || !match) {
        return -1;
    }
    Team *home = match->GetTeam(0);
    std::vector<Player *> players;
    match->GetActiveTeamPlayers(0, players);
    for (size_t i = 0; i < players.size(); ++i) {
        if (home->IsHumanControlled(players[i]->GetID())) {
            return players[i]->GetID();
        }
    }
    // -1, not the first player: when nobody is selected (goal celebration,
    // opponent set piece) the caller must keep the last real selection.
    return -1;
}

int GpfRuntimeNode::get_human_team_id() const {
    if (!runtime_ready || !match) {
        return -1;
    }
    for (int team_id = 0; team_id < 2; ++team_id) {
        Team *team = match->GetTeam(team_id);
        std::vector<Player *> players;
        match->GetActiveTeamPlayers(team_id, players);
        for (size_t i = 0; i < players.size(); ++i) {
            if (team->IsHumanControlled(players[i]->GetID())) {
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
    Team *home = match->GetTeam(0);
    std::vector<Player *> players;
    match->GetActiveTeamPlayers(0, players);
    for (size_t i = 0; i < players.size(); ++i) {
        if (players[i]->GetID() == player_id) {
            home->SelectPlayer(players[i]);
            return;
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
    const int selected_id = get_human_player_id();
    SetPieceHudState set_piece_hud;
    if (presentation && selected_id >= 0) {
        set_piece_hud = presentation->GetHudState(match->GetPlayer(selected_id));
    }
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
    result["team0_name"] = String(match->GetTeam(0)->GetTeamData()->GetName().c_str());
    result["team1_name"] = String(match->GetTeam(1)->GetTeamData()->GetName().c_str());
    MatchData *match_data = match->GetMatchData();
    result["possession0_ms"] = (int)match_data->GetPossessionTime_ms(0);
    result["possession1_ms"] = (int)match_data->GetPossessionTime_ms(1);
    result["shots0"] = match_data->GetShots(0);
    result["shots1"] = match_data->GetShots(1);
    result["actual_time_ms"] = (int)match->GetActualTime_ms();
    result["match_duration_factor"] = match->GetMatchDurationFactor();
    result["paused"] = match->GetPause();
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
