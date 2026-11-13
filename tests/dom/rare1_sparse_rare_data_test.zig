//! An element's rare data as ONE sparse block (lane rare1 batch 1; node-memory
//! plan v2, B7: tmp/redesign/node-memory-plan-v2.md).
//!
//! Blink merged its NodeRareData and ElementRareDataVector into one sparse
//! block on 2026-01-19 (0585db0568ea .. 8e96795b7d9d): a fixed header (flags +
//! a u64 presence bitmap) and one slot per present field, found by the
//! popcount of the bits below it (core/dom/node_rare_data.h:111-132, 716-811
//! at chromium 44274363dc1a). The block REALLOCATES when a field is added, so
//! every setter returns the new block ([[nodiscard]], RareDataUpdate) and
//! every field is an object of its own: a grow moves only pointers. Its 2026
//! bugs were pointers held across a grow (601c5205e1d5: a field constructor
//! that re-entered the block; 5518d421af00 .. a1a3cceafc6d: Node::data_ made
//! private).
//!
//! Crane's fixed ElementRareData (312 bytes at main d7d5a0be246, a 320-byte
//! malloc block) was made for any one field: on the framework pages
//! (tmp/redesign/nodedata/framework-pages.md table C) 99.8% of the blocks
//! held exactly one field, element.style's object. These pin the sparse
//! shape: an 8-byte header and 8-byte slots (16 bytes for one field), every
//! multi-word field in a block of its own, and no API that hands out a
//! pointer into the block.
//!
//! RED at d7d5a0be246: the size pins (no sparse block), the byte bounds (312
//! for any field) and click() (it made the block for one bool).
//!
//! These name only generated interfaces, their States and src/dom types
//! (AGENTS.md "The impls boundary").

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const rare_data = dom.element_rare_data;
/// Whether this build has the sparse block.
const sparse = @hasDecl(rare_data, "Holder");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn printLayout(comptime T: type) void {
    std.debug.print("\n{s}: {d} bytes, align {d}\n", .{ @typeName(T), @sizeOf(T), @alignOf(T) });
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        const F = @FieldType(T, name);
        std.debug.print("  {s:<34} +{d:<4} {d:>4} B  {s}\n", .{ name, @offsetOf(T, name), @sizeOf(F), @typeName(F) });
    }
}

fn expectSize(comptime T: type, expected: usize) !void {
    if (@sizeOf(T) != expected) {
        printLayout(T);
        std.debug.print("{s}: {d} bytes, pinned {d}\n", .{ @typeName(T), @sizeOf(T), expected });
        return error.SizePinMoved;
    }
}

/// Element's InternalState, as its generated State keeps it by value.
const ElementState = @FieldType(interfaces.Element.State, "_embedded");

// ============================================================================
// The shape (comptime pins)
// ============================================================================

test "the sparse block's header is an 8-byte extern struct, its slots 8 bytes" {
    if (comptime !sparse) return error.NoSparseBlock;
    // Z2: a block other code computes into is an extern struct. Z8: an 8-byte
    // header and one 8-byte slot is 16 bytes for the first field.
    try testing.expect(@typeInfo(rare_data.Block).@"struct".layout == .@"extern");
    try expectSize(rare_data.Block, 8);
    try testing.expectEqual(@as(usize, 8), @sizeOf(rare_data.Slot));
    // The fields' order is their use (Z8, framework-pages.md note 3): classList
    // at bit 0 (reserved: N1 moves the generated cache there), style at bit 1,
    // so the two hot reads need no popcount.
    try testing.expectEqual(@as(u5, 0), @backingInt(rare_data.Field.class_list));
    try testing.expectEqual(@as(u5, 1), @backingInt(rare_data.Field.style));
}

test "the block for n fields holds 1, 3, 7 or 15 slots: 16, 32, 64, 128 bytes" {
    if (comptime !sparse) return error.NoSparseBlock;
    // A capacity that fills the block to a 16-byte malloc quantum, implicit
    // in the field count (Blink: popcount rounded up to a power of two, min 2).
    const expected = [_]usize{ 0, 16, 32, 32, 64, 64, 64, 64, 128, 128 };
    for (expected, 0..) |bytes, n| try testing.expectEqual(bytes, rare_data.blockBytesFor(@intCast(n)));
}

test "Element's InternalState stays 40 bytes: the rare word, and click()'s flag in its padding" {
    if (comptime !sparse) return error.NoSparseBlock;
    // HTML click() step 3's flag is the one bool that would make a block on
    // its own. Blink and WebKit keep it out of the element (a set of the
    // elements dispatching a simulated click); here it takes Element's
    // padding, 0 bytes (the integrator, 2026-11-10 19:38).
    try testing.expect(@hasField(ElementState, "click_in_progress"));
    try testing.expectEqual(@as(usize, 8), @sizeOf(@FieldType(ElementState, "rare")));
    try expectSize(ElementState, 40);
}

