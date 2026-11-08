//! The certificates a TLS connection verifies its server against: the
//! platform's system root store with a Browser's extra trust anchors
//! (BrowserConfig.ca_bundle_path: the WPT runner's cacert.pem), parsed once
//! per Browser - kit/curl's trust store, held by the Browser's network
//! context (fetch.network.NetworkContext) and handed to every connection it
//! makes.
//!
//! curl's mbedTLS backend parses its CA file and CA directory again for every
//! connection (lib/vtls/mbedtls.c mbed_connect_step1:
//! mbedtls_x509_crt_parse_file and _parse_path), and a native Linux build of
//! the bundled curl compiled in both /etc/ssl/certs/ca-certificates.crt and
//! the 357 entries of /etc/ssl/certs: ~100 ms of CPU per HTTPS connection on
//! server1 (lane linux1). So curl is built with no CA file or directory of
//! its own (build.zig, "ca-bundle" and "ca-path" "none"), and every handle
//! gets the Browser's chain through curl's SSL context callback (`attach`,
//! which kit/curl's options set). Chrome loads its root store once and gives
//! each network context its additional anchors beside it
//! (net/cert/internal/system_trust_store.cc; services/cert_verifier's
//! per-NetworkContext `additional_trust_anchors`); here the system roots are
//! the Browser's own copy - one parse per Browser instead of one per
//! handshake, and no state outside an owner. mbedTLS only reads a trusted
//! chain while it verifies (x509_crt_verify_chain), so one chain serves
//! every concurrent handshake of the Browser, on any of its threads.
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

/// A Browser's trust: the chain, parsed the first time a connection of the
/// Browser asks for it. OWNED by the Browser's network context, which ends it
/// after the last connection that could read the chain (its connection share
/// and every transfer have ended).
pub const Store = struct {
    allocator: std.mem.Allocator,
    /// Guards the parse: the first connection of the Browser to ask makes it,
    /// on whichever thread; every later one finds it.
    mutex: std.Io.Mutex = .init,
    tried: bool = false,
    chain: ?*Chain = null,
    /// How many times the chain was parsed: once, ever (for tests).
    parses: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) Store {
        return .{ .allocator = allocator };
    }

    /// The chain for the Browser whose extra trust anchors are the PEM
    /// bundle at `extra_bundle_path` (null: none - the same on every call):
    /// the system root store, then those. Parsed on the first call, the same
    /// chain after; lives until `deinit`. Null when nothing at all could be
    /// parsed - the connection then has no trusted certificate, and a
    /// verified handshake fails, as it would with no CA file.
    pub fn chainFor(self: *Store, extra_bundle_path: ?[]const u8) ?*Chain {
        if (!enabled) return null;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (self.tried) return self.chain;
        self.tried = true;
        self.parses += 1;
        self.chain = parse(self.allocator, extra_bundle_path orelse "");
        return self.chain;
    }

    /// How many times the chain was parsed (0 or 1).
    pub fn parseCount(self: *Store) u32 {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.parses;
    }

    pub fn deinit(self: *Store) void {
        if (enabled) {
            if (self.chain) |chain| {
                c.mbedtls_x509_crt_free(chain);
                self.allocator.destroy(chain);
            }
        }
        self.chain = null;
        self.tried = false;
    }
};

/// The first of `system_bundles` that exists, for a handle made without a
/// Browser's trust store (options.zig).
pub fn systemBundle() ?[]const u8 {
    // A plain system call on a path: the single-threaded Io (kit/curl
    // root.zig's futexIo, for the same reason).
    const io = std.Io.Threaded.global_single_threaded.io();
    for (system_bundles) |path| {
        std.Io.Dir.cwd().access(io, path, .{}) catch continue;
        return path;
    }
    return null;
}

const log = std.log.scoped(.trust_store);

fn parse(allocator: std.mem.Allocator, extra: []const u8) ?*Chain {
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
