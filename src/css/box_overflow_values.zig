//! CSS Overflow 3 §§3.1–3.2,5.2 and Overflow 4 §§4–5.
//! Compound values own numeric trees; used layout geometry stays with the host.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const tokens = @import("tokenizer.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Keyword = values.Keyword;
const Stream = properties.Stream;

/// A pointer keeps Value's inline footprint unchanged. The numeric component
/// owns one reference, including when a max-lines calculation accompanies auto.
pub const Numeric = struct {
    allocator: Allocator,
    refs: std.atomic.Value(usize) = .init(1),
    kind: Kind,
    number: Number,
    pub const Kind = enum { clip_padding, clip_content, clip_border, max_lines_auto };

    fn create(allocator: Allocator, kind: Kind, number: Number) Allocator.Error!*Numeric {
        const self = try allocator.create(Numeric);
        self.* = .{ .allocator = allocator, .kind = kind, .number = number };
        return self;
    }
    pub fn ref(self: *Numeric) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Numeric) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.number.unref();
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Numeric, other: *const Numeric) bool {
        return self.kind == other.kind and self.number.eql(other.number);
    }
    pub fn compute(self: *const Numeric, allocator: Allocator, context: math.Context) Allocator.Error!*Numeric {
        const number = try self.number.compute(allocator, context);
        errdefer number.unref();
        return create(allocator, self.kind, number);
    }
    pub fn serialize(self: *const Numeric, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.kind == .max_lines_auto) {
            try self.number.serialize(out, allocator);
            return out.appendSlice(allocator, " auto");
        }
        // Overflow 3 §3.2: padding-box is the omitted reference box. A zero
        // offset may be omitted only if a non-default box supplies the value.
        if (self.kind != .clip_padding) {
            try out.appendSlice(allocator, if (self.kind == .clip_content) "content-box" else "border-box");
            if (self.number == .literal and self.number.literal.value == 0) return;
            try out.append(allocator, ' ');
        }
        try self.number.serialize(out, allocator);
    }
};

fn take(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (allowed) |candidate| {
        if (tokens.nameEql(token.value, candidate.name())) {
            _ = stream.next();
            return candidate;
        }
    }
    return null;
}

pub fn consume(options: properties.ParseOptions, longhand: properties.Longhand, stream: *Stream) Allocator.Error!?Value {
    return switch (longhand) {
        .overflow_x, .overflow_y, .overflow_block, .overflow_inline => consumeAxis(stream),
        .overflow_clip_margin => consumeClipMargin(options, stream),
        .scrollbar_gutter => consumeGutter(stream),
        .scroll_marker_group => consumeMarkers(stream),
        .max_lines => consumeMaxLines(options, stream),
        .block_ellipsis => consumeEdge(options, stream, &.{ .no_ellipsis, .ellipsis }),
        .text_overflow => consumeTextOverflow(options, stream),
        else => unreachable,
    };
}

fn consumeAxis(stream: *Stream) ?Value {
    // Q31/probe31: Chrome and Safari preserve specified overlay; every
    // shipping implementation converts it to auto at computed-value time.
    if (take(stream, &.{ .visible, .hidden, .clip, .scroll, .auto, .overlay })) |keyword| return Value.kw(keyword);
    return null;
}

fn takeClipBox(stream: *Stream) ?Numeric.Kind {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    inline for (.{ .{ "padding-box", Numeric.Kind.clip_padding }, .{ "content-box", Numeric.Kind.clip_content }, .{ "border-box", Numeric.Kind.clip_border } }) |entry| {
        if (tokens.nameEql(token.value, entry[0])) {
            _ = stream.next();
            return entry[1];
        }
    }
    return null;
}

fn consumeClipMargin(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    var box = takeClipBox(stream);
    const number = try Number.consume(options, stream, .{ .kind = .length }, true);
    errdefer if (number) |n| n.unref();
    if (box == null) box = takeClipBox(stream);
    if (box == null and number == null) return null;
    return .{ .box_numeric = try Numeric.create(options.allocator, box orelse .clip_padding, number orelse .{ .literal = .{ .value = 0, .unit = .px } }) };
}

