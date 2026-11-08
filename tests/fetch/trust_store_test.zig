//! The certificates TLS connections verify against (kit/curl's trust store,
//! src/platform/kit/curl/trust.zig): the platform's system roots parsed once
//! per Browser, its extra anchors beside them, and no CA file or CA
//! directory of curl's own - which curl's mbedTLS backend parsed again for
//! every connection (lib/vtls/mbedtls.c mbed_connect_step1), ~100 ms of CPU
//! per HTTPS connection on x86-64 Linux, where a native build compiled in
//! /etc/ssl/certs (lane linux1, server1).
//!
//! The fixture CA and the leaf it signed (fixtures/trust_store/, valid to
//! 2126; their keys were not kept) were made with OpenSSL 3.6:
//! `openssl req -x509 -newkey rsa:2048 ... -addext basicConstraints=critical,CA:TRUE`
//! and a leaf for DNS:trust-store.test signed by it.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const kit_curl = @import("kit_curl_share");
const curl = fetch.network.curl_ffi;
const trust = kit_curl.trust;

const fixture_ca = "tests/fetch/fixtures/trust_store/ca.pem";
const fixture_leaf = "tests/fetch/fixtures/trust_store/leaf.pem";

test "curl loads no CA bundle or CA directory of its own: a connection verifies against the trust store alone" {
    if (!trust.enabled) return error.SkipZigTest;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const handle = curl.easy_init() orelse return error.CurlInitFailed;
    defer curl.easy_cleanup(handle);
    // CURLINFO_CAINFO and CURLINFO_CAPATH: the CA file and directory curl
    // was built to load itself (curl 7.84) - none.
    var ca_file: ?[*:0]const u8 = null;
    var ca_path: ?[*:0]const u8 = null;
    try testing.expectEqual(@as(curl.CURLcode, curl.CURLE_OK), curl.easy_getinfo(handle, curl.c.CURLINFO_CAINFO, &ca_file));
    try testing.expectEqual(@as(curl.CURLcode, curl.CURLE_OK), curl.easy_getinfo(handle, curl.c.CURLINFO_CAPATH, &ca_path));
    if (ca_file) |file| std.debug.print("curl's own CA file: {s}\n", .{file});
    if (ca_path) |path| std.debug.print("curl's own CA directory: {s}\n", .{path});
    try testing.expect(ca_file == null);
    try testing.expect(ca_path == null);
    // And the options kit/curl hands the chain through are curl.h's.
    try testing.expectEqual(@as(c_uint, curl.c.CURLOPT_SSL_CTX_FUNCTION), kit_curl.options.CURLOPT_SSL_CTX_FUNCTION);
    try testing.expectEqual(@as(c_uint, curl.c.CURLOPT_SSL_CTX_DATA), kit_curl.options.CURLOPT_SSL_CTX_DATA);
}

test "a Browser's system roots are parsed once, however many of its connections ask" {
    if (!trust.enabled) return error.SkipZigTest;
    var store = trust.Store.init(testing.allocator);
    defer store.deinit();
    const first = store.chainFor(null);
    for (0..30) |_| try testing.expectEqual(first, store.chainFor(null));
    try testing.expectEqual(@as(u32, 1), store.parseCount());
    // A platform with a bundle file trusts its roots; one without (iOS)
    // trusts none on its own.
    if (trust.systemBundle() != null) try testing.expect(trust.count(first.?) > 10) else try testing.expectEqual(@as(?*trust.Chain, null), first);
}

test "a Browser's network context hands every request and handshake its one trust store" {
    var network = fetch.network.NetworkContext.init(testing.allocator);
    defer network.deinit();
    try network.configure(.{ .ca_bundle_path = fixture_ca });
    const first = network.certOptions();
    try testing.expectEqualStrings(fixture_ca, first.ca_bundle_path.?);
    try testing.expect(first.trust != null);
    try testing.expectEqual(first.trust, network.certOptions().trust);
}

/// mbedTLS's verdict on the PEM certificate at `path` against `chain`: its
/// verification flags (0: trusted).
fn verifyFlags(path: []const u8, chain: *trust.Chain) !u32 {
    const c = trust.mbedtls;
    _ = c.psa_crypto_init();
    var cert: c.mbedtls_x509_crt = undefined;
    c.mbedtls_x509_crt_init(&cert);
    defer c.mbedtls_x509_crt_free(&cert);
    const pem = try std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(64 * 1024));
    defer testing.allocator.free(pem);
    const terminated = try testing.allocator.dupeSentinel(u8, pem, 0);
    defer testing.allocator.free(terminated);
    try testing.expectEqual(@as(c_int, 0), c.mbedtls_x509_crt_parse(&cert, terminated.ptr, terminated.len + 1));
    var flags: u32 = 0;
    _ = c.mbedtls_x509_crt_verify(&cert, chain, null, "trust-store.test", &flags, null, null);
    return flags;
}

test "a Browser's extra trust anchors are trusted beside the system roots" {
    if (!trust.enabled) return error.SkipZigTest;
    var browser = trust.Store.init(testing.allocator);
    defer browser.deinit();
    const with_extra = browser.chainFor(fixture_ca) orelse return error.NoChain;
    try testing.expectEqual(with_extra, browser.chainFor(fixture_ca).?);
    try testing.expectEqual(@as(u32, 1), browser.parseCount());
    // The fixture CA's leaf verifies against the Browser's chain...
    try testing.expectEqual(@as(u32, 0), try verifyFlags(fixture_leaf, with_extra));
    // ...and not against the system roots alone (another Browser's).
    var other = trust.Store.init(testing.allocator);
    defer other.deinit();
    if (other.chainFor(null)) |system| {
        try testing.expect(try verifyFlags(fixture_leaf, system) & @as(u32, trust.mbedtls.MBEDTLS_X509_BADCERT_NOT_TRUSTED) != 0);
        // The system's roots are still in the Browser's chain: one more.
        try testing.expectEqual(trust.count(system) + 1, trust.count(with_extra));
    }
}
