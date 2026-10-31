//! Counter Styles 3 §§2.1, 3.1–3.9, 9.2: the CSSOM descriptor model.
//! The Syntax tokenizer and CSSOM serializers are shared with properties.
const std = @import("std");
const rules = @import("rules.zig");
const properties = @import("properties.zig");
const tokens = @import("tokenizer.zig");
const values = @import("style_values.zig");
const serialize = @import("serialize.zig");
const math = @import("math_values.zig");
const Allocator = std.mem.Allocator;

pub const Descriptor = enum {
    system,
    symbols,
    additive_symbols,
    negative,
    prefix,
    suffix,
    pad,
    range,
    fallback,
    speak_as,

    pub fn name(self: Descriptor) []const u8 {
        return switch (self) {
            .additive_symbols => "additive-symbols",
            .speak_as => "speak-as",
            else => @tagName(self),
        };
    }
    pub fn parse(text: []const u8) ?Descriptor {
        inline for (@typeInfo(Descriptor).@"enum".field_values) |field_value| {
            const d: Descriptor = @enumFromInt(field_value);
            if (std.mem.eql(u8, text, d.name())) return d;
        }
        return null;
    }
};

pub const Algorithm = enum { cyclic, numeric, alphabetic, symbolic, additive, fixed, extends };
pub const Parsed = struct {
    text: []u8,
    algorithm: Algorithm = .symbolic,
    count: usize = 0,
    // Q44: accepted unresolved calculations retain their existing trees;
    // there is no element/font context here, and no used-value evaluation.
    expressions: []*math.Expression = &.{},

    pub fn deinit(self: Parsed, allocator: Allocator) void {
        allocator.free(self.text);
        for (self.expressions) |expression| expression.unref();
        allocator.free(self.expressions);
    }
};
pub const Data = struct {
    allocator: Allocator,
    /// Serialized identifier, owned; getters need no further CSS parsing.
    name: []u8,
    descriptors: [10]?Parsed = .{null} ** 10,

    pub fn deinit(self: *Data) void {
        self.allocator.free(self.name);
        for (self.descriptors) |descriptor| if (descriptor) |d| d.deinit(self.allocator);
    }
    pub fn get(self: *const Data, descriptor: Descriptor) []const u8 {
        return if (self.descriptors[@intFromEnum(descriptor)]) |parsed| parsed.text else "";
    }
    fn algorithm(self: *const Data) Algorithm {
        return if (self.descriptors[@intFromEnum(Descriptor.system)]) |parsed| parsed.algorithm else .symbolic;
    }
    fn definesStyle(self: *const Data) bool {
        const symbols = self.descriptors[@intFromEnum(Descriptor.symbols)];
        const additive = self.descriptors[@intFromEnum(Descriptor.additive_symbols)];
        return switch (self.algorithm()) {
            .numeric, .alphabetic => symbols != null and symbols.?.count >= 2,
            .cyclic, .fixed, .symbolic => symbols != null and symbols.?.count >= 1,
            .additive => additive != null and additive.?.count >= 1,
            .extends => symbols == null and additive == null,
        };
    }
    pub fn setName(self: *Data, input: []const u8) Allocator.Error!bool {
        // Q28 probe, Chrome 156 / Firefox 158 / Safari 27 (2026-10-27):
        // all parse one custom-ident; two lowercase predefined names.
        const replacement = try parseName(self.allocator, input, true) orelse return false;
        self.allocator.free(self.name);
        self.name = replacement;
        return true;
    }
    pub fn set(self: *Data, descriptor: Descriptor, input: []const u8) Allocator.Error!bool {
        // §9.2 steps 1–4: parse, preserve a defined counter style, and
        // never change the algorithm. A failed setter leaves every field.
        const replacement = try parseDescriptor(self.allocator, descriptor, input) orelse return false;
        const old = self.descriptors[@intFromEnum(descriptor)];
        const old_algorithm = self.algorithm();
        self.descriptors[@intFromEnum(descriptor)] = replacement;
        if (!self.definesStyle() or (descriptor == .system and replacement.algorithm != old_algorithm)) {
            self.descriptors[@intFromEnum(descriptor)] = old;
            replacement.deinit(self.allocator);
            return false;
        }
        if (old) |d| d.deinit(self.allocator);
        return true;
    }
    /// Q90 (2026-10-27): Blink css_counter_style_rule.cc and WebKit
    /// CSSCounterStyleRule.cpp use this fixed order; Gecko's
    /// counter_style_descriptors.toml uses another fixed order. Follow the
    /// two-engine majority. WPT CSSCounterStyleRule.html calls order undefined.
    pub fn cssText(self: *const Data, allocator: Allocator) Allocator.Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.appendSlice(allocator, "@counter-style ");
        try out.appendSlice(allocator, self.name);
        try out.appendSlice(allocator, " { ");
        inline for (@typeInfo(Descriptor).@"enum".field_values) |field_value| {
            const descriptor: Descriptor = @enumFromInt(field_value);
            if (self.descriptors[field_value]) |parsed| {
                try out.appendSlice(allocator, descriptor.name());
                try out.appendSlice(allocator, ": ");
                try out.appendSlice(allocator, parsed.text);
                try out.appendSlice(allocator, "; ");
            }
        }
        try out.append(allocator, '}');
        return out.toOwnedSlice(allocator);
    }
};

