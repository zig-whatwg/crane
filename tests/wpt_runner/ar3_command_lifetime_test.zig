//! The computed testdriver commands own their pending arguments, independently
//! of HTML's intentionally weak ARIA associations. Exercise the real timers.
const std = @import("std");
const browser_mod = @import("browser");
const driver_mod = @import("test_driver.zig");
const testing = std.testing;
const Finish = enum { resolve, reject, cancel, destroy };

fn exercise(comptime finish: Finish) !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    var driver: ?*driver_mod.TestDriver = try driver_mod.TestDriver.create(testing.allocator);
    defer if (driver) |d| d.destroy();
    driver.?.defineNatives(browser.getRealm() orelse return error.NoRealm);
    try page.runScript(
        \\globalThis.argument = document.createElement('div');
        \\argument.setAttribute('aria-label', 'Own detached name');
        \\globalThis.weak = new WeakRef(argument);
        \\globalThis.result = 'pending';
    );
    // Leave the job that constructed WeakRef before testing the native hold.
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\__crane_test_driver_get_computed_label(argument).then(
        \\  value => { result = value; },
        \\  error => { result = 'rejected:' + error; });
        \\argument = null;
        \\TestUtils.gc();
        \\if (weak.deref() === undefined) throw new Error('pending command lost argument');
    );
    try testing.expectEqual(@as(usize, 1), driver.?.commands.items.len);
    switch (finish) {
        .resolve => {
            _ = try browser.runEventLoopBlocking(20);
            try page.runScript("if (result !== 'Own detached name') throw new Error('wrong computed name: ' + result);");
        },
        .reject => {
            // Fail the computation's arena allocation after the real command
            // has taken its argument, so reject must release that same hold.
            var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
            driver.?.allocator = failing.allocator();
            defer driver.?.allocator = testing.allocator;
            _ = try browser.runEventLoopBlocking(20);
            try testing.expect(failing.has_induced_failure);
            try page.runScript("if (!result.startsWith('rejected:')) throw new Error('command did not reject: ' + result);");
        },
        .cancel => {
            driver.?.endTest();
            _ = try browser.runEventLoopBlocking(20);
            try page.runScript("if (result !== 'pending') throw new Error('cancelled command fired');");
        },
        .destroy => {
            driver.?.destroy();
            driver = null;
            _ = try browser.runEventLoopBlocking(20);
            try page.runScript("if (result !== 'pending') throw new Error('destroyed driver fired');");
        },
    }
    if (driver) |d| try testing.expectEqual(@as(usize, 0), d.commands.items.len);
    // Each exit must release the argument exactly once: collection proves
    // there is no surviving root, and the allocator/engine catch over-release.
    try page.runScript(
        \\TestUtils.gc();
        \\if (weak.deref() !== undefined) throw new Error('completed command retained argument');
    );
}

fn onFreshThread(comptime finish: Finish) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            exercise(finish) catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "computed command releases its argument after normal resolution" {
    try onFreshThread(.resolve);
}

test "computed command releases its argument after rejection" {
    try onFreshThread(.reject);
}

test "endTest cancels the timer and releases its pending argument" {
    try onFreshThread(.cancel);
}

test "driver teardown releases a pending argument before its timer fires" {
    try onFreshThread(.destroy);
}

// ----------------------------------------------------------------------------
// Lane flaky5: no permission override outlives its test
// ----------------------------------------------------------------------------

/// One Browser serves every file of a runner process, and its automation
/// overrides lived in it: permissions/event-model.https.html ends with
/// geolocation "granted", so a later permissions/permissions-cg.https.html in
/// the same process changed nothing with its own set_permission("granted"),
/// heard no change event, and timed out (generation 210's sweep, shard 5
/// spawn 26). wptrunner's Chrome executor resets the overrides before every
/// test (ChromeDriverTestharnessProtocolPart.reset_browser_state: CDP
/// Browser.resetPermissions); the runner's per-file step calls
/// TestDriver.resetPermissions, its counterpart, beside the cookie jar's
/// clear.
fn permissionOverrideEndsWithItsTest() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    // A real origin: its statuses and overrides have a permission key.
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/permissions/event-model.https.html" });
    const driver = try driver_mod.TestDriver.create(testing.allocator);
    defer driver.destroy();
    driver.defineNatives(browser.getRealm() orelse return error.NoRealm);
    // What event-model.https.html's last test leaves behind.
    try page.runScript(
        \\globalThis.result = 'pending';
        \\__crane_test_driver_set_permission({ descriptor: { name: 'geolocation' }, state: 'granted' })
        \\  .then(() => navigator.permissions.query({ name: 'geolocation' }))
        \\  .then(status => { result = status.state; }, error => { result = 'rejected:' + error; });
    );
    try runUntilSettled(browser);
    try page.runScript("if (result !== 'granted') throw new Error('set_permission did not grant: ' + result);");

    // The next file's start: the runner's per-file step.
    driver.endTest();
    driver_mod.TestDriver.resetPermissions(browser.scope);

    try page.runScript(
        \\result = 'pending';
        \\navigator.permissions.query({ name: 'geolocation' })
        \\  .then(status => { result = status.state; }, error => { result = 'rejected:' + error; });
    );
    try runUntilSettled(browser);
    try page.runScript("if (result !== 'prompt') throw new Error('the previous test\\'s override survived: ' + result);");
}

/// The event loop, until the page's `result` is no longer "pending".
fn runUntilSettled(browser: *browser_mod.Browser) !void {
    const page = browser.current_context orelse return error.NoPage;
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        _ = try browser.runEventLoopBlocking(20);
        const value = try page.evaluateScriptToString("String(globalThis.result)", testing.allocator);
        defer testing.allocator.free(value);
        if (!std.mem.eql(u8, value, "pending")) return;
    }
    return error.NeverSettled;
}

test "no permission override outlives its test: the per-file reset drops them" {
    const Run = struct {
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            permissionOverrideEndsWithItsTest() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}
