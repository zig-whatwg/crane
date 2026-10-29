//! CSS Typed OM numeric graphs through generated interfaces and existing CSS trees.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const css = @import("css");
const engine = @import("engine");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const math = css.math_values;
const numeric = css.typed_om.numeric;
const ops = css.typed_om.numeric_ops;
const ObjectLink = @import("rules.zig").ObjectLink;
const objects = @import("objects.zig");

/// Each immutable holder's own implementation owns this storage. Links
/// guard stale native addresses; traced wrapper edges supply reachability.
pub const NumericLinks = struct { values: []ObjectLink };

fn numericSlot(index: usize, buffer: *[64]u8) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "TypedOM:numeric:{d}", .{index}) catch unreachable };
}

pub fn numericLinks(instance: *runtime.Instance, values: []const *runtime.Instance) !NumericLinks {
    const links = try instance.ctx.allocator.alloc(ObjectLink, values.len);
    errdefer instance.ctx.allocator.free(links);
    for (links, values) |*link, value| {
        if (value.stateAs(interfaces.CSSNumericValue.State) == null and value.stateAs(interfaces.CSSNumericArray.State) == null) return error.TypeError;
        link.* = .{};
        link.set(value);
    }
    return .{ .values = links };
}

/// Publish after the owning impl installs its complete native state. No
/// fallible native allocation follows this step of construction.
pub fn traceNumericLinks(instance: *runtime.Instance, values: []const *runtime.Instance) void {
    for (values, 0..) |value, index| {
        var buffer: [64]u8 = undefined;
        objects.keepFrom(instance, value, numericSlot(index, &buffer));
    }
}

pub fn dropNumericLinks(instance: *runtime.Instance, links: NumericLinks) void {
    for (0..links.values.len) |index| {
        var buffer: [64]u8 = undefined;
        engine.forgetTracedChild(instance, numericSlot(index, &buffer));
    }
    instance.ctx.allocator.free(links.values);
}

pub fn numericLink(links: NumericLinks, index: usize) !*runtime.Instance {
    if (index >= links.values.len) return error.RangeError;
    return links.values[index].get() orelse error.InvalidStateError;
}

pub fn numericType(value: *runtime.Instance) !math.Type {
    const dictionary = try interfaces.CSSNumericValue.call_type(value);
    var result: math.Type = .{};
    inline for (@typeInfo(math.Base).@"enum".fields) |field| {
        const power = @field(dictionary, field.name) orelse 0;
        result.powers[field.value] = power; // Q84: the shared exponent is WebIDL long.
    }
    if (dictionary.percentHint) |hint| result.hint = std.meta.stringToEnum(math.Base, @import("enums").CSSNumericBaseType.idl_values[@intFromEnum(hint)]) orelse return error.TypeError;
    return result;
}

pub fn numericDictionary(value: math.Type) dictionaries.CSSNumericType {
    var result: dictionaries.CSSNumericType = .{};
    inline for (@typeInfo(math.Base).@"enum".fields) |field| {
        const power = value.powers[field.value];
        if (power != 0) @field(result, field.name) = power;
    }
    if (value.hint) |hint| result.percentHint = @enumFromInt(@intFromEnum(hint));
    return result;
}

pub fn numericKind(value: *runtime.Instance) !ops.Kind {
    inline for (.{
        .{ interfaces.CSSUnitValue, ops.Kind.unit },      .{ interfaces.CSSMathSum, ops.Kind.sum },
        .{ interfaces.CSSMathProduct, ops.Kind.product }, .{ interfaces.CSSMathNegate, ops.Kind.negate },
        .{ interfaces.CSSMathInvert, ops.Kind.invert },   .{ interfaces.CSSMathMin, ops.Kind.min },
        .{ interfaces.CSSMathMax, ops.Kind.max },         .{ interfaces.CSSMathClamp, ops.Kind.clamp },
    }) |entry| if (value.stateAs(entry[0].State) != null) return entry[1];
    return error.TypeError;
}

