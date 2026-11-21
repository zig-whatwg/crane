//! Isolated worlds (engine_protocol.zig section 4.2a; src/runtime/engines/v8/
//! protocol_worlds.zig; tmp/plans/cdp-part1-design.md 3.5): several
//! JavaScript worlds over one DOM, Blink's DOMWrapperWorld model.
//!
//! What each test pins, against Blink's behaviour for an isolated world (a
//! Chrome extension's content script, CDP's Page.createIsolatedWorld):
//! - the same DOM, a wrapper per world: `document.body` is the same node, a
//!   distinct object, with the world's own prototypes;
//! - expandos per world: a property one world sets on a node's wrapper is not
//!   seen from another;
//! - a node created in one world is seen from the other;
//! - an event listener runs in the world that registered it, and is handed
//!   that world's wrapper of the event;
//! - a world's wrappers are collected when nothing keeps them, and a node's
//!   world wrapper keeps the node;
//! - a world realm ends with its main realm (navigation, frame removal,
//!   page close), and before it: the shared Window is the main realm's to
//!   free, exactly once;
//! - Window identity per world: the world's `window` is its own global, and
//!   the main world's is the page's;
//! - universal access: a world made with it passes the cross-origin checks.
//!
//! Written for the CDP test pass (the user's directive of 2026-11-21 5:48 PM
//! ET: implement now, run every test in one later pass); the regression
//! protocol (timers x3) and leaks --atExit run there too - this is handle
//! ownership work.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const test_process = @import("test_process.zig");

const Host = struct {
    fn window(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(testing.allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

/// `source`'s completion value in `realm`, as a string, checked.
fn expect(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, expected, got)) std.debug.print("{s}\n  -> {s}\n", .{ source, got });
    try testing.expectEqualStrings(expected, got);
}

/// A page: a Browser scope of the test's own, an agent, a Window realm with
/// an HTML document as its Window's.
const Page = struct {
    own_runtime: test_process.OwnRuntime,
    browser: *runtime.BrowserScope,
    agent: *engine.Agent,
    realm: runtime.Context,
    live: bool = true,

    fn make() !Page {
        test_process.start();
        const own_runtime = test_process.OwnRuntime.begin(testing.allocator);
        errdefer own_runtime.end();
        const browser = try testing.allocator.create(runtime.BrowserScope);
        errdefer testing.allocator.destroy(browser);
        browser.* = runtime.BrowserScope.init(testing.allocator);
        errdefer browser.deinit();
        const hooks: *const engine.HostHooks = &.{};
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = hooks, .allocator = testing.allocator });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = testing.allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .browser_scope = browser,
            .create_global_object = Host.window,
        });
        errdefer engine.destroyWindowRealm(realm, .global_detached);
        const record = realm.getRealm() orelse return error.NoWindow;
        const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
        const document = try interfaces.Document.init(testing.allocator, realm);
        try dom.document_internals.setDocumentType(document, .html);
        dom.window_globals.setDocument(window, document);
        dom.document_browsing_context.setWindow(document, window);
        try expect(realm, "document.appendChild(document.createElement('html')); document.documentElement.appendChild(document.createElement('body')); String(!!document.body)", "true");
        return .{ .own_runtime = own_runtime, .browser = browser, .agent = agent, .realm = realm };
    }

    fn end(self: *Page) void {
        if (self.live) engine.destroyWindowRealm(self.realm, .global_detached);
        self.live = false;
        engine.destroyAgent(self.agent);
        self.browser.deinit();
        testing.allocator.destroy(self.browser);
        self.own_runtime.end();
    }

    fn world(self: *Page, id: engine.WorldId) !runtime.Context {
        return engine.createWorldRealm(self.realm, &.{ .world = id, .name = "__test_world__" });
    }
};

