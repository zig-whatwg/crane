//! CSS Images3 §§3.1–3.4 and Images4 §§3,8: typed gradient components.
//! The object owns syntax and computed values, never used stop fixup or pixels.
//! Design reference: WebKit CSSPropertyParserConsumer+Image.cpp's standard
//! gradient consumers; Q31/Q55/Q56/Q57 settle the browser differences.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const tokens = @import("tokenizer.zig");
const angles = @import("image_angle.zig");
const positions = @import("position_values.zig");
const spaces = @import("color_spaces.zig");
const Scheme = @import("color_scheme.zig").Scheme;
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Color = values.Color;

pub const Kind = enum { linear, radial, conic };
pub const Function = struct { kind: Kind, repeating: bool };

pub fn function(token: tokens.Token) ?Function {
    if (token.token_type != .function) return null;
    inline for (.{ "linear", "radial", "conic" }) |kind| {
        if (tokens.nameEql(token.value, kind ++ "-gradient")) return .{ .kind = @field(Kind, kind), .repeating = false };
        if (tokens.nameEql(token.value, "repeating-" ++ kind ++ "-gradient")) return .{ .kind = @field(Kind, kind), .repeating = true };
    }
    return null;
}

/// Literal angles need neither an expression allocation nor a fake longhand.
/// Other scalar values and calculations use the existing owned Value contract.
const Numeric = union(enum) {
    value: Value,
    angle: angles.Angle,

    fn retain(self: Numeric) void {
        if (self == .value) self.value.retain();
    }
    fn release(self: Numeric) void {
        if (self == .value) self.value.release();
    }
    fn eql(self: Numeric, other: Numeric) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .value => |value| value.eql(other.value),
            .angle => |angle| angle.number == other.angle.number and angle.unit == other.angle.unit,
        };
    }
    fn compute(self: Numeric, context: anytype) Allocator.Error!Numeric {
        return switch (self) {
            .value => |value| .{ .value = try context.length(value) },
            .angle => |angle| .{ .angle = .{ .number = angle.degrees(), .unit = .deg } },
        };
    }
    fn serialize(self: Numeric, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        return switch (self) {
            .value => |value| properties.serializeValue(.margin_left, value, out, allocator),
            .angle => |angle| angle.serialize(out, allocator),
        };
    }
    fn defaultAngle(self: Numeric, degrees: f64) bool {
        return switch (self) {
            .angle => |angle| angle.degrees() == degrees,
            .value => |value| if (value == .calculation) blk: {
                const number = value.calculation.computedNumber() orelse break :blk false;
                break :blk number.unit == .deg and number.value == degrees;
            } else false,
        };
    }
};

const Stop = struct {
    color: ?Color = null,
    offsets: [2]?Numeric = .{ null, null },

    fn retain(self: Stop) void {
        if (self.color) |color| color.retain();
        for (self.offsets) |offset| if (offset) |number| number.retain();
    }
    fn release(self: Stop) void {
        if (self.color) |color| color.release();
        for (self.offsets) |offset| if (offset) |number| number.release();
    }
};

const Corner = struct {
    horizontal: ?enum { left, right } = null,
    vertical: ?enum { top, bottom } = null,
};
const Extent = enum { closest_side, closest_corner, farthest_side, farthest_corner };
const Method = struct { space: spaces.Space, hue: spaces.HueMethod = .shorter };
const Query = enum { metrics, tree, random };

