//! Which V8 archives a build links: `-Dv8`, `-Dv8-build` and the target's OS.
//!
//! `-Dv8` picks the V8 version. 15.7 is 15.7.112.43, the V8 Chrome 157 ships (the
//! user, 2026-11-10; tmp/plans/v8-update-plan.md) and the default since the
//! adapter was ported to it (`resolve` in ../engine_build.zig refuses 13.1.203
//! now), built by
//! scripts/build-v8-15.7.sh into jsengines/v8/15.7.112.43/ beside 13.1's
//! directories. 15.7's sandbox requires libc++ hardening (V8 BUILD.gn:896), so
//! that archive is compiled against Chromium's own libc++ (std::__Cr) and
//! comes with it (`Chromium`): libc++_chromium.a, the headers and the flags a
//! consumer compiles with, Temporal's Rust as librust_v8.a, and the system
//! libraries its link needs; its include/ holds the build's v8-gn.h.
//!
//! The adapter's build file (../engine_build.zig, `link`) links three static
//! archives from one V8 output directory under jsengines/v8/out/. Two macOS
//! builds of the same V8, 13.1.203, exist side by side:
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
//! A helper of the V8 adapter's build file (../engine_build.zig), run by the
//! configure step. std-only, so the test step pins the paths: the adapter
//! lists this file in its `facts.build_tests` (suite v8-build-archives).

const std = @import("std");

/// `-Dv8-build`: which macOS V8 build to link.
pub const Build = enum {
    static,
    official,

    /// The build a plain `zig build` links: `static`, the user's choice
    /// (2026-11-04) after lane v8opt1's measurement.
    pub const default: Build = .static;
};

/// `-Dv8`: which V8 to link.
pub const Version = enum {
    @"13.1",
    @"15.7",

    /// The version a build links unless -Dv8 says otherwise: 15.7, since the
    /// adapter (v8_wrapper.cpp) was ported to it.
    pub const default: Version = .@"15.7";
};

/// What an archive built against Chromium's libc++ (15.7) brings beside
/// itself, relative to the build root.
pub const Chromium = struct {
    /// libc++_chromium.a: Chromium's libc++ and libc++abi objects - the C++
    /// runtime the archive and v8_wrapper.cpp share; Zig's libc++ is not linked.
    libcxx: []const u8,
    /// librust_v8.a: Temporal's Rust (temporal_capi, temporal_rs, ICU4X) and
    /// Rust's std, which the monolith references but does not carry.
    rust: []const u8,
    /// The flags GN compiles every C++ consumer of that libc++ with (its
    /// -D_LIBCPP_*/-D_LIBCXXABI_* defines and -nostdinc++), one per line.
    libcxx_flags: []const u8,
    /// The libc++ header directories, in -I order: __config_site's, libc++'s,
    /// libc++abi's. -I, not -isystem: Zig puts its own -isystem directories
    /// first, and libc++'s <stdio.h> wrapper must come before the C library's.
    libcxx_include: [3][]const u8,
    /// The system libraries and frameworks the archive's link needs
    /// (`-framework X` / `-lX`, one per line), read from d8's link.
    system_libs: []const u8,
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
    /// V8's public headers for this archive (15.7's include/ also holds the
    /// build's v8-gn.h).
    include: []const u8 = "jsengines/v8/include",
    /// Null for 13.1 (the system's or Zig's libc++, std::__1).
    chromium: ?Chromium = null,
};

pub const SelectError = error{
    /// An iOS target: no V8 for iOS in any form (ruling R4).
    NoV8ForIos,
    /// -Dv8-build=official with -Dv8=15.7: there is none - out/official is
    /// retired at the switch until roadmap item v8-pgo (ruling R3).
    NoOfficialBuild,
};

/// The directory scripts/build-v8-15.7.sh installs 15.7.112.43 into.
const dir_15_7 = "jsengines/v8/15.7.112.43";

/// The archives `version` and `build` name for a target whose OS is `os`.
pub fn selectVersion(version: Version, build: Build, os: std.Target.Os.Tag) SelectError!Archives {
    if (os == .ios) return error.NoV8ForIos;
    return switch (version) {
        .@"13.1" => select(build, os),
        .@"15.7" => switch (build) {
            .official => error.NoOfficialBuild,
            .static => .{
                .dir = dir_15_7 ++ "/out/static",
                .monolith = dir_15_7 ++ "/out/static/obj/libv8_monolith.a",
                .libplatform = dir_15_7 ++ "/out/static/obj/libv8_libplatform_fat.a",
                .libbase = dir_15_7 ++ "/out/static/obj/libv8_libbase_fat.a",
                .include = dir_15_7 ++ "/include",
                .chromium = .{
                    .libcxx = dir_15_7 ++ "/out/static/obj/libc++_chromium.a",
                    .rust = dir_15_7 ++ "/out/static/obj/librust_v8.a",
                    .libcxx_flags = dir_15_7 ++ "/libcxx/flags.txt",
                    .libcxx_include = .{ dir_15_7 ++ "/libcxx/config", dir_15_7 ++ "/libcxx/include", dir_15_7 ++ "/libcxx/abi-include" },
                    .system_libs = dir_15_7 ++ "/system-libs.txt",
                },
            },
        },
    };
}

/// The 13.1.203 archives `build` names for a target whose OS is `os`.
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

test "a plain build links V8 15.7: the adapter is ported to it" {
    try testing.expectEqual(Version.@"15.7", Version.default);
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
