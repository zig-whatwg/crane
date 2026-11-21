//! Lane maj5: small script-visible causes Chrome, Firefox and Safari agree on
//! (wpt.fyi 2358bd4835):
//! - Console Standard §1: console's [[Prototype]] is an empty object whose
//!   [[Prototype]] is %Object.prototype% (console/console-is-a-namespace.any.js).
//! - URL 6.2: URLSearchParams' constructor removes ONE leading "?";
//!   has(name, value) and delete(name, value) match the value whenever one is
//!   given, the empty string included (url/urlsearchparams-{constructor,has}.any.js).
//! - HTML 9.4.3: initMessageEvent's ports (sequence<MessagePort>) - a new
//!   frozen array, null a TypeError (html/webappapis/scripting/events/
//!   messageevent-constructor.https.html).
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
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
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

fn consolePrototype() !void {
    const browser = try open();
    defer browser.deinit();
    try expectTrue(browser, "Object.getOwnPropertyNames(Object.getPrototypeOf(console)).length === 0");
    try expectTrue(browser, "Object.getPrototypeOf(Object.getPrototypeOf(console)) === Object.prototype");
    try expectTrue(browser, "Object.getPrototypeOf(console) !== Object.prototype && typeof console.log === 'function'");
}

test "console's prototype is an empty object" {
    try onFreshThread(consolePrototype);
}

fn searchParams() !void {
    const browser = try open();
    defer browser.deinit();
    try expectTrue(browser, "new URLSearchParams('??a=b').toString() === '%3Fa=b'");
    try expectTrue(browser, "new URLSearchParams('?').toString() === '' && new URLSearchParams('??').toString() === '%3F='");
    try expectTrue(browser, "new URLSearchParams('?a=b').toString() === 'a=b'");
    try run(browser, "globalThis.params = new URLSearchParams('a=b&a=d&c&e&'); 0;");
    try expectTrue(browser, "params.has('a', 'b') && !params.has('a', 'c') && params.has('e', '') && params.has('a', undefined)");
    try expectTrue(browser, "params.append('first', null); !params.has('first', '') && params.has('first', 'null')");
    try expectTrue(browser, "params.delete('first', ''); params.has('first')");
    try expectTrue(browser, "params.delete('e', ''); !params.has('e')");
}

test "URLSearchParams: one leading ? is removed; a given value is matched, even an empty one" {
    try onFreshThread(searchParams);
}

fn messageEventPorts() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.channel = new MessageChannel();
        \\globalThis.ev = document.createEvent('messageevent');
        \\ev.initMessageEvent('test', true, false, 'testData', 'testOrigin', 'testId', window, [channel.port1]);
        \\0;
    );
    try expectTrue(browser, "ev.ports.length === 1 && ev.ports[0] === channel.port1 && Object.isFrozen(ev.ports)");
    try expectTrue(browser, "const old = ev.ports; ev.initMessageEvent('test', false, false, null, '', '', null, ev.ports); old !== ev.ports && ev.ports.length === 1");
    try expectTrue(browser, "ev.initMessageEvent('test'); ev.ports.length === 0 && ev.data === null && ev.source === null");
    try expectTrue(browser, "try { ev.initMessageEvent('test', true, false, 'd', 'o', 'i', window, null); false } catch (e) { e instanceof TypeError }");
    try expectTrue(browser, "try { ev.initMessageEvent('test', true, false, 'd', 'o', 'i', window, [{}]); false } catch (e) { e instanceof TypeError }");
}

test "initMessageEvent sets ports from a sequence of MessagePort" {
    try onFreshThread(messageEventPorts);
}
