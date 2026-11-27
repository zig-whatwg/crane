//! TLS 1.2/1.3 server transport for `devtools_transport` (platform protocol
//! 6.12; tmp/plans/mcp1-design.md 3) over the kit's bundled mbedTLS 3.6.
//!
//! Uses `getentropy(2)` (via `fillRandom`) as the mbedTLS RNG callback so no
//! `/dev/urandom` descriptors or DRBG contexts are held per server or stream.
//! Generates fast ephemeral ECDSA P-256 self-signed X.509 v3 certificates in
//! pure Zig (RFC 5280 + RFC 5915 SEC1 DER) when the host supplies no PEM
//! cert/key, computes the leaf certificate's SHA-256 DER fingerprint for
//! client pinning, and polls `{fd, wake.read}` inside the mbedTLS recv BIO so
//! shutdown immediately aborts stalled handshakes and idle reads without
//! touching `mbedtls_ssl_context` from another thread.

const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform");
const posix_root = @import("root.zig");
const transport = @import("devtools_transport.zig");

const enabled = @import("kit_posix_options").mbedtls_tls_server;
const c = if (enabled) @import("mbedtls_c") else struct {};
const libc = std.c;
const Error = platform.Error;

const is_linux = builtin.os.tag == .linux;
const send_flags: u32 = if (is_linux) 0x4000 else 0; // MSG_NOSIGNAL on Linux

fn lastError() libc.E {
    return @fromBackingInt(@intCast(libc._errno().*));
}

fn mbedRandom(_: ?*anyopaque, out: [*c]u8, len: usize) callconv(.c) c_int {
    if (len > 0) posix_root.fillRandom(out[0..len]);
    return 0;
}

const TlsServer = if (enabled) struct {
    allocator: std.mem.Allocator,
    conf: c.mbedtls_ssl_config,
    cert: c.mbedtls_x509_crt,
    key: c.mbedtls_pk_context,
    cert_sha256: [32]u8,
} else opaque {};

const BioState = struct {
    fd: libc.fd_t,
    wake_read_fd: libc.fd_t,
    timeout_ms: c_int,
    woken: bool = false,
    timed_out: bool = false,
    closing: bool = false,
};

const TlsStream = if (enabled) struct {
    allocator: std.mem.Allocator,
    ssl: c.mbedtls_ssl_context,
    bio: BioState,
} else opaque {};

fn bioSend(ctx: ?*anyopaque, buf: [*c]const u8, len: usize) callconv(.c) c_int {
    if (!enabled) return -1;
    const bio: *BioState = @ptrCast(@alignCast(ctx.?));
    if (len == 0) return 0;
    if (bio.closing) {
        var pfd = [_]libc.pollfd{.{ .fd = bio.fd, .events = libc.POLL.OUT, .revents = 0 }};
        const ready = libc.poll(&pfd, 1, 50);
        if (ready <= 0) return c.MBEDTLS_ERR_NET_SEND_FAILED;
    }
    while (true) {
        const n = libc.send(bio.fd, buf, len, send_flags);
        if (n >= 0) return @intCast(n);
        const err = lastError();
        if (err == .INTR) continue;
        if (err == .AGAIN) return c.MBEDTLS_ERR_SSL_WANT_WRITE;
        if (err == .PIPE or err == .CONNRESET) return c.MBEDTLS_ERR_NET_CONN_RESET;
        return c.MBEDTLS_ERR_NET_SEND_FAILED;
    }
}

