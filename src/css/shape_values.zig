//! CSS Masking §5.1 / CSS Shapes §3: clip references and typed basic shapes.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const tokenizer = @import("tokenizer.zig");
const paint = @import("svg_paint.zig");
const positions = @import("position_values.zig");
const components = @import("shape_components.zig");
const Allocator = std.mem.Allocator;
const Value = values.Value;
const Radius = components.Radius;
const Linear = components.Linear;
const Commands = @import("shape_commands.zig").Commands;

pub const GeometryBox = enum {
    border_box,
    padding_box,
    content_box,
    margin_box,
    fill_box,
    stroke_box,
    view_box,
    pub fn name(self: GeometryBox) []const u8 {
        return switch (self) {
            .border_box => "border-box",
            .padding_box => "padding-box",
            .content_box => "content-box",
            .margin_box => "margin-box",
            .fill_box => "fill-box",
            .stroke_box => "stroke-box",
            .view_box => "view-box",
        };
    }
    pub fn parse(stream: *properties.Stream) ?GeometryBox {
        inline for (@typeInfo(GeometryBox).@"enum".fields) |f| {
            const box: GeometryBox = @enumFromInt(f.value);
            if (components.keyword(stream, box.name())) return box;
        }
        return null;
    }
};
const Extent = enum {
    closest_side,
    farthest_side,
    closest_corner,
    farthest_corner,
    fn name(self: Extent) []const u8 {
        return switch (self) {
            .closest_side => "closest-side",
            .farthest_side => "farthest-side",
            .closest_corner => "closest-corner",
            .farthest_corner => "farthest-corner",
        };
    }
};
const ShapeRadius = union(enum) {
    extent: Extent,
    value: Value,
    fn release(self: ShapeRadius) void {
        if (self == .value) self.value.release();
    }
    fn retain(self: ShapeRadius) void {
        if (self == .value) self.value.retain();
    }
    fn serialize(self: ShapeRadius, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .extent => |e| try out.appendSlice(allocator, e.name()),
            .value => |v| try properties.serializeValue(.margin_left, v, out, allocator),
        }
    }
    fn isDefault(self: ShapeRadius) bool {
        return self == .extent and self.extent == .closest_side;
    }
};
const Rect = struct {
    kind: enum { inset, rect, xywh },
    coordinates: union(enum) { specified: [4]Value, computed: [4]Linear },
    radii: ?Radius = null,
};
const Round = struct { ellipse: bool, radii: [2]ShapeRadius, position: ?*positions.Position = null };
const Polygon = struct { evenodd: bool, rounding: ?Value = null, points: []const [2]Value };
const Path = struct { evenodd: bool, text: *values.SharedText };

