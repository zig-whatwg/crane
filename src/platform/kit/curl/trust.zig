//! The certificates a TLS connection verifies its server against: the
//! platform's system root store, parsed once per process, with a Browser's
//! extra trust anchors (BrowserConfig.ca_bundle_path: the WPT runner's
//! cacert.pem) - module `kit_curl_share`'s trust store.
//!
//! Chrome loads its root store once per process and gives each network
//! context its additional trust anchors beside it (net/cert/internal/
//! system_trust_store.cc; services/cert_verifier's per-NetworkContext
//! `additional_trust_anchors`). curl's mbedTLS backend instead parses its CA
//! file and CA directory again for every connection (lib/vtls/mbedtls.c
//! mbed_connect_step1: mbedtls_x509_crt_parse_file and _parse_path), and a
//! native Linux build of the bundled curl compiled in both
//! /etc/ssl/certs/ca-certificates.crt and the 357 entries of /etc/ssl/certs:
//! ~100 ms of CPU per HTTPS connection on server1 (lane linux1). So curl is
//! built with no CA file or directory of its own (build.zig, "ca-bundle" and
//! "ca-path" "none"), and every handle gets a chain from here through curl's
//! SSL context callback (`attach`, which kit/curl's options set): parsed the
//! first time a Browser's trust is asked for, kept for the process, read by
//! every connection on every thread. mbedTLS only reads a trusted chain while
//! it verifies (x509_crt_verify_chain), so one chain serves concurrent
//! handshakes, as one mbedtls_ssl_config may serve several contexts.
//!
//! A system libcurl (-Dsystem-curl) keeps its own CA loading: there the
//! Browser's extra bundle goes to CURLOPT_CAINFO (options.zig), as before.

const std = @import("std");
const builtin = @import("builtin");

/// Whether this build's libcurl is the bundled one, over the mbedTLS this
/// module parses with (build.zig, platformBinding).
pub const enabled = @import("kit_curl_options").mbedtls_trust_store;

const c = if (enabled) @import("mbedtls_c") else struct {};

/// mbedTLS as this module translates it (x509_crt.h, ssl.h, psa/crypto.h),
/// for tests that verify a certificate against a chain.
pub const mbedtls = c;

/// A parsed chain of trusted certificates (mbedtls_x509_crt), as curl's SSL
/// context callback hands it to mbedTLS.
pub const Chain = if (enabled) c.mbedtls_x509_crt else opaque {};

/// Where the platform keeps its root certificates, first match wins: the
/// bundle files of the Linux distributions (Debian and Ubuntu, Fedora and
/// RHEL, openSUSE, OpenELEC, CentOS, Alpine - Go's crypto/x509
/// root_linux.go names the same files), and on macOS the bundle curl's
/// build found there and compiled in until now (/etc/ssl/cert.pem). None on
/// iOS, whose sandbox has no such file: only a Browser's extra anchors.
pub const system_bundles: []const []const u8 = switch (builtin.os.tag) {
    .linux => &.{
        "/etc/ssl/certs/ca-certificates.crt",
        "/etc/pki/tls/certs/ca-bundle.crt",
        "/etc/ssl/ca-bundle.pem",
        "/etc/pki/tls/cacert.pem",
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",
        "/etc/ssl/cert.pem",
    },
    .macos => &.{"/etc/ssl/cert.pem"},
    else => &.{},
};

/// One trust: the system roots and the extra bundle at `extra` ("" for none).
const Entry = struct {
    extra: []const u8,
    chain: *Chain,
};

/// Every trust asked for in this process, by extra bundle path. A process
/// has one or two (the WPT runner: its cacert.pem; the console: none).
const Store = struct {
    mutex: std.Io.Mutex = .init,
    entries: std.ArrayList(Entry) = .empty,
    /// How many chains were parsed: one per distinct extra bundle, ever.
    parses: std.atomic.Value(u32) = .init(0),
};

