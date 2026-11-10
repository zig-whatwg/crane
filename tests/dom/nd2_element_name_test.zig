//! An element's qualified name as ONE pointer to a shared record (lane nd2,
//! batch 1, phase N2; tmp/redesign/nodedata-design.md 4.1 N2,
//! tmp/redesign/nodedata/techniques.md T2).
//!
//! Every element kept its namespace (a 32-byte ?DOMString) and its local
//! name (a 24-byte DOMString) in its ElementData, and its prefix (32 more)
//! in its rare data - static strings on 91-100% of the elements of real
//! pages (crane-layout.md P2). The engines keep ONE pointer:
//! - Blink's Element has `QualifiedName tag_name_`, a pointer to a
//!   QualifiedNameImpl {prefix_, local_name_, namespace_, local_name_upper_}
//!   that every element of that name shares: static for the names
//!   html_names / svg_names / mathml_names define, else interned in the
//!   QualifiedNameCache (core/dom/qualified_name.h, qualified_name.cc).
//! - WebKit's QualifiedName is the same shape (m_prefix, m_localName,
//!   m_namespaceURI, m_localNameUpper, its Namespace and NodeName ids;
//!   Source/WebCore/dom/QualifiedName.h), interned in a QualifiedNameCache.
//! - Gecko's nsINode::mNodeInfo is one pointer to a NodeInfo per name and
//!   document, from the document's nsNodeInfoManager, with the qualified
//!   name and the nodeName - uppercased for an HTML element in an HTML
//!   document - precomputed (dom/base/NodeInfo.cpp).
//!
//! N2 does the same: `ElementData.name` points to an ElementName record -
//! namespace, prefix, local name, qualified name and its ASCII uppercase -
//! static for the HTML, SVG and MathML names html_core's tag table knows,
//! else interned in its Browser's name table (exact for every namespace and
//! prefix, never a lossy enum), living as long as its Browser.
//!
//! The size pins and the record tests are red until N2 lands. The names
//! tests hold before and after it.
//!
//! These name only generated interfaces, their States and src/dom types:
//! Element's InternalState is reached as its State's field type, never
//! through its impl (AGENTS.md "The impls boundary").

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const infra = @import("infra");

const ElementData = dom.element_data.ElementData;
const ElementRareData = dom.element_rare_data.ElementRareData;

/// Whether N2's record is in this build.
const has_record = @hasField(ElementData, "name");