pub const Shape = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    box: ?GeometryBox = null,
    data: union(enum) { box, rect: Rect, round: Round, polygon: Polygon, path: Path, commands: Commands },

    pub fn ref(self: *Shape) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Shape) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.releaseData();
        self.allocator.destroy(self);
    }
    fn releaseData(self: *const Shape) void {
        switch (self.data) {
            .box => {},
            .rect => |r| {
                if (r.coordinates == .specified) components.releaseQuad(r.coordinates.specified);
                if (r.radii) |radii| for (radii) |q| components.releaseQuad(q);
            },
            .round => |r| {
                for (r.radii) |radius| radius.release();
                if (r.position) |p| p.unref();
            },
            .polygon => |p| {
                if (p.rounding) |r| r.release();
                for (p.points) |point| for (point) |v| v.release();
                self.allocator.free(p.points);
            },
            .path => |p| p.text.unref(),
            .commands => |c| c.deinit(self.allocator),
        }
    }

    pub fn compute(self: *const Shape, allocator: Allocator, context: anytype) Allocator.Error!*Shape {
        const result = try allocator.create(Shape);
        result.* = .{ .allocator = allocator, .box = self.box, .data = .box };
        errdefer result.unref();
        const data: @FieldType(Shape, "data") = switch (self.data) {
            .box => .box,
            .path => |p| blk: {
                p.text.ref();
                break :blk .{ .path = p };
            },
            .rect => |r| .{ .rect = try computeRect(r, context) },
            .round => |r| .{ .round = try computeRound(r, allocator, context) },
            .polygon => |p| .{ .polygon = try computePolygon(p, allocator, context) },
            .commands => |c| .{ .commands = try c.compute(allocator, context) },
        };
        result.data = data;
        return result;
    }

    pub fn needsUnavailableMetrics(self: *const Shape, geometry_length: bool) bool {
        switch (self.data) {
            .box, .path => {},
            .rect => |rect| {
                if (rect.coordinates == .specified) for (rect.coordinates.specified) |value| {
                    if (value.needsUnavailableMetrics(geometry_length)) return true;
                };
                if (rect.radii) |radii| for (radii) |quad| {
                    for (quad) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
                };
            },
            .round => |round| {
                for (round.radii) |radius| if (radius == .value and radius.value.needsUnavailableMetrics(geometry_length)) return true;
                if (round.position) |position| if (position.needsUnavailableMetrics(geometry_length)) return true;
            },
            .polygon => |polygon| {
                if (polygon.rounding) |value| if (value.needsUnavailableMetrics(geometry_length)) return true;
                for (polygon.points) |point| for (point) |value| {
                    if (value.needsUnavailableMetrics(geometry_length)) return true;
                };
            },
            .commands => |commands| return commands.needsUnavailableMetrics(geometry_length),
        }
        return false;
    }

    pub fn needsTreeCounts(self: *const Shape) bool {
        switch (self.data) {
            .box, .path => {},
            .rect => |rect| {
                if (rect.coordinates == .specified) for (rect.coordinates.specified) |value| {
                    if (value.needsTreeCounts()) return true;
                };
                if (rect.radii) |radii| for (radii) |quad| {
                    for (quad) |value| if (value.needsTreeCounts()) return true;
                };
            },
            .round => |round| {
                for (round.radii) |radius| if (radius == .value and radius.value.needsTreeCounts()) return true;
                if (round.position) |position| if (position.needsTreeCounts()) return true;
            },
            .polygon => |polygon| {
                if (polygon.rounding) |value| if (value.needsTreeCounts()) return true;
                for (polygon.points) |point| for (point) |value| {
                    if (value.needsTreeCounts()) return true;
                };
            },
            .commands => |commands| return commands.needsTreeCounts(),
        }
        return false;
    }

    pub fn needsRandomBase(self: *const Shape) bool {
        switch (self.data) {
            .box, .path => {},
            .rect => |rect| {
                if (rect.coordinates == .specified) for (rect.coordinates.specified) |value| {
                    if (value.needsRandomBase()) return true;
                };
                if (rect.radii) |radii| for (radii) |quad| {
                    for (quad) |value| if (value.needsRandomBase()) return true;
                };
            },
            .round => |round| {
                for (round.radii) |radius| if (radius == .value and radius.value.needsRandomBase()) return true;
                if (round.position) |position| if (position.needsRandomBase()) return true;
            },
            .polygon => |polygon| {
                if (polygon.rounding) |value| if (value.needsRandomBase()) return true;
                for (polygon.points) |point| for (point) |value| {
                    if (value.needsRandomBase()) return true;
                };
            },
            .commands => |commands| return commands.needsRandomBase(),
        }
        return false;
    }

    pub fn eql(self: *const Shape, other: *const Shape) bool {
        if (self == other) return true;
        if (self.box != other.box or std.meta.activeTag(self.data) != std.meta.activeTag(other.data)) return false;
        switch (self.data) {
            .box => return true,
            .commands => |c| return c.eql(other.data.commands),
            .path => |a| {
                const b = other.data.path;
                return a.evenodd == b.evenodd and std.mem.eql(u8, a.text.bytes, b.text.bytes);
            },
            .round => |a| {
                const b = other.data.round;
                if (a.ellipse != b.ellipse) return false;
                for (a.radii, b.radii) |x, y| {
                    if (std.meta.activeTag(x) != std.meta.activeTag(y)) return false;
                    if (x == .extent) {
                        if (x.extent != y.extent) return false;
                    } else if (!x.value.eql(y.value)) return false;
                }
                return if (a.position) |p| b.position != null and p.eql(b.position.?) else b.position == null;
            },
            .rect => |a| {
                const b = other.data.rect;
                if (a.kind != b.kind or std.meta.activeTag(a.coordinates) != std.meta.activeTag(b.coordinates)) return false;
                switch (a.coordinates) {
                    .specified => |q| if (!components.quadEql(q, b.coordinates.specified)) return false,
                    .computed => |q| {
                        for (q, b.coordinates.computed) |x, y| if (!x.eql(y)) return false;
                    },
                }
                if (a.radii) |r| {
                    if (b.radii == null) return false;
                    for (r, b.radii.?) |x, y| if (!components.quadEql(x, y)) return false;
                } else if (b.radii != null) return false;
                return true;
            },
            .polygon => |a| {
                const b = other.data.polygon;
                if (a.evenodd != b.evenodd or a.points.len != b.points.len) return false;
                if (a.rounding) |r| {
                    if (b.rounding == null or !r.eql(b.rounding.?)) return false;
                } else if (b.rounding != null) return false;
                for (a.points, b.points) |p, q| for (p, q) |x, y| if (!x.eql(y)) return false;
                return true;
            },
        }
    }

    pub fn serialize(self: *const Shape, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.data) {
            .box => return out.appendSlice(allocator, self.box.?.name()),
            .rect => |r| {
                try out.appendSlice(allocator, @tagName(r.kind));
                try out.append(allocator, '(');
                switch (r.coordinates) {
                    .specified => |q| {
                        if (r.kind == .inset) try components.serializeQuad(q, out, allocator) else for (q, 0..) |v, i| {
                            if (i > 0) try out.append(allocator, ' ');
                            try properties.serializeValue(.margin_left, v, out, allocator);
                        }
                    },
                    .computed => |q| {
                        var count: usize = 4;
                        if (q[1].eql(q[3])) {
                            count = 3;
                            if (q[0].eql(q[2])) {
                                count = 2;
                                if (q[0].eql(q[1])) count = 1;
                            }
                        }
                        for (q[0..count], 0..) |v, i| {
                            if (i > 0) try out.append(allocator, ' ');
                            try v.serialize(out, allocator);
                        }
                    },
                }
                if (r.radii) |radius| try components.serializeRadius(radius, out, allocator);
            },
            .round => |r| {
                try out.appendSlice(allocator, if (r.ellipse) "ellipse(" else "circle(");
                const radius_count: usize = if (r.ellipse) 2 else 1;
                const show_radius = !r.radii[0].isDefault() or (r.ellipse and !r.radii[1].isDefault());
                if (show_radius) for (r.radii[0..radius_count], 0..) |radius, i| {
                    if (i > 0) try out.append(allocator, ' ');
                    try radius.serialize(out, allocator);
                };
                if (r.position) |position| {
                    if (show_radius) try out.append(allocator, ' ');
                    try out.appendSlice(allocator, "at ");
                    try position.serialize(out, allocator);
                }
            },
            .polygon => |p| {
                try out.appendSlice(allocator, "polygon(");
                if (p.evenodd) try out.appendSlice(allocator, "evenodd");
                const rounding = if (p.rounding) |r| !components.zero(r) else false;
                if (rounding) {
                    if (p.evenodd) try out.append(allocator, ' ');
                    try out.appendSlice(allocator, "round ");
                    try properties.serializeValue(.margin_left, p.rounding.?, out, allocator);
                }
                if (p.evenodd or rounding) try out.appendSlice(allocator, ", ");
                for (p.points, 0..) |point, i| {
                    if (i > 0) try out.appendSlice(allocator, ", ");
                    try properties.serializeValue(.margin_left, point[0], out, allocator);
                    try out.append(allocator, ' ');
                    try properties.serializeValue(.margin_left, point[1], out, allocator);
                }
            },
            .path => |p| {
                try out.appendSlice(allocator, if (p.evenodd) "path(evenodd, " else "path(");
                try values.appendString(p.text.bytes, out, allocator);
            },
            .commands => |c| try c.serialize(out, allocator),
        }
        try out.append(allocator, ')');
        if (self.box) |box| if (box != .border_box) {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, box.name());
        };
    }
};

