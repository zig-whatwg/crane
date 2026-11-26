//! Lane sab1: transferring a platform object (ImageBitmap, OffscreenCanvas)
//! in `postMessage(null, ..., [transferable])` where the deserialized payload
//! does not reference the transferred object must not leave an unwrapped
//! Instance / State block alive until Browser teardown.
//!
//! `dom.transferables.Received.deinit()` releases every received object that
//! stayed unwrapped after `structuredDeserializeWithOptions` and event
//! construction finished (checked against the generation captured at
//! `receiveAll` time so GC-recycled slots are never touched).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn runUntil(browser: *browser_mod.Browser, page: *browser_mod.Context, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const value = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn unreferencedTransferredObjectsDoNotLeakBody() !void {
    var leaked: usize = 0;
    {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
        defer browser.deinit();
        browser.scope.heap_leak_count_out = &leaked;

        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><canvas id=c width=4 height=4></canvas>", .{ .base_url = "https://a.test/" });
        try runUntil(browser, page, "document.readyState === 'complete'");

        try page.runScript(
            \\globalThis.doneCount = 0;
            \\globalThis.err = null;
            \\self.onmessage = () => { globalThis.doneCount += 1; };
            \\(async () => {
            \\  try {
            \\    const bm = await self.createImageBitmap(document.getElementById('c'));
            \\    self.postMessage(null, '*', [bm]);
            \\    const oc = new OffscreenCanvas(4, 4);
            \\    self.postMessage(null, '*', [oc]);
            \\    const mc = new MessageChannel();
            \\    mc.port2.onmessage = () => { globalThis.doneCount += 1; mc.port2.close(); mc.port1.close(); };
            \\    const oc2 = new OffscreenCanvas(2, 2);
            \\    mc.port1.postMessage(null, [oc2]);
            \\  } catch (e) {
            \\    globalThis.err = String(e);
            \\  }
            \\})();
        );
        try runUntil(browser, page, "globalThis.err !== null || globalThis.doneCount === 3");
        const err_str = try page.evaluateScriptToString("String(globalThis.err)", testing.allocator);
        defer testing.allocator.free(err_str);
        try testing.expectEqualStrings("null", err_str);
    }
    try testing.expectEqual(@as(usize, 0), leaked);
}

test "unreferenced transferred ImageBitmap and OffscreenCanvas leave zero heap leaks at Browser end" {
    try onFreshThread(unreferencedTransferredObjectsDoNotLeakBody);
}
