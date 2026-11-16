//! N1 for elements (lane cg1 batch 1; node-memory plan v2), at run time: an
//! element's family-wide [SameObject] caches are in its sparse rare block
//! (dom.node_rare_data, lane rare1), through dom.same_object_cache's element
//! accessors - the same object every read, each in its own field, whatever
//! the block does when it grows. What the States themselves hold is pinned
//! at comptime in tests/dom/cg1_element_same_object_test.zig.
//!
//! Lane lk1 moved these seven tests here from tests/dom. The objects the
//! getters make are their wrappers' to free, and tests/dom's realm has no
//! engine: five tests ran over an arena so that nothing was reported, and
//! two freed the objects by hand. Here each test has a page of a real
//! Browser (native_read_page.zig): the getters' objects are wrapped when
//! they are made (dom.same_object_cache -> engine.traceChild), kept by their
//! element's edge, and freed by their wrappers - no arena, no hand free. The
//! elements are still made natively and never wrapped, as before.
//!
//! These name only generated interfaces, their States and src/dom types
//! (AGENTS.md "The impls boundary").
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const native_read_page = @import("native_read_page.zig");

const rare_data = dom.node_rare_data;
const Page = native_read_page.Page;
const str = native_read_page.str;

fn blockBytes(element: *runtime.Instance) usize {
    return rare_data.of(element).blockBytes();
}

// ============================================================================
// Each cache: the same object, in the rare data
// ============================================================================

fn classListAtBitZero(page: Page) !void {
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

test "el.classList: the same object every read, kept at bit 0 of a 16-byte block" {
    try native_read_page.onPage(classListAtBitZero);
}

fn classListAndStyleShareABlock(page: Page) !void {
    const div = try page.element("div");

    const list = try interfaces.Element.get_classList(div);
    const style = try interfaces.HTMLElement.get_style(div);
    // classList's slot, style's and its generation: 3 slots, 32 bytes.
    try testing.expectEqual(@as(usize, 32), blockBytes(div));
    try testing.expect((try interfaces.Element.get_classList(div)) == list);
    try testing.expect((try interfaces.HTMLElement.get_style(div)) == style);
    try testing.expect(rare_data.keptGet(rare_data.of(div), .style).? == style);
}

test "classList and style share one 32-byte block, and neither moves the other" {
    try native_read_page.onPage(classListAndStyleShareABlock);
}

fn eachCacheInItsField(page: Page) !void {
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

test "children, part, dataset and attributeStyleMap: the same object every read, each in its field" {
    try native_read_page.onPage(eachCacheInItsField);
}

fn attributesAndStyleAreTheImpls(page: Page) !void {
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

test "element.attributes and element.style are the impls' objects alone: no second copy anywhere" {
    try native_read_page.onPage(attributesAndStyleAreTheImpls);
}

fn svgStyleAndClassName(page: Page) !void {
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

test "an SVG element's style and className are cached in its rare data, apart from HTMLElement's style" {
    try native_read_page.onPage(svgStyleAndClassName);
}

// ============================================================================
// The block moves when it grows: the caches move with it
// ============================================================================

fn cachesSurviveEveryGrow() !void {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    const page = try Page.open(debug.allocator());
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
    // The generated caches' objects are their wrappers' to free, at the
    // latest when the page ends; HTMLElement's kept style and Element's
    // NamedNodeMap go with the element. The page's allocator reports what
    // any of them leaves.
}

test "every cache reads back the same object after every grow of the block (poisoning allocator)" {
    try native_read_page.onFreshThread(cachesSurviveEveryGrow);
}

// ============================================================================
// Teardown: the element's destruction chain ends the caches' edges, then
// Element's teardown frees the block; the objects go with their wrappers
// ============================================================================

fn freedUnwrappedLeavesNothing() !void {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the element leaked");
    const page = try Page.open(debug.allocator());
    defer page.close();

    // Not in the tree: freed by its creator, unwrapped.
    const div = try page.uninserted("div");
    const objects = [_]*runtime.Instance{
        try interfaces.Element.get_classList(div),
        try interfaces.HTMLElement.get_dataset(div),
        try interfaces.Element.get_children(div),
        try interfaces.Element.get_part(div),
        try interfaces.HTMLElement.get_attributeStyleMap(div),
    };
    var generations: [objects.len]u64 = undefined;
    for (objects, &generations) |object, *generation| generation.* = runtime.SlabAllocator.generationOf(object);
    _ = try interfaces.HTMLElement.get_style(div);
    _ = try interfaces.Element.get_attributes(div);
    try testing.expectEqual(@as(usize, 128), blockBytes(div));
    // The chain ends each level's edges (HTMLElement's, then Element's)
    // while the block is still there, then Element frees it with the kept
    // style and map.
    dom.node_creation.destroyUninserted(div);
    // The edges were all that kept the objects' wrappers (an element with
    // no wrapper holds them until its teardown, engine.forgetTracedChild):
    // the collector takes them, and each wrapper's end frees its object.
    for (0..4) |_| try page.collect();
    for (objects, generations) |object, generation| {
        try testing.expect(runtime.SlabAllocator.generationOf(object) != generation);
    }
}

test "an element freed unwrapped with every cache made leaves nothing behind (poisoning allocator)" {
    try native_read_page.onFreshThread(freedUnwrappedLeavesNothing);
}
