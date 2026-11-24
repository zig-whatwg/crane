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
    // The tools that read ELF objects test against one made for Linux.
    .object_format = .{ .name = "elf", .target = "x86_64-linux-none" },
    .checks = &.{
        // check-target for both Linux targets, one after the other.
        // -Dwpt-runner-optimize=Debug: the runner check then shares the
        // testing graph's C libraries instead of building a ReleaseSafe set of
        // its own for a binary that is never linked (build_mode.zig,
        // ownCLibraries).
        .{
            .step = "check-linux",
            .description = "check-target for aarch64-linux-gnu and x86_64-linux-gnu, -Dplatform=linux (cross-compiled; nothing runs)",
            .sub_step = "check-target",
            .targets = &.{ "aarch64-linux-gnu", "x86_64-linux-gnu" },
            .args = &.{ "-Dplatform=linux", "-Dwpt-runner-optimize=Debug" },
        },
    },
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

/// A test executable's debug information needs nothing beside it.
pub fn afterTestBuild(b: *std.Build, test_exe: *std.Build.Step.Compile, run: *std.Build.Step.Run, name: []const u8) void {
    _ = .{ b, test_exe, run, name };
}

/// Whether a compile for `target` has no sysroot here to find the system
/// libraries its graph names in (`addStandIns`): a target of the
/// system the stand-ins are built for whose query names its OS or ABI. What
/// the target's query names, not what the host is: `-Dtarget` with the build
/// machine's own triple names both, and gets no search path.
pub fn needsStandIns(target: std.Build.ResolvedTarget) bool {
    const names_os_or_abi = target.query.os_tag != null or target.query.abi != null;
    return target.result.os.tag == .linux and names_os_or_abi;
}

/// The system libraries a module graph names (kit/sqlite's sqlite3, through
/// the platform's build declaration) are resolved when the compiler starts, even
/// for a compile that links nothing (-fno-emit-bin). The compiler searches
/// the build machine's own library directories only for a target that leaves
/// both its OS and its ABI to the build machine; a target that names either
/// has no sysroot to find them in: "unable to find dynamic system library
/// 'sqlite3' ... searched paths: none", before any Zig is analysed. That is
/// every cross-compile, and also a target that names the build machine's own
/// triple: the x86-64 half of check-linux failed that way on an x86-64 host
/// until this function stopped asking whether the host is another OS or
/// architecture (lane build3, 2026-11-13).
///
/// So a compile-only check of such a Linux target gets empty shared
/// libraries of those names, built from an empty file into the build's own
/// output (the cache, never the source tree) and put on that check's own root
/// module, which nothing else imports. They satisfy name resolution and
/// nothing else: no artifact that links may receive them (build() asserts
/// that neither compile-only check is asked for its binary), and anything
/// linked for Linux needs the real libraries - a test executable bound to
/// such a target is compiled only, by a twin (the root build's
/// targetCheckOf). A real Linux
/// sysroot replaces them - pass its libraries instead and delete this
/// function.
pub fn addStandIns(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    if (!needsStandIns(target)) return;
    const empty = b.addWriteFiles().add("stub.zig", "");
    for ([_][]const u8{"sqlite3"}) |library| {
        const stub = b.addLibrary(.{
            .name = library,
            .linkage = .dynamic,
            .root_module = b.createModule(.{ .root_source_file = empty, .target = target }),
        });
        module.addLibraryPath(stub.getEmittedBinDirectory());
    }
}
