//! The build side of kit/curl (src/platform/kit/kit_build.zig): the static
//! libcurl the kit's network and fetch link, with the mbedTLS, zlib and
//! nghttp2 it links, each compiled from the version build.zig.zon pins.
//! Moved whole from the root build.zig (build migration batch P2).
const std = @import("std");
const kit_build = @import("../kit_build.zig");
const brotli_build = @import("../brotli/brotli_build.zig");

/// The words that name this part's libraries: what `zig build lint-build`
/// looks for in the root build.zig (kit_build.lint_words).
pub const words = [_][]const u8{ "curl", "mbedtls", "nghttp2", "zlib" };

/// Find a library artifact by name from a dependency
/// This is needed because some packages (like curl) expose both .exe and .lib
/// with the same name, causing ambiguity with the standard artifact() method
fn findLibraryArtifact(dependency: *std.Build.Dependency, name: []const u8) ?*std.Build.Step.Compile {
    for (dependency.builder.install_tls.step.dependencies.items) |dep_step| {
        const inst = dep_step.cast(std.Build.Step.InstallArtifact) orelse continue;
        if (!std.mem.eql(u8, inst.artifact.name, name)) continue;
        if (inst.artifact.kind != .lib) continue;
        return inst.artifact;
    }
    return null;
}

/// The TLS library libcurl uses - chosen here and nowhere else. mbedTLS today.
/// HTTP/3 (ngtcp2 + nghttp3) needs a QUIC-capable TLS library - BoringSSL or
/// OpenSSL 3.5+ - so adding it means a new member here, the curl options
/// derived from this in buildStaticLibcurl, and the ALPN query in
/// src/fetch/network/curl_backend.zig (`negotiatedHttp2`), which knows each
/// backend's session type.
pub const TlsBackend = enum { mbedtls };
pub const tls_backend: TlsBackend = .mbedtls;

