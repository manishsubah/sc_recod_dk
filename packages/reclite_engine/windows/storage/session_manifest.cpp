#include "session_manifest.h"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <map>
#include <memory>
#include <sstream>

namespace reclite_engine {
namespace {

std::string Quote(const std::string& text) {
  std::string out = "\"";
  for (const unsigned char c : text) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (c < 0x20) {
          char escaped[8];
          std::snprintf(escaped, sizeof(escaped), "\\u%04x", c);
          out += escaped;
        } else {
          out += static_cast<char>(c);
        }
    }
  }
  return out + "\"";
}

std::string Number(double value) {
  std::ostringstream out;
  out.precision(15);
  out << value;
  return out.str();
}

// Minimal JSON reader for the manifest's own shape (objects, arrays, strings,
// numbers, booleans, null). Unknown keys are ignored.
struct Value {
  enum class Type { kNull, kBool, kNumber, kString, kArray, kObject } type = Type::kNull;
  bool boolean = false;
  double number = 0;
  std::string string;
  std::vector<Value> array;
  std::map<std::string, Value> object;

  const Value* Get(const std::string& key) const {
    const auto it = object.find(key);
    return it == object.end() ? nullptr : &it->second;
  }
};

class Parser {
 public:
  explicit Parser(const std::string& text) : text_(text) {}

  bool Parse(Value* out) {
    if (!ParseValue(out, 0)) return false;
    SkipSpace();
    return pos_ == text_.size();
  }

 private:
  static constexpr int kMaxDepth = 32;

  void SkipSpace() {
    while (pos_ < text_.size() && std::isspace(static_cast<unsigned char>(text_[pos_]))) {
      ++pos_;
    }
  }

  bool Consume(char c) {
    SkipSpace();
    if (pos_ < text_.size() && text_[pos_] == c) {
      ++pos_;
      return true;
    }
    return false;
  }

  bool Literal(const char* word) {
    const std::string expected(word);
    if (text_.compare(pos_, expected.size(), expected) != 0) return false;
    pos_ += expected.size();
    return true;
  }

  bool ParseValue(Value* out, int depth) {
    if (depth > kMaxDepth) return false;
    SkipSpace();
    if (pos_ >= text_.size()) return false;
    const char c = text_[pos_];
    if (c == '{') return ParseObject(out, depth);
    if (c == '[') return ParseArray(out, depth);
    if (c == '"') {
      out->type = Value::Type::kString;
      return ParseString(&out->string);
    }
    if (c == 't' && Literal("true")) {
      out->type = Value::Type::kBool;
      out->boolean = true;
      return true;
    }
    if (c == 'f' && Literal("false")) {
      out->type = Value::Type::kBool;
      return true;
    }
    if (c == 'n' && Literal("null")) {
      out->type = Value::Type::kNull;
      return true;
    }
    return ParseNumber(out);
  }

  bool ParseObject(Value* out, int depth) {
    out->type = Value::Type::kObject;
    ++pos_;
    if (Consume('}')) return true;
    do {
      SkipSpace();
      std::string key;
      if (!ParseString(&key) || !Consume(':')) return false;
      Value value;
      if (!ParseValue(&value, depth + 1)) return false;
      out->object[key] = std::move(value);
    } while (Consume(','));
    return Consume('}');
  }

  bool ParseArray(Value* out, int depth) {
    out->type = Value::Type::kArray;
    ++pos_;
    if (Consume(']')) return true;
    do {
      Value value;
      if (!ParseValue(&value, depth + 1)) return false;
      out->array.push_back(std::move(value));
    } while (Consume(','));
    return Consume(']');
  }

  bool ParseString(std::string* out) {
    if (pos_ >= text_.size() || text_[pos_] != '"') return false;
    ++pos_;
    while (pos_ < text_.size()) {
      const char c = text_[pos_++];
      if (c == '"') return true;
      if (c != '\\') {
        *out += c;
        continue;
      }
      if (pos_ >= text_.size()) return false;
      const char e = text_[pos_++];
      switch (e) {
        case '"': *out += '"'; break;
        case '\\': *out += '\\'; break;
        case '/': *out += '/'; break;
        case 'n': *out += '\n'; break;
        case 'r': *out += '\r'; break;
        case 't': *out += '\t'; break;
        case 'b': *out += '\b'; break;
        case 'f': *out += '\f'; break;
        case 'u': {
          if (pos_ + 4 > text_.size()) return false;
          // strtoul, not stoul: Flutter builds Windows plugins without STL exceptions.
          const std::string hex = text_.substr(pos_, 4);
          char* hex_end = nullptr;
          const unsigned code = static_cast<unsigned>(std::strtoul(hex.c_str(), &hex_end, 16));
          if (hex_end != hex.c_str() + 4) return false;
          pos_ += 4;
          // BMP code point to UTF-8 (the manifest only ever escapes control characters).
          if (code < 0x80) {
            *out += static_cast<char>(code);
          } else if (code < 0x800) {
            *out += static_cast<char>(0xC0 | (code >> 6));
            *out += static_cast<char>(0x80 | (code & 0x3F));
          } else {
            *out += static_cast<char>(0xE0 | (code >> 12));
            *out += static_cast<char>(0x80 | ((code >> 6) & 0x3F));
            *out += static_cast<char>(0x80 | (code & 0x3F));
          }
          break;
        }
        default:
          return false;
      }
    }
    return false;
  }

