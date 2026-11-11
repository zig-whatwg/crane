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
//! prefix, never a lossy enum) - counted, and freed with the last element of
//! its name (batch 1-fix, plan-v2 B2; batch 1 kept it as long as its
//! Browser).
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

test "the rare data keeps no prefix: it is the name record's" {
    // 344 at main b1bd4eae568: - 32 (the prefix, a ?DOMString). Blink's
    // QualifiedName carries the prefix (QualifiedNameImpl::prefix_). Since
    // lane rare1 the rare data is one sparse block with a slot per field
    // set (tests/dom/rare1_sparse_rare_data_test.zig), and no field is the
    // prefix.
    try testing.expect(!@hasField(dom.element_rare_data.Field, "prefix"));
}

test "a name record is 88 bytes, its count (batch 1-fix) in what was padding" {
    // Five slices (80), the namespace byte and the static flag (2), and a
    // u32 count of the elements that name it (plan-v2 B2): 86, aligned 88.
    const ElementName = dom.element_name.ElementName;
    try testing.expect(@hasField(ElementName, "references"));
    try expectSize(ElementName, 88);
}

test "Element's InternalState is 88 bytes at N2, 40 after N3" {
    // 136 at main b1bd4eae568, less ElementData's 48: 88; N3 48 more.
    try expectSize(ElementState, 40);
}