pub fn fromParsed(allocator: Allocator, rule: *const rules.Rule) Allocator.Error!?Data {
    if (!rule.has_block) return null;
    var result: Data = .{ .allocator = allocator, .name = try parseName(allocator, rule.prelude, true) orelse return null };
    errdefer result.deinit();
    for (rule.declarations) |declaration| {
        if (declaration.important) continue;
        const descriptor = Descriptor.parse(declaration.name) orelse continue;
        const parsed = try parseDescriptor(allocator, descriptor, declaration.value) orelse continue;
        if (result.descriptors[@intFromEnum(descriptor)]) |old| old.deinit(allocator);
        result.descriptors[@intFromEnum(descriptor)] = parsed;
    }
    // §3.1: an insufficient symbol list does not invalidate the rule.
    return result;
}

const predefined = [_][]const u8{
    "decimal", "decimal-leading-zero", "arabic-indic", "armenian", "upper-armenian", "lower-armenian", "bengali", "cambodian", "khmer", "cjk-decimal", "devanagari", "georgian", "gujarati", "gurmukhi", "hebrew", "kannada", "lao", "malayalam", "mongolian", "myanmar", "oriya", "persian", "lower-roman", "upper-roman", "tamil", "telugu", "thai", "tibetan", "lower-alpha", "lower-latin", "upper-alpha", "upper-latin", "lower-greek", "hiragana", "hiragana-iroha", "katakana", "katakana-iroha", "disc", "circle", "square", "disclosure-open", "disclosure-closed", "cjk-earthly-branch", "cjk-heavenly-stem", "japanese-informal", "japanese-formal", "korean-hangul-formal", "korean-hanja-informal", "korean-hanja-formal", "simp-chinese-informal", "simp-chinese-formal", "trad-chinese-informal", "trad-chinese-formal", "cjk-ideographic", "ethiopic-numeric",
};

fn customIdent(allocator: Allocator, token: tokens.Token) Allocator.Error!?[]u8 {
    if (token.token_type != .ident) return null;
    const decoded = try tokens.decode(allocator, token.value);
    if (values.CssWide.parse(decoded) != null or std.ascii.eqlIgnoreCase(decoded, "default")) {
        allocator.free(decoded);
        return null;
    }
    return decoded;
}

fn counterName(allocator: Allocator, token: tokens.Token, defining: bool) Allocator.Error!?[]u8 {
    const decoded = try customIdent(allocator, token) orelse return null;
    defer allocator.free(decoded);
    if (std.ascii.eqlIgnoreCase(decoded, "none")) return null;
    if (defining) for ([_][]const u8{ "decimal", "disc", "circle", "square", "disclosure-open", "disclosure-closed" }) |forbidden| {
        if (std.ascii.eqlIgnoreCase(decoded, forbidden)) return null;
    };
    for (predefined) |name| if (std.ascii.eqlIgnoreCase(decoded, name)) return try serialize.serializeIdentifier(allocator, name);
    return try serialize.serializeIdentifier(allocator, decoded);
}

