//! Lane rc9: traced value holds, unwrapped-owner survival, CustomElementRegistry
//! definition tracing, and isolated-world PermissionStatus survival.
//!
//! Red side (cycles that pinned owners until realm end before rc9):
//! - NodeIterator / TreeWalker filter closure capturing the traverser
//! - MessageEvent data/ports/source referencing the event
//! - PopStateEvent state referencing the event
//! - PromiseRejectionEvent reason referencing the event
//! - ImageData data array expando referencing the ImageData
//! - XSLTProcessor parameter referencing the processor
//! - CustomElementRegistry scoped registry whose definition's constructor or
//!   lifecycle callback closes over the registry
//! - ExtendableMessageEvent, FetchEvent, WindowClient cycles
//!
//! Green side (nothing reachable loses its held values):
//! - Unwrapped Zig-made MessageEvent (no wrapper yet) survives full collections
//!   between creation and dispatch, and listeners read its data intact; once
//!   wrapped and dropped, cycles still collect.
//! - Unwrapped Zig-made PromiseRejectionEvent survives full collections before
//!   dispatch.
//! - NodeIterator / TreeWalker filter survives full collections while the
//!   traverser is held.
//! - CustomElementRegistry constructor + lifecycle callbacks survive full
//!   collections while the registry (global or scoped) is reachable.
//! - ImageData data & XSLTProcessor parameters survive full collections while
//!   their owner is held.
//! - Part B.2 end-to-end: a PermissionStatus obtained and listened to ONLY in
//!   an isolated world survives full collections and runs its change listener
//!   when permission state changes.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const permissions = @import("permissions");
const probe = @import("refcount_probe.zig");
const Page = probe.Page;

const slack: usize = 64;
const rounds: usize = 200;

const NoReport = struct {
    fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("unexpected script error: {s}\n", .{info.message});
    }
    const reporter: engine.Reporter = .{ .report = report, .host = null };
};

/// Run `body` (`rounds` iterations building self-referential cycles), settle,
/// and assert that live slab instances did not grow past `slack`.
fn expectCyclesCollected(comptime body: []const u8, comptime label: []const u8) !void {
    const page = try Page.open("");
    defer page.close();
    try page.run(body);
    try page.settle();
    const grown = page.grown();
    if (grown > slack) {
        std.debug.print("rc9 cycle retained ({s}): {d} live instances above baseline (slack {d})\n", .{ label, grown, slack });
        return error.CycleRetained;
    }
}

// ============================================================================
// Red side: self-referential cycles collect cleanly
// ============================================================================

fn nodeIteratorFilterCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const root = document.createElement('div');
        \\  root.appendChild(document.createElement('span'));
        \\  let iter = null;
        \\  iter = document.createNodeIterator(root, NodeFilter.SHOW_ALL, () => {
        \\    void iter;
        \\    return NodeFilter.FILTER_ACCEPT;
        \\  });
        \\}
    , "NodeIterator filter cycle");
}

test "NodeIterator filter closure capturing its own iterator collects" {
    try probe.onFreshThread(nodeIteratorFilterCycle);
}

fn treeWalkerFilterCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const root = document.createElement('div');
        \\  root.appendChild(document.createElement('span'));
        \\  let walker = null;
        \\  walker = document.createTreeWalker(root, NodeFilter.SHOW_ALL, {
        \\    acceptNode() {
        \\      void walker;
        \\      return NodeFilter.FILTER_ACCEPT;
        \\    }
        \\  });
        \\}
    , "TreeWalker filter cycle");
}

test "TreeWalker filter object referencing its own walker collects" {
    try probe.onFreshThread(treeWalkerFilterCycle);
}

fn messageEventCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const payload = {};
        \\  const ch = new MessageChannel();
        \\  const ev = new MessageEvent('m', { data: payload, ports: [ch.port1], source: ch.port2 });
        \\  payload.ev = ev;
        \\  ch.port1.ev = ev;
        \\  ch.port2.ev = ev;
        \\  ev.ports.owner = ev;
        \\  ch.port1.close();
        \\  ch.port2.close();
        \\}
    , "MessageEvent data/ports/source cycle");
}

test "MessageEvent with self-referential data, ports and source collects" {
    try probe.onFreshThread(messageEventCycle);
}

fn popStateEventCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const state = {};
        \\  const ev = new PopStateEvent('popstate', { state });
        \\  state.ev = ev;
        \\}
    , "PopStateEvent state cycle");
}

