#include "sqlite_query.h"

#include <sqlite3.h>

#include <cstring>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

namespace {

// `lower()` in SQLite is ASCII-only, while the search's ordering mirrors the
// prototype's GDScript `to_lower()` (full Unicode). The mapping covers Latin,
// Greek and Cyrillic (every script in the database); anything else is copied
// unchanged, and a test compares the result with the engine's own to_lower().
// Latin Extended-A lowercase pairs (Unicode 15 simple mapping), so Polish and
// Czech names keep the engine's own to_lower() result.
const int LATIN_EXT_A[128] = {
    0x0101, 0x0101, 0x0103, 0x0103, 0x0105, 0x0105, 0x0107, 0x0107,
    0x0109, 0x0109, 0x010B, 0x010B, 0x010D, 0x010D, 0x010F, 0x010F,
    0x0111, 0x0111, 0x0113, 0x0113, 0x0115, 0x0115, 0x0117, 0x0117,
    0x0119, 0x0119, 0x011B, 0x011B, 0x011D, 0x011D, 0x011F, 0x011F,
    0x0121, 0x0121, 0x0123, 0x0123, 0x0125, 0x0125, 0x0127, 0x0127,
    0x0129, 0x0129, 0x012B, 0x012B, 0x012D, 0x012D, 0x012F, 0x012F,
    0x0130, 0x0131, 0x0133, 0x0133, 0x0135, 0x0135, 0x0137, 0x0137,
    0x0138, 0x013A, 0x013A, 0x013C, 0x013C, 0x013E, 0x013E, 0x0140,
    0x0140, 0x0142, 0x0142, 0x0144, 0x0144, 0x0146, 0x0146, 0x0148,
    0x0148, 0x0149, 0x014B, 0x014B, 0x014D, 0x014D, 0x014F, 0x014F,
    0x0151, 0x0151, 0x0153, 0x0153, 0x0155, 0x0155, 0x0157, 0x0157,
    0x0159, 0x0159, 0x015B, 0x015B, 0x015D, 0x015D, 0x015F, 0x015F,
    0x0161, 0x0161, 0x0163, 0x0163, 0x0165, 0x0165, 0x0167, 0x0167,
    0x0169, 0x0169, 0x016B, 0x016B, 0x016D, 0x016D, 0x016F, 0x016F,
    0x0171, 0x0171, 0x0173, 0x0173, 0x0175, 0x0175, 0x0177, 0x0177,
    0x00FF, 0x017A, 0x017A, 0x017C, 0x017C, 0x017E, 0x017E, 0x017F,
};

const int LATIN_EXT_B[208] = {
    0x0180, 0x0253, 0x0183, 0x0183, 0x0185, 0x0185, 0x0254, 0x0188,
    0x0188, 0x0256, 0x0257, 0x018C, 0x018C, 0x018D, 0x01DD, 0x0259,
    0x025B, 0x0192, 0x0192, 0x0260, 0x0263, 0x0195, 0x0269, 0x0268,
    0x0199, 0x0199, 0x019A, 0x019B, 0x026F, 0x0272, 0x019E, 0x0275,
    0x01A1, 0x01A1, 0x01A3, 0x01A3, 0x01A5, 0x01A5, 0x0280, 0x01A8,
    0x01A8, 0x0283, 0x01AA, 0x01AB, 0x01AD, 0x01AD, 0x0288, 0x01B0,
    0x01B0, 0x028A, 0x028B, 0x01B4, 0x01B4, 0x01B6, 0x01B6, 0x0292,
    0x01B9, 0x01B9, 0x01BA, 0x01BB, 0x01BD, 0x01BD, 0x01BE, 0x01BF,
    0x01C0, 0x01C1, 0x01C2, 0x01C3, 0x01C6, 0x01C6, 0x01C6, 0x01C9,
    0x01C9, 0x01C9, 0x01CC, 0x01CC, 0x01CC, 0x01CE, 0x01CE, 0x01D0,
    0x01D0, 0x01D2, 0x01D2, 0x01D4, 0x01D4, 0x01D6, 0x01D6, 0x01D8,
    0x01D8, 0x01DA, 0x01DA, 0x01DC, 0x01DC, 0x01DD, 0x01DF, 0x01DF,
    0x01E1, 0x01E1, 0x01E3, 0x01E3, 0x01E5, 0x01E5, 0x01E7, 0x01E7,
    0x01E9, 0x01E9, 0x01EB, 0x01EB, 0x01ED, 0x01ED, 0x01EF, 0x01EF,
    0x01F0, 0x01F3, 0x01F3, 0x01F3, 0x01F5, 0x01F5, 0x0195, 0x01BF,
    0x01F9, 0x01F9, 0x01FB, 0x01FB, 0x01FD, 0x01FD, 0x01FF, 0x01FF,
    0x0201, 0x0201, 0x0203, 0x0203, 0x0205, 0x0205, 0x0207, 0x0207,
    0x0209, 0x0209, 0x020B, 0x020B, 0x020D, 0x020D, 0x020F, 0x020F,
    0x0211, 0x0211, 0x0213, 0x0213, 0x0215, 0x0215, 0x0217, 0x0217,
    0x0219, 0x0219, 0x021B, 0x021B, 0x021D, 0x021D, 0x021F, 0x021F,
    0x019E, 0x0221, 0x0223, 0x0223, 0x0225, 0x0225, 0x0227, 0x0227,
    0x0229, 0x0229, 0x022B, 0x022B, 0x022D, 0x022D, 0x022F, 0x022F,
    0x0231, 0x0231, 0x0233, 0x0233, 0x0234, 0x0235, 0x0236, 0x0237,
    0x0238, 0x0239, 0x2C65, 0x023C, 0x023C, 0x019A, 0x2C66, 0x023F,
    0x0240, 0x0242, 0x0242, 0x0180, 0x0289, 0x028C, 0x0247, 0x0247,
    0x0249, 0x0249, 0x024B, 0x024B, 0x024D, 0x024D, 0x024F, 0x024F,
};

int lower_codepoint(int code) {
    if (code >= 'A' && code <= 'Z') {
        return code + 32;
    }
    if (code >= 0x00C0 && code <= 0x00DE && code != 0x00D7) {
        return code + 32;
    }
    if (code == 0x0130) {
        // Turkish dotted capital I lowers to a plain i in the engine.
        return 'i';
    }
    if (code >= 0x0100 && code <= 0x017F) {
        return LATIN_EXT_A[code - 0x0100];
    }
    if (code >= 0x0180 && code <= 0x024F) {
        return LATIN_EXT_B[code - 0x0180];
    }
    if (code >= 0x0391 && code <= 0x03AB && code != 0x03A2) {
        return code + 32;
    }
    if (code >= 0x0410 && code <= 0x042F) {
        return code + 32;
    }
    if (code >= 0x0400 && code <= 0x040F) {
        return code + 80;
    }
    return code;
}

int decode_utf8(const unsigned char *text, int *length) {
    unsigned char first = text[0];
    if (first < 0x80) {
        *length = 1;
        return first;
    }
    if ((first & 0xE0) == 0xC0) {
        *length = 2;
        return ((first & 0x1F) << 6) | (text[1] & 0x3F);
    }
    if ((first & 0xF0) == 0xE0) {
        *length = 3;
        return ((first & 0x0F) << 12) | ((text[1] & 0x3F) << 6) | (text[2] & 0x3F);
    }
    if ((first & 0xF8) == 0xF0) {
        *length = 4;
        return ((first & 0x07) << 18) | ((text[1] & 0x3F) << 12)
            | ((text[2] & 0x3F) << 6) | (text[3] & 0x3F);
    }
    *length = 1;
    return first;
}

int encode_utf8(int code, unsigned char *out) {
    if (code < 0x80) {
        out[0] = static_cast<unsigned char>(code);
        return 1;
    }
    if (code < 0x800) {
        out[0] = static_cast<unsigned char>(0xC0 | (code >> 6));
        out[1] = static_cast<unsigned char>(0x80 | (code & 0x3F));
        return 2;
    }
    if (code < 0x10000) {
        out[0] = static_cast<unsigned char>(0xE0 | (code >> 12));
        out[1] = static_cast<unsigned char>(0x80 | ((code >> 6) & 0x3F));
        out[2] = static_cast<unsigned char>(0x80 | (code & 0x3F));
        return 3;
    }
    out[0] = static_cast<unsigned char>(0xF0 | (code >> 18));
    out[1] = static_cast<unsigned char>(0x80 | ((code >> 12) & 0x3F));
    out[2] = static_cast<unsigned char>(0x80 | ((code >> 6) & 0x3F));
    out[3] = static_cast<unsigned char>(0x80 | (code & 0x3F));
    return 4;
}

void of_lower_func(sqlite3_context *context, int argc, sqlite3_value **argv) {
    if (argc != 1 || sqlite3_value_type(argv[0]) == SQLITE_NULL) {
        sqlite3_result_null(context);
        return;
    }
    const unsigned char *text = sqlite3_value_text(argv[0]);
    int size = sqlite3_value_bytes(argv[0]);
    if (text == nullptr) {
        sqlite3_result_null(context);
        return;
    }
    // Worst case each byte becomes a two-byte sequence.
    sqlite3_str *builder = sqlite3_str_new(nullptr);
    int offset = 0;
    while (offset < size) {
        int step = 1;
        int code = decode_utf8(text + offset, &step);
        unsigned char encoded[4];
        int written = encode_utf8(lower_codepoint(code), encoded);
        sqlite3_str_append(builder, reinterpret_cast<const char *>(encoded), written);
        offset += step;
    }
    char *result = sqlite3_str_finish(builder);
    sqlite3_result_text(context, result, -1, sqlite3_free);
}

void bind_value(sqlite3_stmt *statement, int index, const Variant &value) {
    switch (value.get_type()) {
        case Variant::NIL:
            sqlite3_bind_null(statement, index);
            return;
        case Variant::BOOL:
        case Variant::INT:
            sqlite3_bind_int64(statement, index, static_cast<sqlite3_int64>(value));
            return;
        case Variant::FLOAT:
            sqlite3_bind_double(statement, index, static_cast<double>(value));
            return;
        default: {
            CharString utf8 = String(value).utf8();
            sqlite3_bind_text(statement, index, utf8.get_data(), utf8.length(),
                SQLITE_TRANSIENT);
            return;
        }
    }
}

Variant column_value(sqlite3_stmt *statement, int column) {
    switch (sqlite3_column_type(statement, column)) {
        case SQLITE_INTEGER:
            return Variant(static_cast<int64_t>(sqlite3_column_int64(statement, column)));
        case SQLITE_FLOAT:
            return Variant(sqlite3_column_double(statement, column));
        case SQLITE_TEXT: {
            const unsigned char *text = sqlite3_column_text(statement, column);
            return Variant(String::utf8(reinterpret_cast<const char *>(text)));
        }
        case SQLITE_BLOB: {
            const void *data = sqlite3_column_blob(statement, column);
            int size = sqlite3_column_bytes(statement, column);
            PackedByteArray bytes;
            bytes.resize(size);
            if (size > 0) {
                memcpy(bytes.ptrw(), data, size);
            }
            return Variant(bytes);
        }
        default:
            return Variant();
    }
}

} // namespace

