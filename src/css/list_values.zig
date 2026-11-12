//! CSS Lists 3 §§3.3–3.6 and 4.1–4.2: declaration values, without layout.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const serialize_mod = @import("serialize.zig");
const math = @import("math_values.zig");
const symbols_mod = @import("counter_style_values.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Stream = properties.Stream;
const TreeScopeRef = @FieldType(@import("cascade.zig").Source, "tree_scope");

/// Lists 3 §3.3 list-style-type's <counter-style-name>, computed: the name
/// with the tree scope of the declaration that named it (Scoping 1's
/// tree-scoped names; @counter-style rules are looked up from that scope).
/// CSSOM serializes the name alone; equality keeps the scope, so the same
/// name from another tree is another value (css/css-lists/
/// list-style-type-transition-tree-scope-custom-ident.html, Chrome 1/1:
/// the change starts a transition). font_family.zig's model; Blink keeps a
/// ScopedCSSName for list-style-type.
pub const ScopedName = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    name: *values.SharedText,
    scope: TreeScopeRef,

    pub fn create(allocator: Allocator, name: *values.SharedText, scope: TreeScopeRef) Allocator.Error!*ScopedName {
        const self = try allocator.create(ScopedName);
        name.ref();
        self.* = .{ .allocator = allocator, .name = name, .scope = scope };
        return self;
    }

    pub fn ref(self: *ScopedName) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *ScopedName) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.name.unref();
        self.allocator.destroy(self);
    }

    pub fn eql(self: *const ScopedName, other: *const ScopedName) bool {
        return self == other or (self.scope.serial == other.scope.serial and std.mem.eql(u8, self.name.bytes, other.name.bytes));
    }
};

/// Whether list-style-type's specified text is an author-defined
/// <counter-style-name>: not a <string>, not symbols(), and not one of the
/// predefined counter styles, which match as keywords and are the same
/// value from any tree (css/css-lists/list-style-type-transition-tree-scope-
/// keyword.html: `circle` from the document and from a shadow tree starts
/// no transition; Blink parses them as CSSIdentifierValues and only other
/// names as tree-scoped custom idents).
pub fn namesCounterStyle(text: []const u8) bool {
    return text.len != 0 and text[0] != '"' and !std.mem.startsWith(u8, text, "symbols(") and
        !@import("counter_style_descriptors.zig").isPredefined(text);
}

