//! CSS Values4 §8.3 / Values5 §4.2: typed positions, without layout.
//! Backgrounds3 additionally permits its three-component production.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const Grammar = enum { position, background };
pub const Edge = enum {
    left,
    right,
    top,
    bottom,
    center,
    x_start,
    x_end,
    y_start,
    y_end,
    block_start,
    block_end,
    inline_start,
    inline_end,
    start,
    end,

    pub fn name(self: Edge) []const u8 {
        return switch (self) {
            .left => "left",
            .right => "right",
            .top => "top",
            .bottom => "bottom",
            .center => "center",
            .x_start => "x-start",
            .x_end => "x-end",
            .y_start => "y-start",
            .y_end => "y-end",
            .block_start => "block-start",
            .block_end => "block-end",
            .inline_start => "inline-start",
            .inline_end => "inline-end",
            .start => "start",
            .end => "end",
        };
    }

    fn parse(t: tokenizer.Token) ?Edge {
        if (t.token_type != .ident) return null;
        inline for (@typeInfo(Edge).@"enum".fields) |f| {
            const e: Edge = @enumFromInt(f.value);
            if (tokenizer.nameEql(t.value, e.name())) return e;
        }
        return null;
    }

    const Axis = enum { horizontal, vertical, block, inline_axis, neutral, logical_neutral };
    fn axis(self: Edge) Axis {
        return switch (self) {
            .left, .right, .x_start, .x_end => .horizontal,
            .top, .bottom, .y_start, .y_end => .vertical,
            .block_start, .block_end => .block,
            .inline_start, .inline_end => .inline_axis,
            .center => .neutral,
            .start, .end => .logical_neutral,
        };
    }
};

/// An edge optionally followed by its inward offset; null edge denotes a
/// bare length-percentage. The containing Position owns any offset Value.
pub const Anchor = struct {
    edge: ?Edge,
    offset: ?Value = null,
};

/// An offset from top/left. complement keeps `100% - length` typed even
/// before the CSS math parser is merged; no serialized value is re-parsed.
pub const Offset = struct {
    value: Value,
    complement: bool = false,

    pub fn serialize(self: Offset, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (!self.complement) return properties.serializeValue(.margin_left, self.value, out, allocator);
        const len = self.value.length;
        if (len.unit == .percent) {
            try values.appendLength(.percent(100 - len.value), out, allocator);
        } else if (len.value == 0) {
            try out.appendSlice(allocator, "100%");
        } else {
            try out.appendSlice(allocator, if (len.value < 0) "calc(100% + " else "calc(100% - ");
            try values.appendLength(.init(@abs(len.value), len.unit), out, allocator);
            try out.append(allocator, ')');
        }
    }
};

