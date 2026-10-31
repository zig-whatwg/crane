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
    inline for (@typeInfo(math.Base).@"enum".field_names, @typeInfo(math.Base).@"enum".field_values) |field_name, field_value| {
        const power = @field(dictionary, field_name) orelse 0;
        result.powers[field_value] = power; // Q84: the shared exponent is WebIDL long.
    }
    if (dictionary.percentHint) |hint| result.hint = std.meta.stringToEnum(math.Base, @import("enums").CSSNumericBaseType.idl_values[@intFromEnum(hint)]) orelse return error.TypeError;
    return result;
}

pub fn numericDictionary(value: math.Type) dictionaries.CSSNumericType {
    var result: dictionaries.CSSNumericType = .{};
    inline for (@typeInfo(math.Base).@"enum".field_names, @typeInfo(math.Base).@"enum".field_values) |field_name, field_value| {
        const power = value.powers[field_value];
        if (power != 0) @field(result, field_name) = power;
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

const properties = css.properties;
const Native = css.typed_om.native_values;
const Registered = css.typed_om.registered_values.Registered;

/// Construction inputs are borrowed. The CSSStyleValue owner takes its own
/// native references; no map, element, or declaration wrapper is retained.
pub const NativeInit = union(enum) {
    ordinary: struct {
        property: properties.Property,
        assignments: []const properties.Assignment,
        computed: bool,
        animation_index: ?usize = null,
    },
    registered: struct { owner: *Registered, property: []const u8, index: ?usize },
};

pub const NativeValue = union(enum) {
    ordinary: Native.Opaque,
    registered: struct { owner: *Registered, property: []u8, index: ?usize },

    pub fn init(allocator: std.mem.Allocator, input: NativeInit) !NativeValue {
        return switch (input) {
            .ordinary => |v| .{ .ordinary = try Native.Opaque.init(allocator, v.property, v.assignments, v.computed, v.animation_index) },
            .registered => |v| blk: {
                const name = try allocator.dupe(u8, v.property);
                v.owner.retain();
                break :blk .{ .registered = .{ .owner = v.owner, .property = name, .index = v.index } };
            },
        };
    }

    pub fn deinit(self: *NativeValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .ordinary => |*opaque_value| opaque_value.deinit(),
            .registered => |v| {
                v.owner.release();
                allocator.free(v.property);
            },
        }
    }

    pub fn serialize(self: *const NativeValue, allocator: std.mem.Allocator) ![]u8 {
        switch (self.*) {
            .ordinary => |opaque_value| return opaque_value.serialize(allocator),
            .registered => |v| {
                var text: std.ArrayList(u8) = .empty;
                defer text.deinit(allocator);
                if (v.index) |index| {
                    // A read-only single-item view borrows from the retained
                    // owner. It is never deinitialized as a separate owner.
                    const view: css.syntax_values.Value = .{ .allocator = allocator, .data = .{ .single = v.owner.item(index) orelse return error.InvalidStateError } };
                    try view.serialize(&text, allocator);
                } else try v.owner.value.serialize(&text, allocator);
                return text.toOwnedSlice(allocator);
            },
        }
    }
};

/// One call's produced platform values stay alive until the JS result array
/// or enclosing native holder has installed its edges. No permanent root.
pub const Reified = struct {
    ctx: runtime.Context,
    values: std.ArrayList(*runtime.Instance) = .empty,
    holds: std.ArrayList(engine.Owned) = .empty,

    pub fn deinit(self: *Reified) void {
        for (self.holds.items) |hold| hold.release();
        self.holds.deinit(self.ctx.allocator);
        self.values.deinit(self.ctx.allocator);
    }

    pub fn appendNew(self: *Reified, value: *runtime.Instance) !void {
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer runtime.Instance.releaseIfUnwrapped(value, generation);
        try self.values.ensureUnusedCapacity(self.ctx.allocator, 1);
        try self.holds.ensureUnusedCapacity(self.ctx.allocator, 1);
        const hold = try engine.retainValue(value.ctx, .{ .instance = value });
        self.values.appendAssumeCapacity(value);
        self.holds.appendAssumeCapacity(hold);
    }

    pub fn array(self: *const Reified) !runtime.JSValue {
        const result = try engine.createSequenceOfPlatformObjects(self.ctx, self.values.items);
        return result.take();
    }
};

fn keywordObject(ctx: runtime.Context, name: []const u8) !*runtime.Instance {
    return interfaces.CSSKeywordValue.initWith(ctx.allocator, ctx, .{ .keyword_value = name });
}

fn opaqueObject(ctx: runtime.Context, input: NativeInit, image_value: bool) !*runtime.Instance {
    return if (image_value)
        interfaces.CSSImageValue.initWith(ctx.allocator, ctx, .{ .native_style_value = input })
    else
        interfaces.CSSStyleValue.initWith(ctx.allocator, ctx, .{ .native_style_value = input });
}

fn ordinaryOpaque(ctx: runtime.Context, property: properties.Property, assignments: []const properties.Assignment, computed: bool, animation_index: ?usize, image_value: bool) !*runtime.Instance {
    return opaqueObject(ctx, .{ .ordinary = .{
        .property = property,
        .assignments = assignments,
        .computed = computed,
        .animation_index = animation_index,
    } }, image_value);
}

fn stringUnparsed(ctx: runtime.Context, text: []const u8) !*runtime.Instance {
    const parts = [_]typedefs.CSSUnparsedSegment{.{ .usvstring = text }};
    return interfaces.CSSUnparsedValue.initWith(ctx.allocator, ctx, .{ .unparsed_segments = if (text.len == 0) @as([]const typedefs.CSSUnparsedSegment, &.{}) else &parts });
}

/// §5.4: the pure pending graph allocates child lists after their parents;
/// reverse construction is therefore iterative and children are ready first.
pub fn reifyPending(ctx: runtime.Context, pending: *const css.pending_values.Pending) !*runtime.Instance {
    const graph = try css.typed_om.pending_reification.fromNodes(ctx.allocator, pending.nodes);
    defer graph.deinit();
    const lists = try ctx.allocator.alloc(*runtime.Instance, graph.lists.len);
    defer ctx.allocator.free(lists);
    var made: Reified = .{ .ctx = ctx };
    defer made.deinit();
    var index = lists.len;
    while (index != 0) {
        index -= 1;
        const parts = try ctx.allocator.alloc(typedefs.CSSUnparsedSegment, graph.lists[index].len);
        defer ctx.allocator.free(parts);
        for (graph.lists[index], parts) |part, *dest| {
            dest.* = switch (part) {
                .string => |text| .{ .usvstring = text },
                .variable => |variable| blk: {
                    const reference = try interfaces.CSSVariableReferenceValue.initWith(ctx.allocator, ctx, .{
                        .variable_name = variable.name,
                        .variable_fallback = if (variable.fallback) |child| @as(?*runtime.Instance, lists[child]) else null,
                    });
                    try made.appendNew(reference);
                    break :blk .{ .cssvariable_reference_value = reference };
                },
            };
        }
        lists[index] = try interfaces.CSSUnparsedValue.initWith(ctx.allocator, ctx, .{ .unparsed_segments = parts });
        try made.appendNew(lists[index]);
    }
    return lists[0];
}

pub fn reifyCustom(ctx: runtime.Context, value: css.custom_properties.Specified) !*runtime.Instance {
    return switch (value) {
        .css_wide => |wide| stringUnparsed(ctx, wide.name()),
        .text => |text| stringUnparsed(ctx, text.bytes),
        .pending => |pending| reifyPending(ctx, pending),
    };
}

/// §5.2 step 1 also applies to a numeric component inside a retained list.
/// The owning caller preserves the whole property's native value on fallback.
fn canReifyNumber(number: css.numeric_values.Number) bool {
    return switch (number) {
        .literal => true,
        .calculation => |expression| ops.ParsedReader.supports(expression.root),
    };
}

fn reifyNumber(ctx: runtime.Context, number: css.numeric_values.Number) !*runtime.Instance {
    return switch (number) {
        .literal => |literal| unitObject(ctx, literal),
        .calculation => |expression| reifyExpression(ctx, expression),
    };
}

fn reifyExpression(ctx: runtime.Context, expression: *const math.Expression) !*runtime.Instance {
    if (expression.computedNumber()) |number| return unitObject(ctx, number);
    if (expression.root.tag == .numeric) {
        const number = expression.root.numeric;
        const grammar = expression.grammar;
        // §3 create an internal representation; Q36/Q40: only syntactic
        // ranges and non-integral integers need a one-child sum wrapper.
        // Q81/Q83: a derived non-finite scalar also keeps the wrapper;
        // its literal Typed OM String is distinct from specified CSS.
        const outside = !std.math.isFinite(number.value) or (grammar.minimum_kind == .grammar and number.value < grammar.minimum) or
            (grammar.maximum_kind == .grammar and number.value > grammar.maximum) or
            (grammar.kind == .integer and number.value != @floor(number.value));
        if (outside) {
            var held: Reified = .{ .ctx = ctx };
            defer held.deinit();
            try held.appendNew(try unitObject(ctx, number));
            return constructMath(ctx, .sum, &.{.{ .cssnumeric_value = held.values.items[0] }});
        }
    }
    return reifyParsed(ctx, expression.root);
}

/// §2 steps 1–5: run the existing property parser once, then reify its
/// native assignments. This never parses a serializer's output.
pub fn parseStyleValues(ctx: runtime.Context, name: []const u8, text: []const u8) !Reified {
    const property = try propertyName(name);
    var context: style_engine.resource_loading.ParseContext = blk: {
        if (@import("../global_settings.zig").liveGlobalOf(ctx)) |window| {
            if (window.stateAs(interfaces.Window.State) != null) {
                const document = try interfaces.Window.get_document(window);
                break :blk try style_engine.resource_loading.inlineParseContext(document, ctx.allocator, false, text);
            }
        }
        break :blk .{ .parse = .{ .allocator = ctx.allocator } };
    };
    defer context.deinit();
    return parseWithContext(ctx, property, context.options(), text);
}

fn parseWithContext(ctx: runtime.Context, property: css.typed_om.property_names.Name, options: properties.ParseOptions, text: []const u8) !Reified {
    // Chrome 156 + Safari 27, Q65: string APIs retain the empty-input
    // TypeError; this does not change CSS Variables' declaration grammar.
    if (css.substitution.originalText(text).len == 0) return error.TypeError;
    var result: Reified = .{ .ctx = ctx };
    errdefer result.deinit();
    switch (property) {
        .custom => {
            // Properties and Values API §6: specified APIs ignore registrations.
            const value = try css.custom_properties.parse(options, text) orelse return error.TypeError;
            defer value.release();
            try result.appendNew(try reifyCustom(ctx, value));
        },
        .ordinary => |ordinary| {
            var assignments: std.ArrayList(properties.Assignment) = .empty;
            defer {
                for (assignments.items) |assignment| assignment.value.release();
                assignments.deinit(options.allocator);
            }
            if (!try properties.parseDeclaration(options, ordinary, text, &assignments)) return error.TypeError;
            try reifyAssignments(&result, ordinary, assignments.items, false);
        },
    }
    return result;
}

fn reifyAssignments(out: *Reified, property: properties.Property, assignments: []const properties.Assignment, computed: bool) !void {
    std.debug.assert(assignments.len != 0);
    const assigned = assignments[0].value;
    if (assigned == .css_wide) {
        try out.appendNew(try keywordObject(out.ctx, assigned.css_wide.name()));
        return;
    }
    // §5.3 overrides every property's ordinary grammar, including shorthands.
    if (assigned.value == .pending) {
        try out.appendNew(try reifyPending(out.ctx, assigned.value.pending));
        return;
    }
    if (property == .shorthand) {
        try out.appendNew(try ordinaryOpaque(out.ctx, property, assignments, computed, null, false));
        return;
    }
    const longhand = property.longhand;
    if (assigned.value == .layers) {
        for (assigned.value.layers.items) |value| try reifyComponent(out, longhand, value, computed);
    } else if (assigned.value == .animation_list) {
        const list = assigned.value.animation_list;
        // §5.2 step 1, Q124/Q126: unsupported math in any specified
        // component retains the whole property, before creating any items.
        // Ordinary computed values keep their existing reification rules.
        if (!computed) for (list.items.items) |item| {
            const supported = switch (item) {
                .number => |number| canReifyNumber(number),
                .range => |range| canReifyNumber(range.offset),
                else => true,
            };
            if (!supported) {
                try out.appendNew(try ordinaryOpaque(out.ctx, property, assignments, computed, null, false));
                return;
            }
        };
        for (list.items.items, 0..) |item, index| {
            const object = switch (item) {
                .keyword => |keyword| try keywordObject(out.ctx, keyword.name()),
                .number => |number| if (canReifyNumber(number))
                    try reifyNumber(out.ctx, number)
                else
                    try ordinaryOpaque(out.ctx, property, assignments, computed, index, false),
                .name => |name| if (css.keyframe_values.reservedName(name))
                    try ordinaryOpaque(out.ctx, property, assignments, computed, index, false)
                else
                    try keywordObject(out.ctx, name),
                .easing => |easing| if (easing.kind == .keyword)
                    try keywordObject(out.ctx, easing.keyword)
                else
                    try ordinaryOpaque(out.ctx, property, assignments, computed, index, false),
                .range => |range| if (range.name) |name| blk: {
                    // The owning serializer drops an unchanged default offset.
                    const offset = range.offset;
                    if (offset == .literal and offset.literal.unit == .percent and
                        offset.literal.value == (if (longhand == .animation_range_end) @as(f64, 100) else 0))
                        break :blk try keywordObject(out.ctx, name.name());
                    break :blk try ordinaryOpaque(out.ctx, property, assignments, computed, index, false);
                } else if (canReifyNumber(range.offset))
                    try reifyNumber(out.ctx, range.offset)
                else
                    try ordinaryOpaque(out.ctx, property, assignments, computed, index, false),
                .timeline => try ordinaryOpaque(out.ctx, property, assignments, computed, index, false),
            };
            try out.appendNew(object);
        }
    } else try reifyComponent(out, longhand, assigned.value, computed);
}

fn reifyComponent(out: *Reified, longhand: properties.Longhand, value: css.style_values.Value, computed: bool) !void {
    const assignments = [_]properties.Assignment{.{ .longhand = longhand, .value = .{ .value = value } }};
    const object = switch (css.typed_om.native_reification.shape(longhand, value)) {
        .keyword => |keyword| try keywordObject(out.ctx, keyword),
        .canonical_keyword => |native_value| blk: {
            var text: std.ArrayList(u8) = .empty;
            defer text.deinit(out.ctx.allocator);
            try properties.serializeValue(longhand, native_value, &text, out.ctx.allocator);
            break :blk try keywordObject(out.ctx, text.items);
        },
        .numeric => |number| try unitObject(out.ctx, number),
        .calculation => |expression| try reifyExpression(out.ctx, expression),
        .pending => |pending| try reifyPending(out.ctx, pending),
        .text_keywords => |text| blk: {
            if (try css.typed_om.text_keywords.classify(out.ctx.allocator, longhand, text)) |owned| {
                var keywords = owned;
                defer keywords.deinit();
                for (keywords.items) |keyword| try out.appendNew(try keywordObject(out.ctx, keyword));
                return;
            }
            break :blk try ordinaryOpaque(out.ctx, .{ .longhand = longhand }, &assignments, computed, null, false);
        },
        .image => try ordinaryOpaque(out.ctx, .{ .longhand = longhand }, &assignments, computed, null, true),
        .unsupported => try ordinaryOpaque(out.ctx, .{ .longhand = longhand }, &assignments, computed, null, false),
    };
    try out.appendNew(object);
}

/// Properties and Values API §6.2, Q56's explicit cold reconstruction.
fn reifyRegistered(out: *Reified, property: []const u8, definition: *const css.syntax_definitions.Definition, text: []const u8) !void {
    const owner = try css.typed_om.registered_values.parseComputed(.{ .allocator = out.ctx.allocator }, definition, text) orelse return error.InvalidStateError;
    defer owner.release();
    if (owner.value.data == .universal) {
        try out.appendNew(try stringUnparsed(out.ctx, owner.value.data.universal));
        return;
    }
    // A transform-list is one value, not repeated <transform-function>s.
    // Q32's routed hierarchy keeps this whole native representation meanwhile.
    if (owner.value.data == .list and owner.value.data.list.separator == .space and
        owner.value.data.list.items.len > 0 and owner.value.data.list.items[0] == .transform)
    {
        try out.appendNew(try opaqueObject(out.ctx, .{ .registered = .{ .owner = owner, .property = property, .index = null } }, false));
        return;
    }
    // §5.2 step 1, Q126: a computed registered list containing
    // unsupported math is one value associated with its whole property.
    for (0..owner.count()) |index| {
        const item = owner.item(index).?;
        if (item == .numeric and !canReifyNumber(item.numeric.number)) {
            try out.appendNew(try opaqueObject(out.ctx, .{ .registered = .{ .owner = owner, .property = property, .index = null } }, false));
            return;
        }
    }
    for (0..owner.count()) |index| {
        const item = owner.item(index).?;
        const object = switch (item) {
            .numeric => |number| try reifyNumber(out.ctx, number.number),
            .ident => |name| try keywordObject(out.ctx, name),
            .image => |image| try opaqueObject(out.ctx, .{ .registered = .{ .owner = owner, .property = property, .index = index } }, css.typed_om.native_reification.urlImage(image.value) != null),
            else => try opaqueObject(out.ctx, .{ .registered = .{ .owner = owner, .property = property, .index = index } }, false),
        };
        try out.appendNew(object);
    }
}

const style_hooks = @import("hooks.zig");
const style_engine = @import("engine.zig");
const inline_style = @import("inline_style.zig");
const element_style = @import("element_style.zig");
const Rule = @import("rules.zig").Rule;
const Block = css.declarations.DeclarationBlock;
const map_source_slot: engine.TracedSlot = .{ .name = "TypedOM:mapSource" };
const computed_map_slot: engine.TracedSlot = .{ .name = "TypedOM:computedStyleMap" };

pub const PropertyMap = struct {
    kind: enum { computed, inline_style, rule },
    owner: ObjectLink = .{},
    rule: ?*Rule = null,

    pub const Source = union(enum) { computed: *runtime.Instance, inline_style: *runtime.Instance, rule: *Rule };

    pub fn init(instance: *runtime.Instance, source: Source) !PropertyMap {
        var result: PropertyMap = .{ .kind = switch (source) {
            .computed => .computed,
            .inline_style => .inline_style,
            .rule => .rule,
        } };
        const owner = switch (source) {
            .computed, .inline_style => |element| element,
            .rule => |rule| try objects.ruleObject(rule, instance.ctx),
        };
        if (source == .rule) {
            source.rule.ref();
            result.rule = source.rule;
        }
        result.owner.set(owner);
        return result;
    }

    /// The owning impl installs its complete native state before publishing
    /// the approved map -> source edge. No native allocation follows.
    pub fn trace(self: *const PropertyMap, instance: *runtime.Instance) void {
        if (self.owner.get()) |owner| objects.keepFrom(instance, owner, map_source_slot);
    }

    pub fn deinit(self: *PropertyMap, instance: *runtime.Instance) void {
        // Identity links are weak. No owner/model is dereferenced at teardown.
        engine.forgetTracedChild(instance, map_source_slot);
        if (self.rule) |rule| rule.unref();
        self.rule = null;
        self.owner = .{};
    }

    pub fn block(self: *const PropertyMap) !?*Block {
        return switch (self.kind) {
            .computed => null,
            .rule => if (self.rule) |rule| rule.block() else null,
            .inline_style => if (self.owner.get()) |owner| inline_style.blockOf(owner) else null,
        };
    }

    pub fn computed(self: *const PropertyMap) !?*const css.computed_style.ComputedStyle {
        if (self.kind != .computed) return null;
        const owner = self.owner.get() orelse return null;
        if (!try style_engine.hasComputedStyle(owner)) return null;
        return style_engine.computedStyle(owner, null);
    }

    pub fn parseContext(self: *const PropertyMap, instance: *runtime.Instance, text: []const u8) !style_engine.resource_loading.ParseContext {
        if (self.kind == .inline_style) if (self.owner.get()) |owner| return inline_style.parseOptions(owner, text);
        if (self.rule) |rule| {
            if (rule.sheet()) |sheet| return style_engine.resource_loading.ParseContext.forSheet(sheet, instance, text);
            return .{ .parse = .{ .allocator = rule.allocator } };
        }
        return .{ .parse = .{ .allocator = instance.ctx.allocator } };
    }

    pub fn changed(self: *const PropertyMap) !void {
        switch (self.kind) {
            .computed => return error.NoModificationAllowedError,
            .rule => if (self.rule) |rule| if (rule.sheet()) |sheet| {
                sheet.changed();
            },
            .inline_style => if (self.owner.get()) |owner| try inline_style.updateStyleAttribute(owner),
        }
    }
};

pub fn computedMap(element: *runtime.Instance) !*runtime.Instance {
    const state = element_style.of(element) orelse return error.OutOfMemory;
    if (state.computed_map) |link| if (link.object.get()) |map| return map;
    const fresh = state.computed_map == null;
    const link = state.computed_map orelse blk: {
        const created = try state.allocator.create(element_style.ComputedMapLink);
        created.* = .{};
        break :blk created;
    };
    errdefer if (fresh) state.allocator.destroy(link);
    const map = try interfaces.StylePropertyMapReadOnly.initWith(element.ctx.allocator, element.ctx, .{
        .property_map_source = PropertyMap.Source{ .computed = element },
    });
    link.object.set(map);
    state.computed_map = link;
    objects.keepFrom(element, map, computed_map_slot);
    return map;
}

pub fn inlineMap(element: *runtime.Instance) !*runtime.Instance {
    return interfaces.StylePropertyMap.initWith(element.ctx.allocator, element.ctx, .{
        .property_map_source = PropertyMap.Source{ .inline_style = element },
    });
}

pub fn ruleMap(instance: *runtime.Instance) !*runtime.Instance {
    const rule = style_hooks.cssRuleOf(instance) orelse return error.InvalidStateError;
    if (rule.kind() != .style) return error.TypeError;
    return interfaces.StylePropertyMap.initWith(instance.ctx.allocator, instance.ctx, .{
        .property_map_source = PropertyMap.Source{ .rule = rule },
    });
}

fn mapOf(instance: *runtime.Instance) !*PropertyMap {
    return style_hooks.propertyMapOf(instance) orelse error.InvalidStateError;
}

fn propertyName(name: []const u8) !css.typed_om.property_names.Name {
    return css.typed_om.property_names.lookup(name) orelse error.TypeError;
}

/// Snapshot borrowed assignments with the stable ComputedStyle.get accessor.
/// Never index the storage that cascadefast2 owns.
fn readAssignments(map: *const PropertyMap, property: properties.Property, output: []properties.Assignment) !?[]const properties.Assignment {
    const longhands: []const properties.Longhand = switch (property) {
        .longhand => |l| &.{l},
        .shorthand => |s| s.longhands(),
    };
    if (map.kind == .computed) {
        const computed = try map.computed() orelse return null;
        for (longhands, 0..) |longhand, index| output[index] = .{ .longhand = longhand, .value = .{ .value = computed.get(longhand) } };
        return output[0..longhands.len];
    }
    const block = try map.block() orelse return null;
    var important: ?bool = null;
    for (longhands, 0..) |longhand, index| {
        const declaration = block.get(longhand) orelse return null;
        if (important) |priority| if (declaration.important != priority) return null;
        important = declaration.important;
        output[index] = .{ .longhand = longhand, .value = declaration.value };
    }
    if (property == .shorthand) {
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(block.allocator);
        // CSSOM's existing complete-shorthand check also catches pending
        // components originating from different shorthand declarations.
        try block.getPropertyValue(property.shorthand.name(), &text);
        if (text.items.len == 0) return null;
    }
    return output[0..longhands.len];
}

pub fn mapGetAll(instance: *runtime.Instance, name: []const u8) !Reified {
    const property = try propertyName(name);
    const map = try mapOf(instance);
    var result: Reified = .{ .ctx = instance.ctx };
    errdefer result.deinit();
    switch (property) {
        .custom => |custom_name| {
            if (map.kind == .computed) {
                const computed = try map.computed() orelse return result;
                const text = computed.customValue(custom_name) orelse return result;
                if (computed.registered) |snapshot| if (snapshot.find(custom_name)) |registration| {
                    try reifyRegistered(&result, custom_name, &registration.syntax, text.bytes);
                    return result;
                };
                try result.appendNew(try stringUnparsed(instance.ctx, text.bytes));
            } else {
                const block = try map.block() orelse return result;
                const value = block.getCustom(custom_name) orelse return result;
                try result.appendNew(try reifyCustom(instance.ctx, value.value));
            }
        },
        .ordinary => |ordinary| {
            var storage: [properties.max_assignments]properties.Assignment = undefined;
            const assignments = try readAssignments(map, ordinary, &storage) orelse return result;
            try reifyAssignments(&result, ordinary, assignments, map.kind == .computed);
        },
    }
    return result;
}

pub fn mapHas(instance: *runtime.Instance, name: []const u8) !bool {
    const property = try propertyName(name);
    const map = try mapOf(instance);
    return switch (property) {
        .ordinary => |ordinary| blk: {
            var storage: [properties.max_assignments]properties.Assignment = undefined;
            break :blk try readAssignments(map, ordinary, &storage) != null;
        },
        .custom => |custom_name| blk: {
            if (map.kind == .computed) {
                const computed = try map.computed() orelse return false;
                break :blk computed.customValue(custom_name) != null;
            }
            const block = try map.block() orelse return false;
            break :blk block.getCustom(custom_name) != null;
        },
    };
}

pub fn mapSize(instance: *runtime.Instance) !u32 {
    const map = try mapOf(instance);
    if (map.kind == .computed) {
        const computed = try map.computed() orelse return 0;
        const names = try computed.customNames(instance.ctx.allocator);
        defer instance.ctx.allocator.free(names);
        return @intCast(properties.Longhand.count + names.len);
    }
    const block = try map.block() orelse return 0;
    var count: u32 = 0;
    for (block.entries.items) |entry| if (entry != .unparsed) {
        count += 1;
    };
    return count;
}

pub fn mapDelete(instance: *runtime.Instance, name: []const u8) !void {
    _ = try propertyName(name);
    const map = try mapOf(instance);
    if (map.kind == .computed) return error.NoModificationAllowedError;
    const block = try map.block() orelse return;
    var old: std.ArrayList(u8) = .empty;
    defer old.deinit(block.allocator);
    if (try block.removeProperty(name, &old)) try map.changed();
}

pub fn mapClear(instance: *runtime.Instance) !void {
    const map = try mapOf(instance);
    if (map.kind == .computed) return error.NoModificationAllowedError;
    const block = try map.block() orelse return;
    if (block.entries.items.len == 0) return;
    block.clear();
    try map.changed();
}

const MapInput = union(enum) { string: []u8, object: *runtime.Instance };
const MapInputs = struct {
    ctx: runtime.Context,
    values: std.ArrayList(MapInput) = .empty,
    held: std.ArrayList(engine.Owned) = .empty,

    fn deinit(self: *MapInputs) void {
        for (self.values.items) |value| if (value == .string) self.ctx.allocator.free(value.string);
        for (self.held.items) |hold| hold.release();
        self.values.deinit(self.ctx.allocator);
        self.held.deinit(self.ctx.allocator);
    }

    fn convert(self: *MapInputs, input: []const runtime.JSValue) !void {
        for (input) |raw| {
            try self.values.ensureUnusedCapacity(self.ctx.allocator, 1);
            if (engine.convertToPlatformObject(self.ctx, raw)) |object| {
                if (object.stateAs(interfaces.CSSStyleValue.State) != null) {
                    try self.held.ensureUnusedCapacity(self.ctx.allocator, 1);
                    const hold = try engine.retainValue(object.ctx, .{ .instance = object });
                    self.held.appendAssumeCapacity(hold);
                    self.values.appendAssumeCapacity(.{ .object = object });
                    continue;
                }
            }
            const text = try engine.convertToUSVString(self.ctx, raw, self.ctx.allocator);
            self.values.appendAssumeCapacity(.{ .string = text });
        }
    }
};

const Assignments = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(properties.Assignment) = .empty,

    fn deinit(self: *Assignments) void {
        for (self.items.items) |assignment| assignment.value.release();
        self.items.deinit(self.allocator);
    }

    fn copy(self: *Assignments, borrowed: []const properties.Assignment) !void {
        try self.items.ensureUnusedCapacity(self.allocator, borrowed.len);
        for (borrowed) |assignment| {
            assignment.value.retain();
            self.items.appendAssumeCapacity(assignment);
        }
    }
};

