// Throwaway probe: dump original CPU-skinned fullbody vertices and 14 bone
// transforms for the fastest-moving player at a fixed tick. Read-only wrt repo.
#include "blunted.hpp"
#include "gamecontext.hpp"
#include "gametask.hpp"
#include "menu/menutask.hpp"
#include "menu/pagefactory.hpp"
#include "data/matchdata.hpp"
#include "onthepitch/match.hpp"
#include "onthepitch/player/player.hpp"
#include "onthepitch/player/humanoid/humanoidbase.hpp"
#include "onthepitch/player/humanoid/animcollection.hpp"
#include "scene/objects/geometry.hpp"
#include "scene/resources/geometrydata.hpp"
#include "base/geometry/trianglemeshutils.hpp"
#include "base/math/bluntmath.hpp"
#include "managers/usereventmanager.hpp"

#include "SDL3_ttf/SDL_ttf.h"

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>

using namespace blunted;

static void dumpBone(std::ofstream &out, const char *kind, const std::string &name,
                     boost::intrusive_ptr<Node> node) {
  Vector3 lp = node->GetPosition();
  Quaternion lr = node->GetRotation();
  Vector3 dp = node->GetDerivedPosition();
  Quaternion dr = node->GetDerivedRotation();
  out << kind << "," << name
      << "," << lp.coords[0] << "," << lp.coords[1] << "," << lp.coords[2]
      << "," << lr.elements[0] << "," << lr.elements[1] << "," << lr.elements[2] << "," << lr.elements[3]
      << "," << dp.coords[0] << "," << dp.coords[1] << "," << dp.coords[2]
      << "," << dr.elements[0] << "," << dr.elements[1] << "," << dr.elements[2] << "," << dr.elements[3]
      << "\n";
}

static void dumpPlayer(std::ofstream &out, Player *p) {
  std::vector<Player *> all;
  float movement = p->GetMovement().GetLength();
  out << "PLAYER," << p->GetID() << "," << p->GetTeamID()
      << "," << p->GetPlayerData()->GetHeight()
      << "," << p->GetGeomPosition().coords[0]
      << "," << p->GetGeomPosition().coords[1]
      << "," << p->GetGeomPosition().coords[2]
      << "," << movement
      << "," << p->GetCurrentAnim()->anim->GetName()
      << "," << p->GetCurrentAnim()->anim->GetFrameCount()
      << "," << p->GetFrameNum()
      << "," << (int)p->GetCurrentFunctionType()
      << "\n";

  const NodeMap &nm = p->GetNodeMap();
  for (NodeMap::const_iterator it = nm.begin(); it != nm.end(); ++it) {
    dumpBone(out, "BONE", it->first, it->second);
  }

  boost::intrusive_ptr<Geometry> geom = boost::static_pointer_cast<Geometry>(p->GetFullbodyNode()->GetObject("fullbody"));
  boost::intrusive_ptr<Resource<GeometryData> > data = geom->GetGeometryData();
  data->resourceMutex.lock();
  std::vector<MaterializedTriangleMesh> &meshes = data->GetResource()->GetTriangleMeshesRef();
  int elementCount = GetTriangleMeshElementCount();
  for (unsigned int s = 0; s < meshes.size(); s++) {
    int vertexCount = meshes[s].verticesDataSize / elementCount / 3;
    out << "SUBGEOM," << s << "," << vertexCount << "\n";
    for (int v = 0; v < vertexCount; v++) {
      out << "VERTEX," << s << "," << v
          << "," << meshes[s].vertices[v * 3 + 0]
          << "," << meshes[s].vertices[v * 3 + 1]
          << "," << meshes[s].vertices[v * 3 + 2] << "\n";
    }
  }
  data->resourceMutex.unlock();
}

