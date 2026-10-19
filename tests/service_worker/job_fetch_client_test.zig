//! What the Update algorithm's script fetch reads of its job's client
//! (run.zig FetchClient), copied when the job is made: the client's policy
//! container WITHOUT its CSP list. All three browsers check a service worker
//! script URL against the client's CSP once, at register() (realm.zig), and
//! enforce nothing on the job's own fetch - WebKit's ServiceWorkerJob loads
//! with ContentSecurityPolicyEnforcement::DoNotEnforce, Chromium's
//! browser-side register job and script loader check no CSP, Gecko's
//! ServiceWorkerScriptCache channel carries none - so update() fetches under a
//! policy added after registration (crane/sw1b10-update-csp.https.html).
//! The rest of the container (its referrer policy) still applies.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const sw = @import("service_worker");

test "the job's fetch client keeps the client's referrer policy and drops its CSP list" {
    var container = try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
        .url = "https://a.example/page.html",
        .csp = "worker-src 'none'",
        .referrer_policy = "no-referrer",
    });
    defer container.deinit();
    try testing.expect(!container.csp_list.isEmpty());
    const client: fetch.internal.RequestClient = .{ .origin = "https://a.example", .policy_container = &container };
    const made = try sw.run.FetchClient.create(null, &client);
    defer made.destroy();
    const copied = made.policy_container orelse return error.TestUnexpectedResult;
    try testing.expect(copied.csp_list.isEmpty());
    try testing.expectEqual(container.referrer_policy, copied.referrer_policy);
    // The client's own container is untouched.
    try testing.expect(!container.csp_list.isEmpty());
}