fn assignmentsFromInput(instance: *runtime.Instance, map: *const PropertyMap, property: properties.Property, input: MapInput) !Assignments {
    var result: Assignments = .{ .allocator = instance.ctx.allocator };
    errdefer result.deinit();
    if (input == .string) {
        if (css.substitution.originalText(input.string).len == 0) return error.TypeError; // Q65.
        var context = try map.parseContext(instance, input.string);
        defer context.deinit();
        context.parse.allocator = result.allocator;
        if (!try properties.parseDeclaration(context.options(), property, input.string, &result.items)) return error.TypeError;
        return result;
    }
    const object = input.object;
    if (object.stateAs(interfaces.CSSNumericValue.State) != null) {
        // Q192: Chrome 156 and Safari 27 reject numeric grid-line values
        // (wpt.fyi stable, 2026-10-29). Blink b5548ca1190d2e89df6d7c7500799b19b15f81a2,
        // css_properties.json5, admits only Keyword for these longhands.
        // This typed-setter restriction does not alter ordinary CSS parsing.
        if (property == .longhand) switch (property.longhand) {
            .grid_row_start, .grid_row_end, .grid_column_start, .grid_column_end => return error.TypeError,
            else => {},
        };
        // Typed OM §3, create an internal representation: retain the existing
        // grammar for other numeric inputs. Q36/Q58/Q192: background lengths
        // and percentages and negative grid-template fr have a Chrome/Safari
        // 1–1 split, so the spec decides; both accept negative grid-auto fr.
        // Out-of-range values use the parser's calculation wrapping.
        const native = css.typed_om.native_numeric.snapshotForProperty(result.allocator, @intFromPtr(object), NumericReader{}) catch |err| switch (err) {
            error.Invalid => return error.TypeError,
            else => return err,
        };
        defer native.deinit();
        var context = try map.parseContext(instance, "");
        defer context.deinit();
        context.parse.allocator = result.allocator;
        const is_unit = object.stateAs(interfaces.CSSUnitValue.State) != null;
        if (!try properties.parseTypedNumeric(context.options(), property, .{ .expression = native, .is_unit = is_unit }, &result.items)) return error.TypeError;
        // H-OM-SHORTHAND-RANGE-ADMISSION, Q198/Q200: Chrome 156 and Safari
        // 27 both reject out-of-range units on logical border shorthands.
        // Typed OM §3, create an internal representation: this browser
        // rule replaces only the unit's range wrap, not math or longhands.
        // Borrow the matched component's grammar; nested shapes remain
        // unprobed under Q200 and keep their existing calculation semantics.
        if (property == .shorthand and is_unit) for (result.items.items) |assignment| {
            if (assignment.value != .value or assignment.value.value != .calculation) continue;
            const expression = assignment.value.value.calculation;
            // A unit input reifies to a numeric root today (math_values
            // fromTypedNumeric); skip anything else rather than assert, since
            // Crane modules stay Debug in the ReleaseSafe runner (review N1).
            if (expression.root.tag != .numeric) continue;
            const number = expression.root.numeric;
            const n = number.value * (number.unit.absoluteScale() orelse 1);
            const grammar = expression.grammar;
            // floatMax is the owner's unbounded sentinel, not a CSS limit.
            if ((grammar.minimum_kind == .grammar and grammar.minimum != -std.math.floatMax(f64) and n < grammar.minimum) or
                (grammar.maximum_kind == .grammar and grammar.maximum != std.math.floatMax(f64) and n > grammar.maximum)) return error.TypeError;
        };
        return result;
    }
    if (object.stateAs(interfaces.CSSKeywordValue.State) != null) {
        const keyword = try interfaces.CSSKeywordValue.get_value(object);
        defer object.ctx.allocator.free(keyword);
        // The keyword's mutable string is not a parsed CSS representation.
        // Escaping it makes ONE identifier for the existing property grammar.
        const escaped = try css.serialize.serializeIdentifier(result.allocator, keyword);
        defer result.allocator.free(escaped);
        var context = try map.parseContext(instance, escaped);
        defer context.deinit();
        context.parse.allocator = result.allocator;
        if (!try properties.parseDeclaration(context.options(), property, escaped, &result.items)) return error.TypeError;
        return result;
    }
    if (object.stateAs(interfaces.CSSUnparsedValue.State) != null) {
        const text = try serializeUnparsed(object);
        defer object.ctx.allocator.free(text);
        var context = try map.parseContext(instance, text);
        defer context.deinit();
        context.parse.allocator = result.allocator;
        // §3: unparsed values match every property grammar. The existing
        // Pending owner validates declaration/substitution arguments now;
        // its ordinary consuming-property grammar runs at computed time.
        // Blink CSSUnparsedValue::ToCSSValue/IsValidDeclarationValue,
        // cc7021d31c75bdb1ed2a95ea230abb6abcc3c663 (design, no copied code).
        const pending = try css.pending_values.Pending.create(context.options(), property, text) orelse return error.TypeError;
        defer pending.unref();
        const longhands: []const properties.Longhand = switch (property) {
            .longhand => |l| &.{l},
            .shorthand => |s| s.longhands(),
        };
        try result.items.ensureUnusedCapacity(result.allocator, longhands.len);
        for (longhands) |longhand| {
            pending.ref();
            result.items.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = .{ .pending = pending } } });
        }
        return result;
    }
    const payload = style_hooks.styleValueOf(object) orelse return error.TypeError;
    if (object.stateAs(interfaces.CSSImageValue.State) != null) {
        const image_value = switch (payload.*) {
            .ordinary => |native| native.assignments[0].value.value,
            .registered => |registered| blk: {
                const item = registered.owner.item(registered.index orelse return error.TypeError) orelse return error.TypeError;
                if (item != .image) return error.TypeError;
                break :blk item.image.value;
            },
        };
        var context = try map.parseContext(instance, "");
        defer context.deinit();
        context.parse.allocator = result.allocator;
        // Q87: a single-image Content owns its native URL until this call
        // finishes. Extract the borrowed URL tag; never serialize/reparse it.
        const image = css.typed_om.native_reification.urlImage(image_value) orelse return error.TypeError;
        if (!try properties.parseTypedImage(context.options(), property, image, &result.items)) return error.TypeError;
        return result;
    }
    if (payload.* != .ordinary or !Native.sameProperty(payload.ordinary.property, property)) return error.TypeError;
    const native = payload.ordinary;
    if (native.animation_index) |index| {
        // H-ANIMATION-SLICE (Q70): native owner clones just this component.
        const list = try native.assignments[0].value.value.animation_list.slice(result.allocator, index, index + 1) orelse return error.TypeError;
        errdefer list.unref();
        try result.items.append(result.allocator, .{ .longhand = property.longhand, .value = .{ .value = .{ .animation_list = list } } });
    } else try result.copy(native.assignments);
    return result;
}

