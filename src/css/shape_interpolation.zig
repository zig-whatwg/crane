//! Combining computed basic shapes (CSS Shapes 1 3.4 "Interpolation of
//! Basic Shapes"), path() data (SVG 2 9.3 "the d property": "two d property
//! values can only be interpolated smoothly when the path data strings
//! contain have the same structure"; CSS Shapes 1 3.1.1.2), for offset-path
//! (CSS Motion Path 1 2.1), clip-path (CSS Masking 1 3.1), shape-outside
//! (CSS Shapes 1 5.1) and object-view-box (CSS Images 5).
//!
//! Every result is OWNED by the caller (one reference); inputs are borrowed.
//! Null means "no interpolation is specified" (Shapes 1 3.4: "In all other
//! cases no interpolation is specified"): the caller combines discretely.
//!
//! Engines (designs only): Blink BasicShapeInterpolationFunctions (circle,
//! ellipse, inset, polygon: same type, same reference box, same vertex count
//! and fill-rule) and SVGPathBlender / CSSPathInterpolationType (absolute
//! coordinates, arc flags); Gecko servo values/animated basic_shape.rs and
//! SVGPathData::animate (normalized to absolute before animating).
//!
//! Spec: https://drafts.csswg.org/css-shapes-1/#basic-shape-interpolation
//! Spec: https://svgwg.org/svg2-draft/paths.html#DProperty
const std = @import("std");
const values = @import("style_values.zig");
const shapes = @import("shape_values.zig");
const components = @import("shape_components.zig");
const path_values = @import("path_values.zig");
const position_values = @import("position_values.zig");
const interpolation = @import("interpolation.zig");

const Allocator = std.mem.Allocator;
const Value = values.Value;
const Shape = shapes.Shape;
const Linear = components.Linear;

/// How two shapes combine: their numeric components as a * ka + b * kb;
/// `p` is the interpolation progress for the parts that are not linear (an
/// arc flag), null for addition and accumulation (the effect's value wins).
pub const Mix = struct { ka: f64, kb: f64, p: ?f64 };

/// Two computed shapes combined (Shapes 1 3.4): the same reference box, the
/// same shape type, then each value of the shape function. OWNED.
pub fn mixShapes(allocator: Allocator, a: *const Shape, b: *const Shape, m: Mix) Allocator.Error!?*Shape {
    // "Both shapes must use the same reference box."
    if ((a.box == null) != (b.box == null)) return null;
    if (a.box) |box| if (box != b.box.?) return null;
    const result = try allocator.create(Shape);
    errdefer allocator.destroy(result);
    const data = (try mixData(allocator, a, b, m)) orelse {
        allocator.destroy(result);
        return null;
    };
    result.* = .{ .allocator = allocator, .box = a.box, .data = data };
    return result;
}

fn mixData(allocator: Allocator, a: *const Shape, b: *const Shape, m: Mix) Allocator.Error!?@FieldType(Shape, "data") {
    switch (a.data) {
        .path => |pa| switch (b.data) {
            .path => |pb| {
                if (pa.evenodd != pb.evenodd) return null;
                const text = (try mixPathText(allocator, pa.text.bytes, pb.text.bytes, m)) orelse return null;
                return .{ .path = .{ .evenodd = pa.evenodd, .text = text } };
            },
            // Shapes 1 3.1.1.2: path() and shape() interpolate with each
            // other; the result is a shape().
            .commands => |cb| {
                const ca = (try commandsOfPath(allocator, pa.evenodd, pa.text.bytes)) orelse return null;
                defer ca.deinit(allocator);
                return .{ .commands = (try mixCommands(allocator, ca, cb, m)) orelse return null };
            },
            else => return null,
        },
        .commands => |ca| switch (b.data) {
            .commands => |cb| return .{ .commands = (try mixCommands(allocator, ca, cb, m)) orelse return null },
            .path => |pb| {
                const cb = (try commandsOfPath(allocator, pb.evenodd, pb.text.bytes)) orelse return null;
                defer cb.deinit(allocator);
                return .{ .commands = (try mixCommands(allocator, ca, cb, m)) orelse return null };
            },
            else => return null,
        },
        .round => |ra| {
            const rb = switch (b.data) {
                .round => |r| r,
                else => return null,
            };
            return .{ .round = (try mixRounds(allocator, ra, rb, m)) orelse return null };
        },
        .rect => |ra| {
            const rb = switch (b.data) {
                .rect => |r| r,
                else => return null,
            };
            return .{ .rect = (try mixInsets(allocator, ra, rb, m)) orelse return null };
        },
        .polygon => |pa| {
            const pb = switch (b.data) {
                .polygon => |p| p,
                else => return null,
            };
            return .{ .polygon = (try mixPolygons(allocator, pa, pb, m)) orelse return null };
        },
        // A box alone: no interpolation (a pair that matches is equal,
        // which discrete returns unchanged).
        .box => return null,
    }
}

