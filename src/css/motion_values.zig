//! Motion Path 1 §§2.1–2.6: specified and computed components, without layout.
const std = @import("std");
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const positions = @import("position_values.zig");
const shapes = @import("shape_values.zig");
const tokens = @import("tokenizer.zig");
const math = @import("math_values.zig");
const Number = @import("numeric_values.zig").Number;
const keyword = @import("shape_components.zig").keyword;
const Allocator = std.mem.Allocator;
const Value = values.Value;

pub const longhands = [_]properties.Longhand{ .offset_position, .offset_path, .offset_distance, .offset_rotate, .offset_anchor };

pub fn consumePosition(options: properties.ParseOptions, stream: *properties.Stream, normal: bool) Allocator.Error!?Value {
    // §§2.3–2.4: auto is a computed keyword, not a fabricated box position.
    if (keyword(stream, "auto")) return Value.kw(.auto);
    if (normal and keyword(stream, "normal")) return Value.kw(.normal);
    const position = try positions.parse(options, stream, .position) orelse return null;
    return .{ .image_position = position };
}

pub const Rotation = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    mode: ?enum { auto, reverse },
    angle: Number,

    /// Takes one reference to the borrowed angle after allocation succeeds.
    pub fn create(allocator: Allocator, mode: @FieldType(Rotation, "mode"), angle: Number) Allocator.Error!*Rotation {
        const result = try allocator.create(Rotation);
        result.* = .{ .allocator = allocator, .mode = mode, .angle = angle };
        angle.ref();
        return result;
    }
    pub fn ref(self: *Rotation) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Rotation) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.angle.unref();
        self.allocator.destroy(self);
    }
    pub fn eql(self: *const Rotation, other: *const Rotation) bool {
        return self == other or (self.mode == other.mode and self.angle.eql(other.angle));
    }
    pub fn needsUnavailableMetrics(self: *const Rotation, geometry_length: bool) bool {
        return self.angle.needsUnavailableMetrics(geometry_length);
    }
    pub fn needsTreeCounts(self: *const Rotation) bool {
        return self.angle.needsTreeCounts();
    }
    pub fn needsRandomBase(self: *const Rotation) bool {
        return self.angle.needsRandomBase();
    }
    pub fn compute(self: *const Rotation, allocator: Allocator, context: math.Context) Allocator.Error!Value {
        var angle = try self.angle.compute(allocator, context);
        defer angle.unref();
        // §2.5: reverse computes to auto plus 180deg. An angle is never
        // reduced modulo a full turn: 5turn remains 1800deg.
        if (self.mode == .reverse) {
            if (angle == .literal) {
                angle.literal.value += 180;
            } else {
                const half = (try math.dimension(allocator, .{ .value = 180, .unit = .deg }, .{ .kind = .angle })).?;
                defer half.unref();
                const sum = (try math.compose(allocator, .{ .kind = .angle }, .add, angle.calculation, half)).?;
                defer sum.unref();
                const result = try (Number{ .calculation = sum }).compute(allocator, context);
                angle.unref();
                angle = result;
            }
        }
        const mode: @FieldType(Rotation, "mode") = if (self.mode != null) .auto else null;
        if (mode == .auto and isZero(angle)) return Value.kw(.auto);
        return .{ .motion_rotation = try create(allocator, mode, angle) };
    }
    pub fn serialize(self: *const Rotation, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self.mode) |mode| {
            try out.appendSlice(allocator, @tagName(mode));
            if (isZero(self.angle)) return;
            try out.append(allocator, ' ');
        }
        try self.angle.serialize(out, allocator);
    }
};

fn isZero(angle: Number) bool {
    return angle == .literal and angle.literal.value == 0;
}

