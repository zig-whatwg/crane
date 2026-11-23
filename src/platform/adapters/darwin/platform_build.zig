//! The build side of the darwin platform (src/platform/platform_build_protocol.zig):
//! the operating systems it answers for and the extra kit parts it builds
//! in. kit/sqlite, the storage engine of a Browser with a profile directory
//! (the user's ruling, 2026-11-21: SQLite on every platform with one), over
//! the system's libsqlite3 (macOS and iOS ship it: libsqlite3.tbd in the SDKs).
const std = @import("std");
const platform_build = @import("../../platform_build_protocol.zig");
const KitPart = platform_build.KitPart;

/// darwin answers for macOS and iOS: the platform a target of either binds
/// when -Dplatform does not say.
pub fn ownsTarget(target: std.Target) bool {
    return switch (target.os.tag) {
        .macos, .ios => true,
        else => false,
    };
}

pub fn kitParts(target: std.Target) []const KitPart {
    _ = target;
    return &.{.{ .name = "sqlite", .system_libraries = &.{"sqlite3"} }};
}

pub const facts: platform_build.Facts = .{
    // The platform, its two systems, the iPhoneOS SDK and its tool, and the
    // macOS package manager whose paths the build reads.
    .words = &.{ "darwin", "macos", "word:ios", "iphoneos", "xcrun", "homebrew" },
};
