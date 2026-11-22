//! Lane maj5: Window's `self` and `frames` are [Replaceable] attributes -
//! own ACCESSORS of the global (WebIDL 3.7.6 [Global]), a getter that answers
//! the global this value and a setter that defines an own data property in
//! the accessor's place (WebIDL 3.7.6 [Replaceable]). Chrome, Firefox and
//! Safari: html/browsers/the-window-object/window-properties.https.html,
//! webidl/ecmascript-binding/global-object-implicit-this-value.any.js.
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

fn accessors() !void {
    const browser = try open();
    defer browser.deinit();
    for ([_][]const u8{ "self", "frames" }) |name| {
        var buffer: [512]u8 = undefined;
        const check = try std.fmt.bufPrint(&buffer,
            \\(() => {{
            \\  const d = Object.getOwnPropertyDescriptor(window, '{0s}');
            \\  return typeof d.get === 'function' && typeof d.set === 'function' && d.enumerable && d.configurable &&
            \\    !('{0s}' in Window.prototype) && window.{0s} === window && d.get.call(window) === window &&
            \\    d.get.call(null) === window && Reflect.get(window, '{0s}') === window;
            \\}})()
        , .{name});
        try expectTrue(browser, check);
    }
    try expectTrue(browser, "self === globalThis && frames === globalThis");
    // An object that is not the global is no Window: a TypeError.
    try expectTrue(browser, "try { Object.create(globalThis).self; false } catch (e) { e instanceof TypeError }");
    // [Replaceable]: assignment replaces the accessor with a data property.
    try expectTrue(browser, "self = 5; const d = Object.getOwnPropertyDescriptor(window, 'self'); d.value === 5 && d.writable && d.enumerable && d.configurable && frames === window");
}

test "self and frames are [Replaceable] accessors answering the global" {
    try onFreshThread(accessors);
}