fn computeRect(rect: Rect, context: anytype) Allocator.Error!Rect {
    var q: [4]Linear = undefined;
    if (rect.coordinates == .computed) q = rect.coordinates.computed else {
        for (rect.coordinates.specified, 0..) |v, i| {
            if (v.isKeyword(.auto)) q[i] = .{ .percentage = if (i == 1 or i == 2) 100 else 0, .has_percent = true } else {
                const c = try context.length(v);
                defer c.release();
                q[i] = Linear.from(c);
            }
        }
        // Shapes §3.2: rect/xywh compute to inset, without using geometry.
        const hundred = Linear{ .percentage = 100, .has_percent = true };
        if (rect.kind == .rect) {
            var right = hundred;
            right.sub(q[1]);
            var bottom = hundred;
            bottom.sub(q[2]);
            q[1] = right;
            q[2] = bottom;
        } else if (rect.kind == .xywh) {
            var right = hundred;
            right.sub(q[0]);
            right.sub(q[2]);
            var bottom = hundred;
            bottom.sub(q[1]);
            bottom.sub(q[3]);
            // Zig builds an aggregate in its result location. Save both
            // inputs before overwriting q[0] during this reorder.
            const left = q[0];
            const top = q[1];
            q = .{ top, right, bottom, left };
        }
    }
    return .{ .kind = .inset, .coordinates = .{ .computed = q }, .radii = if (rect.radii) |r| try computeRadii(r, context) else null };
}

