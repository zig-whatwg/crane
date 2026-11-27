//! Which V8 archives a build links: `-Dv8`, `-Dv8-build` and the target's OS.
//!
//! `-Dv8` picks the V8 version. There is one: 15.7 is 15.7.112.43, the V8
//! Chrome 157 ships (the user, 2026-11-10; tmp/plans/v8-update-plan.md), built
//! with ICU (the user, 2026-11-22: "Rebuild with ICU") by
//! scripts/build-v8-15.7.sh into jsengines/v8/15.7.112.43-icu/ - beside
//! 15.7.112.43/, the first build, which had no ICU. The adapter
//! (v8_wrapper.cpp) was ported to it from 13.1.203 and no longer compiles
//! against that one, so 13.1 is not a value any more: its archive table and
//! the defines kept by hand for it went with it (the build migration, batch
//! E2). A later V8 is a new value here beside its directory.
//!
//! 15.7's sandbox requires libc++ hardening (V8 BUILD.gn:896), so the archive
//! is compiled against Chromium's own libc++ (std::__Cr) and comes with it
//! (`Chromium`): libc++_chromium.a, the headers and the flags a consumer
//! compiles with, Temporal's Rust as librust_v8.a, and the system libraries
//! its link needs; its include/ holds the build's v8-gn.h.
//!
//! ICU is in the monolith, code and data (icu_use_data_file = false: no
//! icudtl.dat beside the binary), and the archive keeps what a consumer of
//! ICU's own headers needs (`Icu`): the adapter sets ICU's default locale
//! through ICU's C API.
//!
//! `-Dv8-build` picks between builds of that V8. The adapter's build file
//! (../engine_build.zig, `link`) links the archives of one output directory:
//!
//! - `static` (the default): out/static, the release build - no ThinLTO, no
//!   PGO.
//! - `official`: the build with what Chrome's official build adds (ThinLTO
//!   with Chrome's clang PGO profile, and V8's builtins PGO). 15.7 has none:
//!   out/official was 13.1.203's (scripts/build-v8-official.sh; opt-in, the
//!   user kept static as the default on 2026-11-04 after lane v8opt1 measured
//!   no gain) and is retired until roadmap item v8-pgo trains Crane's own
//!   profile (ruling R3), so `select` answers error.NoOfficialBuild.
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

/// `-Dv8-build`: which build of the V8 to link.
pub const Build = enum {
    static,
    official,

    /// The build a plain `zig build` links: `static`, the user's choice
    /// (2026-11-04) after lane v8opt1's measurement.
    pub const default: Build = .static;
};

/// `-Dv8-link`: whether to link V8 statically or dynamically.
pub const LinkMode = enum {
    static,
    dynamic,

    /// Static monolith by default (self-contained single binaries).
    pub const default: LinkMode = .static;
};

/// `-Dv8`: which V8 to link.
pub const Version = enum {
    @"15.7",

    /// The version a build links unless -Dv8 says otherwise.
    pub const default: Version = .@"15.7";
};

/// Static archives in `<root>/out/static/obj/`.
pub const StaticArchives = struct {
    /// libv8_monolith.a: V8, libbase, libplatform and the snapshot.
    monolith: []const u8,
    /// libv8_libplatform_fat.a: a regular archive of libplatform's objects
    /// (GN writes a thin one, which Zig's linker cannot read).
    libplatform: []const u8,
    /// libv8_libbase_fat.a: the same for libbase.
    libbase: []const u8,
    /// libc++_chromium.a: Chromium's libc++ and libc++abi objects - the C++
    /// runtime the archive and v8_wrapper.cpp share; Zig's libc++ is not linked.
    libcxx: []const u8,
    /// librust_v8.a: Temporal's Rust (temporal_capi, temporal_rs, ICU4X) and
    /// Rust's std, which the monolith references but does not carry.
    rust: []const u8,
};