// A div's whole State block is pinned in ONE place: tests/dom/node_block_sizes_test.zig
// (lane cg1; lesson testing-a-total-pinned-in-six-files-moves-in-six-files.md).

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
        return self.openWith(testing.allocator);
    }

    /// `open`, its Browser's allocator `allocator` (its realm's too: an
    /// element is made with its Browser's allocator).
    fn openWith(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
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
        // An element that goes takes its record with it, the last of its
        // name (std.testing.allocator checks both ends free it all).
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
        const start = tableCount(&page.scope);
        const el = try interfaces.Element.init(testing.allocator, &page.ctx);
        defer dom.node_creation.destroyUninserted(el);
        try dom.node_creation.setElementNames(el, infra.namespaces.HTML_NAMESPACE, "x-late");
        try dom.custom_elements.initialize(el, "pre", "x-is", .undefined);
        // The record it was named with first went with its last element.
        try testing.expectEqual(start + 1, tableCount(&page.scope));
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

// ============================================================================
// Lifetime (lane nd2 batch 1-fix, plan-v2 B2: red until the fix)
// ============================================================================
//
// A dynamic record is COUNTED - one reference per element of its name - and
// its Browser's table is weak: the last release removes and frees it, then
// and there (Blink: QualifiedNameImpl's destructor erases it from the
// QualifiedNameCache, static names never counted, qualified_name.cc;
// WebKit: ~QualifiedNameImpl, QualifiedName.cpp; Gecko: NodeInfo's last
// release removes it from its nsNodeInfoManager, nsNodeInfoManager.cpp).
// Batch 1 kept every record for its Browser's life: `createElement('x-' + i)`
// held about 131 B per distinct name until the Browser ended
// (tmp/redesign/review/source/appendix-nd2.md F1).

/// The Browser's interned names, 0 before its first.
fn tableCount(scope: *runtime.BrowserScope) usize {
    const table = scope.existingTable(.element_names, dom.element_name.Table) orelse return 0;
    return table.count();
}

/// A page whose Browser's allocator counts what it holds, over the churn
/// tests' allocator (`poisoning.ChurnAllocator`: poisoned frees and the leak
/// check, no stack traces - std.testing.allocator's capture at every
/// allocation and free was 95% of this churn's time on macOS).
const CountedPage = struct {
    churn: @import("root").poisoning.ChurnAllocator,
    counting: std.testing.FailingAllocator,
    page: Page,

    /// In place, as Page: the allocators point into it.
    fn open(self: *CountedPage, name: []const u8) !void {
        self.churn = .init(name);
        self.counting = std.testing.FailingAllocator.init(self.churn.allocator(), .{});
        try self.page.openWith(self.counting.allocator());
    }

    /// The page's end, then the churn allocator's leak check.
    fn close(self: *CountedPage) !void {
        self.page.close();
        try self.churn.deinit();
    }

    /// The bytes the Browser's allocator handed out and has not had back.
    fn live(self: *const CountedPage) usize {
        return self.counting.allocated_bytes - self.counting.freed_bytes;
    }
};

const Shape = enum { create_element, create_element_ns_prefixed };

/// Elements `first`..`end` of `shape` - each a name of its own - made and
/// dropped one at a time, as script makes and drops them.
fn churn(page: *Page, first: usize, end: usize, shape: Shape) !void {
    var buffer: [32]u8 = undefined;
    for (first..end) |i| {
        const el = switch (shape) {
            .create_element => try page.element(try std.fmt.bufPrint(&buffer, "x-{d}", .{i})),
            .create_element_ns_prefixed => try interfaces.Document.call_createElementNS(page.document, str("urn:x"), str(try std.fmt.bufPrint(&buffer, "p:x{d}", .{i})), .{ .was_passed = false, .value = undefined }),
        };
        dom.node_creation.destroyUninserted(el);
    }
}

fn expectFlat(comptime shape: Shape) !void {
    var counted: CountedPage = undefined;
    try counted.open("nd2_element_name_test: a million " ++ @tagName(shape) ++ " names");
    var closed = false;
    defer if (!closed) counted.close() catch {};
    const page = &counted.page;

    const names_at_start = tableCount(&page.scope);
    // Warm: the classes, chunks and map storage a steady churn reuses.
    try churn(page, 0, 1_000, shape);
    const live_warm = counted.live();
    const arena_warm = page.scope.arena.stats().bytes_in_use;

    try churn(page, 1_000, 1_000_000, shape);

    const names_at_end = tableCount(&page.scope);
    const live_end = counted.live();
    const arena_end = page.scope.arena.stats().bytes_in_use;
    if (names_at_end != names_at_start or live_end > live_warm + 64 * 1024 or arena_end > arena_warm + 64 * 1024) {
        std.debug.print("{s}: names {d} -> {d}; Browser live bytes {d} -> {d}; arena in use {d} -> {d}\n", .{ @tagName(shape), names_at_start, names_at_end, live_warm, live_end, arena_warm, arena_end });
    }
    try testing.expectEqual(names_at_start, names_at_end);
    try testing.expect(live_end <= live_warm + 64 * 1024);
    try testing.expect(arena_end <= arena_warm + 64 * 1024);
    closed = true;
    try counted.close();
}

test "a million createElement('x-' + i), each dropped, leave the Browser's name table and memory where they started" {
    try expectFlat(.create_element);
}

test "a million prefixed createElementNS('urn:x', 'p:x' + i), each dropped, leave the name table and memory where they started" {
    try expectFlat(.create_element_ns_prefixed);
}

test "a record lives while any element of its name does, and goes with the last" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    const start = tableCount(&page.scope);
    const first = try page.element("x-pair");
    const second = try page.element("x-pair");
    try testing.expectEqual(start + 1, tableCount(&page.scope));
    try testing.expect(dom.element_data.of(first).?.name == dom.element_data.of(second).?.name);
    dom.node_creation.destroyUninserted(first);
    // The other element's names are its record's, still whole.
    try testing.expectEqual(start + 1, tableCount(&page.scope));
    try page.expectNames(second, infra.namespaces.HTML_NAMESPACE, null, "x-pair", "X-PAIR");
    // A clone counts its own reference: its original going leaves it named.
    const clone = try interfaces.Node.call_cloneNode(second, .{ .was_passed = true, .value = false });
    dom.node_creation.destroyUninserted(second);
    try testing.expectEqual(start + 1, tableCount(&page.scope));
    try testing.expectEqualStrings("x-pair", dom.element_data.of(clone).?.name.local_name);
    dom.node_creation.destroyUninserted(clone);
    try testing.expectEqual(start, tableCount(&page.scope));
}