pub const Gradient = struct {
    function: Function,
    /// Index0 is an angle; indices1/2 are radial radii.
    numbers: [3]?Numeric = .{ null, null, null },
    corner: ?Corner = null,
    circle: bool = false,
    extent: Extent = .farthest_corner,
    position: ?*positions.Position = null,
    method: ?Method = null,
    stops: []const Stop = &.{},
    computed: bool = false,
    legacy: bool = true,

    /// Borrowed input; each cloned field acquires its own reference.
    pub fn clone(self: Gradient, allocator: Allocator) Allocator.Error!Gradient {
        var result = self;
        result.stops = try allocator.dupe(Stop, self.stops);
        for (result.stops) |stop| stop.retain();
        for (result.numbers) |number| if (number) |value| value.retain();
        if (result.position) |position| position.ref();
        return result;
    }

    pub fn release(self: Gradient, allocator: Allocator) void {
        for (self.stops) |stop| stop.release();
        allocator.free(self.stops);
        for (self.numbers) |number| if (number) |value| value.release();
        if (self.position) |position| position.unref();
    }

    pub fn eql(self: Gradient, other: Gradient) bool {
        if (!std.meta.eql(self.function, other.function) or self.computed != other.computed or self.legacy != other.legacy or
            self.circle != other.circle or self.extent != other.extent or !std.meta.eql(self.corner, other.corner) or
            !std.meta.eql(self.method, other.method) or self.stops.len != other.stops.len) return false;
        for (self.numbers, other.numbers) |a, b| if (!numericEql(a, b)) return false;
        if (self.position) |position| {
            if (other.position == null or !position.eql(other.position.?)) return false;
        } else if (other.position != null) return false;
        for (self.stops, other.stops) |a, b| {
            if (a.color) |color| {
                if (b.color == null or !color.eql(b.color.?)) return false;
            } else if (b.color != null) return false;
            for (a.offsets, b.offsets) |x, y| if (!numericEql(x, y)) return false;
        }
        return true;
    }

    pub fn needsUnavailableMetrics(self: Gradient, geometry_length: bool) bool {
        return self.query(.metrics, geometry_length);
    }
    pub fn needsTreeCounts(self: Gradient) bool {
        return self.query(.tree, false);
    }
    pub fn needsRandomBase(self: Gradient) bool {
        return self.query(.random, false);
    }

    fn query(self: Gradient, comptime which: Query, geometry_length: bool) bool {
        for (self.numbers) |number| if (number) |value| if (queryNumeric(value, which, geometry_length)) return true;
        if (self.position) |position| {
            if (switch (which) {
                .metrics => position.needsUnavailableMetrics(geometry_length),
                .tree => position.needsTreeCounts(),
                .random => position.needsRandomBase(),
            }) return true;
        }
        for (self.stops) |stop| {
            if (stop.color) |color| {
                if (switch (which) {
                    .metrics => color.needsUnavailableMetrics(geometry_length),
                    .tree => color.needsTreeCounts(),
                    .random => color.needsRandomBase(),
                }) return true;
            }
            for (stop.offsets) |number| if (number) |value| if (queryNumeric(value, which, geometry_length)) return true;
        }
        return false;
    }

    /// Ask the Color owner whether any stop depends on currentcolor.
    pub fn containsCurrentColor(self: Gradient) bool {
        for (self.stops) |stop| if (stop.color) |color| {
            if (color.containsCurrentColor()) return true;
        };
        return false;
    }

    /// Owned CSSOM copy: Color4 §15.5 resolves only dependent stop colors
    /// for the receiver. Already-computed geometry and Q56/Q57's inherited
    /// interpolation classification stay unchanged (Images4 §§2, 3.5).
    pub fn resolveCurrentColors(self: Gradient, allocator: Allocator, context: Color.Context) Allocator.Error!Gradient {
        var result = try self.clone(allocator);
        errdefer result.release(allocator);
        for (@constCast(result.stops)) |*stop| {
            if (stop.color) |color| {
                if (!color.containsCurrentColor()) continue;
                const resolved = try color.resolveComputed(allocator, context);
                color.release();
                stop.color = resolved;
            }
        }
        return result;
    }

    pub fn compute(self: Gradient, allocator: Allocator, scheme: Scheme, context: anytype) Allocator.Error!Gradient {
        var result = try self.clone(allocator);
        errdefer result.release(allocator);
        if (self.computed) return result;
        result.computed = true;
        result.legacy = true;
        // Q56/Q57: the per-case browser majority is not one browser's rule.
        // Classify ORIGINAL colors with the ELEMENT scheme before resolution;
        // copying the resulting metadata preserves it through inheritance.
        // Evidence: integrator-probes-1023j/-1023k/-1023l, CSS Color4 §13.2.
        for (self.stops) |stop| if (stop.color) |color| {
            result.legacy = result.legacy and color.usesLegacyGradientInterpolation(.{ .computed = scheme });
        };
        for (&result.numbers) |*number| if (number.*) |value| {
            const computed = try value.compute(context);
            value.release();
            number.* = computed;
        };
        if (result.position) |position| {
            const computed = try position.compute(allocator, context);
            position.unref();
            result.position = computed;
        }
        for (@constCast(result.stops)) |*stop| {
            if (stop.color) |color| {
                const computed = try context.color(color);
                color.release();
                stop.color = computed;
            }
            for (&stop.offsets) |*number| if (number.*) |value| {
                const computed = try value.compute(context);
                value.release();
                number.* = computed;
            };
        }
        // Images4 §3.5.3 is explicitly USED-value fixup, not this operation.
        return result;
    }

    pub fn serialize(self: Gradient, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.function.repeating) try out.appendSlice(allocator, "repeating-");
        try out.appendSlice(allocator, @tagName(self.function.kind));
        try out.appendSlice(allocator, "-gradient(");
        const start = out.items.len;
        switch (self.function.kind) {
            .linear => {
                if (self.numbers[0]) |number| {
                    if (!number.defaultAngle(180)) try number.serialize(out, allocator);
                } else if (self.corner) |corner| {
                    if (corner.horizontal != null or corner.vertical != .bottom) {
                        try out.appendSlice(allocator, "to ");
                        if (corner.horizontal) |side| try out.appendSlice(allocator, @tagName(side));
                        if (corner.vertical) |side| {
                            if (corner.horizontal != null) try out.append(allocator, ' ');
                            try out.appendSlice(allocator, @tagName(side));
                        }
                    }
                }
            },
            .radial => {
                if (self.numbers[1]) |radius| {
                    try radius.serialize(out, allocator);
                    if (self.numbers[2]) |second| {
                        try out.append(allocator, ' ');
                        try second.serialize(out, allocator);
                    }
                } else {
                    if (self.circle) try out.appendSlice(allocator, "circle");
                    if (self.extent != .farthest_corner) {
                        try separate(out, start, allocator);
                        try out.appendSlice(allocator, extentName(self.extent));
                    }
                }
            },
            .conic => if (self.numbers[0]) |angle| {
                if (!angle.defaultAngle(0)) {
                    try out.appendSlice(allocator, "from ");
                    try angle.serialize(out, allocator);
                }
            },
        }
        if (self.position) |position| {
            if (!computedCenter(position)) {
                try separate(out, start, allocator);
                try out.appendSlice(allocator, "at ");
                try position.serialize(out, allocator);
            }
        }
        if (self.method) |method| {
            const default: spaces.Space = if (self.legacy) .srgb else .oklab;
            if (method.space != default or method.hue != .shorter) {
                try separate(out, start, allocator);
                try out.appendSlice(allocator, "in ");
                try out.appendSlice(allocator, method.space.name());
                if (method.hue != .shorter) try out.print(allocator, " {s} hue", .{@tagName(method.hue)});
            }
        }
        if (out.items.len != start) try out.appendSlice(allocator, ", ");
        for (self.stops, 0..) |stop, i| {
            if (i != 0) try out.appendSlice(allocator, ", ");
            if (stop.color) |color| {
                if (self.computed) try color.serializeComputed(out, allocator) else try color.serializeSpecified(out, allocator);
            }
            for (stop.offsets, 0..) |number, j| if (number) |value| {
                if (stop.color != null or j != 0) try out.append(allocator, ' ');
                try value.serialize(out, allocator);
            };
        }
        try out.append(allocator, ')');
    }
};

