//! DOM "move" (moveBefore) keeps a node's state: lane move1 batch 1
//! (tmp/plans/move1-design.md). Each case runs on a fresh Browser on a thread
//! of its own and reads its answers back as one JSON string, so a failure
//! shows every answer at once.
//!
//! Spec: https://dom.spec.whatwg.org/#move
//! Spec: https://dom.spec.whatwg.org/#dom-parentnode-movebefore
const std = @import("std");
const Browser = @import("browser").Browser;

fn exercise(comptime html: []const u8, comptime source: []const u8, expected: []const u8) !void {
    const browser = try Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://move1.test/", .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoContext;
    try context.loadHTML("<!doctype html>" ++ html, .{ .base_url = "https://move1.test/" });
    const text = try context.evaluateScriptToString(source, std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn fresh(comptime html: []const u8, comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, result: *?anyerror) void {
            exercise(html, source, want) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &result });
    thread.join();
    if (result) |err| return err;
}

// Move steps 13 and 20-21: the child list, both ends and the sibling links of
// both parents, for a move to the front, within a parent, and across parents.
test "moveBefore keeps both parents' child lists and sibling links" {
    try fresh("<body><div id=p><i id=a></i><i id=b></i><i id=c></i></div><div id=q></div></body>",
        \\const ids = n => [...n.childNodes].map(c => c.id).join('');
        \\const ends = n => (n.firstChild ? n.firstChild.id : '-') + (n.lastChild ? n.lastChild.id : '-');
        \\const links = n => [...n.childNodes].map(c => (c.previousSibling ? c.previousSibling.id : '-') + (c.nextSibling ? c.nextSibling.id : '-')).join(' ');
        \\const out = [];
        \\p.moveBefore(c, a); out.push(ids(p), ends(p), links(p));
        \\p.moveBefore(c, null); out.push(ids(p), ends(p), links(p));
        \\p.moveBefore(b, b); out.push(ids(p));
        \\q.moveBefore(a, null); out.push(ids(p), ends(p), links(p), ids(q), ends(q), a.parentNode.id);
        \\q.moveBefore(c, a); out.push(ids(p), ends(p), ids(q), ends(q), links(q));
        \\q.moveBefore(b, null); out.push(ids(p), ends(p), p.childNodes.length, ids(q), ends(q), links(q));
        \\JSON.stringify(out);
    , "[\"cab\",\"cb\",\"-a cb a-\",\"abc\",\"ac\",\"-b ac b-\",\"abc\",\"bc\",\"bc\",\"-c b-\",\"a\",\"aa\",\"q\",\"b\",\"bb\",\"ca\",\"ca\",\"-a c-\",\"\",\"--\",0,\"cab\",\"cb\",\"-a cb a-\"]");
}

// Move steps 1-3, in order: different shadow-including roots (a disconnected
// parent, a connected node; a detached node, a connected parent), then the
// host-including ancestor check before the reference child's parent check.
test "moveBefore throws HierarchyRequestError before NotFoundError and across roots" {
    try fresh("<body><div id=target></div><div id=child></div></body>",
        \\const name = f => { try { f(); return 'none'; } catch (e) { return e.name; } };
        \\const target = document.getElementById('target'), child = document.getElementById('child');
        \\const detached = document.createElement('div');
        \\const loose = document.createElement('p'); detached.append(loose);
        \\const inner = document.createElement('div'); child.append(inner);
        \\JSON.stringify([
        \\  name(() => detached.moveBefore(target, null)),
        \\  name(() => document.body.moveBefore(loose, null)),
        \\  name(() => document.body.moveBefore(document.documentElement, inner)),
        \\  name(() => target.moveBefore(child, inner)),
        \\  name(() => document.body.moveBefore(document.createTextNode('x'), null)),
        \\  target.parentNode === document.body && child.parentNode === document.body,
        \\]);
    , "[\"HierarchyRequestError\",\"HierarchyRequestError\",\"HierarchyRequestError\",\"NotFoundError\",\"HierarchyRequestError\",true]");
}

// Move step 25: moving steps instead of removing and insertion steps; 25.3
// connectedMoveCallback, and HTML's fallback to disconnected + connected when
// the definition has none.
test "moveBefore enqueues connectedMoveCallback, or disconnected and connected without one" {
    try fresh("<body><div id=a></div><div id=b></div></body>",
        \\const log = [];
        \\customElements.define('x-move', class extends HTMLElement {
        \\  connectedCallback() { log.push('connected'); }
        \\  disconnectedCallback() { log.push('disconnected'); }
        \\  connectedMoveCallback() { log.push('move'); }
        \\});
        \\customElements.define('x-plain', class extends HTMLElement {
        \\  connectedCallback() { log.push('plain-connected'); }
        \\  disconnectedCallback() { log.push('plain-disconnected'); }
        \\});
        \\const m = document.createElement('x-move'); const p = document.createElement('x-plain');
        \\a.append(m, p); log.length = 0;
        \\b.moveBefore(m, null); b.moveBefore(p, null);
        \\const nested = document.createElement('div'); a.append(nested); nested.append(document.createElement('x-move'));
        \\log.push('|'); b.moveBefore(nested, null);
        \\JSON.stringify(log);
    , "[\"move\",\"plain-disconnected\",\"plain-connected\",\"connected\",\"|\",\"move\"]");
}

