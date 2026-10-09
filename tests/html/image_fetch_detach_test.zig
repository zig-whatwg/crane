//! DW-N2 (tmp/analysis/fix-list.md): an image's fetch must leave its
//! element's state when it ends, whatever became of the element's slot.
//! ImageFetch.detach cleared the element's active_fetch only while the
//! element's slot generation still matched, so a teardown that freed the
//! slot without running the element's own deinit left the state pointing at
//! the fetch `gone` had just destroyed - and the state's later deinit (the
//! registry's next birth at that address, or the exit sweep) terminated and
//! destroyed it a second time. The state is keyed by address and a reissued
//! slot holds its own active_fetch, so detach clears by identity.
//!
//! The case drops the element's slot first, by hand, as such a teardown
//! would, then lets the fetch layer notice its client is gone. A document
//! abort (window.stop()) then cancels the fetches the image states keep -
//! the stale state's included - which is where the second destroy was.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const fetch = @import("fetch");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
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

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    return browser;
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

fn droppedSlotThenGone() !void {
    const browser = try open();
    defer browser.deinit();
    const element = blk: {
        const held = try browser.evaluateScript(
            \\globalThis.image = new Image();
            \\image.src = 'http://127.0.0.1:65533/never-delivered';
            \\image
        );
        defer held.release();
        const realm = browser.getRealm() orelse return error.NoRealm;
        break :blk engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
    };
    // The load started in its microtask and its fetch is in flight.
    try expectTrue(browser, "image.complete === false");

    // A teardown that frees the slot without the element's own deinit.
    runtime.SlabAllocator.get().free(element);
    // The fetch layer finds its client gone: terminates the fetch, and
    // `gone` destroys it.
    try testing.expect(fetch.algorithms.async_fetch.sweep());
    // Script must not reach the freed element again.
    const forget = try browser.evaluateScript("delete globalThis.image; 0");
    forget.release();
    // The document abort walks every image state with a load in flight and
    // cancels its fetch: the stale state's must already be gone.
    const stop = try browser.evaluateScript("window.stop(); 0");
    stop.release();
}

test "an image fetch whose element's slot was dropped first is not destroyed twice" {
    try onFreshThread(droppedSlotThenGone);
}
