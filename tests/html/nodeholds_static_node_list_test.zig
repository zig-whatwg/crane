//! A static NodeList keeps its nodes for as long as script holds it, and only
//! then. Blink's StaticNodeList holds HeapVector<Member<Node>>, WebKit's
//! Vector<Ref<Node>>, natively; Crane's holds them natively too
//! (src/dom/node_holds.zig) and rescues - roots from the list's wrapper - the
//! root of a tree holding one of its nodes when that tree is not a document
//! with a window (lane nodeholds, tmp/plans/lane-nodeholds-handoff.md).
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

fn staticNodeListKeepsItsNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const list = (() => {
        \\  const root = document.createElement('div');
        \\  root.innerHTML = '<p><span id=a>a</span></p><span id=b>b</span>';
        \\  return root.querySelectorAll('span');
        \\})();
        \\collectNow();
        \\if (list.length !== 2) throw new Error('length');
        \\if (list[0].id !== 'a' || list[1].id !== 'b') throw new Error('nodes: ' + list[0].id + ',' + list[1].id);
        \\if (list[0].parentNode.parentNode.localName !== 'div') throw new Error('tree');
    );
    try page.run(
        \\globalThis.weak = [];
        \\(() => {
        \\  const root = document.createElement('div');
        \\  root.innerHTML = '<a></a><a></a>';
        \\  const list = root.querySelectorAll('a');
        \\  weak.push(new WeakRef(list[0]), new WeakRef(list[1]), new WeakRef(root));
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weak.some(ref => ref.deref() !== undefined)) throw new Error('a dropped static list still keeps its nodes');
    );
}

test "a static NodeList keeps its nodes while script holds it, and only then" {
    try onFreshThread(staticNodeListKeepsItsNodes);
}

fn listKeepsNodesThatLeaveTheDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.innerHTML = '<b id=c>c</b><b id=d>d</b><i><b id=e>e</b></i>';
        \\const list = host.querySelectorAll('b');
        \\(() => { const holder = document.createElement('section'); holder.append(...host.childNodes); })();
        \\collectNow();
        \\host.innerHTML = '<b>new</b>';
        \\collectNow();
        \\if (list.length !== 3) throw new Error('length');
        \\if (list[0].id !== 'c' || list[1].id !== 'd' || list[2].id !== 'e') throw new Error('nodes');
        \\if (list[0].parentNode.localName !== 'section' || list[2].parentNode.localName !== 'i') throw new Error('trees');
        \\if (list[2].parentNode.parentNode !== list[0].parentNode) throw new Error('one tree');
        \\host.remove();
    );
}

test "a static NodeList keeps nodes that leave the document after the snapshot" {
    try onFreshThread(listKeepsNodesThatLeaveTheDocument);
}

fn listKeepsAWindowlessDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const list = (() => {
        \\  const doc = document.implementation.createHTMLDocument('t');
        \\  doc.body.innerHTML = '<p id=w1>1</p><p id=w2>2</p>';
        \\  doc.ed = 'doc';
        \\  return doc.querySelectorAll('p');
        \\})();
        \\collectNow();
        \\if (list.length !== 2 || list[0].id !== 'w1' || list[1].id !== 'w2') throw new Error('nodes');
        \\if (list[0].ownerDocument.ed !== 'doc') throw new Error('its document, with its expando');
        \\if (list[0].ownerDocument.body !== list[1].parentNode) throw new Error('tree');
    );
}

test "a static NodeList of a document with no window keeps that document" {
    try onFreshThread(listKeepsAWindowlessDocument);
}

fn listKeepsAShadowTreeWhoseHostLeaves() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const list = (() => {
        \\  const host = document.body.appendChild(document.createElement('div'));
        \\  const shadow = host.attachShadow({ mode: 'closed' });
        \\  shadow.innerHTML = '<span>s1</span><span>s2</span>';
        \\  const found = shadow.querySelectorAll('span');
        \\  host.remove();
        \\  return found;
        \\})();
        \\collectNow();
        \\if (list.length !== 2 || list[0].textContent !== 's1' || list[1].textContent !== 's2') throw new Error('nodes');
        \\const root = list[0].getRootNode();
        \\if (!(root instanceof ShadowRoot) || root.host.localName !== 'div') throw new Error('its shadow tree and host');
    );
}

test "a static NodeList keeps a shadow tree whose host leaves the document" {
    try onFreshThread(listKeepsAShadowTreeWhoseHostLeaves);
}

fn listKeepsTemplateContents() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const list = (() => {
        \\  const template = document.createElement('template');
        \\  template.innerHTML = '<q>t1</q><q>t2</q>';
        \\  return template.content.querySelectorAll('q');
        \\})();
        \\collectNow();
        \\if (list.length !== 2 || list[0].textContent !== 't1' || list[1].textContent !== 't2') throw new Error('nodes');
    );
}

test "a static NodeList keeps the contents of a template script let go" {
    try onFreshThread(listKeepsTemplateContents);
}

fn aListAndTheTreeNamingItCollectTogether() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.weak = [];
        \\(() => {
        \\  const root = document.createElement('div');
        \\  root.innerHTML = '<a></a><a></a>';
        \\  root.list = root.querySelectorAll('a');
        \\  weak.push(new WeakRef(root), new WeakRef(root.list));
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weak.some(ref => ref.deref() !== undefined)) throw new Error('a list and the tree that names it were not collected');
    );
}

test "a static NodeList and the tree that names it are collected together" {
    try onFreshThread(aListAndTheTreeNamingItCollectTogether);
}

fn aHeldNodeMovedThroughTreesDoesNotRetainThemAll() !void {
    const page = try Page.open();
    defer page.close();
    // Each pass leaves the held node in a new detached tree and drops the
    // previous one. The list keeps the tree its node is in now - not every
    // tree it passed through.
    try page.run(
        \\globalThis.el = document.body.appendChild(document.createElement('mark'));
        \\globalThis.list = document.body.querySelectorAll('mark');
        \\globalThis.weak = [];
        \\for (let i = 0; i < 100; i++) {
        \\  const d = document.createElement('div');
        \\  weak.push(new WeakRef(d));
        \\  d.append(el);
        \\  document.body.append(d);
        \\  d.remove();
        \\}
        \\globalThis.last = new WeakRef(el.parentNode);
        \\el = null;
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\const alive = weak.filter(ref => ref.deref() !== undefined).length;
        \\if (alive > 70) throw new Error(alive + ' of 100 trees the node passed through are still alive');
        \\if (last.deref() === undefined || list[0].parentNode !== last.deref()) throw new Error('the tree the node is in now');
        \\if (list[0].localName !== 'mark') throw new Error('the node');
    );
}

test "a held node moved through many detached trees does not keep them all" {
    try onFreshThread(aHeldNodeMovedThroughTreesDoesNotRetainThemAll);
}