fn computeRadii(radii: Radius, context: anytype) Allocator.Error!Radius {
    var result: Radius = undefined;
    var count: usize = 0;
    errdefer for (0..count) |i| result[i / 4][i % 4].release();
    while (count < 8) : (count += 1) result[count / 4][count % 4] = try context.length(radii[count / 4][count % 4]);
    return result;
}

fn computeRound(round: Round, allocator: Allocator, context: anytype) Allocator.Error!Round {
    var radii: [2]ShapeRadius = undefined;
    var count: usize = 0;
    errdefer for (radii[0..count]) |r| r.release();
    while (count < 2) : (count += 1) radii[count] = switch (round.radii[count]) {
        .extent => |e| .{ .extent = e },
        .value => |v| .{ .value = try context.length(v) },
    };
    return .{ .ellipse = round.ellipse, .radii = radii, .position = if (round.position) |p| try p.compute(allocator, context) else null };
}

fn computePolygon(polygon: Polygon, allocator: Allocator, context: anytype) Allocator.Error!Polygon {
    const points = try allocator.alloc([2]Value, polygon.points.len);
    var count: usize = 0;
    errdefer {
        for (0..count) |i| points[i / 2][i % 2].release();
        allocator.free(points);
    }
    while (count < points.len * 2) : (count += 1) points[count / 2][count % 2] = try context.length(polygon.points[count / 2][count % 2]);
    return .{ .evenodd = polygon.evenodd, .points = points, .rounding = if (polygon.rounding) |r| try context.length(r) else null };
}

pub fn parse(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (components.keyword(stream, "none")) return Value.kw(.none);
    if (paint.isUrl(stream.peek())) return paint.parseReference(options, stream);
    var box = GeometryBox.parse(stream);
    const shape = try parseShape(options, stream) orelse {
        if (box == null) return null;
        const result = try options.allocator.create(Shape);
        result.* = .{ .allocator = options.allocator, .box = box, .data = .box };
        return .{ .shape = result };
    };
    if (box == null) box = GeometryBox.parse(stream);
    shape.box = box;
    return .{ .shape = shape };
}