// A div's whole State block is pinned in ONE place: tests/dom/node_block_sizes_test.zig
// (lane cg1; lesson testing-a-total-pinned-in-six-files-moves-in-six-files.md).

// ============================================================================
// An engine-less page
// ============================================================================

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
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

    fn expectString(self: *Page, expected: []const u8, got: runtime.DOMString) !void {
        var value = got;
        defer value.deinit(self.ctx.allocator);
        try testing.expectEqualStrings(expected, value.asSlice());
    }

    fn expectProperty(self: *Page, style: *runtime.Instance, name: []const u8, expected: []const u8) !void {
        try self.expectString(expected, try interfaces.CSSStyleDeclaration.call_getPropertyValue(style, str(name)));
    }
};

/// The bytes of `element`'s rare block as its allocator was asked for them;
/// 0 for none. At d7d5a0be246 (no sparse block) the fixed block's size.
fn rareBlockBytes(element: *runtime.Instance) usize {
    if (comptime sparse) return rare_data.of(element).blockBytes();
    return if (rare_data.of(element) != null) @sizeOf(rare_data.ElementRareData) else 0;
}

fn expectAtMost(what: []const u8, limit: usize, got: usize) !void {
    if (got > limit) {
        std.debug.print("{s}: {d} bytes of rare block, at most {d} wanted\n", .{ what, got, limit });
        return error.RareBlockTooLarge;
    }
}

// ============================================================================
// What one field costs
// ============================================================================

test "reading el.style on a plain element makes at most 32 bytes of rare block" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    try testing.expectEqual(@as(usize, 0), rareBlockBytes(page.div));
    const style = try interfaces.HTMLElement.get_style(page.div);
    // [SameObject]: the same object, and reading it again adds nothing.
    try testing.expect((try interfaces.HTMLElement.get_style(page.div)) == style);
    // The object and its generation (the teardown's proof that it is still
    // this element's): two slots after the 8-byte header.
    try expectAtMost("el.style", 32, rareBlockBytes(page.div));
}

test "an element with ONE rare field of any kind pays at most 32 bytes of rare block" {
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    // element.attributes: the NamedNodeMap and its generation.
    const a = try page.element("p");
    _ = try interfaces.Element.get_attributes(a);
    try expectAtMost("attributes", 32, rareBlockBytes(a));

    // An Attr node: the list is a block of its own, one slot here.
    const b = try page.element("p");
    try interfaces.Element.call_setAttribute(b, str("title"), .{ .domstring = str("t") });
    _ = (try interfaces.Element.call_getAttributeNode(b, str("title"))).?;
    try expectAtMost("Attr node", 32, rareBlockBytes(b));

    // A shadow root and its generation.
    const c = try page.element("section");
    _ = try interfaces.Element.call_attachShadow(c, .{ .mode = ._open_ });
    try expectAtMost("shadow root", 32, rareBlockBytes(c));

    // The nonce: its bytes are a block of their own.
    const d = try page.element("script");
    try interfaces.HTMLElement.set_nonce(d, str("n0nce"));
    try page.expectString("n0nce", try interfaces.HTMLElement.get_nonce(d));
    try expectAtMost("nonce", 32, rareBlockBytes(d));

    // An element reference (aria-activedescendant).
    const e = try page.element("div");
    try interfaces.Element.set_ariaActiveDescendantElement(e, page.div);
    try expectAtMost("element reference", 32, rareBlockBytes(e));

    // A slottable a slot assigns: its state is a block of its own.
    const host = try page.element("div");
    _ = try interfaces.Node.call_appendChild(page.div, host);
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    _ = try interfaces.Node.call_appendChild(shadow, try page.element("slot"));
    const f = try page.element("span");
    _ = try interfaces.Node.call_appendChild(host, f);
    try testing.expect(dom.shadow_dom_algorithms.assignedSlotOf(f) != null);
    try expectAtMost("slottable", 32, rareBlockBytes(f));
}

test "click() makes no rare data: its in-progress flag is no block's" {
    // An engine-less page leaves click()'s synthetic PointerEvent alive
    // (runtime.Instance.releaseIfUnwrapped leaves an unwrapped event it knows
    // nothing about), which std.testing.allocator would count: an arena
    // stands under this page, and the test reads only the rare data.
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    var page: Page = undefined;
    try page.open(arena.allocator());
    defer page.close();

    try interfaces.HTMLElement.call_click(page.div);
    try interfaces.HTMLElement.call_click(page.div);
    try testing.expectEqual(@as(usize, 0), rareBlockBytes(page.div));
}

