//! [young_generation_limit]: engine.AgentOptions.young_generation_limit as
//! V8's ResourceConstraints understand it.
//!
//! V8's young generation under the scavenger is two semispaces and a new
//! large object space of one semispace's size (15.7.112.43 src/heap/heap.cc:
//! 406-415, Heap::YoungGenerationSizeFromSemiSpaceSize: the semispace times
//! NumberOfSemiSpaces() + kNewLargeObjectSpaceToSemiSpaceRatio = 3), and the
//! ceiling an embedder gives is ResourceConstraints::
//! set_max_young_generation_size_in_bytes (include/v8-isolate.h:133-143),
//! which Heap::ConfigureHeap divides by three and rounds UP to a power of two
//! (heap.cc:4886-4925, std::bit_ceil). The protocol's option promises "never
//! more than the host said", so the adapter does the rounding itself,
//! DOWNWARD: the largest power-of-two semispace three of which fit the limit,
//! and never less than the 1 MB V8 starts every semispace at (heap.cc:
//! 4945-4958).
//!
//! It is the embedder API for this: gin configures the same ceiling through
//! ResourceConstraints::ConfigureDefaults(physical memory, virtual memory)
//! (Chromium 157.0.8103.50 gin/isolate_holder.cc:186-190), which on a desktop
//! comes to V8's own 32 MB semispaces and on an Android phone below Chrome's
//! high-end threshold to 8 MB (heap.cc:4844-4860). No V8 flag string: a flag
//! is the process's, and an agent's ceiling is its host's to choose.

const std = @import("std");

/// V8's smallest semispace: what every new space starts at.
pub const min_semispace_bytes: usize = 1024 * 1024;

/// Semispaces and semispace-sized spaces in V8's young generation.
pub const semispaces_in_young_generation: usize = 3;

/// The semispace V8 gets for a host's `limit`: the largest power of two
/// three of which fit, at least `min_semispace_bytes`.
pub fn semispaceBytes(limit: usize) usize {
    const third = limit / semispaces_in_young_generation;
    if (third <= min_semispace_bytes) return min_semispace_bytes;
    return std.math.floorPowerOfTwo(usize, third);
}

/// ffi.IsolateOptions.max_young_generation_bytes for an agent's
/// `young_generation_limit`: 0 (no constraint: V8's own ceiling) for null.
pub fn maxYoungGenerationBytes(limit: ?usize) usize {
    const bytes = limit orelse return 0;
    return semispaceBytes(bytes) * semispaces_in_young_generation;
}