fn bioRecv(ctx: ?*anyopaque, buf: [*c]u8, len: usize) callconv(.c) c_int {
    if (!enabled) return -1;
    const bio: *BioState = @ptrCast(@alignCast(ctx.?));
    if (len == 0) return 0;
    var poll_fds = [_]libc.pollfd{
        .{ .fd = bio.fd, .events = libc.POLL.IN, .revents = 0 },
        .{ .fd = bio.wake_read_fd, .events = libc.POLL.IN, .revents = 0 },
    };
    while (true) {
        const ready = libc.poll(&poll_fds, poll_fds.len, bio.timeout_ms);
        if (ready < 0) {
            if (lastError() == .INTR) continue;
            return c.MBEDTLS_ERR_NET_RECV_FAILED;
        }
        if (ready == 0) {
            bio.timed_out = true;
            return c.MBEDTLS_ERR_SSL_TIMEOUT;
        }
        if (poll_fds[1].revents != 0) {
            bio.woken = true;
            return c.MBEDTLS_ERR_NET_RECV_FAILED;
        }
        if (poll_fds[0].revents != 0) break;
    }
    while (true) {
        const n = libc.recv(bio.fd, buf, len, 0);
        if (n >= 0) return @intCast(n);
        const err = lastError();
        if (err == .INTR) continue;
        if (err == .AGAIN) return c.MBEDTLS_ERR_SSL_WANT_READ;
        if (err == .CONNRESET or err == .PIPE or err == .NOTCONN) return 0;
        return c.MBEDTLS_ERR_NET_RECV_FAILED;
    }
}

// ---------------------------------------------------------------------------
// Minimal DER / X.509 v3 / RFC 5915 SEC1 ECDSA P-256 generator
// ---------------------------------------------------------------------------

fn appendDerTlv(allocator: std.mem.Allocator, out: *std.ArrayList(u8), tag: u8, content: []const u8) error{OutOfMemory}!void {
    try out.append(allocator, tag);
    if (content.len < 128) {
        try out.append(allocator, @intCast(content.len));
    } else if (content.len <= 0xFF) {
        try out.append(allocator, 0x81);
        try out.append(allocator, @intCast(content.len));
    } else {
        try out.append(allocator, 0x82);
        try out.append(allocator, @intCast((content.len >> 8) & 0xFF));
        try out.append(allocator, @intCast(content.len & 0xFF));
    }
    try out.appendSlice(allocator, content);
}

fn appendDerTime(allocator: std.mem.Allocator, out: *std.ArrayList(u8), epoch_secs: i64) error{OutOfMemory}!void {
    const secs_u64: u64 = if (epoch_secs < 0) 0 else @intCast(epoch_secs);
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = secs_u64 };
    const epoch_day = epoch_seconds.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_secs = epoch_seconds.getDaySeconds();
    if (year_day.year >= 1950 and year_day.year < 2050) {
        var buf: [13]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{d:0>2}{d:0>2}{d:0>2}{d:0>2}{d:0>2}{d:0>2}Z", .{
            year_day.year % 100,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_secs.getHoursIntoDay(),
            day_secs.getMinutesIntoHour(),
            day_secs.getSecondsIntoMinute(),
        }) catch unreachable;
        try appendDerTlv(allocator, out, 0x17, &buf); // UTCTime
    } else {
        var buf: [15]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{d:0>4}{d:0>2}{d:0>2}{d:0>2}{d:0>2}{d:0>2}Z", .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_secs.getHoursIntoDay(),
            day_secs.getMinutesIntoHour(),
            day_secs.getSecondsIntoMinute(),
        }) catch unreachable;
        try appendDerTlv(allocator, out, 0x18, &buf); // GeneralizedTime
    }
}

