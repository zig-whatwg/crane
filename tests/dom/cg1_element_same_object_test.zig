//! N1 for elements (lane cg1 batch 1; node-memory plan v2): an element's
//! family-wide [SameObject] caches leave its generated State for its sparse
//! rare block (dom.element_rare_data, lane rare1), through
//! dom.same_object_cache's element accessors.
//!
//! A div's State carried 7 pointers for them - Element's classList,
//! attributes, part and children, HTMLElement's style, attributeStyleMap and
//! dataset: 56 bytes, null on nearly every element (framework-pages.md table
//! E: only style is read on the framework pages, and classList in the grid).
//! attributes and style were cached twice: the impls keep the NamedNodeMap
//! and the inline style object in rare data already. Blink keeps all of them
//! in its ElementRareDataVector (kClassList, kAttributeMap, kPart, kDataset,
//! kCssomWrapper, kCssomMapWrapper).
//!
//! RED at 01edfb83b0a: the States still hold the caches, and nothing reads
//! or writes the rare data for them.
//!
//! These name only generated interfaces, their States and src/dom types
//! (AGENTS.md "The impls boundary").
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const rare_data = dom.element_rare_data;
/// Whether this build has N1's fields.
const n1 = @hasField(rare_data.Field, "dataset");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// The names of `State`'s own-level fields that cache a [SameObject] child.
fn expectNoCaches(comptime State: type) !void {
    const Own = @FieldType(State, "own");
    var found = false;
    inline for (@typeInfo(Own).@"struct".field_names) |name| {
        if (comptime std.mem.startsWith(u8, name, "cached_")) {
            std.debug.print("{s} still caches {s} in its State\n", .{ @typeName(State), name });
            found = true;
        }
    }
    if (found) return error.CacheInState;
}

// ============================================================================
// The States (comptime)
// ============================================================================

test "Element's, HTMLElement's, SVGElement's and MathMLElement's States cache nothing: their own level is empty" {
    try expectNoCaches(interfaces.Element.State);
    try expectNoCaches(interfaces.HTMLElement.State);
    try expectNoCaches(interfaces.SVGElement.State);
    try expectNoCaches(interfaces.MathMLElement.State);
    // The level each pinned: 0 bytes of own fields for Element (32 at
    // 01edfb83b0a), HTMLElement (24), MathMLElement (24) and SVGElement (40
    // at 01edfb83b0a; 8, its impl's `_internal` pointer, until lane quick1
    // moved its nonce slot to the rare data's, 2026-11-12).
    inline for (.{ interfaces.Element.State, interfaces.HTMLElement.State, interfaces.MathMLElement.State, interfaces.SVGElement.State }) |State| {
        try testing.expectEqual(@as(usize, 0), @sizeOf(@FieldType(State, "own")));
    }
}

test "what stays in a State: Node's childNodes (lane wr1 holds NodeRareData), a non-element's and a leaf element's own caches" {
    try testing.expect(@hasField(@FieldType(interfaces.Node.State, "own"), "cached_childNodes"));
    try testing.expect(@hasField(@FieldType(interfaces.Document.State, "own"), "cached_children"));
    try testing.expect(@hasField(@FieldType(interfaces.HTMLAnchorElement.State, "own"), "cached_relList"));
}

test "the rare fields: classList at bit 0 and style at bit 1, every cache a pointer slot" {
    if (comptime !n1) return error.NoN1Fields;
    try testing.expectEqual(@as(u5, 0), @backingInt(rare_data.Field.class_list));
    try testing.expectEqual(@as(u5, 1), @backingInt(rare_data.Field.style));
    inline for (.{ .class_list, .dataset, .children, .part, .attribute_style_map, .inline_style, .svg_class_name }) |field| {
        try testing.expect(rare_data.Value(field) == *runtime.Instance);
    }
}

// ============================================================================
// An engine-less page
// ============================================================================