/// Configure statically-compiled libcurl for the fetch module
///
/// Compiles libcurl from source using allyourcodebase/curl package.
/// TLS provided by `tls_backend` (cross-platform, no system dependencies).
///
/// Features enabled:
/// - HTTP/HTTPS (with `tls_backend`)
/// - HTTP/2, through nghttp2 built from source (buildNghttp2), with
///   -Dhttp2 (the default)
/// - Compression (gzip via zlib, RFC 7932 Brotli unless compiled out)
///
/// Features disabled (minimize binary size):
/// - LDAP, LDAPS (not needed for Fetch)
/// - libpsl (Public Suffix List - URL module handles this)
/// - libssh2 (SSH/SCP/SFTP)
/// - libidn2 (IDN - URL module handles IDNA)
/// - zstd (additional compression)
/// - FTP, TFTP, Telnet, etc. (non-HTTP protocols)
///
/// Called once per C-library set: build() for the shared graph, and
/// runnerGraph for each runner graph whose C libraries differ from it
/// (runner_build_mode.RunnerModes.ownCLibraries). Every call compiles
/// libraries of its OWN - libcurl, mbedTLS, zlib and nghttp2, each a new
/// artifact (copyCLibrary, buildNghttp2) - in `optimize`, with `sanitize_c`
/// (null: Zig's default for the mode). The dependencies' own artifacts are
/// only read: Zig memoizes a dependency by its arguments, so two graphs in
/// one mode get ONE curl, ONE mbedTLS and ONE zlib artifact, and a setting
/// either graph wrote onto them would be both graphs' (lane buildfix1,
/// 2026-11-10: the bug-finding graph's `.full` overwrote the production
/// graph's `.trap` on mbedTLS and zlib; main's release console failed to link,
/// and generation 214's production runner carried the full sanitizer in them).
/// build() checks every build's linked C libraries against its modes at the
/// end of configuration (checkLinkedC).
///
/// `sanitize_c` is the C sanitizer of mbedTLS, zlib and nghttp2 (libcurl's own
/// sources keep theirs off, `libcurl_sanitize_c`, below).
pub fn buildStaticLibcurl(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    enable_http2: bool,
    sanitize_c: ?std.zig.SanitizeC,
    brotli: ?brotli_build.BrotliLibraries,
    prepare: ?kit_build.PrepareC,
) ?StaticLibcurl {
    // Get the curl dependency with appropriate options
    const curl_dep = b.lazyDependency("curl", .{
        .target = target,
        .optimize = optimize,
        // Static linking
        .linkage = .static,
        // TLS backend: `tls_backend` (cross-platform, no OpenSSL issues)
        .@"enable-ssl" = true,
        .@"use-openssl" = false,
        .@"use-mbedtls" = tls_backend == .mbedtls,
        .@"use-schannel" = false,
        .@"use-wolfssl" = false,
        .@"use-gnutls" = false,
        .@"use-rustls" = false,
        // The pinned Brotli build is linked below, not curl's dependency.
        .zlib = true,
        .brotli = false,
        .zstd = false,
        // Disable optional dependencies we don't need
        .libpsl = false, // URL module handles PSL
        .libssh2 = false, // No SSH/SCP/SFTP
        .libssh = false,
        .libidn2 = false, // URL module handles IDNA
        .@"apple-idn" = false,
        .@"win32-idn" = false,
        // Never curl's own: it links a SYSTEM libnghttp2. HTTP/2 comes from
        // buildNghttp2, below.
        .nghttp2 = false,
        .ares = false, // Use threaded resolver
        // Disable non-HTTP protocols
        .@"http-only" = true, // This disables FTP, TFTP, Telnet, etc.
        // No CA bundle or CA directory of curl's own: every TLS connection
        // verifies against Crane's trust store (src/platform/kit/curl/
        // trust.zig - the system roots parsed once per process, with a
        // Browser's extra anchors), which kit/curl's options attach to each
        // handle. "auto", the default, made a native build read the build
        // machine at configure time and compile what it found in: on Linux
        // CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt AND
        // CURL_CA_PATH=/etc/ssl/certs, which curl's mbedTLS backend parses
        // again in every connection's first step (lib/vtls/mbedtls.c
        // mbed_connect_step1: mbedtls_x509_crt_parse_path) - ~100 ms of CPU
        // per HTTPS connection on server1 (lane linux1); on macOS
        // /etc/ssl/cert.pem.
        .@"ca-bundle" = @as([]const u8, "none"),
        .@"ca-path" = @as([]const u8, "none"),
    }) orelse return null; // Lazy dependency not available

    // The curl package declares both a "curl" exe and a "curl" library: its
    // library is the recipe this call's own libcurl is compiled from, in
    // `optimize` with libcurl's own sanitizer (below).
    const libcurl = copyCLibrary(b, findLibraryArtifact(curl_dep, "curl") orelse return null, optimize, libcurl_sanitize_c);
    // "none" above is what upstream curl's CMake takes as "no CA file / no CA
    // directory" (CMakeLists.txt: unset when "none"), but allyourcodebase/curl
    // (5184bb9ff2) writes it into curl_config.h as the PATH "none"
    // (`.CURL_CA_BUNDLE = if (eql(ca_bundle, "auto")) null else ca_bundle`):
    // every connection then failed to read a CA file named "none"
    // (CURLE_SSL_CACERT_BADFILE). Both are left undefined in the header, as
    // CMake leaves them; tests/fetch/trust_store_test.zig pins that curl names
    // neither (CURLINFO_CAINFO, CURLINFO_CAPATH). The header is this libcurl's
    // own copy (copyCLibrary), so the recipe's stays as curl's build wrote it.
    undefineConfigHeaderValue(libcurl.root_module, "curl_config.h", "CURL_CA_BUNDLE");
    undefineConfigHeaderValue(libcurl.root_module, "curl_config.h", "CURL_CA_PATH");

    // mbedTLS and zlib: the versions build.zig.zon pins, not the curl package's.
    //
    // allyourcodebase/curl at c59c65cd - its newest commit; no newer pin exists -
    // pins mbedTLS 3.6.4 and zlib 1.3.1 in its own build.zig.zon and links them
    // with `linkLibrary(dependency.artifact("mbedtls"))` and `("z")`. mbedTLS
    // 3.6.5 and 3.6.6 are security releases. Zig 0.16's package manager cannot
    // override a transitive pin from build.zig.zon (`zig build --fork=<path>` is a
    // command-line override with a local checkout, not a pin), so the override
    // happens here, in the build graph: root's own `.mbedtls` and `.zlib` are
    // built with the arguments curl passes, and libcurl's link entries for curl's
    // copies are pointed at them. Nothing else reaches curl's copies: they are
    // fetched (curl's build asks for them) but never compiled or linked.
    // Root's are recipes too: this call compiles its own of each, in its mode
    // and with its sanitizer (copyCLibrary), and never writes to the
    // dependency's artifact, which every graph in this mode is given.
    // tests/linked_libraries/versions_test.zig asks the linked code which versions it
    // is, and replaceLinkedLibrary fails the build if a curl bump links either
    // library some other way.
    //
    // `.threading = true` is what curl requests (`!(single_threaded orelse
    // false)`, and Crane never sets single-threaded); see MBEDTLS_THREADING_C below.
    const mbedtls_dep = b.lazyDependency("mbedtls", .{
        .target = target,
        .optimize = optimize,
        .threading = true,
    }) orelse return null;
    const zlib_dep = b.lazyDependency("zlib", .{
        .target = target,
        .optimize = optimize,
    }) orelse return null;
    const mbedtls = copyCLibrary(b, mbedtls_dep.artifact("mbedtls"), optimize, sanitize_c);
    const zlib = copyCLibrary(b, zlib_dep.artifact("z"), optimize, sanitize_c);
    replaceLinkedLibrary(libcurl, "mbedtls", mbedtls);
    replaceLinkedLibrary(libcurl, "z", zlib);
    // curl's build passes the version IT pins as MBEDTLS_VERSION - a CMake
    // variable in upstream curl that no C source of curl or mbedTLS reads. Drop it
    // rather than leave a false "3.6.4" on every libcurl compile line.
    removeCMacro(libcurl.root_module, "MBEDTLS_VERSION");

    // Turn Zig's C UBSan OFF for libcurl's own sources.
    //
    // curl 8.18.0 reads `static bool init_ssl` in Curl_ssl_cleanup (lib/vtls/vtls.c
    // :1042) after curl_global_init wrote it, and the byte is not 0 or 1 - so the
    // -fsanitize=undefined bool check Zig inserts in Debug aborts the process. It is
    // reproducible with nothing but globalInit() followed by globalCleanup(), so it is
    // entirely inside libcurl; bisected against mbedTLS 3.6.4 vs 3.6.6 (identical) and
    // against every Crane-side change in the 0.16 migration.
    //
    // The value is truthy, so `if(init_ssl)` takes the branch TRUE would have taken and
    // the library behaves correctly - `zig build test -Doptimize=ReleaseFast`, where the
    // check is absent, passes every one of these tests. The defect is real C UB but it
    // is upstream's, in a content-hash-pinned dependency we cannot patch from here.
    //
    // This disables the sanitizer for libcurl ONLY (`libcurl_sanitize_c`, given to
    // copyCLibrary above). Every Zig module in Crane keeps its full safety checks.
    // Revisit when a curl release fixes it upstream.

    // HTTP/2: nghttp2 built here from its pinned release and linked into
    // libcurl (curl's `nghttp2` option above stays off).
    //
    // This leans on how allyourcodebase/curl (pinned at c59c65cd) builds: it
    // compiles http2.c and cf-h2-proxy.c unconditionally and gates them on
    // USE_NGHTTP2 from a cmake-style config header, whose `#cmakedefine`
    // leaves the macro undefined, not #undef'd, when its option is off - so
    // defining it here turns them on. Whoever bumps curl re-checks that;
    // `fetch`'s test "libcurl speaks HTTP/2 when the build asked for it"
    // fails if HTTP/2 goes missing.
    if (enable_http2) {
        if (buildNghttp2(b, target, optimize, sanitize_c)) |nghttp2| {
            libcurl.root_module.addCMacro("USE_NGHTTP2", "1");
            libcurl.root_module.addCMacro("NGHTTP2_STATICLIB", "1");
            libcurl.root_module.linkLibrary(nghttp2);
        }
    }

    // Use the same pinned decoder as the platform's Compression Streams codec.
    // The dependency's option stays off to avoid its transitive Brotli pin.
    if (brotli) |codec| {
        libcurl.root_module.addCMacro("HAVE_BROTLI", "1");
        libcurl.root_module.linkLibrary(codec.decoder);
    }

    // The mbedTLS package compiles the LIBRARY with these two macros (its
    // build.zig:30-33, under the `threading` option passed above; the same lines
    // in the 3.6.4 and 3.6.6 packages) but does not propagate them to anything
    // that includes the installed headers. MBEDTLS_THREADING_C appends a
    // `mbedtls_threading_mutex_t mutex` to mbedtls_entropy_context and
    // mbedtls_ctr_drbg_context, so the two translation units disagree (aarch64
    // macOS, measured on 3.6.4 and again on 3.6.6 - identical):
    //
    //     libmbedtls.a  (macros on)   entropy_ctx 904   ctr_drbg_ctx 416
    //     libcurl       (macros off)  entropy_ctx 832   ctr_drbg_ctx 344
    //
    // curl sizes its context with the short view, mbedtls_entropy_init writes
    // the mutex 72 bytes past the end of it, a neighbour clears mutex.is_valid,
    // and at connect time mbedtls_entropy_func fails the mutex lock and returns
    // WITHOUT POLLING ANY ENTROPY SOURCE. mbedtls_ctr_drbg_seed then reports
    // -0x0034 CTR_DRBG_ENTROPY_SOURCE_FAILED, surfacing as CURLE_SSL_CONNECT_ERROR.
    //
    // Every `.https.` WPT test failed on this: 0 of 192 produced a single
    // subtest result, 157 of them inside the 0.1 worklist. It presented as a
    // 10-second timeout rather than an error because a network-error response
    // carries no headers, so src/browser/navigation.zig:312 defaults the
    // content type to text/html and parses an empty document as a successful
    // page load.
    if (tls_backend == .mbedtls) {
        libcurl.root_module.addCMacro("MBEDTLS_THREADING_C", "");
        libcurl.root_module.addCMacro("MBEDTLS_THREADING_PTHREAD", "");
    }

    // The target's C preparation (iOS: the SDK paths) has to reach the
    // DEPENDENCY's modules too, not just ours. zlib and mbedtls are artifacts
    // of their own (root's, linked into libcurl above), which the preparation's
    // `graph` reaches through libcurl's link objects; pointing only the
    // top-level module at the SDK left them failing on <stdio.h> and
    // <string.h> - 15 errors and 107 respectively, which read like broken
    // dependencies rather than an unresolved SDK.
    if (prepare) |p| p.graph(&libcurl.step);

    // The mbedTLS libcurl links, for WebCrypto: one library, one PSA key store.
    return .{ .libcurl = libcurl, .mbedtls = mbedtls };
}

