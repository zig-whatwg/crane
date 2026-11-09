//! A node keeps its node document alive for as long as the node lives (lane
//! ownerdoc). Blink's Node traces its tree scope (`Node::Trace` visits
//! `tree_scope_`, core/dom/node.cc), WebKit's counts itself on its document
//! (`Document::incrementReferencingNodeCount`). Crane's node counts itself on
//! its document (refcount: referencing nodes), and its wrapper keeps the
//! document's tree's wrappers through the walk (dom.wrapper_tracing, rule D6:
//! a node keeps its node document's tree). Until the wrapper redesign's P7 an
//! edge did that - from every node wrapper to its parent's, a root's to its
//! node document's (the engine adapter at wrap, the Node impl when adopt
//! changed the document); P7 deleted it, and the cases that read the edge
//! now check what it was for: the documents and trees script still reaches.
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

/// The completion of `source` is "true".
fn expectTrue(page: Page, source: []const u8) !void {
    const answer = try page.evaluate(source);
    defer testing.allocator.free(answer);
    testing.expectEqualStrings("true", answer) catch |err| {
        std.debug.print("does not hold: {s}\n", .{source});
        return err;
    };
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

fn aWrappedRootKeepsItsDocumentAndANodeItsTree() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.made = (() => {
        \\  const d = document.implementation.createHTMLDocument('od');
        \\  d.od = 'doc';
        \\  d.body.innerHTML = '<div><b></b></div>';
        \\  d.body.od = 'body';
        \\  d.body.firstChild.od = 'div';
        \\  return { root: d.createElement('p'), text: d.createTextNode('t'), inTree: d.body.firstChild.firstChild };
        \\})();
    );
    try collectAndTurn(page);
    // Roots script wrapped keep their document and its tree; a node in a
    // tree keeps its tree, and through it its document.
    try expectTrue(page, "String(made.root.ownerDocument.od === 'doc' && made.text.ownerDocument.body.od === 'body' && made.inTree.parentNode.od === 'div' && made.inTree.parentNode.parentNode.od === 'body')");
    // The removal that makes the div a root: it keeps its document still.
    try page.run("made.inTree.parentNode.remove(); made.root = null; made.text = null;");
    try collectAndTurn(page);
    try expectTrue(page, "String(made.inTree.parentNode.od === 'div' && made.inTree.parentNode.parentNode === null && made.inTree.ownerDocument.od === 'doc' && made.inTree.ownerDocument.body.od === 'body')");
}

test "a wrapped root keeps its node document, a node in a tree its tree" {
    try onFreshThread(aWrappedRootKeepsItsDocumentAndANodeItsTree);
}

fn aMovedNodeKeepsItsNewTree() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.a = document.body.appendChild(document.createElement('div'));
        \\globalThis.b = document.body.appendChild(document.createElement('div'));
        \\globalThis.node = a.appendChild(document.createElement('span'));
        \\globalThis.other = document.implementation.createHTMLDocument('other');
        \\other.od = 'other';
        \\other.body.appendChild(other.createElement('div')).od = 'c';
        \\a.od = 'a'; b.od = 'b';
    );
    // moveBefore: one step from parent to parent, no removal.
    try page.run("b.moveBefore(node, null); globalThis.b = null;");
    try collectAndTurn(page);
    try expectTrue(page, "String(node.parentNode.od === 'b')");
    // insertBefore from another parent: removed, then inserted.
    try page.run("a.insertBefore(node, null); globalThis.a = null;");
    try collectAndTurn(page);
    try expectTrue(page, "String(node.parentNode.od === 'a')");
    // Into another document's tree: removed, adopted, inserted.
    try page.run("other.body.firstChild.appendChild(node); globalThis.other = null;");
    try collectAndTurn(page);
    try expectTrue(page, "String(node.parentNode.od === 'c' && node.ownerDocument.od === 'other')");
    // Out of it: a root of that document now.
    try page.run("node.remove();");
    try collectAndTurn(page);
    try expectTrue(page, "String(node.parentNode === null && node.ownerDocument.od === 'other' && node.ownerDocument.body.firstChild.od === 'c')");
    try page.run("document.body.replaceChildren();");
}

