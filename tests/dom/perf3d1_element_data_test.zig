//! An element's attribute data out of line (lane perf3, D1;
//! tmp/plans/perf3b2-element-data-design.md).
//!
//! A kept div cost Crane 2,259 bytes against 173-260 in Chrome, Firefox,
//! Safari and Lightpanda (perf round 2). 848 of them were Element's
//! InternalState, in a 1,024-byte arena block, and 584 of those its
//! ElementData, whose four inline 96-byte attribute slots were empty for 43%
//! of the 3.04 M elements of the perf pages. Blink and WebKit keep an
//! element's attributes out of line, in an ElementData that is null for an
//! element with none, as 16-byte Attributes: an interned QualifiedName and an
//! atomic value (core/dom/element_data.h, attribute.h; WebCore/dom/
//! ElementData.h, Attribute.h). D1 does the same: a 24-byte Attribute (a
//! name record - static for the known names, else the attribute's own - and
//! its owned value) in an exact-size list, the element's namespace the
//! static string, the ID and classes views re-derived from the list.
//!
//! The size pins are red until D1 lands. The behaviour tests hold before and
//! after it: attribute order, the ID and classes through every mutation,
//! names outside the known table (data-*, custom, upper case, namespaced,
//! prefixed), Attr node identity across the list's reallocation, cloning,
//! and both exits freeing everything. The reallocation test runs its Browser
//! on a poisoning DebugAllocator (0xdd over every freed block): an ID or
//! class view left pointing into a list that moved reads poison.
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

const element_data = dom.element_data;
const ElementData = element_data.ElementData;

/// Whether D1's out-of-line list is in this build.
/// Whether the list is out of line: its entries a type of their own (lane
/// perf3 D1's `Attribute`, lane nd2 batch 2's 8-byte `Entry`).
const out_of_line = @hasDecl(element_data, "Attribute") or @hasDecl(element_data, "Entry");

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

/// Element's InternalState, as its generated State keeps it by value (the
/// State's `_embedded`; since lane perf2 batch 6 an embedded level keeps no
/// `own._internal` pointer to it).
const ElementState = @FieldType(interfaces.Element.State, "_embedded");

// ============================================================================
// Sizes (red until D1)
// ============================================================================

test "the std and runtime parts the pins count are the sizes they were pinned with" {
    try testing.expectEqual(@as(usize, 24), @sizeOf(runtime.DOMString));
    try testing.expectEqual(@as(usize, 32), @sizeOf(?runtime.DOMString));
    try testing.expectEqual(@as(usize, 16), @sizeOf([]const u8));
    try testing.expectEqual(@as(usize, 16), @sizeOf(?[]const u8));
}

test "an attribute is an 8-byte entry: a name id and a value id, its records shared" {
    if (comptime !out_of_line) {
        std.debug.print("\nElementData still keeps its attributes inline ({d} bytes)\n", .{@sizeOf(ElementData)});
        return error.AttributesStillInline;
    } else {
        // Blink's and WebKit's are 16: a QualifiedName and an AtomicString,
        // two pointers to shared records. Here the two records are u32 ids
        // (lane nd2 batch 2: A1 + A2): dom.attribute_names, a static record
        // for a known name and the Browser's counted one otherwise, and
        // dom.attribute_values, the Browser's counted record of the value.
        try expectSize(element_data.Entry, 8);
        try testing.expect(@FieldType(element_data.Entry, "name") == element_data.NameId);
        try testing.expect(@FieldType(element_data.Entry, "value") == element_data.ValueId);
        // The list's header: its length and capacity, then the entries.
        try expectSize(element_data.AttributeList, 8);
    }
}