pub const RaySize = enum {
    closest_side,
    closest_corner,
    farthest_side,
    farthest_corner,
    sides,
    fn name(self: RaySize) []const u8 {
        return switch (self) {
            .closest_side => "closest-side",
            .closest_corner => "closest-corner",
            .farthest_side => "farthest-side",
            .farthest_corner => "farthest-corner",
            .sides => "sides",
        };
    }
    fn consume(stream: *properties.Stream) ?RaySize {
        inline for (@typeInfo(RaySize).@"enum".field_values) |value| {
            const size: RaySize = @fromBackingInt(@intCast(value));
            if (keyword(stream, size.name())) return size;
        }
        return null;
    }
};
pub const Ray = struct {
    angle: Number,
    size: RaySize = .closest_side,
    contain: bool = false,
    position: ?*positions.Position = null,
};
pub const PathData = union(enum) {
    box,
    url: Value,
    shape: *shapes.Shape,
    ray: Ray,

    fn retain(self: PathData) void {
        switch (self) {
            .box => {},
            .url => |url| url.retain(),
            .shape => |shape| shape.ref(),
            .ray => |ray| {
                ray.angle.ref();
                if (ray.position) |position| position.ref();
            },
        }
    }
    fn release(self: PathData) void {
        switch (self) {
            .box => {},
            .url => |url| url.release(),
            .shape => |shape| shape.unref(),
            .ray => |ray| {
                ray.angle.unref();
                if (ray.position) |position| position.unref();
            },
        }
    }
};

pub const Path = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    data: PathData,
    box: shapes.GeometryBox,

    /// Retains the borrowed component only after allocation succeeds.
    pub fn create(allocator: Allocator, data: PathData, box: shapes.GeometryBox) Allocator.Error!*Path {
        const result = try allocator.create(Path);
        result.* = .{ .allocator = allocator, .data = data, .box = box };
        data.retain();
        return result;
    }
    pub fn ref(self: *Path) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }
    pub fn unref(self: *Path) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.data.release();
        self.allocator.destroy(self);
    }
    pub fn resourceUrls(self: *const Path) []const values.ResourceUrl {
        // The URL always serializes first, so its source ranges do not move.
        return if (self.data == .url) self.data.url.resourceUrls() else &.{};
    }
    pub fn needsUnavailableMetrics(self: *const Path, geometry_length: bool) bool {
        return switch (self.data) {
            .box, .url => false,
            .shape => |shape| shape.needsUnavailableMetrics(geometry_length),
            .ray => |ray| ray.angle.needsUnavailableMetrics(false) or
                (if (ray.position) |position| position.needsUnavailableMetrics(geometry_length) else false),
        };
    }
    pub fn needsTreeCounts(self: *const Path) bool {
        return switch (self.data) {
            .box, .url => false,
            .shape => |shape| shape.needsTreeCounts(),
            .ray => |ray| ray.angle.needsTreeCounts() or
                (if (ray.position) |position| position.needsTreeCounts() else false),
        };
    }
    pub fn needsRandomBase(self: *const Path) bool {
        return switch (self.data) {
            .box, .url => false,
            .shape => |shape| shape.needsRandomBase(),
            .ray => |ray| ray.angle.needsRandomBase() or
                (if (ray.position) |position| position.needsRandomBase() else false),
        };
    }
    pub fn eql(self: *const Path, other: *const Path) bool {
        if (self == other) return true;
        if (self.box != other.box or std.meta.activeTag(self.data) != std.meta.activeTag(other.data)) return false;
        return switch (self.data) {
            .box => true,
            .url => |url| url.eql(other.data.url),
            .shape => |shape| shape.eql(other.data.shape),
            .ray => |ray| blk: {
                const rhs = other.data.ray;
                if (ray.size != rhs.size or ray.contain != rhs.contain or !ray.angle.eql(rhs.angle)) break :blk false;
                break :blk if (ray.position) |position|
                    rhs.position != null and position.eql(rhs.position.?)
                else
                    rhs.position == null;
            },
        };
    }
    pub fn compute(self: *const Path, allocator: Allocator, components: anytype, numeric: math.Context) Allocator.Error!*Path {
        // §2.1's computed value resolves lengths/angles, retaining any
        // geometry needed by the used-value path and absent ray positions.
        switch (self.data) {
            .box, .url => return create(allocator, self.data, self.box),
            .shape => |shape| {
                const computed = try shape.compute(allocator, components);
                defer computed.unref();
                return create(allocator, .{ .shape = computed }, self.box);
            },
            .ray => |ray| {
                const angle = try ray.angle.compute(allocator, numeric);
                defer angle.unref();
                const position = if (ray.position) |p| try p.compute(allocator, components) else null;
                defer if (position) |p| p.unref();
                return create(allocator, .{ .ray = .{ .angle = angle, .size = ray.size, .contain = ray.contain, .position = position } }, self.box);
            },
        }
    }
    pub fn serialize(self: *const Path, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.data) {
            .box => return out.appendSlice(allocator, self.box.name()),
            .url => |url| try properties.serializeValue(.list_style_image, url, out, allocator),
            .shape => |shape| try shape.serialize(out, allocator),
            .ray => |ray| {
                try out.appendSlice(allocator, "ray(");
                try ray.angle.serialize(out, allocator);
                if (ray.size != .closest_side) {
                    try out.append(allocator, ' ');
                    try out.appendSlice(allocator, ray.size.name());
                }
                if (ray.contain) try out.appendSlice(allocator, " contain");
                if (ray.position) |position| {
                    try out.appendSlice(allocator, " at ");
                    try position.serialize(out, allocator);
                }
                try out.append(allocator, ')');
            },
        }
        // §2.1: border-box is the omitted coordinate box.
        if (self.box != .border_box) {
            try out.append(allocator, ' ');
            try out.appendSlice(allocator, self.box.name());
        }
    }
};