pub fn parseName(allocator: Allocator, input: []const u8, defining: bool) Allocator.Error!?[]u8 {
    var stream = properties.Stream.init(input);
    const token = stream.next();
    if (!stream.atEnd()) return null;
    return counterName(allocator, token, defining);
}

fn symbol(allocator: Allocator, stream: *properties.Stream) Allocator.Error!?[]u8 {
    const token = stream.peek();
    if (token.token_type == .string) {
        _ = stream.next();
        const decoded = try tokens.decode(allocator, token.stringContents());
        defer allocator.free(decoded);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try values.appendString(decoded, &out, allocator);
        return try out.toOwnedSlice(allocator);
    }
    const decoded = try customIdent(allocator, token) orelse return null;
    defer allocator.free(decoded);
    _ = stream.next();
    // Q28: no browser accepts the at-risk <image> arm; idents (including
    // none) and strings are accepted. No image parser is called here.
    return try serialize.serializeIdentifier(allocator, decoded);
}

const Integer = union(enum) {
    literal: f64,
    calculation: *math.Expression,

    fn known(self: Integer) ?f64 {
        return switch (self) {
            .literal => |value| value,
            .calculation => |expression| if (expression.knownNumber()) |n| n.value else null,
        };
    }
    /// Q46's unanimous probe: ordering compares the resolved integer,
    /// while the specified expression itself remains untouched. There is
    /// no computed Context: known() returns null for unresolved ratios.
    fn comparable(self: Integer, nonnegative: bool) ?f64 {
        const raw = self.known() orelse return null;
        const value = if (std.math.isNan(raw)) 0 else raw;
        return std.math.clamp(@floor(value + 0.5), if (nonnegative) 0 else @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32)));
    }
    fn append(self: Integer, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .literal => |value| try values.appendNumber(value, out, allocator),
            .calculation => |expression| try expression.serialize(out, allocator),
        }
    }
};

/// Counter Styles §§3.1/3.4/3.6/3.8; Values 4 §§5.2/10.12.
/// Three-browser probes q43/q44 (2026-10-27): bare integers clamp to
/// int32, but calculations preserve their unrounded, unclamped value.
/// The shared numeric parser owns all math syntax and simplification.
fn integer(allocator: Allocator, stream: *properties.Stream, nonnegative: bool, expressions: *std.ArrayList(*math.Expression)) Allocator.Error!?Integer {
    const token = stream.peek();
    if (token.token_type == .number and token.is_integer) {
        const value = token.numeric_value orelse return null;
        if (nonnegative and value < 0) return null;
        _ = stream.next();
        return .{ .literal = std.math.clamp(value, if (nonnegative) 0 else @as(f64, std.math.minInt(i32)), @as(f64, std.math.maxInt(i32))) };
    }
    if (!math.isFunction(token)) return null;
    const parsed = try properties.mathValue(.{ .allocator = allocator }, stream, .{
        .kind = .integer,
        .minimum = if (nonnegative) 0 else @as(f64, std.math.minInt(i32)),
        .maximum = std.math.maxInt(i32),
        .minimum_kind = if (nonnegative) .grammar else .representation,
        .maximum_kind = .representation,
    }) orelse return null;
    const expression = parsed.calculation;
    errdefer expression.unref();
    // Q44: all browsers reject tree-counting functions in this context.
    // This checks the existing expression; it never guesses a DOM tree.
    if (expression.needsTreeCounts()) {
        expression.unref();
        return null;
    }
    try expressions.append(allocator, expression);
    return .{ .calculation = expression };
}

