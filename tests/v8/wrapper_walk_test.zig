//! The wrapper redesign's P5, the walk (tmp/redesign/wrapper-redesign-
//! design.md 3.2, 4.4 and section 7's P5 entry; risks R2, R3, R4c, R6).
//!
//! A node wrapper is kept through a major collection while any wrapper of its
//! host-including tree is, while a node of its node document's tree keeps it
//! (D6), and while a node of its tree is kept (pending activity) - Blink's
//! Node::Trace through the tree's Member edges, WebKit's opaque roots. Until
//! P7 node tracing's JS edges (wrapper_cache.zig) keep the same trees; P5
//! adds the walk beside them (dom.wrapper_tracing, reached from V8's
//! NodeAnchor::Trace in the collection's atomic pause). P7 deleted the
//! edges: the walk alone keeps trees in production.
//!
//! What this file pins:
//! - THE RED TEST of P5, production since P7: every identity scenario of the
//!   Crane identity set (tests/wpt/crane/wr-*, rc-*, r3-detached-tree-child-
//!   keeps-root, gc-keeps-connected-nodes) holds with the walk alone, and
//!   every collectability scenario (a dropped tree, a removed child, a
//!   dropped document) is collected - the walk roots nothing. (Until P7 the
//!   red ran with the edges turned off by runtime.lifetime's test-only
//!   `tree_edges`, and production ran edges and walk together; P7 deleted
//!   the switch with the edges, so the two modes are one.)
//! - THE NEGATIVE CONTROL: with the walk off (a test-only override of
//!   runtime.lifetime's `trace_tree`), every scenario whose identity rests on
//!   its tree loses it - the scenarios can fail.
//! - Rule 3.2 c: a kept node keeps its tree's wrappers whether or not it is
//!   wrapped itself (the anchors' registry walks the keeps), and its release
//!   lets them go.
//! - The marking type: every agent's C++ heap is made kAtomic, which keeps
//!   every C++ Trace - and the walk - in the atomic pause (the integrator,
//!   2026-11-09 16:22); and the two cases that would break a walk done
//!   earlier in the cycle (the integrator's (a) and (b)): a subtree appended,
//!   and a subtree moved, while V8's incremental marking runs.
//!
//! Each case makes its own agent; the hooks' override is made after the
//! process start and restored after the agent's end.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

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

/// Whether the walk keeps trees.
const Mode = enum {
    /// Production: the walk (P7 deleted node tracing's JS edges).
    production,
    /// The negative control: no walk (no `trace_tree`).
    no_walk,
};

/// The hooks for `mode`, from the installed ones (start the process first).
fn overrideFor(mode: Mode) runtime.lifetime.HooksOverride {
    var hooks = runtime.lifetime.installedHooks();
    if (mode == .no_walk) hooks.trace_tree = null;
    return runtime.lifetime.overrideHooksForTest(hooks);
}

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

    /// The Browser's end, in its order (Browser.deinit): the realm, every
    /// node wrapper's reference, the last drain - which frees the trees only
    /// wrappers held - then the agent.
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
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        if (reports.count != 0) {
            std.debug.print("script failed: {s}\n", .{source});
            return error.ScriptFailed;
        }
    }

    /// Whether `source` evaluates to true (a script that throws - a node
    /// collected under a check that reads through it - is false).
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

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return engine.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn enter(self: Page) bool {
        const entered = ffi.v8_Isolate_GetCurrent() != self.isolate();
        if (entered) ffi.v8_Isolate_Enter(self.isolate());
        return entered;
    }

    fn leave(self: Page, entered: bool) void {
        if (entered) ffi.v8_Isolate_Exit(self.isolate());
    }

    /// Run the agent's posted platform tasks until none is left
    /// (FinalizationRegistry cleanups, the drain a collection posts).
    fn pump(self: Page) void {
        const entered = self.enter();
        defer self.leave(entered);
        while (ffi.v8_Platform_PumpMessageLoop(self.isolate())) {}
    }

    /// Three rounds of two requested full collections, the agent's tasks and
    /// its teardown queue - the Crane tests' `collect` (three collections
    /// between tasks).
    fn settle(self: Page) void {
        for (0..3) |_| {
            ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
            ffi.v8_Isolate_RequestGarbageCollection(self.isolate());
            self.pump();
            self.queue.drainAll();
        }
    }

    /// The adapter's cumulative counter `name`, with the page's isolate
    /// entered.
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

