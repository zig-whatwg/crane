//! Lane style1 batch 3: equal computed data converges to ONE object, so the
//! matched-properties cache - keyed on the parent's custom-property record
//! and inherited groups by address (WebKit MatchedDeclarationsCache hashes
//! &inheritedCustomProperties) - finds the children of equal parents.
//!
//! The browsers converge equal data by construction: a cache hit hands the
//! element the cached style's data (Blink StyleResolver::ApplyMatchedCache
//! InitStyle from the cached style; WebKit inheritFrom/copyNonInheritedFrom),
//! and Blink's StyleVariables::operator== rewrites two equal tries to one
//! pointer. Crane's miss path adopts, after the cascade, an entry's record and
//! groups that hold the same values (S1's adoption, by value: Value.eql and
//! the custom properties' names and values).
//!
//! RED at d7572cf6053: every row with a style attribute (never looked up: a
//! block of its own) made its own record and its own font and text groups
//! (font-family and color through var() allocate per cascade), so each row's
//! child missed the cache.
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const css = dom.style.css;
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const ComputedStyle = css.computed_style.ComputedStyle;
const groups = css.computed_style.groups;
const NodeBase = dom.NodeBase;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn cacheOf(page: helpers.Page) ?*dom.style.matched_properties_cache.MatchedPropertiesCache {
    const document = page.browser.current_context.?.document_instance.?;
    const engine = dom.style.engine.engineOf(document) orelse return null;
    return engine.matched_properties;
}

fn hits(page: helpers.Page) u32 {
    const cache = cacheOf(page) orelse return 0;
    return cache.hits;
}

/// The cached styles of #list's element children, in order.
fn rowStyles(page: helpers.Page, out: *std.ArrayList(*const ComputedStyle)) !void {
    const document = page.browser.current_context.?.document_instance.?;
    const list = (try interfaces.Document.call_getElementById(document, str("list"))) orelse return error.NoList;
    const node = dom.instance_bridge.getNodeBase(list) orelse return error.NoList;
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (c.node_type != NodeBase.ELEMENT_NODE) continue;
        const element: *runtime.Instance = @ptrCast(@alignCast(c.ownerInstance() orelse continue));
        const state = dom.style.element_style.existingOf(element) orelse return error.NoStyleState;
        const cached = state.cached orelse return error.NoCachedStyle;
        try out.append(testing.allocator, cached.style);
    }
}

/// How many distinct addresses `field` of the row styles takes.
fn distinct(styles: []const *const ComputedStyle, comptime what: enum { custom, font, text }) !usize {
    var seen: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer seen.deinit(testing.allocator);
    const font_group = groups.location[@backingInt(css.properties.Longhand.font_family)].group;
    const text_group = groups.location[@backingInt(css.properties.Longhand.color)].group;
    for (styles) |s| {
        const address: usize = switch (what) {
            .custom => @intFromPtr(s.custom),
            .font => @intFromPtr(s.slots[font_group]),
            .text => @intFromPtr(s.slots[text_group]),
        };
        try seen.put(testing.allocator, address, {});
    }
    return seen.count();
}

const convergence_css =
    \\#list { --ff: Georgia, serif; --fg: rgb(10, 20, 30); }
    \\.row { --a: 3px; --b: calc(var(--a) * 2); font-family: var(--ff); color: var(--fg); display: block; }
    \\.c { margin-left: var(--b); padding-left: 1em; }
;

/// 100 rows, each with a style attribute (so each runs the cascade) and a
/// child span (looked up under its row); every span read.
fn makeRows(page: helpers.Page, n: usize, odd_attribute: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    const script = try std.fmt.bufPrint(&buffer,
        \\document.head.insertAdjacentHTML('beforeend', '<style>' + {f} + '</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\{{
        \\  const list = document.getElementById('list');
        \\  for (let i = 0; i < {d}; i++) {{
        \\    const e = document.createElement('div');
        \\    e.className = 'row';
        \\    e.setAttribute('style', i === 57 ? {f} : 'margin-top: ' + (i % 3) + 'px');
        \\    e.innerHTML = '<span class="c">x</span>';
        \\    list.append(e);
        \\  }}
        \\  globalThis.style1b3Margins = [...list.children].map((e) => getComputedStyle(e.firstChild).marginLeft);
        \\}}
    , .{ std.json.fmt(convergence_css, .{}), n, std.json.fmt(odd_attribute, .{}) });
    try page.run(script);
}

fn siblingsConverge() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try makeRows(page, 100, "margin-top: 0px");
    var styles: std.ArrayList(*const ComputedStyle) = .empty;
    defer styles.deinit(testing.allocator);
    try rowStyles(page, &styles);
    try testing.expectEqual(@as(usize, 100), styles.items.len);
    const records = try distinct(styles.items, .custom);
    const fonts = try distinct(styles.items, .font);
    const texts = try distinct(styles.items, .text);
    const h = hits(page);
    std.debug.print("\nSTYLE1B3 100 rows: records {d}, font groups {d}, text groups {d}, hits {d}\n", .{ records, fonts, texts, h });
    // One record, one font group and one text group for every row ...
    try testing.expectEqual(@as(usize, 1), records);
    try testing.expectEqual(@as(usize, 1), fonts);
    try testing.expectEqual(@as(usize, 1), texts);
    // ... so the spans under them hit: the first span's cascade runs, the
    // others take its style.
    try testing.expect(h >= 99);
    try page.run(
        \\if (new Set(style1b3Margins).size !== 1 || style1b3Margins[0] !== '6px') throw new Error(style1b3Margins.join());
        \\const s = getComputedStyle(document.querySelector('.row'));
        \\if (s.fontFamily !== 'Georgia, serif' || s.color !== 'rgb(10, 20, 30)') throw new Error(s.fontFamily + ' / ' + s.color);
    );
}