fn parseShape(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?*Shape {
    const token = stream.peek();
    if (token.token_type != .function) return null;
    const kind: usize = blk: {
        inline for (.{ "inset", "rect", "xywh", "circle", "ellipse", "polygon", "path", "shape" }, 0..) |name, i| if (tokenizer.nameEql(token.value, name)) break :blk i;
        return null;
    };
    _ = stream.next();
    if (stream.next().token_type != .left_paren) return null;
    const data: @FieldType(Shape, "data") = switch (kind) {
        0, 1, 2 => .{ .rect = (try parseRect(options, stream, @enumFromInt(kind))) orelse return null },
        3, 4 => .{ .round = (try parseRound(options, stream, kind == 4)) orelse return null },
        5 => .{ .polygon = (try parsePolygon(options, stream)) orelse return null },
        6 => .{ .path = (try parsePath(options, stream)) orelse return null },
        7 => .{ .commands = (try @import("shape_commands.zig").parse(options, stream)) orelse return null },
        else => unreachable,
    };
    const temporary = Shape{ .allocator = options.allocator, .data = data };
    errdefer temporary.releaseData();
    if (stream.next().token_type != .right_paren) {
        temporary.releaseData();
        return null;
    }
    const result = try options.allocator.create(Shape);
    result.* = temporary;
    return result;
}

fn parseRect(options: properties.ParseOptions, stream: *properties.Stream, kind: @FieldType(Rect, "kind")) Allocator.Error!?Rect {
    var q: [4]Value = undefined;
    var count: usize = 0;
    var moved = false;
    defer if (!moved) for (q[0..count]) |v| v.release();
    if (kind == .inset) {
        q = (try components.quad(options, stream, true)) orelse return null;
        count = 4;
    } else while (count < 4) : (count += 1) {
        if (kind == .rect and components.keyword(stream, "auto")) q[count] = Value.kw(.auto) else q[count] = (try components.length(options, stream, kind != .xywh or count < 2, true)) orelse return null;
    }
    var radii: ?Radius = null;
    if (components.keyword(stream, "round")) radii = (try components.radius(options, stream)) orelse return null;
    moved = true;
    return .{ .kind = kind, .coordinates = .{ .specified = q }, .radii = radii };
}

fn parseRadius(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?ShapeRadius {
    inline for (@typeInfo(Extent).@"enum".fields) |f| {
        const e: Extent = @enumFromInt(f.value);
        if (components.keyword(stream, e.name())) return .{ .extent = e };
    }
    return if (try components.length(options, stream, false, true)) |v| .{ .value = v } else null;
}

fn parseRound(options: properties.ParseOptions, stream: *properties.Stream, ellipse: bool) Allocator.Error!?Round {
    var result = Round{ .ellipse = ellipse, .radii = .{ .{ .extent = .closest_side }, .{ .extent = .closest_side } } };
    var moved = false;
    defer if (!moved) {
        for (result.radii) |radius| radius.release();
        if (result.position) |position| position.unref();
    };
    if (try parseRadius(options, stream)) |radius| {
        result.radii[0] = radius;
        // Q8: the pinned two-radius ellipse grammar wins by all browsers.
        if (ellipse) result.radii[1] = (try parseRadius(options, stream)) orelse return null;
    }
    if (components.keyword(stream, "at")) result.position = (try positions.parse(options, stream, .position)) orelse return null;
    moved = true;
    return result;
}

fn parsePolygon(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Polygon {
    const evenodd = components.keyword(stream, "evenodd");
    const has_rule = evenodd or components.keyword(stream, "nonzero");
    var rounding: ?Value = null;
    defer if (rounding) |r| r.release();
    if (components.keyword(stream, "round")) rounding = (try components.length(options, stream, false, false)) orelse return null;
    if ((has_rule or rounding != null) and stream.next().token_type != .comma) return null;
    var points: std.ArrayList([2]Value) = .empty;
    defer {
        for (points.items) |point| for (point) |v| v.release();
        points.deinit(options.allocator);
    }
    while (true) {
        const x = (try components.length(options, stream, true, true)) orelse return null;
        defer x.release();
        const y = (try components.length(options, stream, true, true)) orelse return null;
        defer y.release();
        try points.ensureUnusedCapacity(options.allocator, 1);
        x.retain();
        y.retain();
        points.appendAssumeCapacity(.{ x, y });
        if (stream.peek().token_type != .comma) break;
        _ = stream.next();
    }
    const owned = try points.toOwnedSlice(options.allocator);
    if (rounding) |r| r.retain();
    return .{ .evenodd = evenodd, .rounding = rounding, .points = owned };
}

fn parsePath(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Path {
    const evenodd = components.keyword(stream, "evenodd");
    const has_rule = evenodd or components.keyword(stream, "nonzero");
    if (has_rule and stream.next().token_type != .comma) return null;
    const t = stream.next();
    if (t.token_type != .string) return null;
    const decoded = try tokenizer.decode(options.allocator, t.stringContents());
    defer options.allocator.free(decoded);
    return .{ .evenodd = evenodd, .text = (try @import("path_values.zig").parse(options.allocator, decoded)) orelse return null };
}
