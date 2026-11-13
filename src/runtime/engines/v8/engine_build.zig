//! The BUILD SIDE of the V8 adapter (docs/engine-protocol.md, 7b): the build
//! options that are V8's alone are declared here, by the adapter, and
//! nowhere in the root build.zig (the user, 2026-11-12: "I don't want any of
//! the v8 code in build.zig, the valid flags should be in the js engine
//! protocol").
//!
//! The protocol's build file (src/runtime/engine_build_protocol.zig, which
//! the root build.zig imports) lists the adapters' build files by engine
//! name and calls this interface, the same for every adapter (its
//! conformance check holds each declaration to its type):
//!
//!   - `declareOptions(b, target)` declares the adapter's `-D` options and
//!     returns what the command line gave; an option's default may depend on
//!     the target. An adapter that is not the build's engine is never asked,
//!     so its options do not exist in that build: `zig build` itself refuses
//!     a `-D` nothing declared.
//!   - `apply(options, adapter_options)` puts the values in the adapter's own
//!     options module - `@import("adapter_options")`, which only the engine
//!     adapter's module imports - never in the `build_options` every module
//!     shares.
//!   - `applyTransitional(options, shared)`: what the shared `build_options`
//!     still carries of this adapter - the three values snapshot_loader.zig
//!     reads there and three engine facts nothing reads - written with the
//!     names and in the order they always had, so that moving their options
//!     here changed no compile. It ends with the migration's one commit
//!     that may change an options module's text
//!     (tmp/plans/build-protocol-design.md, batch E5).
//!   - `isDefaultFor(target)`: whether V8 is the engine of a build for
//!     `target` when -Dengine does not say.
//!   - `resolve(b, target, options)`: which V8 this build links, or the
//!     reason it cannot link one - an answer, never an exit, so a build that
//!     cannot link V8 still configures and each step that needs the engine
//!     fails with the reason.
//!   - `facts`: what the neutral build asks about the adapter.
//!
//! A build file is run by `zig build`'s configure step, not compiled into
//! Crane: it imports std and other build files alone.
//!
//! Still in the root build.zig, to move here (the next batch, E2): the V8
//! link lines - the wrapper's flags and source, the archives - and
//! tools/v8_archives.zig itself.

const std = @import("std");
const engine_build = @import("../../engine_build_protocol.zig");
/// Which archives -Dv8, -Dv8-build and the target select. In tools/ until
/// the link lines that also read it leave the root build.zig (batch E2).
const archives = @import("../../../../tools/v8_archives.zig");

/// What the command line gave the adapter's options.
pub const Options = struct {
    /// `-Dv8-build`: which build of the V8 to link (archives.Build).
    build: archives.Build,
    /// `-Dv8`: which V8 to link (archives.Version).
    version: archives.Version,
    /// `-Djitless`: V8 without its JIT compilers.
    jitless: bool,
    /// `-Dv8-compilation-cache`: start V8 WITH its compilation cache.
    compilation_cache: bool,
    /// `-Dv8-extra-flags`: V8 flags appended to the set V8 starts with.
    extra_flags: []const u8,
    /// `-Dv8-young-generation-mb`: megabytes of the WHOLE young generation of
    /// each isolate; 0 is V8's own sizing; null, not given, is the adapter's
    /// default (young_generation.zig `default_mb`, which says what the value
    /// means and how it is applied).
    young_generation_mb: ?u32,
    /// `-Dv8-navigation-collection-mb`: how many megabytes V8's heap must
    /// hold for the collection after a main frame's navigation; 0 is never;
    /// null, not given, is the adapter's default (navigation_collection.zig,
    /// which says what it is and why).
    navigation_collection_mb: ?u32,
};

