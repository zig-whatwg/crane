//! The young generation's size: a V8 BUILD option, `-Dv8-young-generation-mb`.
//!
//! A generational collector allocates new objects in a young generation and
//! collects it often. A larger one means fewer young collections - faster
//! for allocation-heavy script - and more memory held between them: by V8,
//! and by every native object a dead wrapper keeps until the collection that
//! finds it. Which is right depends on where a build ships (a desktop, a
//! phone, a server running many Browsers), so the build says:
//!
//!     zig build ... -Dv8-young-generation-mb=<n>
//!
//! `<n>` is megabytes of the WHOLE young generation of each isolate, at
//! rest. V8 and Chrome quote the figure per SEMISPACE, a third of it: V8's
//! young generation under the scavenger is two semispaces and a new large
//! object space of one semispace's size (15.7.112.43 src/heap/heap.cc:
//! 406-415, Heap::YoungGenerationSizeFromSemiSpaceSize: the semispace times
//! NumberOfSemiSpaces() + kNewLargeObjectSpaceToSemiSpaceRatio = 3).
//!
//!   | -Dv8-young-generation-mb | V8 semispace | what it is                       |
//!   |--------------------------|--------------|----------------------------------|
//!   | 24                       | 8 MB         | V8 13.1's ceiling; Chrome on an  |
//!   |                          |              | Android phone below its high-end |
//!   |                          |              | threshold (heap.cc:4844-4860)    |
//!   | 48                       | 16 MB        |                                  |
//!   | 96                       | 32 MB        | V8 15.7's own ceiling, as a      |
//!   |                          |              | number                           |
//!   | 0                        | V8's own     | no constraint: V8 15.7 sizes it  |
//!   |                          |              | (32 MB semispaces; Chrome 157 on |
//!   |                          |              | desktop)                         |
//!   | not given                | `default_mb` | this file's one default          |
//!
//! It is a build option of this adapter and not an option of the engine
//! protocol (the user, 2026-11-12: "will this be necessary for javascript
//! core? If not then it should just be a v8 build flag"): JavaScriptCore's
//! public API has no heap sizing at all - JSBase.h offers JSGarbageCollect
//! and nothing else about the heap, JSContextRef.h and JSVirtualMachine.h
//! nothing - so no other engine Crane runs on could honour it. Being the
//! build's, it reaches every isolate the adapter makes - the window agent's
//! and every worker's - with nothing for a host to pass along.
//!
//! How it is applied: the ceiling an embedder gives is ResourceConstraints::
//! set_max_young_generation_size_in_bytes (include/v8-isolate.h:133-143),
//! set on the isolate's CreateParams before it initializes (v8_wrapper.cpp
//! applyHeapConstraints, at both isolate-creation sites). It is the embedder
//! API for this: gin configures the same ceiling through ResourceConstraints
//! ::ConfigureDefaults(physical memory, virtual memory) (Chromium
//! 157.0.8103.50 gin/isolate_holder.cc:186-190), which on a desktop comes to
//! V8's own 32 MB semispaces and on an Android phone below Chrome's high-end
//! threshold to 8 MB. No V8 flag string: `--max-semi-space-size` would do the
//! same for the process, and stays what it is - a measurement route
//! (-Dv8-extra-flags).
//!
//! Rounding: Heap::ConfigureHeap divides the constraint by three and rounds
//! UP to a power of two (heap.cc:4886-4925, std::bit_ceil). A build's value
//! is a promise - "never more than this" - so the adapter does the rounding
//! itself, DOWNWARD: the largest power-of-two semispace three of which fit
//! (20 gives 4 MB semispaces, 12 MB in all; 47 gives 8 MB semispaces), and
//! never less than the 1 MB V8 starts every semispace at (heap.cc:4945-4958;
//! 3 MB in all). V8 does not cap the constraint at its own default: a value
//! above 96 gives semispaces larger than V8's own (192: 64 MB) - nothing
//! Chrome ships, and nothing Crane has tested or measured.
//!
//! "At rest": V8 lets the young generation take pages above its ceiling
//! while a full collection is marking, so as not to end that collection
//! early, and gives them back when it ends (heap.cc:5552-5580); the ceiling
//! is what it returns to.

const std = @import("std");
const build_options = @import("build_options");

/// THE DEFAULT, for a build that does not say: megabytes of the whole young
/// generation, in `-Dv8-young-generation-mb`'s unit; null is V8's own sizing
/// (15.7: 32 MB semispaces - Chrome 157's desktop configuration). ONE
/// constant, so the choice is one line: `24` is 8 MB semispaces (V8 13.1's
/// ceiling), `48` is 16 MB. docs/engine-protocol.md, "The young generation's
/// size is a V8 build option", has what each costs and buys on the perf
/// suite.
pub const default_mb: ?u32 = null;

/// What this build was given: `-Dv8-young-generation-mb` (null: not given).
pub const requested_mb: ?u32 = build_options.v8_young_generation_mb;

/// This build's limit for every isolate's young generation, in bytes of the
/// whole young generation before rounding; null: V8's own sizing.
pub const limit: ?usize = limitFor(requested_mb, default_mb);

/// The limit of a build given `requested` megabytes (null: not given; 0:
/// V8's own sizing) whose default is `default` megabytes (null: V8's own).
pub fn limitFor(requested: ?u32, default: ?u32) ?usize {
    const megabytes = requested orelse (default orelse return null);
    if (megabytes == 0) return null;
    return @as(usize, megabytes) * 1024 * 1024;
}

/// V8's smallest semispace: what every new space starts at.
pub const min_semispace_bytes: usize = 1024 * 1024;

/// Semispaces and semispace-sized spaces in V8's young generation.
pub const semispaces_in_young_generation: usize = 3;

/// The semispace V8 gets for a limit of `bytes`: the largest power of two
/// three of which fit, at least `min_semispace_bytes`.
pub fn semispaceBytes(bytes: usize) usize {
    const third = bytes / semispaces_in_young_generation;
    if (third <= min_semispace_bytes) return min_semispace_bytes;
    return std.math.floorPowerOfTwo(usize, third);
}

/// ffi.IsolateOptions.max_young_generation_bytes for a limit of `bytes`: 0
/// (no constraint: V8's own ceiling) for null.
pub fn maxYoungGenerationBytes(bytes: ?usize) usize {
    return semispaceBytes(bytes orelse return 0) * semispaces_in_young_generation;
}