/// The objects the getters make are their wrappers' to free, and no engine
/// wraps them here: a test either stands an arena under the page (it reads
/// identity and the rare data only) or frees them by hand.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    /// The document element, which the elements are appended to.
    root: *runtime.Instance = undefined,

    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.root = try interfaces.Document.call_createElement(self.document, str("html"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.root);
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        const e = try interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.root, e);
        return e;
    }

    fn elementNS(self: *Page, namespace: []const u8, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElementNS(self.document, str(namespace), str(name), .notPassed());
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

/// A page over an arena: the getters' objects stay until the test ends.
const ArenaPage = struct {
    arena: std.heap.ArenaAllocator,
    page: Page,

    fn open(self: *ArenaPage) !*Page {
        self.arena = .init(std.heap.page_allocator);
        try self.page.open(self.arena.allocator());
        return &self.page;
    }

    fn close(self: *ArenaPage) void {
        self.page.close();
        self.arena.deinit();
    }
};

fn blockBytes(element: *runtime.Instance) usize {
    return rare_data.of(element).blockBytes();
}

// ============================================================================
// Each cache: the same object, in the rare data
// ============================================================================

test "el.classList: the same object every read, kept at bit 0 of a 16-byte block" {
    if (comptime !n1) return error.NoN1Fields;
    var arena_page: ArenaPage = undefined;
    const page = try arena_page.open();
    defer arena_page.close();
    const div = try page.element("div");

    try testing.expectEqual(@as(usize, 0), blockBytes(div));
    const list = try interfaces.Element.get_classList(div);
    try testing.expect((try interfaces.Element.get_classList(div)) == list);
    try testing.expect(rare_data.get(rare_data.of(div), .class_list).? == list);
    // One slot after the 8-byte header (Z8: the first cache costs 16 bytes).
    try testing.expectEqual(@as(usize, 16), blockBytes(div));
    // The list is the element's class attribute's.
    try interfaces.Element.call_setAttribute(div, str("class"), .{ .domstring = str("a b") });
    try testing.expect((try interfaces.Element.get_classList(div)) == list);
    try testing.expect(try interfaces.DOMTokenList.call_contains(list, str("b")));
}

test "classList and style share one 32-byte block, and neither moves the other" {
    if (comptime !n1) return error.NoN1Fields;
    var arena_page: ArenaPage = undefined;
    const page = try arena_page.open();
    defer arena_page.close();
    const div = try page.element("div");

    const list = try interfaces.Element.get_classList(div);
    const style = try interfaces.HTMLElement.get_style(div);
    // classList's slot, style's and its generation: 3 slots, 32 bytes.
    try testing.expectEqual(@as(usize, 32), blockBytes(div));
    try testing.expect((try interfaces.Element.get_classList(div)) == list);
    try testing.expect((try interfaces.HTMLElement.get_style(div)) == style);
    try testing.expect(rare_data.keptGet(rare_data.of(div), .style).? == style);
}

test "children, part, dataset and attributeStyleMap: the same object every read, each in its field" {
    if (comptime !n1) return error.NoN1Fields;
    var arena_page: ArenaPage = undefined;
    const page = try arena_page.open();
    defer arena_page.close();

    const a = try page.element("ul");
    const children = try interfaces.Element.get_children(a);
    try testing.expect((try interfaces.Element.get_children(a)) == children);
    try testing.expect(rare_data.get(rare_data.of(a), .children).? == children);

    const b = try page.element("p");
    const part = try interfaces.Element.get_part(b);
    try testing.expect((try interfaces.Element.get_part(b)) == part);
    try testing.expect(rare_data.get(rare_data.of(b), .part).? == part);

    const c = try page.element("section");
    const dataset = try interfaces.HTMLElement.get_dataset(c);
    try testing.expect((try interfaces.HTMLElement.get_dataset(c)) == dataset);
    try testing.expect(rare_data.get(rare_data.of(c), .dataset).? == dataset);

    const d = try page.element("span");
    const map = try interfaces.HTMLElement.get_attributeStyleMap(d);
    try testing.expect((try interfaces.HTMLElement.get_attributeStyleMap(d)) == map);
    try testing.expect(rare_data.get(rare_data.of(d), .attribute_style_map).? == map);
    // One field each: 16 bytes.
    inline for (.{ a, b, c, d }) |e| try testing.expectEqual(@as(usize, 16), blockBytes(e));
}

test "element.attributes and element.style are the impls' objects alone: no second copy anywhere" {
    if (comptime !n1) return error.NoN1Fields;
    var arena_page: ArenaPage = undefined;
    const page = try arena_page.open();
    defer arena_page.close();
    const div = try page.element("div");

    const map = try interfaces.Element.get_attributes(div);
    try testing.expect((try interfaces.Element.get_attributes(div)) == map);
    try testing.expect(rare_data.keptGet(rare_data.of(div), .named_node_map).? == map);
    // The map and its generation: 2 slots, nothing else (32 bytes).
    try testing.expectEqual(@as(u32, 2), rare_data.of(div).fieldCount());

    const style = try interfaces.HTMLElement.get_style(div);
    try testing.expect(rare_data.keptGet(rare_data.of(div), .style).? == style);
    // HTMLElement's kept style is not the generated inline_style field.
    try testing.expect(rare_data.get(rare_data.of(div), .inline_style) == null);
    try testing.expectEqual(@as(u32, 4), rare_data.of(div).fieldCount());
}

test "an SVG element's style and className are cached in its rare data, apart from HTMLElement's style" {
    if (comptime !n1) return error.NoN1Fields;
    var arena_page: ArenaPage = undefined;
    const page = try arena_page.open();
    defer arena_page.close();
    const rect = try page.elementNS("http://www.w3.org/2000/svg", "rect");

    const style = try interfaces.SVGElement.get_style(rect);
    try testing.expect((try interfaces.SVGElement.get_style(rect)) == style);
    try testing.expect(rare_data.get(rare_data.of(rect), .inline_style).? == style);
    try testing.expect(rare_data.keptGet(rare_data.of(rect), .style) == null);

    const class_name = try interfaces.SVGElement.get_className(rect);
    try testing.expect((try interfaces.SVGElement.get_className(rect)) == class_name);
    try testing.expect(rare_data.get(rare_data.of(rect), .svg_class_name).? == class_name);

    // Element's classList on an SVG element: bit 0 as on any element.
    const list = try interfaces.Element.get_classList(rect);
    try testing.expect(rare_data.get(rare_data.of(rect), .class_list).? == list);
}

// ============================================================================
// The block moves when it grows: the caches move with it
// ============================================================================

test "every cache reads back the same object after every grow of the block (poisoning allocator)" {
    if (comptime !n1) return error.NoN1Fields;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();
    const div = try page.element("div");

    const getters = .{ interfaces.Element.get_classList, interfaces.HTMLElement.get_style, interfaces.HTMLElement.get_dataset, interfaces.Element.get_children, interfaces.Element.get_part, interfaces.HTMLElement.get_attributeStyleMap, interfaces.Element.get_attributes };
    var made: [getters.len]*runtime.Instance = undefined;
    // One field after another: the block grows from 16 to 32, 64 and 128
    // bytes and moves each time (a freed block reads 0xdd); every object
    // read before still reads back.
    inline for (getters, 0..) |getter, n| {
        made[n] = try getter(div);
        inline for (getters, 0..) |again, i| {
            if (i <= n) try testing.expect((try again(div)) == made[i]);
        }
    }
    // And rare1's own fields after: a shadow root, a nonce.
    _ = try interfaces.Element.call_attachShadow(div, .{ .mode = ._open_ });
    try interfaces.HTMLElement.set_nonce(div, str("n"));
    inline for (getters, 0..) |again, i| try testing.expect((try again(div)) == made[i]);
    // 12 fields: 15 slots, 128 bytes.
    try testing.expectEqual(@as(usize, 128), blockBytes(div));

    // The generated caches' objects are their wrappers' to free, and no
    // engine wraps them here: freed by hand, before their element (as
    // lpo_dataset_setter_test does). HTMLElement's kept style and Element's
    // NamedNodeMap go with the element.
    for ([_]usize{ 0, 2, 3, 4, 5 }) |i| runtime.Instance.deinit(made[i]);
}

// ============================================================================
// Teardown: the element's destruction chain ends the caches' edges, then
// Element's teardown frees the block
// ============================================================================

test "an element freed unwrapped with every cache made leaves nothing behind (poisoning allocator)" {
    if (comptime !n1) return error.NoN1Fields;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the element leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    // Not in the tree: freed by its creator, unwrapped.
    const div = try interfaces.Document.call_createElement(page.document, str("div"), .{ .was_passed = false, .value = undefined });
    const objects = [_]*runtime.Instance{
        try interfaces.Element.get_classList(div),
        try interfaces.HTMLElement.get_dataset(div),
        try interfaces.Element.get_children(div),
        try interfaces.Element.get_part(div),
        try interfaces.HTMLElement.get_attributeStyleMap(div),
    };
    _ = try interfaces.HTMLElement.get_style(div);
    _ = try interfaces.Element.get_attributes(div);
    try testing.expectEqual(@as(usize, 128), blockBytes(div));
    for (objects) |object| runtime.Instance.deinit(object);
    // The chain ends each level's edges (HTMLElement's, then Element's)
    // while the block is still there, then Element frees it with the kept
    // style and map.
    dom.node_creation.destroyUninserted(div);
}
