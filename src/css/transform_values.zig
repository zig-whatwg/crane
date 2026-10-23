//! CSS Transforms 2 §§5–5.1: individual transform values, without layout.
//! Numeric components use the same owned trees as animation and easing.
//! Design reference: Blink CSSAxisValue normalizes literal principal axes
//! before specified serialization, and computed axes after resolving numbers.
const std = @import("std");
const properties = @import("properties.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;
const Stream = properties.Stream;

pub const Kind = enum { translate, rotate, scale };

pub const Transform = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    kind: Kind,
    // X/Y/Z, then angle for rotate. The unused fourth component is scalar 0.
    components: [4]Number,

    fn create(allocator: Allocator, kind: Kind) Allocator.Error!*Transform {
        const result = try allocator.create(Transform);
        const zero = Number.scalar(0);
        const px: Number = .{ .literal = .{ .value = 0, .unit = .px } };
        result.* = .{
            .allocator = allocator,
            .kind = kind,
            .components = switch (kind) {
                .translate => .{ px, px, px, zero },
                .rotate => .{ zero, zero, Number.scalar(1), .{ .literal = .{ .value = 0, .unit = .deg } } },
                .scale => .{ Number.scalar(1), Number.scalar(1), Number.scalar(1), zero },
            },
        };
        return result;
    }

    pub fn ref(self: *Transform) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *Transform) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.components) |number| number.unref();
        self.allocator.destroy(self);
    }

    pub fn eql(a: *const Transform, b: *const Transform) bool {
        if (a == b) return true;
        if (a.kind != b.kind) return false;
        for (a.components, b.components) |x, y| if (!x.eql(y)) return false;
        return true;
    }

    pub fn needsTreeCounts(self: *const Transform) bool {
        for (self.components) |number| if (number.needsTreeCounts()) return true;
        return false;
    }

    pub fn needsRandomBase(self: *const Transform) bool {
        for (self.components) |number| if (number.needsRandomBase()) return true;
        return false;
    }

    pub fn needsUnavailableMetrics(self: *const Transform, geometry_length: bool) bool {
        _ = geometry_length;
        // Q25: translation coordinates may preserve unavailable geometric
        // lengths; scale factors and rotation numbers/angles may not.
        for (self.components) |number| if (number.needsUnavailableMetrics(self.kind == .translate)) return true;
        return false;
    }

    pub fn compute(self: *const Transform, allocator: Allocator, context: math.Context) Allocator.Error!*Transform {
        const result = try create(allocator, self.kind);
        errdefer result.unref();
        var component_context = context;
        // §5: translate's resolved value is its computed value, including %.
        component_context.percentage_basis = null;
        for (self.components, &result.components) |number, *destination| {
            destination.* = try number.compute(allocator, component_context);
        }
        try result.normalizeAxis();
        return result;
    }

    fn isLiteral(number: Number, value: f64, unit: math.Unit) bool {
        return number == .literal and number.literal.unit == unit and number.literal.value == value;
    }

    /// §5.1: preserve calculated axes at specified-value time, including
    /// calculated zeroes. Once computed, those axes are ordinary numbers.
    fn principalAxis(self: *const Transform) ?usize {
        var axis: ?usize = null;
        for (self.components[0..3], 0..) |number, index| {
            if (number != .literal or number.literal.unit != .number) return null;
            if (number.literal.value == 0) continue;
            if (axis != null) return null;
            axis = index;
        }
        return axis;
    }

    fn normalizeAxis(self: *Transform) Allocator.Error!void {
        if (self.kind != .rotate) return;
        const axis = self.principalAxis() orelse return;
        const direction = self.components[axis].literal.value;
        if (direction < 0) {
            const old = self.components[3];
            const negated: Number = switch (old) {
                .literal => |number| .{ .literal = .{ .value = -number.value, .unit = number.unit } },
                .calculation => |expression| .{ .calculation = try expression.negated(self.allocator) },
            };
            self.components[3] = negated;
            old.unref();
        }
        self.components[axis] = Number.scalar(1);
    }

    pub fn serialize(self: *const Transform, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.kind == .rotate) {
            if (self.principalAxis()) |axis| {
                if (axis < 2) try out.appendSlice(allocator, if (axis == 0) "x " else "y ");
            } else {
                // The zero vector is not a principal axis and is retained.
                for (self.components[0..3]) |number| {
                    try number.serialize(out, allocator);
                    try out.append(allocator, ' ');
                }
            }
            return self.components[3].serialize(out, allocator);
        }
        var count: usize = 3;
        if (self.kind == .translate) {
            if (isLiteral(self.components[2], 0, .px)) count = 2;
            if (count == 2 and isLiteral(self.components[1], 0, .px)) count = 1;
        } else {
            if (isLiteral(self.components[2], 1, .number)) count = 2;
            if (count == 2 and self.components[0].eql(self.components[1])) count = 1;
        }
        for (self.components[0..count], 0..) |number, index| {
            if (index != 0) try out.append(allocator, ' ');
            try number.serialize(out, allocator);
        }
    }
};

/// Parse the non-none arm. The owning longhand handles CSS-wide keywords and
/// none, and rejects any trailing tokens after this value.
pub fn parse(options: properties.ParseOptions, stream: *Stream, kind: Kind) Allocator.Error!?*Transform {
    const value = try Transform.create(options.allocator, kind);
    errdefer value.unref();
    if (kind == .rotate) {
        if (!try rotation(options, stream, value)) {
            value.unref();
            return null;
        }
        try value.normalizeAxis();
        return value;
    }
    var count: usize = 0;
    while (count < 3) {
        const grammar: math.Grammar = .{ .kind = if (kind == .scale) .number_percentage else if (count < 2) .length_percentage else .length };
        var number = try Number.consume(options, stream, grammar, kind == .translate) orelse break;
        // §5: literal scale percentages serialize as numbers. Calculations
        // preserve their specified units until Number.compute resolves them.
        if (kind == .scale and number == .literal and number.literal.unit == .percent) number = Number.scalar(number.literal.value / 100);
        value.components[count] = number;
        count += 1;
    }
    if (count == 0) {
        value.unref();
        return null;
    }
    if (kind == .scale and count == 1) {
        value.components[1] = value.components[0];
        value.components[1].ref();
    }
    return value;
}

fn rotation(options: properties.ParseOptions, stream: *Stream, value: *Transform) Allocator.Error!bool {
    const start = stream.*;
    if (try Number.consume(options, stream, .{ .kind = .angle }, false)) |angle| {
        value.components[3] = angle;
        if (stream.atEnd()) return true;
        return axes(options, stream, value);
    }
    stream.* = start;
    if (!try axes(options, stream, value)) return false;
    const angle = try Number.consume(options, stream, .{ .kind = .angle }, false) orelse return false;
    value.components[3] = angle;
    return true;
}

fn axes(options: properties.ParseOptions, stream: *Stream, value: *Transform) Allocator.Error!bool {
    const token = stream.peek();
    if (token.token_type == .ident) {
        inline for (.{ "x", "y", "z" }, 0..) |name, index| {
            if (tokens.nameEql(token.value, name)) {
                _ = stream.next();
                value.components[0] = Number.scalar(0);
                value.components[1] = Number.scalar(0);
                value.components[2] = Number.scalar(0);
                value.components[index] = Number.scalar(1);
                return true;
            }
        }
        return false;
    }
    for (value.components[0..3]) |*component| {
        component.* = try Number.consume(options, stream, .{ .kind = .number }, false) orelse return false;
    }
    return true;
}
