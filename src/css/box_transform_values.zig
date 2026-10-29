//! CSS Transforms 1 §§3–5,12 and Transforms 2 §§8–10,16.
//! Shared functions own argument grammar; this owner composes their matrices.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const functions = @import("transform_functions.zig");
const math = @import("math_values.zig");
const Position = @import("position_values.zig").Position;
const tokens = @import("tokenizer.zig");
const Number = @import("numeric_values.zig").Number;
const Allocator = std.mem.Allocator;
const Stream = properties.Stream;
const Value = values.Value;
// Physical origin keywords are local to this grammar. The global property
// keyword enum intentionally has no top/bottom entries.
const OriginKeyword = enum {
    left,
    right,
    top,
    bottom,
    center,

    fn name(self: OriginKeyword) []const u8 {
        return @tagName(self);
    }
};

pub const List = struct {
    allocator: Allocator,
    refs: std.atomic.Value(usize) = .init(1),
    items: []functions.Function,

    pub fn ref(self: *List) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *List) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.items) |*function| function.deinit();
        self.allocator.free(self.items);
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const List, other: *const List) bool {
        if (self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| {
            if (a.kind != b.kind or a.computed != b.computed or a.arguments.len != b.arguments.len) return false;
            for (a.arguments, b.arguments) |x, y| if (!x.eql(y)) return false;
        }
        return true;
    }
    pub fn needsUnavailableMetrics(self: *const List, geometry_length: bool) bool {
        for (self.items) |function| for (function.arguments) |number| {
            if (number.needsUnavailableMetrics(geometry_length)) return true;
        };
        return false;
    }
    pub fn needsTreeCounts(self: *const List) bool {
        for (self.items) |function| for (function.arguments) |number| {
            if (number.needsTreeCounts()) return true;
        };
        return false;
    }
    pub fn needsRandomBase(self: *const List) bool {
        for (self.items) |function| for (function.arguments) |number| {
            if (number.needsRandomBase()) return true;
        };
        return false;
    }
    pub fn compute(self: *const List, allocator: Allocator, context: math.Context) Allocator.Error!*List {
        const items = try allocator.alloc(functions.Function, self.items.len);
        errdefer allocator.free(items);
        var initialized: usize = 0;
        errdefer for (items[0..initialized]) |*function| function.deinit();
        for (self.items, items) |source, *destination| {
            destination.* = try source.compute(allocator, context);
            initialized += 1;
        }
        const result = try allocator.create(List);
        result.* = .{ .allocator = allocator, .items = items };
        return result;
    }
    pub fn serialize(self: *const List, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.items, 0..) |function, i| {
            if (i != 0) try out.append(allocator, ' ');
            try function.serialize(out, allocator);
        }
    }
    pub fn serializeResolved(self: *const List, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        // Transforms 1 §3.2 steps 1–3 / Transforms 2 §2.1: post-multiply
        // in list order. An unresolved reference-box percentage stays typed.
        var result = identity();
        for (self.items) |function| {
            const next = matrixFor(function) orelse return self.serialize(out, allocator);
            compose(&result, function, next);
        }
        const two_dimensional = result[2] == 0 and result[3] == 0 and result[6] == 0 and result[7] == 0 and
            result[8] == 0 and result[9] == 0 and result[10] == 1 and result[11] == 0 and result[14] == 0 and result[15] == 1;
        try out.appendSlice(allocator, if (two_dimensional) "matrix(" else "matrix3d(");
        const flat = [6]f64{ result[0], result[1], result[4], result[5], result[12], result[13] };
        const components: []const f64 = if (two_dimensional) &flat else &result;
        for (components, 0..) |number, i| {
            if (i != 0) try out.appendSlice(allocator, ", ");
            try values.appendNumber(number, out, allocator);
        }
        try out.append(allocator, ')');
    }
};

pub fn consumeList(options: properties.ParseOptions, stream: *Stream, legacy: bool) Allocator.Error!?Value {
    if (stream.peek().isIdent("none")) {
        _ = stream.next();
        return Value.kw(.none);
    }
    var items: std.ArrayList(functions.Function) = .empty;
    defer {
        for (items.items) |*function| function.deinit();
        items.deinit(options.allocator);
    }
    while (!stream.atEnd()) {
        var function = (if (legacy) try functions.consumeWithLegacyPerspective(options, stream) else try functions.consume(options, stream)) orelse return null;
        errdefer function.deinit();
        try items.append(options.allocator, function);
    }
    if (items.items.len == 0) return null;
    const result = try options.allocator.create(List);
    errdefer options.allocator.destroy(result);
    result.* = .{ .allocator = options.allocator, .items = try items.toOwnedSlice(options.allocator) };
    return .{ .transform_list = result };
}

