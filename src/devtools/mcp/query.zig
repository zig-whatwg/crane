//! What wait_for asks a frame (chrome-devtools-mcp-v1.13.0 McpPage
//! waitForTextOnPage: a race of `aria/<text>` and `text/<text>` locators over
//! the page's frames), as Puppeteer answers it (puppeteer-core 25.17.0):
//! - `aria/`: lib/puppeteer/common/AriaQueryHandler.js parseARIASelector
//!   (translated here; Copyright 2020 Google Inc., Apache-2.0), then
//!   Accessibility.queryAXTree on the frame's document, the ignored nodes
//!   and the text-only roles left out (cdp/ElementHandle.js queryAXTree);
//! - `text/`: lib/puppeteer/injected/TextQuerySelector.js and
//!   TextContent.js, copied (injected/text_query.js), run in the frame's
//!   utility world as TextQueryHandler runs it.
//! THIRD_PARTY_NOTICES.md.

const std = @import("std");
const Allocator = std.mem.Allocator;
const text_util = @import("text.zig");

/// The injected script: evaluated in a utility world, it is the object
/// whose `textQuerySelectorAll(root, text)` yields the deepest elements
/// whose text contains `text`.
pub const text_query_source = @embedFile("injected/text_query.js");

/// QueryHandler's querySelector over textQuerySelectorAll, from the
/// frame's document, as a function of the injected object: whether one
/// element matches.
pub const text_query_call =
    \\function (selector) {
    \\  for (const node of this.textQuerySelectorAll(document, selector)) {
    \\    return true;
    \\  }
    \\  return false;
    \\}
;

/// NON_ELEMENT_NODE_ROLES: queryAXTree's answers that are not elements.
pub fn isElementRole(role: []const u8) bool {
    return !std.mem.eql(u8, role, "StaticText") and !std.mem.eql(u8, role, "InlineTextBox");
}

pub const AriaQuery = struct {
    name: ?[]const u8 = null,
    role: ?[]const u8 = null,
};

/// parseARIASelector: each `[name="..."]` or `[role='...']` taken out (the
/// last of each wins); what is left is the name when no name attribute gave
/// a non-empty one. Null where Puppeteer throws - a selector over 10,000
/// code units, or an attribute other than name and role - and the query
/// then never matches.
pub fn parseAriaSelector(arena: Allocator, selector: []const u8) !?AriaQuery {
    if (text_util.codeUnits(selector) > 10_000) return null;
    var query: AriaQuery = .{};
    var rest: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (i < selector.len) {
        if (matchAttribute(selector, i)) |m| {
            if (std.mem.eql(u8, m.attribute, "name")) {
                query.name = m.value;
            } else if (std.mem.eql(u8, m.attribute, "role")) {
                query.role = m.value;
            } else return null;
            i = m.end;
            continue;
        }
        try rest.append(arena, selector[i]);
        i += 1;
    }
    const has_name = if (query.name) |n| n.len != 0 else false;
    if (rest.items.len != 0 and !has_name) query.name = rest.items;
    return query;
}

const Attribute = struct { attribute: []const u8, value: []const u8, end: usize };

/// ATTRIBUTE_REGEXP at `start`:
/// /\[\s*(?<attribute>\w+)\s*=\s*(?<quote>"|')(?<value>\\.|.*?(?=\k<quote>))\k<quote>\s*\]/
/// - the value's first alternative (a backslash and one character) tried
/// first, then the shortest run of characters before the quote that
/// closes the attribute; `.` matches no line terminator.
fn matchAttribute(s: []const u8, start: usize) ?Attribute {
    if (s[start] != '[') return null;
    var j = skipSpace(s, start + 1);
    const name_start = j;
    while (j < s.len and isWord(s[j])) j += 1;
    if (j == name_start) return null;
    const attribute = s[name_start..j];
    j = skipSpace(s, j);
    if (j >= s.len or s[j] != '=') return null;
    j = skipSpace(s, j + 1);
    if (j >= s.len or (s[j] != '"' and s[j] != '\'')) return null;
    const quote = s[j];
    const value_start = j + 1;
    // \\.
    if (value_start < s.len and s[value_start] == '\\') {
        if (charAt(s, value_start + 1)) |c| if (!c.line_terminator) {
            const value_end = value_start + 1 + c.len;
            if (closes(s, value_end, quote)) |end| return .{ .attribute = attribute, .value = s[value_start..value_end], .end = end };
        };
    }
    // .*?(?=\k<quote>)
    var p = value_start;
    while (true) {
        if (p < s.len and s[p] == quote) {
            if (closes(s, p, quote)) |end| return .{ .attribute = attribute, .value = s[value_start..p], .end = end };
        }
        const c = charAt(s, p) orelse return null;
        if (c.line_terminator) return null;
        p += c.len;
    }
}