// ============================================================================
// The block moves when it grows: nothing may hold a pointer into it
// ============================================================================

test "el.style keeps working while every other field is added and the block grows (poisoning allocator)" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const el = page.div;
    const style = try interfaces.HTMLElement.get_style(el);
    try interfaces.CSSStyleDeclaration.call_setProperty(style, str("color"), str("red"), .notPassed());

    // Each step adds a field; after each, every field added before still
    // reads back, through a block that may have moved (a freed one is 0xdd).
    const Check = struct {
        fn all(p: *Page, e: *runtime.Instance, s: *runtime.Instance, step: usize) !void {
            try testing.expect((try interfaces.HTMLElement.get_style(e)) == s);
            try p.expectProperty(s, "color", "red");
            if (step >= 1) _ = try interfaces.Element.get_attributes(e);
            if (step >= 2) try testing.expect((try interfaces.Element.call_getAttributeNode(e, str("title"))) != null);
            if (step >= 3) try testing.expect((try interfaces.Element.get_shadowRoot(e)) != null);
            if (step >= 4) try p.expectString("n-4", try interfaces.HTMLElement.get_nonce(e));
            if (step >= 5) try testing.expect((try interfaces.Element.get_ariaActiveDescendantElement(e)) != null);
        }
    };
    try Check.all(&page, el, style, 0);
    const map = try interfaces.Element.get_attributes(el);
    try Check.all(&page, el, style, 1);
    try testing.expect((try interfaces.Element.get_attributes(el)) == map);
    try interfaces.Element.call_setAttribute(el, str("title"), .{ .domstring = str("t") });
    const title = (try interfaces.Element.call_getAttributeNode(el, str("title"))).?;
    try Check.all(&page, el, style, 2);
    _ = try interfaces.Element.call_attachShadow(el, .{ .mode = ._open_ });
    try Check.all(&page, el, style, 3);
    try interfaces.HTMLElement.set_nonce(el, str("n-4"));
    try Check.all(&page, el, style, 4);
    const target = try page.element("p");
    _ = try interfaces.Node.call_appendChild(el, target);
    try interfaces.Element.set_ariaActiveDescendantElement(el, target);
    try Check.all(&page, el, style, 5);
    // More Attr nodes: the list (a block of its own) grows, the block not.
    var i: usize = 0;
    while (i < 12) : (i += 1) {
        var buffer: [24]u8 = undefined;
        const name = try std.fmt.bufPrint(&buffer, "data-a{d}", .{i});
        try interfaces.Element.call_setAttribute(el, str(name), .{ .domstring = str(name) });
        _ = try interfaces.Element.call_getAttributeNode(el, str(name));
        try Check.all(&page, el, style, 5);
    }
    try testing.expect((try interfaces.Element.call_getAttributeNode(el, str("title"))).? == title);
}

// ============================================================================
// The module itself: grow, re-entrant construction, cleared fields
// ============================================================================

/// Stand-ins for the objects a slot names: the block stores their addresses
/// and never reads through them.
const StandIns = struct {
    words: [4]u64 align(16) = @splat(0),

    fn at(self: *StandIns, i: usize) *runtime.Instance {
        return @ptrCast(&self.words[i]);
    }
};

test "every field added one at a time: each one added before reads back after every grow (poisoning allocator)" {
    if (comptime !sparse) return error.NoSparseBlock;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the block leaked");
    const ctx: rare_data.Context = .{ .allocator = debug.allocator() };
    var holder: rare_data.Holder = .{};
    defer rare_data.destroy(ctx, &holder);
    var objects: StandIns = .{};

    try rare_data.keptMade(ctx, &holder, .style, objects.at(0));
    try testing.expectEqual(@as(usize, 32), holder.blockBytes());
    try rare_data.keptMade(ctx, &holder, .named_node_map, objects.at(1));
    try testing.expectEqual(@as(usize, 64), holder.blockBytes());
    try rare_data.keptMade(ctx, &holder, .shadow_root, objects.at(2));
    try testing.expectEqual(@as(usize, 64), holder.blockBytes());
    const list = try rare_data.ensureOwn(ctx, &holder, .attr_nodes);
    try testing.expectEqual(@as(usize, 64), holder.blockBytes());
    const slottable = try rare_data.ensureOwn(ctx, &holder, .slottable);
    try testing.expectEqual(@as(usize, 128), holder.blockBytes());
    try rare_data.putBytes(ctx, &holder, .nonce, "abc");
    try rare_data.putBytes(ctx, &holder, .is_value, "x-y");
    try rare_data.put(ctx, &holder, .element_internals, objects.at(3));

    try testing.expect(rare_data.keptGet(holder, .style).? == objects.at(0));
    try testing.expect(rare_data.keptGet(holder, .named_node_map).? == objects.at(1));
    try testing.expect(rare_data.keptGet(holder, .shadow_root).? == objects.at(2));
    try testing.expect(rare_data.get(holder, .attr_nodes).? == list);
    try testing.expect(rare_data.get(holder, .slottable).? == slottable);
    try testing.expectEqualStrings("abc", rare_data.getBytes(holder, .nonce).?);
    try testing.expectEqualStrings("x-y", rare_data.getBytes(holder, .is_value).?);
    try testing.expect(rare_data.get(holder, .element_internals).? == objects.at(3));
    try testing.expect(rare_data.get(holder, .references) == null);
    try testing.expect(rare_data.get(holder, .custom_element_definition) == null);
}

