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

/// -Dsystem-curl: the kit's system-library option, by name, and as a
/// command-line flag (the root build's check-configure-cache configures with
/// it).
const system_library_option = "system-curl";
pub const system_library_flag = "-D" ++ system_library_option;

/// The import name under which `fetch` reaches the kit's network connection
/// share (kit/curl/share.zig) until transfers move behind the platform's
/// port; the tests that reach it import it under the same name.
pub const network_share_import = "kit_curl_share";

/// One module graph's C libraries, as the kit builds them for it
/// (`libraries`): each graph's own artifacts, in its mode and C sanitizer
/// (curl/curl_build.zig copyCLibrary says why they are never shared).
pub const Libraries = struct {
    brotli: ?brotli.BrotliLibraries,
    image_codecs: ?*std.Build.Step.Compile,
    /// The kit's libcurl and the mbedTLS it links; null with the system
    /// library (Options.system_library) or when the lazy dependencies are
    /// not fetched yet.
    static_libcurl: ?curl.StaticLibcurl,

    /// The TLS library the kit's libcurl links - which WebCrypto and the
    /// trust store share and the linked-versions test asks - or null.
    pub fn linkedTls(self: Libraries) ?*std.Build.Step.Compile {
        return if (self.static_libcurl) |static| static.mbedtls else null;
    }
};

/// What `libraries` is asked to build.
pub const LibrariesRequest = struct {
    options: Options,
    /// -Dplatform-without: libcurl links the Brotli decoder unless the
    /// `brotli` capability is compiled out.
    without: []const []const u8,
    /// Also make the step that installs the image codecs for any target
    /// (`platform-image-codecs`): the shared graph's libraries only.
    image_codecs_step: bool = false,
};