/// One case of the identity set: `setup` builds what script holds and drops
/// the rest; after the collections every check must hold.
const Scenario = struct {
    /// The Crane test it stands for.
    name: []const u8,
    setup: []const u8,
    checks: []const []const u8,
    /// Whether the identity checked rests on tree reachability alone - with
    /// no walk, at least one check fails (the negative
    /// control). False for a collectability case, which holds in every mode.
    tree_only: bool = true,
};

/// An HTML document of its own (attachShadow needs HTML elements), bound to
/// `d`.
const html_document = "globalThis.d = new Document().implementation.createHTMLDocument('');\n";

const scenarios = [_]Scenario{
    .{
        .name = "wr-detached-root-keeps-descendants",
        .setup = html_document ++
            \\globalThis.root = d.createElement('div');
            \\(() => {
            \\  const p = root.appendChild(d.createElement('p')); p.wr = 'p';
            \\  const b = p.appendChild(d.createElement('b')); b.wr = 'b';
            \\  root.appendChild(d.createElement('i')).wr = 'i';
            \\  globalThis.refs = { p: new WeakRef(p), b: new WeakRef(b) };
            \\})();
        ,
        .checks = &.{
            "root.firstChild.wr === 'p'",
            "root.firstChild.firstChild.wr === 'b'",
            "root.lastChild.wr === 'i'",
            "refs.p.deref() === root.firstChild",
            "refs.b.deref() === root.firstChild.firstChild",
        },
    },
    .{
        .name = "wr-held-node-keeps-ancestors / r3-detached-tree-child-keeps-root / rc-held-node-keeps-tree",
        .setup = html_document ++
            \\(() => {
            \\  let node = d.createElement('section'); node.wr = 'root';
            \\  globalThis.refs = { root: new WeakRef(node) };
            \\  for (let i = 0; i < 5; i++) { node = node.appendChild(d.createElement('div')); node.wr = 'level' + i; }
            \\  globalThis.leaf = node;
            \\})();
            \\globalThis.up = (n, k) => { while (k-- > 0) n = n.parentNode; return n; };
        ,
        .checks = &.{
            "leaf.wr === 'level4'",
            "up(leaf, 1).wr === 'level3'",
            "up(leaf, 4).wr === 'level0'",
            "up(leaf, 5).wr === 'root'",
            "refs.root.deref() === up(leaf, 5)",
        },
    },
    .{
        .name = "wr-flat-tree-one-wrapped-child (the child held)",
        .setup = html_document ++
            \\(() => {
            \\  const root = d.createElement('div');
            \\  root.innerHTML = '<p></p>'.repeat(10000); root.wr = 'root';
            \\  const child = root.children[5000]; child.wr = 'the one';
            \\  globalThis.child = child; globalThis.refs = { root: new WeakRef(root) };
            \\})();
        ,
        .checks = &.{
            "child.parentNode.wr === 'root'",
            "refs.root.deref() === child.parentNode",
            "child.parentNode.childElementCount === 10000",
        },
    },
    .{
        .name = "wr-flat-tree-one-wrapped-child (the root held)",
        .setup = html_document ++
            \\(() => {
            \\  const root = d.createElement('div');
            \\  root.innerHTML = '<p></p>'.repeat(10000);
            \\  const child = root.children[5000]; child.wr = 'the one';
            \\  globalThis.root = root; globalThis.refs = { child: new WeakRef(child) };
            \\})();
        ,
        .checks = &.{
            "root.children[5000].wr === 'the one'",
            "refs.child.deref() === root.children[5000]",
            "root.firstChild.wr === undefined",
        },
    },
    .{
        .name = "wr-node-keeps-document-tree / rc-document-held-through-detached-node",
        .setup =
        \\(() => {
        \\  const doc = new Document().implementation.createHTMLDocument('');
        \\  doc.wr = 'doc'; doc.documentElement.wr = 'html'; doc.body.wr = 'body';
        \\  globalThis.refs = { doc: new WeakRef(doc), body: new WeakRef(doc.body) };
        \\  globalThis.detached = doc.createElement('span');
        \\})();
        ,
        .checks = &.{
            "detached.ownerDocument.wr === 'doc'",
            "detached.ownerDocument.documentElement.wr === 'html'",
            "detached.ownerDocument.body.wr === 'body'",
            "refs.doc.deref() === detached.ownerDocument",
            "refs.body.deref() === detached.ownerDocument.body",
        },
    },
    .{
        .name = "rc-document-held-through-node-in-it",
        .setup =
        \\(() => {
        \\  const doc = new Document().implementation.createHTMLDocument('');
        \\  doc.wr = 'doc'; doc.head.wr = 'head';
        \\  globalThis.p = doc.body.appendChild(doc.createElement('p'));
        \\  globalThis.refs = { doc: new WeakRef(doc) };
        \\})();
        ,
        .checks = &.{
            "p.ownerDocument.wr === 'doc'",
            "p.ownerDocument.head.wr === 'head'",
            "refs.doc.deref() === p.ownerDocument",
        },
    },
    .{
        .name = "wr-shadow-and-template-wrappers (a node in the shadow tree held)",
        .setup = html_document ++
            \\(() => {
            \\  const host = d.createElement('div'); host.wr = 'host';
            \\  const sr = host.attachShadow({ mode: 'open' }); sr.wr = 'sr';
            \\  const inner = sr.appendChild(d.createElement('span')); inner.wr = 'inner';
            \\  inner.appendChild(d.createElement('b')).wr = 'deep';
            \\  globalThis.inner = inner; globalThis.refs = { host: new WeakRef(host), sr: new WeakRef(sr) };
            \\})();
        ,
        .checks = &.{
            "inner.parentNode.wr === 'sr'",
            "inner.parentNode.host.wr === 'host'",
            "inner.firstChild.wr === 'deep'",
            "refs.sr.deref() === inner.parentNode",
            "refs.host.deref() === inner.parentNode.host",
        },
    },
    .{
        .name = "wr-shadow-and-template-wrappers (the host held)",
        .setup = html_document ++
            \\(() => {
            \\  const host = d.createElement('div');
            \\  const sr = host.attachShadow({ mode: 'open' }); sr.wr = 'sr';
            \\  const inner = sr.appendChild(d.createElement('span')); inner.wr = 'inner';
            \\  globalThis.host = host; globalThis.refs = { inner: new WeakRef(inner) };
            \\})();
        ,
        .checks = &.{
            "host.shadowRoot.wr === 'sr'",
            "host.shadowRoot.firstChild.wr === 'inner'",
            "refs.inner.deref() === host.shadowRoot.firstChild",
        },
    },
    .{
        .name = "wr-shadow-and-template-wrappers (the template held)",
        .setup = html_document ++
            \\(() => {
            \\  const t = d.createElement('template');
            \\  t.content.wr = 'content';
            \\  const b = t.content.appendChild(d.createElement('b')); b.wr = 'b';
            \\  b.appendChild(d.createElement('i')).wr = 'i';
            \\  globalThis.t = t; globalThis.refs = { b: new WeakRef(b) };
            \\})();
        ,
        .checks = &.{
            "t.content.wr === 'content'",
            "t.content.firstChild.wr === 'b'",
            "t.content.firstChild.firstChild.wr === 'i'",
            "refs.b.deref() === t.content.firstChild",
        },
    },
    .{
        // A template's contents' host is in their host-including tree (Blink:
        // TemplateContentDocumentFragment::Trace visits its host_).
        .name = "wr-shadow-and-template-wrappers (a node in the template's contents held)",
        .setup = html_document ++
            \\(() => {
            \\  const t = d.createElement('template'); t.wr = 't';
            \\  t.content.wr = 'content';
            \\  globalThis.b = t.content.appendChild(d.createElement('b'));
            \\  globalThis.refs = { t: new WeakRef(t) };
            \\})();
        ,
        .checks = &.{
            "b.parentNode.wr === 'content'",
            "refs.t.deref() !== undefined && refs.t.deref().wr === 't'",
            "refs.t.deref().content === b.parentNode",
        },
    },
    .{
        .name = "wr-weak-targets-through-tree",
        .setup = html_document ++
            \\globalThis.root = d.createElement('div');
            \\globalThis.wm = new WeakMap(); globalThis.fired = [];
            \\globalThis.fr = new FinalizationRegistry((t) => fired.push(t));
            \\(() => {
            \\  const c = root.appendChild(d.createElement('p'));
            \\  wm.set(c, 'value'); fr.register(c, 'c');
            \\  globalThis.refs = { c: new WeakRef(c) };
            \\})();
        ,
        .checks = &.{
            "wm.get(root.firstChild) === 'value'",
            "refs.c.deref() === root.firstChild",
            "fired.length === 0",
        },
    },
    .{
        .name = "rc4-opaque-root-follows-the-tree (moved to another tree)",
        .setup = html_document ++
            \\globalThis.a = d.createElement('div'); globalThis.b = d.createElement('div');
            \\(() => {
            \\  const s = a.appendChild(d.createElement('span')); s.wr = 's';
            \\  s.appendChild(d.createElement('i')).wr = 'i';
            \\})();
            \\b.appendChild(a.firstChild); globalThis.a = null;
        ,
        .checks = &.{
            "b.firstChild.wr === 's'",
            "b.firstChild.firstChild.wr === 'i'",
        },
    },
    .{
        .name = "wr-static-nodelist-removed-nodes",
        .setup = html_document ++
            \\(() => {
            \\  const container = d.createElement('div');
            \\  for (let i = 0; i < 3; i++) container.appendChild(d.createElement('p')).appendChild(d.createElement('b'));
            \\  const list = container.querySelectorAll('p');
            \\  list.forEach((p, i) => { p.wr = 'p' + i; p.firstChild.wr = 'b' + i; });
            \\  for (const p of list) p.remove();
            \\  globalThis.list = list;
            \\})();
        ,
        .checks = &.{
            "list[0].wr === 'p0' && list[2].wr === 'p2'",
            "list[0].firstChild.wr === 'b0' && list[2].firstChild.wr === 'b2'",
        },
    },
    .{
        .name = "wr-mutation-record-nodes / rc-record-node-keeps-expando",
        .setup = html_document ++
            \\(() => {
            \\  const host = d.createElement('div');
            \\  const u = host.appendChild(d.createElement('u')); u.wr = 'u';
            \\  u.appendChild(d.createElement('em')).wr = 'em';
            \\  const mo = new MutationObserver(() => {});
            \\  mo.observe(host, { childList: true });
            \\  host.removeChild(u);
            \\  globalThis.records = mo.takeRecords(); mo.disconnect();
            \\})();
        ,
        .checks = &.{
            "records[0].removedNodes[0].wr === 'u'",
            "records[0].removedNodes[0].firstChild.wr === 'em'",
        },
    },
    // Collectability: the walk keeps what the browsers keep and nothing
    // more - these hold in every mode.
    .{
        .name = "a dropped detached tree is collected",
        .setup = html_document ++
            \\(() => {
            \\  const r = d.createElement('div'); r.wr = 1;
            \\  const c = r.appendChild(d.createElement('p')); c.wr = 2;
            \\  globalThis.refs = [new WeakRef(r), new WeakRef(c)];
            \\})();
        ,
        .checks = &.{"refs.every((r) => r.deref() === undefined)"},
        .tree_only = false,
    },
    .{
        .name = "a child removed from a held tree is collected",
        .setup = html_document ++
            \\globalThis.root = d.createElement('div');
            \\(() => {
            \\  const c = root.appendChild(d.createElement('p')); c.wr = 1;
            \\  c.appendChild(d.createElement('b')).wr = 2;
            \\  globalThis.refs = [new WeakRef(c), new WeakRef(c.firstChild)];
            \\  root.removeChild(c);
            \\})();
        ,
        .checks = &.{ "refs.every((r) => r.deref() === undefined)", "root.firstChild === null" },
        .tree_only = false,
    },
    .{
        .name = "a document does not keep a detached node of it (D6 is one way)",
        .setup =
        \\(() => {
        \\  globalThis.doc = new Document().implementation.createHTMLDocument('');
        \\  const s = doc.createElement('span'); s.wr = 1;
        \\  s.appendChild(doc.createElement('b')).wr = 2;
        \\  globalThis.refs = [new WeakRef(s), new WeakRef(s.firstChild)];
        \\})();
        ,
        .checks = &.{"refs.every((r) => r.deref() === undefined)"},
        .tree_only = false,
    },
    .{
        .name = "a dropped document and a detached node of it are collected",
        .setup =
        \\(() => {
        \\  const doc = new Document().implementation.createHTMLDocument('');
        \\  doc.body.wr = 1;
        \\  const s = doc.createElement('span'); s.wr = 2;
        \\  globalThis.refs = [new WeakRef(doc), new WeakRef(doc.body), new WeakRef(s)];
        \\})();
        ,
        .checks = &.{"refs.every((r) => r.deref() === undefined)"},
        .tree_only = false,
    },
};