test "PopStateEvent with state referencing the event collects" {
    try probe.onFreshThread(popStateEventCycle);
}

fn promiseRejectionEventCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const p = Promise.resolve();
        \\  const reason = {};
        \\  const ev = new PromiseRejectionEvent('unhandledrejection', { promise: p, reason });
        \\  reason.ev = ev;
        \\  p.ev = ev;
        \\}
    , "PromiseRejectionEvent promise/reason cycle");
}

test "PromiseRejectionEvent with promise and reason referencing the event collects" {
    try probe.onFreshThread(promiseRejectionEventCycle);
}

fn imageDataCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const img = new ImageData(2, 2);
        \\  img.data.owner = img;
        \\}
    , "ImageData data cycle");
}

test "ImageData with data expando referencing the ImageData collects" {
    try probe.onFreshThread(imageDataCycle);
}

fn xsltProcessorCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const proc = new XSLTProcessor();
        \\  proc.setParameter('', 'self', proc);
        \\}
    , "XSLTProcessor parameter cycle");
}

test "XSLTProcessor with parameter referencing the processor collects" {
    try probe.onFreshThread(xsltProcessorCycle);
}

fn customElementRegistryCycle() !void {
    try expectCyclesCollected(
        \\for (let i = 0; i < 200; i++) {
        \\  const reg = new CustomElementRegistry();
        \\  class X extends HTMLElement {
        \\    constructor() { super(); void reg; }
        \\    connectedCallback() { void reg; }
        \\    disconnectedCallback() { void reg; }
        \\    adoptedCallback() { void reg; }
        \\    connectedMoveCallback() { void reg; }
        \\    attributeChangedCallback() { void reg; }
        \\    static get observedAttributes() { return ['a']; }
        \\  }
        \\  reg.define('x-rc9-cycle', X);
        \\}
    , "scoped CustomElementRegistry definition cycle");
}

test "scoped CustomElementRegistry whose definition closes over the registry collects" {
    try probe.onFreshThread(customElementRegistryCycle);
}

fn serviceWorkerEventsAndClientCycle() !void {
    const page = try Page.open("");
    defer page.close();
    const ctx = page.browser.current_context orelse return error.NoPage;
    const realm = ctx.realm orelse return error.NoRealm;

    // ExtendableMessageEvent cycle via Zig construction + JS wrap.
    for (0..rounds) |_| {
        const obj = try engine.evaluateClassicScript(realm, .{ .utf8 = "({ tag: 'ext' })" }, "", null, NoReport.reporter);
        defer obj.release();
        const ev = try interfaces.ExtendableMessageEvent.call_constructor(
            realm,
            runtime.DOMString.initInterned("message"),
            .{ .was_passed = true, .value = .{ .base = .{ .base = .{} }, .data = obj.value } },
        );
        const held = try engine.retainValue(realm, .{ .instance = ev });
        defer held.release();
        try engine.setProperty(realm, obj.value, "ev", held.value);
    }

    // FetchEvent cycle via Zig construction + JS wrap.
    for (0..rounds) |_| {
        const req = try interfaces.Request.call_constructor(
            realm,
            .{ .usvstring = "https://example.test/rc9" },
            .{ .was_passed = false, .value = undefined },
        );
        const ev = try interfaces.FetchEvent.call_constructor(
            realm,
            runtime.DOMString.initInterned("fetch"),
            .{ .base = .{ .base = .{} }, .request = req },
        );
        const ev_held = try engine.retainValue(realm, .{ .instance = ev });
        defer ev_held.release();
        const req_held = try engine.retainValue(realm, .{ .instance = req });
        defer req_held.release();
        try engine.setProperty(realm, req_held.value, "ev", ev_held.value);
        const handled = try interfaces.FetchEvent.get_handled(ev);
        defer engine.releaseValue(.{ .value = handled });
        try engine.setProperty(realm, handled, "ev", ev_held.value);
    }

    try page.settle();
    const grown = page.grown();
    if (grown > slack) {
        std.debug.print("rc9 SW events cycle retained: {d} live instances above baseline\n", .{grown});
        return error.CycleRetained;
    }
}

test "ExtendableMessageEvent and FetchEvent self-referential cycles collect" {
    try probe.onFreshThread(serviceWorkerEventsAndClientCycle);
}