fn valuesArray(value: *runtime.Instance, kind: ops.Kind) !*runtime.Instance {
    return switch (kind) {
        .sum => interfaces.CSSMathSum.get_values(value),
        .product => interfaces.CSSMathProduct.get_values(value),
        .min => interfaces.CSSMathMin.get_values(value),
        .max => interfaces.CSSMathMax.get_values(value),
        else => error.TypeError,
    };
}

pub const NumericReader = struct {
    pub fn view(_: @This(), id: usize) !ops.View {
        const value: *runtime.Instance = @ptrFromInt(id);
        const kind = try numericKind(value);
        if (kind == .unit) {
            const name = try interfaces.CSSUnitValue.get_unit(value);
            defer value.ctx.allocator.free(name);
            return .{ .kind = kind, .number = .{
                .value = try interfaces.CSSUnitValue.get_value(value),
                .unit = numeric.parseUnit(name) orelse return error.TypeError,
            } };
        }
        return .{ .kind = kind, .count = switch (kind) {
            .unit => unreachable,
            .negate, .invert => 1,
            .clamp => 3,
            else => try interfaces.CSSNumericArray.get_length(try valuesArray(value, kind)),
        } };
    }

    pub fn child(_: @This(), id: usize, index: usize) !usize {
        const value: *runtime.Instance = @ptrFromInt(id);
        const child_value = switch (try numericKind(value)) {
            .negate => try interfaces.CSSMathNegate.get_value(value),
            .invert => try interfaces.CSSMathInvert.get_value(value),
            .clamp => switch (index) {
                0 => try interfaces.CSSMathClamp.get_lower(value),
                1 => try interfaces.CSSMathClamp.get_value(value),
                2 => try interfaces.CSSMathClamp.get_upper(value),
                else => return error.RangeError,
            },
            .unit => return error.TypeError,
            else => |kind| try interfaces.CSSNumericArray.call_getter(try valuesArray(value, kind), @intCast(index)),
        };
        return @intFromPtr(child_value);
    }
};

/// §4.3.1 rectification, with temporary roots only while a new parent is
/// under construction. Every generated unit is released on failure too.
pub const NumericArguments = struct {
    ctx: runtime.Context,
    values: std.ArrayList(*runtime.Instance) = .empty,
    held: std.ArrayList(engine.Owned) = .empty,

    pub fn deinit(self: *NumericArguments) void {
        for (self.held.items) |held| held.release();
        self.held.deinit(self.ctx.allocator);
        self.values.deinit(self.ctx.allocator);
    }

    pub fn append(self: *NumericArguments, input: typedefs.CSSNumberish) !void {
        try self.values.ensureUnusedCapacity(self.ctx.allocator, 1);
        try self.held.ensureUnusedCapacity(self.ctx.allocator, 1);
        const value = switch (input) {
            .double => |number| try interfaces.CSSUnitValue.call_constructor(self.ctx, number, "number"),
            .cssnumeric_value => |value| value,
        };
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer if (input == .double) runtime.Instance.releaseIfUnwrapped(value, generation);
        if (value.stateAs(interfaces.CSSNumericValue.State) == null) return error.TypeError;
        const held = try engine.retainValue(value.ctx, .{ .instance = value });
        self.held.appendAssumeCapacity(held);
        self.values.appendAssumeCapacity(value);
    }

    pub fn appendAll(self: *NumericArguments, inputs: []const typedefs.CSSNumberish) !void {
        for (inputs) |value| try self.append(value);
    }
};