/// \k<quote>\s*\] at `at`: the index after the bracket.
fn closes(s: []const u8, at: usize, quote: u8) ?usize {
    if (at >= s.len or s[at] != quote) return null;
    const j = skipSpace(s, at + 1);
    if (j >= s.len or s[j] != ']') return null;
    return j + 1;
}

const Char = struct { len: usize, line_terminator: bool };

fn charAt(s: []const u8, at: usize) ?Char {
    if (at >= s.len) return null;
    const len = std.unicode.utf8ByteSequenceLength(s[at]) catch return .{ .len = 1, .line_terminator = false };
    if (at + len > s.len) return .{ .len = 1, .line_terminator = false };
    const cp = std.unicode.utf8Decode(s[at .. at + len]) catch return .{ .len = 1, .line_terminator = false };
    return .{ .len = len, .line_terminator = cp == '\n' or cp == '\r' or cp == 0x2028 or cp == 0x2029 };
}

fn skipSpace(s: []const u8, from: usize) usize {
    var i = from;
    while (i < s.len) {
        const len = std.unicode.utf8ByteSequenceLength(s[i]) catch return i;
        if (i + len > s.len) return i;
        const cp = std.unicode.utf8Decode(s[i .. i + len]) catch return i;
        if (!text_util.isJsSpace(cp)) return i;
        i += len;
    }
    return i;
}

fn isWord(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

test "parseARIASelector: plain text is the name; name and role attributes come out" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const plain = (try parseAriaSelector(arena, "Order confirmed")).?;
    try std.testing.expectEqualStrings("Order confirmed", plain.name.?);
    try std.testing.expect(plain.role == null);
    const both = (try parseAriaSelector(arena, "[name=\"Submit\"][role='button']")).?;
    try std.testing.expectEqualStrings("Submit", both.name.?);
    try std.testing.expectEqualStrings("button", both.role.?);
    // Text beside a role is the name; a name attribute wins over it.
    const mixed = (try parseAriaSelector(arena, "Save [role=\"button\"]")).?;
    try std.testing.expectEqualStrings("Save ", mixed.name.?);
    const named = (try parseAriaSelector(arena, "x [ name = 'y' ]")).?;
    try std.testing.expectEqualStrings("y", named.name.?);
    // The value's first alternative: a backslash and one character.
    const escaped = (try parseAriaSelector(arena, "[name=\"\\\"\"]")).?;
    try std.testing.expectEqualStrings("\\\"", escaped.name.?);
    // A quote inside the value: the shortest run that closes the attribute.
    const inner = (try parseAriaSelector(arena, "[name=\"a\"b\"]")).?;
    try std.testing.expectEqualStrings("a\"b", inner.name.?);
    // Not an attribute: all of it is the name.
    const unclosed = (try parseAriaSelector(arena, "[name=\"a")).?;
    try std.testing.expectEqualStrings("[name=\"a", unclosed.name.?);
    // An empty selector names nothing.
    const empty = (try parseAriaSelector(arena, "")).?;
    try std.testing.expect(empty.name == null and empty.role == null);
}

test "parseARIASelector: an unknown attribute or an over-long selector never matches" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    try std.testing.expect((try parseAriaSelector(arena, "[label=\"x\"]")) == null);
    const long: [10_001]u8 = @splat('a');
    try std.testing.expect((try parseAriaSelector(arena, &long)) == null);
}