/// Shared libraries in `<root>/out/dynamic/` (from `scripts/build-v8-15.7.sh --dynamic`,
/// `is_component_build = true`). Temporal's Rust is linked inside `libv8`.
pub const DynamicLibraries = struct {
    v8: []const u8,
    libplatform: []const u8,
    libbase: []const u8,
    /// Chromium's shared libc++ (std::__Cr) built alongside V8.
    libcxx: []const u8,
    /// ICU common + i18n shared libraries (with static linked-in data).
    icuuc: []const u8,
    icui18n: []const u8,

    pub fn all(self: *const DynamicLibraries) [6][]const u8 {
        return .{ self.v8, self.libplatform, self.libbase, self.libcxx, self.icuuc, self.icui18n };
    }
};

pub const LinkInputs = union(LinkMode) {
    static: StaticArchives,
    dynamic: DynamicLibraries,
};

/// Consumer compile metadata for Chromium's libc++ and system libraries.
pub const ChromiumMeta = struct {
    libcxx_flags: []const u8,
    libcxx_include: [3][]const u8,
    system_libs: []const u8,
};

/// Resolved V8 layout for either static or dynamic linking, rooted at either
/// the default `jsengines/v8/15.7.112.43-icu` directory or a caller-supplied
/// `-Dv8-dir=<path>`.
pub const ResolvedArchives = struct {
    /// Output directory (`<root>/out/static` or `<root>/out/dynamic`).
    dir: []const u8,
    /// Static archives or dynamic shared libraries to link.
    link_inputs: LinkInputs,
    /// V8's public headers (`v8.h` + build-generated `v8-gn.h`).
    include: []const u8,
    /// Chromium libc++ consumer metadata and system libraries list.
    chromium: ChromiumMeta,
    /// ICU's public headers and consumer defines.
    icu: Icu,
    /// True when `-Dv8-dir` supplied a non-empty override path (resolved
    /// relative to the caller's working directory or as an absolute path),
    /// false for the default in-tree path relative to Crane's package root.
    cwd_relative: bool,

    pub fn deinit(self: *const ResolvedArchives, allocator: std.mem.Allocator) void {
        allocator.free(self.dir);
        switch (self.link_inputs) {
            .static => |s| {
                allocator.free(s.monolith);
                allocator.free(s.libplatform);
                allocator.free(s.libbase);
                allocator.free(s.libcxx);
                allocator.free(s.rust);
            },
            .dynamic => |d| {
                for (d.all()) |path| allocator.free(path);
            },
        }
        allocator.free(self.include);
        allocator.free(self.chromium.libcxx_flags);
        for (self.chromium.libcxx_include) |inc| allocator.free(inc);
        allocator.free(self.chromium.system_libs);
        allocator.free(self.icu.include);
        allocator.free(self.icu.flags);
    }
};

pub const SelectOptions = struct {
    version: Version = Version.default,
    build: Build = Build.default,
    link_mode: LinkMode = LinkMode.default,
    custom_dir: ?[]const u8 = null,
    os: std.Target.Os.Tag,
};

/// Shared library extension for `os` (`dylib` on macOS, `so` on Linux/Unix).
pub fn sharedLibExt(os: std.Target.Os.Tag) []const u8 {
    return switch (os) {
        .macos => "dylib",
        else => "so",
    };
}

fn normalizeRoot(custom_dir: ?[]const u8) struct { root: []const u8, cwd_relative: bool } {
    if (custom_dir) |raw| {
        if (raw.len > 0) {
            const trimmed = std.mem.trimEnd(u8, raw, "/");
            return .{
                .root = if (trimmed.len > 0) trimmed else "/",
                .cwd_relative = true,
            };
        }
    }
    return .{ .root = dir_15_7, .cwd_relative = false };
}

fn joinPath(allocator: std.mem.Allocator, base: []const u8, rel: []const u8) std.mem.Allocator.Error![]u8 {
    if (std.mem.eql(u8, base, "/")) return std.fmt.allocPrint(allocator, "/{s}", .{rel});
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ base, rel });
}

