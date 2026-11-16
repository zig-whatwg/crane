//! Real nodes for the tests of this directory (lane wb1: the WithBase
//! retirement, node-memory plan v2 X3).
//!
//! Every node a test of src/dom's algorithms works on is made the way
//! production makes it: an Instance of a Browser scope's slab, its State
//! block from the scope's arena, its NodeBase in that block, registered with
//! dom.instance_bridge - through the generated interfaces. No test builds a
//! NodeBase by value any more (`NodeBase.ownerless`, the ElementWithBase /
//! TextWithBase / AttrWithBase types): a NodeBase outside a node block
//! cannot hold the links the node allocator's cage needs (the plan's H4).
//!
//! Two kinds of node:
//! - a node of a document (`element`, `text`, ...): what script makes;
//! - a BARE node (`bare`): made by its interface's construction chain with
//!   no node document - what the tests of the links, the counts and the
//!   rare block need, where a document's own bookkeeping (its counts of
//!   referencing nodes, the foreign holds of its detached trees) would be
//!   noise. Still a real node block.
//!
//! `close` ends the page as a Browser ends it: each document's teardown
//! frees its tree (and what its nodes own: an attribute map),
//! then the Browser's sweeps release every node still alive, in no order -
//! bare nodes and nodes never inserted. The sweeps release a node, not the
//! objects it made for script. A test that is handed an object of its own (a
//! static NodeList) frees it (`runtime.gc.onObjectFreed`). An object an
//! element keeps for script (`classList`, `dataset`) is its wrapper's to
//! end, and an engine-less realm has no wrapper: nothing here ends it. A
//! test that reads one belongs in tests/html, on a page of a real Browser
//! (tests/html/native_read_page.zig; lane lk1 moved the classList tests
//! there), where its wrapper frees it as in production.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

pub const NodeBase = dom.NodeBase;
pub const Instance = runtime.Instance;

pub fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// The NodeBase of a node the test holds.
pub fn baseOf(node: *Instance) *NodeBase {
    return dom.instance_bridge.getNodeBase(node) orelse @panic("real_nodes.baseOf: not a live node");
}

/// The Instance of a node the test holds.
pub fn instanceOf(node: *NodeBase) *Instance {
    return dom.instance_bridge.getInstanceTyped(Instance, node) orelse @panic("real_nodes.instanceOf: the node was released");
}

pub const Kind = enum { element, text, comment, fragment, document, attr };

/// An engine-less Browser scope and the nodes a test makes in it.
pub const Nodes = struct {
    allocator: std.mem.Allocator,
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    /// The documents made here, torn down by `close`, newest first.
    documents: [max_documents]*Instance = undefined,
    document_count: usize = 0,

    const max_documents = 4;

    /// In place: the scope must not move once it has made an object.
    pub fn open(self: *Nodes, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{
            .allocator = allocator,
            .scope = runtime.BrowserScope.init(allocator),
            .ctx = try runtime.ContextData.init(allocator, .{}),
        };
        self.ctx.browser_scope = &self.scope;
    }

    /// The page's end and the Browser's, as Browser.deinit runs it with no
    /// engine: each document's tree, then every node still alive (the
    /// teardown sweeps).
    pub fn close(self: *Nodes) void {
        while (self.document_count != 0) {
            self.document_count -= 1;
            interfaces.Document.deinit(self.documents[self.document_count]);
        }
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    /// An HTML document.
    pub fn document(self: *Nodes) !*Instance {
        if (self.document_count == max_documents) return error.TooManyDocuments;
        const doc = try interfaces.Document.init(self.allocator, &self.ctx);
        self.documents[self.document_count] = doc;
        self.document_count += 1;
        try dom.document_internals.setContentType(doc, "text/html");
        try dom.document_internals.setDocumentType(doc, .html);
        return doc;
    }

    /// `document.createElement(local_name)`.
    pub fn element(self: *Nodes, doc: *Instance, local_name: []const u8) !*Instance {
        _ = self;
        return interfaces.Document.call_createElement(doc, str(local_name), .{ .was_passed = false, .value = undefined });
    }

    /// `document.createTextNode(data)`.
    pub fn text(self: *Nodes, doc: *Instance, data: []const u8) !*Instance {
        _ = self;
        return interfaces.Document.call_createTextNode(doc, str(data));
    }

    /// `document.createComment(data)`.
    pub fn comment(self: *Nodes, doc: *Instance, data: []const u8) !*Instance {
        _ = self;
        return interfaces.Document.call_createComment(doc, str(data));
    }

    /// `document.createDocumentFragment()`.
    pub fn fragment(self: *Nodes, doc: *Instance) !*Instance {
        _ = self;
        return interfaces.Document.call_createDocumentFragment(doc);
    }

    /// `parent.appendChild(child)`.
    pub fn append(self: *Nodes, parent: *Instance, child: *Instance) !void {
        _ = self;
        _ = try interfaces.Node.call_appendChild(parent, child);
    }

    /// `element.setAttribute(name, value)`.
    pub fn setAttribute(self: *Nodes, node: *Instance, name: []const u8, value: []const u8) !void {
        _ = self;
        try interfaces.Element.call_setAttribute(node, str(name), .{ .domstring = str(value) });
    }

    /// A bare node of `kind`: its interface's construction chain, no node
    /// document. Released at `close`.
    pub fn bareInstance(self: *Nodes, kind: Kind) !*Instance {
        return switch (kind) {
            .element => interfaces.Element.init(self.allocator, &self.ctx),
            .text => interfaces.Text.init(self.allocator, &self.ctx),
            .comment => interfaces.Comment.init(self.allocator, &self.ctx),
            .fragment => interfaces.DocumentFragment.init(self.allocator, &self.ctx),
            .document => interfaces.Document.init(self.allocator, &self.ctx),
            .attr => interfaces.Attr.init(self.allocator, &self.ctx),
        };
    }

    /// `bareInstance`, as its NodeBase.
    pub fn bare(self: *Nodes, kind: Kind) !*NodeBase {
        return baseOf(try self.bareInstance(kind));
    }
};
