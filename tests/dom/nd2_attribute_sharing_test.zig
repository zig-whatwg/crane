//! Attribute-block sharing (lane nd2 batch 4, plan-v2 A3): elements whose
//! attribute sets are equal - names and values, in order - hold ONE
//! immutable block, made by a parser run's cache or by a clone from its
//! source, and the first write on one of them copies it (copy on write).
//! Blink: core/dom/element_data_cache.cc (ElementDataCache::
//! CachedShareableElementDataWithAttributes), Element::ParserSetAttributes,
//! Element::CloneAttributesFrom, Element::CreateUniqueElementData. WebKit:
//! Source/WebCore/dom/DocumentSharedObjectPool.cpp, Element::
//! parserSetAttributes, Element::cloneAttributesFromElement.
//!
//! Which elements share is not web-observable; these tests read it from the
//! list's block (dom.element_data.of) and check that every writer leaves
//! the other holders' attributes as they were. std.testing.allocator checks
//! that every block, record and cache table is freed.
//!
//! These name only generated interfaces and src/dom: no impl (AGENTS.md "The
//! impls boundary").

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const no_force: @import("webidl").Opt(bool) = .{ .was_passed = false, .value = undefined };

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    /// The div's children after `html` is parsed into it (the fragment
    /// parser: one parser run).
    fn parse(self: *Page, html: []const u8, out: []*runtime.Instance) !void {
        try interfaces.Element.set_innerHTML(self.div, .{ .domstring = str(html) });
        var at = try interfaces.Element.get_firstElementChild(self.div);
        for (out) |*slot| {
            slot.* = at.?;
            at = try interfaces.Element.get_nextElementSibling(at.?);
        }
    }

    fn get(el: *runtime.Instance, name: []const u8) !?[]const u8 {
        const view = dom.element_data.of(el).?;
        return view.findValue(null, name);
    }
};

/// The block `el`'s attributes are in, or null.
fn blockOf(el: *runtime.Instance) ?*const dom.element_data.AttributeList {
    return dom.element_data.of(el).?.data.attrs;
}

test "A3: parser-made elements with equal sets share one block; the parse's cache is gone after it" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    var els: [4]*runtime.Instance = undefined;
    try page.parse("<p class=\"a b\" id=x></p><p class=\"a b\" id=x></p><p id=x class=\"a b\"></p><p class=\"a b\" id=y></p>", &els);
    const shared = blockOf(els[0]).?;
    try testing.expect(blockOf(els[1]).? == shared);
    // Another order, another value: other sets.
    try testing.expect(blockOf(els[2]).? != shared and blockOf(els[3]).? != shared);
    // Two elements hold it; the parser's cache let go when the parse ended.
    try testing.expectEqual(@as(u8, 2), shared.holders);
    try testing.expectEqual(@as(u8, 1), blockOf(els[2]).?.holders);
    // The ID and classes read through the shared block's indices.
    for (els[0..3]) |el| {
        var id = try interfaces.Element.get_id(el);
        defer id.deinit(testing.allocator);
        try testing.expectEqualStrings("x", id.asSlice());
        try testing.expect(try interfaces.Document.call_getElementById(page.document, str("x")) == els[0]);
    }
    var class_name = try interfaces.Element.get_className(els[1]);
    defer class_name.deinit(testing.allocator);
    try testing.expectEqualStrings("a b", class_name.asSlice());
}

