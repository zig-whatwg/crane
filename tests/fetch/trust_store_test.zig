//! The certificates TLS connections verify against (kit/curl's trust store,
//! src/platform/kit/curl/trust.zig): the platform's system roots parsed once
//! per process, a Browser's extra anchors beside them, and no CA file or CA
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
const curl = fetch.network.curl_ffi;

test "curl loads no CA bundle or CA directory of its own: a connection verifies against the trust store alone" {
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
}
