//! CSS Conditional 5 sections 5.4, 6 and 9.1: owned, serialized conditions.
//! This module parses queries; it does not answer layout or container state.
//! Recognized productions serialize without simplifying their boolean tree;
//! general-enclosed keeps its source, following WebKit's separate node kind
//! (GenericMediaQuerySerialization.cpp, 3ef14dfb5202ec892329ebc5e1667dd9d9b88c4c).
const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const identifiers = @import("serialize.zig");
const rules = @import("rules.zig");
const properties = @import("properties.zig");
const numeric = @import("numeric_values.zig");
const substitution = @import("substitution.zig");
const container_values = @import("container_values.zig");
const Allocator = std.mem.Allocator;
const Out = std.ArrayList(u8);

pub const Condition = struct { name: []u8, query: []u8 };
pub const List = struct {
    allocator: Allocator,
    conditions: []Condition,

    pub fn deinit(self: *List) void {
        for (self.conditions) |condition| {
            self.allocator.free(condition.name);
            self.allocator.free(condition.query);
        }
        self.allocator.free(self.conditions);
    }

    /// Conditional 5 section 9.1's conditionText algorithm, steps 1–5.
    pub fn serialize(self: *const List, allocator: Allocator) Allocator.Error![]u8 {
        var out: Out = .empty;
        errdefer out.deinit(allocator);
        for (self.conditions, 0..) |condition, i| {
            if (i != 0) try out.appendSlice(allocator, ", ");
            try out.appendSlice(allocator, condition.name);
            if (condition.name.len != 0 and condition.query.len != 0) try out.append(allocator, ' ');
            try out.appendSlice(allocator, condition.query);
        }
        return out.toOwnedSlice(allocator);
    }
};

const Kind = enum { size, style, scroll };
const Span = struct { start: usize, end: usize };
const Component = struct {
    token: tokenizer.Token,
    span: Span,
    inner: ?Span = null,

    fn is(self: Component, name: []const u8) bool {
        return self.token.token_type == .ident and tokenizer.nameEql(self.token.value, name);
    }
};

/// Top-level components with actual source positions. A function token's
/// payload omits its punctuation, and cannot be used to recover its start.
fn components(a: Allocator, text: []const u8) Allocator.Error!?[]Component {
    var result: std.ArrayList(Component) = .empty;
    defer result.deinit(a);
    var closers: std.ArrayList(tokenizer.TokenType) = .empty;
    defer closers.deinit(a);
    var tokens = tokenizer.Tokenizer.init(text);
    while (true) {
        tokens.skipWhitespace();
        const start = tokens.pos;
        const token = tokens.next();
        switch (token.token_type) {
            .eof => return try result.toOwnedSlice(a),
            .bad_string, .bad_url, .right_paren, .right_bracket, .right_brace => return null,
            else => {},
        }
        var item = Component{ .token = token, .span = .{ .start = start, .end = tokens.pos } };
        const opening = if (token.token_type == .function) tokens.next().token_type else token.token_type;
        switch (opening) {
            .left_paren, .left_bracket, .left_brace => {
                const inner_start = tokens.pos;
                try closers.append(a, rules.closerOf(opening));
                while (closers.items.len != 0) {
                    const next = tokens.next();
                    switch (next.token_type) {
                        .eof, .bad_string, .bad_url => return null,
                        .left_paren, .left_bracket, .left_brace => try closers.append(a, rules.closerOf(next.token_type)),
                        .right_paren, .right_bracket, .right_brace => {
                            if (next.token_type != closers.items[closers.items.len - 1]) return null;
                            _ = closers.pop();
                        },
                        else => {},
                    }
                }
                // A closing bracket is precisely one byte, unlike a name
                // or url token. Comments before it remain in the inner span.
                item.inner = .{ .start = inner_start, .end = tokens.pos - 1 };
                item.span.end = tokens.pos;
            },
            else => {},
        }
        try result.append(a, item);
    }
}

