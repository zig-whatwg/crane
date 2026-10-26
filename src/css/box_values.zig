//! Box-property grammars independent of layout geometry.
//! CSS Flexbox 2 §§5–6.1 and CSS Display 4 §3.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Keyword = values.Keyword;
const Value = values.Value;
const Stream = properties.Stream;

/// A canonical keyword pair needs no retained storage or computation context.
/// A lone keyword uses Value.keyword instead.
pub const KeywordPair = struct {
    first: Keyword,
    second: ?Keyword = null,

    pub fn eql(a: KeywordPair, b: KeywordPair) bool {
        return a.first == b.first and a.second == b.second;
    }

    pub fn serialize(self: KeywordPair, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, self.first.name());
        if (self.second) |second| {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, second.name());
        }
    }
};

fn keyword(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (allowed) |candidate| {
        if (tokenizer.nameEql(token.value, candidate.name())) {
            _ = stream.next();
            return candidate;
        }
    }
    return null;
}

pub fn consume(options: properties.ParseOptions, longhand: properties.Longhand, stream: *Stream) Allocator.Error!?Value {
    return switch (longhand) {
        .flex_wrap => consumeWrap(stream),
        .flex_line_count => consumeInteger(options, stream, 1),
        .order => consumeInteger(options, stream, null),
        else => unreachable,
    };
}

fn consumeWrap(stream: *Stream) ?Value {
    // Flexbox 2 §5.2: nowrap | [wrap | wrap-reverse] || balance.
    // Chrome ships the newer balance grammar; other engines lag (row125 D3).
    if (keyword(stream, &.{.nowrap})) |single| return Value.kw(single);
    var direction: ?Keyword = null;
    var balanced = false;
    for (0..2) |_| {
        const part = keyword(stream, &.{ .wrap, .wrap_reverse, .balance }) orelse break;
        if (part == .balance) {
            if (balanced) return null;
            balanced = true;
        } else {
            if (direction != null) return null;
            direction = part;
        }
    }
    if (balanced) {
        // The omitted wrapping direction is wrap, including in CSSOM.
        if (direction == .wrap_reverse) return .{ .box_keywords = .{ .first = .wrap_reverse, .second = .balance } };
        return Value.kw(.balance);
    }
    return Value.kw(direction orelse return null);
}

fn consumeInteger(options: properties.ParseOptions, stream: *Stream, minimum: ?i32) Allocator.Error!?Value {
    // Values 4 §10.12: a calculation is rounded and range-clamped only
    // after computation. Pin representation bounds before the scalar cast.
    const low: f64 = @floatFromInt(minimum orelse std.math.minInt(i32));
    const high: f64 = @floatFromInt(std.math.maxInt(i32));
    if (math.isFunction(stream.peek()))
        return properties.mathValue(options, stream, .{ .kind = .integer, .minimum = low, .maximum = high });
    const token = stream.peek();
    if (token.token_type != .number or !token.is_integer) return null;
    const number = token.numeric_value orelse return null;
    if (minimum != null and number < low) return null;
    _ = stream.next();
    // Values 4 §5: out-of-representation integers clamp, rather than
    // invalidating an otherwise valid authored integer.
    return .{ .integer = @intFromFloat(std.math.clamp(number, low, high)) };
}

pub fn parseFlexFlow(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // Flexbox 2 §5.3: <flex-direction> || <flex-wrap>, each at most once.
    // Probe 1026n (2026-10-26): Chrome, the balance shipper, rejects a
    // direction between the two wrap keywords. Consume the pair together.
    var direction: ?Value = null;
    var wrapping: ?Value = null;
    while (!stream.atEnd()) {
        if (direction == null) {
            direction = try properties.parseLonghand(options, .flex_direction, stream);
            if (direction != null) continue;
        }
        if (wrapping == null) {
            wrapping = consumeWrap(stream);
            if (wrapping != null) continue;
        }
        return false;
    }
    if (direction == null and wrapping == null) return false;
    // Both components are inline keyword values, with no references to own.
    try out.ensureUnusedCapacity(options.allocator, 2);
    out.appendAssumeCapacity(.{ .longhand = .flex_direction, .value = .{ .value = direction orelse Value.kw(.row) } });
    out.appendAssumeCapacity(.{ .longhand = .flex_wrap, .value = .{ .value = wrapping orelse Value.kw(.nowrap) } });
    return true;
}

pub fn serializeFlexFlow(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    // CSSOM's shortest form also applies to computed shorthand readback:
    // Firefox + Safari agree; Chrome alone keeps initial components
    // (probe 1026n, 2026-10-26; row125 Q27). No newer spec split is involved.
    const direction = assigned[0].value;
    const wrapping = assigned[1].value;
    const write_direction = !direction.isKeyword(.row) or wrapping.isKeyword(.nowrap);
    const write_wrap = !wrapping.isKeyword(.nowrap);
    if (write_direction) try properties.serializeValue(.flex_direction, direction, out, allocator);
    if (write_wrap) {
        if (write_direction) try out.append(allocator, ' ');
        try properties.serializeValue(.flex_wrap, wrapping, out, allocator);
    }
    return true;
}
