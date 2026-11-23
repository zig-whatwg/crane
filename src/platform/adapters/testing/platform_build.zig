//! The build side of the testing platform (src/platform/platform_build_protocol.zig):
//! the extra kit parts it builds in. kit/sqlite, the storage engine of a
//! Browser with a profile directory (the user's ruling, 2026-11-21: SQLite on
//! every platform with one), over the system's libsqlite3.
const std = @import("std");
const KitPart = @import("../../platform_build_protocol.zig").KitPart;

pub fn kitParts(target: std.Target) []const KitPart {
    _ = target;
    return &.{.{ .name = "sqlite", .system_libraries = &.{"sqlite3"} }};
}
