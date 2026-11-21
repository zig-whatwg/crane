//! Lane maj6: small DOM conformance fixes, each pinned by script in a page.
//! - DOM 4.2.10.2: an HTMLCollection is named by an element's `name`
//!   attribute only when the element is in the HTML namespace - namedItem,
//!   `in`, hasOwnProperty and Object.getOwnPropertyNames alike
//!   (dom/nodes/Element-children.html, Element-/Document-getElementsByTagName
//!   .html, dom/collections/HTMLCollection-supported-property-names.html;
//!   Chrome 157, Firefox 160 and Safari 27.2 pass).
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
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://maj6.test/page.html" });
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
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

fn collectionNames() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\const c = document.createElement('div');
        \\c.innerHTML = '<img id=foo><img name=bar>';
        \\const id = document.createElementNS('', 'img'); id.setAttribute('id', 'baz'); c.append(id);
        \\const named = document.createElementNS('', 'img'); named.setAttribute('name', 'qux'); c.append(named);
        \\const svg = document.createElementNS('http://www.w3.org/2000/svg', 'g'); svg.setAttribute('name', 'quux'); c.append(svg);
        \\document.body.append(c);
        \\globalThis.list = c.children;
        \\0;
    );
    try expectTrue(browser, "JSON.stringify(Object.getOwnPropertyNames(list)) === '[\"0\",\"1\",\"2\",\"3\",\"4\",\"foo\",\"bar\",\"baz\"]'");
    try expectTrue(browser, "!('qux' in list) && !list.hasOwnProperty('qux') && list.qux === undefined && list.namedItem('qux') === null");
    try expectTrue(browser, "!('quux' in list) && list.namedItem('quux') === null");
    // An id names it in any namespace; a name in the HTML namespace.
    try expectTrue(browser, "list.baz === list[2] && list.namedItem('baz') === list[2] && list.bar === list[1]");
    try expectTrue(browser, "document.getElementsByTagName('img').namedItem('qux') === null");
}

test "an HTMLCollection is named by the name attribute of HTML elements only" {
    try onFreshThread(collectionNames);
}
