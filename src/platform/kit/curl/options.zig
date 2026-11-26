//! A Browser's network options on a curl easy handle (kit/curl): its user
//! agent string, its proxy, and its TLS verification - what every transfer
//! and every WebSocket handshake of the Browser is made with. fetch's
//! curl_backend.zig and the platform WebSocket transport apply them here, so
//! neither sets these options itself, and they are set one way for both.
//!
//! Until step 2 of the platform protocol moves transfers behind the port, the
//! fetch still makes its handles in src/fetch/network. curl copies every
//! string option it is given (since 7.17), so the temporaries made here go
//! before `apply` returns.

const std = @import("std");
const Allocator = std.mem.Allocator;
const trust_store = @import("trust.zig");

/// Declared with the types translate-c gives curl.h's (CURL is void, the
/// option and the result C enums), so it is the same extern as `fetch`'s
/// @cImport of it.
extern fn curl_easy_setopt(curl: ?*anyopaque, option: c_uint, ...) c_uint;

/// curl.h's CURLoption values (CURLOPTTYPE_LONG 0, CURLOPTTYPE_STRINGPOINT
/// 10000, libcurl 8).
const CURLOPT_PROXY: c_uint = 10004;
const CURLOPT_PROXYUSERPWD: c_uint = 10006;
const CURLOPT_USERAGENT: c_uint = 10018;
const CURLOPT_SSL_VERIFYPEER: c_uint = 64;
const CURLOPT_CAINFO: c_uint = 10065;
const CURLOPT_SSL_VERIFYHOST: c_uint = 81;
const CURLOPT_NOPROXY: c_uint = 10177;
const CURLOPT_FRESH_CONNECT: c_uint = 74;
const CURLOPT_FORBID_REUSE: c_uint = 75;
/// CURLOPTTYPE_FUNCTIONPOINT + 108 and CURLOPTTYPE_CBPOINT + 109: the SSL
/// context callback and its data (tests/fetch/trust_store_test.zig checks
/// them against curl.h).
pub const CURLOPT_SSL_CTX_FUNCTION: c_uint = 20108;
pub const CURLOPT_SSL_CTX_DATA: c_uint = 10109;
/// CURLOPTTYPE_LONG + 329: the zig-whatwg/curl fork's CURLOPT_HTTP_LENIENT,
/// with both of its bits, CURLHTTPLENIENT_NOCOLON (1 << 0) and
/// CURLHTTPLENIENT_BADCLEN (1 << 1) - tests/fetch/net3_lenient_response_test
/// checks them against curl.h. Only the bundled libcurl is the fork: a
/// system libcurl may give 329 to another option, so it is never set there.
pub const CURLOPT_HTTP_LENIENT: c_uint = 329;
pub const http_lenient_all: c_long = (1 << 0) | (1 << 1);
/// CURLOPTTYPE_OFF_T (30000) + 145 / 146: transfer speed caps in bytes/sec
/// (CDP Network.emulateNetworkConditions*).
pub const CURLOPT_MAX_SEND_SPEED_LARGE: c_uint = 30145;
pub const CURLOPT_MAX_RECV_SPEED_LARGE: c_uint = 30146;

/// A proxy for one transfer.
pub const Proxy = struct {
    /// e.g. "http://proxy.example:8080"; empty: no proxy at all, whatever
    /// the environment says.
    url: []const u8,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    /// Comma-separated hosts that bypass it.
    no_proxy: ?[]const u8 = null,
};

pub const HandleOptions = struct {
    /// The `User-Agent` curl sends unless the request carries one of its
    /// own. Null: none set (fetch adds the header itself).
    user_agent: ?[]const u8 = null,
    /// Null: curl's default - the environment's proxy settings.
    proxy: ?Proxy = null,
    /// Verify the certificate chain, and the host name against it.
    verify_peer: bool = true,
    verify_host: bool = true,
    /// A CA bundle trusted besides the system's (PEM).
    ca_bundle_path: ?[]const u8 = null,
    /// The Browser's trust store (its network context's): the system roots
    /// and `ca_bundle_path`, parsed once for the Browser. BORROWED for the
    /// handle's life. Null - a handle made outside a Browser - trusts the
    /// system bundle file, or `ca_bundle_path` alone, as curl's CA file.
    trust: ?*trust_store.Store = null,
};

