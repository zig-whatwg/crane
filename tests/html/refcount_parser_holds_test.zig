//! Lane refcount6 (refcount step 5a): what the HTML parser holds of the
//! nodes it builds.
//!
//! The tree builder's own structures - the stack of open elements, the list
//! of active formatting elements (its element entries, never its markers),
//! the head and form element pointers - each name tree nodes. WebKit's
//! stack, formatting list and head hold `HTMLStackItem`s, whose
//! `RefPtr<ContainerNode> m_node` counts the DOM node
//! (Source/WebCore/html/parser/HTMLStackItem.h), and the form pointer is a
//! `RefPtr<HTMLFormElement> m_form` (HTMLConstructionSite.h); Blink traces
//! the same structures (HTMLConstructionSite::Trace: head_, form_,
//! open_elements_, active_formatting_elements_). Crane counts how many of
//! them name each tree node (`TreeNode.structure_refs`) and tells the DOM
//! adapter when a node becomes held (0 -> 1) and when the last structure
//! lets go (1 -> 0); the adapter takes and drops one counted reference on
//! the DOM node then.
//!
//! These cases drive the tree builder alone, with a recorder for an
//! adapter: every hold has exactly one release, and what is held is exactly
//! what the structures name.
const std = @import("std");
const testing = std.testing;
const parser = @import("html").parser;
const TreeNode = parser.TreeNode;

/// The adapter's view: the tree nodes it was told are held.
const Recorder = struct {
    held: std.AutoHashMapUnmanaged(*TreeNode, void) = .empty,
    holds: usize = 0,
    releases: usize = 0,
    /// A hold of a node already held, or a release of one not held.
    unbalanced: usize = 0,

    fn deinit(self: *Recorder) void {
        self.held.deinit(testing.allocator);
    }

    fn onHold(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        self.holds += 1;
        const slot = self.held.getOrPut(testing.allocator, node) catch unreachable;
        if (slot.found_existing) self.unbalanced += 1;
    }

    fn onRelease(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        self.releases += 1;
        if (!self.held.remove(node)) self.unbalanced += 1;
    }

    /// Whether the held set is exactly what `builder`'s structures name.
    fn matches(self: *const Recorder, builder: *const parser.TreeBuilder) !void {
        var named: std.AutoHashMapUnmanaged(*TreeNode, void) = .empty;
        defer named.deinit(testing.allocator);
        for (builder.open_elements.toSlice()) |node| try named.put(testing.allocator, node, {});
        for (builder.active_formatting_elements.toSlice()) |entry| switch (entry) {
            .element => |element| try named.put(testing.allocator, element.node, {}),
            .marker => {},
        };
        if (builder.head_element) |node| try named.put(testing.allocator, node, {});
        if (builder.form_element) |node| try named.put(testing.allocator, node, {});
        try testing.expectEqual(named.count(), self.held.count());
        var it = named.keyIterator();
        while (it.next()) |node| try testing.expect(self.held.contains(node.*));
        try testing.expectEqual(@as(usize, 0), self.unbalanced);
    }
};

/// A tree builder over an input stream that stays open (more may be written),
/// with `recorder` as its adapter's holder.
const Streaming = struct {
    stream: parser.document_write.InputStreamManager,
    tokenizer: parser.Tokenizer,
    builder: parser.TreeBuilder,

    fn init(self: *Streaming, input: []const u8, recorder: *Recorder) !void {
        self.stream = try parser.document_write.InputStreamManager.init(testing.allocator, input);
        self.stream.complete = false;
        self.tokenizer = parser.Tokenizer.initWithStreamManager(testing.allocator, &self.stream);
        self.stream.attach(&self.tokenizer);
        self.builder = try parser.TreeBuilder.initWithStreamManager(testing.allocator, &self.tokenizer, &self.stream);
        self.builder.setDomAdapterCallbacks(recorder, null, null, null);
        self.builder.setDomAdapterStructureHoldCallbacks(&Recorder.onHold, &Recorder.onRelease);
    }

    fn write(self: *Streaming, more: []const u8) !void {
        try self.stream.buffer.appendSlice(self.stream.allocator, more);
        self.stream.sync();
        try self.builder.parse();
    }

    fn finish(self: *Streaming) !void {
        self.stream.complete = true;
        try self.builder.parse();
    }

    fn deinit(self: *Streaming) void {
        self.builder.deinit();
        self.tokenizer.deinit();
        self.stream.deinit();
    }
};

