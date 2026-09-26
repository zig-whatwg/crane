# Architecture: `std.Random` is a view, not a generator

**Date**: 2026-09-22
**Lesson**: `blob_url_store.zig` stored `prng.random()` of a stack-local `DefaultPrng` - a pointer into a dead frame. Consecutive blob UUIDs came out identical and each call wrote 32 bytes into whatever lived there.

**Takeaway**: **Any `{ptr, vtable}` interface (Random, Allocator) must be built over state that outlives it.**
