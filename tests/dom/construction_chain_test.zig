//! A node is made by its interface's generated construction chain, and what
//! the chain is given at construction is all it needs (impls boundary B2,
//! tmp/plans/impls-boundary-design.md 3.2.3).
//!
//! - The node type is a construction fact: the interface the node implements.
//!   WebKit passes it to Node's constructor (`Node(Document&, NodeType, ...)`)
//!   and never sets it again. Here Node's own steps read it off the
//!   most-derived State, so `interfaces.X.init` alone makes a node of the right
//!   type - no creation path sets it afterwards. A Text made that way used to
//!   be an ELEMENT_NODE until its constructor set it.
//! - Every level of the chain runs: a CDATASection is a Text (DOM 4.13), so it
//!   has Text's part - its `wholeText` used to throw InvalidStateError, since
//!   its init chained to CharacterData's past Text's.
//! - The destruction chain frees every level: std.testing.allocator fails a
//!   test whose teardown left anything behind.
//! - A fact given at construction travels the chain as a construction
//!   argument (`initWith`), the C++ constructor's parameter list - not a
//!   non-IDL factory (the user's decision Q4). A CookieStore is told whether
//!   its relevant settings object is a secure context: Window and
//!   ServiceWorkerGlobalScope make their cookieStore attribute's store with
//!   `interfaces.CookieStore.initWith(.., .{ .is_secure_context = .. })`,
//!   where both used to name CookieStore's impl for its `createForOrigin`.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const allocator = testing.allocator;

fn nodeType(node: *runtime.Instance) !u16 {
    return interfaces.Node.get_nodeType(node);
}

const Realm = struct {
    ctx: runtime.ContextData,

    fn init(self: *Realm) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.ctx = try runtime.ContextData.init(allocator, .{});
    }

    fn deinit(self: *Realm) void {
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }
};

test "each node interface's init alone makes a node of its type" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    const ctx = &realm.ctx;

    inline for (.{
        .{ interfaces.Text, interfaces.Node.get_TEXT_NODE() },
        .{ interfaces.CDATASection, interfaces.Node.get_CDATA_SECTION_NODE() },
        .{ interfaces.Comment, interfaces.Node.get_COMMENT_NODE() },
        .{ interfaces.ProcessingInstruction, interfaces.Node.get_PROCESSING_INSTRUCTION_NODE() },
        .{ interfaces.Attr, interfaces.Node.get_ATTRIBUTE_NODE() },
        .{ interfaces.DocumentType, interfaces.Node.get_DOCUMENT_TYPE_NODE() },
        .{ interfaces.DocumentFragment, interfaces.Node.get_DOCUMENT_FRAGMENT_NODE() },
        .{ interfaces.Document, interfaces.Node.get_DOCUMENT_NODE() },
        .{ interfaces.HTMLDivElement, interfaces.Node.get_ELEMENT_NODE() },
        .{ interfaces.HTMLElement, interfaces.Node.get_ELEMENT_NODE() },
        .{ interfaces.SVGElement, interfaces.Node.get_ELEMENT_NODE() },
    }) |case| {
        const node = try case[0].init(allocator, ctx);
        defer case[0].deinit(node);
        try testing.expectEqual(case[1], try nodeType(node));
    }
}

test "a CDATASection is constructed as a Text: its Text part answers" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    const cdata = try interfaces.CDATASection.init(allocator, &realm.ctx);
    defer interfaces.CDATASection.deinit(cdata);
    try interfaces.CharacterData.set_data(cdata, runtime.DOMString.initInterned("x"));
    // Text's part exists: its getter answers rather than InvalidStateError.
    var whole = try interfaces.Text.get_wholeText(cdata);
    whole.deinit(cdata.ctx.allocator);
}