int main(int argc, char **argv) {
  setvbuf(stdout, NULL, _IONBF, 0);
  int targetTick = (argc > 1) ? atoi(argv[1]) : 300;
  const char *outPath = (argc > 2) ? argv[2] : "skindump.csv";
  printf("start tick=%d out=%s\n", targetTick, outPath);

  Properties config;
  config.LoadFile("football.config");
  config.Set("graphics3d_renderer", "mock");
  config.Set("audio_renderer", "mock");
  config.Set("match_difficulty", 0.8f);
  config.Set("match_duration", 1.0f);

  Initialize(config);
  if (!InitGameContext(config)) { printf("InitGameContext failed\n"); ::exit(1); }

  gameTask = boost::shared_ptr<GameTask>(new GameTask());

  std::string fontFile = config.Get("font_filename", "media/fonts/alegreya/AlegreyaSansSC-ExtraBold.ttf");
  TTF_Font *defaultFont = TTF_OpenFont(fontFile.c_str(), 32);
  if (!defaultFont) { printf("font fail\n"); ::exit(1); }
  TTF_Font *defaultOutlineFont = TTF_OpenFont(fontFile.c_str(), 32);
  TTF_SetFontOutline(defaultOutlineFont, 2);
  menuTask = boost::shared_ptr<MenuTask>(new MenuTask(5.0f / 4.0f, 0, defaultFont, defaultOutlineFont));

  boost::shared_ptr<TaskSequence> gameSequence(new TaskSequence("game", 10, false));
  gameSequence->AddUserTaskEntry(menuTask, e_TaskPhase_Get);
  GetScheduler()->RegisterTaskSequence(gameSequence);

  menuTask->SetTeamIDs("3", "8");
  Properties loadingProps;
  menuTask->GetWindowManager()->GetPageFactory()->CreatePage((int)e_PageID_LoadingMatch, loadingProps, 0);
  MatchData *matchData = new MatchData(menuTask->GetTeamID(0), menuTask->GetTeamID(1));
  menuTask->SetMatchData(matchData);

  std::vector<SideSelection> sides;
  SideSelection kb;
  kb.controllerID = 0;
  kb.joystickID = 0;
  kb.controllerImage = 0;
  kb.side = -1;
  sides.push_back(kb);
  menuTask->SetControllerSetup(sides);

  randomize(42);
  gameTask->Action(e_GameTaskMessage_StartMatch);
  Match *match = gameTask->GetMatch();
  printf("match=%p\n", (void*)match);
  {
    std::vector<Player *> srcPlayers;
    match->GetActiveTeamPlayers(0, srcPlayers);
    if (!srcPlayers.empty()) {
      std::ofstream srcOut("skindsource.csv");
      srcOut << "record,key,value\n";
      dumpPlayer(srcOut, srcPlayers[0]);
      srcOut.close();
      printf("wrote skindsource.csv\n");
    }
  }

  unsigned long simTime = 0;
  for (int i = 0; i <= targetTick; i++) {
    UserEventManager::GetInstance().SetKeyboardState(SDLK_UP, true);
    simTime += 10;
    match->SetPresentationClock(true, simTime, simTime);
    gameTask->ProcessPhase();
    match->SetPresentationClock(true, simTime, simTime);
    gameTask->PutPhase();
  }

  std::vector<Player *> players;
  match->GetActiveTeamPlayers(0, players);
  match->GetActiveTeamPlayers(1, players);
  Player *best = 0;
  float bestMovement = -1.0f;
  for (unsigned int i = 0; i < players.size(); i++) {
    float m = players[i]->GetMovement().GetLength();
    printf("player id=%d team=%d pos=(%.2f %.2f %.2f) move=%.3f anim=%s frame=%d\n",
           players[i]->GetID(), players[i]->GetTeamID(),
           players[i]->GetGeomPosition().coords[0], players[i]->GetGeomPosition().coords[1], players[i]->GetGeomPosition().coords[2],
           m, players[i]->GetCurrentAnim()->anim->GetName().c_str(), players[i]->GetFrameNum());
    if (m > bestMovement) { bestMovement = m; best = players[i]; }
  }
  if (!best) { printf("no players\n"); ::exit(1); }
  printf("selected id=%d movement=%.3f anim=%s\n", best->GetID(), bestMovement, best->GetCurrentAnim()->anim->GetName().c_str());

  std::ofstream out(outPath);
  out << "record,key,value\n";
  out << "TICK," << targetTick << "," << simTime << "\n";
  dumpPlayer(out, best);
  out.close();
  printf("wrote %s\n", outPath);
  fflush(stdout);
  ::exit(0);
}


