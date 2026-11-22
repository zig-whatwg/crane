//! A sequence an observer hands its callback is made in the callback's realm
//! (lane fw2, from Vue's Puppeteer e2e suite): WebIDL "invoke a callback
//! function" step 5 takes F's associated realm and step 10 converts the
//! arguments there, so the Array of entries or records is of the callback's
//! realm - and, in an isolated world, of the callback's world (Blink converts
//! a callback's arguments in the callback's ScriptState). Puppeteer's
//! ElementHandle.isIntersectingViewport runs `new IntersectionObserver(entries
//! => resolve(entries[0].intersectionRatio))` in its utility world before
//! every click: Crane built the Array in the observer's main realm, the world
//! boundary structured-cloned it - an array of platform objects cannot be -
//! and the callback was handed null.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const engine = @import("engine");
const runtime = @import("runtime");

const isolated_worlds = browser_mod.isolated_worlds;
const navigable: u64 = 1;

fn makeBrowser(allocator: std.mem.Allocator) !*browser_mod.Browser {
    return browser_mod.Browser.init(allocator, .{ .snapshot_path = "" });
}

const Reports = struct {
    count: usize = 0,
    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

fn evaluate(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    errdefer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try evaluate(realm, source);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, expected, got)) std.debug.print("{s}\n  -> {s}\n", .{ source, got });
    try testing.expectEqualStrings(expected, got);
}

/// Pump the Browser's loop until `condition` evaluates to "true" in `realm`.
fn pumpUntil(browser: *browser_mod.Browser, realm: runtime.Context, condition: []const u8, turns: usize) !void {
    var turn: usize = 0;
    while (turn < turns) : (turn += 1) {
        _ = try browser.runEventLoopBlocking(5);
        const value = try evaluate(realm, condition);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
    }
    std.debug.print("condition never held: {s}\n", .{condition});
    return error.ConditionNeverHeld;
}

fn loadPage(browser: *browser_mod.Browser, html: []const u8) !runtime.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(20);
    return (browser.current_context orelse return error.NoPage).realm orelse error.NoRealm;
}

/// What a callback records about its first argument: whether it is an Array
/// of the callback's own realm, whether its first element is `element_class`
/// of that realm (the world's wrapper, as Blink converts each element in the
/// callback's ScriptState), and `check`, an expression over that element `e`
/// (its target is the world's wrapper of the observed element). A callback
/// that throws records its error instead.
fn describeArgument(comptime element_class: []const u8, comptime check: []const u8) []const u8 {
    return "(list) => { try { const e = list[0]; seen = String(Array.isArray(list)) + ':' + String(list instanceof Array) + ':' + String(list.length > 0) + ':' + String(e instanceof " ++ element_class ++ ") + ':' + String(" ++ check ++ "); } catch (err) { seen = 'threw:' + err.message; } }";
}

/// The observed element's wrapper in the realm the check runs in.
const target_is_t = "e.target === document.getElementById('t')";

test "an IntersectionObserver made in an isolated world hands its callback the world's Array of entries" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body><div id=t>x</div></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__fw2_io__", false);
    try expect(world, "globalThis.seen = ''; globalThis.io = new IntersectionObserver(" ++ comptime describeArgument("IntersectionObserverEntry", target_is_t) ++ "); io.observe(document.getElementById('t')); 'ok'", "ok");
    try pumpUntil(browser, world, "seen !== ''", 400);
    try expect(world, "seen", "true:true:true:true:true");
    try expect(world, "io.disconnect(); 'ok'", "ok");
}

test "a MutationObserver made in an isolated world hands its callback the world's Array of records" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body><div id=t>x</div></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__fw2_mo__", false);
    try expect(world, "globalThis.seen = ''; globalThis.mo = new MutationObserver(" ++ comptime describeArgument("MutationRecord", target_is_t) ++ "); mo.observe(document.body, { childList: true, subtree: true }); 'ok'", "ok");
    // The page mutates; the world's observer sees the record in its world.
    try expect(page, "document.getElementById('t').append(document.createElement('span')); 'ok'", "ok");
    try pumpUntil(browser, world, "seen !== ''", 400);
    try expect(world, "seen", "true:true:true:true:true");
    try expect(world, "mo.disconnect(); 'ok'", "ok");
}

test "a ResizeObserver made in an isolated world hands its callback the world's Array of entries" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body><div id=t>x</div></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__fw2_ro__", false);
    try expect(world, "globalThis.seen = ''; globalThis.ro = new ResizeObserver(" ++ comptime describeArgument("ResizeObserverEntry", target_is_t) ++ "); ro.observe(document.getElementById('t')); 'ok'", "ok");
    try pumpUntil(browser, world, "seen !== ''", 400);
    try expect(world, "seen", "true:true:true:true:true");
    try expect(world, "ro.disconnect(); 'ok'", "ok");
}

