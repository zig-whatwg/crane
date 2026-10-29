//! Refcount step 5g (lane refcount4): an event takes one counted reference on
//! its target and its relatedTarget (WebKit: Event `RefPtr<EventTarget>
//! m_target`, MouseEvent and FocusEvent `RefPtr<EventTarget>
//! m_relatedTarget` - Source/WebCore/dom/Event.h, MouseEvent.h,
//! FocusEvent.h), its path one on each node it names while dispatch runs
//! (EventContext `RefPtr<Node> m_node`, `RefPtr<Node> m_relatedTarget`,
//! dom/EventContext.h), dispatch one on the activation target across the
//! activation steps, and the HTML events one on the element they name
//! (ToggleEvent and CommandEvent source, SubmitEvent submitter, NavigateEvent
//! sourceElement). SHADOW MODE: counts read through dom.refcount.count - the
//! wrapper's (1, the node is kept by a global; it adopted the node's born
//! reference, lane refcount7) + the holders'.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const browser_mod = h.browser_mod;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn eventCountsItsTarget() !void {
    const page = try Page.open();
    defer page.close();
    try page.run("globalThis.t = document.createElement('div'); globalThis.e = new Event('x');");
    const t = try page.node("t");
    try expectCount(1, t, "t, before any dispatch");
    // The target dispatch leaves the event with, which script reads after.
    try page.run("t.dispatchEvent(e); if (e.target !== t) throw new Error('target');");
    try expectCount(2, t, "t, the kept event's target");
    try page.run("e = null;");
    try page.collect();
    try expectCount(1, t, "t, after the event was collected");
    // An event script never sees (no listener wraps it) is freed when its
    // dispatch ends, and lets its target go then.
    try page.run("t.click();");
    try expectCount(1, t, "t, after an unseen event was fired at it");
}

test "an event takes one counted reference on the target dispatch leaves it with, and releases it" {
    try onFreshThread(eventCountsItsTarget);
}

fn eventCountsItsRelatedTarget() !void {
    const page = try Page.open();
    defer page.close();
    try page.run("globalThis.rt = document.createElement('span');");
    const rt = try page.node("rt");
    try page.run("globalThis.me = new MouseEvent('mouseover', { relatedTarget: rt });");
    try expectCount(2, rt, "rt, a MouseEvent's relatedTarget");
    try page.run("globalThis.fe = new FocusEvent('focus', { relatedTarget: rt });");
    try expectCount(3, rt, "rt, a FocusEvent's relatedTarget too");
    try page.run("me.initMouseEvent('mouseout', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);");
    try expectCount(2, rt, "rt, after initMouseEvent cleared the MouseEvent's");
    try page.run("me = null; fe = null;");
    try page.collect();
    try expectCount(1, rt, "rt, after both events were collected");
}

test "an event takes one counted reference on its relatedTarget, and releases it" {
    try onFreshThread(eventCountsItsRelatedTarget);
}

/// Reads its nodes' counts each time the page calls `probe()`.
const CountProbe = struct {
    nodes: []const *dom.NodeBase,
    seen: [4][4]u32 = std.mem.zeroes([4][4]u32),
    calls: usize = 0,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *CountProbe = @ptrCast(@alignCast(data.?));
        if (self.calls < self.seen.len) {
            for (self.nodes, 0..) |node, i| self.seen[self.calls][i] = dom.refcount.count(node);
        }
        self.calls += 1;
        return .undefined;
    }

    fn install(self: *CountProbe, callback: *engine.BuiltinFunction, page: Page) !void {
        callback.* = .{ .steps = steps, .data = self };
        const realm = page.browser.getRealm() orelse return error.NoRealm;
        try engine.defineBuiltinFunction(realm, "probe", 0, callback);
    }

    fn expectSeen(self: *const CountProbe, call: usize, expected: []const u32, what: []const u8) !void {
        if (self.calls <= call) {
            std.debug.print("{s}: probe called {d} times\n", .{ what, self.calls });
            return error.ProbeNotCalled;
        }
        for (expected, 0..) |want, i| {
            if (self.seen[call][i] != want) {
                std.debug.print("{s}: node {d} count {d}, expected {d}\n", .{ what, i, self.seen[call][i], want });
                return error.WrongCount;
            }
        }
    }
};

