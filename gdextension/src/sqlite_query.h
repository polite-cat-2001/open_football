#ifndef OPEN_FOOTBALL_SQLITE_QUERY_H
#define OPEN_FOOTBALL_SQLITE_QUERY_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

struct sqlite3;

namespace godot {

// Read-only SQLite connection for the career database. The GDScript catalog
// walks the file itself for the small lookups it always needed; the transfer
// search needs a real query (WHERE/ORDER BY/LIMIT over 120k players) and this
// class exists for that.
class SqliteQuery : public RefCounted {
    GDCLASS(SqliteQuery, RefCounted)

    sqlite3 *db = nullptr;
    String last_error;

protected:
    static void _bind_methods();

public:
    SqliteQuery() = default;
    ~SqliteQuery();

    bool open(const String &path);
    void close();
    bool is_open() const;
    bool exec(const String &sql);
    Array select(const String &sql, const Array &params = Array());
    String last_error_message() const;
};

} // namespace godot

#endif
