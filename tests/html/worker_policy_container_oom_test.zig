//! HTML "initialize a worker global scope's policy container" fails closed.
//!
//! A data: or blob: worker's global scope gets a CLONE of its owner's policy
//! container (step 1). `worker_host.workerPolicyContainer` made that clone
//! with `owner.clone(allocator) catch PolicyContainer.init(allocator)`: when
//! the clone could not be allocated the worker got an EMPTY container - no
//! CSP list, the default referrer policy - and ran without its creator's
//! policies. The start fails instead now (an `error` event at the Worker or
//! SharedWorker): every allocation failure is OutOfMemory, never a container
//! without the owner's policies.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const html = @import("html");
const runtime = @import("runtime");
const fetch = @import("fetch");

const PolicyContainer = fetch.internal.PolicyContainer;

/// The page's policies: an enforced CSP and a referrer policy, both from
/// <meta>, so its container differs from a new one in both.
const page_html =
    \\<!doctype html>
    \\<meta http-equiv="Content-Security-Policy" content="img-src 'none'; connect-src 'self'">
    \\<meta name="referrer" content="no-referrer">
    \\<body></body>
;

/// One "initialize a worker global scope's policy container" for a data:
/// script, whose response made no container: the owner's, cloned with
/// `allocator`. Either it fails, or it has every one of the owner's policies.
fn initializeFor(allocator: std.mem.Allocator, fetched: *html.workers.FetchedScript, realm: runtime.Context, owner: *const PolicyContainer) error{ OutOfMemory, TestExpectedEqual }!void {
    var container = try html.worker_host.workerPolicyContainer(allocator, fetched, realm);
    defer container.deinit();
    try testing.expectEqual(owner.csp_list.policies.items.len, container.csp_list.policies.items.len);
    try testing.expectEqual(owner.referrer_policy, container.referrer_policy);
}

fn exercise() !void {
    const allocator = testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    const realm = browser.getRealm() orelse return error.NoRealm;
    const owner = html.worker_host.creatorPolicyContainer(realm) orelse return error.NoOwnerContainer;
    // The page's policies are in its container, so a clone has something to
    // lose.
    try testing.expectEqual(@as(usize, 1), owner.csp_list.policies.items.len);
    try testing.expect(owner.referrer_policy == .no_referrer);
    // A data: script, whose response made no container.
    var fetched = try html.workers.FetchedScript.init(allocator, "postMessage(1)", "data:text/javascript,postMessage(1)", "text/javascript", false);
    defer fetched.deinit();
    // The clone with nothing failing has them all.
    try initializeFor(allocator, &fetched, realm, owner);
    // And with each of its allocations failing in turn.
    try testing.checkAllAllocationFailures(allocator, initializeFor, .{ &fetched, realm, owner });
}

test "a data: worker's policy container is its owner's or none: never an empty one" {
    // A Browser of its own, on a thread of its own (tests/html shares one
    // process: no per-thread state from another file).
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