/// Construct without arithmetic simplification: new CSSMathSum(1,2) keeps
/// both original children. The public arithmetic methods simplify separately.
pub fn constructMath(ctx: runtime.Context, kind: ops.Kind, inputs: []const typedefs.CSSNumberish) !*runtime.Instance {
    if (inputs.len == 0) return error.SyntaxError;
    var args: NumericArguments = .{ .ctx = ctx };
    defer args.deinit();
    try args.appendAll(inputs);
    var typ = try numericType(args.values.items[0]);
    if (kind == .invert) typ = numeric.invertType(typ) catch return error.TypeError;
    for (args.values.items[1..]) |value| {
        const next = try numericType(value);
        typ = (if (kind == .product) numeric.multiplyTypes(typ, next) else numeric.addTypes(typ, next)) catch return error.TypeError;
    }
    if (kind == .negate or kind == .invert or kind == .clamp) {
        const construction = .{ .numeric_type = typ, .numeric_operands = args.values.items };
        return switch (kind) {
            .negate => interfaces.CSSMathNegate.initWith(ctx.allocator, ctx, construction),
            .invert => interfaces.CSSMathInvert.initWith(ctx.allocator, ctx, construction),
            .clamp => interfaces.CSSMathClamp.initWith(ctx.allocator, ctx, construction),
            else => unreachable,
        };
    }
    const array = try interfaces.CSSNumericArray.initWith(ctx.allocator, ctx, .{ .numeric_operands = args.values.items });
    const generation = runtime.SlabAllocator.generationOf(array);
    errdefer runtime.Instance.releaseIfUnwrapped(array, generation);
    const held = try engine.retainValue(ctx, .{ .instance = array });
    defer held.release();
    const construction = .{ .numeric_type = typ, .numeric_operands = @as([]const *runtime.Instance, &.{array}) };
    return switch (kind) {
        .sum => interfaces.CSSMathSum.initWith(ctx.allocator, ctx, construction),
        .product => interfaces.CSSMathProduct.initWith(ctx.allocator, ctx, construction),
        .min => interfaces.CSSMathMin.initWith(ctx.allocator, ctx, construction),
        .max => interfaces.CSSMathMax.initWith(ctx.allocator, ctx, construction),
        else => error.TypeError,
    };
}

pub fn serializeNumeric(instance: *runtime.Instance) ![]u8 {
    return ops.serialize(instance.ctx.allocator, @intFromPtr(instance), NumericReader{});
}

pub fn numericEquals(instance: *runtime.Instance, inputs: []const typedefs.CSSNumberish) !bool {
    var args: NumericArguments = .{ .ctx = instance.ctx };
    defer args.deinit();
    try args.appendAll(inputs);
    for (args.values.items) |value| if (!try ops.equals(instance.ctx.allocator, @intFromPtr(instance), @intFromPtr(value), NumericReader{})) return false;
    return true;
}

fn unitObject(ctx: runtime.Context, value: math.Numeric) !*runtime.Instance {
    return interfaces.CSSUnitValue.call_constructor(ctx, value.value, @tagName(value.unit));
}

fn transformed(ctx: runtime.Context, value: *runtime.Instance, invert: bool) !*runtime.Instance {
    const view = try NumericReader.view(.{}, @intFromPtr(value));
    if (view.kind == .unit and (!invert or view.number.unit == .number)) {
        if (invert and view.number.value == 0) return error.RangeError;
        return unitObject(ctx, .{ .value = if (invert) 1 / view.number.value else -view.number.value, .unit = view.number.unit });
    }
    if (view.kind == (if (invert) ops.Kind.invert else ops.Kind.negate))
        return @ptrFromInt(try NumericReader.child(.{}, @intFromPtr(value), 0));
    return constructMath(ctx, if (invert) .invert else .negate, &.{.{ .cssnumeric_value = value }});
}

fn appendProduced(args: *NumericArguments, value: *runtime.Instance) !void {
    const generation = runtime.SlabAllocator.generationOf(value);
    errdefer runtime.Instance.releaseIfUnwrapped(value, generation);
    try args.append(.{ .cssnumeric_value = value });
}

