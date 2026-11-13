//! The BUILD SIDE of the JavaScriptCore adapter (docs/engine-protocol.md,
//! 7b): the interface src/runtime/engine_build_protocol.zig asks of every
//! listed adapter (src/runtime/engines/v8/engine_build.zig says what each
//! declaration is for).
//!
//! The adapter binds the protocol (protocol.zig) and links no engine yet, so
//! this file declares no option and answers `unavailable`: a build with
//! -Dengine=jsc - and a build for iOS, whose engine this is - configures,
//! and each step that needs the engine fails with the reason. When
//! JavaScriptCore is linked, its framework and its options are declared
//! here, and nothing in the root build.zig changes.
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
    shared.addOption([]const u8, "engine_name", "jsc");
    shared.addOption(bool, "has_snapshot_support", false);
    shared.addOption(bool, "has_isolate_per_thread", false);
}

/// iOS is JavaScriptCore's: the system's, linked dynamically (the user,
/// 2026-11-10, ruling R4).
pub fn isDefaultFor(target: std.Target) bool {
    return target.os.tag == .ios;
}

/// Nothing is linked yet.
pub const Resolved = struct {};

pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options) engine_build.Resolution(Resolved) {
    _ = b;
    _ = target;
    _ = options;
    return .{ .unavailable = "the JavaScriptCore adapter (src/runtime/engines/jsc/) links no engine yet: nothing that runs script can be built with -Dengine=jsc, or for iOS, whose engine it is (the user, 2026-11-10: iOS builds wait for this adapter)" };
}

/// Nothing to link yet: the protocol links only an engine that can be built.
pub fn link(b: *std.Build, module: *std.Build.Module, resolved: *const Resolved, request: engine_build.LinkRequest) void {
    _ = b;
    _ = module;
    _ = resolved;
    _ = request;
}

/// `link` puts nothing on a module.
pub fn linkedInto(module: *std.Build.Module) bool {
    _ = module;
    return false;
}

/// What the neutral build asks about this adapter.
pub const facts: engine_build.Facts = .{
    .words = &.{ "jsc", "javascriptcore" },
};