test "a parse paused mid-document holds exactly the nodes its structures name" {
    var recorder = Recorder{};
    defer recorder.deinit();
    var parse: Streaming = undefined;
    try parse.init("<!doctype html><html><head><title>t</title></head><body><form id=f><b><i><p>x", &recorder);
    defer parse.deinit();
    try parse.builder.parse();
    // html, body, form?, b, i, p are open; b and i are formatting entries;
    // head stays held by its pointer after its pop; form by its pointer.
    try testing.expect(parse.builder.open_elements.len >= 5);
    try testing.expect(parse.builder.head_element != null);
    try testing.expect(parse.builder.form_element != null);
    try recorder.matches(&parse.builder);
    // Misnested formatting: the adoption agency replaces entries in both
    // lists and moves nodes between them.
    try parse.write("</b>y</i>z<a href=1><div>w</a>v<table><tr><td>c<b>d</td></tr></table>");
    try recorder.matches(&parse.builder);
    try parse.write("</form><template><b>t</template><select><option>o</select>");
    try recorder.matches(&parse.builder);
    // The end: every open element is popped; the formatting list, head and
    // form pointers still name theirs.
    try parse.finish();
    try testing.expectEqual(@as(usize, 0), parse.builder.open_elements.len);
    try recorder.matches(&parse.builder);
    // The parser lets go of everything before its adapter goes.
    parse.builder.releaseStructureHolds();
    try testing.expectEqual(@as(usize, 0), recorder.held.count());
    try testing.expectEqual(recorder.holds, recorder.releases);
    try testing.expectEqual(@as(usize, 0), recorder.unbalanced);
}

test "an aborted parser lets go of its open elements and its pointers once each" {
    var recorder = Recorder{};
    defer recorder.deinit();
    var parse: Streaming = undefined;
    try parse.init("<html><head></head><body><form><b><div><object>", &recorder);
    defer parse.deinit();
    try parse.builder.parse();
    try recorder.matches(&parse.builder);
    parse.builder.abort();
    try testing.expectEqual(@as(usize, 0), parse.builder.open_elements.len);
    try recorder.matches(&parse.builder);
    parse.builder.releaseStructureHolds();
    try testing.expectEqual(@as(usize, 0), recorder.held.count());
    try testing.expectEqual(recorder.holds, recorder.releases);
}

test "a frameset parse, a foster-parented table and a reopened form keep the counts exact" {
    var recorder = Recorder{};
    defer recorder.deinit();
    var parse: Streaming = undefined;
    try parse.init("<html><head></head><body><table><b>x<form><tr><td>a</table><p><b><b><b><b>four</p>", &recorder);
    defer parse.deinit();
    try parse.builder.parse();
    try recorder.matches(&parse.builder);
    try parse.finish();
    try recorder.matches(&parse.builder);
    // A builder's own end lets go of what it still holds, adapter or not.
    parse.builder.releaseStructureHolds();
    try testing.expectEqual(recorder.holds, recorder.releases);

    var frames = Recorder{};
    defer frames.deinit();
    var framed: Streaming = undefined;
    try framed.init("<html><head></head><frameset><frame><frameset><frame></frameset>", &frames);
    defer framed.deinit();
    try framed.builder.parse();
    try frames.matches(&framed.builder);
    try framed.finish();
    try frames.matches(&framed.builder);
    framed.builder.releaseStructureHolds();
    try testing.expectEqual(frames.holds, frames.releases);
}

test "every tree node's structure count equals the structures that name it, without an adapter" {
    // The builder keeps the counts whether or not an adapter listens; its
    // own check after each parse (under test) compares them with the
    // structures, and this calls it directly too.
    const inputs = [_][]const u8{
        "<!doctype html><p><b><i>x</b>y</i>z",
        "<a><p>one<a>two</p>three",
        "<table><tr><td><b>x</table>y",
        "<body><form><form></form><select><option><optgroup>",
        "<svg><foreignObject><b>x</b></foreignObject></svg><math><mi>y",
        "<b><b><b><b><b>noah</b></b></b></b></b>",
        "<template><tr><td>c</template><dd><dt><li>",
    };
    for (inputs) |input| {
        var tokenizer = parser.Tokenizer.init(testing.allocator, input);
        defer tokenizer.deinit();
        var builder = try parser.TreeBuilder.init(testing.allocator, &tokenizer);
        defer builder.deinit();
        try builder.parse();
        try testing.expect(builder.structureHoldsConsistent());
    }
}

// ============================================================================
// The DOM side: the adapter's counted references (shadow mode). Counts read
// through dom.refcount.count, natively - no wrapper is made, so a count is
// the parser's alone: the structures' one reference (the creator's, adopted
// at the push), or none once the parser let go. A node no structure names
// counts nothing after its insertion (decision D-A: the parser hands its
// born reference on).
// ============================================================================

const h = @import("refcount_holders_helpers.zig");
const runtime = h.runtime;
const dom = h.dom;
const interfaces = @import("interfaces");

