// Generates the C++ reference fixture for tests/check_player_stats.gd.
//
// The stat formula and the formation normalization are copied verbatim from
// GameplayFootball (src/utils.cpp: CalculateStat, src/data/teamdata.cpp:
// InitFromRaw) together with the bluntmath helpers they use (clamp,
// NormalizedClamp, curve, Vector3::Normalize's 1e-6 fallback). The tool reads
// the real database, computes every player's final stats and a few sample
// formations, and writes tests/fixtures/player_stats_reference.json.
//
// Build (from this folder; sqlite3 comes from the GameplayFootball vcpkg tree):
//   call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
//   cl /std:c++17 /EHsc /O2 /Fe:player_stats_reference.exe main.cpp ^
//      /I"<GameplayFootball>/build/vcpkg_installed/x64-windows/include" ^
//      /link /LIBPATH:"<GameplayFootball>/build/vcpkg_installed/x64-windows/lib" sqlite3.lib
//   copy "<GameplayFootball>\build\vcpkg_installed\x64-windows\bin\sqlite3.dll" .
//   player_stats_reference.exe "<GameplayFootball>/data/databases/default/database.sqlite" ^
//      "../../tests/fixtures/player_stats_reference.json"
//
// Only the aggregation sums and a sample of players/formations are stored, so the
// fixture stays small while the Godot test still checks every player.

#include <sqlite3.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <string>
#include <vector>

namespace {

const float kPi = 3.1415926535897932384626433832795028841972f;

const char *kStatNames[] = {
    "physical_balance",
    "physical_reaction",
    "physical_acceleration",
    "physical_velocity",
    "physical_stamina",
    "physical_agility",
    "physical_shotpower",
    "technical_standingtackle",
    "technical_slidingtackle",
    "technical_ballcontrol",
    "technical_dribble",
    "technical_shortpass",
    "technical_highpass",
    "technical_header",
    "technical_shot",
    "technical_volley",
    "mental_calmness",
    "mental_workrate",
    "mental_resilience",
    "mental_defensivepositioning",
    "mental_offensivepositioning",
    "mental_vision",
};
const int kStatCount = sizeof(kStatNames) / sizeof(kStatNames[0]);

float Clamp(float value, float min, float max) {
    if (min > value) return min;
    if (max < value) return max;
    return value;
}

float NormalizedClamp(float value, float min, float max) {
    float banana = Clamp(value, min, max);
    return (banana - min) / (max - min);
}

float Curve(float source, float bias = 1.0f) {
    return (sinf((source - 0.5f) * kPi) * 0.5f + 0.5f) * bias +
           source * (1.0f - bias);
}

float CalculateStat(float baseStat, float profileStat, float age) {
    float idealAge = 27;
    float ageFactor = Curve(1.0f - NormalizedClamp(fabsf(age - idealAge), 0, 13) * 0.5f, 1.0f) * 2.0f - 1.0f;
    float agedBaseStat = baseStat * (ageFactor * 0.5f + 0.5f) * 1.2f;
    return Clamp(profileStat * 2.0f * agedBaseStat, 0.01f, 1.0f);
}

struct Vec2 {
    float x = 0.0f;
    float y = 0.0f;

    Vec2() = default;
    Vec2(float px, float py) : x(px), y(py) {}

