//! Lane refcount7 (refcount design 1.2, "the creator of a node until it
//! hands the node on"): every creator hands the reference a node is born
//! with on, so a node's count is what its holders other than its creator
//! hold.
//!
//! WebKit's create functions return the `Ref` a node is born with, and the
//! binding moves it into the new wrapper (bindings/js/JSDOMWrapperCache.h
//! `createWrapper`: "domObject is moved into the wrapper"); a native
//! creator's `Ref` ends at its scope once the parent bit keeps the node.
//! So here: a node script made and keeps in a global counts 1 (its
//! wrapper's, which adopted the born reference - 2 before this lane), and a
//! node a native creator built into a tree, never wrapped, counts 0 (the
//! parent bit alone - 1 before). A Document's creator keeps its reference
//! (a navigable's, refcount step 5i) unless it hands the document to script.
//!
//! Children are read through the NodeBase links, never from script: a read
//! from script would wrap them.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;
const runtime = h.runtime;

fn firstChild(node: *dom.NodeBase) !*dom.NodeBase {
    return node.first_child orelse error.NoChild;
}

fn lastChild(node: *dom.NodeBase) !*dom.NodeBase {
    return node.last_child orelse error.NoChild;
}

/// The first element child of a document (its doctype skipped).
fn documentElement(document: *dom.NodeBase) !*dom.NodeBase {
    var child = document.first_child;
    while (child) |node| : (child = node.next_sibling) {
        if (node.node_type == dom.NodeBase.ELEMENT_NODE) return node;
    }
    return error.NoDocumentElement;
}

fn createMethodsHandTheirReferenceToTheWrapper() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.e = document.createElement('div');
        \\globalThis.ens = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        \\globalThis.t = document.createTextNode('x');
        \\globalThis.c = document.createComment('x');
        \\globalThis.f = document.createDocumentFragment();
        \\globalThis.pi = document.createProcessingInstruction('x', 'y');
        \\globalThis.a = document.createAttribute('x');
        \\globalThis.ans = document.createAttributeNS(null, 'y');
        \\globalThis.cd = new DOMParser().parseFromString('<r/>', 'application/xml').createCDATASection('x');
    );
    const names = [_][]const u8{ "e", "ens", "t", "c", "f", "pi", "a", "ans", "cd" };
    for (names) |name| try h.expectCount(1, try page.node(name), name);
}

test "Document's create methods hand the born reference to the node's wrapper" {
    try h.onFreshThread(createMethodsHandTheirReferenceToTheWrapper);
}

fn constructorsHandTheirReferenceToTheWrapper() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.t = new Text('x');
        \\globalThis.c = new Comment('x');
        \\globalThis.f = new DocumentFragment();
        \\globalThis.i = new Image();
        \\globalThis.o = new Option('x');
        \\customElements.define('x-rc7', class extends HTMLElement {});
        \\globalThis.x1 = new (customElements.get('x-rc7'))();
        \\globalThis.x2 = document.createElement('x-rc7');
        \\globalThis.nd = new Document();
    );
    const names = [_][]const u8{ "t", "c", "f", "i", "o", "x1", "x2", "nd" };
    for (names) |name| try h.expectCount(1, try page.node(name), name);
}

test "constructors, legacy factories and custom element construction hand the born reference to the wrapper" {
    try h.onFreshThread(constructorsHandTheirReferenceToTheWrapper);
}

fn cloningHandsItsReferencesOn() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.src = document.createElement('div');
        \\src.innerHTML = '<p><b>x</b></p>';
        \\globalThis.cl = src.cloneNode(true);
        \\globalThis.im = document.importNode(src, true);
        \\globalThis.dc = document.implementation.createHTMLDocument('t').cloneNode(true);
    );
    inline for (.{ "cl", "im" }) |name| {
        const root = try page.node(name);
        try h.expectCount(1, root, name ++ ": the returned clone, its wrapper's");
        const p = try firstChild(root);
        try h.expectCount(0, p, name ++ ": a cloned child, inserted");
        try h.expectCount(0, try firstChild(p), name ++ ": a cloned grandchild, inserted");
    }
    const dc = try page.node("dc");
    try h.expectCount(1, dc, "a cloned document: its wrapper's (the clone offered it)");
    try h.expectCount(0, try documentElement(dc), "the cloned document's element, inserted");
}

test "cloneNode and importNode hand the root's reference to its wrapper and the descendants' to the tree" {
    try h.onFreshThread(cloningHandsItsReferencesOn);
}