/// Element's InternalState, as its generated State keeps it by value.
const ElementState = @FieldType(interfaces.Element.State, "_embedded");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn printLayout(comptime T: type) void {
    @setEvalBranchQuota(100_000);
    std.debug.print("\n{s}: {d} bytes, align {d} (mode {s}, runtime_safety {})\n", .{ @typeName(T), @sizeOf(T), @alignOf(T), @tagName(builtin.mode), std.debug.runtime_safety });
    std.debug.print("{s:<34} {s:>6} {s:>6} {s:>6}  {s}\n", .{ "field", "offset", "size", "align", "type" });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("{s:<34} {d:>6} {d:>6} {d:>6}  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @alignOf(F), @typeName(F) });
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

fn expectNoFields(comptime T: type, comptime gone: anytype) !void {
    var found: usize = 0;
    inline for (gone) |name| {
        if (@hasField(T, name)) {
            std.debug.print("{s} still has `{s}`\n", .{ @typeName(T), name });
            found += 1;
        }
    }
    if (found != 0) {
        printLayout(T);
        return error.FieldStillThere;
    }
}

// ============================================================================
// Sizes (red until N2)
// ============================================================================

test "ElementData names its element with one 8-byte record pointer: 64 bytes at N2, 16 after N3" {
    // 112 at main b1bd4eae568: - 32 (namespace_uri, a ?DOMString) - 24
    // (local_name, a DOMString) + 8 (the record pointer).
    try expectNoFields(ElementData, .{ "namespace_uri", "local_name" });
    if (comptime !has_record) {
        printLayout(ElementData);
        return error.NameStillInline;
    } else {
        try testing.expect(@FieldType(ElementData, "name") == *const dom.element_name.ElementName);
        // 64 at N2; N3 took the ID and classes views out (48,
        // tests/dom/nd2_id_class_index_test.zig).
        try expectSize(ElementData, 16);
    }
}

test "ElementRareData keeps no prefix: it is the name record's - 312 bytes" {
    // 344 at main b1bd4eae568: - 32 (the prefix, a ?DOMString). Blink's
    // QualifiedName carries the prefix (QualifiedNameImpl::prefix_).
    try expectNoFields(ElementRareData, .{"prefix"});
    try expectSize(ElementRareData, 312);
}

test "Element's InternalState is 88 bytes at N2, 40 after N3" {
    // 136 at main b1bd4eae568, less ElementData's 48: 88; N3 48 more.
    try expectSize(ElementState, 40);
}

test "a div's one block is 312 bytes at N2 (a 320-byte class), 264 after N3 (272)" {
    // 360 at main b1bd4eae568 (a 368-byte class), less ElementData's 48.
    const S = interfaces.HTMLDivElement.State;
    // N3: 48 more (ElementData's ID and classes views).
    try expectSize(S, 264);
    const held = runtime.ArenaAllocator.heldBytes(@sizeOf(S), @alignOf(S));
    try testing.expectEqual(@as(usize, 272), held);
}

// ============================================================================
// An engine-less page
// ============================================================================

/// An HTML document with one div in it.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(testing.allocator), .ctx = try runtime.ContextData.init(testing.allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    fn elementNS(self: *Page, namespace: ?[]const u8, qualified_name: []const u8) !*runtime.Instance {
        const ns: ?runtime.DOMString = if (namespace) |n| str(n) else null;
        const el = try interfaces.Document.call_createElementNS(self.document, ns, str(qualified_name), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.div, el);
        return el;
    }

    /// `el`'s localName, namespaceURI, prefix and tagName, checked.
    fn expectNames(self: *Page, el: *runtime.Instance, namespace: ?[]const u8, prefix: ?[]const u8, local_name: []const u8, tag_name: []const u8) !void {
        const allocator = self.ctx.allocator;
        var local = try interfaces.Element.get_localName(el);
        defer local.deinit(allocator);
        try testing.expectEqualStrings(local_name, local.asSlice());
        var ns = try interfaces.Element.get_namespaceURI(el);
        defer if (ns) |*n| n.deinit(allocator);
        if (namespace) |expected| try testing.expectEqualStrings(expected, ns.?.asSlice()) else try testing.expect(ns == null);
        var p = try interfaces.Element.get_prefix(el);
        defer if (p) |*value| value.deinit(allocator);
        if (prefix) |expected| try testing.expectEqualStrings(expected, p.?.asSlice()) else try testing.expect(p == null);
        var tag = try interfaces.Element.get_tagName(el);
        defer tag.deinit(allocator);
        try testing.expectEqualStrings(tag_name, tag.asSlice());
        var node_name = try interfaces.Node.get_nodeName(el);
        defer node_name.deinit(allocator);
        try testing.expectEqualStrings(tag_name, node_name.asSlice());
        // dom.node_creation's borrowed names agree.
        const names = dom.node_creation.elementNames(el).?;
        try testing.expectEqualStrings(local_name, names.local_name);
        if (prefix) |expected| try testing.expectEqualStrings(expected, names.prefix.?) else try testing.expect(names.prefix == null);
        if (namespace) |expected| try testing.expectEqualStrings(expected, names.namespace.?) else try testing.expect(names.namespace == null);
    }
};

// ============================================================================
// Names (hold before and after N2)
// ============================================================================

