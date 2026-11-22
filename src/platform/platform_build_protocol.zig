//! THE BUILD SIDE OF THE PLATFORM PROTOCOL (docs/platform-protocol.md 10).
//!
//! What is one platform's in the build beyond its fixed kit - the extra kit
//! parts it builds in and the system libraries each links - is declared by
//! the platform's adapter, in a build file beside its code,
//! `adapters/<platform>/platform_build.zig`, and never by the root build.zig
//! (the user, 2026-11-12: no engine or platform code in build.zig), as the
//! engine's adapters declare theirs (src/runtime/engine_build_protocol.zig).
//! This file is the protocol's part: the list of adapters, the declaration's
//! type, and what the root build.zig asks. The root build names no library.
//!
//! What an adapter's build file exports:
//!
//!   pub fn kitParts(target: std.Target) []const KitPart
//!
//! A part is `src/platform/kit/<name>/root.zig`, a module the adapter
//! imports as `kit_<name>`, made with the platform facade and the platform
//! options as every kit part is, and linked against `system_libraries`.
//! kit/sqlite is the first (the user's ruling, 2026-11-21: SQLite on every
//! platform with a profile directory). A third-party platform
//! (-Dplatform-module) declares none here.
//!
//! Run by `zig build`'s configure step, not compiled into Crane: std and
//! build files only. (tools/lint_build_neutral.zig does not count it: it is
//! where the build side meets the adapters.)
const std = @import("std");

/// The platform adapters, by their -Dplatform name: each one's build file.
pub const adapters = .{
    .darwin = @import("adapters/darwin/platform_build.zig"),
    .linux = @import("adapters/linux/platform_build.zig"),
    .testing = @import("adapters/testing/platform_build.zig"),
};

/// One extra kit part a platform builds in.
pub const KitPart = struct {
    /// Its directory under src/platform/kit/, and the `kit_<name>` import.
    name: []const u8,
    /// The system libraries it links (linkSystemLibrary).
    system_libraries: []const []const u8 = &.{},
};

/// The extra kit parts of the platform named `platform_name` for `target`:
/// its adapter's declaration, none for a platform with no build file here.
pub fn kitParts(platform_name: []const u8, target: std.Target) []const KitPart {
    inline for (@typeInfo(@TypeOf(adapters)).@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, platform_name)) return @field(adapters, field.name).kitParts(target);
    }
    return &.{};
}

/// Link `module`, part `part`'s module, against what the part declares.
pub fn link(module: *std.Build.Module, part: KitPart) void {
    for (part.system_libraries) |library| module.linkSystemLibrary(library, .{});
}