// ============================================================================
// path() (SVG 2 9.3; Shapes 1 3.1.1.2)
// ============================================================================

/// Two canonical path data strings with the same structure - the same number
/// of commands of the same types, in order, compared in absolute form
/// (Blink SVGPathBlender and Gecko SVGPathData both absolutize first) -
/// combined parameter by parameter "as real numbers". Arc flags interpolate
/// "as fractions between zero and one, with any non-zero value considered to
/// be a value of one": for p in (0, 1) either set flag gives 1; outside the
/// interval the nearer endpoint's flag (WPT
/// css/motion/animation/offset-path-interpolation-002.html, which Chrome,
/// Firefox and Safari pass). Addition takes the effect value's flags. The
/// result is absolute canonical text; null when the structures differ or a
/// number overflows.
pub fn mixPathText(allocator: Allocator, a: []const u8, b: []const u8, m: Mix) Allocator.Error!?*values.SharedText {
    var xs = path_values.Absolutizer.init(a);
    var ys = path_values.Absolutizer.init(b);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    while (true) {
        const x = xs.next() catch return null;
        const y = ys.next() catch return null;
        if (x == null and y == null) break;
        const sx = x orelse return null;
        const sy = y orelse return null;
        if (sx.command != sy.command) return null;
        var segment: path_values.Segment = .{ .command = sx.command, .count = sx.count };
        for (0..sx.count) |i| {
            const is_flag = sx.command == 'A' and (i == 3 or i == 4);
            segment.args[i] = if (is_flag) mixFlag(sx.args[i], sy.args[i], m) else sx.args[i] * m.ka + sy.args[i] * m.kb;
            if (!std.math.isFinite(segment.args[i])) return null;
        }
        if (out.items.len > 0) try out.append(allocator, ' ');
        try path_values.appendSegment(segment, &out, allocator);
    }
    return try values.SharedText.create(allocator, out.items);
}

fn mixFlag(a: f64, b: f64, m: Mix) f64 {
    const p = m.p orelse return b;
    if (p <= 0) return a;
    if (p >= 1) return b;
    return if (a != 0 or b != 0) 1 else 0;
}

// ============================================================================
// circle() and ellipse()
// ============================================================================

const Round = @FieldType(@FieldType(Shape, "data"), "round");
const ShapeRadius = @typeInfo(@FieldType(Round, "radii")).array.child;

/// "If both shapes are the same type, that type is ellipse() or circle(),
/// and the radiuses are specified as <length-percentage> (rather than
/// keywords), interpolate between each value in the shape functions." A
/// keyword radius combines only with the same keyword; an omitted position
/// is the center (Shapes 1 3.1: "If omitted, the position defaults to
/// center").
fn mixRounds(allocator: Allocator, a: Round, b: Round, m: Mix) Allocator.Error!?Round {
    if (a.ellipse != b.ellipse) return null;
    var radii: [2]ShapeRadius = undefined;
    var made: usize = 0;
    var done = false;
    defer if (!done) for (radii[0..made]) |r| if (r == .value) r.value.release();
    for (a.radii, b.radii) |x, y| {
        radii[made] = switch (x) {
            .extent => |e| if (y == .extent and y.extent == e) .{ .extent = e } else return null,
            .value => |v| if (y == .value) .{
                .value = interpolation.nonNegative((try interpolation.mixLengthPercentage(allocator, v, m.ka, y.value, m.kb)) orelse return null),
            } else return null,
        };
        made += 1;
    }
    var position: ?*position_values.Position = null;
    if (a.position != null or b.position != null) {
        var center_a = center(allocator);
        var center_b = center(allocator);
        const pa = a.position orelse &center_a;
        const pb = b.position orelse &center_b;
        const mixed = (try interpolation.mixPosition(allocator, pa, m.ka, pb, m.kb)) orelse return null;
        position = mixed.image_position;
    }
    done = true;
    return .{ .ellipse = a.ellipse, .radii = radii, .position = position };
}

/// The computed `center` position, 50% 50%, on the stack (no allocation:
/// percentages own nothing).
fn center(allocator: Allocator) position_values.Position {
    const half: Value = .{ .length = .percent(50) };
    return .{ .allocator = allocator, .data = .{ .computed = .{ .{ .value = half }, .{ .value = half } } } };
}

