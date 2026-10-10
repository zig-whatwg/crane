//! Step 1 of the reference-counting migration (lane rc12,
//! tmp/plans/refcount-design.md section 7): the retention the migration must
//! fix, and the lifetime it must keep, measured as live instances after the
//! page settles (tests/html/refcount_probe.zig).
//!
//! RED today (known red until their step, see the probe's `knownRed`):
//! - a never-wrapped detached subtree is freed by nothing before its realm
//!   ends (RETENTION; the 45,000-node control of lane nodeholds);
//! - a closure over its own detached target pins the target's tree through the
//!   listener's or observer callback's strong root (decision D7).
//! GREEN today, must stay green:
//! - a held node keeps its whole tree and the tree goes when the hold ends
//!   (decision D1, script-held and natively held);
//! - a windowless document is kept through a node of it and freed after
//!   (decision D6);
//! - the control: wrapped, discarded nodes are collected.
const std = @import("std");
const testing = std.testing;
const probe = @import("refcount_probe.zig");
const Page = probe.Page;

/// Not a regression bound against a control: absolute. The page's own
/// instances come and go by a few; a tree is 45 nodes or more.
const slack: usize = 64;

// ---- RETENTION -------------------------------------------------------------

/// 1,000 rounds of a 45-node tree parsed by innerHTML and replaced by the next
/// round: no node ever has a wrapper. The measured red on main (2a3f07d8d6) is
/// printed by the test.
fn neverWrappedTreesAreFreed() !void {
    const page = try Page.open("<div id=host></div>");
    defer page.close();
    try page.run(
        \\const host = document.getElementById('host');
        \\const markup = '<section><p><b>x</b></p><ul><li>1</li><li>2</li></ul></section>'.repeat(5);
        \\for (let i = 0; i < 1000; i++) host.innerHTML = markup;
        \\host.innerHTML = '';
    );
    try page.settle();
    const grown = page.grown();
    std.debug.print("innerHTML churn, 1,000 rounds x 45 nodes: {d} instances alive after settling\n", .{grown});
    try probe.knownRed(probe.migrated.switch_step7, grown <= slack, "never-wrapped detached subtrees are freed (RETENTION)");
}

test "1,000 innerHTML rounds free every tree they removed (never wrapped)" {
    try probe.onFreshThread(neverWrappedTreesAreFreed);
}

/// The same churn over ONE root a round, which script touches: the tree has a
/// wrapper, so the collector frees it today. The control that must stay green.
fn wrappedTreesAreFreed() !void {
    const page = try Page.open("<div id=host></div>");
    defer page.close();
    try page.run(
        \\const host = document.getElementById('host');
        \\const markup = '<section><p><b>x</b></p><ul><li>1</li><li>2</li></ul></section>';
        \\for (let i = 0; i < 1000; i++) { host.innerHTML = markup; void host.firstChild; }
        \\host.innerHTML = '';
    );
    try page.settle();
    const grown = page.grown();
    std.debug.print("innerHTML churn, a wrapped root a round: {d} instances alive after settling\n", .{grown});
    try testing.expect(grown <= slack);
}

test "control: wrapped discarded nodes are collected" {
    try probe.onFreshThread(createElementDiscardIsFreed);
    try probe.onFreshThread(wrappedTreesAreFreed);
}

fn createElementDiscardIsFreed() !void {
    const page = try Page.open("");
    defer page.close();
    try page.run(
        \\for (let i = 0; i < 5000; i++) {
        \\  const d = document.createElement('div');
        \\  d.appendChild(document.createElement('span'));
        \\}
    );
    try page.settle();
    const grown = page.grown();
    std.debug.print("5,000 createElement+discard: {d} instances alive after settling\n", .{grown});
    try testing.expect(grown <= slack);
}

// ---- D7: the listener cycle ------------------------------------------------

fn closureOverTarget(comptime attach: []const u8, comptime label: []const u8) !void {
    const page = try Page.open("");
    defer page.close();
    try page.run(
        "for (let i = 0; i < 500; i++) {\n" ++
            "  const root = document.createElement('div');\n" ++
            "  root.appendChild(document.createElement('span'));\n" ++
            "  " ++ attach ++ "\n" ++
            "}\n",
    );
    try page.settle();
    const grown = page.grown();
    std.debug.print("{s}: {d} instances alive after settling (500 trees of 2 nodes)\n", .{ label, grown });
    try probe.knownRed(probe.migrated.cycle_breakers_step8, grown <= slack, label);
}

fn listenerCycle() !void {
    try closureOverTarget("root.addEventListener('x', () => root);", "a listener closing over its detached target");
}
fn handlerCycle() !void {
    try closureOverTarget("root.onclick = () => root;", "an on* handler closing over its detached target");
}
fn observerCycle() !void {
    try closureOverTarget("new MutationObserver(() => root).observe(root, { childList: true, subtree: true });", "a MutationObserver callback closing over its observed target");
}

