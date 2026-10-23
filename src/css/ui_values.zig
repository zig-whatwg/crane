//! CSS UI 4 §§3, 5.2: owned caret pairs and unordered shorthand components.
//! Design reference: Blink CaretColor::ParseSingleValue and
//! StyleBuilderConverter::ConvertStyleCaretColor, independently implemented.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Stream = properties.Stream;

/// Single caret values use Value.keyword/Value.color directly. Only the
/// two-value production allocates, and it retains both component values.
pub const CaretPair = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    first: Value,
    second: Value,

    fn create(allocator: Allocator, first: Value, second: Value) Allocator.Error!*CaretPair {
        const self = try allocator.create(CaretPair);
        self.* = .{ .allocator = allocator, .first = first, .second = second };
        first.retain();
        second.retain();
        return self;
    }
    pub fn ref(self: *CaretPair) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *CaretPair) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.first.release();
        self.second.release();
        self.allocator.destroy(self);
    }
    pub fn eql(a: *const CaretPair, b: *const CaretPair) bool {
        return a == b or (a.first.eql(b.first) and a.second.eql(b.second));
    }
    pub fn needsUnavailableMetrics(self: *const CaretPair) bool {
        return self.first.needsUnavailableMetrics(false) or self.second.needsUnavailableMetrics(false);
    }
    pub fn needsTreeCounts(self: *const CaretPair) bool {
        return self.first.needsTreeCounts() or self.second.needsTreeCounts();
    }

    pub fn needsRandomBase(self: *const CaretPair) bool {
        return self.first.needsRandomBase() or self.second.needsRandomBase();
    }
    pub fn compute(self: *CaretPair, allocator: Allocator, context: values.Color.Context) Allocator.Error!*CaretPair {
        const first = try computeColor(self.first, allocator, context);
        defer first.release();
        const second = try computeColor(self.second, allocator, context);
        defer second.release();
        if (first.eql(self.first) and second.eql(self.second)) {
            self.ref();
            return self;
        }
        return create(allocator, first, second);
    }
    pub fn serialize(self: *const CaretPair, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try properties.serializeValue(.caret_color, self.first, out, allocator);
        try out.append(allocator, ' ');
        try properties.serializeValue(.caret_color, self.second, out, allocator);
    }
};

/// UI 4 §5.2.1, Q59: auto and currentcolor remain distinct computed values.
/// Named/system colors compute now; receiving-element currentcolor is used
/// only by resolved serialization below, so inheritance does not freeze RGB.
pub fn computeColor(value: Value, allocator: Allocator, context: values.Color.Context) Allocator.Error!Value {
    if (value == .color) return .{ .color = try value.color.resolveComputed(allocator, context) };
    value.retain();
    return value;
}

pub fn consumeAutoColor(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const token = stream.peek();
    if (token.token_type == .ident and tokens.nameEql(token.value, "auto")) {
        _ = stream.next();
        return .kw(.auto);
    }
    // The Quirks hashless-hex rule's property allowlist excludes UI colors.
    var color_options = options;
    color_options.quirks = false;
    return properties.parseLonghand(color_options, .color, stream);
}

pub fn consumeCaretColor(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    const first = try consumeAutoColor(options, stream) orelse return null;
    errdefer first.release();
    const saved = stream.*;
    const second = try consumeAutoColor(options, stream) orelse {
        stream.* = saved;
        return first;
    };
    defer second.release();
    const pair = try CaretPair.create(options.allocator, first, second);
    first.release();
    return .{ .caret_pair = pair };
}

/// Q46/Q59: getComputedStyle exposes the resolved first color. An omitted
/// second color is auto, and an explicit second auto is omitted here only.
pub fn serializeCaretResolved(value: Value, context: values.Color.Context, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (value == .caret_pair) {
        try serializeAutoColorResolved(value.caret_pair.first, context, out, allocator);
        if (!value.caret_pair.second.isKeyword(.auto)) {
            try out.append(allocator, ' ');
            try serializeAutoColorResolved(value.caret_pair.second, context, out, allocator);
        }
    } else try serializeAutoColorResolved(value, context, out, allocator);
}

fn serializeAutoColorResolved(value: Value, context: values.Color.Context, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const color: values.Color = if (value == .color) value.color else .current;
    const resolved = try color.resolveComputed(allocator, context);
    defer resolved.release();
    try resolved.serializeComputed(out, allocator);
}

/// UI 4 §3.1, CSS Values ||: each longhand is consumed once, in
/// grammar order when two can match. Missing components take their initial
/// values. The caller owns every returned component, including on expansion.
pub fn consumeGroup(options: properties.ParseOptions, stream: *Stream, comptime longhands: [3]properties.Longhand) Allocator.Error!?[3]Value {
    var result: [3]Value = undefined;
    inline for (longhands, 0..) |l, i| {
        result[i] = l.info().initial;
        result[i].retain();
    }
    var transferred = false;
    defer if (!transferred) for (result) |v| v.release();
    var seen = [_]bool{false} ** 3;
    var any = false;
    while (!stream.atEnd()) {
        var matched = false;
        inline for (longhands, 0..) |l, i| {
            if (!matched and !seen[i]) {
                const saved = stream.*;
                if (try properties.parseLonghand(options, l, stream)) |value| {
                    result[i].release();
                    result[i] = value;
                    seen[i] = true;
                    matched = true;
                } else stream.* = saved;
            }
        }
        if (!matched) return null;
        any = true;
    }
    if (!any) return null;
    transferred = true;
    return result;
}
