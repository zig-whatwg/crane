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
//!   a build with -Dv8-build=official runs there. Opt-in: the user kept
//!   static as the default (2026-11-04) after lane v8opt1 measured no gain
//!   (WPT identical; gc_bench DOM -1.7% CPU, a JS loop +3.2%).
//!
//! out/static is also the official build's baseline: the control build of
//! scripts/build-v8-official.sh - out/static's arguments from a 13.1.203
//! checkout, with the clang 13.1.203's DEPS pins and SDK 26.2 - reproduces
//! its three archives byte for byte (lane v8opt1, 2026-11-04: equal
//! SHA-256s), so static and official differ in ThinLTO and PGO alone.
//!
//! An iOS target has no V8 archive at all: iOS is JavaScriptCore's (the
//! user, 2026-11-10, ruling R4: "ios was always supposed to use javascript
//! core"), so `select` answers error.NoV8ForIos for either build, never a
//! quiet fallback to another archive. iOS builds wait for the JavaScriptCore
//! adapter (src/runtime/engines/jsc/).
//!
//! std-only, so `zig build test` pins the paths (tools-v8_archives).

const std = @import("std");

/// `-Dv8-build`: which macOS V8 build to link.
pub const Build = enum {
    static,
    official,

    /// The build a plain `zig build` links: `static`, the user's choice
    /// (2026-11-04) after lane v8opt1's measurement.
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
    /// An iOS target: no V8 for iOS in any form (ruling R4).
    NoV8ForIos,
};

/// The archives `build` names for a target whose OS is `os`.
pub fn select(build: Build, os: std.Target.Os.Tag) SelectError!Archives {
    if (os == .ios) return error.NoV8ForIos;
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

test "an iOS target has no V8 archive, static or official: iOS is JavaScriptCore's" {
    // The user, 2026-11-10 (ruling R4): "ios was always supposed to use javascript core" - no V8
    // for iOS in any form; never a quiet fallback to another archive.
    try testing.expectError(error.NoV8ForIos, select(.static, .ios));
    try testing.expectError(error.NoV8ForIos, select(.official, .ios));
}

test "a plain build links V8 13.1 until the switch" {
    try testing.expectEqual(Version.@"13.1", Version.default);
}

test "13.1 static: today's out/static, its include/, no Chromium libc++" {
    const a = try selectVersion(.@"13.1", .static, .macos);
    try testing.expectEqualStrings("jsengines/v8/out/static/obj/libv8_monolith.a", a.monolith);
    try testing.expectEqualStrings("jsengines/v8/include", a.include);
    try testing.expect(a.chromium == null);
}

test "15.7 static on macOS: the 15.7.112.43 directory, its include/ (with v8-gn.h), Chromium's libc++ and Temporal's Rust" {
    const a = try selectVersion(.@"15.7", .static, .macos);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/out/static", a.dir);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/out/static/obj/libv8_monolith.a", a.monolith);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/out/static/obj/libv8_libplatform_fat.a", a.libplatform);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/out/static/obj/libv8_libbase_fat.a", a.libbase);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/include", a.include);
    const c = a.chromium orelse return error.TestExpectedChromiumLibcxx;
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/out/static/obj/libc++_chromium.a", c.libcxx);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/out/static/obj/librust_v8.a", c.rust);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/libcxx/flags.txt", c.libcxx_flags);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/system-libs.txt", c.system_libs);
    // -I order: __config_site first, then libc++'s headers, then libc++abi's.
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/libcxx/config", c.libcxx_include[0]);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/libcxx/include", c.libcxx_include[1]);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/libcxx/abi-include", c.libcxx_include[2]);
}

test "15.7 static on Linux: the same directory (each host installs its own build there)" {
    const a = try selectVersion(.@"15.7", .static, .linux);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43/out/static/obj/libv8_monolith.a", a.monolith);
    try testing.expect(a.chromium != null);
}

test "15.7 has no official build: retired until roadmap item v8-pgo (ruling R3)" {
    try testing.expectError(error.NoOfficialBuild, selectVersion(.@"15.7", .official, .macos));
}

test "15.7 for iOS: no V8 for iOS in any form" {
    try testing.expectError(error.NoV8ForIos, selectVersion(.@"15.7", .static, .ios));
}
