//! An HTTP/1 response the browsers read and libcurl alone rejected (lane
//! net3): a header line with no colon, and a Content-Length that is not a
//! number. Both failed the transfer with CURLE_WEIRD_SERVER_REPLY (curl
//! lib/http.c verify_header and http_header_c), so trusted-types'
//! navigate-to-javascript-url-csp-headers (a %0A in a CSP value), the text
//! module's ignore-content-type (a %0A in a Content-Type), cookies' "ignore
//! value after LF" and resource_timing_content_length ("Content-Length:auto")
//! never got a response at all.
//!
//! Chrome skips a line with no colon (net/http/http_util.cc
//! HttpUtil::HeadersIterator::GetNext) and reads an unparsable Content-Length
//! as absent (http_response_headers.cc GetInt64HeaderValue); Firefox skips
//! the line (nsHttpHeaderArray::ParseHeaderLine) and runs Fetch's "extract a
//! length", which returns null for a value that is not all ASCII digits and
//! failure for two different values (nsHttpResponseHead::
//! ParseResponseContentLength). Crane's libcurl is the zig-whatwg/curl fork,
//! whose CURLOPT_HTTP_LENIENT does the same; kit/curl's options set it on
//! every handle. What all three browsers reject stays rejected: a NUL byte
//! in a header (fetch/h1-parsing/resources-with-0x00-in-header, C/F/S 4/4)
//! and two different lengths.
const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const network = fetch.network;
const NetworkRequest = network.NetworkRequest;
const NetworkResponse = network.NetworkResponse;
const kit_curl = @import("kit_curl_share");
const fixtures = @import("quick1b3_coding_fixtures.zig");

fn get(url: []const u8) NetworkRequest {
    return .{ .url = url, .method = "GET", .headers = &.{}, .body = null };
}

/// The response `raw` (sent whole, then the connection closes) as the
/// network layer reads it.
fn fetchRaw(raw: []const u8) !NetworkResponse {
    var server: fixtures.Canned = .{ .response = raw };
    try server.start();
    defer server.stop();
    var url_buf: [64]u8 = undefined;
    const request = get(try server.url(&url_buf, "/net3"));
    const backend = try network.LibcurlBackend.init(testing.allocator);
    defer backend.deinit();
    return backend.getBackend().send(testing.allocator, &request);
}

fn header(response: *const NetworkResponse, name: []const u8) ?[]const u8 {
    for (response.headers) |field| {
        if (std.ascii.eqlIgnoreCase(field.name, name)) return field.value;
    }
    return null;
}

test "a header line with no colon is skipped, and the fields around it are kept" {
    var response = try fetchRaw("HTTP/1.1 200 OK\r\nX-Before: one\r\nno colon on this line\r\nX-After: two\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok");
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqualStrings("one", header(&response, "X-Before").?);
    try testing.expectEqualStrings("two", header(&response, "X-After").?);
    for (response.headers) |field| try testing.expect(std.mem.indexOf(u8, field.name, "no colon") == null);
    try testing.expectEqualStrings("ok", response.body orelse "");
}

test "a %0A in a header value ends the field there, and the rest of the line is dropped" {
    // trusted-types navigate-to-javascript-url-csp-headers' whitespace case:
    // wptserve's header() pipe writes the decoded LF into the value.
    var response = try fetchRaw("HTTP/1.1 200 OK\r\nContent-Security-Policy: require-trusted-types-for 'script'\t'script'\n'script'\x0c'script'\r'script' 'script'\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok");
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqualStrings("require-trusted-types-for 'script'\t'script'", header(&response, "Content-Security-Policy").?);
    try testing.expectEqualStrings("ok", response.body orelse "");
}

test "a Content-Length that is not a number is absent: the body runs to the end of the connection" {
    // resource_timing_content_length.html's resource writes these two.
    for ([_][]const u8{ "auto", "none", "-3", "3x", "" }) |value| {
        const raw = try std.fmt.allocPrint(testing.allocator, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\nContent-Length:{s}\r\n\r\nxxxxxxx", .{value});
        defer testing.allocator.free(raw);
        var response = try fetchRaw(raw);
        defer response.deinit();
        try testing.expectEqual(@as(u16, 200), response.status);
        try testing.expectEqualStrings("xxxxxxx", response.body orelse "");
    }
}

test "two different Content-Length values stay a network error, as in Fetch's extract a length" {
    for ([_][]const u8{
        "Content-Length: 3\r\nContent-Length: 4\r\n",
        "Content-Length: 3, 4\r\n",
        "Content-Length: abc\r\nContent-Length: 3\r\n",
        "Content-Length: 3, abc\r\n",
    }) |fields| {
        const raw = try std.fmt.allocPrint(testing.allocator, "HTTP/1.1 200 OK\r\n{s}Connection: close\r\n\r\nxxxx", .{fields});
        defer testing.allocator.free(raw);
        try testing.expectError(error.ProtocolError, fetchRaw(raw));
    }
}

test "a NUL byte in a header stays a network error, as in all three browsers" {
    try testing.expectError(error.ProtocolError, fetchRaw("HTTP/1.1 200 OK\r\nX-Nul: a\x00b\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"));
}

test "kit/curl's CURLOPT_HTTP_LENIENT is curl.h's" {
    const curl = network.curl_ffi;
    if (!@hasDecl(curl.c, "CURLOPT_HTTP_LENIENT")) return error.SkipZigTest; // a system libcurl (-Dsystem-curl)
    try testing.expectEqual(@as(c_uint, curl.c.CURLOPT_HTTP_LENIENT), kit_curl.options.CURLOPT_HTTP_LENIENT);
    try testing.expectEqual(@as(c_long, curl.c.CURLHTTPLENIENT_NOCOLON | curl.c.CURLHTTPLENIENT_BADCLEN), kit_curl.options.http_lenient_all);
}