test "ElementData is 16 bytes: the list out of line, no allocator, the Attr nodes rare data, the name one record, the ID and classes indices in the list" {
    if (comptime !out_of_line) {
        printLayout(ElementData);
        return error.AttributesStillInline;
    } else {
        // 584 at 5b07812bf00: - 384 (four inline 96-byte slots) - 1 (their
        // count) - 40 (the heap list) - 16 (the allocator copy) + 8 (the
        // list) + 8 (the Attr nodes) = 152 at D1; D2 moved the prefix (32)
        // and the Attr nodes (8) to the element's rare data
        // (tests/dom/perf3d2_element_rare_data_test.zig): namespace 32, local
        // name 24, ID 24, classes 24, list 8: 112. Lane nd2 N2 made the
        // namespace and local name one record pointer (8; the prefix joined
        // it from rare data): 64 (tests/dom/nd2_element_name_test.zig).
        // N3 kept the ID and classes as two indices in the list's header
        // (tests/dom/nd2_id_class_index_test.zig): 16.
        try expectSize(ElementData, 16);
        inline for (.{ "allocator", "inline_attrs", "inline_attr_count", "heap_attrs" }) |gone| {
            if (@hasField(ElementData, gone)) {
                std.debug.print("ElementData still has `{s}`\n", .{gone});
                return error.FieldStillThere;
            }
        }
        try testing.expectEqual(@as(usize, 8), @sizeOf(@FieldType(ElementData, "attrs")));
    }
}

test "Element's InternalState is 40 bytes" {
    // 848 at 5b07812bf00: - 432 (ElementData's diet) = 416 at D1, Element
    // still keeping its 16-byte allocator copy then (in the V8 tests' realms
    // the creation allocator was not the scope's: docs/lessons/
    // architecture-a-nodes-creation-allocator-is-its-browsers-only-inside-a-
    // browser.md); D2 took the copy out and the cold fields into rare data
    // (tests/dom/perf3d2_element_rare_data_test.zig): 240; E1 its registry
    // association (tests/dom/perf3e1_element_registry_test.zig): 200, and
    // its slottable state (tests/dom/perf3e1_slottable_test.zig): 136; nd2
    // N2 its name (tests/dom/nd2_element_name_test.zig): 88.
    // N3 the ID and classes views: 40.
    try expectSize(ElementState, 40);
    // Kept by value in its element's one State block (perf2 b5, Z7), or in a
    // block of its own before that: either way at most 512 bytes of arena.
    try testing.expect(runtime.ArenaAllocator.heldBytes(@sizeOf(ElementState), @alignOf(ElementState)) <= 512);
}

// A div's whole State block is pinned in ONE place: tests/dom/node_block_sizes_test.zig
// (lane cg1; lesson testing-a-total-pinned-in-six-files-moves-in-six-files.md).

// ============================================================================
// An engine-less page
// ============================================================================

/// An HTML document with one div in it, made with `allocator`.
const Page = struct {
    allocator: std.mem.Allocator,
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .allocator = allocator, .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn data(self: *Page, el: *runtime.Instance) !element_data.View {
        _ = self;
        return element_data.of(el) orelse error.NoElementData;
    }

    /// The qualified names of `el`'s attributes in list order, joined by " ".
    fn names(self: *Page, el: *runtime.Instance, buffer: []u8) ![]const u8 {
        _ = self;
        var stream: std.Io.Writer = .fixed(buffer);
        var index: usize = 0;
        while (dom.element_attributes.at(el, index)) |attribute| : (index += 1) {
            if (index > 0) try stream.writeAll(" ");
            if (attribute.prefix) |p| try stream.print("{s}:", .{p});
            try stream.writeAll(attribute.local_name);
        }
        return stream.buffered();
    }

    fn expectNames(self: *Page, el: *runtime.Instance, expected: []const u8) !void {
        var buffer: [512]u8 = undefined;
        try testing.expectEqualStrings(expected, try self.names(el, &buffer));
    }

    fn expectId(self: *Page, el: *runtime.Instance, expected: []const u8) !void {
        try testing.expectEqualStrings(expected, (try self.data(el)).idValue());
        var id = try interfaces.Element.get_id(el);
        defer id.deinit(self.ctx.allocator);
        try testing.expectEqualStrings(expected, id.asSlice());
    }

    fn expectClassName(self: *Page, el: *runtime.Instance, expected: []const u8) !void {
        try testing.expectEqualStrings(expected, (try self.data(el)).classValue());
        var class_name = try interfaces.Element.get_className(el);
        defer class_name.deinit(self.ctx.allocator);
        try testing.expectEqualStrings(expected, class_name.asSlice());
    }
};

// ============================================================================
// The safety rule: nothing reads the list across a reallocation
// ============================================================================

