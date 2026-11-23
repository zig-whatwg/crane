//! Refcount step 8 under isolated worlds (lane rc8; main's ruling of
//! 2026-11-23 11:53 AM ET, option (c)): listeners, event handlers and
//! observer callbacks are traced from their owner's wrapper - and an owner
//! has a wrapper per world (src/runtime/engines/v8/protocol_worlds.zig). The
//! set must reach EVERY wrapper the owner has, and a wrapper made later gets
//! it drawn onto it: Blink traces a listener from the C++ EventTarget
//! (EventTarget::Trace -> EventListenerMap -> TraceWrapperV8Reference), which
//! any of its wrappers, in any world, keeps alive - so a listener lives as
//! long as ANY wrapper of its target does.
//!
//! Automation is where isolated worlds are made (Puppeteer's and
//! Playwright's utility worlds, CDP Page.createIsolatedWorld, the built-in MCP
//! server), so these hold there as the main-world cases of
//! cb8_cycle_breakers_test.zig and refcount_retention_test.zig hold without
//! worlds:
//! - green side: what a world (or the page) still reaches keeps every
//!   listener of it, whichever world added it;
//! - red side: a cycle through a world wrapper - a world's closure over its
//!   own target - is collected like the page's.
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const runtime = @import("runtime");
const browser_mod = @import("browser");
const probe = @import("refcount_probe.zig");
const Page = probe.Page;

const isolated_worlds = browser_mod.isolated_worlds;

/// The navigable the test's world is made for (isolated_worlds keys a world
/// by navigable and name; one page here).
const navigable: u64 = 1;

/// As refcount_retention_test.zig's: what a settled page may still hold of
/// 500 rounds that each made a 2-node tree.
const slack: usize = 64;

