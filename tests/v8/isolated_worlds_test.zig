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
const ffi = @import("v8").ffi;

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
/// an HTML document as its Window's, shown by a top-level browsing context of
/// the scope - so the document is fully active, as a page's is. Without the
/// context the Window had a Document no navigable showed: not fully active,
/// so DOM "inner invoke" (steps 2.7-2.8, EventTarget.windowFullyActive)
/// skipped every listener - the page's own included - and each test that
/// dispatched an event checked nothing (lane tpf: 5 of these tests failed on
/// that alone).
const Page = struct {
    own_runtime: test_process.OwnRuntime,
    browser: *runtime.BrowserScope,
    agent: *engine.Agent,
    realm: runtime.Context,
    context: *dom.browser_state.BrowsingContext,
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
        // The top-level browsing context that shows them (HTML "create a new
        // top-level browsing context": its active window and document).
        const navigables = dom.browser_state.navigablesOf(realm) orelse return error.NoNavigables;
        const context = try dom.browser_state.BrowsingContext.initTopLevel(testing.allocator, navigables);
        errdefer context.releaseByOwner();
        context.setActiveDocument(document, window);
        try expect(realm, "document.appendChild(document.createElement('html')); document.documentElement.appendChild(document.createElement('body')); String(!!document.body)", "true");
        return .{ .own_runtime = own_runtime, .browser = browser, .agent = agent, .realm = realm, .context = context };
    }

    fn end(self: *Page) void {
        // The context goes first (no Window holds it): the realm's end then
        // finds no context naming its Window, as a closed page's.
        self.context.releaseByOwner();
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

/// `n` young-generation collections of `page`'s agent, finished.
fn scavenge(page: *Page, n: u32) !void {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(page.agent));
    const entered = ffi.v8_Isolate_GetCurrent() != isolate;
    if (entered) ffi.v8_Isolate_Enter(isolate);
    defer if (entered) ffi.v8_Isolate_Exit(isolate);
    const before = ffi.v8_Debug_MinorGCCount(isolate);
    ffi.v8_test_Isolate_MinorGC(isolate, n);
    try testing.expect(ffi.v8_Debug_MinorGCCount(isolate) >= before + n);
    while (ffi.v8_Platform_PumpMessageLoop(isolate)) {}
}

fn droppedWrappers(page: *Page) u64 {
    return ffi.v8_test_NodeWrappers_Dropped(@ptrCast(@alignCast(page.agent)));
}

// Refcount step 8 traces a node's listeners from the node, and the walk
// visits a node only while it is held. A node wrapped ONLY in an isolated
// world is held by that world's wrapper - a droppable traced reference in the
// world's wrapper cache, which a young-generation collection drops while the
// wrapper is unmodified and no script holds it. The node then has no hold,
// the walk passes it by, and the next full collection takes its listeners,
// though the world can still reach the node through its tree. So a node that
// keeps values keeps its wrapper through young collections in EVERY world
// (engine.keepNodeWrapperInYoungCollections; main's ruling of 2026-11-23
// 9:05 PM ET). The first trace-time build's private-property mark was drawn
// on the main world's wrapper only: it never covered this either.

test "a node only a world wrapped keeps its listener through a young collection while its tree lives" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    // The control: 200 elements the world made and let go of - a young
    // collection drops their wrappers.
    try expect(world, "(() => { for (let i = 0; i < 200; i++) document.body.appendChild(document.createElement('i')); })(); 'ok'", "ok");
    const control_before = droppedWrappers(&page);
    try scavenge(&page, 4);
    const control = droppedWrappers(&page) - control_before;
    // 200 elements the world made, each with a listener of the world's; the
    // world holds none of them, the page never saw them.
    try expect(world,
        \\globalThis.fired = 0;
        \\(() => { for (let i = 0; i < 200; i++) document.body.appendChild(document.createElement('b')).addEventListener('x', () => { fired++; }); })();
        \\'ok'
    , "ok");
    const before = droppedWrappers(&page);
    try scavenge(&page, 4);
    const dropped = droppedWrappers(&page) - before;
    std.debug.print("world wrappers young collections dropped: {d} of 200 plain elements, {d} of 200 with a listener\n", .{ control, dropped });
    try testing.expect(control >= 150);
    try testing.expect(dropped <= 8);
    // The document is the page's and lives: every listener still runs.
    engine.requestGarbageCollection(page.agent);
    engine.requestGarbageCollection(page.agent);
    try expect(world, "for (const b of document.body.querySelectorAll('b')) b.dispatchEvent(new Event('x')); String(fired)", "200");
}

