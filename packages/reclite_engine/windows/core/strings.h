#ifndef RECLITE_ENGINE_CORE_STRINGS_H_
#define RECLITE_ENGINE_CORE_STRINGS_H_

#include <string>

namespace reclite_engine {

// UTF-8 (Dart strings) <-> UTF-16 (Win32 APIs).
std::wstring Utf8ToWide(const std::string& utf8);
std::string WideToUtf8(const std::wstring& wide);

// Readable text for an HRESULT, e.g. "0x80070005 Access is denied.".
std::string HresultMessage(long hr);

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CORE_STRINGS_H_