pub fn parseDescriptor(allocator: Allocator, descriptor: Descriptor, input: []const u8) Allocator.Error!?Parsed {
    var stream = properties.Stream.init(input);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var expressions: std.ArrayList(*math.Expression) = .empty;
    defer {
        for (expressions.items) |expression| expression.unref();
        expressions.deinit(allocator);
    }
    var result: Parsed = .{ .text = undefined };
    switch (descriptor) {
        .system => {
            const token = stream.next();
            if (token.token_type != .ident) return null;
            var algorithm: ?Algorithm = null;
            inline for (@typeInfo(Algorithm).@"enum".field_names, @typeInfo(Algorithm).@"enum".field_values) |field_name, field_value| if (tokens.nameEql(token.value, field_name)) {
                algorithm = @enumFromInt(field_value);
            };
            result.algorithm = algorithm orelse return null;
            try out.appendSlice(allocator, @tagName(result.algorithm));
            if (result.algorithm == .extends) {
                const name = try counterName(allocator, stream.next(), false) orelse return null;
                defer allocator.free(name);
                try out.append(allocator, ' ');
                try out.appendSlice(allocator, name);
            } else if (result.algorithm == .fixed) {
                const value: Integer = if (stream.atEnd()) .{ .literal = 1 } else try integer(allocator, &stream, false, &expressions) orelse return null;
                try out.append(allocator, ' ');
                try value.append(&out, allocator);
            }
        },
        .symbols, .negative, .prefix, .suffix => {
            const limit: usize = switch (descriptor) {
                .negative => 2,
                .prefix, .suffix => 1,
                else => std.math.maxInt(usize),
            };
            while (!stream.atEnd() and result.count < limit) {
                const value = try symbol(allocator, &stream) orelse return null;
                defer allocator.free(value);
                if (result.count != 0) try out.append(allocator, ' ');
                try out.appendSlice(allocator, value);
                result.count += 1;
            }
            if (result.count == 0) return null;
        },
        .pad, .additive_symbols => {
            var previous = std.math.inf(f64);
            while (true) {
                var n = try integer(allocator, &stream, true, &expressions);
                const value = try symbol(allocator, &stream) orelse return null;
                defer allocator.free(value);
                if (n == null) n = try integer(allocator, &stream, true, &expressions);
                const weight = n orelse return null;
                if (descriptor == .additive_symbols) {
                    // Q44: descending order requires parse-time values.
                    // Unresolved ratios are therefore invalid in this slot.
                    const known = weight.comparable(true) orelse return null;
                    if (result.count != 0 and known >= previous) return null;
                    previous = known;
                }
                if (result.count != 0) try out.appendSlice(allocator, ", ");
                try weight.append(&out, allocator);
                try out.append(allocator, ' ');
                try out.appendSlice(allocator, value);
                result.count += 1;
                if (descriptor == .pad or stream.atEnd()) break;
                if (stream.next().token_type != .comma) return null;
            }
        },
        .range => {
            const first = stream.peek();
            if (first.token_type == .ident and tokens.nameEql(first.value, "auto")) {
                _ = stream.next();
                try out.appendSlice(allocator, "auto");
            } else while (true) {
                var bounds: [2]f64 = undefined;
                for (&bounds, 0..) |*bound, index| {
                    if (index != 0) try out.append(allocator, ' ');
                    const token = stream.peek();
                    if (token.token_type == .ident and tokens.nameEql(token.value, "infinite")) {
                        _ = stream.next();
                        bound.* = if (index == 0) -std.math.inf(f64) else std.math.inf(f64);
                        try out.appendSlice(allocator, "infinite");
                    } else {
                        const value = try integer(allocator, &stream, false, &expressions) orelse return null;
                        // Q44: lower <= upper needs values at parse time;
                        // a context-dependent bound cannot be validated.
                        bound.* = value.comparable(false) orelse return null;
                        try value.append(&out, allocator);
                    }
                }
                if (bounds[0] > bounds[1]) return null;
                if (stream.atEnd()) break;
                if (stream.next().token_type != .comma) return null;
                try out.appendSlice(allocator, ", ");
            }
        },
        .fallback, .speak_as => {
            const token = stream.next();
            var keyword: ?[]const u8 = null;
            if (descriptor == .speak_as and token.token_type == .ident) {
                for ([_][]const u8{ "auto", "bullets", "numbers", "words", "spell-out" }) |name| if (tokens.nameEql(token.value, name)) {
                    keyword = name;
                    break;
                };
            }
            if (keyword) |name| try out.appendSlice(allocator, name) else {
                const name = try counterName(allocator, token, false) orelse return null;
                defer allocator.free(name);
                try out.appendSlice(allocator, name);
            }
        },
    }
    if (!stream.atEnd()) return null;
    result.text = try out.toOwnedSlice(allocator);
    errdefer allocator.free(result.text);
    result.expressions = try expressions.toOwnedSlice(allocator);
    return result;
}
