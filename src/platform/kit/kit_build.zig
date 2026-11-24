//! THE KIT'S BUILD SIDE (docs/platform-protocol.md 10;
//! tmp/plans/build-protocol-design.md 2.4). The platform kit is not an
//! adapter, but its C libraries are the platform's, so they are built here
//! and in the build files beside the parts that link them, never in the
//! root build.zig (the user, 2026-11-12: no engine or platform code in
//! build.zig):
//!
//!   curl/curl_build.zig                  libcurl, with the mbedTLS, zlib and nghttp2 it links
//!   brotli/brotli_build.zig              Brotli, the RFC 7932 codec
//!   image_codecs/image_codecs_build.zig  the testing image codecs (libjpeg-turbo, Expat, NanoSVG)
//!
//! The root build reaches this file through the platform protocol's build
//! side (src/platform/platform_build_protocol.zig `kit`) and names no
//! library.
//!
//! Run by `zig build`'s configure step, not compiled into Crane: std and
//! build files only.
const std = @import("std");

/// The parts' build files.
pub const curl = @import("curl/curl_build.zig");
pub const brotli = @import("brotli/brotli_build.zig");
pub const image_codecs = @import("image_codecs/image_codecs_build.zig");

/// What a C compile or a C-header translation for the target needs beyond
/// what Zig finds by itself - a system root's headers, libraries and
/// frameworks - supplied by the platform that answers for the target
/// (the design's `prepareC`, 2.4); null when it needs nothing. The kit calls
/// it wherever it makes C for the target, and knows nothing of what it adds.
pub const PrepareC = struct {
    /// For a module that compiles or links C.
    module: *const fn (module: *std.Build.Module) void,
    /// For every compile reachable from a step: a library's own and the
    /// libraries it links, which are artifacts of their own.
    graph: *const fn (step: *std.Build.Step) void,
    /// For a translation of C headers to Zig (`addTranslateC`).
    translate: *const fn (translate: *std.Build.Step.TranslateC) void,
};

/// A C header set translated to Zig by the build: what a file's `@cImport`
/// was, before Zig 0.17 removed `@cImport` (roadmap zig-017; Step.TranslateC
/// is deprecated in 0.17 but present). The file
/// imports the result by name (`const c = @import("curl_c");`).
///
/// `@cImport` translated against its module's include paths and C macros; a
/// translate-c step sees only its own, so each set names them: `libs`'
/// installed headers (what linkLibrary gave the module), `macros` (what
/// addCMacro gave it), `system_libs` (linkSystemLibrary's pkg-config flags)
/// and what the target's C preparation adds (`prepare`: for aarch64-ios, the
/// SDK's usr/include - which kit/posix's time.h never had, the iOS lib-full
/// break since de4a36b9529a).
///
/// ONE module per header set per graph: two translate-c modules with the same
/// inputs have the same output file, and a file in two modules of one compile
/// is an error. So a set two importers in one graph share is made once and
/// handed to both (the root build's PlatformBinding.c_time, for tests/platform).
///
/// Translated as Debug: none of these headers tests __OPTIMIZE__ or NDEBUG
/// (curl 8.18, mbedTLS 3.6.6, Brotli, image_codecs.h and <time.h>; checked
/// 2026-10-29), so the result is the same in every mode the importers build.
pub const CImport = struct {
    includes: []const []const u8,
    libs: []const *std.Build.Step.Compile = &.{},
    macros: []const [2][]const u8 = &.{},
    system_libs: []const []const u8 = &.{},
};

/// The threading configuration buildStaticLibcurl compiles mbedTLS with, which
/// every translation of its headers must see too.
pub const mbedtls_threading_macros = [_][2][]const u8{ .{ "MBEDTLS_THREADING_C", "" }, .{ "MBEDTLS_THREADING_PTHREAD", "" } };

/// `spec`'s header set, translated for `target` (see CImport), as a module.
pub fn cImport(b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, prepare: ?PrepareC, spec: CImport) *std.Build.Module {
    var text: std.ArrayList(u8) = .empty;
    for (spec.includes) |include| text.print(b.allocator, "#include <{s}>\n", .{include}) catch @panic("OOM");
    const header = b.addWriteFiles().add(b.fmt("{s}.h", .{name}), text.items);
    const translate = b.addTranslateC(.{ .root_source_file = header, .target = target, .optimize = .Debug, .link_libc = true });
    for (spec.libs) |lib| translate.addIncludePath(lib.getEmittedIncludeTree());
    for (spec.macros) |macro| translate.defineCMacro(macro[0], macro[1]);
    for (spec.system_libs) |lib| translate.linkSystemLibrary(lib, .{});
    if (prepare) |p| p.translate(translate);
    return translate.createModule();
}

/// The C sanitizer a kit library keeps in every mode, whatever the modes of
/// the build that links it say - what the root build's checkLinkedC holds it
/// to: libcurl's own sources' (curl_build.zig `libcurl_sanitize_c`, which says
/// why). Null for every other library, which takes its build's.
pub fn expectedSanitizer(library: []const u8) ?std.zig.SanitizeC {
    if (std.mem.eql(u8, library, "curl")) return curl.libcurl_sanitize_c;
    return null;
}

/// The kit's own `-D` options.
pub const Options = struct {
    /// -Dsystem-curl: link the system's libcurl instead of compiling the
    /// kit's (curl/curl_build.zig).
    system_library: bool,
    /// -Dhttp2: HTTP/2 through the vendored nghttp2 (curl_build.zig
    /// buildNghttp2).
    http2: bool,
};