pub const Position = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    data: union(enum) { specified: [2]Anchor, computed: [2]Offset },
    /// true orders the specified anchors by block then inline axis.
    logical: bool = false,

    pub fn ref(self: *Position) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Position) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        switch (self.data) {
            .specified => |axes| for (axes) |a| {
                if (a.offset) |v| v.release();
            },
            .computed => |axes| for (axes) |a| a.value.release(),
        }
        self.allocator.destroy(self);
    }

    pub fn create(allocator: Allocator, axes: [2]Anchor, logical: bool) Allocator.Error!*Position {
        const self = try allocator.create(Position);
        self.* = .{ .allocator = allocator, .data = .{ .specified = axes }, .logical = logical };
        for (axes) |a| if (a.offset) |v| v.retain();
        return self;
    }

    pub fn needsUnavailableMetrics(self: *const Position, geometry_length: bool) bool {
        switch (self.data) {
            .specified => |axes| for (axes) |anchor| {
                if (anchor.offset) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
            },
            .computed => |axes| for (axes) |offset| {
                if (offset.value.needsUnavailableMetrics(geometry_length)) return true;
            },
        }
        return false;
    }

    pub fn needsTreeCounts(self: *const Position) bool {
        switch (self.data) {
            .specified => |axes| for (axes) |anchor| {
                if (anchor.offset) |value| if (value.needsTreeCounts()) return true;
            },
            .computed => |axes| for (axes) |offset| {
                if (offset.value.needsTreeCounts()) return true;
            },
        }
        return false;
    }

    pub fn needsRandomBase(self: *const Position) bool {
        switch (self.data) {
            .specified => |axes| for (axes) |anchor| {
                if (anchor.offset) |value| if (value.needsRandomBase()) return true;
            },
            .computed => |axes| for (axes) |offset| {
                if (offset.value.needsRandomBase()) return true;
            },
        }
        return false;
    }

    pub fn eql(self: *const Position, other: *const Position) bool {
        if (self == other) return true;
        if (self.logical != other.logical or std.meta.activeTag(self.data) != std.meta.activeTag(other.data)) return false;
        switch (self.data) {
            .specified => |a| for (a, other.data.specified) |x, y| {
                if (x.edge != y.edge) return false;
                if (x.offset) |v| {
                    if (y.offset == null or !v.eql(y.offset.?)) return false;
                } else if (y.offset != null) return false;
            },
            .computed => |a| for (a, other.data.computed) |x, y| {
                if (x.complement != y.complement or !x.value.eql(y.value)) return false;
            },
        }
        return true;
    }

    /// Values5 §4.2: logical edges resolve in the declaring element's
    /// writing mode; the computed pair is always left then top offsets.
    pub fn compute(self: *const Position, allocator: Allocator, context: anytype) Allocator.Error!*Position {
        if (self.data == .computed) {
            const result: *Position = @constCast(self);
            result.ref();
            return result;
        }
        var axes: [2]Offset = undefined;
        var initialized = [_]bool{false} ** 2;
        errdefer for (initialized, 0..) |done, i| {
            if (done) axes[i].value.release();
        };
        for (self.data.specified, 0..) |anchor, i| {
            const horizontal = if (self.logical) (context.writing_mode != .horizontal_tb) == (i == 0) else i == 0;
            const index: usize = if (horizontal) 0 else 1;
            const side = if (anchor.edge) |edge| physical(edge, i, context.writing_mode, context.direction) else null;
            axes[index] = if (anchor.edge == .center)
                .{ .value = .{ .length = .percent(50) } }
            else
                .{ .value = if (anchor.offset) |v| try context.length(v) else .{ .length = .percent(0) }, .complement = side == .right or side == .bottom };
            initialized[index] = true;
        }
        const result = try allocator.create(Position);
        result.* = .{ .allocator = allocator, .data = .{ .computed = axes } };
        return result;
    }

    pub fn serialize(self: *const Position, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.data) {
            .computed => |axes| {
                try axes[0].serialize(out, allocator);
                try out.append(allocator, ' ');
                try axes[1].serialize(out, allocator);
            },
            .specified => |axes| for (axes, 0..) |a, i| {
                if (i > 0) try out.append(allocator, ' ');
                if (a.edge) |edge| try out.appendSlice(allocator, edge.name());
                if (a.offset) |v| {
                    if (a.edge != null) try out.append(allocator, ' ');
                    try properties.serializeValue(.margin_left, v, out, allocator);
                }
            },
        }
    }
};

pub fn physical(edge: Edge, index: usize, mode: values.Keyword, direction: values.Keyword) ?properties.PhysicalSide {
    const horizontal = mode == .horizontal_tb;
    return switch (edge) {
        .left => .left,
        .right => .right,
        .top => .top,
        .bottom => .bottom,
        .center => null,
        .block_start => properties.physicalSide(.block_start, mode, direction),
        .block_end => properties.physicalSide(.block_end, mode, direction),
        .inline_start => properties.physicalSide(.inline_start, mode, direction),
        .inline_end => properties.physicalSide(.inline_end, mode, direction),
        .x_start => properties.physicalSide(if (horizontal) .inline_start else .block_start, mode, direction),
        .x_end => properties.physicalSide(if (horizontal) .inline_end else .block_end, mode, direction),
        .y_start => properties.physicalSide(if (horizontal) .block_start else .inline_start, mode, direction),
        .y_end => properties.physicalSide(if (horizontal) .block_end else .inline_end, mode, direction),
        .start => properties.physicalSide(if (index == 0) .block_start else .inline_start, mode, direction),
        .end => properties.physicalSide(if (index == 0) .block_end else .inline_end, mode, direction),
    };
}

const Part = union(enum) { edge: Edge, value: Value };
const Ordered = struct { axes: [2]Anchor, logical: bool = false };

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream, grammar: Grammar) Allocator.Error!?*Position {
    // Values4 Appendix C does not grant quirky lengths to positions.
    var strict = options;
    strict.quirks = false;
    var parts: [4]Part = undefined;
    var marks: [4]properties.Stream = undefined;
    var count: usize = 0;
    const original = stream.*;
    defer for (parts[0..count]) |part| {
        if (part == .value) part.value.release();
    };
    while (count < parts.len) {
        if (Edge.parse(stream.peek())) |edge| {
            _ = stream.next();
            parts[count] = .{ .edge = edge };
        } else {
            const saved = stream.*;
            const v = try properties.parseLonghand(strict, .margin_left, stream) orelse {
                stream.* = saved;
                break;
            };
            if (v != .length) {
                v.release();
                stream.* = saved;
                break;
            }
            parts[count] = .{ .value = v };
        }
        marks[count] = stream.*;
        count += 1;
    }
    var n = count;
    while (n > 0) : (n -= 1) {
        if (order(parts[0..n], grammar)) |ordered| {
            stream.* = marks[n - 1];
            return try Position.create(options.allocator, ordered.axes, ordered.logical);
        }
    }
    stream.* = original;
    return null;
}

