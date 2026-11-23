//! The build side of the linux platform (src/platform/platform_build_protocol.zig):
//! the operating system it answers for and the extra kit parts it builds
//! in. kit/sqlite, the storage engine of a Browser with a profile directory
//! (the user's ruling, 2026-11-21: SQLite on every platform with one), over
//! the system's libsqlite3.
const std = @import("std");
const platform_build = @import("../../platform_build_protocol.zig");
const KitPart = platform_build.KitPart;

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
