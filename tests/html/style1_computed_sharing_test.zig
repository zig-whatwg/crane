//! Lane style1 batch 1: what a computed style costs an element, and that
//! sharing it changes no computed value.
//!
//! tmp/redesign/nodedata/framework-pages.md (finding 5, table J): a cached
//! computed style was 3,008 B per element on the jQuery page - its 232-B
//! header and a private copy of every group of values the element's cascade
//! wrote (24 + 15 x 32 = 504 B each), even when 1,000 elements wrote the same
//! values. The browsers share those groups between elements: Blink's
//! MatchedPropertiesCache and WebKit's MatchedDeclarationsCache key a cached
//! style by the declarations that matched and copy its groups by reference
//! into the next element that matches the same ones (Stylo shares whole
//! ComputedValues through its style sharing cache and the reset structs
//! through its rule cache). Crane's dom.style engine does the same
//! (matched_properties_cache.zig).
//!
//! The bytes are counted from the styles themselves: each element's header
//! (@sizeOf(ComputedStyle)) and every distinct group the elements hold, once
//! - requested bytes, before any allocator rounding.
//!
//! RED at 01edfb83b0a: the two byte pins (each sibling holds its own groups).
//! The value and invalidation tests hold before and after.
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const css = dom.style.css;
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const ComputedStyle = css.computed_style.ComputedStyle;
const Group = css.computed_style.Group;
const Value = css.style_values.Value;
const groups = css.computed_style.groups;
const NodeBase = dom.NodeBase;

fn groupBytes(len: usize) usize {
    return std.mem.alignForward(usize, @sizeOf(Group), @alignOf(Value)) + len * @sizeOf(Value);
}

const Account = struct {
    elements: usize = 0,
    header_bytes: usize = 0,
    group_bytes: usize = 0,
    distinct_groups: usize = 0,
    group_refs: usize = 0,

    fn perElement(self: Account) f64 {
        return @as(f64, @floatFromInt(self.header_bytes + self.group_bytes)) / @as(f64, @floatFromInt(self.elements));
    }

    fn groupsPerElement(self: Account) f64 {
        return @as(f64, @floatFromInt(self.group_bytes)) / @as(f64, @floatFromInt(self.elements));
    }

    fn print(self: Account, label: []const u8) void {
        std.debug.print("\nSTYLE1_ACCOUNT {s}: {d} elements, headers {d} B ({d} each), {d} distinct groups ({d} B; {d} references), {d:.1} B of groups per element, {d:.1} B per element in all\n", .{ label, self.elements, self.header_bytes, @sizeOf(ComputedStyle), self.distinct_groups, self.group_bytes, self.group_refs, self.groupsPerElement(), self.perElement() });
    }
};

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// The computed styles cached on #list's element children.
fn account(page: helpers.Page) !Account {
    const document = page.browser.current_context.?.document_instance.?;
    const list = (try interfaces.Document.call_getElementById(document, str("list"))) orelse return error.NoList;
    const node = dom.instance_bridge.getNodeBase(list) orelse return error.NoList;
    var seen: std.AutoHashMapUnmanaged(usize, void) = .empty;
    defer seen.deinit(testing.allocator);
    var a: Account = .{};
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (c.node_type != NodeBase.ELEMENT_NODE) continue;
        const element: *runtime.Instance = @ptrCast(@alignCast(c.ownerInstance() orelse continue));
        const state = dom.style.element_style.existingOf(element) orelse return error.NoStyleState;
        const cached = state.cached orelse return error.NoCachedStyle;
        a.elements += 1;
        a.header_bytes += @sizeOf(ComputedStyle);
        var it = cached.style.held.iterator(.{});
        while (it.next()) |g| {
            a.group_refs += 1;
            const gop = try seen.getOrPut(testing.allocator, @intFromPtr(cached.style.slots[g]));
            if (gop.found_existing) continue;
            a.distinct_groups += 1;
            a.group_bytes += groupBytes(groups.lengths[g]);
        }
    }
    return a;
}