test "a listener that closes over its detached target does not pin the tree (D7)" {
    try probe.onFreshThread(listenerCycle);
}
test "an on* handler that closes over its detached target does not pin the tree (D7)" {
    try probe.onFreshThread(handlerCycle);
}
test "a MutationObserver callback that closes over its target does not pin the tree (D7)" {
    try probe.onFreshThread(observerCycle);
}

// ---- D1: a held node keeps its whole tree -----------------------------------

/// Script holds the DEEPEST node of a 100-node tree and lets the root go: the
/// whole tree must stay alive while it is held (natively: its instances), and
/// go when the hold ends.
fn scriptHeldDescendantKeepsTree() !void {
    const page = try Page.open("");
    defer page.close();
    try page.run(
        \\globalThis.held = (() => {
        \\  const root = document.createElement('div');
        \\  let at = root;
        \\  for (let i = 0; i < 24; i++) {
        \\    at.appendChild(document.createElement('i'));
        \\    at.appendChild(document.createElement('b'));
        \\    at.appendChild(document.createTextNode('t'));
        \\    at = at.appendChild(document.createElement('u'));
        \\  }
        \\  return at;
        \\})();
    );
    try page.settle();
    const kept = page.grown();
    try page.expect("(() => { let n = 0, at = held; while (at.parentNode) { at = at.parentNode; n++; } return n + ':' + at.localName; })()", "24:div");
    std.debug.print("script holds one deep node of a 97-node tree: {d} instances alive while held\n", .{kept});
    // GREEN today and after: the held node keeps the whole tree.
    try testing.expect(kept >= 97);
    try page.run("globalThis.held = null;");
    try page.settle();
    const freed = page.grown();
    std.debug.print("after the hold ends: {d} instances alive\n", .{freed});
    try testing.expect(freed <= slack);
}

test "D1 script-held: a held descendant keeps all 97 nodes of its tree and releases them" {
    try probe.onFreshThread(scriptHeldDescendantKeepsTree);
}

/// Native hold: a static NodeList over a detached tree script drops. The
/// list's nodes have no wrappers.
fn nativeHeldDescendantKeepsTree() !void {
    const page = try Page.open("");
    defer page.close();
    try page.run(
        \\globalThis.list = (() => {
        \\  const root = document.createElement('div');
        \\  root.innerHTML = '<section><p><b>x</b></p><ul><li>1</li><li>2</li></ul></section>'.repeat(5);
        \\  return root.querySelectorAll('li');
        \\})();
    );
    try page.settle();
    const kept = page.grown();
    std.debug.print("a static list holds 10 nodes of a 46-node detached tree: {d} instances alive while held\n", .{kept});
    try page.expect("list.length + ':' + list[0].parentNode.parentNode.localName + ':' + list[0].parentNode.parentNode.parentNode.localName", "10:section:div");
    // Held natively, with no wrapper for the node: the whole tree stays.
    try testing.expect(kept >= 46);
    try page.run("globalThis.list = null;");
    try page.settle();
    const freed = page.grown();
    std.debug.print("after the list is dropped: {d} instances alive\n", .{freed});
    try testing.expect(freed <= slack);
}

test "D1 native-held: a static list's node keeps all 46 nodes of its tree and releases them" {
    try probe.onFreshThread(nativeHeldDescendantKeepsTree);
}

// ---- D6: a document held through a detached node ----------------------------

fn documentHeldThroughDetachedNode() !void {
    const page = try Page.open("");
    defer page.close();
    try page.run(
        \\globalThis.node = (() => {
        \\  const doc = document.implementation.createHTMLDocument('rc-d6');
        \\  for (let i = 0; i < 30; i++) doc.body.appendChild(doc.createElement('p'));
        \\  const node = doc.body.appendChild(doc.createElement('em'));
        \\  node.remove();
        \\  return node;
        \\})();
    );
    try page.settle();
    const kept = page.grown();
    std.debug.print("a windowless document held through one detached node: {d} instances alive while held\n", .{kept});
    // The document and its 30 paragraphs stay. RED on main: the document is
    // freed under the node, and reading `node.ownerDocument` is a use after
    // free that crashes the process (SIGSEGV in template_registry.getTemplate,
    // via Node.get_ownerDocument). So the script is read only once the
    // property holds.
    const holds = kept >= 33;
    try probe.knownRed(probe.migrated.switch_step7, holds, "a windowless document is kept by a detached node of it (D6; reading it crashes today)");
    if (holds) try page.expect("node.ownerDocument.title + ':' + node.ownerDocument.body.childNodes.length", "rc-d6:30");
    try page.run("globalThis.node = null;");
    try page.settle();
    const freed = page.grown();
    std.debug.print("after the node is dropped: {d} instances alive\n", .{freed});
    try testing.expect(freed <= slack);
}

test "D6: a windowless document held only through a detached node keeps its tree and is freed after" {
    try probe.onFreshThread(documentHeldThroughDetachedNode);
}
