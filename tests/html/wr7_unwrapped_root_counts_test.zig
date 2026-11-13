//! The wrapper redesign's P7 (tmp/redesign/wrapper-redesign-design.md section
//! 7): a wrap no longer wraps the node's ancestors, so a root no script read
//! can have a wrapped, script-held node in its tree. Two native frees used to
//! read the root's own wrapper state for the whole tree:
//! - runtime.orphan_roots (dom.mutation's orphanRemoved, Node's stillOrphan):
//!   a removed root no wrapper reached was freed at its realm's end;
//! - dom.node_creation.destroyUninserted (Node's destroyUninsertedHook): a
//!   creator - the parser's adapter for a node it removed, a template for its
//!   contents - freed an unwrapped root and its subtree.
//! Both now leave a tree that holds a node to the counts (refcount step 7):
//! it lives while the held node does, and once script lets go of it the
//! whole tree goes - its last release makes it garbage and the agent's queue
//! frees it. Each case checks both halves: the tree kept while held, freed
//! after the release (the root's slab generation), and the Browser's end on
//! std.testing.allocator with refcount_teardown's live-node check finds
//! nothing left.
//!
//! Each test runs a real Browser on a thread of its own.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const dom = @import("dom");
const engine = @import("engine");
const interfaces = @import("interfaces");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

fn realmOf(page: Page) !engine.Context {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.realm orelse error.NoRealm;
}

/// The node script's `expression` evaluates to.
fn nodeOf(page: Page, expression: []const u8) !*dom.NodeBase {
    const context = page.browser.current_context orelse return error.NoPage;
    const value = try context.evaluateScript(expression);
    defer value.release();
    const instance = engine.convertToPlatformObject(try realmOf(page), value.borrow()) orelse return error.NotAPlatformObject;
    return dom.instance_bridge.getNodeBase(instance) orelse error.NotANode;
}

/// A node, watched natively by its slab generation: script never reads it.
const Watched = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(node: *dom.NodeBase) !Watched {
        const raw = dom.instance_bridge.getInstance(node) orelse return error.NoInstance;
        const instance: *runtime.Instance = @ptrCast(@alignCast(raw));
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Watched) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

fn check(ok: bool, what: []const u8) !void {
    if (!ok) {
        std.debug.print("does not hold: {s}\n", .{what});
        return error.TestUnexpectedResult;
    }
}

/// Collect, let the deferred teardown free what was collected, twice.
fn collectAndTurn(page: Page) !void {
    for (0..2) |_| {
        try page.run("collectNow();");
        try page.turn();
    }
}

fn expectTrue(page: Page, source: []const u8) !void {
    const answer = try page.evaluate(source);
    defer testing.allocator.free(answer);
    testing.expectEqualStrings("true", answer) catch |err| {
        std.debug.print("does not hold: {s}\n", .{source});
        return err;
    };
}

fn removedRootKeptWhileHeld() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<section><div><p id=x></p></div></section>';
        \\globalThis.held = document.getElementById('x');
        \\held.wr7 = 'held';
        \\document.body.innerHTML = '';
    );
    const p = try nodeOf(page, "held");
    const section = (p.parent_node orelse return error.NoParent).parent_node orelse return error.NoParent;
    // The removed root script never read: no wrapper, and its tree holds p.
    try testing.expect(section.wrapper.isEmpty());
    try testing.expect(section.subtree_holds != 0);
    const watched = try Watched.of(section);
    try collectAndTurn(page);
    try testing.expect(watched.alive());
    try expectTrue(page, "String(held.wr7 === 'held' && held.parentNode.parentNode.localName === 'section')");
    // Script lets go: the whole tree goes.
    try page.run("globalThis.held = null;");
    try collectAndTurn(page);
    try testing.expect(!watched.alive());
}

test "wr7: a removed root script never read lives while a node script holds in its tree does, and goes with it" {
    try onFreshThread(removedRootKeptWhileHeld);
}

fn parserRemovedBodyKeptWhileHeld() !void {
    const page = try Page.open();
    defer page.close();
    // HTML "in body", a start tag "frameset" with frameset-ok "ok": the
    // parser removes the body; the script inside it read a node of it.
    try page.run(
        \\document.open();
        \\document.write('<div id=a title=t><b></b></div><script>globalThis.held = document.getElementById("a"); held.wr7 = "held";<\/script><frameset></frameset>');
        \\document.close();
    );
    try expectTrue(page, "String(document.body.localName === 'frameset')");
    const div = try nodeOf(page, "held");
    const body = div.parent_node orelse return error.NoParent;
    try testing.expect(body.parent_node == null);
    try testing.expect(body.wrapper.isEmpty());
    const watched = try Watched.of(body);
    try collectAndTurn(page);
    try testing.expect(watched.alive());
    try expectTrue(page, "String(held.wr7 === 'held' && held.title === 't' && held.firstChild.localName === 'b' && held.parentNode.localName === 'body')");
    try page.run("globalThis.held = null;");
    try collectAndTurn(page);
    try testing.expect(!watched.alive());
}