/// libcurl's own C sanitizer, in every mode: off (buildStaticLibcurl says
/// why). checkLinkedC holds libcurl to it.
pub const libcurl_sanitize_c: std.zig.SanitizeC = .off;

/// A C library of the calling graph's own, compiled from `recipe` - a static
/// library a dependency's build.zig declares - in `optimize` with `sanitize_c`
/// (null: Zig's default for the mode).
///
/// Zig memoizes a dependency by its arguments, so every graph that asks for
/// curl, mbedTLS or zlib with the same target and mode is given the SAME
/// artifact, and whatever one graph writes onto it is every graph's. None of
/// the three packages declares an option for the C sanitizer (allyourcodebase/
/// mbedtls 3.6.6 declares `threading`, zlib 1.3.2 `pie`, curl none for it), so
/// no honest argument tells two instances apart. The dependency's artifact is
/// therefore a recipe that is only read - never built, never written: the copy
/// takes its root module whole (its C sources and their flags, its macros,
/// include directories, link entries, system libraries and frameworks, and
/// every other setting) with its own mode and sanitizer, a config header of
/// its own (so an edit to it stays this copy's), and the recipe's installed
/// headers, and is a new artifact. The configuration fails here if the
/// recipe is anything but a static C library, or carries a link entry a copy
/// cannot take.
fn copyCLibrary(b: *std.Build, recipe: *std.Build.Step.Compile, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC) *std.Build.Step.Compile {
    const from = recipe.root_module;
    if (recipe.kind != .lib or recipe.linkage != .static or from.root_source_file != null or from.import_table.count() != 0) {
        std.debug.panic("{s} is not a static C library; re-check copyCLibrary", .{recipe.name});
    }
    const gpa = b.allocator;
    const module = gpa.create(std.Build.Module) catch @panic("OOM");
    module.init(b, .{ .existing = from });
    module.owner = b;
    module.optimize = optimize;
    module.sanitize_c = sanitize_c;
    module.cached_graph = .{ .modules = &.{}, .names = &.{} };
    module.import_table = .empty;
    module.c_macros = from.c_macros.clone(gpa) catch @panic("OOM");
    module.include_dirs = from.include_dirs.clone(gpa) catch @panic("OOM");
    module.lib_paths = from.lib_paths.clone(gpa) catch @panic("OOM");
    module.rpaths = from.rpaths.clone(gpa) catch @panic("OOM");
    module.frameworks = from.frameworks.clone(gpa) catch @panic("OOM");
    module.link_objects = from.link_objects.clone(gpa) catch @panic("OOM");
    for (module.include_dirs.items) |*dir| switch (dir.*) {
        .config_header_step => |header| dir.* = .{ .config_header_step = copyConfigHeader(b, header) },
        else => {},
    };
    for (module.link_objects.items) |object| switch (object) {
        .c_source_files, .c_source_file, .assembly_file, .static_path, .other_step, .system_lib => {},
        .win32_resource_file => std.debug.panic("{s} compiles a Win32 resource; re-check copyCLibrary", .{recipe.name}),
    };
    const lib = b.addLibrary(.{ .name = recipe.name, .linkage = .static, .root_module = module, .version = recipe.version });
    lib.installLibraryHeaders(recipe);
    return lib;
}

