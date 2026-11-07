//! The attributes of every Node family whose generated State loses its IDL
//! attribute fields (lane perf2, batch 3: Z1) read and write as before.
//!
//! A characterization test: it passes on main before the change and must pass
//! after it. Each attribute here is an accessor over the node itself - the
//! impl's InternalState, ElementData or NodeBase - as an IDL attribute is in
//! every engine (Blink's HTMLElement::title() reads the title attribute, its
//! Node::nodeValue() the node's data): none of them ever read the generated
//! State field of its name, which is why those fields can go. Engine-free,
//! through the generated interfaces only; std.testing.allocator checks that
//! the teardown of each family still returns everything.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const testing = std.testing;

const html_ns = "http://www.w3.org/1999/xhtml";

fn str(value: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(value);
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    body: *runtime.Instance,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(testing.allocator);
        self.ctx = try runtime.ContextData.init(testing.allocator, .{});
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        const html = try interfaces.Document.call_createElementNS(self.document, str(html_ns), str("html"), .notPassed());
        _ = try interfaces.Node.call_appendChild(self.document, html);
        const head = try interfaces.Document.call_createElementNS(self.document, str(html_ns), str("head"), .notPassed());
        _ = try interfaces.Node.call_appendChild(html, head);
        self.body = try interfaces.Document.call_createElementNS(self.document, str(html_ns), str("body"), .notPassed());
        _ = try interfaces.Node.call_appendChild(html, self.body);
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn expectString(self: *Fixture, expected: []const u8, got: runtime.DOMString) !void {
        var value = got;
        defer value.deinit(self.ctx.allocator);
        try testing.expectEqualStrings(expected, value.asSlice());
    }

    fn expectNullableString(self: *Fixture, expected: ?[]const u8, got: ?runtime.DOMString) !void {
        if (expected) |text| {
            try testing.expect(got != null);
            try self.expectString(text, got.?);
        } else {
            try testing.expect(got == null);
        }
    }
};

test "Element and HTMLElement attributes reflect their content attributes" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const div = try interfaces.Document.call_createElementNS(f.document, str(html_ns), str("div"), .notPassed());
    _ = try interfaces.Node.call_appendChild(f.body, div);

    // Element: id, className and slot reflect id, class and slot.
    try f.expectString("", try interfaces.Element.get_id(div));
    try interfaces.Element.set_id(div, str("main"));
    try f.expectString("main", try interfaces.Element.get_id(div));
    try interfaces.Element.set_className(div, str("a b"));
    try f.expectString("a b", try interfaces.Element.get_className(div));
    try interfaces.Element.set_slot(div, str("s"));
    try f.expectString("s", try interfaces.Element.get_slot(div));
    try f.expectString("DIV", try interfaces.Element.get_tagName(div));
    try f.expectString("div", try interfaces.Element.get_localName(div));

    // HTMLElement: title, lang, dir and accessKey reflect; translate,
    // draggable, spellcheck, autofocus and tabIndex keep their own rules.
    try f.expectString("", try interfaces.HTMLElement.get_title(div));
    try interfaces.HTMLElement.set_title(div, str("tip"));
    try f.expectString("tip", try interfaces.HTMLElement.get_title(div));
    try interfaces.HTMLElement.set_lang(div, str("fr"));
    try f.expectString("fr", try interfaces.HTMLElement.get_lang(div));
    try interfaces.HTMLElement.set_dir(div, str("RTL"));
    try f.expectString("rtl", try interfaces.HTMLElement.get_dir(div));
    try interfaces.HTMLElement.set_accessKey(div, str("k"));
    try f.expectString("k", try interfaces.HTMLElement.get_accessKey(div));
    try testing.expect(try interfaces.HTMLElement.get_translate(div));
    try interfaces.HTMLElement.set_translate(div, false);
    try testing.expect(!try interfaces.HTMLElement.get_translate(div));
    try testing.expect(!try interfaces.HTMLElement.get_draggable(div));
    try interfaces.HTMLElement.set_draggable(div, true);
    try testing.expect(try interfaces.HTMLElement.get_draggable(div));
    try testing.expect(!try interfaces.HTMLElement.get_autofocus(div));
    try interfaces.HTMLElement.set_autofocus(div, true);
    try testing.expect(try interfaces.HTMLElement.get_autofocus(div));
    try testing.expectEqual(@as(i32, -1), try interfaces.HTMLElement.get_tabIndex(div));
    try interfaces.HTMLElement.set_tabIndex(div, 3);
    try testing.expectEqual(@as(i32, 3), try interfaces.HTMLElement.get_tabIndex(div));

    // The content attributes are what the accessors wrote.
    const data = dom.element_data.of(div) orelse return error.NoElementData;
    try testing.expectEqualStrings("main", dom.element_data.getAttributeValue(data, "id", null));
    try testing.expectEqualStrings("tip", dom.element_data.getAttributeValue(data, "title", null));
    try testing.expectEqualStrings("RTL", dom.element_data.getAttributeValue(data, "dir", null));
    try testing.expectEqualStrings("3", dom.element_data.getAttributeValue(data, "tabindex", null));
}

