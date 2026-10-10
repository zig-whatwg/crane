//! A node keeps its node document alive for as long as the node lives (lane
//! ownerdoc). Blink's Node traces its tree scope (`Node::Trace` visits
//! `tree_scope_`, core/dom/node.cc), WebKit's counts itself on its document
//! (`Document::incrementReferencingNodeCount`); Crane draws an edge from every
//! node wrapper to its node document's wrapper (dom.node_document.traced_slot:
//! the engine adapter at wrap, the Node impl when adopt changes the document).
//!
//! Before it, a node removed from a document script let go of read its freed
//! document: `ownerDocument` answered with whatever took the document's slab
//! slot - an element, a text node, another document - or crashed in the
//! template lookup of the wrap (refcount decision D6, rc12's red test).
//!
//! Each test runs a real Browser on a thread of its own (tests/html is one
//! executable; a Browser's agent belongs to the thread that made it).
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

fn realmOf(page: Page) !engine.Context {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.realm orelse error.NoRealm;
}

/// The platform object script's `expression` evaluates to.
fn instanceOf(page: Page, expression: []const u8) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    const value = try context.evaluateScript(expression);
    defer value.release();
    return engine.convertToPlatformObject(try realmOf(page), value.borrow()) orelse error.NotAPlatformObject;
}

/// `node`'s wrapper keeps `document`'s: the edge in the node document slot
/// names exactly that document's wrapper.
fn expectKeepsDocument(page: Page, node: *runtime.Instance, document: *runtime.Instance) !void {
    try testing.expect(engine.hasWrapper(node));
    const kept = engine.tracedValue(node, dom.node_document.traced_slot) orelse return error.NoNodeDocumentEdge;
    defer kept.release();
    try testing.expect(engine.sameValue(try realmOf(page), kept.borrow(), .{ .instance = document }));
}

/// Collect, let the deferred teardown free what was collected (it runs
/// between tasks), and collect again with the freed slots reissued.
fn collectAndTurn(page: Page) !void {
    try page.run("collectNow();");
    try page.turn();
    try page.run("collectNow();");
    try page.turn();
}

fn detachedNodesKeepTheirDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = document.implementation.createHTMLDocument('od');
        \\  doc.od = 'doc';
        \\  doc.body.od = 'body';
        \\  const removed = doc.body.appendChild(doc.createElement('p'));
        \\  removed.remove();
        \\  const parsed = doc.body.appendChild(doc.createElement('div'));
        \\  parsed.innerHTML = '<b>x</b>';
        \\  const b = parsed.firstChild;
        \\  parsed.innerHTML = '';
        \\  return { removed, text: doc.createTextNode('t'), b };
        \\})();
    );
    try collectAndTurn(page);
    try page.run(
        \\for (const [name, node] of Object.entries(kept)) {
        \\  const doc = node.ownerDocument;
        \\  if (doc.nodeType !== 9) throw new Error(name + ': ownerDocument is a ' + doc.nodeType);
        \\  if (doc.od !== 'doc') throw new Error(name + ': another document');
        \\  if (doc.body.od !== 'body') throw new Error(name + ': its tree went');
        \\  if (doc.createElement('i').ownerDocument !== doc) throw new Error(name + ': the document stopped working');
        \\}
    );
}

test "a detached node keeps its node document, with its tree" {
    try onFreshThread(detachedNodesKeepTheirDocument);
}

fn everyWrappedNodeKeepsItsDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.d = document.implementation.createHTMLDocument('od');
        \\globalThis.made = d.createElement('p');
        \\d.body.innerHTML = '<div><b></b></div>';
        \\globalThis.inTree = d.body.firstChild.firstChild;
        \\globalThis.text = d.createTextNode('t');
    );
    const doc = try instanceOf(page, "d");
    // Wrapped by script while detached, and while in the tree - and the
    // ancestor node tracing wrapped for it.
    try expectKeepsDocument(page, try instanceOf(page, "made"), doc);
    try expectKeepsDocument(page, try instanceOf(page, "inTree"), doc);
    try expectKeepsDocument(page, try instanceOf(page, "text"), doc);
    const in_tree = try instanceOf(page, "inTree");
    const div = (try interfaces.Node.get_parentNode(in_tree)) orelse return error.NoParent;
    try expectKeepsDocument(page, div, doc);
    // A document keeps none of its own.
    if (engine.tracedValue(doc, dom.node_document.traced_slot)) |self_edge| {
        self_edge.release();
        return error.DocumentKeepsItself;
    }
}

test "every wrapped node's wrapper keeps its node document's" {
    try onFreshThread(everyWrappedNodeKeepsItsDocument);
}

fn adoptReplacesTheEdge() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.d1 = document.implementation.createHTMLDocument('one');
        \\globalThis.d2 = document.implementation.createHTMLDocument('two');
        \\globalThis.moved = d1.body.appendChild(d1.createElement('section'));
        \\moved.innerHTML = '<p><i></i></p>';
        \\globalThis.deep = moved.firstChild.firstChild;
        \\globalThis.unseen = moved.firstChild;
    );
    const d1 = try instanceOf(page, "d1");
    const d2 = try instanceOf(page, "d2");
    const moved = try instanceOf(page, "moved");
    try expectKeepsDocument(page, moved, d1);
    try page.run("d2.adoptNode(moved)");
    // The node and every wrapped descendant now keep the new document only.
    try expectKeepsDocument(page, moved, d2);
    try expectKeepsDocument(page, try instanceOf(page, "deep"), d2);
    try expectKeepsDocument(page, try instanceOf(page, "unseen"), d2);
    // Into the window's document by insertion (insert adopts).
    try page.run("document.body.appendChild(moved)");
    try expectKeepsDocument(page, moved, try instanceOf(page, "document"));
    try page.run("moved.remove()");
}

test "adopt replaces a wrapped node's document edge" {
    try onFreshThread(adoptReplacesTheEdge);
}

fn aRescuedRootKeepsItsDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.d = document.implementation.createHTMLDocument('od');
        \\d.body.innerHTML = '<ol><li>1</li></ol>';
        \\globalThis.list = d.body.querySelectorAll('li');
        \\d.body.innerHTML = '';
    );
    // The removal left the ol a root no script reached: the list rescued it
    // (dom.node_holds), and the rescue's wrapper carries the edge.
    const list = try instanceOf(page, "list");
    const li = (try interfaces.NodeList.call_item(list, 0)) orelse return error.NoItem;
    const ol = (try interfaces.Node.get_parentNode(li)) orelse return error.NoParent;
    try expectKeepsDocument(page, ol, try instanceOf(page, "d"));
}

test "a root a holder rescues keeps its node document" {
    try onFreshThread(aRescuedRootKeepsItsDocument);
}

fn wrappingANodeWrapsItsDocument() !void {
    const page = try Page.open();
    defer page.close();
    // A document script has not seen (`new Document()`'s steps, run
    // natively), and a node of it.
    const doc = try interfaces.Document.call_constructor(try realmOf(page));
    const text = try interfaces.Document.call_createTextNode(doc, runtime.DOMString.initInterned("native"));
    try testing.expect(!engine.hasWrapper(doc));
    try testing.expect(!engine.hasWrapper(text));
    const wrapped = try engine.createSequenceOfPlatformObjects(try realmOf(page), &.{text});
    defer wrapped.release();
    try expectKeepsDocument(page, text, doc);
}

test "wrapping a node makes its document's wrapper for the edge" {
    try onFreshThread(wrappingANodeWrapsItsDocument);
}
