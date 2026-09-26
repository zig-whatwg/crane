# Architecture: One handle kind per layer

**Date**: 2026-09-22
**Lesson**: A `runtime.JSValue` handle is always a `Global<Value>*`, and
`GlobalHandle.get()` returns a LOCAL slot pointer that is merely typed
`*ffi.Value`. Mixing them reads an object's first word as a handle location.

**What Happened**: the WritableStream constructor cast a JSValue handle to a Zig
dictionary struct; elsewhere a Local slot was passed where a Global was
expected. An argument typed `object` in IDL must be converted by the impl,
reading members with Get in lexicographic order (WebIDL dictionary conversion).

**Takeaway**: **Know which handle kind you hold; the types will not tell you.**