fn consumeGutter(stream: *Stream) ?Value {
    // Overflow 3 §5.2: auto | stable && both-edges?. The second keyword
    // cannot appear alone; canonical order always puts stable first.
    if (take(stream, &.{.auto})) |single| return Value.kw(single);
    const first = take(stream, &.{ .stable, .both_edges }) orelse return null;
    const second = take(stream, &.{ .stable, .both_edges });
    if (first == .stable and second == null) return Value.kw(.stable);
    if (second == null or second == first) return null;
    return .{ .box_keywords = .{ .first = .stable, .second = .both_edges } };
}

fn consumeMarkers(stream: *Stream) ?Value {
    // Overflow 5 §3.1.3, row125 Q12: shipping/pinned ordered grammar.
    // The newer mode-first/mode-only proposal remains held by that ruling.
    if (take(stream, &.{.none})) |single| return Value.kw(single);
    const placement = take(stream, &.{ .before, .after }) orelse return null;
    const mode = take(stream, &.{ .links, .tabs });
    return .{ .box_keywords = .{ .first = placement, .second = mode } };
}

fn consumeMaxLines(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    // Overflow 4 §5.2: auto || <integer [1,infinity]>. Consume the whole
    // component together, so a shorthand cannot split it with an ellipsis.
    var automatic = take(stream, &.{.auto}) != null;
    const integer = try @import("box_values.zig").consumeInteger(options, stream, 1);
    errdefer if (integer) |v| v.release();
    if (!automatic) automatic = take(stream, &.{.auto}) != null;
    const value = integer orelse return if (automatic) Value.kw(.auto) else null;
    if (!automatic) return value;
    const number: Number = switch (value) {
        .integer => |n| Number.scalar(@floatFromInt(n)),
        .calculation => |expression| .{ .calculation = expression },
        else => unreachable,
    };
    return .{ .box_numeric = try Numeric.create(options.allocator, .max_lines_auto, number) };
}

fn consumeEdge(options: properties.ParseOptions, stream: *Stream, keywords: []const Keyword) Allocator.Error!?Value {
    if (take(stream, keywords)) |keyword| return Value.kw(keyword);
    const token = stream.peek();
    if (token.token_type != .string) return null;
    const decoded = try tokens.decode(options.allocator, token.stringContents());
    defer options.allocator.free(decoded);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(options.allocator);
    try values.appendString(decoded, &out, options.allocator);
    const text = try values.SharedText.create(options.allocator, out.items);
    _ = stream.next();
    return .{ .text = text };
}

fn consumeTextOverflow(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    // Overflow 4 §4.1: one component applies at the inline end, two at the
    // physical left/right edges. Equal pairs must therefore NOT collapse.
    const first = try consumeEdge(options, stream, &.{ .clip, .ellipsis }) orelse return null;
    defer first.release();
    const second = try consumeEdge(options, stream, &.{ .clip, .ellipsis }) orelse {
        first.retain();
        return first;
    };
    defer second.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(options.allocator);
    try properties.serializeValue(.text_overflow, first, &out, options.allocator);
    try out.append(options.allocator, ' ');
    try properties.serializeValue(.text_overflow, second, &out, options.allocator);
    return .{ .text = try values.SharedText.create(options.allocator, out.items) };
}

