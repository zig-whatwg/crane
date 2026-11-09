//! The wrapper redesign's P6: holders trace their nodes
//! (tmp/redesign/wrapper-redesign-design.md 3.2 rule (d), 4.4 "Holders" and
//! section 7's P6 entry; risk R3).
//!
//! A holder whose wrapper is kept keeps the wrappers of every node it holds
//! for script, and of those nodes' trees - Blink's holders trace their
//! `Member<Node>`s (Chromium 131.0.6778.0): StaticNodeTypeList::Trace visits
//! `nodes_` (core/dom/static_node_list.h), ChildListRecord::Trace its
//! `target_`, node lists and siblings (core/dom/mutation_record.cc),
//! MutationObserver::Trace its pending `records_` (core/dom/
//! mutation_observer.cc), XPathResult::Trace its `node_set_` and `document_`
//! (core/xml/xpath_result.cc), IntersectionObserverEntry::Trace its `target_`
//! (core/intersection_observer/intersection_observer_entry.cc), and a live
//! collection its root (LiveNodeListBase's `owner_node_`). Crane's holders keep
//! counted references (refcount) and are ALSO traced: a holder's wrapper
//! carries a HolderAnchor on the agent's C++ heap whose Trace names the held
//! nodes to the walk (VTable.trace_held_nodes -> dom.wrapper_tracing).
//!
//! What this file pins, each case in a page of its own:
//! - THE RED TEST, production since P7: the holder's wrapper alone keeps
//!   each held node's wrapper identity - its expando and `===` through a
//!   WeakRef - through full collections; and dropping the holder lets them
//!   go. (P6's red ran with every node edge off - runtime.lifetime's
//!   test-only `tree_edges`: the tree edges, keepOpaqueRoot's edges and
//!   node_holds' rescues - and production with them on; P7 deleted the
//!   edges and the switch, so the two runs are one.)
//! - The cost lesson (docs/lessons/architecture-tracing-a-holders-nodes-makes-
//!   a-wrapper-per-node.md): a querySelectorAll of 1,000 nodes makes no node
//!   wrapper, and neither does a collection while the list is held.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");

const DeferredTeardown = runtime.gc.DeferredTeardown;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,
    /// A check's exception is its answer (false), not news.
    quiet: bool = false,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        if (!self.quiet) std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) engine.Reporter {
        return .{ .report = report, .host = self };
    }
};

const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,
    queue: *DeferredTeardown,

    fn open(queue: *DeferredTeardown) !Page {
        test_process.start();
        const agent = try engine.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &test_process.no_hooks,
            .host = null,
            .deferred_teardown = queue,
        });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm, .queue = queue };
    }

    /// The Browser's end, in its order (Browser.deinit).
    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.releaseNodeWrappers(self.agent);
        self.queue.drainAll();
        engine.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter()) catch |err| {
            std.debug.print("script failed ({s}): {s}\n", .{ @errorName(err), source });
            return err;
        };
        held.release();
        if (reports.count != 0) {
            std.debug.print("script failed: {s}\n", .{source});
            return error.ScriptFailed;
        }
    }

    /// Whether `source` evaluates to true (a throwing check is false).
    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{ .quiet = true };
        const held = engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter()) catch |err| {
            if (reports.count != 0) return false;
            return err;
        };
        defer held.release();
        if (reports.count != 0) return false;
        return engine.toBoolean(self.realm, held.value);
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    fn pump(self: Page) void {
        const entered = self.enter();
        defer self.leave(entered);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
    }

    /// Three rounds of two requested full collections, the agent's tasks and
    /// its teardown queue - the Crane tests' `collect`.
    fn settle(self: Page) void {
        for (0..3) |_| {
            ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
            ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
            self.pump();
            self.queue.drainAll();
        }
    }

    fn counter(self: Page, name: []const u8) !i64 {
        const entered = self.enter();
        defer self.leave(entered);
        const counters = try engine.diagnosticCounters(testing.allocator);
        defer testing.allocator.free(counters);
        for (counters) |c| if (std.mem.eql(u8, c.name, name)) return c.value;
        std.debug.print("the adapter reports no counter named {s}\n", .{name});
        return error.CounterMissing;
    }
};

/// One holder: `setup` makes it hold detached, wrapped nodes with expandos
/// (and WeakRefs to them in `refs`) and drops every other reference; after
/// the collections every `kept` check holds; `drop` lets the holder go, and
/// after more collections every node wrapper is gone (`refs` all empty).
const Scenario = struct {
    /// The Crane test it stands for (tests/wpt/crane/wr-holder-*).
    name: []const u8,
    setup: []const u8,
    kept: []const []const u8,
    drop: []const u8,
};