pub const Counters = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    entries: []const Entry,

    const Entry = struct {
        name: []u8,
        reversed: bool,
        // Lists3 §4.1: a reversed counter with no explicit start remains
        // automatic. Its used value needs the counter tree, not CSS parsing.
        number: ?Value,

        fn deinit(self: Entry, allocator: Allocator) void {
            allocator.free(self.name);
            if (self.number) |number| number.release();
        }
    };

    /// Takes the entire list on success; callers release it on failure.
    fn take(allocator: Allocator, entries: *std.ArrayList(Entry)) Allocator.Error!*Counters {
        const result = try allocator.create(Counters);
        errdefer allocator.destroy(result);
        result.* = .{ .allocator = allocator, .entries = try entries.toOwnedSlice(allocator) };
        return result;
    }

    pub fn ref(self: *Counters) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Counters) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.entries) |entry| entry.deinit(self.allocator);
        self.allocator.free(self.entries);
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Counters, other: *const Counters) bool {
        if (self == other) return true;
        if (self.entries.len != other.entries.len) return false;
        for (self.entries, other.entries) |a, b| {
            if (a.reversed != b.reversed or !std.mem.eql(u8, a.name, b.name)) return false;
            if (a.number) |number| {
                if (b.number == null or !number.eql(b.number.?)) return false;
            } else if (b.number != null) return false;
        }
        return true;
    }
    pub fn needsUnavailableMetrics(self: *const Counters) bool {
        for (self.entries) |entry| if (entry.number) |number| {
            if (number.needsUnavailableMetrics(false)) return true;
        };
        return false;
    }
    pub fn needsTreeCounts(self: *const Counters) bool {
        for (self.entries) |entry| if (entry.number) |number| {
            if (number.needsTreeCounts()) return true;
        };
        return false;
    }
    pub fn needsRandomBase(self: *const Counters) bool {
        for (self.entries) |entry| if (entry.number) |number| {
            if (number.needsRandomBase()) return true;
        };
        return false;
    }

    pub fn compute(self: *Counters, allocator: Allocator, context: math.Context) Allocator.Error!*Counters {
        var needs_compute = false;
        for (self.entries) |entry| if (entry.number) |number| {
            if (number == .calculation) needs_compute = true;
        };
        if (!needs_compute) {
            self.ref();
            return self;
        }
        var entries: std.ArrayList(Entry) = .empty;
        defer {
            for (entries.items) |entry| entry.deinit(allocator);
            entries.deinit(allocator);
        }
        for (self.entries) |entry| {
            const name = try allocator.dupe(u8, entry.name);
            errdefer allocator.free(name);
            var number = entry.number;
            if (number) |n| {
                if (n == .calculation) {
                    const computed = try n.calculation.compute(allocator, context);
                    if (computed.computedNumber()) |scalar| {
                        number = .{ .integer = @intFromFloat(scalar.value) };
                        computed.unref();
                    } else number = .{ .calculation = computed };
                } else n.retain();
            }
            errdefer if (number) |n| n.release();
            try entries.append(allocator, .{ .name = name, .reversed = entry.reversed, .number = number });
        }
        return take(allocator, &entries);
    }

    pub fn serialize(self: *const Counters, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.entries, 0..) |entry, index| {
            if (index != 0) try out.append(allocator, ' ');
            if (entry.reversed) try out.appendSlice(allocator, "reversed(");
            const escaped = try serialize_mod.serializeIdentifier(allocator, entry.name);
            defer allocator.free(escaped);
            try out.appendSlice(allocator, escaped);
            if (entry.reversed) try out.append(allocator, ')');
            if (entry.number) |number| {
                try out.append(allocator, ' ');
                try properties.serializeValue(.counter_reset, number, out, allocator);
            }
        }
    }

    pub fn consume(options: properties.ParseOptions, longhand: properties.Longhand, stream: *Stream) Allocator.Error!?*Counters {
        const allocator = options.allocator;
        var entries: std.ArrayList(Entry) = .empty;
        defer {
            for (entries.items) |entry| entry.deinit(allocator);
            entries.deinit(allocator);
        }
        while (!stream.atEnd()) {
            var token = stream.next();
            const reversed = token.token_type == .function and tokens.nameEql(token.value, "reversed");
            if (reversed) {
                if (longhand != .counter_reset or stream.next().token_type != .left_paren) return null;
                token = stream.next();
            }
            if (token.token_type != .ident) return null;
            const name = try tokens.decode(allocator, token.value);
            var owned = true;
            defer if (owned) allocator.free(name);
            if (!@import("syntax_definitions.zig").isCustomIdent(name) or std.ascii.eqlIgnoreCase(name, "none")) return null;
            if (reversed and !closeFunction(stream)) return null;
            var number = try @import("box_values.zig").consumeInteger(options, stream, null);
            if (number == null and !reversed) number = .{ .integer = if (longhand == .counter_increment) 1 else 0 };
            defer if (owned) if (number) |n| n.release();
            try entries.append(allocator, .{ .name = name, .reversed = reversed, .number = number });
            owned = false;
        }
        if (entries.items.len == 0) return null;
        return try take(allocator, &entries);
    }
};

fn closeFunction(stream: *Stream) bool {
    if (stream.peek().token_type == .right_paren) {
        _ = stream.next();
        return true;
    }
    return stream.atEnd();
}