/// Arithmetic methods, §4.3.1: flatten only the receiver when it has the
/// requested operation. Preserve object identity for every unfurled child.
pub fn arithmetic(instance: *runtime.Instance, kind: ops.Kind, inputs: []const typedefs.CSSNumberish, inverse: bool) !*runtime.Instance {
    const ctx = instance.ctx;
    var args: NumericArguments = .{ .ctx = ctx };
    defer args.deinit();
    const own_view = try NumericReader.view(.{}, @intFromPtr(instance));
    if (own_view.kind == kind) {
        for (0..own_view.count) |index| try args.append(.{ .cssnumeric_value = @ptrFromInt(try NumericReader.child(.{}, @intFromPtr(instance), index)) });
    } else try args.append(.{ .cssnumeric_value = instance });
    var rhs: NumericArguments = .{ .ctx = ctx };
    defer rhs.deinit();
    try rhs.appendAll(inputs);
    for (rhs.values.items) |value| {
        if (inverse) try appendProduced(&args, try transformed(ctx, value, kind == .product)) else try args.append(.{ .cssnumeric_value = value });
    }
    var all_units = true;
    var folded: math.Numeric = .{ .value = if (kind == .product) 1 else 0, .unit = .number };
    var dimensional: usize = 0;
    for (args.values.items, 0..) |value, index| {
        const view = try NumericReader.view(.{}, @intFromPtr(value));
        if (view.kind != .unit) {
            all_units = false;
            break;
        }
        const next = view.number;
        if (kind == .product) {
            if (next.unit != .number) {
                dimensional += 1;
                folded.unit = next.unit;
            }
            if (dimensional > 1) {
                all_units = false;
                break;
            }
            folded.value *= next.value;
        } else if (index == 0) {
            folded = next;
        } else {
            if (folded.unit != next.unit) {
                all_units = false;
                break;
            }
            folded.value = switch (kind) {
                .sum => folded.value + next.value,
                .min => ops.minimum(folded.value, next.value),
                .max => ops.maximum(folded.value, next.value),
                else => unreachable,
            };
        }
    }
    if (all_units) return unitObject(ctx, folded);
    const numberish = try ctx.allocator.alloc(typedefs.CSSNumberish, args.values.items.len);
    defer ctx.allocator.free(numberish);
    for (numberish, args.values.items) |*input, value| input.* = .{ .cssnumeric_value = value };
    return constructMath(ctx, kind, numberish);
}

pub fn numericTo(instance: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const unit = numeric.parseUnit(name) orelse return error.SyntaxError;
    var sum = ops.sumValue(instance.ctx.allocator, @intFromPtr(instance), NumericReader{}) catch |err| switch (err) {
        error.Invalid => return error.TypeError,
        else => return err,
    };
    defer sum.deinit(instance.ctx.allocator);
    if (sum.items.len != 1) return error.TypeError;
    const value = sum.items[0].asNumeric() catch return error.TypeError;
    return unitObject(instance.ctx, ops.convert(value, unit) catch return error.TypeError);
}

pub fn numericToSum(instance: *runtime.Instance, names: []const runtime.USVString) !*runtime.Instance {
    const ctx = instance.ctx;
    const units = try ctx.allocator.alloc(math.Unit, names.len);
    defer ctx.allocator.free(units);
    for (units, names) |*unit, name| unit.* = numeric.parseUnit(name) orelse return error.SyntaxError;
    var sum = ops.sumValue(ctx.allocator, @intFromPtr(instance), NumericReader{}) catch |err| switch (err) {
        error.Invalid => return error.TypeError,
        else => return err,
    };
    defer sum.deinit(ctx.allocator);
    var values: std.ArrayList(math.Numeric) = .empty;
    defer values.deinit(ctx.allocator);
    for (sum.items) |item| try values.append(ctx.allocator, item.asNumeric() catch return error.TypeError);
    var result: NumericArguments = .{ .ctx = ctx };
    defer result.deinit();
    if (units.len == 0) {
        const Order = struct {
            fn less(_: void, a: math.Numeric, b: math.Numeric) bool {
                return std.mem.order(u8, @tagName(a.unit), @tagName(b.unit)) == .lt;
            }
        };
        std.mem.sort(math.Numeric, values.items, {}, Order.less);
        for (values.items) |value| try appendProduced(&result, try unitObject(ctx, value));
    } else {
        for (units) |unit| {
            var total: f64 = 0;
            var index: usize = 0;
            while (index < values.items.len) {
                if (ops.convert(values.items[index], unit)) |converted| {
                    total += converted.value;
                    _ = values.orderedRemove(index);
                } else |_| index += 1;
            }
            try appendProduced(&result, try unitObject(ctx, .{ .value = total, .unit = unit }));
        }
        if (values.items.len != 0) return error.TypeError;
    }
    const inputs = try ctx.allocator.alloc(typedefs.CSSNumberish, result.values.items.len);
    defer ctx.allocator.free(inputs);
    for (inputs, result.values.items) |*input, value| input.* = .{ .cssnumeric_value = value };
    return constructMath(ctx, .sum, inputs);
}