fn customFromInput(instance: *runtime.Instance, map: *const PropertyMap, name: []const u8, input: MapInput) !css.custom_properties.Specified {
    if (input == .object) {
        const object = input.object;
        if (object.stateAs(interfaces.CSSUnparsedValue.State) == null) {
            // A direct opaque value for this same registered property can
            // reproduce its immutable native value. Subclasses (including
            // units and images) still do not match unregistered grammar.
            if (object.stateAs(interfaces.CSSImageValue.State) != null) return error.TypeError;
            const payload = style_hooks.styleValueOf(object) orelse return error.TypeError;
            if (payload.* != .registered or !std.mem.eql(u8, payload.registered.property, name)) return error.TypeError;
            const text = try payload.serialize(instance.ctx.allocator);
            defer instance.ctx.allocator.free(text);
            return .{ .text = try css.custom_properties.Text.create(instance.ctx.allocator, text) };
        }
        const text = try serializeUnparsed(object);
        defer object.ctx.allocator.free(text);
        var context = try map.parseContext(instance, text);
        defer context.deinit();
        context.parse.allocator = instance.ctx.allocator;
        return try css.custom_properties.parse(context.options(), text) orelse error.TypeError;
    }
    if (css.substitution.originalText(input.string).len == 0) return error.TypeError;
    var context = try map.parseContext(instance, input.string);
    defer context.deinit();
    context.parse.allocator = instance.ctx.allocator;
    return try css.custom_properties.parse(context.options(), input.string) orelse error.TypeError;
}