test "rows that declare the same custom properties and var() values share one record and one font and text group, and their children hit" {
    try helpers.onFreshThread(siblingsConverge);
}

fn changedValueDoesNotShare() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Row 57 declares --a: 4px: its record has another value.
    try makeRows(page, 100, "--a: 4px");
    var styles: std.ArrayList(*const ComputedStyle) = .empty;
    defer styles.deinit(testing.allocator);
    try rowStyles(page, &styles);
    try testing.expectEqual(@as(usize, 2), try distinct(styles.items, .custom));
    try page.run(
        \\const odd = style1b3Margins.filter((m, i) => i === 57);
        \\const rest = style1b3Margins.filter((m, i) => i !== 57);
        \\if (odd[0] !== '8px' || new Set(rest).size !== 1 || rest[0] !== '6px') throw new Error(style1b3Margins.join());
    );
}

test "a row whose custom property has another value keeps its own record and its child computes from it" {
    try helpers.onFreshThread(changedValueDoesNotShare);
}

fn registeredAndChains() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // A registered <length> computes to px at each row (its em under the
    // row's own font-size): rows with different font sizes hold different
    // values, rows with the same one the same; a var() chain reads it.
    try page.run(
        \\CSS.registerProperty({ name: '--len', syntax: '<length>', inherits: true, initialValue: '0px' });
        \\document.head.insertAdjacentHTML('beforeend', '<style>.row { --len: 2em; --chain: calc(var(--len) + 1px); } .c { margin-left: var(--chain); }</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\const list = document.getElementById('list');
        \\for (let i = 0; i < 40; i++) {
        \\  const e = document.createElement('div');
        \\  e.className = 'row';
        \\  e.setAttribute('style', 'font-size: ' + (10 + (i % 4)) + 'px');
        \\  e.innerHTML = '<span class="c">x</span>';
        \\  list.append(e);
        \\}
        \\const got = [...list.children].map((e) => getComputedStyle(e.firstChild).marginLeft + '|' + getComputedStyle(e).getPropertyValue('--len'));
        \\const want = [...list.children].map((e, i) => (2 * (10 + (i % 4)) + 1) + 'px|' + (2 * (10 + (i % 4))) + 'px');
        \\if (got.join() !== want.join()) throw new Error(got.join() + ' vs ' + want.join());
    );
    var styles: std.ArrayList(*const ComputedStyle) = .empty;
    defer styles.deinit(testing.allocator);
    try rowStyles(page, &styles);
    // Four font sizes, four values of --len: four records.
    try testing.expectEqual(@as(usize, 4), try distinct(styles.items, .custom));
}

test "registered custom properties and var() chains compute the same values; rows with different values keep different records" {
    try helpers.onFreshThread(registeredAndChains);
}

fn lifetimeBalances() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try makeRows(page, 100, "margin-top: 0px");
    var styles: std.ArrayList(*const ComputedStyle) = .empty;
    defer styles.deinit(testing.allocator);
    try rowStyles(page, &styles);
    const record = styles.items[0].custom orelse return error.NoRecord;
    for (styles.items) |s| try testing.expect(s.custom == record);
    // Every reference on the shared record is a style's or a cache entry's:
    // the rows' and their spans' styles (a span declaring none shares its
    // row's record), and the holders and parent copies the cache keeps.
    const cache = cacheOf(page) orelse return error.NoCache;
    var held_by_cache: u32 = 0;
    for (cache.buckets.values()) |*bucket| for (bucket.items[0..bucket.len]) |entry| {
        if (entry.holder.custom == record) held_by_cache += 1;
        if (entry.hit) |hit| if (hit.parent.custom == record) {
            held_by_cache += 1;
        };
    };
    try testing.expectEqual(@as(u32, 200) + held_by_cache, record.refs);
    // Mutate one row's style after convergence (an inline write and an
    // animation): the others keep their values - no write reaches the
    // shared record or groups.
    try page.run(
        \\const rows = [...document.getElementById('list').children];
        \\rows[3].style.setProperty('--a', '5px');
        \\rows[3].style.color = 'rgb(200, 0, 0)';
        \\rows[4].animate([{ color: 'rgb(0, 200, 0)' }, { color: 'rgb(0, 200, 0)' }], { duration: 100000, fill: 'forwards' });
        \\const m = rows.map((e) => getComputedStyle(e.firstChild).marginLeft);
        \\const c = rows.map((e) => getComputedStyle(e).color);
        \\if (m[3] !== '10px' || m.filter((x, i) => i !== 3).some((x) => x !== '6px')) throw new Error('margins ' + m.join());
        \\if (c[3] !== 'rgb(200, 0, 0)' || c[4] !== 'rgb(0, 200, 0)' || c.filter((x, i) => i !== 3 && i !== 4).some((x) => x !== 'rgb(10, 20, 30)')) throw new Error('colors ' + c.join());
        \\// Drop every row but one, then the last: the record and groups they
        \\// shared go with their last holder (the testing allocator checks it
        \\// at the document's end).
        \\for (const e of rows.slice(1)) e.remove();
        \\if (getComputedStyle(rows[0].firstChild).marginLeft !== '6px') throw new Error('last row');
        \\rows[0].remove();
    );
}

test "a converged record's references balance; a mutation after convergence reaches only its element; dropping the last holder frees it" {
    try helpers.onFreshThread(lifetimeBalances);
}
