//! Which V8 archives a build links: `-Dv8-build` and the target's OS.
//!
//! build.zig links three static archives from one V8 output directory under
//! jsengines/v8/out/ (`linkV8`, and the artifacts that add them by hand). Two
//! macOS builds of the same V8, 13.1.203, exist side by side:
//!
//! - `static` (the default): out/static, the release build of
//!   scripts/build-v8-static.sh's GN arguments - no ThinLTO, no PGO.
//! - `official`: out/official, scripts/build-v8-official.sh - the same
//!   arguments plus what Chrome's official build adds (is_official_build:
//!   ThinLTO with Chrome's mac-arm64 clang PGO profile, and V8's builtins
//!   PGO). Its ThinLTO step has already run: the archives hold native arm64
//!   Mach-O objects, since Zig's linker cannot read LLVM bitcode. It exists
//!   on chat.local only (every pool mirror's jsengines/v8 is the host's), so
//!   a build with -Dv8-build=official runs there until the user decides on
//!   a default (2026-11-04).
//!
//! out/static is also the official build's baseline: the control build of
//! scripts/build-v8-official.sh - out/static's arguments from a 13.1.203
//! checkout, with the clang 13.1.203's DEPS pins and SDK 26.2 - reproduces
//! its three archives byte for byte (lane v8opt1, 2026-11-04: equal
//! SHA-256s), so static and official differ in ThinLTO and PGO alone.
//!
//! iOS links out/ios-arm64. There is no official iOS build, so
//! -Dv8-build=official for an iOS target is an error, not a quiet fallback.
//!
//! std-only, so `zig build test` pins the paths (tools-v8_archives).

const std = @import("std");

/// `-Dv8-build`: which macOS V8 build to link.
pub const Build = enum {
    static,
    official,

    /// The build a plain `zig build` links. It stays `static` until the user
    /// chooses otherwise (lane v8opt1, 2026-11-04).
    pub const default: Build = .static;
};

/// One V8 output directory's archives, relative to the build root.
pub const Archives = struct {
    /// The GN output directory (jsengines/v8/out/<name>).
    dir: []const u8,
    /// libv8_monolith.a: V8, libbase, libplatform and the snapshot.
    monolith: []const u8,
    /// libv8_libplatform_fat.a: a regular archive of libplatform's objects
    /// (GN writes a thin one, which Zig's linker cannot read).
    libplatform: []const u8,
    /// libv8_libbase_fat.a: the same for libbase.
    libbase: []const u8,
};

pub const SelectError = error{
    /// -Dv8-build=official for an iOS target: out/ios-arm64 is the only iOS
    /// build.
    NoOfficialIosBuild,
};

/// The archives `build` names for a target whose OS is `os`.
pub fn select(build: Build, os: std.Target.Os.Tag) SelectError!Archives {
    if (os == .ios) return switch (build) {
        .static => archivesIn("jsengines/v8/out/ios-arm64"),
        .official => error.NoOfficialIosBuild,
    };
    return switch (build) {
        .static => archivesIn("jsengines/v8/out/static"),
        .official => archivesIn("jsengines/v8/out/official"),
    };
}

fn archivesIn(comptime dir: []const u8) Archives {
    return .{
        .dir = dir,
        .monolith = dir ++ "/obj/libv8_monolith.a",
        .libplatform = dir ++ "/obj/libv8_libplatform_fat.a",
        .libbase = dir ++ "/obj/libv8_libbase_fat.a",
    };
}

const testing = std.testing;

test "a plain build links out/static" {
    try testing.expectEqual(Build.static, Build.default);
}

test "static on macOS: the three archives of out/static" {
    const a = try select(.static, .macos);
    try testing.expectEqualStrings("jsengines/v8/out/static", a.dir);
    try testing.expectEqualStrings("jsengines/v8/out/static/obj/libv8_monolith.a", a.monolith);
    try testing.expectEqualStrings("jsengines/v8/out/static/obj/libv8_libplatform_fat.a", a.libplatform);
    try testing.expectEqualStrings("jsengines/v8/out/static/obj/libv8_libbase_fat.a", a.libbase);
}

test "official on macOS: the three archives of out/official" {
    const a = try select(.official, .macos);
    try testing.expectEqualStrings("jsengines/v8/out/official", a.dir);
    try testing.expectEqualStrings("jsengines/v8/out/official/obj/libv8_monolith.a", a.monolith);
    try testing.expectEqualStrings("jsengines/v8/out/official/obj/libv8_libplatform_fat.a", a.libplatform);
    try testing.expectEqualStrings("jsengines/v8/out/official/obj/libv8_libbase_fat.a", a.libbase);
}

test "official on Linux: out/official as well (the option is not macOS-only)" {
    const a = try select(.official, .linux);
    try testing.expectEqualStrings("jsengines/v8/out/official/obj/libv8_monolith.a", a.monolith);
}

test "iOS links out/ios-arm64 by default" {
    const a = try select(.static, .ios);
    try testing.expectEqualStrings("jsengines/v8/out/ios-arm64", a.dir);
    try testing.expectEqualStrings("jsengines/v8/out/ios-arm64/obj/libv8_monolith.a", a.monolith);
    try testing.expectEqualStrings("jsengines/v8/out/ios-arm64/obj/libv8_libplatform_fat.a", a.libplatform);
    try testing.expectEqualStrings("jsengines/v8/out/ios-arm64/obj/libv8_libbase_fat.a", a.libbase);
}

test "official for iOS is an error, never a quiet fallback" {
    try testing.expectError(error.NoOfficialIosBuild, select(.official, .ios));
}
