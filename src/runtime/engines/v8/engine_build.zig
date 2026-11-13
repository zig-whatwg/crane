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
//!   - `resolve(b, target, options)`: which V8 this build links - the
//!     archives, and what an archive keeps beside itself for its consumers -
//!     or the reason it cannot link one: an answer, never an exit, so a build
//!     that cannot link V8 still configures and each step that needs the
//!     engine fails with the reason.
//!   - `link(b, module, resolved, request)`: V8 into one artifact's own root
//!     module - v8_wrapper.cpp with its flags and include paths, then the
//!     archives, their C++ runtime and system libraries. The request is in
//!     the build's words (engine_build.LinkRequest); what each field means
//!     for V8 is decided here.
//!   - `facts`: what the neutral build asks about the adapter - the words
//!     that name it, its Zig module (root file, name, and what it imports,
//!     in order), its build side's own tests.
//!
//! A build file is run by `zig build`'s configure step, not compiled into
//! Crane: it imports std and other build files alone.

const std = @import("std");
const engine_build = @import("../../engine_build_protocol.zig");
/// Which archives -Dv8, -Dv8-build and the target select.
const archives = @import("build/archives.zig");

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
    /// `-Dv8-wrapper-trace-check`: compile in the node wrapper walk's oracle
    /// (node_wrappers.zig `checkWalk`, the wrapper redesign's P5): in every
    /// major collection's weak processing the trees every kept node wrapper
    /// keeps are walked unpruned, each wrapper they hold must have been kept
    /// and each kept wrapper's node reached by the walk. A diagnosis build's
    /// option: it costs a walk of every live tree per collection. Not given:
    /// off.
    wrapper_trace_check: bool,
    /// `-Dv8-memory-pool-timeout-s`: how many seconds V8's page pool keeps a
    /// page a collection freed before the operating system gets it back; 0
    /// is no pool; null, not given, is the adapter's default - V8's own pool
    /// and no flag (memory_pool.zig, which has the values and what each
    /// measured).
    memory_pool_timeout_s: ?u32,
};

/// Declare the V8 adapter's build options. `target`: what the build is for -
/// -Djitless defaults from it.
pub fn declareOptions(b: *std.Build, target: std.Build.ResolvedTarget) Options {
    return .{
        // Where this target's V8 archives live.
        //
        // -Dv8-build picks between builds of the same V8: `static` (the default)
        // and `official`, the build with Chrome's official ThinLTO and PGO - which
        // 15.7 does not have (out/official was 13.1.203's and is retired until
        // roadmap item v8-pgo), so `resolve` answers that it is unavailable.
        // build/archives.zig holds the paths and pins them. An iOS target has
        // none: iOS is JavaScriptCore's (the user, 2026-11-10, ruling R4 - no V8
        // for iOS in any form), and the user paused every iOS build until the
        // JavaScriptCore adapter exists (15:55 ET: "skip ios builds and tests for
        // now until we get js core implemented"). So an aarch64-ios build with
        // -Dengine=v8 has no V8 to link, and `resolve` says so; nothing else
        // changes for a host build, and no gate builds for iOS.
        .build = b.option(
            archives.Build,
            "v8-build",
            "Which build of the V8 to link: static (default: the release build, <the V8's directory>/out/static) or official (ThinLTO + PGO as Chrome's official build; V8 15.7 has none yet - roadmap item v8-pgo)",
        ) orelse archives.Build.default,
        // -Dv8: the V8 version (build/archives.zig Version). One value: 15.7
        // is 15.7.112.43, Chrome 157's (the user, 2026-11-10;
        // tmp/plans/v8-update-plan.md), from jsengines/v8/15.7.112.43/. 13.1,
        // which the adapter no longer compiles against, is not a value any more
        // (the integrator's ruling Q5 on the build migration: dead pieces are
        // deleted): `zig build` itself refuses -Dv8=13.1 as it refuses any
        // value an option does not list.
        .version = b.option(archives.Version, "v8", "The V8 to link: 15.7 (15.7.112.43, Chrome 157's - jsengines/v8/15.7.112.43, scripts/build-v8-15.7.sh)") orelse archives.Version.default,
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
        // 522 files x3 on server1: summed per-file time 0.997. Its cost is confined to the adapter's own internal
        // compiles: a page's scripts each carry their own host-defined options, so V8's script cache never hit across
        // them in Crane, but a script the adapter itself compiles more than once is now a real compile every time -
        // which is why the adapter may evaluate a script of its own only where the adapter's script-compiles check,
        // tests/infra/v8up_adapter_script_compiles_test.zig, lists it (lane v8up b8, 2026-11-13: the per-call
        // compile behind ReadableStream's values() cost 21% of that row before it was removed).
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
        .wrapper_trace_check = b.option(
            bool,
            "v8-wrapper-trace-check",
            "V8: check the node wrapper walk in every major collection (the wrapper redesign's oracle; logs wrapper-trace-check errors, costs a walk of every live tree per collection)",
        ) orelse false,
        .memory_pool_timeout_s = b.option(
            u32,
            "v8-memory-pool-timeout-s",
            "V8: how many seconds its page pool keeps a page a collection freed before the operating system gets it back (default: not given = V8's own pool, 8 s, as Chrome ships - src/runtime/engines/v8/memory_pool.zig default_timeout_s); 0 = no pool: memory back at once, for a host of many short-lived pages",
        ),
    };
}