/// `scenario` in `mode`, in a page of its own: how many of its checks fail.
fn failedChecks(mode: Mode, scenario: Scenario) !usize {
    test_process.start();
    const override = overrideFor(mode);
    defer override.restore();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(scenario.setup);
    page.settle();
    var failed: usize = 0;
    for (scenario.checks) |check| {
        if (try page.holds(check)) continue;
        failed += 1;
        if (mode != .no_walk or !scenario.tree_only) std.debug.print("{s} ({s}): does not hold: {s}\n", .{ scenario.name, @tagName(mode), check });
    }
    return failed;
}

test "wrapper walk P5: every agent's C++ heap marks atomically, so every Trace - and the walk - runs in the atomic pause" {
    // cppgc::Heap::MarkingType.kAtomic (v8_wrapper.cpp agentCppHeapParams;
    // inMarkingAtomicPause cites the 13.1 source).
    try testing.expectEqual(@as(u8, 0), ffi.v8_test_AgentCppHeapMarkingSupport());
}

test "wrapper walk P5 negative control: with the walk off, every tree-only scenario loses identity, and collection still collects" {
    for (scenarios) |scenario| {
        const failed = try failedChecks(.no_walk, scenario);
        if (scenario.tree_only) {
            if (failed == 0) std.debug.print("negative control: {s} kept its identity with no walk\n", .{scenario.name});
            try testing.expect(failed > 0);
        } else try testing.expectEqual(@as(usize, 0), failed);
    }
}

