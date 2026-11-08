//! Lane perf2, batch 2 (tmp/plans/perf2b2-design.md): a node type's internal
//! state is found through its instance's own generated State
//! (`runtime.OwnState`), no longer through a hash table keyed by the
//! instance's address. These pin the behaviour that move must keep - identity,
//! teardown and lifetime under collection - for every node type that moved:
//!
//! - a node in a tree keeps every state of its chain while its wrapper is
//!   collected and its slot's neighbours are freed and reissued;
//! - a slot freed and issued again starts with no state of the dead object;
//! - a node torn down under a wrapper that outlives it answers every read the
//!   same way twice (never reads what was freed);
//! - an EventTarget whose impl never chains EventTarget's init (Performance)
//!   keeps its listeners, which its realm's end releases;
//! - dom.instance_bridge answers a node's NodeBase, and null for a non-node.
//!
//! The Browser runs on std.testing.allocator, so a state, a string or a
//! NodeBase left at its end fails the test. Each test runs on a thread of its
//! own (tests/html is one executable; an agent belongs to its thread).
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectEvaluates(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluate(source);
    defer testing.allocator.free(got);
    testing.expectEqualStrings(expected, got) catch |err| {
        std.debug.print("evaluating: {s}\n", .{source});
        return err;
    };
}

fn statesSurviveTheirWrappers() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // One node of every moved type, each with state of its own, kept only by
    // the tree: the script's references die with the IIFE.
    try page.run(
        \\globalThis.fired = 0;
        \\(() => {
        \\  const host = document.body.appendChild(document.createElement('section'));
        \\  host.id = 'host';
        \\  host.innerHTML = '<div id=d class="a b" data-k=v title=t>text<!--note--></div>' +
        \\    '<a id=link href="http://example.test/x?y#z">a</a><map><area id=ar href="http://example.test/area"></map>' +
        \\    '<template id=tpl><p class=inside>in</p></template>' +
        \\    '<svg><script id=svs>void 0</script></svg>';
        \\  const d = document.getElementById('d');
        \\  d.addEventListener('ping', () => { globalThis.fired++; });
        \\  d.setAttribute('data-extra', 'e'.repeat(64));
        \\  const shadowHost = host.appendChild(document.createElement('div'));
        \\  shadowHost.id = 'sh';
        \\  const root = shadowHost.attachShadow({ mode: 'open' });
        \\  root.innerHTML = '<slot name=s1></slot><span>shadow</span>';
        \\  const slotted = shadowHost.appendChild(document.createElement('b'));
        \\  slotted.slot = 's1';
        \\  const fragment = document.createDocumentFragment();
        \\  fragment.appendChild(document.createTextNode('from a fragment'));
        \\  host.appendChild(fragment);
        \\})();
    );
    try page.turn();
    // Collect every wrapper nothing holds, then free and reissue slots with
    // new nodes, twice.
    try page.run("collectNow(); collectNow();");
    try expectEvaluates(page,
        \\(() => {
        \\  const d = document.getElementById('d');
        \\  const out = [d.className, d.getAttribute('data-k'), d.title, d.getAttribute('data-extra').length,
        \\    d.firstChild.data, d.lastChild.data, d.attributes.length, d.parentNode.id];
        \\  d.dispatchEvent(new Event('ping'));
        \\  out.push(globalThis.fired);
        \\  const a = document.getElementById('link');
        \\  out.push(a.pathname, a.search, a.hash);
        \\  out.push(new URL(document.getElementById('ar').href).pathname);
        \\  out.push(document.getElementById('tpl').content.firstChild.className);
        \\  out.push(document.getElementById('svs').textContent);
        \\  const sh = document.getElementById('sh');
        \\  out.push(sh.shadowRoot.lastChild.textContent, sh.shadowRoot.firstChild.name);
        \\  out.push(sh.shadowRoot.firstChild.assignedNodes().length, sh.lastChild.assignedSlot.name);
        \\  out.push(document.getElementById('host').lastChild.data);
        \\  out.push(document.doctype.name);
        \\  return out.join('|');
        \\})()
    , "a b|v|t|64|text|note|5|host|1|/x|?y|#z|/area|inside|void 0|shadow|s1|1|s1|from a fragment|html");
}

test "every moved node type keeps its state while its wrapper is collected and slots around it are reissued" {
    try helpers.onFreshThread(statesSurviveTheirWrappers);
}

fn reissuedSlotsStartClean() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Nodes with state of every kind, dropped: their slots go back to the
    // slab, LIFO, and the next nodes made take them.
    try page.run(
        \\globalThis.fired = 0;
        \\(() => {
        \\  for (let i = 0; i < 300; i++) {
        \\    const div = document.createElement('div');
        \\    div.id = 'dead' + i;
        \\    div.className = 'dead';
        \\    div.setAttribute('data-dead', String(i));
        \\    div.addEventListener('ping', () => { globalThis.fired++; });
        \\    div.appendChild(document.createTextNode('dead text ' + i));
        \\    document.createComment('dead comment');
        \\    const a = document.createElement('a');
        \\    a.href = 'http://example.test/dead/' + i;
        \\  }
        \\})();
    );
    try page.turn();
    try page.run("TestUtils.gc(); TestUtils.gc();");
    try expectEvaluates(page,
        \\(() => {
        \\  let bad = 0;
        \\  for (let i = 0; i < 300; i++) {
        \\    const div = document.createElement('div');
        \\    if (div.id !== '' || div.className !== '' || div.attributes.length !== 0 || div.firstChild !== null) bad++;
        \\    div.dispatchEvent(new Event('ping'));
        \\    const text = document.createTextNode('');
        \\    if (text.data !== '') bad++;
        \\    const a = document.createElement('a');
        \\    if (a.href !== '' || a.getAttribute('href') !== null) bad++;
        \\  }
        \\  return bad + ' ' + globalThis.fired;
        \\})()
    , "0 0");
}