SqliteQuery::~SqliteQuery() {
    close();
}

void SqliteQuery::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open", "path"), &SqliteQuery::open);
    ClassDB::bind_method(D_METHOD("close"), &SqliteQuery::close);
    ClassDB::bind_method(D_METHOD("is_open"), &SqliteQuery::is_open);
    ClassDB::bind_method(D_METHOD("exec", "sql"), &SqliteQuery::exec);
    ClassDB::bind_method(D_METHOD("select", "sql", "params"), &SqliteQuery::select,
        DEFVAL(Array()));
    ClassDB::bind_method(D_METHOD("last_error_message"), &SqliteQuery::last_error_message);
}

bool SqliteQuery::open(const String &path) {
    close();
    last_error = String();
    CharString utf8 = path.utf8();
    int result = sqlite3_open_v2(utf8.get_data(), &db, SQLITE_OPEN_READONLY, nullptr);
    if (result != SQLITE_OK) {
        last_error = db != nullptr ? String::utf8(sqlite3_errmsg(db))
                                   : String("cannot open database");
        close();
        return false;
    }
    sqlite3_busy_timeout(db, 2000);
    sqlite3_create_function_v2(db, "of_lower", 1,
        SQLITE_UTF8 | SQLITE_DETERMINISTIC, nullptr, &of_lower_func, nullptr, nullptr,
        nullptr);
    return true;
}

