//! Lane closewatch1: a queued element task keeps the nodes it will hand to
//! script (node_holds.TaskHold, ElementTask) - refcount design 2.4's
//! GCReachableRef, WebKit's Node::queueTaskKeepingNodeAlive - until it runs,
//! is cancelled or is dropped, and every hold it took is released exactly
//! once on each of those ends and at the Browser's end.
//!
//! The popover toggle event task (HTML 6.12 "queue a popover toggle event
//! task") is the task under test: a removed popover's toggle still fires,
//! the element is alive until it does and collectable after, and a coalesced
//! pair fires one event (popover-events.html, "The toggle event is
//! coalesced"). Run under std.testing.allocator, each Browser on a thread of
//! its own (AGENTS.md: a test directory is one executable).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><div id=held popover></div></body>", .{ .base_url = "http://example.test/holds" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    page.runScript(source) catch |err| {
        std.debug.print("script failed: {s}\n", .{source});
        return err;
    };
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const value = try browser.evaluateScript(source);
    defer value.release();
    if (!engine.toBoolean(browser.getRealm().?, value.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

/// Two full collections from native code, outside any script job.
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

fn books(browser: *browser_mod.Browser) !*dom.node_holds.ElementTasks {
    const realm = browser.getRealm() orelse return error.NoRealm;
    return dom.node_holds.ElementTasks.existingOf(realm) orelse error.NoElementTasks;
}

fn removedPopoverIsKeptUntilItsToggleRuns() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.toggles = [];
        \\globalThis.weak = (() => {
        \\  const element = document.getElementById('held');
        \\  element.addEventListener('toggle', event => toggles.push(event.oldState + '>' + event.newState));
        \\  return new WeakRef(element);
        \\})();
        \\0;
    );
    // Leave the job that made the WeakRef while the tree still owns it.
    _ = try browser.runEventLoopBlocking(1);
    // Show it (queues the toggle task), then take it out of the tree; no
    // script reference survives this job.
    try run(browser,
        \\(() => {
        \\  const element = document.getElementById('held');
        \\  element.showPopover();
        \\  element.remove();
        \\})();
        \\0;
    );
    // The task is still queued: only its hold keeps the element.
    try collect(browser);
    try expectTrue(browser, "toggles.length === 0 && weak.deref() !== undefined");
    _ = try browser.runEventLoopBlocking(20);
    try expectTrue(browser, "toggles.join() === 'closed>open'");
    // The task ended, and with it the hold: a new task boundary also ends
    // deref's own root for the job.
    _ = try browser.runEventLoopBlocking(1);
    try collect(browser);
    try expectTrue(browser, "weak.deref() === undefined");
    const tasks = try books(browser);
    try testing.expectEqual(tasks.holds_taken, tasks.holds_released);
    try testing.expectEqual(tasks.queued, tasks.ended);
}

test "a removed popover's queued toggle task keeps the element until it runs, then lets it go" {
    try onFreshThread(removedPopoverIsKeptUntilItsToggleRuns);
}

fn queuedToggleDroppedAtBrowsersEnd() !void {
    const browser = try open();
    // Queue the task and end the Browser before its loop runs it: the
    // loop's end drops it, and its drop releases every hold. A record or a
    // hold left over is a testing-allocator leak or an error log
    // (ElementTasks.deinit), either of which fails the test.
    run(browser, "document.getElementById('held').showPopover()") catch |err| {
        browser.deinit();
        return err;
    };
    const tasks = books(browser) catch |err| {
        browser.deinit();
        return err;
    };
    const taken = tasks.holds_taken;
    const queued = tasks.queued;
    const released = tasks.holds_released;
    browser.deinit();
    try testing.expectEqual(@as(u64, 1), taken);
    try testing.expectEqual(@as(u64, 1), queued);
    try testing.expectEqual(@as(u64, 0), released);
}

test "a queued toggle task dropped at the Browser's end releases its holds" {
    try onFreshThread(queuedToggleDroppedAtBrowsersEnd);
}

fn coalescedTogglesReleaseEveryHold() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.toggles = [];
        \\globalThis.popover = document.getElementById('held');
        \\popover.addEventListener('toggle', event => toggles.push(event.oldState + '>' + event.newState));
        \\popover.showPopover();
        \\popover.hidePopover(); // cancels the queued "show" task, takes its old state
    );
    const tasks = try books(browser);
    // Two tasks queued; the first was cancelled, which released its hold.
    try testing.expectEqual(@as(u64, 2), tasks.queued);
    try testing.expectEqual(@as(u64, 2), tasks.holds_taken);
    try testing.expectEqual(@as(u64, 1), tasks.holds_released);
    _ = try browser.runEventLoopBlocking(20);
    try expectTrue(browser, "toggles.join() === 'closed>closed'");
    try testing.expectEqual(tasks.holds_taken, tasks.holds_released);
    try testing.expectEqual(@as(u64, 2), tasks.ended);
    // A show, run; then hide and show again before the task runs.
    try run(browser, "toggles.length = 0; popover.showPopover();");
    _ = try browser.runEventLoopBlocking(20);
    try run(browser, "popover.hidePopover(); popover.showPopover();");
    _ = try browser.runEventLoopBlocking(20);
    try expectTrue(browser, "toggles.join() === 'closed>open,open>open'");
    try testing.expectEqual(tasks.holds_taken, tasks.holds_released);
    try testing.expectEqual(tasks.queued, tasks.ended);
}

test "coalesced popover toggle tasks fire one event and release every hold" {
    try onFreshThread(coalescedTogglesReleaseEveryHold);
}

fn toggleOfARemovedFrameIsDropped() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.frame = document.createElement('iframe');
        \\document.body.appendChild(frame);
        \\frame.contentDocument.body.innerHTML = '<div id=inner popover></div>';
        \\globalThis.innerToggles = 0;
        \\frame.contentDocument.getElementById('inner').addEventListener('toggle', () => ++innerToggles);
    );
    _ = try browser.runEventLoopBlocking(20);
    // The task's document goes with the frame before the task can run: the
    // loop drops it, and the drop releases what it holds.
    try run(browser, "frame.contentDocument.getElementById('inner').showPopover(); frame.remove();");
    _ = try browser.runEventLoopBlocking(20);
    try expectTrue(browser, "innerToggles === 0");
    const tasks = try books(browser);
    try testing.expectEqual(@as(u64, 1), tasks.queued);
    try testing.expectEqual(@as(u64, 1), tasks.ended);
    try testing.expectEqual(tasks.holds_taken, tasks.holds_released);
}

test "a toggle task whose document went with its frame is dropped and releases its holds" {
    try onFreshThread(toggleOfARemovedFrameIsDropped);
}