/// Conditional 5 section 5.4's non-forgiving <container-condition>#.
pub fn parse(a: Allocator, text: []const u8) Allocator.Error!?List {
    const items = try components(a, text) orelse return null;
    defer a.free(items);
    var conditions: std.ArrayList(Condition) = .empty;
    defer conditions.deinit(a);
    var transferred = false;
    defer if (!transferred) for (conditions.items) |condition| {
        a.free(condition.name);
        a.free(condition.query);
    };
    var start: usize = 0;
    var end: usize = 0;
    while (end <= items.len) : (end += 1) {
        if (end != items.len and items[end].token.token_type != .comma) continue;
        if (start == end) return null;
        const slice = items[start..end];
        var name: []u8 = &.{};
        var owns_name = true;
        defer if (owns_name) a.free(name);
        var first: usize = 0;
        if (slice[0].token.token_type == .ident and !slice[0].is("not")) {
            const decoded = try tokenizer.decode(a, slice[0].token.value);
            defer a.free(decoded);
            if (!container_values.isName(decoded)) return null;
            name = try identifiers.serializeIdentifier(a, decoded);
            first = 1;
        }
        var out: Out = .empty;
        defer out.deinit(a);
        if (first != slice.len) {
            if (!try query(a, text, slice[first..], .size, &out)) return null;
        } else if (name.len == 0) return null;
        const query_text = try out.toOwnedSlice(a);
        errdefer a.free(query_text);
        try conditions.append(a, .{ .name = name, .query = query_text });
        owns_name = false;
        start = end + 1;
    }
    const owned = try conditions.toOwnedSlice(a);
    transferred = true;
    return .{ .allocator = a, .conditions = owned };
}

/// Boolean query grammar. Each attempt rolls output back on syntax failure,
/// allowing the caller to preserve the entire production as general-enclosed.
fn query(a: Allocator, text: []const u8, items: []const Component, kind: Kind, out: *Out) Allocator.Error!bool {
    const start = out.items.len;
    var valid = false;
    defer if (!valid) out.shrinkRetainingCapacity(start);
    if (items.len == 0) return false;
    if (kind != .size and try feature(a, text, items, kind, out)) {
        valid = true;
        return true;
    }
    if (items[0].is("not")) {
        if (items.len != 2) return false;
        try out.appendSlice(a, "not ");
        valid = try inParens(a, text, items[1], kind, out);
        return valid;
    }
    if (!try inParens(a, text, items[0], kind, out)) return false;
    if (items.len % 2 == 0) return false;
    var operation: ?bool = null;
    var i: usize = 1;
    while (i < items.len) : (i += 2) {
        const and_op = items[i].is("and");
        if (!and_op and !items[i].is("or")) return false;
        if (operation) |prior| if (prior != and_op) return false;
        operation = and_op;
        try out.appendSlice(a, if (and_op) " and " else " or ");
        if (!try inParens(a, text, items[i + 1], kind, out)) return false;
    }
    valid = true;
    return true;
}

fn inParens(a: Allocator, text: []const u8, item: Component, kind: Kind, out: *Out) Allocator.Error!bool {
    if (item.token.token_type != .left_paren and item.token.token_type != .function) return false;
    const span = item.inner orelse return false;
    const body = text[span.start..span.end];
    const nested = try components(a, body) orelse return false;
    defer a.free(nested);
    var content: Out = .empty;
    defer content.deinit(a);
    var function_name: []const u8 = "";
    const recognized = if (item.token.token_type == .function) blk: {
        if (kind != .size) break :blk false;
        const inner_kind: Kind = if (tokenizer.nameEql(item.token.value, "style")) .style else if (tokenizer.nameEql(item.token.value, "scroll-state")) .scroll else break :blk false;
        function_name = if (inner_kind == .style) "style" else "scroll-state";
        break :blk try query(a, body, nested, inner_kind, &content);
    } else (try query(a, body, nested, kind, &content)) or (try feature(a, body, nested, kind, &content));
    if (recognized) {
        try out.appendSlice(a, function_name);
        try out.append(a, '(');
        try out.appendSlice(a, content.items);
        try out.append(a, ')');
    } else {
        // MQ5 section 3: the final extensibility alternative is taken
        // only after the recognized branches fail. No logical rewriting.
        try appendSource(a, out, text[item.span.start..item.span.end]);
    }
    return true;
}

const Category = enum { length, ratio, orientation, stuck, snapped, scrollable, scrolled, custom };
const FeatureName = struct { text: []u8, category: Category, prefixed: bool };