test "every namespace, prefix and case keeps its exact names; tagName uppercases only an HTML element in an HTML document" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    const html = infra.namespaces.HTML_NAMESPACE;
    const svg = infra.namespaces.SVG_NAMESPACE;
    const mathml = infra.namespaces.MATHML_NAMESPACE;
    // createElement lowercases in an HTML document; DOM 4.9's tagName is the
    // HTML-uppercased qualified name.
    try page.expectNames(page.div, html, null, "div", "DIV");
    const upper = try page.element("SPAN");
    _ = try interfaces.Node.call_appendChild(page.div, upper);
    try page.expectNames(upper, html, null, "span", "SPAN");
    // A custom element name, and one no table has.
    const custom = try page.element("x-foo");
    _ = try interfaces.Node.call_appendChild(page.div, custom);
    try page.expectNames(custom, html, null, "x-foo", "X-FOO");
    // createElementNS keeps the case and the prefix.
    try page.expectNames(try page.elementNS(html, "p:Div"), html, "p", "Div", "P:DIV");
    try page.expectNames(try page.elementNS(html, "DIV"), html, null, "DIV", "DIV");
    try page.expectNames(try page.elementNS(svg, "circle"), svg, null, "circle", "circle");
    try page.expectNames(try page.elementNS(svg, "svg:foreignObject"), svg, "svg", "foreignObject", "svg:foreignObject");
    try page.expectNames(try page.elementNS(mathml, "mi"), mathml, null, "mi", "mi");
    // Any other namespace is kept exactly, prefix and all; no namespace too.
    try page.expectNames(try page.elementNS("urn:x", "x:Foo"), "urn:x", "x", "Foo", "x:Foo");
    try page.expectNames(try page.elementNS("urn:x", "div"), "urn:x", null, "div", "div");
    try page.expectNames(try page.elementNS(null, "foo"), null, null, "foo", "foo");
    try page.expectNames(try page.elementNS("", "Bar"), null, null, "Bar", "Bar");
    // A non-ASCII name uppercases its ASCII letters only.
    try page.expectNames(try page.elementNS(html, "x-\u{e9}t\u{e9}"), html, null, "x-\u{e9}t\u{e9}", "X-\u{e9}T\u{e9}");

    // A clone keeps every name.
    const clone = try interfaces.Node.call_cloneNode(try page.elementNS("urn:y", "q:Thing"), .{ .was_passed = true, .value = false });
    _ = try interfaces.Node.call_appendChild(page.div, clone);
    try page.expectNames(clone, "urn:y", "q", "Thing", "q:Thing");
}