test "the ID and classes survive the list's reallocation (poisoning DebugAllocator)" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    // Set the ID and classes first, so they are the list's first attributes,
    // then grow the list well past any first allocation: it reallocates
    // (moves) several times, and the old blocks are poisoned.
    try interfaces.Element.call_setAttribute(page.div, str("id"), .{ .domstring = str("main") });
    try interfaces.Element.call_setAttribute(page.div, str("class"), .{ .domstring = str("a b") });
    const before = (try page.data(page.div)).findAttribute(null, "id").?;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        var buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "data-n{d}", .{i});
        try interfaces.Element.call_setAttribute(page.div, str(name), .{ .domstring = str(name) });
    }
    try page.expectId(page.div, "main");
    try page.expectClassName(page.div, "a b");
    // A view a reader took before the growth reads the value's own buffer.
    try testing.expectEqualStrings("main", before.value);
    try testing.expectEqual(@as(usize, 22), (try page.data(page.div)).getAttributeCount());

    // Removing attributes before them moves the list's contents; the ID and
    // classes follow, and so does getElementById.
    try interfaces.Element.call_removeAttribute(page.div, str("data-n0"));
    try interfaces.Element.call_removeAttribute(page.div, str("data-n1"));
    try page.expectId(page.div, "main");
    try page.expectClassName(page.div, "a b");
    try testing.expect((try interfaces.Document.call_getElementById(page.document, str("main"))) == page.div);
    // And a change to the ID after all that re-derives it.
    try interfaces.Element.call_setAttribute(page.div, str("id"), .{ .domstring = str("other") });
    try page.expectId(page.div, "other");
    try testing.expect((try interfaces.Document.call_getElementById(page.document, str("main"))) == null);
    try testing.expect((try interfaces.Document.call_getElementById(page.document, str("other"))) == page.div);
}

test "the ID and classes follow set, change, remove, toggle and the namespaced lookalikes" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try page.expectId(page.div, "");
    try page.expectClassName(page.div, "");
    try interfaces.Element.set_id(page.div, str("x"));
    try interfaces.Element.set_className(page.div, str("c1"));
    try page.expectId(page.div, "x");
    try page.expectClassName(page.div, "c1");
    try interfaces.Element.call_setAttribute(page.div, str("ID"), .{ .domstring = str("y") });
    try page.expectId(page.div, "y");
    // An id or class attribute in a namespace is not the element's.
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("p:id"), .{ .domstring = str("ns") });
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("p:class"), .{ .domstring = str("ns") });
    try page.expectId(page.div, "y");
    try page.expectClassName(page.div, "c1");
    // An empty value unsets the ID.
    try interfaces.Element.call_setAttribute(page.div, str("id"), .{ .domstring = str("") });
    try page.expectId(page.div, "");
    try interfaces.Element.call_setAttribute(page.div, str("id"), .{ .domstring = str("z") });
    try interfaces.Element.call_removeAttribute(page.div, str("id"));
    try page.expectId(page.div, "");
    // toggleAttribute adds an empty class, then removes it.
    try interfaces.Element.call_removeAttribute(page.div, str("class"));
    try page.expectClassName(page.div, "");
    try testing.expect(try interfaces.Element.call_toggleAttribute(page.div, str("class"), .{ .was_passed = false, .value = undefined }));
    try page.expectClassName(page.div, "");
    try interfaces.Element.call_setAttribute(page.div, str("class"), .{ .domstring = str("t") });
    try page.expectClassName(page.div, "t");
    try testing.expect(!try interfaces.Element.call_toggleAttribute(page.div, str("class"), .{ .was_passed = false, .value = undefined }));
    try page.expectClassName(page.div, "");
    try page.expectNames(page.div, "p:id p:class");
}

// ============================================================================
// Order and names
// ============================================================================

