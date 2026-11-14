//! An element's rare data (lane perf3, D2; tmp/plans/perf3b2-element-data-design.md
//! section 3 D2), and Element's and HTMLElement's allocator copies out.
//!
//! After D1 and perf2 batch 6 a div's one State block was 736 bytes, 416 of
//! them Element's InternalState and 88 HTMLElement's. Most of both are fields
//! almost no element uses: over the 3.04 M elements of the perf pages none
//! had a prefix, an Attr node, a shadow root, an is value, a NamedNodeMap, a
//! nonce or an `element.style` object. WebKit keeps those in an
//! ElementRareData made by `ensureElementRareData()` on first use
//! (Source/WebCore/dom/ElementRareData.h: m_attributeMap, m_nonce,
//! m_explicitlySetAttrElementsMap, ...); Blink in its NodeRareData's sparse
//! fields ("most Elements set only 0-3 of the 50+ possible fields":
//! kShadowRoot, kAttributeMap, kAttrNodeList, kCssomWrapper,
//! kElementInternals, kNonce, kIsValue, kExplicitlySetElementsForAttr;
//! core/dom/node_rare_data.h). D2 does the same: one ElementRareData, made
//! on first use, never moved, freed at both exits (the element's deinit and
//! its Browser's teardown sweep).
//!
//! The size pins are red until D2 lands. The behaviour tests hold before
//! and after it, except those that read the rare data itself.
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

/// Whether D2's rare data is in this build.
const has_rare = @hasDecl(dom, "element_rare_data");

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

/// Element's and HTMLElement's InternalStates, as their generated States
/// keep them by value (the State's `_embedded`).
const ElementState = @FieldType(interfaces.Element.State, "_embedded");
const HTMLElementState = @FieldType(interfaces.HTMLElement.State, "_embedded");

// ============================================================================
// Sizes (red until D2)
// ============================================================================

test "Element's InternalState keeps no allocator copy" {
    // 16 bytes on every element: its Browser's allocator is found from its
    // address (runtime.allocatorOf), as Node's has been since perf2 b6, and
    // Element's init asserts that it is the one the element was made with.
    try expectNoFields(ElementState, .{"allocator"});
}

test "HTMLElement's InternalState keeps no allocator copy" {
    try expectNoFields(HTMLElementState, .{"allocator"});
}

test "Element's InternalState: the cold fields are rare data, the slot name its attribute" {
    // 416 at dfa8592a878: - 16 (the allocator copy) - 40 (ElementData's
    // prefix and Attr nodes) - 104 (the NamedNodeMap and its generation, the
    // shadow root and its edge, the definition, the is value, the element
    // references) - 24 (the slot name, read from the slot attribute as
    // Blink does: Element keeps only computed_style_, tag_name_,
    // element_data_ and a bloom filter) + 8 (the rare data pointer). Left:
    // ElementData 112, the slottable state 64, the registry association 40,
    // the style state 8, the rare data 8 and three one-byte fields: 240.
    // E1 item 1 (tests/dom/perf3e1_element_registry_test.zig): the
    // association became a one-byte place, -40; item 2 the slottable state
    // went to rare data (tests/dom/perf3e1_slottable_test.zig), -64.
    try expectNoFields(ElementState, .{ "references", "shadow_root", "shadow_root_kept", "custom_element_definition", "is_value", "named_node_map", "named_node_map_generation", "slot" });
    if (comptime !@hasField(ElementState, "rare")) {
        printLayout(ElementState);
        return error.NoRareData;
    }
    // Lane nd2 N2 the name to one record pointer (nd2_element_name_test):
    // -48; N3 the ID and classes views (nd2_id_class_index_test): -48: 40.
    // Its size is pinned in ONE place, tests/dom/node_block_sizes_test.zig (lane nm1).
}

test "ElementData is 16 bytes: its Attr nodes are rare data, its name one record, its ID and classes two indices in its list" {
    // 152 at dfa8592a878 (D1): - 32 (the prefix) - 8 (the Attr node list);
    // lane nd2 N2: - 48 (the namespace and local name, one record pointer
    // now, the prefix in it too); N3: - 48 (the ID and classes views).
    try expectNoFields(ElementData, .{ "prefix", "attr_nodes" });
    try expectSize(ElementData, 16);
}

test "HTMLElement's InternalState is empty: every field it kept is rare data" {
    // 88 at dfa8592a878: the allocator copy, the nonce, the ElementInternals
    // and element.style objects with their edges, five flags (two never
    // read: was_focused_by_script, is_dragging).
    try expectSize(HTMLElementState, 0);
}