/// Both legacy callers share the conversion in the function grammar owner.
pub fn consumeLegacyPerspective(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    if (stream.peek().isIdent("none")) {
        _ = stream.next();
        return Value.kw(.none);
    }
    const number = try functions.consumeLegacyPerspectiveLength(options, stream) orelse return null;
    return switch (number) {
        .calculation => |expression| .{ .calculation = expression },
        // Number.consume keeps only absolute lengths as literals; relative
        // lengths already use the shared expression and its capability checks.
        .literal => |literal| .{ .length = values.Length.init(literal.value, values.LengthUnit.fromString(literal.unit.name()).?) },
    };
}

const Part = union(enum) {
    keyword: OriginKeyword,
    number: Number,

    fn unref(self: Part) void {
        if (self == .number) self.number.unref();
    }
    fn eql(self: Part, other: Part) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .keyword => |keyword| keyword == other.keyword,
            .number => |number| number.eql(other.number),
        };
    }
    fn compute(self: Part, allocator: Allocator, context: math.Context) Allocator.Error!Part {
        return .{ .number = if (self == .number) try self.number.compute(allocator, context) else Number.percent(switch (self.keyword) {
            .left, .top => 0,
            .right, .bottom => 100,
            .center => 50,
        }) };
    }
    fn serialize(self: Part, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        return switch (self) {
            .keyword => |keyword| out.appendSlice(allocator, keyword.name()),
            .number => |number| number.serialize(out, allocator),
        };
    }
    fn permitsAxis(self: Part, horizontal: bool) bool {
        if (self == .number or self.keyword == .center) return true;
        return if (horizontal) self.keyword == .left or self.keyword == .right else self.keyword == .top or self.keyword == .bottom;
    }
};

pub const Origin = struct {
    allocator: Allocator,
    refs: std.atomic.Value(usize) = .init(1),
    xy: [2]Part = .{ .{ .keyword = .center }, .{ .keyword = .center } },
    z: ?Number = null,

    pub fn ref(self: *Origin) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Origin) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        for (self.xy) |part| part.unref();
        if (self.z) |number| number.unref();
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Origin, other: *const Origin) bool {
        for (self.xy, other.xy) |a, b| if (!a.eql(b)) return false;
        if (self.z) |number| return other.z != null and number.eql(other.z.?);
        return other.z == null;
    }
    pub fn needsUnavailableMetrics(self: *const Origin, geometry_length: bool) bool {
        for (self.xy) |part| if (part == .number and part.number.needsUnavailableMetrics(geometry_length)) return true;
        return if (self.z) |number| number.needsUnavailableMetrics(geometry_length) else false;
    }
    pub fn needsTreeCounts(self: *const Origin) bool {
        for (self.xy) |part| if (part == .number and part.number.needsTreeCounts()) return true;
        return if (self.z) |number| number.needsTreeCounts() else false;
    }
    pub fn needsRandomBase(self: *const Origin) bool {
        for (self.xy) |part| if (part == .number and part.number.needsRandomBase()) return true;
        return if (self.z) |number| number.needsRandomBase() else false;
    }
    pub fn compute(self: *const Origin, allocator: Allocator, context: math.Context) Allocator.Error!*Origin {
        const result = try allocator.create(Origin);
        result.* = .{ .allocator = allocator };
        errdefer result.unref();
        var component_context = context;
        component_context.percentage_basis = null;
        for (self.xy, &result.xy) |part, *destination| destination.* = try part.compute(allocator, component_context);
        if (self.z) |number| result.z = try number.compute(allocator, component_context);
        return result;
    }
    pub fn serialize(self: *const Origin, resolved: bool, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        return self.serializeComponents(resolved, false, out, allocator);
    }
    pub fn serializeResolved(self: *const Origin, has_box: bool, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        return self.serializeComponents(true, has_box, out, allocator);
    }
    fn serializeComponents(self: *const Origin, resolved: bool, has_box: bool, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        for (self.xy, 0..) |part, i| {
            if (i != 0) try out.append(allocator, ' ');
            if (has_box and part == .number) {
                const number = part.number;
                if (number == .literal and number.literal.unit == .percent and number.literal.value == 0) {
                    try out.appendSlice(allocator, "0px");
                    continue;
                }
                if (number == .calculation and try serializeZeroPercentMath(number.calculation, out, allocator)) continue;
            }
            try part.serialize(out, allocator);
        }
        if (self.z) |number| {
            // Q14 / Transforms 1 §4: authored zero Z is retained; the
            // resolved value omits a computed zero length.
            if (resolved and number == .literal and number.literal.unit == .px and number.literal.value == 0) return;
            try out.append(allocator, ' ');
            try number.serialize(out, allocator);
        }
    }
};