test "a tree's teardown frees every level of every node in it" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    const ctx = &realm.ctx;

    const fragment = try interfaces.DocumentFragment.init(allocator, ctx);
    defer interfaces.DocumentFragment.deinit(fragment);
    _ = try interfaces.Node.call_appendChild(fragment, try interfaces.HTMLDivElement.init(allocator, ctx));
    _ = try interfaces.Node.call_appendChild(fragment, try interfaces.Text.init(allocator, ctx));
    _ = try interfaces.Node.call_appendChild(fragment, try interfaces.Comment.init(allocator, ctx));
    _ = try interfaces.Node.call_appendChild(fragment, try interfaces.CDATASection.init(allocator, ctx));
}

test "CookieStore takes is_secure_context at construction; nothing else does" {
    try testing.expect(interfaces.CookieStore.takesConstructionArg("is_secure_context"));
    try testing.expect(!interfaces.CookieStore.takesConstructionArg("origin"));
    // Its parent's chain has no such argument, and no unrelated chain does.
    try testing.expect(!interfaces.EventTarget.takesConstructionArg("is_secure_context"));
    try testing.expect(!interfaces.HTMLDivElement.takesConstructionArg("is_secure_context"));
}

test "a CookieStore made with or without its construction argument is torn down whole" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    const insecure = try interfaces.CookieStore.initWith(allocator, &realm.ctx, .{ .is_secure_context = false });
    interfaces.CookieStore.deinit(insecure);
    const secure = try interfaces.CookieStore.init(allocator, &realm.ctx);
    interfaces.CookieStore.deinit(secure);
}

test "a CharacterData node's data is a construction argument of every CharacterData" {
    // WebKit: `Text::create(document, String&& data)` -> CharacterData(document,
    // data, ...). Text(data), Comment(data), document.createTextNode and
    // createProcessingInstruction give the data at construction; none runs
    // "replace data" on a node no one can observe yet.
    try testing.expect(interfaces.CharacterData.takesConstructionArg("data"));
    try testing.expect(interfaces.Text.takesConstructionArg("data"));
    try testing.expect(interfaces.CDATASection.takesConstructionArg("data"));
    try testing.expect(interfaces.Comment.takesConstructionArg("data"));
    try testing.expect(interfaces.ProcessingInstruction.takesConstructionArg("data"));
    try testing.expect(!interfaces.Node.takesConstructionArg("data"));
    try testing.expect(!interfaces.HTMLDivElement.takesConstructionArg("data"));

    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();

    inline for (.{ interfaces.Text, interfaces.CDATASection, interfaces.Comment, interfaces.ProcessingInstruction }) |Interface| {
        // Long enough for CharacterData's heap storage, past its inline bytes.
        const long = "data given at construction, " ** 4;
        inline for (.{ "", "x", long }) |data| {
            const node = try Interface.initWith(allocator, &realm.ctx, .{ .data = data });
            defer Interface.deinit(node);
            var read = try interfaces.CharacterData.get_data(node);
            defer read.deinit(node.ctx.allocator);
            try testing.expectEqualStrings(data, read.asSlice());
            try testing.expectEqual(@as(u32, data.len), try interfaces.CharacterData.get_length(node));
        }
    }
}

test "dom.character_data reads a CharacterData node's data in place" {
    var realm: Realm = undefined;
    try realm.init();
    defer realm.deinit();
    const character_data = @import("dom").character_data;

    const text = try interfaces.Text.initWith(allocator, &realm.ctx, .{ .data = "in place" });
    defer interfaces.Text.deinit(text);
    try testing.expectEqualStrings("in place", character_data.dataOf(text).?);
    // Borrowed until the data next changes: a change is seen on the next read.
    try interfaces.CharacterData.set_data(text, runtime.DOMString.initInterned("changed"));
    try testing.expectEqualStrings("changed", character_data.dataOf(text).?);

    // A node with no CharacterData part has no data.
    const div = try interfaces.HTMLDivElement.init(allocator, &realm.ctx);
    defer interfaces.HTMLDivElement.deinit(div);
    try testing.expect(character_data.dataOf(div) == null);
}