test "a node moved between parents keeps its new tree" {
    try onFreshThread(aMovedNodeKeepsItsNewTree);
}

fn adoptKeepsTheNewDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.d1 = document.implementation.createHTMLDocument('one');
        \\globalThis.d2 = document.implementation.createHTMLDocument('two');
        \\d1.od = 'one'; d2.od = 'two';
        \\globalThis.moved = d1.createElement('section');
        \\d1.body.appendChild(moved);
        \\moved.innerHTML = '<p><i></i></p>';
        \\globalThis.deep = moved.firstChild.firstChild;
        \\deep.od = 'deep';
        \\globalThis.oldRef = new WeakRef(d1);
    );
    // Adopted: the root keeps the new document only, its descendants their
    // tree; script lets go of the old document, which goes.
    try page.run("d2.adoptNode(moved); globalThis.d1 = null; globalThis.d2 = null; globalThis.moved = null;");
    try collectAndTurn(page);
    try expectTrue(page, "String(deep.ownerDocument.od === 'two' && deep.parentNode.parentNode.ownerDocument.od === 'two' && deep.parentNode.parentNode.parentNode === null)");
    try expectTrue(page, "String(oldRef.deref() === undefined)");
    // Into the window's document by insertion (insert adopts).
    try page.run("globalThis.twoRef = new WeakRef(deep.ownerDocument); document.body.appendChild(deep.parentNode.parentNode);");
    try collectAndTurn(page);
    try expectTrue(page, "String(deep.ownerDocument === document && deep.parentNode.parentNode.parentNode === document.body && twoRef.deref() === undefined)");
    try page.run("document.body.replaceChildren();");
}

test "adopt moves a wrapped node to its new document and lets the old one go" {
    try onFreshThread(adoptKeepsTheNewDocument);
}

fn aHeldTreeKeepsItsDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.list = (() => {
        \\  const d = document.implementation.createHTMLDocument('od');
        \\  d.od = 'doc';
        \\  d.body.innerHTML = '<ol><li>1</li></ol>';
        \\  const list = d.body.querySelectorAll('li');
        \\  d.body.innerHTML = '';
        \\  return list;
        \\})();
    );
    // The removal left the ol a root no script reached, and script keeps
    // only the list: the list's trace keeps the li's trees - its own and
    // its node document's (refcount decision D6) - and wraps nothing for
    // them (the wrapper redesign's P6; the rescue that wrapped the ol and
    // drew its document edge is gone).
    try collectAndTurn(page);
    const answer = try page.evaluate("String(list[0].ownerDocument.od === 'doc' && list[0].parentNode.parentNode === null)");
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings("true", answer);
}

test "a tree a holder holds keeps its node document" {
    try onFreshThread(aHeldTreeKeepsItsDocument);
}

fn wrappingANodeWrapsNothingElse() !void {
    const page = try Page.open();
    defer page.close();
    // A document script has not seen (`new Document()`'s steps, run
    // natively), and a node of it.
    const doc = try interfaces.Document.call_constructor(try realmOf(page));
    const doc_generation = runtime.SlabAllocator.generationOf(doc);
    const text = try interfaces.Document.call_createTextNode(doc, runtime.DOMString.initInterned("native"));
    try testing.expect(!engine.hasWrapper(doc));
    try testing.expect(!engine.hasWrapper(text));
    const wrapped = try engine.createSequenceOfPlatformObjects(try realmOf(page), &.{text});
    defer wrapped.release();
    // The wrapper redesign's P7: the wrap makes the node's wrapper only - no
    // edge to its document, so no wrapper made for one. The text keeps its
    // document natively (its referencing-node count) and its wrapper keeps
    // the document's tree through the walk.
    try testing.expect(engine.hasWrapper(text));
    try testing.expect(!engine.hasWrapper(doc));
    try testing.expectEqual(doc_generation, runtime.SlabAllocator.generationOf(doc));
    // The native creator is done with the document.
    dom.node_creation.releaseIfUnwrapped(doc, doc_generation);
}

test "wrapping a node makes no wrapper for its document" {
    try onFreshThread(wrappingANodeWrapsNothingElse);
}