test "Node, CharacterData and Text attributes read the node's own data" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const p = try interfaces.Document.call_createElementNS(f.document, str(html_ns), str("p"), .notPassed());
    _ = try interfaces.Node.call_appendChild(f.body, p);
    const text = try interfaces.Document.call_createTextNode(f.document, str("one"));
    _ = try interfaces.Node.call_appendChild(p, text);
    const comment = try interfaces.Document.call_createComment(f.document, str("note"));
    _ = try interfaces.Node.call_appendChild(p, comment);

    try testing.expectEqual(interfaces.Node.get_TEXT_NODE(), try interfaces.Node.get_nodeType(text));
    try f.expectString("#text", try interfaces.Node.get_nodeName(text));
    try f.expectString("#comment", try interfaces.Node.get_nodeName(comment));
    try f.expectString("P", try interfaces.Node.get_nodeName(p));
    try testing.expect(try interfaces.Node.get_isConnected(text));
    try testing.expectEqual(p, (try interfaces.Node.get_parentNode(text)).?);
    try testing.expectEqual(text, (try interfaces.Node.get_firstChild(p)).?);

    try f.expectString("one", try interfaces.CharacterData.get_data(text));
    try testing.expectEqual(@as(u32, 3), try interfaces.CharacterData.get_length(text));
    try interfaces.CharacterData.set_data(text, str("three"));
    try testing.expectEqual(@as(u32, 5), try interfaces.CharacterData.get_length(text));
    try f.expectNullableString("three", try interfaces.Node.get_nodeValue(text));
    try interfaces.Node.set_nodeValue(text, str("two"));
    try f.expectString("two", try interfaces.CharacterData.get_data(text));
    try f.expectString("two", try interfaces.Text.get_wholeText(text));
    try f.expectString("note", try interfaces.CharacterData.get_data(comment));

    // An element's nodeValue is null and its textContent its Text
    // descendants' data, comments left out.
    try f.expectNullableString(null, try interfaces.Node.get_nodeValue(p));
    try f.expectNullableString("two", try interfaces.Node.get_textContent(p));
    try testing.expectEqual(@as(u32, 0), try interfaces.Element.get_childElementCount(p));
    // Setting it on an empty element makes its one Text child.
    const q = try interfaces.Document.call_createElementNS(f.document, str(html_ns), str("q"), .notPassed());
    _ = try interfaces.Node.call_appendChild(f.body, q);
    try interfaces.Node.set_textContent(q, str("set"));
    try f.expectNullableString("set", try interfaces.Node.get_textContent(q));
    const made = (try interfaces.Node.get_firstChild(q)).?;
    try f.expectString("set", try interfaces.CharacterData.get_data(made));
}

test "Document and DocumentFragment attributes read the document and its tree" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();

    try f.expectString("CSS1Compat", try interfaces.Document.get_compatMode(f.document));
    try f.expectString("text/html", try interfaces.Document.get_contentType(f.document));
    try f.expectString("UTF-8", try interfaces.Document.get_characterSet(f.document));
    try testing.expect((try interfaces.Document.get_documentElement(f.document)) != null);
    try testing.expectEqual(f.body, (try interfaces.Document.get_body(f.document)).?);
    try testing.expect((try interfaces.Document.get_head(f.document)) != null);
    try testing.expectEqual(@as(u32, 1), try interfaces.Document.get_childElementCount(f.document));
    try f.expectString("", try interfaces.Document.get_title(f.document));
    try interfaces.Document.set_title(f.document, str("A title"));
    try f.expectString("A title", try interfaces.Document.get_title(f.document));
    try interfaces.Document.set_dir(f.document, str("ltr"));
    try f.expectString("ltr", try interfaces.Document.get_dir(f.document));

    const fragment = try interfaces.Document.call_createDocumentFragment(f.document);
    const span = try interfaces.Document.call_createElementNS(f.document, str(html_ns), str("span"), .notPassed());
    _ = try interfaces.Node.call_appendChild(fragment, span);
    try testing.expectEqual(@as(u32, 1), try interfaces.DocumentFragment.get_childElementCount(fragment));
    try testing.expectEqual(span, (try interfaces.DocumentFragment.get_firstElementChild(fragment)).?);
    // Inserting the fragment moves its children and leaves it empty.
    _ = try interfaces.Node.call_appendChild(f.body, fragment);
    try testing.expectEqual(@as(u32, 0), try interfaces.DocumentFragment.get_childElementCount(fragment));
    try testing.expectEqual(f.body, (try interfaces.Node.get_parentNode(span)).?);
    dom.node_creation.destroyUninserted(fragment);
}
