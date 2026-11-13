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
//!   - `linkedInto(module)`: whether `link` put the wrapper's source on a
//!     module.
//!   - `facts`: what the neutral build asks about the adapter.
//!
//! A build file is run by `zig build`'s configure step, not compiled into
//! Crane: it imports std and other build files alone.

const std = @import("std");
const engine_build = @import("../../engine_build_protocol.zig");
/// Which archives -Dv8, -Dv8-build and the target select.
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

/// What this build links: the archives -Dv8, -Dv8-build and the target's OS
/// select (tools/v8_archives.zig) and, for an archive built against
/// Chromium's libc++ (-Dv8=15.7), what `resolve` reads from beside it at
/// configure time: that libc++'s consumer flags and the system libraries the
/// archive's own link names. Resolved once, so every artifact links the same
/// V8.
pub const Resolved = struct {
    archives: archives.Archives,
    /// libcxx/flags.txt's -D defines and -nostdinc++ (its directories are
    /// added by `addSourceTo`, relative and as -I).
    libcxx_flags: []const []const u8 = &.{},
    /// system-libs.txt's `-framework X` entries.
    frameworks: []const []const u8 = &.{},
    /// system-libs.txt's `-lX` entries.
    system_libs: []const []const u8 = &.{},
};

/// Which V8 this build links, or why it can link none: the archives the
/// options and the target's OS select and, for an archive built against
/// Chromium's libc++, the facts it keeps beside itself
/// (scripts/build-v8-15.7.sh writes them from GN's own compile and d8's own
/// link). A configure-time read the configuration cache cannot see change, so
/// it is poisoned; a host without the archive gets the reason and how to get
/// it as this build's answer.
pub fn resolve(b: *std.Build, target: std.Build.ResolvedTarget, options: Options) engine_build.Resolution(Resolved) {
    if (options.version == .@"13.1") return .{
        .unavailable = "-Dv8=13.1: the V8 adapter (src/runtime/engines/v8/v8_wrapper.cpp) is ported to V8 15.7.112.43 and no longer compiles against 13.1.203; drop -Dv8",
    };
    const selected = archives.selectVersion(options.version, options.build, target.result.os.tag) catch |err| return .{
        .unavailable = switch (err) {
            error.NoOfficialBuild => "-Dv8=15.7 has no official build: out/official is retired until roadmap item v8-pgo (the user, 2026-11-10); drop -Dv8-build",
            error.NoV8ForIos => "an iOS target builds nothing yet: iOS uses JavaScriptCore, never V8 (the user, 2026-11-10), and iOS builds wait for the JavaScriptCore adapter (src/runtime/engines/jsc/)",
        },
    };
    const chromium = selected.chromium orelse return .{ .ready = .{ .archives = selected } };
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
/// sandbox) and the cppgc ones, in this one place.
///
/// An archive built against Chromium's libc++ (-Dv8=15.7) says all of them
/// itself: its include/ holds the build's v8-gn.h, which v8config.h includes
/// under -DV8_GN_HEADER (V8 BUILD.gn v8_generate_external_defines_header), and
/// its libcxx/flags.txt the defines GN compiles every consumer of that libc++
/// with (`Resolved.libcxx_flags`, read by `resolve`). Nothing is kept by hand
/// for it. What follows is 13.1's list:
///
/// The cppgc defines are the archive's ABI, not a choice (the wrapper
/// redesign, tmp/redesign/wrapper-redesign-design.md 2.6 and 4.12; risk R7).
/// The headers inline `cppgc::Member`'s pointer compression, the write
/// barrier's fast path and the cage constants, so they must see what the
/// library was built with or a Member reads back another address than it was
/// given. 13.1.203's BUILD.gn sets cppgc_enable_caged_heap on 64-bit, which
/// forces CPPGC_YOUNG_GENERATION and CPPGC_POINTER_COMPRESSION, and its
/// gni/v8.gni defaults cppgc_enable_slim_write_barrier and
/// cppgc_enable_larger_cage to true; no args.gn Crane builds with
/// (scripts/build-v8-official.sh control_args, scripts/build-v8-linux.sh)
/// changes them. Read from the archives themselves (lane wr2, .wr2/abi-check.sh
/// in its handoff): out/static on macOS and on Linux define
/// CagedHeapBase::g_heap_base_, AgeTable, CombinedWriteBarrierSlow and
/// CageBaseGlobal::g_base_, whose initial value - the cage alignment's mask -
/// is 0x3ffffffff: the 16 GB "larger cage", compression shift 3
/// (include/cppgc/internal/api-constants.h). out/ios-arm64's is 0xffffffff:
/// built without the larger cage (shift 1), so an iOS compile leaves
/// CPPGC_ENABLE_LARGER_CAGE out. tests/v8/cpp_heap_test.zig checks the result:
/// a Member is 4 bytes and reads back what it was given.
///
/// `archive_os`: the OS whose archive the artifact links (tools/v8_archives.zig
/// selects it by the target's OS). `extra`: flags of the artifact's own.
fn wrapperFlags(b: *std.Build, resolved: *const Resolved, archive_os: std.Target.Os.Tag, extra: []const []const u8) []const []const u8 {
    if (resolved.archives.chromium != null) {
        const from_archive = [_][]const u8{ "-std=c++20", "-fno-exceptions", "-fno-rtti", "-DV8_GN_HEADER" };
        return std.mem.concat(b.allocator, []const u8, &.{ &from_archive, resolved.libcxx_flags, extra }) catch @panic("OOM");
    }
    const common = [_][]const u8{
        "-std=c++20",
        "-fno-exceptions",
        "-fno-rtti",
        "-DV8_COMPRESS_POINTERS",
        "-DV8_ENABLE_SANDBOX",
        "-DCPPGC_CAGED_HEAP",
        "-DCPPGC_YOUNG_GENERATION",
        "-DCPPGC_POINTER_COMPRESSION",
        "-DCPPGC_SLIM_WRITE_BARRIER",
    };
    const larger_cage: []const []const u8 = if (archive_os == .ios) &.{} else &.{"-DCPPGC_ENABLE_LARGER_CAGE"};
    return std.mem.concat(b.allocator, []const u8, &.{ &common, larger_cage, extra }) catch @panic("OOM");
}

/// Link V8 into `module`, one artifact's own root module (the protocol's
/// `Engine.link` says why it must be the artifact's alone): the C++ wrapper,
/// and - unless the request is for a compile-only check - V8's archives.
///
/// What the build's words mean for V8:
///   - `request.thread_sanitized`: the wrapper is compiled apart, as a static
///     library of its own, uninstrumented (`addSource`);
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

/// Whether `module` compiles the wrapper itself: `link` put v8_wrapper.cpp on
/// it.
///
/// KNOWN DEFECT, kept as it answers today (this function moved here with the
/// link code, a move that changed no build; found by lane build3,
/// 2026-11-13): for a thread-sanitized artifact the wrapper is on a library
/// of its own (`addSource`), so this answers false although the artifact
/// links V8, and the test executables of a -Dsanitize-thread build are told
/// they have no engine. The fix is the neutral build's own record of what it
/// linked the engine into, in place of this inspection of sources.
pub fn linkedInto(module: *std.Build.Module) bool {
    for (module.link_objects.items) |object| {
        if (object != .c_source_file) continue;
        const file = object.c_source_file.file;
        if (file == .src_path and std.mem.eql(u8, file.src_path.sub_path, wrapper_source)) return true;
    }
    return false;
}

/// The V8 wrapper's source and headers on `module`: v8_wrapper.cpp with
/// wrapperFlags, then the include directories. For an archive built against
/// Chromium's libc++ that libc++'s three directories come first, as -I
/// (addIncludePath): Zig puts its own -isystem directories (clang's builtins,
/// the C library's) before any a module adds, so as -isystem they would follow
/// the C library's and <cstdio> would find its <stdio.h> instead of libc++'s
/// (scripts/build-v8-15.7.sh, step_smoke). Then V8's include/. Zig's own
/// libc++ only for 13.1: with 15.7 the binary holds Chromium's, alone.
///
/// `apart` (a thread-sanitized artifact) with such an archive: Zig links
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
    if (apart and resolved.archives.chromium != null) {
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
        .flags = wrapperFlags(b, resolved, module.resolved_target.?.result.os.tag, extra),
    });
    if (resolved.archives.chromium) |chromium| for (chromium.libcxx_include) |dir| module.addIncludePath(.{ .cwd_relative = dir });
    module.addIncludePath(.{ .cwd_relative = resolved.archives.include });
    if (resolved.archives.chromium == null) module.link_libcpp = true else module.link_libc = true;
}

/// V8's archives on `module`, and the C++ runtime and system libraries they
/// need: Zig's libc++ for 13.1; for 15.7 Chromium's libc++ (libc++_chromium.a),
/// Temporal's Rust (librust_v8.a) and the archive's frameworks and libraries.
/// The archives' libplatform and libbase are regular ("fat") archives: GN's
/// thin ones cannot be read by Zig's linker.
fn addArchives(module: *std.Build.Module, resolved: *const Resolved) void {
    module.addObjectFile(.{ .cwd_relative = resolved.archives.monolith });
    module.addObjectFile(.{ .cwd_relative = resolved.archives.libplatform });
    module.addObjectFile(.{ .cwd_relative = resolved.archives.libbase });
    if (resolved.archives.chromium) |chromium| {
        module.addObjectFile(.{ .cwd_relative = chromium.libcxx });
        module.addObjectFile(.{ .cwd_relative = chromium.rust });
        for (resolved.frameworks) |framework| module.linkFramework(framework, .{});
        for (resolved.system_libs) |library| module.linkSystemLibrary(library, .{});
    }
}

/// What the neutral build asks about this adapter.
pub const facts: engine_build.Facts = .{
    .words = &.{"v8"},
};
