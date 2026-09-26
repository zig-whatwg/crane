# Architecture: `SuppressMicrotaskExecutionScope` must live on the C++ stack

**Date**: 2026-09-22
**Lesson**: The scope records its own address as the isolate's last API entry, so it cannot be heap-allocated and handed across the FFI; `v8_RunWithMicrotasksSuppressed(isolate, body, data)` holds it on the C++ stack and runs a callback inside.

**Takeaway**: **When a V8 scope object keys off its own address, the FFI takes a callback, not a handle.**
