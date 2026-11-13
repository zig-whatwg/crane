const std = @import("std");
/// The WPT runner's optimize modes (root, Crane's modules, C libraries),
/// std-only and pinned by `zig build test`.
const runner_build_mode = @import("tests/wpt_runner/build_mode.zig");
/// Which tests/<dir>/ directories hold tests no suite runs, std-only and
/// pinned by `zig build test` (`checkEveryTestDirectoryIsASuite`).
const test_suites = @import("tools/test_suites.zig");
/// Which V8 archives -Dv8-build and the target select (out/static,
/// out/official, out/ios-arm64), std-only and pinned by `zig build test`
/// (tools-v8_archives).
const v8_archives = @import("tools/v8_archives.zig");

/// THE BUILD SIDE OF THE ENGINE PROTOCOL (docs/engine-protocol.md, 7b): an engine adapter's build options are
/// declared by the adapter, in its own build file, never here (the user, 2026-11-12: "the valid flags should be in
/// the js engine protocol"). The protocol's build file lists the adapters and asks the chosen one; this file names
/// no adapter and no adapter's option.
const engine_build = @import("src/runtime/engine_build_protocol.zig");

// Crane builds with a Zig from the 0.17.x branch pinned at 77c319a0f00a
// (0.17.1-dev+77c319a0f0) until 0.17.1 ships. Zig 0.17.0 itself cannot build
// aarch64-ios (ziglang/zig#37061) and its checkAllAllocationFailures lets
// resizes reach SafeAllocator, so tests fail with NondeterministicMemoryUsage
// (ziglang/zig#37142). build.zig.zon's minimum_zig_version is not enforced.
comptime {
    const v = @import("builtin").zig_version;
    if (v.major == 0 and v.minor == 17 and v.patch == 0) @compileError("Crane does not build with Zig 0.17.0 (ziglang/zig#37061: aarch64-ios; #37142: checkAllAllocationFailures resizes): use the pinned 0.17.x-branch build 0.17.1-dev+77c319a0f0 (77c319a0f00a), or 0.17.1 once it ships");
}

// ============================================================================
// Platform-Specific Storage Backend Configuration (Phase 9)
// ============================================================================

/// Configure storage backend library linking based on target platform
///
/// Phase 9.1: iOS SQLite Integration - Uses system-provided SQLite
/// Phase 9.2: Android SQLite Integration - Uses system-provided SQLite
/// Phase 9.3: Desktop LevelDB Static Linking - Statically links LevelDB
///
/// Platform Strategy:
/// - iOS: System SQLite (always available, zero binary size cost)
/// - Android: System SQLite (NDK provides libsqlite3)
/// - macOS: Homebrew SQLite + LevelDB (development), system SQLite (production)
/// - Linux: System SQLite + LevelDB via pkg-config
/// - Windows: Bundled SQLite + LevelDB (static linking)
/// - WASM: Memory backend only (no native libraries)
fn configureStorageBackends(
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
) void {
    const os = target.result.os.tag;
    const cpu_arch = target.result.cpu.arch;

    // Detect if this is an Android build (Linux ABI with Android)
    const is_android = os == .linux and target.result.abi == .android;

    if (os == .ios) {
        // ====================================================================
        // Phase 9.1: iOS SQLite Integration
        // ====================================================================
        // iOS provides SQLite as a system framework - no additional linking needed
        // The SQLite C API is available via libsqlite3.tbd
        module.linkSystemLibrary("sqlite3", .{});
        // Note: On iOS, SQLite is part of the SDK, no path configuration needed

        // LevelDB is not used on iOS (SQLite is the default backend)
        // Memory backend is always available as fallback

    } else if (is_android) {
        // ====================================================================
        // Phase 9.2: Android SQLite Integration
        // ====================================================================
        // Android NDK provides libsqlite3.so
        // Link against the system SQLite library
        module.linkSystemLibrary("sqlite3", .{});
        // Note: Android's SQLite is provided by the system, linked dynamically

        // LevelDB is not used on Android (SQLite is the default backend)
        // Memory backend is always available as fallback

    } else if (os == .macos) {
        // ====================================================================
        // macOS: Homebrew development / System production
        // ====================================================================
        // For development on macOS with Homebrew-installed libraries
        // Production builds could use system SQLite or bundled libraries

        // SQLite: Use Homebrew installation (development)
        // System SQLite is also available at /usr/lib/libsqlite3.dylib
        module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/sqlite/lib" });
        module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/sqlite/include" });
        module.linkSystemLibrary("sqlite3", .{});

        // Phase 9.3: LevelDB Static Linking for Desktop
        // Use Homebrew LevelDB (static library preferred)
        module.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/leveldb/lib" });
        module.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/leveldb/include" });
        module.linkSystemLibrary("leveldb", .{});
    } else if (os == .linux) {
        // ====================================================================
        // Linux: System libraries via pkg-config
        // ====================================================================
        // Most Linux distributions provide SQLite and LevelDB packages

        // SQLite: System library (libsqlite3-dev on Debian/Ubuntu)
        module.linkSystemLibrary("sqlite3", .{});

        // Phase 9.3: LevelDB Static Linking for Desktop
        // System library (libleveldb-dev on Debian/Ubuntu)
        module.linkSystemLibrary("leveldb", .{});
    } else if (os == .windows) {
        // ====================================================================
        // Windows: Static linking with bundled libraries
        // ====================================================================
        // Windows builds typically bundle SQLite and LevelDB statically
        // TODO: Add paths to bundled Windows libraries when available

        // For now, attempt system library linking (MSYS2, vcpkg, etc.)
        module.linkSystemLibrary("sqlite3", .{});
        module.linkSystemLibrary("leveldb", .{});
    } else if (cpu_arch == .wasm32 or cpu_arch == .wasm64) {
        // ====================================================================
        // WASM: Memory backend only
        // ====================================================================
        // No native SQLite or LevelDB available in WASM
        // The Memory backend will be used automatically
        // No library linking needed

    } else {
        // ====================================================================
        // Unknown/Other platforms: Best effort
        // ====================================================================
        // Attempt system library linking, fall back to memory backend at runtime
        module.linkSystemLibrary("sqlite3", .{});
        module.linkSystemLibrary("leveldb", .{});
    }
}

// ============================================================================
// Static libcurl Configuration for Fetch Module
// ============================================================================

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
const TlsBackend = enum { mbedtls };
const tls_backend: TlsBackend = .mbedtls;

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
fn buildStaticLibcurl(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    enable_http2: bool,
    sanitize_c: ?std.zig.SanitizeC,
    brotli: ?BrotliLibraries,
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

    // iOS: the SDK paths have to reach the DEPENDENCY's modules too, not just ours.
    // zlib and mbedtls are artifacts of their own (root's, linked into libcurl
    // above), which applyIosSdkRecursively reaches through libcurl's link objects;
    // pointing only the top-level module at the SDK left them failing on <stdio.h>
    // and <string.h> - 15 errors and 107 respectively, which read like broken
    // dependencies rather than an unresolved SDK.
    if (target.result.os.tag == .ios) {
        applyIosSdkRecursively(b, &libcurl.step, iosSdkPath(b));
    }

    // The mbedTLS libcurl links, for WebCrypto: one library, one PSA key store.
    return .{ .libcurl = libcurl, .mbedtls = mbedtls };
}

/// libcurl's own C sanitizer, in every mode: off (buildStaticLibcurl says
/// why). checkLinkedC holds libcurl to it.
const libcurl_sanitize_c: std.zig.SanitizeC = .off;

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
const StaticLibcurl = struct {
    libcurl: *std.Build.Step.Compile,
    mbedtls: *std.Build.Step.Compile,
};

/// Link the static libcurl into `module` (one module graph's fetch).
fn linkStaticLibcurl(
    b: *std.Build,
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    libcurl: *std.Build.Step.Compile,
) void {
    // The importing module links against the SDK too (its curl_c translation
    // gets the SDK headers from addCImport).
    if (target.result.os.tag == .ios) addIosSdkPaths(module, iosSdkPath(b));

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

/// Google's pinned RFC 7932 implementation, following upstream CMake's three
/// library source sets. Only the C codec is built, for the requested target.
const BrotliLibraries = struct { common: *std.Build.Step.Compile, decoder: *std.Build.Step.Compile, encoder: *std.Build.Step.Compile };
fn buildBrotli(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC) ?BrotliLibraries {
    const upstream = b.lazyDependency("brotli", .{}) orelse return null;
    var libs: [3]*std.Build.Step.Compile = undefined;
    const groups = .{ .{ "common", &brotli_common_sources }, .{ "dec", &brotli_dec_sources }, .{ "enc", &brotli_enc_sources } };
    inline for (groups, 0..) |group, i| {
        const lib = b.addLibrary(.{
            .name = "brotli" ++ group[0],
            .linkage = .static,
            .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true }),
        });
        if (sanitize_c) |sanitizer| lib.root_module.sanitize_c = sanitizer;
        lib.root_module.addIncludePath(upstream.path("c/include"));
        lib.root_module.addCSourceFiles(.{ .root = upstream.path("c"), .files = group[1], .flags = &.{"-std=c99"} });
        lib.installHeadersDirectory(upstream.path("c/include/brotli"), "brotli", .{});
        if (target.result.os.tag == .ios) addIosSdkPaths(lib.root_module, iosSdkPath(b));
        libs[i] = lib;
    }
    libs[1].root_module.linkLibrary(libs[0]);
    // The upstream default calls exit() on OOM; embedders must unwind instead.
    libs[2].root_module.addCMacro("BROTLI_ENCODER_CLEANUP_ON_OOM", "1");
    libs[2].root_module.linkLibrary(libs[0]);
    return .{ .common = libs[0], .decoder = libs[1], .encoder = libs[2] };
}

const brotli_common_sources = [_][]const u8{
    "common/constants.c",
    "common/context.c",
    "common/dictionary.c",
    "common/platform.c",
    "common/shared_dictionary.c",
    "common/transform.c",
};

const brotli_dec_sources = [_][]const u8{
    "dec/bit_reader.c",
    "dec/decode.c",
    "dec/huffman.c",
    "dec/prefix.c",
    "dec/state.c",
    "dec/static_init.c",
};

const brotli_enc_sources = [_][]const u8{
    "enc/backward_references.c",
    "enc/backward_references_hq.c",
    "enc/bit_cost.c",
    "enc/block_splitter.c",
    "enc/brotli_bit_stream.c",
    "enc/cluster.c",
    "enc/command.c",
    "enc/compound_dictionary.c",
    "enc/compress_fragment.c",
    "enc/compress_fragment_two_pass.c",
    "enc/dictionary_hash.c",
    "enc/encode.c",
    "enc/encoder_dict.c",
    "enc/entropy_encode.c",
    "enc/fast_log.c",
    "enc/histogram.c",
    "enc/literal_cost.c",
    "enc/memory.c",
    "enc/metablock.c",
    "enc/static_dict.c",
    "enc/static_dict_lut.c",
    "enc/static_init.c",
    "enc/utf8_util.c",
};

/// The testing image decoders. Unmodified pinned sources; no tools, test
/// corpus, system JPEG/XML dependency, or build-time interpreter. Scalar JPEG
/// builds on every target, including iOS, without assembler or CPU globals.
fn buildImageCodecs(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sanitize_c: ?std.zig.SanitizeC) ?*std.Build.Step.Compile {
    const jpeg = b.lazyDependency("jpeg", .{}) orelse return null;
    const nanosvg = b.lazyDependency("nanosvg", .{}) orelse return null;
    const expat = b.lazyDependency("expat", .{}) orelse return null;
    const headers = b.addWriteFiles();
    _ = headers.add("jconfig.h",
        \\#define JPEG_LIB_VERSION 62
        \\#define LIBJPEG_TURBO_VERSION 3.1.3
        \\#define LIBJPEG_TURBO_VERSION_NUMBER 3001003
        \\#define MEM_SRCDST_SUPPORTED 1
        \\#ifndef BITS_IN_JSAMPLE
        \\#define BITS_IN_JSAMPLE 8
        \\#endif
        \\#define C_ARITH_CODING_SUPPORTED 1
        \\#define D_ARITH_CODING_SUPPORTED 1
        \\
    );
    _ = headers.add("jconfigint.h", b.fmt(
        \\#define BUILD "crane-3.1.3"
        \\#define HIDDEN __attribute__((visibility("hidden")))
        \\#define INLINE inline __attribute__((always_inline))
        \\#define THREAD_LOCAL _Thread_local
        \\#define PACKAGE_NAME "libjpeg-turbo"
        \\#define VERSION "3.1.3"
        \\#define SIZEOF_SIZE_T {d}
        \\#define HAVE_BUILTIN_CTZL 1
        \\#define FALLTHROUGH __attribute__((fallthrough));
        \\#ifndef BITS_IN_JSAMPLE
        \\#define BITS_IN_JSAMPLE 8
        \\#endif
        \\#undef C_ARITH_CODING_SUPPORTED
        \\#undef D_ARITH_CODING_SUPPORTED
        \\#if BITS_IN_JSAMPLE == 8
        \\#define C_ARITH_CODING_SUPPORTED 1
        \\#define D_ARITH_CODING_SUPPORTED 1
        \\#endif
        \\
    , .{target.result.ptrBitWidth() / 8}));
    const jpeg_version = b.addConfigHeader(.{ .style = .{ .cmake = jpeg.path("src/jversion.h.in") }, .include_path = "jversion.h" }, .{ .COPYRIGHT_YEAR = "1991-2025" });
    const jpeg_lib = b.addLibrary(.{ .name = "jpeg", .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = sanitize_c }) });
    jpeg_lib.root_module.addIncludePath(headers.getDirectory());
    jpeg_lib.root_module.addIncludePath(jpeg.path("src"));
    jpeg_lib.root_module.addConfigHeader(jpeg_version);
    // jinclude.h's PUTENV_S calls setenv(), which glibc declares under
    // -std=c11 only with a feature-test macro (setenv is POSIX, not ISO C).
    // libjpeg-turbo's CMake build compiles with the compiler's default GNU
    // dialect, which implies _DEFAULT_SOURCE; ask for it explicitly here.
    // Apple's libc declares setenv unconditionally.
    if (target.result.os.tag == .linux) jpeg_lib.root_module.addCMacro("_DEFAULT_SOURCE", "1");
    jpeg_lib.root_module.addCSourceFiles(.{ .root = jpeg.path("src"), .files = &jpeg_sources, .flags = &.{"-std=c11"} });

    const xml_headers = b.addWriteFiles();
    _ = xml_headers.add("expat_config.h", b.fmt(
        \\#define BYTEORDER {d}
        \\#define XML_CONTEXT_BYTES 1024
        \\#define XML_GE 1
        \\#define XML_NS 1
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_STDLIB_H 1
        \\#define HAVE_STRING_H 1
        \\#define HAVE_UNISTD_H 1
        \\#define HAVE_SYS_TYPES_H 1
        \\#define HAVE_FCNTL_H 1
        \\#define HAVE_{s} 1
        \\
    , .{ if (target.result.cpu.arch.endian() == .little) @as(u16, 1234) else 4321, if (target.result.os.tag == .linux) "GETRANDOM" else "ARC4RANDOM_BUF" }));
    const xml_lib = b.addLibrary(.{ .name = "expat", .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = sanitize_c }) });
    xml_lib.root_module.addIncludePath(xml_headers.getDirectory());
    xml_lib.root_module.addIncludePath(expat.path("expat/lib"));
    xml_lib.root_module.addCMacro("XML_STATIC", "1");
    xml_lib.root_module.addCSourceFiles(.{ .root = expat.path("expat/lib"), .files = &.{ "xcs.c", "xmlparse.c", "xmlrole.c", "xmltok.c", if (target.result.os.tag == .linux) "random_getrandom.c" else "random_arc4random_buf.c" }, .flags = &.{"-std=c11"} });

    const lib = b.addLibrary(.{ .name = "crane_image_codecs", .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = sanitize_c }) });
    lib.root_module.addIncludePath(headers.getDirectory());
    lib.root_module.addIncludePath(jpeg.path("src"));
    lib.root_module.addIncludePath(expat.path("expat/lib"));
    lib.root_module.addIncludePath(nanosvg.path("src"));
    lib.root_module.addCMacro("XML_STATIC", "1");
    lib.root_module.addCSourceFiles(.{ .root = b.path("src/platform/kit/image_codecs"), .files = &.{ "jpeg.c", "svg.c" }, .flags = &.{"-std=c11"} });
    lib.root_module.linkLibrary(jpeg_lib);
    lib.root_module.linkLibrary(xml_lib);
    if (target.result.os.tag == .linux) lib.root_module.linkSystemLibrary("m", .{});
    lib.installHeader(b.path("src/platform/kit/image_codecs/image_codecs.h"), "image_codecs.h");
    if (target.result.os.tag == .ios) for ([_]*std.Build.Step.Compile{ jpeg_lib, xml_lib, lib }) |part| addIosSdkPaths(part.root_module, iosSdkPath(b));
    return lib;
}

// libjpeg-turbo 3.1.3 CMakeLists.txt JPEG_SOURCES, including all sample precisions.
const jpeg_sources = [_][]const u8{
    "jcapimin.c",
    "wrapper/jcapistd-8.c",
    "wrapper/jcapistd-12.c",
    "wrapper/jcapistd-16.c",
    "wrapper/jccoefct-8.c",
    "wrapper/jccoefct-12.c",
    "wrapper/jccolor-8.c",
    "wrapper/jccolor-12.c",
    "wrapper/jccolor-16.c",
    "wrapper/jcdctmgr-8.c",
    "wrapper/jcdctmgr-12.c",
    "wrapper/jcdiffct-8.c",
    "wrapper/jcdiffct-12.c",
    "wrapper/jcdiffct-16.c",
    "jchuff.c",
    "jcicc.c",
    "jcinit.c",
    "jclhuff.c",
    "wrapper/jclossls-8.c",
    "wrapper/jclossls-12.c",
    "wrapper/jclossls-16.c",
    "wrapper/jcmainct-8.c",
    "wrapper/jcmainct-12.c",
    "wrapper/jcmainct-16.c",
    "jcmarker.c",
    "jcmaster.c",
    "jcomapi.c",
    "jcparam.c",
    "jcphuff.c",
    "wrapper/jcprepct-8.c",
    "wrapper/jcprepct-12.c",
    "wrapper/jcprepct-16.c",
    "wrapper/jcsample-8.c",
    "wrapper/jcsample-12.c",
    "wrapper/jcsample-16.c",
    "jctrans.c",
    "jdapimin.c",
    "wrapper/jdapistd-8.c",
    "wrapper/jdapistd-12.c",
    "wrapper/jdapistd-16.c",
    "jdatadst.c",
    "jdatasrc.c",
    "wrapper/jdcoefct-8.c",
    "wrapper/jdcoefct-12.c",
    "wrapper/jdcolor-8.c",
    "wrapper/jdcolor-12.c",
    "wrapper/jdcolor-16.c",
    "wrapper/jddctmgr-8.c",
    "wrapper/jddctmgr-12.c",
    "wrapper/jddiffct-8.c",
    "wrapper/jddiffct-12.c",
    "wrapper/jddiffct-16.c",
    "jdhuff.c",
    "jdicc.c",
    "jdinput.c",
    "jdlhuff.c",
    "wrapper/jdlossls-8.c",
    "wrapper/jdlossls-12.c",
    "wrapper/jdlossls-16.c",
    "wrapper/jdmainct-8.c",
    "wrapper/jdmainct-12.c",
    "wrapper/jdmainct-16.c",
    "jdmarker.c",
    "jdmaster.c",
    "wrapper/jdmerge-8.c",
    "wrapper/jdmerge-12.c",
    "jdphuff.c",
    "wrapper/jdpostct-8.c",
    "wrapper/jdpostct-12.c",
    "wrapper/jdpostct-16.c",
    "wrapper/jdsample-8.c",
    "wrapper/jdsample-12.c",
    "wrapper/jdsample-16.c",
    "jdtrans.c",
    "jerror.c",
    "jfdctflt.c",
    "wrapper/jfdctfst-8.c",
    "wrapper/jfdctfst-12.c",
    "wrapper/jfdctint-8.c",
    "wrapper/jfdctint-12.c",
    "wrapper/jidctflt-8.c",
    "wrapper/jidctflt-12.c",
    "wrapper/jidctfst-8.c",
    "wrapper/jidctfst-12.c",
    "wrapper/jidctint-8.c",
    "wrapper/jidctint-12.c",
    "wrapper/jidctred-8.c",
    "wrapper/jidctred-12.c",
    "jmemmgr.c",
    "jmemnobs.c",
    "jpeg_nbits.c",
    "wrapper/jquant1-8.c",
    "wrapper/jquant1-12.c",
    "wrapper/jquant2-8.c",
    "wrapper/jquant2-12.c",
    "wrapper/jutils-8.c",
    "wrapper/jutils-12.c",
    "wrapper/jutils-16.c",
    "jaricom.c",
    "jcarith.c",
    "jdarith.c",
};

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

/// Warns when `-Dsystem-curl` selects a libcurl that cannot do WebSockets.
///
/// `curl_ws_send`/`curl_ws_recv` have been declared in `<curl/websockets.h>`
/// since 7.86, so the link always succeeds. A libcurl built without the feature
/// just returns `CURLE_UNSUPPORTED_PROTOCOL` at runtime - invisible at build
/// time, and afterwards indistinguishable from a Crane bug. macOS still ships
/// 8.7.1, whose `curl-config --features` has no `WebSockets` entry; the vendored
/// curl (8.18.0, see `buildStaticLibcurl`) has it compiled in.
///
/// Advisory only: `-Dsystem-curl` is a legitimate shortcut for work that never
/// opens a WebSocket, so a missing feature must warn rather than fail.
fn warnIfSystemCurlLacksWebSockets(b: *std.Build) void {
    // A configure-time probe of the machine the configure cache cannot track.
    b.graph.poisonCache();
    var code: u8 = 0;
    const features = b.runAllowFail(
        &.{ "curl-config", "--features" },
        &code,
        .ignore,
    ) catch {
        std.debug.print(
            "warning: -Dsystem-curl is set, but `curl-config --features` would not run, " ++
                "so the system libcurl's WebSocket support is unverified.\n" ++
                "         If WebSockets fail at runtime, omit -Dsystem-curl to build the " ++
                "vendored curl 8.18.0.\n",
            .{},
        );
        return;
    };

    // One feature per line. No other curl feature name contains "WebSockets".
    var it = std.mem.tokenizeAny(u8, features, " \t\r\n");
    while (it.next()) |feature| {
        if (std.ascii.eqlIgnoreCase(feature, "WebSockets")) return;
    }

    var version_code: u8 = 0;
    const version_out: []const u8 = b.runAllowFail(
        &.{ "curl-config", "--version" },
        &version_code,
        .ignore,
    ) catch "";
    const version = std.mem.trim(u8, version_out, " \t\r\n");

    std.debug.print(
        "warning: -Dsystem-curl is set and the system {s} lacks WebSocket support " ++
            "(`curl-config --features` lists no `WebSockets`).\n" ++
            "         src/websocket links that libcurl, so `curl_ws_send` resolves at " ++
            "link time and returns CURLE_UNSUPPORTED_PROTOCOL at run time: every " ++
            "WebSocket connection fails,\n" ++
            "         and the WebSocket tests with it. Omit -Dsystem-curl to build the " ++
            "vendored curl 8.18.0, which has WebSockets compiled in.\n",
        .{if (version.len != 0) version else "libcurl"},
    );
}

/// The name of the generated test root `addTestFilesFromDir` writes into each
/// test directory (gitignored).
const test_root_name = ".all_tests.zig";

/// Which test executables `addTestFilesFromDir` builds.
const TestSelection = struct {
    /// -Dtest-file: only this file, as its own executable.
    file: ?[]const u8 = null,
    /// How every test executable is run: tools/test_launcher (see
    /// `TestLaunch` and `addSuiteRun`). Set where the launcher is built,
    /// before the first test executable.
    launch: *const TestLaunch = undefined,
    /// Every tests/<dir>/ build.zig makes a suite: `addTestFilesFromDir`
    /// records its directory, and a directory wired by hand is recorded
    /// beside its wiring (`recordSuiteDir`), whether or not -Dspec selects
    /// it. `checkEveryTestDirectoryIsASuite` reads it.
    suite_dirs: *std.ArrayList([]const u8) = undefined,
    /// The V8 archives every test that links V8 links (-Dv8-build).
    v8: V8Link,
    /// -Dtest-binaries=v8: the directories `test` runs that link V8 join ONE
    /// executable (`OneBinary`) instead of one each. Null: one executable per
    /// directory.
    one: ?*OneBinary = null,
};

/// How `zig build test` groups its tests into executables (-Dtest-binaries;
/// lanes onebin1 and onebin2, which measured three layouts on chat2, -j2,
/// fresh caches - tests/AGENTS.md "Test binaries"; the user chose the
/// hybrid, 2026-11-03).
const TestBinaries = enum {
    /// One executable per tests/<dir>/ (`addTestFilesFromDir`): the default,
    /// because a change to one test file rebuilds only its directory's
    /// executable (245 s against 775 s for `v8`).
    dirs,
    /// ONE executable for the tests/<dir>/ suites `test` runs that link V8
    /// and whose imports agree (`OneBinary`): each of their executables is a
    /// full analysis and V8 link of the engine, so one executable does that
    /// work once (cold 1,560 s against 2,176 s for `dirs`). The rest keep
    /// their cheap executables. For cold full gates (main's gate, final
    /// checks). A third layout, every directory in one (`one`), lost to this
    /// one on every row and was removed (lane onebin2).
    v8,
};

/// -Dtest-binaries=v8: the tests/<dir>/ suites `test` runs that link V8,
/// compiled as ONE executable rooted at tests/.all_tests.zig (gitignored, generated like a
/// directory's), which imports each member's `<dir>/.all_tests.zig`. Test
/// names start with the member's directory under tests/ ("html.<file>.test.
/// <name>"), so each member's suite_configs row still applies, keyed by that
/// prefix: the launcher batches each member as its own executable was
/// (`--group`), and its slow, alone and tsan_skip names carry the prefix.
///
/// What joins: a directory whose imports agree with the others' (each name
/// to the module most members give it) and whose row needs nothing the one
/// executable cannot give per member - a process count of its own (`jobs`),
/// index order, a state-check or variant mode other than `.fail` - and that
/// imports no module whose root file another member's module imports as a
/// file (tests/codegen: `codegen`, which src/webidl/root.zig imports as
/// codegen/root.zig). Any other keeps an executable of its own, as before
/// (tests/runtime: its `runtime` and `engine` are the engine-less tier's).
/// src/ module roots cannot join:
/// Zig collects test blocks from the root module only, and each such root is
/// the module itself (or a clone of one other modules import).
const OneBinary = struct {
    /// The step whose directories join (`test`): one added to another step
    /// (test-browser, bench, test-eventsource) keeps its own executable.
    step: *std.Build.Step,
    /// The V8 archives the executables it makes link (-Dv8-build).
    v8: V8Link,
    members: std.ArrayList(Member) = .empty,

    const Member = struct {
        dir_path: []const u8,
        /// Its suite's name and suite_configs row ("tests-html").
        name: []const u8,
        /// Its test files, relative to `dir_path` (for test-verify).
        files: []const []const u8,
        imports: []const std.Build.Module.Import,
        link_v8: bool,
        target: std.Build.ResolvedTarget,
    };
};

/// A member suite of a one-binary executable, as the launcher runs it
/// (`addSuiteRunWith`): its tests' name prefix, its suite_configs row, and
/// whether its own executable linked V8 (`plain`: it did not, so the
/// many-Browsers variant never runs a busy Browser beside it).
const SuiteGroup = struct { prefix: []const u8, config: SuiteConfig, plain: bool };

/// Record `dir`, a tests/<dir>/ whose tests a hand-made root runs, as a
/// suite (`TestSelection.suite_dirs`).
fn recordSuiteDir(b: *std.Build, select: TestSelection, dir: []const u8) void {
    select.suite_dirs.append(b.allocator, dir) catch @panic("OOM");
}

/// Fail the configuration when a tests/<dir>/ holds `*_test.zig` files and no
/// suite runs them: build.zig compiles a directory's tests only when it names
/// the directory, so a directory it does not name is silently never compiled
/// (tests/infra, from 633a1e91df4 to lane flakes2). And when a `*_test.zig`
/// sits directly in tests/, where no suite looks (lane testfix2). Run when
/// the whole tree is configured - no -Dspec, no -Dtest-file - since a
/// selection skips suites.
fn checkEveryTestDirectoryIsASuite(b: *std.Build, suite_dirs: []const []const u8) void {
    // A configure-time read of the checkout the configure cache cannot track.
    b.graph.poisonCache();
    const io = b.graph.io;
    var tests_dir = b.root.root_dir.handle.openDir(io, "tests", .{ .iterate = true }) catch |err|
        std.debug.panic("build.zig: cannot open tests/ to check its suites: {s}", .{@errorName(err)});
    defer tests_dir.close(io);
    const with_tests = test_suites.dirsWithTests(b.allocator, io, tests_dir, "tests") catch |err|
        std.debug.panic("build.zig: cannot scan tests/ for test files: {s}", .{@errorName(err)});
    const missing = test_suites.missing(b.allocator, with_tests, suite_dirs) catch @panic("OOM");
    // A test file directly in tests/ is in no directory, so no suite collects
    // it (lane testfix2: sixteen sat there, compiled by nothing).
    const top_level = test_suites.topLevelTestFiles(b.allocator, io, tests_dir, "tests") catch |err|
        std.debug.panic("build.zig: cannot scan tests/ for top-level test files: {s}", .{@errorName(err)});
    if (missing.len == 0 and top_level.len == 0) return;
    for (missing) |dir| std.debug.print("build.zig: {s}/ holds *_test.zig files that no suite runs\n", .{dir});
    for (top_level) |file| std.debug.print("build.zig: {s} is directly in tests/, where no suite collects it\n", .{file});
    if (top_level.len != 0) std.debug.panic(
        "build.zig: {d} test file{s} directly in tests/ never compiled (listed above): move each into the tests/<dir>/ of its suite",
        .{ top_level.len, if (top_level.len == 1) "" else "s" },
    );
    std.debug.panic(
        "build.zig: {d} tests/ director{s} with test files never compiled (listed above): make each a suite with addTestFilesFromDir, or record its hand-made root with recordSuiteDir",
        .{ missing.len, if (missing.len == 1) "y" else "ies" },
    );
}

/// Every test executable runs through tools/test_launcher, in its server
/// mode: the build runner speaks the Zig test-runner protocol to the
/// launcher as it would to the executable, and the launcher runs the
/// executable's tests as seeded batches in parallel child processes, with a
/// per-test timeout, and re-runs every failure alone to classify it (FAIL,
/// ORDER-DEPENDENT, FLAKY - none a pass). tmp/plans/test-launcher-design.md.
const TestLaunch = struct {
    /// `zig build test-launch`: the test executables alone, without the
    /// lints and checks `test` also runs.
    step: *std.Build.Step,
    launcher: *std.Build.Step.Compile,
    /// The launcher's own tests run by the build runner directly: they test
    /// the launcher, so they cannot run through it. The one exception
    /// `checkEveryTestRunsThroughTheLauncher` allows.
    own_tests: *std.Build.Step.Compile,
    /// -Dlaunch-batch: overrides every suite's batch size (`suite_configs`).
    batch: ?u32,
    /// -Dlaunch-jobs: test processes at once, for the whole build.
    jobs: ?u32,
    /// -Dlaunch-seed: "digest" (the default: a seed derived from the
    /// executable's bytes, printed, so an unchanged suite keeps its plan and
    /// the cache skips it), "random" (a fresh seed every run; the step is
    /// then never cached), or a value.
    seed: []const u8,
    /// -Dlaunch-timeout: per-test seconds; a slow test gets 4x. Default 300:
    /// Crane's tests run in Debug, and under a full build's load (compiles
    /// beside a test process per core) tests took up to 3x their time alone -
    /// at 60 s, tests that take 20-28 s alone timed out (lane tlaunch2). It
    /// is there to catch hangs; the build runner had no timeout at all.
    timeout: u32,
    /// -Dlaunch-shuffle: true shuffles every suite (an explicit check, such
    /// as the whole-suite runs with several seeds - even a suite whose
    /// `suite_configs` row keeps index order), false runs every suite in index
    /// order; unset, each suite's row decides.
    shuffle: ?bool,
    /// -Dsanitize-thread: every test executable `addSuiteRun` runs is built
    /// with ThreadSanitizer - Crane's own modules only
    /// (`instrumentForThreadSanitizer`) - and run with TSAN_OPTIONS that make
    /// a race a crash blamed on its test (tools/test_launcher, child.zig).
    sanitize_thread: bool,
    /// -Dmany-browsers: the many-Browsers variant - every test runs beside a
    /// second, busy Browser on another thread of its process
    /// (tests/test_runner/neighbour.zig), so state two instances share shows
    /// up as a failure, or under -Dsanitize-thread as a race.
    many_browsers: bool,
    /// -Dtest-log-level: the test executables' log level (`useCraneTestRunner`).
    log_level: ?std.log.Level,
    /// The browser module, which the many-Browsers variant adds to every
    /// test executable that links V8 and lacks it (`addTestRoot`).
    browser_module: ?*std.Build.Module = null,
    /// Every test executable `addSuiteRun` runs, for the instrumentation
    /// pass at the end of `build` (`instrumentForThreadSanitizer`).
    test_exes: *std.ArrayList(*std.Build.Step.Compile),
    /// `zig build test-verify`: the changed test files and their step
    /// (`TestVerify`).
    verify: *TestVerify,
    /// -Dtest-filter=PATTERN, repeatable: run-time test selection. Each is
    /// passed to every suite's launcher as `--filter=` (a test runs when any
    /// pattern matches its whole name, `*` any run of characters;
    /// tools/test_launcher/filter.zig). It changes no compile: every test
    /// executable is the one the build's cache already holds, and a suite
    /// that has no matching test runs nothing and passes.
    filters: []const []const u8 = &.{},
};

/// `zig build test-verify` (the approved test plan, section 6: Gecko's
/// test-verify, Chromium's 20x, WebKit's 10x): every test of each named
/// tests/<dir>/**/*_test.zig file, run by the launcher's verify mode from
/// the file's directory executable - 10 times in one process and 5 times
/// each alone; under -Dsanitize-thread, once - and any run that is not a
/// pass fails the step. The files: -Dverify-files=<a,b,...> (repository-
/// relative), or -Dverify-base=<git ref> for the *_test.zig files under
/// tests/ that `git diff <ref>...HEAD` adds or changes - where there is a
/// git checkout (a pool mirror has none: compute the list in the checkout
/// and pass -Dverify-files).
const TestVerify = struct {
    step: *std.Build.Step,
    files: []const []const u8 = &.{},
    /// Which `files` a directory's executable took (the rest fail the step).
    matched: []bool = &.{},
    /// Whether the files were asked for at all (-Dverify-files or
    /// -Dverify-base); without them the step fails, saying how to ask.
    asked: bool = false,
};

/// One suite's launcher settings. Batch size per the measurements
/// (tmp/plans/test-launcher-design.md section 0, and this lane's merge
/// report): a process per test where the suite starts a Browser or V8 and
/// that costs little (Chromium: 1 for browser tests), 10 otherwise
/// (Chromium's unit tests).
const SuiteConfig = struct {
    batch: u32 = 10,
    /// Null: the build-wide default (-Dlaunch-jobs, else the CPU count).
    jobs: ?u32 = null,
    shuffle: bool = true,
    /// Tests (full names) known to be slow: their timeout is 4x (Chromium's
    /// and V8's SLOW). Each needs a reason, and a bug when it should not be.
    slow: []const []const u8 = &.{},
    /// The Crane test runner's process-state check after each test
    /// (`useCraneTestRunner`): `.fail` fails a test that leaves state behind,
    /// by the field's name; `.report` only logs it, for a suite whose
    /// findings are not fixed yet - each such row is TEMPORARY and says why.
    state_checks: StateChecks = .fail,
    /// The many-Browsers variant (-Dmany-browsers) for this suite: `.fail`
    /// fails what fails beside the busy Browser; `.report` runs it and
    /// reports every non-pass without failing the step (the launcher's
    /// --report-only), for a suite whose findings are not fixed yet - each
    /// such row is TEMPORARY and names its findings file. Suites with no
    /// Browser to run (no V8) never start one.
    many_browsers: VariantMode = .fail,
    /// ThreadSanitizer (-Dsanitize-thread) for this suite, the same way: a
    /// race, a TSAN-only failure, fails the step unless the row is a
    /// TEMPORARY `.report` naming its findings file.
    sanitize_thread: VariantMode = .fail,
    /// Tests that need their process to themselves, so the many-Browsers
    /// variant runs each in a process of its own with no busy Browser
    /// beside it (the launcher's --alone, which names each with its reason
    /// when it runs): a test that makes its process's FIRST isolate, or
    /// whose subject is a count the whole process shares. Declared, never a
    /// silent skip; each entry gives a reason a reader can check. A test
    /// that merely reads a process-wide counter as its instrument is
    /// converted to a per-agent one instead (docs/lessons/testing-a-test-
    /// that-measures-a-process-wide-counter-assumes-it-is-alone.md). A name
    /// ending in ".test." declares every test of that file.
    alone: []const DeclaredTest = &.{},
    /// Tests NOT run under ThreadSanitizer (-Dsanitize-thread; the
    /// launcher's --tsan-skip, which names each with its reason): only a test
    /// whose subject is real time itself, which the instrumentation's
    /// slowdown changes - V8's status files SKIP such tests under tsan. A
    /// test that merely waits on a time budget is fixed to wait on its
    /// condition instead. Keep it to one or two.
    tsan_skip: []const DeclaredTest = &.{},
    /// Who makes the standalone runtime (runtime.initializeRuntime), the
    /// Crane test runner's `runtime.standalone_runtime`.
    standalone_runtime: StandaloneRuntime = .per_test,
};

/// Who makes a suite's standalone runtime. `.per_test`: each test that
/// needs one makes and ends its own, so none runs between tests and a test
/// that leaves one fails by the field's name - a later test that makes and
/// ends its own would replace it and end with none (lane testfix3: two
/// tests/html files left one, and 8 later tests failed ORDER-DEPENDENT with
/// `runtime.standalone_runtime: 1 -> 0`). `.process_start`: the suite's test
/// start makes it once for the process (tests/v8/test_process.zig `start`),
/// so it may appear once, as everything the process start makes may.
const StandaloneRuntime = enum { per_test, process_start };

/// A test declared by its full name, with why (`SuiteConfig.alone`,
/// `SuiteConfig.tsan_skip`).
const DeclaredTest = struct { name: []const u8, reason: []const u8 };

/// What a test variant (-Dmany-browsers, -Dsanitize-thread) does with a
/// suite's results: `.fail` as any run; `.report` prints and records every
/// verdict and passes the step (lane tsan1: report first, fail once clean,
/// as the state checks went - lane tstate1).
const VariantMode = enum { report, fail };

/// What the Crane test runner does with a change a test leaves in the
/// process (tests/test_runner/state.zig). CRANE_TEST_STATE=fail|report|off
/// in the environment overrides it for a run (a survey of every suite in
/// report mode, with CRANE_TEST_STATE_REPORT_DIR=<dir> collecting what it
/// finds), without rebuilding a test executable.
const StateChecks = enum { off, report, fail };

/// The per-suite table, by the name `addSuiteRun` is given. A suite not
/// listed gets `SuiteConfig{}`.
const suite_configs = [_]struct { name: []const u8, config: SuiteConfig }{
    // Wall-clock measurements: one process, index order, nothing beside them.
    .{ .name = "tests-benchmarks", .config = .{ .batch = 0, .jobs = 1, .shuffle = false } },
    .{ .name = "tests-intl_bench", .config = .{ .batch = 0, .jobs = 1, .shuffle = false } },
    // Suites that start V8 or a Browser: a process per test.
    .{ .name = "tests-dom", .config = .{ .batch = 1 } },
    // Both test variants fail (lane tsanfix1 fixed lane tsan1's findings,
    // docs/testing/test-variant-findings-2026-11-02.tsv).
    .{ .name = "tests-html", .config = .{ .batch = 1, .slow = &html_slow, .tsan_skip = &html_tsan_skip } },
    .{ .name = "tests-service_worker", .config = .{ .batch = 1 } },
    .{ .name = "tests-websocket", .config = .{ .batch = 1 } },
    // tests-v8 ran as one index-order process until lane v8order1
    // (2026-11-01) made its tests hermetic (tests/v8/test_process.zig; the
    // order findings it fixed: docs/testing/tests-v8-order-findings-2026-11-01.tsv).
    // Its process-state checks fail a test that leaves state behind, as
    // every suite's do: the findings that kept them report-only (lane
    // tstate1) are classified and fixed, each with its commit, in
    // docs/testing/test-state-findings-2026-11-02.tsv (lanes engown1,
    // fixes1, v8state1).
    // Beside the busy Browser (-Dmany-browsers) it fails like any run (lane
    // tsanfix1); the tests that need their process to themselves run alone,
    // each with its reason (`v8_alone`). Its test start makes the
    // standalone runtime for the process (test_process.start).
    .{ .name = "tests-v8", .config = .{ .batch = 1, .alone = &v8_alone, .standalone_runtime = .process_start } },
    .{ .name = "src-browser", .config = .{ .batch = 1 } },
    .{ .name = "tests-browser", .config = .{ .batch = 1 } },
    // The browser console (tools/repl.zig): every test starts a Browser
    // (lane console1).
    .{ .name = "tests-repl", .config = .{ .batch = 1 } },
    .{ .name = "lib-exports", .config = .{ .batch = 1 } },
    .{ .name = "tests-codegen", .config = .{ .slow = &codegen_slow } },
};

/// tests-v8's tests that need their process to themselves under the
/// many-Browsers variant (`SuiteConfig.alone`; lane tsanfix1).
const v8_alone = snapshot_first ++ [_]DeclaredTest{
    // The subject is a count the whole process shares.
    .{ .name = "diagnostic_live_counters_test.test.live_agents counts an agent from createAgent to destroyAgent", .reason = "the subject is engine.live_agents, the process's count of live agents, which the busy Browser's agent is in" },
    .{ .name = "worker_thread_state_test.test.worker threads that end leave no per-thread containers mapped", .reason = "the subject is the process's mapped memory over 32 worker threads, which the busy Browser's allocations grow" },
    .{ .name = "agents_concurrent_engine_state_test.test.two fresh agents on two threads: for-await, Intl, JSON modules and ObservableArray 200 times at once", .reason = "TEMPORARY: it compares the process's live weak callback records over its two agents' rounds; per isolate, each round's for await makes a stream, and wrapper_cache.isStreamsGraphObject holds a streams object's wrapper strongly until its realm ends (lane leakcheck1's finding; the streams wrapper lifetime lane) - converted once that is settled" },
    .{ .name = "test_process_test.test.a test's agent takes its realms down with it, their context handles too", .reason = "the subject is the process's live Global<Context> count after the agent's end - its isolate is gone, so nothing per isolate is left to read - which the busy Browser's realms move" },
} ++ ledger_tests ++ process_count_subjects;

/// object_global_ledger_test: the subject of each is the adapter's
/// process-wide live_object_globals ledger itself.
const ledger_reason = "the subject is the adapter's process-wide live_object_globals ledger, which every Browser of the process moves (V8's per-isolate global handle bytes are its cross-check, not its subject)";
const ledger_tests = [_]DeclaredTest{
    .{ .name = "object_global_ledger_test.test.v8_Object_New is counted when made and when released by v8_Object_Dispose", .reason = ledger_reason },
    .{ .name = "object_global_ledger_test.test.v8_Object_New released as a Value (the binding's release) leaves the ledger where it started", .reason = ledger_reason },
    .{ .name = "object_global_ledger_test.test.the other object constructors are counted the same way", .reason = ledger_reason },
    .{ .name = "object_global_ledger_test.test.a counted entry point released through a generic dispose leaves nothing counted", .reason = ledger_reason },
    .{ .name = "object_global_ledger_test.test.a binding call that makes and releases objects leaves the ledger where it started", .reason = ledger_reason },
};

/// The many-Browsers variant's reason for a test that restores agents from
/// Crane's snapshot.
const snapshot_first_reason = "restores agents from Crane's snapshot, so it must make its process's first isolate: V8 keeps one read-only heap per process, made by the first live isolate (v8_wrapper.cpp g_read_only_heap), and beside the busy Browser's snapshotless isolate the restore is refused";

/// Tests that restore agents from Crane's snapshot (each skips, saying so,
/// when it does not make its process's first isolate).
const snapshot_first = [_]DeclaredTest{
    .{ .name = "agents_concurrent_engine_state_test.test.two agents restored from the snapshot, on two threads: for-await, Intl, ShadowRealm, JSON modules and ObservableArray 200 times at once", .reason = snapshot_first_reason },
    .{ .name = "bf1_engine_task_initialization_test.test.snapshot initialization runner wakes a later sink and closes safely", .reason = snapshot_first_reason },
    .{ .name = "cpp_heap_test.test.an agent restored from the snapshot has a C++ heap", .reason = snapshot_first_reason },
    .{ .name = "new_global_snapshot_test.test.snapshot agent: parseJsonInNewGlobal parses in a new global, not the page's", .reason = snapshot_first_reason },
    .{ .name = "new_global_snapshot_test.test.snapshot agent: parseJsonInNewGlobal, again and again, each in a global of its own", .reason = snapshot_first_reason },
    .{ .name = "new_global_snapshot_test.test.snapshot agent: v8_Context_New and v8_Context_NewWithMicrotaskQueue make a plain global", .reason = snapshot_first_reason },
    .{ .name = "pattern_attribute_snapshot_test.test.snapshot agent: a pattern matches the whole value, compiled standalone with the v flag", .reason = snapshot_first_reason },
    .{ .name = "pattern_attribute_snapshot_test.test.snapshot agent: what the page did to RegExp does not matter", .reason = snapshot_first_reason },
    .{ .name = "pattern_attribute_snapshot_test.test.snapshot agent: the page's legacy RegExp statics do not see the value", .reason = snapshot_first_reason },
    .{ .name = "snapshot_blob_in_place_test.test.agents restored from the snapshot read the engine's blob in place, and all end before it does", .reason = snapshot_first_reason },
    .{ .name = "tsanfix1_read_only_heap_test.test.an agent asked for the snapshot while a snapshotless isolate is the process's first is made without it, and works", .reason = snapshot_first_reason },
    .{ .name = "tsanfix1_read_only_heap_test.test.a snapshotless agent made while a snapshot agent is the process's first: each is what it asked for", .reason = snapshot_first_reason },
    .{ .name = "tsanfix1_read_only_heap_test.test.a dedicated worker's agent started while a snapshot window agent lives: both work, the window restored", .reason = snapshot_first_reason },
    .{ .name = "tsanfix1_read_only_heap_test.test.a snapshot window agent made while a worker's agent is the process's first is made without the snapshot, and works", .reason = snapshot_first_reason },
    .{ .name = "wh_wasm_address_descriptor_test.test.snapshot realm: a Window realm restored from Crane's snapshot takes address i64", .reason = snapshot_first_reason },
    .{ .name = "wj1_wasm_constructor_test.test.snapshot Window worklet and ShadowRealm use their own wasm adapter intrinsics", .reason = snapshot_first_reason },
    .{ .name = "xw1_exposure_snapshot_test.test.xw1 snapshot Window keeps its scope while workers install their own exposed members", .reason = snapshot_first_reason },
};

/// context_counter_test: the subject of each is the balance of the adapter's
/// process-wide live_context_globals count itself. The file's other tests
/// read their own isolate's global handle bytes (lane testfix2).
const context_count_reason = "the subject is the adapter's process-wide live_context_globals count - every Global<Context> made is counted and every dispose uncounts it - which the busy Browser's realms move too (V8's per-isolate global handle bytes see a leaked context, not a miscounted one)";

/// Tests whose subject is that a binding path makes NO Global for its
/// receiver: a handle made and disposed leaves the isolate's global handle
/// bytes as they were, so only the adapter's process-wide creation count per
/// entry point (object_globals_from.*) sees one (lane testfix2).
const receiver_creation_reason = "the subject is that the path makes no Global for its receiver - a handle made and disposed leaves the isolate's global handle bytes as they were, so only the adapter's process-wide creation count object_globals_from.* sees it, which the busy Browser's bindings move too";

/// weak_callback_ownership_test: the subject of each is the adapter's
/// process-wide ledger of live weak callback records itself - "returns to
/// baseline" is the assertion, and a record freed late or never is invisible
/// to the isolate's global handle bytes once its handle is reset (lane
/// testfix2, with the integrator's ruling).
const weak_record_reason = "the process-wide weak-record ledger is the subject: v8_Debug_LiveWeakCallbackData returning to its baseline is the assertion, and the busy Browser's wrappers arm and free records too";

/// cpp_heap_test: the subject is cppgc's process-wide registry of live C++
/// heaps, the one measure of an agent's end freeing its heap (lane wr2).
const cpp_heap_registry_reason = "the subject is cppgc's process-wide registry of live C++ heaps - an agent's end must give its count back - which the busy Browser's agents move too";

/// The tests of lane tsanfix1's whole-file entries (2026-11-02) whose
/// subject is a count the whole process shares; their files' other tests
/// read their own isolate's global handle bytes (lane testfix2).
const process_count_subjects = [_]DeclaredTest{
    .{ .name = "cpp_heap_test.test.an agent's end frees its C++ heap: cppgc's heap registry is back where it was", .reason = cpp_heap_registry_reason },
    .{ .name = "context_counter_test.test.binding getter and method calls leave live_context_globals unchanged", .reason = context_count_reason },
    .{ .name = "context_counter_test.test.a context made with a global constructor and disposed leaves live_context_globals unchanged", .reason = context_count_reason },
    .{ .name = "indexed_property_semantics_test.test.an indexed read and an `in` check make no handle for the list", .reason = receiver_creation_reason },
    .{ .name = "indexed_property_semantics_test.test.an attribute read makes no handle for its receiver and leaves none", .reason = receiver_creation_reason },
    .{ .name = "weak_callback_ownership_test.test.disarming a handle frees the record V8 hands back", .reason = weak_record_reason },
    .{ .name = "weak_callback_ownership_test.test.disposing an armed handle ends the arm - the record cannot outlive the Global", .reason = weak_record_reason },
    .{ .name = "weak_callback_ownership_test.test.re-arming the same handle replaces the record rather than stacking one", .reason = weak_record_reason },
    .{ .name = "weak_callback_ownership_test.test.a handle that was never armed is unaffected by disarm and dispose", .reason = weak_record_reason },
    .{ .name = "weak_callback_ownership_test.test.v8_Value_ToWeakGlobal arms the handle it returns, not a null one", .reason = weak_record_reason },
    .{ .name = "weak_callback_ownership_test.test.disposing an isolate leaves another isolate's detached records alone", .reason = weak_record_reason },
    .{ .name = "weak_callback_ownership_test.test.a finalizer runs in V8's second pass, after its first-pass unlink, and its record goes with it", .reason = weak_record_reason },
    .{ .name = "weak_callback_ownership_test.test.disposing a handle before its second pass cancels the finalizer and frees its record", .reason = weak_record_reason },
};

// Slow tests: over 45 s alone on chat.local in Debug (lane tlaunch2,
// 2026-11-01, four at once); under a full build's load they took up to 3x.
const codegen_slow = [_][]const u8{
    // 82.7 s: every committed interface and mixin module.
    "ce_reactions_emission_test.test.every committed interface and mixin module's table matches its brackets",
};
/// tests-html's tests whose subject is real time (`SuiteConfig.tsan_skip`;
/// lane tsanfix1, with the integrator's ruling).
const html_tsan_skip = [_]DeclaredTest{
    .{ .name = "detplat1_virtual_time_test.test.virtual clock: a timer-heavy page runs far faster than real time (measured)", .reason = "the subject is real time: it measures how much faster than real time a virtual clock runs a timer-heavy page, and ThreadSanitizer's slowdown is that measurement" },
    .{ .name = "fk2_idle_period_spin_test.test.every idle period that starts runs an idle callback (no empty periods spinning)", .reason = "the subject is real time: an idle period's callbacks run only before its real-time deadline, and under ThreadSanitizer's slowdown the task that runs them can start after it - an empty period the spec allows; its scenario needs a fetch in flight, which stops a virtual clock (event_loop.fastForwardToNextWakeUp)" },
};

const html_slow = [_][]const u8{
    // 74.6, 78.9 and 50.4 s: 300,000 live ranges; two Browsers churning.
    "rangeuaf_live_range_walk_test.test.removing a node after 300,000 ranges were made in it moves every live range it holds",
    "rangeuaf_live_range_walk_test.test.splitting text after 300,000 ranges were made in it moves every live range it holds",
    "rangeuaf_live_range_walk_test.test.two Browsers on two threads churn live ranges and walk their own lists at once",
    // 77.2 s: 1,000 dropped lists, two collections each.
    "nodeholds_cost_test.test.1,000 dropped querySelectorAll lists that rescued their trees retain nothing past two collections",
    // 77.0 s.
    "rc9_document_tasks_test.test.documents dropped inside one script stay bounded by the queue's high water, not by their number",
};

fn suiteConfig(name: []const u8) SuiteConfig {
    for (suite_configs) |entry| if (std.mem.eql(u8, entry.name, name)) return entry.config;
    return .{};
}

/// Runs the test executable `test_exe` - the ONE way build.zig runs a test
/// executable. `name` names the suite: its result file
/// tmp/test-launch/<name>.jsonl (the next run's timings, for the
/// longest-first claim order), its row in `suite_configs` (`config_name`,
/// when that differs: a -Dtest-file executable takes its directory's), and
/// its step, "test <name>". The step is a `zig_test` Run of the launcher, so
/// it caches like a test executable's own run (unless -Dlaunch-seed=random).
/// The caller adds it to its own step; `test-launch` gets the ones `test`
/// reaches.
fn addSuiteRun(b: *std.Build, launch: *const TestLaunch, test_exe: *std.Build.Step.Compile, name: []const u8, config_name: ?[]const u8) *std.Build.Step.Run {
    return addSuiteRunWith(b, launch, test_exe, name, config_name, &.{});
}

/// `addSuiteRun` for an executable that holds several suites (`OneBinary`):
/// each of `groups` keeps its own row of suite_configs, keyed by its tests'
/// name prefix (`addGroupArgs`).
fn addSuiteRunWith(b: *std.Build, launch: *const TestLaunch, test_exe: *std.Build.Step.Compile, name: []const u8, config_name: ?[]const u8, groups: []const SuiteGroup) *std.Build.Step.Run {
    const config = suiteConfig(config_name orelse name);
    // Whether this executable can run the many-Browsers variant's busy
    // Browser: -Dmany-browsers, and it links V8 and the browser module. The
    // others run as usual under -Dmany-browsers, and say nothing about it.
    const many_browsers = useCraneTestRunner(b, test_exe, name, config.state_checks, config.standalone_runtime, groups, launch.many_browsers, launch.log_level);
    const run = b.addRunArtifact(launch.launcher);
    run.setName(b.fmt("test {s}", .{name}));
    // The build runner speaks the test-runner protocol to the launcher.
    run.stdio = .zig_test;
    run.addArtifactArg(test_exe);
    run.addArg(b.fmt("--name={s}", .{name}));
    run.addArg(b.fmt("--batch={d}", .{launch.batch orelse config.batch}));
    if (config.jobs orelse launch.jobs) |jobs| run.addArg(b.fmt("--jobs={d}", .{jobs}));
    run.addArg(b.fmt("--launch-seed={s}", .{launch.seed}));
    run.addArg(b.fmt("--timeout={d}", .{launch.timeout}));
    if (!(launch.shuffle orelse config.shuffle)) run.addArg("--no-shuffle");
    for (config.slow) |slow| run.addArg(b.fmt("--slow={s}", .{slow}));
    if (launch.sanitize_thread) {
        run.addArg("--sanitize-thread");
        run.addPrefixedFileArg("--tsan-suppressions=", b.path("tools/test_launcher/tsan_suppressions.txt"));
        for (config.tsan_skip) |skip| {
            run.addArg(b.fmt("--tsan-skip={s}", .{skip.name}));
            run.addArg(b.fmt("--tsan-skip-reason={s}", .{skip.reason}));
        }
        // Line numbers in a race report: on macOS the debug information
        // stays in the object files, and ThreadSanitizer's symbolizer (atos)
        // reads a dSYM bundle beside the binary - without one a report names
        // functions with `<null>` lines (lane tlaunch1; checked on
        // chat.local, lane tsan1). The bundle lands beside the cached
        // executable the launcher runs; cached like the executable.
        if (test_exe.rootModuleTarget().os.tag.isDarwin() and b.graph.host.result.os.tag.isDarwin()) {
            const dsym = b.addSystemCommand(&.{"dsymutil"});
            dsym.setName(b.fmt("dsymutil {s}", .{name}));
            dsym.addArtifactArg(test_exe);
            dsym.expectExitCode(0);
            // Its warnings about objects without debug information (the V8
            // prebuilt) are not the build's diagnostics.
            _ = dsym.captureStdErr(.{});
            run.step.dependOn(&dsym.step);
        }
    }
    if (many_browsers) {
        run.addArg("--many-browsers");
        for (config.alone) |alone| {
            run.addArg(b.fmt("--alone={s}", .{alone.name}));
            run.addArg(b.fmt("--alone-reason={s}", .{alone.reason}));
        }
    }
    addGroupArgs(b, run, launch, groups, many_browsers, true);
    // A variant's TEMPORARY report-only row: every verdict printed and
    // recorded, the step passes (`VariantMode`).
    if ((many_browsers and config.many_browsers == .report) or (launch.sanitize_thread and config.sanitize_thread == .report)) run.addArg("--report-only");
    launch.test_exes.append(b.allocator, test_exe) catch @panic("OOM");
    // -Dtest-filter: run-time selection, so the executable stays the cached
    // one.
    for (launch.filters) |pattern| run.addArg(b.fmt("--filter={s}", .{pattern}));
    // Relative to the repository root, where tests open their fixtures. A
    // variant's results, and a filtered run's, beside the suite's own, never
    // over them: tmp/test-launch/<name>[.tsan][.many-browsers][.filtered].jsonl
    // (the timings stay the plain full run's).
    const variant = b.fmt("{s}{s}{s}", .{
        if (launch.sanitize_thread) ".tsan" else "",
        if (many_browsers) ".many-browsers" else "",
        if (launch.filters.len != 0) ".filtered" else "",
    });
    run.addArg(b.fmt("--out=tmp/test-launch/{s}{s}.jsonl", .{ name, variant }));
    run.addArg(b.fmt("--timings=tmp/test-launch/{s}.jsonl", .{name}));
    run.setCwd(b.path("."));
    // A fresh seed every run must run every time.
    if (std.mem.eql(u8, launch.seed, "random")) run.has_side_effects = true;
    return run;
}

/// The launcher arguments of the member suites of a one-binary executable
/// (`SuiteGroup`): each one's batch size (`--group`; -Dlaunch-batch
/// overrides every one, so batch 0 is still each suite in one process), its
/// slow, alone and tsan_skip names with its prefix, and `--plain` for one
/// whose own executable linked no V8. `batches`: false for test-verify,
/// which runs its own shapes.
fn addGroupArgs(b: *std.Build, run: *std.Build.Step.Run, launch: *const TestLaunch, groups: []const SuiteGroup, many_browsers: bool, batches: bool) void {
    for (groups) |g| {
        if (batches) run.addArg(b.fmt("--group={s}={d}", .{ g.prefix, launch.batch orelse g.config.batch }));
        for (g.config.slow) |slow| run.addArg(b.fmt("--slow={s}{s}", .{ g.prefix, slow }));
        if (launch.sanitize_thread) for (g.config.tsan_skip) |skip| {
            run.addArg(b.fmt("--tsan-skip={s}{s}", .{ g.prefix, skip.name }));
            run.addArg(b.fmt("--tsan-skip-reason={s}", .{skip.reason}));
        };
        if (many_browsers) {
            if (g.plain) run.addArg(b.fmt("--plain={s}", .{g.prefix}));
            for (g.config.alone) |alone| {
                run.addArg(b.fmt("--alone={s}{s}", .{ g.prefix, alone.name }));
                run.addArg(b.fmt("--alone-reason={s}", .{alone.reason}));
            }
        }
    }
}

/// Builds `test_exe` with the Crane test runner (tests/test_runner/): Zig's
/// server-mode runner, which the launcher and the build runner speak to as
/// before, with a process-state check around every test - a digest of the
/// process's state before and after it, and a test that leaves a change
/// fails by the field's name (the approved test plan,
/// tmp/plans/test-launcher-design.md sections 2 and 3).
///
/// The runner reads only what the executable links: its directory is copied
/// beside a generated `suite.zig` that names the root module's own imports
/// it may read - every import whose root is a `src/<dir>/root.zig`, keyed by
/// that directory - and the engine only where the root module links V8.
/// Zig gives a custom test runner a copy of the root module's imports, so
/// the runner's `@import("dom")` is the executable's own dom. And
/// tools/global_state_baseline.txt, lint-global-state's inventory, from which
/// the runner makes its table of global variables.
///
/// `many_browsers` (-Dmany-browsers): the runner may run the busy Browser of
/// the many-Browsers variant (tests/test_runner/neighbour.zig) - `browser`,
/// where the executable imports the browser module and links V8. Returns
/// whether it can. `standalone`: who makes the standalone runtime
/// (`StandaloneRuntime`), which decides how the runner compares it.
/// `members`: the member suites of a joined executable (`OneBinary`,
/// -Dtest-binaries=v8), each with its own row: the runner judges a test by
/// its member's StandaloneRuntime, found by the test's name prefix (lane
/// onebin3: tests-v8's .process_start had no per-member path, so its tests
/// read as leavers in the joined "tests" executable). Empty for an
/// executable of one suite, which keeps `standalone` for every test.
///
/// `log_level` (-Dtest-log-level): the runner's `std_options.log_level`, the
/// level below which every `std.log` call is compiled out, and the level it
/// prints at while a test runs (`testing.log_level`). Unset, a test
/// executable compiles its logs at .info - no `log.debug` site is analysed,
/// though a Debug build's default would compile all of them (lane
/// compiletime1) - and prints at .warn, as it always has. A test may lower
/// `testing.log_level` to .info and read info logs; to read debug logs, build
/// with -Dtest-log-level=debug, which compiles and prints them. The WPT
/// runner, the library and the tools keep their own levels.
fn useCraneTestRunner(b: *std.Build, test_exe: *std.Build.Step.Compile, name: []const u8, checks: StateChecks, standalone: StandaloneRuntime, members: []const SuiteGroup, many_browsers: bool, log_level: ?std.log.Level) bool {
    const root = test_exe.root_module;
    const wf = b.addWriteFiles();
    _ = wf.addCopyDirectory(b.path("tests/test_runner"), "", .{ .include_extensions = &.{".zig"} });
    _ = wf.addCopyFile(b.path("tools/global_state_baseline.txt"), "global_state_baseline.txt");

    var suite: std.Io.Writer.Allocating = .init(b.allocator);
    const w = &suite.writer;
    w.print(
        \\//! Generated by build.zig (useCraneTestRunner) for the test executable
        \\//! '{s}': what the Crane test runner may read. Do not edit.
        \\
        \\pub const name = "{s}";
        \\pub const Mode = enum {{ off, report, fail }};
        \\pub const mode: Mode = .{t};
        \\/// -Dtest-log-level, or null: the runner's log levels (runner.zig).
        \\pub const log_level_option: ?@import("std").log.Level = {s};
        \\/// Who makes the standalone runtime (build.zig's StandaloneRuntime).
        \\pub const StandaloneRuntime = enum {{ per_test, process_start }};
        \\pub const standalone_runtime: StandaloneRuntime = .{t};
        \\/// A joined executable's member suites (build.zig -Dtest-binaries=v8):
        \\/// a test whose name starts with a member's prefix is judged by that
        \\/// member's own StandaloneRuntime - the longest prefix wins. Empty for an
        \\/// executable of one suite.
        \\pub const Member = struct {{ prefix: []const u8, standalone_runtime: StandaloneRuntime }};
        \\pub const members: []const Member = &.{{
        \\
    , .{ name, name, checks, if (log_level) |level| b.fmt(".{t}", .{level}) else "null", standalone }) catch @panic("OOM");
    for (members) |m| w.print("    .{{ .prefix = \"{s}\", .standalone_runtime = .{t} }},\n", .{ m.prefix, m.config.standalone_runtime }) catch @panic("OOM");
    w.writeAll(
        \\};
        \\
        \\/// The root module's imports rooted at src/<dir>/root.zig, by directory.
        \\pub const roots = .{
        \\
    ) catch @panic("OOM");
    // Every import rooted at a src/<dir>/root.zig - but, besides `dom` and
    // `runtime` (the counters' own, which import no other module's root as
    // a file), none whose directory holds another's: its root may import the
    // other's root as a file (src/webidl/root.zig imports codegen/root.zig,
    // the `codegen` module's root), and once the runner's import makes it
    // reachable that file would be in two modules - which the compile refuses
    // even where the tests themselves never imported the outer module.
    var dirs: std.ArrayList(struct { name: []const u8, dir: []const u8 }) = .empty;
    for (root.import_table.keys(), root.import_table.values()) |import_name, module| {
        const source = module.root_source_file orelse continue;
        if (source != .src_path) continue;
        const sub_path = source.src_path.sub_path;
        if (!std.mem.startsWith(u8, sub_path, "src/") or !std.mem.eql(u8, std.fs.path.basename(sub_path), "root.zig")) continue;
        dirs.append(b.allocator, .{ .name = import_name, .dir = b.fmt("{s}/", .{std.fs.path.dirname(sub_path).?}) }) catch @panic("OOM");
    }
    var has_dom = false;
    var has_runtime = false;
    outer: for (dirs.items) |entry| {
        const counters = (std.mem.eql(u8, entry.name, "dom") and std.mem.eql(u8, entry.dir, "src/dom/")) or
            (std.mem.eql(u8, entry.name, "runtime") and std.mem.eql(u8, entry.dir, "src/runtime/"));
        if (!counters) for (dirs.items) |other| {
            if (other.dir.len > entry.dir.len and std.mem.startsWith(u8, other.dir, entry.dir)) continue :outer;
        };
        w.print("    .{{ \"{s}\", @import(\"{s}\") }},\n", .{ entry.dir, entry.name }) catch @panic("OOM");
        if (std.mem.eql(u8, entry.name, "dom") and std.mem.eql(u8, entry.dir, "src/dom/")) has_dom = true;
        if (std.mem.eql(u8, entry.name, "runtime") and std.mem.eql(u8, entry.dir, "src/runtime/")) has_runtime = true;
    }
    w.writeAll("};\n\n") catch @panic("OOM");
    w.print("pub const dom: ?type = {s};\n", .{if (has_dom) "@import(\"dom\")" else "null"}) catch @panic("OOM");
    w.print("pub const runtime: ?type = {s};\n", .{if (has_runtime) "@import(\"runtime\")" else "null"}) catch @panic("OOM");
    const has_engine = root.import_table.get("engine") != null and linksV8(root);
    w.print("/// The engine, where the executable links V8.\npub const engine: ?type = {s};\n", .{if (has_engine) "@import(\"engine\")" else "null"}) catch @panic("OOM");
    const has_browser = many_browsers and root.import_table.get("browser") != null and linksV8(root);
    w.print("/// The browser module, for the many-Browsers variant's busy Browser\n/// (-Dmany-browsers, where the executable links V8).\npub const browser: ?type = {s};\n", .{if (has_browser) "@import(\"browser\")" else "null"}) catch @panic("OOM");
    _ = wf.add("suite.zig", suite.written());

    const runner = wf.getDirectory().path(b, "runner.zig");
    test_exe.test_runner = .{ .path = runner.dupe(b.graph), .mode = .server };
    runner.addStepDependencies(&test_exe.step);
    return has_browser;
}

/// Whether `module` links V8 itself (`linkV8`): its own C++ wrapper.
fn linksV8(module: *std.Build.Module) bool {
    for (module.link_objects.items) |object| {
        if (object != .c_source_file) continue;
        const file = object.c_source_file.file;
        if (file == .src_path and std.mem.eql(u8, file.src_path.sub_path, "src/runtime/engines/v8/v8_wrapper.cpp")) return true;
    }
    return false;
}

/// Fails the configuration if any step runs a test executable other than
/// through `addSuiteRun`: a test the build runner runs directly gets no
/// timeout, no seeded order and no failure classification, and nothing
/// would say so. Then makes `test-launch` the launcher runs `test` reaches.
fn checkEveryTestRunsThroughTheLauncher(b: *std.Build, launch: *const TestLaunch, test_step: *std.Build.Step) void {
    var seen: std.AutoHashMapUnmanaged(*std.Build.Step, void) = .empty;
    var stack: std.ArrayList(*std.Build.Step) = .empty;
    for (b.top_level_steps.values()) |tls| stack.append(b.allocator, &tls.step) catch @panic("OOM");
    while (stack.pop()) |step| {
        if ((seen.getOrPut(b.allocator, step) catch @panic("OOM")).found_existing) continue;
        if (step.cast(std.Build.Step.Run)) |run| if (run.producer) |producer| {
            if (producer.kind.isTest() and producer != launch.own_tests) std.debug.panic(
                "build.zig: step '{s}' runs test executable '{s}' directly; run it with addSuiteRun (tools/test_launcher)",
                .{ step.name, producer.name },
            );
        };
        for (step.dependencies.items) |dep| stack.append(b.allocator, dep) catch @panic("OOM");
    }

    seen.clearRetainingCapacity();
    stack.append(b.allocator, test_step) catch @panic("OOM");
    while (stack.pop()) |step| {
        if ((seen.getOrPut(b.allocator, step) catch @panic("OOM")).found_existing) continue;
        if (step.cast(std.Build.Step.Run)) |run| if (run.producer == launch.launcher) {
            launch.step.dependOn(step);
            continue;
        };
        for (step.dependencies.items) |dep| stack.append(b.allocator, dep) catch @panic("OOM");
    }
}

/// The `test-verify` step and its files: -Dverify-files, else
/// -Dverify-base's git diff.
fn testVerifySelection(b: *std.Build) *TestVerify {
    const v = b.allocator.create(TestVerify) catch @panic("OOM");
    v.* = .{ .step = b.step("test-verify", "Verify new and changed tests: each test of the files -Dverify-files=<a,b> (or -Dverify-base=<ref>: git diff <ref>...HEAD) 10 times in one process and 5 times alone; with -Dsanitize-thread, once") };
    const files_option = b.option([]const u8, "verify-files", "test-verify: comma-separated tests/<dir>/**/*_test.zig files (repository-relative)");
    const base = b.option([]const u8, "verify-base", "test-verify: the git ref whose diff (<ref>...HEAD) names the changed test files, where there is a git checkout");
    var files: std.ArrayList([]const u8) = .empty;
    if (files_option) |list| {
        v.asked = true;
        var it = std.mem.tokenizeAny(u8, list, ", \n");
        while (it.next()) |file| files.append(b.allocator, file) catch @panic("OOM");
    } else if (base) |ref| {
        v.asked = true;
        // A configure-time read of the checkout the configure cache cannot
        // track.
        b.graph.poisonCache();
        var code: u8 = 0;
        const out = b.runAllowFail(&.{ "git", "diff", "--name-only", "--diff-filter=AMR", b.fmt("{s}...HEAD", .{ref}), "--", "tests/" }, &code, .inherit) catch |err| {
            v.step.dependOn(&b.addFail(b.fmt("test-verify: git diff {s}...HEAD failed ({t}): no git checkout here? Pass -Dverify-files=<a,b,...> instead", .{ ref, err })).step);
            return v;
        };
        var lines = std.mem.tokenizeScalar(u8, out, '\n');
        while (lines.next()) |file| {
            if (std.mem.endsWith(u8, file, "_test.zig") and !std.mem.startsWith(u8, file, "tests/wpt/")) files.append(b.allocator, file) catch @panic("OOM");
        }
    }
    v.files = files.items;
    v.matched = b.allocator.alloc(bool, files.items.len) catch @panic("OOM");
    @memset(v.matched, false);
    return v;
}

/// Adds the verify run of `test_exe`, the executable of the test directory
/// `dir_path` made of `files` (relative to it), for the verify files in it.
/// Test names start with the file's path in the directory, '/' as '.', no
/// `.zig`: "navigation.nav2h_indexes_test.test.<name>".
fn addTestVerify(b: *std.Build, launch: *const TestLaunch, test_exe: *std.Build.Step.Compile, name: []const u8, dir_path: []const u8, files: []const []const u8) void {
    addTestVerifyIn(b, launch, test_exe, name, dir_path, files, .{ .prefix = "", .config = suiteConfig(name), .plain = false });
}

/// `addTestVerify` for one member suite of a one-binary executable
/// (`OneBinary`): its tests' names start with `group.prefix`, and its row of
/// suite_configs is `group.config`.
fn addTestVerifyIn(b: *std.Build, launch: *const TestLaunch, test_exe: *std.Build.Step.Compile, name: []const u8, dir_path: []const u8, files: []const []const u8, group: SuiteGroup) void {
    const v = launch.verify;
    var prefixes: std.ArrayList([]const u8) = .empty;
    for (v.files, v.matched) |file, *matched| {
        if (!std.mem.startsWith(u8, file, dir_path) or file.len <= dir_path.len + 1 or file[dir_path.len] != '/') continue;
        const rel = file[dir_path.len + 1 ..];
        for (files) |f| {
            if (!std.mem.eql(u8, f, rel)) continue;
            matched.* = true;
            const stem = rel[0 .. rel.len - ".zig".len];
            const dotted = b.allocator.dupe(u8, stem) catch @panic("OOM");
            std.mem.replaceScalar(u8, dotted, '/', '.');
            prefixes.append(b.allocator, b.fmt("{s}{s}.test.", .{ group.prefix, dotted })) catch @panic("OOM");
        }
    }
    if (prefixes.items.len == 0) return;
    const run = b.addRunArtifact(launch.launcher);
    run.setName(b.fmt("test-verify {s}", .{name}));
    run.addArtifactArg(test_exe);
    run.addArg(b.fmt("--name={s}", .{name}));
    for (prefixes.items) |prefix| run.addArg(b.fmt("--verify={s}", .{prefix}));
    if (launch.sanitize_thread) {
        // "Once under -Dsanitize-thread": the instrumented build is the
        // slow one, and a race needs no repetition to be seen.
        run.addArgs(&.{ "--verify-batched=1", "--verify-alone=0", "--sanitize-thread" });
        run.addPrefixedFileArg("--tsan-suppressions=", b.path("tools/test_launcher/tsan_suppressions.txt"));
    }
    if (launch.many_browsers) run.addArg("--many-browsers");
    // The row's names (tsan_skip, alone, slow), with the member's prefix.
    addGroupArgs(b, run, launch, &.{group}, launch.many_browsers, false);
    if (launch.jobs) |jobs| run.addArg(b.fmt("--jobs={d}", .{jobs}));
    run.addArg(b.fmt("--timeout={d}", .{launch.timeout}));
    run.addArg(b.fmt("--out=tmp/test-launch/{s}.verify{s}.jsonl", .{ name, if (launch.sanitize_thread) ".tsan" else "" }));
    run.setCwd(b.path("."));
    // A verification is a run, never a cache hit.
    run.has_side_effects = true;
    run.stdio = .inherit;
    v.step.dependOn(&run.step);
}

/// The verify files no directory executable took fail the step, by name.
fn finishTestVerify(b: *std.Build, v: *TestVerify) void {
    if (!v.asked) {
        v.step.dependOn(&b.addFail("test-verify: name the test files: -Dverify-files=tests/<dir>/<file>_test.zig,... (or -Dverify-base=main where there is a git checkout)").step);
        return;
    }
    if (v.files.len == 0) return; // nothing changed: nothing to verify
    for (v.files, v.matched) |file, matched| {
        if (!matched) v.step.dependOn(&b.addFail(b.fmt("test-verify: {s} is no test file of a suite this build makes (a tests/<dir>/**/*_test.zig file; select every suite: no -Dspec, or -Dspec=all)", .{file})).step);
    }
}

/// -Dsanitize-thread: ThreadSanitizer on every module of every test
/// executable `addSuiteRun` runs that is Crane's own - made by this build,
/// so not a dependency package's (curl, mbedTLS, zlib: their option sets
/// reject the option, and they stay uninstrumented, as do the C libraries
/// this build links as separate artifacts - brotli, the image codecs,
/// nghttp2 - which are not modules of the graph) - and never the V8
/// prebuilt, which is an archive. The C++ of a Crane module is instrumented
/// with it - except v8_wrapper.cpp, compiled apart against Chromium's libc++
/// (addV8Source, V8Link.wrapper_apart). Run at the end of `build`,
/// when every import is in place. A module the tests share with another
/// artifact of the same build is instrumented there too.
///
/// What the uninstrumented code does is invisible to TSAN except through
/// the calls it intercepts (pthread, malloc): a race inside V8 is not seen,
/// and V8's own atomics can make a report a false positive - suppressed
/// only when proven, in tools/test_launcher/tsan_suppressions.txt.
/// V8 15.7's v8::base::Mutex is an absl::Mutex (src/base/platform/mutex.h),
/// which synchronizes with futexes and atomics in uninstrumented code, so
/// ThreadSanitizer sees none of V8's own locking - only V8's calls into the
/// runtime's interceptors (memcpy, operator new/delete, free) - and reports
/// V8-internal handoffs as races (the first -Dsanitize-thread run on 15.7,
/// server1, lane v8up b3e: 336 reports in the snapshot generator, all in V8's
/// DefaultWorkerThreadsTaskRunner and heap). 13.1's base::Mutex was a pthread
/// mutex, which TSAN intercepts. Those reports are suppressed by V8's own
/// frames (tools/test_launcher/tsan_suppressions.txt, section 2), never by
/// dropping the interceptors' accesses (`ignore_interceptors_accesses`, b3e's
/// first answer): that also drops a Zig free or memcpy racing a Zig read,
/// the class verify mode exists for. The launcher names the file in every
/// test child's TSAN_OPTIONS; the snapshot generator, which links the same
/// instrumented modules, gets it from `useTsanSuppressions`.
const tsan_suppressions_path = "tools/test_launcher/tsan_suppressions.txt";

/// A run of an instrumented program outside the launcher (the snapshot
/// generator) reads the suppressions too: TSAN_OPTIONS names the file
/// relative to the build root, which becomes the run's working directory
/// (the runtime opens a relative path from there), and the file is an input
/// of the run, so a changed file runs it again.
fn useTsanSuppressions(b: *std.Build, run: *std.Build.Step.Run) void {
    run.setCwd(b.path("."));
    run.addFileInput(b.path(tsan_suppressions_path));
    run.setEnvironmentVariable("TSAN_OPTIONS", "suppressions=" ++ tsan_suppressions_path);
}

fn instrumentForThreadSanitizer(b: *std.Build, launch: *const TestLaunch) void {
    var seen: std.AutoHashMapUnmanaged(*std.Build.Module, void) = .empty;
    var stack: std.ArrayList(*std.Build.Module) = .empty;
    for (launch.test_exes.items) |exe| stack.append(b.allocator, exe.root_module) catch @panic("OOM");
    while (stack.pop()) |module| {
        if ((seen.getOrPut(b.allocator, module) catch @panic("OOM")).found_existing) continue;
        if (module.owner != b) continue;
        module.sanitize_thread = true;
        for (module.import_table.values()) |imported| stack.append(b.allocator, imported) catch @panic("OOM");
    }
}

/// Add the `*_test.zig` files under `dir_path` (recursively) to `step`, as ONE
/// test executable per directory.
///
/// One executable per directory, not per file: every test executable is a
/// separate root-module compile that re-analyses everything its imports reach,
/// and most of them reach the whole engine through `impls` - tests/v8 alone
/// had 53 executables, each a full analysis and a full V8 link. So the
/// directory's files are imported by one generated root, `<dir>/.all_tests.zig`,
/// written here when its file list changes: a module's root file must sit in
/// the directory its imports are resolved under, so it cannot live in the
/// cache, and generating it means a new test file joins its directory's
/// executable with no list to keep. The launcher (addSuiteRun) decides at
/// run time how the binary's tests share processes - a process per test, per
/// batch of 10, or the whole suite in one (`suite_configs`, -Dlaunch-batch) -
/// so a test must not assume it is the first, or the only one, to start the
/// engine.
///
/// `select.file`, a path such as `tests/v8/foo_test.zig` (-Dtest-file), builds
/// that one file as its own executable and skips every directory that does
/// not hold it - the quick red/green loop for a single test file.
///
/// Per-file executables (-Dtest-isolation=file, 1,592 of them, about four
/// times the CPU) are retired: `-Dlaunch-batch=1` runs every test in a process
/// of its own from these binaries (2026-11-01, lane tlaunch2).
fn addTestFilesFromDir(
    builder: *std.Build,
    step: *std.Build.Step,
    dir_path: []const u8,
    target: std.Build.ResolvedTarget,
    modules: []const std.Build.Module.Import,
    link_v8: bool,
    select: TestSelection,
) !void {
    const allocator = builder.allocator;
    const io = builder.graph.io;
    recordSuiteDir(builder, select, dir_path);

    if (select.file) |file| {
        if (!std.mem.startsWith(u8, file, dir_path) or file.len <= dir_path.len or file[dir_path.len] != '/') return;
        var dir_name: std.ArrayList(u8) = .empty;
        for (dir_path) |c| try dir_name.append(allocator, if (c == '/') '-' else c);
        _ = addTestRoot(builder, step, file, builder.fmt("{s}", .{std.fs.path.stem(file)}), dir_name.items, target, modules, link_v8, select.launch, select.v8);
        return;
    }

    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| {
        // Directory might not exist yet, skip silently
        if (err == error.FileNotFound) return;
        return err;
    };
    defer dir.close(io);

    var files: std.ArrayList([]const u8) = .empty;
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, "_test.zig")) continue;
        try files.append(allocator, try allocator.dupe(u8, entry.path));
    }
    if (files.items.len == 0) return;
    std.mem.sort([]const u8, files.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    var root: std.Io.Writer.Allocating = .init(allocator);
    try root.writer.writeAll(
        \\//! Generated by build.zig (addTestFilesFromDir): this directory's test
        \\//! files, compiled as one test executable. Gitignored and rewritten
        \\//! when the file list changes - do not edit.
        \\
        \\test {
        \\
    );
    for (files.items) |file| try root.writer.print("    _ = @import(\"{s}\");\n", .{file});
    try root.writer.writeAll("}\n");
    const contents = root.written();

    const root_path = builder.fmt("{s}/{s}", .{ dir_path, test_root_name });
    const current = dir.readFileAlloc(io, test_root_name, allocator, .limited(1 << 20)) catch "";
    if (!std.mem.eql(u8, current, contents)) {
        // Through a temporary and a rename, so a build reading the root
        // concurrently never sees half of it.
        const tmp_name = builder.fmt("{s}.{d}.tmp", .{ test_root_name, std.Thread.getCurrentId() });
        try dir.writeFile(io, .{ .sub_path = tmp_name, .data = contents });
        try dir.rename(tmp_name, dir, test_root_name, io);
    }

    var name: std.ArrayList(u8) = .empty;
    for (dir_path) |c| try name.append(allocator, if (c == '/') '-' else c);
    // -Dtest-binaries=v8: a directory `test` runs joins the one executable
    // (`finishOneBinary` decides whether it can, at the end of the build).
    if (select.one) |one| if (step == one.step) {
        try one.members.append(allocator, .{
            .dir_path = dir_path,
            .name = name.items,
            .files = files.items,
            .imports = try allocator.dupe(std.Build.Module.Import, modules),
            .link_v8 = link_v8,
            .target = target,
        });
        return;
    };
    const test_exe = addTestRoot(builder, step, root_path, name.items, null, target, modules, link_v8, select.launch, select.v8);
    addTestVerify(builder, select.launch, test_exe, name.items, dir_path, files.items);
}

/// -Dtest-binaries=v8, at the end of the build: the members that link V8,
/// whose imports agree and whose rows allow it (`OneBinary`) become ONE
/// executable, "tests", rooted at tests/.all_tests.zig; every other member
/// gets its own executable, as with -Dtest-binaries=dirs.
fn finishOneBinary(b: *std.Build, launch: *const TestLaunch, one: *OneBinary) !void {
    const allocator = b.allocator;
    const members = one.members.items;
    if (members.len == 0) return;
    // Each import name's module: the one most members give it
    // (tools/test_suites.zig importTable), keyed by the module's address.
    const keyed = try allocator.alloc([]const test_suites.Import, members.len);
    for (members, keyed) |m, *k| {
        const list = try allocator.alloc(test_suites.Import, m.imports.len);
        for (m.imports, list) |imp, *e| e.* = .{ .name = imp.name, .key = @intFromPtr(imp.module) };
        k.* = list;
    }
    const table = try test_suites.importTable(allocator, keyed);

    // A module whose root file another table module's root imports as a file
    // (test_suites.importsAsFile: src/webidl/root.zig's `codegen/root.zig`,
    // the `codegen` module's root) cannot share a compile with it once
    // anything reaches that declaration - "file exists in modules", measured
    // on the first one-binary build. The members that import such a module
    // keep their own executables.
    var claimed: std.AutoHashMapUnmanaged(usize, void) = .empty;
    {
        // A configure-time read of the checkout the configure cache cannot track.
        b.graph.poisonCache();
        var roots: std.ArrayList(struct { key: usize, path: []const u8 }) = .empty;
        for (members) |m| for (m.imports) |imp| {
            const source = imp.module.root_source_file orelse continue;
            if (source != .src_path or source.src_path.owner != b) continue;
            const key = @intFromPtr(imp.module);
            for (roots.items) |r| {
                if (r.key == key) break;
            } else try roots.append(allocator, .{ .key = key, .path = source.src_path.sub_path });
        };
        for (roots.items) |outer| {
            var text: ?[]const u8 = null;
            for (roots.items) |inner| {
                const rel = test_suites.pathFrom(outer.path, inner.path) orelse continue;
                if (text == null) text = b.root.root_dir.handle.readFileAlloc(b.graph.io, outer.path, allocator, .limited(16 << 20)) catch "";
                if (test_suites.importsAsFile(text.?, rel)) try claimed.put(allocator, inner.key, {});
            }
        }
    }

    var joined: std.ArrayList(OneBinary.Member) = .empty;
    var joined_dirs: std.ArrayList([]const u8) = .empty;
    for (members, keyed) |m, imports| {
        const config = suiteConfig(m.name);
        var fits = m.link_v8 and config.jobs == null and config.shuffle and config.state_checks == .fail and
            config.many_browsers == .fail and config.sanitize_thread == .fail and
            m.target.result.cpu.arch == members[0].target.result.cpu.arch and m.target.result.os.tag == members[0].target.result.os.tag;
        for (imports) |imp| {
            if (claimed.contains(imp.key)) fits = false;
        }
        if (fits and test_suites.agrees(&table, imports)) {
            try joined.append(allocator, m);
            try joined_dirs.append(allocator, m.dir_path);
            continue;
        }
        const root_path = b.fmt("{s}/{s}", .{ m.dir_path, test_root_name });
        const exe = addTestRoot(b, one.step, root_path, m.name, null, m.target, m.imports, m.link_v8, launch, one.v8);
        addTestVerify(b, launch, exe, m.name, m.dir_path, m.files);
    }
    if (joined.items.len == 0) return;

    // tests/.all_tests.zig: each member's own root, which imports its files.
    // Written as a directory's root is: through a temporary and a rename,
    // only when it changes.
    const contents = try test_suites.oneBinaryRoot(allocator, joined_dirs.items, test_root_name);
    const io = b.graph.io;
    var tests_dir = try std.Io.Dir.cwd().openDir(io, "tests", .{});
    defer tests_dir.close(io);
    const current = tests_dir.readFileAlloc(io, test_root_name, allocator, .limited(1 << 20)) catch "";
    if (!std.mem.eql(u8, current, contents)) {
        const tmp_name = b.fmt("{s}.{d}.tmp", .{ test_root_name, std.Thread.getCurrentId() });
        try tests_dir.writeFile(io, .{ .sub_path = tmp_name, .data = contents });
        try tests_dir.rename(tmp_name, tests_dir, test_root_name, io);
    }

    var groups: std.ArrayList(SuiteGroup) = .empty;
    var link_v8 = false;
    for (joined.items) |m| {
        link_v8 = link_v8 or m.link_v8;
        try groups.append(allocator, .{ .prefix = try test_suites.memberPrefix(allocator, m.dir_path), .config = suiteConfig(m.name), .plain = !m.link_v8 });
    }
    // The table's names a joined member imports, with their modules.
    var imports: std.ArrayList(std.Build.Module.Import) = .empty;
    for (joined.items) |m| for (m.imports) |imp| {
        for (imports.items) |have| {
            if (std.mem.eql(u8, have.name, imp.name)) break;
        } else try imports.append(allocator, imp);
    };
    const exe = addTestRootWith(b, one.step, b.fmt("tests/{s}", .{test_root_name}), "tests", null, joined.items[0].target, imports.items, link_v8, launch, one.v8, groups.items);
    for (joined.items, groups.items) |m, g| addTestVerifyIn(b, launch, exe, m.name, m.dir_path, m.files, g);
}

fn addTestRoot(
    builder: *std.Build,
    step: *std.Build.Step,
    root_path: []const u8,
    name: []const u8,
    config_name: ?[]const u8,
    target: std.Build.ResolvedTarget,
    modules: []const std.Build.Module.Import,
    link_v8: bool,
    launch: *const TestLaunch,
    v8: V8Link,
) *std.Build.Step.Compile {
    return addTestRootWith(builder, step, root_path, name, config_name, target, modules, link_v8, launch, v8, &.{});
}

/// `addTestRoot` for an executable that holds several suites' tests
/// (`OneBinary`, `addSuiteRunWith`).
fn addTestRootWith(
    builder: *std.Build,
    step: *std.Build.Step,
    root_path: []const u8,
    name: []const u8,
    config_name: ?[]const u8,
    target: std.Build.ResolvedTarget,
    modules: []const std.Build.Module.Import,
    link_v8: bool,
    launch: *const TestLaunch,
    v8: V8Link,
    groups: []const SuiteGroup,
) *std.Build.Step.Compile {
    const test_exe = builder.addTest(.{
        .name = name,
        .root_module = builder.createModule(.{
            .root_source_file = builder.path(root_path),
            .target = target,
            .imports = modules,
        }),
    });

    // tests/support: fixtures every test directory shares - each its own
    // module, since a test root cannot import a file outside its directory.
    // loopback_listener: an accept loop a fixture stops without closing the
    // listener under it (lane fixes1).
    test_exe.root_module.addImport("loopback_listener", builder.createModule(.{
        .root_source_file = builder.path("tests/support/loopback_listener.zig"),
        .target = target,
    }));

    // Link V8 libraries if requested (for V8 tests)
    if (link_v8) linkV8(builder, test_exe.root_module, v8);

    // The many-Browsers variant's busy Browser needs the browser module: a
    // suite that links V8 without it (tests/dom, tests/v8) gets the testing
    // graph's, the one its own modules belong to.
    if (link_v8 and launch.many_browsers and test_exe.root_module.import_table.get("browser") == null) {
        if (launch.browser_module) |browser_mod| test_exe.root_module.addImport("browser", browser_mod);
    }

    // The engine, for the Crane test runner's live counters (agents, Global
    // handles): the executable's own, the one its runtime is bound to - this
    // root is the executable's alone, so the import reaches nothing else.
    if (link_v8 and test_exe.root_module.import_table.get("engine") == null) {
        if (test_exe.root_module.import_table.get("runtime")) |runtime_mod| {
            if (runtime_mod.import_table.get("engine")) |engine_mod| test_exe.root_module.addImport("engine", engine_mod);
        }
    }

    step.dependOn(&addSuiteRunWith(builder, launch, test_exe, name, config_name, groups).step);
    // A -Dtest-file executable is named after its file and takes its
    // directory's row (`config_name`).
    if (link_v8 and holdsTestsV8(config_name orelse name, groups)) {
        if (addEngineLateRun(builder, launch, test_exe, name, groups)) |late| step.dependOn(&late.step);
    }
    return test_exe;
}

/// Whether the executable `name` (with `groups`, a joined one's members)
/// holds tests/v8's tests.
fn holdsTestsV8(name: []const u8, groups: []const SuiteGroup) bool {
    if (std.mem.eql(u8, name, "tests-v8")) return true;
    for (groups) |g| if (std.mem.eql(u8, g.prefix, "v8.")) return true;
    return false;
}

/// tests/v8's platform start tests once more, each in a process whose start
/// skipped engine.initializeBeforeThreadCreation (CRANE_TEST_ENGINE_EARLY=0,
/// which the Crane test runner reads): there V8 starts on a later thread
/// beside threads that already exist, and its platform must give it no
/// thread-isolated allocator - the fallback of every host that skips the
/// call, which would otherwise fault on x86-64 Linux (lane linux1; the
/// integrator's ruling, 2026-11-08). The same executable, so nothing more
/// is compiled; only the plain run has it (a variant or a -Dtest-filter run
/// selects its own tests).
fn addEngineLateRun(b: *std.Build, launch: *const TestLaunch, test_exe: *std.Build.Step.Compile, name: []const u8, groups: []const SuiteGroup) ?*std.Build.Step.Run {
    if (launch.sanitize_thread or launch.many_browsers or launch.filters.len != 0) return null;
    const run = b.addRunArtifact(launch.launcher);
    run.setName(b.fmt("test {s} (engine started late)", .{name}));
    run.stdio = .zig_test;
    run.addArtifactArg(test_exe);
    run.addArg(b.fmt("--name={s}-engine-late", .{name}));
    // A process per test: each race needs a process where nothing has
    // started V8 yet.
    run.addArg("--batch=1");
    run.addArg(b.fmt("--launch-seed={s}", .{launch.seed}));
    run.addArg(b.fmt("--timeout={d}", .{launch.timeout}));
    addGroupArgs(b, run, launch, groups, false, false);
    // The leading `*` takes the joined executable's "v8." prefix too: the
    // launcher strips a group's prefix only for a group it is told of, and
    // this run passes no batches (a bare "platform_start_once_test*" ran
    // nothing in the joined "tests" on server1, lane linux1).
    run.addArg("--filter=*platform_start_once_test.*");
    // Its results beside the suite's own, never over them; the order is the
    // plain run's (as a filtered run's is).
    run.addArg(b.fmt("--out=tmp/test-launch/{s}.engine-late.jsonl", .{name}));
    run.addArg(b.fmt("--timings=tmp/test-launch/{s}.jsonl", .{name}));
    run.setCwd(b.path("."));
    run.setEnvironmentVariable("CRANE_TEST_ENGINE_EARLY", "0");
    if (std.mem.eql(u8, launch.seed, "random")) run.has_side_effects = true;
    return run;
}

/// An executable that is compiled and never linked - nothing asks for its
/// binary, so Zig analyses all the Zig it reaches (-fno-emit-bin) and still
/// compiles v8_wrapper.cpp, but links nothing: no V8 archive, no system
/// library is read. For a check (check-target, crane-check), never installed.
fn addCompileCheck(
    b: *std.Build,
    name: []const u8,
    root_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
    v8: V8Link,
) *std.Build.Step.Compile {
    const check = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_path),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    addV8Source(b, check.root_module, v8, &.{});
    addCrossLibraryStubs(b, check.root_module, target);
    return check;
}

/// The system libraries a module graph names (configureStorageBackends:
/// sqlite3 and leveldb on Linux) are resolved when the compiler starts, even
/// for a compile that links nothing (-fno-emit-bin), and a Linux cross-compile
/// from macOS has no sysroot to find them in: "unable to find dynamic system
/// library 'sqlite3' ... searched paths: none", before any Zig is analysed.
///
/// So a compile-only check of a foreign Linux target gets empty shared
/// libraries of those names, built from an empty file into the build's own
/// output (the cache, never the source tree) and put on that check's own root
/// module, which nothing else imports. They satisfy name resolution and
/// nothing else: no artifact that links may receive them (build() asserts
/// that neither compile-only check is asked for its binary), and anything
/// linked for Linux needs the real libraries. A real Linux sysroot replaces
/// them - pass its libraries instead and delete this function.
fn addCrossLibraryStubs(b: *std.Build, module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    const host = b.graph.host.result;
    if (target.result.os.tag != .linux or (host.os.tag == .linux and host.cpu.arch == target.result.cpu.arch)) return;
    const empty = b.addWriteFiles().add("stub.zig", "");
    for ([_][]const u8{ "sqlite3", "leveldb" }) |library| {
        const stub = b.addLibrary(.{
            .name = library,
            .linkage = .dynamic,
            .root_module = b.createModule(.{ .root_source_file = empty, .target = target }),
        });
        module.addLibraryPath(stub.getEmittedBinDirectory());
    }
}

/// The flags every compile of v8_wrapper.cpp passes: C++20 without exceptions
/// or RTTI, and the defines V8's public headers must see to agree with the
/// archive the artifact links - the V8 ones (pointer compression, the
/// sandbox) and the cppgc ones, in this one place.
///
/// An archive built against Chromium's libc++ (-Dv8=15.7) says all of them
/// itself: its include/ holds the build's v8-gn.h, which v8config.h includes
/// under -DV8_GN_HEADER (V8 BUILD.gn v8_generate_external_defines_header), and
/// its libcxx/flags.txt the defines GN compiles every consumer of that libc++
/// with (`V8Link.libcxx_flags`, read by `loadV8Link`). Nothing is kept by hand
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
fn v8WrapperFlags(b: *std.Build, v8: V8Link, archive_os: std.Target.Os.Tag, extra: []const []const u8) []const []const u8 {
    if (v8.archives.chromium != null) {
        const from_archive = [_][]const u8{ "-std=c++20", "-fno-exceptions", "-fno-rtti", "-DV8_GN_HEADER" };
        return std.mem.concat(b.allocator, []const u8, &.{ &from_archive, v8.libcxx_flags, extra }) catch @panic("OOM");
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

/// How a build links V8: the archives -Dv8, -Dv8-build and the target's OS
/// select (tools/v8_archives.zig) and, for an archive built against
/// Chromium's libc++ (-Dv8=15.7), what `loadV8Link` reads from beside it at
/// configure time: that libc++'s consumer flags and the system libraries the
/// archive's own link names. Passed in, so every artifact links the same V8.
const V8Link = struct {
    archives: v8_archives.Archives,
    /// libcxx/flags.txt's -D defines and -nostdinc++ (its directories are
    /// added by `addV8Source`, relative and as -I).
    libcxx_flags: []const []const u8 = &.{},
    /// system-libs.txt's `-framework X` entries.
    frameworks: []const []const u8 = &.{},
    /// system-libs.txt's `-lX` entries.
    system_libs: []const []const u8 = &.{},
    /// -Dsanitize-thread with an archive built against Chromium's libc++: the
    /// V8-facing C++ (v8_wrapper.cpp) is compiled apart, as a static library
    /// of its own, uninstrumented (`addV8Source`).
    wrapper_apart: bool = false,
    /// The build's engine, when it cannot be built (another adapter that
    /// links nothing yet, or no V8 for this target or these options): nothing
    /// of `archives` is read, and what would link V8 fails with the engine's
    /// reason instead (`addV8Source`).
    unavailable: ?*const engine_build.Engine = null,
};

/// The V8Link of the build's engine: the archives the V8 adapter resolved
/// (its build file: -Dv8, -Dv8-build and the target's OS) and, for an archive
/// built against Chromium's libc++, the facts it keeps beside itself
/// (scripts/build-v8-15.7.sh writes them from GN's own compile and d8's own
/// link). A configure-time read the configuration cache cannot see change, so
/// it is poisoned; a host without the archive gets the reason and how to get
/// it, and the build stops. An engine that cannot be built - another adapter,
/// or no V8 for this build - has no archives: its link is `unavailable`.
/// TRANSITIONAL: this and the link functions below move into the V8
/// adapter's build file with the design's batch E2, behind the protocol.
fn loadV8Link(b: *std.Build, engine: *const engine_build.Engine) V8Link {
    const resolved = engine.resolvedOf(.v8) orelse return .{
        .archives = .{ .dir = "", .monolith = "", .libplatform = "", .libbase = "" },
        .unavailable = engine,
    };
    const archives = resolved.archives;
    const chromium = archives.chromium orelse return .{ .archives = archives };
    b.graph.poisonCache();
    const dir = b.root.root_dir.handle;
    const flags_text = dir.readFileAlloc(b.graph.io, chromium.libcxx_flags, b.allocator, .limited(1 << 16)) catch |err| noV8Archive(chromium.libcxx_flags, err);
    const libs_text = dir.readFileAlloc(b.graph.io, chromium.system_libs, b.allocator, .limited(1 << 16)) catch |err| noV8Archive(chromium.system_libs, err);
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
    return .{ .archives = archives, .libcxx_flags = flags.items, .frameworks = frameworks.items, .system_libs = system_libs.items };
}

fn noV8Archive(path: []const u8, err: anyerror) noreturn {
    std.debug.print("Error: -Dv8=15.7 needs {s} ({s}) on this host: build the archive with scripts/build-v8-15.7.sh, or copy jsengines/v8/15.7.112.43 from a host of the same OS and check it with its SHA256SUMS\n", .{ path, @errorName(err) });
    std.process.exit(1);
}

/// The V8 wrapper's source and headers on `module`: v8_wrapper.cpp with
/// v8WrapperFlags, then the include directories. For an archive built against
/// Chromium's libc++ that libc++'s three directories come first, as -I
/// (addIncludePath): Zig puts its own -isystem directories (clang's builtins,
/// the C library's) before any a module adds, so as -isystem they would follow
/// the C library's and <cstdio> would find its <stdio.h> instead of libc++'s
/// (scripts/build-v8-15.7.sh, step_smoke). Then V8's include/. Zig's own
/// libc++ only for 13.1: with 15.7 the binary holds Chromium's, alone.
///
/// -Dsanitize-thread (`V8Link.wrapper_apart`) with such an archive: Zig links
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
/// instrumented (instrumentForThreadSanitizer). What this gives up: races
/// inside v8_wrapper.cpp itself, which 13.1's build instrumented, and its
/// UBSan checks in the sanitizer build (sanitize_c off for the library: the
/// UBSan runtime would be a second one beside the artifact's). On Linux the
/// runtime and Chromium's libc++abi both define the __cxa_guard functions:
/// CRANE_V8_WRAPPER_APART_FOR_TSAN gives v8_wrapper.cpp weak ones that keep
/// libc++abi's from being linked, so the runtime's win (see there).
fn addV8Source(builder: *std.Build, module: *std.Build.Module, v8: V8Link, extra: []const []const u8) void {
    // An engine that cannot be built: whatever takes this module fails with
    // the adapter's reason, and nothing of V8 is added.
    if (v8.unavailable) |engine| return engine.failModule(builder, module);
    if (v8.wrapper_apart and v8.archives.chromium != null) {
        const wrapper = builder.addLibrary(.{
            .name = "v8_wrapper",
            .linkage = .static,
            .root_module = builder.createModule(.{
                .target = module.resolved_target,
                .optimize = module.optimize orelse .Debug,
                .link_libc = true,
                .sanitize_c = .off,
            }),
        });
        const flags = std.mem.concat(builder.allocator, []const u8, &.{ extra, &.{"-DCRANE_V8_WRAPPER_APART_FOR_TSAN=1"} }) catch @panic("OOM");
        addV8SourceTo(builder, wrapper.root_module, v8, flags);
        module.linkLibrary(wrapper);
        module.link_libc = true;
        return;
    }
    addV8SourceTo(builder, module, v8, extra);
}

/// `addV8Source`'s compile of v8_wrapper.cpp into `module`.
fn addV8SourceTo(builder: *std.Build, module: *std.Build.Module, v8: V8Link, extra: []const []const u8) void {
    module.addCSourceFile(.{
        .file = builder.path("src/runtime/engines/v8/v8_wrapper.cpp"),
        .flags = v8WrapperFlags(builder, v8, module.resolved_target.?.result.os.tag, extra),
    });
    if (v8.archives.chromium) |chromium| for (chromium.libcxx_include) |dir| module.addIncludePath(.{ .cwd_relative = dir });
    module.addIncludePath(.{ .cwd_relative = v8.archives.include });
    if (v8.archives.chromium == null) module.link_libcpp = true else module.link_libc = true;
}

/// V8's archives on `module`, and the C++ runtime and system libraries they
/// need: Zig's libc++ for 13.1; for 15.7 Chromium's libc++ (libc++_chromium.a),
/// Temporal's Rust (librust_v8.a) and the archive's frameworks and libraries.
fn addV8Archives(module: *std.Build.Module, v8: V8Link) void {
    if (v8.unavailable != null) return;
    module.addObjectFile(.{ .cwd_relative = v8.archives.monolith });
    module.addObjectFile(.{ .cwd_relative = v8.archives.libplatform });
    module.addObjectFile(.{ .cwd_relative = v8.archives.libbase });
    if (v8.archives.chromium) |chromium| {
        module.addObjectFile(.{ .cwd_relative = chromium.libcxx });
        module.addObjectFile(.{ .cwd_relative = chromium.rust });
        for (v8.frameworks) |framework| module.linkFramework(framework, .{});
        for (v8.system_libs) |library| module.linkSystemLibrary(library, .{});
    }
}

/// Link the V8 C++ wrapper and V8's archives into `module`.
///
/// `module` must be one the caller owns exclusively - a module created for a
/// single artifact, never one shared through `addImport`. A module's link
/// objects belong to every artifact downstream of it, so linking V8 into a
/// shared module puts a second `v8_wrapper.cpp` into each consumer that
/// already compiles one: 844 duplicate symbol definitions, measured.
///
/// `v8`: what `build()` selected (-Dv8, -Dv8-build and the target's OS,
/// tools/v8_archives.zig) - passed in, so every artifact links the same V8.
fn linkV8(builder: *std.Build, module: *std.Build.Module, v8: V8Link) void {
    addV8Source(builder, module, v8, &.{});
    addV8Archives(module, v8);
}

/// A `zig test` artifact for an existing module's own test tree, with V8 linked.
///
/// `b.addTest(.{ .root_module = mod })` does **not** give the test its own
/// module: the Compile's `root_module` *is* `mod`, shared with every artifact
/// that imports it. Linking V8 there would add `v8_wrapper.cpp` and the three
/// archives to `crane`, `wpt_runner`, `full_static_lib` and the rest - each of
/// which already adds them - and the link would fail on duplicate symbols.
///
/// So clone: same root source file, same import table, its own link objects.
/// Call this only after the module's last `addImport`, or the clone's import
/// table comes out short.
fn addModuleTestWithV8(
    builder: *std.Build,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    v8: V8Link,
) *std.Build.Step.Compile {
    const test_mod = builder.createModule(.{
        .root_source_file = mod.root_source_file,
        .target = target,
    });
    for (mod.import_table.keys(), mod.import_table.values()) |name, dep| {
        test_mod.addImport(name, dep);
    }
    linkV8(builder, test_mod, v8);
    return builder.addTest(.{ .root_module = test_mod });
}

/// The engine protocol (src/runtime/engine_protocol.zig) bound to the
/// adapter at `adapter_root`, over `runtime`: a facade and adapter pair of
/// their own, for a test compile whose graph holds no other binding - one
/// file belongs to one module per compile, so two bindings of the facade
/// cannot meet in one.
/// A runtime module for a compile with no V8 in it, bound to the engine
/// protocol over `adapter_root`: runtime_mod's imports except v8 and engine,
/// and the facade the adapter makes (which imports this runtime).
fn runtimeTier(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    runtime_mod: *std.Build.Module,
    adapter_root: std.Build.LazyPath,
) struct { runtime: *std.Build.Module, engine: *std.Build.Module } {
    const tier = builder.createModule(.{
        .root_source_file = runtime_mod.root_source_file,
        .target = target,
    });
    for (runtime_mod.import_table.keys(), runtime_mod.import_table.values()) |import_name, dep| {
        if (std.mem.eql(u8, import_name, "v8") or std.mem.eql(u8, import_name, "engine")) continue;
        tier.addImport(import_name, dep);
    }
    const facade = engineProtocolBinding(builder, target, tier, adapter_root);
    tier.addImport("engine", facade);
    return .{ .runtime = tier, .engine = facade };
}

fn engineProtocolBinding(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    runtime: *std.Build.Module,
    adapter_root: std.Build.LazyPath,
) *std.Build.Module {
    const facade = builder.createModule(.{ .root_source_file = builder.path("src/runtime/engine_protocol.zig"), .target = target });
    facade.addImport("runtime", runtime);
    const adapter = builder.createModule(.{ .root_source_file = adapter_root, .target = target });
    adapter.addImport("engine", facade);
    facade.addImport("engine_impl", adapter);
    return facade;
}

/// The iPhoneOS SDK root: `-Dios-sdk=<path>` when given, else what `xcrun`
/// names, else null.
///
/// Queried rather than hardcoded: the SDK version moves with Xcode, and a stale
/// path fails as missing libc headers rather than as a missing SDK. The option
/// is for a machine whose xcode-select names the Command Line Tools, which
/// have no iPhoneOS SDK: the pool hosts are set up that way and link their
/// Xcode's SDK at ~/sdks/iPhoneOS.sdk (`zig build check-ios -Dios-sdk=$HOME/sdks/iPhoneOS.sdk`).
/// build() declares the option; this reads it, since one option cannot be
/// declared twice and every caller here holds only `b`.
fn iosSdkPath(b: *std.Build) ?[]const u8 {
    if (b.user_input_options.get("ios-sdk")) |option| switch (option) {
        .scalar => |path| return path,
        else => {},
    };
    // A configure-time probe of the machine: the configure cache cannot see
    // what xcrun answers, so a cached configuration must not be reused.
    b.graph.poisonCache();
    var code: u8 = 0;
    const out = b.runAllowFail(
        &.{ "xcrun", "--sdk", "iphoneos", "--show-sdk-path" },
        &code,
        .ignore,
    ) catch return null;
    const path = std.mem.trim(u8, out, " \n\r\t");
    if (path.len == 0) return null;
    return b.dupe(path);
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
fn applyIosSdkRecursively(b: *std.Build, root: *std.Build.Step, sdk: ?[]const u8) void {
    if (sdk == null) return;
    applyIosSdkStep(b, root, sdk, 0);
}

fn applyIosSdkStep(b: *std.Build, step: *std.Build.Step, sdk: ?[]const u8, depth: u32) void {
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
fn addIosSdkPaths(module: *std.Build.Module, sdk: ?[]const u8) void {
    const root = sdk orelse return;
    module.addSystemIncludePath(.{ .cwd_relative = std.fmt.allocPrint(
        module.owner.allocator,
        "{s}/usr/include",
        .{root},
    ) catch @panic("OOM") });
    module.addLibraryPath(.{ .cwd_relative = std.fmt.allocPrint(
        module.owner.allocator,
        "{s}/usr/lib",
        .{root},
    ) catch @panic("OOM") });
    module.addFrameworkPath(.{ .cwd_relative = std.fmt.allocPrint(
        module.owner.allocator,
        "{s}/System/Library/Frameworks",
        .{root},
    ) catch @panic("OOM") });
}

/// A C header set translated to Zig by the build: what a file's `@cImport`
/// was, before Zig 0.17 removed `@cImport` (roadmap zig-017; works on 0.16
/// and 0.17, where Step.TranslateC is deprecated but present). The file
/// imports the result by name (`const c = @import("curl_c");`).
///
/// `@cImport` translated against its module's include paths and C macros; a
/// translate-c step sees only its own, so each set names them: `libs`'
/// installed headers (what linkLibrary gave the module), `macros` (what
/// addCMacro gave it), `system_libs` (linkSystemLibrary's pkg-config flags)
/// and, for aarch64-ios, the SDK's usr/include - which kit/posix's time.h
/// never had (the iOS lib-full break since de4a36b9529a).
///
/// ONE module per header set per graph: two translate-c modules with the same
/// inputs have the same output file, and a file in two modules of one compile
/// is an error. So a set two importers in one graph share is made once and
/// handed to both (PlatformBinding.c_time, for tests/platform).
///
/// Translated as Debug: none of these headers tests __OPTIMIZE__ or NDEBUG
/// (curl 8.18, mbedTLS 3.6.6, Brotli, image_codecs.h and <time.h>; checked
/// 2026-10-29), so the result is the same in every mode the importers build.
/// The threading configuration buildStaticLibcurl compiles mbedTLS with, which
/// every translation of its headers must see too.
const mbedtls_threading_macros = [_][2][]const u8{ .{ "MBEDTLS_THREADING_C", "" }, .{ "MBEDTLS_THREADING_PTHREAD", "" } };

const CImport = struct {
    includes: []const []const u8,
    libs: []const *std.Build.Step.Compile = &.{},
    macros: []const [2][]const u8 = &.{},
    system_libs: []const []const u8 = &.{},
};

fn addCImport(b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, spec: CImport) *std.Build.Module {
    var text: std.ArrayList(u8) = .empty;
    for (spec.includes) |include| text.print(b.allocator, "#include <{s}>\n", .{include}) catch @panic("OOM");
    const header = b.addWriteFiles().add(b.fmt("{s}.h", .{name}), text.items);
    const translate = b.addTranslateC(.{ .root_source_file = header, .target = target, .optimize = .Debug, .link_libc = true });
    for (spec.libs) |lib| translate.addIncludePath(lib.getEmittedIncludeTree());
    for (spec.macros) |macro| translate.defineCMacro(macro[0], macro[1]);
    for (spec.system_libs) |lib| translate.linkSystemLibrary(lib, .{});
    if (target.result.os.tag == .ios) if (iosSdkPath(b)) |sdk| {
        translate.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/usr/include", .{sdk}) });
    };
    return translate.createModule();
}

/// The platform a module graph is built for (docs/platform-protocol.md 1.1):
/// a built-in one, or `external` - the implementation -Dplatform-module names.
const Platform = enum {
    darwin,
    linux,
    testing,
    external,

    /// The platform a target gets by default: darwin for macOS and iOS, linux
    /// for Linux; null where Crane has no built-in platform (pass
    /// -Dplatform-module).
    fn ofTarget(target: std.Build.ResolvedTarget) ?Platform {
        return switch (target.result.os.tag) {
            .macos, .ios => .darwin,
            .linux => .linux,
            else => null,
        };
    }
};

/// The capabilities -Dplatform-without may name: src/platform/protocol.zig's
/// Capabilities fields. The facade checks the names again at compile time;
/// this list only makes a typo fail before any compile starts.
const platform_capability_names = [_][]const u8{
    "image_decoding",
    "image_encoding",
    "font_decoding",
    "brotli",
    "persistent_storage",
    "file_urls",
    "system_trust_store",
    "http2",
    "http3",
    "thread_qos",
    "resident_memory",
    "layout",
    "os_permissions",
    "simple_dialogs",
    "printing",
    "file_picker",
    "windows",
    "media_decoding",
    "webcodecs",
    "media_capabilities",
    "encrypted_media",
    "camera",
    "microphone",
    "screen_capture",
    "audio_output",
    "speech_synthesis",
    "speech_recognition",
    "clipboard",
    "notifications",
    "push",
    "background_sync",
    "background_fetch",
    "geolocation",
    "sensors",
    "device_orientation",
    "usb",
    "hid",
    "serial",
    "bluetooth",
    "nfc",
    "midi",
    "gamepad",
    "payment",
    "webauthn",
    "identity_credentials",
    "share",
    "contacts",
    "fullscreen",
    "pointer_lock",
    "keyboard_lock",
    "wake_lock",
    "idle_detection",
    "battery",
    "vibration",
    "badging",
    "eyedropper",
    "local_fonts",
    "keyboard_map",
    "screen_details",
    "presentation",
    "remote_playback",
    "picture_in_picture",
    "media_session",
    "network_information",
    "compute_pressure",
    "device_posture",
    "virtual_keyboard",
    "protocol_handlers",
    "address_space",
};

/// The link-plan items -Dplatform-static may name (contract section 10): a
/// platform compiles the kit's static implementation of each instead of
/// linking the system library. `all` names every one.
const platform_static_items = [_][]const u8{ "sqlite", "zlib", "brotli", "crypto", "trust_store", "curl", "nghttp2", "all" };

/// A comma-separated option as a list of names, each checked against `valid`.
fn optionList(b: *std.Build, option: []const u8, value: ?[]const u8, valid: []const []const u8) []const []const u8 {
    const text = value orelse return &.{};
    var names: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeScalar(u8, text, ',');
    while (it.next()) |raw| {
        const name = std.mem.trim(u8, raw, " ");
        for (valid) |v| {
            if (std.mem.eql(u8, v, name)) break;
        } else {
            std.debug.print("Error: -D{s} names '{s}', which is not one of: ", .{ option, name });
            for (valid, 0..) |v, i| std.debug.print("{s}{s}", .{ if (i == 0) "" else ", ", v });
            std.debug.print("\n", .{});
            std.process.exit(1);
        }
        names.append(b.allocator, b.dupe(name)) catch @panic("OOM");
    }
    return names.items;
}

/// What every module graph shares, decided once in build().
const ModuleConfig = struct {
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    debug_options: *std.Build.Step.Options,
    /// The dom module's own options (refcount_audit).
    dom_options: *std.Build.Step.Options,
    /// The engine adapter's own options, from its build file (the engine's `adapterOptions`).
    engine_adapter_options: *std.Build.Step.Options,
    engine_choice: []const u8,
    use_system_curl: bool,
    enable_http2: bool,
    /// libcurl and its mbedTLS, built once for every graph (null with
    /// -Dsystem-curl or when the lazy dependencies are not fetched yet).
    static_libcurl: ?StaticLibcurl,
    brotli: ?BrotliLibraries,
    image_codecs: ?*std.Build.Step.Compile,
    /// The graph whose modules are registered by name for dependent packages.
    public_platform: Platform,
    /// -Dplatform-without, -Dplatform-static and -Dplatform-module.
    platform_without: []const []const u8,
    platform_static: []const []const u8,
    platform_module: ?[]const u8,
    /// Tables computed once by build steps and embedded (`addGeneratedTables`).
    tables: GeneratedTables,
};

/// Tables a build step computes once and Zig caches, which modules embed with
/// `@embedFile` of an anonymous import (lane compiletime1, 2026-11-04). Each
/// was computed at compile time in every binary that reached it - about 9 s of
/// single-threaded Sema per test binary (lane onebin2's time report). Their
/// tools' tests run in `zig build test`; the tables' identity with what the
/// compile-time code made is pinned by tests/encoding/
/// reverse_index_table_test.zig and tests/url/psl_table_test.zig.
const GeneratedTables = struct {
    /// src/encoding/reverse_index.zig's five tables, by
    /// `reverse_index_table_names` (tools/encoding/reverse_index_table.zig).
    reverse_index: [reverse_index_table_names.len]std.Build.LazyPath,
    /// src/url/public_suffix.zig's rule table (tools/url/psl_table.zig).
    psl: std.Build.LazyPath,
    /// The tools' root modules, whose tests `zig build test` runs.
    reverse_index_tool: *std.Build.Module,
    psl_tool: *std.Build.Module,
};

/// The reverse indexes, in the order tools/encoding/reverse_index_table.zig
/// takes its output paths; each forward index is the tool's module
/// `<name>_index`, and each table the encoding module's import
/// `reverse_index_<name>`.
const reverse_index_table_names = [_][]const u8{ "jis0208", "jis0212", "big5", "gb18030", "euc_kr" };
const reverse_index_forward_indexes = [_][]const u8{
    "src/encoding/japanese/jis0208_index.zig",
    "src/encoding/japanese/jis0212_index.zig",
    "src/encoding/chinese/big5_index.zig",
    "src/encoding/chinese/gb18030_index.zig",
    "src/encoding/korean/euc_kr_index.zig",
};

/// The generated tables' tools, run once per build (`GeneratedTables`).
fn addGeneratedTables(b: *std.Build) GeneratedTables {
    const reverse_index_module = b.createModule(.{
        .root_source_file = b.path("tools/encoding/reverse_index_table.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    for (reverse_index_table_names, reverse_index_forward_indexes) |name, path| {
        reverse_index_module.addAnonymousImport(b.fmt("{s}_index", .{name}), .{ .root_source_file = b.path(path) });
    }
    const reverse_index_run = b.addRunArtifact(b.addExecutable(.{ .name = "reverse_index_table", .root_module = reverse_index_module }));
    var reverse_index: [reverse_index_table_names.len]std.Build.LazyPath = undefined;
    for (reverse_index_table_names, &reverse_index) |name, *table| table.* = reverse_index_run.addOutputFileArg(b.fmt("{s}.bin", .{name}));

    const psl_module = b.createModule(.{
        .root_source_file = b.path("tools/url/psl_table.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const psl_run = b.addRunArtifact(b.addExecutable(.{ .name = "psl_table", .root_module = psl_module }));
    psl_run.addFileArg(b.path("src/url/public_suffix_data.zig"));
    const psl = psl_run.addOutputFileArg("psl_table.bin");

    return .{ .reverse_index = reverse_index, .psl = psl, .reverse_index_tool = reverse_index_module, .psl_tool = psl_module };
}

/// The platform protocol's modules for one platform (docs/platform-protocol.md
/// section 1): the facade `platform` (src/platform/protocol.zig), the bound
/// implementation `platform_impl`, the kit parts it composes and this
/// binding's `platform_options`. The facade's comptime check holds the
/// implementation to the contract whenever the facade is compiled.
const PlatformBinding = struct {
    facade: *std.Build.Module,
    options: *std.Build.Module,
    /// kit/curl's connection share (src/platform/kit/curl/share.zig), which
    /// `fetch` imports for a Browser's network context until transfers move
    /// behind the platform's port. A module of its own that imports nothing:
    /// a graph whose `fetch` is compiled beside the old platform root (tests/
    /// platform/retained_old_platform.zig) must not reach the facade's files.
    kit_curl_share: *std.Build.Module,
    /// kit/sfnt and kit/inflate, whose own test blocks the platform tests
    /// run (decision 20).
    kit_sfnt: *std.Build.Module,
    kit_inflate: *std.Build.Module,
    /// kit/media_decoding, the built-in media decoders (lane wptcfg D4),
    /// whose own test blocks the platform tests run.
    kit_media_decoding: *std.Build.Module,
    /// <time.h> translated (addCImport), which kit/posix imports as `c_time`;
    /// tests/platform takes the same module (one per header set per graph).
    c_time: *std.Build.Module,
};

const PlatformBindingOptions = struct {
    platform: Platform,
    /// -Dplatform-module's root, for `.external`.
    module_path: ?[]const u8 = null,
    without: []const []const u8 = &.{},
    static: []const []const u8 = &.{},
    http2: bool,
    libcurl: ?*std.Build.Step.Compile,
    /// The mbedTLS libcurl links (StaticLibcurl.mbedtls): kit/curl's trust
    /// store parses certificates with it and hands curl's TLS configuration
    /// the chain. Null with a system libcurl, whose TLS library is its own.
    mbedtls: ?*std.Build.Step.Compile = null,
    brotli: ?BrotliLibraries,
    image_codecs: ?*std.Build.Step.Compile,
    /// Register the facade by name (the public graph).
    public: bool = false,
    /// Today's bridges, which kit/posix wraps and the facade's TRANSITIONAL
    /// timer_backend reads.
    clock: *std.Build.Module,
    host: *std.Build.Module,
    memory: *std.Build.Module,
    /// MIME Sniffing's parser, which kit/media_decoding's canPlayType parses
    /// a type with: one parser in Crane, not a copy in the platform. Pure
    /// Zig over `infra` (whose only import is the clock bridge), so no part
    /// of it reaches back to the facade.
    mimesniff: *std.Build.Module,
};

fn platformBinding(b: *std.Build, target: std.Build.ResolvedTarget, options: PlatformBindingOptions) PlatformBinding {
    const platform_options = b.addOptions();
    platform_options.addOption([]const u8, "platform_name", @tagName(options.platform));
    platform_options.addOption([]const []const u8, "platform_without", options.without);
    platform_options.addOption([]const []const u8, "platform_static", options.static);
    platform_options.addOption(bool, "http2", options.http2);
    const options_mod = platform_options.createModule();

    const facade = graphModule(b, options.public, "platform", .{
        .root_source_file = b.path("src/platform/protocol.zig"),
        .target = target,
    });
    facade.addImport("platform_options", options_mod);
    // TRANSITIONAL: the re-exported timer_backend reads the clock bridge.
    facade.addImport("clock", options.clock);

    const impl_root: std.Build.LazyPath = switch (options.platform) {
        .external => .{ .cwd_relative = options.module_path.? },
        else => b.path(b.fmt("src/platform/adapters/{s}/protocol.zig", .{@tagName(options.platform)})),
    };
    const impl = b.createModule(.{ .root_source_file = impl_root, .target = target, .link_libc = true });
    impl.addImport("platform", facade);
    impl.addImport("platform_options", options_mod);
    facade.addImport("platform_impl", impl);

    // The kit: one module per part, each importing the facade for its types;
    // any platform, built-in or third-party, may import any of them.
    const brotli_enabled = for (options.without) |name| {
        if (std.mem.eql(u8, name, "brotli")) break false;
    } else true;
    const font_decoding_enabled = for (options.without) |name| {
        if (std.mem.eql(u8, name, "font_decoding")) break false;
    } else true;
    const kit_parts = [_][]const u8{ "posix", "headless", "memory_store", "curl", "crypto", "memory_clipboard", "browser_state", "brotli", "image_codecs", "inflate", "sfnt", "image_decoding", "media_decoding", "image_encoding" };
    var kit: [kit_parts.len]*std.Build.Module = undefined;
    for (kit_parts, 0..) |part, i| {
        kit[i] = b.createModule(.{
            .root_source_file = b.path(b.fmt("src/platform/kit/{s}/root.zig", .{part})),
            .target = target,
            .link_libc = true,
        });
        kit[i].addImport("platform", facade);
        kit[i].addImport("platform_options", options_mod);
        // A disabled codec does not import its C headers or link its libraries,
        // even when the conformance test compiles every adapter operation.
        impl.addImport(b.fmt("kit_{s}", .{part}), if (i == 7 and !brotli_enabled) kit[1] else kit[i]);
    }
    // font_decoding brings the Brotli decoder WOFF2 needs whether or not the
    // `brotli` capability is compiled in (decision 20, Q3): kit/sfnt reaches
    // kit/brotli by its own import, which only a font decode calls.
    if (brotli_enabled or font_decoding_enabled) if (options.brotli) |codec| {
        kit[7].linkLibrary(codec.decoder);
        kit[7].linkLibrary(codec.encoder);
        kit[7].addImport("brotli_c", addCImport(b, "brotli_c", target, .{ .includes = &.{ "brotli/decode.h", "brotli/encode.h" }, .libs = &.{ codec.decoder, codec.encoder } }));
    };
    // kit/sfnt (decision 20): WOFF through kit/inflate, WOFF2 through
    // kit/brotli - headless's NotSupported when no Brotli library is built.
    kit[10].addImport("kit_inflate", kit[9]);
    kit[10].addImport("kit_brotli", if (options.brotli != null) kit[7] else kit[1]);
    // kit/image_decoding (D1, the user 2026-11-09): every built-in platform's
    // image decoders - PNG through kit/inflate, JPEG and SVG through
    // kit/image_codecs. Found by name, so a part appended after it keeps it.
    const image_decoding_part = comptime for (kit_parts, 0..) |part, i| {
        if (std.mem.eql(u8, part, "image_decoding")) break i;
    } else unreachable;
    const kit_image_decoding = kit[image_decoding_part];
    kit_image_decoding.addImport("kit_inflate", kit[9]);
    kit_image_decoding.addImport("kit_image_codecs", kit[8]);
    // kit/media_decoding (lane wptcfg D4, the user 2026-11-09): the media
    // decoders darwin, linux and testing build in - WAV linear PCM - its
    // canPlayType parsing with MIME Sniffing's parser. Found by name too.
    const media_decoding_part = comptime for (kit_parts, 0..) |part, i| {
        if (std.mem.eql(u8, part, "media_decoding")) break i;
    } else unreachable;
    const kit_media_decoding = kit[media_decoding_part];
    kit_media_decoding.addImport("mimesniff", options.mimesniff);
    if (options.image_codecs) |codecs| {
        kit[8].linkLibrary(codecs);
        kit[8].addImport("image_codecs_c", addCImport(b, "image_codecs_c", target, .{ .includes = &.{"image_codecs.h"}, .libs = &.{codecs} }));
    }
    if (target.result.os.tag == .ios) {
        addIosSdkPaths(kit[7], iosSdkPath(b));
        addIosSdkPaths(kit[8], iosSdkPath(b));
    }
    // darwin's fonts are CoreText's (decision 20), linked dynamically as
    // the system frameworks they are; compiled out, nothing is linked.
    if (options.platform == .darwin and target.result.os.tag.isDarwin() and font_decoding_enabled) {
        if (target.result.os.tag == .ios) addIosSdkPaths(impl, iosSdkPath(b));
        impl.linkFramework("CoreText", .{});
        impl.linkFramework("CoreFoundation", .{});
    }
    // kit/posix wraps today's clock, process Io and resident-memory bridges.
    kit[0].addImport("clock", options.clock);
    kit[0].addImport("host", options.host);
    kit[0].addImport("memory", options.memory);
    // and reads the local time zone through <time.h> (localtime_r, tzset).
    const c_time = addCImport(b, "c_time", target, .{ .includes = &.{"time.h"} });
    kit[0].addImport("c_time", c_time);
    // kit/browser_state keeps a Browser's stores in kit/memory_store.
    kit[6].addImport("kit_memory_store", kit[2]);
    // kit/curl's connection share, its own module (see PlatformBinding).
    const kit_curl_share = b.createModule(.{
        .root_source_file = b.path("src/platform/kit/curl/share.zig"),
        .target = target,
        .link_libc = true,
    });
    kit[3].addImport("kit_curl_share", kit_curl_share);
    // Its trust store (trust.zig) parses with libcurl's own mbedTLS, when
    // libcurl is the bundled one; a system libcurl keeps its own CA loading.
    const kit_curl_options = b.addOptions();
    kit_curl_options.addOption(bool, "mbedtls_trust_store", options.mbedtls != null);
    kit_curl_share.addOptions("kit_curl_options", kit_curl_options);
    if (options.mbedtls) |mbedtls| {
        kit_curl_share.linkLibrary(mbedtls);
        kit_curl_share.addImport("mbedtls_c", addCImport(b, "mbedtls_trust_c", target, .{
            .includes = &.{ "mbedtls/x509_crt.h", "mbedtls/ssl.h", "psa/crypto.h" },
            .libs = &.{mbedtls},
            .macros = &mbedtls_threading_macros,
        }));
        if (target.result.os.tag == .ios) addIosSdkPaths(kit_curl_share, iosSdkPath(b));
    }
    // kit/curl/websocket.zig's header set (curl.h, websockets.h, header.h) is
    // its own module: fetch's curl_ffi translates curl.h alone, as the two
    // @cImports did.
    const kit_curl_includes: []const []const u8 = &.{ "curl/curl.h", "curl/websockets.h", "curl/header.h" };
    if (options.libcurl) |libcurl| {
        linkStaticLibcurl(b, kit[3], target, libcurl);
        kit[3].addImport("curl_c", addCImport(b, "curl_c", target, .{ .includes = kit_curl_includes, .libs = &.{libcurl}, .macros = &.{.{ "CURL_STATICLIB", "1" }} }));
    } else {
        kit[3].linkSystemLibrary("curl", .{});
        kit[3].addImport("curl_c", addCImport(b, "curl_c", target, .{ .includes = kit_curl_includes, .system_libs = &.{"curl"} }));
    }
    return .{ .facade = facade, .options = options_mod, .kit_curl_share = kit_curl_share, .kit_sfnt = kit[10], .kit_inflate = kit[9], .kit_media_decoding = kit_media_decoding, .c_time = c_time };
}

/// A module of a graph: registered by name when the graph is public, private
/// otherwise (one name cannot be registered twice).
fn graphModule(b: *std.Build, public: bool, name: []const u8, options: std.Build.Module.CreateOptions) *std.Build.Module {
    return if (public) b.addModule(name, options) else b.createModule(options);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The build's JavaScript engine: -Dengine, and with it every option the
    // chosen adapter declares in its own build file - no other adapter's
    // exists in this build (src/runtime/engine_build_protocol.zig). An engine
    // that cannot be built for this target or with these options still
    // configures: each step that needs it fails with the adapter's reason.
    const engine = engine_build.choose(b, target);

    // Zig 0.16 resolves the macOS SDK for Darwin targets, but NOT the iOS one: a
    // trivial `#include <stdio.h>` for aarch64-ios fails with 'stdio.h' file not
    // found, with or without --sysroot. That surfaces far from the cause, as 15
    // errors in vendored zlib and 107 in mbedtls, which reads like a dependency
    // problem rather than a missing SDK.
    //
    // Point the compiler and linker at the iPhoneOS SDK explicitly. Queried through
    // `xcrun --sdk iphoneos` rather than hardcoded, because the SDK version moves
    // with Xcode.
    // -Dios-sdk: the SDK root iosSdkPath uses before xcrun (declared here once;
    // check-ios passes it to its sub-build).
    const ios_sdk_option = b.option([]const u8, "ios-sdk", "The iPhoneOS SDK root for an aarch64-ios build (default: xcrun --sdk iphoneos)");
    const ios_sdk: ?[]const u8 = if (target.result.os.tag == .ios) iosSdkPath(b) else null;

    // -Dsanitize-thread, read before any artifact links V8: under it the V8
    // wrapper is compiled apart (V8Link.wrapper_apart, addV8Source).
    const sanitize_thread_option = b.option(bool, "sanitize-thread", "Build every test executable with ThreadSanitizer (Crane's own modules; not the C libraries, the V8 prebuilt or the V8 wrapper) and run it so a race crashes its test (TSAN_OPTIONS=halt_on_error=1)") orelse false;
    const v8 = loadV8Link(b, &engine);
    // What the test executables and the snapshot generator link: the same V8,
    // with the wrapper compiled apart under -Dsanitize-thread. Never the
    // production artifacts' (wpt_runner, repl, gc_bench: checkLinkedC holds
    // every C library they link to their modes).
    var v8_tests_link = v8;
    v8_tests_link.wrapper_apart = sanitize_thread_option;
    const v8_tests = v8_tests_link;

    // ========================================================================
    // BUILD OPTIONS
    // ========================================================================

    const spec_filter = b.option(
        []const u8,
        "spec",
        "Run tests for a specific spec (infra, webidl, dom, encoding, url, console, streams, mimesniff, wpt_runner, or 'all')",
    );
    var test_selection: TestSelection = .{
        .file = b.option(
            []const u8,
            "test-file",
            "Build and run only this tests/**/*_test.zig file, as its own executable (with -Dspec=<its directory's spec>)",
        ),
        .v8 = v8_tests,
    };

    // WHATWG TestUtils Standard - Build-time gating
    // Per spec: "must not be enabled in the default shipping configuration of user agents"
    // See: https://testutils.spec.whatwg.org/
    // Default is true for development builds; production builds should use -Denable-test-utils=false
    const enable_test_utils = b.option(
        bool,
        "enable-test-utils",
        "Enable TestUtils namespace (WHATWG TestUtils Standard). " ++
            "Disable with -Denable-test-utils=false for production builds.",
    ) orelse true;

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

    // ========================================================================
    // DEBUG OPTIONS
    // ========================================================================

    // Debug output - compile-time flag to enable debug.print statements
    // When false (default), all debug output is completely eliminated from the binary
    const debug_enabled = b.option(
        bool,
        "debug",
        "Enable debug output (use -Ddebug=true to enable)",
    ) orelse false;

    // Debug scope filter - only show debug output for specific scopes
    // Example: -Ddebug-scope=v8,webidl will only show v8 and webidl debug output
    const debug_scope = b.option(
        []const u8,
        "debug-scope",
        "Filter debug output by scope (comma-separated: v8,webidl,dom,css,html,url,encoding,streams,fetch,runtime,gc,wpt,general)",
    ) orelse "";

    // ========================================================================
    // BUILD OPTIONS MODULE
    // ========================================================================

    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_test_utils", enable_test_utils);
    // The refcount zombie audit's hooks (dom.refcount_audit: the checks on
    // the hottest node paths, instance_bridge.getNodeBase and Node's state)
    // compile in only when asked, so a normal build pays nothing for them;
    // unit tests always have them (builtin.is_test). The audit sweep's runner
    // is built with -Drefcount-audit=true (refcount8, H-RC8-BUILD-AUDIT).
    // Its own options module, as fetch's curl_options: build_options is
    // imported by several modules already.
    const refcount_audit = b.option(bool, "refcount-audit", "Compile in the refcount zombie audit (run it with CRANE_REFCOUNT_AUDIT=1); unit tests always have it") orelse false;
    const dom_options = b.addOptions();
    dom_options.addOption(bool, "refcount_audit", refcount_audit);

    // Debug options module (separate from build_options for cleaner imports)
    const debug_options = b.addOptions();
    debug_options.addOption(bool, "debug_enabled", debug_enabled);
    debug_options.addOption([]const u8, "debug_scope", debug_scope);

    // Engine configuration options (for conditional compilation)
    // Phase 8 (DCE): an optional allow-list of WebIDL interfaces to expose.
    //
    // Empty (the default) means "every interface", i.e. exactly today's behaviour.
    // A non-empty comma-separated list restricts the binding and external-reference
    // loops to those names plus their ancestors - `interfaceAllowed` walks
    // `Meta.ParentInterface` upwards, so listing HTMLDivElement also admits
    // HTMLElement, Element, Node and EventTarget. Without that a gated build would
    // expose a constructor whose prototype chain is missing every link above it. The loops that consult this are the only thing
    // forcing all 1,263 interfaces to be analysed - `pub const X = @import(..)` in
    // interfaces/root.zig does NOT, because Zig only analyses referenced decls.
    const interface_allowlist = b.option(
        []const u8,
        "interfaces",
        "Comma-separated WebIDL interfaces to expose (default: all). Shrinks mobile binaries.",
    ) orelse "";
    build_options.addOption([]const u8, "interface_allowlist", interface_allowlist);

    // What the shared module still carries of the engine, written by the
    // adapter where this file used to write it (TRANSITIONAL: the design's
    // batch E5 moves it to the adapter's own module), and the adapter's own
    // options module, which the engine adapter's module alone imports.
    engine.applyTransitional(build_options);
    const engine_adapter_options = engine.adapterOptions(b);

    // Validate spec filter.
    //
    // One name per `std.mem.eql(u8, spec_filter.?, "...")` branch below, and one
    // branch per name. Keep the two in step: a name here with no branch silently
    // runs nothing, and a branch with no name here is unreachable because this
    // check exits first.
    //
    // The "Valid specs:" message is derived from this array rather than spelled
    // out a second time. Three copies of one list is what let it rot: the array
    // named 25 of the 28 specs, the message 24, and no two agreed.
    const valid_specs = [_][]const u8{
        "all",
        "process",
        "infra",
        "webidl",
        "dom",
        "selector",
        "encoding",
        "url",
        "urlpattern",
        "console",
        "streams",
        "mimesniff",
        "compression",
        "quirks",
        "css",
        "storage",
        "cookiestore",
        "runtime",
        "codegen",
        "v8",
        "file",
        "fs",
        "fetch",
        "trusted_types",
        "csp",
        "permissions",
        "html",
        "service_worker",
        "intl",
        "platform",
        "websocket",
        "browser",
        "xhr",
        "xml",
        "wpt_runner",
    };
    if (spec_filter) |spec| {
        var is_valid = false;
        for (valid_specs) |valid_spec| {
            if (std.mem.eql(u8, spec, valid_spec)) {
                is_valid = true;
                break;
            }
        }
        if (!is_valid) {
            std.debug.print("Error: Invalid spec '{s}'\n", .{spec});
            std.debug.print("Valid specs:", .{});
            for (valid_specs, 0..) |valid_spec, i| {
                std.debug.print("{s} {s}", .{ if (i == 0) "" else ",", valid_spec });
            }
            std.debug.print("\n", .{});
            std.process.exit(1);
        }
    }

    // ========================================================================
    // MODULE GRAPHS - one per platform this invocation builds for
    // ========================================================================

    // The shared graph's C libraries, in -Doptimize's mode at Zig's default C
    // sanitizer: the target platform's graph and the testing graph link the
    // same artifacts. A runner graph whose C libraries differ in mode or
    // sanitizer builds its own (runnerGraph); none is ever written to by
    // another graph (checkLinkedC, at the end of build()).
    const platform_without = optionList(b, "platform-without", b.option([]const u8, "platform-without", "Capabilities to compile out (comma-separated; src/platform/protocol.zig Capabilities)"), &platform_capability_names);
    const brotli_enabled = for (platform_without) |name| {
        if (std.mem.eql(u8, name, "brotli")) break false;
    } else true;
    const brotli = buildBrotli(b, target, optimize, null);
    const image_codecs = buildImageCodecs(b, target, optimize, null);
    const image_codecs_step = b.step("platform-image-codecs", "Build the testing JPEG/SVG libraries (also for cross targets)");
    if (image_codecs) |codecs| image_codecs_step.dependOn(&b.addInstallArtifact(codecs, .{}).step);
    const static_libcurl: ?StaticLibcurl = if (use_system_curl) null else buildStaticLibcurl(b, target, optimize, enable_http2, null, if (brotli_enabled) brotli else null);
    // A system libcurl may lack WebSockets. Say so now rather than leaving it to
    // a runtime CURLE_UNSUPPORTED_PROTOCOL.
    if (use_system_curl) warnIfSystemCurlLacksWebSockets(b);

    // The library, the CLI and the iOS build use the target's platform; the WPT
    // runner and the test tiers use `testing` (docs/platform-protocol.md 1.1).
    // Step 0 binds no platform yet, so both graphs are today's modules.
    // The platform protocol's build options (docs/platform-protocol.md 1.1).
    const platform_module_path = b.option([]const u8, "platform-module", "A third-party platform: the root file of an implementation of src/platform/protocol.zig");
    const platform_choice = b.option(Platform, "platform", "The platform: darwin, linux or testing (default: from the target)");
    const target_platform: Platform = if (platform_module_path != null) .external else platform_choice orelse Platform.ofTarget(target) orelse {
        std.debug.print("Error: no built-in platform for {s}; pass -Dplatform-module=<path>\n", .{@tagName(target.result.os.tag)});
        std.process.exit(1);
    };
    if (platform_choice == .external and platform_module_path == null) {
        std.debug.print("Error: -Dplatform=external needs -Dplatform-module=<path>\n", .{});
        std.process.exit(1);
    }
    const platform_static = optionList(b, "platform-static", b.option([]const u8, "platform-static", "Link-plan items to compile statically instead of linking the system library (comma-separated, or all)"), &platform_static_items);
    const module_config: ModuleConfig = .{
        .optimize = optimize,
        .build_options = build_options,
        .dom_options = dom_options,
        .engine_adapter_options = engine_adapter_options,
        .debug_options = debug_options,
        .engine_choice = @tagName(engine.name),
        .use_system_curl = use_system_curl,
        .enable_http2 = enable_http2,
        .static_libcurl = static_libcurl,
        .brotli = brotli,
        .image_codecs = image_codecs,
        .public_platform = target_platform,
        .platform_without = platform_without,
        .platform_static = platform_static,
        .platform_module = platform_module_path,
        .tables = addGeneratedTables(b),
    };
    const crane_graph = addCraneModules(b, target, target_platform, module_config);
    const testing_graph = if (target_platform == .testing) crane_graph else addCraneModules(b, target, .testing, module_config);

    // The WPT runner's two builds (tests/wpt_runner/build_mode.zig
    // `RunnerBuild`; the user, 2026-11-09: "I want our WPT to only ever run
    // Crane with the exact same configuration and memory setup that Crane
    // would have running in a production environment. We should never
    // special case something" - and "ok then we should architect ours like
    // the way browsers do it"). wpt.fyi scores the browsers' SHIPPING builds;
    // their own CI also runs WPT on debug and sanitizer builds, which never
    // feed a score. So:
    // - `wpt_runner` (`zig build wpt-runner`) is the PRODUCTION run: Crane
    //   exactly as its own browser, the release console, is built - every
    //   part in the release mode, the C code at that mode's own sanitizer,
    //   libc's malloc, and the console's platform graph (the target's own
    //   adapter, never the testing platform's compiled-in test
    //   capabilities). It shares the release console's graph, so the two
    //   cannot drift (build_mode.zig pins the configuration). Generation
    //   sweeps, the progress site, lane A/B pass counts and every timing.
    // - `wpt_runner_bug_finding` (`zig build wpt-runner-bug-finding`) is the
    //   BUG-FINDING run: the same platform graph, with detection added -
    //   Crane's modules keep -Doptimize's `builtin.mode` (Debug: the refcount
    //   ledger, the isolate cleanup validation), the C code at the full
    //   sanitizer, the leak- and double-free-detecting allocator with
    //   poison-on-free. Never published, never timed. `-Dwpt-runner-optimize`
    //   sets its root's mode (Debug for a diagnosis).
    // `-Dwpt-runner-release` / `-Dwpt-runner-release-fast` choose the release
    // console's mode - ReleaseSafe, the headline, or the ReleaseFast column
    // (the user, 2026-11-04 and 11-05) - and production follows it. The two
    // name different builds: both at once is refused.
    const runner_release_safe = b.option(
        bool,
        "wpt-runner-release",
        "Crane's release build in ReleaseSafe - the console, the production WPT runner (always) and gc_bench: every part ReleaseSafe, the C code at ReleaseSafe's default sanitizer, libc's malloc",
    ) orelse false;
    const runner_release_fast = b.option(
        bool,
        "wpt-runner-release-fast",
        "-Dwpt-runner-release with only the mode changed: the console, the production WPT runner and gc_bench ReleaseFast throughout, no C sanitizer - for timing beside the ReleaseSafe release build",
    ) orelse false;
    const runner_release = runner_build_mode.releaseOption(runner_release_safe, runner_release_fast) catch {
        std.debug.print("Error: -Dwpt-runner-release and -Dwpt-runner-release-fast name two release builds; pass one\n", .{});
        std.process.exit(1);
    };
    const runner_optimize_option = b.option(
        std.builtin.OptimizeMode,
        "wpt-runner-optimize",
        "Optimize mode of the bug-finding WPT runner's root and of gc_bench (default: ReleaseSafe, or -Doptimize when given; Debug for a diagnosis). The production runner is always the release console's",
    );
    const optimize_given = b.user_input_options.contains("optimize") or b.graph.release_mode != .off;
    const production_build = runner_build_mode.runnerBuild(.production, runner_release, runner_optimize_option, optimize, optimize_given);
    const bug_finding_build = runner_build_mode.runnerBuild(.bug_finding, runner_release, runner_optimize_option, optimize, optimize_given);
    // gc_bench keeps the runner rule it was built with: the bug-finding
    // root's mode, or the release build under -Dwpt-runner-release.
    const gc_bench_modes = if (runner_release) |release| runner_build_mode.releaseRunner(release) else bug_finding_build.modes;
    // The production graph: a private graph of the console's platform in the
    // release modes (docs/lessons/workflow-a-second-graph-of-the-target-
    // platform-must-be-private.md), over C libraries built at the root's
    // sanitizer - a .trap root links no full UBSan runtime, so C built with
    // .full would not link (docs/lessons/workflow-a-release-root-over-debug-
    // c-libraries-must-link-the-full-sanitizer-runtime.md). The release
    // console links this same graph (repl_graph below).
    const production_graph = runnerGraph(b, target, production_build, .{
        .module_config = module_config,
        .target_platform = target_platform,
        .shared = crane_graph,
        .testing = testing_graph,
        .use_system_curl = use_system_curl,
        .enable_http2 = enable_http2,
        .brotli_enabled = brotli_enabled,
    });
    // The bug-finding graph: the same platform; the shared graph itself when
    // its modes are -Doptimize's throughout (`-Doptimize=Debug`), else a
    // private one with its own C libraries in its root's mode.
    const bug_finding_graph = runnerGraph(b, target, bug_finding_build, .{
        .module_config = module_config,
        .target_platform = target_platform,
        .shared = crane_graph,
        .testing = testing_graph,
        .use_system_curl = use_system_curl,
        .enable_http2 = enable_http2,
        .brotli_enabled = brotli_enabled,
    });
    // The mode and C sanitizer of each graph's C libraries: the shared
    // graph's are -Doptimize's at Zig's default; a runner graph's are its
    // modes' (-Dsystem-curl builds every runner on the shared graph,
    // runnerGraph). What each binary bundles of the UBSan runtime follows
    // from them (addWptRunner, gc_bench), and checkLinkedC holds every build
    // to them at the end of build().
    const shared_c: CModes = .{ .optimize = optimize, .sanitize_c = null };
    const production_c: CModes = if (use_system_curl) shared_c else .libraries(production_build.modes);
    const bug_finding_c: CModes = if (use_system_curl) shared_c else .libraries(bug_finding_build.modes);
    const whatwg_mod = crane_graph.whatwg;
    const clock_mod = crane_graph.clock;
    const host_mod = crane_graph.host;
    const memory_mod = crane_graph.memory;
    const infra_mod = crane_graph.infra;
    const webidl_mod = crane_graph.webidl;
    const storage_mod = crane_graph.storage;
    const runtime_mod = crane_graph.runtime;
    const v8_mod = crane_graph.v8;
    const codegen_mod = crane_graph.codegen;
    const callbacks_mod = crane_graph.callbacks;
    const dictionaries_mod = crane_graph.dictionaries;
    const enums_mod = crane_graph.enums;
    const namespaces_mod = crane_graph.namespaces;
    const typedefs_mod = crane_graph.typedefs;
    const interfaces_mod = crane_graph.interfaces;
    const impls_mod = crane_graph.impls;
    const engine_mod = crane_graph.engine;
    const dom_mod = crane_graph.dom;
    const mixins_mod = crane_graph.mixins;
    const encoding_mod = crane_graph.encoding;
    const url_mod = crane_graph.url;
    const console_mod = crane_graph.console;
    const streams_mod = crane_graph.streams;
    const mimesniff_mod = crane_graph.mimesniff;
    const csp_mod = crane_graph.csp;
    const fetch_mod = crane_graph.fetch;
    const linked_mbedtls: ?*std.Build.Step.Compile = if (static_libcurl) |static| static.mbedtls else null;
    const trusted_types_mod = crane_graph.trusted_types;
    const hr_time_mod = crane_graph.hr_time;
    const websocket_mod = crane_graph.websocket;
    const platform_mod = crane_graph.platform;
    const html_core_mod = crane_graph.html_core;
    const html_mod = crane_graph.html;
    const permissions_mod = crane_graph.permissions;
    const browser_mod = crane_graph.browser;
    const webdriver_mod = crane_graph.webdriver;
    const intl_mod = crane_graph.intl;

    // ========================================================================
    // TESTS - GENERIC SPEC FILTERING
    // ========================================================================

    const test_step = b.step("test", "Run WHATWG spec tests (use -Dspec=<name> to filter)");

    // tools/test_launcher runs EVERY test executable (addSuiteRun): seeded
    // batches of child processes over the Zig test runner's protocol, a
    // per-test timeout, and every failure re-run alone and classified
    // (tmp/plans/test-architecture-recommendation.md, step 3).
    // `test-launch` runs the test executables alone, without the lints and
    // checks `test` adds; -Dspec and -Dtest-file select them for both.
    const launch: *const TestLaunch = launch: {
        const many_browsers = b.option(bool, "many-browsers", "The many-Browsers variant: every test runs beside a second, busy Browser on another thread of its process (suites that link V8)") orelse false;
        const test_log_level = b.option(std.log.Level, "test-log-level", "The test executables' log level: compiled and printed while a test runs (default: compiled at info, printed at warn; debug for a local diagnosis)");
        // The CRANE_POISON_FREES switch the launcher reads for libc's
        // scribbling in every test child (child.zig, `malloc_scribble`), as
        // the Crane test runner reads it (lane poison2): std only.
        const launcher_poisoning = b.createModule(.{
            .root_source_file = b.path("tests/test_runner/poisoning.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        });
        const launcher_module = b.createModule(.{
            .root_source_file = b.path("tools/test_launcher/main.zig"),
            // Build-time tool: runs on the host, as codegen does.
            .target = b.graph.host,
            .optimize = .Debug,
            .imports = &.{.{ .name = "poisoning", .module = launcher_poisoning }},
        });
        const launcher = b.addExecutable(.{ .name = "test_launcher", .root_module = launcher_module });
        const launch_step = b.step("test-launch", "Run the selected test executables through tools/test_launcher, without test's lints and checks (-Dspec=<dir> -Dlaunch-batch=B -Dlaunch-seed=S|random)");

        // The launcher's own tests (the scheduler, the seeded plan, the
        // classification, the server and the protocol, against fakes and a
        // fixture executable): part of `test`, and `test-launcher` alone.
        // They are the one test executable the build runner runs directly:
        // a launcher cannot vouch for itself.
        const launcher_fixture = b.addTest(.{
            .name = "test_launcher_fixture",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/test_launcher/fixture_test.zig"),
                .target = b.graph.host,
                .optimize = .Debug,
            }),
        });
        const launcher_fixture_options = b.addOptions();
        launcher_fixture_options.addOptionPath("path", launcher_fixture.getEmittedBin());
        // The Crane test runner's state check, failing, over tests that each
        // leave one kind of state behind (tests/test_runner_fixture/): run as
        // real processes by child.zig's tests, which read each test's
        // verdict and the field its output names.
        const state_fixture = b.addTest(.{
            .name = "test_state_fixture",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/test_runner_fixture/state_fixture.zig"),
                .target = target,
                .imports = &.{
                    .{ .name = "runtime", .module = testing_graph.runtime },
                    .{ .name = "dom", .module = testing_graph.dom },
                },
            }),
        });
        _ = useCraneTestRunner(b, state_fixture, "test_state_fixture", .fail, .per_test, &.{}, false, test_log_level);
        launcher_fixture_options.addOptionPath("state_path", state_fixture.getEmittedBin());
        // A joined executable as -Dtest-binaries=v8 makes one (tests/
        // test_runner_fixture/joined_fixture.zig): two members, "start."
        // (.process_start, as tests-v8) and "held." (the default .per_test),
        // each judged by its own row (lane onebin3).
        const joined_fixture = b.addTest(.{
            .name = "test_joined_fixture",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/test_runner_fixture/joined_fixture.zig"),
                .target = target,
                .imports = &.{
                    .{ .name = "runtime", .module = testing_graph.runtime },
                    .{ .name = "dom", .module = testing_graph.dom },
                },
            }),
        });
        _ = useCraneTestRunner(b, joined_fixture, "test_joined_fixture", .fail, .per_test, &.{
            .{ .prefix = "start.", .config = .{ .standalone_runtime = .process_start }, .plain = false },
            .{ .prefix = "held.", .config = .{}, .plain = false },
        }, false, test_log_level);
        launcher_fixture_options.addOptionPath("joined_path", joined_fixture.getEmittedBin());
        // Reads after a free, through std.testing.allocator and through a
        // test's own allocator (tests/test_runner_fixture/poison_fixture.zig):
        // child.zig's tests check that each fails by its name - it reads the
        // poison, or faults on it - and that CRANE_POISON_FREES=0 lets it
        // read the old bytes and pass (lane poison2).
        const poison_fixture = b.addTest(.{
            .name = "test_poison_fixture",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/test_runner_fixture/poison_fixture.zig"),
                .target = target,
                // std.heap.c_allocator: libc's malloc, which the launcher's
                // MallocScribble poisons.
                .link_libc = true,
            }),
        });
        _ = useCraneTestRunner(b, poison_fixture, "test_poison_fixture", .fail, .per_test, &.{}, false, test_log_level);
        launcher_fixture_options.addOptionPath("poison_path", poison_fixture.getEmittedBin());
        // A test that races, built with ThreadSanitizer: child.zig's tests
        // check that the launcher's TSAN_OPTIONS make the race a crash of
        // its process, blamed on that test (-Dsanitize-thread's contract).
        const tsan_fixture = b.addTest(.{
            .name = "test_launcher_tsan_fixture",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/test_launcher/tsan_fixture_test.zig"),
                .target = b.graph.host,
                .optimize = .Debug,
                .sanitize_thread = true,
            }),
        });
        launcher_fixture_options.addOptionPath("tsan_path", tsan_fixture.getEmittedBin());
        // -Dmany-browsers: a test that assumes it is the only Browser of its
        // process, and one that assumes nothing - child.zig's tests check that
        // the variant's busy Browser runs beside them and works cleanly. It
        // links V8, so it is built only in that build.
        if (many_browsers) {
            const many_fixture = b.addTest(.{
                .name = "test_many_browsers_fixture",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("tests/test_runner_fixture/many_browsers_fixture.zig"),
                    .target = target,
                    .imports = &.{
                        .{ .name = "runtime", .module = testing_graph.runtime },
                        .{ .name = "browser", .module = testing_graph.browser },
                    },
                }),
            });
            linkV8(b, many_fixture.root_module, v8_tests);
            _ = useCraneTestRunner(b, many_fixture, "test_many_browsers_fixture", .fail, .per_test, &.{}, true, test_log_level);
            launcher_fixture_options.addOptionPath("many_browsers_path", many_fixture.getEmittedBin());
        }
        const launcher_test_module = b.createModule(.{
            .root_source_file = b.path("tools/test_launcher/main.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "launcher_fixture", .module = launcher_fixture_options.createModule() },
                .{ .name = "poisoning", .module = launcher_poisoning },
            },
        });
        const own_tests = b.addTest(.{ .name = "test_launcher", .root_module = launcher_test_module });
        const launcher_tests = b.addRunArtifact(own_tests);
        test_step.dependOn(&launcher_tests.step);
        b.step("test-launcher", "Run tools/test_launcher's own tests").dependOn(&launcher_tests.step);

        const l = b.allocator.create(TestLaunch) catch @panic("OOM");
        l.* = .{
            .step = launch_step,
            .launcher = launcher,
            .own_tests = own_tests,
            .batch = b.option(u32, "launch-batch", "Tests per child process for every suite, overriding build.zig's suite_configs (1 = a process per test; 0 = the whole suite in one process)"),
            .jobs = b.option(u32, "launch-jobs", "Test processes at once for the whole build (default: the CPU count)"),
            .seed = b.option([]const u8, "launch-seed", "The launcher's seed: digest (default: from each test executable's bytes, printed; unchanged suites stay cached), random (fresh every run, never cached), or a value") orelse "digest",
            .timeout = b.option(u32, "launch-timeout", "Per-test timeout in seconds (default 300; tests build.zig lists as slow get 4x)") orelse 300,
            .shuffle = b.option(bool, "launch-shuffle", "true: shuffle every suite's order and batches from the seed; false: index order everywhere (default: each suite's suite_configs row, mostly shuffled)"),
            .sanitize_thread = sanitize_thread_option,
            .many_browsers = many_browsers,
            .log_level = test_log_level,
            .browser_module = testing_graph.browser,
            .test_exes = test_exes: {
                const list = b.allocator.create(std.ArrayList(*std.Build.Step.Compile)) catch @panic("OOM");
                list.* = .empty;
                break :test_exes list;
            },
            .verify = testVerifySelection(b),
            .filters = b.option([]const []const u8, "test-filter", "Run only the tests this pattern matches (repeatable: any of them): the whole test name, `*` any run of characters - names start with the file's stem, so 'mutation_test*' is a file and '*removes*' any name holding 'removes'. Selected at run time: nothing recompiles, and a suite with no match runs nothing") orelse &.{},
        };
        break :launch l;
    };
    test_selection.launch = launch;
    const test_binaries = b.option(TestBinaries, "test-binaries", "How `test` compiles tests/<dir>/: dirs (an executable each, the default: a test-file change rebuilds one directory) or v8 (ONE executable for the directories that link V8: for cold full gates)") orelse .dirs;
    if (test_binaries == .v8 and test_selection.file == null) {
        const one = b.allocator.create(OneBinary) catch @panic("OOM");
        one.* = .{ .step = test_step, .v8 = v8_tests };
        test_selection.one = one;
    }
    test_selection.suite_dirs = suite_dirs: {
        const list = b.allocator.create(std.ArrayList([]const u8)) catch @panic("OOM");
        list.* = .empty;
        break :suite_dirs list;
    };

    // The Crane test runner's many-Browsers neighbour (tests/test_runner/
    // neighbour.zig): its thread and handshake, std only, tested with a fake
    // work function. Run through the launcher like any suite; part of
    // `test` and of `test-launcher`.
    {
        const neighbour_tests = b.addTest(.{
            .name = "test_runner-neighbour",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/test_runner/neighbour.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_neighbour_tests = addSuiteRun(b, launch, neighbour_tests, "test_runner-neighbour", null);
        if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all")) test_step.dependOn(&run_neighbour_tests.step);
        b.top_level_steps.get("test-launcher").?.step.dependOn(&run_neighbour_tests.step);
    }

    // Poison on free (tests/test_runner/poisoning.zig, lane poison2): the
    // Poisoning front, the DebugAllocator a test makes for itself, and the
    // CRANE_POISON_FREES switch - std only, under the Crane test runner it
    // serves (its `poison_frees` decides). Part of `test` and of
    // `test-launcher`.
    {
        const poisoning_tests = b.addTest(.{
            .name = "test_runner-poisoning",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/test_runner/poisoning.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_poisoning_tests = addSuiteRun(b, launch, poisoning_tests, "test_runner-poisoning", null);
        // -Dverify-files=tests/test_runner/poisoning.zig: its tests live in
        // the module, as the WPT runner's harness modules' do.
        addTestVerify(b, launch, poisoning_tests, "test_runner-poisoning", "tests/test_runner", &.{"poisoning.zig"});
        if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all")) test_step.dependOn(&run_poisoning_tests.step);
        b.top_level_steps.get("test-launcher").?.step.dependOn(&run_poisoning_tests.step);
    }

    // The V8 snapshot the tests/v8 snapshot tests restore: THIS build's,
    // made by a cached run of the snapshot generator (filled in where the
    // generator is defined, below) and passed by path, so the tests depend on
    // it. Never a file found from the current directory: a stale
    // zig-out/bin/whatwg_snapshot.bin there made three of them fail and,
    // where there was none, all of them skip (feature queue, 2026-11-01).
    const test_snapshot_options = b.addOptions();
    const test_snapshot_module = test_snapshot_options.createModule();

    // What -Dtarget can build without running anything there: the artifacts
    // that link no V8 are built (libwhatwg, the image codecs, the platform
    // conformance tests); those that link V8 (crane, wpt_runner) are compiled
    // without a binary, which analyses all their Zig and compiles
    // v8_wrapper.cpp, and never links - there is no V8 prebuilt for any target
    // but the build machine's (jsengines/v8/out/static). `check-linux` runs it
    // for both Linux targets; `crane-check` is the host's crane compile.
    const check_target_step = b.step("check-target", "Build what -Dtarget can build (libwhatwg, codecs, platform tests); compile crane and wpt_runner without linking");
    if (image_codecs) |codecs| check_target_step.dependOn(&codecs.step);

    // tests/eventsource/: a directory suite (addTestFilesFromDir), its own
    // step's and `test`'s. Built for the target, as the testing graph it
    // imports is: a host root over target modules mixes two targets in one
    // compile, and for a Linux target from macOS std.c is Darwin's under
    // kit/posix's Linux branch (pthread_setname_np: expected 1 argument(s),
    // found 2).
    const eventsource_test_step = b.step("test-eventsource", "Run server-sent event parser and connection tests");
    const eventsource_test_imports = [_]std.Build.Module.Import{
        .{ .name = "eventsource", .module = testing_graph.eventsource },
        .{ .name = "infra", .module = testing_graph.infra },
        .{ .name = "fetch", .module = testing_graph.fetch },
    };
    addTestFilesFromDir(b, eventsource_test_step, "tests/eventsource", target, &eventsource_test_imports, false, test_selection) catch |err| {
        std.debug.print("Warning: Failed to add eventsource test files: {}\n", .{err});
    };
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "eventsource")) {
        test_step.dependOn(eventsource_test_step);
    }

    const webcrypto_tests = b.addTest(.{ .root_module = testing_graph.webcrypto });
    const run_webcrypto_tests = addSuiteRun(b, launch, webcrypto_tests, "src-webcrypto", null);
    const webcrypto_test_step = b.step("test-webcrypto", "Run Web Cryptography API primitive tests");
    webcrypto_test_step.dependOn(&run_webcrypto_tests.step);
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all")) {
        test_step.dependOn(&run_webcrypto_tests.step);
    }

    // The mbedTLS and zlib versions the binary links, asked of the linked code
    // (tests/linked_libraries/versions_test.zig). Built against the same mbedTLS
    // artifact, headers and threading macros as libcurl and WebCrypto. Not under
    // -Dsystem-curl: there is no mbedTLS artifact, and the versions are the system's.
    recordSuiteDir(b, test_selection, "tests/linked_libraries");
    if (linked_mbedtls) |mbedtls_library| {
        const deps_test_mod = b.createModule(.{
            .root_source_file = b.path("tests/linked_libraries/versions_test.zig"),
            .target = target,
            .imports = &.{.{ .name = "fetch", .module = testing_graph.fetch }},
        });
        deps_test_mod.linkLibrary(mbedtls_library);
        deps_test_mod.addImport("mbedtls_version_c", addCImport(b, "mbedtls_version_c", target, .{ .includes = &.{"mbedtls/version.h"}, .libs = &.{mbedtls_library}, .macros = &mbedtls_threading_macros }));
        const run_deps_tests = addSuiteRun(b, launch, b.addTest(.{ .root_module = deps_test_mod }), "tests-linked_libraries", null);
        b.step("test-deps", "Check the mbedTLS and zlib versions libcurl and WebCrypto link").dependOn(&run_deps_tests.step);
        if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all")) {
            test_step.dependOn(&run_deps_tests.step);
        }
    }

    const test_all = spec_filter == null or std.mem.eql(u8, spec_filter.?, "all");
    const test_infra = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "infra"));
    const test_process = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "process"));
    const test_webidl = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "webidl"));
    const test_dom = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "dom"));
    const test_selector = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "selector"));
    const test_encoding = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "encoding"));
    const test_url = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "url"));
    const test_urlpattern = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "urlpattern"));
    const test_console = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "console"));
    const test_streams = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "streams"));
    const test_compression = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "compression"));
    const test_mimesniff = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "mimesniff"));
    const test_quirks = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "quirks"));
    const test_css = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "css"));
    const test_xml = test_all or (spec_filter != null and std.mem.eql(u8, spec_filter.?, "xml"));

    if (test_process) {
        // src/process: the start-up phase and Hook(T) (moved from src/dom by
        // lane hookfreeze2; their tests ran in src-dom until then).
        const process_tests = b.addTest(.{ .root_module = testing_graph.process });
        const run_process_tests = addSuiteRun(b, launch, process_tests, "src-process", null);
        test_step.dependOn(&run_process_tests.step);
    }

    if (test_infra) {
        const infra_tests = b.addTest(.{ .root_module = testing_graph.infra });
        const run_infra_tests = addSuiteRun(b, launch, infra_tests, "src-infra", null);
        test_step.dependOn(&run_infra_tests.step);

        // tests/infra/: never compiled until lane flakes2 (2026-11-02) - no
        // suite named the directory (checkEveryTestDirectoryIsASuite).
        const infra_imports = [_]std.Build.Module.Import{
            .{ .name = "infra", .module = testing_graph.infra },
        };
        addTestFilesFromDir(b, test_step, "tests/infra", target, &infra_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add infra test files: {}\n", .{err});
        };
    }

    if (test_webidl) {
        const webidl_tests = b.addTest(.{ .root_module = testing_graph.webidl });
        const run_webidl_tests = addSuiteRun(b, launch, webidl_tests, "src-webidl", null);
        test_step.dependOn(&run_webidl_tests.step);

        // Add dedicated test files from tests/webidl/
        const webidl_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "dom", .module = testing_graph.dom },
            .{ .name = "streams", .module = testing_graph.streams },
            .{ .name = "console", .module = testing_graph.console },
        };
        addTestFilesFromDir(b, test_step, "tests/webidl", target, &webidl_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add webidl test files: {}\n", .{err});
        };
    }

    if (test_dom) {
        const dom_tests = b.addTest(.{ .root_module = testing_graph.dom });
        const run_dom_tests = addSuiteRun(b, launch, dom_tests, "src-dom", null);
        test_step.dependOn(&run_dom_tests.step);

        // Add dedicated test files from tests/dom/
        const dom_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "dom", .module = testing_graph.dom },
            .{ .name = "selector", .module = testing_graph.selector },
            .{ .name = "runtime", .module = testing_graph.runtime },
            .{ .name = "interfaces", .module = testing_graph.interfaces },
            .{ .name = "impls", .module = testing_graph.impls },
            .{ .name = "enums", .module = testing_graph.enums },
            // tests/dom/hr_time_coarsen_exactness_test.zig: the coarsening grid's exact arithmetic.
            .{ .name = "hr_time", .module = testing_graph.hr_time },
        };
        // link_v8 = true: tests/dom/mutation_test.zig calls dom.mutation.insert
        // and .adopt, and src/dom/mutation.zig reaches impls.NodeList/Range/
        // NodeIterator and interfaces.NodeList.vtable - i.e. the V8 FFI layer,
        // which also drags in libuv's event loop. With `false` this was the only
        // one of 262 build steps that failed to link, with 246 undefined symbols
        // (236 _v8_* + 10 _uv_*).
        addTestFilesFromDir(b, test_step, "tests/dom", target, &dom_imports, true, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add dom test files: {}\n", .{err});
        };
    }

    if (test_selector) {
        const selector_tests = b.addTest(.{ .root_module = testing_graph.selector });
        const run_selector_tests = addSuiteRun(b, launch, selector_tests, "src-selector", null);
        test_step.dependOn(&run_selector_tests.step);

        // Add dedicated test files from tests/selector/
        const selector_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "dom", .module = testing_graph.dom },
            .{ .name = "selector", .module = testing_graph.selector },
        };
        addTestFilesFromDir(b, test_step, "tests/selector", target, &selector_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add selector test files: {}\n", .{err});
        };
    }

    if (test_encoding) {
        const encoding_tests = b.addTest(.{ .root_module = testing_graph.encoding });
        const run_encoding_tests = addSuiteRun(b, launch, encoding_tests, "src-encoding", null);
        test_step.dependOn(&run_encoding_tests.step);

        // Add dedicated test files from tests/encoding/
        const encoding_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "encoding", .module = testing_graph.encoding },
        };
        addTestFilesFromDir(b, test_step, "tests/encoding", target, &encoding_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add encoding test files: {}\n", .{err});
        };
    }

    if (test_url) {
        const url_tests = b.addTest(.{ .root_module = testing_graph.url });
        const run_url_tests = addSuiteRun(b, launch, url_tests, "src-url", null);
        test_step.dependOn(&run_url_tests.step);

        // Add dedicated test files from tests/url/
        const url_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "encoding", .module = testing_graph.encoding },
            .{ .name = "url", .module = testing_graph.url },
        };
        addTestFilesFromDir(b, test_step, "tests/url", target, &url_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add url test files: {}\n", .{err});
        };
    }

    if (test_urlpattern) {
        const urlpattern_tests = b.addTest(.{ .root_module = testing_graph.urlpattern });
        const run_urlpattern_tests = addSuiteRun(b, launch, urlpattern_tests, "src-urlpattern", null);
        test_step.dependOn(&run_urlpattern_tests.step);

        // Add dedicated test files from tests/urlpattern/
        const urlpattern_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "urlpattern", .module = testing_graph.urlpattern },
            .{ .name = "url", .module = testing_graph.url },
        };
        addTestFilesFromDir(b, test_step, "tests/urlpattern", target, &urlpattern_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add urlpattern test files: {}\n", .{err});
        };
    }

    if (test_console) {
        const console_tests = b.addTest(.{ .root_module = testing_graph.console });
        const run_console_tests = addSuiteRun(b, launch, console_tests, "src-console", null);
        test_step.dependOn(&run_console_tests.step);

        // Add dedicated test files from tests/console/
        const console_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "console", .module = testing_graph.console },
        };
        addTestFilesFromDir(b, test_step, "tests/console", target, &console_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add console test files: {}\n", .{err});
        };
    }

    if (test_streams) {
        // Note: Module tests for streams are skipped because they use refAllDecls on
        // V8-dependent code (interfaces/impls). The dedicated test files in tests/streams/
        // cover the functionality without requiring V8 to be linked.
        // To run full streams tests with V8, use the REPL or integration tests.

        // Add dedicated test files from tests/streams/
        const streams_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "dom", .module = testing_graph.dom },
            .{ .name = "streams", .module = testing_graph.streams },
            .{ .name = "interfaces", .module = testing_graph.interfaces },
            .{ .name = "impls", .module = testing_graph.impls },
            .{ .name = "dictionaries", .module = testing_graph.dictionaries },
            .{ .name = "streams_common", .module = testing_graph.streams_common },
            .{ .name = "streams_queue", .module = testing_graph.streams_queue },
            .{ .name = "streams_async_promise", .module = testing_graph.streams_async_promise },
            .{ .name = "streams_read_request", .module = testing_graph.streams_read_request },
            .{ .name = "streams_write_request", .module = testing_graph.streams_write_request },
            .{ .name = "streams_read_into_request", .module = testing_graph.streams_read_into_request },
            .{ .name = "streams_pull_into_descriptor", .module = testing_graph.streams_pull_into_descriptor },
            .{ .name = "streams_event_loop", .module = testing_graph.streams_event_loop },
            .{ .name = "streams_test_event_loop", .module = testing_graph.streams_test_event_loop },
        };
        addTestFilesFromDir(b, test_step, "tests/streams", target, &streams_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add streams test files: {}\n", .{err});
        };
    }

    if (test_compression) {
        const compression_tests = b.addTest(.{ .root_module = testing_graph.compression });
        test_step.dependOn(&addSuiteRun(b, launch, compression_tests, "src-compression", null).step);
        const imports = [_]std.Build.Module.Import{
            .{ .name = "compression", .module = testing_graph.compression },
        };
        addTestFilesFromDir(b, test_step, "tests/compression", target, &imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add compression test files: {}\n", .{err});
        };
    }

    if (test_mimesniff) {
        const mimesniff_tests = b.addTest(.{ .root_module = testing_graph.mimesniff });
        const run_mimesniff_tests = addSuiteRun(b, launch, mimesniff_tests, "src-mimesniff", null);
        test_step.dependOn(&run_mimesniff_tests.step);

        // Add dedicated test files from tests/mimesniff/
        const mimesniff_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "mimesniff", .module = testing_graph.mimesniff },
        };
        addTestFilesFromDir(b, test_step, "tests/mimesniff", target, &mimesniff_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add mimesniff test files: {}\n", .{err});
        };
    }

    if (test_xml) {
        const xml_tests = b.addTest(.{ .root_module = testing_graph.xml });
        const run_xml_tests = addSuiteRun(b, launch, xml_tests, "src-xml", null);
        test_step.dependOn(&run_xml_tests.step);

        // Add dedicated test files from tests/xml/
        const xml_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "xml", .module = testing_graph.xml },
        };
        addTestFilesFromDir(b, test_step, "tests/xml", target, &xml_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add xml test files: {}\n", .{err});
        };
    }

    if (test_quirks) {
        const quirks_tests = b.addTest(.{ .root_module = testing_graph.quirks });
        const run_quirks_tests = addSuiteRun(b, launch, quirks_tests, "src-quirks", null);
        test_step.dependOn(&run_quirks_tests.step);

        // Add dedicated test files from tests/quirks/
        const quirks_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "quirks", .module = testing_graph.quirks },
        };
        addTestFilesFromDir(b, test_step, "tests/quirks", target, &quirks_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add quirks test files: {}\n", .{err});
        };
    }

    if (test_css) {
        const css_tests = b.addTest(.{ .root_module = testing_graph.css });
        const run_css_tests = addSuiteRun(b, launch, css_tests, "src-css", null);
        test_step.dependOn(&run_css_tests.step);

        // Add dedicated test files from tests/css/
        const css_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "css", .module = testing_graph.css },
            .{ .name = "quirks", .module = testing_graph.quirks },
        };
        addTestFilesFromDir(b, test_step, "tests/css", target, &css_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add css test files: {}\n", .{err});
        };
    }

    // HTML tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "html")) {
        // NOT V8-linked, and it cannot be - see below. `testing_graph.html` imports
        // `runtime`, `impls`, `interfaces` and `v8`, so this target links today
        // only for as long as Zig's lazy analysis never walks from a test block
        // in `src/html/` into a `v8_*` extern. The day one does, this goes red
        // with ~238 `undefined symbol: _v8_*`. `tests/dom/` hit exactly that
        // wall with 246 and was fixed by passing `link_v8 = true` for the files
        // under `tests/dom/`; the module-root target still is not linked, so
        // `testing_graph.dom`, `testing_graph.intl` and `testing_graph.platform` all carry the same latency.
        //
        // Neither way of linking it works from build.zig alone. Both measured:
        //
        //   Clone the module - same root source file, same import table, its
        //   own link objects - so the linkage stays local to the test:
        //     src/webidl/impls/HTMLIFrameElement.zig:1:1: error: file exists in
        //     modules 'root' and 'html'
        //   because `testing_graph.impls.addImport("html", testing_graph.html)` above makes
        //   `testing_graph.html` a transitive dependency of itself. The clone is rooted
        //   at `src/html/full.zig` and so is `testing_graph.html`, and both end up in the
        //   one compilation: `-Mroot=src/html/full.zig ... -Mhtml=src/html/full.zig`.
        //
        //   `linkV8(b, testing_graph.html, v8)` - link it in place:
        //     844 `error: duplicate symbol definition:` (_crane_callback_*,
        //     CallbackManager::instance_, ...)
        //   because `testing_graph.html` is a dependency of `wpt_runner`, `full_static_lib`,
        //   `crane` and `crane_exe`, each of which already compiles
        //   `v8_wrapper.cpp` into itself. A module's link objects belong to every
        //   artifact downstream of it.
        //
        // A generated root that does `_ = @import("html")` does not help either:
        // `zig test` collects test blocks from the root module only, never from
        // an imported module (verified - a dep module's tests do not run).
        //
        // The fix is a source change, so it is not made here. Either:
        //   1. break the cycle - have `src/webidl/impls/**` reach HTML through
        //      `html_core` (as it already does for DOMParser, innerHTML and
        //      Window) instead of `html`, which leaves `testing_graph.html` a leaf that
        //      can be cloned; or
        //   2. keep every V8-reaching HTML test under `tests/html/`, which IS
        //      V8-linked below, and treat `src/html/**` test blocks as
        //      pure-Zig-only. That is the convention `tests/dom/` follows.
        const html_tests = b.addTest(.{ .root_module = testing_graph.html });
        const run_html_tests = addSuiteRun(b, launch, html_tests, "src-html", null);
        test_step.dependOn(&run_html_tests.step);

        // Add dedicated test files from tests/html/
        const html_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "html", .module = testing_graph.html },
            .{ .name = "html_core", .module = testing_graph.html_core },
            .{ .name = "infra", .module = testing_graph.infra },
            .{ .name = "runtime", .module = testing_graph.runtime },
            .{ .name = "platform", .module = testing_graph.platform },
            // The engine protocol html already reaches, for tests whose host
            // makes an agent and a realm (the worker-thread tests).
            .{ .name = "engine", .module = testing_graph.engine },
            // For tests that make platform objects with no Browser: the hooks
            // (interfaces.process_hooks.startHooksForTest).
            .{ .name = "interfaces", .module = testing_graph.interfaces },
            // Media owner-hook tests reach only the public DOM seam.
            .{ .name = "dom", .module = testing_graph.dom },
            // Document abort tests measure transports through a browser host.
            .{ .name = "browser", .module = testing_graph.browser },
            .{ .name = "fetch", .module = testing_graph.fetch },
            // The Browser's stores, which instances tests reach through two
            // Browsers' scopes (tests/html/instances_isolation_test.zig).
            .{ .name = "file", .module = testing_graph.file },
            .{ .name = "cookiestore", .module = testing_graph.cookiestore },
            .{ .name = "permissions", .module = testing_graph.permissions },
            .{ .name = "xhr", .module = testing_graph.xhr },
        };
        addTestFilesFromDir(b, test_step, "tests/html", target, &html_imports, true, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add html test files: {}\n", .{err});
        };
    }

    // Service Workers: the service_worker module's tests (a dependency of
    // itself through impls, as html is, so its src/ test blocks do not run -
    // its tests live in tests/service_worker, V8-linked like tests/html).
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "service_worker")) {
        const service_worker_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "service_worker", .module = testing_graph.service_worker },
            .{ .name = "html", .module = testing_graph.html },
            .{ .name = "html_core", .module = testing_graph.html_core },
            .{ .name = "runtime", .module = testing_graph.runtime },
            .{ .name = "engine", .module = testing_graph.engine },
            .{ .name = "platform", .module = testing_graph.platform },
            .{ .name = "interfaces", .module = testing_graph.interfaces },
            .{ .name = "dom", .module = testing_graph.dom },
            .{ .name = "fetch", .module = testing_graph.fetch },
            .{ .name = "browser", .module = testing_graph.browser },
        };
        addTestFilesFromDir(b, test_step, "tests/service_worker", target, &service_worker_imports, true, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add service_worker test files: {}\n", .{err});
        };
    }

    // Browser tests (the single-isolate browser that WPT drives)
    //
    // `src/browser/` had no test root in this file at all - `testing_graph.browser` was
    // only ever a dependency of `wpt_runner`, `crane_exe` and friends - so its
    // test blocks compiled as part of those binaries and were never run. That
    // is 13 of them, 9 added to `navigation.zig` on 2026-09-21 alone, and
    // `src/browser/root.zig` even has the `test { _ = @import(...); }` block
    // that pulls the other three files in. It was wired to nothing.
    //
    // V8-linked, and it has to be: `Browser.init` creates an isolate, and
    // `testing_graph.browser` imports `v8`, `runtime` and `impls`. Unlike `testing_graph.html`
    // above, nothing imports `testing_graph.browser`, so it is not a dependency of itself
    // and `addModuleTestWithV8` can clone it without two modules claiming
    // `src/browser/root.zig`.
    //
    // tests/browser/ is a directory suite of its own, run by the separate
    // `test-browser` step (below), not by `test`.
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "browser")) {
        const browser_tests = addModuleTestWithV8(b, testing_graph.browser, target, v8_tests);
        const run_browser_tests = addSuiteRun(b, launch, browser_tests, "src-browser", null);
        test_step.dependOn(&run_browser_tests.step);
    }

    // File API tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "file")) {
        const file_tests = b.addTest(.{ .root_module = testing_graph.file });
        const run_file_tests = addSuiteRun(b, launch, file_tests, "src-file", null);
        test_step.dependOn(&run_file_tests.step);

        // Add dedicated test files from tests/file/ when they exist
        const file_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "file", .module = testing_graph.file },
        };
        addTestFilesFromDir(b, test_step, "tests/file", target, &file_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add file test files: {}\n", .{err});
        };
    }

    // Fetch API tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "fetch")) {
        const fetch_tests = b.addTest(.{ .root_module = testing_graph.fetch });
        const run_fetch_tests = addSuiteRun(b, launch, fetch_tests, "src-fetch", null);
        test_step.dependOn(&run_fetch_tests.step);

        // Referrer Policy is a module of its own, so the fetch test binary,
        // though it imports it, never runs its test blocks.
        const referrer_policy_tests = b.addTest(.{ .root_module = testing_graph.referrer_policy });
        test_step.dependOn(&addSuiteRun(b, launch, referrer_policy_tests, "src-referrer_policy", null).step);

        // Add dedicated test files from tests/fetch/ when they exist
        const fetch_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "fetch", .module = testing_graph.fetch },
            // kit/curl's share, options and trust store, as fetch reaches them.
            .{ .name = "kit_curl_share", .module = testing_graph.fetch.import_table.get("kit_curl_share").? },
        };
        addTestFilesFromDir(b, test_step, "tests/fetch", target, &fetch_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add fetch test files: {}\n", .{err});
        };
    }

    // XMLHttpRequest tests (WHATWG XHR Standard)
    //
    // These were opt-in behind `-Dspec=xhr` and left out of `all` while
    // `src/xhr/` carried 30 compile errors across 8 files - a module that
    // nothing had ever compiled, because `testing_graph.impls` imports `xhr` but Zig
    // analyses only what is REFERENCED, and `call_send` never called into it.
    //
    // All 30 are fixed, so this runs with `all` like every other spec. Keep it
    // that way: a gated test block is a test block that rots.
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "xhr")) {
        const xhr_tests = b.addTest(.{ .root_module = testing_graph.xhr });
        const run_xhr_tests = addSuiteRun(b, launch, xhr_tests, "src-xhr", null);
        test_step.dependOn(&run_xhr_tests.step);

        // `testing_graph.xhr` already carries `fetch`, which is where the curl linkage
        // comes from, so the test root needs nothing beyond `xhr` itself. No V8
        // link: nothing under `src/xhr/` reaches a `v8_*` extern, which is now
        // structural rather than incidental - the module has no `runtime`
        // import at all.
        const xhr_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "xhr", .module = testing_graph.xhr },
            // A response-shaped test fixture needs `InternalResponse` and
            // `Body`: a state carrying received bytes but no response is one
            // the algorithms cannot reach, and the text response algorithm
            // reads "" out of it.
            .{ .name = "fetch", .module = testing_graph.fetch },
        };
        addTestFilesFromDir(b, test_step, "tests/xhr", target, &xhr_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add xhr test files: {}\n", .{err});
        };
    }

    // WebSocket tests (WHATWG WebSockets API)
    //
    // These were opt-in behind `-Dspec=websocket` and left out of `all` while the
    // module carried 14 compile errors. `tests/websocket/` had no entry here at
    // all, so neither its tests nor the ones inside `src/websocket/` were ever
    // compiled - and nothing in the build referenced
    // `src/websocket/{events,send_buffer}.zig`, so those two files sat out the
    // Zig 0.16 ArrayList migration in plain sight while `zig build` stayed green.
    //
    // All 14 are fixed, so this runs with `all` like every other spec. Keep it
    // that way: a gated test block is a test block that rots.
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "websocket")) {
        const websocket_tests = b.addTest(.{ .root_module = testing_graph.websocket });
        const run_websocket_tests = addSuiteRun(b, launch, websocket_tests, "src-websocket", null);
        test_step.dependOn(&run_websocket_tests.step);

        // Add dedicated test files from tests/websocket/
        // `testing_graph.websocket` already carries its own `fetch` import, which is where
        // the curl linkage comes from, so the test root needs nothing else.
        const websocket_imports = [_]std.Build.Module.Import{
            .{ .name = "websocket", .module = testing_graph.websocket },
            // A Browser's network context, which a connection is made with
            // (tests/websocket/websocket_proxy_test.zig).
            .{ .name = "fetch", .module = testing_graph.fetch },
            .{ .name = "browser", .module = testing_graph.browser },
            .{ .name = "engine", .module = testing_graph.engine },
        };
        addTestFilesFromDir(b, test_step, "tests/websocket", target, &websocket_imports, true, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add websocket test files: {}\n", .{err});
        };
    }

    // File System Access API tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "fs")) {
        const fs_tests = b.addTest(.{ .root_module = testing_graph.fs });
        const run_fs_tests = addSuiteRun(b, launch, fs_tests, "src-fs", null);
        test_step.dependOn(&run_fs_tests.step);

        // Add dedicated test files from tests/fs/ when they exist
        const fs_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "fs", .module = testing_graph.fs },
        };
        addTestFilesFromDir(b, test_step, "tests/fs", target, &fs_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add fs test files: {}\n", .{err});
        };
    }

    // Trusted Types tests (W3C Trusted Types)
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "trusted_types")) {
        const trusted_types_tests = b.addTest(.{ .root_module = testing_graph.trusted_types });
        const run_trusted_types_tests = addSuiteRun(b, launch, trusted_types_tests, "src-trusted_types", null);
        test_step.dependOn(&run_trusted_types_tests.step);

        // Add dedicated test files from tests/trusted_types/ when they exist
        const trusted_types_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "trusted_types", .module = testing_graph.trusted_types },
        };
        addTestFilesFromDir(b, test_step, "tests/trusted_types", target, &trusted_types_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add trusted_types test files: {}\n", .{err});
        };
    }

    // CSP tests (W3C Content Security Policy Level 3)
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "csp")) {
        const csp_tests = b.addTest(.{ .root_module = testing_graph.csp });
        const run_csp_tests = addSuiteRun(b, launch, csp_tests, "src-csp", null);
        test_step.dependOn(&run_csp_tests.step);

        // Add dedicated test files from tests/csp/ when they exist
        const csp_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "csp", .module = testing_graph.csp },
        };
        addTestFilesFromDir(b, test_step, "tests/csp", target, &csp_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add csp test files: {}\n", .{err});
        };
    }

    // Permissions tests (W3C Permissions API)
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "permissions")) {
        const permissions_tests = b.addTest(.{ .root_module = testing_graph.permissions });
        const run_permissions_tests = addSuiteRun(b, launch, permissions_tests, "src-permissions", null);
        test_step.dependOn(&run_permissions_tests.step);

        // Add dedicated test files from tests/permissions/ when they exist
        const permissions_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "permissions", .module = testing_graph.permissions },
        };
        addTestFilesFromDir(b, test_step, "tests/permissions", target, &permissions_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add permissions test files: {}\n", .{err});
        };
    }

    // Storage tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "storage")) {
        const storage_tests = b.addTest(.{ .root_module = testing_graph.storage });
        const run_storage_tests = addSuiteRun(b, launch, storage_tests, "src-storage", null);
        test_step.dependOn(&run_storage_tests.step);

        // Add dedicated test files from tests/storage/
        const storage_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "storage", .module = testing_graph.storage },
            // infra.tombstones: the slot counts of storage's long-lived maps.
            .{ .name = "infra", .module = testing_graph.infra },
        };
        addTestFilesFromDir(b, test_step, "tests/storage", target, &storage_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add storage test files: {}\n", .{err});
        };
    }

    // CookieStore tests (WHATWG Cookie Store API)
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "cookiestore")) {
        const cookiestore_tests = b.addTest(.{ .root_module = testing_graph.cookiestore });
        const run_cookiestore_tests = addSuiteRun(b, launch, cookiestore_tests, "src-cookiestore", null);
        test_step.dependOn(&run_cookiestore_tests.step);

        // Add dedicated test files from tests/cookiestore/
        const cookiestore_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "cookiestore", .module = testing_graph.cookiestore },
            .{ .name = "public_suffix", .module = testing_graph.cookiestore.import_table.get("public_suffix").? },
            .{ .name = "impls", .module = testing_graph.impls },
            .{ .name = "interfaces", .module = testing_graph.interfaces },
            .{ .name = "runtime", .module = testing_graph.runtime },
        };
        addTestFilesFromDir(b, test_step, "tests/cookiestore", target, &cookiestore_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add cookiestore test files: {}\n", .{err});
        };
    }

    // Runtime tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "runtime")) {
        // The runtime tier's tests link no engine, and bind the engine
        // protocol to an adapter with none behind it.
        //
        // A second binding of the facade cannot share a compile with the
        // production one: Zig checks that a file belongs to one module over
        // the whole import graph, analysed or not ("file exists in modules
        // 'engine' and 'engine0'"). testing_graph.runtime reaches the V8 binding
        // through a `v8` import (runtime -> v8 -> impls -> engine), so these
        // tests use runtime without one - the runtime tier as the engine
        // boundary leaves it. (runtime itself imports no v8 any more: its last
        // use, realm.zig's populateIntrinsics, moved into the adapter's
        // createWindowRealm.)
        //
        // The runtime imports "engine" too, so a tier is a copy of testing_graph.runtime
        // bound to its own facade: every import of testing_graph.runtime except v8 and
        // engine, plus the facade the tier's adapter makes. A copy that kept
        // testing_graph.runtime's engine would reach the V8-bound facade a second way,
        // and the facade's file cannot be in two modules of one compile.
        const test_adapter_tier = runtimeTier(b, target, testing_graph.runtime, b.path("tests/runtime/protocol_test_adapter.zig"));
        const runtime_tier_mod = test_adapter_tier.runtime;
        const test_adapter_engine_mod = test_adapter_tier.engine;
        // Every tests/runtime file sees the protocol bound to the runtime
        // tier's test adapter. And each other adapter with no engine behind
        // it - the JavaScriptCore and QuickJS protocol roots, which nothing
        // else compiles while -Dengine=jsc|quickjs is not buildable - gets the
        // protocol's tests in a compile of its own, with a runtime tier of its
        // own: compiling the facade against an adapter is what checks it
        // against the protocol.
        for ([_][]const u8{ "jsc", "quickjs" }) |adapter| {
            const adapter_tier = runtimeTier(b, target, testing_graph.runtime, b.path(b.fmt("src/runtime/engines/{s}/protocol.zig", .{adapter})));
            const conformance = b.addTest(.{
                .name = b.fmt("engine_protocol_{s}", .{adapter}),
                .root_module = b.createModule(.{
                    .root_source_file = b.path("tests/runtime/engine_protocol_test.zig"),
                    .target = target,
                    .imports = &.{
                        .{ .name = "runtime", .module = adapter_tier.runtime },
                        .{ .name = "engine", .module = adapter_tier.engine },
                    },
                }),
            });
            test_step.dependOn(&addSuiteRun(b, launch, conformance, conformance.name, null).step);
        }
        const runtime_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "runtime", .module = runtime_tier_mod },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "engine", .module = test_adapter_engine_mod },
        };
        addTestFilesFromDir(b, test_step, "tests/runtime", target, &runtime_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add runtime test files: {}\n", .{err});
        };
    }

    // V8 engine tests.
    //
    // Its own directory because it is the only one that needs the `v8` module
    // itself. Test blocks living inside `src/runtime/engines/v8/*.zig` are NEVER
    // run - `addTestFilesFromDir` only collects `tests/**/ *_test.zig` - so a test
    // written next to the code it covers is a test that does not exist.
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "v8")) {
        const v8_test_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "runtime", .module = testing_graph.runtime },
            .{ .name = "v8", .module = testing_graph.v8 },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "engine", .module = testing_graph.engine },
            // The generated interfaces, for a test host that makes platform
            // objects - a Window for a realm (page_realm_operations_test.zig).
            .{ .name = "interfaces", .module = testing_graph.interfaces },
            // The impl helpers a tests/v8 test reaches through an impl's
            // re-export (Response.streams_js, for the Deferred lifetime test).
            .{ .name = "impls", .module = testing_graph.impls },
            // DOM's hooks, for a test that fires a trusted event
            // (dom.fire_event) - the one module already in this graph
            // through impls, not a second binding of it.
            .{ .name = "dom", .module = testing_graph.dom },
            // URLPattern's construction and matching, whose regexps run in
            // the engine (urlpattern_*_test.zig), and URL for its corpus.
            .{ .name = "urlpattern", .module = testing_graph.urlpattern },
            .{ .name = "url", .module = testing_graph.url },
            // This build's snapshot (`test_snapshot_options`).
            .{ .name = "test_snapshot", .module = test_snapshot_module },
        };
        addTestFilesFromDir(b, test_step, "tests/v8", target, &v8_test_imports, true, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add v8 test files: {}\n", .{err});
        };
    }

    // Codegen tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "codegen")) {
        const codegen_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "codegen", .module = testing_graph.codegen },
            .{ .name = "webidl", .module = testing_graph.webidl },
            .{ .name = "infra", .module = testing_graph.infra },
        };
        addTestFilesFromDir(b, test_step, "tests/codegen", target, &codegen_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add codegen test files: {}\n", .{err});
        };
    }

    // Intl tests (ECMA-402 Internationalization APIs)
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "intl")) {
        const intl_tests = b.addTest(.{ .root_module = testing_graph.intl });
        const run_intl_tests = addSuiteRun(b, launch, intl_tests, "src-intl", null);
        test_step.dependOn(&run_intl_tests.step);

        // Add dedicated test files from tests/intl/
        const intl_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "intl", .module = testing_graph.intl },
        };
        addTestFilesFromDir(b, test_step, "tests/intl", target, &intl_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add intl test files: {}\n", .{err});
        };
    }

    // Platform tests
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "platform")) {
        const platform_tests = b.addTest(.{ .root_module = testing_graph.platform });
        const run_platform_tests = addSuiteRun(b, launch, platform_tests, "src-platform", null);
        test_step.dependOn(&run_platform_tests.step);

        const platform_imports = [_]std.Build.Module.Import{
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "platform", .module = testing_graph.platform },
            .{ .name = "platform_options", .module = testing_graph.platform_options },
            // dp1_local_datetime_test.zig checks against localtime_r through the
            // <time.h> module kit/posix imports (addCImport: one per graph).
            .{ .name = "c_time", .module = testing_graph.c_time },
            // tls1_stack_overflow_test.zig runs the stack-overflow fixture
            // (tests/platform/stack_overflow_fixture.zig): a program set up
            // as Crane's roots are - no signal stack from std, the platform's
            // own alternate stack (kit/posix/signal_stack.zig, compiled in as
            // it is) - in the two modes whose builds report a stack overflow:
            // ReleaseSafe (the release console, the production runner) and
            // Debug (the bug-finding runner's Crane modules).
            .{ .name = "stack_overflow_fixtures", .module = stack_overflow_fixtures: {
                const options = b.addOptions();
                for ([_]std.builtin.OptimizeMode{ .ReleaseSafe, .Debug }) |mode| {
                    const fixture = b.addExecutable(.{
                        .name = b.fmt("stack_overflow_fixture_{t}", .{mode}),
                        .root_module = b.createModule(.{
                            .root_source_file = b.path("tests/platform/stack_overflow_fixture.zig"),
                            .target = target,
                            .optimize = mode,
                            .link_libc = true,
                            .imports = &.{.{ .name = "signal_stack", .module = b.createModule(.{
                                .root_source_file = b.path("src/platform/kit/posix/signal_stack.zig"),
                                .target = target,
                                .optimize = mode,
                                .link_libc = true,
                            }) }},
                        }),
                    });
                    options.addOptionPath(if (mode == .debug) "debug" else "release_safe", fixture.getEmittedBin());
                }
                break :stack_overflow_fixtures options.createModule();
            } },
        };
        addTestFilesFromDir(b, test_step, "tests/platform", target, &platform_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add platform test files: {}\n", .{err});
        };

        // TRANSITIONAL: the old platform code step 0 keeps, compiled until each
        // recipes step that replaces it retires it (tests/platform/
        // retained_old_platform.zig). Its own executable: the old root shares
        // files with the facade, so it cannot join a compile that has `platform`.
        // Fetch now reaches that facade for SRI. The retained adapter uses
        // only network.backend, so keep its real code in a narrow test graph.
        const retained_fetch = b.createModule(.{
            .root_source_file = b.path("src/fetch/retained_network_root.zig"),
            .target = target,
            .imports = &.{.{ .name = "kit_curl_share", .module = testing_graph.fetch.import_table.get("kit_curl_share").? }},
        });
        const old_platform = b.createModule(.{
            .root_source_file = b.path("src/platform/root.zig"),
            .target = target,
            .imports = &.{
                .{ .name = "clock", .module = testing_graph.clock },
                .{ .name = "host", .module = testing_graph.host },
                .{ .name = "fetch", .module = retained_fetch },
            },
        });
        const retained_old_platform = b.addTest(.{
            .name = "retained_old_platform",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/platform/retained_old_platform.zig"),
                .target = target,
                .imports = &.{.{ .name = "platform_legacy", .module = old_platform }},
            }),
        });
        test_step.dependOn(&addSuiteRun(b, launch, retained_old_platform, "retained_old_platform", null).step);

        // The contract against every built-in platform (the directory's
        // executable above binds `testing`), and once with capabilities
        // compiled out: tests/platform/protocol_conformance_test.zig, each its
        // own small executable - the facade, one platform, the kit, nothing
        // of the engine.
        const conformance_bindings = [_]struct { name: []const u8, platform: Platform, without: []const []const u8 }{
            .{ .name = "darwin", .platform = .darwin, .without = &.{} },
            .{ .name = "linux", .platform = .linux, .without = &.{} },
            .{ .name = "testing_without_camera_clipboard", .platform = .testing, .without = &.{ "camera", "clipboard" } },
            .{ .name = "testing_without_brotli", .platform = .testing, .without = &.{"brotli"} },
            .{ .name = "testing_without_image_decoding", .platform = .testing, .without = &.{"image_decoding"} },
            .{ .name = "testing_without_image_encoding", .platform = .testing, .without = &.{"image_encoding"} },
            .{ .name = "testing_without_font_decoding", .platform = .testing, .without = &.{"font_decoding"} },
            .{ .name = "darwin_without_font_decoding", .platform = .darwin, .without = &.{"font_decoding"} },
        };
        for (conformance_bindings) |binding| {
            const bound = platformBinding(b, target, .{
                .platform = binding.platform,
                .brotli = brotli,
                .image_codecs = image_codecs,
                .without = binding.without,
                .http2 = enable_http2 and !use_system_curl,
                .libcurl = if (static_libcurl) |lib| lib.libcurl else null,
                .mbedtls = if (static_libcurl) |lib| lib.mbedtls else null,
                .clock = testing_graph.clock,
                .host = testing_graph.host,
                .memory = testing_graph.memory,
                .mimesniff = testing_graph.mimesniff,
            });
            const conformance = b.addTest(.{
                .name = b.fmt("platform_protocol_{s}", .{binding.name}),
                .root_module = b.createModule(.{
                    .root_source_file = b.path("tests/platform/protocol_conformance_test.zig"),
                    .target = target,
                    .imports = &.{
                        .{ .name = "platform", .module = bound.facade },
                        .{ .name = "platform_options", .module = bound.options },
                    },
                }),
            });
            const run_conformance = addSuiteRun(b, launch, conformance, conformance.name, null);
            // The file tests write under tmp/, relative to the repo root.
            run_conformance.setCwd(b.path("."));
            test_step.dependOn(&run_conformance.step);
            // The font operations on darwin and linux (decision 20):
            // tests/platform/font_adapters.zig, bound to each.
            if ((binding.platform == .darwin or binding.platform == .linux) and binding.without.len == 0) {
                const font_adapters = b.addTest(.{
                    .name = b.fmt("platform_fonts_{s}", .{binding.name}),
                    .root_module = b.createModule(.{
                        .root_source_file = b.path("tests/platform/font_adapters.zig"),
                        .target = target,
                        .imports = &.{.{ .name = "platform", .module = bound.facade }},
                    }),
                });
                const run_font_adapters = addSuiteRun(b, launch, font_adapters, font_adapters.name, null);
                // WPT's fonts, relative to the repo root.
                run_font_adapters.setCwd(b.path("."));
                test_step.dependOn(&run_font_adapters.step);
                check_target_step.dependOn(&font_adapters.step);
                // Media decoding on darwin and linux (lane wptcfg, D4): the
                // directory's tests/platform/media_decoding_test.zig, bound to
                // each - the three default platforms share kit/media_decoding.
                const media_decoding = b.addTest(.{
                    .name = b.fmt("platform_media_{s}", .{binding.name}),
                    .root_module = b.createModule(.{
                        .root_source_file = b.path("tests/platform/media_decoding_test.zig"),
                        .target = target,
                        .imports = &.{.{ .name = "platform", .module = bound.facade }},
                    }),
                });
                test_step.dependOn(&addSuiteRun(b, launch, media_decoding, media_decoding.name, null).step);
                check_target_step.dependOn(&media_decoding.step);
            }
            // The kit parts with test blocks of their own, once (they do
            // not depend on the platform they are bound with).
            if (std.mem.eql(u8, binding.name, "darwin")) {
                for ([_]*std.Build.Module{ bound.kit_sfnt, bound.kit_inflate, bound.kit_media_decoding }, [_][]const u8{ "kit_sfnt", "kit_inflate", "kit_media_decoding" }) |module, name| {
                    const kit_tests = b.addTest(.{ .name = name, .root_module = module });
                    test_step.dependOn(&addSuiteRun(b, launch, kit_tests, name, null).step);
                }
            }
            // Built, not run: the target need not be this machine.
            check_target_step.dependOn(&conformance.step);
        }
    }

    // Benchmark tests (requires V8 + browser)
    //
    // Wired to a dedicated `bench` step and deliberately kept OUT of
    // `zig build test`. These are wall-clock measurements, not correctness
    // tests: a timing threshold in the correctness suite goes red on machine
    // load rather than on a defect, and a gate that fails for reasons unrelated
    // to the change trains people to ignore red.
    //
    // This was not hypothetical. `context_creation_bench_test.zig:262` asserted
    // navigate+eval < 15ms while its strictly cheaper navigate-only sibling was
    // measured at ~24ms and had its own threshold raised to 30ms three hours
    // later (f34d490341, then 69cd1a159 on 2025-12-23). It was unsatisfiable on
    // any machine from that moment and stayed red for nine months.
    //
    // Run deliberately, on an idle machine: `zig build bench`.
    // Mirrors the existing `intl-bench` step.
    const bench_step = b.step("bench", "Run browser performance benchmarks (wall-clock; run on an idle machine)");
    {
        const benchmark_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = clock_mod },
            .{ .name = "host", .module = host_mod },
            .{ .name = "browser", .module = browser_mod },
            .{ .name = "runtime", .module = runtime_mod },
        };
        addTestFilesFromDir(b, bench_step, "tests/benchmarks", target, &benchmark_imports, true, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add benchmark test files: {}\n", .{err});
        };

        // Intl's wall-clock benchmarks (avg-ns thresholds) belong here for the same
        // reason: in `zig build test` they went red under build load, not on a defect
        // (2026-09-30: three DateTimeFormat/NumberFormat thresholds failed a lane's gate
        // while three test builds shared the machine).
        const intl_bench_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = clock_mod },
            .{ .name = "host", .module = host_mod },
            .{ .name = "intl", .module = intl_mod },
        };
        addTestFilesFromDir(b, bench_step, "tests/intl_bench", target, &intl_bench_imports, false, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add intl benchmark test files: {}\n", .{err});
        };
    }

    // ========================================================================
    // BROWSER TEST - Standalone browser initialization test
    // ========================================================================

    // tests/browser/: a directory suite like any (a new file there joins it),
    // run by its own step rather than by `test` - one more root compile of
    // the whole engine with V8 linked. Its directory is recorded whatever
    // -Dspec selects (addTestFilesFromDir), so the configure check counts it.
    const test_browser_step = b.step("test-browser", "Run browser initialization tests (tests/browser/)");
    const browser_test_imports = [_]std.Build.Module.Import{
        .{ .name = "browser", .module = testing_graph.browser },
    };
    addTestFilesFromDir(b, test_browser_step, "tests/browser", target, &browser_test_imports, true, test_selection) catch |err| {
        std.debug.print("Warning: Failed to add browser test files: {}\n", .{err});
    };

    // ========================================================================
    // EXECUTABLE (optional CLI tool)
    // ========================================================================

    const exe = b.addExecutable(.{
        .name = "whatwg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "whatwg", .module = whatwg_mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the WHATWG CLI tool");
    run_step.dependOn(&run_cmd.step);

    // ========================================================================
    // C LIBRARY TARGET (for Swift/Kotlin/C integration)
    // ========================================================================

    // Static library (libwhatwg.a). exports.zig allocates with
    // std.heap.c_allocator, so it links libc: a Darwin target links libSystem
    // whatever the module says, a Linux target only when asked, and without
    // it c_allocator is a compile error there.
    const static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "whatwg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/platform/exports.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    b.installArtifact(static_lib);

    // Shared library (libwhatwg.so / libwhatwg.dylib), libc as above.
    const shared_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "whatwg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/platform/exports.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    b.installArtifact(shared_lib);

    // Built into the cache, not installed: a cross check must not replace the
    // host's zig-out/lib/libwhatwg.a.
    check_target_step.dependOn(&static_lib.step);
    check_target_step.dependOn(&shared_lib.step);

    // Build step for just the C library
    const lib_step = b.step("lib", "Build the C-compatible static and shared libraries");
    const install_static = b.addInstallArtifact(static_lib, .{});
    const install_shared = b.addInstallArtifact(shared_lib, .{});
    lib_step.dependOn(&install_static.step);
    lib_step.dependOn(&install_shared.step);

    // ========================================================================
    // FULL BROWSER RUNTIME LIBRARY (includes all WebIDL interfaces + V8)
    // ========================================================================

    // Create lib_exports module with all necessary imports
    const lib_exports_mod = b.createModule(.{
        .root_source_file = b.path("src/lib_exports.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add all the imports that lib_exports.zig needs
    lib_exports_mod.addImport("runtime", runtime_mod);
    lib_exports_mod.addImport("webidl", webidl_mod);
    lib_exports_mod.addImport("infra", infra_mod);
    lib_exports_mod.addImport("engine", engine_mod);
    lib_exports_mod.addImport("interfaces", interfaces_mod);
    lib_exports_mod.addImport("impls", impls_mod);
    lib_exports_mod.addImport("namespaces", namespaces_mod);
    lib_exports_mod.addImport("dictionaries", dictionaries_mod);
    lib_exports_mod.addImport("typedefs", typedefs_mod);
    lib_exports_mod.addImport("enums", enums_mod);
    lib_exports_mod.addImport("callbacks", callbacks_mod);
    lib_exports_mod.addImport("mixins", mixins_mod);
    lib_exports_mod.addImport("browser", browser_mod);
    lib_exports_mod.addImport("dom", dom_mod);
    lib_exports_mod.addImport("encoding", encoding_mod);
    lib_exports_mod.addImport("url", url_mod);
    lib_exports_mod.addImport("console", console_mod);
    lib_exports_mod.addImport("streams", streams_mod);
    lib_exports_mod.addImport("mimesniff", mimesniff_mod);
    lib_exports_mod.addImport("fetch", fetch_mod);
    lib_exports_mod.addImport("html_core", html_core_mod);
    lib_exports_mod.addImport("html", html_mod);
    lib_exports_mod.addImport("storage", storage_mod);
    lib_exports_mod.addImport("trusted_types", trusted_types_mod);
    lib_exports_mod.addImport("csp", csp_mod);
    lib_exports_mod.addImport("hr_time", hr_time_mod);
    lib_exports_mod.addImport("websocket", websocket_mod);
    lib_exports_mod.addImport("permissions", permissions_mod);
    lib_exports_mod.addImport("intl", intl_mod);
    lib_exports_mod.addImport("platform", platform_mod);

    // Static library with full browser runtime (libwhatwg_full.a)
    const full_static_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "whatwg_full",
        .root_module = lib_exports_mod,
    });

    // Zig does not resolve the iOS SDK itself; without this the C sources below
    // fail on <stdio.h> and the link fails on libSystem.
    addIosSdkPaths(full_static_lib.root_module, ios_sdk);
    // The V8 wrapper, V8's archives and their C++ runtime (-Dv8).
    linkV8(b, full_static_lib.root_module, v8);

    // Configure storage backends
    configureStorageBackends(lib_exports_mod, target);

    b.installArtifact(full_static_lib);

    // The C ABI's own tests - a browser created and destroyed through it under
    // std.testing.allocator - run with the browser tests: nothing else compiles
    // this module for the host.
    const lib_exports_test = b.addTest(.{ .root_module = lib_exports_mod });
    test_browser_step.dependOn(&addSuiteRun(b, launch, lib_exports_test, "lib-exports", null).step);

    // Build step for the full browser runtime library
    const lib_full_step = b.step("lib-full", "Build the full browser runtime library with all WebIDL interfaces");
    const install_full_static = b.addInstallArtifact(full_static_lib, .{});
    lib_full_step.dependOn(&install_full_static.step);

    // ========================================================================
    // CRANE BROWSER (Self-contained browser with static V8)
    // ========================================================================
    //
    // Build: zig build browser
    // Output: zig-out/bin/crane (executable) + zig-out/lib/libcrane.a (library)

    // Create crane module
    const crane_mod = b.createModule(.{
        .root_source_file = b.path("src/lib_exports.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add all module imports
    crane_mod.addImport("runtime", runtime_mod);
    crane_mod.addImport("webidl", webidl_mod);
    crane_mod.addImport("infra", infra_mod);
    // lib_exports.zig reaches the engine through the protocol, as
    // lib_exports_mod does; it had "v8" and no "engine", so it did not compile.
    crane_mod.addImport("engine", engine_mod);
    crane_mod.addImport("interfaces", interfaces_mod);
    crane_mod.addImport("impls", impls_mod);
    crane_mod.addImport("namespaces", namespaces_mod);
    crane_mod.addImport("dictionaries", dictionaries_mod);
    crane_mod.addImport("typedefs", typedefs_mod);
    crane_mod.addImport("enums", enums_mod);
    crane_mod.addImport("callbacks", callbacks_mod);
    crane_mod.addImport("mixins", mixins_mod);
    crane_mod.addImport("browser", browser_mod);
    crane_mod.addImport("dom", dom_mod);
    crane_mod.addImport("encoding", encoding_mod);
    crane_mod.addImport("url", url_mod);
    crane_mod.addImport("console", console_mod);
    crane_mod.addImport("streams", streams_mod);
    crane_mod.addImport("mimesniff", mimesniff_mod);
    crane_mod.addImport("fetch", fetch_mod);
    crane_mod.addImport("html_core", html_core_mod);
    crane_mod.addImport("html", html_mod);
    crane_mod.addImport("storage", storage_mod);
    crane_mod.addImport("trusted_types", trusted_types_mod);
    crane_mod.addImport("csp", csp_mod);
    crane_mod.addImport("hr_time", hr_time_mod);
    crane_mod.addImport("websocket", websocket_mod);
    crane_mod.addImport("permissions", permissions_mod);
    crane_mod.addImport("intl", intl_mod);
    crane_mod.addImport("platform", platform_mod);

    // Configure storage backends
    configureStorageBackends(crane_mod, target);

    // ---- Crane Static Library (libcrane.a) ----
    const crane_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "crane",
        .root_module = crane_mod,
    });

    // The V8 wrapper, V8's archives and their C++ runtime (-Dv8). The archives'
    // libplatform and libbase are regular ("fat") archives: GN's thin ones
    // cannot be read by Zig's linker.
    linkV8(b, crane_lib.root_module, v8);

    // System frameworks (macOS)
    if (target.result.os.tag == .macos) {
        crane_lib.root_module.linkFramework("CoreFoundation", .{});
        crane_lib.root_module.linkFramework("CoreServices", .{});
        crane_lib.root_module.linkFramework("SystemConfiguration", .{});
    }

    // ---- Crane Executable (crane) ----
    // WebDriver browser for wptrunner integration
    const crane_exe = b.addExecutable(.{
        .name = "crane",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/webdriver/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add all imports to crane executable
    const crane_exe_imports = [_]std.Build.Module.Import{
        .{ .name = "runtime", .module = runtime_mod },
        .{ .name = "interfaces", .module = interfaces_mod },
        .{ .name = "namespaces", .module = namespaces_mod },
        .{ .name = "browser", .module = browser_mod },
        .{ .name = "fetch", .module = fetch_mod },
        .{ .name = "webdriver", .module = webdriver_mod },
        // main adopts std.start's Io as the process Io (src/platform/host.zig).
        .{ .name = "host", .module = host_mod },
        // main's first step: engine.initializeBeforeThreadCreation.
        .{ .name = "engine", .module = engine_mod },
        // main attaches the main thread's alternate signal stack
        // (platform.attachSignalStack: std_options sets std's own off).
        .{ .name = "platform", .module = platform_mod },
    };
    for (crane_exe_imports) |import| crane_exe.root_module.addImport(import.name, import.module);

    // The V8 wrapper, V8's archives and their C++ runtime (-Dv8).
    linkV8(b, crane_exe.root_module, v8);

    // Configure storage backends for executable
    configureStorageBackends(crane_exe.root_module, target);

    // System frameworks (macOS)
    if (target.result.os.tag == .macos) {
        crane_exe.root_module.linkFramework("CoreFoundation", .{});
        crane_exe.root_module.linkFramework("CoreServices", .{});
        crane_exe.root_module.linkFramework("SystemConfiguration", .{});
    }

    // Build step
    const browser_step = b.step("browser", "Build Crane browser (self-contained with static V8)");

    const install_crane_lib = b.addInstallArtifact(crane_lib, .{});
    const install_crane_exe = b.addInstallArtifact(crane_exe, .{});

    browser_step.dependOn(&install_crane_lib.step);
    browser_step.dependOn(&install_crane_exe.step);

    // Add "crane" as an alias for browser step (WebDriver-controlled browser)
    const crane_step = b.step("crane", "Build Crane WebDriver browser (alias for 'browser')");
    crane_step.dependOn(&install_crane_exe.step);

    // crane without a binary: all of src/webdriver and the target platform's
    // graph analysed, v8_wrapper.cpp compiled, nothing linked. Nothing else
    // compiles either for the build machine - every test binds `testing` -
    // which is how src/webdriver sat out the Zig 0.16 migration.
    const crane_check = addCompileCheck(b, "crane_check", "src/webdriver/main.zig", target, optimize, &crane_exe_imports, v8);
    b.step("crane-check", "Compile crane (src/webdriver + the target platform's graph) without linking").dependOn(&crane_check.step);
    check_target_step.dependOn(&crane_check.step);
    // Part of the whole test run (the integrator, 2026-10-23: about 78 s and
    // 2.3 GB beside a 46-minute test), one more root under its -j.
    if ((spec_filter == null or std.mem.eql(u8, spec_filter.?, "all")) and test_selection.file == null) {
        test_step.dependOn(&crane_check.step);
    }

    // check-target for both Linux targets, one after the other, each its own
    // `zig build` (a module graph is built per target, and this invocation's is
    // the host's). -j2 inside each: two root compiles at a time, as AGENTS.md
    // asks of every local build.
    const check_linux_step = b.step("check-linux", "check-target for aarch64-linux-gnu and x86_64-linux-gnu, -Dplatform=linux (cross-compiled; nothing runs)");
    var previous_linux_check: ?*std.Build.Step = null;
    for ([_][]const u8{ "aarch64-linux-gnu", "x86_64-linux-gnu" }) |triple| {
        // -Dwpt-runner-optimize=Debug: the runner check then shares the testing
        // graph's C libraries instead of building a ReleaseSafe set of its own
        // for a binary that is never linked (build_mode.zig, ownCLibraries).
        const sub_build = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "check-target", b.fmt("-Dtarget={s}", .{triple}), "-Dplatform=linux", "-Dwpt-runner-optimize=Debug", "-j2" });
        // The parent's local cache; the global one travels as ZIG_GLOBAL_CACHE_DIR
        // in the environment (Zig 0.17's `zig build` takes no --global-cache-dir).
        sub_build.addArg("--cache-dir");
        sub_build.addDirectoryArg2(std.Build.LazyPath.cache_root, .{ .make_absolute = true });
        sub_build.setCwd(b.path("."));
        // The sub-build decides what is up to date; this step always asks it.
        sub_build.has_side_effects = true;
        if (previous_linux_check) |previous| sub_build.step.dependOn(previous);
        previous_linux_check = &sub_build.step;
        check_linux_step.dependOn(&sub_build.step);
    }

    // lib-full for aarch64-ios, its own `zig build` like check-linux: a static
    // library, so it builds every C library and all of Crane for iOS and links
    // nothing (an iOS link also needs a V8 ios-arm64 prebuilt that matches the
    // wrapper - 24 V8 API symbols are missing from today's, lane zig017trial -
    // and iOS ships on JavaScriptCore). -Dios-sdk passes through: the merge
    // check runs `zig build check-ios -Dios-sdk=$HOME/sdks/iPhoneOS.sdk -j2`.
    // PAUSED (the user, 2026-11-10 15:55 ET: "skip ios builds and tests for now
    // until we get js core implemented"): the sub-build's engine links nothing
    // yet for iOS, so its lib-full fails with that adapter's reason, and this
    // step with it, until the adapter builds lib-full; it is no gate.
    const check_ios_step = b.step("check-ios", "lib-full for aarch64-ios (a static library: built, not linked); -Dios-sdk passes through");
    const ios_build = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "lib-full", "-Dtarget=aarch64-ios", "-j2" });
    if (ios_sdk_option) |sdk| ios_build.addArg(b.fmt("-Dios-sdk={s}", .{sdk}));
    // The parent's local cache; the global one travels as ZIG_GLOBAL_CACHE_DIR
    // in the environment (Zig 0.17's `zig build` takes no --global-cache-dir).
    ios_build.addArg("--cache-dir");
    ios_build.addDirectoryArg2(std.Build.LazyPath.cache_root, .{ .make_absolute = true });
    ios_build.setCwd(b.path("."));
    ios_build.has_side_effects = true;
    check_ios_step.dependOn(&ios_build.step);

    // ========================================================================
    // WEBIDL TOOLS
    // ========================================================================

    // Codegen tool
    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/codegen_main.zig"),
            // Build-time tool: must run on the HOST. Using `target` cross-compiled it,
            // so `zig build -Dtarget=aarch64-ios` tried to build the code generator
            // for the phone and then run it here.
            .target = b.graph.host,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "codegen", .module = codegen_mod },
                .{ .name = "webidl", .module = webidl_mod },
                .{ .name = "infra", .module = infra_mod },
            },
        }),
    });
    b.installArtifact(codegen_exe);

    // Add run step for codegen (don't depend on full install to avoid build errors in other tools)
    const run_codegen = b.addRunArtifact(codegen_exe);
    run_codegen.addPassthruArgs();

    const codegen_step = b.step("codegen", "Run WebIDL code generator (use -- to pass args)");
    codegen_step.dependOn(&run_codegen.step);

    // The codegen drift check: regenerate the whole tree from scratch, from
    // specs/idl and specs/supplementary in one invocation, into a temporary
    // directory, and compare it byte for byte with the committed generated
    // directories under src/webidl/. A hand-edited generated file, an IDL or
    // codegen change committed without its regeneration, or a stale generated
    // file all fail it. `zig build test` runs it.
    const codegen_check = b.addRunArtifact(codegen_exe);
    // It reads specs/ and src/webidl/, which the build graph does not track.
    codegen_check.has_side_effects = true;
    codegen_check.setCwd(b.path("."));
    codegen_check.addArgs(&.{ "--check", "--dest-root", "src/webidl", "--scratch" });
    codegen_check.addDirectoryArg(b.tmpPath().path(b, "tree"));
    const codegen_check_step = b.step("codegen-check", "Fail if the committed generated WebIDL tree differs from a from-scratch regeneration");
    codegen_check_step.dependOn(&codegen_check.step);
    // ~45 s on chat (a full regeneration and a byte compare of ~2,900 files).
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "codegen")) {
        test_step.dependOn(&codegen_check.step);
    }

    // IDL scanner tool
    const idl_scanner_exe = b.addExecutable(.{
        .name = "idl-scanner",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/idl_scanner_main.zig"),
            // Build-time tool: must run on the HOST. Using `target` cross-compiled it,
            // so `zig build -Dtarget=aarch64-ios` tried to build the code generator
            // for the phone and then run it here.
            .target = b.graph.host,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "codegen", .module = codegen_mod },
                .{ .name = "webidl", .module = webidl_mod },
            },
        }),
    });
    b.installArtifact(idl_scanner_exe);

    // Add run step for idl-scanner
    const run_idl_scanner = b.addRunArtifact(idl_scanner_exe);
    run_idl_scanner.step.dependOn(b.getInstallStep());
    run_idl_scanner.addPassthruArgs();

    const idl_scanner_step = b.step("idl-scanner", "Run IDL scanner tool (use -- to pass args)");
    idl_scanner_step.dependOn(&run_idl_scanner.step);

    // Interfaces tool
    const interfaces_exe = b.addExecutable(.{
        .name = "interfaces",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/interfaces_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "interfaces", .module = interfaces_mod },
                .{ .name = "runtime", .module = runtime_mod },
            },
        }),
    });
    b.installArtifact(interfaces_exe);

    // Add run step for interfaces tool
    const run_interfaces_tool = b.addRunArtifact(interfaces_exe);
    run_interfaces_tool.step.dependOn(b.getInstallStep());
    run_interfaces_tool.addPassthruArgs();

    const interfaces_tool_step = b.step("interfaces-tool", "Run interfaces tool (use -- to pass args)");
    interfaces_tool_step.dependOn(&run_interfaces_tool.step);

    // ========================================================================
    // SNAPSHOT GENERATOR (must be defined before REPL and WPT runner)
    // ========================================================================

    // The generator's mode is fixed - Debug, whatever -Doptimize says
    // (tools/snapshot_generator_mode.zig): the blob it writes is a function
    // of the source, not of the optimizer, and every artifact restores it
    // whatever its own mode. Built with -Doptimize, a release build paid a
    // second optimized compile of Crane before its snapshot could run.
    // -Dsnapshot-generator-optimize builds another for a diagnosis.
    const snapshot_generator_mode = @import("tools/snapshot_generator_mode.zig");
    const snapshot_generator_optimize = snapshot_generator_mode.snapshotGeneratorMode(b.option(
        std.builtin.OptimizeMode,
        "snapshot-generator-optimize",
        "Optimize mode of the V8 snapshot generator (default: Debug, whatever -Doptimize says)",
    ));

    // Snapshot Generator tool for creating V8 heap snapshots with WebIDL interfaces
    const snapshot_gen_exe = b.addExecutable(.{
        .name = "snapshot_generator",
        .root_module = b.createModule(.{
            // Snapshots are V8's by nature (engine.capabilities.restores_snapshots),
            // so the generator lives inside the V8 adapter.
            .root_source_file = b.path("src/runtime/engines/v8/snapshot_generator.zig"),
            // Build-time tool: must run on the HOST. It is executed via
            // `b.addRunArtifact` below, so building it for `target` means
            // `zig build -Dtarget=aarch64-ios` produces a phone binary and then
            // tries to run it here. The same fix landed for codegen, the IDL
            // scanner and the three cldr tools; this one was missed, and it would
            // have been the next failure after the V8 blocker is lifted.
            .target = b.graph.host,
            .optimize = snapshot_generator_optimize,
            .imports = &.{
                .{ .name = "runtime", .module = runtime_mod },
                .{ .name = "v8", .module = v8_mod },
                .{ .name = "interfaces", .module = interfaces_mod },
                .{ .name = "namespaces", .module = namespaces_mod },
            },
        }),
    });

    // The V8 wrapper, V8's archives and their C++ runtime (-Dv8).
    linkV8(b, snapshot_gen_exe.root_module, v8_tests);

    // A ReleaseSafe generator (-Dsnapshot-generator-optimize) over the
    // Debug-built C libraries links the full UBSan runtime they call into.
    if (snapshot_generator_mode.sanitizeC(snapshot_generator_optimize)) |sanitizer| snapshot_gen_exe.root_module.sanitize_c = sanitizer;

    // Add run step for Snapshot Generator (manual use)
    const run_snapshot_gen = b.addRunArtifact(snapshot_gen_exe);
    run_snapshot_gen.addPassthruArgs();

    const snapshot_gen_step = b.step("snapshot-generator", "Run snapshot generator (use -- to pass output path)");
    snapshot_gen_step.dependOn(&run_snapshot_gen.step);

    // tools/snapshot_generator_mode.zig: the generator's fixed mode, std-only.
    const snapshot_generator_mode_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tools/snapshot_generator_mode.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&addSuiteRun(b, launch, snapshot_generator_mode_tests, "tools-snapshot_generator_mode", null).step);

    // ========================================================================
    // SNAPSHOT GENERATION (auto-generate snapshot for fast browser startup)
    // ========================================================================

    // The generator writes into the cache (an output file argument, so the
    // run is cached on the generator's hash) and the install step copies the
    // blob to the install prefix's bin/ - zig-out/bin/whatwg_snapshot.bin,
    // where the runner, the console and gc_bench look for it - making that
    // directory. The generator was handed "zig-out/bin/whatwg_snapshot.bin"
    // to write itself, and a fresh checkout has no zig-out/bin: `zig build
    // snapshot` failed with FileNotFound there (server1's first native run,
    // 2026-11-07); crane-remote.sh's `mkdir -p zig-out/bin` hid it on the
    // pool's hosts.
    const gen_snapshot = b.addRunArtifact(snapshot_gen_exe);
    const install_snapshot = b.addInstallBinFile(gen_snapshot.addOutputFileArg("whatwg_snapshot.bin"), "whatwg_snapshot.bin");

    // Create a build step for manual snapshot generation
    const snapshot_step = b.step("snapshot", "Generate V8 heap snapshot with WebIDL interfaces");
    snapshot_step.dependOn(&install_snapshot.step);

    // The tests' snapshot: the same generator, into the cache (an output
    // file argument, so the run is cached on the generator's hash), passed
    // to tests/v8 by path (`test_snapshot_options` above).
    const gen_test_snapshot = b.addRunArtifact(snapshot_gen_exe);
    // Under -Dsanitize-thread the generator shares instrumented modules with
    // the tests: it runs with their suppressions (useTsanSuppressions).
    if (sanitize_thread_option) {
        useTsanSuppressions(b, gen_test_snapshot);
        useTsanSuppressions(b, gen_snapshot);
        useTsanSuppressions(b, run_snapshot_gen);
    }
    test_snapshot_options.addOptionPath("path", gen_test_snapshot.addOutputFileArg("whatwg_snapshot.bin"));

    // ========================================================================
    // REPL TOOL
    // ========================================================================

    // The browser console (tools/repl.zig): a Browser on a page, and the
    // console that evaluates in it - REPL-mode evaluation through the engine
    // (engine.evaluateReplScript), the Browser's event loop running while an
    // evaluation waits (Browser.spinEventLoopUntil), results printed by the
    // Console Standard's printer (src/console/printer.zig). Its imports are
    // the ones the console uses, and nothing else.
    // The console is a user-facing tool: ReleaseSafe unless asked otherwise,
    // the WPT runner's rule (tests/wpt_runner/build_mode.zig runnerModes,
    // pinned by its tests) - `-Drepl-optimize=Debug` (or an explicit
    // `-Doptimize=Debug`) builds the Debug console a diagnosis wants. Its
    // root decides the LLVM pipeline of all of its Zig; Crane's modules keep
    // -Doptimize's `builtin.mode`. A Debug console was slow to the point of
    // lag: std's Debug allocator captures a stack trace per allocation and
    // free (tools/repl.zig, main, chooses its own allocator too).
    // `-Dwpt-runner-release` makes it Crane's release build, the one the
    // performance suite times beside the browsers (tools/perf_bench,
    // docs/performance.md): release_runner's modes exactly (build_mode.zig
    // consoleModes) over the production graph - the very graph the
    // production WPT runner links (`production_graph` above), so what WPT
    // scores and times is what the console runs (the user, 2026-11-09).
    const repl_modes = runner_build_mode.consoleModes(
        runner_release,
        b.option(std.builtin.OptimizeMode, "repl-optimize", "Optimize mode of the browser console (default: ReleaseSafe, or -Doptimize when given; Debug for a diagnosis)"),
        optimize,
        optimize_given,
    );
    const repl_graph = if (runner_release != null) production_graph else crane_graph;
    // What that graph's C libraries are built with (-Dsystem-curl builds the
    // production graph as the shared one, runnerGraph).
    const repl_c: CModes = if (runner_release != null and !use_system_curl) .libraries(repl_modes) else shared_c;
    const repl_optimize = repl_modes.root;
    const repl_exe = b.addExecutable(.{
        .name = "repl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/repl.zig"),
            .target = target,
            .optimize = repl_optimize,
            .imports = &.{
                .{ .name = "engine", .module = repl_graph.engine },
                .{ .name = "browser", .module = repl_graph.browser },
                .{ .name = "console", .module = repl_graph.console },
                // Real time for the console's deadlines (platform.monotonicNow).
                .{ .name = "platform", .module = repl_graph.platform },
            },
        }),
    });

    // The C libraries it links are built with -Doptimize's mode and its C
    // sanitizer: a ReleaseSafe root links the full UBSan runtime they call
    // into (the runner's rule, RunnerModes.sanitize_c), or the link misses
    // __ubsan_handle_* (libbrotli, a Debug-built C library).
    if (repl_modes.sanitize_c) |sanitizer| repl_exe.root_module.sanitize_c = sanitizer;
    // And it links the runtime for C libraries built with the full sanitizer
    // (the shared graph's, in Debug), as the runners do (addWptRunner); the
    // release console's are `.trap`, so it links none.
    if (repl_c.compilesFull()) repl_exe.bundle_ubsan_rt = true;

    // The V8 wrapper, V8's archives and their C++ runtime (-Dv8).
    linkV8(b, repl_exe.root_module, v8);

    // The snapshot the console's Browser starts from (zig-out/bin/
    // whatwg_snapshot.bin, read beside the binary when it RUNS): its install
    // waits for the generator, its compile does not, so the console's
    // compile and the generator's build and run go side by side.
    const install_repl = b.addInstallArtifact(repl_exe, .{});
    install_repl.step.dependOn(&install_snapshot.step);
    b.getInstallStep().dependOn(&install_repl.step);
    // A release console names its build beside itself (zig-out/bin/
    // repl.modes, build_mode.zig `writeModesFile`): its modes and the CPU
    // its code is for (-Dcpu, or the build host's when none is given), in
    // the pin's own key=value lines, so the performance suite's pin records
    // the build's identity from what was built. The user, 2026-11-06:
    // published Crane numbers use a FIXED CPU target, -Dcpu=apple_m1 -
    // standardTargetOptions has no default, so without it a console is
    // tuned to whichever pool host built it (docs/performance.md).
    if (runner_release != null) {
        var modes_text: std.Io.Writer.Allocating = .init(b.allocator);
        runner_build_mode.writeModesFile(&modes_text.writer, repl_modes, target.result.cpu, runner_build_mode.cpuIsNative(target.query)) catch @panic("OOM");
        const modes_file = b.addWriteFiles().add("repl.modes", modes_text.written());
        install_repl.step.dependOn(&b.addInstallBinFile(modes_file, "repl.modes").step);
    }

    // `zig build repl-exe`: the console alone - zig-out/bin/repl and its
    // snapshot - not the install step (19 artifacts, a root-module analysis
    // of the tree each: the ReleaseSafe console took ~2 h on the Mac that
    // way, 2026-11-02).
    const repl_exe_step = b.step("repl-exe", "Build the browser console alone (zig-out/bin/repl)");
    repl_exe_step.dependOn(&install_repl.step);

    // `zig build repl -- <args>`: build the console alone, then run it.
    const run_repl = b.addRunArtifact(repl_exe);
    run_repl.step.dependOn(&install_repl.step);
    run_repl.addPassthruArgs();

    const repl_step = b.step("repl", "Run the browser console (use -- to pass args)");
    repl_step.dependOn(&run_repl.step);

    // The console-parity step: WPT parity through the console
    // (tools/console_parity.zig) - each test file of a list opened by the
    // console binary against `wpt serve`, its results compared with a WPT
    // runner journal. It expands a source into the runner's own runs with
    // the runner's own parser (tests/wpt_runner/test_parser.zig, with the
    // imports the harness tests give it below), and is built for the
    // console's target: it runs where the console does.
    const parity_test_parser_mod = b.createModule(.{
        .root_source_file = b.path("tests/wpt_runner/test_parser.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "clock", .module = clock_mod },
            .{ .name = "host", .module = host_mod },
            .{ .name = "xml", .module = crane_graph.xml },
            .{ .name = "xml_document_encoding", .module = crane_graph.xml_document_encoding },
        },
    });
    const console_parity_exe = b.addExecutable(.{
        .name = "console_parity",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/console_parity.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{.{ .name = "wpt_test_parser", .module = parity_test_parser_mod }},
        }),
    });
    const install_console_parity = b.addInstallArtifact(console_parity_exe, .{});
    const console_parity_step = b.step("console-parity", "Build the console's WPT parity tool alone (zig-out/bin/console_parity)");
    console_parity_step.dependOn(&install_console_parity.step);
    const console_parity_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tools/console_parity.zig"),
        .target = target,
        .optimize = .Debug,
        .link_libc = true,
        .imports = &.{.{ .name = "wpt_test_parser", .module = b.createModule(.{
            .root_source_file = b.path("tests/wpt_runner/test_parser.zig"),
            .target = target,
            .imports = &.{
                .{ .name = "clock", .module = testing_graph.clock },
                .{ .name = "host", .module = testing_graph.host },
                .{ .name = "xml", .module = testing_graph.xml },
                .{ .name = "xml_document_encoding", .module = testing_graph.xml_document_encoding },
            },
        }) }},
    }) });
    test_step.dependOn(&addSuiteRun(b, launch, console_parity_tests, "tools-console_parity", null).step);

    // tests/repl/: the browser console driven in-process (tools/repl.zig's
    // Console fed lines, its output read back), part of `zig build test`.
    // Each test starts a Browser: batch 1 (suite_configs, tests-repl).
    // Selected with the Browser's own spec name, -Dspec=browser (tests/console/
    // is the Console Standard's suite, without V8).
    if (spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "browser")) {
        const repl_test_mod = b.createModule(.{
            .root_source_file = b.path("tools/repl.zig"),
            .target = target,
            .imports = &.{
                .{ .name = "engine", .module = testing_graph.engine },
                .{ .name = "browser", .module = testing_graph.browser },
                .{ .name = "console", .module = testing_graph.console },
                .{ .name = "platform", .module = testing_graph.platform },
            },
        });
        const console_test_imports = [_]std.Build.Module.Import{
            .{ .name = "repl", .module = repl_test_mod },
            .{ .name = "browser", .module = testing_graph.browser },
            .{ .name = "engine", .module = testing_graph.engine },
            .{ .name = "console", .module = testing_graph.console },
            .{ .name = "clock", .module = testing_graph.clock },
        };
        addTestFilesFromDir(b, test_step, "tests/repl", target, &console_test_imports, true, test_selection) catch |err| {
            std.debug.print("Warning: Failed to add repl test files: {}\n", .{err});
        };
    }

    // ========================================================================
    // GC BENCHMARK (Phase 6 exit criterion)
    // ========================================================================

    // Same module set and link lines as the REPL, because it is the same thing:
    // a full Browser driving real JS. It differs only in what it runs and that it
    // reads resident memory between batches.
    //
    // Built in the WPT runner's root mode (ReleaseSafe by default,
    // `-Dwpt-runner-optimize=Debug` for both): its timings are bars beside the
    // runner's pages, and a Debug gc_bench measures a different engine - at -O0
    // v8_wrapper.cpp's inlined V8 helpers were 45% of an indexed read
    // (tmp/plans/lane-idxfast-handoff.md). Its Crane modules and C libraries
    // are -Doptimize's, as the runner's modules are.
    const gc_bench_exe = b.addExecutable(.{
        .name = "gc_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gc_bench.zig"),
            .target = target,
            .optimize = gc_bench_modes.root,
            .imports = &.{
                .{ .name = "runtime", .module = runtime_mod },
                .{ .name = "engine", .module = engine_mod },
                .{ .name = "memory", .module = memory_mod },
                .{ .name = "interfaces", .module = interfaces_mod },
                .{ .name = "namespaces", .module = namespaces_mod },
                .{ .name = "fetch", .module = fetch_mod },
                .{ .name = "platform", .module = platform_mod },
                .{ .name = "html", .module = html_core_mod },
                .{ .name = "html_full", .module = html_mod },
                .{ .name = "dom", .module = dom_mod },
                .{ .name = "infra", .module = infra_mod },
                .{ .name = "browser", .module = browser_mod },
                .{ .name = "impls", .module = impls_mod },
                .{ .name = "webidl", .module = webidl_mod },
                .{ .name = "dictionaries", .module = dictionaries_mod },
            },
        }),
    });

    // Only this binary pays for Global<T> accounting. It runs on every
    // handle creation, so a browser should not carry it.
    addV8Source(b, gc_bench_exe.root_module, v8, &.{"-DCRANE_TRACK_GLOBALS=1"});
    addV8Archives(gc_bench_exe.root_module, v8);
    // As the runner's: the full C sanitizer, and its runtime bundled for the
    // C libraries a release root links when they are built with the full
    // sanitizer (the shared graph's: -Doptimize's mode; see addWptRunner).
    if (gc_bench_modes.sanitize_c) |sanitizer| gc_bench_exe.root_module.sanitize_c = sanitizer;
    if (shared_c.compilesFull()) gc_bench_exe.bundle_ubsan_rt = true;
    gc_bench_exe.step.dependOn(&install_snapshot.step);

    b.installArtifact(gc_bench_exe);

    const run_gc_bench = b.addRunArtifact(gc_bench_exe);
    // gc_bench's own install, not the whole install step: that built all 19
    // installed artifacts, a root-module analysis of the tree each, before a
    // run that needs one of them.
    run_gc_bench.step.dependOn(&b.addInstallArtifact(gc_bench_exe, .{}).step);
    run_gc_bench.addPassthruArgs();

    const gc_bench_step = b.step("gc-bench", "Measure RSS across createElement+discard cycles (Phase 6)");
    gc_bench_step.dependOn(&run_gc_bench.step);

    // Part of `zig build test`: gc_bench's command line (the per-cycle script,
    // --body / --control), tested on its own - gc_bench.zig links the engine,
    // gc_bench_options.zig only std.
    const gc_bench_options_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tools/gc_bench_options.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&addSuiteRun(b, launch, gc_bench_options_tests, "tools-gc_bench_options", null).step);

    // ========================================================================
    // WPT (Web Platform Tests) RUNNER
    // ========================================================================

    // Poison on free, std only: the sweep allocator's front
    // (runner_allocator.zig), shared with the Crane test runner, which
    // imports the same file as one beside it (lane poison2).
    const poisoning_module = b.createModule(.{
        .root_source_file = b.path("tests/test_runner/poisoning.zig"),
        .target = target,
    });

    // Unit tests for the runner's pure-Zig support modules. These import only
    // std, so they build and run without V8 or libuv - which means the parts of
    // the harness that decide *which* tests exist and *which* are in scope are
    // covered by `zig build test`, not just by the runner binary.
    {
        const harness_sources = [_][]const u8{
            "tests/wpt_runner/manifest.zig",
            "tests/wpt_runner/config.zig",
            "tests/wpt_runner/selection.zig",
            "tests/wpt_runner/journal.zig",
            "tests/wpt_runner/repeat.zig",
            // Not part of the WPT runner, but the same shape - std-only, and its
            // test blocks would otherwise never run, since the build collects
            // tests/**/*_test.zig and nothing else.
            "src/platform/memory.zig",
            "tests/wpt_runner/options.zig",
            "tests/wpt_runner/discovery.zig",
            "tests/wpt_runner/webdriver_keys.zig",
            "tests/wpt_runner/wpt_server.zig",
            "tests/wpt_runner/baseline.zig",
            "tests/wpt_runner/test_parser.zig",
            "tests/wpt_runner/output.zig",
            "tests/wpt_runner/stall_watchdog.zig",
            "tests/wpt_runner/wpt_test_ids.zig",
            "tests/wpt_runner/result_reporter.zig",
            "tests/wpt_runner/runner_allocator.zig",
            "tests/wpt_runner/script_deadline.zig",
            "tests/wpt_runner/build_mode.zig",
            "tests/wpt_runner/file_lock.zig",
            "tests/wpt_runner/work_queue.zig",
            "tests/wpt_runner/build_compare.zig",
        };
        for (harness_sources) |src| {
            const harness_tests = b.addTest(.{
                .root_module = b.createModule(.{
                    .root_source_file = b.path(src),
                    .target = target,
                    .optimize = optimize,
                    // host is std-only (plus libc); it keeps these modules free
                    // of V8 and libuv while giving them the process std.Io.
                    .imports = &.{
                        .{ .name = "clock", .module = testing_graph.clock },
                        .{ .name = "host", .module = testing_graph.host },
                        .{ .name = "xml", .module = testing_graph.xml },
                        .{ .name = "xml_document_encoding", .module = testing_graph.xml_document_encoding },
                        // runner_allocator.zig's Poisoning (lane poison2).
                        .{ .name = "poisoning", .module = poisoning_module },
                    },
                }),
            });
            const run_harness_tests = addSuiteRun(b, launch, harness_tests, b.fmt("wpt_runner-{s}", .{std.fs.path.stem(src)}), null);
            // test-verify for the runner's own modules: their tests live in
            // the module (no *_test.zig), so each module root is its own
            // "directory executable" of one file for the verify mode -
            // -Dverify-files=tests/wpt_runner/work_queue.zig.
            if (std.mem.startsWith(u8, src, "tests/wpt_runner/")) addTestVerify(b, launch, harness_tests, b.fmt("wpt_runner-{s}", .{std.fs.path.stem(src)}), "tests/wpt_runner", &.{std.fs.path.basename(src)});
            // manifest.zig has a regression test that reads the real
            // tests/wpt/MANIFEST.json by relative path (and skips itself when
            // the WPT checkout is absent), so it must run from the repo root.
            run_harness_tests.setCwd(b.path("."));
            test_step.dependOn(&run_harness_tests.step);
        }
    }

    // Real testdriver commands need the Browser graph; keep this one Debug
    // native lifetime test separate from the std-only harness modules above.
    const command_lifetime_test = "tests/wpt_runner/ar3_command_lifetime_test.zig";
    // The directory's std-only modules (harness_sources, above) and this test.
    recordSuiteDir(b, test_selection, "tests/wpt_runner");
    if ((spec_filter == null or std.mem.eql(u8, spec_filter.?, "all") or std.mem.eql(u8, spec_filter.?, "wpt_runner")) and
        (test_selection.file == null or std.mem.eql(u8, test_selection.file.?, command_lifetime_test)))
    {
        const command_test_imports = [_]std.Build.Module.Import{
            .{ .name = "clock", .module = testing_graph.clock },
            .{ .name = "host", .module = testing_graph.host },
            .{ .name = "xml", .module = testing_graph.xml },
            .{ .name = "xml_document_encoding", .module = testing_graph.xml_document_encoding },
            .{ .name = "runtime", .module = testing_graph.runtime },
            .{ .name = "engine", .module = testing_graph.engine },
            .{ .name = "interfaces", .module = testing_graph.interfaces },
            .{ .name = "html", .module = testing_graph.html_core },
            .{ .name = "html_full", .module = testing_graph.html },
            .{ .name = "dom", .module = testing_graph.dom },
            .{ .name = "browser", .module = testing_graph.browser },
            .{ .name = "cookiestore", .module = testing_graph.cookiestore },
            .{ .name = "permissions", .module = testing_graph.permissions },
        };
        _ = addTestRoot(b, test_step, command_lifetime_test, "ar3-command-lifetime", null, target, &command_test_imports, true, launch, v8_tests);
    }

    // The WPT runner's two builds (build_mode.zig `RunnerBuild`, the graphs
    // above): `wpt_runner`, the PRODUCTION run - Crane exactly as the release
    // console runs it - and `wpt_runner_bug_finding`, the same product with
    // detection added. Each is one ReleaseSafe compile of the whole tree
    // (about 12 min cold on Zig 0.17), so each has a step of its own and
    // neither step builds the other.
    // WPT build options
    const wpt_output = b.option(
        []const u8,
        "wpt-output",
        "Output path for wptreport.json (default: wpt-results/)",
    ) orelse "wpt-results";

    const wpt_verbose = b.option(
        bool,
        "wpt-verbose",
        "Show verbose output for each test",
    ) orelse false;

    const wpt_debug = b.option(
        bool,
        "wpt-debug",
        "Enable debug log output (std.log.debug) during WPT tests",
    ) orelse false;

    const wpt_runner_exe = addWptRunner(b, .production, production_build, production_graph, production_c, .{
        .target = target,
        .poisoning = poisoning_module,
        .install_snapshot = &install_snapshot.step,
        .wpt_debug = wpt_debug,
        .check_target = check_target_step,
        .v8 = v8,
    });
    const wpt_runner_check = wpt_runner_exe.check;
    // Build ONLY wpt_runner. A bare `zig build` compiles all 19 installed
    // artifacts, and every one that embeds the tree is a separate root-module
    // analysis of ~1M lines - about 6 GB of RAM each, three at a time by
    // default. On a 32 GB machine, one full build plus two agents doing the
    // same is swap, not CPU. The WPT loop needs exactly this executable:
    //
    //     zig build wpt-runner -j2 --cache-dir /tmp/<cache>
    //
    // `-j2` caps concurrent root compiles; the `wpt` step (build + run) is the
    // other single-artifact path.
    const wpt_runner_step = b.step("wpt-runner", "Build only wpt_runner, the PRODUCTION WPT runner (Crane's production configuration: published and timed); pair with -j2");
    wpt_runner_step.dependOn(&wpt_runner_exe.install.step);
    const bug_finding_runner = addWptRunner(b, .bug_finding, bug_finding_build, bug_finding_graph, bug_finding_c, .{
        .target = target,
        .poisoning = poisoning_module,
        .install_snapshot = &install_snapshot.step,
        .wpt_debug = wpt_debug,
        .check_target = check_target_step,
        .v8 = v8,
    });
    // The two runs compared (tests/wpt_runner/build_compare.zig): the
    // bug-finding run's gate - no crash, poison read, leak, double free,
    // panic, refcount or ownership violation - and every difference between
    // the runs against tools/wpt_build_differences.txt. std-only: built for
    // the host, it reads journals, result streams and logs.
    const build_compare_exe = b.addExecutable(.{
        .name = "wpt_build_compare",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/wpt_runner/build_compare.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
            .imports = &.{.{ .name = "host", .module = testing_graph.host }},
        }),
    });
    const install_build_compare = b.addInstallArtifact(build_compare_exe, .{});
    b.getInstallStep().dependOn(&install_build_compare.step);
    const run_build_compare = b.addRunArtifact(build_compare_exe);
    run_build_compare.setCwd(b.path("."));
    run_build_compare.addPassthruArgs();
    const build_compare_step = b.step("wpt-build-compare", "Compare a production WPT run with a bug-finding run of the same tree: the bug-finding gate, and every difference against tools/wpt_build_differences.txt (use -- --production=<dir> --bug-finding=<dir> --log=<sweep.log>)");
    build_compare_step.dependOn(&run_build_compare.step);
    const install_build_compare_step = b.step("wpt-build-compare-exe", "Build only zig-out/bin/wpt_build_compare");
    install_build_compare_step.dependOn(&install_build_compare.step);
    const bug_finding_step = b.step("wpt-runner-bug-finding", "Build only wpt_runner_bug_finding, the BUG-FINDING WPT runner (debug allocator, poison-on-free, Debug checks, the full C sanitizer: never published or timed); pair with -j2");
    bug_finding_step.dependOn(&bug_finding_runner.install.step);

    // Add step to clear WPT ports before running
    // There used to be a `clear_ports` pre-step here that `kill -9`ed every
    // process on 8000-8003, 8443-8446 and 9000 before each run. On a machine
    // where several runners share one `wpt serve`, that killed the server out
    // from under all of them mid-run (2026-09-22 09:03, three agents), and
    // the orphaned children it left holding :8000 became the "adopted corpse"
    // failure documented in AGENTS.md. The runner now adopts a live server by
    // probing the port and deletes a stale lockfile itself, so nothing here
    // needs to kill anything.

    // Add run step for WPT runner
    const run_wpt = b.addRunArtifact(wpt_runner_exe.exe);
    // Only wpt_runner. `b.getInstallStep()` here meant `zig build wpt` built
    // all 19 installed artifacts - see the `wpt-runner` step above for the cost.
    run_wpt.step.dependOn(&wpt_runner_exe.install.step);

    // Pass build options as command-line arguments
    run_wpt.addArg(b.fmt("--output={s}", .{wpt_output}));
    if (wpt_verbose) {
        run_wpt.addArg("--verbose");
    }

    // Pass through any additional args (e.g., category filters)
    run_wpt.addPassthruArgs();

    const wpt_step = b.step("wpt", "Run Web Platform Tests (use -- to pass args like url/)");
    wpt_step.dependOn(&run_wpt.step);

    // Refresh the 0.1 progress report from whatever journals exist.
    //
    // Attached to `wpt` rather than left as a separate command anyone has to
    // remember: the report is the thing that says whether the release gate is
    // met, and a report you have to remember to regenerate is a report that is
    // usually wrong. It sat five hours stale exactly that way.
    //
    // It reads journals and writes wpt-results/progress.html, so it is safe to
    // run when no tests ran at all - it just reports the accumulated state.
    const progress_report = b.addSystemCommand(&.{ "python3", "tools/wpt_progress.py" });
    progress_report.step.dependOn(&run_wpt.step);
    wpt_step.dependOn(&progress_report.step);

    // Same thing on its own, for refreshing the page without running tests.
    const progress_step = b.step("wpt-progress", "Regenerate wpt-results/progress.html (and the public results site) from existing journals");
    const progress_only = b.addSystemCommand(&.{ "python3", "tools/wpt_progress.py" });

    // ========================================================================
    // WPT: the public results site (tools/wpt_site/)
    // ========================================================================
    // tools/wpt_site/generate.zig writes Crane's static WPT results site -
    // finished HTML for the index, every directory and every test file, the
    // social card and the hand-written assets - from the state
    // and history the progress report keeps, the worklist, and the runner's
    // per-file result streams, into wpt-results/site/. `wpt-progress` runs it
    // after every regeneration of the report; when wpt-results/site is a
    // worktree of the gh-pages branch it commits there, and it never pushes.
    // `zig build test` runs its tests.
    const wpt_site_module = b.createModule(.{
        .root_source_file = b.path("tools/wpt_site/generate.zig"),
        // A tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
    });
    const wpt_site_exe = b.addExecutable(.{ .name = "wpt_site", .root_module = wpt_site_module });
    const wpt_site_run = b.addRunArtifact(wpt_site_exe);
    wpt_site_run.has_side_effects = true;
    wpt_site_run.setCwd(b.path("."));
    wpt_site_run.addPassthruArgs();
    const wpt_site_step = b.step("wpt-site", "Regenerate the public WPT results site in wpt-results/site/ (-- --out=<dir> --no-commit ...)");
    wpt_site_step.dependOn(&wpt_site_run.step);
    // The same, after the report: every regeneration of the report regenerates the site.
    const wpt_site_after_progress = b.addRunArtifact(wpt_site_exe);
    wpt_site_after_progress.has_side_effects = true;
    wpt_site_after_progress.setCwd(b.path("."));
    wpt_site_after_progress.step.dependOn(&progress_only.step);
    progress_step.dependOn(&wpt_site_after_progress.step);
    // And after the report `wpt` refreshes, so every regeneration of the report - both
    // steps that write it - regenerates the site (the user's requirement, 2026-09-30).
    const wpt_site_after_wpt = b.addRunArtifact(wpt_site_exe);
    wpt_site_after_wpt.has_side_effects = true;
    wpt_site_after_wpt.setCwd(b.path("."));
    wpt_site_after_wpt.step.dependOn(&progress_report.step);
    wpt_step.dependOn(&wpt_site_after_wpt.step);
    const wpt_site_tests = b.addTest(.{ .root_module = wpt_site_module });
    const run_wpt_site_tests = addSuiteRun(b, launch, wpt_site_tests, "tools-wpt_site", null);
    test_step.dependOn(&run_wpt_site_tests.step);

    // ========================================================================
    // The UBSan-symbol check
    // ========================================================================
    // tools/ubsan_symbols.zig counts the `__ubsan_handle_*` symbols in a built
    // binary's symbol tables. The end of build() runs it on the production
    // runner, the bug-finding runner and the release console as part of
    // their own steps (checkLinkedC's builds). Its tests read real objects:
    // one C source compiled for ELF and for Mach-O, with the full sanitizer
    // (it calls handlers) and at `.trap` (it calls none).
    const ubsan_fixture_source = b.addWriteFiles().add("ubsan_fixture.c",
        \\int crane_fixture_add(int a, int b) { return a + b; }
        \\int crane_fixture_shift(int a, int b) { return a << b; }
        \\
    );
    const ubsan_fixtures = b.addOptions();
    for ([_]struct { []const u8, []const u8 }{ .{ "elf", "x86_64-linux-none" }, .{ "mach_o", "aarch64-macos-none" } }) |format| {
        const fixture_target = b.resolveTargetQuery(std.Target.Query.parse(.{ .arch_os_abi = format[1] }) catch @panic("fixture target"));
        for ([_]std.zig.SanitizeC{ .full, .trap }) |sanitizer| {
            const object = b.addObject(.{
                .name = b.fmt("ubsan_fixture_{s}_{t}", .{ format[0], sanitizer }),
                .root_module = b.createModule(.{ .target = fixture_target, .optimize = .ReleaseSafe, .sanitize_c = sanitizer }),
            });
            object.root_module.addCSourceFile(.{ .file = ubsan_fixture_source });
            ubsan_fixtures.addOptionPath(b.fmt("{s}_{t}", .{ format[0], sanitizer }), object.getEmittedBin());
        }
    }
    const ubsan_symbols_module = b.createModule(.{
        .root_source_file = b.path("tools/ubsan_symbols.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    ubsan_symbols_module.addOptions("ubsan_fixtures", ubsan_fixtures);
    const ubsan_symbols_exe = b.addExecutable(.{ .name = "ubsan_symbols", .root_module = ubsan_symbols_module });
    const ubsan_symbols_tests = b.addTest(.{ .root_module = ubsan_symbols_module });
    test_step.dependOn(&addSuiteRun(b, launch, ubsan_symbols_tests, "tools-ubsan_symbols", null).step);
    // Verify mode for its tests, which live in the tool:
    // -Dverify-files=tools/ubsan_symbols.zig.
    addTestVerify(b, launch, ubsan_symbols_tests, "tools-ubsan_symbols", "tools", &.{"ubsan_symbols.zig"});

    // ========================================================================
    // The thread-local block check
    // ========================================================================
    // tools/thread_local_size.zig reads how many bytes of thread-local
    // storage a built binary's image carries - a per-THREAD cost: macOS
    // allocates the image's whole block for a thread on its first touch of
    // any thread-local, glibc with every thread - and its largest
    // thread-local symbols. The end of build() runs it on the same three
    // binaries as the UBSan-symbol check, as part of their own steps,
    // against tools/thread_local_size_budget.txt, which only goes down
    // (`zig build thread-local-size -- --budget=<file> --lower=<bytes>`).
    // Its tests read real objects: one C source compiled for ELF and for
    // Mach-O, with a 65,536-byte thread-local array and without.
    const thread_local_fixture_source = b.addWriteFiles().add("thread_local_fixture.c",
        \\#ifdef CRANE_FIXTURE_PLAIN
        \\#define CRANE_FIXTURE_STORAGE
        \\#else
        \\#define CRANE_FIXTURE_STORAGE _Thread_local
        \\#endif
        \\CRANE_FIXTURE_STORAGE char crane_fixture_big[65536];
        \\CRANE_FIXTURE_STORAGE int crane_fixture_small = 7;
        \\char *crane_fixture_touch(void) { crane_fixture_small += 1; return crane_fixture_big; }
        \\
    );
    const thread_local_fixtures = b.addOptions();
    for ([_]struct { []const u8, []const u8 }{ .{ "elf", "x86_64-linux-none" }, .{ "mach_o", "aarch64-macos-none" } }) |format| {
        const fixture_target = b.resolveTargetQuery(std.Target.Query.parse(.{ .arch_os_abi = format[1] }) catch @panic("fixture target"));
        for ([_]struct { []const u8, []const []const u8 }{ .{ "", &.{} }, .{ "_plain", &.{"-DCRANE_FIXTURE_PLAIN"} } }) |variant| {
            const object = b.addObject(.{
                .name = b.fmt("thread_local_fixture_{s}{s}", .{ format[0], variant[0] }),
                .root_module = b.createModule(.{ .target = fixture_target, .optimize = .ReleaseSafe }),
            });
            object.root_module.addCSourceFile(.{ .file = thread_local_fixture_source, .flags = variant[1] });
            thread_local_fixtures.addOptionPath(b.fmt("{s}{s}", .{ format[0], variant[0] }), object.getEmittedBin());
        }
    }
    const thread_local_size_module = b.createModule(.{
        .root_source_file = b.path("tools/thread_local_size.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    thread_local_size_module.addOptions("thread_local_fixtures", thread_local_fixtures);
    const thread_local_size_exe = b.addExecutable(.{ .name = "thread_local_size", .root_module = thread_local_size_module });
    const thread_local_size_tests = b.addTest(.{ .root_module = thread_local_size_module });
    test_step.dependOn(&addSuiteRun(b, launch, thread_local_size_tests, "tools-thread_local_size", null).step);
    // Verify mode for its tests, which live in the tool:
    // -Dverify-files=tools/thread_local_size.zig.
    addTestVerify(b, launch, thread_local_size_tests, "tools-thread_local_size", "tools", &.{"thread_local_size.zig"});
    const thread_local_size_run = b.addRunArtifact(thread_local_size_exe);
    thread_local_size_run.has_side_effects = true;
    thread_local_size_run.setCwd(b.path("."));
    thread_local_size_run.addPassthruArgs();
    b.step("thread-local-size", "Report a binary's thread-local block and its largest thread-local symbols (-- [--budget=tools/thread_local_size_budget.txt] <binary>; -- --budget=<file> --lower=<bytes> records a lower budget)").dependOn(&thread_local_size_run.step);

    // ========================================================================
    // PERFORMANCE: the benchmark suite's runner and /performance/ (tools/perf_bench/)
    // ========================================================================
    // tools/perf_bench serves tests/perf/ (the engine-neutral workload
    // pages), launches each pinned engine on them - Crane's console in its
    // release build, Chrome, Firefox, Safari, Lightpanda - reads each
    // engine's process set as the pages report, writes the journal, and
    // renders /performance/ from journals (docs/performance.md). A tool:
    // std only (no engine), on the host. Its card reuses the WPT site's
    // atlas and its page the WPT site's HTML helpers.
    const perf_bench_module = b.createModule(.{
        .root_source_file = b.path("tools/perf_bench/main.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        // libproc (proc_pid_rusage) and mach_timebase_info are libSystem's.
        .link_libc = true,
        .imports = &.{
            .{ .name = "site_html", .module = b.createModule(.{ .root_source_file = b.path("tools/wpt_site/html.zig"), .target = b.graph.host, .optimize = .ReleaseSafe }) },
            .{ .name = "site_card", .module = b.createModule(.{ .root_source_file = b.path("tools/wpt_site/card.zig"), .target = b.graph.host, .optimize = .ReleaseSafe }) },
        },
    });
    const perf_bench_exe = b.addExecutable(.{ .name = "perf_bench", .root_module = perf_bench_module });
    const install_perf_bench = b.addInstallArtifact(perf_bench_exe, .{});
    const perf_bench_step = b.step("perf-bench", "Build the benchmark suite's runner and report tool alone (zig-out/bin/perf_bench)");
    perf_bench_step.dependOn(&install_perf_bench.step);
    const perf_bench_tests = b.addTest(.{ .root_module = perf_bench_module });
    const run_perf_bench_tests = addSuiteRun(b, launch, perf_bench_tests, "tools-perf_bench", null);
    test_step.dependOn(&run_perf_bench_tests.step);
    // The suite held to its pages: every page there, every workload the
    // suite lists declared by its page and none declared but unlisted.
    const perf_suite_check = b.addRunArtifact(perf_bench_exe);
    perf_suite_check.setCwd(b.path("."));
    perf_suite_check.addArgs(&.{ "check-suite", "--suite=tests/perf/suite.json", "--root=tests/perf" });
    perf_suite_check.has_side_effects = true;
    test_step.dependOn(&perf_suite_check.step);
    // The memory-per-element pages are a suite of their own (one case per
    // page, `retained`), so suite.json stays the pages every round repeats.
    const elements_suite_check = b.addRunArtifact(perf_bench_exe);
    elements_suite_check.setCwd(b.path("."));
    elements_suite_check.addArgs(&.{ "check-suite", "--suite=tests/perf/elements.json", "--root=tests/perf" });
    elements_suite_check.has_side_effects = true;
    test_step.dependOn(&elements_suite_check.step);
    // `zig build perf-bench-test`: the tool's tests and the suite check
    // alone, with build_mode's (the console's release modes).
    const perf_bench_test_step = b.step("perf-bench-test", "Run tools/perf_bench's tests, the suite check, the WPT site's tests, the runner build-mode tests and the UBSan-symbol check's tests alone");
    perf_bench_test_step.dependOn(&run_perf_bench_tests.step);
    perf_bench_test_step.dependOn(&perf_suite_check.step);
    perf_bench_test_step.dependOn(&elements_suite_check.step);
    // The WPT site's tests too: /performance/'s card draws with its atlas,
    // and the site leaves performance/ alone and links to it.
    perf_bench_test_step.dependOn(&run_wpt_site_tests.step);
    perf_bench_test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tests/wpt_runner/build_mode.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    }) }), "perf-build_mode", null).step);
    // The check that reads the built runners and console back (build_mode's
    // modes, as their binaries carry them).
    perf_bench_test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = ubsan_symbols_module }), "perf-ubsan_symbols", null).step);

    // ========================================================================
    // FRAMEWORKS: the JS framework compatibility matrix's harness (tools/fw_matrix/)
    // ========================================================================
    // tools/fw_matrix fetches the frameworks' pinned suites by checksum,
    // serves each suite's tree on 127.0.0.1, opens its pages in Crane's
    // console (`repl <url>`, a fresh one per page), reads the framework's own
    // report and writes the journal (tmp/plans/framework-matrix-plan.md). A
    // tool: std only, on the host; no Node.
    const fw_matrix_module = b.createModule(.{
        .root_source_file = b.path("tools/fw_matrix/main.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
        // The report's HTML helpers are the WPT site's (escaping, numbers).
        .imports = &.{
            .{ .name = "site_html", .module = b.createModule(.{ .root_source_file = b.path("tools/wpt_site/html.zig"), .target = b.graph.host, .optimize = .ReleaseSafe }) },
        },
    });
    const fw_matrix_exe = b.addExecutable(.{ .name = "fw_matrix", .root_module = fw_matrix_module });
    const install_fw_matrix = b.addInstallArtifact(fw_matrix_exe, .{});
    const fw_matrix_step = b.step("fw-matrix", "Build the JS framework matrix's harness alone (zig-out/bin/fw_matrix)");
    fw_matrix_step.dependOn(&install_fw_matrix.step);
    const fw_matrix_tests = b.addTest(.{ .root_module = fw_matrix_module });
    const run_fw_matrix_tests = addSuiteRun(b, launch, fw_matrix_tests, "tools-fw_matrix", null);
    test_step.dependOn(&run_fw_matrix_tests.step);
    addTestVerify(b, launch, fw_matrix_tests, "tools-fw_matrix", "tools/fw_matrix", &.{
        "main.zig",      "journal.zig", "exclusions.zig", "manifest.zig", "readers.zig",
        "generated.zig", "server.zig",  "fetch.zig",      "run.zig",      "report.zig",
    });
    // The manifest and the exclusion lists, read strictly: every entry with
    // its reason, each belonging to a page.
    const fw_matrix_check = b.addRunArtifact(fw_matrix_exe);
    fw_matrix_check.setCwd(b.path("."));
    fw_matrix_check.addArgs(&.{"check"});
    fw_matrix_check.has_side_effects = true;
    test_step.dependOn(&fw_matrix_check.step);
    const fw_matrix_test_step = b.step("fw-matrix-test", "Run tools/fw_matrix's tests and its manifest check alone");
    fw_matrix_test_step.dependOn(&run_fw_matrix_tests.step);
    fw_matrix_test_step.dependOn(&fw_matrix_check.step);

    // tools/test_suites.zig: the configure-time check that every tests/<dir>/
    // with test files is a suite (checkEveryTestDirectoryIsASuite), std-only.
    const test_suites_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tools/test_suites.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&addSuiteRun(b, launch, test_suites_tests, "tools-test_suites", null).step);

    // tools/v8_archives.zig: the V8 archives -Dv8-build selects, std-only.
    const v8_archives_tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("tools/v8_archives.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    }) });
    test_step.dependOn(&addSuiteRun(b, launch, v8_archives_tests, "tools-v8_archives", null).step);

    // ========================================================================
    // COMPREHENSIVE BUILD TEST
    // ========================================================================

    const comprehensive_exe = b.addExecutable(.{
        .name = "comprehensive",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/comprehensive_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "whatwg", .module = whatwg_mod },
                .{ .name = "infra", .module = infra_mod },
                .{ .name = "webidl", .module = webidl_mod },
                .{ .name = "runtime", .module = runtime_mod },
                .{ .name = "dom", .module = dom_mod },
                .{ .name = "encoding", .module = encoding_mod },
                .{ .name = "url", .module = url_mod },
                .{ .name = "console", .module = console_mod },
                .{ .name = "streams", .module = streams_mod },
                .{ .name = "mimesniff", .module = mimesniff_mod },
                .{ .name = "interfaces", .module = interfaces_mod },
                .{ .name = "impls", .module = impls_mod },
            },
        }),
    });

    b.installArtifact(comprehensive_exe);

    const comprehensive_run = b.addRunArtifact(comprehensive_exe);
    comprehensive_run.step.dependOn(b.getInstallStep());

    const comprehensive_step = b.step("comprehensive", "Build comprehensive binary with all WHATWG specs");
    comprehensive_step.dependOn(&comprehensive_run.step);

    // ========================================================================
    // INTERFACES BUILD STEP - Check that all interfaces compile
    // ========================================================================

    const interfaces_check = b.addTest(.{
        .root_module = interfaces_mod,
    });

    const run_interfaces_check = addSuiteRun(b, launch, interfaces_check, "interfaces-check", null);

    const interfaces_step = b.step("interfaces", "Check that all interfaces compile");
    interfaces_step.dependOn(&run_interfaces_check.step);

    // ========================================================================
    // LINT: the impls boundary, as a ratchet
    // ========================================================================
    // AGENTS.md "The impls boundary": impls are private. tools/lint_impls_boundary.zig
    // counts every reference into an impl from code that does not own it - per file
    // and per Impl.member - and fails if any rises above
    // tools/impls_boundary_baseline.txt or a new one appears. The baseline only goes
    // down: `zig build lint-impls -- --update` records a paid-down tree and refuses
    // to record an increase.
    //
    // `zig build test` depends on it, so the pre-commit suite cannot pass with a new
    // cross-impl reference. (The check it replaces listed files importing impls
    // outside allowed directories, failed on files that predated it, and so gated
    // nothing; impl-to-impl calls were not checked at all.)
    const lint_impls_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_impls_boundary.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_impls_exe = b.addExecutable(.{
        .name = "lint_impls_boundary",
        .root_module = lint_impls_module,
    });

    const lint_impls_step = b.step("lint-impls", "Fail on new references into impls (use -- --update after paying debt down)");
    const lint_impls = b.addRunArtifact(lint_impls_exe);
    // It reads src/ and the baseline, which the build graph does not track.
    lint_impls.has_side_effects = true;
    lint_impls.setCwd(b.path("."));
    lint_impls.addPassthruArgs();
    lint_impls_step.dependOn(&lint_impls.step);

    // Part of `zig build test`: the check itself (never with --update) and the
    // tool's own tests.
    const lint_impls_check = b.addRunArtifact(lint_impls_exe);
    lint_impls_check.has_side_effects = true;
    lint_impls_check.setCwd(b.path("."));
    test_step.dependOn(&lint_impls_check.step);
    const lint_impls_tests = b.addTest(.{ .root_module = lint_impls_module });
    test_step.dependOn(&addSuiteRun(b, launch, lint_impls_tests, "tools-lint_impls", null).step);

    // ========================================================================
    // LINT: the engine boundary, as a ratchet
    // ========================================================================
    // AGENTS.md "The engine boundary": the JavaScript engine is an adapter, and
    // V8 belongs in src/runtime/engines/v8/ (and tests/v8/) only.
    // tools/lint_engine_boundary.zig counts every V8 reference elsewhere - per
    // file and per name - and fails if any rises above
    // tools/engine_boundary_baseline.txt or a new one appears. The baseline only
    // goes down: `zig build lint-engine -- --update` records a paid-down tree and
    // refuses to record an increase. `zig build test` depends on it.
    const lint_engine_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_engine_boundary.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_engine_exe = b.addExecutable(.{
        .name = "lint_engine_boundary",
        .root_module = lint_engine_module,
    });

    const lint_engine_step = b.step("lint-engine", "Fail on new V8 references outside the V8 adapter (use -- --update after paying debt down)");
    const lint_engine = b.addRunArtifact(lint_engine_exe);
    // It reads src/, tests/, tools/ and the baseline, which the build graph does not track.
    lint_engine.has_side_effects = true;
    lint_engine.setCwd(b.path("."));
    lint_engine.addPassthruArgs();
    lint_engine_step.dependOn(&lint_engine.step);

    // Part of `zig build test`: the check itself (never with --update) and the
    // tool's own tests.
    const lint_engine_check = b.addRunArtifact(lint_engine_exe);
    lint_engine_check.has_side_effects = true;
    lint_engine_check.setCwd(b.path("."));
    test_step.dependOn(&lint_engine_check.step);
    const lint_engine_tests = b.addTest(.{ .root_module = lint_engine_module });
    test_step.dependOn(&addSuiteRun(b, launch, lint_engine_tests, "tools-lint_engine", null).step);

    // ========================================================================
    // LINT: the platform boundary, as a ratchet
    // ========================================================================
    // docs/platform-protocol.md section 11: everything platform-specific goes
    // through the platform protocol (`@import("platform")`). Outside
    // src/platform/ there is no OS API and no libcurl, mbedTLS, SQLite or
    // LevelDB identifier. tools/lint_platform_boundary.zig counts every such
    // reference per file and key and fails if any rises above
    // tools/platform_boundary_baseline.txt or a new pair appears; the baseline
    // only goes down (`zig build lint-platform -- --update`).
    const lint_platform_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_platform_boundary.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_platform_exe = b.addExecutable(.{
        .name = "lint_platform_boundary",
        .root_module = lint_platform_module,
    });

    const lint_platform_step = b.step("lint-platform", "Fail on new OS or platform-library references outside src/platform/ (use -- --update after paying debt down)");
    const lint_platform = b.addRunArtifact(lint_platform_exe);
    // It reads src/, tests/, tools/ and the baseline, which the build graph does not track.
    lint_platform.has_side_effects = true;
    lint_platform.setCwd(b.path("."));
    lint_platform.addPassthruArgs();
    lint_platform_step.dependOn(&lint_platform.step);

    // Part of `zig build test`: the check itself (never with --update) and the
    // tool's own tests.
    const lint_platform_check = b.addRunArtifact(lint_platform_exe);
    lint_platform_check.has_side_effects = true;
    lint_platform_check.setCwd(b.path("."));
    test_step.dependOn(&lint_platform_check.step);
    const lint_platform_tests = b.addTest(.{ .root_module = lint_platform_module });
    test_step.dependOn(&addSuiteRun(b, launch, lint_platform_tests, "tools-lint_platform", null).step);

    // ========================================================================
    // LINT: the build's neutrality, as a ratchet
    // ========================================================================
    // The user, 2026-11-12: this file holds no code of one engine or of one
    // platform - an adapter declares its build in its own build file, behind
    // the build side of its protocol. tools/lint_build_neutral.zig counts what
    // this file and the neutral files it imports still name of either, per
    // file, per word and per kind of text (code, comment, embedded script),
    // and fails if any count rises above tools/build_neutral_baseline.txt or a
    // new one appears. The baseline only goes down, a slice with each batch of
    // the migration: `zig build lint-build -- --update` records it and refuses
    // an increase; `-- --list` prints every site. `zig build test` depends on
    // it.
    //
    // The words it looks for, a list per class. An engine's words are its
    // adapter's own, from the engine protocol's list of adapters. Until the
    // platform protocol's build file supplies the rest the same way, they are
    // spelled here - and counted like every other line of this file.
    const lint_build_words = [_][]const u8{
        "--engine=" ++ engine_build.lint_words,
        "--platform=darwin,linux,macos,word:ios,iphoneos,xcrun,homebrew,.testing",
        "--target=os.tag,isDarwin,.abi ==",
        "--library=curl,mbedtls,nghttp2,brotli,zlib,sqlite,leveldb,jpeg,expat,nanosvg",
    };
    const lint_build_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_build_neutral.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_build_exe = b.addExecutable(.{
        .name = "lint_build_neutral",
        .root_module = lint_build_module,
    });

    const lint_build_step = b.step("lint-build", "Fail when build.zig or a neutral file it imports names an engine, an operating system or a platform library more often than the baseline (use -- --update after moving a slice out; -- --list prints every site)");
    const lint_build = b.addRunArtifact(lint_build_exe);
    // It reads this file, the files it imports and the baseline, which the build graph does not track.
    lint_build.has_side_effects = true;
    lint_build.setCwd(b.path("."));
    lint_build.addArgs(&lint_build_words);
    lint_build.addPassthruArgs();
    lint_build_step.dependOn(&lint_build.step);

    // Part of `zig build test`: the check itself (never with --update) and the
    // tool's own tests.
    const lint_build_check = b.addRunArtifact(lint_build_exe);
    lint_build_check.has_side_effects = true;
    lint_build_check.setCwd(b.path("."));
    lint_build_check.addArgs(&lint_build_words);
    test_step.dependOn(&lint_build_check.step);
    const lint_build_tests = b.addTest(.{ .root_module = lint_build_module });
    test_step.dependOn(&addSuiteRun(b, launch, lint_build_tests, "tools-lint_build", null).step);

    // ========================================================================
    // LINT: global state, as a ratchet
    // ========================================================================
    // docs/instances.md: several isolated instances run in one process, each
    // with its tabs, so a container-level `var` (shared by every instance) or
    // a `threadlocal` (per thread, neither per instance nor per tab) is state
    // without an owner. tools/lint_global_state.zig counts every one in src/ -
    // Zig through std.zig.Ast, C++ by a scan of the code - per file and
    // qualified name, and fails if any rises above
    // tools/global_state_baseline.txt or a new one appears. The baseline only
    // goes down: `zig build lint-global-state -- --update` records a paid-down
    // tree and refuses to record an increase. `zig build test` depends on it.
    const lint_global_state_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_global_state.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_global_state_exe = b.addExecutable(.{
        .name = "lint_global_state",
        .root_module = lint_global_state_module,
    });

    const lint_global_state_step = b.step("lint-global-state", "Fail on new process-global or threadlocal variables in src/ (use -- --update after removing some)");
    const lint_global_state = b.addRunArtifact(lint_global_state_exe);
    // It reads src/ and the baseline, which the build graph does not track.
    lint_global_state.has_side_effects = true;
    lint_global_state.setCwd(b.path("."));
    lint_global_state.addPassthruArgs();
    lint_global_state_step.dependOn(&lint_global_state.step);

    // Part of `zig build test`: the check itself (never with --update) and the
    // tool's own tests.
    const lint_global_state_check = b.addRunArtifact(lint_global_state_exe);
    lint_global_state_check.has_side_effects = true;
    lint_global_state_check.setCwd(b.path("."));
    test_step.dependOn(&lint_global_state_check.step);
    // Unicode IDNA tables are regenerated explicitly; normal tests use inline fixtures only.
    const idna_tables_module = b.createModule(.{
        .root_source_file = b.path("tools/url/generate_idna_tables.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const idna_tables_exe = b.addExecutable(.{ .name = "idna_tables", .root_module = idna_tables_module });
    const idna_tables_run = b.addRunArtifact(idna_tables_exe);
    idna_tables_run.setCwd(b.path("."));
    idna_tables_run.has_side_effects = true;
    idna_tables_run.addPassthruArgs();
    b.step("idna-tables", "Regenerate the pinned Unicode IDNA tables from local inputs").dependOn(&idna_tables_run.step);
    test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = idna_tables_module }), "tools-idna_tables", null).step);

    // Explicit, hash-pinned Unicode casing generation; tests use local fixtures.
    const case_tables_module = b.createModule(.{
        .root_source_file = b.path("tools/unicode/generate_case_tables.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const case_tables_exe = b.addExecutable(.{ .name = "case_tables", .root_module = case_tables_module });
    const case_tables_run = b.addRunArtifact(case_tables_exe);
    case_tables_run.setCwd(b.path("."));
    case_tables_run.has_side_effects = true;
    case_tables_run.addPassthruArgs();
    b.step("case-tables", "Regenerate pinned Unicode full case mappings from local inputs").dependOn(&case_tables_run.step);
    test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = case_tables_module }), "tools-case_tables", null).step);

    const unicode_identifier_module = b.createModule(.{
        .root_source_file = b.path("tools/unicode/generate_identifier_tables.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const unicode_identifier_tests = b.addTest(.{ .root_module = unicode_identifier_module });
    test_step.dependOn(&addSuiteRun(b, launch, unicode_identifier_tests, "tools-unicode_identifier", null).step);

    const lint_global_state_tests = b.addTest(.{ .root_module = lint_global_state_module });
    test_step.dependOn(&addSuiteRun(b, launch, lint_global_state_tests, "tools-lint_global_state", null).step);

    // ========================================================================
    // LINT: reference counting's structural rules, as a ratchet
    // ========================================================================
    // tmp/plans/refcount-design.md section 7 step 2. tools/lint_refcount.zig
    // counts, through std.zig.Ast, every write to `.parent_node` outside
    // NodeBase's one setter and every counted reference (`Ref`, `GCReachableRef`)
    // held inside a node's own state, per file, and fails if any count rises
    // above tools/refcount_baseline.txt or a new pair appears. The baseline only
    // goes down (`zig build lint-refcount -- --update`). `zig build test`
    // depends on it.
    const lint_refcount_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_refcount.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_refcount_exe = b.addExecutable(.{
        .name = "lint_refcount",
        .root_module = lint_refcount_module,
    });
    const lint_refcount_step = b.step("lint-refcount", "Fail on a new write to .parent_node outside NodeBase's setter or a counted reference in node state (use -- --update after removing some)");
    const lint_refcount = b.addRunArtifact(lint_refcount_exe);
    // It reads src/ and the baseline, which the build graph does not track.
    lint_refcount.has_side_effects = true;
    lint_refcount.setCwd(b.path("."));
    lint_refcount.addPassthruArgs();
    lint_refcount_step.dependOn(&lint_refcount.step);
    // Part of `zig build test`: the check itself (never with --update) and the
    // tool's own tests.
    const lint_refcount_check = b.addRunArtifact(lint_refcount_exe);
    lint_refcount_check.has_side_effects = true;
    lint_refcount_check.setCwd(b.path("."));
    test_step.dependOn(&lint_refcount_check.step);
    const lint_refcount_tests = b.addTest(.{ .root_module = lint_refcount_module });
    test_step.dependOn(&addSuiteRun(b, launch, lint_refcount_tests, "tools-lint_refcount", null).step);

    // ========================================================================
    // LINT: long-lived hash maps that never clear their tombstones
    // ========================================================================
    // std.HashMap deletes by tombstone and never grows while puts and removes
    // balance, so a long-lived map's free slots run out and every miss walks
    // the table (src/infra/tombstones.zig; found and fixed in the instance
    // registries, the V8 wrapper cache and the timer maps).
    // tools/lint_tombstones.zig flags, through std.zig.Ast, every container
    // field or container-level `var` std hash map in src/ that its file removes
    // from with no TombstoneGuard and no `// tombstones: <why>` exemption, and
    // fails if any is missing from tools/tombstones_baseline.txt. The baseline
    // only goes down (`zig build lint-tombstones -- --update`; `-- --list`
    // prints every unguarded map). `zig build test` depends on it.
    const lint_tombstones_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_tombstones.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_tombstones_exe = b.addExecutable(.{
        .name = "lint_tombstones",
        .root_module = lint_tombstones_module,
    });
    const lint_tombstones_step = b.step("lint-tombstones", "Fail on a new long-lived std hash map that is removed from with no TombstoneGuard (use -- --update after guarding some, -- --list to see them)");
    const lint_tombstones = b.addRunArtifact(lint_tombstones_exe);
    // It reads src/ and the baseline, which the build graph does not track.
    lint_tombstones.has_side_effects = true;
    lint_tombstones.setCwd(b.path("."));
    lint_tombstones.addPassthruArgs();
    lint_tombstones_step.dependOn(&lint_tombstones.step);
    // Part of `zig build test`: the check itself (never with --update) and the
    // tool's own tests.
    const lint_tombstones_check = b.addRunArtifact(lint_tombstones_exe);
    lint_tombstones_check.has_side_effects = true;
    lint_tombstones_check.setCwd(b.path("."));
    test_step.dependOn(&lint_tombstones_check.step);
    const lint_tombstones_tests = b.addTest(.{ .root_module = lint_tombstones_module });
    test_step.dependOn(&addSuiteRun(b, launch, lint_tombstones_tests, "tools-lint_tombstones", null).step);

    // ========================================================================
    // LINT: the CSS module's two import boundaries
    // ========================================================================
    // Two cold Typed OM entries stay off CSS's parsing and computation paths
    // (Q61: the native animation-list concatenation; Q59: the canonical-text
    // inspection). Each was a `comptime {}` block that @embedFile'd and
    // searched the files it guards - 20 s of single-threaded Sema in every
    // test binary that reached src/css (lane onebin2's time report).
    // tools/lint_css_boundaries.zig checks the same files for the same
    // patterns with the same messages, once per `zig build test` (lane
    // compiletime1). Not a ratchet: any breach fails.
    const lint_css_module = b.createModule(.{
        .root_source_file = b.path("tools/lint_css_boundaries.zig"),
        // Build-time tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const lint_css_exe = b.addExecutable(.{
        .name = "lint_css_boundaries",
        .root_module = lint_css_module,
    });
    const lint_css_step = b.step("lint-css", "Fail when a CSS parsing/computation file reaches a cold Typed OM entry (Q59, Q61)");
    const lint_css = b.addRunArtifact(lint_css_exe);
    // It reads src/css, which the build graph does not track.
    lint_css.has_side_effects = true;
    lint_css.setCwd(b.path("."));
    lint_css_step.dependOn(&lint_css.step);
    test_step.dependOn(&lint_css.step);
    test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = lint_css_module }), "tools-lint_css", null).step);

    // The generated tables' tools (`addGeneratedTables`): their own tests.
    test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = module_config.tables.reverse_index_tool }), "tools-reverse_index_table", null).step);
    test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = module_config.tables.psl_tool }), "tools-psl_table", null).step);

    // ========================================================================
    // The code-size report
    // ========================================================================
    // tools/code_size_report.zig groups a binary's functions by generic
    // family - every instance of `V8Interface(X).constructorCallback` is one
    // family - from its symbol table, with count and bytes per family: what
    // LLVM emitted, so what LLVM Emit Object spent its time on (lane
    // compiletime1; Rust's cargo-llvm-lines). `zig build code-size --
    // <binary> [--top=N] [--base=<binary>] [--tsv]`.
    const code_size_module = b.createModule(.{
        .root_source_file = b.path("tools/code_size_report.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const code_size_run = b.addRunArtifact(b.addExecutable(.{ .name = "code_size_report", .root_module = code_size_module }));
    code_size_run.has_side_effects = true;
    code_size_run.setCwd(b.path("."));
    code_size_run.addPassthruArgs();
    b.step("code-size", "Group a binary's functions by generic family, with count and bytes (-- <binary> [--top=N] [--base=<binary>] [--tsv])").dependOn(&code_size_run.step);
    test_step.dependOn(&addSuiteRun(b, launch, b.addTest(.{ .root_module = code_size_module }), "tools-code_size_report", null).step);

    // ========================================================================
    // WPT: the wpt.fyi upload package
    // ========================================================================
    // tools/wpt_upload_package.zig turns a supervised sweep's reports, result
    // streams and journals into gzipped wptreport chunks for wpt.fyi, and
    // `check` dry-runs wpt.fyi's shape checks over a package. It uploads
    // nothing. `zig build test` runs its tests.
    const wpt_upload_package_module = b.createModule(.{
        .root_source_file = b.path("tools/wpt_upload_package.zig"),
        // A tool: runs on the host, as codegen does.
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const wpt_upload_package_exe = b.addExecutable(.{
        .name = "wpt_upload_package",
        .root_module = wpt_upload_package_module,
    });
    const wpt_upload_package_step = b.step("wpt-upload-package", "Package a WPT sweep for wpt.fyi (-- build --input=... --manifest=... --out=...), or check a package (-- check <chunk.json.gz>...)");
    const wpt_upload_package_run = b.addRunArtifact(wpt_upload_package_exe);
    wpt_upload_package_run.has_side_effects = true;
    wpt_upload_package_run.setCwd(b.path("."));
    wpt_upload_package_run.addPassthruArgs();
    wpt_upload_package_step.dependOn(&wpt_upload_package_run.step);
    const wpt_upload_package_tests = b.addTest(.{ .root_module = wpt_upload_package_module });
    test_step.dependOn(&addSuiteRun(b, launch, wpt_upload_package_tests, "tools-wpt_upload_package", null).step);

    // ========================================================================
    // HELP: Available JavaScript Engines
    // ========================================================================

    const help_engines_step = b.step("help-engines", "Show available JavaScript engines");
    const help_engines_cmd = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        \\echo "Available JavaScript Engines"
        \\echo "============================"
        \\echo ""
        \\echo "  v8       Google V8 (default)"
        \\echo "           - Best performance and feature support"
        \\echo "           - Supports heap snapshots for fast startup"
        \\echo "           - Isolate-per-thread threading model"
        \\echo "           - Status: FULLY IMPLEMENTED"
        \\echo "           - Requires: Homebrew V8 (brew install v8)"
        \\echo ""
        \\echo "  jsc      JavaScriptCore (WebKit)"
        \\echo "           - Native on macOS/iOS"
        \\echo "           - Good performance, stable C API"
        \\echo "           - Status: PARTIAL (see whatwg-qfv3a)"
        \\echo "           - Requires: JavaScriptCore.framework (macOS)"
        \\echo "                       javascriptcoregtk-4.0 (Linux)"
        \\echo ""
        \\echo "  quickjs  QuickJS"
        \\echo "           - Lightweight, embeddable"
        \\echo "           - Good for resource-constrained environments"
        \\echo "           - Status: PARTIAL (see whatwg-qfv3a)"
        \\echo "           - Requires: libquickjs.a"
        \\echo ""
        \\echo "Usage:"
        \\echo "  zig build -Dengine=v8      # Build with V8 (default)"
        \\echo "  zig build -Dengine=jsc     # Build with JavaScriptCore"
        \\echo "  zig build -Dengine=quickjs # Build with QuickJS"
        \\echo ""
        \\echo "Note: Currently only V8 is fully implemented."
        \\echo "JSC and QuickJS backends are tracked in issue whatwg-qfv3a."
        ,
    });
    help_engines_step.dependOn(&help_engines_cmd.step);

    // ========================================================================
    // CLDR DATA PIPELINE TOOLS
    // ========================================================================

    // CLDR Downloader - fetches CLDR JSON from Unicode
    const cldr_download_exe = b.addExecutable(.{
        .name = "cldr-download",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/cldr/download.zig"),
            // Build-time tool: must run on the HOST. Using `target` cross-compiled it,
            // so `zig build -Dtarget=aarch64-ios` tried to build the code generator
            // for the phone and then run it here.
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    b.installArtifact(cldr_download_exe);

    const run_cldr_download = b.addRunArtifact(cldr_download_exe);
    run_cldr_download.addPassthruArgs();

    const cldr_download_step = b.step("cldr-download", "Download CLDR JSON data from Unicode");
    cldr_download_step.dependOn(&run_cldr_download.step);

    // CLDR Extractor - extracts locale data to Zig source
    const cldr_extract_exe = b.addExecutable(.{
        .name = "cldr-extract",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/cldr/extract.zig"),
            // Build-time tool: must run on the HOST. Using `target` cross-compiled it,
            // so `zig build -Dtarget=aarch64-ios` tried to build the code generator
            // for the phone and then run it here.
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    b.installArtifact(cldr_extract_exe);

    const run_cldr_extract = b.addRunArtifact(cldr_extract_exe);
    run_cldr_extract.addPassthruArgs();

    const cldr_extract_step = b.step("cldr-extract", "Extract CLDR data to Zig source");
    cldr_extract_step.dependOn(&run_cldr_extract.step);

    // CLDR Encoder - encodes to binary format for Tier 2 locales
    const cldr_encode_exe = b.addExecutable(.{
        .name = "cldr-encode",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/cldr/encode.zig"),
            // Build-time tool: must run on the HOST. Using `target` cross-compiled it,
            // so `zig build -Dtarget=aarch64-ios` tried to build the code generator
            // for the phone and then run it here.
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    b.installArtifact(cldr_encode_exe);

    const run_cldr_encode = b.addRunArtifact(cldr_encode_exe);
    run_cldr_encode.addPassthruArgs();

    const cldr_encode_step = b.step("cldr-encode", "Encode CLDR data to binary format");
    cldr_encode_step.dependOn(&run_cldr_encode.step);

    // ========================================================================
    // INTL BENCHMARKING TOOL
    // ========================================================================

    // Intl Benchmark - performance benchmarks for pure Zig internationalization library
    const intl_bench_exe = b.addExecutable(.{
        .name = "intl-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/intl_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast, // Always optimize for benchmarks
        }),
    });
    intl_bench_exe.root_module.addImport("intl", intl_mod);
    b.installArtifact(intl_bench_exe);

    const run_intl_bench = b.addRunArtifact(intl_bench_exe);

    const intl_bench_step = b.step("intl-bench", "Run Intl performance benchmarks");
    intl_bench_step.dependOn(&run_intl_bench.step);

    // ========================================================================
    // SETUP: Download external data files
    // ========================================================================
    // Downloads all required data files that are not committed to the repository.
    // This includes:
    // - CLDR v46.0.0 JSON data (~745MB) for internationalization
    // - Unicode data files (UnicodeData.txt, IdnaMappingTable.txt, etc.)
    // - Public Suffix List (PSL) for domain parsing
    // - IDNA test data for URL conformance tests
    // - Encoding index files for legacy encoding support
    //
    // Run: zig build setup

    const setup_step = b.step("setup", "Download external data files (CLDR, Unicode, PSL, etc.)");

    const setup_data = b.addSystemCommand(&.{
        "bash", "-c",
        \\set -e
        \\
        \\DATA_DIR="data"
        \\mkdir -p "$DATA_DIR"
        \\
        \\echo "==> Setting up external data files..."
        \\echo ""
        \\
        \\# ========================================
        \\# CLDR v46.0.0 JSON data (~745MB)
        \\# ========================================
        \\CLDR_VERSION="46.0.0"
        \\CLDR_DIR="$DATA_DIR/cldr"
        \\
        \\if [ ! -d "$CLDR_DIR/cldr-core" ]; then
        \\    echo "==> Downloading CLDR v$CLDR_VERSION JSON data..."
        \\    mkdir -p "$CLDR_DIR"
        \\    cd "$CLDR_DIR"
        \\    
        \\    # Download the full CLDR JSON release (single zip file)
        \\    echo "    Downloading cldr-$CLDR_VERSION-json-full.zip..."
        \\    curl -sL "https://github.com/unicode-org/cldr-json/releases/download/$CLDR_VERSION/cldr-$CLDR_VERSION-json-full.zip" -o "cldr-full.zip"
        \\    unzip -q "cldr-full.zip"
        \\    rm "cldr-full.zip"
        \\    
        \\    cd - > /dev/null
        \\    echo "    CLDR data downloaded successfully"
        \\else
        \\    echo "==> CLDR data already present"
        \\fi
        \\
        \\# ========================================
        \\# Unicode data files (~4MB)
        \\# ========================================
        \\UNICODE_DIR="$DATA_DIR/unicode"
        \\UNICODE_VERSION="16.0.0"
        \\
        \\if [ ! -f "$UNICODE_DIR/UnicodeData.txt" ]; then
        \\    echo "==> Downloading Unicode $UNICODE_VERSION data files..."
        \\    mkdir -p "$UNICODE_DIR"
        \\    
        \\    # Core Unicode files
        \\    curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/UnicodeData.txt" -o "$UNICODE_DIR/UnicodeData.txt"
        \\    curl -sL "https://www.unicode.org/Public/idna/$UNICODE_VERSION/IdnaMappingTable.txt" -o "$UNICODE_DIR/IdnaMappingTable.txt"
        \\    curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/extracted/DerivedBidiClass.txt" -o "$UNICODE_DIR/DerivedBidiClass.txt"
        \\    curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/DerivedCoreProperties.txt" -o "$UNICODE_DIR/DerivedCoreProperties.txt"
        \\    curl -sL "https://www.unicode.org/Public/$UNICODE_VERSION/ucd/DerivedNormalizationProps.txt" -o "$UNICODE_DIR/DerivedNormalizationProps.txt"
        \\    
        \\    echo "    Unicode data downloaded successfully"
        \\else
        \\    echo "==> Unicode data already present"
        \\fi
        \\
        \\# ========================================
        \\# Public Suffix List (~320KB)
        \\# ========================================
        \\PSL_DIR="$DATA_DIR/psl"
        \\
        \\if [ ! -f "$PSL_DIR/public_suffix_list.dat" ]; then
        \\    echo "==> Downloading Public Suffix List..."
        \\    mkdir -p "$PSL_DIR"
        \\    
        \\    curl -sL "https://publicsuffix.org/list/public_suffix_list.dat" -o "$PSL_DIR/public_suffix_list.dat"
        \\    
        \\    echo "    PSL downloaded successfully"
        \\else
        \\    echo "==> PSL already present"
        \\fi
        \\
        \\# ========================================
        \\# IDNA Test Data (~760KB)
        \\# ========================================
        \\IDNA_DIR="$DATA_DIR/idna"
        \\
        \\if [ ! -f "$IDNA_DIR/IdnaTestV2.txt" ]; then
        \\    echo "==> Downloading IDNA test data..."
        \\    mkdir -p "$IDNA_DIR"
        \\    
        \\    curl -sL "https://www.unicode.org/Public/idna/$UNICODE_VERSION/IdnaTestV2.txt" -o "$IDNA_DIR/IdnaTestV2.txt"
        \\    
        \\    echo "    IDNA test data downloaded successfully"
        \\else
        \\    echo "==> IDNA test data already present"
        \\fi
        \\
        \\# ========================================
        \\# Encoding index files
        \\# ========================================
        \\ENCODING_DIR="$DATA_DIR/encoding/indexes"
        \\
        \\if [ ! -f "$ENCODING_DIR/index-ibm866.txt" ]; then
        \\    echo "==> Downloading Encoding index files..."
        \\    mkdir -p "$ENCODING_DIR"
        \\    
        \\    # Legacy encoding indexes from encoding.spec.whatwg.org
        \\    ENCODINGS=(
        \\        "ibm866"
        \\        "iso-8859-2"
        \\        "iso-8859-3"
        \\        "iso-8859-4"
        \\        "iso-8859-5"
        \\        "iso-8859-6"
        \\        "iso-8859-7"
        \\        "iso-8859-8"
        \\        "iso-8859-10"
        \\        "iso-8859-13"
        \\        "iso-8859-14"
        \\        "iso-8859-15"
        \\        "iso-8859-16"
        \\        "koi8-r"
        \\        "koi8-u"
        \\        "macintosh"
        \\        "windows-874"
        \\        "windows-1250"
        \\        "windows-1251"
        \\        "windows-1252"
        \\        "windows-1253"
        \\        "windows-1254"
        \\        "windows-1255"
        \\        "windows-1256"
        \\        "windows-1257"
        \\        "windows-1258"
        \\        "x-mac-cyrillic"
        \\        "gb18030"
        \\        "big5"
        \\        "euc-jp"
        \\        "iso-2022-jp"
        \\        "shift_jis"
        \\        "euc-kr"
        \\    )
        \\    
        \\    for enc in "${ENCODINGS[@]}"; do
        \\        echo "    Downloading index-$enc.txt..."
        \\        curl -sL "https://encoding.spec.whatwg.org/index-$enc.txt" -o "$ENCODING_DIR/index-$enc.txt" || echo "      (not found, skipping)"
        \\    done
        \\    
        \\    echo "    Encoding indexes downloaded successfully"
        \\else
        \\    echo "==> Encoding indexes already present"
        \\fi
        \\
        \\# ========================================
        \\# W3C WebRef data (algorithms only: specs/idl is a committed, pinned
        \\# snapshot - see specs/idl/WEBREF.md - and setup never overwrites it)
        \\# ========================================
        \\SPECS_DIR="specs"
        \\
        \\if [ ! -d "$SPECS_DIR/algorithms" ]; then
        \\    echo "==> Downloading W3C WebRef data..."
        \\    
        \\    # Download tarball (no auth required for public repos)
        \\    WEBREF_TMP=$(mktemp -d)
        \\    curl -sL "https://github.com/w3c/webref/archive/refs/heads/main.tar.gz" | tar -xz -C "$WEBREF_TMP"
        \\    
        \\    # Copy to specs directory (tarball extracts to webref-main/)
        \\    mkdir -p "$SPECS_DIR"
        \\    rm -rf "$SPECS_DIR/algorithms"
        \\    cp -r "$WEBREF_TMP/webref-main/ed/algorithms" "$SPECS_DIR/algorithms"
        \\    rm -rf "$WEBREF_TMP"
        \\    
        \\    echo "    WebRef data downloaded successfully"
        \\else
        \\    echo "==> WebRef data already present"
        \\fi
        \\
        \\# ========================================
        \\# WHATWG Specifications (converted to markdown)
        \\# ========================================
        \\WHATWG_DIR="$SPECS_DIR/whatwg"
        \\
        \\# Check if pandoc is available
        \\if ! command -v pandoc &> /dev/null; then
        \\    echo "==> WARNING: pandoc not found, skipping WHATWG spec downloads"
        \\    echo "    Install pandoc to download specs: brew install pandoc"
        \\else
        \\    if [ ! -f "$WHATWG_DIR/url.md" ]; then
        \\        echo "==> Downloading WHATWG specifications..."
        \\        mkdir -p "$WHATWG_DIR"
        \\        
        \\        # List of WHATWG specs to download
        \\        WHATWG_SPECS=(
        \\            "compat"
        \\            "compression"
        \\            "console"
        \\            "dom"
        \\            "encoding"
        \\            "fetch"
        \\            "fullscreen"
        \\            "infra"
        \\            "mimesniff"
        \\            "notifications"
        \\            "quirks"
        \\            "storage"
        \\            "streams"
        \\            "url"
        \\            "urlpattern"
        \\            "webidl"
        \\            "websockets"
        \\            "xhr"
        \\        )
        \\        
        \\        for spec in "${WHATWG_SPECS[@]}"; do
        \\            echo "    Downloading $spec spec..."
        \\            ./specs/get "https://$spec.spec.whatwg.org/" "$WHATWG_DIR/" 2>/dev/null || echo "      (failed, skipping)"
        \\        done
        \\        
        \\        # Special case: cookiestore uses a different URL pattern
        \\        echo "    Downloading cookiestore spec..."
        \\        ./specs/get "https://wicg.github.io/cookie-store/" "$WHATWG_DIR/" 2>/dev/null || echo "      (failed, skipping)"
        \\        
        \\        echo "    WHATWG specs downloaded successfully"
        \\    else
        \\        echo "==> WHATWG specs already present"
        \\    fi
        \\    
        \\    # ========================================
        \\    # HTML Multipage spec (each section separate)
        \\    # ========================================
        \\    HTML_DIR="$WHATWG_DIR/html"
        \\    
        \\    # Skip if html directory has multiple markdown files (not just html.md)
        \\    HTML_FILE_COUNT=$(find "$HTML_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        \\    if [ "$HTML_FILE_COUNT" -lt 2 ]; then
        \\        echo "==> Downloading HTML multipage specification..."
        \\        mkdir -p "$HTML_DIR"
        \\        
        \\        HTML_SECTIONS=(
        \\            "introduction"
        \\            "infrastructure"
        \\            "dom"
        \\            "semantics"
        \\            "common-microsyntaxes"
        \\            "urls-and-fetching"
        \\            "common-dom-interfaces"
        \\            "structured-data"
        \\            "sections"
        \\            "grouping-content"
        \\            "text-level-semantics"
        \\            "links"
        \\            "edits"
        \\            "embedded-content"
        \\            "images"
        \\            "iframe-embed-object"
        \\            "media"
        \\            "image-maps"
        \\            "embedded-content-other"
        \\            "tables"
        \\            "forms"
        \\            "input"
        \\            "form-elements"
        \\            "form-control-infrastructure"
        \\            "interactive-elements"
        \\            "scripting"
        \\            "canvas"
        \\            "custom-elements"
        \\            "semantics-other"
        \\            "microdata"
        \\            "interaction"
        \\            "dnd"
        \\            "popover"
        \\            "browsers"
        \\            "nav-history-apis"
        \\            "document-sequences"
        \\            "browsing-the-web"
        \\            "document-lifecycle"
        \\            "speculative-loading"
        \\            "webappapis"
        \\            "dynamic-markup-insertion"
        \\            "timers-and-user-prompts"
        \\            "system-state"
        \\            "imagebitmap-and-animations"
        \\            "comms"
        \\            "server-sent-events"
        \\            "web-messaging"
        \\            "workers"
        \\            "worklets"
        \\            "webstorage"
        \\            "syntax"
        \\            "parsing"
        \\            "named-characters"
        \\            "xhtml"
        \\            "rendering"
        \\            "obsolete"
        \\        )
        \\        
        \\        for section in "${HTML_SECTIONS[@]}"; do
        \\            echo "    Downloading html/$section..."
        \\            ./specs/get "https://html.spec.whatwg.org/multipage/$section.html" "$HTML_DIR/" 2>/dev/null || echo "      (failed, skipping)"
        \\        done
        \\        
        \\        echo "    HTML multipage spec downloaded successfully"
        \\    else
        \\        echo "==> HTML multipage spec already present"
        \\    fi
        \\fi
        \\
        \\# ========================================
        \\# V8 JavaScript Engine (13.1.x branch)
        \\# ========================================
        \\PROJECT_ROOT="$(pwd)"
        \\V8_DEST="$PROJECT_ROOT/jsengines/v8"
        \\V8_LIB="$V8_DEST/out/static/obj/libv8_monolith.a"
        \\DEPOT_TOOLS_DIR="$PROJECT_ROOT/jsengines/depot_tools"
        \\
        \\if [ ! -f "$V8_LIB" ]; then
        \\    echo "==> Building V8 13.1.x (this takes 30-60 minutes on first run)..."
        \\    
        \\    # Install depot_tools if not present
        \\    if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
        \\        echo "    Installing depot_tools..."
        \\        git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
        \\    fi
        \\    export PATH="$DEPOT_TOOLS_DIR:$PATH"
        \\    
        \\    # Bootstrap depot_tools (required before first use)
        \\    echo "    Bootstrapping depot_tools..."
        \\    gclient --version > /dev/null 2>&1 || true
        \\    
        \\    # Clone V8 to /tmp and checkout 13.1.x
        \\    V8_BUILD_DIR="/tmp/v8-build"
        \\    if [ ! -d "$V8_BUILD_DIR/v8" ]; then
        \\        echo "    Cloning V8 repository..."
        \\        rm -rf "$V8_BUILD_DIR"
        \\        mkdir -p "$V8_BUILD_DIR"
        \\        cd "$V8_BUILD_DIR"
        \\        fetch v8
        \\        cd v8
        \\        git checkout branch-heads/13.1
        \\        gclient sync
        \\        cd - > /dev/null
        \\    fi
        \\    
        \\    # Build V8 static library
        \\    echo "    Building V8 static library..."
        \\    cd "$V8_BUILD_DIR/v8"
        \\    
        \\    # Detect architecture
        \\    ARCH=$(uname -m)
        \\    if [ "$ARCH" = "arm64" ]; then
        \\        V8_TARGET_CPU="arm64"
        \\    else
        \\        V8_TARGET_CPU="x64"
        \\    fi
        \\    
        \\    # Generate build configuration
        \\    mkdir -p out/static
        \\    cat > out/static/args.gn << 'ARGS'
        \\is_component_build = false
        \\v8_monolithic = true
        \\v8_use_external_startup_data = false
        \\is_debug = false
        \\symbol_level = 0
        \\v8_enable_sandbox = true
        \\v8_enable_pointer_compression = true
        \\v8_enable_gdbjit = false
        \\v8_enable_disassembler = false
        \\v8_enable_object_print = false
        \\v8_enable_verify_heap = false
        \\v8_enable_trace_maps = false
        \\v8_enable_test_features = false
        \\v8_enable_v8_checks = false
        \\v8_enable_i18n_support = false
        \\clang_use_chrome_plugins = false
        \\treat_warnings_as_errors = false
        \\use_custom_libcxx = false
        \\ARGS
        \\    echo "target_cpu = \"$V8_TARGET_CPU\"" >> out/static/args.gn
        \\    
        \\    gn gen out/static
        \\    ninja -C out/static v8_monolith v8_libplatform v8_libbase
        \\    
        \\    # Convert thin archives to fat archives (Zig can't parse thin archives)
        \\    LLVM_AR="$(pwd)/third_party/llvm-build/Release+Asserts/bin/llvm-ar"
        \\    cd out/static
        \\    echo "    Converting thin archives to fat archives..."
        \\    $LLVM_AR -t obj/libv8_libplatform.a > /tmp/platform_objs.txt
        \\    $LLVM_AR rcs obj/libv8_libplatform_fat.a $(cat /tmp/platform_objs.txt)
        \\    $LLVM_AR -t obj/libv8_libbase.a > /tmp/base_objs.txt
        \\    $LLVM_AR rcs obj/libv8_libbase_fat.a $(cat /tmp/base_objs.txt)
        \\    cd ../..
        \\    
        \\    cd - > /dev/null
        \\    
        \\    # Copy to jsengines/v8
        \\    echo "    Copying V8 to $V8_DEST..."
        \\    mkdir -p "$V8_DEST"
        \\    rm -rf "$V8_DEST/include" "$V8_DEST/out"
        \\    cp -r "$V8_BUILD_DIR/v8/include" "$V8_DEST/include"
        \\    mkdir -p "$V8_DEST/out/static/obj"
        \\    cp "$V8_BUILD_DIR/v8/out/static/obj/libv8_monolith.a" "$V8_DEST/out/static/obj/"
        \\    cp "$V8_BUILD_DIR/v8/out/static/obj/libv8_libplatform_fat.a" "$V8_DEST/out/static/obj/"
        \\    cp "$V8_BUILD_DIR/v8/out/static/obj/libv8_libbase_fat.a" "$V8_DEST/out/static/obj/"
        \\    
        \\    echo "    V8 13.1.x built successfully"
        \\else
        \\    echo "==> V8 already present"
        \\fi
        \\
        \\echo ""
        \\echo "==> Setup complete!"
        \\echo ""
        \\echo "Data files are in: $DATA_DIR/"
        \\echo "  - cldr/     CLDR v$CLDR_VERSION JSON (~745MB)"
        \\echo "  - unicode/  Unicode $UNICODE_VERSION data (~4MB)"
        \\echo "  - psl/      Public Suffix List (~320KB)"
        \\echo "  - idna/     IDNA test data (~760KB)"
        \\echo "  - encoding/ Encoding indexes"
        \\echo ""
        \\echo "Spec files are in: $SPECS_DIR/"
        \\echo "  - algorithms/  W3C WebRef algorithm definitions"
        \\echo "  - idl/         W3C WebRef IDL definitions"
        \\echo "  - whatwg/      WHATWG specs (markdown)"
        \\echo "  - whatwg/html/ HTML multipage spec sections"
        \\echo ""
        \\echo "V8 engine is in: jsengines/v8/"
        \\echo "  - include/     V8 headers"
        \\echo "  - out/static/  Built static libraries"
        \\
    });

    setup_step.dependOn(&setup_data.step);

    // The compile-only checks may carry empty stand-ins for system libraries
    // (addCrossLibraryStubs), so nothing may link them: a step that asks for a
    // check's binary (an install, a run, getEmittedBin) would link against the
    // stubs. Asked or not is known here, once every step exists.
    for ([_]*std.Build.Step.Compile{ crane_check, wpt_runner_check, bug_finding_runner.check }) |check| {
        if (check.generated_bin != .none) std.debug.panic("build.zig: {s} is compile-only; nothing may ask for its binary (addCrossLibraryStubs)", .{check.name});
    }

    // Every test executable runs through the launcher; and `test-launch` is
    // the launcher runs `test` makes. Both known here, once every step exists.
    if (test_selection.one) |one| finishOneBinary(b, launch, one) catch |err| std.debug.panic("build.zig: the one test executable: {t}", .{err});
    checkEveryTestRunsThroughTheLauncher(b, launch, test_step);
    // Every tests/<dir>/ with test files is a suite: known here, once every
    // suite has been added - when no -Dspec or -Dtest-file skipped some.
    if ((spec_filter == null or std.mem.eql(u8, spec_filter.?, "all")) and test_selection.file == null) {
        checkEveryTestDirectoryIsASuite(b, test_selection.suite_dirs.items);
    }
    if (launch.sanitize_thread) instrumentForThreadSanitizer(b, launch);
    finishTestVerify(b, launch.verify);

    // Every C library each build links is compiled in the mode and with the
    // C sanitizer that build's modes say (build_mode.zig checkCLibraries),
    // known here, once every graph is configured: a dependency instance two
    // graphs share and each writes to fails the configuration, naming the
    // artifact, instead of silently crossing graphs (lane buildfix1,
    // 2026-11-10: generation 214's production runner linked the bug-finding
    // graph's full-sanitizer mbedTLS and zlib, and main's release console did
    // not link). The production runner and the release console are held to
    // the release build's modes, the bug-finding runner to its own; every
    // build on the shared graph to -Doptimize's mode at Zig's default
    // sanitizer (production_c, bug_finding_c, shared_c).
    // Both directions (the integrator, 2026-11-10): the production runner
    // and the release console carry no `.full` C and no UBSan runtime; the
    // bug-finding runner carries `.full` everywhere, nghttp2 and Brotli
    // included, and the runtime it calls.
    const checked_builds = [_]CheckedBuild{
        .{ .exe = wpt_runner_exe.exe, .root = .root(production_build.modes), .c = production_c, .step = wpt_runner_step },
        .{ .exe = bug_finding_runner.exe, .root = .root(bug_finding_build.modes), .c = bug_finding_c, .step = bug_finding_step },
        .{ .exe = repl_exe, .root = .root(repl_modes), .c = repl_c, .step = if (runner_release != null) repl_exe_step else null },
        .{ .exe = gc_bench_exe, .root = .root(gc_bench_modes), .c = shared_c, .step = null },
    };
    checkLinkedC(b, &checked_builds);
    // And once built, each of the three binaries is read back: its symbol
    // tables name a `__ubsan_handle_*` exactly when its modes need the
    // runtime (tools/ubsan_symbols.zig), as part of its own step.
    for (checked_builds) |checked| if (checked.step) |step| {
        const check = b.addRunArtifact(ubsan_symbols_exe);
        check.addArg(if (checked.needsUbsanRuntime()) "--expect=some" else "--expect=none");
        check.addArg(b.fmt("--name={s}", .{checked.exe.name}));
        check.addFileArg(checked.exe.getEmittedBin());
        // Checked, not inherited: no side effects, so Zig's cache reruns it
        // only when the binary (its file argument) changes, and its stderr
        // is shown when it fails.
        check.expectExitCode(0);
        step.dependOn(&check.step);
        // And its thread-local block is within the budget
        // (tools/thread_local_size.zig): what every thread of the build pays
        // for touching a thread-local. The budget is a file argument, so a
        // changed budget reruns the check.
        const thread_local_check = b.addRunArtifact(thread_local_size_exe);
        thread_local_check.addPrefixedFileArg("--budget=", b.path("tools/thread_local_size_budget.txt"));
        thread_local_check.addArg(b.fmt("--name={s}", .{checked.exe.name}));
        thread_local_check.addFileArg(checked.exe.getEmittedBin());
        thread_local_check.expectExitCode(0);
        step.dependOn(&thread_local_check.step);
    };
}

/// The mode and C sanitizer one part of a build compiles its C with (null:
/// Zig's default for the mode): its root's own C and C++, or the C libraries
/// it links.
const CModes = struct {
    optimize: std.builtin.OptimizeMode,
    sanitize_c: ?std.zig.SanitizeC,

    /// What `modes` give the C libraries.
    fn libraries(modes: runner_build_mode.RunnerModes) CModes {
        return .{ .optimize = modes.c_libraries, .sanitize_c = modes.sanitize_c };
    }

    /// What `modes` give the root (v8_wrapper.cpp).
    fn root(modes: runner_build_mode.RunnerModes) CModes {
        return .{ .optimize = modes.root, .sanitize_c = modes.sanitize_c };
    }

    /// Whether this C is compiled with the full sanitizer, whose failed
    /// checks call the UBSan runtime.
    fn compilesFull(self: CModes) bool {
        return runner_build_mode.effectiveSanitizeC(self.sanitize_c, self.optimize) == .full;
    }
};

/// A build checkLinkedC checks: its executable, what its modes give its root
/// and its C libraries, and the step that builds it alone, which also reads
/// the built binary back (tools/ubsan_symbols.zig) - none for a build no
/// step names.
const CheckedBuild = struct {
    exe: *std.Build.Step.Compile,
    root: CModes,
    c: CModes,
    step: ?*std.Build.Step,

    fn needsUbsanRuntime(self: CheckedBuild) bool {
        return runner_build_mode.needsUbsanRuntimeFor(self.root.optimize, self.root.sanitize_c, self.c.optimize, self.c.sanitize_c);
    }
};

/// Fails the configuration unless each of `builds` is what its modes say
/// (build_mode.zig checkCLibraries): its root, and every C library it links,
/// in its modes' mode and C sanitizer; and Zig's UBSan runtime linked exactly
/// when they need it. What a build links is found from its executable: every
/// library artifact reachable through the link entries of the modules in its
/// graph, and of those libraries in turn (libcurl's mbedTLS, zlib, nghttp2,
/// Brotli). libcurl's own sources are held to `libcurl_sanitize_c`.
fn checkLinkedC(b: *std.Build, builds: []const CheckedBuild) void {
    const gpa = b.allocator;
    var linked: std.ArrayList(runner_build_mode.LinkedCLibrary) = .empty;
    var runtimes: std.ArrayList(runner_build_mode.LinkedUbsanRuntime) = .empty;
    for (builds) |checked| {
        const root = checked.exe.root_module;
        const root_optimize = root.optimize orelse .debug;
        linked.append(gpa, .{
            .build = checked.exe.name,
            .library = "the root",
            .artifact = @intFromPtr(checked.exe),
            .optimize = root_optimize,
            .sanitize_c = root.sanitize_c,
            .want_optimize = checked.root.optimize,
            .want_sanitize_c = checked.root.sanitize_c,
        }) catch @panic("OOM");
        // Zig links the runtime when asked (bundle_ubsan_rt), and by default
        // when the root compiles its own C at the full sanitizer.
        runtimes.append(gpa, .{
            .build = checked.exe.name,
            .links = checked.exe.bundle_ubsan_rt orelse (runner_build_mode.effectiveSanitizeC(root.sanitize_c, root_optimize) == .full),
            .needs = checked.needsUbsanRuntime(),
        }) catch @panic("OOM");
        var modules: std.array_hash_map.Auto(*std.Build.Module, void) = .empty;
        var libraries: std.array_hash_map.Auto(*std.Build.Step.Compile, void) = .empty;
        modules.put(gpa, checked.exe.root_module, {}) catch @panic("OOM");
        var next: usize = 0;
        while (next < modules.count()) : (next += 1) {
            const module = modules.keys()[next];
            for (module.import_table.values()) |imported| modules.put(gpa, imported, {}) catch @panic("OOM");
            for (module.link_objects.items) |object| switch (object) {
                .other_step => |other| if (other.kind == .lib) {
                    libraries.put(gpa, other, {}) catch @panic("OOM");
                    modules.put(gpa, other.root_module, {}) catch @panic("OOM");
                },
                else => {},
            };
        }
        for (libraries.keys()) |library| {
            const is_libcurl = std.mem.eql(u8, library.name, "curl");
            linked.append(gpa, .{
                .build = checked.exe.name,
                .library = library.name,
                .artifact = @intFromPtr(library),
                .optimize = library.root_module.optimize orelse .debug,
                .sanitize_c = library.root_module.sanitize_c,
                .want_optimize = checked.c.optimize,
                .want_sanitize_c = if (is_libcurl) libcurl_sanitize_c else checked.c.sanitize_c,
            }) catch @panic("OOM");
        }
    }
    var report: std.Io.Writer.Allocating = .init(gpa);
    const problems = runner_build_mode.checkCLibraries(&report.writer, linked.items, runtimes.items) catch @panic("OOM");
    if (problems == 0) return;
    std.debug.print("error: build.zig: {d} problem(s) with the C a build compiles and links (tests/wpt_runner/build_mode.zig checkCLibraries):\n{s}", .{ problems, report.written() });
    std.process.exit(1);
}

/// Every Crane module, built for one platform (docs/platform-protocol.md 1.1).
///
/// build.zig builds its module graph once per platform an invocation needs: the
/// WPT runner and the test tiers against `testing`, the library, the CLI and the
/// iOS build against the target's platform. Each artifact is its own compile, so
/// a second graph costs no extra analysis; within one compile every file belongs
/// to one module, so an artifact takes ALL its Crane modules from one graph
/// (docs/lessons/architecture-a-module-bound-twice-cannot-share-a-compile.md).
const CraneModules = struct {
    /// The platform binding's options module (tests/platform reads it).
    platform_options: *std.Build.Module,
    /// The platform binding's <time.h> module (tests/platform reads it).
    c_time: *std.Build.Module,
    whatwg: *std.Build.Module,
    clock: *std.Build.Module,
    host: *std.Build.Module,
    memory: *std.Build.Module,
    process: *std.Build.Module,
    infra: *std.Build.Module,
    webidl: *std.Build.Module,
    storage: *std.Build.Module,
    cookiestore: *std.Build.Module,
    runtime: *std.Build.Module,
    v8: *std.Build.Module,
    codegen: *std.Build.Module,
    callbacks: *std.Build.Module,
    dictionaries: *std.Build.Module,
    enums: *std.Build.Module,
    namespaces: *std.Build.Module,
    typedefs: *std.Build.Module,
    interfaces: *std.Build.Module,
    impls: *std.Build.Module,
    webcrypto: *std.Build.Module,
    eventsource: *std.Build.Module,
    engine: *std.Build.Module,
    dom: *std.Build.Module,
    quirks: *std.Build.Module,
    css: *std.Build.Module,
    selector: *std.Build.Module,
    mixins: *std.Build.Module,
    encoding: *std.Build.Module,
    url: *std.Build.Module,
    urlpattern: *std.Build.Module,
    console: *std.Build.Module,
    streams_common: *std.Build.Module,
    streams_event_loop: *std.Build.Module,
    streams_async_promise: *std.Build.Module,
    streams_test_event_loop: *std.Build.Module,
    streams_queue: *std.Build.Module,
    streams_read_request: *std.Build.Module,
    streams_write_request: *std.Build.Module,
    streams_read_into_request: *std.Build.Module,
    streams_pull_into_descriptor: *std.Build.Module,
    streams: *std.Build.Module,
    mimesniff: *std.Build.Module,
    compression: *std.Build.Module,
    file: *std.Build.Module,
    fs: *std.Build.Module,
    referrer_policy: *std.Build.Module,
    csp: *std.Build.Module,
    fetch: *std.Build.Module,
    xhr: *std.Build.Module,
    trusted_types: *std.Build.Module,
    hr_time: *std.Build.Module,
    websocket: *std.Build.Module,
    platform: *std.Build.Module,
    html_core: *std.Build.Module,
    html: *std.Build.Module,
    service_worker: *std.Build.Module,
    xml: *std.Build.Module,
    xml_document_encoding: *std.Build.Module,
    permissions: *std.Build.Module,
    browser: *std.Build.Module,
    webdriver: *std.Build.Module,
    intl: *std.Build.Module,
};

/// One graph of Crane modules for `platform`. The graph of the target's own platform
/// is `public`: its modules are registered by name (b.addModule) for packages that
/// depend on Crane; any other graph is private to this build.
/// What `addWptRunner` needs beside the build and its graph.
const WptRunnerContext = struct {
    target: std.Build.ResolvedTarget,
    /// runner_allocator.zig's poisoning front (tests/test_runner/poisoning.zig).
    poisoning: *std.Build.Module,
    /// The snapshot's install: the runner reads zig-out/bin/whatwg_snapshot.bin.
    install_snapshot: *std.Build.Step,
    /// -Dwpt-debug.
    wpt_debug: bool,
    check_target: *std.Build.Step,
    /// The V8 the runner links (-Dv8, `linkV8`).
    v8: V8Link,
};

/// One built WPT runner (`addWptRunner`).
const WptRunner = struct {
    exe: *std.Build.Step.Compile,
    install: *std.Build.Step.InstallArtifact,
    /// The runner without a binary, for check-target: no snapshot (nothing
    /// runs), no link.
    check: *std.Build.Step.Compile,
};

/// One build of tests/wpt_runner/main.zig (build_mode.zig `RunnerBuild`):
/// `build.modes` decide its root's mode, its C sanitizer and its allocator,
/// `graph` is the module graph it links (`runnerGraph`), and its
/// `wpt_options` tell main.zig which build it is; `c_libraries` is what that
/// graph's C libraries are built with.
fn addWptRunner(b: *std.Build, which: runner_build_mode.RunnerBuild, config: runner_build_mode.Build, graph: CraneModules, c_libraries: CModes, ctx: WptRunnerContext) WptRunner {
    const imports = b.allocator.dupe(std.Build.Module.Import, &.{
        // The sweep allocator's poisoning front (runner_allocator.zig), shared
        // with the Crane test runner (lane poison2).
        .{ .name = "poisoning", .module = ctx.poisoning },
        .{ .name = "clock", .module = graph.clock },
        .{ .name = "host", .module = graph.host },
        .{ .name = "xml", .module = graph.xml },
        .{ .name = "xml_document_encoding", .module = graph.xml_document_encoding },
        .{ .name = "runtime", .module = graph.runtime },
        .{ .name = "engine", .module = graph.engine },
        .{ .name = "interfaces", .module = graph.interfaces },
        .{ .name = "namespaces", .module = graph.namespaces },
        .{ .name = "fetch", .module = graph.fetch },
        // Platform abstraction for timer backend
        .{ .name = "platform", .module = graph.platform },
        // HTML event loop and timer manager (core module without interfaces)
        .{ .name = "html", .module = graph.html_core },
        // HTML full module with custom_elements for thread-local cleanup
        .{ .name = "html_full", .module = graph.html },
        // DOM module for mutation observer thread-local cleanup
        .{ .name = "dom", .module = graph.dom },
        // Infra primitives
        .{ .name = "infra", .module = graph.infra },
        // Browser module for single-isolate WPT execution
        .{ .name = "browser", .module = graph.browser },
        // Impls module for HTMLParser (needed for HTML test parsing)
        .{ .name = "impls", .module = graph.impls },
        // WebIDL module for Optional type wrappers
        .{ .name = "webidl", .module = graph.webidl },
        // Dictionaries module for Event init dictionaries
        .{ .name = "dictionaries", .module = graph.dictionaries },
        // Storage module for cleanup
        .{ .name = "storage", .module = graph.storage },
        // File module for blob URL store cleanup
        .{ .name = "file", .module = graph.file },
        // The cookie store, for testdriver's cookie commands (test_driver.zig)
        .{ .name = "cookiestore", .module = graph.cookiestore },
        // Permissions, for testdriver's set_permission (test_driver.zig).
        .{ .name = "permissions", .module = graph.permissions },
    }) catch @panic("OOM");

    const exe = b.addExecutable(.{
        .name = which.binaryName(),
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/wpt_runner/main.zig"),
            .target = ctx.target,
            .optimize = config.modes.root,
            .imports = imports,
        }),
    });
    linkV8(b, exe.root_module, ctx.v8);
    // v8_wrapper.cpp's sanitizer (build_mode.zig, RunnerModes.sanitize_c):
    // the production run's is its release mode's own (.trap), as the
    // console's; the bug-finding run's is `.full`, so a failed check names
    // itself in a ReleaseSafe runner as it does in Debug.
    if (config.modes.sanitize_c) |sanitizer| exe.root_module.sanitize_c = sanitizer;
    // The full sanitizer's handlers (___ubsan_handle_*) are called from C
    // libraries built as artifacts of their own, which a release root does not
    // bundle a runtime for: without this a ReleaseSafe bug-finding runner fails
    // to link on them (libmbedtls.a). Only that build: the production run's C
    // libraries are `.trap`, which calls no handler, so it links no runtime -
    // as the release console links none (build_mode.zig needsUbsanRuntimeFor).
    if (c_libraries.compilesFull()) exe.bundle_ubsan_rt = true;
    // The runner reads the snapshot beside it.
    exe.step.dependOn(ctx.install_snapshot);
    const install = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&install.step);

    const options = b.addOptions();
    options.addOption(bool, "debug_enabled", ctx.wpt_debug);
    // Which build this is (build_mode.zig RunnerBuild): what its banner
    // names, what its journal records carry, and everything main.zig does
    // differently in the bug-finding build.
    options.addOption(bool, "production", which == .production);
    // For the build banner: the root's mode is the runner's own builtin.mode.
    options.addOption(std.builtin.OptimizeMode, "crane_modules_mode", config.modes.crane_modules);
    options.addOption(std.builtin.OptimizeMode, "c_libraries_mode", config.modes.c_libraries);
    // libc's malloc (the production run's, as the console's) or the leak-
    // and double-free-detecting allocator (the bug-finding run's).
    options.addOption(bool, "production_allocator", config.modes.allocator == .production);
    // The build's identity, as repl.modes spells the console's
    // (build_mode.zig `describe`), for the banner.
    var described: [160]u8 = undefined;
    options.addOption([]const u8, "modes", b.dupe(runner_build_mode.describe(&described, config.modes) catch @panic("modes")));
    exe.root_module.addOptions("wpt_options", options);

    const check = addCompileCheck(b, b.fmt("{s}_check", .{which.binaryName()}), "tests/wpt_runner/main.zig", ctx.target, config.modes.root, imports, ctx.v8);
    check.root_module.addOptions("wpt_options", options);
    ctx.check_target.dependOn(&check.step);
    return .{ .exe = exe, .install = install, .check = check };
}

/// What `runnerGraph` reuses or builds from: the invocation's module
/// configuration and the graphs it already has.
const RunnerGraphContext = struct {
    module_config: ModuleConfig,
    target_platform: Platform,
    /// The target platform's public graph, in -Doptimize's mode.
    shared: CraneModules,
    /// The testing platform's graph, in -Doptimize's mode.
    testing: CraneModules,
    use_system_curl: bool,
    enable_http2: bool,
    brotli_enabled: bool,
};

/// The module graph a WPT runner build links (tests/wpt_runner/build_mode.zig
/// `Build`): its platform graph's existing one when its Crane modules and C
/// libraries are the shared graph's - -Doptimize's mode, at Zig's default C
/// sanitizer for it (`RunnerModes.ownGraph`) - or with -Dsystem-curl, whose
/// one libcurl cannot be built per mode; else a private graph of that
/// platform in its modes, over C libraries of its own (buildStaticLibcurl,
/// buildBrotli, buildImageCodecs: new artifacts per call) built at its root's
/// sanitizer. Private: the target platform's public graph registers its
/// modules by name, once (docs/lessons/workflow-a-second-graph-of-the-target-
/// platform-must-be-private.md).
fn runnerGraph(b: *std.Build, target: std.Build.ResolvedTarget, runner: runner_build_mode.Build, ctx: RunnerGraphContext) CraneModules {
    const platform: Platform = switch (runner.platform) {
        .console => ctx.target_platform,
        .testing => .testing,
    };
    const existing = if (platform == .testing) ctx.testing else ctx.shared;
    if (!runner.modes.ownGraph(ctx.module_config.optimize) or ctx.use_system_curl) return existing;
    var config = ctx.module_config;
    // Any platform but the graph's own.
    config.public_platform = if (platform == .testing) .darwin else .testing;
    config.optimize = runner.modes.crane_modules;
    config.brotli = buildBrotli(b, target, runner.modes.c_libraries, runner.modes.sanitize_c);
    config.image_codecs = buildImageCodecs(b, target, runner.modes.c_libraries, runner.modes.sanitize_c);
    config.static_libcurl = buildStaticLibcurl(b, target, runner.modes.c_libraries, ctx.enable_http2, runner.modes.sanitize_c, if (ctx.brotli_enabled) config.brotli else null);
    return addCraneModules(b, target, platform, config);
}

fn addCraneModules(b: *std.Build, target: std.Build.ResolvedTarget, platform: Platform, config: ModuleConfig) CraneModules {
    const public = platform == config.public_platform;
    const optimize = config.optimize;
    const build_options = config.build_options;
    const debug_options = config.debug_options;
    const engine_choice = config.engine_choice;
    const use_system_curl = config.use_system_curl;
    const enable_http2 = config.enable_http2;
    // ========================================================================
    // LIBRARY MODULE
    // ========================================================================

    const whatwg_mod = graphModule(b, public, "whatwg", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // ========================================================================
    // INDIVIDUAL SPEC MODULES
    // ========================================================================

    // Process clocks. Zig 0.16 removed std.time's milliTimestamp/nanoTimestamp/
    // timestamp/sleep/Timer; the replacements live on std.Io and need an Io value
    // in scope. src/platform/clock.zig provides them over libc instead, so the 203
    // call sites do not have to wait for the Io architecture.
    //
    // ZERO dependencies, deliberately. It is imported by fetch, storage, runtime,
    // impls and others, and platform_mod already imports fetch - so putting the
    // clock in platform would make fetch -> platform -> fetch. A leaf module cannot
    // participate in a cycle.
    const clock_mod = graphModule(b, public, "clock", .{
        .root_source_file = b.path("src/platform/clock.zig"),
        .target = target,
    });
    clock_mod.link_libc = true;

    // The process std.Io. Zig 0.16 moved the filesystem, networking and timers onto
    // std.Io, which is passed like an Allocator; Crane has ~150 filesystem sites in
    // leaf code reached from C-ABI callbacks that cannot take another parameter.
    // Zero dependencies for the same reason as clock_mod.
    const host_mod = graphModule(b, public, "host", .{
        .root_source_file = b.path("src/platform/host.zig"),
        .target = target,
    });
    host_mod.link_libc = true;

    // Current resident memory, for measuring whether memory is actually reclaimed.
    // Zero dependencies for the same reason as clock_mod and host_mod: it is read
    // from measurement loops in leaf code, and a leaf module cannot form a cycle.
    const memory_mod = graphModule(b, public, "memory", .{
        .root_source_file = b.path("src/platform/memory.zig"),
        .target = target,
    });
    memory_mod.link_libc = true;

    // The process's start-up phase and its hook slots (src/process: start.zig,
    // hook.zig's Hook(T) and List(T, capacity)), written while the process
    // starts and frozen after. ZERO dependencies for the same reason as
    // clock_mod: every layer declares hook slots - src/dom, but also the
    // runtime tier, the V8 adapter, fetch and hr_time below it - and a leaf
    // module cannot form a cycle. dom re-exports it (dom.Hook,
    // dom.process_start).
    const process_mod = graphModule(b, public, "process", .{
        .root_source_file = b.path("src/process/root.zig"),
        .target = target,
    });

    const infra_mod = graphModule(b, public, "infra", .{
        .root_source_file = b.path("src/infra/root.zig"),
        .target = target,
    });
    infra_mod.addImport("clock", clock_mod);
    infra_mod.addImport("host", host_mod);

    const webidl_mod = graphModule(b, public, "webidl", .{
        .root_source_file = b.path("src/webidl/root.zig"),
        .target = target,
    });
    webidl_mod.addImport("infra", infra_mod);
    // src/webidl/root.zig re-exports codegen/root.zig, so the codegen sources are
    // part of THIS module, not just of codegen_mod - and they need host for std.Io.
    webidl_mod.addImport("host", host_mod);
    webidl_mod.addImport("clock", clock_mod);
    webidl_mod.addOptions("debug_options", debug_options);

    // Storage module (IndexedDB and Storage Standard backend)
    const storage_mod = graphModule(b, public, "storage", .{
        .root_source_file = b.path("src/storage/root.zig"),
        .target = target,
    });
    storage_mod.addImport("clock", clock_mod);
    storage_mod.addImport("host", host_mod);
    storage_mod.addImport("infra", infra_mod);

    // Configure platform-specific storage backend linking (Phase 9)
    // - iOS: System SQLite (Phase 9.1)
    // - Android: System SQLite (Phase 9.2)
    // - Desktop: SQLite + LevelDB static linking (Phase 9.3)
    configureStorageBackends(storage_mod, target);

    // CookieStore module (WHATWG Cookie Store API)
    const cookiestore_mod = graphModule(b, public, "cookiestore", .{
        .root_source_file = b.path("src/cookiestore/root.zig"),
        .target = target,
    });
    cookiestore_mod.addImport("clock", clock_mod);
    cookiestore_mod.addImport("host", host_mod);

    // Runtime module (WebIDL runtime infrastructure)
    const runtime_mod = graphModule(b, public, "runtime", .{
        .root_source_file = b.path("src/runtime/root.zig"),
        .target = target,
    });
    runtime_mod.addImport("clock", clock_mod);
    runtime_mod.addImport("process", process_mod);
    runtime_mod.addImport("host", host_mod);
    runtime_mod.addImport("webidl", webidl_mod);
    runtime_mod.addImport("infra", infra_mod);
    runtime_mod.addImport("storage", storage_mod);
    runtime_mod.addOptions("build_options", build_options);
    runtime_mod.addOptions("debug_options", debug_options);

    // V8 bindings module
    const v8_mod = graphModule(b, public, "v8", .{
        .root_source_file = b.path("src/runtime/engines/v8/root.zig"),
        .target = target,
    });
    // Phase 8 (DCE): interface_bindings consults build_options.interface_allowlist.
    v8_mod.addOptions("build_options", build_options);
    v8_mod.addImport("clock", clock_mod);
    v8_mod.addImport("process", process_mod);
    v8_mod.addImport("infra", infra_mod);
    v8_mod.addImport("host", host_mod);
    v8_mod.addImport("runtime", runtime_mod);
    v8_mod.addOptions("debug_options", debug_options);
    // v8_mod will need event_loop - added later after streams_event_loop_mod is defined

    // JS bindings module
    const js_bindings_mod = graphModule(b, public, "js_bindings", .{
        .root_source_file = b.path("src/js_bindings/root.zig"),
        .target = target,
    });
    js_bindings_mod.addImport("runtime", runtime_mod);

    // WebIDL codegen module
    const codegen_mod = graphModule(b, public, "codegen", .{
        .root_source_file = b.path("src/webidl/codegen/root.zig"),
        .target = target,
    });
    codegen_mod.addImport("webidl", webidl_mod);
    codegen_mod.addImport("infra", infra_mod);
    codegen_mod.addImport("host", host_mod);

    // ========================================================================
    // WEBIDL CALLBACKS MODULE
    // ========================================================================

    const callbacks_mod = graphModule(b, public, "callbacks", .{
        .root_source_file = b.path("src/webidl/callbacks/root.zig"),
        .target = target,
    });
    callbacks_mod.addImport("runtime", runtime_mod);
    callbacks_mod.addImport("webidl", webidl_mod); // For Opt wrapper in optional parameters

    // ========================================================================
    // WEBIDL DICTIONARIES MODULE
    // ========================================================================

    const dictionaries_mod = graphModule(b, public, "dictionaries", .{
        .root_source_file = b.path("src/webidl/dictionaries/root.zig"),
        .target = target,
    });
    dictionaries_mod.addImport("runtime", runtime_mod);
    dictionaries_mod.addImport("webidl", webidl_mod);

    // ========================================================================
    // WEBIDL ENUMS MODULE
    // ========================================================================

    const enums_mod = graphModule(b, public, "enums", .{
        .root_source_file = b.path("src/webidl/enums/root.zig"),
        .target = target,
    });

    // ========================================================================
    // WEBIDL NAMESPACES MODULE
    // ========================================================================

    const namespaces_mod = graphModule(b, public, "namespaces", .{
        .root_source_file = b.path("src/webidl/namespaces/root.zig"),
        .target = target,
    });
    namespaces_mod.addImport("runtime", runtime_mod);
    namespaces_mod.addImport("webidl", webidl_mod); // For Opt wrapper in optional parameters
    namespaces_mod.addOptions("build_options", build_options);
    namespaces_mod.addOptions("debug_options", debug_options);

    // ========================================================================
    // WEBIDL TYPEDEFS MODULE
    // ========================================================================

    const typedefs_mod = graphModule(b, public, "typedefs", .{
        .root_source_file = b.path("src/webidl/typedefs/root.zig"),
        .target = target,
    });
    typedefs_mod.addImport("runtime", runtime_mod);
    typedefs_mod.addImport("callbacks", callbacks_mod);
    typedefs_mod.addImport("webidl", webidl_mod);
    typedefs_mod.addImport("dictionaries", dictionaries_mod);
    typedefs_mod.addImport("enums", enums_mod);

    // ========================================================================
    // INTERFACES MODULE (WebIDL interface definitions)
    // All interfaces in one module so they can import each other with relative paths
    // ========================================================================

    const interfaces_mod = graphModule(b, public, "interfaces", .{
        .root_source_file = b.path("src/webidl/interfaces/root.zig"),
        .target = target,
    });
    interfaces_mod.addImport("runtime", runtime_mod);
    interfaces_mod.addImport("webidl", webidl_mod); // For Opt wrapper and other WebIDL types

    // ========================================================================
    // IMPLEMENTATIONS MODULE (WebIDL interface implementations)
    // ========================================================================

    const impls_mod = graphModule(b, public, "impls", .{
        .root_source_file = b.path("src/webidl/impls/root.zig"),
        .target = target,
    });
    impls_mod.addImport("clock", clock_mod);
    impls_mod.addImport("host", host_mod);
    impls_mod.addImport("runtime", runtime_mod);
    impls_mod.addImport("storage", storage_mod); // For IndexedDB and Storage impl connections
    impls_mod.addImport("cookiestore", cookiestore_mod); // For CookieStore impl

    // Web Cryptography API primitives. Keep the pure algorithms independently
    // testable; their tests use std.testing.allocator and injected Io.
    const webcrypto_mod = graphModule(b, public, "webcrypto", .{
        .root_source_file = b.path("src/webcrypto/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    impls_mod.addImport("webcrypto", webcrypto_mod);
    webcrypto_mod.addImport("runtime", runtime_mod);

    const eventsource_mod = graphModule(b, public, "eventsource", .{
        .root_source_file = b.path("src/eventsource/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    eventsource_mod.addImport("infra", infra_mod);
    impls_mod.addImport("eventsource", eventsource_mod);
    impls_mod.addOptions("build_options", build_options);
    impls_mod.addOptions("debug_options", debug_options);

    // ========================================================================
    // ENGINE PROTOCOL (module `engine`)
    // ========================================================================
    //
    // AGENTS.md "The engine boundary": consumers `@import("engine")` and call
    // `engine.op(...)`. The facade forwards every operation, inline, to
    // `engine_impl.protocol` - the adapter `-Dengine=` selects - so dispatch
    // is static, and a missing or mis-typed adapter function is a compile
    // error in the facade. In a V8 build `engine_impl` IS the v8 module (its
    // root re-exports src/runtime/engines/v8/protocol.zig), because the
    // protocol functions live beside the adapter files they call, and a file
    // of another module cannot import those by relative path. One module
    // each, shared by every artifact: binding it adds no root-module
    // analysis, and runtime already imports v8, so it adds no module cycle.
    const engine_protocol_root = b.path("src/runtime/engine_protocol.zig");
    const engine_mod = graphModule(b, public, "engine", .{
        .root_source_file = engine_protocol_root,
        .target = target,
    });
    engine_mod.addImport("runtime", runtime_mod);
    const engine_impl_mod = if (std.mem.eql(u8, engine_choice, "v8")) v8_mod else b.createModule(.{
        .root_source_file = b.path(b.fmt("src/runtime/engines/{s}/protocol.zig", .{engine_choice})),
        .target = target,
    });
    engine_impl_mod.addImport("engine", engine_mod);
    // The adapter's own build options (its build file's, the engine's `adapterOptions`): this module alone
    // imports them.
    engine_impl_mod.addOptions("adapter_options", config.engine_adapter_options);
    engine_mod.addImport("engine_impl", engine_impl_mod);
    impls_mod.addImport("engine", engine_mod);
    webcrypto_mod.addImport("engine", engine_mod);
    // The runtime reaches the engine the way everything else does: an
    // unwrapped instance asks engine.hasWrapper, [PutForwards] and
    // [Replaceable] setters use its Set and DefineOwnProperty. The facade
    // imports runtime, so this is a cycle - the same shape as facade and
    // adapter.
    runtime_mod.addImport("engine", engine_mod);

    // Cross-imports for WebIDL modules
    interfaces_mod.addImport("interfaces", interfaces_mod); // Self-import for cross-interface refs
    interfaces_mod.addImport("impls", impls_mod);
    namespaces_mod.addImport("impls", impls_mod); // Namespaces need access to impls
    interfaces_mod.addImport("typedefs", typedefs_mod);
    interfaces_mod.addImport("dictionaries", dictionaries_mod);
    interfaces_mod.addImport("enums", enums_mod);
    interfaces_mod.addImport("callbacks", callbacks_mod);
    impls_mod.addImport("interfaces", interfaces_mod);
    impls_mod.addImport("typedefs", typedefs_mod);
    impls_mod.addImport("dictionaries", dictionaries_mod);
    impls_mod.addImport("enums", enums_mod);
    impls_mod.addImport("callbacks", callbacks_mod);
    impls_mod.addImport("webidl", webidl_mod); // For error types and WebIDL infrastructure

    // V8 module needs interfaces for automatic constructor inheritance setup
    v8_mod.addImport("interfaces", interfaces_mod);
    // V8 module needs dictionaries for async iterator options parsing
    v8_mod.addImport("dictionaries", dictionaries_mod);
    // V8 module needs webidl for error types (Exception)
    v8_mod.addImport("webidl", webidl_mod);
    // V8 module needs typedefs for HeadersInit conversion
    v8_mod.addImport("typedefs", typedefs_mod);
    // V8 module needs impls for ReadableStream start callback invocation
    v8_mod.addImport("impls", impls_mod);

    // Dictionaries module needs typedefs, enums and callbacks for RequestInit and other dictionaries
    dictionaries_mod.addImport("typedefs", typedefs_mod);
    dictionaries_mod.addImport("enums", enums_mod);
    dictionaries_mod.addImport("callbacks", callbacks_mod);

    // AGENTS.md "The engine boundary": no module outside the V8 adapter (and
    // its tests and tools) imports "v8" - the module graph, not only
    // lint-engine, keeps V8 inside the adapter. The engine is reached through
    // `engine`, which build.zig binds to the adapter.
    // The adapter registers the namespaces a snapshot lacks when it creates a
    // Window realm (an Engine function pointer cannot take a comptime module).
    v8_mod.addImport("namespaces", namespaces_mod);

    // DOM module
    const dom_mod = graphModule(b, public, "dom", .{
        .root_source_file = b.path("src/dom/root.zig"),
        .target = target,
    });
    // The refcount audit's comptime switch (dom_options.refcount_audit).
    dom_mod.addOptions("dom_options", config.dom_options);
    dom_mod.addImport("clock", clock_mod);
    // hook.zig and process_start.zig re-export the process module.
    dom_mod.addImport("process", process_mod);
    dom_mod.addImport("host", host_mod);
    dom_mod.addImport("infra", infra_mod);
    // The user agent's cookie jar, which a settings object hands out.
    dom_mod.addImport("cookiestore", cookiestore_mod);
    dom_mod.addImport("webcrypto", webcrypto_mod);
    webcrypto_mod.addImport("dom", dom_mod);
    dom_mod.addImport("webidl", webidl_mod);
    dom_mod.addImport("runtime", runtime_mod);
    dom_mod.addImport("storage", storage_mod);
    dom_mod.addImport("engine", engine_mod);
    dom_mod.addImport("interfaces", interfaces_mod);
    dom_mod.addImport("impls", impls_mod); // For document_internals to access Document.InternalState
    // CSP violation events (csp_violations.zig): a queued task run in the
    // global's realm (the engine protocol), and the event's init dictionary.
    dom_mod.addImport("engine", engine_mod);
    dom_mod.addImport("dictionaries", dictionaries_mod);
    dom_mod.addImport("enums", enums_mod);
    dom_mod.addImport("typedefs", typedefs_mod);

    // Quirks module (WHATWG Quirks Mode Standard)
    const quirks_mod = graphModule(b, public, "quirks", .{
        .root_source_file = b.path("src/quirks/root.zig"),
        .target = target,
    });

    // CSS module (CSS property value parser)
    const css_mod = graphModule(b, public, "css", .{
        .root_source_file = b.path("src/css/root.zig"),
        .target = target,
    });
    css_mod.addImport("quirks", quirks_mod);
    // The CSSOM's model (src/dom/cssom.zig) holds a sheet's parsed rules.
    dom_mod.addImport("css", css_mod);

    // Selector module (CSS Selectors Level 4 implementation)
    const selector_mod = graphModule(b, public, "selector", .{
        .root_source_file = b.path("src/selector/root.zig"),
        .target = target,
    });
    selector_mod.addImport("infra", infra_mod);
    selector_mod.addImport("dom", dom_mod);
    selector_mod.addImport("quirks", quirks_mod);

    // Add selector to dom (after selector_mod is defined to avoid undefined reference)
    dom_mod.addImport("selector", selector_mod);
    // Add unified interfaces module
    dom_mod.addImport("interfaces", interfaces_mod);
    // The generated interfaces' defaults run src/dom's algorithms: an event
    // handler IDL attribute's getter and setter (dom.event_handlers).
    interfaces_mod.addImport("dom", dom_mod);

    // V8 module needs dom for document initialization
    v8_mod.addImport("dom", dom_mod);

    // MIXINS MODULE (Shared WebIDL mixin implementations)
    // ========================================================================
    const mixins_mod = graphModule(b, public, "mixins", .{
        .root_source_file = b.path("src/webidl/mixins/root.zig"),
        .target = target,
    });
    mixins_mod.addImport("runtime", runtime_mod);
    mixins_mod.addImport("interfaces", interfaces_mod);
    mixins_mod.addImport("impls", impls_mod);
    mixins_mod.addImport("selector", selector_mod);
    mixins_mod.addImport("typedefs", typedefs_mod);
    mixins_mod.addImport("enums", enums_mod);
    mixins_mod.addImport("dictionaries", dictionaries_mod);
    mixins_mod.addImport("callbacks", callbacks_mod);
    mixins_mod.addImport("webidl", webidl_mod);
    mixins_mod.addImport("mixins", mixins_mod); // Self-import for cross-mixin refs
    // A mixin module's defaults run src/dom's algorithms, as an interface's do.
    mixins_mod.addImport("dom", dom_mod);

    // Add mixins to impls (so impls can use shared mixin code)
    impls_mod.addImport("mixins", mixins_mod);
    // Add selector to impls (for ParentNode querySelector/querySelectorAll)
    impls_mod.addImport("selector", selector_mod);
    // Add css to impls (the CSS namespace: CSS.supports, CSS.escape)
    impls_mod.addImport("css", css_mod);

    // Add mixins to interfaces (for ParentNode.NodeOrString and other mixin types)
    interfaces_mod.addImport("mixins", mixins_mod);

    const encoding_mod = graphModule(b, public, "encoding", .{
        .root_source_file = b.path("src/encoding/root.zig"),
        .target = target,
    });
    encoding_mod.addImport("infra", infra_mod);
    encoding_mod.addImport("webidl", webidl_mod);
    for (reverse_index_table_names, config.tables.reverse_index) |name, table| {
        encoding_mod.addAnonymousImport(b.fmt("reverse_index_{s}", .{name}), .{ .root_source_file = table });
    }
    css_mod.addImport("encoding", encoding_mod);

    // URL internal modules that generated interfaces need
    // URL internal modules need to be created first for cross-dependencies
    const url_internal_host_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/host.zig"),
        .target = target,
    });

    // Cookies share URL's PSL without depending on the URL/WebIDL facade.
    const public_suffix_mod = b.createModule(.{
        .root_source_file = b.path("src/url/public_suffix.zig"),
        .target = target,
    });
    public_suffix_mod.addImport("host", url_internal_host_mod);
    public_suffix_mod.addAnonymousImport("psl_table", .{ .root_source_file = config.tables.psl });
    cookiestore_mod.addImport("public_suffix", public_suffix_mod);

    const url_internal_path_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/path.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_blob_url_mod = b.createModule(.{
        .root_source_file = b.path("src/url/blob_url.zig"),
        .target = target,
    });

    const url_internal_url_record_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/url_record.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "host", .module = url_internal_host_mod },
            .{ .name = "path", .module = url_internal_path_mod },
            .{ .name = "blob_url", .module = url_blob_url_mod },
        },
    });

    const url_parser_api_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/api_url_parser.zig"),
        .target = target,
    });

    const url_host_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/host_serializer.zig"),
        .target = target,
    });
    url_host_serializer_mod.addImport("host", url_internal_host_mod);
    url_host_serializer_mod.addImport("infra", infra_mod);

    const url_path_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/url_path_serializer.zig"),
        .target = target,
    });
    url_path_serializer_mod.addImport("url_record", url_internal_url_record_mod);
    url_path_serializer_mod.addImport("infra", infra_mod);

    const url_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/url_serializer.zig"),
        .target = target,
    });
    url_serializer_mod.addImport("url_record", url_internal_url_record_mod);
    url_serializer_mod.addImport("path_serializer", url_path_serializer_mod);
    url_serializer_mod.addImport("host_serializer", url_host_serializer_mod);
    url_serializer_mod.addImport("infra", infra_mod);

    const url_basic_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/basic_url_parser.zig"),
        .target = target,
    });
    url_basic_parser_mod.addImport("infra", infra_mod);
    url_basic_parser_mod.addImport("url_record", url_internal_url_record_mod);
    url_basic_parser_mod.addImport("host", url_internal_host_mod);
    url_basic_parser_mod.addImport("path", url_internal_path_mod);

    // Add imports to url_parser_api_mod now that dependencies are defined
    url_parser_api_mod.addImport("infra", infra_mod);
    url_parser_api_mod.addImport("url_record", url_internal_url_record_mod);
    url_parser_api_mod.addImport("basic_parser", url_basic_parser_mod);
    // encodingParseAndSerialize serializes what it parses.
    url_parser_api_mod.addImport("url_serializer", url_serializer_mod);

    const url_parser_state_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/parser_state.zig"),
        .target = target,
    });

    const url_helpers_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/helpers.zig"),
        .target = target,
    });

    // Add late imports to url_basic_parser_mod now that helpers and parser_state are defined
    url_basic_parser_mod.addImport("parser_state", url_parser_state_mod);
    url_basic_parser_mod.addImport("helpers", url_helpers_mod);

    const url_percent_encoding_mod = b.createModule(.{
        .root_source_file = b.path("src/url/encoding/percent_encoding.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_encode_sets_mod = b.createModule(.{
        .root_source_file = b.path("src/url/encoding/encode_sets.zig"),
        .target = target,
    });

    const url_search_params_impl_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/url_search_params_impl.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_form_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/form_urlencoded/parser.zig"),
        .target = target,
    });
    url_form_parser_mod.addImport("infra", infra_mod);
    url_form_parser_mod.addImport("percent_encoding", url_percent_encoding_mod);

    const url_form_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/form_urlencoded/serializer.zig"),
        .target = target,
    });
    url_form_serializer_mod.addImport("form_parser", url_form_parser_mod);
    url_form_serializer_mod.addImport("infra", infra_mod);
    url_form_serializer_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_form_serializer_mod.addImport("encode_sets", url_encode_sets_mod);

    // Additional URL modules for internal use
    const url_validation_mod = b.createModule(.{
        .root_source_file = b.path("src/url/validation.zig"),
        .target = target,
    });

    const url_ipv4_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/ipv4_serializer.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const url_ipv6_serializer_mod = b.createModule(.{
        .root_source_file = b.path("src/url/serialization/ipv6_serializer.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    // Add serializer dependencies to host_serializer (needed after ipv4/ipv6 serializers are defined)
    url_host_serializer_mod.addImport("ipv4_serializer", url_ipv4_serializer_mod);
    url_host_serializer_mod.addImport("ipv6_serializer", url_ipv6_serializer_mod);

    const url_ipv4_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/ipv4_parser.zig"),
        .target = target,
    });

    const url_ipv6_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/ipv6_parser.zig"),
        .target = target,
    });

    const url_idna_mod = b.createModule(.{
        .root_source_file = b.path("src/url/idna/root.zig"),
        .target = target,
    });
    url_idna_mod.addImport("infra", infra_mod);

    const url_host_parser_mod = b.createModule(.{
        .root_source_file = b.path("src/url/parser/host_parser.zig"),
        .target = target,
    });
    url_host_parser_mod.addImport("infra", infra_mod);
    url_host_parser_mod.addImport("idna", url_idna_mod);
    url_host_parser_mod.addImport("validation", url_validation_mod);
    url_host_parser_mod.addImport("host", url_internal_host_mod);
    url_host_parser_mod.addImport("ipv4_parser", url_ipv4_parser_mod);
    url_host_parser_mod.addImport("ipv6_parser", url_ipv6_parser_mod);
    url_host_parser_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_host_parser_mod.addImport("encode_sets", url_encode_sets_mod);

    // Add host_parser import to url_basic_parser_mod now that it's defined
    url_basic_parser_mod.addImport("host_parser", url_host_parser_mod);

    const url_windows_drive_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/windows_drive.zig"),
        .target = target,
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "infra", .module = infra_mod },
        },
    });

    // Add remaining imports to url_basic_parser_mod now that all dependencies are defined
    url_basic_parser_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_basic_parser_mod.addImport("encode_sets", url_encode_sets_mod);
    url_basic_parser_mod.addImport("windows_drive", url_windows_drive_mod);
    // The URL parser's query state percent-encodes after encoding with the
    // given encoding (HTML "encoding-parse a URL": the document's).
    url_basic_parser_mod.addImport("encoding", encoding_mod);

    const url_special_schemes_mod = b.createModule(.{
        .root_source_file = b.path("src/url/internal/special_schemes.zig"),
        .target = target,
    });

    const url_origin_mod_internal = b.createModule(.{
        .root_source_file = b.path("src/url/origin.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "url_record", .module = url_internal_url_record_mod },
            .{ .name = "host", .module = url_internal_host_mod },
            .{ .name = "host_serializer", .module = url_host_serializer_mod },
            .{ .name = "path", .module = url_internal_path_mod },
            .{ .name = "path_serializer", .module = url_path_serializer_mod },
            .{ .name = "api_url_parser", .module = url_parser_api_mod },
        },
    });

    const url_equivalence_mod = b.createModule(.{
        .root_source_file = b.path("src/url/equivalence.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "url_record", .module = url_internal_url_record_mod },
            .{ .name = "host", .module = url_internal_host_mod },
            .{ .name = "url_serializer", .module = url_serializer_mod },
            .{ .name = "path", .module = url_internal_path_mod },
        },
    });

    // Add dependencies for internal modules
    url_search_params_impl_mod.addImport("form_parser", url_form_parser_mod);
    url_search_params_impl_mod.addImport("form_serializer", url_form_serializer_mod);

    url_ipv4_parser_mod.addImport("infra", infra_mod);
    url_ipv4_parser_mod.addImport("validation", url_validation_mod);
    url_ipv6_parser_mod.addImport("infra", infra_mod);
    url_ipv6_parser_mod.addImport("validation", url_validation_mod);
    url_percent_encoding_mod.addImport("encode_sets", url_encode_sets_mod);
    url_blob_url_mod.addImport("origin", url_origin_mod_internal);
    url_blob_url_mod.addImport("api_url_parser", url_parser_api_mod);

    // Main url module
    const url_mod = graphModule(b, public, "url", .{
        .root_source_file = b.path("src/url/root.zig"),
        .target = target,
    });
    url_mod.addImport("public_suffix", public_suffix_mod);
    url_mod.addImport("infra", infra_mod);
    url_mod.addImport("webidl", webidl_mod);
    url_mod.addImport("encoding", encoding_mod);
    url_mod.addImport("url_search_params_impl", url_search_params_impl_mod);
    url_mod.addImport("url_record", url_internal_url_record_mod);
    url_mod.addImport("host_serializer", url_host_serializer_mod);
    url_mod.addImport("basic_parser", url_basic_parser_mod);
    url_mod.addImport("parser_state", url_parser_state_mod);
    url_mod.addImport("encode_sets", url_encode_sets_mod);
    url_mod.addImport("percent_encoding", url_percent_encoding_mod);
    url_mod.addImport("windows_drive", url_windows_drive_mod);
    url_mod.addImport("special_schemes", url_special_schemes_mod);
    url_mod.addImport("validation", url_validation_mod);
    url_mod.addImport("host", url_internal_host_mod);
    url_mod.addImport("ipv4_parser", url_ipv4_parser_mod);
    url_mod.addImport("ipv6_parser", url_ipv6_parser_mod);
    url_mod.addImport("idna", url_idna_mod);
    url_mod.addImport("host_parser", url_host_parser_mod);
    url_mod.addImport("ipv4_serializer", url_ipv4_serializer_mod);
    url_mod.addImport("ipv6_serializer", url_ipv6_serializer_mod);
    url_mod.addImport("helpers", url_helpers_mod);
    url_mod.addImport("origin", url_origin_mod_internal);
    url_mod.addImport("blob_url", url_blob_url_mod);
    url_mod.addImport("equivalence", url_equivalence_mod);
    url_mod.addImport("path_serializer", url_path_serializer_mod);

    // URL infrastructure modules for impls (needed by URL.zig and URLSearchParams.zig impl)
    impls_mod.addImport("url_record", url_internal_url_record_mod);
    impls_mod.addImport("api_parser", url_parser_api_mod);
    impls_mod.addImport("basic_parser", url_basic_parser_mod);
    impls_mod.addImport("url_serializer", url_serializer_mod);
    impls_mod.addImport("host_serializer", url_host_serializer_mod);
    impls_mod.addImport("path_serializer", url_path_serializer_mod);
    impls_mod.addImport("origin", url_origin_mod_internal);
    impls_mod.addImport("percent_encoding", url_percent_encoding_mod);
    impls_mod.addImport("encode_sets", url_encode_sets_mod);
    impls_mod.addImport("parser_state", url_parser_state_mod);
    impls_mod.addImport("form_parser", url_form_parser_mod);
    impls_mod.addImport("form_serializer", url_form_serializer_mod);

    // Infra module for URLSearchParams (List type)
    impls_mod.addImport("infra", infra_mod);

    // Encoding module for TextDecoder/TextEncoder implementations
    impls_mod.addImport("encoding", encoding_mod);
    eventsource_mod.addImport("encoding", encoding_mod);

    // ========================================================================
    // URLPATTERN MODULE (WHATWG URLPattern Standard)
    // ========================================================================

    const urlpattern_mod = graphModule(b, public, "urlpattern", .{
        .root_source_file = b.path("src/urlpattern/root.zig"),
        .target = target,
    });
    urlpattern_mod.addImport("url", url_mod);
    // A component's regular expression is ECMAScript RegExpCreate and
    // RegExpBuiltinExec, done by the engine (src/urlpattern/regexp.zig).
    urlpattern_mod.addImport("engine", engine_mod);

    const console_mod = graphModule(b, public, "console", .{
        .root_source_file = b.path("src/console/root.zig"),
        .target = target,
    });
    console_mod.addImport("webidl", webidl_mod);
    console_mod.addImport("interfaces", interfaces_mod);
    console_mod.addImport("namespaces", namespaces_mod);
    // The Console Standard's printer (src/console/printer.zig) reads values
    // through the engine protocol.
    console_mod.addImport("engine", engine_mod);
    console_mod.addImport("runtime", runtime_mod);
    // The console namespace's impl prints through it.
    impls_mod.addImport("console", console_mod);

    // Streams internal modules (used by both root.zig and generated interfaces)
    // All internal files need to import each other via modules to avoid circular file ownership

    const streams_common_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/common.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_event_loop_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/event_loop.zig"),
        .target = target,
    });

    const streams_async_promise_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/async_promise.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "common", .module = streams_common_mod },
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const streams_test_event_loop_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/test_event_loop.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "infra", .module = infra_mod },
        },
    });

    const streams_queue_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/queue_with_sizes.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    const streams_read_request_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/read_request.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    const streams_write_request_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/write_request.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "queue_with_sizes", .module = streams_queue_mod },
            .{ .name = "async_promise", .module = streams_async_promise_mod },
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_read_into_request_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/read_into_request.zig"),
        .target = target,
    });

    const streams_read_into_request_promise_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/read_into_request_promise.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "event_loop", .module = streams_event_loop_mod },
            .{ .name = "async_promise", .module = streams_async_promise_mod },
            .{ .name = "read_into_request", .module = streams_read_into_request_mod },
        },
    });

    const streams_pull_into_descriptor_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/pull_into_descriptor.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
        },
    });

    const streams_async_iterator_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/async_iterator.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    const streams_message_port_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/message_port.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "infra", .module = infra_mod },
            .{ .name = "common", .module = streams_common_mod },
        },
    });

    const streams_cross_realm_transform_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/cross_realm_transform.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "common", .module = streams_common_mod },
            .{ .name = "pull_into_descriptor", .module = streams_pull_into_descriptor_mod },
            .{ .name = "message_port", .module = streams_message_port_mod },
        },
    });

    const streams_view_construction_mod = b.createModule(.{
        .root_source_file = b.path("src/streams/internal/view_construction.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "webidl", .module = webidl_mod },
            .{ .name = "pull_into_descriptor", .module = streams_pull_into_descriptor_mod },
        },
    });

    // Main streams module
    const streams_mod = graphModule(b, public, "streams", .{
        .root_source_file = b.path("src/streams/root.zig"),
        .target = target,
    });
    streams_mod.addImport("infra", infra_mod);
    streams_mod.addImport("webidl", webidl_mod);
    streams_mod.addImport("runtime", runtime_mod);
    streams_mod.addImport("dom", dom_mod);

    // Add event loop to runtime and v8 for async operations (streams, promises)
    runtime_mod.addImport("event_loop", streams_event_loop_mod);
    v8_mod.addImport("event_loop", streams_event_loop_mod);
    v8_mod.addImport("streams_async_promise", streams_async_promise_mod);

    // Add internal modules so root.zig can access them
    streams_mod.addImport("common", streams_common_mod);
    streams_mod.addImport("event_loop", streams_event_loop_mod);
    streams_mod.addImport("async_promise", streams_async_promise_mod);
    streams_mod.addImport("test_event_loop", streams_test_event_loop_mod);
    streams_mod.addImport("queue_with_sizes", streams_queue_mod);
    streams_mod.addImport("read_request", streams_read_request_mod);
    streams_mod.addImport("read_into_request", streams_read_into_request_mod);
    streams_mod.addImport("pull_into_descriptor", streams_pull_into_descriptor_mod);
    streams_mod.addImport("write_request", streams_write_request_mod);
    streams_mod.addImport("view_construction", streams_view_construction_mod);
    streams_mod.addImport("async_iterator", streams_async_iterator_mod);
    streams_mod.addImport("message_port", streams_message_port_mod);
    streams_mod.addImport("cross_realm_transform", streams_cross_realm_transform_mod);
    // Add unified interfaces module
    streams_mod.addImport("interfaces", interfaces_mod);

    // Add streams event loop to interfaces for ReadableStreamBYOBReader init
    interfaces_mod.addImport("streams_event_loop", streams_event_loop_mod);

    // Add streams modules to impls for ReadableStream, WritableStream, TransformStream implementations
    impls_mod.addImport("streams_common", streams_common_mod);
    impls_mod.addImport("streams_event_loop", streams_event_loop_mod);
    impls_mod.addImport("streams_async_promise", streams_async_promise_mod);
    impls_mod.addImport("streams_test_event_loop", streams_test_event_loop_mod);
    impls_mod.addImport("streams_queue", streams_queue_mod);
    impls_mod.addImport("streams_read_request", streams_read_request_mod);
    impls_mod.addImport("streams_write_request", streams_write_request_mod);
    impls_mod.addImport("streams_read_into_request", streams_read_into_request_mod);
    impls_mod.addImport("streams_read_into_request_promise", streams_read_into_request_promise_mod);
    impls_mod.addImport("streams_pull_into_descriptor", streams_pull_into_descriptor_mod);
    impls_mod.addImport("streams_internal", streams_message_port_mod);

    // DOM module for XPath implementations
    impls_mod.addImport("dom", dom_mod);

    // Quirks module for Document quirks mode support
    impls_mod.addImport("quirks", quirks_mod);

    // ArrayBufferView is part of runtime module, no separate module needed
    // (ReadableStreamBYOBReader accesses it via runtime.arraybuffer_view)

    const compression_mod = graphModule(b, public, "compression", .{
        .root_source_file = b.path("src/compression/root.zig"),
        .target = target,
    });
    impls_mod.addImport("compression", compression_mod);

    const mimesniff_mod = graphModule(b, public, "mimesniff", .{
        .root_source_file = b.path("src/mimesniff/root.zig"),
        .target = target,
    });
    mimesniff_mod.addImport("infra", infra_mod);
    impls_mod.addImport("mimesniff", mimesniff_mod); // FileReader's package data parses a Blob's type

    // File API module (W3C File API - Blob, File, FileReader)
    const file_mod = graphModule(b, public, "file", .{
        .root_source_file = b.path("src/file/root.zig"),
        .target = target,
    });
    file_mod.addImport("clock", clock_mod);
    file_mod.addImport("host", host_mod);
    file_mod.addImport("infra", infra_mod);
    file_mod.addImport("encoding", encoding_mod);
    file_mod.addImport("mimesniff", mimesniff_mod);
    file_mod.addImport("blob_url", url_blob_url_mod);
    // file_mod.addImport("streams", streams_mod);

    // Add file module to impls (for Blob, File, FileReader implementations)
    impls_mod.addImport("file", file_mod);
    // dom.browser_state: a realm reaches its Browser's blob URL store, a
    // supplement of the Browser's scope (docs/instances.md).
    dom_mod.addImport("file", file_mod);

    // File System Access API module (WHATWG File System Standard)
    const fs_mod = graphModule(b, public, "fs", .{
        .root_source_file = b.path("src/fs/root.zig"),
        .target = target,
    });
    fs_mod.addImport("clock", clock_mod);
    fs_mod.addImport("host", host_mod);
    // fs_mod dependencies will be added as implementation progresses:
    // fs_mod.addImport("storage", storage_mod);
    // fs_mod.addImport("streams", streams_mod);

    // Add fs to storage module for StorageManager.getDirectory()
    // Per WHATWG File System spec, navigator.storage.getDirectory() returns FileSystemDirectoryHandle
    storage_mod.addImport("fs", fs_mod);

    // Referrer Policy module (W3C Referrer Policy)
    const referrer_policy_mod = graphModule(b, public, "referrer_policy", .{
        .root_source_file = b.path("src/referrer_policy/root.zig"),
        .target = target,
    });

    // CSP module (W3C Content Security Policy Level 3)
    const csp_mod = graphModule(b, public, "csp", .{
        .root_source_file = b.path("src/csp/root.zig"),
        .target = target,
    });
    csp_mod.addImport("clock", clock_mod);
    csp_mod.addImport("host", host_mod);

    // Fetch API module (WHATWG Fetch Standard)
    const fetch_mod = graphModule(b, public, "fetch", .{
        .root_source_file = b.path("src/fetch/root.zig"),
        .target = target,
    });
    fetch_mod.addImport("clock", clock_mod);
    fetch_mod.addImport("process", process_mod);
    fetch_mod.addImport("host", host_mod);
    fetch_mod.addImport("referrer_policy", referrer_policy_mod);
    // A request's policy container holds its client's CSP list, which main
    // fetch checks the request against (CSP 4.1).
    fetch_mod.addImport("csp", csp_mod);
    // HTTP-redirect fetch parses a `Location` value against the response URL.
    // The same three URL modules `xhr_mod` takes, for the same reason.
    fetch_mod.addImport("url_record", url_internal_url_record_mod);
    fetch_mod.addImport("basic_parser", url_basic_parser_mod);
    fetch_mod.addImport("url_serializer", url_serializer_mod);
    // Main fetch step 12 and the CORS check compare origins (URL "origin").
    fetch_mod.addImport("origin", url_origin_mod_internal);
    // Main fetch step 19: a JavaScript MIME type essence match (MIME Sniffing).
    fetch_mod.addImport("mimesniff", mimesniff_mod);
    // HTTP-network-or-cache fetch sends and stores cookies in the jar.
    fetch_mod.addImport("cookiestore", cookiestore_mod);
    // The network layer asks the vendored TLS library what ALPN chose, and
    // tests that HTTP/2 is live when the build asked for it. Its own options
    // module: one options file imported as a module by two others in the same
    // compilation is an error ("file exists in modules"), and build_options
    // already is, through runtime and impls.
    const curl_options = b.addOptions();
    curl_options.addOption(bool, "http2", enable_http2 and !use_system_curl);
    curl_options.addOption(bool, "mbedtls", tls_backend == .mbedtls and !use_system_curl);
    fetch_mod.addOptions("curl_options", curl_options);
    // A base64 data: URL body is Infra's forgiving-base64 decode.
    fetch_mod.addImport("infra", infra_mod);

    // Configure libcurl for network requests
    if (use_system_curl) {
        // Development: Use system libcurl for faster builds
        fetch_mod.linkSystemLibrary("curl", .{});
        fetch_mod.addImport("curl_c", addCImport(b, "curl_c", target, .{ .includes = &.{"curl/curl.h"}, .system_libs = &.{"curl"} }));
    } else if (config.static_libcurl) |static| {
        // Production: the statically compiled libcurl with mbedTLS
        linkStaticLibcurl(b, fetch_mod, target, static.libcurl);
        fetch_mod.addImport("curl_c", addCImport(b, "curl_c", target, .{ .includes = &.{"curl/curl.h"}, .libs = &.{static.libcurl}, .macros = &.{.{ "CURL_STATICLIB", "1" }} }));
    }
    const linked_mbedtls: ?*std.Build.Step.Compile = if (config.static_libcurl) |static| static.mbedtls else null;

    // WebCrypto shares curl's exact mbedTLS artifact - build.zig.zon's
    // `.mbedtls`, which buildStaticLibcurl links into libcurl - including its
    // installed headers, translated with the library's threading macros.
    if (linked_mbedtls) |library| {
        webcrypto_mod.linkLibrary(library);
        webcrypto_mod.addImport("mbedtls_c", addCImport(b, "mbedtls_c", target, .{
            .includes = &.{ "psa/crypto.h", "mbedtls/nist_kw.h", "mbedtls/rsa.h", "mbedtls/pk.h" },
            .libs = &.{library},
            .macros = &mbedtls_threading_macros,
        }));
    }
    const webcrypto_options = b.addOptions();
    webcrypto_options.addOption(bool, "mbedtls", tls_backend == .mbedtls and !use_system_curl);
    webcrypto_mod.addOptions("options", webcrypto_options);
    if (target.result.os.tag == .ios) addIosSdkPaths(webcrypto_mod, iosSdkPath(b));

    // fetch_mod dependencies will be added as implementation progresses:
    // fetch_mod.addImport("url", url_mod);
    // fetch_mod.addImport("streams", streams_mod);
    // fetch_mod.addImport("encoding", encoding_mod);

    // XMLHttpRequest module (WHATWG XHR Standard)
    const xhr_mod = graphModule(b, public, "xhr", .{
        .root_source_file = b.path("src/xhr/root.zig"),
        .target = target,
    });
    xhr_mod.addImport("clock", clock_mod);
    xhr_mod.addImport("host", host_mod);
    xhr_mod.addImport("fetch", fetch_mod); // XHR uses Fetch infrastructure
    xhr_mod.addImport("mimesniff", mimesniff_mod); // XHR uses MIME type parsing for overrideMimeType
    // open() resolves a relative URL against the document base URL, which needs
    // the URL parser. Without this, `parseURL` accepted only absolute http(s),
    // data and file URLs and threw SyntaxError on everything else - and every
    // WPT XHR test asks for `resources/*.py`, so `send()` was never reached.
    // `url_mod`'s root does not re-export the serializer, and the parser is
    // reachable only as `url.parser.basic_url_parser`, so take the same three
    // modules `impls_mod` does (build.zig:1332-1335).
    xhr_mod.addImport("url_record", url_internal_url_record_mod);
    xhr_mod.addImport("basic_parser", url_basic_parser_mod);
    xhr_mod.addImport("url_serializer", url_serializer_mod);
    //
    // `runtime` is deliberately NOT an import here. `src/xhr/internal/context.zig`
    // was the only file that wanted it, for a `runtime.event_loop.Scheduler`
    // that does not exist; that file is gone. Keeping xhr free of `runtime`
    // also breaks the cycle `impls -> xhr -> runtime -> v8 -> impls`, which is
    // what stopped `xhr_mod` from being cloned into a test root, and lets the
    // test block below run without linking V8.

    // Allow impls to access fetch for Headers, Request, Response implementations
    impls_mod.addImport("fetch", fetch_mod);
    impls_mod.addImport("url", url_mod); // For Request constructor URL parsing
    impls_mod.addImport("urlpattern", urlpattern_mod); // For URLPattern implementation
    impls_mod.addImport("xhr", xhr_mod); // For FormData implementation

    // Trusted Types module (W3C Trusted Types)
    const trusted_types_mod = graphModule(b, public, "trusted_types", .{
        .root_source_file = b.path("src/trusted_types/root.zig"),
        .target = target,
    });
    // trusted_types_mod dependencies will be added as implementation progresses:
    // trusted_types_mod.addImport("infra", infra_mod);
    // trusted_types_mod.addImport("webidl", webidl_mod);

    // Add trusted_types to impls for TrustedHTML, TrustedScript, etc. implementations
    impls_mod.addImport("trusted_types", trusted_types_mod);

    // Add csp to impls for Document CSP checks
    impls_mod.addImport("csp", csp_mod);

    // HR-Time module (W3C High Resolution Time)
    const hr_time_mod = graphModule(b, public, "hr_time", .{
        .root_source_file = b.path("src/hr_time/root.zig"),
        .target = target,
    });
    hr_time_mod.addImport("clock", clock_mod);
    hr_time_mod.addImport("process", process_mod);
    hr_time_mod.addImport("host", host_mod);

    // Add hr_time to impls for Performance implementation
    impls_mod.addImport("hr_time", hr_time_mod);
    // fetch's connection timing info is coarsened on hr_time's grid
    // (fetch_timing.coarsenTime -> hr_time.coarsen.coarsenMilliseconds).
    fetch_mod.addImport("hr_time", hr_time_mod);

    // WebSocket module (WHATWG WebSockets API)
    const websocket_mod = graphModule(b, public, "websocket", .{
        .root_source_file = b.path("src/websocket/root.zig"),
        .target = target,
    });
    // WebSocket needs fetch for curl backend
    websocket_mod.addImport("fetch", fetch_mod);
    // The opening handshake's cookies come from and go to the jar.
    websocket_mod.addImport("cookiestore", cookiestore_mod);

    // Add websocket to impls for WebSocket interface implementation
    impls_mod.addImport("websocket", websocket_mod);

    // The platform protocol (module `platform`, src/platform/protocol.zig),
    // bound to this graph's platform. A leaf: it no longer imports fetch.
    const platform_binding = platformBinding(b, target, .{
        .platform = platform,
        .brotli = config.brotli,
        .image_codecs = config.image_codecs,
        .module_path = config.platform_module,
        .without = config.platform_without,
        .static = config.platform_static,
        .http2 = enable_http2 and !use_system_curl,
        .libcurl = if (config.static_libcurl) |lib| lib.libcurl else null,
        .mbedtls = if (config.static_libcurl) |lib| lib.mbedtls else null,
        .public = public,
        .clock = clock_mod,
        .host = host_mod,
        .memory = memory_mod,
        .mimesniff = mimesniff_mod,
    });
    const platform_mod = platform_binding.facade;
    compression_mod.addImport("platform", platform_mod);
    fetch_mod.addImport("platform", platform_mod);
    dom_mod.addImport("platform", platform_mod);
    storage_mod.addImport("platform", platform_mod);
    // A Browser's network context keeps its connection share in kit/curl,
    // and fetch's transfers and WebSocket's handshakes take the Browser's
    // network options (proxy, TLS, user agent) from it.
    fetch_mod.addImport("kit_curl_share", platform_binding.kit_curl_share);
    websocket_mod.addImport("platform", platform_mod);
    const platform_options_mod = platform_binding.options;

    // HTML Core module (WHATWG HTML Standard) - Interface-free subset
    // Contains parser (§13), window (§7), event loop (§8.1.7), structured clone (§2.7)
    // This module can be safely imported by impls without creating a cycle.
    // NO imports of: interfaces, impls, runtime
    //
    // ARCHITECTURAL NOTE: fetch_mod is safe to import here because:
    // - fetch_mod only imports: referrer_policy_mod (no cycles possible)
    // - This enables real HTTP(S) fetching for navigation and workers
    // - See whatwg-aujed for the analysis that led to this decision
    const html_core_mod = graphModule(b, public, "html_core", .{
        .root_source_file = b.path("src/html/root.zig"),
        .target = target,
    });
    html_core_mod.addImport("clock", clock_mod);
    html_core_mod.addImport("host", host_mod);
    html_core_mod.addImport("infra", infra_mod);
    html_core_mod.addImport("dom", dom_mod);
    html_core_mod.addImport("eventsource", eventsource_mod);
    html_core_mod.addImport("platform", platform_mod);
    html_core_mod.addImport("fetch", fetch_mod);
    html_core_mod.addImport("csp", csp_mod);
    html_core_mod.addImport("storage", storage_mod); // For web_storage.zig Storage backend
    html_core_mod.addImport("encoding", encoding_mod); // For iframe document loading encoding detection
    // HTML "determining the character encoding": the transport layer's charset
    // is the charset parameter of the Content-Type, parsed as a MIME type.
    html_core_mod.addImport("mimesniff", mimesniff_mod);
    // WorkerLocation's origin is the URL Standard's origin of the worker's URL.
    html_core_mod.addImport("origin", url_origin_mod_internal);
    html_core_mod.addImport("basic_parser", url_basic_parser_mod);
    // A browsing context reaches the user agent's cookie jar.
    html_core_mod.addImport("cookiestore", cookiestore_mod);

    // HTML module (full WHATWG HTML Standard) - Includes interface-dependent code
    // Uses full.zig as root which re-exports html_core plus adds interface access.
    // Contains everything in html_core PLUS access to:
    // - interfaces module (for script execution files)
    // - impls module (for script execution coordination)
    // - runtime module (for JS execution context)
    //
    // Dependency graph (no cycle):
    //   html_core_mod ← infra, dom, platform (NO interfaces)
    //        ↓
    //   impls_mod ← html_core_mod, interfaces_mod, ...
    //        ↓
    //   html_mod ← interfaces_mod, impls_mod, runtime_mod (CAN use interfaces)
    //
    // html_mod does NOT feed back into impls_mod, so no cycle is created.
    const html_mod = graphModule(b, public, "html", .{
        .root_source_file = b.path("src/html/full.zig"),
        .target = target,
    });
    // Import html_core as a module (not file import) to avoid file ownership conflicts
    html_mod.addImport("html_core", html_core_mod);
    // Interface access for script execution files (now in src/html/)
    html_mod.addImport("interfaces", interfaces_mod);
    html_mod.addImport("impls", impls_mod);
    html_mod.addImport("runtime", runtime_mod);
    html_mod.addImport("platform", platform_mod);
    // WebIDL types needed by custom_elements.zig and upgrade.zig
    html_mod.addImport("webidl", webidl_mod);
    // Dependencies for script_execution.zig, script_runner.zig, event_utils.zig
    html_mod.addImport("infra", infra_mod);
    html_mod.addImport("fetch", fetch_mod);
    html_mod.addImport("csp", csp_mod);
    // The engine protocol (AGENTS.md "The engine boundary"): html's
    // engine-neutral code calls `engine.op`.
    html_mod.addImport("engine", engine_mod);
    html_mod.addImport("dictionaries", dictionaries_mod);
    // The Unicode bidi classes, for HTML's directionality (form_associated.zig).
    html_mod.addImport("url", url_mod);
    // DOM module for document_internals access in parser_script_execution.zig
    html_mod.addImport("dom", dom_mod);
    // HTML "encoding-parse a URL" (html.encoding_parse) runs the URL parser
    // with a document's encoding.
    html_mod.addImport("api_parser", url_parser_api_mod);
    // A style sheet's @import rules, for style_sheet_loading.zig.
    html_mod.addImport("css", css_mod);

    // The XML parser (XML 1.0 + Namespaces in XML): engine- and DOM-free, no
    // imports. HTML's XML tree builder (src/html/xml_document_parser.zig)
    // turns its events into a Document.
    const xml_mod = graphModule(b, public, "xml", .{
        .root_source_file = b.path("src/xml/root.zig"),
        .target = target,
    });
    html_mod.addImport("xml", xml_mod);

    // One owner per graph for these engine-free HTML data/decoding files.
    // The XML metadata harness uses them without HTML core's DOM or fetch.
    const html_encoding_sniffing_mod = graphModule(b, public, "html_encoding_sniffing", .{
        .root_source_file = b.path("src/html/parser/encoding_sniffing.zig"),
        .target = target,
    });
    html_encoding_sniffing_mod.addImport("encoding", encoding_mod);
    html_encoding_sniffing_mod.addImport("mimesniff", mimesniff_mod);
    const html_entities_mod = graphModule(b, public, "html_entities", .{
        .root_source_file = b.path("src/html/parser/entities.zig"),
        .target = target,
    });
    html_core_mod.addImport("html_encoding_sniffing", html_encoding_sniffing_mod);
    html_core_mod.addImport("html_entities", html_entities_mod);
    const xml_document_encoding_mod = graphModule(b, public, "xml_document_encoding", .{
        .root_source_file = b.path("src/html/xml_document_encoding.zig"),
        .target = target,
    });
    xml_document_encoding_mod.addImport("xml", xml_mod);
    xml_document_encoding_mod.addImport("encoding", encoding_mod);
    xml_document_encoding_mod.addImport("html_encoding_sniffing", html_encoding_sniffing_mod);
    xml_document_encoding_mod.addImport("html_entities", html_entities_mod);
    html_core_mod.addImport("xml_document_encoding", xml_document_encoding_mod);

    // Add html_core to impls for DOMParser, innerHTML, document.write, Window implementations
    // Using html_core (not html) to avoid cycle: impls → html → interfaces → impls
    impls_mod.addImport("html_core", html_core_mod);

    // Add platform to impls for Worker to access TimerBackend
    impls_mod.addImport("platform", platform_mod);

    // Add html_core and csp to dom for document_internals
    dom_mod.addImport("html_core", html_core_mod);
    dom_mod.addImport("api_parser", url_parser_api_mod);
    dom_mod.addImport("csp", csp_mod);
    dom_mod.addImport("trusted_types", trusted_types_mod);
    // A settings object is a request's client: global_settings.requestClient
    // hands fetch what "populate request from client" reads.
    dom_mod.addImport("fetch", fetch_mod);
    dom_mod.addImport("mimesniff", mimesniff_mod); // The shared image decoder sniffs per MIME Sniffing.
    // Document's state type (dom.document_state) holds its active parser,
    // html's DocumentParser. The edge adds no cycle: dom already reached
    // html through impls.
    dom_mod.addImport("html", html_mod);

    // Add html to impls for script execution algorithms
    // Note: This creates html ↔ impls mutual dependency. Zig handles this because
    // the dependency is only at the module level, not at function call time during
    // module initialization. The imports are lazy (evaluated when used).
    impls_mod.addImport("html", html_mod);

    // Service Workers (W3C): a Browser's registrations, jobs and service
    // worker records (a BrowserScope supplement), the job thread, and what a
    // realm keeps of them. Its threads are html's worker threads; the impls
    // reach it for navigator.serviceWorker and the service worker globals.
    const service_worker_mod = graphModule(b, public, "service_worker", .{
        .root_source_file = b.path("src/service_worker/root.zig"),
        .target = target,
    });
    service_worker_mod.addImport("runtime", runtime_mod);
    service_worker_mod.addImport("engine", engine_mod);
    service_worker_mod.addImport("platform", platform_mod);
    service_worker_mod.addImport("html", html_mod);
    service_worker_mod.addImport("html_core", html_core_mod);
    service_worker_mod.addImport("fetch", fetch_mod);
    service_worker_mod.addImport("dom", dom_mod);
    service_worker_mod.addImport("webidl", webidl_mod);
    service_worker_mod.addImport("interfaces", interfaces_mod);
    service_worker_mod.addImport("dictionaries", dictionaries_mod);
    service_worker_mod.addImport("enums", enums_mod);
    service_worker_mod.addImport("typedefs", typedefs_mod);
    // Setup ServiceWorkerGlobalScope step 1: the unsafe creation time.
    service_worker_mod.addImport("hr_time", hr_time_mod);
    // The URL Standard's parser, serializer and origins (scope and script URL
    // checks, registration matching).
    service_worker_mod.addImport("basic_parser", url_basic_parser_mod);
    service_worker_mod.addImport("url_serializer", url_serializer_mod);
    service_worker_mod.addImport("url_record", url_internal_url_record_mod);
    service_worker_mod.addImport("origin", url_origin_mod_internal);
    // Static routing: a router condition's URL pattern (Parse URL Pattern,
    // Match Router Condition).
    service_worker_mod.addImport("urlpattern", urlpattern_mod);
    // Cookie Store: a registration's cookie change subscription list and
    // "process cookie changes" step 2 (cookiestore imports neither
    // service_worker nor anything that does: no cycle).
    service_worker_mod.addImport("cookiestore", cookiestore_mod);
    impls_mod.addImport("service_worker", service_worker_mod);

    // Permissions module (W3C Permissions API)
    const permissions_mod = graphModule(b, public, "permissions", .{
        .root_source_file = b.path("src/permissions/root.zig"),
        .target = target,
    });

    // Add permissions to impls for navigator.permissions implementation
    permissions_mod.addImport("runtime", runtime_mod);
    impls_mod.addImport("permissions", permissions_mod);

    // Browser module - Single V8 isolate browser implementation for WPT
    const browser_mod = graphModule(b, public, "browser", .{
        .root_source_file = b.path("src/browser/root.zig"),
        .target = target,
    });
    browser_mod.addImport("clock", clock_mod);
    browser_mod.addImport("host", host_mod);
    browser_mod.addImport("engine", engine_mod);
    browser_mod.addImport("runtime", runtime_mod);
    browser_mod.addImport("interfaces", interfaces_mod);
    // crane.Process installs the mixins' hooks (mixins.installHooks).
    browser_mod.addImport("mixins", mixins_mod);
    browser_mod.addImport("namespaces", namespaces_mod);
    browser_mod.addImport("fetch", fetch_mod);
    // The Browser owns the user agent's cookie jar.
    browser_mod.addImport("cookiestore", cookiestore_mod);
    browser_mod.addImport("impls", impls_mod);
    browser_mod.addImport("webidl", webidl_mod);
    browser_mod.addImport("dom", dom_mod);
    browser_mod.addImport("html", html_mod);
    // The platform protocol: the Browser's platform state, clock and seed.
    browser_mod.addImport("platform", platform_mod);
    // A navigation's URL string is parsed and serialized before it is fetched.
    browser_mod.addImport("basic_parser", url_basic_parser_mod);
    browser_mod.addImport("url_serializer", url_serializer_mod);
    // The Browser's Clear-Site-Data handler clears its service worker
    // registrations (src/browser/clear_site_data.zig).
    browser_mod.addImport("service_worker", service_worker_mod);

    // WebDriver module - W3C WebDriver protocol implementation for wptrunner
    const webdriver_mod = graphModule(b, public, "webdriver", .{
        .root_source_file = b.path("src/webdriver/root.zig"),
        .target = target,
    });
    webdriver_mod.addImport("clock", clock_mod);
    webdriver_mod.addImport("host", host_mod);
    webdriver_mod.addImport("browser", browser_mod);

    // Intl module - ECMA-402 Internationalization APIs (pure Zig ICU replacement)
    const intl_mod = graphModule(b, public, "intl", .{
        .root_source_file = b.path("src/intl/root.zig"),
        .target = target,
    });
    intl_mod.addImport("infra", infra_mod);
    intl_mod.addImport("host", host_mod);
    html_mod.addImport("intl", intl_mod);

    // V8 module needs intl for pure Zig Intl.DateTimeFormat implementation
    v8_mod.addImport("intl", intl_mod);

    // V8 module needs fetch for ES module loading from HTTP URLs
    v8_mod.addImport("fetch", fetch_mod);

    // Wire spec modules into whatwg module
    whatwg_mod.addImport("infra", infra_mod);
    whatwg_mod.addImport("webidl", webidl_mod);
    whatwg_mod.addImport("runtime", runtime_mod);
    whatwg_mod.addImport("dom", dom_mod);
    whatwg_mod.addImport("encoding", encoding_mod);
    whatwg_mod.addImport("url", url_mod);
    whatwg_mod.addImport("console", console_mod);
    whatwg_mod.addImport("streams", streams_mod);
    whatwg_mod.addImport("mimesniff", mimesniff_mod);
    whatwg_mod.addImport("interfaces", interfaces_mod);
    whatwg_mod.addImport("impls", impls_mod);
    whatwg_mod.addImport("quirks", quirks_mod);
    whatwg_mod.addImport("css", css_mod);
    whatwg_mod.addImport("file", file_mod);
    whatwg_mod.addImport("fs", fs_mod);
    whatwg_mod.addImport("fetch", fetch_mod);
    whatwg_mod.addImport("trusted_types", trusted_types_mod);
    whatwg_mod.addImport("csp", csp_mod);
    whatwg_mod.addImport("hr_time", hr_time_mod);
    whatwg_mod.addImport("websocket", websocket_mod);
    whatwg_mod.addImport("permissions", permissions_mod);
    whatwg_mod.addImport("html", html_mod);
    whatwg_mod.addImport("browser", browser_mod);
    whatwg_mod.addImport("intl", intl_mod);

    return .{
        .whatwg = whatwg_mod,
        .clock = clock_mod,
        .host = host_mod,
        .memory = memory_mod,
        .process = process_mod,
        .infra = infra_mod,
        .webidl = webidl_mod,
        .storage = storage_mod,
        .cookiestore = cookiestore_mod,
        .runtime = runtime_mod,
        .v8 = v8_mod,
        .codegen = codegen_mod,
        .callbacks = callbacks_mod,
        .dictionaries = dictionaries_mod,
        .enums = enums_mod,
        .namespaces = namespaces_mod,
        .typedefs = typedefs_mod,
        .interfaces = interfaces_mod,
        .impls = impls_mod,
        .webcrypto = webcrypto_mod,
        .eventsource = eventsource_mod,
        .engine = engine_mod,
        .dom = dom_mod,
        .quirks = quirks_mod,
        .css = css_mod,
        .selector = selector_mod,
        .mixins = mixins_mod,
        .encoding = encoding_mod,
        .url = url_mod,
        .urlpattern = urlpattern_mod,
        .console = console_mod,
        .streams_common = streams_common_mod,
        .streams_event_loop = streams_event_loop_mod,
        .streams_async_promise = streams_async_promise_mod,
        .streams_test_event_loop = streams_test_event_loop_mod,
        .streams_queue = streams_queue_mod,
        .streams_read_request = streams_read_request_mod,
        .streams_write_request = streams_write_request_mod,
        .streams_read_into_request = streams_read_into_request_mod,
        .streams_pull_into_descriptor = streams_pull_into_descriptor_mod,
        .streams = streams_mod,
        .mimesniff = mimesniff_mod,
        .compression = compression_mod,
        .file = file_mod,
        .fs = fs_mod,
        .referrer_policy = referrer_policy_mod,
        .csp = csp_mod,
        .fetch = fetch_mod,
        .xhr = xhr_mod,
        .trusted_types = trusted_types_mod,
        .hr_time = hr_time_mod,
        .websocket = websocket_mod,
        .platform = platform_mod,
        .platform_options = platform_options_mod,
        .c_time = platform_binding.c_time,
        .html_core = html_core_mod,
        .html = html_mod,
        .service_worker = service_worker_mod,
        .xml = xml_mod,
        .xml_document_encoding = xml_document_encoding_mod,
        .permissions = permissions_mod,
        .browser = browser_mod,
        .webdriver = webdriver_mod,
        .intl = intl_mod,
    };
}