/// A graph's C libraries for `target`, in `mode` with `sanitize_c` (null:
/// Zig's default for the mode), prepared for the target's C: Brotli, the
/// image codecs and libcurl with its mbedTLS, zlib and nghttp2, in that
/// order - every call builds artifacts of its own.
pub fn libraries(b: *std.Build, target: std.Build.ResolvedTarget, mode: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC, prepare: ?PrepareC, request: LibrariesRequest) Libraries {
    const brotli_libraries = brotli.buildBrotli(b, target, mode, sanitize_c, prepare);
    const codecs = image_codecs.buildImageCodecs(b, target, mode, sanitize_c, prepare);
    if (request.image_codecs_step) {
        const image_codecs_step = b.step("platform-image-codecs", "Build the testing JPEG/SVG libraries (also for cross targets)");
        if (codecs) |library| image_codecs_step.dependOn(&b.addInstallArtifact(library, .{}).step);
    }
    const brotli_enabled = for (request.without) |name| {
        if (std.mem.eql(u8, name, "brotli")) break false;
    } else true;
    const static_libcurl: ?curl.StaticLibcurl = if (request.options.system_library) null else curl.buildStaticLibcurl(b, target, mode, request.options.http2, sanitize_c, if (brotli_enabled) brotli_libraries else null, prepare);
    return .{ .brotli = brotli_libraries, .image_codecs = codecs, .static_libcurl = static_libcurl };
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
        system_library_option,
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

/// What the kit's modules are made with for one platform binding (the
/// platform protocol's `binding`).
pub const ModulesRequest = struct {
    /// The binding's facade (`platform`), its options (`platform_options`)
    /// and its bound implementation, which imports each part as
    /// `kit_<name>`.
    facade: *std.Build.Module,
    options: *std.Build.Module,
    impl: *std.Build.Module,
    /// -Dplatform-without: a codec compiled out links nothing.
    without: []const []const u8,
    /// The C libraries this binding's graph built (`libraries`). The
    /// mbedTLS libcurl links (`Libraries.linkedTls`): kit/curl's trust store
    /// parses certificates with it and hands curl's TLS configuration the
    /// chain; null with a system libcurl, whose TLS library is its own.
    libraries: Libraries,
    /// Today's bridges, which kit/posix wraps, and MIME Sniffing's parser,
    /// which kit/media_decoding parses a type with.
    clock: *std.Build.Module,
    host: *std.Build.Module,
    memory: *std.Build.Module,
    mimesniff: *std.Build.Module,
};

/// The modules of the kit a binding hands on to what imports it.
pub const Modules = struct {
    /// kit/curl's connection share (src/platform/kit/curl/share.zig), which
    /// `fetch` imports for a Browser's network context until transfers move
    /// behind the platform's port: a module of its own that imports nothing.
    kit_curl_share: *std.Build.Module,
    /// kit/sfnt, kit/inflate and kit/media_decoding, whose own test blocks
    /// the platform tests run.
    kit_sfnt: *std.Build.Module,
    kit_inflate: *std.Build.Module,
    kit_media_decoding: *std.Build.Module,
    /// <time.h> translated (`cImport`), which kit/posix imports as `c_time`;
    /// tests/platform takes the same module (one per header set per graph).
    c_time: *std.Build.Module,
};

/// The kit's modules for one binding: one module per part, imported by the
/// bound implementation, each linked against and given the C headers of the
/// libraries this binding's graph built, prepared for the target's C
/// (`prepare`). Moved whole from the root build's platformBinding (build
/// migration batch P3).
pub fn modules(b: *std.Build, target: std.Build.ResolvedTarget, prepare: ?PrepareC, request: ModulesRequest) Modules {
    // The kit: one module per part, each importing the facade for its types;
    // any platform, built-in or third-party, may import any of them.
    const brotli_enabled = for (request.without) |name| {
        if (std.mem.eql(u8, name, "brotli")) break false;
    } else true;
    const font_decoding_enabled = for (request.without) |name| {
        if (std.mem.eql(u8, name, "font_decoding")) break false;
    } else true;
    const kit_parts = [_][]const u8{ "posix", "headless", "memory_store", "curl", "crypto", "memory_clipboard", "browser_state", "brotli", "image_codecs", "inflate", "sfnt", "image_decoding", "media_decoding", "image_encoding" };
    var kit_modules: [kit_parts.len]*std.Build.Module = undefined;
    for (kit_parts, 0..) |part, i| {
        kit_modules[i] = b.createModule(.{
            .root_source_file = b.path(b.fmt("src/platform/kit/{s}/root.zig", .{part})),
            .target = target,
            .link_libc = true,
        });
        kit_modules[i].addImport("platform", request.facade);
        kit_modules[i].addImport("platform_options", request.options);
        // A disabled codec does not import its C headers or link its libraries,
        // even when the conformance test compiles every adapter operation.
        request.impl.addImport(b.fmt("kit_{s}", .{part}), if (i == 7 and !brotli_enabled) kit_modules[1] else kit_modules[i]);
    }
    // font_decoding brings the Brotli decoder WOFF2 needs whether or not the
    // `brotli` capability is compiled in (decision 20, Q3): kit/sfnt reaches
    // kit/brotli by its own import, which only a font decode calls.
    if (brotli_enabled or font_decoding_enabled) if (request.libraries.brotli) |codec| {
        kit_modules[7].linkLibrary(codec.decoder);
        kit_modules[7].linkLibrary(codec.encoder);
        kit_modules[7].addImport("brotli_c", cImport(b, "brotli_c", target, prepare, .{ .includes = &.{ "brotli/decode.h", "brotli/encode.h" }, .libs = &.{ codec.decoder, codec.encoder } }));
    };
    // kit/sfnt (decision 20): WOFF through kit/inflate, WOFF2 through
    // kit/brotli - headless's NotSupported when no Brotli library is built.
    kit_modules[10].addImport("kit_inflate", kit_modules[9]);
    kit_modules[10].addImport("kit_brotli", if (request.libraries.brotli != null) kit_modules[7] else kit_modules[1]);
    // kit/image_decoding (D1, the user 2026-11-09): every built-in platform's
    // image decoders - PNG through kit/inflate, JPEG and SVG through
    // kit/image_codecs. Found by name, so a part appended after it keeps it.
    const image_decoding_part = comptime for (kit_parts, 0..) |part, i| {
        if (std.mem.eql(u8, part, "image_decoding")) break i;
    } else unreachable;
    const kit_image_decoding = kit_modules[image_decoding_part];
    kit_image_decoding.addImport("kit_inflate", kit_modules[9]);
    kit_image_decoding.addImport("kit_image_codecs", kit_modules[8]);
    // kit/media_decoding (lane wptcfg D4, the user 2026-11-09): the media
    // decoders darwin, linux and testing build in - WAV linear PCM - its
    // canPlayType parsing with MIME Sniffing's parser. Found by name too.
    const media_decoding_part = comptime for (kit_parts, 0..) |part, i| {
        if (std.mem.eql(u8, part, "media_decoding")) break i;
    } else unreachable;
    const kit_media_decoding = kit_modules[media_decoding_part];
    kit_media_decoding.addImport("mimesniff", request.mimesniff);
    if (request.libraries.image_codecs) |codecs| {
        kit_modules[8].linkLibrary(codecs);
        kit_modules[8].addImport("image_codecs_c", cImport(b, "image_codecs_c", target, prepare, .{ .includes = &.{"image_codecs.h"}, .libs = &.{codecs} }));
    }
    if (prepare) |p| {
        p.module(kit_modules[7]);
        p.module(kit_modules[8]);
    }
    // kit/posix wraps today's clock, process Io and resident-memory bridges.
    kit_modules[0].addImport("clock", request.clock);
    kit_modules[0].addImport("host", request.host);
    kit_modules[0].addImport("memory", request.memory);
    // and reads the local time zone through <time.h> (localtime_r, tzset).
    const c_time = cImport(b, "c_time", target, prepare, .{ .includes = &.{"time.h"} });
    kit_modules[0].addImport("c_time", c_time);
    // kit/browser_state keeps a Browser's stores in kit/memory_store.
    kit_modules[6].addImport("kit_memory_store", kit_modules[2]);
    // kit/curl's connection share, its own module (see Modules).
    const kit_curl_share = b.createModule(.{
        .root_source_file = b.path("src/platform/kit/curl/share.zig"),
        .target = target,
        .link_libc = true,
    });
    kit_modules[3].addImport("kit_curl_share", kit_curl_share);
    // Its trust store (trust.zig) parses with libcurl's own mbedTLS, when
    // libcurl is the bundled one; a system libcurl keeps its own CA loading.
    const kit_curl_options = b.addOptions();
    kit_curl_options.addOption(bool, "mbedtls_trust_store", request.libraries.linkedTls() != null);
    kit_curl_share.addOptions("kit_curl_options", kit_curl_options);
    if (request.libraries.linkedTls()) |mbedtls| {
        kit_curl_share.linkLibrary(mbedtls);
        kit_curl_share.addImport("mbedtls_c", cImport(b, "mbedtls_trust_c", target, prepare, .{
            .includes = &.{ "mbedtls/x509_crt.h", "mbedtls/ssl.h", "psa/crypto.h" },
            .libs = &.{mbedtls},
            .macros = &mbedtls_threading_macros,
        }));
        if (prepare) |p| p.module(kit_curl_share);
    }
    // kit/curl/websocket.zig's header set (curl.h, websockets.h, header.h) is
    // its own module: fetch's curl_ffi translates curl.h alone, as the two
    // @cImports did.
    const kit_curl_includes: []const []const u8 = &.{ "curl/curl.h", "curl/websockets.h", "curl/header.h" };
    if (request.libraries.static_libcurl) |static| {
        const libcurl = static.libcurl;
        curl.linkStaticLibcurl(kit_modules[3], target, libcurl, prepare);
        kit_modules[3].addImport("curl_c", cImport(b, "curl_c", target, prepare, .{ .includes = kit_curl_includes, .libs = &.{libcurl}, .macros = &.{.{ "CURL_STATICLIB", "1" }} }));
    } else {
        kit_modules[3].linkSystemLibrary("curl", .{});
        kit_modules[3].addImport("curl_c", cImport(b, "curl_c", target, prepare, .{ .includes = kit_curl_includes, .system_libs = &.{"curl"} }));
    }
    return .{ .kit_curl_share = kit_curl_share, .kit_sfnt = kit_modules[10], .kit_inflate = kit_modules[9], .kit_media_decoding = kit_media_decoding, .c_time = c_time };
}

/// TRANSITIONAL (design question 7): what two Crane modules outside the
/// platform still link of the kit's libraries directly, because their code
/// has not moved behind the platform protocol yet. Each entry names the step
/// of docs/platform-protocol-recipes.md that retires it:
///   * fetch's libcurl (system or static) and its `curl_c` header module,
///     and its `curl_options` - recipes step 2a, "Move libcurl behind the
///     protocol";
///   * WebCrypto's mbedTLS and its `mbedtls_c` header module, and its
///     `options` - recipes step 5, the crypto primitives (decision 11).
pub const TransitionalLinks = struct {
    fetch: *std.Build.Module,
    webcrypto: *std.Build.Module,
    /// The kit's options (-Dsystem-curl, -Dhttp2).
    options: Options,
    /// The C libraries the kit built for this graph.
    libraries: Libraries,
};

/// fetch's own options module for its network layer (TRANSITIONAL, see
/// TransitionalLinks): the network layer asks the vendored TLS library what
/// ALPN chose, and tests that HTTP/2 is live when the build asked for it.
/// Its own options module: one options file imported as a module by two
/// others in the same compilation is an error ("file exists in modules"),
/// and build_options already is, by the engine adapter's module. Made where
/// the root build adds fetch's imports, in their order.
pub fn addFetchOptions(b: *std.Build, links: TransitionalLinks) void {
    const curl_options = b.addOptions();
    curl_options.addOption(bool, "http2", links.options.http2 and !links.options.system_library);
    curl_options.addOption(bool, "mbedtls", curl.tls_backend == .mbedtls and !links.options.system_library);
    links.fetch.addOptions("curl_options", curl_options);
}

/// fetch's and WebCrypto's links to the kit's libraries (TRANSITIONAL, see
/// TransitionalLinks), prepared for the target's C (`prepare`).
pub fn linkTransitional(b: *std.Build, target: std.Build.ResolvedTarget, prepare: ?PrepareC, links: TransitionalLinks) void {
    const fetch_mod = links.fetch;
    const webcrypto_mod = links.webcrypto;
    // Configure libcurl for network requests
    if (links.options.system_library) {
        // Development: Use system libcurl for faster builds
        fetch_mod.linkSystemLibrary("curl", .{});
        fetch_mod.addImport("curl_c", cImport(b, "curl_c", target, prepare, .{ .includes = &.{"curl/curl.h"}, .system_libs = &.{"curl"} }));
    } else if (links.libraries.static_libcurl) |static| {
        // Production: the statically compiled libcurl with mbedTLS
        curl.linkStaticLibcurl(fetch_mod, target, static.libcurl, prepare);
        fetch_mod.addImport("curl_c", cImport(b, "curl_c", target, prepare, .{ .includes = &.{"curl/curl.h"}, .libs = &.{static.libcurl}, .macros = &.{.{ "CURL_STATICLIB", "1" }} }));
    }
    const linked_mbedtls = links.libraries.linkedTls();

    // WebCrypto shares curl's exact mbedTLS artifact - build.zig.zon's
    // `.mbedtls`, which buildStaticLibcurl links into libcurl - including its
    // installed headers, translated with the library's threading macros.
    if (linked_mbedtls) |library| {
        webcrypto_mod.linkLibrary(library);
        webcrypto_mod.addImport("mbedtls_c", cImport(b, "mbedtls_c", target, prepare, .{
            .includes = &.{ "psa/crypto.h", "mbedtls/nist_kw.h", "mbedtls/rsa.h", "mbedtls/pk.h" },
            .libs = &.{library},
            .macros = &mbedtls_threading_macros,
        }));
    }
    const webcrypto_options = b.addOptions();
    webcrypto_options.addOption(bool, "mbedtls", curl.tls_backend == .mbedtls and !links.options.system_library);
    webcrypto_mod.addOptions("options", webcrypto_options);
    if (prepare) |p| p.module(webcrypto_mod);
}

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
