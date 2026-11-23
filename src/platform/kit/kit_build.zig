//! THE KIT'S BUILD SIDE (docs/platform-protocol.md 10;
//! tmp/plans/build-protocol-design.md 2.4). The platform kit is not an
//! adapter, but its C libraries are the platform's, so they are built here
//! and in the build files beside the parts that link them, never in the
//! root build.zig (the user, 2026-11-12: no engine or platform code in
//! build.zig):
//!
//!   brotli/brotli_build.zig              Brotli, the RFC 7932 codec
//!
//! The root build reaches this file through the platform protocol's build
//! side (src/platform/platform_build_protocol.zig `kit`) and names no
//! library.
//!
//! Run by `zig build`'s configure step, not compiled into Crane: std and
//! build files only.
const std = @import("std");

/// The parts' build files.
pub const brotli = @import("brotli/brotli_build.zig");

/// What a C compile or a C-header translation for the target needs beyond
/// what Zig finds by itself - a system root's headers, libraries and
/// frameworks - supplied by the platform that answers for the target
/// (the design's `prepareC`, 2.4); null when it needs nothing. The kit calls
/// it wherever it makes C for the target, and knows nothing of what it adds.
pub const PrepareC = struct {
    /// For a module that compiles or links C.
    module: *const fn (module: *std.Build.Module) void,
    /// For every compile reachable from a step: a library's own and the
    /// libraries it links, which are artifacts of their own.
    graph: *const fn (step: *std.Build.Step) void,
    /// For a translation of C headers to Zig (`addTranslateC`).
    translate: *const fn (translate: *std.Build.Step.TranslateC) void,
};
