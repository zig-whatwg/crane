//! Paged Media 3 §§4.2–4.3/7.1–7.3 and CSSOM §6.4.7.
//! This module uses Crane's CSS tokenizer and existing numeric parser.
const std = @import("std");
const tokens = @import("tokenizer.zig");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const serialization = @import("serialize.zig");
const Allocator = std.mem.Allocator;

/// §4.3: an optional comma-separated page selector list. Whitespace is
/// allowed around selectors, never inside one. Comments are tokenizer
/// trivia, so foo/**/:first is accepted without inventing whitespace.
pub fn selectors(allocator: Allocator, input: []const u8) Allocator.Error!?[]u8 {
    var tokenizer = tokens.Tokenizer.init(input);
    var token = tokenizer.next();
    while (token.token_type == .whitespace) token = tokenizer.next();
    if (token.token_type == .eof) return try allocator.dupe(u8, "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    while (true) {
        var components: usize = 0;
        if (token.token_type == .ident) {
            const name = try tokens.decode(allocator, token.value);
            defer allocator.free(name);
            const escaped = try serialization.serializeIdentifier(allocator, name);
            defer allocator.free(escaped);
            try out.appendSlice(allocator, escaped);
            components += 1;
            token = tokenizer.next();
        }
        while (token.token_type == .colon) {
            const pseudo = tokenizer.next();
            if (pseudo.token_type != .ident) return null;
            var name: ?[]const u8 = null;
            for ([_][]const u8{ "left", "right", "first", "blank" }) |candidate| {
                if (tokens.nameEql(pseudo.value, candidate)) {
                    name = candidate;
                    break;
                }
            }
            try out.append(allocator, ':');
            try out.appendSlice(allocator, name orelse return null);
            components += 1;
            token = tokenizer.next();
        }
        if (components == 0) return null;
        while (token.token_type == .whitespace) token = tokenizer.next();
        if (token.token_type == .eof) break;
        if (token.token_type != .comma) return null;
        try out.appendSlice(allocator, ", ");
        token = tokenizer.next();
        while (token.token_type == .whitespace) token = tokenizer.next();
    }
    return try out.toOwnedSlice(allocator);
}

pub const Descriptor = enum {
    size,
    page_orientation,
    marks,
    bleed,

    pub fn name(self: Descriptor) []const u8 {
        return if (self == .page_orientation) "page-orientation" else @tagName(self);
    }
    pub fn parse(name_text: []const u8) ?Descriptor {
        inline for (@typeInfo(Descriptor).@"enum".fields) |field| {
            const kind: Descriptor = @enumFromInt(field.value);
            if (std.ascii.eqlIgnoreCase(name_text, kind.name())) return kind;
        }
        return null;
    }
};

const Length = union(enum) {
    numeric: math.Numeric,
    calculation: *math.Expression,

    fn deinit(self: Length) void {
        if (self == .calculation) self.calculation.unref();
    }
    fn append(self: Length, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .calculation => |expression| try expression.serialize(out, allocator),
            .numeric => |number| {
                try values.appendNumber(number.value, out, allocator);
                try out.appendSlice(allocator, number.unit.name());
            },
        }
    }
};

fn length(allocator: Allocator, stream: *properties.Stream, nonnegative: bool) Allocator.Error!?Length {
    const token = stream.peek();
    if (math.isFunction(token)) {
        const parsed = try properties.mathValue(.{ .allocator = allocator }, stream, .{
            .kind = .length,
            .minimum = if (nonnegative) 0 else -std.math.floatMax(f64),
        }) orelse return null;
        return .{ .calculation = parsed.calculation };
    }
    const number = token.numeric_value orelse return null;
    if (nonnegative and number < 0) return null;
    const unit: math.Unit = if (token.token_type == .number and number == 0)
        .px
    else if (token.token_type == .dimension)
        math.Unit.parse(token.unit orelse return null) orelse return null
    else
        return null;
    if (unit.base() != .length) return null;
    _ = stream.next();
    return .{ .numeric = .{ .value = number, .unit = unit } };
}

fn keyword(token: tokens.Token, candidates: []const []const u8) ?[]const u8 {
    if (token.token_type != .ident) return null;
    for (candidates) |name| if (tokens.nameEql(token.value, name)) return name;
    return null;
}

/// Page-specific descriptor grammar (Q47). Ordinary properties belong to
/// DeclarationBlock; pending substitution is handled by the page Data.
pub fn descriptor(allocator: Allocator, kind: Descriptor, input: []const u8) Allocator.Error!?[]u8 {
    var stream = properties.Stream.init(input);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    // Q47 (Chrome 156 / Firefox 158 / Safari 27, 2026-10-27): no
    // browser accepts marks or bleed. Keep their unshipped IDL attributes
    // inert until the separately routed exposure override hides them.
    if (kind == .marks or kind == .bleed) return null;
    const first_token = stream.peek();
    if (first_token.token_type == .ident) {
        const decoded = try tokens.decode(allocator, first_token.value);
        defer allocator.free(decoded);
        if (values.CssWide.parse(decoded)) |wide| {
            _ = stream.next();
            if (!stream.atEnd()) return null;
            return try allocator.dupe(u8, wide.name());
        }
    }
    switch (kind) {
        .size => {
            const sizes = &.{ "a5", "a4", "a3", "b5", "b4", "jis-b5", "jis-b4", "letter", "legal", "ledger" };
            const orientations = &.{ "portrait", "landscape" };
            if (keyword(stream.peek(), &.{"auto"})) |name| {
                _ = stream.next();
                try out.appendSlice(allocator, name);
            } else if (stream.peek().token_type == .ident) {
                var size: ?[]const u8 = null;
                var orientation: ?[]const u8 = null;
                var count: usize = 0;
                while (count < 2 and !stream.atEnd()) : (count += 1) {
                    const token = stream.next();
                    if (keyword(token, sizes)) |name| {
                        if (size != null) return null;
                        size = name;
                    } else if (keyword(token, orientations)) |name| {
                        if (orientation != null) return null;
                        orientation = name;
                    } else return null;
                }
                if (size) |name| try out.appendSlice(allocator, name);
                if (orientation) |name| {
                    // CSSOM shortest serialization: a named page size is
                    // portrait by default (css-page size-valid.html).
                    if (size == null or !std.mem.eql(u8, name, "portrait")) {
                        if (size != null) try out.append(allocator, ' ');
                        try out.appendSlice(allocator, name);
                    }
                }
            } else {
                const first = try length(allocator, &stream, true) orelse return null;
                defer first.deinit();
                try first.append(&out, allocator);
                if (!stream.atEnd()) {
                    const second = try length(allocator, &stream, true) orelse return null;
                    defer second.deinit();
                    var tail: std.ArrayList(u8) = .empty;
                    defer tail.deinit(allocator);
                    try second.append(&tail, allocator);
                    if (!std.mem.eql(u8, out.items, tail.items)) {
                        try out.append(allocator, ' ');
                        try out.appendSlice(allocator, tail.items);
                    }
                }
            }
        },
        .page_orientation => {
            const name = keyword(stream.next(), &.{ "upright", "rotate-left", "rotate-right" }) orelse return null;
            try out.appendSlice(allocator, name);
        },
        .marks, .bleed => unreachable,
    }
    if (!stream.atEnd()) return null;
    return try out.toOwnedSlice(allocator);
}