test "wrapper walk P5 RED, production since P7: the walk alone keeps every tree of the identity set, and the walk runs" {
    var failures: usize = 0;
    for (scenarios) |scenario| failures += try failedChecks(.production, scenario);
    try testing.expectEqual(@as(usize, 0), failures);
    // The walk ran, and found nothing amiss.
    test_process.start();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(scenarios[0].setup);
    const before = try page.counter("node_wrapper_walks");
    page.settle();
    try testing.expect(try page.counter("node_wrapper_walks") > before);
    try testing.expectEqual(@as(i64, 0), try page.counter("wrapper_trace_check_failures"));
}

/// Rule 3.2 c: a kept node keeps its tree's wrappers - wrapped or not
/// itself - until its keep is released (the anchors' registry walks the
/// keeps, design 4.4 "Kept nodes"). Answers whether the root's wrapper (and
/// expando) survived the keep, and checks it goes after the release.
fn keptUnwrappedNodeKeepsTree(mode: Mode) !bool {
    test_process.start();
    const override = overrideFor(mode);
    defer override.restore();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(html_document ++
        \\globalThis.root = d.createElement('div'); root.wr = 'root';
        \\root.innerHTML = '<u></u>';
        \\globalThis.refs = { root: new WeakRef(root) };
    );
    // The parser's <u>, never wrapped: its NodeBase from the root's.
    const root_instance = try page.instance("root");
    const root_node = dom.instance_bridge.getNodeBase(@ptrCast(root_instance)) orelse return error.NotANode;
    const u_node = root_node.first_child orelse return error.NoChild;
    try testing.expect(u_node.wrapper.isEmpty());
    const u: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(u_node) orelse return error.NoInstance));
    // The keep's owner holds its node natively, as pending activity does.
    dom.refcount.holderRef(u_node);
    engine.keepPlatformObjectAlive(u);
    try page.run("globalThis.root = null;");
    page.settle();
    const kept = try page.holds("refs.root.deref() !== undefined && refs.root.deref().wr === 'root'");
    try testing.expect(u_node.wrapper.isEmpty());
    engine.releasePlatformObject(u);
    dom.refcount.holderDeref(u_node);
    page.settle();
    try testing.expect(try page.holds("refs.root.deref() === undefined"));
    return kept;
}

