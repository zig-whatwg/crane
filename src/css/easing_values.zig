//! CSS Easing 2 §2: typed easing values, independent of animation execution.
//! Blink ConsumeSteps/ConsumeCubicBezier/ConsumeLinearStop supply the design
//! for owning numeric arguments; Q41/Q61/Q62 select the shipping behavior.
const std = @import("std");
const math = @import("math_values.zig");
const numbers = @import("numeric_values.zig");
const properties = @import("properties.zig");
const tokens = @import("tokenizer.zig");
const values = @import("style_values.zig");
const Allocator = std.mem.Allocator;
const Number = numbers.Number;
const Stream = properties.Stream;
const Error = Allocator.Error || error{Invalid};

pub const Easing = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    kind: Kind,
    keyword: []const u8 = "",
    jump: Jump = .end,
    terms: std.ArrayList(Number) = .empty,
    stops: std.ArrayList(Stop) = .empty,
    expanded: bool = false,

    const Kind = enum { keyword, cubic, steps, linear };
    const Stop = struct { output: usize, first: ?usize = null, second: ?usize = null };
    const Jump = enum {
        start,
        end,
        jump_start,
        jump_end,
        jump_none,
        jump_both,

        fn name(self: Jump) []const u8 {
            return switch (self) {
                .start => "start",
                .end => "end",
                .jump_start => "jump-start",
                .jump_end => "jump-end",
                .jump_none => "jump-none",
                .jump_both => "jump-both",
            };
        }
        fn parse(token: tokens.Token) ?Jump {
            if (token.token_type != .ident) return null;
            inline for (@typeInfo(Jump).@"enum".field_values) |field_value| {
                const value: Jump = @enumFromInt(field_value);
                if (tokens.nameEql(token.value, value.name())) return value;
            }
            return null;
        }
    };

    fn create(allocator: Allocator, kind: Kind) Allocator.Error!*Easing {
        const self = try allocator.create(Easing);
        self.* = .{ .allocator = allocator, .kind = kind };
        return self;
    }
    pub fn ref(self: *Easing) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Easing) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.terms.items) |term| term.unref();
        self.terms.deinit(self.allocator);
        self.stops.deinit(self.allocator);
        self.allocator.destroy(self);
    }
    pub fn eql(a: *const Easing, b: *const Easing) bool {
        if (a == b) return true;
        if (a.kind != b.kind or a.jump != b.jump or a.expanded != b.expanded or
            !std.mem.eql(u8, a.keyword, b.keyword) or a.terms.items.len != b.terms.items.len or
            a.stops.items.len != b.stops.items.len) return false;
        for (a.terms.items, b.terms.items) |x, y| if (!x.eql(y)) return false;
        for (a.stops.items, b.stops.items) |x, y| if (!std.meta.eql(x, y)) return false;
        return true;
    }
    pub fn needsUnavailableMetrics(self: *const Easing) bool {
        for (self.terms.items) |term| if (term.needsUnavailableMetrics(false)) return true;
        return false;
    }
    pub fn needsTreeCounts(self: *const Easing) bool {
        for (self.terms.items) |term| if (term.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Easing) bool {
        for (self.terms.items) |term| if (term.needsRandomBase()) return true;
        return false;
    }
    fn append(self: *Easing, term: Number) Allocator.Error!usize {
        errdefer term.unref();
        const index = self.terms.items.len;
        try self.terms.append(self.allocator, term);
        return index;
    }
    fn take(self: *Easing, stream: *Stream, grammar: math.Grammar) Error!usize {
        const term = try Number.consume(.{ .allocator = self.allocator }, stream, grammar, false) orelse return error.Invalid;
        return self.append(term);
    }
    fn require(stream: *Stream, expected: tokens.TokenType) error{Invalid}!void {
        const actual = stream.next().token_type;
        // CSS Syntax closes open function blocks at end of input.
        if (actual != expected and !(expected == .right_paren and actual == .eof)) return error.Invalid;
    }

    pub fn consume(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?*Easing {
        const start = stream.*;
        return parse(options.allocator, stream) catch |err| switch (err) {
            error.Invalid => {
                stream.* = start;
                return null;
            },
            error.OutOfMemory => return error.OutOfMemory,
        };
    }
    fn parse(allocator: Allocator, stream: *Stream) Error!*Easing {
        const token = stream.next();
        if (token.token_type == .ident) {
            inline for (.{ "linear", "ease", "ease-in", "ease-out", "ease-in-out" }) |name| {
                if (tokens.nameEql(token.value, name)) {
                    const self = try create(allocator, .keyword);
                    self.keyword = name;
                    return self;
                }
            }
            if (tokens.nameEql(token.value, "step-start") or tokens.nameEql(token.value, "step-end")) {
                const self = try create(allocator, .steps);
                errdefer self.unref();
                _ = try self.append(Number.scalar(1));
                self.jump = if (tokens.nameEql(token.value, "step-start")) .start else .end;
                return self;
            }
            return error.Invalid;
        }
        if (token.token_type != .function) return error.Invalid;
        const kind: Kind = if (tokens.nameEql(token.value, "cubic-bezier")) .cubic else if (tokens.nameEql(token.value, "steps")) .steps else if (tokens.nameEql(token.value, "linear")) .linear else return error.Invalid;
        try require(stream, .left_paren);
        const self = try create(allocator, kind);
        errdefer self.unref();
        switch (kind) {
            .keyword => unreachable,
            .cubic => {
                for (0..4) |i| {
                    const index = try self.take(stream, .{ .kind = .number });
                    // Q62: C/F reject element-dependent arguments; Blink's
                    // GetValueIfKnown TODO is crbug.com/407420298.
                    const known = self.terms.items[index].known() orelse return error.Invalid;
                    // Q61: known calculated x values outside [0,1] reject,
                    // matching C/F. This does not alter the shared math AST.
                    if ((i == 0 or i == 2) and (known.value < 0 or known.value > 1)) return error.Invalid;
                    if (i < 3) try require(stream, .comma);
                }
                try require(stream, .right_paren);
            },
            .steps => {
                const index = try self.take(stream, .{ .kind = .integer, .minimum = 1 });
                if (stream.peek().token_type == .comma) {
                    _ = stream.next();
                    self.jump = Jump.parse(stream.next()) orelse return error.Invalid;
                }
                try require(stream, .right_paren);
                if (self.terms.items[index].known()) |known| {
                    // Q61: NaN rejects in C/F. The jump-none constraint is
                    // checked before integer rounding; other calc counts
                    // clamp at computation, as C/S do.
                    if (std.math.isNan(known.value) or (self.jump == .jump_none and known.value < 2)) return error.Invalid;
                }
            },
            .linear => {
                var nonfinite = false;
                while (true) {
                    var stop = Stop{ .output = undefined };
                    const saved = stream.*;
                    if (try Number.consume(.{ .allocator = allocator }, stream, .{ .kind = .number }, false)) |output| {
                        stop.output = try self.append(output);
                        if (try Number.consume(.{ .allocator = allocator }, stream, .{ .kind = .percentage }, false)) |input| {
                            stop.first = try self.append(input);
                            if (try Number.consume(.{ .allocator = allocator }, stream, .{ .kind = .percentage }, false)) |second| stop.second = try self.append(second);
                        }
                    } else {
                        stream.* = saved;
                        stop.first = try self.take(stream, .{ .kind = .percentage });
                        if (try Number.consume(.{ .allocator = allocator }, stream, .{ .kind = .percentage }, false)) |second| stop.second = try self.append(second);
                        stop.output = try self.take(stream, .{ .kind = .number });
                    }
                    for ([_]?usize{ stop.output, stop.first, stop.second }) |maybe_index| if (maybe_index) |index| {
                        // Q70, integrator-probes-1022f: C/F reject unknown
                        // output AND input components; Safari alone accepts.
                        const known = self.terms.items[index].known() orelse return error.Invalid;
                        if (!std.math.isFinite(known.value)) nonfinite = true;
                    };
                    try self.stops.append(allocator, stop);
                    const separator = stream.next().token_type;
                    if (separator == .right_paren or separator == .eof) break;
                    if (separator != .comma) return error.Invalid;
                }
                // Q41: all three still reject a single typed stop, even
                // when its two percentages could expand to two points.
                if (self.stops.items.len < 2) return error.Invalid;
                if (nonfinite) {
                    // Q41: linear's owning boundary eagerly censors NaN and
                    // fixes positions in C/F. Preserve the general AST.
                    const fixed = try self.compute(allocator, .{});
                    self.unref();
                    return fixed;
                }
            },
        }
        return self;
    }

    pub fn compute(self: *Easing, allocator: Allocator, context: math.Context) Allocator.Error!*Easing {
        if (self.kind == .keyword) {
            self.ref();
            return self;
        }
        const result = try create(allocator, self.kind);
        errdefer result.unref();
        result.jump = self.jump;
        for (self.terms.items) |term| _ = try result.append(try term.compute(allocator, context));
        try result.stops.appendSlice(allocator, self.stops.items);
        if (result.kind == .steps) {
            if (result.terms.items[0].known()) |known| {
                // Q61/D63: Blink MapAnimationTimingFunction also clamps a
                // late jump-none count to two; the AST stays immutable.
                const n = @max(@floor(known.value + 0.5), if (self.jump == .jump_none) @as(f64, 2) else 1);
                result.terms.items[0].unref();
                result.terms.items[0] = Number.scalar(n);
            }
        } else if (result.kind == .linear) try result.expand();
        return result;
    }

    /// Easing 2 §2.1 canonicalization steps 1–4, at COMPUTED time by
    /// unanimous browsers (Q41). Specified omitted/double positions survive.
    fn expand(self: *Easing) Allocator.Error!void {
        for (self.terms.items) |term| if (term.known() == null) return;
        var points: std.ArrayList(Stop) = .empty;
        defer points.deinit(self.allocator);
        for (self.stops.items) |stop| {
            try points.append(self.allocator, .{ .output = stop.output, .first = stop.first });
            if (stop.second) |second| try points.append(self.allocator, .{ .output = stop.output, .first = second });
        }
        if (points.items[0].first == null) points.items[0].first = try self.append(Number.percent(0));
        if (points.items[points.items.len - 1].first == null) points.items[points.items.len - 1].first = try self.append(Number.percent(100));
        var greatest = -std.math.inf(f64);
        for (points.items) |point| if (point.first) |index| {
            const value = @max(greatest, self.terms.items[index].known().?.value);
            self.terms.items[index].unref();
            self.terms.items[index] = Number.percent(value);
            greatest = value;
        };
        var previous: usize = 0;
        for (points.items[1..], 1..) |point, i| {
            if (point.first == null) continue;
            const lo = self.terms.items[points.items[previous].first.?].known().?.value;
            const hi = self.terms.items[point.first.?].known().?.value;
            for (previous + 1..i) |j| {
                const fraction = @as(f64, @floatFromInt(j - previous)) / @as(f64, @floatFromInt(i - previous));
                // Weighted endpoints avoid overflowing hi-lo for large,
                // opposite-sign percentages.
                const value = lo * (1 - fraction) + hi * fraction;
                points.items[j].first = try self.append(Number.percent(value));
            }
            previous = i;
        }
        self.stops.deinit(self.allocator);
        self.stops = points;
        points = .empty;
        self.expanded = true;
    }

    pub fn serialize(self: *const Easing, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.kind) {
            .keyword => try out.appendSlice(allocator, self.keyword),
            .cubic => {
                try out.appendSlice(allocator, "cubic-bezier(");
                for (self.terms.items, 0..) |term, i| {
                    if (i > 0) try out.appendSlice(allocator, ", ");
                    try term.serialize(out, allocator);
                }
                try out.append(allocator, ')');
            },
            .steps => {
                try out.appendSlice(allocator, "steps(");
                try self.terms.items[0].serialize(out, allocator);
                if (self.jump != .end and self.jump != .jump_end) {
                    try out.appendSlice(allocator, ", ");
                    try out.appendSlice(allocator, self.jump.name());
                }
                try out.append(allocator, ')');
            },
            .linear => {
                try out.appendSlice(allocator, "linear(");
                for (self.stops.items, 0..) |stop, i| {
                    if (i > 0) try out.appendSlice(allocator, ", ");
                    try self.terms.items[stop.output].serialize(out, allocator);
                    for ([_]?usize{ stop.first, stop.second }) |maybe_index| if (maybe_index) |index| {
                        try out.append(allocator, ' ');
                        try self.terms.items[index].serialize(out, allocator);
                    };
                }
                try out.append(allocator, ')');
            },
        }
    }
};