pub fn parseClamp(options: properties.ParseOptions, legacy: bool, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    var maximum: ?Value = null;
    var ellipsis: ?Value = null;
    var continuation: Keyword = .normal;
    defer {
        if (maximum) |v| v.release();
        if (ellipsis) |v| v.release();
    }
    // Overflow 4 §§5.1–5.1.1: reset all three constituents. Q65 deliberately
    // departs from today's §5.1.1 "unconditionally sets block-ellipsis to
    // ellipsis" text for legacy none, pending CSSWG #14673 (OPEN, Async
    // Resolution: Proposed). The matching serializer below uses the same
    // initial tuple; positive integers retain ellipsis/-webkit-legacy.
    // Overflow editor Florian Rivoal agrees with that proposed correction:
    // https://github.com/w3c/csswg-drafts/issues/14673#issuecomment-6420092047
    // Chromium's flagged implementation is the design reference (not copied):
    // https://github.com/chromium/chromium/blob/3fefddfc43edcf3a5d62ed60f15cb592f299ab18/third_party/blink/renderer/core/css/properties/shorthands/shorthands_custom.cc
    // https://github.com/chromium/chromium/blob/3fefddfc43edcf3a5d62ed60f15cb592f299ab18/third_party/blink/renderer/core/css/style_property_serializer.cc
    // Integrator probe, 2026-10-27, tmp/cssbox/probe-q65/: Chrome 156,
    // Firefox 158 and Safari 27 read initial and none as "none"; their shipped
    // standalone property does not expose the newer shorthand constituents.
    if (take(stream, &.{.none}) != null) {
        maximum = Value.kw(.auto);
        ellipsis = Value.kw(.no_ellipsis);
    } else if (legacy) {
        maximum = try @import("box_values.zig").consumeInteger(options, stream, 1) orelse return false;
        ellipsis = Value.kw(.ellipsis);
        continuation = ._webkit_legacy;
    } else {
        while (!stream.atEnd()) {
            if (maximum == null) {
                var trial = stream.*;
                maximum = try consumeMaxLines(options, &trial);
                if (maximum != null) {
                    stream.* = trial;
                    continue;
                }
            }
            if (ellipsis == null) {
                var trial = stream.*;
                ellipsis = try consumeEdge(options, &trial, &.{ .no_ellipsis, .ellipsis });
                if (ellipsis != null) {
                    stream.* = trial;
                    continue;
                }
            }
            break;
        }
        if (maximum == null and ellipsis == null) return false;
        maximum = maximum orelse Value.kw(.auto);
        ellipsis = ellipsis orelse Value.kw(.ellipsis);
        continuation = take(stream, &.{._webkit_legacy}) orelse .collapse;
    }
    if (!stream.atEnd()) return false;
    const components = [_]Value{ maximum.?, ellipsis.?, Value.kw(continuation) };
    try out.ensureUnusedCapacity(options.allocator, components.len);
    for (properties.Shorthand.line_clamp.longhands(), components) |longhand, value| {
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeClamp(legacy: bool, assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const maximum = assigned[0].value;
    const ellipsis = assigned[1].value;
    const continuation = assigned[2].value;
    if (legacy) {
        // Q65 / CSSWG #14673: match parseClamp's documented temporary
        // §5.1.1 departure, so this spelling reproduces every constituent.
        if (maximum.isKeyword(.auto) and ellipsis.isKeyword(.no_ellipsis) and continuation.isKeyword(.normal)) {
            try out.appendSlice(allocator, "none");
            return true;
        }
        if (!ellipsis.isKeyword(.ellipsis)) return false;
        if (!continuation.isKeyword(._webkit_legacy) or (maximum != .integer and maximum != .calculation)) return false;
        try properties.serializeValue(.max_lines, maximum, out, allocator);
        return true;
    }
    if (continuation.isKeyword(.normal)) {
        if (!maximum.isKeyword(.auto) or !ellipsis.isKeyword(.no_ellipsis)) return false;
        try out.appendSlice(allocator, "none");
        return true;
    }
    if (!continuation.isKeyword(.collapse) and !continuation.isKeyword(._webkit_legacy)) return false;
    // Canonical max-lines is always present; omitted ellipsis is ellipsis.
    try properties.serializeValue(.max_lines, maximum, out, allocator);
    if (!ellipsis.isKeyword(.ellipsis)) {
        try out.append(allocator, ' ');
        try properties.serializeValue(.block_ellipsis, ellipsis, out, allocator);
    }
    if (continuation.isKeyword(._webkit_legacy)) try out.appendSlice(allocator, " -webkit-legacy");
    return true;
}