// ============================================================================
// inset() (rect() and xywh() compute to inset())
// ============================================================================

const Rect = @FieldType(@FieldType(Shape, "data"), "rect");

/// "If both shapes are of type inset(), interpolate between each value in
/// the shape functions": the four offsets as length-percentages, and the
/// corner radii (an omitted radius is zero).
fn mixInsets(allocator: Allocator, a: Rect, b: Rect, m: Mix) Allocator.Error!?Rect {
    if (a.kind != .inset or b.kind != .inset) return null;
    const qa = linearQuad(a) orelse return null;
    const qb = linearQuad(b) orelse return null;
    var q: [4]Linear = undefined;
    for (&q, qa, qb) |*out, x, y| out.* = .{
        .percentage = x.percentage * m.ka + y.percentage * m.kb,
        .px = x.px * m.ka + y.px * m.kb,
        .has_percent = x.has_percent or y.has_percent,
        .has_px = x.has_px or y.has_px,
    };
    var radii: ?components.Radius = null;
    if (a.radii != null or b.radii != null) {
        const zero: components.Radius = @splat(@splat(Value.px(0)));
        const ra = a.radii orelse zero;
        const rb = b.radii orelse zero;
        var out: components.Radius = undefined;
        var made: usize = 0;
        var done = false;
        defer if (!done) for (0..made) |i| out[i / 4][i % 4].release();
        while (made < 8) : (made += 1) {
            const x = ra[made / 4][made % 4];
            const y = rb[made / 4][made % 4];
            out[made / 4][made % 4] = interpolation.nonNegative((try interpolation.mixLengthPercentage(allocator, x, m.ka, y, m.kb)) orelse return null);
        }
        done = true;
        radii = out;
    }
    return .{ .kind = .inset, .coordinates = .{ .computed = q }, .radii = radii };
}

/// A computed inset's four offsets as px + percentage sums; null for one
/// whose offsets are math this cannot split (a calc() with other terms).
fn linearQuad(rect: Rect) ?[4]Linear {
    switch (rect.coordinates) {
        .computed => |q| return q,
        .computed_values => |q| {
            var out: [4]Linear = undefined;
            for (&out, q) |*l, v| l.* = linearOf(v) orelse return null;
            return out;
        },
        .specified => return null,
    }
}

fn linearOf(v: Value) ?Linear {
    return switch (v) {
        .length => |len| switch (len.unit) {
            .px, .percent => Linear.from(v),
            else => null,
        },
        .calculation => |c| blk: {
            const n = c.computedNumber() orelse break :blk null;
            break :blk switch (n.unit) {
                .px => .{ .px = n.value, .has_px = true },
                .percent => .{ .percentage = n.value, .has_percent = true },
                else => null,
            };
        },
        else => null,
    };
}

// ============================================================================
// polygon()
// ============================================================================

const Polygon = @FieldType(@FieldType(Shape, "data"), "polygon");

/// "If both shapes are of type polygon(), both polygons have the same number
/// of vertices, and use the same <'fill-rule'>, interpolate between each
/// value in the shape functions."
fn mixPolygons(allocator: Allocator, a: Polygon, b: Polygon, m: Mix) Allocator.Error!?Polygon {
    if (a.evenodd != b.evenodd or a.points.len != b.points.len) return null;
    if ((a.rounding == null) != (b.rounding == null)) return null;
    const points = try allocator.alloc([2]Value, a.points.len);
    var made: usize = 0;
    var done = false;
    defer if (!done) {
        for (0..made) |i| points[i / 2][i % 2].release();
        allocator.free(points);
    };
    while (made < points.len * 2) : (made += 1) {
        const x = a.points[made / 2][made % 2];
        const y = b.points[made / 2][made % 2];
        points[made / 2][made % 2] = (try interpolation.mixLengthPercentage(allocator, x, m.ka, y, m.kb)) orelse return null;
    }
    var rounding: ?Value = null;
    if (a.rounding) |x| rounding = interpolation.nonNegative((try interpolation.mixLengthPercentage(allocator, x, m.ka, b.rounding.?, m.kb)) orelse return null);
    done = true;
    return .{ .evenodd = a.evenodd, .rounding = rounding, .points = points };
}

// ============================================================================
// shape() (CSS Shapes 1 3.1.1.2 "Interpolating the shape() Function")
// ============================================================================

