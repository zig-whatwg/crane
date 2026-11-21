//! Lane maj6: a same-origin WindowProxy's array-index properties and the
//! natively bound Window operations' receivers.
//! - HTML 7.2.3.5 [[GetOwnProperty]]: a child navigable's index is
//!   { writable: false, enumerable: true, configurable: true }.
//! - HTML 7.2.3.7 [[DefineOwnProperty]]: false for every array index, child
//!   or not (Object.defineProperty throws, Reflect.defineProperty answers
//!   false), and so [[Set]] does nothing, and throws in strict code.
//!   (html/browsers/the-window-object/window-indexed-properties{,-strict}.html;
//!   Chrome 157, Firefox 160 and Safari 27.2 pass these cases.)
//! - WebIDL 3.7.6 step 2.1: a Window operation called on something that is
//!   no Window throws a TypeError - the timers and animation frame callbacks,
//!   bound natively, took any receiver
//!   (webidl/ecmascript-binding/global-object-implicit-this-value*.html).
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
    try page.loadHTML("<!doctype html><body><iframe></iframe></body>", .{ .base_url = "https://maj6.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
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

fn throwsTypeError(comptime body: []const u8) []const u8 {
    return "(() => { try { " ++ body ++ "; return false; } catch (e) { return e instanceof TypeError; } })()";
}

fn indexedProperties() !void {
    const browser = try open();
    defer browser.deinit();
    try expectTrue(browser, "window.length === 1 && window[0] === document.querySelector('iframe').contentWindow");
    // [[GetOwnProperty]]: enumerable, configurable, not writable.
    try expectTrue(browser, "(() => { const d = Object.getOwnPropertyDescriptor(window, '0'); return d.enumerable && d.configurable && !d.writable; })()");
    // [[DefineOwnProperty]]: false at an index with a child and without.
    try expectTrue(browser, throwsTypeError("Object.defineProperty(window, 0, { value: 'bar' })"));
    try expectTrue(browser, throwsTypeError("Object.defineProperty(window, 1, { value: 'bar' })"));
    try expectTrue(browser, throwsTypeError("Object.defineProperty(window, 1, { get() { return 1; } })"));
    try expectTrue(browser, "Reflect.defineProperty(window, 1, { value: 3 }) === false");
    // [[Set]]: nothing, silently in sloppy code...
    try expectTrue(browser, "window[1] = 'foo'; window[1] === undefined && Object.getOwnPropertyDescriptor(window, 1) === undefined");
    // ...and a TypeError in strict code.
    try expectTrue(browser, throwsTypeError("(() => { 'use strict'; window[1] = 'foo'; })()"));
    try expectTrue(browser, throwsTypeError("(() => { 'use strict'; window[0] = 'foo'; })()"));
    try expectTrue(browser, "window[0] === document.querySelector('iframe').contentWindow && window[1] === undefined");
    // Not an array index: an ordinary property, as before.
    try expectTrue(browser, "window[4294967295] = 1; window[4294967295] === 1 && delete window[4294967295]");
}

fn operationReceivers() !void {
    const browser = try open();
    defer browser.deinit();
    try expectTrue(browser, throwsTypeError("Object.create(globalThis).setInterval(() => {}, 100)"));
    try expectTrue(browser, throwsTypeError("Object.create(globalThis).setTimeout(() => {}, 100)"));
    try expectTrue(browser, throwsTypeError("clearTimeout.call({}, 0)"));
    try expectTrue(browser, throwsTypeError("clearInterval.call(Object.create(Window.prototype), 0)"));
    try expectTrue(browser, throwsTypeError("requestAnimationFrame.call({}, () => {})"));
    try expectTrue(browser, throwsTypeError("cancelAnimationFrame.call({}, 0)"));
    // The Window itself, given or left out, and another realm's WindowProxy.
    try expectTrue(browser, "typeof (0, setInterval)(() => {}, 100) === 'number'");
    try expectTrue(browser, "typeof setTimeout.call(undefined, () => {}, 0) === 'number'");
    try expectTrue(browser, "typeof window.setTimeout(() => {}, 0) === 'number'");
    try expectTrue(browser, "clearTimeout.call(window[0], 0) === undefined");
    try expectTrue(browser, "typeof window[0].setTimeout(() => {}, 0) === 'number'");
    // The timer is the receiver's: in the frame's map when the frame is
    // `this`, whichever realm's function made it.
    const held = try browser.evaluateScript(
        \\globalThis.out = {};
        \\const frame = window[0];
        \\const a = window.setTimeout.call(frame, () => { out.a = true; }, 0);
        \\frame.clearTimeout(a);
        \\const b = window.setTimeout.call(frame, () => { out.b = true; }, 0);
        \\clearTimeout(b);
        \\0;
    );
    held.release();
    _ = try browser.runEventLoopBlocking(50);
    try expectTrue(browser, "out.a === undefined && out.b === true");
}

test "a same-origin WindowProxy refuses to define or set an array-index property" {
    try onFreshThread(indexedProperties);
}

test "a natively bound Window operation throws on a receiver that is no Window" {
    try onFreshThread(operationReceivers);
}