    Vec2 operator+(const Vec2 &other) const { return Vec2(x + other.x, y + other.y); }
    Vec2 operator-(const Vec2 &other) const { return Vec2(x - other.x, y - other.y); }
    Vec2 operator*(float factor) const { return Vec2(x * factor, y * factor); }
    Vec2 &operator+=(const Vec2 &other) { x += other.x; y += other.y; return *this; }
    Vec2 &operator-=(const Vec2 &other) { x -= other.x; y -= other.y; return *this; }
    float Length() const { return sqrtf(x * x + y * y); }
    Vec2 NormalizedOr(const Vec2 &ifNull) const {
        if (fabsf(x) < 0.000001f && fabsf(y) < 0.000001f) return ifNull;
        float factor = 1.0f / sqrtf(x * x + y * y);
        return Vec2(x * factor, y * factor);
    }
};

struct FormationEntry {
    int slot = 0;
    std::string role = "CM";
    Vec2 databasePosition;
    Vec2 position;
};

std::map<std::string, Vec2> DefaultRolePositions() {
    return {
        {"GK", Vec2(-1.0f, 0.0f)},
        {"CB", Vec2(-1.0f, 0.0f)},
        {"LB", Vec2(-0.8f, 0.8f)},
        {"RB", Vec2(-0.8f, -0.8f)},
        {"DM", Vec2(-0.5f, 0.0f)},
        {"CM", Vec2(0.0f, 0.0f)},
        {"LM", Vec2(0.0f, 1.0f)},
        {"RM", Vec2(0.0f, -1.0f)},
        {"AM", Vec2(0.5f, 0.0f)},
        {"CF", Vec2(1.0f, 0.0f)},
        {"ST", Vec2(1.0f, 0.0f)},
        {"LW", Vec2(0.7f, 0.9f)},
        {"RW", Vec2(0.7f, -0.9f)},
    };
}

std::string RoleFromString(const std::string &value) {
    static const char *roles[] = {"GK", "CB", "LB", "RB", "DM", "CM", "LM", "RM",
                                  "AM", "CF", "LW", "RW", "ST"};
    for (const char *role : roles) {
        if (value == role) return value;
    }
    return "CM";
}

bool IsSlotTag(const std::string &tag) {
    if (tag.size() < 2 || tag[0] != 'p') return false;
    for (size_t i = 1; i < tag.size(); ++i) {
        if (!isdigit(static_cast<unsigned char>(tag[i]))) return false;
    }
    int number = atoi(tag.c_str() + 1);
    return number >= 1 && number <= 11;
}

Vec2 ParseVector(const std::string &text) {
    float x = 0.0f;
    float y = 0.0f;
    size_t comma = text.find(',');
    if (comma == std::string::npos) {
        x = static_cast<float>(atof(text.c_str()));
    } else {
        x = static_cast<float>(atof(text.substr(0, comma).c_str()));
        y = static_cast<float>(atof(text.substr(comma + 1).c_str()));
    }
    return Vec2(x, y);
}

std::string ExtractTag(const std::string &block, const std::string &name) {
    std::string open = "<" + name + ">";
    std::string close = "</" + name + ">";
    size_t start = block.find(open);
    if (start == std::string::npos) return "";
    start += open.size();
    size_t end = block.find(close, start);
    if (end == std::string::npos) return "";
    return block.substr(start, end - start);
}

std::vector<FormationEntry> ParseFormation(const std::string &xml) {
    std::vector<FormationEntry> entries;
    size_t position = 0;
    while (true) {
        size_t open = xml.find("<p", position);
        if (open == std::string::npos) break;
        size_t tagEnd = xml.find('>', open);
        if (tagEnd == std::string::npos) break;
        std::string tag = xml.substr(open + 1, tagEnd - open - 1);
        if (!IsSlotTag(tag)) {
            position = tagEnd + 1;
            continue;
        }
        std::string closing = "</" + tag + ">";
        size_t blockEnd = xml.find(closing, tagEnd);
        if (blockEnd == std::string::npos) break;
        std::string block = xml.substr(tagEnd + 1, blockEnd - tagEnd - 1);
        FormationEntry entry;
        entry.slot = atoi(tag.c_str() + 1) - 1;
        entry.databasePosition = ParseVector(ExtractTag(block, "position"));
        entry.role = RoleFromString(ExtractTag(block, "role"));
        entries.push_back(entry);
        position = blockEnd + closing.size();
    }
    std::sort(entries.begin(), entries.end(), [](const FormationEntry &a, const FormationEntry &b) {
        return a.slot < b.slot;
    });
    return entries;
}

std::vector<FormationEntry> NormalizeFormation(std::vector<FormationEntry> entries) {
    if (entries.empty()) return entries;
    const std::map<std::string, Vec2> defaults = DefaultRolePositions();
    std::vector<Vec2> positions;
    positions.reserve(entries.size());
    for (const FormationEntry &entry : entries) {
        Vec2 defaultPosition = Vec2(0.0f, 0.0f);
        auto found = defaults.find(entry.role);
        if (found != defaults.end()) defaultPosition = found->second;
        positions.push_back(entry.databasePosition * 0.6f + defaultPosition * 0.4f);
    }

    const float minDistanceFraction = 0.5f;
    const unsigned int maxIterations = 10;
    for (unsigned int iteration = 0; iteration < maxIterations; ++iteration) {
        std::vector<Vec2> offset(positions.size());
        bool changed = false;
        for (size_t p1 = 0; p1 + 1 < positions.size(); ++p1) {
            if (entries[p1].role == "GK") continue;
            for (size_t p2 = p1 + 1; p2 < positions.size(); ++p2) {
                if (entries[p2].role == "GK") continue;
                Vec2 difference = positions[p1] - positions[p2];
                if (difference.Length() >= minDistanceFraction) continue;
                changed = true;
                float distanceFactor = 1.0f - (difference.Length() / minDistanceFraction);
                Vec2 direction = difference.NormalizedOr(Vec2(0.0f, 1.0f));
                Vec2 push = direction * minDistanceFraction * distanceFactor * 0.5f;
                offset[p1] += push;
                offset[p2] -= push;
            }
        }
        if (!changed) break;
        for (size_t i = 0; i < positions.size(); ++i) {
            Vec2 position = positions[i] + offset[i];
            positions[i] = Vec2(Clamp(position.x, -1.0f, 1.0f), Clamp(position.y, -1.0f, 1.0f));
        }
    }
    for (size_t i = 0; i < entries.size(); ++i) entries[i].position = positions[i];
    return entries;
}

std::map<std::string, float> ParseProfile(const std::string &xml) {
    std::map<std::string, float> profile;
    size_t position = 0;
    while (true) {
        size_t open = xml.find('<', position);
        if (open == std::string::npos) break;
        size_t close = xml.find('>', open);
        if (close == std::string::npos) break;
        std::string name = xml.substr(open + 1, close - open - 1);
        size_t valueEnd = xml.find('<', close + 1);
        if (valueEnd == std::string::npos) break;
        if (!name.empty() && name[0] != '/') {
            profile[name] = static_cast<float>(atof(xml.substr(close + 1, valueEnd - close - 1).c_str()));
        }
        position = valueEnd;
    }
    return profile;
}

void JsonString(FILE *out, const std::string &value) {
    fputc('"', out);
    for (char c : value) {
        if (c == '"' || c == '\\') {
            fputc('\\', out);
            fputc(c, out);
        } else if (c == '\n') {
            fputs("\\n", out);
        } else if (c == '\r') {
            fputs("\\r", out);
        } else if (c == '\t') {
            fputs("\\t", out);
        } else {
            fputc(c, out);
        }
    }
    fputc('"', out);
}

std::string ColumnText(sqlite3_stmt *statement, int column) {
    const unsigned char *text = sqlite3_column_text(statement, column);
    return text ? reinterpret_cast<const char *>(text) : "";
}

} // namespace

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s <database.sqlite> <output.json>\n", argv[0]);
        return 2;
    }

    sqlite3 *database = nullptr;
    if (sqlite3_open_v2(argv[1], &database, SQLITE_OPEN_READONLY, nullptr) != SQLITE_OK) {
        fprintf(stderr, "cannot open database: %s\n", sqlite3_errmsg(database));
        return 1;
    }

    const int sampleStride = 100;
    const int sampleTeams[] = {3, 8, 4407};
    const int samplePlayerIds[] = {16694}; // Declan Rice: high base_stat at peak age
    const int formationTeams[] = {1, 3, 8, 100, 1000, 280, 4407};

    sqlite3_stmt *statement = nullptr;
    const char *query = "select id, team_id, age, base_stat, profile_xml from players order by id";
    if (sqlite3_prepare_v2(database, query, -1, &statement, nullptr) != SQLITE_OK) {
        fprintf(stderr, "cannot query players: %s\n", sqlite3_errmsg(database));
        return 1;
    }

    double sums[kStatCount] = {0};
    double sumsSquares[kStatCount] = {0};
    long long playerCount = 0;
    struct SamplePlayer {
        int id;
        int teamId;
        int age;
        float baseStat;
        float stats[kStatCount];
    };
    std::vector<SamplePlayer> samples;

    while (sqlite3_step(statement) == SQLITE_ROW) {
        int id = sqlite3_column_int(statement, 0);
        int teamId = sqlite3_column_int(statement, 1);
        int age = sqlite3_column_int(statement, 2);
        float baseStat = static_cast<float>(sqlite3_column_double(statement, 3));
        std::string profileXml = ColumnText(statement, 4);
        std::map<std::string, float> profile = ParseProfile(profileXml);

        bool isSample = (playerCount % sampleStride == 0);
        for (int team : sampleTeams) {
            if (teamId == team) isSample = true;
        }
        for (int sampleId : samplePlayerIds) {
            if (id == sampleId) isSample = true;
        }
        SamplePlayer sample;
        sample.id = id;
        sample.teamId = teamId;
        sample.age = age;
        sample.baseStat = baseStat;

        for (int i = 0; i < kStatCount; ++i) {
            auto found = profile.find(kStatNames[i]);
            float profileStat = found == profile.end() ? 0.0f : found->second;
            float value = CalculateStat(baseStat, profileStat, static_cast<float>(age));
            sums[i] += value;
            sumsSquares[i] += static_cast<double>(value) * static_cast<double>(value);
            sample.stats[i] = value;
        }
        if (isSample) samples.push_back(sample);
        ++playerCount;
    }
    sqlite3_finalize(statement);

    FILE *out = fopen(argv[2], "wb");
    if (!out) {
        fprintf(stderr, "cannot write %s\n", argv[2]);
        return 1;
    }

    fputs("{\n", out);
    fputs("  \"generated_by\": \"tools/player_stats_reference/main.cpp (C++ transcription of CalculateStat and TeamData::InitFromRaw)\",\n", out);
    fputs("  \"stat_names\": [", out);
    for (int i = 0; i < kStatCount; ++i) {
        if (i > 0) fputs(", ", out);
        JsonString(out, kStatNames[i]);
    }
    fputs("],\n", out);
    fprintf(out, "  \"player_count\": %lld,\n", playerCount);

    fputs("  \"sums\": {", out);
    for (int i = 0; i < kStatCount; ++i) {
        if (i > 0) fputs(", ", out);
        JsonString(out, kStatNames[i]);
        fprintf(out, ": %.12g", sums[i]);
    }
    fputs("},\n", out);

    fputs("  \"sums_squares\": {", out);
    for (int i = 0; i < kStatCount; ++i) {
        if (i > 0) fputs(", ", out);
        JsonString(out, kStatNames[i]);
        fprintf(out, ": %.12g", sumsSquares[i]);
    }
    fputs("},\n", out);

    fputs("  \"samples\": [\n", out);
    for (size_t s = 0; s < samples.size(); ++s) {
        const SamplePlayer &sample = samples[s];
        fprintf(out, "    {\"id\": %d, \"team_id\": %d, \"age\": %d, \"base_stat\": %.9g, \"stats\": {",
                sample.id, sample.teamId, sample.age, sample.baseStat);
        for (int i = 0; i < kStatCount; ++i) {
            if (i > 0) fputs(", ", out);
            JsonString(out, kStatNames[i]);
            fprintf(out, ": %.9g", sample.stats[i]);
        }
        fputs("}}", out);
        if (s + 1 < samples.size()) fputc(',', out);
        fputc('\n', out);
    }
    fputs("  ],\n", out);

    fputs("  \"formations\": [\n", out);
    for (size_t t = 0; t < sizeof(formationTeams) / sizeof(formationTeams[0]); ++t) {
        sqlite3_stmt *teamStatement = nullptr;
        if (sqlite3_prepare_v2(database, "select name, formation_xml from teams where id = ?", -1,
                               &teamStatement, nullptr) != SQLITE_OK) {
            continue;
        }
        sqlite3_bind_int(teamStatement, 1, formationTeams[t]);
        if (sqlite3_step(teamStatement) != SQLITE_ROW) {
            sqlite3_finalize(teamStatement);
            continue;
        }
        std::string name = ColumnText(teamStatement, 0);
        std::vector<FormationEntry> entries = NormalizeFormation(ParseFormation(ColumnText(teamStatement, 1)));
        sqlite3_finalize(teamStatement);

        fprintf(out, "    {\"id\": %d, \"name\": ", formationTeams[t]);
        JsonString(out, name);
        fputs(", \"entries\": [", out);
        for (size_t i = 0; i < entries.size(); ++i) {
            const FormationEntry &entry = entries[i];
            if (i > 0) fputs(", ", out);
            fprintf(out, "{\"slot\": %d, \"role\": ", entry.slot);
            JsonString(out, entry.role);
            fprintf(out, ", \"db_x\": %.9g, \"db_y\": %.9g, \"x\": %.9g, \"y\": %.9g}",
                    entry.databasePosition.x, entry.databasePosition.y,
                    entry.position.x, entry.position.y);
        }
        fputs("]}", out);
        if (t + 1 < sizeof(formationTeams) / sizeof(formationTeams[0])) fputc(',', out);
        fputc('\n', out);
    }
    fputs("  ]\n}\n", out);

    fclose(out);
    sqlite3_close(database);
    printf("wrote %s: %lld players, %zu samples\n", argv[2], playerCount, samples.size());
    return 0;
}