// Q38 / CSSOM §9, Transforms 1 §5: a zero percentage needs no box size,
// but only generated boxes use this resolved-value path. Inspect the existing
// computed tree before giving the shared evaluator a basis: no missing font,
// viewport, anchor, symbol, random or tree input may acquire a default here.
fn hasOnlyAbsoluteAndZeroPercentLeaves(node: anytype) bool {
    switch (node.tag) {
        .numeric => return switch (node.numeric.unit) {
            .percent => node.numeric.value == 0,
            .number, .px, .cm, .mm, .q, .in, .pt, .pc, .deg, .grad, .rad, .turn, .s, .ms, .hz, .khz, .dpi, .dpcm, .dppx, .x, .fr => true,
            else => false,
        },
        .sum, .product, .negate, .invert, .min, .max, .clamp, .function => {
            for (node.children) |child| if (!hasOnlyAbsoluteAndZeroPercentLeaves(child)) return false;
            return true;
        },
        else => return false,
    }
}

fn serializeZeroPercentMath(expression: *const math.Expression, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    if (!expression.computed or !hasOnlyAbsoluteAndZeroPercentLeaves(expression.root)) return false;
    const resolved = try expression.compute(allocator, .{ .percentage_basis = 0 });
    defer resolved.unref();
    try resolved.serialize(out, allocator);
    return true;
}

pub fn serializePerspectiveOrigin(position: *const Position, has_box: bool, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (!has_box or position.data != .computed) return position.serialize(out, allocator);
    for (position.data.computed, 0..) |offset, i| {
        if (i != 0) try out.append(allocator, ' ');
        if (offset.value == .length and offset.value.length.unit == .percent) {
            const percent = if (offset.complement) 100 - offset.value.length.value else offset.value.length.value;
            if (percent == 0) {
                try out.appendSlice(allocator, "0px");
                continue;
            }
        }
        // Position.compute has already expressed calculation complements
        // from the start edge. Literal end-edge offsets retain their flag.
        if (!offset.complement and offset.value == .calculation and
            try serializeZeroPercentMath(offset.value.calculation, out, allocator)) continue;
        try offset.serialize(out, allocator);
    }
}

