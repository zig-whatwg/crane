//! CSS Shapes §3.1.1: typed shape() commands. No path geometry is evaluated.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const parts = @import("shape_components.zig");
const positions = @import("position_values.zig");
const angles = @import("image_angle.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Point = union(enum) {
    position: *positions.Position,
    pair: [2]Value,
    fn release(self: Point) void {
        switch (self) {
            .position => |p| p.unref(),
            .pair => |p| for (p) |v| v.release(),
        }
    }
    fn needsUnavailableMetrics(self: Point, geometry_length: bool) bool {
        return switch (self) {
            .position => |position| position.needsUnavailableMetrics(geometry_length),
            .pair => |p| p[0].needsUnavailableMetrics(geometry_length) or p[1].needsUnavailableMetrics(geometry_length),
        };
    }
    fn needsTreeCounts(self: Point) bool {
        return switch (self) {
            .position => |position| position.needsTreeCounts(),
            .pair => |p| p[0].needsTreeCounts() or p[1].needsTreeCounts(),
        };
    }
    fn needsRandomBase(self: Point) bool {
        return switch (self) {
            .position => |position| position.needsRandomBase(),
            .pair => |p| p[0].needsRandomBase() or p[1].needsRandomBase(),
        };
    }
    fn eql(self: Point, other: Point) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .position => |p| p.eql(other.position),
            .pair => |p| p[0].eql(other.pair[0]) and p[1].eql(other.pair[1]),
        };
    }
    fn serialize(self: Point, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .position => |p| try p.serialize(out, allocator),
            .pair => |p| {
                try properties.serializeValue(.margin_left, p[0], out, allocator);
                try out.append(allocator, ' ');
                try properties.serializeValue(.margin_left, p[1], out, allocator);
            },
        }
    }
    fn compute(self: Point, allocator: Allocator, context: anytype) Allocator.Error!Point {
        return switch (self) {
            .position => |p| .{ .position = try p.compute(allocator, context) },
            .pair => |p| blk: {
                const x = try context.length(p[0]);
                errdefer x.release();
                break :blk .{ .pair = .{ x, try context.length(p[1]) } };
            },
        };
    }
};
const AxisPoint = union(enum) {
    edge: positions.Edge,
    value: Value,
    fn release(self: AxisPoint) void {
        if (self == .value) self.value.release();
    }
    fn eql(self: AxisPoint, other: AxisPoint) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .edge => |e| e == other.edge,
            .value => |v| v.eql(other.value),
        };
    }
    fn serialize(self: AxisPoint, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .edge => |e| try out.appendSlice(allocator, e.name()),
            .value => |v| try properties.serializeValue(.margin_left, v, out, allocator),
        }
    }
};
const Control = struct {
    point: Point,
    origin: enum { start, end, origin },
    fn eql(self: Control, other: Control) bool {
        return self.origin == other.origin and self.point.eql(other.point);
    }
};
const Rotation = union(enum) {
    literal: angles.Angle,
    value: Value,

    fn release(self: Rotation) void {
        if (self == .value) self.value.release();
    }
    fn eql(self: Rotation, other: Rotation) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .literal => |a| a.number == other.literal.number and a.unit == other.literal.unit,
            .value => |value| value.eql(other.value),
        };
    }
    fn isDefault(self: Rotation) bool {
        // Shapes §3.3 / Q142: specified math zero keeps its expression;
        // literal zero and a computed zero omit the default rotation.
        return self == .literal and self.literal.number == 0;
    }
    fn serialize(self: Rotation, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .literal => |angle| try angle.serialize(out, allocator),
            .value => |value| try properties.serializeValue(.margin_left, value, out, allocator),
        }
    }
    fn compute(self: Rotation, context: anytype) Allocator.Error!Rotation {
        const degrees = switch (self) {
            .literal => |angle| angle.degrees(),
            .value => |value| blk: {
                // Values §10.11: the actual component context keeps Source,
                // tree counts, random base and font inputs from the winner.
                const result = try context.length(value);
                defer result.release();
                std.debug.assert(result == .calculation);
                const number = result.calculation.computedNumber().?;
                std.debug.assert(number.unit == .deg);
                break :blk number.value;
            },
        };
        return .{ .literal = .{ .number = degrees, .unit = .deg } };
    }
};
const Arc = struct {
    radii: [2]Value = undefined,
    count: u2 = 0,
    clockwise: bool = false,
    large: bool = false,
    rotation: Rotation = .{ .literal = .{ .number = 0, .unit = .deg } },
};
const Kind = enum { move, line, hline, vline, curve, smooth, arc, close };
const Command = struct {
    kind: Kind,
    relative: bool = false,
    endpoint: union(enum) { none, point: Point, axis: AxisPoint } = .none,
    controls: [2]Control = undefined,
    control_count: u2 = 0,
    arc: ?Arc = null,
    fn release(self: Command) void {
        switch (self.endpoint) {
            .none => {},
            .point => |p| p.release(),
            .axis => |p| p.release(),
        }
        for (self.controls[0..self.control_count]) |c| c.point.release();
        if (self.arc) |a| {
            a.rotation.release();
            for (a.radii[0..a.count]) |v| v.release();
        }
    }
    fn eql(self: Command, other: Command) bool {
        if (self.kind != other.kind or self.relative != other.relative or self.control_count != other.control_count or std.meta.activeTag(self.endpoint) != std.meta.activeTag(other.endpoint)) return false;
        switch (self.endpoint) {
            .none => {},
            .point => |p| if (!p.eql(other.endpoint.point)) return false,
            .axis => |p| if (!p.eql(other.endpoint.axis)) return false,
        }
        for (self.controls[0..self.control_count], other.controls[0..other.control_count]) |a, b| if (!a.eql(b)) return false;
        if (self.arc) |a| {
            const b = other.arc orelse return false;
            if (a.count != b.count or a.clockwise != b.clockwise or a.large != b.large or !a.rotation.eql(b.rotation)) return false;
            for (a.radii[0..a.count], b.radii[0..b.count]) |x, y| if (!x.eql(y)) return false;
        } else if (other.arc != null) return false;
        return true;
    }
    fn serialize(self: Command, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, @tagName(self.kind));
        if (self.kind == .close) return;
        try out.appendSlice(allocator, if (self.relative) " by " else " to ");
        switch (self.endpoint) {
            .none => unreachable,
            .point => |p| try p.serialize(out, allocator),
            .axis => |p| try p.serialize(out, allocator),
        }
        for (self.controls[0..self.control_count], 0..) |c, i| {
            try out.appendSlice(allocator, if (i == 0) " with " else " / ");
            try c.point.serialize(out, allocator);
            const default_origin: @FieldType(Control, "origin") = if (self.relative) .start else .origin;
            if (c.origin != default_origin) {
                try out.appendSlice(allocator, " from ");
                try out.appendSlice(allocator, @tagName(c.origin));
            }
        }
        if (self.arc) |a| {
            try out.appendSlice(allocator, " of ");
            for (a.radii[0..a.count], 0..) |v, i| {
                if (i > 0) try out.append(allocator, ' ');
                try properties.serializeValue(.margin_left, v, out, allocator);
            }
            if (a.clockwise) try out.appendSlice(allocator, " cw");
            if (a.large) try out.appendSlice(allocator, " large");
            if (!a.rotation.isDefault()) {
                try out.appendSlice(allocator, " rotate ");
                try a.rotation.serialize(out, allocator);
            }
        }
    }
    fn compute(self: Command, allocator: Allocator, context: anytype) Allocator.Error!Command {
        var result = Command{ .kind = self.kind, .relative = self.relative };
        errdefer result.release();
        const endpoint: @FieldType(Command, "endpoint") = switch (self.endpoint) {
            .none => .none,
            .point => |p| .{ .point = try p.compute(allocator, context) },
            .axis => |p| .{ .axis = switch (p) {
                .value => |v| .{ .value = try context.length(v) },
                .edge => |e| blk: {
                    const side = positions.physical(e, if (self.kind == .hline) 0 else 1, context.writing_mode, context.direction);
                    break :blk .{ .value = .{ .length = .percent(if (e == .center) 50 else if (side == .right or side == .bottom) 100 else 0) } };
                },
            } },
        };
        result.endpoint = endpoint;
        while (result.control_count < self.control_count) : (result.control_count += 1) {
            const c = self.controls[result.control_count];
            result.controls[result.control_count] = .{ .point = try c.point.compute(allocator, context), .origin = c.origin };
        }
        if (self.arc) |a| {
            result.arc = .{ .clockwise = a.clockwise, .large = a.large, .rotation = try a.rotation.compute(context) };
            while (result.arc.?.count < a.count) : (result.arc.?.count += 1) {
                const i = result.arc.?.count;
                result.arc.?.radii[i] = try context.length(a.radii[i]);
            }
        }
        return result;
    }
};