fn pendingOrWide(assigned: properties.Assigned) bool {
    return assigned == .css_wide or (assigned == .value and assigned.value == .pending);
}

// css-typed-om-1 set() steps 7-10 remove props[property] and re-add it at the
// END of the map, after a step (9) that can throw. Crane follows the browsers
// instead (golden rule 2, no newer spec): it validates every value first and
// replaces the declaration in place, keeping its position. Blink's
// StylePropertyMap::set coerces all values (CoerceStyleValuesOrStrings /
// CoerceStyleValueOrString), throws before any write and calls SetProperty
// with no prior RemoveProperty (chromium third_party/blink/renderer/core/css/
// cssom/style_property_map.cc); WebKit's StylePropertyMap::set likewise
// checks and converts before one setProperty/setShorthandProperty/
// setCustomProperty call and never removes first (Source/WebCore/css/typedom/
// StylePropertyMap.cpp). Firefox ships no Typed OM. Row 128 review S2.
pub fn mapSet(instance: *runtime.Instance, name: []const u8, raw: []const runtime.JSValue, append: bool) !void {
    // WebIDL conversion precedes the algorithm and can run script. Keep
    // earlier object arguments alive across later ToString callbacks.
    var input: MapInputs = .{ .ctx = instance.ctx };
    defer input.deinit();
    try input.convert(raw);
    const property = try propertyName(name);
    const map = try mapOf(instance);
    if (map.kind == .computed) return error.NoModificationAllowedError;
    const list_valued = property == .ordinary and css.typed_om.property_lists.kind(property.ordinary) != .single;
    if ((append and !list_valued) or (!list_valued and input.values.items.len > 1)) return error.TypeError;
    if (input.values.items.len == 0) {
        if (append) return; // Q58: zero-argument append is a no-op.
        return error.TypeError;
    }
    if (property == .custom) {
        const value = try customFromInput(instance, map, property.custom, input.values.items[0]);
        defer value.release();
        const block = try map.block() orelse return error.InvalidStateError;
        const changed = block.setValidatedCustom(property.custom, value) catch |err| switch (err) {
            error.Invalid => return error.TypeError,
            else => return err,
        };
        // Typed OM §3 set step 10 (Q178): successful inline sets update the
        // attribute even for equal values. Chrome 156 and Safari 27 agree;
        // Q178 selects this uniform rule for their shorthand text split too.
        // Probe: tmp/probes/q178/RESULT.md, 2026-10-29.
        if (changed or map.kind == .inline_style) try map.changed();
        return;
    }
    // Validate every new input before examining/mutating the declaration.
    var owned: std.ArrayList(Assignments) = .empty;
    defer {
        for (owned.items) |*item| item.deinit();
        owned.deinit(instance.ctx.allocator);
    }
    try owned.ensureTotalCapacity(instance.ctx.allocator, input.values.items.len);
    for (input.values.items) |value| owned.appendAssumeCapacity(try assignmentsFromInput(instance, map, property.ordinary, value));
    const block = try map.block() orelse return error.InvalidStateError;
    const all = owned.items;
    if (!list_valued) {
        const changed = block.setValidatedProperty(property.ordinary, all[0].items.items) catch |err| switch (err) {
            error.Invalid => return error.TypeError,
            else => return err,
        };
        if (changed or map.kind == .inline_style) try map.changed();
        return;
    }
    const longhand = property.ordinary.longhand;
    var components: std.ArrayList(css.style_values.Value) = .empty;
    defer components.deinit(instance.ctx.allocator);
    if (append) if (block.get(longhand)) |current| {
        if (pendingOrWide(current.value)) return error.TypeError;
        try components.append(instance.ctx.allocator, current.value.value);
    };
    for (all) |item| {
        const assigned = item.items.items[0].value;
        if (pendingOrWide(assigned)) {
            if (append or all.len != 1) return error.TypeError;
            const changed = block.setValidatedProperty(property.ordinary, item.items.items) catch |err| switch (err) {
                error.Invalid => return error.TypeError,
                else => return err,
            };
            if (changed or map.kind == .inline_style) try map.changed();
            return;
        }
        try components.append(instance.ctx.allocator, assigned.value);
    }
    const combined = css.typed_om.property_lists.concat(instance.ctx.allocator, longhand, components.items) catch |err| switch (err) {
        error.Invalid => return error.TypeError,
        else => return err,
    };
    defer combined.release();
    const assigned = [_]properties.Assignment{.{ .longhand = longhand, .value = .{ .value = combined } }};
    const changed = block.setValidatedProperty(property.ordinary, &assigned) catch |err| switch (err) {
        error.Invalid => return error.TypeError,
        else => return err,
    };
    if (changed or map.kind == .inline_style) try map.changed();
}

