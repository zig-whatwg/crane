//! Lane refcount9 (row 130 review F2, feature-queue "REFCOUNT: TaskHold.take
//! marks kept=true"): a TaskHold records the pending-activity keep it took
//! only when it got one.
//!
//! `engine.keepPlatformObjectAlive` cannot report failure: on a member with no
//! wrapper it records the keep in its realm's side table, and out of memory it
//! records nothing (docs/lessons/architecture-a-counted-keep-the-engine-may-
//! not-record-must-not-be-released.md). TaskHold.take wraps an unwrapped node
//! first (the shadow-mode net) - and when that wrap fails too, it kept
//! `kept = true` anyway, so its release ended a keep nobody took: the
//! counted API's unmatched release (an error log, fatal here), or, with
//! another owner's keep on the same wrapper, THAT owner's keep. Row 130's
//! selectedcontent queue reaches it from an option's removal.
//!
//! The test fails every allocation of the Browser's from the take on (a
//! FailingAllocator over c_allocator: an out-of-memory path elsewhere may
//! leak, which is not this test's), then lets memory back and releases.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const h = @import("refcount_holders_helpers.zig");

fn instanceOf(node: *dom.NodeBase) !*runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return error.NotANode));
}

/// A page whose body holds one element no script has wrapped.
fn open(allocator: std.mem.Allocator) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try page.runScript("globalThis.body = document.body; body.innerHTML = '<p></p>'; 0;");
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

fn unwrappedChild(browser: *browser_mod.Browser) !*runtime.Instance {
    const held = try browser.evaluateScript("body");
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const body_instance = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
    const body = dom.instance_bridge.getNodeBase(@ptrCast(body_instance)) orelse return error.NotANode;
    const p = try instanceOf(body.first_child orelse return error.NoChild);
    if (engine.hasWrapper(p)) return error.AlreadyWrapped;
    return p;
}

fn aFailedTakeRecordsNoKeep() !void {
    var failing = std.testing.FailingAllocator.init(std.heap.c_allocator, .{});
    const browser = try open(failing.allocator());
    defer browser.deinit();
    const p = try unwrappedChild(browser);
    var hold: dom.node_holds.TaskHold = .{};
    // Every allocation fails from here: the wrap TaskHold.take makes, and the
    // side table's record of a keep on an unwrapped member.
    failing.fail_index = failing.alloc_index;
    hold.take(p);
    failing.fail_index = std.math.maxInt(usize);
    // It holds its member either way; it says it kept one only if it did.
    try testing.expect(hold.isHeld());
    try testing.expectEqual(engine.hasWrapper(p), hold.kept);
    // And its release ends no keep it did not take (an unmatched release is
    // an error log in Debug: this test's failure).
    hold.release();
    try testing.expect(!hold.isHeld());
}

test "a TaskHold whose member's wrapper could not be made takes no keep and releases none" {
    try h.onFreshThread(aFailedTakeRecordsNoKeep);
}

fn aTakeWithMemoryKeepsOnItsWrapper() !void {
    const browser = try open(std.heap.c_allocator);
    defer browser.deinit();
    const p = try unwrappedChild(browser);
    var hold: dom.node_holds.TaskHold = .{};
    hold.take(p);
    // The control: the take made the wrapper and kept it.
    try testing.expect(engine.hasWrapper(p));
    try testing.expect(hold.kept);
    hold.release();
}

test "control: a TaskHold on an unwrapped node wraps it and keeps the wrapper" {
    try h.onFreshThread(aTakeWithMemoryKeepsOnItsWrapper);
}
