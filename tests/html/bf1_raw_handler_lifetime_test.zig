//! The raw handler's compiled Global must be weakened with its document realm.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const result = try browser.evaluateScript(source);
    result.release();
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    for (0..3) |_| try engine.runInRealm(browser.getRealm().?, Collect.steps, browser.getAgent().?);
}

fn frameCycle(browser: *browser_mod.Browser) !void {
    try run(browser,
        \\(() => {
        \\  const frame = document.createElement('iframe');
        \\  document.body.append(frame);
        \\  const button = frame.contentDocument.createElement('button');
        \\  frame.contentDocument.body.append(button);
        \\  button.setAttribute('onclick', 'return window');
        \\  const callback = button.onclick;
        \\  weakHandlers.push(new WeakRef(callback));
        \\  frame.remove();
        \\})();
        \\0;
    );
    _ = try browser.runEventLoopBlocking(20);
    try collect(browser);
}

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try run(browser, "globalThis.weakHandlers = []");
    // Warm the utility contexts before comparing the live native realm count.
    try frameCycle(browser);
    const before = engine.heapStatistics(browser.getAgent().?).realm_count;
    for (0..6) |_| try frameCycle(browser);
    const after = engine.heapStatistics(browser.getAgent().?);
    try std.testing.expectEqual(before, after.realm_count);
    const result = try browser.evaluateScript("weakHandlers.every(ref => ref.deref() === undefined)");
    defer result.release();
    try std.testing.expect(engine.toBoolean(browser.getRealm().?, result.borrow()));
}

test "raw handlers closing over removed frames release their native realms" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = exercise();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}