test "a ReportingObserver made in an isolated world hands its callback the world's Array of reports" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadPage(browser, "<!doctype html><body></body>");
    const world = try isolated_worlds.createIsolatedWorld(page, navigable, "__fw2_rep__", false);
    try expect(world, "globalThis.seen = ''; globalThis.rep = new ReportingObserver(" ++ comptime describeArgument("Object", "Object.getPrototypeOf(e) === Object.prototype && e.type === 'csp-violation'") ++ ", { types: ['csp-violation'] }); rep.observe(); 'ok'", "ok");
    const global = dom.reporting.globalOf(page) orelse return error.NoGlobal;
    try dom.reporting.generate(global, "csp-violation", "absent-endpoint", "https://example.test/", "{\"effectiveDirective\":\"script-src\"}");
    try pumpUntil(browser, world, "seen !== ''", 400);
    try expect(world, "seen", "true:true:true:true:true");
    try expect(world, "rep.disconnect(); 'ok'", "ok");
}

// ---------------------------------------------------------------------------
// The page's observer, the frame's callback: the argument is the frame's
// (WebIDL invoke step 5 takes F's associated realm). A platform object in it
// stays its own realm's wrapper (one object, one wrapper per world).
// ---------------------------------------------------------------------------

/// A page with one same-origin frame, its realm, once the frame has a body.
fn loadFramedPage(browser: *browser_mod.Browser) !runtime.Context {
    const page = try loadPage(browser, "<!doctype html><body><div id=t>x</div><iframe srcdoc='<body>frame</body>'></iframe></body>");
    try pumpUntil(browser, page, "!!(frames[0] && frames[0].document && frames[0].document.body)", 400);
    return page;
}

test "a MutationObserver whose callback is the frame's hands it an Array of the frame's realm" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadFramedPage(browser);
    try expect(page,
        \\globalThis.seen = '';
        \\const callback = frames[0].Function('list', 'parent.seen = String(Object.getPrototypeOf(list) === Array.prototype) + ":" + String(list instanceof parent.Array) + ":" + String(list[0] instanceof parent.MutationRecord)');
        \\globalThis.mo = new MutationObserver(callback);
        \\mo.observe(document.body, { childList: true, subtree: true });
        \\document.getElementById('t').append(document.createElement('span'));
        \\'ok'
    , "ok");
    try pumpUntil(browser, page, "seen !== ''", 400);
    try expect(page, "seen", "true:false:true");
    try expect(page, "mo.disconnect(); 'ok'", "ok");
}

test "a ReportingObserver whose callback is the frame's hands it reports of the frame's realm" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadFramedPage(browser);
    try expect(page,
        \\globalThis.seen = '';
        \\const callback = frames[0].Function('list', 'parent.seen = String(Object.getPrototypeOf(list) === Array.prototype) + ":" + String(Object.getPrototypeOf(list[0]) === Object.prototype) + ":" + list[0].type');
        \\globalThis.rep = new ReportingObserver(callback, { types: ['csp-violation'] });
        \\rep.observe();
        \\'ok'
    , "ok");
    const global = dom.reporting.globalOf(page) orelse return error.NoGlobal;
    try dom.reporting.generate(global, "csp-violation", "absent-endpoint", "https://example.test/", "{\"effectiveDirective\":\"script-src\"}");
    try pumpUntil(browser, page, "seen !== ''", 400);
    try expect(page, "seen", "true:true:csp-violation");
    try expect(page, "rep.disconnect(); 'ok'", "ok");
}

test "a PerformanceObserver whose callback is the frame's hands it callback options of the frame's realm" {
    const browser = try makeBrowser(testing.allocator);
    defer browser.deinit();
    const page = try loadFramedPage(browser);
    try expect(page,
        \\globalThis.seen = '';
        \\const callback = frames[0].Function('list', 'observer', 'options', 'parent.seen = String(Object.getPrototypeOf(options) === Object.prototype) + ":" + String(list instanceof parent.PerformanceObserverEntryList) + ":" + list.getEntries().length');
        \\globalThis.po = new PerformanceObserver(callback);
        \\po.observe({ type: 'mark' });
        \\performance.mark('fw2');
        \\'ok'
    , "ok");
    try pumpUntil(browser, page, "seen !== ''", 400);
    try expect(page, "seen", "true:true:1");
    try expect(page, "po.disconnect(); 'ok'", "ok");
}
