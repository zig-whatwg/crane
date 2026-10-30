//! CSS Transforms 1 §7 and Transforms 2 §12: shared transform-function grammar.
//! Owns typed arguments, without matrix projection or a layout dependency.
const std = @import("std");
const properties = @import("properties.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;

pub const Kind = enum {
    matrix,
    matrix3d,
    translate,
    translateX,
    translateY,
    translateZ,
    translate3d,
    scale,
    scaleX,
    scaleY,
    scaleZ,
    scale3d,
    rotate,
    rotateX,
    rotateY,
    rotateZ,
    rotate3d,
    skew,
    skewX,
    skewY,
    perspective,

    fn parse(raw: []const u8) ?Kind {
        inline for (@typeInfo(Kind).@"enum".fields) |field| {
            if (tokens.nameEql(raw, field.name)) return @enumFromInt(field.value);
        }
        return null;
    }

    fn arity(self: Kind) struct { min: usize, max: usize } {
        return switch (self) {
            .matrix => .{ .min = 6, .max = 6 },
            .matrix3d => .{ .min = 16, .max = 16 },
            .translate, .scale, .skew => .{ .min = 1, .max = 2 },
            .translate3d, .scale3d => .{ .min = 3, .max = 3 },
            .rotate3d => .{ .min = 4, .max = 4 },
            else => .{ .min = 1, .max = 1 },
        };
    }

    fn grammar(self: Kind, index: usize) math.Grammar {
        return switch (self) {
            .matrix, .matrix3d => .{ .kind = .number },
            .translate, .translateX, .translateY => .{ .kind = .length_percentage },
            .translateZ => .{ .kind = .length },
            .translate3d => .{ .kind = if (index == 2) .length else .length_percentage },
            .scale, .scaleX, .scaleY, .scaleZ, .scale3d => .{ .kind = .number_percentage },
            .rotate, .rotateX, .rotateY, .rotateZ, .skew, .skewX, .skewY => .{ .kind = .angle },
            .rotate3d => .{ .kind = if (index == 3) .angle else .number },
            .perspective => .{ .kind = .length, .minimum = 0 },
        };
    }
};

/// Owns each argument; an empty argument slice denotes perspective(none).
pub const Function = struct {
    allocator: Allocator,
    kind: Kind,
    arguments: []Number,
    computed: bool = false,

    pub fn deinit(self: *Function) void {
        for (self.arguments) |argument| argument.unref();
        self.allocator.free(self.arguments);
        self.* = undefined;
    }

    /// P&V §2.4: compute typed arguments, preserving translate percentages.
    pub fn compute(self: Function, allocator: Allocator, context: math.Context) Allocator.Error!Function {
        const arguments = try allocator.alloc(Number, self.arguments.len);
        errdefer allocator.free(arguments);
        var count: usize = 0;
        errdefer for (arguments[0..count]) |argument| argument.unref();
        var argument_context = context;
        argument_context.percentage_basis = null;
        for (self.arguments, arguments) |argument, *destination| {
            destination.* = try argument.compute(allocator, argument_context);
            count += 1;
        }
        return .{ .allocator = allocator, .kind = self.kind, .arguments = arguments, .computed = true };
    }

    pub fn serialize(self: Function, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, @tagName(self.kind));
        try out.append(allocator, '(');
        if (self.arguments.len == 0) try out.appendSlice(allocator, "none");
        // Transforms 1 §3.1, current-browser computed serialization (Q11).
        // Specified values retain authored optional arguments. A percentage
        // zero is not the default translation length and must stay visible.
        var count = self.arguments.len;
        if (self.computed and count == 2) {
            const second = self.arguments[1];
            const redundant = switch (self.kind) {
                .scale => self.arguments[0].eql(second),
                .translate => second == .literal and second.literal.unit == .px and second.literal.value == 0,
                .skew => second == .literal and second.literal.unit == .deg and second.literal.value == 0,
                else => false,
            };
            if (redundant) count = 1;
        }
        for (self.arguments[0..count], 0..) |argument, i| {
            if (i != 0) try out.appendSlice(allocator, ", ");
            try argument.serialize(out, allocator);
        }
        try out.append(allocator, ')');
    }
};

/// Consume one complete function. Failure leaves the stream unchanged;
/// success leaves following transform functions for the containing grammar.
pub fn consume(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Function {
    return consumeFunction(options, stream, false);
}

/// Compat's legacy transform alias differs only in perspective's length.
/// Registered syntax and the canonical property keep the strict entry above.
pub fn consumeWithLegacyPerspective(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Function {
    return consumeFunction(options, stream, true);
}

/// Compat §3.4 / row125 Q19: convert only numbers known before style
/// computation. Both legacy perspective callers use this single conversion.
pub fn consumeLegacyPerspectiveLength(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Number {
    var trial = stream.*;
    if (try Number.consume(options, &trial, .{ .kind = .length, .minimum = 0 }, true)) |length| {
        stream.* = trial;
        return length;
    }
    trial = stream.*;
    const number = try Number.consume(options, &trial, .{ .kind = .number, .minimum = 0 }, false) orelse return null;
    defer number.unref();
    const known = number.known() orelse return null;
    if (known.unit != .number) return null;
    const value = if (std.math.isNan(known.value) or known.value < 0) 0 else known.value;
    stream.* = trial;
    return .{ .literal = .{ .value = value, .unit = .px } };
}

fn consumeFunction(options: properties.ParseOptions, stream: *properties.Stream, legacy_perspective: bool) Allocator.Error!?Function {
    var trial = stream.*;
    const token = trial.next();
    if (token.token_type != .function) return null;
    const kind = Kind.parse(token.value) orelse return null;
    if (trial.next().token_type != .left_paren) return null;
    if (kind == .perspective and trial.peek().isIdent("none")) {
        _ = trial.next();
        if (!close(&trial)) return null;
        stream.* = trial;
        return .{ .allocator = options.allocator, .kind = kind, .arguments = &.{} };
    }

    var arguments: [16]Number = undefined;
    var count: usize = 0;
    defer for (arguments[0..count]) |argument| argument.unref();
    const arity = kind.arity();
    while (count < arity.max) {
        const grammar = kind.grammar(count);
        // Transforms 1 §7: unitless zero is also admitted for <angle>.
        const next = trial.peek();
        var number = if (legacy_perspective and kind == .perspective)
            try consumeLegacyPerspectiveLength(options, &trial) orelse return null
        else if (grammar.kind == .angle and next.token_type == .number and next.numeric_value.? == 0) blk: {
            _ = trial.next();
            break :blk Number{ .literal = .{ .value = 0, .unit = .deg } };
        } else try Number.consume(options, &trial, grammar, true) orelse return null;
        // Transforms 2: scale percentages represent scalar factors.
        if (grammar.kind == .number_percentage and number == .literal and number.literal.unit == .percent)
            number = Number.scalar(number.literal.value / 100);
        arguments[count] = number;
        count += 1;
        if (trial.peek().token_type != .comma) break;
        _ = trial.next();
        if (count == arity.max) return null;
    }
    if (count < arity.min or !close(&trial)) return null;
    const owned = try options.allocator.dupe(Number, arguments[0..count]);
    count = 0; // References move into the returned function.
    stream.* = trial;
    return .{ .allocator = options.allocator, .kind = kind, .arguments = owned };
}

fn close(stream: *properties.Stream) bool {
    // CSS Syntax §5.5.10: EOF closes an open function.
    const token = stream.next().token_type;
    return token == .right_paren or token == .eof;
}