/// Put `options` in the adapter's own options module.
pub fn apply(options: Options, adapter_options: *std.Build.Step.Options) void {
    adapter_options.addOption(?u32, "young_generation_mb", options.young_generation_mb);
    adapter_options.addOption(?u32, "navigation_collection_mb", options.navigation_collection_mb);
    adapter_options.addOption(bool, "wrapper_trace_check", options.wrapper_trace_check);
    adapter_options.addOption(?u32, "memory_pool_timeout_s", options.memory_pool_timeout_s);
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

/// What this build links: the archives -Dv8, -Dv8-build and the target's OS
/// select (build/archives.zig) and what `resolve` reads from beside them at
/// configure time - the archive is built against Chromium's libc++, and
/// keeps that libc++'s consumer flags and the system libraries its own link
/// names in two files. Resolved once, so every artifact links the same V8.
pub const Resolved = struct {
    archives: archives.Archives,
    /// libcxx/flags.txt's -D defines and -nostdinc++ (its directories are
    /// added by `addSourceTo`, relative and as -I).
    libcxx_flags: []const []const u8,
    /// system-libs.txt's `-framework X` entries.
    frameworks: []const []const u8,
    /// system-libs.txt's `-lX` entries.
    system_libs: []const []const u8,
};

/// Which V8 this build links, or why it can link none: the archives the
/// options and the target's OS select, and the facts the archive keeps
/// beside itself (scripts/build-v8-15.7.sh writes them from GN's own compile
/// and d8's own link). A configure-time read the configuration cache cannot
/// see change, so it is poisoned; a host without the archive gets the reason
/// and how to get it as this build's answer.
pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options) engine_build.Resolution(Resolved) {
    const selected = archives.select(options.version, options.build, target.result.os.tag) catch |err| return .{
        .unavailable = switch (err) {
            error.NoOfficialBuild => "-Dv8=15.7 has no official build: out/official is retired until roadmap item v8-pgo (the user, 2026-11-10); drop -Dv8-build",
            error.NoV8ForIos => "an iOS target builds nothing yet: iOS uses JavaScriptCore, never V8 (the user, 2026-11-10), and iOS builds wait for the JavaScriptCore adapter (src/runtime/engines/jsc/)",
        },
    };
    const chromium = selected.chromium;
    b.graph.poisonCache();
    const dir = b.root.root_dir.handle;
    const flags_text = dir.readFileAlloc(b.graph.io, chromium.libcxx_flags, b.allocator, .limited(1 << 16)) catch |err| return .{ .unavailable = noArchive(b, chromium.libcxx_flags, err) };
    const libs_text = dir.readFileAlloc(b.graph.io, chromium.system_libs, b.allocator, .limited(1 << 16)) catch |err| return .{ .unavailable = noArchive(b, chromium.system_libs, err) };
    var flags: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.tokenizeScalar(u8, flags_text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "-D") or std.mem.eql(u8, line, "-nostdinc++")) flags.append(b.allocator, line) catch @panic("OOM");
    }
    var frameworks: std.ArrayList([]const u8) = .empty;
    var system_libs: std.ArrayList([]const u8) = .empty;
    lines = std.mem.tokenizeScalar(u8, libs_text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "-framework ")) {
            frameworks.append(b.allocator, std.mem.trim(u8, line["-framework ".len..], " ")) catch @panic("OOM");
        } else if (std.mem.startsWith(u8, line, "-l")) {
            system_libs.append(b.allocator, line[2..]) catch @panic("OOM");
        }
    }
    return .{ .ready = .{ .archives = selected, .libcxx_flags = flags.items, .frameworks = frameworks.items, .system_libs = system_libs.items } };
}

/// Why a host that lacks `path`, a file the archive keeps beside itself, can
/// link no V8, and how to get the archive.
fn noArchive(b: *std.Build, path: []const u8, err: anyerror) []const u8 {
    return b.fmt("-Dv8=15.7 needs {s} ({s}) on this host: build the archive with scripts/build-v8-15.7.sh, or copy jsengines/v8/15.7.112.43 from a host of the same OS and check it with its SHA256SUMS", .{ path, @errorName(err) });
}