const rows_css =
    \\.row { display: block; margin: 2px 0; padding: 1px 4px; color: #333; background: #fafafa; border: 1px solid #ddd; }
    \\.c1 { color: #a00; } .c2 { background: #eef; } .c3 { margin-left: 8px; } .c4 { padding-top: 3px; }
    \\.c5 { border-color: #0a0; } .c6 { font-weight: bold; } .c7 { opacity: 0.5; } .c8 { display: flex; } .c9 { text-align: right; }
;

fn makeRows(page: helpers.Page, n: usize, distinct: usize) !void {
    var buffer: [4096]u8 = undefined;
    const script = try std.fmt.bufPrint(&buffer,
        \\document.head.insertAdjacentHTML('beforeend', '<style>' + {f} + '</style>');
        \\document.body.innerHTML = '<div id="list"></div>';
        \\{{
        \\  const list = document.getElementById('list');
        \\  for (let i = 0; i < {d}; i++) {{
        \\    const e = document.createElement('div');
        \\    e.className = 'row c' + (i % {d});
        \\    e.textContent = 'row ' + i;
        \\    list.append(e);
        \\  }}
        \\  for (const e of list.children) getComputedStyle(e).display;
        \\}}
    , .{ std.json.fmt(rows_css, .{}), n, distinct });
    try page.run(script);
}

fn identicalRows() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try makeRows(page, 1000, 1);
    const a = try account(page);
    a.print("1,000 siblings, one style");
    try testing.expectEqual(@as(usize, 1000), a.elements);
    // Each element pays its header; the groups its cascade wrote are held
    // once for all of them (at most a few copies in all, not one each).
    try testing.expect(a.groupsPerElement() <= 16);
}

test "1,000 siblings with identical styles share their computed-value groups" {
    try helpers.onFreshThread(identicalRows);
}

fn tenStyles() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try makeRows(page, 1000, 10);
    const a = try account(page);
    a.print("1,000 siblings, ten styles");
    try testing.expectEqual(@as(usize, 1000), a.elements);
    // Ten styles: about ten copies of each written group in all.
    try testing.expect(a.groupsPerElement() <= 64);
}

test "1,000 siblings with ten distinct styles hold about ten copies of each group" {
    try helpers.onFreshThread(tenStyles);
}

/// Every element's computed values, as getComputedStyle answers them, for
/// the properties a context can change: inherited values, em and rem,
/// currentcolor, explicit inheritance, custom properties, tree counts,
/// attr(), and logical properties under two writing modes.
const values_page =
    \\document.head.insertAdjacentHTML('beforeend', `<style>
    \\  .a { font-size: 10px; color: rgb(1, 2, 3); margin-right: 4px; }
    \\  .b { font-size: 20px; color: rgb(4, 5, 6); margin-right: 6px; writing-mode: vertical-rl; --v: 7px; }
    \\  .k { margin-left: 2em; padding-left: 1rem; border-left: 1px solid currentcolor; margin-inline-start: 3px;
    \\       margin-right: inherit; padding-top: var(--v, 1px); width: calc(1px * sibling-index());
    \\       display: block; background: #fafafa; }
    \\  .k:hover { background: rgb(9, 9, 9); }
    \\  .q::before { content: attr(data-q); }
    \\</style>`);
    \\document.body.innerHTML = '<div id="list">' +
    \\  '<div class="a"><p class="k q" data-q="one">1</p><p class="k q" data-q="two">2</p><p class="k">3</p></div>' +
    \\  '<div class="b"><p class="k q" data-q="one">1</p><p class="k">2</p><p class="k">3</p></div>' +
    \\  '<div class="a"><span class="k">1</span><span class="k">2</span></div>' +
    \\  '</div>';
    \\globalThis.style1Props = ['color', 'font-size', 'margin-left', 'margin-top', 'margin-right', 'padding-left', 'padding-top',
    \\  'border-left-color', 'border-left-width', 'width', 'display', 'background-color',
    \\  'writing-mode'];
    \\globalThis.style1Read = (reverse) => {
    \\  const els = [...document.querySelectorAll('#list *')];
    \\  if (reverse) els.reverse();
    \\  const out = new Map();
    \\  for (const e of els) {
    \\    const cs = getComputedStyle(e);
    \\    out.set(e, style1Props.map((p) => p + ': ' + cs.getPropertyValue(p)).join('; ') + ' | ::before ' + getComputedStyle(e, '::before').content);
    \\  }
    \\  return [...document.querySelectorAll('#list *')].map((e) => out.get(e)).join('\n');
    \\};
;

fn valuesUnchanged() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(values_page);
    // Forward, then again in reverse order after a new sheet makes every
    // cached style stale: another element seeds each shared group.
    try page.run(
        \\globalThis.style1Forward = style1Read(false);
        \\const extra = document.createElement('style');
        \\extra.textContent = '.unused-style1 { color: red; }';
        \\document.head.append(extra);
        \\globalThis.style1Reverse = style1Read(true);
        \\if (style1Forward !== style1Reverse) throw new Error('forward:\n' + style1Forward + '\nreverse:\n' + style1Reverse);
    );
    // The context-dependent values themselves (the browsers' answers).
    try page.run(
        \\const ps = [...document.querySelectorAll('#list .k')];
        \\const want = (i, p, v) => { const got = getComputedStyle(ps[i]).getPropertyValue(p); if (got !== v) throw new Error(i + ' ' + p + ': ' + got + ' != ' + v); };
        \\// em follows the parent's font size; the inline-start margin maps by writing mode.
        \\want(0, 'margin-left', '3px'); want(3, 'margin-left', '40px'); want(3, 'margin-top', '3px');
        \\want(0, 'padding-left', '16px'); want(3, 'padding-left', '16px');
        \\// currentcolor and explicit inheritance follow each parent.
        \\want(0, 'border-left-color', 'rgb(1, 2, 3)'); want(3, 'border-left-color', 'rgb(4, 5, 6)');
        \\want(0, 'margin-right', '4px'); want(3, 'margin-right', '6px');
        \\// A custom property from the parent, and the fallback without one.
        \\want(0, 'padding-top', '1px'); want(3, 'padding-top', '7px');
        \\// sibling-index() per element.
        \\want(0, 'width', '1px'); want(1, 'width', '2px'); want(2, 'width', '3px'); want(4, 'width', '2px');
        \\// attr() per element.
        \\if (getComputedStyle(ps[0], '::before').content !== '"one"') throw new Error('attr one: ' + getComputedStyle(ps[0], '::before').content);
        \\if (getComputedStyle(ps[1], '::before').content !== '"two"') throw new Error('attr two: ' + getComputedStyle(ps[1], '::before').content);
    );
}