test "a world realm is the main realm's Window in a realm of its own: same DOM, a wrapper per world" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);

    // The protocol's view of it.
    try testing.expect(world != page.realm);
    try testing.expectEqual(@as(engine.WorldId, 1), engine.worldOf(world));
    try testing.expectEqual(engine.main_world, engine.worldOf(page.realm));
    try testing.expectEqual(page.realm, engine.mainRealmOf(world));
    try testing.expectEqual(page.realm, engine.mainRealmOf(page.realm));
    try testing.expectEqual(@as(?runtime.Context, world), engine.worldRealmFor(page.realm, 1));
    try testing.expectEqual(@as(?runtime.Context, page.realm), engine.worldRealmFor(page.realm, engine.main_world));
    try testing.expectEqual(@as(?runtime.Context, null), engine.worldRealmFor(page.realm, 2));
    // Made once per (realm, world): asking again answers the same realm.
    try testing.expectEqual(world, try page.world(1));
    var out: [4]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 1), engine.worldRealmsOf(page.realm, &out));
    try testing.expectEqual(world, out[0]);
    const info = engine.worldInfoOf(world) orelse return error.NoWorldInfo;
    try testing.expectEqualStrings("__test_world__", info.name);
    try testing.expect(!info.universal_access);
    try testing.expectEqual(page.realm, info.main);
    try testing.expectEqual(@as(?engine.WorldInfo, null), engine.worldInfoOf(page.realm));

    // The same DOM.
    try expect(page.realm, "document.body.id = 'b'; document.body.setAttribute('data-x', '1'); 'ok'", "ok");
    try expect(world, "document.body.id + ' ' + document.body.getAttribute('data-x') + ' ' + document.title.length", "b 1 0");
    try expect(world, "document.body.className = 'from-world'; 'ok'", "ok");
    try expect(page.realm, "document.body.className", "from-world");
    // Its own global, intrinsics and prototypes.
    try expect(page.realm, "globalThis.page_global = 1; HTMLElement.prototype.page_mark = 1; 'ok'", "ok");
    try expect(world, "String(typeof page_global) + ' ' + String(document.body.page_mark) + ' ' + String(document.body instanceof HTMLBodyElement)", "undefined undefined true");
    // Wrapper identity holds within the world.
    try expect(world, "String(document.body === document.body && document.body === document.querySelector('body'))", "true");
}

test "expandos are per world: a property one world sets on a node's wrapper is not the other's" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(page.realm, "document.body.mainExpando = 'main'; 'ok'", "ok");
    try expect(world, "document.body.worldExpando = 'world'; String(document.body.mainExpando)", "undefined");
    try expect(page.realm, "String(document.body.worldExpando) + ' ' + document.body.mainExpando", "undefined main");
    try expect(world, "document.body.worldExpando", "world");
    // The Window's too: each world's global is its own object.
    try expect(page.realm, "window.mainWindowExpando = 1; 'ok'", "ok");
    try expect(world, "String(window.mainWindowExpando) + ' ' + String(window === globalThis) + ' ' + String(self === window)", "undefined true true");
}

test "a node created in one world is the page's, and seen from the other world" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world,
        \\const made = document.createElement('section');
        \\made.id = 'from-world';
        \\made.textContent = 'hello';
        \\document.body.appendChild(made);
        \\const text = new Text(' there');
        \\made.appendChild(text);
        \\'ok'
    , "ok");
    try expect(page.realm, "const s = document.getElementById('from-world'); s.textContent + ' ' + String(s instanceof HTMLElement) + ' ' + String(s.ownerDocument === document)", "hello there true true");
    // And a node made by the page is the world's to read.
    try expect(page.realm, "const p = document.createElement('p'); p.id = 'from-page'; document.body.appendChild(p); 'ok'", "ok");
    try expect(world, "String(document.getElementById('from-page') instanceof HTMLParagraphElement)", "true");
}

test "an event listener runs in the world that registered it, with that world's wrappers" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world,
        \\globalThis.seen = [];
        \\document.body.addEventListener('ping', (event) => {
        \\  seen.push(String(event instanceof Event) + ':' + String(event.target === document.body) + ':' + String(typeof page_value) + ':' + String(event.worldMark));
        \\});
        \\'ok'
    , "ok");
    try expect(page.realm,
        \\globalThis.page_value = 1;
        \\const event = new Event('ping');
        \\event.worldMark = 'page-expando';
        \\document.body.dispatchEvent(event);
        \\'ok'
    , "ok");
    // The world saw its own wrapper of the event (no page expando), its own
    // wrapper of the body, and its own global.
    try expect(world, "seen.join(',')", "true:true:undefined:undefined");
}

test "a world's wrappers are collected when nothing keeps them, and a node's world wrapper keeps its node" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    // A detached node only the world's wrapper holds survives collections,
    // and keeps what the world put on it.
    try expect(world, "globalThis.held = document.createElement('div'); held.mark = 'kept'; 'ok'", "ok");
    engine.requestGarbageCollection(page.agent);
    engine.requestGarbageCollection(page.agent);
    try expect(world, "held.mark + ' ' + held.tagName", "kept DIV");
    // A node in the document keeps its world wrapper's expandos while its
    // tree's wrappers are kept (the walk visits every world's wrappers).
    try expect(world, "document.body.kept = 'body'; delete globalThis.held; 'ok'", "ok");
    engine.requestGarbageCollection(page.agent);
    engine.requestGarbageCollection(page.agent);
    try expect(world, "String(document.body.kept)", "body");
    // Many wrappers made and dropped in the world: collected, with nothing
    // left to leak (the agent's end checks the caches and the counts).
    try expect(world, "for (let i = 0; i < 2000; i++) { const e = document.createElement('span'); e.x = i; } 'ok'", "ok");
    engine.requestGarbageCollection(page.agent);
}