test "a slot freed and issued again starts with no state of the dead node" {
    try helpers.onFreshThread(reissuedSlotsStartClean);
}

fn tornDownUnderASurvivingWrapper() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Nodes of a frame's document, held by the parent's script: the frame's
    // removal ends its realm, whose teardown frees its tree while these
    // wrappers live on in the parent.
    try page.run(
        \\const frame = document.body.appendChild(document.createElement('iframe'));
        \\const fd = frame.contentDocument;
        \\fd.body.innerHTML = '<p id=x class=c data-k=v>x<!--c--></p>';
        \\globalThis.kept = { p: fd.getElementById('x') };
        \\kept.text = kept.p.firstChild;
        \\kept.comment = kept.p.lastChild;
        \\kept.p.addEventListener('ping', () => {});
        \\frame.remove();
    );
    try page.turn();
    try page.run("collectNow(); collectNow();");
    // Whatever each read answers - a value, or an exception - it answers the
    // same the second time: nothing freed is read back.
    try page.run(
        \\const reads = [
        \\  () => kept.p.id, () => kept.p.className, () => kept.p.getAttribute('data-k'), () => kept.p.attributes.length,
        \\  () => kept.p.parentNode, () => kept.p.firstChild, () => kept.text.data, () => kept.comment.data,
        \\  () => kept.p.dispatchEvent(new Event('ping')), () => kept.p.isConnected,
        \\];
        \\const answer = (read) => { try { const v = read(); return 'ok:' + (v === null ? 'null' : typeof v === 'object' ? 'object' : String(v)); } catch (e) { return 'threw:' + e.name; } };
        \\const first = reads.map(answer).join('|');
        \\collectNow();
        \\const second = reads.map(answer).join('|');
        \\if (first !== second) throw new Error('reads changed: ' + first + ' then ' + second);
    );
    try page.run("delete globalThis.kept; TestUtils.gc(); TestUtils.gc();");
    try page.turn();
}

test "a node torn down under a wrapper that outlives it answers every read the same way twice" {
    try helpers.onFreshThread(tornDownUnderASurvivingWrapper);
}

fn lazyEventTargetKeepsItsListeners() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Performance's impl never chains EventTarget's init: its listener list
    // is made on first use and released by its realm's end.
    try page.run(
        \\globalThis.marks = 0;
        \\performance.addEventListener('perf2', () => { globalThis.marks++; });
        \\performance.dispatchEvent(new Event('perf2'));
        \\collectNow();
        \\performance.dispatchEvent(new Event('perf2'));
        \\if (globalThis.marks !== 2) throw new Error('listener lost: ' + globalThis.marks);
    );
    try page.turn();
}

test "an EventTarget whose impl never chains EventTarget's init keeps its listeners" {
    try helpers.onFreshThread(lazyEventTargetKeepsItsListeners);
}

fn bridgeAnswersNodesOnly() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const context = page.browser.current_context orelse return error.NoPage;
    const document = context.document_instance orelse return error.NoDocument;
    const scope = page.browser.scope;

    // The document's NodeBase is its own, and names it back.
    const document_base = dom.instance_bridge.getNodeBase(@ptrCast(document)) orelse return error.NoNodeBase;
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(document)), document_base.ownerInstance());

    // A non-node platform object has none.
    const window = context.window_instance orelse return error.NoWindow;
    try testing.expect(dom.instance_bridge.getNodeBase(@ptrCast(window)) == null);

    // Every node made counts once, and its teardown takes it back out. What
    // the page's load let go of is collected first, so the count is the
    // page's own.
    try page.run("TestUtils.gc(); TestUtils.gc();");
    try page.turn();
    const before = dom.instance_bridge.entryCount(scope);
    try page.run("globalThis.made = []; for (let i = 0; i < 10; i++) made.push(document.createElement('i'));");
    try testing.expectEqual(before + 10, dom.instance_bridge.entryCount(scope));
    try page.run("delete globalThis.made; TestUtils.gc(); TestUtils.gc();");
    try page.turn();
    try testing.expectEqual(before, dom.instance_bridge.entryCount(scope));
    try testing.expectEqual(@as(usize, 0), dom.instance_bridge.deadSlotLookups(scope));
    _ = runtime;
}

test "dom.instance_bridge answers a node's NodeBase, null for a non-node, and counts nodes as they come and go" {
    try helpers.onFreshThread(bridgeAnswersNodesOnly);
}
