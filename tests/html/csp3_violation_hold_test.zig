//! A violation task's element hold is observable independently of event targeting.
const std = @import("std");
const browser_mod = @import("browser");
const engine = @import("engine");

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const value = try browser.evaluateScript(source);
    value.release();
}

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

fn exercise() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><meta http-equiv='Content-Security-Policy' content=\"style-src 'none'\"><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(20);
    try run(browser,
        \\globalThis.dispatched = false;
        \\document.addEventListener('securitypolicyviolation', event => {
        \\  if (event.effectiveDirective === 'style-src-attr') {
        \\    globalThis.dispatched = true;
        \\    globalThis.documentTarget = event.target === document;
        \\  }
        \\});
        \\globalThis.weak = (() => {
        \\  const element = document.createElement('div');
        \\  element.id = 'csp3-held';
        \\  document.body.appendChild(element);
        \\  return new WeakRef(element);
        \\})();
        \\0;
    );
    // Finish the WeakRef-construction job while the element is still in the
    // tree. In particular, do not deref in the job that tests collection.
    _ = try browser.runEventLoopBlocking(1);
    try run(browser,
        \\(() => {
        \\  const element = document.getElementById('csp3-held');
        \\  element.setAttribute('style', 'color: red');
        \\  element.remove();
        \\})();
        \\0;
    );
    // Native control deliberately leaves the violation task pending.
    try collect(browser);
    try expectTrue(browser, "!dispatched && weak.deref() !== undefined");
    _ = try browser.runEventLoopBlocking(20);
    try expectTrue(browser, "dispatched && documentTarget");
    // A new task boundary also releases deref's own KeepDuringJob root.
    _ = try browser.runEventLoopBlocking(1);
    try collect(browser);
    try expectTrue(browser, "weak.deref() === undefined");
}

test "CSP violation task holds its detached element until dispatch then releases it" {
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