/// Declare the V8 adapter's build options. `target`: what the build is for -
/// -Djitless defaults from it.
pub fn declareOptions(b: *std.Build, target: std.Build.ResolvedTarget) Options {
    return .{
        // Where this target's V8 archives live.
        //
        // -Dv8-build picks between two macOS builds of the same V8 (13.1.203):
        // `static` (the default) and `official`, the build with Chrome's official
        // ThinLTO and PGO (scripts/build-v8-official.sh, whose control build
        // reproduces out/static byte for byte). tools/v8_archives.zig holds the
        // paths and pins them. An iOS target has none: iOS is JavaScriptCore's (the
        // user, 2026-11-10, ruling R4 - no V8 for iOS in any form), and the user
        // paused every iOS build until the JavaScriptCore adapter exists (15:55 ET:
        // "skip ios builds and tests for now until we get js core implemented").
        // So an aarch64-ios build with -Dengine=v8 has no V8 to link, and
        // `resolve` says so; nothing else changes for a host build, and no gate
        // builds for iOS.
        .build = b.option(
            archives.Build,
            "v8-build",
            "Which V8 13.1.203 build to link on macOS: static (default; jsengines/v8/out/static) or official (opt-in: jsengines/v8/out/official, ThinLTO + PGO as Chrome's official build, scripts/build-v8-official.sh; on chat.local only - build with it there)",
        ) orelse archives.Build.default,
        // -Dv8: the V8 version (tools/v8_archives.zig Version): 13.1 until the
        // switch commit; 15.7 is 15.7.112.43, Chrome 157's (the user, 2026-11-10;
        // tmp/plans/v8-update-plan.md), from jsengines/v8/15.7.112.43/.
        .version = b.option(archives.Version, "v8", "The V8 to link: 15.7 (default: 15.7.112.43, Chrome 157's - jsengines/v8/15.7.112.43, scripts/build-v8-15.7.sh); 13.1 is refused, the adapter is ported") orelse archives.Version.default,
        // Phase 8 (mobile): iOS forbids JIT outright - no W^X exception for third-party
        // apps - so V8 must run in its interpreter-only mode there or the process is
        // killed on first code generation. Defaults ON for iOS targets and OFF everywhere
        // else, because --jitless costs a large amount of JS throughput and nothing but
        // the platform restriction justifies paying it.
        .jitless = b.option(
            bool,
            "jitless",
            "Run V8 without JIT (required on iOS; large JS slowdown elsewhere)",
        ) orelse (target.result.os.tag == .ios),
        // Crane starts V8 WITHOUT its compilation cache (the user's ruling, 2026-11-11 16:12 UTC; lane v8up b4).
        // V8 15.7's eval cache serves `new Function(...)` and eval by source text alone (EvalCacheKey: source, outer
        // function, language mode, position - no host-defined options; compiler.cc LookupEval) and stores a compile
        // on its FIRST sighting (13.1: on its second, behind a dummy entry), so a Function built from the same text
        // by a second script imports with the FIRST script's base URL and nonce. WPT
        // html/semantics/scripting-1/the-script-element/module/dynamic-import/code-cache-base-url.html ("beta -
        // Function", "gamma - Function") and code-cache-nonce.html ("Second" and "Third dynamic import should use
        // nonce=...") fail that way in Chrome 157 and pass in Firefox 160 and Safari 27.2 (wpt.fyi stable runs of
        // 2026-11-11): golden rule 2, the majority and the spec. V8 15.7's public API has nothing narrower than the
        // flag (ScriptCompiler::CompileOptions has no cache bypass; Isolate::ClearCachesForTesting is test-only;
        // compilation-cache.h IsEnabledScriptAndEval reads v8_flags.compilation_cache), and the flag turns off the
        // script cache too. Measured before the ruling, flag against no flag at 7ebd08c5001: all 9 subtests of the
        // two files pass x3; the perf suite x5 on chat.local: time 0.9998, memory 0.9987; WPT dom/nodes + html/dom,
        // 522 files x3 on server1: summed per-file time 0.997. It costs nothing today because every script carries
        // its own host-defined options, so V8's script cache never hits across scripts in Crane.
        // -Dv8-compilation-cache turns the cache back on, for measurement only (tmp/plans/feature-queue.md says
        // when to re-measure).
        .compilation_cache = b.option(
            bool,
            "v8-compilation-cache",
            "Start V8 WITH its compilation cache (a measurement switch; default off: the cache answers Function() with another script's base URL and nonce)",
        ) orelse false,
        // -Dv8-extra-flags="<flags>": V8 flags a MEASUREMENT build starts V8 with, after the product's (lane v8up
        // b5: the collector's cadence and the young generation's size cannot be read or changed any other way -
        // V8 freezes its flags when it starts). Empty by default, pinned by tests/v8/v8_flags_test.zig; never an
        // environment variable. Chromium's route is the --js-flags switch (gin/v8_initializer.cc).
        .extra_flags = b.option(
            []const u8,
            "v8-extra-flags",
            "V8 flags appended to the set V8 starts with (a measurement route; default none), e.g. \"--trace-gc --max-semi-space-size=8\"",
        ) orelse "",
        .young_generation_mb = b.option(
            u32,
            "v8-young-generation-mb",
            "V8: the most memory each isolate's young generation takes at rest, in MB of the WHOLE young generation: 24 = 8 MB semispaces (the default: src/runtime/engines/v8/young_generation.zig default_mb), 48 = 16 MB, 96 = 32 MB, 0 = V8's own sizing (32 MB semispaces, Chrome's on desktop: for a desktop build)",
        ),
        .navigation_collection_mb = b.option(
            u32,
            "v8-navigation-collection-mb",
            "V8: after a main frame's navigation, collect the page that was left when V8's heap holds at least this many MB (default: 16 with a limited young generation, never with V8's own sizing, -Dv8-young-generation-mb=0); 0 = never",
        ),
    };
}

