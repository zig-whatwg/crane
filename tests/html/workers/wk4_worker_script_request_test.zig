//! The request a worker's top-level script is fetched with.
//!
//! HTML "fetch a classic worker script" step 1: "a new request whose URL is
//! url, client is fetchClient, destination is destination, initiator type is
//! "other", mode is "same-origin", credentials mode is "same-origin", parser
//! metadata is "not parser-inserted", and whose use-URL-credentials flag is
//! set." "Fetch a single module script" steps 8-10 give a top-level module
//! worker script mode "same-origin" too. The client is the outside settings,
//! so the request's origin is theirs, and main fetch compares it with the
//! URL of every hop: a cross-origin script - directly or through a redirect -
//! is a network error (workers/same-origin-check.sub.html).
//!
//! The origin used to be left "client" with no client to resolve it, which
//! InternalRequest.currentUrlIsSameOrigin answers with true: every
//! cross-origin worker script loaded.

const std = @import("std");
const testing = std.testing;
const script_fetch = @import("html_core").workers.script_fetch;

const page_origin = "http://web-platform.test:8000";

test "a dedicated worker's classic script: same-origin, from the outside settings' origin" {
    const request = try script_fetch.workerScriptRequest(testing.allocator, "http://web-platform.test:8001/w.js", .{
        .requesting_origin = page_origin,
    });
    defer request.deinit();
    try testing.expectEqual(.same_origin, request.mode);
    try testing.expectEqual(.worker, request.destination);
    try testing.expectEqual(.same_origin, request.credentials_mode);
    try testing.expect(request.use_url_credentials);
    try testing.expectEqualStrings(page_origin, request.origin.origin);
    // Main fetch's same-origin check: another port is another origin.
    try testing.expect(!try request.currentUrlIsSameOrigin());
}

test "a shared worker's script is a sharedworker request, same-origin" {
    const request = try script_fetch.workerScriptRequest(testing.allocator, page_origin ++ "/w.js", .{
        .requesting_origin = page_origin,
        .shared = true,
    });
    defer request.deinit();
    try testing.expectEqual(.same_origin, request.mode);
    try testing.expectEqual(.sharedworker, request.destination);
    try testing.expectEqualStrings(page_origin, request.origin.origin);
    try testing.expect(try request.currentUrlIsSameOrigin());
}

test "a module worker's top-level script is same-origin too" {
    const request = try script_fetch.workerScriptRequest(testing.allocator, "http://other.test:8000/m.js", .{
        .requesting_origin = page_origin,
        .worker_type = .module,
    });
    defer request.deinit();
    try testing.expectEqual(.same_origin, request.mode);
    try testing.expect(!try request.currentUrlIsSameOrigin());
}

test "an opaque outside origin is same origin with no URL" {
    const request = try script_fetch.workerScriptRequest(testing.allocator, page_origin ++ "/w.js", .{
        .requesting_origin = "null",
    });
    defer request.deinit();
    try testing.expect(!try request.currentUrlIsSameOrigin());
}