fn featureName(a: Allocator, item: Component, kind: Kind) Allocator.Error!?FeatureName {
    if (item.token.token_type != .ident) return null;
    const name = try tokenizer.decode(a, item.token.value);
    var keep = false;
    defer if (!keep) a.free(name);
    if (kind == .style) {
        // All three engines intentionally defer ordinary-property style
        // queries: CSSWG #7185 (2023-12-27), WebKit position #57 and Mozilla
        // position #686 limit agreement to custom properties. The Q28/Q42
        // probe (2026-10-27) preserves ordinary-property source verbatim.
        // Revisit when the CSSWG reverses that deferral or an engine ships it.
        // https://github.com/w3c/csswg-drafts/issues/7185
        // https://github.com/WebKit/standards-positions/issues/57
        // https://github.com/mozilla/standards-positions/issues/686
        if (!std.mem.startsWith(u8, name, "--") or name.len <= 2) return null;
        keep = true;
        return .{ .text = name, .category = .custom, .prefixed = false };
    }
    _ = std.ascii.lowerString(name, name);
    const prefixed = kind == .size and (std.mem.startsWith(u8, name, "min-") or std.mem.startsWith(u8, name, "max-"));
    const base = if (prefixed) name[4..] else name;
    const category: Category = if (kind == .size) blk: {
        for ([_][]const u8{ "width", "height", "inline-size", "block-size" }) |s|
            if (std.mem.eql(u8, base, s)) break :blk .length;
        if (std.mem.eql(u8, base, "aspect-ratio")) break :blk .ratio;
        if (!prefixed and std.mem.eql(u8, base, "orientation")) break :blk .orientation;
        return null;
    } else blk: {
        inline for (.{ .stuck, .snapped, .scrollable, .scrolled }) |tag|
            if (std.mem.eql(u8, base, @tagName(tag))) break :blk tag;
        return null;
    };
    keep = true;
    return .{ .text = name, .category = category, .prefixed = prefixed };
}

fn feature(a: Allocator, text: []const u8, items: []const Component, kind: Kind, out: *Out) Allocator.Error!bool {
    const start = out.items.len;
    var valid = false;
    defer if (!valid) out.shrinkRetainingCapacity(start);
    if (items.len == 0) return false;
    if (try featureName(a, items[0], kind)) |name| {
        defer a.free(name.text);
        if (items.len == 1) {
            if (name.prefixed) return false;
            try appendIdentifier(a, out, name.text);
            valid = true;
            return true;
        }
        if (items[1].token.token_type == .colon) {
            try appendIdentifier(a, out, name.text);
            try out.appendSlice(a, ": ");
            const value_text = text[items[1].span.end..items[items.len - 1].span.end];
            if (kind == .style) {
                // Conditional 5 section 6.2: a declaration value cannot
                // contain top-level semicolons or comparison operators.
                // parseDeclarationList alone would accept a trailing ';'.
                for (items[2..]) |item| {
                    if (item.token.token_type == .semicolon) return false;
                    if (item.token.token_type == .delim and item.token.value.len == 1 and
                        std.mem.indexOfScalar(u8, "<>=", item.token.value[0]) != null) return false;
                }
                // Syntax's declaration parser removes !important and
                // preserves custom properties' authored token text.
                const declarations = try rules.parseDeclarationList(a, text);
                defer rules.freeDeclarationList(a, declarations);
                if (declarations.len != 1 or !try substitution.validate(a, declarations[0].value)) return false;
                try appendSource(a, out, declarations[0].value);
            } else if (!try featureValue(a, value_text, name.category, out)) return false;
            valid = true;
            return true;
        }
    }
    if (kind == .scroll) return false;
    valid = try range(a, text, items, kind, out);
    return valid;
}

const Comparison = struct { index: usize, after: usize, text: []const u8 };

/// MQ5 section 3 forbids whitespace tokens between < or > and =.
/// Syntax discards comments without emitting a token (liaison Q57).
fn commentsOnly(text: []const u8) bool {
    var gap = tokenizer.Tokenizer.init(text);
    return gap.next().token_type == .eof;
}