  bool ParseNumber(Value* out) {
    const size_t start = pos_;
    while (pos_ < text_.size() &&
           (std::isdigit(static_cast<unsigned char>(text_[pos_])) || text_[pos_] == '-' ||
            text_[pos_] == '+' || text_[pos_] == '.' || text_[pos_] == 'e' ||
            text_[pos_] == 'E')) {
      ++pos_;
    }
    if (pos_ == start) return false;
    const std::string digits = text_.substr(start, pos_ - start);
    char* end = nullptr;
    out->number = std::strtod(digits.c_str(), &end);
    if (end != digits.c_str() + digits.size()) return false;
    out->type = Value::Type::kNumber;
    return true;
  }

  const std::string& text_;
  size_t pos_ = 0;
};

std::string StringOr(const Value& object, const std::string& key, const std::string& fallback) {
  const Value* v = object.Get(key);
  return v && v->type == Value::Type::kString ? v->string : fallback;
}

double NumberOr(const Value& object, const std::string& key, double fallback) {
  const Value* v = object.Get(key);
  return v && v->type == Value::Type::kNumber ? v->number : fallback;
}

bool BoolOr(const Value& object, const std::string& key, bool fallback) {
  const Value* v = object.Get(key);
  return v && v->type == Value::Type::kBool ? v->boolean : fallback;
}

}  // namespace

int64_t SessionManifest::TotalDurationMs() const {
  int64_t total = 0;
  for (const auto& segment : segments) {
    total += segment.duration_ms;
  }
  return total;
}

void SessionManifest::AddSegment(const Segment& segment) {
  const bool listed = std::any_of(segments.begin(), segments.end(),
                                  [&](const Segment& s) { return s.index == segment.index; });
  if (listed) {
    return;
  }
  segments.push_back(segment);
  std::sort(segments.begin(), segments.end(),
            [](const Segment& a, const Segment& b) { return a.index < b.index; });
}

std::string SessionManifest::ToJson() const {
  std::ostringstream out;
  out << "{\n";
  out << "  \"app\" : \"RecLite\",\n";
  out << "  \"audio\" : { \"microphone\" : " << (microphone ? "true" : "false")
      << ", \"system\" : " << (system_audio ? "true" : "false") << " },\n";
  if (!ended_at.empty()) {
    out << "  \"endedAt\" : " << Quote(ended_at) << ",\n";
  }
  out << "  \"segmentSeconds\" : " << segment_seconds << ",\n";
  out << "  \"segments\" : [";
  for (size_t i = 0; i < segments.size(); ++i) {
    const Segment& s = segments[i];
    out << (i == 0 ? "\n" : ",\n") << "    { \"bytes\" : " << s.bytes
        << ", \"durationMs\" : " << s.duration_ms << ", \"file\" : " << Quote(s.file)
        << ", \"index\" : " << s.index << ", \"status\" : " << Quote(s.status) << " }";
  }
  out << (segments.empty() ? "],\n" : "\n  ],\n");
  out << "  \"sessionId\" : " << Quote(session_id) << ",\n";
  out << "  \"source\" : { ";
  if (area.size() == 4) {
    out << "\"area\" : [" << Number(area[0]) << ", " << Number(area[1]) << ", "
        << Number(area[2]) << ", " << Number(area[3]) << "], ";
  }
  out << "\"name\" : " << Quote(source_name) << ", \"type\" : " << Quote(source_type)
      << " },\n";
  out << "  \"startedAt\" : " << Quote(started_at) << ",\n";
  out << "  \"status\" : " << Quote(status) << ",\n";
  out << "  \"version\" : 1,\n";
  out << "  \"video\" : { \"codec\" : \"h264\", \"fps\" : " << fps << ", \"height\" : " << height
      << ", \"width\" : " << width << " }\n";
  out << "}\n";
  return out.str();
}

std::optional<SessionManifest> SessionManifest::FromJson(const std::string& json) {
  Value root;
  if (!Parser(json).Parse(&root) || root.type != Value::Type::kObject) {
    return std::nullopt;
  }
  SessionManifest m;
  m.session_id = StringOr(root, "sessionId", "");
  m.started_at = StringOr(root, "startedAt", "");
  m.ended_at = StringOr(root, "endedAt", "");
  m.status = StringOr(root, "status", "recording");
  m.segment_seconds = static_cast<int>(NumberOr(root, "segmentSeconds", 0));
  if (const Value* source = root.Get("source")) {
    m.source_type = StringOr(*source, "type", "display");
    m.source_name = StringOr(*source, "name", "");
    if (const Value* area = source->Get("area"); area && area->array.size() == 4) {
      for (const Value& v : area->array) m.area.push_back(v.number);
    }
  }
  if (const Value* audio = root.Get("audio")) {
    m.system_audio = BoolOr(*audio, "system", false);
    m.microphone = BoolOr(*audio, "microphone", false);
  }
  if (const Value* video = root.Get("video")) {
    m.width = static_cast<int>(NumberOr(*video, "width", 0));
    m.height = static_cast<int>(NumberOr(*video, "height", 0));
    m.fps = static_cast<int>(NumberOr(*video, "fps", 0));
  }
  if (const Value* list = root.Get("segments")) {
    for (const Value& item : list->array) {
      Segment s;
      s.index = static_cast<int>(NumberOr(item, "index", 0));
      s.file = StringOr(item, "file", "");
      s.duration_ms = static_cast<int64_t>(NumberOr(item, "durationMs", 0));
      s.bytes = static_cast<int64_t>(NumberOr(item, "bytes", 0));
      s.status = StringOr(item, "status", "complete");
      m.AddSegment(s);
    }
  }
  return m;
}

}  // namespace reclite_engine
