//! The build side of the testing platform (src/platform/platform_build_protocol.zig):
//! the operating systems it answers for - none - and the extra kit parts it
//! builds in. kit/sqlite, the storage engine of a Browser with a profile
//! directory (the user's ruling, 2026-11-21: SQLite on every platform with
//! one), over the system's libsqlite3.
const std = @import("std");
const platform_build = @import("../../platform_build_protocol.zig");
const KitPart = platform_build.KitPart;

/// The testing platform answers for no operating system: it is the build
/// machine's real OS services plus test capabilities (docs/platform-protocol.md
/// 9), bound for the tests (`tests_platform`) or when -Dplatform asks.
pub fn ownsTarget(target: std.Target) bool {
    _ = target;
    return false;
}

pub fn kitParts(target: std.Target) []const KitPart {
    _ = target;
    return &.{.{ .name = "sqlite", .system_libraries = &.{"sqlite3"} }};
}

pub const facts: platform_build.Facts = .{
    // The adapter's name as build code spells it: the enum literal (the
    // word alone is everywhere, std.testing included).
    .words = &.{".testing"},
};