test "attribute order holds through append, change, remove and replace, 0 to 5 to 0" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try page.expectNames(page.div, "");
    for ([_][]const u8{ "a", "b", "c", "d", "e" }) |name| {
        try interfaces.Element.call_setAttribute(page.div, str(name), .{ .domstring = str(name) });
    }
    try page.expectNames(page.div, "a b c d e");
    // A change keeps the attribute's place.
    try interfaces.Element.call_setAttribute(page.div, str("b"), .{ .domstring = str("B") });
    try page.expectNames(page.div, "a b c d e");
    try testing.expectEqualStrings("B", element_data.getAttributeValue(try page.data(page.div), "b", null));
    // A replace (setAttributeNode with a new Attr of the same name) too.
    const attr = try interfaces.Document.call_createAttribute(page.document, str("c"));
    try interfaces.Attr.set_value(attr, str("C"));
    const old = (try interfaces.Element.call_setAttributeNode(page.div, attr)).?;
    try page.expectNames(page.div, "a b c d e");
    try testing.expectEqualStrings("C", element_data.getAttributeValue(try page.data(page.div), "c", null));
    var old_value = try interfaces.Attr.get_value(old);
    defer old_value.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("c", old_value.asSlice());
    try testing.expect((try interfaces.Attr.get_ownerElement(old)) == null);
    try testing.expect((try interfaces.Attr.get_ownerElement(attr)) == page.div);
    // Removal from the front, the middle and the end.
    try interfaces.Element.call_removeAttribute(page.div, str("a"));
    try page.expectNames(page.div, "b c d e");
    try interfaces.Element.call_removeAttribute(page.div, str("d"));
    try page.expectNames(page.div, "b c e");
    try interfaces.Element.call_removeAttribute(page.div, str("e"));
    try page.expectNames(page.div, "b c");
    try interfaces.Element.call_removeAttribute(page.div, str("b"));
    try interfaces.Element.call_removeAttribute(page.div, str("c"));
    try page.expectNames(page.div, "");
    try testing.expect(!try interfaces.Element.call_hasAttributes(page.div));
    // And it grows again from nothing.
    try interfaces.Element.call_setAttribute(page.div, str("f"), .{ .domstring = str("f") });
    try page.expectNames(page.div, "f");
}

test "names outside the known table keep their exact names: data-*, custom, upper case, namespaced, prefixed" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try interfaces.Element.call_setAttribute(page.div, str("data-foo-bar"), .{ .domstring = str("1") });
    try interfaces.Element.call_setAttribute(page.div, str("my-attr"), .{ .domstring = str("2") });
    // setAttributeNS keeps the case (no lowercasing outside setAttribute).
    try interfaces.Element.call_setAttributeNS(page.div, null, str("FOO"), .{ .domstring = str("3") });
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("p:q"), .{ .domstring = str("4") });
    try interfaces.Element.call_setAttributeNS(page.div, str(infra.namespaces.XLINK_NAMESPACE), str("xlink:href"), .{ .domstring = str("#a") });
    try interfaces.Element.call_setAttributeNS(page.div, str(infra.namespaces.XML_NAMESPACE), str("xml:lang"), .{ .domstring = str("en") });
    // A known local name in a namespace, and with another prefix.
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:y"), str("title"), .{ .domstring = str("5") });
    try interfaces.Element.call_setAttributeNS(page.div, str(infra.namespaces.XLINK_NAMESPACE), str("other:title"), .{ .domstring = str("6") });
    try page.expectNames(page.div, "data-foo-bar my-attr FOO p:q xlink:href xml:lang title other:title");

    const data = try page.data(page.div);
    try testing.expectEqualStrings("1", element_data.getAttributeValue(data, "data-foo-bar", null));
    try testing.expectEqualStrings("3", element_data.getAttributeValue(data, "FOO", null));
    try testing.expectEqualStrings("", element_data.getAttributeValue(data, "foo", null));
    try testing.expectEqualStrings("4", element_data.getAttributeValue(data, "q", "urn:x"));
    try testing.expectEqualStrings("#a", element_data.getAttributeValue(data, "href", infra.namespaces.XLINK_NAMESPACE));
    try testing.expectEqualStrings("en", element_data.getAttributeValue(data, "lang", infra.namespaces.XML_NAMESPACE));
    try testing.expectEqualStrings("5", element_data.getAttributeValue(data, "title", "urn:y"));
    try testing.expectEqualStrings("", element_data.getAttributeValue(data, "title", null));
    const xlink = data.findAttribute(infra.namespaces.XLINK_NAMESPACE, "href").?;
    try testing.expectEqualStrings("xlink", xlink.prefix.?);
    // getAttribute by qualified name; an HTML element in an HTML document
    // lowercases it, so "FOO" (upper case, set by setAttributeNS) is not
    // found by getAttribute("FOO").
    var q = (try interfaces.Element.call_getAttribute(page.div, str("p:q"))).?;
    defer q.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("4", q.asSlice());
    try testing.expect((try interfaces.Element.call_getAttribute(page.div, str("FOO"))) == null);
    var ns_value = (try interfaces.Element.call_getAttributeNS(page.div, str(infra.namespaces.XLINK_NAMESPACE), str("title"))).?;
    defer ns_value.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("6", ns_value.asSlice());

    // Removing them by namespace frees what each owns (the leak check).
    try interfaces.Element.call_removeAttributeNS(page.div, str("urn:x"), str("q"));
    try interfaces.Element.call_removeAttributeNS(page.div, null, str("FOO"));
    try page.expectNames(page.div, "data-foo-bar my-attr xlink:href xml:lang title other:title");
}