fn queryNumeric(number: Numeric, comptime which: Query, geometry_length: bool) bool {
    return number == .value and switch (which) {
        .metrics => number.value.needsUnavailableMetrics(geometry_length),
        .tree => number.value.needsTreeCounts(),
        .random => number.value.needsRandomBase(),
    };
}
fn numericEql(a: ?Numeric, b: ?Numeric) bool {
    return if (a) |number| if (b) |other| number.eql(other) else false else b == null;
}
fn separate(out: *std.ArrayList(u8), start: usize, allocator: Allocator) Allocator.Error!void {
    if (out.items.len != start) try out.append(allocator, ' ');
}
fn computedCenter(position: *const positions.Position) bool {
    if (position.data != .computed) return false;
    for (position.data.computed) |offset| {
        if (offset.value != .length or offset.value.length.unit != .percent or offset.value.length.value != 50) return false;
    }
    return true;
}
fn extentName(extent: Extent) []const u8 {
    return switch (extent) {
        .closest_side => "closest-side",
        .closest_corner => "closest-corner",
        .farthest_side => "farthest-side",
        .farthest_corner => "farthest-corner",
    };
}
fn keyword(stream: *properties.Stream, name: []const u8) bool {
    const token = stream.peek();
    if (token.token_type != .ident or !tokens.nameEql(token.value, name)) return false;
    _ = stream.next();
    return true;
}