const shape_commands = @import("shape_commands.zig");
const Commands = shape_commands.Commands;
const Command = @typeInfo(@FieldType(Commands, "items")).pointer.child;
const Endpoint = @FieldType(Command, "endpoint");
const Point = @FieldType(Endpoint, "point");
const Control = @typeInfo(@FieldType(Command, "controls")).array.child;
const Arc = @typeInfo(@FieldType(Command, "arc")).optional.child;

/// Two shape() command lists "of the same length [with] the same commands,
/// in order": "commands are 'the same' if they use the same command keyword,
/// and use the same <by-to> keyword. For curve and smooth, they also must
/// have the same number of control points." The `from` positions and every
/// numeric component combine; an arc's differing <arc-sweep> is cw, and
/// differing <arc-size> large, "for any progress value between 0 and 1"
/// (outside it the nearer endpoint's). OWNED; null for lists that differ.
pub fn mixCommands(allocator: Allocator, a: Commands, b: Commands, m: Mix) Allocator.Error!?Commands {
    if (a.evenodd != b.evenodd or a.items.len != b.items.len) return null;
    const origin_value = (try interpolation.mixPosition(allocator, a.origin, m.ka, b.origin, m.kb)) orelse return null;
    const origin = origin_value.image_position;
    const items = allocator.alloc(Command, a.items.len) catch |err| {
        origin.unref();
        return err;
    };
    var made: usize = 0;
    var done = false;
    defer if (!done) {
        for (items[0..made]) |c| c.release();
        allocator.free(items);
        origin.unref();
    };
    for (a.items, b.items) |x, y| {
        items[made] = (try mixCommand(allocator, x, y, m)) orelse return null;
        made += 1;
    }
    done = true;
    return .{ .evenodd = a.evenodd, .origin = origin, .items = items };
}

fn mixCommand(allocator: Allocator, x: Command, y: Command, m: Mix) Allocator.Error!?Command {
    if (x.kind != y.kind or x.relative != y.relative or x.control_count != y.control_count) return null;
    if (std.meta.activeTag(x.endpoint) != std.meta.activeTag(y.endpoint)) return null;
    if ((x.arc == null) != (y.arc == null)) return null;
    var result: Command = .{ .kind = x.kind, .relative = x.relative };
    var done = false;
    defer if (!done) result.release();
    switch (x.endpoint) {
        .none => {},
        .point => |px| result.endpoint = .{ .point = (try mixPoint(allocator, px, y.endpoint.point, m)) orelse return null },
        .axis => |ax| {
            const ay = y.endpoint.axis;
            if (ax != .value or ay != .value) return null;
            result.endpoint = .{ .axis = .{ .value = (try interpolation.mixLengthPercentage(allocator, ax.value, m.ka, ay.value, m.kb)) orelse return null } };
        },
    }
    for (x.controls[0..x.control_count], y.controls[0..y.control_count]) |cx, cy| {
        if (cx.origin != cy.origin) return null;
        const point = (try mixPoint(allocator, cx.point, cy.point, m)) orelse return null;
        result.controls[result.control_count] = .{ .point = point, .origin = cx.origin };
        result.control_count += 1;
    }
    if (x.arc) |ax| {
        const ay = y.arc.?;
        if (ax.count != ay.count) return null;
        var arc: Arc = .{ .clockwise = mixFlag(flag(ax.clockwise), flag(ay.clockwise), m) != 0, .large = mixFlag(flag(ax.large), flag(ay.large), m) != 0 };
        const dx = rotationDegrees(ax) orelse return null;
        const dy = rotationDegrees(ay) orelse return null;
        arc.rotation = .{ .literal = .{ .number = dx * m.ka + dy * m.kb, .unit = .deg } };
        result.arc = arc;
        for (ax.radii[0..ax.count], ay.radii[0..ay.count]) |rx, ry| {
            const radius = interpolation.nonNegative((try interpolation.mixLengthPercentage(allocator, rx, m.ka, ry, m.kb)) orelse return null);
            result.arc.?.radii[result.arc.?.count] = radius;
            result.arc.?.count += 1;
        }
    }
    done = true;
    return result;
}

fn flag(b: bool) f64 {
    return if (b) 1 else 0;
}

/// A computed arc rotation in degrees (computation leaves a literal angle).
fn rotationDegrees(arc: Arc) ?f64 {
    return switch (arc.rotation) {
        .literal => |angle| angle.degrees(),
        .value => null,
    };
}

