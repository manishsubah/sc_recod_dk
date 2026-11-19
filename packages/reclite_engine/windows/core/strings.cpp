#include "strings.h"

#include <cstdio>

#include "win.h"

namespace reclite_engine {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length =
      ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                            static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8.data(),
                        static_cast<int>(utf8.size()), wide.data(), length);
  return wide;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  const int length =
      ::WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                            nullptr, 0, nullptr, nullptr);
  if (length <= 0) {
    return std::string();
  }
  std::string utf8(static_cast<size_t>(length), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                        utf8.data(), length, nullptr, nullptr);
  return utf8;
}

std::string HresultMessage(long hr) {
  wchar_t* buffer = nullptr;
  const DWORD size = ::FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, static_cast<DWORD>(hr), 0, reinterpret_cast<wchar_t*>(&buffer), 0,
      nullptr);
  std::wstring text = size > 0 && buffer != nullptr ? std::wstring(buffer, size) : L"";
  if (buffer != nullptr) {
    ::LocalFree(buffer);
  }
  while (!text.empty() && (text.back() == L'\n' || text.back() == L'\r')) {
    text.pop_back();
  }
  char code[16];
  std::snprintf(code, sizeof(code), "0x%08lX", static_cast<unsigned long>(hr));
  return text.empty() ? std::string(code) : std::string(code) + " " + WideToUtf8(text);
}

}  // namespace reclite_engine