fn order(parts: []const Part, grammar: Grammar) ?Ordered {
    if (parts.len == 1) {
        if (parts[0] == .value) return .{ .axes = .{ .{ .edge = null, .offset = parts[0].value }, .{ .edge = .center } } };
        const e = parts[0].edge;
        if (e == .start or e == .end) return null;
        const first = switch (e.axis()) {
            .vertical, .inline_axis => false,
            else => true,
        };
        var axes = [2]Anchor{ .{ .edge = .center }, .{ .edge = .center } };
        axes[if (first) 0 else 1].edge = e;
        return .{ .axes = axes, .logical = e.axis() == .block or e.axis() == .inline_axis };
    }
    if (parts.len == 2) {
        if (parts[0] == .edge and parts[1] == .edge) {
            return orderAxes(.{ .{ .edge = parts[0].edge }, .{ .edge = parts[1].edge } });
        }
        // A value in a pair fixes the order to horizontal then vertical.
        var axes: [2]Anchor = undefined;
        for (parts, 0..) |p, i| {
            if (p == .value) axes[i] = .{ .edge = null, .offset = p.value } else {
                const a = p.edge.axis();
                if (a != .neutral and a != (if (i == 0) Edge.Axis.horizontal else .vertical)) return null;
                axes[i] = .{ .edge = p.edge };
            }
        }
        return .{ .axes = axes };
    }
    if (parts.len == 3 and grammar != .background) return null;
    var axes: [2]Anchor = undefined;
    var index: usize = 0;
    for (&axes) |*a| {
        if (index == parts.len or parts[index] != .edge) return null;
        a.* = .{ .edge = parts[index].edge };
        index += 1;
        if (index < parts.len and parts[index] == .value) {
            if (a.edge.? == .center) return null;
            a.offset = parts[index].value;
            index += 1;
        } else if (parts.len == 4) return null;
    }
    if (index != parts.len) return null;
    return orderAxes(axes);
}