/// A config header of its own with `original`'s template and values
/// (copyCLibrary).
fn copyConfigHeader(b: *std.Build, original: *std.Build.Step.ConfigHeader) *std.Build.Step.ConfigHeader {
    if (original.include_guard != .none) std.debug.panic("{s} has an include guard; re-check copyConfigHeader", .{original.include_path});
    const copy = std.Build.Step.ConfigHeader.create(b, .{
        .style = original.style,
        .max_bytes = original.input_size_limit,
        .include_path = original.include_path,
    });
    copy.values = original.values.clone(b.allocator) catch @panic("OOM");
    return copy;
}

/// libcurl and the mbedTLS it links, built by buildStaticLibcurl for one
/// C-library set.
pub const StaticLibcurl = struct {
    libcurl: *std.Build.Step.Compile,
    mbedtls: *std.Build.Step.Compile,
};

/// Link the static libcurl into `module` (one module graph's fetch).
pub fn linkStaticLibcurl(
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    libcurl: *std.Build.Step.Compile,
    prepare: ?kit_build.PrepareC,
) void {
    // The importing module is prepared for the target's C too (its curl_c
    // translation gets the same from the C-header translation).
    if (prepare) |p| p.module(module);

    // Link the static library to the module
    module.linkLibrary(libcurl);

    // Required macro for static linking
    module.addCMacro("CURL_STATICLIB", "1");

    // Platform-specific system libraries required by curl
    const os = target.result.os.tag;
    if (os == .windows) {
        // Windows: Winsock2 and crypto libraries
        module.linkSystemLibrary("ws2_32", .{});
        module.linkSystemLibrary("bcrypt", .{});
        module.linkSystemLibrary("advapi32", .{});
        module.linkSystemLibrary("crypt32", .{});
    } else if (os == .linux) {
        // Linux: pthread for threaded resolver
        module.linkSystemLibrary("pthread", .{});
    }
    // macOS: No additional libraries needed with mbedTLS
}

