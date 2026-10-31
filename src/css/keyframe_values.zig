//! CSS Animations 1 §3 and Scroll Animations 1 named range selectors.
//! Q63: C/F reject calculated selectors; F/S make invalid keyText a no-op.
//! Selector matching follows Blink FindKeyframeIndex: ordered numeric lists,
//! never a comparison of rounded serialization or a subset of the selectors.
const std = @import("std");
const tokens = @import("tokenizer.zig");
const values = @import("style_values.zig");
const serialize = @import("serialize.zig");
const Stream = @import("properties.zig").Stream;
const Allocator = std.mem.Allocator;

pub const Range = enum {
    cover,
    contain,
    entry,
    exit,
    entry_crossing,
    exit_crossing,

    pub fn name(self: Range) []const u8 {
        return switch (self) {
            .entry_crossing => "entry-crossing",
            .exit_crossing => "exit-crossing",
            else => @tagName(self),
        };
    }
    pub fn parse(token: tokens.Token) ?Range {
        if (token.token_type != .ident) return null;
        inline for (@typeInfo(Range).@"enum".field_values) |field_value| {
            const r: Range = @fromBackingInt(@intCast(field_value));
            if (tokens.nameEql(token.value, r.name())) return r;
        }
        return null;
    }
};

pub const Selector = struct { range: ?Range = null, percentage: f64 };
pub const Selectors = struct {
    allocator: Allocator,
    items: []Selector,

    pub fn deinit(self: *Selectors) void {
        self.allocator.free(self.items);
    }
    pub fn eql(a: Selectors, b: Selectors) bool {
        if (a.items.len != b.items.len) return false;
        for (a.items, b.items) |x, y| if (x.range != y.range or x.percentage != y.percentage) return false;
        return true;
    }
    pub fn parse(allocator: Allocator, text: []const u8) Allocator.Error!?Selectors {
        var out: std.ArrayList(Selector) = .empty;
        defer out.deinit(allocator);
        var stream = Stream.init(text);
        while (true) {
            const token = stream.next();
            var item: Selector = undefined;
            if (token.token_type == .ident and (tokens.nameEql(token.value, "from") or tokens.nameEql(token.value, "to"))) {
                item = .{ .percentage = if (tokens.nameEql(token.value, "from")) 0 else 100 };
            } else {
                const range = Range.parse(token);
                const percent = if (range != null) stream.next() else token;
                if (percent.token_type != .percentage) return null;
                const n = percent.numeric_value orelse return null;
                // Named ranges accept percentages outside [0,100]. Ordinary
                // offsets do not (Animations 1 §3, Scroll Animations 1).
                if (!std.math.isFinite(n) or (range == null and (n < 0 or n > 100))) return null;
                item = .{ .range = range, .percentage = n };
            }
            try out.append(allocator, item);
            const separator = stream.next();
            if (separator.token_type == .eof) break;
            if (separator.token_type != .comma) return null;
        }
        return .{ .allocator = allocator, .items = try out.toOwnedSlice(allocator) };
    }
    pub fn serialize(self: Selectors, allocator: Allocator) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);
        for (self.items, 0..) |item, i| {
            if (i > 0) try out.appendSlice(allocator, ", ");
            if (item.range) |range| {
                try out.appendSlice(allocator, range.name());
                try out.append(allocator, ' ');
            }
            try values.appendNumber(item.percentage, &out, allocator);
            try out.append(allocator, '%');
        }
        return out.toOwnedSlice(allocator);
    }
};

pub fn reservedName(name: []const u8) bool {
    inline for (.{ "none", "default", "initial", "inherit", "unset", "revert", "revert-layer" }) |keyword| {
        if (std.ascii.eqlIgnoreCase(name, keyword)) return true;
    }
    return false;
}

/// Decoded, owned name. String and identifier forms have the same identity.
/// Empty strings are invalid (CSSWG #13151; all three engines, Q63/D66).
pub fn consumeName(allocator: Allocator, stream: *Stream) Allocator.Error!?[]u8 {
    const token = stream.next();
    if (token.token_type != .ident and token.token_type != .string) return null;
    const raw = if (token.token_type == .string) token.stringContents() else token.value;
    const decoded = try tokens.decode(allocator, raw);
    if (decoded.len == 0 or (token.token_type == .ident and reservedName(decoded))) {
        allocator.free(decoded);
        return null;
    }
    return decoded;
}

/// The January 2026 serializer rule ships in Firefox; Q63 follows the newer
/// spec. A CSSOM setter can still supply an otherwise unparseable name.
pub fn serializeName(name: []const u8, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (reservedName(name)) {
        try out.append(allocator, '"');
        for (name) |c| switch (c) {
            '"', '\\' => {
                try out.append(allocator, '\\');
                try out.append(allocator, c);
            },
            0 => try out.appendSlice(allocator, "\u{FFFD}"),
            1...0x1f, 0x7f => try out.print(allocator, "\\{x} ", .{c}),
            else => try out.append(allocator, c),
        };
        try out.append(allocator, '"');
    } else {
        const escaped = try serialize.serializeIdentifier(allocator, name);
        defer allocator.free(escaped);
        try out.appendSlice(allocator, escaped);
    }
}