fn numeric(options: properties.ParseOptions, stream: *properties.Stream, kind: math.Kind, nonnegative: bool) Allocator.Error!?Numeric {
    const token = stream.peek();
    const grammar = math.Grammar{ .kind = kind, .minimum = if (nonnegative) 0 else -std.math.floatMax(f64) };
    if (math.isFunction(token)) {
        const value = try properties.mathValue(options, stream, grammar) orelse return null;
        return .{ .value = value };
    }
    if (kind == .angle or kind == .angle_percentage) {
        if (angles.parse(stream, true)) |angle| return .{ .angle = angle };
        if (kind == .angle_percentage and token.token_type == .percentage) {
            _ = stream.next();
            return .{ .value = .{ .length = .percent(token.numeric_value orelse return null) } };
        }
        return null;
    }
    // Use the existing strict scalar grammar; the public dimension builder
    // also validates units absent from LengthUnit without a copied unit list.
    var strict = options;
    strict.quirks = false;
    const saved = stream.*;
    const value = try properties.parseLonghand(strict, .margin_left, stream) orelse {
        stream.* = saved;
        return null;
    };
    if (value == .length and (kind == .length_percentage or value.length.unit != .percent) and (!nonnegative or value.length.value >= 0))
        return .{ .value = value };
    value.release();
    stream.* = saved;
    if (token.token_type == .dimension) {
        const unit = math.Unit.parse(token.unit orelse return null) orelse return null;
        const expression = try math.dimension(options.allocator, .{ .value = token.numeric_value orelse return null, .unit = unit }, grammar) orelse return null;
        _ = stream.next();
        return .{ .value = .{ .calculation = expression } };
    }
    return null;
}

fn interpolation(stream: *properties.Stream) ?Method {
    const token = stream.next();
    if (token.token_type != .ident) return null;
    var method = Method{ .space = spaces.Space.parse(token.value) orelse return null };
    if (method.space.hue() != null) {
        inline for (@typeInfo(spaces.HueMethod).@"enum".fields) |field| {
            if (keyword(stream, field.name)) {
                if (!keyword(stream, "hue")) return null;
                method.hue = @enumFromInt(field.value);
                return method;
            }
        }
    }
    return method;
}