test "a node that keeps values gets a world wrapper young collections keep, when a world wraps it later" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    // The page's listeners; then the world sees each node once and lets go.
    try expect(page.realm,
        \\globalThis.fired = 0;
        \\(() => { for (let i = 0; i < 200; i++) document.body.appendChild(document.createElement('b')).addEventListener('x', () => { fired++; }); })();
        \\'ok'
    , "ok");
    try scavenge(&page, 2);
    try expect(world, "(() => { let n = 0; for (const b of document.body.querySelectorAll('b')) n += b.nodeName.length; return String(n); })()", "200");
    const before = droppedWrappers(&page);
    try scavenge(&page, 4);
    const dropped = droppedWrappers(&page) - before;
    std.debug.print("world wrappers of 200 listener nodes, made after the listeners, that young collections dropped: {d}\n", .{dropped});
    try testing.expect(dropped <= 8);
    engine.requestGarbageCollection(page.agent);
    engine.requestGarbageCollection(page.agent);
    try expect(page.realm, "for (const b of document.body.querySelectorAll('b')) b.dispatchEvent(new Event('x')); String(fired)", "200");
}

test "a world wrapper script holds keeps its tree's main-world wrappers, and their expandos" {
    // Blink: an isolated world's wrapper reaches the C++ Node, whose Trace
    // reaches its tree and its main-world wrapper - so a detached subtree only
    // a world holds keeps the page's expandos on it. Crane: the world's node
    // wrapper is bound to a holder anchor whose trace walks from its node
    // (platform_anchor.bindInWorld, node_wrappers.traceHolder).
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(page.realm,
        \\const kept = document.createElement('div');
        \\kept.id = 'kept';
        \\const inner = document.createElement('span');
        \\inner.mainMark = 'main-expando';
        \\kept.appendChild(inner);
        \\kept.mainMark = 'main-root';
        \\document.body.appendChild(kept);
        \\'ok'
    , "ok");
    // The world takes the subtree; the page detaches it and keeps no
    // reference to any of it.
    try expect(world, "globalThis.held = document.getElementById('kept'); 'ok'", "ok");
    try expect(page.realm, "document.getElementById('kept').remove(); 'ok'", "ok");
    for (0..3) |_| engine.requestGarbageCollection(page.agent);
    // The world puts it back; the page finds its own wrappers, expandos and
    // all.
    try expect(world, "document.body.appendChild(held); delete globalThis.held; 'ok'", "ok");
    try expect(page.realm, "const k = document.getElementById('kept'); k.mainMark + ' ' + k.firstChild.mainMark", "main-root main-expando");
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

test "detachWindowRealm ends a main realm's worlds with its frame" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world, "document.body.worldExpando = 1; 'ok'", "ok");
    // The page never sees the world's expando while both live.
    try expect(page.realm, "String(document.body !== null) + ' ' + String(document.body.worldExpando)", "true undefined");
    engine.detachWindowRealm(page.realm);
    var out: [2]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 0), engine.worldRealmsOf(page.realm, &out));
    try testing.expectEqual(@as(?runtime.Context, null), engine.worldRealmFor(page.realm, 1));
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
    engine.detachWindowRealm(page.realm);
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

// ---------------------------------------------------------------------------
// Values across worlds (protocol_worlds.acrossWorlds; Blink's
// WorldSafeV8Reference::GetAcrossWorld and ScriptPromiseProperty): a value an
// impl keeps - a CustomEvent's detail - or a callback's argument never
// reaches one world's script as another world's object.
// ---------------------------------------------------------------------------