fn consumePart(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Part {
    const token = stream.peek();
    if (token.token_type == .ident) {
        for ([_]OriginKeyword{ .left, .right, .top, .bottom, .center }) |keyword| {
            if (tokens.nameEql(token.value, keyword.name())) {
                _ = stream.next();
                return .{ .keyword = keyword };
            }
        }
    }
    return .{ .number = try Number.consume(options, stream, .{ .kind = .length_percentage }, true) orelse return null };
}

pub fn consumeOrigin(options: properties.ParseOptions, stream: *Stream) Allocator.Error!?Value {
    // Transforms 1 §4: one/two XY parts, then an optional length Z. A
    // numerical part fixes XY order; only two keywords can be reordered.
    var parts: [2]Part = undefined;
    var count: usize = 0;
    defer for (parts[0..count]) |part| part.unref();
    while (count < 2) {
        parts[count] = try consumePart(options, stream) orelse break;
        count += 1;
    }
    if (count == 0) return null;
    var xy = [2]Part{ .{ .keyword = .center }, .{ .keyword = .center } };
    if (count == 1) {
        xy[if (parts[0].permitsAxis(true)) 0 else 1] = parts[0];
    } else if (parts[0].permitsAxis(true) and parts[1].permitsAxis(false)) {
        xy = parts;
    } else if (parts[0] == .keyword and parts[1] == .keyword and parts[1].permitsAxis(true) and parts[0].permitsAxis(false)) {
        xy = .{ parts[1], parts[0] };
    } else return null;
    var z: ?Number = null;
    defer if (z) |number| number.unref();
    if (count == 2 and !stream.atEnd()) z = try Number.consume(options, stream, .{ .kind = .length }, true) orelse return null;
    const result = try options.allocator.create(Origin);
    result.* = .{ .allocator = options.allocator, .xy = xy, .z = z };
    count = 0;
    z = null; // All references move into the origin.
    return .{ .transform_origin = result };
}

const Matrix = [16]f64;
fn identity() Matrix {
    return .{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 };
}
fn multiply(left: Matrix, right: Matrix) Matrix {
    var result: Matrix = .{0} ** 16;
    for (0..4) |column| for (0..4) |row| {
        for (0..4) |k| result[column * 4 + row] += left[k * 4 + row] * right[column * 4 + k];
    };
    return result;
}

/// Q55–57: compose each operation on its affected terms. Design references:
/// Chromium ui/gfx/geometry/{transform.cc,matrix44.cc}. Generic matrix
/// concatenation deliberately keeps zero products, including infinity * 0.
fn compose(result: *Matrix, function: functions.Function, next: Matrix) void {
    switch (function.kind) {
        .scale, .scaleX, .scaleY, .scaleZ, .scale3d => {
            const columns: []const usize = switch (function.kind) {
                .scale => &.{ 0, 1 },
                .scaleX => &.{0},
                .scaleY => &.{1},
                .scaleZ => &.{2},
                .scale3d => &.{ 0, 1, 2 },
                else => unreachable,
            };
            for (columns) |column| for (0..4) |row| {
                result[column * 4 + row] *= next[column * 4 + column];
            };
        },
        .translate, .translateX, .translateY, .translateZ, .translate3d => {
            for (0..4) |row| {
                var offset = result[row] * next[12] + result[4 + row] * next[13];
                if (next[14] != 0) offset += result[8 + row] * next[14];
                result[12 + row] = offset + result[12 + row];
            }
        },
        .rotate, .rotateX, .rotateY, .rotateZ => {
            const pair: [2]usize = switch (function.kind) {
                .rotate, .rotateZ => .{ 0, 1 },
                .rotateX => .{ 1, 2 },
                .rotateY => .{ 0, 2 },
                else => unreachable,
            };
            const p = pair[0];
            const q = pair[1];
            if (next[p * 4 + p] == 1 and next[p * 4 + q] == 0) return;
            const left = result.*;
            for (0..4) |row| {
                result[p * 4 + row] = left[p * 4 + row] * next[p * 4 + p] + left[q * 4 + row] * next[p * 4 + q];
                result[q * 4 + row] = left[p * 4 + row] * next[q * 4 + p] + left[q * 4 + row] * next[q * 4 + q];
            }
        },
        .skew, .skewX, .skewY => {
            var nonzero_angle = false;
            for (function.arguments) |number| nonzero_angle = nonzero_angle or number.literal.value != 0;
            if (!nonzero_angle) return;
            const left = result.*;
            for (0..4) |row| {
                result[row] = left[row] + left[4 + row] * next[1];
                result[4 + row] = left[row] * next[4] + left[4 + row];
            }
        },
        .perspective => if (function.arguments.len != 0) {
            for (0..4) |row| result[8 + row] += result[12 + row] * next[11];
        },
        .rotate3d => {
            // Transforms 2 §12.2 / Q68: an axis that cannot be normalized
            // applies no operation, including no generic zero products.
            if (function.arguments[0].literal.value == 0 and function.arguments[1].literal.value == 0 and function.arguments[2].literal.value == 0) return;
            result.* = multiply(result.*, next);
        },
        .matrix, .matrix3d => result.* = multiply(result.*, next),
    }
}

/// Design reference: Chromium Matrix44 and SinCosDegrees. Exact quadrants
/// avoid inventing tiny rotations; skew intentionally uses the raw tangent.
/// Q68/Q69: rotate3d instead follows WebKit's TransformationMatrix::rotate3d,
/// Source/WebCore/platform/graphics/transforms/TransformationMatrix.cpp at
/// f9a95765137320ced3ec8b9586bf7abfaaae9abf (design, not copied code).
/// Keep raw angles, epsilon snapping and positive-principal construction;
/// generic multiplication and Crane's shared number precision then apply.
fn rotation(x_raw: f64, y_raw: f64, z_raw: f64, degrees_raw: f64, arbitrary_axis: bool) Matrix {
    const scale = @max(@abs(x_raw), @abs(y_raw), @abs(z_raw));
    if (scale == 0) return identity();
    var x = x_raw / scale;
    var y = y_raw / scale;
    var z = z_raw / scale;
    const norm = @sqrt(x * x + y * y + z * z);
    x /= norm;
    y /= norm;
    z /= norm;
    const degrees = if (arbitrary_axis) degrees_raw else @mod(degrees_raw, 360);
    const radians = degrees * (std.math.pi / 180.0);
    var sine = if (arbitrary_axis) @sin(radians) else if (degrees == 0 or degrees == 180) 0 else if (degrees == 90) 1 else if (degrees == 270) -1 else @sin(radians);
    var cosine = if (arbitrary_axis) @cos(radians) else if (degrees == 90 or degrees == 270) 0 else if (degrees == 0) 1 else if (degrees == 180) -1 else @cos(radians);
    if (arbitrary_axis) {
        if (@abs(sine) < std.math.floatEps(f64)) sine = 0;
        if (@abs(cosine) < std.math.floatEps(f64)) cosine = 0;
        if (x == 1) return principalRotation(0, sine, cosine);
        if (y == 1) return principalRotation(1, sine, cosine);
        if (z == 1) return principalRotation(2, sine, cosine);
    }
    const complement = 1 - cosine;
    return .{
        cosine + x * x * complement,   y * x * complement + z * sine, z * x * complement - y * sine, 0,
        x * y * complement - z * sine, cosine + y * y * complement,   z * y * complement + x * sine, 0,
        x * z * complement + y * sine, y * z * complement - x * sine, cosine + z * z * complement,   0,
        0,                             0,                             0,                             1,
    };
}

fn principalRotation(axis: usize, sine: f64, cosine: f64) Matrix {
    const pairs = [3][2]usize{ .{ 1, 2 }, .{ 0, 2 }, .{ 0, 1 } };
    const p = pairs[axis][0];
    const q = pairs[axis][1];
    const oriented_sine = if (axis == 1) -sine else sine;
    var result = identity();
    result[p * 4 + p] = cosine;
    result[q * 4 + q] = cosine;
    result[p * 4 + q] = oriented_sine;
    result[q * 4 + p] = -oriented_sine;
    return result;
}

fn matrixFor(function: functions.Function) ?Matrix {
    var arguments: [16]f64 = undefined;
    for (function.arguments, 0..) |number, i| {
        if (number != .literal) return null;
        const literal = number.literal;
        arguments[i] = switch (literal.unit) {
            .number, .px, .deg => literal.value,
            .percent => if (literal.value == 0) 0 else return null,
            else => return null,
        };
    }
    const a = arguments[0..function.arguments.len];
    var result = identity();
    // Transforms 1 §12 / Transforms 2 §16, column-major coordinates.
    switch (function.kind) {
        .matrix => for ([_]usize{ 0, 1, 4, 5, 12, 13 }, a) |index, number| {
            result[index] = number;
        },
        .matrix3d => @memcpy(&result, a),
        .translate => {
            result[12] = a[0];
            if (a.len == 2) result[13] = a[1];
        },
        .translateX => result[12] = a[0],
        .translateY => result[13] = a[0],
        .translateZ => result[14] = a[0],
        .translate3d => @memcpy(result[12..15], a),
        .scale => {
            result[0] = a[0];
            result[5] = if (a.len == 2) a[1] else a[0];
        },
        .scaleX => result[0] = a[0],
        .scaleY => result[5] = a[0],
        .scaleZ => result[10] = a[0],
        .scale3d => {
            result[0] = a[0];
            result[5] = a[1];
            result[10] = a[2];
        },
        .rotate, .rotateZ => return rotation(0, 0, 1, a[0], false),
        .rotateX => return rotation(1, 0, 0, a[0], false),
        .rotateY => return rotation(0, 1, 0, a[0], false),
        .rotate3d => return rotation(a[0], a[1], a[2], a[3], true),
        .skew => {
            result[4] = @tan(a[0] * (std.math.pi / 180.0));
            if (a.len == 2) result[1] = @tan(a[1] * (std.math.pi / 180.0));
        },
        .skewX => result[4] = @tan(a[0] * (std.math.pi / 180.0)),
        .skewY => result[1] = @tan(a[0] * (std.math.pi / 180.0)),
        // Transforms 2 §12.3: the used depth is at least 1px. none is
        // infinity and therefore leaves the identity matrix unchanged.
        .perspective => if (a.len != 0) {
            result[11] = -1 / @max(a[0], 1);
        },
    }
    return result;
}