pub const IterableSnapshot = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(Entry) = .empty,
    roots: std.ArrayList(Reified) = .empty,

    pub const Entry = struct { name: []const u8, value: []const *runtime.Instance };

    /// Names and instance slices are BORROWED until deinit. Every instance
    /// has a call-local Owned root throughout conversion, even if the source
    /// declaration, element, or map is changed or collected in the meantime.
    /// The eventual binding must finish array conversion before deinit.
    pub fn deinit(self: *IterableSnapshot) void {
        for (self.entries.items) |entry| self.allocator.free(entry.name);
        for (self.roots.items) |*values| values.deinit();
        self.entries.deinit(self.allocator);
        self.roots.deinit(self.allocator);
    }

    fn append(self: *IterableSnapshot, instance: *runtime.Instance, name: []const u8) !void {
        try self.entries.ensureUnusedCapacity(self.allocator, 1);
        try self.roots.ensureUnusedCapacity(self.allocator, 1);
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        var values = try mapGetAll(instance, name);
        errdefer values.deinit();
        self.entries.appendAssumeCapacity(.{ .name = owned_name, .value = values.values.items });
        self.roots.appendAssumeCapacity(values);
    }
};

pub fn mapEntries(instance: *runtime.Instance) !IterableSnapshot {
    const allocator = instance.ctx.allocator;
    var result: IterableSnapshot = .{ .allocator = allocator };
    errdefer result.deinit();
    const map = try mapOf(instance);
    if (map.kind != .computed) {
        const block = try map.block() orelse return result;
        // §3.2 preserves the declaration block's order, including customs.
        for (block.entries.items) |*entry| if (entry.* != .unparsed)
            try result.append(instance, entry.name());
        return result;
    }
    const computed = try map.computed() orelse return result;
    var names: std.ArrayList([]const u8) = .empty;
    defer names.deinit(allocator);
    inline for (@typeInfo(properties.Longhand).@"enum".field_values) |field_value| {
        const longhand: properties.Longhand = @enumFromInt(field_value);
        try names.append(allocator, longhand.name());
    }
    const customs = try computed.customNames(allocator);
    defer allocator.free(customs);
    try names.appendSlice(allocator, customs);
    const Order = struct {
        fn group(name: []const u8) u2 {
            return if (std.mem.startsWith(u8, name, "--")) 2 else if (std.mem.startsWith(u8, name, "-")) 1 else 0;
        }
        fn less(_: void, left: []const u8, right: []const u8) bool {
            const l = group(left);
            const r = group(right);
            return if (l != r) l < r else std.mem.lessThan(u8, left, right);
        }
    };
    // §3.1: standardized, vendor-prefixed, custom; then code-point order.
    std.mem.sort([]const u8, names.items, {}, Order.less);
    for (names.items) |name| try result.append(instance, name);
    return result;
}