fn encodeSanExtension(extra_host: []const u8, buf: *[256]u8) []const u8 {
    var body: [240]u8 = undefined;
    var pos: usize = 0;

    // dNSName [2] "localhost"
    const dns_local = "localhost";
    body[pos] = 0x82;
    body[pos + 1] = dns_local.len;
    @memcpy(body[pos + 2 .. pos + 2 + dns_local.len], dns_local);
    pos += 2 + dns_local.len;

    // iPAddress [7] 127.0.0.1
    body[pos] = 0x87;
    body[pos + 1] = 4;
    @memcpy(body[pos + 2 .. pos + 6], &[_]u8{ 127, 0, 0, 1 });
    pos += 6;

    // iPAddress [7] ::1
    const ipv6_loopback = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 };
    body[pos] = 0x87;
    body[pos + 1] = 16;
    @memcpy(body[pos + 2 .. pos + 18], &ipv6_loopback);
    pos += 18;

    if (extra_host.len > 0) {
        if (transport.parseIpv4(extra_host)) |v4| {
            const is_wild = v4[0] == 0 and v4[1] == 0 and v4[2] == 0 and v4[3] == 0;
            const is_loop = v4[0] == 127 and v4[1] == 0 and v4[2] == 0 and v4[3] == 1;
            if (!is_wild and !is_loop) {
                body[pos] = 0x87;
                body[pos + 1] = 4;
                @memcpy(body[pos + 2 .. pos + 6], &v4);
                pos += 6;
            }
        } else if (transport.parseIpv6(extra_host)) |v6| {
            const zeros: [16]u8 = @splat(0);
            if (!std.mem.eql(u8, &v6, &zeros) and !std.mem.eql(u8, &v6, &ipv6_loopback)) {
                body[pos] = 0x87;
                body[pos + 1] = 16;
                @memcpy(body[pos + 2 .. pos + 18], &v6);
                pos += 18;
            }
        }
    }

    buf[0] = 0x30;
    buf[1] = @intCast(pos);
    @memcpy(buf[2 .. 2 + pos], body[0..pos]);
    return buf[0 .. 2 + pos];
}

fn appendExtension(allocator: std.mem.Allocator, out: *std.ArrayList(u8), oid: []const u8, critical: bool, value_der: []const u8) error{OutOfMemory}!void {
    var inner: std.ArrayList(u8) = .empty;
    defer inner.deinit(allocator);
    try appendDerTlv(allocator, &inner, 0x06, oid);
    if (critical) try appendDerTlv(allocator, &inner, 0x01, &[_]u8{0xFF});
    try appendDerTlv(allocator, &inner, 0x04, value_der);
    try appendDerTlv(allocator, out, 0x30, inner.items);
}