pub const Commands = struct {
    evenodd: bool,
    origin: *positions.Position,
    items: []const Command,
    pub fn deinit(self: Commands, allocator: Allocator) void {
        self.origin.unref();
        for (self.items) |c| c.release();
        allocator.free(self.items);
    }
    pub fn needsUnavailableMetrics(self: Commands, geometry_length: bool) bool {
        if (self.origin.needsUnavailableMetrics(geometry_length)) return true;
        for (self.items) |entry| {
            switch (entry.endpoint) {
                .none => {},
                .point => |p| if (p.needsUnavailableMetrics(geometry_length)) return true,
                .axis => |axis| if (axis == .value and axis.value.needsUnavailableMetrics(geometry_length)) return true,
            }
            for (entry.controls[0..entry.control_count]) |c| if (c.point.needsUnavailableMetrics(geometry_length)) return true;
            if (entry.arc) |arc| {
                if (arc.rotation == .value and arc.rotation.value.needsUnavailableMetrics(false)) return true;
                for (arc.radii[0..arc.count]) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
            }
        }
        return false;
    }

    pub fn needsTreeCounts(self: Commands) bool {
        if (self.origin.needsTreeCounts()) return true;
        for (self.items) |entry| {
            switch (entry.endpoint) {
                .none => {},
                .point => |p| if (p.needsTreeCounts()) return true,
                .axis => |axis| if (axis == .value and axis.value.needsTreeCounts()) return true,
            }
            for (entry.controls[0..entry.control_count]) |c| if (c.point.needsTreeCounts()) return true;
            if (entry.arc) |arc| {
                if (arc.rotation == .value and arc.rotation.value.needsTreeCounts()) return true;
                for (arc.radii[0..arc.count]) |value| if (value.needsTreeCounts()) return true;
            }
        }
        return false;
    }
    pub fn needsRandomBase(self: Commands) bool {
        if (self.origin.needsRandomBase()) return true;
        for (self.items) |entry| {
            switch (entry.endpoint) {
                .none => {},
                .point => |p| if (p.needsRandomBase()) return true,
                .axis => |axis| if (axis == .value and axis.value.needsRandomBase()) return true,
            }
            for (entry.controls[0..entry.control_count]) |c| if (c.point.needsRandomBase()) return true;
            if (entry.arc) |arc| {
                if (arc.rotation == .value and arc.rotation.value.needsRandomBase()) return true;
                for (arc.radii[0..arc.count]) |value| if (value.needsRandomBase()) return true;
            }
        }
        return false;
    }
    pub fn eql(self: Commands, other: Commands) bool {
        if (self.evenodd != other.evenodd or !self.origin.eql(other.origin) or self.items.len != other.items.len) return false;
        for (self.items, other.items) |a, b| if (!a.eql(b)) return false;
        return true;
    }
    /// Shape owns the final ')' and the optional geometry box.
    pub fn serialize(self: Commands, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        try out.appendSlice(allocator, if (self.evenodd) "shape(evenodd from " else "shape(from ");
        try self.origin.serialize(out, allocator);
        for (self.items) |c| {
            try out.appendSlice(allocator, ", ");
            try c.serialize(out, allocator);
        }
    }
    pub fn compute(self: Commands, allocator: Allocator, context: anytype) Allocator.Error!Commands {
        const origin = try self.origin.compute(allocator, context);
        errdefer origin.unref();
        const items = try allocator.alloc(Command, self.items.len);
        var count: usize = 0;
        errdefer {
            for (items[0..count]) |c| c.release();
            allocator.free(items);
        }
        while (count < items.len) : (count += 1) items[count] = try self.items[count].compute(allocator, context);
        return .{ .evenodd = self.evenodd, .origin = origin, .items = items };
    }
};

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Commands {
    const evenodd = parts.keyword(stream, "evenodd");
    if (!evenodd) _ = parts.keyword(stream, "nonzero");
    if (!parts.keyword(stream, "from")) return null;
    const origin = (try positions.parse(options, stream, .position)) orelse return null;
    var moved = false;
    defer if (!moved) origin.unref();
    if (stream.next().token_type != .comma) return null;
    var items: std.ArrayList(Command) = .empty;
    defer {
        for (items.items) |c| c.release();
        items.deinit(options.allocator);
    }
    while (true) {
        const c = (try command(options, stream)) orelse return null;
        errdefer c.release();
        try items.append(options.allocator, c);
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    const owned = try items.toOwnedSlice(options.allocator);
    moved = true;
    return .{ .evenodd = evenodd, .origin = origin, .items = owned };
}

fn point(options: properties.ParseOptions, stream: *properties.Stream, relative: bool) Allocator.Error!?Point {
    if (!relative) return if (try positions.parse(options, stream, .position)) |p| .{ .position = p } else null;
    const x = (try parts.length(options, stream, true, true)) orelse return null;
    var moved = false;
    defer if (!moved) x.release();
    const y = (try parts.length(options, stream, true, true)) orelse return null;
    moved = true;
    return .{ .pair = .{ x, y } };
}

fn control(options: properties.ParseOptions, stream: *properties.Stream, relative: bool) Allocator.Error!?Control {
    const mark = stream.*;
    const coordinates = try point(options, stream, true);
    if (coordinates) |p| {
        var moved = false;
        defer if (!moved) p.release();
        var origin: @FieldType(Control, "origin") = if (relative) .start else .origin;
        if (parts.keyword(stream, "from")) {
            origin = if (parts.keyword(stream, "start")) .start else if (parts.keyword(stream, "end")) .end else if (parts.keyword(stream, "origin")) .origin else return null;
        }
        moved = true;
        return .{ .point = p, .origin = origin };
    }
    stream.* = mark;
    if (relative) return null;
    return .{ .point = (try point(options, stream, false)) orelse return null, .origin = .origin };
}

fn command(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Command {
    const kind: Kind = blk: {
        inline for (@typeInfo(Kind).@"enum".field_names, @typeInfo(Kind).@"enum".field_values) |f_name, f_value| if (parts.keyword(stream, f_name)) break :blk @enumFromInt(f_value);
        return null;
    };
    var result = Command{ .kind = kind };
    var moved = false;
    defer if (!moved) result.release();
    if (kind == .close) {
        moved = true;
        return result;
    }
    result.relative = parts.keyword(stream, "by");
    if (!result.relative and !parts.keyword(stream, "to")) return null;
    if (kind == .hline or kind == .vline) {
        const endpoint = (try axisPoint(options, stream, kind == .hline, result.relative)) orelse return null;
        result.endpoint = .{ .axis = endpoint };
    } else {
        const endpoint = (try point(options, stream, result.relative)) orelse return null;
        result.endpoint = .{ .point = endpoint };
    }
    if (kind == .curve or kind == .smooth) {
        if (parts.keyword(stream, "with")) {
            result.controls[0] = (try control(options, stream, result.relative)) orelse return null;
            result.control_count = 1;
            if (kind == .curve and slash(stream)) {
                result.controls[1] = (try control(options, stream, result.relative)) orelse return null;
                result.control_count = 2;
            }
        } else if (kind == .curve) return null;
    }
    if (kind == .arc) {
        result.arc = .{};
        var of = false;
        var sweep = false;
        var size = false;
        var rotation = false;
        while (true) {
            if (!of and parts.keyword(stream, "of")) {
                result.arc.?.radii[0] = (try parts.length(options, stream, true, true)) orelse return null;
                result.arc.?.count = 1;
                if (try parts.length(options, stream, true, true)) |v| {
                    result.arc.?.radii[1] = v;
                    result.arc.?.count = 2;
                }
                of = true;
            } else if (!sweep and parts.keyword(stream, "cw")) {
                result.arc.?.clockwise = true;
                sweep = true;
            } else if (!sweep and parts.keyword(stream, "ccw")) {
                sweep = true;
            } else if (!size and parts.keyword(stream, "large")) {
                result.arc.?.large = true;
                size = true;
            } else if (!size and parts.keyword(stream, "small")) {
                size = true;
            } else if (!rotation and parts.keyword(stream, "rotate")) {
                result.arc.?.rotation = if (stream.peek().token_type == .function)
                    .{ .value = (try properties.mathValue(options, stream, .{ .kind = .angle })) orelse return null }
                else
                    .{ .literal = angles.parse(stream, false) orelse return null };
                rotation = true;
            } else break;
        }
        if (!of) return null;
    }
    moved = true;
    return result;
}

fn axisPoint(options: properties.ParseOptions, stream: *properties.Stream, horizontal: bool, relative: bool) Allocator.Error!?AxisPoint {
    if (!relative) {
        const allowed: []const positions.Edge = if (horizontal) &.{ .left, .center, .right, .x_start, .x_end } else &.{ .top, .center, .bottom, .y_start, .y_end };
        for (allowed) |e| if (parts.keyword(stream, e.name())) return .{ .edge = e };
    }
    return if (try parts.length(options, stream, true, true)) |v| .{ .value = v } else null;
}
fn slash(stream: *properties.Stream) bool {
    const t = stream.peek();
    if (t.token_type != .delim or !std.mem.eql(u8, t.value, "/")) return false;
    _ = stream.next();
    return true;
}