/// The adapter's V8-facing C++, relative to the build root.
const wrapper_source = "src/runtime/engines/v8/v8_wrapper.cpp";

/// The flags every compile of v8_wrapper.cpp passes: C++20 without exceptions
/// or RTTI, and the defines V8's public headers must see to agree with the
/// archive the artifact links - the V8 ones (pointer compression, the
/// sandbox) and the cppgc ones, which are the archive's ABI, not a choice: the
/// headers inline `cppgc::Member`'s pointer compression, the write barrier's
/// fast path and the cage constants, so they must see what the library was
/// built with or a Member reads back another address than it was given
/// (tests/v8/cpp_heap_test.zig checks the result).
///
/// The archive says all of them itself, so none is kept by hand: its
/// include/ holds the build's v8-gn.h, which v8config.h includes under
/// -DV8_GN_HEADER (V8 BUILD.gn v8_generate_external_defines_header), and its
/// libcxx/flags.txt the defines GN compiles every consumer of its libc++ with
/// (`Resolved.libcxx_flags`, read by `resolve`). (13.1.203's archive said
/// neither, and its seven defines were listed here by hand until the value
/// -Dv8=13.1 was deleted.)
///
/// `extra`: flags of the artifact's own.
fn wrapperFlags(b: *std.Build, resolved: *const Resolved, extra: []const []const u8) []const []const u8 {
    const from_archive = [_][]const u8{ "-std=c++20", "-fno-exceptions", "-fno-rtti", "-DV8_GN_HEADER" };
    return std.mem.concat(b.allocator, []const u8, &.{ &from_archive, resolved.libcxx_flags, extra }) catch @panic("OOM");
}

/// Link V8 into `module`, one artifact's own root module (the protocol's
/// `Engine.link` says why it must be the artifact's alone): the C++ wrapper,
/// and - unless the request is for a compile-only check - V8's archives.
///
/// What the build's words mean for V8:
///   - `request.thread_sanitized`: the wrapper is compiled apart, as a static
///     library of its own, uninstrumented (`addSource`) - so its source is
///     then not among the module's own, and nothing may take "this module
///     compiles v8_wrapper.cpp" for "this artifact links V8" (the protocol's
///     `Engine.isLinkedInto` is the build's record of the call);
///   - `request.handle_accounting`: the wrapper counts live Global<T> handles
///     (-DCRANE_TRACK_GLOBALS=1). It runs on every handle creation, so only
///     the binary that reports the count pays for it, never a browser;
///   - `request.link` false: the wrapper is compiled and nothing is linked -
///     no V8 archive, no system library is read.
pub fn link(b: *std.Build, module: *std.Build.Module, resolved: *const Resolved, request: engine_build.LinkRequest) void {
    const extra: []const []const u8 = if (request.handle_accounting) &.{"-DCRANE_TRACK_GLOBALS=1"} else &.{};
    addSource(b, module, resolved, request.thread_sanitized, extra);
    if (request.link) addArchives(module, resolved);
}

/// The V8 wrapper's source and headers on `module`: v8_wrapper.cpp with
/// wrapperFlags, then the include directories. The three directories of
/// Chromium's libc++, which the archive is built against, come first, as -I
/// (addIncludePath): Zig puts its own -isystem directories (clang's builtins,
/// the C library's) before any a module adds, so as -isystem they would follow
/// the C library's and <cstdio> would find its <stdio.h> instead of libc++'s
/// (scripts/build-v8-15.7.sh, step_smoke). Then V8's include/. Zig's own
/// libc++ is not linked: the binary holds Chromium's, alone.
///
/// `apart` (a thread-sanitized artifact): Zig links
/// its ThreadSanitizer runtime with its own libc++ (std::__1) into every
/// compilation that has an instrumented module, and puts that libc++'s -D
/// macros and -isystem directories on every C++ file the compilation builds -
/// against Chromium's libc++ headers v8_wrapper.cpp is compiled with
/// ("_LIBCPP_ABI_NAMESPACE macro redefined"; errno and FP_NAN undeclared).
/// So the wrapper is its own compilation: a static library with no
/// instrumented module and no Zig libc++ - built exactly as without the
/// sanitizer, Chromium's libc++ alone (std::__Cr) - linked into the
/// artifact, where the two libc++ coexist by inline namespace. V8's archive
/// and Chromium's libc++ are uninstrumented too. Chromium's own TSAN builds
/// instrument everything, libc++ and V8 included (build/config/sanitizers/
/// BUILD.gn, use_custom_libcxx with is_tsan), because they look for races in
/// V8 and Blink; verify mode looks for races in Crane's Zig code, which stays
/// instrumented (the root build.zig's instrumentForThreadSanitizer). What
/// this gives up: races inside v8_wrapper.cpp itself, which 13.1's build
/// instrumented, and its UBSan checks in the sanitizer build (sanitize_c off
/// for the library: the UBSan runtime would be a second one beside the
/// artifact's). On Linux the runtime and Chromium's libc++abi both define
/// the __cxa_guard functions: CRANE_V8_WRAPPER_APART_FOR_TSAN gives
/// v8_wrapper.cpp weak ones that keep libc++abi's from being linked, so the
/// runtime's win (see there).
fn addSource(b: *std.Build, module: *std.Build.Module, resolved: *const Resolved, apart: bool, extra: []const []const u8) void {
    if (apart) {
        const wrapper = b.addLibrary(.{
            .name = "v8_wrapper",
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = module.resolved_target,
                .optimize = module.optimize orelse .Debug,
                .link_libc = true,
                .sanitize_c = .off,
            }),
        });
        const flags = std.mem.concat(b.allocator, []const u8, &.{ extra, &.{"-DCRANE_V8_WRAPPER_APART_FOR_TSAN=1"} }) catch @panic("OOM");
        addSourceTo(b, wrapper.root_module, resolved, flags);
        module.linkLibrary(wrapper);
        module.link_libc = true;
        return;
    }
    addSourceTo(b, module, resolved, extra);
}