test "wr7: a body the parser removed for a frameset lives while the node a script held in it does, and goes with it" {
    try onFreshThread(parserRemovedBodyKeptWhileHeld);
}

fn templateContentsKeptWhileHeld() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.held = (() => {
        \\  const template = document.createElement('template');
        \\  template.innerHTML = '<b></b><i></i>';
        \\  return template.content.firstChild;
        \\})();
        \\held.wr7 = 'held';
    );
    const b = try nodeOf(page, "held");
    const content = b.parent_node orelse return error.NoParent;
    const watched = try Watched.of(content);
    try collectAndTurn(page);
    try testing.expect(watched.alive());
    try expectTrue(page, "String(held.wr7 === 'held' && held.nextSibling.localName === 'i' && held.ownerDocument.createElement('u').ownerDocument === held.ownerDocument)");
    try page.run("globalThis.held = null;");
    try collectAndTurn(page);
    try testing.expect(!watched.alive());
}

test "wr7: a template's contents live while a node script holds in them does, and go with it" {
    try onFreshThread(templateContentsKeptWhileHeld);
}

/// Fills the young generation with garbage, so V8 scavenges (and drops the
/// unmodified node wrappers nothing reaches: the redesign's P8).
const scavenge =
    \\(() => { let sink = 0;
    \\  for (let round = 0; round < 48; round++) { const junk = []; for (let i = 0; i < 4096; i++) junk.push({ i, s: 'x' + (i & 7) }); sink += junk.length; }
    \\  return sink; })();
;

fn templateTornDownUnderAWrappedContentNode() !void {
    const page = try Page.open();
    defer page.close();
    const context = page.browser.current_context orelse return error.NoPage;
    const realm = try realmOf(page);
    const document = context.document_instance orelse return error.NoDocument;
    // A template a native creator makes and owns - the parser's way - with a
    // node in its contents, handed to script alone. (The contents' root has
    // a wrapper all the same: the template's own edge to its contents,
    // HTMLTemplateElement's establishContents engine.traceChild, makes it.)
    const template = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("template"), .{ .was_passed = false, .value = undefined });
    const content = try interfaces.HTMLTemplateElement.get_content(template);
    const b = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("b"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(content, b);
    {
        const global = try context.evaluateScript("globalThis");
        defer global.release();
        try engine.setProperty(realm, global.borrow(), "held", .{ .instance = b });
    }
    try page.run("held.wr7 = 'held';");
    try check(!(dom.instance_bridge.getNodeBase(b) orelse return error.NotANode).wrapper.isEmpty(), "the held node is wrapped");
    const watched = try Watched.of(dom.instance_bridge.getNodeBase(content) orelse return error.NotANode);
    // The creator drops the template: its teardown lets its contents go -
    // but a node of them is wrapped, so the counts keep them.
    dom.node_creation.destroyUninserted(template);
    try check(watched.alive(), "the contents live right after the template's teardown");
    try collectAndTurn(page);
    try check(watched.alive(), "the contents live through collections while the node is held");
    try expectTrue(page, "String(held.wr7 === 'held' && held.parentNode.nodeType === Node.DOCUMENT_FRAGMENT_NODE && held.parentNode.firstChild === held)");
    // Script lets go: the contents go.
    try page.run("globalThis.held = null;");
    try collectAndTurn(page);
    try check(!watched.alive(), "the contents go once the node is let go");
}

test "wr7: a template torn down while a node of its contents is wrapped leaves them to the counts: kept while held, freed after" {
    try onFreshThread(templateTornDownUnderAWrappedContentNode);
}

fn contentWrapperIsNotDroppable() !void {
    const page = try Page.open();
    defer page.close();
    // A template's contents keep their template contents owner document by
    // an edge from the contents' wrapper (HTMLTemplateElement's
    // establishContents: engine.traceChild) - a property on the wrapper, so
    // V8 never drops it in a scavenge (P8), and the walk keeps it in a full
    // collection while a node of its tree is wrapped: script cannot see the
    // contents' root lose its wrapper while it holds a node of them.
    try page.run(
        \\globalThis.held = (() => { const t = document.createElement('template'); t.innerHTML = '<b></b>'; return t.content.firstChild; })();
        \\held.wr7 = 'held';
    );
    const b = try nodeOf(page, "held");
    const content = b.parent_node orelse return error.NoParent;
    try testing.expect(!content.wrapper.isEmpty());
    try page.run(scavenge);
    try page.turn();
    try testing.expect(!content.wrapper.isEmpty());
    try collectAndTurn(page);
    try testing.expect(!content.wrapper.isEmpty());
    try page.run("globalThis.held = null;");
    try collectAndTurn(page);
}

test "wr7: a template contents' wrapper is never dropped while a node of them is wrapped - its owner-document edge makes it modified, and the walk keeps it" {
    try onFreshThread(contentWrapperIsNotDroppable);
}