/// Resolve V8 paths for `options`, supporting `-Dv8-dir` and `-Dv8-link=static|dynamic`.
pub fn selectResolved(allocator: std.mem.Allocator, options: SelectOptions) (SelectError || std.mem.Allocator.Error)!ResolvedArchives {
    if (options.os == .ios) return error.NoV8ForIos;
    switch (options.version) {
        .@"15.7" => switch (options.build) {
            .official => return error.NoOfficialBuild,
            .static => {},
        },
    }
    const norm = normalizeRoot(options.custom_dir);
    const root = norm.root;

    switch (options.link_mode) {
        .static => {
            const dir = try joinPath(allocator, root, "out/static");
            errdefer allocator.free(dir);
            const monolith = try joinPath(allocator, root, "out/static/obj/libv8_monolith.a");
            errdefer allocator.free(monolith);
            const libplatform = try joinPath(allocator, root, "out/static/obj/libv8_libplatform_fat.a");
            errdefer allocator.free(libplatform);
            const libbase = try joinPath(allocator, root, "out/static/obj/libv8_libbase_fat.a");
            errdefer allocator.free(libbase);
            const libcxx = try joinPath(allocator, root, "out/static/obj/libc++_chromium.a");
            errdefer allocator.free(libcxx);
            const rust = try joinPath(allocator, root, "out/static/obj/librust_v8.a");
            errdefer allocator.free(rust);
            const include = try joinPath(allocator, root, "include");
            errdefer allocator.free(include);
            const libcxx_flags = try joinPath(allocator, root, "libcxx/flags.txt");
            errdefer allocator.free(libcxx_flags);
            const libcxx_inc0 = try joinPath(allocator, root, "libcxx/config");
            errdefer allocator.free(libcxx_inc0);
            const libcxx_inc1 = try joinPath(allocator, root, "libcxx/include");
            errdefer allocator.free(libcxx_inc1);
            const libcxx_inc2 = try joinPath(allocator, root, "libcxx/abi-include");
            errdefer allocator.free(libcxx_inc2);
            const system_libs = try joinPath(allocator, root, "system-libs.txt");
            errdefer allocator.free(system_libs);
            const icu_include = try joinPath(allocator, root, "icu/include");
            errdefer allocator.free(icu_include);
            const icu_flags = try joinPath(allocator, root, "icu/flags.txt");
            errdefer allocator.free(icu_flags);

            return .{
                .dir = dir,
                .link_inputs = .{ .static = .{
                    .monolith = monolith,
                    .libplatform = libplatform,
                    .libbase = libbase,
                    .libcxx = libcxx,
                    .rust = rust,
                } },
                .include = include,
                .chromium = .{
                    .libcxx_flags = libcxx_flags,
                    .libcxx_include = .{ libcxx_inc0, libcxx_inc1, libcxx_inc2 },
                    .system_libs = system_libs,
                },
                .icu = .{
                    .include = icu_include,
                    .flags = icu_flags,
                },
                .cwd_relative = norm.cwd_relative,
            };
        },
        .dynamic => {
            const ext = sharedLibExt(options.os);
            const dir = try joinPath(allocator, root, "out/dynamic");
            errdefer allocator.free(dir);
            const v8 = try std.fmt.allocPrint(allocator, "{s}/libv8.{s}", .{ dir, ext });
            errdefer allocator.free(v8);
            const libplatform = try std.fmt.allocPrint(allocator, "{s}/libv8_libplatform.{s}", .{ dir, ext });
            errdefer allocator.free(libplatform);
            const libbase = try std.fmt.allocPrint(allocator, "{s}/libv8_libbase.{s}", .{ dir, ext });
            errdefer allocator.free(libbase);
            const libcxx = try std.fmt.allocPrint(allocator, "{s}/libc++.{s}", .{ dir, ext });
            errdefer allocator.free(libcxx);
            const icuuc = try std.fmt.allocPrint(allocator, "{s}/libicuuc.{s}", .{ dir, ext });
            errdefer allocator.free(icuuc);
            const icui18n = try std.fmt.allocPrint(allocator, "{s}/libicui18n.{s}", .{ dir, ext });
            errdefer allocator.free(icui18n);
            const include = try joinPath(allocator, dir, "include");
            errdefer allocator.free(include);
            const libcxx_flags = try joinPath(allocator, dir, "libcxx/flags.txt");
            errdefer allocator.free(libcxx_flags);
            const libcxx_inc0 = try joinPath(allocator, dir, "libcxx/config");
            errdefer allocator.free(libcxx_inc0);
            const libcxx_inc1 = try joinPath(allocator, dir, "libcxx/include");
            errdefer allocator.free(libcxx_inc1);
            const libcxx_inc2 = try joinPath(allocator, dir, "libcxx/abi-include");
            errdefer allocator.free(libcxx_inc2);
            const system_libs = try joinPath(allocator, dir, "system-libs.txt");
            errdefer allocator.free(system_libs);
            const icu_include = try joinPath(allocator, dir, "icu/include");
            errdefer allocator.free(icu_include);
            const icu_flags = try joinPath(allocator, dir, "icu/flags.txt");
            errdefer allocator.free(icu_flags);

            return .{
                .dir = dir,
                .link_inputs = .{ .dynamic = .{
                    .v8 = v8,
                    .libplatform = libplatform,
                    .libbase = libbase,
                    .libcxx = libcxx,
                    .icuuc = icuuc,
                    .icui18n = icui18n,
                } },
                .include = include,
                .chromium = .{
                    .libcxx_flags = libcxx_flags,
                    .libcxx_include = .{ libcxx_inc0, libcxx_inc1, libcxx_inc2 },
                    .system_libs = system_libs,
                },
                .icu = .{
                    .include = icu_include,
                    .flags = icu_flags,
                },
                .cwd_relative = norm.cwd_relative,
            };
        },
    }
}