/// Generate an ephemeral ECDSA P-256 keypair and self-signed X.509 v3 cert,
/// parsing both into mbedTLS's `cert` and `key` structures.
fn generateSelfSigned(allocator: std.mem.Allocator, cert: *c.mbedtls_x509_crt, key: *c.mbedtls_pk_context, common_name: []const u8) Error!void {
    const Ecdsa = std.crypto.sign.ecdsa.EcdsaP256Sha256;
    var seed: [Ecdsa.KeyPair.seed_length]u8 = undefined;
    posix_root.fillRandom(&seed);
    const kp = Ecdsa.KeyPair.generateDeterministic(seed) catch return error.Io;
    const secret_bytes = kp.secret_key.toBytes();
    const pub_uncompressed = kp.public_key.toUncompressedSec1();

    // 1. Encode RFC 5915 SEC1 ECPrivateKey DER for mbedtls_pk_parse_key.
    const oid_prime256v1 = [_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07 };
    var sec1_body: std.ArrayList(u8) = .empty;
    defer sec1_body.deinit(allocator);
    // version INTEGER 1
    try appendDerTlv(allocator, &sec1_body, 0x02, &[_]u8{1});
    // privateKey OCTET STRING (32 bytes)
    try appendDerTlv(allocator, &sec1_body, 0x04, &secret_bytes);
    // parameters [0] EXPLICIT OID prime256v1
    var param_oid: std.ArrayList(u8) = .empty;
    defer param_oid.deinit(allocator);
    try appendDerTlv(allocator, &param_oid, 0x06, &oid_prime256v1);
    try appendDerTlv(allocator, &sec1_body, 0xA0, param_oid.items);
    // publicKey [1] EXPLICIT BIT STRING (0 unused bits || uncompressed pubkey)
    var pub_bitstr: [66]u8 = undefined;
    pub_bitstr[0] = 0x00;
    @memcpy(pub_bitstr[1..], &pub_uncompressed);
    var pub_tlv: std.ArrayList(u8) = .empty;
    defer pub_tlv.deinit(allocator);
    try appendDerTlv(allocator, &pub_tlv, 0x03, &pub_bitstr);
    try appendDerTlv(allocator, &sec1_body, 0xA1, pub_tlv.items);

    var sec1_der: std.ArrayList(u8) = .empty;
    defer sec1_der.deinit(allocator);
    try appendDerTlv(allocator, &sec1_der, 0x30, sec1_body.items);

    if (c.mbedtls_pk_parse_key(key, sec1_der.items.ptr, sec1_der.items.len, null, 0, mbedRandom, null) != 0) return error.Io;

    // 2. Encode RFC 5280 TBSCertificate DER.
    // AlgorithmIdentifier: ecdsa-with-SHA256 (1.2.840.10045.4.3.2), no parameters.
    const alg_ecdsa_sha256 = [_]u8{ 0x30, 0x0A, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02 };
    // Distinguished Name: CN=crane-mcp
    const dn_cn = [_]u8{
        0x30, 0x14, // SEQUENCE (Name)
        0x31, 0x12, // SET (RDN)
        0x30, 0x10, // SEQUENCE (AVA)
        0x06, 0x03, 0x55, 0x04, 0x03, // OID 2.5.4.3 (CN)
        0x0C, 0x09, 'c', 'r', 'a', 'n', 'e', '-', 'm', 'c', 'p', // UTF8String
    };
    // SubjectPublicKeyInfo AlgorithmIdentifier: id-ecPublicKey + prime256v1
    const spki_alg = [_]u8{
        0x30, 0x13,
        0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, // id-ecPublicKey
        0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, // prime256v1
    };

    var tbs_body: std.ArrayList(u8) = .empty;
    defer tbs_body.deinit(allocator);
    // version [0] EXPLICIT INTEGER 2 (v3)
    try tbs_body.appendSlice(allocator, &[_]u8{ 0xA0, 0x03, 0x02, 0x01, 0x02 });
    // serialNumber positive 16-byte INTEGER
    var serial: [16]u8 = undefined;
    posix_root.fillRandom(&serial);
    serial[0] &= 0x7F;
    if (serial[0] == 0) serial[0] = 1;
    try appendDerTlv(allocator, &tbs_body, 0x02, &serial);
    // signature AlgorithmIdentifier
    try tbs_body.appendSlice(allocator, &alg_ecdsa_sha256);
    // issuer
    try tbs_body.appendSlice(allocator, &dn_cn);
    // validity (now - 1 day .. now + 365 days)
    const now_s = @divFloor(posix_root.wallNow().ns_since_epoch, std.time.ns_per_s);
    var validity: std.ArrayList(u8) = .empty;
    defer validity.deinit(allocator);
    try appendDerTime(allocator, &validity, now_s - 86_400);
    try appendDerTime(allocator, &validity, now_s + 365 * 86_400);
    try appendDerTlv(allocator, &tbs_body, 0x30, validity.items);
    // subject
    try tbs_body.appendSlice(allocator, &dn_cn);
    // subjectPublicKeyInfo
    var spki_body: std.ArrayList(u8) = .empty;
    defer spki_body.deinit(allocator);
    try spki_body.appendSlice(allocator, &spki_alg);
    try appendDerTlv(allocator, &spki_body, 0x03, &pub_bitstr);
    try appendDerTlv(allocator, &tbs_body, 0x30, spki_body.items);

    // extensions [3] EXPLICIT SEQUENCE
    var exts_seq: std.ArrayList(u8) = .empty;
    defer exts_seq.deinit(allocator);
    // BasicConstraints: CA:FALSE (critical)
    try appendExtension(allocator, &exts_seq, &[_]u8{ 0x55, 0x1D, 0x13 }, true, &[_]u8{ 0x30, 0x00 });
    // KeyUsage: digitalSignature (bit 0 = 0x80 with 7 unused bits, critical)
    try appendExtension(allocator, &exts_seq, &[_]u8{ 0x55, 0x1D, 0x0F }, true, &[_]u8{ 0x03, 0x02, 0x07, 0x80 });
    // ExtendedKeyUsage: id-kp-serverAuth (1.3.6.1.5.5.7.3.1)
    try appendExtension(allocator, &exts_seq, &[_]u8{ 0x55, 0x1D, 0x25 }, false, &[_]u8{ 0x30, 0x0A, 0x06, 0x08, 0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01 });
    // SubjectAltName
    var san_buf: [256]u8 = undefined;
    const san_der = encodeSanExtension(common_name, &san_buf);
    try appendExtension(allocator, &exts_seq, &[_]u8{ 0x55, 0x1D, 0x11 }, false, san_der);

    var exts_outer: std.ArrayList(u8) = .empty;
    defer exts_outer.deinit(allocator);
    try appendDerTlv(allocator, &exts_outer, 0x30, exts_seq.items);
    try appendDerTlv(allocator, &tbs_body, 0xA3, exts_outer.items);

    var tbs_der: std.ArrayList(u8) = .empty;
    defer tbs_der.deinit(allocator);
    try appendDerTlv(allocator, &tbs_der, 0x30, tbs_body.items);

    // 3. Sign TBSCertificate with ECDSA P-256 SHA-256 and assemble final Certificate DER.
    const sig = kp.sign(tbs_der.items, null) catch return error.Io;
    var sig_der_buf: [Ecdsa.Signature.der_encoded_length_max]u8 = undefined;
    const sig_der = sig.toDer(&sig_der_buf);

    var cert_body: std.ArrayList(u8) = .empty;
    defer cert_body.deinit(allocator);
    try cert_body.appendSlice(allocator, tbs_der.items);
    try cert_body.appendSlice(allocator, &alg_ecdsa_sha256);
    var sig_bits: [Ecdsa.Signature.der_encoded_length_max + 1]u8 = undefined;
    sig_bits[0] = 0x00;
    @memcpy(sig_bits[1 .. 1 + sig_der.len], sig_der);
    try appendDerTlv(allocator, &cert_body, 0x03, sig_bits[0 .. 1 + sig_der.len]);

    var cert_der: std.ArrayList(u8) = .empty;
    defer cert_der.deinit(allocator);
    try appendDerTlv(allocator, &cert_der, 0x30, cert_body.items);

    if (c.mbedtls_x509_crt_parse_der(cert, cert_der.items.ptr, cert_der.items.len) != 0) return error.Io;
}

