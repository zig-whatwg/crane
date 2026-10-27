//! CSS Inline3 values that do not need layout metrics.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Number = @import("numeric_values.zig").Number;
const Components = @import("text_values.zig").Components;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Keyword = values.Keyword;
const Stream = properties.Stream;

fn keyword(stream: *Stream, allowed: []const Keyword) ?Keyword {
    const token = stream.peek();
    if (token.token_type != .ident) return null;
    for (allowed) |candidate| if (tokens.nameEql(token.value, candidate.name())) {
        _ = stream.next();
        return candidate;
    };
    return null;
}

fn numeric(options: properties.ParseOptions, stream: *Stream, grammar: math.Grammar, unitless_zero: bool) Allocator.Error!?Value {
    // Values4 §5: implementation integer limits clamp valid large literals;
    // grammar minima still reject negative/zero values when prohibited.
    if (grammar.kind == .integer and stream.peek().token_type == .number) {
        const token = stream.peek();
        const n = token.numeric_value orelse return null;
        if (!token.is_integer or n < grammar.minimum) return null;
        _ = stream.next();
        return .{ .integer = @intFromFloat(@min(n, @as(f64, std.math.maxInt(i32)))) };
    }
    const start = stream.*;
    const number = try Number.consume(options, stream, grammar, unitless_zero) orelse {
        stream.* = start;
        return null;
    };
    return switch (number) {
        .calculation => |expression| .{ .calculation = expression },
        .literal => |literal| switch (literal.unit) {
            .number => .{ .number = literal.value },
            .percent => .{ .length = .percent(literal.value) },
            else => .{ .length = .{ .value = literal.value, .unit = values.LengthUnit.fromString(literal.unit.name()).? } },
        },
    };
}

fn shift(options: properties.ParseOptions, stream: *Stream, quirky: bool) Allocator.Error!?Value {
    if (keyword(stream, &.{ .sub, .super, .top, .center, .bottom })) |k| return Value.kw(k);
    // Values4 AppendixC: only vertical-align admits a literal quirky length,
    // never baseline-shift and never a number inside a calculation.
    if (quirky and options.quirks and stream.peek().token_type == .number) {
        const token = stream.next();
        return Value.px(token.numeric_value orelse return null);
    }
    return numeric(options, stream, .{ .kind = .length_percentage }, true);
}

pub fn parse(options: properties.ParseOptions, property: properties.Longhand, stream: *Stream) Allocator.Error!?Value {
    switch (property) {
        .text_box_edge => {
            // Inline3 §5.2 prose and Firefox/Safari's shipped short forms
            // (CSSWG11460, Q17): a missing nonmatching side is text.
            if (keyword(stream, &.{ .auto, .alphabetic })) |k| return Value.kw(k);
            const over = keyword(stream, &.{ .text, .ideographic, .ideographic_ink, .cap, .ex }) orelse return null;
            const default_under: Keyword = if (over == .cap or over == .ex) .text else over;
            const under = keyword(stream, &.{ .text, .ideographic, .ideographic_ink, .alphabetic }) orelse default_under;
            if (under == default_under) return Value.kw(over);
            if (over == .text and under == .alphabetic) return Value.kw(.alphabetic);
            return .{ .text_values = try Components.create(options.allocator, property, &.{ Value.kw(over), Value.kw(under) }) };
        },
        .baseline_shift => {
            // Inline3 §4.2.3.1: legacy baseline is separate from the
            // shorthand's alignment baseline, and computes to 0px.
            if (keyword(stream, &.{.baseline})) |k| return Value.kw(k);
            return shift(options, stream, false);
        },
        .initial_letter => {
            // Inline3 §7.3; Blink InitialLetter::CSSValueFromComputedStyleInternal
            // keeps omitted/drop/raise at CSSOM (sole shipper, pinned WPT).
            if (keyword(stream, &.{.normal})) |k| return Value.kw(k);
            const prefix = keyword(stream, &.{ .drop, .raise });
            const size = try numeric(options, stream, .{ .kind = .number, .minimum = 1 }, false) orelse return null;
            defer size.release();
            var sink: ?Value = if (prefix) |k| Value.kw(k) else null;
            defer if (sink) |item| item.release();
            if (sink == null) {
                sink = if (keyword(stream, &.{ .drop, .raise })) |k| Value.kw(k) else try numeric(options, stream, .{ .kind = .integer, .minimum = 1, .maximum = std.math.maxInt(i32) }, false);
            }
            return .{ .text_values = try Components.create(options.allocator, property, if (sink) |item| &.{ size, item } else &.{size}) };
        },
        else => unreachable,
    }
}