/// §5.6: create native Typed OM objects from the existing simplified tree.
/// Temporary roots cover every completed object until the result is handed
/// back; the returned holders keep only their traced child links.
pub fn reifyParsed(ctx: runtime.Context, root: *const math.Node) !*runtime.Instance {
    const reader: ops.ParsedReader = .{};
    const Frame = struct { id: usize, view: ops.View, index: usize = 0, base: usize };
    var frames: std.ArrayList(Frame) = .empty;
    defer frames.deinit(ctx.allocator);
    var results: std.ArrayList(*runtime.Instance) = .empty;
    defer results.deinit(ctx.allocator);
    var owned: NumericArguments = .{ .ctx = ctx };
    defer owned.deinit();
    try frames.append(ctx.allocator, .{ .id = @intFromPtr(root), .view = try reader.view(@intFromPtr(root)), .base = 0 });
    while (frames.items.len != 0) {
        const top = &frames.items[frames.items.len - 1];
        if (top.index < top.view.count) {
            const child = try reader.child(top.id, top.index);
            top.index += 1;
            try frames.append(ctx.allocator, .{ .id = child, .view = try reader.view(child), .base = results.items.len });
            continue;
        }
        const frame = frames.pop().?;
        try results.ensureUnusedCapacity(ctx.allocator, 1);
        const object = if (frame.view.kind == .unit)
            try unitObject(ctx, frame.view.number)
        else blk: {
            const inputs = try ctx.allocator.alloc(typedefs.CSSNumberish, results.items.len - frame.base);
            defer ctx.allocator.free(inputs);
            for (inputs, results.items[frame.base..]) |*input, value| input.* = .{ .cssnumeric_value = value };
            break :blk try constructMath(ctx, frame.view.kind, inputs);
        };
        try appendProduced(&owned, object);
        results.shrinkRetainingCapacity(frame.base);
        results.appendAssumeCapacity(object);
    }
    return results.items[0];
}

pub fn parseNumeric(ctx: runtime.Context, text: []const u8) !*runtime.Instance {
    const expression = try math.parseNumeric(ctx.allocator, text) orelse return error.SyntaxError;
    defer expression.deinit();
    return reifyParsed(ctx, expression.root) catch |err| switch (err) {
        error.Invalid => error.SyntaxError,
        else => err,
    };
}

/// §6.1: the pure traversal reads the live slots through their owners.
/// Getter strings are owned, and released after appending each segment.
pub fn serializeUnparsed(instance: *runtime.Instance) ![]u8 {
    const Reader = struct {
        string_allocator: std.mem.Allocator,

        pub fn length(_: *@This(), id: usize) !usize {
            return try interfaces.CSSUnparsedValue.get_length(@ptrFromInt(id));
        }

        pub fn segment(self: *@This(), id: usize, index: usize) !css.typed_om.unparsed.Segment {
            const value: *runtime.Instance = @ptrFromInt(id);
            self.string_allocator = value.ctx.allocator;
            const item = try interfaces.CSSUnparsedValue.call_getter(value, @intCast(index));
            return switch (item) {
                .usvstring => |string| .{ .string = string },
                .cssvariable_reference_value => |reference| blk: {
                    self.string_allocator = reference.ctx.allocator;
                    const name = try interfaces.CSSVariableReferenceValue.get_variable(reference);
                    errdefer reference.ctx.allocator.free(name);
                    const fallback = try interfaces.CSSVariableReferenceValue.get_fallback(reference);
                    break :blk .{ .variable = .{ .name = name, .fallback = if (fallback) |child| @intFromPtr(child) else null } };
                },
            };
        }

        pub fn release(self: *@This(), item: css.typed_om.unparsed.Segment) void {
            // The iterative reader has at most one outstanding segment;
            // its string may belong to another realm's allocator.
            self.string_allocator.free(switch (item) {
                .string => |string| string,
                .variable => |variable| variable.name,
            });
        }
    };
    var reader: Reader = .{ .string_allocator = instance.ctx.allocator };
    return css.typed_om.unparsed.serialize(instance.ctx.allocator, @intFromPtr(instance), &reader);
}
