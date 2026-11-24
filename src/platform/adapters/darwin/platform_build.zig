//! The build side of the darwin platform (src/platform/platform_build_protocol.zig):
//! the operating systems it answers for and the extra kit parts it builds
//! in. kit/sqlite, the storage engine of a Browser with a profile directory
//! (the user's ruling, 2026-11-21: SQLite on every platform with one), over
//! the system's libsqlite3 (macOS and iOS ship it: libsqlite3.tbd in the SDKs).
const std = @import("std");
const platform_build = @import("../../platform_build_protocol.zig");
const KitPart = platform_build.KitPart;
const kit_build = @import("../../kit/kit_build.zig");

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
    // The tools that read Mach-O objects test against one made for macOS.
    .object_format = .{ .name = "mach_o", .target = "aarch64-macos-none" },
    .checks = &.{
        // lib-full for aarch64-ios, its own `zig build` like check-linux: a
        // static library, so it builds every C library and all of Crane for
        // iOS and links nothing (an iOS link also needs an engine prebuilt for
        // the phone that matches the adapter - 24 of the engine's API symbols
        // are missing from today's, lane zig017trial - and iOS ships on its
        // system engine). -Dios-sdk passes through (`forwarded`): the merge
        // check runs `zig build check-ios -Dios-sdk=$HOME/sdks/iPhoneOS.sdk
        // -j2`. PAUSED (the user, 2026-11-10 15:55 ET: "skip ios builds and
        // tests for now until we get js core implemented"): the sub-build's
        // engine links nothing yet for iOS, so its lib-full fails with that
        // adapter's reason, and this step with it, until the adapter builds
        // lib-full; it is no gate.
        .{
            .step = "check-ios",
            .description = "lib-full for aarch64-ios (a static library: built, not linked); -Dios-sdk passes through",
            .sub_step = "lib-full",
            .targets = &.{"aarch64-ios"},
            .forward_options = true,
        },
    },
};

/// darwin's own -D options: declared only when darwin answers for the
/// target's operating system (platform_build.chooseOs).
pub const Options = struct {
    /// -Dios-sdk: the iPhoneOS SDK root, used instead of xcrun's.
    ios_sdk: ?[]const u8,
};

const sdk_option_name = "ios-sdk";

/// Zig 0.16 resolves the macOS SDK for Darwin targets, but NOT the iOS one: a
/// trivial `#include <stdio.h>` for aarch64-ios fails with 'stdio.h' file not
/// found, with or without --sysroot. That surfaces far from the cause, as 15
/// errors in vendored zlib and 107 in mbedtls, which reads like a dependency
/// problem rather than a missing SDK.
///
/// Point the compiler and linker at the iPhoneOS SDK explicitly. Queried through
/// `xcrun --sdk iphoneos` rather than hardcoded, because the SDK version moves
/// with Xcode - asked at make time (recordSdkRoot).
/// -Dios-sdk: the SDK root used instead of xcrun's (declared here once;
/// check-ios passes it to its sub-build).
pub fn declareOptions(b: *std.Build) Options {
    return .{ .ios_sdk = b.option([]const u8, sdk_option_name, "The iPhoneOS SDK root for an aarch64-ios build (default: xcrun --sdk iphoneos)") };
}

/// What darwin reads of the machine for `target`, once: an iOS target's SDK
/// root, recorded for the C preparation (`prepareC`) - asked at make time by
/// `probe`, the root build's tools/build_probe.zig.
pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options, probe: *std.Build.Step.Compile) void {
    if (target.result.os.tag == .ios) _ = recordSdkRoot(b, target, options.ios_sdk, sdk_option_name, probe);
}

/// What a sub-build of the root build for another darwin target takes from
/// this one (check-ios): -Dios-sdk, when given.
pub fn forwarded(b: *std.Build, options: Options) []const []const u8 {
    const sdk = options.ios_sdk orelse return &.{};
    const args = b.allocator.alloc([]const u8, 1) catch @panic("OOM");
    args[0] = b.fmt("-Dios-sdk={s}", .{sdk});
    return args;
}