// A div's whole State block is pinned in ONE place: tests/dom/node_block_sizes_test.zig
// (lane cg1; lesson testing-a-total-pinned-in-six-files-moves-in-six-files.md).

test "the rare data is one sparse block, made only for the elements that use it: 16 bytes for one field" {
    if (comptime !has_rare) return error.NoRareData;
    // 312 bytes in one fixed block at d7d5a0be246 (prefix 32 until nd2 N2,
    // Attr nodes 32, NamedNodeMap 16, shadow root + edge 40, definition 8,
    // is value 32, references 8, HTMLElement's part 72, E1's registry 40 and
    // slottable state 64), made for any one field. Since lane rare1 it is
    // an 8-byte header and an 8-byte slot per field set
    // (tests/dom/rare1_sparse_rare_data_test.zig).
    try testing.expectEqual(@as(usize, 16), dom.element_rare_data.blockBytesFor(1));
}

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

    fn elementNS(self: *Page, namespace: []const u8, qualified_name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElementNS(self.document, str(namespace), str(qualified_name), .{ .was_passed = false, .value = undefined });
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn expectString(self: *Page, expected: []const u8, got: runtime.DOMString) !void {
        var value = got;
        defer value.deinit(self.ctx.allocator);
        try testing.expectEqualStrings(expected, value.asSlice());
    }
};

/// `element`'s rare block, or null when it has none (or D2 is not in).
fn rareOf(element: *runtime.Instance) ?*anyopaque {
    if (comptime !has_rare) return null;
    return @ptrCast(dom.element_rare_data.of(element).block orelse return null);
}

// ============================================================================
// Who gets rare data
// ============================================================================

test "a div made, parsed, cloned and given attributes, an ID and classes has no rare data" {
    if (comptime !has_rare) return error.NoRareData;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try testing.expect(rareOf(page.div) == null);
    try interfaces.Element.call_setAttribute(page.div, str("id"), .{ .domstring = str("main") });
    try interfaces.Element.call_setAttribute(page.div, str("class"), .{ .domstring = str("a b") });
    try interfaces.Element.call_setAttribute(page.div, str("data-k"), .{ .domstring = str("v") });
    try interfaces.Element.call_setAttribute(page.div, str("slot"), .{ .domstring = str("s") });
    try interfaces.Element.call_removeAttribute(page.div, str("data-k"));
    var value = (try interfaces.Element.call_getAttribute(page.div, str("class"))).?;
    value.deinit(page.ctx.allocator);
    try page.expectString("main", try interfaces.Element.get_id(page.div));
    try page.expectString("s", try interfaces.Element.get_slot(page.div));
    try page.expectString("DIV", try interfaces.Element.get_tagName(page.div));
    try testing.expect((try interfaces.Element.get_prefix(page.div)) == null);
    try testing.expect((try interfaces.Element.get_shadowRoot(page.div)) == null);
    try testing.expect(rareOf(page.div) == null);

    // Parsed elements with attributes, and a deep clone of them.
    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str("<span id=x class=c title=t><b data-n=1>b</b></span><p lang=en>p</p>") });
    const span = (try interfaces.Node.get_firstChild(page.div)).?;
    const b = (try interfaces.Node.get_firstChild(span)).?;
    const p = (try interfaces.Node.get_nextSibling(span)).?;
    try page.expectString("x", try interfaces.Element.get_id(span));
    for ([_]*runtime.Instance{ span, b, p }) |el| try testing.expect(rareOf(el) == null);
    const clone = try interfaces.Node.call_cloneNode(span, .{ .was_passed = true, .value = true });
    _ = try interfaces.Node.call_appendChild(page.div, clone);
    try testing.expect(rareOf(clone) == null);
    try testing.expect(rareOf((try interfaces.Node.get_firstChild(clone)).?) == null);
    try testing.expect(rareOf(page.div) == null);
}