test "a value one world stored reaches another as its own: a clone, its wrapper, or null - never the other world's object" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world,
        \\globalThis.seen = [];
        \\document.body.addEventListener('detail', (event) => {
        \\  const d = event.detail;
        \\  if (d === null) { seen.push('null'); return; }
        \\  if (typeof d !== 'object') { seen.push(typeof d + ':' + String(d)); return; }
        \\  if (d instanceof Node) { seen.push('node:' + String(d === document.body) + ':' + String(d.pageExpando)); return; }
        \\  seen.push('object:' + String(Object.getPrototypeOf(d) === Object.prototype) + ':' + String(d.a) + ':' +
        \\    String(Array.isArray(d.list) && d.list instanceof Array) + ':' + String(typeof d.pageOnly));
        \\});
        \\'ok'
    , "ok");
    try expect(page.realm,
        \\document.body.pageExpando = 'page';
        \\const fire = (detail) => document.body.dispatchEvent(new CustomEvent('detail', { detail }));
        \\fire({ a: 1, list: [1, 2] });
        \\fire(document.body);
        \\fire(() => 1);
        \\fire({ f: () => 1 });
        \\fire(7);
        \\fire('text');
        \\'ok'
    , "ok");
    // A plain object: cloned into the world (the world's Object.prototype);
    // a node: the world's wrapper of it (no page expando); what cannot be
    // cloned: null, with nothing thrown; a primitive: itself.
    try expect(world, "seen.join(' ')", "object:true:1:true:undefined node:true:undefined null null number:7 string:text");
    // The page reads its own object, the same one.
    try expect(page.realm, "const d = { a: 2 }; const e = new CustomEvent('x', { detail: d }); String(e.detail === d)", "true");
    // And a world's object reaches the page's listener as the page's.
    try expect(page.realm,
        \\globalThis.pageSeen = [];
        \\document.body.addEventListener('from-world', (event) => {
        \\  pageSeen.push(String(Object.getPrototypeOf(event.detail) === Object.prototype) + ':' + String(event.detail.n));
        \\});
        \\'ok'
    , "ok");
    try expect(world, "document.body.dispatchEvent(new CustomEvent('from-world', { detail: { n: 3 } })); 'ok'", "ok");
    try expect(page.realm, "pageSeen.join(' ')", "true:3");
}

test "a promise of one world reaches another as that world's promise: one per world, settled with the value as the world sees it" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world,
        \\globalThis.results = [];
        \\document.body.addEventListener('promise', (event) => {
        \\  const p = event.detail;
        \\  results.push(String(p instanceof Promise) + ':' + String(p === event.detail));
        \\  p.then((value) => {
        \\    results.push('resolved:' + String(value === document.body) + ':' + String(value instanceof HTMLBodyElement));
        \\  });
        \\});
        \\'ok'
    , "ok");
    try expect(page.realm,
        \\globalThis.pagePromise = Promise.resolve(document.body);
        \\document.body.dispatchEvent(new CustomEvent('promise', { detail: pagePromise }));
        \\'ok'
    , "ok");
    try engine.performMicrotaskCheckpoint(page.agent);
    try engine.performMicrotaskCheckpoint(page.agent);
    try expect(world, "results.join(' ')", "true:true resolved:true:true");
    // The page's promise is still its own.
    try expect(page.realm, "const e = new CustomEvent('x', { detail: pagePromise }); String(e.detail === pagePromise)", "true");
}

test "a callback of one world is handed another world's held value as its own" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    var reports: Reports = .{};
    const reporter: engine.Reporter = .{ .report = Reports.report, .host = &reports };
    const function = try engine.evaluateClassicScript(world, .{ .utf8 = "(arg) => { globalThis.argSeen = String(Object.getPrototypeOf(arg) === Object.prototype) + ':' + String(arg.v); }" }, "", null, reporter);
    const callback: engine.CallbackFunction = .{ .function = function, .context = world };
    defer callback.release();
    const argument = try engine.evaluateClassicScript(page.realm, .{ .utf8 = "({ v: 5 })" }, "", null, reporter);
    defer argument.release();
    const completion = try engine.invokeCallbackFunction(page.realm, &callback, .undefined, &.{argument.value}, .rethrow);
    switch (completion) {
        .normal => |value| value.release(),
        .throw => |thrown| {
            thrown.release();
            return error.CallbackThrew;
        },
    }
    try testing.expectEqual(@as(usize, 0), reports.count);
    try expect(world, "argSeen", "true:5");
}