fn fragmentParsingHandsItsReferencesOn() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.d = document.createElement('div');
        \\d.innerHTML = '<p>1</p><s>2</s>';
        \\d.lastChild.outerHTML = '<u>3</u>';
        \\d.insertAdjacentHTML('beforeend', '<i>4</i>');
        \\globalThis.su = document.createElement('div');
        \\su.setHTMLUnsafe('<q>5</q>');
        \\globalThis.sh = document.createElement('div').attachShadow({ mode: 'open' });
        \\sh.innerHTML = '<em>6</em>';
        \\globalThis.rg = document.createRange();
        \\rg.selectNodeContents(document.body);
        \\globalThis.cf = rg.createContextualFragment('<kbd>7</kbd>');
    );
    const d = try page.node("d");
    try h.expectCount(0, try firstChild(d), "innerHTML: a parsed element, inserted");
    try h.expectCount(0, try firstChild(try firstChild(d)), "innerHTML: a parsed text node, inserted");
    try h.expectCount(0, (try firstChild(d)).next_sibling orelse return error.NoChild, "outerHTML: the replacement");
    try h.expectCount(0, try lastChild(d), "insertAdjacentHTML: the inserted element");
    try h.expectCount(0, try firstChild(try page.node("su")), "setHTMLUnsafe");
    const sh = try page.node("sh");
    try h.expectCount(1, sh, "attachShadow: the shadow root's insertion ended its creator's reference; its wrapper's");
    try h.expectCount(0, try firstChild(sh), "ShadowRoot.innerHTML");
    const cf = try page.node("cf");
    try h.expectCount(1, cf, "createContextualFragment: the returned fragment, its wrapper's");
    try h.expectCount(0, try firstChild(cf), "createContextualFragment: a parsed element, inserted");
}

test "the fragment parser's nodes hand their references to the tree, a returned fragment to its wrapper" {
    try h.onFreshThread(fragmentParsingHandsItsReferencesOn);
}

fn scriptFacingDocumentsHandTheirReferencesOn() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.hd = document.implementation.createHTMLDocument('t');
        \\globalThis.xd = document.implementation.createDocument('urn:x', 'r', null);
        \\globalThis.pd = new DOMParser().parseFromString('<p>x</p>', 'text/html');
        \\globalThis.px = new DOMParser().parseFromString('<r><c/></r>', 'application/xml');
        \\globalThis.ud = Document.parseHTMLUnsafe('<p>x</p>');
        \\const x = new XMLHttpRequest();
        \\x.open('GET', 'data:text/xml,<r><c/></r>', false);
        \\x.send();
        \\globalThis.rx = x.responseXML;
    );
    inline for (.{ "hd", "xd", "pd", "px", "ud", "rx" }) |name| {
        const document = try page.node(name);
        try h.expectCount(1, document, name ++ ": the returned document, its wrapper's (its creator offered it)");
        const element = try documentElement(document);
        try h.expectCount(0, element, name ++ ": its document element, inserted");
    }
    try h.expectCount(0, try firstChild(try documentElement(try page.node("hd"))), "createHTMLDocument's head, inserted");
}

test "a document a creator hands to script hands its reference to its wrapper, and its nodes theirs to the tree" {
    try h.onFreshThread(scriptFacingDocumentsHandTheirReferencesOn);
}

fn aNavigatedDocumentKeepsItsCreatorsReference() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.doc = document; globalThis.tp = document.createElement('template');");
    const document = try page.node("doc");
    try testing.expect(!document.rc_flags.creator);
    // Its creator's (step 5i), and its wrapper's when the wrapper counts.
    try testing.expect(dom.refcount.count(document) >= 1);
    // A template's contents: made with the template and hosted by it, so
    // its insertion under its host ended its creator's reference.
    const template: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(try page.node("tp")) orelse return error.NotANode));
    const content = dom.template_contents.contentOf(template) orelse return error.NoContent;
    const content_base = dom.instance_bridge.getNodeBase(@ptrCast(content)) orelse return error.NotANode;
    // Its wrapper's, if it has one (the template's wrapper can wrap it).
    const wrapped: u32 = if (h.engine.hasWrapper(content)) 1 else 0;
    try h.expectCount(wrapped, content_base, "a template's contents: hosted, so its creator's reference ended");
}

test "a navigable's document keeps its creator's reference, a template's contents hand theirs to the host" {
    try h.onFreshThread(aNavigatedDocumentKeepsItsCreatorsReference);
}

fn aNativelyBuiltNodeCountsZeroOnceItsLastHolderLetsGo() !void {
    const page = try h.Page.open();
    defer page.close();
    // host's wrapper keeps the tree; p was never wrapped. A static NodeList
    // (refcount 5b) holds it while the list lives.
    try page.run(
        \\globalThis.host = document.createElement('div');
        \\host.innerHTML = '<p></p>';
        \\globalThis.list = host.querySelectorAll('p');
    );
    const p = try firstChild(try page.node("host"));
    try h.expectCount(1, p, "p: the static NodeList's reference alone");
    try page.run("delete globalThis.list;");
    try page.collect();
    try h.expectCount(0, p, "p: its last holder let go");
}

test "a natively built node counts zero once its last holder lets go" {
    try h.onFreshThread(aNativelyBuiltNodeCountsZeroOnceItsLastHolderLetsGo);
}