void SqliteQuery::close() {
    if (db != nullptr) {
        sqlite3_close(db);
        db = nullptr;
    }
}

bool SqliteQuery::is_open() const {
    return db != nullptr;
}

bool SqliteQuery::exec(const String &sql) {
    last_error = String();
    if (db == nullptr) {
        last_error = "database is not open";
        return false;
    }
    CharString utf8 = sql.utf8();
    char *message = nullptr;
    int result = sqlite3_exec(db, utf8.get_data(), nullptr, nullptr, &message);
    if (result != SQLITE_OK) {
        last_error = message != nullptr ? String::utf8(message) : String("exec failed");
        if (message != nullptr) {
            sqlite3_free(message);
        }
        return false;
    }
    return true;
}

Array SqliteQuery::select(const String &sql, const Array &params) {
    Array rows;
    last_error = String();
    if (db == nullptr) {
        last_error = "database is not open";
        return rows;
    }
    sqlite3_stmt *statement = nullptr;
    CharString utf8 = sql.utf8();
    int result = sqlite3_prepare_v2(db, utf8.get_data(), utf8.length(), &statement, nullptr);
    if (result != SQLITE_OK) {
        last_error = String::utf8(sqlite3_errmsg(db));
        return rows;
    }
    int expected = sqlite3_bind_parameter_count(statement);
    if (expected != params.size()) {
        last_error = vformat("%d placeholders but %d values", expected, params.size());
        sqlite3_finalize(statement);
        return rows;
    }
    for (int64_t index = 0; index < params.size(); index++) {
        bind_value(statement, static_cast<int>(index) + 1, params[index]);
    }
    int columns = sqlite3_column_count(statement);
    while (sqlite3_step(statement) == SQLITE_ROW) {
        Dictionary row;
        for (int column = 0; column < columns; column++) {
            const char *name = sqlite3_column_name(statement, column);
            row[String::utf8(name)] = column_value(statement, column);
        }
        rows.append(row);
    }
    if (sqlite3_errcode(db) != SQLITE_OK && sqlite3_errcode(db) != SQLITE_DONE) {
        last_error = String::utf8(sqlite3_errmsg(db));
    }
    sqlite3_finalize(statement);
    return rows;
}

String SqliteQuery::last_error_message() const {
    return last_error;
}