fn loadHostPem(allocator: std.mem.Allocator, cert: *c.mbedtls_x509_crt, key: *c.mbedtls_pk_context, cert_pem: []const u8, key_pem: []const u8) Error!void {
    if (cert_pem.len == 0 or key_pem.len == 0) return error.Io;
    const cert_z = allocator.dupeSentinel(u8, cert_pem, 0) catch return error.OutOfMemory;
    defer allocator.free(cert_z);
    const key_z = allocator.dupeSentinel(u8, key_pem, 0) catch return error.OutOfMemory;
    defer allocator.free(key_z);
    if (c.mbedtls_x509_crt_parse(cert, cert_z.ptr, cert_z.len + 1) != 0) return error.Io;
    if (c.mbedtls_pk_parse_key(key, key_z.ptr, key_z.len + 1, null, 0, mbedRandom, null) != 0) return error.Io;
}

pub fn devtoolsTlsServerNew(allocator: std.mem.Allocator, options: *const platform.DevtoolsTlsOptions) Error!platform.DevtoolsTlsServerInfo {
    if (!enabled) return error.NotSupported;
    if (c.psa_crypto_init() != c.PSA_SUCCESS) return error.Io;

    const server = allocator.create(TlsServer) catch return error.OutOfMemory;
    errdefer allocator.destroy(server);
    server.allocator = allocator;
    c.mbedtls_ssl_config_init(&server.conf);
    errdefer c.mbedtls_ssl_config_free(&server.conf);
    c.mbedtls_x509_crt_init(&server.cert);
    errdefer c.mbedtls_x509_crt_free(&server.cert);
    c.mbedtls_pk_init(&server.key);
    errdefer c.mbedtls_pk_free(&server.key);

    if (options.cert_pem.len != 0 or options.key_pem.len != 0) {
        try loadHostPem(allocator, &server.cert, &server.key, options.cert_pem.slice(), options.key_pem.slice());
    } else {
        try generateSelfSigned(allocator, &server.cert, &server.key, options.common_name.slice());
    }

    if (server.cert.raw.p == null or server.cert.raw.len == 0) return error.Io;
    std.crypto.hash.sha2.Sha256.hash(server.cert.raw.p[0..server.cert.raw.len], &server.cert_sha256, .{});

    if (c.mbedtls_ssl_config_defaults(&server.conf, c.MBEDTLS_SSL_IS_SERVER, c.MBEDTLS_SSL_TRANSPORT_STREAM, c.MBEDTLS_SSL_PRESET_DEFAULT) != 0) return error.Io;
    c.mbedtls_ssl_conf_rng(&server.conf, mbedRandom, null);
    c.mbedtls_ssl_conf_min_tls_version(&server.conf, c.MBEDTLS_SSL_VERSION_TLS1_2);
    if (c.mbedtls_ssl_conf_own_cert(&server.conf, &server.cert, &server.key) != 0) return error.Io;

    return .{
        .handle = @ptrCast(server),
        .cert_sha256 = server.cert_sha256,
    };
}