// ============================================================================
// Green side: unwrapped-owner survival and reachable value survival
// ============================================================================

fn unwrappedMessageEventSurvivesFullGC() !void {
    const page = try Page.open("");
    defer page.close();
    const ctx = page.browser.current_context orelse return error.NoPage;
    const realm = ctx.realm orelse return error.NoRealm;

    try page.run(
        \\globalThis.seen = null;
        \\globalThis.target = new EventTarget();
        \\target.addEventListener('msg', (e) => {
        \\  globalThis.seen = e.data && e.data.secret;
        \\});
    );

    // Construct a MessageEvent purely in Zig (NO wrapper yet) with a fresh JS
    // object nothing else in script references.
    const event = blk: {
        const payload = try engine.evaluateClassicScript(realm, .{ .utf8 = "({ secret: 'survived-gc-42' })" }, "", null, NoReport.reporter);
        defer payload.release();
        break :blk try interfaces.MessageEvent.call_constructor(
            realm,
            runtime.DOMString.initInterned("msg"),
            .{ .was_passed = true, .value = .{ .base = .{}, .data = payload.value } },
        );
    };
    const event_gen = runtime.SlabAllocator.generationOf(event);
    try testing.expect(!engine.hasWrapper(event));

    // Force multiple FULL collections BEFORE the event has ever been wrapped!
    try page.settle();
    try testing.expect(!engine.hasWrapper(event));

    // Now dispatch to the target: the listener wraps `event` and reads `e.data`.
    const target_val = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis.target" }, "", null, NoReport.reporter);
    defer target_val.release();
    const target = engine.convertToPlatformObject(realm, target_val.value) orelse return error.NoTarget;
    _ = try interfaces.EventTarget.call_dispatchEvent(target, event);
    event.releaseIfUnwrapped(event_gen);

    try page.expect("String(globalThis.seen)", "survived-gc-42");
}

test "unwrapped Zig-made MessageEvent keeps its data across full GCs before dispatch" {
    try probe.onFreshThread(unwrappedMessageEventSurvivesFullGC);
}

fn unwrappedPromiseRejectionEventSurvivesFullGC() !void {
    const page = try Page.open("");
    defer page.close();
    const ctx = page.browser.current_context orelse return error.NoPage;
    const realm = ctx.realm orelse return error.NoRealm;

    try page.run(
        \\globalThis.seen = null;
        \\globalThis.target = new EventTarget();
        \\target.addEventListener('unhandledrejection', (e) => {
        \\  globalThis.seen = (e.promise instanceof Promise) + ':' + (e.reason && e.reason.tag);
        \\});
    );

    const event = blk: {
        const p = try engine.evaluateClassicScript(realm, .{ .utf8 = "Promise.resolve(1)" }, "", null, NoReport.reporter);
        defer p.release();
        const r = try engine.evaluateClassicScript(realm, .{ .utf8 = "({ tag: 'reason-ok' })" }, "", null, NoReport.reporter);
        defer r.release();
        break :blk try interfaces.PromiseRejectionEvent.call_constructor(
            realm,
            runtime.DOMString.initInterned("unhandledrejection"),
            .{ .base = .{}, .promise = p.value, .reason = r.value },
        );
    };
    const event_gen = runtime.SlabAllocator.generationOf(event);
    try testing.expect(!engine.hasWrapper(event));

    try page.settle();

    const target_val = try engine.evaluateClassicScript(realm, .{ .utf8 = "globalThis.target" }, "", null, NoReport.reporter);
    defer target_val.release();
    const target = engine.convertToPlatformObject(realm, target_val.value) orelse return error.NoTarget;
    _ = try interfaces.EventTarget.call_dispatchEvent(target, event);
    event.releaseIfUnwrapped(event_gen);

    try page.expect("String(globalThis.seen)", "true:reason-ok");
}

test "unwrapped Zig-made PromiseRejectionEvent keeps promise and reason across full GCs" {
    try probe.onFreshThread(unwrappedPromiseRejectionEventSurvivesFullGC);
}

