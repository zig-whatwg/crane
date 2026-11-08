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
const trust = @import("trust.zig");

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
const CURLOPT_FORBID_REUSE: c_uint = 75;
/// CURLOPTTYPE_FUNCTIONPOINT + 108 and CURLOPTTYPE_CBPOINT + 109: the SSL
/// context callback and its data (tests/fetch/trust_store_test.zig checks
/// them against curl.h).
pub const CURLOPT_SSL_CTX_FUNCTION: c_uint = 20108;
pub const CURLOPT_SSL_CTX_DATA: c_uint = 10109;

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
};

/// Apply `options` to the curl easy handle `handle`.
pub fn apply(handle: *anyopaque, allocator: Allocator, options: HandleOptions) Allocator.Error!void {
    _ = curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, @as(c_long, if (options.verify_peer) 1 else 0));
    _ = curl_easy_setopt(handle, CURLOPT_SSL_VERIFYHOST, @as(c_long, if (options.verify_host) 2 else 0));
    if (trust.enabled) {
        // The process's trust store (trust.zig): the system roots, parsed
        // once, and the Browser's extra bundle, handed to the connection's
        // mbedTLS configuration before its handshake - curl itself loads no
        // CA file or directory (build.zig, "ca-bundle"/"ca-path" "none").
        if (trust.chainFor(options.ca_bundle_path)) |chain| {
            _ = curl_easy_setopt(handle, CURLOPT_SSL_CTX_FUNCTION, @as(*const anyopaque, @ptrCast(&trust.attach)));
            _ = curl_easy_setopt(handle, CURLOPT_SSL_CTX_DATA, @as(*anyopaque, @ptrCast(chain)));
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

test "forbidReuse sets curl's option on a handle" {
    const c = struct {
        extern fn curl_easy_init() ?*anyopaque;
        extern fn curl_easy_cleanup(curl: ?*anyopaque) void;
    };
    const handle = c.curl_easy_init() orelse return error.SkipZigTest;
    defer c.curl_easy_cleanup(handle);
    forbidReuse(handle);
    // CURLE_OK: curl knows the option id and takes a long.
    try std.testing.expectEqual(@as(c_uint, 0), curl_easy_setopt(handle, CURLOPT_FORBID_REUSE, @as(c_long, 1)));
}