test "A3: each writer on one of two sharing elements copies and leaves the other untouched" {
    const Writer = enum { change, append, remove, toggle_off, attr_value, class_list, set_attribute_node };
    for (std.enums.values(Writer)) |writer| {
        // classList's DOMTokenList is a same-object cache that only a
        // wrapper's collection frees: with no engine here it stays, so that
        // case runs over an arena (as cg1_element_same_object_test does).
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        var page: Page = undefined;
        try page.open(if (writer == .class_list) arena.allocator() else testing.allocator);
        defer page.close();
        var els: [2]*runtime.Instance = undefined;
        try page.parse("<span class=\"k\" title=t></span><span class=\"k\" title=t></span>", &els);
        const shared = blockOf(els[0]).?;
        try testing.expect(blockOf(els[1]).? == shared);
        const el = els[0];
        switch (writer) {
            .change => try interfaces.Element.call_setAttribute(el, str("title"), .{ .domstring = str("u") }),
            .append => try interfaces.Element.call_setAttribute(el, str("lang"), .{ .domstring = str("en") }),
            .remove => try interfaces.Element.call_removeAttribute(el, str("title")),
            .toggle_off => try testing.expect(!try interfaces.Element.call_toggleAttribute(el, str("title"), no_force)),
            .attr_value => try interfaces.Attr.set_value((try interfaces.Element.call_getAttributeNode(el, str("title"))).?, str("u")),
            .class_list => try interfaces.DOMTokenList.call_add(try interfaces.Element.get_classList(el), &.{str("m")}),
            .set_attribute_node => {
                const attr = try interfaces.Document.call_createAttribute(page.document, str("title"));
                try interfaces.Attr.set_value(attr, str("u"));
                _ = try interfaces.Element.call_setAttributeNode(el, attr);
            },
        }
        // The other element keeps the block and its attributes.
        try testing.expect(blockOf(els[1]).? == shared);
        try testing.expectEqualStrings("k", (try Page.get(els[1], "class")).?);
        try testing.expectEqualStrings("t", (try Page.get(els[1], "title")).?);
        try testing.expect((try Page.get(els[1], "lang")) == null);
        try testing.expectEqual(@as(u8, 1), shared.holders);
        // The writer has a list of its own, with the write in it.
        const mine = blockOf(el).?;
        try testing.expect(mine != shared and !mine.isShared());
        switch (writer) {
            .change, .attr_value, .set_attribute_node => try testing.expectEqualStrings("u", (try Page.get(el, "title")).?),
            .append => try testing.expectEqualStrings("en", (try Page.get(el, "lang")).?),
            .remove, .toggle_off => try testing.expect((try Page.get(el, "title")) == null),
            .class_list => try testing.expectEqualStrings("k m", (try Page.get(el, "class")).?),
        }
    }
}

test "A3: a clone shares its source's block, deep clones and imports too, and either side's write copies" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    var els: [1]*runtime.Instance = undefined;
    try page.parse("<ul class=list><li class=item data-n=1>a</li></ul>", &els);
    const ul = els[0];
    const li = (try interfaces.Element.get_firstElementChild(ul)).?;
    const clone = try interfaces.Node.call_cloneNode(ul, .passed(true));
    const li_clone = (try interfaces.Element.get_firstElementChild(clone)).?;
    try testing.expect(blockOf(clone).? == blockOf(ul).?);
    try testing.expect(blockOf(li_clone).? == blockOf(li).?);
    try testing.expectEqual(@as(u8, 2), blockOf(li).?.holders);

    // importNode into another document of the same Browser: the ids are the
    // Browser's, so the block crosses documents.
    const other = try interfaces.Document.init(testing.allocator, &page.ctx);
    defer interfaces.Document.deinit(other);
    const imported = try interfaces.Document.call_importNode(other, li, .{ .was_passed = true, .value = .{ .boolean = true } });
    try testing.expect(blockOf(imported).? == blockOf(li).?);
    try testing.expectEqual(@as(u8, 3), blockOf(li).?.holders);

    // The source writes: it copies; the clones keep the block.
    const block = blockOf(li).?;
    try interfaces.Element.call_setAttribute(li, str("data-n"), .{ .domstring = str("2") });
    try testing.expect(blockOf(li).? != block and blockOf(li_clone).? == block and blockOf(imported).? == block);
    try testing.expectEqualStrings("1", (try Page.get(li_clone, "data-n")).?);
    try testing.expectEqualStrings("2", (try Page.get(li, "data-n")).?);

    // A script-made element's own list becomes shared when it is cloned.
    const made = try interfaces.Document.call_createElement(page.document, str("b"), .{ .was_passed = false, .value = undefined });
    try interfaces.Element.call_setAttribute(made, str("title"), .{ .domstring = str("t") });
    const own = blockOf(made).?;
    try testing.expect(!own.isShared());
    const made_clone = try interfaces.Node.call_cloneNode(made, .passed(false));
    try testing.expect(blockOf(made_clone).? == own and own.holders == 2);
    _ = try interfaces.Node.call_appendChild(page.div, made);
    _ = try interfaces.Node.call_appendChild(page.div, made_clone);
}