test "in an XML document tagName keeps an HTML element's case" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    const xml = try interfaces.Document.init(testing.allocator, &page.ctx);
    defer interfaces.Document.deinit(xml);
    try dom.document_internals.setContentType(xml, "application/xml");
    try dom.document_internals.setDocumentType(xml, .xml);
    const el = try interfaces.Document.call_createElementNS(xml, str(infra.namespaces.HTML_NAMESPACE), str("p:div"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(xml, el);
    try page.expectNames(el, infra.namespaces.HTML_NAMESPACE, "p", "div", "p:div");
    // Adopted into the HTML document, the same element uppercases.
    _ = try interfaces.Document.call_adoptNode(page.document, el);
    _ = try interfaces.Node.call_appendChild(page.div, el);
    try page.expectNames(el, infra.namespaces.HTML_NAMESPACE, "p", "div", "P:DIV");
}

// ============================================================================
// The records (red until N2)
// ============================================================================

test "a known name is one static record every element shares; any other is interned once per Browser" {
    if (comptime !has_record) return error.NameStillInline else {
        var page: Page = undefined;
        try page.open();
        defer page.close();

        const html = infra.namespaces.HTML_NAMESPACE;
        const data = dom.element_data.of;
        const div_name = data(page.div).?.name;
        try testing.expect(div_name.is_static);
        try testing.expect(div_name.namespace_uri.?.ptr == html.ptr);
        try testing.expectEqualStrings("DIV", div_name.qualified_name_upper);
        // createElement and createElementNS make the same name: one record.
        const div2 = try page.element("div");
        _ = try interfaces.Node.call_appendChild(page.div, div2);
        try testing.expect(data(div2).?.name == div_name);
        try testing.expect(data(try page.elementNS(html, "div")).?.name == div_name);
        // SVG and MathML names are static too.
        try testing.expect(data(try page.elementNS(infra.namespaces.SVG_NAMESPACE, "path")).?.name.is_static);
        try testing.expect(data(try page.elementNS(infra.namespaces.MATHML_NAMESPACE, "mrow")).?.name.is_static);

        // A custom name is interned: two elements, one record of the Browser's.
        const a = try page.element("x-item");
        const b = try page.element("x-item");
        _ = try interfaces.Node.call_appendChild(page.div, a);
        _ = try interfaces.Node.call_appendChild(page.div, b);
        const custom = data(a).?.name;
        try testing.expect(!custom.is_static);
        try testing.expect(data(b).?.name == custom);
        try testing.expectEqualStrings("X-ITEM", custom.qualified_name_upper);
        // So is a namespaced, prefixed one - exact, the namespace static.
        const prefixed = data(try page.elementNS(html, "p:div")).?.name;
        try testing.expect(prefixed != div_name and !prefixed.is_static);
        try testing.expect(prefixed.namespace_uri.?.ptr == html.ptr);
        try testing.expectEqualStrings("p", prefixed.prefix.?);
        try testing.expectEqualStrings("p:div", prefixed.qualified_name);
        // Blink's QualifiedName::Matches: same namespace and local name.
        try testing.expect(prefixed.matches(div_name));
        try testing.expect(!custom.matches(div_name));
        const other = data(try page.elementNS("urn:x", "div")).?.name;
        try testing.expect(!other.matches(div_name));
        try testing.expect(data(try page.elementNS("urn:x", "div")).?.name == other);
        // A clone shares its original's record.
        const clone = try interfaces.Node.call_cloneNode(a, .{ .was_passed = true, .value = false });
        _ = try interfaces.Node.call_appendChild(page.div, clone);
        try testing.expect(data(clone).?.name == custom);
    }
}

test "each Browser interns its own records, freed with it" {
    if (comptime !has_record) return error.NameStillInline else {
        var first: Page = undefined;
        try first.open();
        defer first.close();
        var second: Page = undefined;
        try second.open();
        defer second.close();

        const one = try first.element("x-shared");
        _ = try interfaces.Node.call_appendChild(first.div, one);
        const two = try second.element("x-shared");
        _ = try interfaces.Node.call_appendChild(second.div, two);
        const one_name = dom.element_data.of(one).?.name;
        const two_name = dom.element_data.of(two).?.name;
        try testing.expect(one_name != two_name);
        try testing.expectEqualStrings(one_name.local_name, two_name.local_name);
        // A static name is the same in both.
        try testing.expect(dom.element_data.of(first.div).?.name == dom.element_data.of(second.div).?.name);
        // An element that goes keeps nothing alive: its record is its
        // Browser's (std.testing.allocator checks both ends free it all).
        const gone = try first.element("x-gone");
        dom.node_creation.destroyUninserted(gone);
        const again = try first.element("x-gone");
        _ = try interfaces.Node.call_appendChild(first.div, again);
        try testing.expectEqualStrings("x-gone", dom.element_data.of(again).?.name.local_name);
    }
}

test "a custom element's prefix, set by create-an-element after its names, joins its record" {
    if (comptime !has_record) return error.NameStillInline else {
        var page: Page = undefined;
        try page.open();
        defer page.close();

        // create-an-element sets the namespace and local name first, then
        // the prefix and is value (dom.custom_elements.initialize).
        const el = try interfaces.Element.init(testing.allocator, &page.ctx);
        defer dom.node_creation.destroyUninserted(el);
        try dom.node_creation.setElementNames(el, infra.namespaces.HTML_NAMESPACE, "x-late");
        try dom.custom_elements.initialize(el, "pre", "x-is", .undefined);
        const name = dom.element_data.of(el).?.name;
        try testing.expectEqualStrings("pre", name.prefix.?);
        try testing.expectEqualStrings("x-late", name.local_name);
        try testing.expectEqualStrings("pre:x-late", name.qualified_name);
        try testing.expectEqualStrings("x-is", dom.node_creation.elementIsValue(el).?);
        // Clearing both leaves the unprefixed record.
        try dom.custom_elements.initialize(el, null, null, .undefined);
        try testing.expect(dom.element_data.of(el).?.name.prefix == null);
        try testing.expect(dom.node_creation.elementIsValue(el) == null);
    }
}