test "wrapper walk P5: a kept node keeps its tree's wrappers even unwrapped (rule 3.2 c), and its release lets them go" {
    try testing.expect(try keptUnwrappedNodeKeepsTree(.production));
    // The negative control: nothing but the walk keeps such a tree.
    try testing.expect(!try keptUnwrappedNodeKeepsTree(.no_walk));
}

/// The integrator's (a) and (b): a tree change made while V8's incremental
/// marking runs is seen by the walk, which runs in the atomic pause over
/// every anchor marked in the cycle. `setup` makes the trees, `mutation` runs
/// with marking in progress, then the collection finishes; whether every
/// check holds.
fn midCycle(mode: Mode, setup: []const u8, mutation: []const u8, checks: []const []const u8) !bool {
    // A cycle the mutation's own allocations finished first proves nothing:
    // tried again, a few times, before the case fails as inconclusive.
    for (0..4) |_| return midCycleOnce(mode, setup, mutation, checks) catch |err| switch (err) {
        error.Inconclusive => continue,
        else => return err,
    };
    std.debug.print("mid-cycle case inconclusive four times: the collection finished during the mutation\n", .{});
    return error.Inconclusive;
}

fn midCycleOnce(mode: Mode, setup: []const u8, mutation: []const u8, checks: []const []const u8) !bool {
    test_process.start();
    const override = overrideFor(mode);
    defer override.restore();
    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    try page.run(setup);
    // Live ballast, so V8's marking has work left when the mutation runs.
    try page.run("globalThis.ballast = Array.from({ length: 200000 }, (_, i) => ({ i }));");
    page.settle();
    {
        const entered = page.enter();
        defer page.leave(entered);
        // V8's incremental marking starts - and with it the C++ heap's (its
        // marking type is atomic: nothing is traced until the pause).
        try testing.expect(ffi.v8_test_Isolate_StartIncrementalMarking(page.isolate()));
    }
    try page.run(mutation);
    {
        const entered = page.enter();
        defer page.leave(entered);
        // Still marking: the change landed mid-cycle (else the case proves
        // nothing).
        if (!ffi.v8_test_Isolate_CppHeapIsMarking(page.isolate())) return error.Inconclusive;
    }
    page.settle();
    var all = true;
    for (checks) |check| {
        if (try page.holds(check)) continue;
        if (mode != .no_walk) std.debug.print("mid-cycle ({s}): does not hold: {s}\n", .{ @tagName(mode), check });
        all = false;
    }
    return all;
}

