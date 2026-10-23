//! Lane closewatch1: a form's planned navigation (HTML 4.10.21.3 "plan to
//! navigate") keeps its submitter until its task runs, so the navigate event
//! names it as sourceElement (step 4.2: "with ... sourceElement set to
//! submitter") even after script removed it and dropped every reference.
//! The task held the submitter by address and slab generation only: a
//! collected submitter read as "no element".
//!
//! Run under std.testing.allocator, on a thread of its own.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const value = try browser.evaluateScript(source);
    defer value.release();
    if (!engine.toBoolean(browser.getRealm().?, value.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn submitterOutlivesItsRemoval() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><form id=f><input id=s type=submit></form></body>", .{ .base_url = "http://example.test/form" });
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\globalThis.source = 'not fired';
        \\navigation.onnavigate = event => {
        \\  event.intercept();
        \\  source = event.sourceElement ? event.sourceElement.id : null;
        \\};
        \\globalThis.weak = new WeakRef(document.getElementById('s'));
    );
    _ = try browser.runEventLoopBlocking(1);
    // Plan the navigation with the submitter, then take the submitter out of
    // the tree with no script reference left.
    try page.runScript(
        \\(() => {
        \\  const submitter = document.getElementById('s');
        \\  document.getElementById('f').requestSubmit(submitter);
        \\  submitter.remove();
        \\})();
    );
    try collect(browser);
    try expectTrue(browser, "source === 'not fired' && weak.deref() !== undefined");
    _ = try browser.runEventLoopBlocking(50);
    try expectTrue(browser, "source === 's'");
    _ = try browser.runEventLoopBlocking(1);
    try collect(browser);
    try expectTrue(browser, "weak.deref() === undefined");
}

test "a planned navigation keeps its removed submitter until its task names it as sourceElement" {
    try onFreshThread(submitterOutlivesItsRemoval);
}