/// The SDK root of this build's target, as `recordSdkRoot` recorded it, or
/// null for a target that needs none. Every caller here holds only `b`, so
/// the root is kept by name on the build itself (`named_lazy_paths`).
fn iosSdkPath(b: *std.Build) ?std.Build.LazyPath {
    return b.named_lazy_paths.get(sdk_root_name);
}

/// The name `recordSdkRoot` keeps the SDK root under.
const sdk_root_name = "crane-sdk-root";

/// Record the SDK root of a target whose libc Zig does not find: the path
/// `option` (the build option `option_name`) gives, else the root the
/// machine's SDK tools name for the target, asked at make time (build_probe
/// sdk-root links it into the cache) - a program's answer is never asked at
/// configure time (`check-configure-cache`). No SDK fails that step, naming
/// the option.
///
/// Queried rather than hardcoded: the SDK version moves with Xcode, and a stale
/// path fails as missing libc headers rather than as a missing SDK. The option
/// is for a machine whose xcode-select names the Command Line Tools, which
/// have no iPhoneOS SDK: the pool hosts are set up that way and link their
/// Xcode's SDK at ~/sdks/iPhoneOS.sdk (`zig build check-ios -Dios-sdk=$HOME/sdks/iPhoneOS.sdk`).
fn recordSdkRoot(b: *std.Build, target: std.Build.ResolvedTarget, option: ?[]const u8, option_name: []const u8, build_probe: *std.Build.Step.Compile) std.Build.LazyPath {
    const root: std.Build.LazyPath = if (option) |path| .{ .cwd_relative = path } else asked: {
        const run = b.addRunArtifact(build_probe);
        run.setName("find the target's SDK");
        const triple = target.result.zigTriple(b.allocator) catch @panic("OOM");
        run.addArgs(&.{ "sdk-root", b.fmt("--target={s}", .{triple}), b.fmt("--option={s}", .{option_name}) });
        const out = run.addOutputDirectoryArg("sdk");
        // Its answer is the machine's: asked on every build.
        run.has_side_effects = true;
        break :asked out.path(b, "root");
    };
    b.addNamedLazyPath(sdk_root_name, root);
    return root;
}

/// Apply the iOS SDK paths to every Compile step reachable from `root`.
///
/// zlib and mbedtls are TRANSITIVE dependencies of the curl package - curl depends
/// on them, and each is its own artifact with its own module. Touching only
/// libcurl's module left them failing on <stdio.h> and <string.h>, so the whole
/// reachable graph gets the paths.
///
/// Depth-bounded rather than visited-tracked: the build graph is a DAG, revisiting
/// a module is idempotent here, and a bound needs no allocation. Real dependency
/// chains are nowhere near this deep.
fn applyIosSdkRecursively(b: *std.Build, root: *std.Build.Step, sdk: ?std.Build.LazyPath) void {
    if (sdk == null) return;
    applyIosSdkStep(b, root, sdk, 0);
}

fn applyIosSdkStep(b: *std.Build, step: *std.Build.Step, sdk: ?std.Build.LazyPath, depth: u32) void {
    if (depth > 24) return;
    if (step.cast(std.Build.Step.Compile)) |compile| {
        addIosSdkPaths(compile.root_module, sdk);
        // Linked artifacts are recorded as `link_objects` entries on the MODULE, not
        // as step dependencies, so walking `step.dependencies` alone never reaches
        // zlib or mbedtls - they are libraries curl links, not steps it waits on.
        for (compile.root_module.link_objects.items) |obj| {
            switch (obj) {
                .other_step => |other| applyIosSdkStep(b, &other.step, sdk, depth + 1),
                else => {},
            }
        }
    }
    for (step.dependencies.items) |dep| applyIosSdkStep(b, dep, sdk, depth + 1);
}