/// Put `options` in the adapter's own options module.
pub fn apply(options: Options, adapter_options: *std.Build.Step.Options) void {
    adapter_options.addOption(?u32, "young_generation_mb", options.young_generation_mb);
    adapter_options.addOption(?u32, "navigation_collection_mb", options.navigation_collection_mb);
}

/// TRANSITIONAL (batch E5 of tmp/plans/build-protocol-design.md ends it): the
/// three values snapshot_loader.zig still reads from the shared
/// `build_options`, and after them the three engine facts the root build.zig
/// used to write there and nothing reads (code asks `engine.name` and
/// `engine.capabilities`) - all six with the names, the values and the order
/// they have always had, so the module's text, and with it every compile
/// that imports it, is what it was. The first three move to `apply`, and the
/// last three go, with the one commit of the migration that may change an
/// options module's text.
pub fn applyTransitional(options: Options, shared: *std.Build.Step.Options) void {
    shared.addOption(bool, "jitless", options.jitless);
    shared.addOption(bool, "v8_compilation_cache", options.compilation_cache);
    shared.addOption([]const u8, "v8_extra_flags", std.mem.trim(u8, options.extra_flags, " "));
    shared.addOption([]const u8, "engine_name", "v8");
    shared.addOption(bool, "has_snapshot_support", true);
    shared.addOption(bool, "has_isolate_per_thread", true);
}

/// V8 is the engine of every build but an iOS one: iOS is JavaScriptCore's
/// (the user, 2026-11-10, ruling R4: no V8 for iOS in any form).
pub fn isDefaultFor(target: std.Target) bool {
    return target.os.tag != .ios;
}

/// What this build links.
pub const Resolved = struct {
    /// The archives -Dv8, -Dv8-build and the target's OS select.
    archives: archives.Archives,
};

/// Which V8 this build links, or why it can link none.
pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options) engine_build.Resolution(Resolved) {
    _ = b;
    if (options.version == .@"13.1") return .{
        .unavailable = "-Dv8=13.1: the V8 adapter (src/runtime/engines/v8/v8_wrapper.cpp) is ported to V8 15.7.112.43 and no longer compiles against 13.1.203; drop -Dv8",
    };
    const selected = archives.selectVersion(options.version, options.build, target.result.os.tag) catch |err| return .{
        .unavailable = switch (err) {
            error.NoOfficialBuild => "-Dv8=15.7 has no official build: out/official is retired until roadmap item v8-pgo (the user, 2026-11-10); drop -Dv8-build",
            error.NoV8ForIos => "an iOS target builds nothing yet: iOS uses JavaScriptCore, never V8 (the user, 2026-11-10), and iOS builds wait for the JavaScriptCore adapter (src/runtime/engines/jsc/)",
        },
    };
    return .{ .ready = .{ .archives = selected } };
}

/// What the neutral build asks about this adapter.
pub const facts: engine_build.Facts = .{
    .words = &.{"v8"},
};