test "sharing groups changes no computed value: forward and reverse reads agree, context-dependent values follow their element" {
    try helpers.onFreshThread(valuesUnchanged);
}

fn invalidation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try makeRows(page, 50, 1);
    try page.run(
        \\const rows = [...document.getElementById('list').children];
        \\const bg = (e) => getComputedStyle(e).backgroundColor;
        \\const want = (e, v, what) => { if (bg(e) !== v) throw new Error(what + ': ' + bg(e) + ' != ' + v); };
        \\for (const e of rows) want(e, 'rgb(250, 250, 250)', 'initial');
        \\// A class change restyles that element alone.
        \\rows[7].classList.add('c2');
        \\want(rows[7], 'rgb(238, 238, 255)', 'class change'); want(rows[6], 'rgb(250, 250, 250)', 'sibling of a class change'); want(rows[8], 'rgb(250, 250, 250)', 'sibling of a class change');
        \\rows[7].classList.remove('c2');
        \\want(rows[7], 'rgb(250, 250, 250)', 'class removed');
        \\// A sheet inserted restyles every element.
        \\const s = document.createElement('style'); s.textContent = '.row { background: rgb(1, 1, 1); }'; document.head.append(s);
        \\for (const e of rows) want(e, 'rgb(1, 1, 1)', 'sheet inserted');
        \\s.remove();
        \\for (const e of rows) want(e, 'rgb(250, 250, 250)', 'sheet removed');
        \\// An inherited property changed on the parent reaches every child.
        \\document.getElementById('list').style.fontWeight = '700';
        \\document.getElementById('list').style.color = 'rgb(2, 3, 4)';
        \\for (const e of rows) { if (getComputedStyle(e).fontWeight !== '700') throw new Error('inherited font-weight'); if (getComputedStyle(e).color !== 'rgb(51, 51, 51)') throw new Error('own color kept'); }
        \\// An inline style on one element.
        \\rows[3].style.backgroundColor = 'rgb(5, 5, 5)';
        \\want(rows[3], 'rgb(5, 5, 5)', 'inline'); want(rows[4], 'rgb(250, 250, 250)', 'sibling of inline');
    );
}

test "a shared group never carries one element's change to another: class, sheet, inherited and inline changes" {
    try helpers.onFreshThread(invalidation);
}

fn hover() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try makeRows(page, 20, 1);
    try page.run(
        \\document.head.insertAdjacentHTML('beforeend', '<style>.row:hover { background: rgb(3, 3, 3); }</style>');
        \\for (const e of document.getElementById('list').children) getComputedStyle(e).backgroundColor;
    );
    const document = page.browser.current_context.?.document_instance.?;
    const list = (try interfaces.Document.call_getElementById(document, str("list"))).?;
    const node = dom.instance_bridge.getNodeBase(list).?;
    var child = node.first_child;
    var index: usize = 0;
    var target: ?*runtime.Instance = null;
    while (child) |c| : (child = c.next_sibling) {
        if (c.node_type != NodeBase.ELEMENT_NODE) continue;
        if (index == 5) target = @ptrCast(@alignCast(c.ownerInstance().?));
        index += 1;
    }
    var pointer: @import("html").user_input.Pointer = .{};
    @import("html").user_input.pointerMove(&pointer, target.?, .{});
    try page.run(
        \\const rows = [...document.getElementById('list').children];
        \\for (let i = 0; i < rows.length; i++) {
        \\  const want = i === 5 ? 'rgb(3, 3, 3)' : 'rgb(250, 250, 250)';
        \\  if (getComputedStyle(rows[i]).backgroundColor !== want) throw new Error('hover ' + i + ': ' + getComputedStyle(rows[i]).backgroundColor);
        \\}
    );
}

test "a hovered element's style is its own while its siblings keep the shared one" {
    try helpers.onFreshThread(hover);
}