pub fn devtoolsTlsServerClose(handle: *platform.DevtoolsTlsServer) void {
    if (!enabled) return;
    const server: *TlsServer = @ptrCast(@alignCast(handle));
    const allocator = server.allocator;
    c.mbedtls_ssl_config_free(&server.conf);
    c.mbedtls_x509_crt_free(&server.cert);
    c.mbedtls_pk_free(&server.key);
    allocator.destroy(server);
}

pub fn devtoolsTlsAccept(allocator: std.mem.Allocator, handle: *platform.DevtoolsTlsServer, raw_stream: platform.DevtoolsStream, wake: platform.DevtoolsWake) Error!?*platform.DevtoolsTlsStream {
    if (!enabled) return error.NotSupported;
    const server: *TlsServer = @ptrCast(@alignCast(handle));
    const conn = allocator.create(TlsStream) catch return error.OutOfMemory;
    errdefer allocator.destroy(conn);
    conn.allocator = allocator;
    conn.bio = .{
        .fd = @intCast(raw_stream.handle),
        .wake_read_fd = @intCast(wake.read),
        .timeout_ms = 10_000,
    };
    c.mbedtls_ssl_init(&conn.ssl);
    errdefer c.mbedtls_ssl_free(&conn.ssl);
    if (c.mbedtls_ssl_setup(&conn.ssl, &server.conf) != 0) return error.Io;
    c.mbedtls_ssl_set_bio(&conn.ssl, &conn.bio, bioSend, bioRecv, null);

    while (true) {
        const ret = c.mbedtls_ssl_handshake(&conn.ssl);
        if (ret == 0) break;
        if (conn.bio.woken) {
            c.mbedtls_ssl_free(&conn.ssl);
            allocator.destroy(conn);
            return null;
        }
        if (ret == c.MBEDTLS_ERR_SSL_WANT_READ or ret == c.MBEDTLS_ERR_SSL_WANT_WRITE) continue;
        return error.Io;
    }
    conn.bio.timeout_ms = -1;
    return @ptrCast(conn);
}