fn pathCountsItsNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.outer = document.createElement('div');
        \\globalThis.mid = outer.appendChild(document.createElement('p'));
        \\globalThis.leaf = mid.appendChild(document.createElement('span'));
        \\globalThis.rt = document.createElement('em');
        \\outer.addEventListener('x', () => probe());
    );
    const nodes = [_]*dom.NodeBase{ try page.node("outer"), try page.node("mid"), try page.node("leaf"), try page.node("rt") };
    var probe: CountProbe = .{ .nodes = &nodes };
    var callback: engine.BuiltinFunction = undefined;
    try probe.install(&callback, page);
    // While the event runs at outer, its path holds outer, mid and leaf; rt,
    // its relatedTarget, is held by the event and by the path items.
    try page.run("globalThis.e = new MouseEvent('x', { bubbles: true, relatedTarget: rt }); leaf.dispatchEvent(e);");
    try probe.expectSeen(0, &.{ 2, 2, 2, 3 }, "the path's nodes during dispatch");
    // After it: the event keeps its target and relatedTarget, the path none.
    try expectCount(1, nodes[0], "outer, after dispatch");
    try expectCount(1, nodes[1], "mid, after dispatch");
    try expectCount(2, nodes[2], "leaf, the kept event's target");
    try expectCount(2, nodes[3], "rt, the kept event's relatedTarget");
    try page.run("e = null;");
    try page.collect();
    try expectCount(1, nodes[2], "leaf, after the event was collected");
    try expectCount(1, nodes[3], "rt, after the event was collected");
}

test "an event's path takes one counted reference on each node it names while dispatch runs" {
    try onFreshThread(pathCountsItsNodes);
}

fn activationTargetIsHeld() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.cb = document.body.appendChild(document.createElement('input'));
        \\cb.type = 'checkbox';
        \\cb.addEventListener('change', () => probe());
    );
    const nodes = [_]*dom.NodeBase{try page.node("cb")};
    var probe: CountProbe = .{ .nodes = &nodes };
    var callback: engine.BuiltinFunction = undefined;
    try probe.install(&callback, page);
    try expectCount(1, nodes[0], "cb, before the click");
    // The checkbox's activation behaviour (dispatch step 12) fires change
    // after the click's path was emptied (step 9): cb is then held by the
    // click event's kept target, by dispatch across the activation steps,
    // and by the change event's own path.
    try page.run("cb.click(); if (!cb.checked) throw new Error('not checked');");
    try probe.expectSeen(0, &.{4}, "cb during its activation behaviour");
    // The change event a listener saw lives until it is collected.
    try page.collect();
    try expectCount(1, nodes[0], "cb, after the click's events went");
}

test "dispatch holds the activation target across the activation steps" {
    try onFreshThread(activationTargetIsHeld);
}

fn htmlEventsCountTheirElements() !void {
    const page = try Page.open();
    defer page.close();
    try page.run("globalThis.el = document.createElement('button');");
    const el = try page.node("el");
    try page.run("globalThis.te = new ToggleEvent('toggle', { source: el });");
    try expectCount(2, el, "el, a ToggleEvent's source");
    try page.run("globalThis.ce = new CommandEvent('command', { source: el });");
    try expectCount(3, el, "el, a CommandEvent's source too");
    try page.run("globalThis.se = new SubmitEvent('submit', { submitter: el });");
    try expectCount(4, el, "el, a SubmitEvent's submitter too");
    try page.run("te = null; ce = null; se = null;");
    try page.collect();
    try expectCount(1, el, "el, after the three events were collected");
}

test "ToggleEvent, CommandEvent and SubmitEvent take one counted reference on the element they name" {
    try onFreshThread(htmlEventsCountTheirElements);
}

/// A page with the navigation API: an https document (about:blank's initial
/// document fires no navigate event).
fn openNavigablePage() !Page {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions("https://refcount4.test/page.html", .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://refcount4.test/page.html" });
    _ = try browser.runEventLoopBlocking(10);
    return .{ .browser = browser };
}

fn navigateEventCountsItsSourceElement() !void {
    const page = try openNavigablePage();
    defer page.close();
    try page.run(
        \\globalThis.link = document.body.appendChild(document.createElement('a'));
        \\link.href = '#s';
        \\navigation.addEventListener('navigate', e => { globalThis.ne = e; }, { once: true });
    );
    const link = try page.node("link");
    try expectCount(1, link, "the link, before the click");
    try page.run("link.click();");
    for (0..10) |_| _ = try page.browser.runEventLoopBlocking(10);
    try page.run("if (!globalThis.ne || ne.sourceElement !== link) throw new Error('no navigate event from the link');");
    try expectCount(2, link, "the link, the kept navigate event's sourceElement");
    try page.run("ne = null;");
    try page.collect();
    try expectCount(1, link, "the link, after the navigate event was collected");
}

test "a NavigateEvent takes one counted reference on its sourceElement, and releases it" {
    try onFreshThread(navigateEventCountsItsSourceElement);
}