/// Declare the kit's options and answer them, defaults included. The root
/// build calls it once, where they stand in its option order.
pub fn declareOptions(b: *std.Build) Options {
    // Fetch network backend options
    // Use system libcurl for faster development builds (no static compilation)
    const use_system_curl = b.option(
        bool,
        "system-curl",
        "Use system libcurl instead of static compilation (faster dev builds)",
    ) orelse false;

    // HTTP/2 through the vendored nghttp2 (buildNghttp2)
    const enable_http2 = b.option(
        bool,
        "http2",
        "HTTP/2 via the vendored nghttp2 (default on)",
    ) orelse true;
    return .{ .system_library = use_system_curl, .http2 = enable_http2 };
}

/// A system libcurl may lack WebSockets. Say so when building rather than
/// leaving it to a runtime CURLE_UNSUPPORTED_PROTOCOL: a warning, asked at
/// make time by `probe` (the root build's tools/build_probe.zig,
/// curl-websockets) - the root build adds it to every top-level step. Null
/// when the kit compiles its own libcurl.
pub fn systemLibraryCheck(b: *std.Build, options: Options, probe: *std.Build.Step.Compile) ?*std.Build.Step.Run {
    if (!options.system_library) return null;
    const run = b.addRunArtifact(probe);
    run.setName("check the system libcurl for WebSockets");
    run.addArg("curl-websockets");
    // Its answer is the machine's: asked on every build.
    run.has_side_effects = true;
    return run;
}

/// The kit's linked-versions test: the mbedTLS and zlib versions the binary
/// links, asked of the linked code (tests/linked_libraries/versions_test.zig).
/// Built against the same mbedTLS artifact, headers and threading macros as
/// libcurl and WebCrypto. The root build runs it as one of its suites, where
/// the kit builds the library (never under -Dsystem-curl: there is no mbedTLS
/// artifact, and the versions are the system's).
pub const versions_test = struct {
    /// The test directory, recorded as a suite's.
    pub const dir = "tests/linked_libraries";
    /// Its suite's name.
    pub const suite = "tests-linked_libraries";
    /// The step that runs it alone.
    pub const step_name = "test-deps";
    pub const step_description = "Check the mbedTLS and zlib versions libcurl and WebCrypto link";

    /// The test's root module: built against `mbedtls_library` (the mbedTLS
    /// the kit's libcurl links, curl_build.zig StaticLibcurl.mbedtls), with
    /// its version header translated, and importing `fetch`, whose zlib it
    /// asks.
    pub fn module(b: *std.Build, target: std.Build.ResolvedTarget, prepare: ?PrepareC, mbedtls_library: *std.Build.Step.Compile, fetch: *std.Build.Module) *std.Build.Module {
        const deps_test_mod = b.createModule(.{
            .root_source_file = b.path("tests/linked_libraries/versions_test.zig"),
            .target = target,
            .imports = &.{.{ .name = "fetch", .module = fetch }},
        });
        deps_test_mod.linkLibrary(mbedtls_library);
        deps_test_mod.addImport("mbedtls_version_c", cImport(b, "mbedtls_version_c", target, prepare, .{ .includes = &.{"mbedtls/version.h"}, .libs = &.{mbedtls_library}, .macros = &mbedtls_threading_macros }));
        return deps_test_mod;
    }
};

/// The kit parts with no build file of their own: the words that name their
/// libraries. kit/sqlite's link is each platform adapter's declaration
/// (platform_build_protocol.zig KitPart).
const unbuilt_part_words = [_][]const u8{"sqlite"};

/// Every part's words, comma-separated: the library keys of `zig build
/// lint-build`, from the parts themselves - so the root build.zig spells no
/// library to look for one.
pub const lint_words: []const u8 = words: {
    var text: []const u8 = "";
    for ([_][]const []const u8{ &curl.words, &brotli.words, &image_codecs.words, &unbuilt_part_words }) |part| {
        for (part) |word| text = text ++ (if (text.len == 0) "" else ",") ++ word;
    }
    break :words text;
};

const testing = std.testing;

test "the lint's library keys are the kit parts' words, in the parts' order" {
    try testing.expectEqualStrings("curl,mbedtls,nghttp2,zlib,brotli,jpeg,expat,nanosvg,sqlite", lint_words);
}

test "libcurl keeps its own C sanitizer, off in every mode; every other kit library takes its build's" {
    try testing.expectEqual(@as(?std.zig.SanitizeC, .off), expectedSanitizer("curl"));
    for ([_][]const u8{ "mbedtls", "z", "nghttp2", "brotlicommon", "brotlidec", "brotlienc", "jpeg", "expat", "crane_image_codecs" }) |name| {
        try testing.expectEqual(@as(?std.zig.SanitizeC, null), expectedSanitizer(name));
    }
}

test "the linked-versions test is its directory's suite, named as the launcher names every tests/ directory's" {
    try testing.expect(std.mem.startsWith(u8, versions_test.dir, "tests/"));
    try testing.expectEqualStrings("tests-" ++ versions_test.dir["tests/".len..], versions_test.suite);
}

test "every translation of mbedTLS's headers sees the threading configuration curl_build compiles it with" {
    try testing.expectEqual(@as(usize, 2), mbedtls_threading_macros.len);
    try testing.expectEqualStrings("MBEDTLS_THREADING_C", mbedtls_threading_macros[0][0]);
    try testing.expectEqualStrings("MBEDTLS_THREADING_PTHREAD", mbedtls_threading_macros[1][0]);
}