pub fn devtoolsTlsRead(handle: *platform.DevtoolsTlsStream, buffer: []u8, wake: platform.DevtoolsWake) Error!?usize {
    if (!enabled) return error.NotSupported;
    if (buffer.len == 0) return 0;
    const conn: *TlsStream = @ptrCast(@alignCast(handle));
    conn.bio.wake_read_fd = @intCast(wake.read);
    conn.bio.woken = false;
    conn.bio.timeout_ms = -1;
    while (true) {
        const ret = c.mbedtls_ssl_read(&conn.ssl, buffer.ptr, buffer.len);
        if (ret > 0) return @intCast(ret);
        if (conn.bio.woken) return null;
        if (ret == 0 or ret == c.MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY or ret == c.MBEDTLS_ERR_NET_CONN_RESET) return 0;
        if (ret == c.MBEDTLS_ERR_SSL_WANT_READ or ret == c.MBEDTLS_ERR_SSL_WANT_WRITE or ret == c.MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET) continue;
        return error.Io;
    }
}

pub fn devtoolsTlsWrite(handle: *platform.DevtoolsTlsStream, bytes: platform.Bytes) Error!void {
    if (!enabled) return error.NotSupported;
    const conn: *TlsStream = @ptrCast(@alignCast(handle));
    var rest = bytes.slice();
    while (rest.len > 0) {
        const ret = c.mbedtls_ssl_write(&conn.ssl, rest.ptr, rest.len);
        if (ret > 0) {
            rest = rest[@intCast(ret)..];
            continue;
        }
        if (ret == c.MBEDTLS_ERR_SSL_WANT_READ or ret == c.MBEDTLS_ERR_SSL_WANT_WRITE) continue;
        return error.Io;
    }
}

pub fn devtoolsTlsClose(handle: *platform.DevtoolsTlsStream) void {
    if (!enabled) return;
    const conn: *TlsStream = @ptrCast(@alignCast(handle));
    const allocator = conn.allocator;
    conn.bio.closing = true;
    _ = c.mbedtls_ssl_close_notify(&conn.ssl);
    c.mbedtls_ssl_free(&conn.ssl);
    allocator.destroy(conn);
}

// ---------------------------------------------------------------------------
// Unit test: real mbedTLS client <-> server handshake, SHA-256 fingerprint
// verification, and encrypted round-trip.
// ---------------------------------------------------------------------------