// The world ends the way a browser ends one: with its main realm, here by
// the realm's detach (a navigation or its navigable's removal,
// engine.detachWindowRealm). Blink disposes every world's context of a frame
// together (WindowProxyManager::ClearForNavigation, ClearForClose) and has no
// operation that ends one world while its page lives on, so this test
// asserts nothing on such a path - it used engine.destroyWorldRealms on a
// live page, a host-only path ("No invented paths"; main's ruling of
// 2026-11-23 12:37 PM ET, lane rc8). The world's listener is a once
// listener: under refcount step 8 a listener on a page node is traced from
// the node, as Blink traces it from its EventTarget, and would keep its
// world's context while the page's node lives - which the page's promise,
// held here, keeps. What this test is for is the mirror: the world's promise
// for the page's promise, and its reaction on it, keep nothing of the world.
test "a world's promise for a page promise keeps nothing of the world after it ends: the page's promise lives on, the world's context is collected" {
    var page = try Page.make();
    defer page.end();
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(page.agent));
    for (0..3) |_| engine.requestGarbageCollection(page.agent);
    var contexts_before: usize = 0;
    ffi.v8_Isolate_GetContextCounts(isolate, &contexts_before, null);

    const world = try page.world(1);
    // The page keeps a pending promise; the world reads it twice - one
    // promise of the world's for it, kept on it, and a reaction waiting on it.
    try expect(page.realm, "globalThis.pending = new Promise((resolve) => { globalThis.settle = resolve; }); 'ok'", "ok");
    try expect(world, "globalThis.mirrors = []; document.body.addEventListener('p', (e) => { mirrors.push(e.detail, e.detail); }, { once: true }); 'ok'", "ok");
    try expect(page.realm, "document.body.dispatchEvent(new CustomEvent('p', { detail: pending })); 'ok'", "ok");
    try expect(world, "String(mirrors.length === 2 && mirrors[0] === mirrors[1] && mirrors[0] instanceof Promise)", "true");

    // The page's promise is held - as anything a browser keeps of a page
    // after it goes might hold it - while the page's realm is detached: its
    // world realms end with it, the world's kept promise is taken off the
    // page's, and its reaction holds nothing of the world.
    var reports: Reports = .{};
    const pending = try engine.evaluateClassicScript(page.realm, .{ .utf8 = "pending" }, "", null, .{ .report = Reports.report, .host = &reports });
    defer pending.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
    engine.detachWindowRealm(page.realm);
    var worlds: [2]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 0), engine.worldRealmsOf(page.realm, &worlds));
    for (0..4) |_| engine.requestGarbageCollection(page.agent);
    // The page's context lives on with its promise; the world's is collected.
    var contexts_after: usize = 0;
    ffi.v8_Isolate_GetContextCounts(isolate, &contexts_after, null);
    try testing.expectEqual(contexts_before, contexts_after);
}

// ---------------------------------------------------------------------------
// Event handler attributes per world (Blink's EventTarget::
// GetAttributeRegisteredEventListener / BelongsToTheCurrentWorld).
// ---------------------------------------------------------------------------

test "event handler attributes are per world: a world's onclick never replaces the page's, and each reads and clears its own" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(page.realm, "globalThis.log = []; globalThis.pageHandler = () => log.push('page'); document.body.onclick = pageHandler; 'ok'", "ok");
    // The world has none of its own yet: the page's is not the world's.
    try expect(world, "globalThis.log = []; globalThis.worldHandler = () => log.push('world'); String(document.body.onclick)", "null");
    try expect(world, "document.body.onclick = worldHandler; String(document.body.onclick === worldHandler)", "true");
    try expect(page.realm, "String(document.body.onclick === pageHandler)", "true");
    // Both run on a dispatch, each in its own world.
    try expect(page.realm, "document.body.dispatchEvent(new Event('click')); log.join(' ')", "page");
    try expect(world, "log.join(' ')", "world");
    // The world clears its own; the page's stays and runs alone.
    try expect(world, "document.body.onclick = null; String(document.body.onclick)", "null");
    try expect(page.realm, "log.length = 0; document.body.dispatchEvent(new Event('click')); String(document.body.onclick === pageHandler) + ' ' + log.join(' ')", "true page");
    try expect(world, "log.join(' ')", "world");
    // The page clears its own; the world's, set again, runs alone.
    try expect(page.realm, "document.body.onclick = null; 'ok'", "ok");
    try expect(world, "document.body.onclick = worldHandler; 'ok'", "ok");
    try expect(page.realm, "log.length = 0; document.body.dispatchEvent(new Event('click')); String(document.body.onclick) + ':' + log.join(' ')", "null:");
    try expect(world, "log.join(' ')", "world world");
    // A Window's too: the world's onmessage is not the page's.
    try expect(page.realm, "globalThis.pageOnMessage = () => {}; window.onmessage = pageOnMessage; 'ok'", "ok");
    try expect(world, "window.onmessage = () => {}; 'ok'", "ok");
    try expect(page.realm, "String(window.onmessage === pageOnMessage)", "true");
}

test "a world's event handler is isolated from the page and tears down with its main realm's detach" {
    var page = try Page.make();
    defer page.end();
    const world = try page.world(1);
    try expect(world, "document.body.onclick = () => {}; 'ok'", "ok");
    try expect(page.realm, "String(document.body.onclick)", "null");
    try expect(page.realm, "globalThis.pageHandler = () => {}; document.body.onclick = pageHandler; String(document.body.onclick === pageHandler)", "true");
    engine.detachWindowRealm(page.realm);
    var out: [2]runtime.Context = undefined;
    try testing.expectEqual(@as(usize, 0), engine.worldRealmsOf(page.realm, &out));
}
