//! Lane maj5: MessagePort has no `onclose` and fires no `close` event -
//! whatwg/html#13016 (2026-10) removed them, "no browser ships the close
//! events", and Chrome, Firefox and Safari pass
//! webmessaging/message-channels/historical.any.js.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

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
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://maj5.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        const page = browser.current_context orelse return error.NoPage;
        const log = try page.evaluateScriptToString("JSON.stringify(globalThis.log || null)", testing.allocator);
        defer testing.allocator.free(log);
        std.debug.print("expected true: {s}\nlog: {s}\n", .{ source, log });
        return error.TestExpectedTrue;
    }
}

/// Run the event loop until `condition` holds, or about a second has passed.
fn waitFor(browser: *browser_mod.Browser, condition: []const u8) !void {
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        const held = try browser.evaluateScript(condition);
        defer held.release();
        if (engine.toBoolean(browser.getRealm().?, held.borrow())) return;
        _ = try browser.runEventLoopBlocking(20);
    }
    try expectTrue(browser, condition);
}

fn noCloseEvent() !void {
    const browser = try open();
    defer browser.deinit();
    try expectTrue(browser, "!('onclose' in MessagePort.prototype) && !('onclose' in new MessageChannel().port1)");
    try run(browser,
        \\globalThis.log = [];
        \\const c = new MessageChannel();
        \\c.port1.addEventListener('close', () => log.push('close on port1'));
        \\c.port2.addEventListener('close', () => log.push('close on port2'));
        \\c.port1.start(); c.port2.start();
        \\c.port2.close();
        \\globalThis.done = false;
        \\setTimeout(() => setTimeout(() => { done = true; }, 0), 0);
        \\0;
    );
    try waitFor(browser, "done");
    try expectTrue(browser, "log.length === 0");
}

test "MessagePort has no onclose and fires no close event" {
    try onFreshThread(noCloseEvent);
}