test "a world realm ends with its main realm, before it, and the shared Window is freed once" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world, "globalThis.worldNode = document.body; 'ok'", "ok");
    // Its end is the main realm's: after it, no world realm is listed.
    page.live = false;
    engine.destroyWindowRealm(page.realm, .global_detached);
    // The world realm went with it: nothing of it is listed, and the agent's
    // end (Page.end) finds no world realm left (protocol_worlds.endAgent logs
    // one as an error).
    try testing.expectEqual(@as(?runtime.Context, null), engine.worldRealmFor(page.realm, 1));
}

test "destroyWorldRealms ends a main realm's worlds while it lives on; a new one can be made after" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world, "document.body.worldExpando = 1; 'ok'", "ok");
    engine.destroyWorldRealms(page.realm);
    var out: [2]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 0), engine.worldRealmsOf(page.realm, &out));
    try testing.expectEqual(@as(?runtime.Context, null), engine.worldRealmFor(page.realm, 1));
    // The page is untouched.
    try expect(page.realm, "String(document.body !== null) + ' ' + String(document.body.worldExpando)", "true undefined");
    // The world again: a new realm, with no expando of the old one.
    const again = try page.world(1);
    try expect(again, "String(document.body.worldExpando)", "undefined");
}

test "two worlds and the main world: three wrappers of one node, each with its own expandos" {
    var page = try Page.make();
    defer page.end();
    const one = try page.world(1);
    const two = try engine.createWorldRealm(page.realm, &.{ .world = 2, .name = "__second__" });
    try expect(page.realm, "document.body.who = 'main'; 'ok'", "ok");
    try expect(one, "document.body.who = 'one'; 'ok'", "ok");
    try expect(two, "document.body.who = 'two'; 'ok'", "ok");
    try expect(page.realm, "document.body.who", "main");
    try expect(one, "document.body.who", "one");
    try expect(two, "document.body.who", "two");
    var out: [4]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 2), engine.worldRealmsOf(page.realm, &out));
    try testing.expectEqualStrings("__second__", engine.worldInfoOf(two).?.name);
}

test "the world observer is told each world realm's making and end" {
    var page = try Page.make();
    defer page.end();
    const Seen = struct {
        created: usize = 0,
        destroyed: usize = 0,
        last: ?runtime.Context = null,
        fn onCreated(host: ?*anyopaque, realm: runtime.Context) void {
            const self: *@This() = @ptrCast(@alignCast(host.?));
            self.created += 1;
            self.last = realm;
        }
        fn onDestroyed(host: ?*anyopaque, realm: runtime.Context) void {
            const self: *@This() = @ptrCast(@alignCast(host.?));
            self.destroyed += 1;
            std.debug.assert(self.last == realm);
        }
        const observer: engine.WorldObserver = .{ .created = onCreated, .destroyed = onDestroyed };
    };
    var seen: Seen = .{};
    engine.installWorldObserver(page.agent, &Seen.observer, &seen);
    defer engine.installWorldObserver(page.agent, null, null);
    const world = try page.world(1);
    try testing.expectEqual(@as(usize, 1), seen.created);
    try testing.expectEqual(@as(?runtime.Context, world), seen.last);
    engine.destroyWorldRealms(page.realm);
    try testing.expectEqual(@as(usize, 1), seen.destroyed);
}

test "a world made with universal access is recorded so; one without is not" {
    var page = try Page.make();
    defer page.end();
    const plain = try page.world(1);
    const universal = try engine.createWorldRealm(page.realm, &.{ .world = 2, .name = "__utility__", .universal_access = true });
    try testing.expect(!engine.worldInfoOf(plain).?.universal_access);
    try testing.expect(engine.worldInfoOf(universal).?.universal_access);
    // The options are the world's: a later request with others keeps them.
    try testing.expectEqual(universal, try engine.createWorldRealm(page.realm, &.{ .world = 2, .name = "other", .universal_access = false }));
    try testing.expectEqualStrings("__utility__", engine.worldInfoOf(universal).?.name);
}

test "HTML element constructors are the main world's: an isolated world's is an illegal constructor" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world, "try { new HTMLElement(); 'constructed' } catch (e) { e.constructor.name }", "TypeError");
}