fn orderAxes(input: [2]Anchor) ?Ordered {
    const x = input[0].edge.?.axis();
    const y = input[1].edge.?.axis();
    if ((x == .logical_neutral or x == .neutral) and (y == .logical_neutral or y == .neutral)) return .{ .axes = input, .logical = x == .logical_neutral or y == .logical_neutral };
    const logical = x == .block or x == .inline_axis or y == .block or y == .inline_axis;
    const first: Edge.Axis = if (logical) .block else .horizontal;
    const second: Edge.Axis = if (logical) .inline_axis else .vertical;
    if ((x == first or x == .neutral) and (y == second or y == .neutral)) return .{ .axes = input, .logical = logical };
    if ((y == first or y == .neutral) and (x == second or x == .neutral)) return .{ .axes = .{ input[1], input[0] }, .logical = logical };
    return null;
}
/// Backgrounds4 §2.6: one independently mutable axis. The pair parser and
/// this component share Anchor/Offset and the same logical-edge conversion.
pub const PositionAxis = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    data: union(enum) { specified: Anchor, computed: Offset },

    pub fn create(allocator: Allocator, anchor: Anchor) Allocator.Error!*PositionAxis {
        const result = try allocator.create(PositionAxis);
        result.* = .{ .allocator = allocator, .data = .{ .specified = anchor } };
        if (anchor.offset) |v| v.retain();
        return result;
    }
    pub fn ref(self: *PositionAxis) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *PositionAxis) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        switch (self.data) {
            .specified => |a| if (a.offset) |v| v.release(),
            .computed => |o| o.value.release(),
        }
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const PositionAxis, other: *const PositionAxis) bool {
        if (self == other) return true;
        if (std.meta.activeTag(self.data) != std.meta.activeTag(other.data)) return false;
        return switch (self.data) {
            .specified => |a| blk: {
                const b = other.data.specified;
                if (a.edge != b.edge) break :blk false;
                if (a.offset) |v| break :blk if (b.offset) |w| v.eql(w) else false;
                break :blk b.offset == null;
            },
            .computed => |o| o.complement == other.data.computed.complement and o.value.eql(other.data.computed.value),
        };
    }
    pub fn needsUnavailableMetrics(self: *const PositionAxis, geometry_length: bool) bool {
        return switch (self.data) {
            .specified => |anchor| if (anchor.offset) |value| value.needsUnavailableMetrics(geometry_length) else false,
            .computed => |offset| offset.value.needsUnavailableMetrics(geometry_length),
        };
    }
    pub fn needsTreeCounts(self: *const PositionAxis) bool {
        return switch (self.data) {
            .specified => |anchor| if (anchor.offset) |value| value.needsTreeCounts() else false,
            .computed => |offset| offset.value.needsTreeCounts(),
        };
    }
    pub fn needsRandomBase(self: *const PositionAxis) bool {
        return switch (self.data) {
            .specified => |anchor| if (anchor.offset) |value| value.needsRandomBase() else false,
            .computed => |offset| offset.value.needsRandomBase(),
        };
    }
    pub fn serialize(self: *const PositionAxis, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.data) {
            .computed => |o| try o.serialize(out, allocator),
            .specified => |a| try serializeAnchor(a, out, allocator),
        }
    }
    pub fn compute(self: *const PositionAxis, allocator: Allocator, index: usize, context: anytype) Allocator.Error!*PositionAxis {
        if (self.data == .computed) {
            @constCast(self).ref();
            return @constCast(self);
        }
        const anchor = self.data.specified;
        const side = if (anchor.edge) |edge| physical(edge, index, context.writing_mode, context.direction) else null;
        const offset: Offset = if (anchor.edge == .center)
            .{ .value = .{ .length = .percent(50) } }
        else
            .{ .value = if (anchor.offset) |v| try context.length(v) else .{ .length = .percent(0) }, .complement = side == .right or side == .bottom };
        errdefer offset.value.release();
        const result = try allocator.create(PositionAxis);
        result.* = .{ .allocator = allocator, .data = .{ .computed = offset } };
        return result;
    }
};

pub fn parseAxis(options: properties.ParseOptions, stream: *properties.Stream, horizontal: bool) Allocator.Error!?Value {
    var anchor = Anchor{ .edge = null };
    if (Edge.parse(stream.peek())) |edge| {
        const allowed = if (horizontal)
            edge == .center or edge == .left or edge == .right or edge == .x_start or edge == .x_end
        else
            edge == .center or edge == .top or edge == .bottom or edge == .y_start or edge == .y_end;
        if (!allowed) return null;
        _ = stream.next();
        anchor.edge = edge;
        if (edge == .center) return .{ .image_axis = try PositionAxis.create(options.allocator, anchor) };
    }
    anchor.offset = try @import("shape_components.zig").length(options, stream, true, true);
    defer if (anchor.offset) |v| v.release();
    if (anchor.edge == null and anchor.offset == null) return null;
    return .{ .image_axis = try PositionAxis.create(options.allocator, anchor) };
}

fn serializeAnchor(anchor: Anchor, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (anchor.edge) |edge| try out.appendSlice(allocator, edge.name());
    if (anchor.offset) |v| {
        if (anchor.edge != null) try out.append(allocator, ' ');
        try properties.serializeValue(.margin_left, v, out, allocator);
    }
}

/// Background-position recombines independent components. If one edge has
/// an offset, a bare length on the other axis needs its explicit start edge
/// to keep the serialized three/four-value grammar valid.
pub fn serializeAxes(x: Value, y: Value, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const vs = [2]Value{ x, y };
    var anchors: [2]Anchor = undefined;
    var computed = false;
    var edge_offset = false;
    for (vs, 0..) |v, i| {
        if (v == .image_axis) {
            if (v.image_axis.data == .computed) {
                computed = true;
                continue;
            }
            anchors[i] = v.image_axis.data.specified;
        } else anchors[i] = .{ .edge = null, .offset = v };
        if (anchors[i].edge != null and anchors[i].offset != null) edge_offset = true;
    }
    if (computed) {
        try properties.serializeValue(.background_position_x, x, out, allocator);
        try out.append(allocator, ' ');
        try properties.serializeValue(.background_position_y, y, out, allocator);
        return;
    }
    for (anchors, 0..) |item, i| {
        var anchor = item;
        if (i != 0) try out.append(allocator, ' ');
        if (edge_offset and anchor.edge == null) anchor.edge = if (i == 0) .left else .top;
        try serializeAnchor(anchor, out, allocator);
    }
}