fn document(page: h.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

/// The element with `id`, found natively: no wrapper is made.
fn base(page: h.Page, id: []const u8) !*dom.NodeBase {
    const element = (try interfaces.Document.call_getElementById(try document(page), runtime.DOMString.initInterned(id))) orelse return error.NoSuchElement;
    return dom.instance_bridge.getNodeBase(@ptrCast(element)) orelse error.NotANode;
}

fn firstChildOf(node: *dom.NodeBase) !*dom.NodeBase {
    return node.first_child orelse error.NoChild;
}

/// `node`'s count is the parser's `held` references plus its wrapper's,
/// if it has one: a parser move's shadow-mode net (engine.retainValue on the
/// moved node and its new parent) wraps both, and in a document a wrapper
/// stays with its tree.
fn expectParserCount(held: u32, node: *dom.NodeBase, what: []const u8) !void {
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return error.NotANode));
    const wrapper: u32 = if (h.engine.hasWrapper(instance)) 1 else 0;
    try h.expectCount(held + wrapper, node, what);
}

fn stackHoldsWhatIsOpen() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("document.open(); document.write('<!doctype html><head><title>t</title></head><body><div id=a><p id=b>text')");
    const a = try base(page, "a");
    const b = try base(page, "b");
    try h.expectCount(1, a, "an open element: the stack's reference (its creator's, adopted)");
    try h.expectCount(1, b, "the current node");
    try h.expectCount(0, try firstChildOf(b), "a text node, inserted: its creator's reference handed to the tree");
    const head = (try base(page, "a")).parent_node.?.parent_node.?.first_child.?;
    try h.expectCount(1, head, "the popped head: the head element pointer still names it");
    try page.run("document.write('</p></div><span id=c></span><b id=x>bold')");
    try h.expectCount(0, a, "popped: nothing of the parser holds it");
    try h.expectCount(0, b, "popped");
    try h.expectCount(0, try base(page, "c"), "pushed and popped");
    try h.expectCount(1, try base(page, "x"), "open, and an active formatting element: one reference");
    try page.run("document.write('</b>')");
    try h.expectCount(0, try base(page, "x"), "off the stack and out of the formatting list");
    try page.run("document.close()");
    try h.expectCount(0, head, "the parser was released: the head pointer let go");
}

test "a suspended parser's open elements and head pointer hold one counted reference each, and a popped or inserted node none" {
    try h.onFreshThread(stackHoldsWhatIsOpen);
}

fn formPointerAndFormattingList() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("document.open(); document.write('<!doctype html><body><form id=f><input id=i><b id=b1>x<p id=p>y')");
    const f = try base(page, "f");
    try h.expectCount(1, f, "open and the form element pointer: one reference");
    try h.expectCount(0, try base(page, "i"), "a void element: pushed, popped");
    // The adoption agency: </b> with a block inside the formatting element
    // moves the block and makes replacement elements (moves are held across
    // their removal; every hold ends).
    try page.run("document.write('</b>z</form>')");
    try expectParserCount(0, f, "closed: popped and the pointer cleared (the move's new parent: wrapped)");
    try expectParserCount(0, try base(page, "b1"), "the adoption agency took it off both lists");
    // The furthest block, moved under the form; the outer loop's second
    // turn closes the new b, and </form>'s implied end tags close the p.
    try expectParserCount(0, try base(page, "p"), "moved by the adoption agency, then closed by </form>");
    try page.run("document.write('<table><b id=t>fostered<tr><td>c</table>'); document.close()");
    try expectParserCount(0, try base(page, "t"), "foster-parented, then closed");
}

test "the form pointer and the formatting list hold their elements, and every hold of an adoption agency run ends" {
    try h.onFreshThread(formPointerAndFormattingList);
}

fn scriptRemovedWhileOpen() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("document.open(); document.write('<!doctype html><body><div id=host><section id=s><em>e')");
    const s = try base(page, "s");
    try h.expectCount(1, s, "open");
    // Script detaches an open element: the stack still names it - its
    // count is the parser's, and its tree is held through it.
    try page.run("window.kept = document.getElementById('s'); kept.expando = 1; document.getElementById('host').remove();");
    try h.expectCount(2, s, "open and wrapped (a global keeps the wrapper)");
    try page.collect();
    try page.run("document.write('still</em></section>more</div>');");
    try page.run("if (kept.textContent !== 'estill') throw new Error(kept.textContent); if (kept.expando !== 1) throw new Error('expando');");
    try h.expectCount(1, s, "popped: the wrapper's reference alone");
    try page.run("document.close()");
}

test "an element script detaches while it is open stays counted by the stack and keeps receiving its content" {
    try h.onFreshThread(scriptRemovedWhileOpen);
}