/// `addSource`'s compile of v8_wrapper.cpp into `module`.
fn addSourceTo(b: *std.Build, module: *std.Build.Module, resolved: *const Resolved, extra: []const []const u8) void {
    module.addCSourceFile(.{
        .file = b.path(wrapper_source),
        .flags = wrapperFlags(b, resolved, extra),
    });
    for (resolved.archives.chromium.libcxx_include) |dir| module.addIncludePath(.{ .cwd_relative = dir });
    module.addIncludePath(.{ .cwd_relative = resolved.archives.include });
    module.link_libc = true;
}

/// V8's archives on `module`, and the C++ runtime and system libraries they
/// need: Chromium's libc++ (libc++_chromium.a), Temporal's Rust
/// (librust_v8.a) and the archive's frameworks and libraries. The archives'
/// libplatform and libbase are regular ("fat") archives: GN's thin ones
/// cannot be read by Zig's linker.
fn addArchives(module: *std.Build.Module, resolved: *const Resolved) void {
    module.addObjectFile(.{ .cwd_relative = resolved.archives.monolith });
    module.addObjectFile(.{ .cwd_relative = resolved.archives.libplatform });
    module.addObjectFile(.{ .cwd_relative = resolved.archives.libbase });
    module.addObjectFile(.{ .cwd_relative = resolved.archives.chromium.libcxx });
    module.addObjectFile(.{ .cwd_relative = resolved.archives.chromium.rust });
    for (resolved.frameworks) |framework| module.linkFramework(framework, .{});
    for (resolved.system_libs) |library| module.linkSystemLibrary(library, .{});
}

/// What the neutral build asks about this adapter.
pub const facts: engine_build.Facts = .{
    .words = &.{"v8"},
    .build_tests = &.{"src/runtime/engines/v8/build/archives.zig"},
    // The adapter's Zig module. Its root re-exports protocol.zig, so in a V8
    // build the facade's `engine_impl` IS this module: the protocol functions
    // live beside the adapter files they call, and a file of another module
    // cannot import those by relative path.
    .module_root = "src/runtime/engines/v8/root.zig",
    .module_name = "v8",
    // What the module imports, in the order the root build.zig added them
    // while it wired this module by hand. The order is part of every compile
    // that takes the module: a new import goes at the end, or where its cost
    // is known.
    .imports = &.{
        // interface_bindings consults build_options.interface_allowlist (and
        // snapshot_loader the three values `applyTransitional` still writes
        // there).
        "build_options",
        "clock",
        "process",
        "infra",
        "host",
        "runtime",
        "debug_options",
        // The protocol's facade: the adapter's own files call it as
        // everything else does.
        "engine",
        // This adapter's own build options (`apply`): this module alone
        // imports them.
        "adapter_options",
        // For automatic constructor inheritance setup.
        "interfaces",
        // For async iterator options parsing.
        "dictionaries",
        // For error types (Exception).
        "webidl",
        // For HeadersInit conversion.
        "typedefs",
        // For ReadableStream start callback invocation.
        "impls",
        // The adapter registers the namespaces a snapshot lacks when it
        // creates a Window realm.
        "namespaces",
        // For document initialization.
        "dom",
        // The event loop and the streams' promise helper, for async
        // operations (streams, promises).
        "event_loop",
        "streams_async_promise",
        // The platform protocol: the adapter's Intl asks it for local time
        // (intl_binding.zig, platform.localDateTime).
        "platform",
        // For the pure Zig Intl.DateTimeFormat implementation.
        "intl",
        // For ES module loading from HTTP URLs.
        "fetch",
    },
    .engineless = false,
};