// process-wide: the trusted chains every TLS connection of every Browser verifies against, parsed once per distinct extra bundle and never changed after; entries are added under `mutex` and read by connections on any thread only after `chainFor` returned them; held until the process exits, like the system root store a browser loads once.
var store: Store = .{};

/// The process's own allocations: not any Browser's.
const allocator = std.heap.page_allocator;

const log = std.log.scoped(.trust_store);

/// The chain for a Browser whose extra trust anchors are the PEM bundle at
/// `extra_bundle_path` (null: none): the system root store, then those.
/// Parsed the first time it is asked for in the process, the same chain
/// after; lives as long as the process. Null when nothing at all could be
/// parsed - curl then has no trusted certificate, and every verified
/// handshake fails, as it would with no CA file.
pub fn chainFor(extra_bundle_path: ?[]const u8) ?*Chain {
    if (!enabled) return null;
    const extra = extra_bundle_path orelse "";
    std.Io.Threaded.mutexLockUncancelable(&store.mutex);
    defer std.Io.Threaded.mutexUnlock(&store.mutex);
    for (store.entries.items) |entry| if (std.mem.eql(u8, entry.extra, extra)) return entry.chain;
    const chain = parse(extra) orelse return null;
    const key = allocator.dupe(u8, extra) catch return chain;
    store.entries.append(allocator, .{ .extra = key, .chain = chain }) catch allocator.free(key);
    return chain;
}

/// How many chains this process has parsed (one per distinct extra bundle).
pub fn parseCount() u32 {
    return store.parses.load(.acquire);
}

fn parse(extra: []const u8) ?*Chain {
    const chain = allocator.create(Chain) catch return null;
    c.mbedtls_x509_crt_init(chain);
    var parsed = false;
    for (system_bundles) |path| {
        if (parseFile(chain, path)) {
            parsed = true;
            break;
        }
    }
    if (extra.len != 0) {
        if (parseFile(chain, extra)) parsed = true else log.warn("the extra trust anchors at {s} could not be read; trusting the system's alone", .{extra});
    }
    _ = store.parses.fetchAdd(1, .acq_rel);
    if (!parsed) {
        c.mbedtls_x509_crt_free(chain);
        allocator.destroy(chain);
        return null;
    }
    return chain;
}

/// Adds the PEM or DER certificates of the file at `path` to `chain`;
/// whether any was added. A bundle with some unparseable certificates keeps
/// the rest, as curl does (mbedtls_x509_crt_parse_file's positive answer).
fn parseFile(chain: *Chain, path: []const u8) bool {
    var buffer: [std.Io.Dir.max_path_bytes:0]u8 = undefined;
    if (path.len >= buffer.len) return false;
    @memcpy(buffer[0..path.len], path);
    buffer[path.len] = 0;
    const before = count(chain);
    const result = c.mbedtls_x509_crt_parse_file(chain, &buffer);
    return result >= 0 and count(chain) > before;
}

/// How many certificates `chain` holds.
pub fn count(chain: *const Chain) usize {
    if (!enabled) return 0;
    // An initialized, empty chain is one zeroed record: no raw certificate.
    if (chain.raw.p == null) return 0;
    var n: usize = 0;
    var at: ?*const Chain = chain;
    while (at) |cert| : (at = cert.next) n += 1;
    return n;
}

/// curl's SSL context callback (CURLOPT_SSL_CTX_FUNCTION): `ssl_ctx` is the
/// connection's mbedtls_ssl_config, called before the handshake (lib/vtls/
/// mbedtls.c mbed_connect_step1), and `chain` the CURLOPT_SSL_CTX_DATA
/// `chainFor` gave. The connection verifies against it.
pub fn attach(curl: ?*anyopaque, ssl_ctx: ?*anyopaque, chain: ?*anyopaque) callconv(.c) c_uint {
    _ = curl;
    if (!enabled) return 0;
    const config: *c.mbedtls_ssl_config = @ptrCast(@alignCast(ssl_ctx orelse return 0));
    c.mbedtls_ssl_conf_ca_chain(config, @ptrCast(@alignCast(chain)), null);
    return 0; // CURLE_OK
}