// No removing steps: a modal dialog stays modal, an open popover stays open,
// an iframe keeps its navigable's document and a running CSS animation is the
// same animation (Blink skips each of these resets during an atomic move).
test "moveBefore keeps the top layer, an iframe's document and a running animation" {
    try fresh(
        \\<style>@keyframes spin { from { margin-left: 0px } to { margin-left: 100px } } #anim { animation: spin 10s linear infinite }</style>
        \\<body><section id=a><dialog id=d></dialog><div id=pop popover>x</div><iframe id=f></iframe><div id=anim></div></section><section id=b></section></body>
    ,
        \\d.showModal(); pop.showPopover();
        \\const doc = f.contentDocument; const animation = anim.getAnimations()[0];
        \\b.moveBefore(d, null); b.moveBefore(pop, null); b.moveBefore(f, null); b.moveBefore(anim, null);
        \\JSON.stringify([d.matches(':modal'), d.open, pop.matches(':popover-open'), f.contentDocument === doc, anim.getAnimations().length, anim.getAnimations()[0] === animation, animation.playState]);
    , "[true,true,true,true,1,true,\"running\"]");
}

// Children changed steps run with the move's reason (a stated deviation from
// DOM move, which runs none - Blink's ChildrenChanged and Gecko's
// ContentInserted both run on a move): a style element takes the moved text,
// and neither script element prepares for it.
test "moveBefore updates a style element's sheet and prepares no script" {
    try fresh("<body><style id=s></style><script id=hs></script><svg><script id=ss></script></svg><div id=t></div><div id=holder></div></body>",
        \\window.ran = [];
        \\const css = document.createTextNode('#t { color: rgb(0, 128, 0) }');
        \\const js1 = document.createTextNode('ran.push("html")');
        \\const js2 = document.createTextNode('ran.push("svg")');
        \\holder.append(css, js1, js2);
        \\s.moveBefore(css, null); hs.moveBefore(js1, null); ss.moveBefore(js2, null);
        \\const color = getComputedStyle(t).color;
        \\holder.moveBefore(css, null);
        \\JSON.stringify([color, getComputedStyle(t).color, ran]);
    , "[\"rgb(0, 128, 0)\",\"rgb(0, 0, 0)\",[]]");
}

// Lifetime: a node a live range and a NodeIterator hold, moved back and forth,
// then dropped and collected, on a Browser of its own over a DebugAllocator
// that poisons what it frees (tests/AGENTS.md): any read of a freed node or
// list slot faults, and anything the moves leaked fails the check. The range
// and the iterator follow DOM move steps 9-10 (the pre-remove steps).
test "a moved node a range and an iterator hold survives the moves and is freed once" {
    const Run = struct {
        fn run(result: *?anyerror) void {
            var debug_allocator: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
            steps(debug_allocator.allocator()) catch |err| {
                result.* = err;
            };
            if (debug_allocator.deinit() == .leak and result.* == null) result.* = error.Leaked;
        }
        fn steps(allocator: std.mem.Allocator) !void {
            const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigateWithOptions("https://move1.test/", .window, .{ .skip_load = true });
            const context = browser.current_context orelse return error.NoContext;
            try context.loadHTML("<!doctype html><body><div id=p></div><div id=q></div></body>", .{ .base_url = "https://move1.test/" });
            const text = try context.evaluateScriptToString(
                \\const p = document.getElementById('p'), q = document.getElementById('q');
                \\let moved = document.createElement('div'); moved.innerHTML = '<b>x</b><i>y</i>'; p.append(moved);
                \\let range = document.createRange(); range.setStart(moved.firstChild, 0); range.setEnd(moved.lastChild, 0);
                \\let it = document.createNodeIterator(document.body);
                \\while (it.nextNode() !== moved.lastChild) {}
                \\for (let k = 0; k < 200; k++) { q.moveBefore(moved, null); p.moveBefore(moved, null); }
                \\const out = [range.startContainer === p, range.startOffset, range.collapsed, it.referenceNode === p, moved.parentNode === p, p.firstChild === moved, q.firstChild];
                \\moved.remove(); moved = null; range = null; it = null;
                \\TestUtils.gc(); TestUtils.gc();
                \\JSON.stringify(out);
            , allocator);
            defer allocator.free(text);
            try std.testing.expectEqualStrings("[true,0,true,true,true,true,null]", text);
            _ = try browser.runEventLoopBlocking(50);
            const after = try context.evaluateScriptToString("TestUtils.gc(); String(document.body.childNodes.length)", allocator);
            defer allocator.free(after);
            try std.testing.expectEqualStrings("2", after);
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}