test "tls_server: mbedTLS client connects, verifies server SHA-256 cert fingerprint, and exchanges encrypted bytes" {
    if (!enabled) return error.SkipZigTest;
    const allocator = std.testing.allocator;

    const tls_info = try devtoolsTlsServerNew(allocator, &.{ .common_name = platform.Str.from("127.0.0.1") });
    defer devtoolsTlsServerClose(tls_info.handle);

    const listener = try transport.devtoolsListenAddress(platform.Str.from("127.0.0.1"), 0);
    defer transport.devtoolsCloseListener(listener);
    const wake = try transport.devtoolsWakeNew();
    defer transport.devtoolsWakeClose(wake);

    const ServerCtx = struct {
        allocator: std.mem.Allocator,
        listener: platform.DevtoolsListener,
        tls: *platform.DevtoolsTlsServer,
        wake: platform.DevtoolsWake,
        ok: bool = false,

        fn run(ctx: ?*anyopaque) callconv(.c) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            const raw = (transport.devtoolsAccept(self.listener, self.wake) catch return) orelse return;
            defer transport.devtoolsClose(raw);
            const stream = (devtoolsTlsAccept(self.allocator, self.tls, raw, self.wake) catch return) orelse return;
            defer devtoolsTlsClose(stream);
            var buf: [64]u8 = undefined;
            const n = (devtoolsTlsRead(stream, &buf, self.wake) catch return) orelse return;
            if (!std.mem.eql(u8, buf[0..n], "ping-tls")) return;
            devtoolsTlsWrite(stream, platform.Bytes.from("pong-tls")) catch return;
            self.ok = true;
        }
    };

    var server_ctx: ServerCtx = .{ .allocator = allocator, .listener = listener, .tls = tls_info.handle, .wake = wake };
    const thread = try posix_root.spawnThread(.{ .name = .from("tls-test-srv") }, ServerCtx.run, &server_ctx);
    defer posix_root.joinThread(thread);

    const client_fd = libc.socket(libc.AF.INET, libc.SOCK.STREAM, 0);
    try std.testing.expect(client_fd >= 0);
    defer _ = libc.close(client_fd);
    var addr: libc.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, listener.port),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
    try std.testing.expectEqual(@as(c_int, 0), libc.connect(client_fd, @ptrCast(&addr), @sizeOf(libc.sockaddr.in)));

    var cli_conf: c.mbedtls_ssl_config = undefined;
    var cli_ssl: c.mbedtls_ssl_context = undefined;
    c.mbedtls_ssl_config_init(&cli_conf);
    defer c.mbedtls_ssl_config_free(&cli_conf);
    c.mbedtls_ssl_init(&cli_ssl);
    defer c.mbedtls_ssl_free(&cli_ssl);

    try std.testing.expectEqual(@as(c_int, 0), c.mbedtls_ssl_config_defaults(&cli_conf, c.MBEDTLS_SSL_IS_CLIENT, c.MBEDTLS_SSL_TRANSPORT_STREAM, c.MBEDTLS_SSL_PRESET_DEFAULT));
    c.mbedtls_ssl_conf_authmode(&cli_conf, c.MBEDTLS_SSL_VERIFY_OPTIONAL);
    c.mbedtls_ssl_conf_rng(&cli_conf, mbedRandom, null);
    try std.testing.expectEqual(@as(c_int, 0), c.mbedtls_ssl_setup(&cli_ssl, &cli_conf));

    var cli_bio: BioState = .{ .fd = client_fd, .wake_read_fd = @intCast(wake.read), .timeout_ms = 5_000 };
    c.mbedtls_ssl_set_bio(&cli_ssl, &cli_bio, bioSend, bioRecv, null);

    while (true) {
        const ret = c.mbedtls_ssl_handshake(&cli_ssl);
        if (ret == 0) break;
        if (ret == c.MBEDTLS_ERR_SSL_WANT_READ or ret == c.MBEDTLS_ERR_SSL_WANT_WRITE) continue;
        return error.ClientHandshakeFailed;
    }

    const peer_cert = c.mbedtls_ssl_get_peer_cert(&cli_ssl) orelse return error.NoPeerCert;
    var observed_sha256: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(peer_cert.*.raw.p[0..peer_cert.*.raw.len], &observed_sha256, .{});
    try std.testing.expectEqualSlices(u8, &tls_info.cert_sha256, &observed_sha256);

    const msg = "ping-tls";
    try std.testing.expectEqual(@as(c_int, msg.len), c.mbedtls_ssl_write(&cli_ssl, msg.ptr, msg.len));
    var reply: [64]u8 = undefined;
    var got: usize = 0;
    while (got == 0) {
        const r = c.mbedtls_ssl_read(&cli_ssl, &reply, reply.len);
        if (r > 0) {
            got = @intCast(r);
            break;
        }
        if (r == c.MBEDTLS_ERR_SSL_WANT_READ or r == c.MBEDTLS_ERR_SSL_WANT_WRITE or r == c.MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET) continue;
        return error.ClientReadFailed;
    }
    try std.testing.expectEqualStrings("pong-tls", reply[0..got]);
    _ = c.mbedtls_ssl_close_notify(&cli_ssl);
}