const appended_setup = html_document ++
    \\globalThis.root = d.createElement('div');
    \\root.appendChild(d.createElement('p')).wr = 'p';
;
const appended_mutation =
    \\(() => {
    \\  const s = root.firstChild.appendChild(d.createElement('section')); s.wr = 'appended';
    \\  s.appendChild(d.createElement('b')).wr = 'b';
    \\  globalThis.refs = { s: new WeakRef(s) };
    \\})();
;
const appended_checks = [_][]const u8{
    "root.firstChild.wr === 'p'",
    "root.firstChild.firstChild.wr === 'appended'",
    "root.firstChild.firstChild.firstChild.wr === 'b'",
    "refs.s.deref() === root.firstChild.firstChild",
};

test "wrapper walk P5 (a): a subtree appended while incremental marking runs keeps its wrappers" {
    try testing.expect(try midCycle(.production, appended_setup, appended_mutation, &appended_checks));
    try testing.expect(!try midCycle(.no_walk, appended_setup, appended_mutation, &appended_checks));
}

const moved_setup = html_document ++
    \\globalThis.a = d.createElement('div'); globalThis.b = d.createElement('div');
    \\(() => {
    \\  const s = a.appendChild(d.createElement('span')); s.wr = 's';
    \\  s.appendChild(d.createElement('i')).wr = 'i';
    \\})();