test "known names share a static record; other names have their own; a named namespace is static" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    if (comptime !out_of_line) {
        return error.AttributesStillInline;
    } else {
        const data = try page.data(page.div);
        // The element's namespace is the static string, not a copy.
        try testing.expect(data.namespaceSlice().?.ptr == infra.namespaces.HTML_NAMESPACE.ptr);
        try interfaces.Element.call_setAttribute(page.div, str("class"), .{ .domstring = str("a") });
        try interfaces.Element.call_setAttribute(page.div, str("onclick"), .{ .domstring = str("") });
        try interfaces.Element.call_setAttribute(page.div, str("aria-label"), .{ .domstring = str("x") });
        try interfaces.Element.call_setAttribute(page.div, str("data-x"), .{ .domstring = str("y") });
        try interfaces.Element.call_setAttributeNS(page.div, str(infra.namespaces.XLINK_NAMESPACE), str("xlink:href"), .{ .domstring = str("#a") });
        try interfaces.Element.call_setAttributeNS(page.div, str(infra.namespaces.XLINK_NAMESPACE), str("other:role"), .{ .domstring = str("r") });
        try testing.expect(data.data.storedAt(0).?.name.isStatic());
        try testing.expect(data.data.storedAt(1).?.name.isStatic());
        try testing.expect(data.data.storedAt(2).?.name.isStatic());
        try testing.expect(!data.data.storedAt(3).?.name.isStatic());
        try testing.expect(data.data.storedAt(4).?.name.isStatic());
        // xlink:role is in the table; other:role is not, and keeps the
        // static namespace string in its Browser's record.
        const other = data.nameAt(5).?;
        try testing.expect(!other.is_static);
        try testing.expect(other.namespace_uri.?.ptr == infra.namespaces.XLINK_NAMESPACE.ptr);
        // Two elements share the record of a known name.
        const span = try page.element("span");
        _ = try interfaces.Node.call_appendChild(page.div, span);
        try interfaces.Element.call_setAttribute(span, str("class"), .{ .domstring = str("b") });
        try testing.expect((try page.data(span)).data.storedAt(0).?.name == data.data.storedAt(0).?.name);
        // A foreign element's namespace is static too.
        const svg = try interfaces.Document.call_createElementNS(page.document, str(infra.namespaces.SVG_NAMESPACE), str("svg"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(page.div, svg);
        try testing.expect((try page.data(svg)).namespaceSlice().?.ptr == infra.namespaces.SVG_NAMESPACE.ptr);
    }
}

// ============================================================================
// Attr nodes, cloning, teardown
// ============================================================================

test "an Attr node stays the same node while the list grows, is replaced, and is removed" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try interfaces.Element.call_setAttribute(page.div, str("title"), .{ .domstring = str("t") });
    try interfaces.Element.call_setAttribute(page.div, str("data-k"), .{ .domstring = str("k") });
    const title = (try interfaces.Element.call_getAttributeNode(page.div, str("title"))).?;
    const data_k = (try interfaces.Element.call_getAttributeNode(page.div, str("data-k"))).?;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        var buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "a{d}", .{i});
        try interfaces.Element.call_setAttribute(page.div, str(name), .{ .domstring = str(name) });
    }
    try testing.expect((try interfaces.Element.call_getAttributeNode(page.div, str("title"))).? == title);
    try testing.expect((try interfaces.Element.call_getAttributeNode(page.div, str("data-k"))).? == data_k);
    try testing.expect((try interfaces.Element.call_getAttributeNodeNS(page.div, null, str("data-k"))).? == data_k);

    // The Attr's value setter changes the element's attribute.
    try interfaces.Attr.set_value(title, str("T2"));
    try testing.expectEqualStrings("T2", element_data.getAttributeValue(try page.data(page.div), "title", null));

    // An attribute removed before it moves the list; the node stays.
    try interfaces.Element.call_removeAttribute(page.div, str("a0"));
    try testing.expect((try interfaces.Element.call_getAttributeNode(page.div, str("data-k"))).? == data_k);

    // removeAttributeNode: the node keeps its last value and loses its element.
    _ = try interfaces.Element.call_removeAttributeNode(page.div, data_k);
    try testing.expect((try interfaces.Attr.get_ownerElement(data_k)) == null);
    var k = try interfaces.Attr.get_value(data_k);
    defer k.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("k", k.asSlice());
    try testing.expect((try interfaces.Element.call_getAttribute(page.div, str("data-k"))) == null);

    // setAttributeNode with a prefixed Attr of the same namespace and local
    // name replaces it in place, taking the new prefix.
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("p:n"), .{ .domstring = str("1") });
    const first = (try interfaces.Element.call_getAttributeNodeNS(page.div, str("urn:x"), str("n"))).?;
    const second = try interfaces.Document.call_createAttributeNS(page.document, str("urn:x"), str("q:n"));
    try interfaces.Attr.set_value(second, str("2"));
    try testing.expect((try interfaces.Element.call_setAttributeNode(page.div, second)).? == first);
    try testing.expect((try interfaces.Element.call_getAttributeNodeNS(page.div, str("urn:x"), str("n"))).? == second);
    const replaced = (try page.data(page.div)).findAttribute("urn:x", "n").?;
    try testing.expectEqualStrings("q", replaced.prefix.?);
    try testing.expectEqualStrings("2", replaced.value);
}

