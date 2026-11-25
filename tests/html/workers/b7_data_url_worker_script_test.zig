//! A worker's script from a data: URL is what Fetch's scheme fetch "data"
//! answers - the "data: URL processor" (Fetch 6) - and is checked as HTML
//! checks the response:
//!
//! - "fetch a classic worker script", processResponseConsumeBody step 3,
//!   refuses a script for its MIME type only when "response's URL's scheme
//!   is an HTTP(S) scheme": a classic data: worker runs whatever its type;
//! - "fetch a single module script" accepts a module script only with a
//!   JavaScript MIME type, whatever its scheme: a module data: worker whose
//!   type is none (text/plain;charset=US-ASCII), text/plain, or one that does
//!   not parse is refused.
//!
//! Golden rule 2: Chrome 157 and Firefox 159 do exactly this; Safari 27.0
//! runs a module data: worker of any type (lane core1 b7 probe, 2026-11-24).
//! The spec and the majority agree.

const std = @import("std");
const testing = std.testing;
const script_fetch = @import("html_core").workers.script_fetch;

// "cG9zdE1lc3NhZ2UoJ29rJyk=" is "postMessage('ok')".

test "a classic data: worker with no type runs, its type Fetch's default" {
    var fetched = try script_fetch.fetchWorkerScript(testing.allocator, "data:,postMessage('ok')", .{ .worker_type = .classic });
    defer fetched.deinit();
    try testing.expectEqualStrings("postMessage('ok')", fetched.source);
    try testing.expectEqualStrings("text/plain;charset=US-ASCII", fetched.content_type);
    try testing.expectEqualStrings("data:,postMessage('ok')", fetched.final_url);
}

test "a classic data: worker runs whatever its type" {
    var plain = try script_fetch.fetchWorkerScript(testing.allocator, "data:text/plain,postMessage(%27ok%27)", .{ .worker_type = .classic });
    defer plain.deinit();
    try testing.expectEqualStrings("postMessage('ok')", plain.source);
    var invalid = try script_fetch.fetchWorkerScript(testing.allocator, "data:javascript,1", .{ .worker_type = .classic });
    defer invalid.deinit();
    try testing.expectEqualStrings("1", invalid.source);
}

test "a module data: worker with no type, text/plain or a type that does not parse is refused" {
    const refused = [_][]const u8{
        "data:,export {}",
        "data:text/plain,export {}",
        "data:javascript,export {}",
        "data:text/javascript foo,export {}",
        "data:;base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/plain;base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
    };
    for (refused) |url| {
        try testing.expectError(error.ParseError, script_fetch.fetchWorkerScript(testing.allocator, url, .{ .worker_type = .module }));
    }
}

test "a module data: worker with a JavaScript MIME type runs" {
    const accepted = [_][]const u8{
        "data:text/javascript,postMessage('ok')",
        "data:TEXT/JAVASCRIPT,postMessage('ok')",
        "data:application/javascript;charset=x,postMessage('ok')",
        "data:text/javascript;base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/javascript;BASE64,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/javascript; base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/javascript;base64 ,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/javascript ;base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/javascript;charset=utf-8;base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
    };
    for (accepted) |url| {
        var fetched = try script_fetch.fetchWorkerScript(testing.allocator, url, .{ .worker_type = .module });
        defer fetched.deinit();
        try testing.expectEqualStrings("postMessage('ok')", fetched.source);
    }
}

test "'base64' that does not end the type leaves the body as it is" {
    const literal = [_][]const u8{
        "data:text/javascript;base64;charset=utf-8,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/javascript;enc=base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
        "data:text/javascript;%20base64,cG9zdE1lc3NhZ2UoJ29rJyk=",
    };
    for (literal) |url| {
        var fetched = try script_fetch.fetchWorkerScript(testing.allocator, url, .{ .worker_type = .classic });
        defer fetched.deinit();
        try testing.expectEqualStrings("cG9zdE1lc3NhZ2UoJ29rJyk=", fetched.source);
    }
}

test "a data: worker whose base64 body does not decode is a network error" {
    try testing.expectError(error.NetworkError, script_fetch.fetchWorkerScript(testing.allocator, "data:text/javascript;base64,!!", .{ .worker_type = .classic }));
}
