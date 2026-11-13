//! Lane style1 batch 2 (S2): an element whose matched declarations and
//! parent another element had already gets that element's style without a
//! cascade (Blink MatchedPropertiesCache, WebKit MatchedDeclarationsCache;
//! dom/style/matched_properties_cache.zig), and every element whose cascade
//! reads an input of its own still runs it - with the values the browsers
//! answer.
//!
//! RED at e498e8bbc0d: the cache answered no lookup (S1 compared values
//! after every cascade), so the hit counts were zero.
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

fn implemented() bool {
    return @hasField(dom.style.matched_properties_cache.MatchedPropertiesCache, "hits");
}

/// The document's cache counters: lookups answered and not.
fn counters(page: helpers.Page) struct { hits: u32, misses: u32 } {
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.engine.engineOf(document) orelse return .{ .hits = 0, .misses = 0 };
    const cache = engine.matched_properties orelse return .{ .hits = 0, .misses = 0 };
    return .{ .hits = cache.hits, .misses = cache.misses };
}

const rows_css =
    \\.row { display: block; margin: 2px 0; padding: 1px 4px; color: #333; background: #fafafa; border: 1px solid #ddd;
    \\       transition: opacity 0.3s ease; margin-left: 1em; }
;

fn rows(page: helpers.Page, n: usize, row_attributes: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    const script = try std.fmt.bufPrint(&buffer,
        \\document.head.insertAdjacentHTML('beforeend', '<style>' + {f} + '</style>');
        \\document.body.innerHTML = '<div id="list" style="font-size: 20px"></div>';
        \\{{
        \\  const list = document.getElementById('list');
        \\  let html = '';
        \\  for (let i = 0; i < {d}; i++) html += '<div class="row" ' + {f} + '>row ' + i + '</div>';
        \\  list.innerHTML = html;
        \\  globalThis.style1b2Values = [...list.children].map((e) => getComputedStyle(e).marginLeft + ' ' + getComputedStyle(e).width);
        \\}}
    , .{ std.json.fmt(rows_css, .{}), n, std.json.fmt(row_attributes, .{}) });
    try page.run(script);
}

fn siblingsHit() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try rows(page, 1000, "");
    const c = counters(page);
    std.debug.print("\nSTYLE1B2_HITS 1,000 siblings: hits {d} misses {d}\n", .{ c.hits, c.misses });
    // The first row runs the cascade; the 999 after it do not.
    try testing.expect(c.hits >= 999);
    try page.run(
        \\if (new Set(style1b2Values).size !== 1 || style1b2Values[0] !== '20px auto') throw new Error(style1b2Values[0]);
    );
}

test "1,000 siblings with one style: the cascade runs for the first only" {
    if (comptime !implemented()) return error.SkipNotImplemented;
    try helpers.onFreshThread(siblingsHit);
}

fn ownInputsMiss() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Each row's width reads its own place among its siblings (Values 5
    // sibling-index(); Blink HasSiblingFunctions): no row stands for another.
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<style>.t { width: calc(1px * sibling-index()); margin-left: 1em; }</style>');
        \\document.body.innerHTML = '<div id="list" style="font-size: 20px"></div>';
        \\const list = document.getElementById('list');
        \\for (let i = 0; i < 50; i++) list.insertAdjacentHTML('beforeend', '<div class="t">t</div>');
        \\globalThis.style1b2Widths = [...list.children].map((e) => getComputedStyle(e).width).join(',');
    );
    const c = counters(page);
    try testing.expectEqual(@as(u32, 0), c.hits);
    try page.run(
        \\const want = Array.from({ length: 50 }, (_, i) => (i + 1) + 'px').join(',');
        \\if (style1b2Widths !== want) throw new Error(style1b2Widths);
    );
}

test "rows whose cascade reads their own place among their siblings run it every time" {
    if (comptime !implemented()) return error.SkipNotImplemented;
    try helpers.onFreshThread(ownInputsMiss);
}

fn ownBlocksMiss() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // A style attribute is a block of the element's own, looked up by its
    // content since lane style1 b5 (Blink CSSPropertyValueSet::ComputeHash):
    // 100 equal attributes, one cascade.
    try rows(page, 100, "style=\"margin-top: 3px\"");
    const c = counters(page);
    try testing.expect(c.hits >= 99);
    try page.run(
        \\const list = document.getElementById('list');
        \\for (const e of list.children) if (getComputedStyle(e).marginTop !== '3px') throw new Error(getComputedStyle(e).marginTop);
        \\// The element keeps its style attribute's block where it was: a new
        \\// value in the same block must not find the old style.
        \\const first = list.children[0];
        \\first.setAttribute('style', 'margin-top: 7px');
        \\if (getComputedStyle(first).marginTop !== '7px') throw new Error('changed: ' + getComputedStyle(first).marginTop);
    );
}

test "rows with equal style attributes hit, and a style attribute changed in place reads its new value" {
    if (comptime !implemented()) return error.SkipNotImplemented;
    try helpers.onFreshThread(ownBlocksMiss);
}

fn parentsDiffer() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Two parents with different font sizes: em under each is its own; a
    // class change and a new sheet re-resolve with the new declarations.
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<style>.k { margin-left: 2em; } .k.wide { margin-left: 3em; } .p { justify-items: legacy center; }</style>');
        \\document.body.innerHTML = '<div id="a" style="font-size: 10px"><p class="k">1</p><p class="k">2</p></div>' +
        \\  '<div id="b" style="font-size: 20px"><p class="k">1</p><p class="k">2</p></div>' +
        \\  '<div id="c" class="p"><p class="k">1</p></div><div id="d"><p class="k">1</p></div>';
        \\const read = () => [...document.querySelectorAll('.k')].map((e) => getComputedStyle(e).marginLeft + '/' + getComputedStyle(e).justifyItems).join(',');
        \\const first = read();
        \\if (first !== '20px/normal,20px/normal,40px/normal,40px/normal,32px/legacy center,32px/normal') throw new Error('first ' + first);
        \\document.querySelector('#b .k').classList.add('wide');
        \\const second = read();
        \\if (second !== '20px/normal,20px/normal,60px/normal,40px/normal,32px/legacy center,32px/normal') throw new Error('second ' + second);
        \\document.head.insertAdjacentHTML('beforeend', '<style>.k { margin-left: 1em; }</style>');
        \\const third = read();
        \\if (third !== '10px/normal,10px/normal,60px/normal,20px/normal,16px/legacy center,16px/normal') throw new Error('third ' + third);
        \\// A rule's block changed in place through the CSSOM: same address, new values.
        \\const sheet = document.styleSheets[document.styleSheets.length - 1];
        \\sheet.cssRules[0].style.marginLeft = '4em';
        \\const fourth = read();
        \\if (fourth !== '40px/normal,40px/normal,60px/normal,80px/normal,64px/legacy center,64px/normal') throw new Error('fourth ' + fourth);
    );
    const c = counters(page);
    // The second row under each parent at least was a hit.
    try testing.expect(c.hits >= 2);
}

test "a parent with other inherited values or another justify-items is another parent; a class change and a new sheet re-resolve" {
    if (comptime !implemented()) return error.SkipNotImplemented;
    try helpers.onFreshThread(parentsDiffer);
}