fn consumeBox(stream: *properties.Stream) ?shapes.GeometryBox {
    var trial = stream.*;
    const box = shapes.GeometryBox.parse(&trial) orelse return null;
    if (box == .margin_box) return null;
    stream.* = trial;
    return box;
}

fn consumeRay(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Ray {
    const token = stream.peek();
    if (token.token_type != .function or !tokens.nameEql(token.value, "ray")) return null;
    _ = stream.next();
    if (stream.next().token_type != .left_paren) return null;
    var angle: ?Number = null;
    var size: ?RaySize = null;
    var contain = false;
    var position: ?*positions.Position = null;
    var moved = false;
    defer if (!moved) {
        if (angle) |a| a.unref();
        if (position) |p| p.unref();
    };
    // §2.1.1: angle && size? && contain? && [at position]?; the
    // shared position parser leaves subsequent ray components unread.
    while (stream.peek().token_type != .right_paren and !stream.atEnd()) {
        if (angle == null) {
            var trial = stream.*;
            if (try Number.consume(options, &trial, .{ .kind = .angle }, false)) |a| {
                angle = a;
                stream.* = trial;
                continue;
            }
        }
        if (size == null) if (RaySize.consume(stream)) |s| {
            size = s;
            continue;
        };
        if (!contain and keyword(stream, "contain")) {
            contain = true;
            continue;
        }
        if (position == null and keyword(stream, "at")) {
            position = try positions.parse(options, stream, .position) orelse return null;
            continue;
        }
        return null;
    }
    if (angle == null) return null;
    if (!stream.atEnd()) _ = stream.next();
    moved = true;
    return .{ .angle = angle.?, .size = size orelse .closest_side, .contain = contain, .position = position };
}

pub fn consumePath(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    if (keyword(stream, "none")) return Value.kw(.none);
    var box = consumeBox(stream);
    var data: PathData = .box;
    defer data.release();
    const token = stream.peek();
    if (token.token_type == .function and tokens.nameEql(token.value, "ray")) {
        data = .{ .ray = try consumeRay(options, stream) orelse return null };
    } else if (@import("svg_paint.zig").isUrl(token)) {
        data = .{ .url = try @import("svg_paint.zig").parseReference(options, stream) orelse return null };
    } else {
        var trial = stream.*;
        // Motion 1 §2.1 imports <basic-shape>, whose Shapes 1 path() grammar
        // permits a fill-rule. But fxtf-drafts#512 settled on ignoring it in
        // path contexts, and css/motion/parsing/offset-path-parsing-invalid.html
        // records unanimous Chrome 156, Firefox 159, and Safari 27.2 rejection
        // of both values. Q60 therefore rejects explicit path() fill-rules for
        // offset-path only; inspect CSS tokens so escapes and case are handled
        // by the tokenizer, while the shared shape parser remains unchanged.
        var lookahead = trial;
        const shape_token = lookahead.peek();
        if (shape_token.token_type == .function and tokens.nameEql(shape_token.value, "path")) {
            _ = lookahead.next();
            if (lookahead.next().token_type == .left_paren) {
                const first = lookahead.peek();
                if (first.token_type == .ident and (tokens.nameEql(first.value, "nonzero") or tokens.nameEql(first.value, "evenodd"))) return null;
            }
        }
        if (try shapes.consumeBasicShape(options, &trial)) |shape| {
            data = .{ .shape = shape };
            stream.* = trial;
        } else if (trial.tok.pos != stream.tok.pos) {
            // A recognized but malformed shape cannot become a bare box.
            // An unrelated function stays unread for a shorthand's distance.
            return null;
        }
    }
    if (box == null) box = consumeBox(stream);
    if (data == .box and box == null) return null;
    return .{ .motion_path = try Path.create(options.allocator, data, box orelse .border_box) };
}

pub fn consumeRotation(options: properties.ParseOptions, stream: *properties.Stream) Allocator.Error!?Value {
    var mode: @FieldType(Rotation, "mode") = null;
    var angle: ?Number = null;
    defer if (angle) |number| number.unref();
    for (0..2) |_| {
        if (mode == null) {
            if (keyword(stream, "auto")) {
                mode = .auto;
                continue;
            }
            if (keyword(stream, "reverse")) {
                mode = .reverse;
                continue;
            }
        }
        if (angle == null) {
            var trial = stream.*;
            if (try Number.consume(options, &trial, .{ .kind = .angle }, false)) |number| {
                angle = number;
                stream.* = trial;
                continue;
            }
        }
        break;
    }
    if (mode == null and angle == null) return null;
    const number = angle orelse Number{ .literal = .{ .value = 0, .unit = .deg } };
    if (mode == .auto and isZero(number)) return Value.kw(.auto);
    return .{ .motion_rotation = try Rotation.create(options.allocator, mode, number) };
}

pub fn consumeShorthand(options: properties.ParseOptions, stream: *properties.Stream, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    // §2.6: [position? [path [distance || rotate]?]?]! [/ anchor]?
    // Rotation is one component: reverse <distance> <angle> cannot split it.
    var parsed: [longhands.len]?Value = @splat(null);
    defer for (parsed) |item| if (item) |value| value.release();
    var trial = stream.*;
    if (try consumePosition(options, &trial, true)) |position| {
        parsed[0] = position;
        stream.* = trial;
    }
    trial = stream.*;
    if (try consumePath(options, &trial)) |path| {
        parsed[1] = path;
        stream.* = trial;
        for (0..2) |_| {
            var matched = false;
            for ([_]usize{ 2, 3 }) |index| {
                if (parsed[index] != null) continue;
                trial = stream.*;
                if (try properties.parseLonghand(options, longhands[index], &trial)) |component| {
                    parsed[index] = component;
                    stream.* = trial;
                    matched = true;
                    break;
                }
            }
            if (!matched) break;
        }
    }
    if (parsed[0] == null and parsed[1] == null) return false;
    const token = stream.peek();
    if (token.token_type == .delim and std.mem.eql(u8, token.value, "/")) {
        _ = stream.next();
        parsed[4] = try consumePosition(options, stream, false) orelse return false;
    }
    if (!stream.atEnd()) return false;
    try out.ensureUnusedCapacity(options.allocator, longhands.len);
    for (longhands, parsed) |longhand, item| {
        const value = item orelse longhand.info().initial;
        value.retain();
        out.appendAssumeCapacity(.{ .longhand = longhand, .value = .{ .value = value } });
    }
    return true;
}

pub fn serializeShorthand(assigned: []const properties.Assigned, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!bool {
    const position = assigned[0].value;
    const path = assigned[1].value;
    const distance = assigned[2].value;
    const rotation = assigned[3].value;
    const anchor = assigned[4].value;
    var wrote = false;
    if (!position.isKeyword(.normal)) {
        try properties.serializeValue(.offset_position, position, out, allocator);
        wrote = true;
    }
    const show_distance = distance != .length or distance.length.value != 0;
    const show_rotation = !rotation.isKeyword(.auto);
    if (!path.isKeyword(.none) or show_distance or show_rotation or !wrote) {
        if (wrote) try out.append(allocator, ' ');
        try properties.serializeValue(.offset_path, path, out, allocator);
        if (show_distance) {
            try out.append(allocator, ' ');
            try properties.serializeValue(.offset_distance, distance, out, allocator);
        }
        if (show_rotation) {
            try out.append(allocator, ' ');
            try properties.serializeValue(.offset_rotate, rotation, out, allocator);
        }
    }
    if (!anchor.isKeyword(.auto)) {
        try out.appendSlice(allocator, " / ");
        try properties.serializeValue(.offset_anchor, anchor, out, allocator);
    }
    return true;
}