pub fn consumeType(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const allocator = options.allocator;
    const token = stream.peek();
    if (token.token_type == .ident) {
        if (tokens.nameEql(token.value, "none")) {
            _ = stream.next();
            return Value.kw(.none);
        }
        const name = try @import("counter_style_descriptors.zig").parseName(allocator, token.value, false) orelse return null;
        defer allocator.free(name);
        _ = stream.next();
        if (std.mem.eql(u8, name, "disc")) return Value.kw(.disc);
        return .{ .text = try values.SharedText.create(allocator, name) };
    }
    if (token.token_type == .string) {
        _ = stream.next();
        const text = try tokens.decode(allocator, token.stringContents());
        defer allocator.free(text);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try values.appendString(text, &out, allocator);
        return .{ .text = try values.SharedText.create(allocator, out.items) };
    }
    if (token.token_type != .function or !tokens.nameEql(token.value, "symbols")) return null;
    _ = stream.next();
    var reader = StringSymbols{ .allocator = allocator, .stream = stream };
    const symbols = try symbols_mod.consumeSymbols(allocator, false, &reader) orelse return null;
    defer symbols.deinit(allocator);
    return .{ .text = try values.SharedText.create(allocator, symbols.text) };
}

const StringSymbols = struct {
    allocator: Allocator,
    stream: *Stream,

    pub fn peek(self: *StringSymbols) tokens.Token {
        return self.stream.peek();
    }
    pub fn next(self: *StringSymbols) tokens.Token {
        return self.stream.next();
    }
    pub fn take(self: *StringSymbols, kind: tokens.TokenType) bool {
        if (self.peek().token_type != kind) return false;
        _ = self.next();
        return true;
    }
    pub fn closeFunction(self: *StringSymbols) bool {
        return self.take(.right_paren) or self.stream.atEnd();
    }
    pub fn symbol(self: *StringSymbols) Allocator.Error!?symbols_mod.Symbol {
        const token = self.next();
        if (token.token_type != .string) return null;
        const text = try tokens.decode(self.allocator, token.stringContents());
        defer self.allocator.free(text);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(self.allocator);
        try values.appendString(text, &out, self.allocator);
        return .{ .text = try out.toOwnedSlice(self.allocator) };
    }
};

pub const longhands = [_]properties.Longhand{ .list_style_position, .list_style_image, .list_style_type };

pub fn consumeShorthand(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var parts: [longhands.len]?Value = @splat(null);
    defer for (parts) |part| if (part) |value| value.release();
    var none_count: usize = 0;
    var any = false;
    while (!stream.atEnd()) {
        const token = stream.peek();
        if (token.token_type == .ident and tokens.nameEql(token.value, "none")) {
            _ = stream.next();
            none_count += 1;
            if (none_count > 2) return false;
            any = true;
            continue;
        }
        var matched = false;
        // Lists3 §3.6 / Q32: once position is filled its spelling can be
        // a custom style name, but a third type/position has no slot.
        for (longhands, 0..) |longhand, index| {
            if (parts[index] != null) continue;
            var trial = stream.*;
            if (try properties.parseLonghand(options, longhand, &trial)) |value| {
                parts[index] = value;
                stream.* = trial;
                matched = true;
                any = true;
                break;
            }
        }
        if (!matched) return false;
    }
    if (!any) return false;
    if (none_count != 0) {
        // §3.6: each none fills an otherwise unset image/type, and one
        // none applies to both when neither was explicitly set.
        const available = @as(usize, @intFromBool(parts[1] == null)) + @as(usize, @intFromBool(parts[2] == null));
        if (none_count > available) return false;
        if (parts[1] == null) parts[1] = Value.kw(.none);
        if (parts[2] == null) parts[2] = Value.kw(.none);
    }
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, parts) |longhand, part| {
        const value = part orelse longhand.info().initial;
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeShorthand(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const list_type = assigned[2].value;
    const type_name: ?[]const u8 = switch (list_type) {
        .text => |t| t.bytes,
        .scoped_name => |n| n.name.bytes,
        else => null,
    };
    const ambiguous = if (type_name) |name| std.ascii.eqlIgnoreCase(name, "inside") or std.ascii.eqlIgnoreCase(name, "outside") else false;
    var wrote = false;
    for (longhands, assigned, 0..) |longhand, item, index| {
        // Q32 / CSSOM shortest round-trip form: retain an initial outside
        // before a type named inside/outside, so the type stays a name.
        if (!(index == 0 and ambiguous) and item.value.eql(longhand.info().initial)) continue;
        if (wrote) try out.append(allocator, ' ');
        try properties.serializeValue(longhand, item.value, out, allocator);
        wrote = true;
    }
    if (!wrote) try out.appendSlice(allocator, "outside");
    return true;
}
