//! The BUILD SIDE of the QuickJS adapter (docs/engine-protocol.md, 7b): the
//! interface src/runtime/engine_build_protocol.zig asks of every listed
//! adapter (src/runtime/engines/v8/engine_build.zig says what each
//! declaration is for).
//!
//! The adapter binds the protocol (protocol.zig) and links no engine yet, so
//! this file declares no option and answers `unavailable`: a build with
//! -Dengine=quickjs configures, and each step that needs the engine fails
//! with the reason. When QuickJS is linked, its sources and its options are
//! declared here, and nothing in the root build.zig changes.
//!
//! Run by `zig build`'s configure step, not compiled into Crane.

const std = @import("std");
const engine_build = @import("../../engine_build_protocol.zig");

/// The adapter has no build option yet.
pub const Options = struct {};

pub fn declareOptions(b: *std.Build, target: std.Build.ResolvedTarget) Options {
    _ = b;
    _ = target;
    return .{};
}

/// Nothing to put in the adapter's own options module.
pub fn apply(options: Options, adapter_options: *std.Build.Step.Options) void {
    _ = options;
    _ = adapter_options;
}

/// TRANSITIONAL (batch E5 of tmp/plans/build-protocol-design.md ends it): the
/// three engine facts the shared `build_options` carries and nothing reads,
/// with the values the root build.zig gave a build of this engine.
pub fn applyTransitional(options: Options, shared: *std.Build.Step.Options) void {
    _ = options;
    shared.addOption([]const u8, "engine_name", "quickjs");
    shared.addOption(bool, "has_snapshot_support", false);
    shared.addOption(bool, "has_isolate_per_thread", false);
}

/// No target's engine unless -Dengine asks for it.
pub fn isDefaultFor(target: std.Target) bool {
    _ = target;
    return false;
}

/// Nothing is linked yet.
pub const Resolved = struct {};

pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options) engine_build.Resolution(Resolved) {
    _ = b;
    _ = target;
    _ = options;
    return .{ .unavailable = "the QuickJS adapter (src/runtime/engines/quickjs/) links no engine yet: nothing that runs script can be built with -Dengine=quickjs" };
}

/// Nothing to link yet: the protocol links only an engine that can be built.
pub fn link(b: *std.Build, module: *std.Build.Module, resolved: *const Resolved, request: engine_build.LinkRequest) void {
    _ = b;
    _ = module;
    _ = resolved;
    _ = request;
}

/// What the neutral build asks about this adapter.
pub const facts: engine_build.Facts = .{
    .words = &.{"quickjs"},
};