fn reachableOwnersKeepTheirValues() !void {
    const page = try Page.open("<div id=root><span>a</span><span>b</span></div>");
    defer page.close();
    try page.run(
        \\const root = document.getElementById('root');
        \\globalThis.iter = document.createNodeIterator(root, NodeFilter.SHOW_ELEMENT, (n) =>
        \\  n.tagName === 'SPAN' ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP);
        \\globalThis.walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT, {
        \\  acceptNode(n) { return n.tagName === 'SPAN' ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP; }
        \\});
        \\globalThis.img = new ImageData(2, 2);
        \\img.data[0] = 123;
        \\globalThis.proc = new XSLTProcessor();
        \\proc.setParameter('', 'k', { val: 99 });
        \\globalThis.ceLog = [];
        \\(() => {
        \\  class MyEl extends HTMLElement {
        \\    static get observedAttributes() { return ['x']; }
        \\    connectedCallback() { ceLog.push('conn'); }
        \\    attributeChangedCallback(name, oldV, newV) { ceLog.push(name + '=' + newV); }
        \\  }
        \\  customElements.define('x-rc9-live', MyEl);
        \\})();
    );
    try page.settle();

    try page.expect("iter.nextNode().textContent + ':' + walker.nextNode().textContent", "a:a");
    try page.expect("String(typeof iter.filter === 'function' && typeof walker.filter === 'object')", "true");
    try page.expect("String(img.data[0])", "123");
    try page.expect("String(proc.getParameter('', 'k').val)", "99");
    try page.run(
        \\const el = document.createElement('x-rc9-live');
        \\document.body.appendChild(el);
        \\el.setAttribute('x', '7');
    );
    try page.expect("ceLog.join(',') + ':' + (typeof customElements.get('x-rc9-live'))", "conn,x=7:function");
}

test "reachable NodeIterator, TreeWalker, ImageData, XSLTProcessor and CustomElementRegistry keep their values across full GCs" {
    try probe.onFreshThread(reachableOwnersKeepTheirValues);
}

// ============================================================================
// Part B.2 end-to-end: PermissionStatus obtained and listened to ONLY in an
// isolated world survives full collections and runs its change listener.
// ============================================================================

fn worldOnlyPermissionStatusSurvivesGC() !void {
    const page_url = "http://127.0.0.1:65533/rc9-perm";
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const ctx = browser.current_context orelse return error.NoPage;
    try ctx.loadHTML("<!doctype html><body></body>", .{ .base_url = page_url });
    _ = try browser.runEventLoopBlocking(20);
    const main_realm = ctx.realm orelse return error.NoRealm;
    const world = try browser_mod.isolated_worlds.createIsolatedWorld(main_realm, 1, "__rc9_perm_world__", false);

    // Query and listen ONLY in the isolated world; drop the status reference.
    {
        const s = try engine.evaluateClassicScriptToString(
            world,
            .{ .utf8 = "globalThis.ready = false; globalThis.changed = ''; navigator.permissions.query({ name: 'geolocation' }).then(s => { s.addEventListener('change', () => { globalThis.changed = s.state; }); globalThis.ready = true; }); 'ok'" },
            "",
            null,
            testing.allocator,
            NoReport.reporter,
        );
        testing.allocator.free(s);
    }

    // Wait for query promise to settle.
    var ready = false;
    for (0..50) |_| {
        _ = try browser.runEventLoopBlocking(20);
        const got = try engine.evaluateClassicScriptToString(world, .{ .utf8 = "String(globalThis.ready)" }, "", null, testing.allocator, NoReport.reporter);
        defer testing.allocator.free(got);
        if (std.mem.eql(u8, got, "true")) {
            ready = true;
            break;
        }
    }
    try testing.expect(ready);

    // Full GCs with NO script reference to the PermissionStatus in either realm.
    for (0..4) |_| {
        try ctx.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }

    // Trigger a permission state change via the Browser's store.
    const store = try browser.scope.of(permissions.BrowserStore);
    const set = try store.set("http://127.0.0.1:65533", permissions.PermissionDescriptor.simple(.geolocation), .granted);
    set.release();

    // Wait for the change event to fire in the isolated world.
    var saw_change = false;
    for (0..50) |_| {
        _ = try browser.runEventLoopBlocking(20);
        const got = try engine.evaluateClassicScriptToString(world, .{ .utf8 = "String(globalThis.changed)" }, "", null, testing.allocator, NoReport.reporter);
        defer testing.allocator.free(got);
        if (std.mem.eql(u8, got, "granted")) {
            saw_change = true;
            break;
        }
    }
    try testing.expect(saw_change);
}

test "PermissionStatus obtained and listened to ONLY in an isolated world survives GC and fires change" {
    try probe.onFreshThread(worldOnlyPermissionStatusSurvivesGC);
}