test "each rare field goes into the one block, and every field works" {
    if (comptime !has_rare) return error.NoRareData;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    // `attributes` ([SameObject]) makes it.
    const map = try interfaces.Element.get_attributes(page.div);
    _ = rareOf(page.div) orelse return error.NoRareData;
    try testing.expect((try interfaces.Element.get_attributes(page.div)) == map);

    // An Attr node ([SameObject] per attribute).
    try interfaces.Element.call_setAttribute(page.div, str("title"), .{ .domstring = str("t") });
    const title = (try interfaces.Element.call_getAttributeNode(page.div, str("title"))).?;
    try testing.expect((try interfaces.Element.call_getAttributeNode(page.div, str("title"))).? == title);
    // A shadow root.
    const shadow = try interfaces.Element.call_attachShadow(page.div, .{ .mode = ._open_ });
    try testing.expect((try interfaces.Element.get_shadowRoot(page.div)).? == shadow);
    // The nonce and element.style. (Not click(), whose in-progress flag is
    // rare data too: an engine-less page leaves its synthetic PointerEvent
    // alive, runtime.Instance.releaseIfUnwrapped's "nothing is known about
    // who else holds it - leave it", which std.testing.allocator counts.)
    try interfaces.HTMLElement.set_nonce(page.div, str("n0nce"));
    try page.expectString("n0nce", try interfaces.HTMLElement.get_nonce(page.div));
    const style = try interfaces.HTMLElement.get_style(page.div);
    try testing.expect((try interfaces.HTMLElement.get_style(page.div)) == style);
    // Every field above went into the same block, which moved as it grew
    // (lane rare1): the map and the shadow root with their generations, the
    // Attr node list, the nonce, the style object and its generation.
    try testing.expectEqual(@as(u32, 8), dom.element_rare_data.of(page.div).fieldCount());

    // An element made with a prefix keeps it in its name record (lane nd2
    // N2; rare data of its own before): it makes no rare data.
    const prefixed = try page.elementNS(infra.namespaces.SVG_NAMESPACE, "s:svg");
    try testing.expect(rareOf(prefixed) == null);
    try page.expectString("s", (try interfaces.Element.get_prefix(prefixed)).?);
    try page.expectString("s:svg", try interfaces.Element.get_tagName(prefixed));
    // And one made without one has none.
    const plain = try page.elementNS(infra.namespaces.SVG_NAMESPACE, "svg");
    try testing.expect(rareOf(plain) == null);
    try testing.expect((try interfaces.Element.get_prefix(plain)) == null);
}

test "an Attr node follows its attribute through a replace that changes its prefix" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("p:n"), .{ .domstring = str("1") });
    const first = (try interfaces.Element.call_getAttributeNodeNS(page.div, str("urn:x"), str("n"))).?;
    const second = try interfaces.Document.call_createAttributeNS(page.document, str("urn:x"), str("q:n"));
    try interfaces.Attr.set_value(second, str("2"));
    try testing.expect((try interfaces.Element.call_setAttributeNode(page.div, second)).? == first);
    try testing.expect((try interfaces.Element.call_getAttributeNodeNS(page.div, str("urn:x"), str("n"))).? == second);
    try testing.expect((try interfaces.Attr.get_ownerElement(first)) == null);
    try testing.expect((try interfaces.Attr.get_ownerElement(second)) == page.div);
    // A third Attr through the same prefix-changing replace, and back.
    const third = try interfaces.Document.call_createAttributeNS(page.document, str("urn:x"), str("p:n"));
    try testing.expect((try interfaces.Element.call_setAttributeNode(page.div, third)).? == second);
    try testing.expect((try interfaces.Element.call_getAttributeNodeNS(page.div, str("urn:x"), str("n"))).? == third);
    _ = try interfaces.Element.call_removeAttributeNode(page.div, third);
    try testing.expect((try interfaces.Element.call_getAttributeNodeNS(page.div, str("urn:x"), str("n"))) == null);
}

test "an element's slot name is its slot attribute's value, through set, change and remove" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const host = try page.element("section");
    _ = try interfaces.Node.call_appendChild(page.div, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    const named = try page.element("slot");
    try interfaces.Element.call_setAttribute(named, str("name"), .{ .domstring = str("a") });
    const default = try page.element("slot");
    _ = try interfaces.Node.call_appendChild(shadow, named);
    _ = try interfaces.Node.call_appendChild(shadow, default);

    const child = try page.element("span");
    _ = try interfaces.Node.call_appendChild(host, child);
    try testing.expect((try interfaces.Element.get_assignedSlot(child)).? == default);
    try interfaces.Element.set_slot(child, str("a"));
    try page.expectString("a", try interfaces.Element.get_slot(child));
    try testing.expect((try interfaces.Element.get_assignedSlot(child)).? == named);
    try interfaces.Element.call_setAttribute(child, str("slot"), .{ .domstring = str("b") });
    try page.expectString("b", try interfaces.Element.get_slot(child));
    try testing.expect((try interfaces.Element.get_assignedSlot(child)) == null);
    // A slot attribute in a namespace is not the slot name.
    try interfaces.Element.call_setAttributeNS(child, str("urn:x"), str("p:slot"), .{ .domstring = str("a") });
    try page.expectString("b", try interfaces.Element.get_slot(child));
    try testing.expect((try interfaces.Element.get_assignedSlot(child)) == null);
    try interfaces.Element.call_removeAttribute(child, str("slot"));
    try page.expectString("", try interfaces.Element.get_slot(child));
    try testing.expect((try interfaces.Element.get_assignedSlot(child)).? == default);
    // The empty value is the default slot too.
    try interfaces.Element.call_setAttribute(child, str("slot"), .{ .domstring = str("") });
    try testing.expect((try interfaces.Element.get_assignedSlot(child)).? == default);
}

