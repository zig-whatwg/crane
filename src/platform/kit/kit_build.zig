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