test "cloneNode copies every attribute exactly, in order" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try interfaces.Element.call_setAttribute(page.div, str("id"), .{ .domstring = str("i") });
    try interfaces.Element.call_setAttribute(page.div, str("class"), .{ .domstring = str("c d") });
    try interfaces.Element.call_setAttribute(page.div, str("data-x"), .{ .domstring = str("x") });
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("p:q"), .{ .domstring = str("q") });
    try interfaces.Element.call_setAttributeNS(page.div, null, str("UP"), .{ .domstring = str("u") });
    const clone = try interfaces.Node.call_cloneNode(page.div, .{ .was_passed = true, .value = false });
    _ = try interfaces.Node.call_appendChild(page.div, clone);
    try page.expectNames(clone, "id class data-x p:q UP");
    try page.expectId(clone, "i");
    try page.expectClassName(clone, "c d");
    const data = try page.data(clone);
    try testing.expectEqualStrings("q", element_data.getAttributeValue(data, "q", "urn:x"));
    try testing.expectEqualStrings("u", element_data.getAttributeValue(data, "UP", null));
}

test "an element alive at its Browser's end, and one torn down with its document, free their lists and own names" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    // Torn down with the document: in the tree.
    try interfaces.Element.call_setAttribute(page.div, str("data-in-tree"), .{ .domstring = str("1") });
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("p:q"), .{ .domstring = str("2") });
    _ = try interfaces.Element.call_getAttributeNode(page.div, str("data-in-tree"));
    // An orphan no teardown reaches before the Browser's sweep.
    const orphan = try page.element("custom-el");
    try interfaces.Element.call_setAttribute(orphan, str("data-orphan"), .{ .domstring = str("3") });
    try interfaces.Element.call_setAttribute(orphan, str("class"), .{ .domstring = str("o") });
    try interfaces.Element.call_setAttributeNS(orphan, str("urn:y"), str("r:s"), .{ .domstring = str("4") });
    _ = try interfaces.Element.call_getAttributeNode(orphan, str("data-orphan"));
    try page.expectClassName(orphan, "o");
    // std.testing.allocator fails the test on any block left.
}
