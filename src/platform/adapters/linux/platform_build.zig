//! The build side of the linux platform (src/platform/platform_build_protocol.zig):
//! the operating system it answers for and the extra kit parts it builds
//! in. kit/sqlite, the storage engine of a Browser with a profile directory
//! (the user's ruling, 2026-11-21: SQLite on every platform with one), over
//! the system's libsqlite3.
const std = @import("std");
const platform_build = @import("../../platform_build_protocol.zig");
const KitPart = platform_build.KitPart;
const kit_build = @import("../../kit/kit_build.zig");

/// linux answers for Linux: the platform a Linux target binds when
/// -Dplatform does not say.
pub fn ownsTarget(target: std.Target) bool {
    return target.os.tag == .linux;
}

pub fn kitParts(target: std.Target) []const KitPart {
    _ = target;
    return &.{.{ .name = "sqlite", .system_libraries = &.{"sqlite3"} }};
}

pub const facts: platform_build.Facts = .{
    .words = &.{"linux"},
};

/// No -D options of its own.
pub const Options = struct {};
pub fn declareOptions(b: *std.Build) Options {
    _ = b;
    return .{};
}

/// Nothing to read of the machine.
pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options, probe: *std.Build.Step.Compile) void {
    _ = .{ b, target, options, probe };
}

/// No arguments for a sub-build.
pub fn forwarded(b: *std.Build, options: Options) []const []const u8 {
    _ = .{ b, options };
    return &.{};
}

/// Zig finds what its C needs by itself.
pub fn prepareC(target: std.Build.ResolvedTarget) ?kit_build.PrepareC {
    _ = target;
    return null;
}

/// Nothing more for a finished program or library.
pub fn linkArtifact(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    _ = .{ module, target };
}

/// Its implementation links nothing of its own beyond its kit parts.
pub fn bind(impl: *std.Build.Module, target: std.Build.ResolvedTarget, request: platform_build.BindRequest) void {
    _ = .{ impl, target, request };
}