/// What an archive built against Chromium's libc++ brings beside itself,
/// relative to the build root.
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

/// What an archive built with ICU keeps for a consumer of ICU's headers,
/// relative to the build root. ICU's code and data are in the monolith.
pub const Icu = struct {
    /// The directory holding ICU's public headers as `unicode/*.h`
    /// (source/common/unicode and source/i18n/unicode), for -I.
    include: []const u8,
    /// The defines GN compiles ICU's consumers with (its icu_config:
    /// U_USING_ICU_NAMESPACE=0, U_STATIC_IMPLEMENTATION,
    /// ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC, ...), one -D per line, read
    /// from the compile command of V8's own src/objects/intl-objects.cc.
    flags: []const u8,
};

/// One V8 output directory's archives, relative to the build root.
pub const Archives = struct {
    /// The GN output directory (jsengines/v8/<version>/out/<name>).
    dir: []const u8,
    /// libv8_monolith.a: V8, libbase, libplatform and the snapshot.
    monolith: []const u8,
    /// libv8_libplatform_fat.a: a regular archive of libplatform's objects
    /// (GN writes a thin one, which Zig's linker cannot read).
    libplatform: []const u8,
    /// libv8_libbase_fat.a: the same for libbase.
    libbase: []const u8,
    /// V8's public headers for this archive; the directory also holds the
    /// build's v8-gn.h.
    include: []const u8,
    /// The C++ runtime the archive was built against, and what comes with it.
    chromium: Chromium,
    /// ICU's headers and consumer defines.
    icu: Icu,
};

pub const SelectError = error{
    /// An iOS target: no V8 for iOS in any form (ruling R4).
    NoV8ForIos,
    /// -Dv8-build=official with -Dv8=15.7: there is none - out/official is
    /// retired until roadmap item v8-pgo (ruling R3).
    NoOfficialBuild,
};

/// The directory scripts/build-v8-15.7.sh installs 15.7.112.43, built with
/// ICU, into.
const dir_15_7 = "jsengines/v8/15.7.112.43-icu";

