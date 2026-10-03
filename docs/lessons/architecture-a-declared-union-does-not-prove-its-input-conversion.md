# Architecture: A declared union does not prove its input conversion

**Date**: 2026-10-02
**Lesson**: Trace a script argument through the adapter before treating a generated union as an implemented input type.

**Why**: A generated Zig union can describe an IDL type accurately while the generic JavaScript conversion path recognizes none of its object alternatives. The impl then never receives a valid script argument.

**What Happened**: WebCrypto's BufferSource was a union of an ArrayBuffer pointer and an ArrayBufferView union. Neither alternative matched the adapter's generic union dispatch. AlgorithmIdentifier's `object: runtime.JSValue` alternative also failed that dispatch, which recognized dictionary structs but not a general object alternative. Valid buffers and algorithm dictionaries became TypeErrors before SubtleCrypto's stubs ran. Separately, the ArrayBufferView conversion cloned a handle which argument cleanup did not release; the typed result converter only borrowed it.

**Fix**: Pin the script-facing input shapes in Crane tests, then have the adapter owner implement the conversions and their ownership contract together. The WebCrypto lane keeps the generated signatures intact, reads borrowed values only during the synchronous steps, and copies bytes needed by asynchronous work. This session identified the gaps and handed their fixes to the adapter lane; it did not work around them in impl code.

**Takeaway**: **Check both union selection and argument cleanup at the binding seam; a complete IDL surface proves neither.**