/// Two points of one form: positions as <position>s, coordinate pairs as
/// two length-percentages. OWNED.
fn mixPoint(allocator: Allocator, x: Point, y: Point, m: Mix) Allocator.Error!?Point {
    switch (x) {
        .position => |px| {
            if (y != .position) return null;
            const mixed = (try interpolation.mixPosition(allocator, px, m.ka, y.position, m.kb)) orelse return null;
            return .{ .position = mixed.image_position };
        },
        .pair => |px| {
            if (y != .pair) return null;
            const first = (try interpolation.mixLengthPercentage(allocator, px[0], m.ka, y.pair[0], m.kb)) orelse return null;
            const second = (try interpolation.mixLengthPercentage(allocator, px[1], m.ka, y.pair[1], m.kb)) orelse {
                first.release();
                return null;
            };
            return .{ .pair = .{ first, second } };
        },
    }
}

/// Shapes 1 3.1.1.2: a path() as the shape() commands it is equivalent to,
/// for interpolation with a shape(). "The first command of the path()
/// function [a move] interpolat[es] with the initial <coordinate-pair> in
/// the shape() function"; each later command keeps its <by-to> (lower case
/// is `by`): M move, L line, H hline, V vline, C curve with two control
/// points, Q curve with one, S smooth with one, T smooth with none, A arc
/// (sweep flag 1 is cw, large-arc flag 1 large), Z close. Coordinates are
/// user units, px. An absolute endpoint is a <position> and a relative one
/// a coordinate pair, as shape() parses them; control points are coordinate
/// pairs from the default origin. OWNED; null when the text is empty.
pub fn commandsOfPath(allocator: Allocator, evenodd: bool, text: []const u8) Allocator.Error!?Commands {
    var reader = path_values.Reader.init(text);
    const first = reader.next() orelse return null;
    if (std.ascii.toUpper(first.command) != 'M') return null;
    const origin = try pxPosition(allocator, first.args[0], first.args[1]);
    var items: std.ArrayList(Command) = .empty;
    var done = false;
    defer if (!done) {
        for (items.items) |c| c.release();
        items.deinit(allocator);
        origin.unref();
    };
    while (reader.next()) |segment| {
        const command = try commandOfSegment(allocator, segment);
        items.append(allocator, command) catch |err| {
            command.release();
            return err;
        };
    }
    const owned = try items.toOwnedSlice(allocator);
    done = true;
    return .{ .evenodd = evenodd, .origin = origin, .items = owned };
}

fn commandOfSegment(allocator: Allocator, segment: path_values.Segment) Allocator.Error!Command {
    const relative = std.ascii.isLower(segment.command);
    const args = segment.args;
    var result: Command = .{ .kind = switch (std.ascii.toUpper(segment.command)) {
        'M' => .move,
        'L' => .line,
        'H' => .hline,
        'V' => .vline,
        'C', 'Q' => .curve,
        'S', 'T' => .smooth,
        'A' => .arc,
        else => .close,
    }, .relative = relative };
    errdefer result.release();
    if (result.kind == .close) return result;
    const n = segment.count;
    switch (result.kind) {
        .hline, .vline => result.endpoint = .{ .axis = .{ .value = Value.px(args[0]) } },
        else => result.endpoint = .{ .point = try endpointPoint(allocator, relative, args[n - 2], args[n - 1]) },
    }
    const control_origin: @FieldType(Control, "origin") = if (relative) .start else .origin;
    const controls: usize = switch (std.ascii.toUpper(segment.command)) {
        'C' => 2,
        'Q', 'S' => 1,
        else => 0,
    };
    for (0..controls) |k| {
        result.controls[k] = .{ .point = .{ .pair = .{ Value.px(args[k * 2]), Value.px(args[k * 2 + 1]) } }, .origin = control_origin };
        result.control_count += 1;
    }
    if (result.kind == .arc) result.arc = .{
        .radii = .{ Value.px(args[0]), Value.px(args[1]) },
        .count = 2,
        .rotation = .{ .literal = .{ .number = args[2], .unit = .deg } },
        .large = args[3] != 0,
        .clockwise = args[4] != 0,
    };
    return result;
}

fn endpointPoint(allocator: Allocator, relative: bool, x: f64, y: f64) Allocator.Error!Point {
    if (relative) return .{ .pair = .{ Value.px(x), Value.px(y) } };
    return .{ .position = try pxPosition(allocator, x, y) };
}

/// A computed <position> of two px offsets. OWNED.
fn pxPosition(allocator: Allocator, x: f64, y: f64) Allocator.Error!*position_values.Position {
    const result = try allocator.create(position_values.Position);
    result.* = .{ .allocator = allocator, .data = .{ .computed = .{ .{ .value = Value.px(x) }, .{ .value = Value.px(y) } } } };
    return result;
}
