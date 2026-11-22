//! Lane maj5: HTML focus() step 3 - "If options["focusVisible"] is true, or
//! does not exist but in an implementation-defined way the user agent
//! determines it would be best to do so, then indicate focus" - and
//! :focus-visible matching where focus is indicated (Chrome, Firefox and
//! Safari: html/interaction/focus/processing-model/focusVisible.html).
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

fn focusVisible() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\document.body.innerHTML = '<button id=b>B</button><input id=i><div id=t tabindex=0>T</div><div id=n>N</div>';
        \\globalThis.$ = (id) => document.getElementById(id);
        \\0;
    );
    // The option decides, both ways, for controls that take text and not.
    try expectTrue(browser, "$('b').focus({ focusVisible: false }); document.activeElement === $('b') && !$('b').matches(':focus-visible')");
    try expectTrue(browser, "$('i').focus({ focusVisible: false }); $('i').matches(':focus') && !$('i').matches(':focus-visible')");
    try expectTrue(browser, "$('t').focus({ focusVisible: true }); $('t').matches(':focus-visible')");
    try expectTrue(browser, "$('b').focus({ focusVisible: true }); $('b').matches(':focus-visible')");
    // Not given: the heuristic again (a text control indicates focus).
    try expectTrue(browser, "$('i').focus({ focusVisible: false }); $('i').focus(); $('i').matches(':focus-visible')");
    try expectTrue(browser, "$('i').focus({}); $('i').matches(':focus-visible')");
    // An element that cannot be focused does not take the focus or match.
    try expectTrue(browser, "$('n').focus({ focusVisible: true }); document.activeElement !== $('n') && !$('n').matches(':focus-visible')");
}

test "focus()'s focusVisible decides :focus-visible for the element it focuses" {
    try onFreshThread(focusVisible);
}
