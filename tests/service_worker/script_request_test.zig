//! The request a service worker's script fetch makes (html_core's
//! serviceWorkerScriptRequest): Update step 7's "fetch a classic worker
//! script" with destination "serviceworker" and the fetch hook's steps.
//! Its origin is the client's, set - never left at "client", which on the
//! job thread (no client to resolve it from) reads every URL as same-origin,
//! so a cross-origin script or redirect would pass.

const std = @import("std");
const testing = std.testing;
const html_core = @import("html_core");
const script_fetch = html_core.workers.script_fetch;

test "a main script's request: same-origin mode with the client's origin, serviceworker, no redirects, Service-Worker: script" {
    const request = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://a.example/sw.js", .{
        .kind = .main_script,
        .origin = "https://a.example",
        .bypass_http_cache = true,
    });
    defer request.deinit();
    try testing.expect(request.destination == .serviceworker);
    try testing.expect(request.mode == .same_origin);
    try testing.expect(request.credentials_mode == .same_origin);
    try testing.expect(request.redirect_mode == .@"error");
    try testing.expect(request.service_workers_mode == .none);
    try testing.expect(request.cache_mode == .no_cache);
    try testing.expectEqualStrings("script", request.header_list.getFirstValue("Service-Worker").?);
    switch (request.origin) {
        .origin => |origin| try testing.expectEqualStrings("https://a.example", origin),
        .client => return error.TestUnexpectedResult,
    }
    try testing.expect(try request.currentUrlIsSameOrigin());
}

test "a main script on another origin is not same-origin for its request - main fetch refuses it" {
    const request = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://b.example/sw.js", .{
        .kind = .main_script,
        .origin = "https://a.example",
    });
    defer request.deinit();
    try testing.expect(!try request.currentUrlIsSameOrigin());
    // And a hop to another origin from a same-origin URL: refused as a
    // redirect (mode "error"), and as cross-origin were it followed.
    try request.addUrl("https://c.example/sw.js");
    try testing.expect(!try request.currentUrlIsSameOrigin());
}

test "an imported script's request: no-cors, destination script, the client's origin" {
    const request = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://b.example/lib.js", .{
        .kind = .imported_script,
        .origin = "https://a.example",
    });
    defer request.deinit();
    try testing.expect(request.destination == .script);
    try testing.expect(request.mode == .no_cors);
    try testing.expect(request.redirect_mode == .follow);
    try testing.expect(request.service_workers_mode == .none);
    try testing.expect(request.cache_mode == .default);
    try testing.expect(request.header_list.getFirstValue("Service-Worker") == null);
}
