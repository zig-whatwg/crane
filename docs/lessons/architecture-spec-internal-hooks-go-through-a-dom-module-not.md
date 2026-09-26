# Architecture: Spec-internal hooks go through a dom module, not another impl

**Date**: 2026-09-22
**Lesson**: No IDL member adds an abort algorithm to an AbortSignal, so pipeTo reaches it through `src/dom/abort_algorithms.zig`, which AbortSignal installs into - the same shape as `mutation.zig`'s insertion-steps registry. Use this pattern, not an impl-to-impl call, for any algorithm with no IDL surface.
