//! The DOM's side tables are each Browser's (instances B1): every impl's
//! InstanceRegistry, EventTarget's states, the instance-to-NodeBase bridge,
//! StaticRange's, the option and textarea maps are side tables of the
//! Browser's runtime.BrowserScope, found from the object's address. So one
//! Browser's end - its teardown sweeps (dom.teardown_sweeps.runAll(scope),
//! which was impls/cleanup.zig's process-wide cleanupAllDomRegistries) and
//! its scope's end - frees its own entries and never another Browser's: the
//! other's nodes keep their tree, attributes, listeners and NodeBases.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const testing = std.testing;
const allocator = testing.allocator;

fn name(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// One Browser's page, engine-less: a document with a div (an id, a text
/// child) in it, and an orphan - an element made and never inserted, which
/// only the Browser's end frees.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,
    text: *runtime.Instance = undefined,
    orphan: *runtime.Instance = undefined,
    ended: bool = false,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, id: []const u8) !void {
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try interfaces.Document.call_createElement(self.document, name("div"), .{ .was_passed = false, .value = undefined });
        try interfaces.Element.call_setAttribute(self.div, name("id"), .{ .domstring = name(id) });
        self.text = try interfaces.Document.call_createTextNode(self.document, name("text"));
        _ = try interfaces.Node.call_appendChild(self.div, self.text);
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
        self.orphan = try interfaces.Document.call_createElement(self.document, name("span"), .{ .was_passed = false, .value = undefined });
    }

    /// The Browser's end, as Browser.deinit runs it with no engine: the
    /// teardown sweeps over its scope, then its scope's end.
    fn end(self: *Page) void {
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
        self.ended = true;
    }

    /// A page torn down the ordinary way: its document's tree, then its
    /// Browser's end (for the orphan).
    fn close(self: *Page) void {
        if (self.ended) return;
        interfaces.Document.deinit(self.document);
        self.end();
    }

    fn expectIntact(self: *Page, id: []const u8) !void {
        // Every object is this Browser's.
        try testing.expectEqual(&self.scope, runtime.BrowserScope.ofInstance(self.div));
        try testing.expectEqual(&self.scope, runtime.BrowserScope.ofInstance(self.orphan));
        // The bridge and the tree.
        const div_base = dom.instance_bridge.getNodeBase(self.div) orelse return error.NoNodeBase;
        const text_base = dom.instance_bridge.getNodeBase(self.text) orelse return error.NoNodeBase;
        try testing.expectEqual(text_base, div_base.first_child.?);
        try testing.expect(dom.instance_bridge.getNodeBase(self.orphan) != null);
        // Element's state: the attribute.
        const value = (try interfaces.Element.call_getAttribute(self.div, name("id"))) orelse return error.NoAttribute;
        try testing.expectEqualStrings(id, value.asSlice());
        // Node's state: the parent.
        try testing.expectEqual(@as(?*runtime.Instance, self.div), try interfaces.Node.get_parentNode(self.text));
    }
};

test "one Browser's end sweeps its own side tables and leaves another Browser's nodes intact" {
    interfaces.process_hooks.startHooksForTest();
    var a: Page = undefined;
    try a.open("a");
    defer a.close();
    var b: Page = undefined;
    try b.open("b");
    defer b.close();
    try a.expectIntact("a");
    try b.expectIntact("b");

    // Each Browser's bridge holds its own nodes: four each (document, div,
    // text, orphan).
    try testing.expectEqual(@as(usize, 4), dom.instance_bridge.entryCount(&a.scope));
    try testing.expectEqual(@as(usize, 4), dom.instance_bridge.entryCount(&b.scope));

    // A ends without tearing its tree down - every node of it is left to
    // the sweeps, the orphan as well (impls/cleanup.zig swept every
    // Browser's).
    a.end();

    try b.expectIntact("b");
    try testing.expectEqual(@as(usize, 4), dom.instance_bridge.entryCount(&b.scope));
}

test "a Browser's sweeps free its own orphans: what no teardown reached" {
    interfaces.process_hooks.startHooksForTest();
    var a: Page = undefined;
    try a.open("a");
    // The tree goes; the orphan stays for the Browser's end, whose sweeps
    // free what its states own (std.testing.allocator fails this test on a
    // leak).
    interfaces.Document.deinit(a.document);
    try testing.expectEqual(@as(usize, 1), dom.instance_bridge.entryCount(&a.scope));
    a.end();
}