// ============================================================================
// DOM memory and both exits
// ============================================================================

test "the rare data's bytes are counted in the Browser's DOM memory while they live" {
    if (comptime !has_rare) return error.NoRareData;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const el = try page.element("div");
    const before = page.scope.dom_memory.live;
    try interfaces.HTMLElement.set_nonce(el, str("n"));
    try testing.expect(rareOf(el) != null);
    // One field: the header and one slot (the nonce's bytes are its own).
    try testing.expectEqual(before + 16, page.scope.dom_memory.live);
    // Two more go into the same block, which grows to three slots: its old
    // bytes are given back, its new ones counted.
    _ = try interfaces.HTMLElement.get_style(el);
    try testing.expectEqual(before + 32, page.scope.dom_memory.live);
    // The element's own deinit (its wrapper's collection) gives them back.
    interfaces.HTMLDivElement.deinit(el);
    try testing.expect(page.scope.dom_memory.live <= before);
}

/// Give `el` every rare field an engine-less page can reach.
fn useEveryRareField(page: *Page, el: *runtime.Instance) !void {
    _ = try interfaces.Element.get_attributes(el);
    try interfaces.Element.call_setAttribute(el, str("data-r"), .{ .domstring = str("1") });
    _ = try interfaces.Element.call_getAttributeNode(el, str("data-r"));
    try interfaces.Element.call_setAttributeNS(el, str("urn:x"), str("p:q"), .{ .domstring = str("2") });
    _ = try interfaces.Element.call_getAttributeNodeNS(el, str("urn:x"), str("q"));
    try interfaces.HTMLElement.set_nonce(el, str("nonce-value"));
    _ = try interfaces.HTMLElement.get_style(el);
    _ = page;
}

test "both exits free the rare data: in the tree, an orphan swept, a parsed orphan innerHTML dropped (std.testing.allocator)" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    // Torn down with its document.
    try useEveryRareField(&page, page.div);
    _ = try interfaces.Element.call_attachShadow(page.div, .{ .mode = ._open_ });
    // An orphan no teardown reaches before the Browser's sweep.
    const orphan = try page.element("section");
    try useEveryRareField(&page, orphan);
    _ = try interfaces.Element.call_attachShadow(orphan, .{ .mode = ._closed_ });
    // A prefixed foreign orphan.
    const prefixed = try page.elementNS(infra.namespaces.SVG_NAMESPACE, "s:g");
    try interfaces.Element.call_setAttribute(prefixed, str("data-x"), .{ .domstring = str("x") });
    _ = try interfaces.Element.call_getAttributeNode(prefixed, str("data-x"));
    // Parsed elements given rare data, then dropped by innerHTML while no
    // wrapper holds them: their only exit is the sweep.
    const holder = try page.element("div");
    _ = try interfaces.Node.call_appendChild(page.div, holder);
    try interfaces.Element.set_innerHTML(holder, .{ .domstring = str("<p title=a>x</p><svg><g></g></svg><article nonce=z>y</article>") });
    var child = try interfaces.Node.get_firstChild(holder);
    while (child) |c| : (child = try interfaces.Node.get_nextSibling(c)) {
        if ((try interfaces.Node.get_nodeType(c)) != 1) continue;
        _ = try interfaces.Element.get_attributes(c);
        try interfaces.Element.call_setAttribute(c, str("data-y"), .{ .domstring = str("y") });
        _ = try interfaces.Element.call_getAttributeNode(c, str("data-y"));
    }
    try interfaces.Element.set_innerHTML(holder, .{ .domstring = str("") });
    // std.testing.allocator fails the test on any block left.
}

test "both exits free the rare data under a poisoning DebugAllocator" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    try useEveryRareField(&page, page.div);
    const orphan = try page.element("article");
    try useEveryRareField(&page, orphan);
    // The rare data outlives a list that reallocates many times.
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        var buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "data-n{d}", .{i});
        try interfaces.Element.call_setAttribute(orphan, str(name), .{ .domstring = str(name) });
        _ = try interfaces.Element.call_getAttributeNode(orphan, str(name));
    }
    try page.expectString("nonce-value", try interfaces.HTMLElement.get_nonce(orphan));
    var value = (try interfaces.Element.call_getAttribute(orphan, str("data-n3"))).?;
    defer value.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("data-n3", value.asSlice());
}