/// The archives `version` and `build` name for a target whose OS is `os`.
pub fn select(version: Version, build: Build, os: std.Target.Os.Tag) SelectError!Archives {
    if (os == .ios) return error.NoV8ForIos;
    return switch (version) {
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
                .icu = .{
                    .include = dir_15_7 ++ "/icu/include",
                    .flags = dir_15_7 ++ "/icu/flags.txt",
                },
            },
        },
    };
}

const testing = std.testing;

test "a plain build links the static build" {
    try testing.expectEqual(Build.static, Build.default);
}

test "a plain build links V8 15.7: the adapter is ported to it" {
    try testing.expectEqual(Version.@"15.7", Version.default);
}

test "-Dv8 takes 15.7 alone: 13.1, which the adapter no longer compiles against, is not a value" {
    const versions = std.meta.fieldNames(Version);
    try testing.expectEqual(@as(usize, 1), versions.len);
    try testing.expectEqualStrings("15.7", versions[0]);
    try testing.expect(std.meta.stringToEnum(Version, "13.1") == null);
}

test "15.7 static on macOS: the 15.7.112.43-icu directory, its include/ (with v8-gn.h), Chromium's libc++, Temporal's Rust and ICU's headers" {
    const a = try select(.@"15.7", .static, .macos);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static", a.dir);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/libv8_monolith.a", a.monolith);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/libv8_libplatform_fat.a", a.libplatform);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/libv8_libbase_fat.a", a.libbase);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/include", a.include);
    const c = a.chromium;
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/libc++_chromium.a", c.libcxx);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/librust_v8.a", c.rust);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/libcxx/flags.txt", c.libcxx_flags);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/system-libs.txt", c.system_libs);
    // -I order: __config_site first, then libc++'s headers, then libc++abi's.
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/libcxx/config", c.libcxx_include[0]);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/libcxx/include", c.libcxx_include[1]);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/libcxx/abi-include", c.libcxx_include[2]);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/icu/include", a.icu.include);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/icu/flags.txt", a.icu.flags);
}

test "the archive a build links is the one built with ICU, never the first 15.7 build without it" {
    // jsengines/v8/15.7.112.43 (v8_enable_i18n_support = false) stays on the
    // pool's hosts for builds of an older Crane; this tree links only the
    // ICU build (the user, 2026-11-22: "Rebuild with ICU").
    const a = try select(.@"15.7", .static, .linux);
    try testing.expect(std.mem.startsWith(u8, a.dir, "jsengines/v8/15.7.112.43-icu/"));
    try testing.expect(std.mem.startsWith(u8, a.monolith, "jsengines/v8/15.7.112.43-icu/"));
}

test "15.7 static on Linux: the same directory (each host installs its own build there)" {
    const a = try select(.@"15.7", .static, .linux);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/libv8_monolith.a", a.monolith);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/libc++_chromium.a", a.chromium.libcxx);
}

test "15.7 has no official build on any OS: retired until roadmap item v8-pgo (ruling R3)" {
    try testing.expectError(error.NoOfficialBuild, select(.@"15.7", .official, .macos));
    try testing.expectError(error.NoOfficialBuild, select(.@"15.7", .official, .linux));
}

test "an iOS target has no V8 archive, static or official: iOS is JavaScriptCore's" {
    // The user, 2026-11-10 (ruling R4): "ios was always supposed to use javascript core" - no V8
    // for iOS in any form; never a quiet fallback to another archive.
    try testing.expectError(error.NoV8ForIos, select(.@"15.7", .static, .ios));
    try testing.expectError(error.NoV8ForIos, select(.@"15.7", .official, .ios));
}

test "a plain build defaults to static V8 linking (-Dv8-link=static)" {
    try testing.expectEqual(LinkMode.static, LinkMode.default);
}