fn range(a: Allocator, text: []const u8, items: []const Component, kind: Kind, out: *Out) Allocator.Error!bool {
    var comparisons: [2]Comparison = undefined;
    var count: usize = 0;
    var i: usize = 0;
    while (i < items.len) : (i += 1) {
        const token = items[i].token;
        if (token.token_type != .delim or token.value.len != 1 or std.mem.indexOfScalar(u8, "<>=", token.value[0]) == null) continue;
        if (count == 2) return false;
        const index = i;
        var op = token.value;
        if (token.value[0] != '=' and i + 1 < items.len and items[i + 1].token.token_type == .delim and std.mem.eql(u8, items[i + 1].token.value, "=") and commentsOnly(text[items[i].span.end..items[i + 1].span.start])) {
            i += 1;
            op = if (token.value[0] == '<') "<=" else ">=";
        }
        comparisons[count] = .{ .index = index, .after = i + 1, .text = op };
        count += 1;
    }
    if (count == 0) return false;
    if (count == 2 and (comparisons[0].text[0] == '=' or comparisons[0].text[0] != comparisons[1].text[0])) return false;
    const middle_start = comparisons[0].after;
    const middle_end = if (count == 2) comparisons[1].index else items.len;
    const spans = [_][]const Component{ items[0..comparisons[0].index], items[middle_start..middle_end], if (count == 2) items[comparisons[1].after..] else &.{} };
    for (spans[0 .. count + 1]) |part| if (part.len == 0) return false;
    var subject: ?usize = null;
    var name: ?FeatureName = null;
    defer if (name) |n| a.free(n.text);
    if (kind == .size) {
        for (spans[0 .. count + 1], 0..) |part, n| {
            if (part.len != 1) continue;
            if (try featureName(a, part[0], kind)) |candidate| {
                if (candidate.prefixed or candidate.category == .orientation or subject != null or (count == 2 and n != 1)) {
                    a.free(candidate.text);
                    return false;
                }
                subject = n;
                name = candidate;
            }
        }
        if (subject == null) return false;
    }
    for (spans[0 .. count + 1], 0..) |part, n| {
        if (n != 0) {
            try out.append(a, ' ');
            try out.appendSlice(a, comparisons[n - 1].text);
            try out.append(a, ' ');
        }
        if (subject == n) {
            try appendIdentifier(a, out, name.?.text);
        } else {
            const value_text = text[part[0].span.start..part[part.len - 1].span.end];
            if (kind == .style) {
                for (part) |item| {
                    if (item.token.token_type == .semicolon or
                        (item.token.token_type == .delim and std.mem.eql(u8, item.token.value, "!"))) return false;
                }
                if (!try substitution.validate(a, value_text)) return false;
                if (part.len == 1 and part[0].token.token_type == .ident) {
                    const decoded = try tokenizer.decode(a, part[0].token.value);
                    defer a.free(decoded);
                    try appendIdentifier(a, out, decoded);
                } else try appendSource(a, out, value_text);
            } else if (!try featureValue(a, value_text, name.?.category, out)) return false;
        }
    }
    return true;
}

fn featureValue(a: Allocator, text: []const u8, category: Category, out: *Out) Allocator.Error!bool {
    var stream = properties.Stream.init(text);
    if (category == .length or category == .ratio) {
        // Arbitrary substitutions retain their real grammar and source;
        // their type is checked by the eventual container evaluator.
        if (substitution.mentionsFunction(text)) {
            if (!try substitution.validate(a, text)) return false;
            try appendSource(a, out, substitution.originalText(text));
            return true;
        }
        const grammar = @import("math_values.zig").Grammar{ .kind = if (category == .length) .length else .number, .minimum = if (category == .ratio) 0 else -std.math.floatMax(f64) };
        const first = try numeric.Number.consume(.{ .allocator = a }, &stream, grammar, category == .length) orelse return false;
        defer first.unref();
        try first.serialize(out, a);
        if (category == .ratio) {
            const slash = stream.peek();
            if (slash.token_type == .delim and std.mem.eql(u8, slash.value, "/")) {
                _ = stream.next();
                const second = try numeric.Number.consume(.{ .allocator = a }, &stream, grammar, false) orelse return false;
                defer second.unref();
                try out.appendSlice(a, " / ");
                try second.serialize(out, a);
            }
        }
        return stream.atEnd();
    }
    const token = stream.next();
    if (token.token_type != .ident or !stream.atEnd()) return false;
    const keywords: []const []const u8 = switch (category) {
        .orientation => &.{ "portrait", "landscape" },
        .stuck => &.{ "none", "top", "right", "bottom", "left", "block-start", "inline-start", "block-end", "inline-end" },
        .snapped => &.{ "none", "x", "y", "block", "inline", "both" },
        .scrollable, .scrolled => &.{ "none", "top", "right", "bottom", "left", "block-start", "inline-start", "block-end", "inline-end", "x", "y", "block", "inline" },
        else => return false,
    };
    for (keywords) |keyword| if (tokenizer.nameEql(token.value, keyword)) {
        try out.appendSlice(a, keyword);
        return true;
    };
    return false;
}

fn appendIdentifier(a: Allocator, out: *Out, name: []const u8) Allocator.Error!void {
    const serialized = try identifiers.serializeIdentifier(a, name);
    defer a.free(serialized);
    try out.appendSlice(a, serialized);
}

/// CSS Syntax 3 section 3.3, preserving source whitespace and escapes.
fn appendSource(a: Allocator, out: *Out, text: []const u8) Allocator.Error!void {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        switch (text[i]) {
            0 => try out.appendSlice(a, "�"),
            '\r' => {
                try out.append(a, '\n');
                if (i + 1 < text.len and text[i + 1] == '\n') i += 1;
            },
            0x0c => try out.append(a, '\n'),
            0xed => {
                if (i + 2 < text.len and text[i + 1] >= 0xa0 and text[i + 1] <= 0xbf) {
                    try out.appendSlice(a, "�");
                    i += 2;
                } else try out.append(a, text[i]);
            },
            else => try out.append(a, text[i]),
        }
    }
}
