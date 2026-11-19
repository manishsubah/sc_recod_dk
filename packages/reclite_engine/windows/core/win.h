#ifndef RECLITE_ENGINE_CORE_WIN_H_
#define RECLITE_ENGINE_CORE_WIN_H_

// Include order matters: <unknwn.h> before C++/WinRT enables classic COM interop.
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <unknwn.h>
#include <wrl/client.h>

#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace reclite_engine {

using Microsoft::WRL::ComPtr;

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CORE_WIN_H_
