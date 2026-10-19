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

test "a main script's request: its referrer is the job's - its client's creation URL; with none, it stays the client's" {
    const has_referrer = comptime @hasField(script_fetch.ServiceWorkerFetchOptions, "referrer");
    {
        var options: script_fetch.ServiceWorkerFetchOptions = .{ .kind = .main_script, .origin = "https://a.example" };
        if (has_referrer) @field(options, "referrer") = "https://a.example/page.html";
        const request = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://a.example/sw.js", options);
        defer request.deinit();
        switch (request.referrer) {
            .url => |url| try testing.expectEqualStrings("https://a.example/page.html", url),
            else => return error.TestExpectedReferrerUrl,
        }
    }
    {
        // A Soft Update's job has no client: no referrer is set, as before.
        const request = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://a.example/sw.js", .{ .kind = .main_script, .origin = "https://a.example" });
        defer request.deinit();
        try testing.expect(request.referrer == .client);
    }
}

// Update step 7 for a module worker: its imported modules, compared on
// update (update_fetch.zig's stated deviation), are fetched as the module
// graph fetched them - "fetch a single module script" with the graph's
// destination "serviceworker" and credentials "omit", mode "cors" - not as a
// classic worker's importScripts() (soft-update-fetch-metadata.https.html's
// module case: sec-fetch-dest serviceworker, sec-fetch-mode cors, no
// Service-Worker header).
test "an imported module's request: serviceworker, cors, omit, no Service-Worker header" {
    const request = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://a.example/dep.js", .{
        .kind = .imported_module,
        .origin = "https://a.example",
    });
    defer request.deinit();
    try testing.expect(request.destination == .serviceworker);
    try testing.expect(request.mode == .cors);
    try testing.expect(request.credentials_mode == .omit);
    try testing.expect(request.redirect_mode == .follow);
    try testing.expect(request.service_workers_mode == .none);
    try testing.expect(request.header_list.getFirstValue("Service-Worker") == null);
}

/// A reporter that counts what it is handed.
const CountingReporter = struct {
    violations: usize = 0,

    fn report(context: *anyopaque, _: *const @import("fetch").internal.CspViolation) void {
        const self: *CountingReporter = @ptrCast(@alignCast(context));
        self.violations += 1;
    }
};

test "a service worker's importScripts() request reports its CSP violations to the reporter it is given (its own global's)" {
    var counting: CountingReporter = .{};
    const request = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://b.example/lib.js", .{
        .kind = .imported_script,
        .origin = "https://a.example",
        .csp_violation_reporter = .{ .context = &counting, .report = &CountingReporter.report },
    });
    defer request.deinit();
    const reporter = request.csp_violation_reporter orelse return error.TestUnexpectedResult;
    try testing.expect(reporter.context == @as(*anyopaque, &counting));
    // And none when none is given (the job thread's fetches).
    const plain = try script_fetch.serviceWorkerScriptRequest(testing.allocator, "https://a.example/sw.js", .{ .kind = .main_script, .origin = "https://a.example" });
    defer plain.deinit();
    try testing.expect(plain.csp_violation_reporter == null);
}
