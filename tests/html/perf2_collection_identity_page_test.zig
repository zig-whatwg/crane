//! Lane perf2: in a page, getElementsByClassName, getElementsByTagName(NS)
//! and getElementsByName answer the same object for the same root and
//! argument while it lives - expandos included, as in Chrome, Firefox and
//! Safari (Blink/WebKit NodeListsNodeData, Gecko nsContentList's hashtables)
//! - and a working one of their own once it was collected, never another
//! object at a reissued address. A [SameObject] collection that HTML defines
//! with its own filter (datalist.options, map.areas) is its own object, as
//! it is in all three browsers.
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

fn open(html: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(html, .{ .base_url = "about:blank" });
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

const page_html =
    \\<!doctype html><body><section id=s><span class=tag>a</span><span class=tag>b</span></section>
    \\<input name=q><datalist id=d><option>x</option></datalist><map id=m><area></map></body>
;

fn sameObjects() !void {
    const browser = try open(page_html);
    defer browser.deinit();
    try expectTrue(browser, "document.getElementsByClassName('tag') === document.getElementsByClassName('tag')");
    try expectTrue(browser, "s.getElementsByClassName('tag') === s.getElementsByClassName('tag') && s.getElementsByClassName('tag') !== document.getElementsByClassName('tag')");
    try expectTrue(browser, "document.getElementsByTagName('span') === document.getElementsByTagName('span') && document.getElementsByTagName('span') !== document.getElementsByTagName('SPAN')");
    try expectTrue(browser, "document.getElementsByTagNameNS(null, 'x') === document.getElementsByTagNameNS('', 'x')");
    try expectTrue(browser, "document.getElementsByName('q') === document.getElementsByName('q') && document.getElementsByName('q').length === 1");
    // Expandos stay with the object while it lives.
    try expectTrue(browser, "(document.getElementsByClassName('tag').mark = 7, document.getElementsByClassName('tag').mark === 7)");
    // Still live through the shared object.
    try expectTrue(browser, "(s.appendChild(document.createElement('span')).className = 'tag', document.getElementsByClassName('tag').length === 3)");
    try expectTrue(browser, "(s.textContent = '', document.getElementsByClassName('tag').length === 0 && document.getElementsByClassName('tag')[0] === undefined)");
}

test "the getElementsBy* methods answer one object per root and argument while it lives" {
    try onFreshThread(sameObjects);
}

fn ownSameObjectCollections() !void {
    const browser = try open(page_html);
    defer browser.deinit();
    try expectTrue(browser, "d.options !== d.getElementsByTagNameNS('http://www.w3.org/1999/xhtml', 'option') && d.options === d.options && d.options.length === 1");
    try expectTrue(browser, "m.areas !== m.getElementsByTagNameNS('http://www.w3.org/1999/xhtml', 'area') && m.areas.length === 1");
    // In the other order too.
    try expectTrue(browser, "(() => { const d2 = document.createElement('datalist'); const byNs = d2.getElementsByTagNameNS('http://www.w3.org/1999/xhtml', 'option'); return d2.options !== byNs; })()");
}

test "datalist.options and map.areas are their own objects, not getElementsByTagNameNS's" {
    try onFreshThread(ownSameObjectCollections);
}

fn collectedCollections() !void {
    const browser = try open(page_html);
    defer browser.deinit();
    try run(browser,
        \\document.getElementsByClassName('tag').mark = 1;
        \\document.getElementsByTagName('span').mark = 1;
        \\document.getElementsByName('q').mark = 1;
        \\0
    );
    // Nothing keeps them: the collector takes them, and other collections
    // take their slots.
    try collect(browser);
    try run(browser,
        \\globalThis.others = [];
        \\for (let i = 0; i < 200; i++) {
        \\  const e = document.createElement('div');
        \\  others.push(e.getElementsByClassName('other' + i), e.getElementsByTagName('b'), document.getElementsByName('n' + i));
        \\}
        \\0
    );
    // Each answer is a working collection for its own root and argument.
    try expectTrue(browser, "document.getElementsByClassName('tag') instanceof HTMLCollection && document.getElementsByClassName('tag').length === 2 && document.getElementsByClassName('tag')[1].textContent === 'b'");
    try expectTrue(browser, "document.getElementsByTagName('span').length === 2 && document.getElementsByTagName('span') === document.getElementsByTagName('span')");
    try expectTrue(browser, "document.getElementsByName('q') instanceof NodeList && document.getElementsByName('q').length === 1");
    try expectTrue(browser, "others[0].length === 0 && others[0] === others[0]");
}

test "a collected collection is answered by a working one of its own, never another at its address" {
    try onFreshThread(collectedCollections);
}