/// An HTML document of its own, bound to `d`.
const html_document = "globalThis.d = new Document().implementation.createHTMLDocument('');\n";
const all_gone = "refs.every((r) => r.deref() === undefined)";

const scenarios = [_]Scenario{
    .{
        .name = "wr-holder-static-nodelist",
        .setup = html_document ++
            \\(() => {
            \\  const container = d.createElement('div');
            \\  for (let i = 0; i < 3; i++) container.appendChild(d.createElement('p')).appendChild(d.createElement('b'));
            \\  const list = container.querySelectorAll('p');
            \\  list.forEach((p, i) => { p.wr = 'p' + i; p.firstChild.wr = 'b' + i; });
            \\  for (const p of list) p.remove();
            \\  globalThis.list = list;
            \\  globalThis.refs = [...list].flatMap((p) => [new WeakRef(p), new WeakRef(p.firstChild)]);
            \\})();
        ,
        .kept = &.{
            "list[0].wr === 'p0' && list[1].wr === 'p1' && list[2].wr === 'p2'",
            "list[0].firstChild.wr === 'b0' && list[2].firstChild.wr === 'b2'",
            "refs[0].deref() === list[0] && refs[5].deref() === list[2].firstChild",
        },
        .drop = "globalThis.list = null;",
    },
    .{
        .name = "wr-holder-mutation-record",
        .setup = html_document ++
            \\(() => {
            \\  const host = d.createElement('div'); host.wr = 'host';
            \\  const u = host.appendChild(d.createElement('u')); u.wr = 'u';
            \\  u.appendChild(d.createElement('em')).wr = 'em';
            \\  const mo = new MutationObserver(() => {});
            \\  mo.observe(host, { childList: true });
            \\  host.removeChild(u);
            \\  globalThis.records = mo.takeRecords(); mo.disconnect();
            \\  globalThis.refs = [new WeakRef(host), new WeakRef(u), new WeakRef(u.firstChild)];
            \\})();
        ,
        .kept = &.{
            "records.length === 1 && records[0].target.wr === 'host'",
            "records[0].removedNodes[0].wr === 'u'",
            "records[0].removedNodes[0].firstChild.wr === 'em'",
            "refs[1].deref() === records[0].removedNodes[0]",
        },
        .drop = "globalThis.records = null;",
    },
    .{
        // Records still queued on their observer: unwrapped, reached through
        // the observer's wrapper (Blink: MutationObserver::Trace visits
        // records_).
        .name = "wr-holder-mutation-observer-pending",
        .setup = html_document ++
            \\globalThis.delivered = 0;
            \\globalThis.mo = new MutationObserver(() => { globalThis.delivered++; });
            \\(() => {
            \\  const host = d.createElement('div'); host.wr = 'host';
            \\  const u = host.appendChild(d.createElement('u')); u.wr = 'u';
            \\  mo.observe(host, { childList: true });
            \\  host.removeChild(u);
            \\  globalThis.refs = [new WeakRef(host), new WeakRef(u)];
            \\})();
        ,
        .kept = &.{
            // Still pending when collected: no delivery ran.
            "delivered === 0",
            "(() => { globalThis.taken = mo.takeRecords(); return taken.length === 1; })()",
            "taken[0].removedNodes[0].wr === 'u' && taken[0].target.wr === 'host'",
            "refs[1].deref() === taken[0].removedNodes[0]",
        },
        .drop = "mo.disconnect(); globalThis.mo = null; globalThis.taken = null;",
    },
    .{
        .name = "wr-holder-xpath-result",
        .setup = html_document ++
            \\(() => {
            \\  const container = d.createElement('div'); container.wr = 'c';
            \\  for (let i = 0; i < 2; i++) container.appendChild(d.createElement('p')).wr = 'p' + i;
            \\  globalThis.result = d.evaluate('.//p', container, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
            \\  globalThis.refs = [new WeakRef(container), new WeakRef(container.firstChild), new WeakRef(container.lastChild)];
            \\})();
        ,
        .kept = &.{
            "result.snapshotLength === 2 && result.snapshotItem(0).wr === 'p0' && result.snapshotItem(1).wr === 'p1'",
            "result.snapshotItem(1).parentNode.wr === 'c'",
            "refs[0].deref() === result.snapshotItem(0).parentNode",
        },
        .drop = "globalThis.result = null;",
    },
    .{
        .name = "wr-holder-intersection-observer-entry",
        .setup = html_document ++
            \\(() => {
            \\  const t = d.createElement('div'); t.wr = 't';
            \\  t.appendChild(d.createElement('i')).wr = 'i';
            \\  const rect = { x: 0, y: 0, width: 0, height: 0 };
            \\  globalThis.entry = new IntersectionObserverEntry({ time: 0, rootBounds: rect, boundingClientRect: rect, intersectionRect: rect, isIntersecting: false, isVisible: false, intersectionRatio: 0, target: t });
            \\  globalThis.refs = [new WeakRef(t), new WeakRef(t.firstChild)];
            \\})();
        ,
        .kept = &.{
            "entry.target.wr === 't' && entry.target.firstChild.wr === 'i'",
            "refs[0].deref() === entry.target",
        },
        .drop = "globalThis.entry = null;",
    },
    .{
        // A live collection keeps its root (WebKit: Ref<ContainerNode>
        // m_ownerNode; Blink: LiveNodeListBase traces owner_node_).
        .name = "wr-holder-live-collection-root",
        .setup = html_document ++
            \\(() => {
            \\  const root = d.createElement('div'); root.wr = 'root';
            \\  root.appendChild(d.createElement('p'));
            \\  globalThis.coll = root.children;
            \\  globalThis.refs = [new WeakRef(root)];
            \\})();
        ,
        .kept = &.{
            "coll.length === 1 && coll[0].parentNode.wr === 'root'",
            "refs[0].deref() === coll[0].parentNode",
        },
        .drop = "globalThis.coll = null;",
    },
    .{
        .name = "wr-holder-child-nodes-root",
        .setup = html_document ++
            \\(() => {
            \\  const root = d.createElement('div'); root.wr = 'root';
            \\  root.appendChild(d.createElement('p'));
            \\  globalThis.nodes = root.childNodes;
            \\  globalThis.refs = [new WeakRef(root)];
            \\})();
        ,
        .kept = &.{
            "nodes.length === 1 && nodes[0].parentNode.wr === 'root'",
            "refs[0].deref() === nodes[0].parentNode",
        },
        .drop = "globalThis.nodes = null;",
    },
    .{
        // An SVGAnimatedString keeps the element it reflects (Blink:
        // SVGAnimatedPropertyBase's context element, traced).
        .name = "wr-holder-svg-animated-string",
        .setup = html_document ++
            \\(() => {
            \\  const a = d.createElementNS('http://www.w3.org/2000/svg', 'a'); a.wr = 'a';
            \\  globalThis.anim = a.className;
            \\  globalThis.refs = [new WeakRef(a)];
            \\})();
        ,
        .kept = &.{"refs[0].deref() !== undefined && refs[0].deref().wr === 'a'"},
        .drop = "globalThis.anim = null;",
    },
};

/// `scenario`, in a page of its own: how many checks fail - the kept checks
/// after the collections, then the gone check after the holder is dropped.
fn failedChecks(scenario: Scenario) !usize {
    test_process.start();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(scenario.setup);
    page.settle();
    var failed: usize = 0;
    for (scenario.kept) |check| {
        if (try page.holds(check)) continue;
        failed += 1;
        std.debug.print("{s}: does not hold: {s}\n", .{ scenario.name, check });
    }
    try page.run(scenario.drop);
    page.settle();
    if (!try page.holds(all_gone)) {
        failed += 1;
        std.debug.print("{s}: dropping the holder did not let its nodes' wrappers go\n", .{scenario.name});
    }
    return failed;
}

test "wr6 RED, production since P7: a holder's wrapper alone keeps its held nodes' wrappers, and dropping it lets them go" {
    var failures: usize = 0;
    for (scenarios) |scenario| failures += try failedChecks(scenario);
    try testing.expectEqual(@as(usize, 0), failures);
}

/// The cost lesson: a static list of 1,000 nodes, made and held across
/// collections, makes no node wrapper - its holds are counted references,
/// and its trace names only wrappers that exist.
fn querySelectorAllWrapsNothing() !void {
    test_process.start();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(html_document ++
        \\globalThis.c = d.createElement('div');
        \\c.innerHTML = '<p></p>'.repeat(1000);
    );
    page.settle();
    const before = try page.counter("node_wrappers");
    try page.run("globalThis.n = c.querySelectorAll('p').length; globalThis.l = c.querySelectorAll('p');");
    try testing.expect(try page.holds("n === 1000 && l.length === 1000"));
    try testing.expectEqual(before, try page.counter("node_wrappers"));
    // Traced across collections while held, still none.
    page.settle();
    try testing.expectEqual(before, try page.counter("node_wrappers"));
    try testing.expect(try page.holds("l.length === 1000"));
}

test "wr6: a querySelectorAll of 1,000 nodes makes no node wrapper, held across collections or not" {
    try querySelectorAllWrapsNothing();
}