/// Point a module at the iOS SDK's headers, libraries and frameworks.
///
/// No-op off iOS. Called for every module that compiles or links C, since Zig will
/// not find them on its own for this target.
fn addIosSdkPaths(module: *std.Build.Module, sdk: ?std.Build.LazyPath) void {
    const root = sdk orelse return;
    module.addSystemIncludePath(root.path(module.owner, "usr/include"));
    module.addLibraryPath(root.path(module.owner, "usr/lib"));
    module.addFrameworkPath(root.path(module.owner, "System/Library/Frameworks"));
}

/// What the kit's C needs for `target` beyond what Zig finds by itself
/// (kit_build.PrepareC): the iOS SDK's paths, for an iOS target, whose SDK
/// root `resolve` recorded (recordSdkRoot); nothing for macOS, whose SDK Zig
/// finds.
pub fn prepareC(target: std.Build.ResolvedTarget) ?kit_build.PrepareC {
    return if (target.result.os.tag == .ios) sdk_prepare_c else null;
}
const sdk_prepare_c: kit_build.PrepareC = .{ .module = sdkModule, .graph = sdkGraph, .translate = sdkTranslate };
fn sdkModule(module: *std.Build.Module) void {
    addIosSdkPaths(module, iosSdkPath(module.owner));
}
fn sdkGraph(step: *std.Build.Step) void {
    applyIosSdkRecursively(step.owner, step, iosSdkPath(step.owner));
}
fn sdkTranslate(translate: *std.Build.Step.TranslateC) void {
    const b = translate.step.owner;
    if (iosSdkPath(b)) |sdk| translate.addSystemIncludePath(sdk.path(b, "usr/include"));
}

/// What a finished program or library links on darwin's systems (crane's
/// library and executable): macOS's CoreFoundation, CoreServices and
/// SystemConfiguration.
pub fn linkArtifact(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    // System frameworks (macOS)
    if (target.result.os.tag == .macos) {
        module.linkFramework("CoreFoundation", .{});
        module.linkFramework("CoreServices", .{});
        module.linkFramework("SystemConfiguration", .{});
    }
}

/// What darwin's implementation links when a graph binds it: its fonts are
/// CoreText's (decision 20), linked dynamically as the system frameworks they
/// are, on a darwin target; compiled out, nothing is linked.
pub fn bind(impl: *std.Build.Module, target: std.Build.ResolvedTarget, request: platform_build.BindRequest) void {
    if (target.result.os.tag.isDarwin() and request.font_decoding) {
        if (prepareC(target)) |prepare| prepare.module(impl);
        impl.linkFramework("CoreText", .{});
        impl.linkFramework("CoreFoundation", .{});
    }
}

/// What a race report needs beside a test executable for its lines, built
/// for a darwin target on a darwin machine (the root build asks it for a
/// ThreadSanitizer run). On macOS the debug information stays in the object
/// files, and ThreadSanitizer's symbolizer (atos) reads a dSYM bundle beside
/// the binary - without one a report names functions with `<null>` lines
/// (lane tlaunch1; checked on chat.local, lane tsan1). The bundle lands
/// beside the cached executable the launcher runs; cached like the
/// executable.
pub fn afterTestBuild(b: *std.Build, test_exe: *std.Build.Step.Compile, run: *std.Build.Step.Run, name: []const u8) void {
    if (test_exe.rootModuleTarget().os.tag.isDarwin() and b.graph.host.result.os.tag.isDarwin()) {
        const dsym = b.addSystemCommand(&.{"dsymutil"});
        dsym.setName(b.fmt("dsymutil {s}", .{name}));
        dsym.addArtifactArg(test_exe);
        dsym.expectExitCode(0);
        // Its warnings about objects without debug information (the
        // engine's prebuilt archives) are not the build's diagnostics.
        _ = dsym.captureStdErr(.{});
        run.step.dependOn(&dsym.step);
    }
}

/// Its system libraries are found where Zig looks for them: no stand-ins.
pub fn needsStandIns(target: std.Build.ResolvedTarget) bool {
    _ = target;
    return false;
}
pub fn addStandIns(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    _ = .{ b, module, target };
}