/// Point `library` at `replacement` wherever it links the artifact named `name`:
/// its link object (what the linker reads) and its include directory (the
/// installed headers its C sources compile against) - the two entries
/// `Module.linkLibrary` appends. The build runner derives step dependencies
/// from these entries (createModuleDependenciesForStep), so the original
/// artifact is then unreachable and never built.
///
/// Panics unless exactly one of each was replaced: a dependency that links the
/// library some other way must fail the build here, not quietly link its own pin.
fn replaceLinkedLibrary(library: *std.Build.Step.Compile, name: []const u8, replacement: *std.Build.Step.Compile) void {
    var links: usize = 0;
    for (library.root_module.link_objects.items) |*object| switch (object.*) {
        .other_step => |other| if (std.mem.eql(u8, other.name, name)) {
            object.* = .{ .other_step = replacement };
            links += 1;
        },
        else => {},
    };
    var includes: usize = 0;
    for (library.root_module.include_dirs.items) |*dir| switch (dir.*) {
        .other_step => |other| if (std.mem.eql(u8, other.name, name)) {
            dir.* = .{ .other_step = replacement };
            includes += 1;
        },
        else => {},
    };
    if (links != 1 or includes != 1) std.debug.panic(
        "{s} links {d} artifact(s) and {d} header tree(s) named '{s}', expected one of each; " ++
            "the dependency changed how it links '{s}' - re-check buildStaticLibcurl",
        .{ library.name, links, includes, name, name },
    );
    // What Module.linkLibrary records too: the build needs the binary.
    _ = replacement.getEmittedBin();
}