test "-Dv8-dir overrides the default V8 root for static builds (absolute, relative, trailing slash)" {
    const abs = try selectResolved(testing.allocator, .{
        .custom_dir = "/opt/crane-v8/15.7.112.43-icu/",
        .os = .linux,
    });
    defer abs.deinit(testing.allocator);
    try testing.expectEqualStrings("/opt/crane-v8/15.7.112.43-icu/out/static", abs.dir);
    try testing.expectEqualStrings("/opt/crane-v8/15.7.112.43-icu/out/static/obj/libv8_monolith.a", abs.link_inputs.static.monolith);
    try testing.expectEqualStrings("/opt/crane-v8/15.7.112.43-icu/include", abs.include);
    try testing.expectEqualStrings("/opt/crane-v8/15.7.112.43-icu/libcxx/flags.txt", abs.chromium.libcxx_flags);
    try testing.expectEqualStrings("/opt/crane-v8/15.7.112.43-icu/icu/flags.txt", abs.icu.flags);
    try testing.expectEqualStrings("/opt/crane-v8/15.7.112.43-icu/system-libs.txt", abs.chromium.system_libs);

    const rel = try selectResolved(testing.allocator, .{
        .custom_dir = "../../jsengines/v8/15.7.112.43-icu",
        .os = .macos,
    });
    defer rel.deinit(testing.allocator);
    try testing.expectEqualStrings("../../jsengines/v8/15.7.112.43-icu/out/static/obj/libv8_monolith.a", rel.link_inputs.static.monolith);

    const empty = try selectResolved(testing.allocator, .{
        .custom_dir = "",
        .os = .linux,
    });
    defer empty.deinit(testing.allocator);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/static/obj/libv8_monolith.a", empty.link_inputs.static.monolith);
}

test "-Dv8-link=dynamic resolves shared V8 libraries on macOS (.dylib) and Linux (.so)" {
    const mac = try selectResolved(testing.allocator, .{
        .link_mode = .dynamic,
        .custom_dir = "/opt/v8",
        .os = .macos,
    });
    defer mac.deinit(testing.allocator);
    try testing.expectEqualStrings("/opt/v8/out/dynamic", mac.dir);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/libv8.dylib", mac.link_inputs.dynamic.v8);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/libv8_libplatform.dylib", mac.link_inputs.dynamic.libplatform);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/libv8_libbase.dylib", mac.link_inputs.dynamic.libbase);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/libc++.dylib", mac.link_inputs.dynamic.libcxx);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/libicuuc.dylib", mac.link_inputs.dynamic.icuuc);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/libicui18n.dylib", mac.link_inputs.dynamic.icui18n);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/include", mac.include);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/libcxx/flags.txt", mac.chromium.libcxx_flags);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/icu/flags.txt", mac.icu.flags);
    try testing.expectEqualStrings("/opt/v8/out/dynamic/system-libs.txt", mac.chromium.system_libs);

    const lin = try selectResolved(testing.allocator, .{
        .link_mode = .dynamic,
        .os = .linux,
    });
    defer lin.deinit(testing.allocator);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/dynamic", lin.dir);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/dynamic/libv8.so", lin.link_inputs.dynamic.v8);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/dynamic/libv8_libplatform.so", lin.link_inputs.dynamic.libplatform);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/dynamic/libv8_libbase.so", lin.link_inputs.dynamic.libbase);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/dynamic/libc++.so", lin.link_inputs.dynamic.libcxx);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/dynamic/libicuuc.so", lin.link_inputs.dynamic.icuuc);
    try testing.expectEqualStrings("jsengines/v8/15.7.112.43-icu/out/dynamic/libicui18n.so", lin.link_inputs.dynamic.icui18n);
}

test "-Dv8-link=dynamic rejects iOS and official builds" {
    try testing.expectError(error.NoV8ForIos, selectResolved(testing.allocator, .{ .link_mode = .dynamic, .os = .ios }));
    try testing.expectError(error.NoOfficialBuild, selectResolved(testing.allocator, .{ .link_mode = .dynamic, .build = .official, .os = .linux }));
}
