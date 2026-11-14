//! SVG presentation hints are SHARED (src/dom/style/svg_hints.zig, Blink's
//! PresentationAttributeCache): two SVG elements with equal presentation
//! attributes hold one hint block - one address - and the second's style is
//! a matched-properties-cache hit; a changed attribute gives its element a
//! new entry and leaves the other's; the document's cache is empty once no
//! element holds a hint.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

fn document(page: helpers.Page) *runtime.Instance {
    return page.browser.current_context.?.document_instance.?;
}

fn byId(page: helpers.Page, id: []const u8) !*runtime.Instance {
    return (try interfaces.Document.call_getElementById(document(page), runtime.DOMString.initInterned(id))) orelse error.NoElement;
}

/// The address of `id`'s hint (its style state's hint slot), 0 with none.
fn hintOf(page: helpers.Page, id: []const u8) !usize {
    const state = dom.style.element_style.existingOf(try byId(page, id)) orelse return 0;
    const hint = state.hint orelse return 0;
    return @intFromPtr(hint);
}

fn cacheCount(page: helpers.Page) usize {
    const engine = dom.style.engine.engineOf(document(page)) orelse return 0;
    return engine.svgHintCount();
}

fn counters(page: helpers.Page) struct { hits: u32, misses: u32 } {
    const engine = dom.style.engine.engineOf(document(page)) orelse return .{ .hits = 0, .misses = 0 };
    const cache = engine.matched_properties orelse return .{ .hits = 0, .misses = 0 };
    return .{ .hits = cache.hits, .misses = cache.misses };
}

fn sharedAndSeparate() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<svg><rect id=a fill=blue stroke-width=2 /><rect id=b stroke-width=2 fill=blue /></svg>';
        \\void getComputedStyle(a).fill;
    );
    const before = counters(page);
    try page.run("void getComputedStyle(b).fill;");
    const after = counters(page);
    // Equal attributes (in any order): one hint, one address; b's style a
    // hit of a's.
    const a = try hintOf(page, "a");
    const b = try hintOf(page, "b");
    try testing.expect(a != 0);
    try testing.expectEqual(a, b);
    try testing.expectEqual(@as(usize, 1), cacheCount(page));
    try testing.expectEqual(before.misses, after.misses);
    try testing.expect(after.hits > before.hits);
    // b's fill changes: b gets a new entry, a keeps its own.
    try page.run("b.setAttribute('fill', 'red'); void getComputedStyle(b).fill;");
    try testing.expectEqual(a, try hintOf(page, "a"));
    const b2 = try hintOf(page, "b");
    try testing.expect(b2 != 0 and b2 != a);
    try testing.expectEqual(@as(usize, 2), cacheCount(page));
    const fills = try page.evaluate("getComputedStyle(a).fill + ' ' + getComputedStyle(b).fill");
    defer testing.allocator.free(fills);
    try testing.expectEqualStrings("rgb(0, 0, 255) rgb(255, 0, 0)", fills);
    // No element holds a hint any more: the cache is empty.
    try page.run(
        \\for (const e of [a, b]) { e.removeAttribute('fill'); e.removeAttribute('stroke-width'); void getComputedStyle(e).fill; }
    );
    try testing.expectEqual(@as(usize, 0), cacheCount(page));
}

test "SVG elements with equal presentation attributes share one hint; a changed one gets its own; the cache empties" {
    try helpers.onFreshThread(sharedAndSeparate);
}

fn baseUrlInTheKey() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<svg><rect id=a fill="url(#g)" /><rect id=b fill="blue" /></svg>';
        \\void getComputedStyle(a).fill; void getComputedStyle(b).fill;
    );
    // Different keys: two entries; a url() value is keyed with the base too.
    try testing.expect((try hintOf(page, "a")) != (try hintOf(page, "b")));
    try testing.expectEqual(@as(usize, 2), cacheCount(page));
}

test "a url() presentation attribute is keyed with the base URL" {
    try helpers.onFreshThread(baseUrlInTheKey);
}