/// A field whose construction adds other fields to the same element: the
/// block grows (1 -> 3 -> 7 slots) while the outer insert is under way.
const Reentrant = struct {
    ctx: rare_data.Context,
    holder: *rare_data.Holder,
    objects: *StandIns,

    fn make(self: *Reentrant) error{OutOfMemory}!*runtime.Instance {
        try rare_data.keptMade(self.ctx, self.holder, .named_node_map, self.objects.at(1));
        try rare_data.keptMade(self.ctx, self.holder, .shadow_root, self.objects.at(2));
        try rare_data.putBytes(self.ctx, self.holder, .nonce, "inner");
        return self.objects.at(3);
    }
};

test "a field whose construction re-enters and adds other fields (Blink 601c5205e1d5's shape)" {
    if (comptime !sparse) return error.NoSparseBlock;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the block leaked");
    const ctx: rare_data.Context = .{ .allocator = debug.allocator() };
    var holder: rare_data.Holder = .{};
    defer rare_data.destroy(ctx, &holder);

    var objects: StandIns = .{};
    try rare_data.putBytes(ctx, &holder, .is_value, "outer");
    const before = holder.blockBytes();
    var reentrant: Reentrant = .{ .ctx = ctx, .holder = &holder, .objects = &objects };
    // Built fully, then inserted: the insert reads the holder after `make`.
    const made = try rare_data.ensureWith(ctx, &holder, .element_internals, &reentrant, Reentrant.make, null);
    try testing.expect(made == objects.at(3));
    try testing.expect(holder.blockBytes() > before);
    try testing.expect(rare_data.get(holder, .element_internals).? == objects.at(3));
    try testing.expect(rare_data.keptGet(holder, .named_node_map).? == objects.at(1));
    try testing.expect(rare_data.keptGet(holder, .shadow_root).? == objects.at(2));
    try testing.expectEqualStrings("inner", rare_data.getBytes(holder, .nonce).?);
    try testing.expectEqualStrings("outer", rare_data.getBytes(holder, .is_value).?);
    // A second ensure finds it and makes nothing.
    try testing.expect((try rare_data.ensureWith(ctx, &holder, .element_internals, &reentrant, Reentrant.make, null)) == objects.at(3));
}

test "a cleared field keeps its bit: setting it again reuses its slot and moves nothing" {
    if (comptime !sparse) return error.NoSparseBlock;
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the block leaked");
    const ctx: rare_data.Context = .{ .allocator = debug.allocator() };
    var holder: rare_data.Holder = .{};
    defer rare_data.destroy(ctx, &holder);

    try rare_data.putBytes(ctx, &holder, .nonce, "a");
    const block = holder.block;
    rare_data.clearBytes(ctx, &holder, .nonce);
    try testing.expect(rare_data.getBytes(holder, .nonce) == null);
    try rare_data.putBytes(ctx, &holder, .nonce, "");
    // Explicitly empty is not null (HTML 2.5.6's hidden nonce).
    try testing.expectEqualStrings("", rare_data.getBytes(holder, .nonce).?);
    try testing.expect(holder.block == block);
}

test "the DOM memory counts the block as allocated, through every grow, and none after" {
    if (comptime !sparse) return error.NoSparseBlock;
    var memory: runtime.gc.ExternalMemory = .{};
    const ctx: rare_data.Context = .{ .allocator = testing.allocator, .memory = &memory };
    var holder: rare_data.Holder = .{};
    var objects: StandIns = .{};
    try rare_data.putBytes(ctx, &holder, .nonce, "abc");
    try testing.expect(memory.live >= 16);
    try rare_data.keptMade(ctx, &holder, .style, objects.at(0));
    try rare_data.keptMade(ctx, &holder, .shadow_root, objects.at(2));
    try testing.expect(memory.live >= holder.blockBytes());
    rare_data.destroy(ctx, &holder);
    try testing.expectEqual(@as(usize, 0), memory.live);
    try testing.expect(holder.blockBytes() == 0);
}