const alignment = [_]Keyword{ .baseline, .text_bottom, .alphabetic, .ideographic, .middle, .central, .mathematical, .hanging, .text_top };

pub fn parseVerticalAlign(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // Inline3 §4.2; Firefox's shipped shorthand (Q11/Q12). The CSSOM
    // expansion order is alignment-baseline, baseline-shift, baseline-source.
    var items = [_]Value{ Value.kw(.baseline), Value.px(0), Value.kw(.auto) };
    defer for (items) |item| item.release();
    var seen = [_]bool{ false, false, false };
    var any = false;
    while (!stream.atEnd()) {
        if (!seen[2]) if (keyword(stream, &.{ .first, .last })) |k| {
            items[2] = Value.kw(k);
            seen[2] = true;
            any = true;
            continue;
        };
        if (!seen[0]) if (keyword(stream, &alignment)) |k| {
            items[0] = Value.kw(k);
            seen[0] = true;
            any = true;
            continue;
        };
        if (!seen[1]) if (try shift(options, stream, true)) |value| {
            items[1] = value;
            seen[1] = true;
            any = true;
            continue;
        };
        return false;
    }
    if (!any) return false;
    try out.ensureUnusedCapacity(options.allocator, 3);
    for (properties.Shorthand.vertical_align.longhands(), items) |property, value| {
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = property, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeVerticalAlign(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    // The canonical textual order differs from CSSOM longhand enumeration.
    const longhands = properties.Shorthand.vertical_align.longhands();
    var count: usize = 0;
    for ([_]usize{ 2, 0, 1 }) |i| {
        const property = longhands[i];
        const value = assigned[i].value;
        // Legacy SVG values cannot be represented by this shorthand.
        if (value.isKeyword(.text_before_edge) or value.isKeyword(.text_after_edge) or
            (property == .baseline_shift and value.isKeyword(.baseline))) return false;
        if (value.eql(property.info().initial)) continue;
        if (count != 0) try out.append(allocator, ' ');
        try properties.serializeValue(property, value, out, allocator);
        count += 1;
    }
    if (count == 0) try out.appendSlice(allocator, "baseline");
    return true;
}

pub fn parseTextBox(options: properties.ParseOptions, stream: *Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // Inline3 §6.1: normal resets both to their initial values. Otherwise
    // a missing trim is trim-both, while a missing edge remains auto.
    var trim: ?Keyword = null;
    var edge: ?Value = null;
    defer if (edge) |value| value.release();
    if (keyword(stream, &.{.normal}) != null) {
        if (!stream.atEnd()) return false;
        trim = .none;
    } else {
        var any = false;
        while (!stream.atEnd()) {
            if (trim == null) if (keyword(stream, &.{ .none, .trim_start, .trim_end, .trim_both })) |k| {
                trim = k;
                any = true;
                continue;
            };
            if (edge == null) if (try parse(options, .text_box_edge, stream)) |value| {
                edge = value;
                any = true;
                continue;
            };
            return false;
        }
        if (!any) return false;
    }
    const edge_value = edge orelse Value.kw(.auto);
    try out.ensureUnusedCapacity(options.allocator, 2);
    edge_value.retain();
    out.appendAssumeCapacity(.{ .longhand = .text_box_trim, .value = .{ .value = Value.kw(trim orelse .trim_both) } });
    out.appendAssumeCapacity(.{ .longhand = .text_box_edge, .value = .{ .value = edge_value } });
    return true;
}

pub fn serializeTextBox(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const trim = assigned[0].value.keyword;
    const edge = assigned[1].value;
    if (edge.isKeyword(.auto)) {
        try out.appendSlice(allocator, if (trim == .none) "normal" else trim.name());
    } else {
        if (trim != .trim_both) {
            try out.appendSlice(allocator, trim.name());
            try out.append(allocator, ' ');
        }
        try properties.serializeValue(.text_box_edge, edge, out, allocator);
    }
    return true;
}