;
const moved_mutation =
    \\b.appendChild(a.firstChild); globalThis.a = null;
;
const moved_checks = [_][]const u8{
    "b.firstChild.wr === 's'",
    "b.firstChild.firstChild.wr === 'i'",
};

test "wrapper walk P5 (b): a subtree moved between trees while incremental marking runs keeps its wrappers" {
    try testing.expect(try midCycle(.production, moved_setup, moved_mutation, &moved_checks));
    try testing.expect(!try midCycle(.no_walk, moved_setup, moved_mutation, &moved_checks));
}

test "wrapper walk P5: two agents on one thread - each collection walks its own agent's trees through its own record" {
    test_process.start();
    var queue_a = DeferredTeardown.init(testing.allocator);
    defer queue_a.deinit();
    var queue_b = DeferredTeardown.init(testing.allocator);
    defer queue_b.deinit();
    const a = try Page.open(&queue_a);
    defer a.close();
    const b = try Page.open(&queue_b);
    defer b.close();
    const make = html_document ++
        \\globalThis.root = d.createElement('div');
        \\(() => { const p = root.appendChild(d.createElement('p')); p.wr = 'kept'; p.appendChild(d.createElement('b')).wr = 'deep'; })();
    ;
    try a.run(make);
    try b.run(make);
    const pages = [_]Page{ a, b };
    for (pages, 0..) |collecting, k| {
        const other = pages[1 - k];
        const walks_collecting = try collecting.counter("node_wrapper_walks");
        const walks_other = try other.counter("node_wrapper_walks");
        {
            // The OTHER agent's isolate is the current one when this one
            // collects: the collection enters its own (CollectingScope), and
            // its anchors find its record (collectingRecord) - never the
            // other's.
            const entered = other.enter();
            defer other.leave(entered);
            ffi.v8_Isolate_RequestGarbageCollection(collecting.isolate());
            ffi.v8_Isolate_RequestGarbageCollection(collecting.isolate());
        }
        try testing.expect(try collecting.counter("node_wrapper_walks") > walks_collecting);
        try testing.expectEqual(walks_other, try other.counter("node_wrapper_walks"));
    }
    for (pages) |page| {
        page.settle();
        try testing.expect(try page.holds("root.firstChild.wr === 'kept' && root.firstChild.firstChild.wr === 'deep'"));
        try testing.expectEqual(@as(i64, 0), try page.counter("wrapper_trace_check_failures"));
    }
}