/// Return null for an invalid header, false for no header, true when present.
fn geometry(result: *Gradient, options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?bool {
    var present = false;
    switch (result.function.kind) {
        .linear => {
            result.numbers[0] = try numeric(options, stream, .angle, false);
            if (result.numbers[0] != null) return true;
            if (!keyword(stream, "to")) return false;
            var corner = Corner{};
            for (0..2) |_| {
                if (keyword(stream, "left")) {
                    if (corner.horizontal != null) return null;
                    corner.horizontal = .left;
                } else if (keyword(stream, "right")) {
                    if (corner.horizontal != null) return null;
                    corner.horizontal = .right;
                } else if (keyword(stream, "top")) {
                    if (corner.vertical != null) return null;
                    corner.vertical = .top;
                } else if (keyword(stream, "bottom")) {
                    if (corner.vertical != null) return null;
                    corner.vertical = .bottom;
                } else break;
            }
            if (corner.horizontal == null and corner.vertical == null) return null;
            result.corner = corner;
            return true;
        },
        .radial => {
            var shape_seen = false;
            var size_seen = false;
            for (0..2) |_| {
                if (keyword(stream, "circle")) {
                    if (shape_seen) return null;
                    result.circle = true;
                    shape_seen = true;
                    present = true;
                    continue;
                }
                if (keyword(stream, "ellipse")) {
                    if (shape_seen) return null;
                    shape_seen = true;
                    present = true;
                    continue;
                }
                var extent: ?Extent = null;
                inline for (@typeInfo(Extent).@"enum".fields) |field| {
                    const candidate: Extent = @enumFromInt(field.value);
                    if (extent == null and keyword(stream, extentName(candidate))) extent = candidate;
                }
                if (extent) |found| {
                    if (size_seen) return null;
                    result.extent = found;
                    size_seen = true;
                    present = true;
                    continue;
                }
                const start = stream.*;
                const first = try numeric(options, stream, .length_percentage, true) orelse break;
                if (size_seen) {
                    first.release();
                    return null;
                }
                result.numbers[1] = first;
                result.numbers[2] = try numeric(options, stream, .length_percentage, true);
                if (result.numbers[2] == null) {
                    // Images3 §3.2.1 / Q31: a lone radius must be LENGTH.
                    // Reparse the same tokens under that grammar; ParseScope
                    // is immutable and locates random keys by source offset.
                    first.release();
                    result.numbers[1] = null;
                    stream.* = start;
                    result.numbers[1] = try numeric(options, stream, .length, true) orelse return null;
                }
                size_seen = true;
                present = true;
            }
            if (result.numbers[1] != null) {
                if (shape_seen and result.circle != (result.numbers[2] == null)) return null;
                result.circle = result.numbers[2] == null;
            }
        },
        .conic => {
            if (keyword(stream, "from")) {
                result.numbers[0] = try numeric(options, stream, .angle, false) orelse return null;
                present = true;
            }
        },
    }
    if (keyword(stream, "at")) {
        result.position = try positions.parse(options, stream, .position) orelse return null;
        present = true;
    }
    return present;
}

/// Images4 §3.5.1: one or more colors, optional interior nonadjacent hints,
/// and at most two positions per color. EOF closes the function (Syntax3
/// §5.5.10); every other unmatched delimiter or malformed token is rejected.
pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Gradient {
    const kind = function(stream.next()) orelse return null;
    if (stream.next().token_type != .left_paren) return null;
    var result = Gradient{ .function = kind };
    var transferred = false;
    defer if (!transferred) result.release(options.allocator);
    if (keyword(stream, "in")) result.method = interpolation(stream) orelse return null;
    const header = try geometry(&result, options, stream) orelse return null;
    if (header and result.method == null and keyword(stream, "in")) result.method = interpolation(stream) orelse return null;
    if (header or result.method != null) if (stream.next().token_type != .comma) return null;
    var stops: std.ArrayList(Stop) = .empty;
    defer {
        for (stops.items) |stop| stop.release();
        stops.deinit(options.allocator);
    }
    var previous_hint = true;
    const numeric_kind: math.Kind = if (kind.kind == .conic) .angle_percentage else .length_percentage;
    while (true) {
        var stop = Stop{};
        defer stop.release();
        var strict = options;
        strict.quirks = false;
        const saved = stream.*;
        if (try properties.parseLonghand(strict, .color, stream)) |color| {
            if (color != .color) {
                color.release();
                return null;
            }
            stop.color = color.color;
            result.legacy = result.legacy and color.color.usesLegacyGradientInterpolation(.specified);
        } else stream.* = saved;
        stop.offsets[0] = try numeric(options, stream, numeric_kind, false);
        if (stop.color == null) {
            if (stop.offsets[0] == null or previous_hint) return null;
        } else if (stop.offsets[0] != null) stop.offsets[1] = try numeric(options, stream, numeric_kind, false);
        previous_hint = stop.color == null;
        try stops.append(options.allocator, stop);
        stop.retain();
        switch (stream.next().token_type) {
            .comma => continue,
            .right_paren, .eof => break,
            else => return null,
        }
    }
    if (previous_hint) return null;
    result.stops = try stops.toOwnedSlice(options.allocator);
    transferred = true;
    return result;
}
