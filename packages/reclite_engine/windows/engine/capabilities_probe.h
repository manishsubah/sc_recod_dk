#ifndef RECLITE_ENGINE_CAPABILITIES_PROBE_H_
#define RECLITE_ENGINE_CAPABILITIES_PROBE_H_

#include "../messages.g.h"

namespace reclite_engine {

// Detects what this PC and Windows version can do. Cheap; safe on the
// platform thread.
EngineCapabilities QueryCapabilities();

}  // namespace reclite_engine

#endif  // RECLITE_ENGINE_CAPABILITIES_PROBE_H_