/// Remove every `-D<name>=...` from `module`'s C macros.
/// Leaves `name` undefined in `module`'s config header `include_path` (a
/// ConfigHeader step a dependency made): for a value the dependency's build
/// writes where its upstream leaves it unset. The build fails if the header or
/// the value is not there, so a dependency bump that renames them is seen.
fn undefineConfigHeaderValue(module: *std.Build.Module, include_path: []const u8, name: []const u8) void {
    for (module.include_dirs.items) |dir| switch (dir) {
        .config_header_step => |header| if (std.mem.eql(u8, header.include_path, include_path)) {
            const value = header.values.getPtr(name) orelse std.debug.panic("{s} has no {s}", .{ include_path, name });
            value.* = .undef;
            return;
        },
        else => {},
    };
    std.debug.panic("no config header {s} in the module", .{include_path});
}

fn removeCMacro(module: *std.Build.Module, name: []const u8) void {
    const prefix = module.owner.fmt("-D{s}=", .{name});
    var i: usize = 0;
    while (i < module.c_macros.items.len) {
        if (std.mem.startsWith(u8, module.c_macros.items[i], prefix)) {
            _ = module.c_macros.orderedRemove(i);
        } else i += 1;
    }
}

/// nghttp2 - the HTTP/2 library libcurl speaks HTTP/2 through - compiled from
/// its release tarball (build.zig.zon `nghttp2`, pinned by hash), never a
/// system library. Only lib/ is built, as upstream's --enable-lib-only does:
/// lib/CMakeLists.txt's NGHTTP2_SOURCES and definitions.
fn buildNghttp2(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC) ?*std.Build.Step.Compile {
    const upstream = b.lazyDependency("nghttp2", .{}) orelse return null;
    const version_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("lib/includes/nghttp2/nghttp2ver.h.in") },
        .include_path = "nghttp2/nghttp2ver.h",
    }, .{
        .PACKAGE_VERSION = "1.70.0",
        .PACKAGE_VERSION_NUM = 0x014600,
    });
    const lib = b.addLibrary(.{
        .name = "nghttp2",
        .linkage = .static,
        .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = sanitize_c }),
    });
    lib.root_module.addIncludePath(upstream.path("lib/includes"));
    lib.root_module.addConfigHeader(version_h);
    lib.root_module.addCMacro("BUILDING_NGHTTP2", "1");
    lib.root_module.addCMacro("NGHTTP2_STATICLIB", "1");
    // What upstream's configure finds on a POSIX system (there is no
    // config.h: nothing defines HAVE_CONFIG_H).
    lib.root_module.addCMacro("HAVE_ARPA_INET_H", "1");
    lib.root_module.addCMacro("HAVE_NETINET_IN_H", "1");
    lib.root_module.addCMacro("HAVE_CLOCK_GETTIME", "1");
    lib.root_module.addCMacro("HAVE_DECL_CLOCK_MONOTONIC", "1");
    lib.root_module.addCSourceFiles(.{ .root = upstream.path("lib"), .files = &nghttp2_sources });
    lib.installHeadersDirectory(upstream.path("lib/includes/nghttp2"), "nghttp2", .{});
    lib.installConfigHeader(version_h);
    return lib;
}

const nghttp2_sources = [_][]const u8{
    "nghttp2_pq.c",            "nghttp2_map.c",             "nghttp2_queue.c",
    "nghttp2_frame.c",         "nghttp2_buf.c",             "nghttp2_stream.c",
    "nghttp2_outbound_item.c", "nghttp2_session.c",         "nghttp2_submit.c",
    "nghttp2_helper.c",        "nghttp2_alpn.c",            "nghttp2_hd.c",
    "nghttp2_hd_huffman.c",    "nghttp2_hd_huffman_data.c", "nghttp2_version.c",
    "nghttp2_priority_spec.c", "nghttp2_option.c",          "nghttp2_callbacks.c",
    "nghttp2_mem.c",           "nghttp2_http.c",            "nghttp2_rcbuf.c",
    "nghttp2_extpri.c",        "nghttp2_ratelim.c",         "nghttp2_time.c",
    "nghttp2_debug.c",         "sfparse.c",
};
