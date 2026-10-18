// A minimal JSON writer for the snapshots the native samplers hand to Dart.
#ifndef RUNNER_JSON_WRITER_H_
#define RUNNER_JSON_WRITER_H_

#include <windows.h>

#include <cmath>
#include <cstdio>
#include <string>

namespace oc {

class Json {
 public:
  std::string str;

  Json& Key(const char* k) {
    if (!first_) str += ',';
    first_ = false;
    Quote(k);
    str += ':';
    after_key_ = true;
    return *this;
  }
  Json& Str(const std::string& s) {
    Comma();
    Quote(s);
    return *this;
  }
  Json& Num(double v) {
    Comma();
    if (!std::isfinite(v)) {
      str += "null";
    } else {
      char buf[32];
      snprintf(buf, sizeof(buf), "%.10g", v);
      str += buf;
    }
    return *this;
  }
  // Writes null for a negative value: "no reading".
  Json& Opt(double v) {
    if (v >= 0) return Num(v);
    Comma();
    str += "null";
    return *this;
  }
  Json& Int(long long v) {
    Comma();
    str += std::to_string(v);
    return *this;
  }
  Json& Bool(bool v) {
    Comma();
    str += v ? "true" : "false";
    return *this;
  }
  Json& Obj() {
    Comma();
    str += '{';
    first_ = true;
    return *this;
  }
  Json& EndObj() {
    str += '}';
    first_ = false;
    return *this;
  }
  Json& Arr() {
    Comma();
    str += '[';
    first_ = true;
    return *this;
  }
  Json& EndArr() {
    str += ']';
    first_ = false;
    return *this;
  }

 private:
  void Comma() {
    if (after_key_) {
      after_key_ = false;
    } else if (!first_) {
      str += ',';
    }
    first_ = false;
  }
  void Quote(const std::string& s) {
    str += '"';
    for (unsigned char c : s) {
      if (c == '"' || c == '\\') {
        str += '\\';
        str += static_cast<char>(c);
      } else if (c < 0x20) {
        char buf[8];
        snprintf(buf, sizeof(buf), "\\u%04x", c);
        str += buf;
      } else {
        str += static_cast<char>(c);
      }
    }
    str += '"';
  }
  bool first_ = true;
  bool after_key_ = false;
};

inline std::string Utf8(const std::wstring& w) {
  if (w.empty()) return {};
  const int n = WideCharToMultiByte(CP_UTF8, 0, w.data(),
                                    static_cast<int>(w.size()), nullptr, 0,
                                    nullptr, nullptr);
  std::string s(n, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.data(), static_cast<int>(w.size()),
                      s.data(), n, nullptr, nullptr);
  return s;
}

}  // namespace oc

#endif  // RUNNER_JSON_WRITER_H_