const Reports = struct {
    count: usize = 0,
    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

/// A page with an isolated world made for it (a utility world, as a CDP
/// client makes one), settled again so that what making the world allocated
/// is in the baseline.
const WorldPage = struct {
    page: Page,
    world: runtime.Context,

    fn open() !WorldPage {
        var page = try Page.open("");
        errdefer page.close();
        const main_realm = (page.browser.current_context orelse return error.NoPage).realm orelse return error.NoRealm;
        const world = try isolated_worlds.createIsolatedWorld(main_realm, navigable, "__cb8_utility_world__", false);
        try page.settle();
        page.baseline = page.slab.stats().currently_allocated;
        return .{ .page = page, .world = world };
    }

    fn close(self: WorldPage) void {
        self.page.close();
    }

    /// Run `source` in the world; nothing it throws is reported.
    fn inWorld(self: WorldPage, source: []const u8) !void {
        var reports: Reports = .{};
        const got = try engine.evaluateClassicScriptToString(self.world, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
        testing.allocator.free(got);
        if (reports.count != 0) {
            std.debug.print("world script reported: {s}\n", .{source});
            return error.WorldScriptThrew;
        }
    }

    fn expectInWorld(self: WorldPage, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = try engine.evaluateClassicScriptToString(self.world, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = Reports.report, .host = &reports });
        defer testing.allocator.free(got);
        try testing.expectEqual(@as(usize, 0), reports.count);
        testing.expectEqualStrings(expected, got) catch |err| {
            std.debug.print("world script: {s}\n", .{source});
            return err;
        };
    }
};

// ---- green side: a reachable target keeps every world's listeners -----------

fn reinsertedNodeKeepsListeners() !void {
    const p = try WorldPage.open();
    defer p.close();
    // The page's listener and handler and the world's listener, on one node.
    try p.page.run(
        \\globalThis.fired = 0;
        \\(() => {
        \\  const d = document.body.appendChild(document.createElement('div'));
        \\  d.id = 'w';
        \\  d.addEventListener('ping', () => { globalThis.fired += 1; });
        \\  d.onclick = () => { globalThis.fired += 100; };
        \\})();
    );
    try p.inWorld(
        \\globalThis.worldFired = 0;
        \\globalThis.held = document.getElementById('w');
        \\held.addEventListener('ping', () => { globalThis.worldFired += 1; });
    );
    // The page detaches it and keeps no reference: only the world's script
    // holds the node now.
    try p.page.run("document.getElementById('w').remove();");
    try p.page.settle();
    // The world puts it back; the page reaches it again.
    try p.inWorld("document.body.appendChild(held); delete globalThis.held;");
    try p.page.settle();
    try p.page.run(
        \\const d = document.getElementById('w');
        \\d.dispatchEvent(new Event('ping'));
        \\if (typeof d.onclick === 'function') d.click();
    );
    try p.page.expect("String(globalThis.fired)", "101");
    try p.expectInWorld("String(globalThis.worldFired)", "1");
}
test "a node only a world held while detached keeps the page's and the world's listeners when it is put back" {
    try probe.onFreshThread(reinsertedNodeKeepsListeners);
}

/// The page hands `t` - a target it then lets go - to the world through an
/// event's detail (a platform object reaches another world as that world's
/// wrapper of it: protocol_worlds.acrossWorlds).
const hand_to_world =
    \\document.body.dispatchEvent(new CustomEvent('hand', { detail: t }));
;
const world_takes =
    \\globalThis.held = null;
    \\document.body.addEventListener('hand', (e) => { globalThis.held = e.detail; });
;

fn pageTargetHeldByWorldListenerFirst() !void {
    const p = try WorldPage.open();
    defer p.close();
    try p.inWorld(world_takes);
    // The listener is added before the world has a wrapper of the target:
    // the world's wrapper, made at the hand-over, gets the set drawn onto it.
    try p.page.run("globalThis.fired = 0;\n(() => {\n  const t = new EventTarget();\n  t.addEventListener('ping', () => { globalThis.fired++; });\n" ++ hand_to_world ++ "\n})();");
    try p.expectInWorld("String(held instanceof EventTarget)", "true");
    try p.page.settle();
    try p.inWorld("held.dispatchEvent(new Event('ping'));");
    try p.page.expect("String(globalThis.fired)", "1");
}
test "a page's EventTarget only a world holds keeps the listener the page added before handing it over" {
    try probe.onFreshThread(pageTargetHeldByWorldListenerFirst);
}

fn pageTargetHeldByWorldListenerAfter() !void {
    const p = try WorldPage.open();
    defer p.close();
    try p.inWorld(world_takes);
    // The world wraps the target first; the page's listener comes after, and
    // must reach the world's wrapper too.
    try p.page.run("globalThis.fired = 0;\n(() => {\n  const t = new EventTarget();\n" ++ hand_to_world ++ "\n  t.addEventListener('ping', () => { globalThis.fired++; });\n})();");
    try p.page.settle();
    try p.inWorld("held.dispatchEvent(new Event('ping'));");
    try p.page.expect("String(globalThis.fired)", "1");
}
test "a page's EventTarget only a world holds keeps a listener the page added after the world wrapped it" {
    try probe.onFreshThread(pageTargetHeldByWorldListenerAfter);
}

fn worldTargetHeldByPage() !void {
    const p = try WorldPage.open();
    defer p.close();
    try p.page.run(
        \\globalThis.held = null;
        \\document.body.addEventListener('hand', (e) => { globalThis.held = e.detail; });
    );
    // The world makes a target, listens to it, hands it to the page and lets
    // it go: only the page holds it.
    try p.inWorld(
        \\globalThis.worldFired = 0;
        \\(() => {
        \\  const t = new EventTarget();
        \\  t.addEventListener('ping', () => { globalThis.worldFired++; });
        \\  document.body.dispatchEvent(new CustomEvent('hand', { detail: t }));
        \\})();
    );
    try p.page.expect("String(held instanceof EventTarget)", "true");
    try p.page.settle();
    try p.page.run("held.dispatchEvent(new Event('ping'));");
    try p.expectInWorld("String(globalThis.worldFired)", "1");
}
test "a world's EventTarget only the page holds keeps the world's listener" {
    try probe.onFreshThread(worldTargetHeldByPage);
}

fn worldObserverOfPageNode() !void {
    const p = try WorldPage.open();
    defer p.close();
    try p.page.run("globalThis.kept = document.body.appendChild(document.createElement('div'));");
    // The world's observer, with no script reference to it: the node it
    // observes keeps it, and its callback is traced from its wrapper.
    try p.inWorld(
        \\globalThis.worldFired = 0;
        \\new MutationObserver(() => { globalThis.worldFired++; }).observe(document.body.lastChild, { attributes: true });
    );
    try p.page.settle();
    try p.page.run("kept.setAttribute('data-x', '1');");
    _ = try p.page.browser.runEventLoopBlocking(20);
    try p.expectInWorld("String(globalThis.worldFired)", "1");
}
test "a world's MutationObserver of a page node delivers after collections, with no script reference to it" {
    try probe.onFreshThread(worldObserverOfPageNode);
}

fn worldObserverOfWorldNode() !void {
    const p = try WorldPage.open();
    defer p.close();
    // A node only the world ever wrapped (the page never saw it), which the
    // world holds; the world's observer of it has no script reference: the
    // node's registered observer list keeps it (DOM 4.3; Blink traces the
    // registration from the node, whichever world's wrapper keeps the node).
    try p.inWorld(
        \\globalThis.worldFired = 0;
        \\globalThis.held = document.createElement('div');
        \\new MutationObserver(() => { globalThis.worldFired++; }).observe(held, { attributes: true });
    );
    try p.page.settle();
    try p.inWorld("held.setAttribute('data-x', '1');");
    _ = try p.page.browser.runEventLoopBlocking(20);
    try p.expectInWorld("String(globalThis.worldFired)", "1");
}
test "a world's MutationObserver of a node only the world wrapped delivers after collections, with no script reference to it" {
    try probe.onFreshThread(worldObserverOfWorldNode);
}

// ---- red side: a cycle through a world wrapper is collected ------------------

/// 500 rounds of `body` run in the WORLD; nothing it makes is reachable from
/// any script after the loop, so every instance it made must be collected.
fn worldCycleCollected(comptime body: []const u8, comptime label: []const u8) !void {
    const p = try WorldPage.open();
    defer p.close();
    try p.inWorld("for (let i = 0; i < 500; i++) {\n" ++ body ++ "\n}\n");
    try p.page.settle();
    const grown = p.page.grown();
    std.debug.print("{s}: {d} instances alive after settling (500 rounds)\n", .{ label, grown });
    try testing.expect(grown <= slack);
}

fn worldListenerCycle() !void {
    try worldCycleCollected(
        \\  const root = document.createElement('div');
        \\  root.appendChild(document.createElement('span'));
        \\  root.addEventListener('x', () => root);
    , "a world's listener closing over its detached target");
}
fn worldHandlerCycle() !void {
    try worldCycleCollected(
        \\  const root = document.body.appendChild(document.createElement('div'));
        \\  root.appendChild(document.createElement('span'));
        \\  root.onclick = () => root;
        \\  root.remove();
    , "a world's on* handler closing over its node, the node removed from the document");
}
fn worldPlainTargetCycle() !void {
    try worldCycleCollected(
        \\  const target = new EventTarget();
        \\  target.addEventListener('x', () => target);
    , "a world's listener closing over its EventTarget (not a node)");
}
fn worldObserverCycle() !void {
    try worldCycleCollected(
        \\  const root = document.createElement('div');
        \\  root.appendChild(document.createElement('span'));
        \\  const mo = new MutationObserver(() => [mo, root]);
        \\  mo.observe(root, { attributes: true, subtree: true });
    , "a world's MutationObserver callback closing over its observer and its detached target");
}
fn pageNodeWorldListenerCycle() !void {
    const p = try WorldPage.open();
    defer p.close();
    // The page makes the trees and lets them go; the world's listener on each
    // closes over it. Both worlds wrapped every root.
    try p.page.run(
        \\globalThis.roots = [];
        \\for (let i = 0; i < 500; i++) {
        \\  const root = document.createElement('div');
        \\  root.appendChild(document.createElement('span'));
        \\  roots.push(root);
        \\}
    );
    try p.inWorld(
        \\// The page's array does not cross worlds; its nodes do, one by one.
        \\document.body.addEventListener('one', (e) => {
        \\  const root = e.detail;
        \\  root.addEventListener('x', () => root);
        \\});
    );
    try p.page.run("for (const root of roots) document.body.dispatchEvent(new CustomEvent('one', { detail: root }));\ndelete globalThis.roots;");
    try p.page.settle();
    const grown = p.page.grown();
    std.debug.print("page trees with a world's self-capturing listener: {d} instances alive after settling (500 trees)\n", .{grown});
    try testing.expect(grown <= slack);
}

test "a world's listener that closes over its detached target does not pin the tree" {
    try probe.onFreshThread(worldListenerCycle);
}
test "a world's on* handler that closes over its removed node does not pin it" {
    try probe.onFreshThread(worldHandlerCycle);
}
test "a world's listener that closes over its non-node EventTarget does not pin it" {
    try probe.onFreshThread(worldPlainTargetCycle);
}
test "a world's MutationObserver callback that captures its observer and its target does not pin either" {
    try probe.onFreshThread(worldObserverCycle);
}
test "a world's listener closing over a page-made node both worlds wrapped does not pin the tree" {
    try probe.onFreshThread(pageNodeWorldListenerCycle);
}