test "a prefixed name makes exactly one record" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    // DOM "create an element" gives the element its namespace, prefix and
    // local name at once: one record, (urn:x, p, q) - never (urn:x, null, q)
    // first (appendix-nd2.md F2: Element.setNames then initialize).
    const start = tableCount(&page.scope);
    const el = try page.elementNS("urn:x", "p:q");
    try testing.expectEqual(start + 1, tableCount(&page.scope));
    try testing.expectEqualStrings("p", dom.element_data.of(el).?.name.prefix.?);
    // The unprefixed name is another record, made only when asked for.
    _ = try page.elementNS("urn:x", "q");
    try testing.expectEqual(start + 2, tableCount(&page.scope));
}

test "a name record never takes a freed node block" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    // Two divs' blocks go back to the state arena's class list, and the
    // next two divs take them at once (the premise: the arena reuses them).
    const first = try page.element("div");
    const second = try page.element("div");
    const blocks = [2]usize{ @intFromPtr(first.state), @intFromPtr(second.state) };
    dom.node_creation.destroyUninserted(first);
    dom.node_creation.destroyUninserted(second);
    const again = [2]*runtime.Instance{ try page.element("div"), try page.element("div") };
    for (again) |div| try testing.expect(@intFromPtr(div.state) == blocks[0] or @intFromPtr(div.state) == blocks[1]);
    for (again) |div| dom.node_creation.destroyUninserted(div);
    // An element whose record is the size of a div's block (the record, its
    // local name and that name's uppercase: 264 bytes, the div's 272-byte
    // class) - page-chosen bytes. Its own block takes one freed div block;
    // its record never takes the other: records are not the state arena's
    // (node-memory-architecture.md 3.2: a block whose bytes the page
    // controls is never a former node block; appendix-nd2.md F3).
    var name: [88]u8 = undefined;
    @memcpy(name[0..2], "x-");
    @memset(name[2..], 'a');
    const el = try page.element(&name);
    defer dom.node_creation.destroyUninserted(el);
    const record = @intFromPtr(dom.element_data.of(el).?.name);
    for (blocks) |block| try testing.expect(record < block or record >= block + 272);
}

test "only an HTML record keeps an uppercase copy: nothing else reads one" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    // tagName uppercases an element in the HTML namespace only (DOM 4.9).
    for ([_]struct { ?[]const u8, []const u8 }{ .{ null, "feed" }, .{ "urn:x", "p:entry" }, .{ infra.namespaces.SVG_NAMESPACE, "fooBar" }, .{ infra.namespaces.MATHML_NAMESPACE, "mfoo" } }) |case| {
        const name = dom.element_data.of(try page.elementNS(case[0], case[1])).?.name;
        try testing.expect(!name.is_static);
        try testing.expect(name.qualified_name_upper.ptr == name.qualified_name.ptr);
    }
    const html = dom.element_data.of(try page.elementNS(infra.namespaces.HTML_NAMESPACE, "x-up")).?.name;
    try testing.expectEqualStrings("X-UP", html.qualified_name_upper);
}

test "the parser's selectedcontent is a static name" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    // HTML's selectedcontent element (element_interface's table has it): a
    // static record, never one interned per Browser (appendix-nd2.md F11).
    const el = try page.element("selectedcontent");
    _ = try interfaces.Node.call_appendChild(page.div, el);
    try testing.expect(dom.element_data.of(el).?.name.is_static);
}

test ":nth-of-type counts a prefixed and an unprefixed element of one expanded name as one type" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    // Selectors 4 13.4: an element's type is its namespace and local name -
    // the prefix is not part of it, though it is part of a record's identity
    // (appendix-nd2.md F5: a later cache keyed by record must not split them).
    const first = try page.elementNS(infra.namespaces.HTML_NAMESPACE, "div");
    const second = try page.elementNS(infra.namespaces.HTML_NAMESPACE, "p:div");
    try testing.expect(dom.element_data.of(first).?.name != dom.element_data.of(second).?.name);
    try testing.expect(try interfaces.Element.call_matches(first, str(":first-of-type")));
    try testing.expect(!try interfaces.Element.call_matches(second, str(":first-of-type")));
    try testing.expect(try interfaces.Element.call_matches(second, str(":nth-of-type(2)")));
    try testing.expect(try interfaces.Element.call_matches(second, str(":last-of-type")));
}