/// Apply `options` to the curl easy handle `handle`.
pub fn apply(handle: *anyopaque, allocator: Allocator, options: HandleOptions) Allocator.Error!void {
    // An HTTP/1 response is read the way the browsers read it: a header
    // line with no colon is skipped (Chrome net/http/http_util.cc
    // HttpUtil::HeadersIterator::GetNext; Firefox nsHttpHeaderArray::
    // ParseHeaderLine), and a Content-Length that is not a number is absent
    // (Fetch's "extract a length"; Chrome HttpResponseHeaders::
    // GetInt64HeaderValue; Firefox nsHttpResponseHead::
    // ParseResponseContentLength). libcurl's default fails both transfers
    // with CURLE_WEIRD_SERVER_REPLY. The bundled libcurl is the fork that has
    // the option (build.zig.zon); `trust_store.enabled` is "bundled".
    if (trust_store.enabled) _ = curl_easy_setopt(handle, CURLOPT_HTTP_LENIENT, http_lenient_all);
    _ = curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, @as(c_long, if (options.verify_peer) 1 else 0));
    _ = curl_easy_setopt(handle, CURLOPT_SSL_VERIFYHOST, @as(c_long, if (options.verify_host) 2 else 0));
    if (trust_store.enabled) {
        if (options.trust) |store| {
            // The Browser's trust store (trust.zig): the system roots and its
            // extra bundle, parsed once for the Browser, handed to the
            // connection's mbedTLS configuration before its handshake - curl
            // itself loads no CA file or directory (build.zig,
            // "ca-bundle"/"ca-path" "none").
            if (store.chainFor(options.ca_bundle_path)) |chain| {
                _ = curl_easy_setopt(handle, CURLOPT_SSL_CTX_FUNCTION, @as(*const anyopaque, @ptrCast(&trust_store.attach)));
                _ = curl_easy_setopt(handle, CURLOPT_SSL_CTX_DATA, @as(*anyopaque, @ptrCast(chain)));
            }
        } else if (options.ca_bundle_path orelse trust_store.systemBundle()) |path| {
            // No Browser: curl parses one CA file for the connection.
            try setString(handle, allocator, CURLOPT_CAINFO, path);
        }
    } else if (options.ca_bundle_path) |path| try setString(handle, allocator, CURLOPT_CAINFO, path);
    if (options.user_agent) |value| try setString(handle, allocator, CURLOPT_USERAGENT, value);
    if (options.proxy) |proxy| {
        try setString(handle, allocator, CURLOPT_PROXY, proxy.url);
        if (proxy.username != null and proxy.password != null) {
            const userpwd = try std.fmt.allocPrintSentinel(allocator, "{s}:{s}", .{ proxy.username.?, proxy.password.? }, 0);
            defer allocator.free(userpwd);
            _ = curl_easy_setopt(handle, CURLOPT_PROXYUSERPWD, userpwd.ptr);
        }
        if (proxy.no_proxy) |hosts| try setString(handle, allocator, CURLOPT_NOPROXY, hosts);
    }
}

fn setString(handle: *anyopaque, allocator: Allocator, option: c_uint, value: []const u8) Allocator.Error!void {
    const copy = try allocator.dupeSentinel(u8, value, 0);
    defer allocator.free(copy);
    _ = curl_easy_setopt(handle, option, copy.ptr);
}

/// The connection the transfer on `handle` uses is closed when the transfer
/// ends, not kept for another (CURLOPT_FORBID_REUSE). curl reads it when the
/// transfer is done (multi_done), so a header callback may set it for the
/// response it is reading.
pub fn forbidReuse(handle: *anyopaque) void {
    _ = curl_easy_setopt(handle, CURLOPT_FORBID_REUSE, @as(c_long, 1));
}

/// The transfer on `handle` opens a new connection rather than take one from
/// the pool (CURLOPT_FRESH_CONNECT) - Fetch's HTTP-network fetch "obtain a
/// connection" with new "yes", for HTTP-network-or-cache fetch step 17's
/// retry of a 421. The connection it opens joins the pool as any other.
pub fn freshConnect(handle: *anyopaque) void {
    _ = curl_easy_setopt(handle, CURLOPT_FRESH_CONNECT, @as(c_long, 1));
}

/// Cap download and/or upload throughput on `handle` in bytes per second
/// (0 = unlimited). Used by CDP Network.emulateNetworkConditions*.
pub fn setSpeedLimits(handle: *anyopaque, max_recv_bps: u64, max_send_bps: u64) void {
    if (max_recv_bps > 0) {
        const cap: i64 = @intCast(@min(max_recv_bps, @as(u64, std.math.maxInt(i64))));
        _ = curl_easy_setopt(handle, CURLOPT_MAX_RECV_SPEED_LARGE, cap);
    }
    if (max_send_bps > 0) {
        const cap: i64 = @intCast(@min(max_send_bps, @as(u64, std.math.maxInt(i64))));
        _ = curl_easy_setopt(handle, CURLOPT_MAX_SEND_SPEED_LARGE, cap);
    }
}
