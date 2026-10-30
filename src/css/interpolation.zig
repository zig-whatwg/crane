//! Combining computed values (CSS Values 4 section 3): interpolation,
//! addition and accumulation of two COMPUTED values of one longhand, and the
//! animation type of each longhand (Web Animations 1 5.2 and Appendix A).
//! Web Animations' effect values (5.3.4) and the effect stack (5.4) are made
//! of these three operations; src/dom/animations/effect_stack.zig drives them.
//!
//! The procedures follow each value type's "combining" rules, by VALUE kind
//! (WebKit CSSPropertyAnimation.cpp's blendFunc/addFunc per wrapper, Blink's
//! CSSInterpolationType per type - designs only):
//! - <number>: a weighted sum; addition is the sum.
//! - <integer>: interpolated as a real number, then rounded to the nearest
//!   integer, halfway values towards positive infinity (Values 4 5.1).
//! - <length>, <percentage>: a weighted sum of the computed (px, %) values;
//!   a length and a percentage combine into a calc() mix (Values 4 5.5).
//! - <color>: premultiplied sRGB for two legacy colors (CSS Color 4 12.3:
//!   legacy colors interpolate in sRGB); addition adds the premultiplied
//!   channels, clamped.
//! - visibility: "if one of the values is visible, interpolated as a
//!   discrete step where values of p between 0 and 1 map to visible and other
//!   values of p map to the closer endpoint" (CSS Visibility, Web Animations
//!   Appendix A).
//! - everything else combines as DISCRETE: V_start below p = 0.5, V_end from
//!   it, and not additive (Values 4 3: addition of a not-additive type is
//!   V_result = V_b). Value kinds whose smooth rules are not built yet
//!   (transforms, shadows, filters, repeatable lists, non-legacy colors,
//!   currentcolor mixes) fall back here and are listed in `pendingKinds` so
//!   the gap stays visible.
//!
//! Range checking (Values 4 3.1) is NOT applied by these operations:
//! "clamping is only applied to the final result of applying all
//! interpolation-related operations" - `clampFinal`.
//!
//! Every result is OWNED by the caller (one reference, `Value.release`);
//! inputs are borrowed.
//!
//! Spec: https://drafts.csswg.org/css-values-4/#combining-values
//! Spec: https://drafts.csswg.org/web-animations-1/#animating-properties

const std = @import("std");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const math = @import("math_values.zig");
const transform_values = @import("transform_values.zig");
const box_transform_values = @import("box_transform_values.zig");
const position_values = @import("position_values.zig");
const box_shadow_values = @import("box_shadow_values.zig");
const Number = @import("numeric_values.zig").Number;

const Longhand = properties.Longhand;
const Value = values.Value;
const Length = values.Length;
const RgbaColor = values.RgbaColor;

/// Web Animations 1 5.2.
pub const AnimationType = enum {
    not_animatable,
    discrete,
    /// By computed value (and repeatable list: the list rules live with
    /// their value kinds).
    by_computed_value,
    /// See prose: visibility.
    visibility,
};

/// The longhands whose "Animation type" line says "not animatable": the
/// animation and transition controls (Animations 1, Transitions 1), the
/// bidi and writing-mode properties (Writing Modes 4 2.1-2.4, 5.1),
/// contain (Contain 2 3), interpolate-size (Values 5 / Sizing 4).
const not_animatable = [_]Longhand{
    .animation_duration,    .animation_timing_function, .animation_delay,            .animation_iteration_count,
    .animation_direction,   .animation_fill_mode,       .animation_play_state,       .animation_name,
    .animation_composition, .animation_timeline,        .animation_range_start,      .animation_range_end,
    .transition_property,   .transition_duration,       .transition_timing_function, .transition_delay,
    .transition_behavior,   .direction,                 .unicode_bidi,               .writing_mode,
    .text_orientation,      .contain,                   .interpolate_size,
};

const type_table: [std.meta.fields(Longhand).len]AnimationType = blk: {
    var table = [_]AnimationType{.by_computed_value} ** std.meta.fields(Longhand).len;
    for (not_animatable) |l| table[@intFromEnum(l)] = .not_animatable;
    table[@intFromEnum(Longhand.visibility)] = .visibility;
    break :blk table;
};

/// The animation type of `l`. Unlisted longhands are "by computed value",
/// whose combination falls back to discrete for any value kind without a
/// smooth rule - never the other way round.
pub fn animationType(l: Longhand) AnimationType {
    return type_table[@intFromEnum(l)];
}

/// The value kinds that combine discretely today although their types have
/// smooth rules (named so a reader sees the gap, not an approximation).
pub const pendingKinds = [_][]const u8{
    "transform_list", "text_shadow", "filter",           "layers",        "image_size",      "corner_radius",
    "font_settings",  "paint",       "color.expression", "color.current", "sizing_function", "grid_tracks",
};

// ============================================================================
// Interpolation
// ============================================================================

/// Values 4 3 "interpolation" of the computed values `from` and `to` of
/// `l` at `p` (any real: easing can extrapolate).
pub fn interpolate(allocator: Allocator, l: Longhand, from: Value, to: Value, p: f64) Allocator.Error!Value {
    // "p = 0 produces V_A and p = 1 produces V_B" (Values 4 3): exactly,
    // with no calc() mix left over from a cancelled component.
    if (p == 0) return retained(from);
    if (p == 1) return retained(to);
    switch (animationType(l)) {
        .not_animatable, .discrete => return discrete(from, to, p),
        .visibility => return visibility(from, to, p),
        .by_computed_value => {},
    }
    if (try smooth(allocator, from, to, p)) |v| return v;
    return discrete(from, to, p);
}

/// Discrete: V_start for p < 0.5, V_end otherwise (Web Animations 5.2).
pub fn discrete(from: Value, to: Value, p: f64) Value {
    const chosen = if (p < 0.5) from else to;
    chosen.retain();
    return chosen;
}

fn visibility(from: Value, to: Value, p: f64) Value {
    const from_visible = from == .keyword and from.keyword == .visible;
    const to_visible = to == .keyword and to.keyword == .visible;
    if (!from_visible and !to_visible) return discrete(from, to, p);
    if (p > 0 and p < 1) return Value.kw(.visible);
    return if (p <= 0) retained(from) else retained(to);
}

fn isNone(v: Value) bool {
    return v == .keyword and v.keyword == .none;
}

fn retained(v: Value) Value {
    v.retain();
    return v;
}

fn lerp(a: f64, b: f64, p: f64) f64 {
    return a + (b - a) * p;
}

/// Values 4 5.1: halfway values round towards positive infinity.
fn roundInteger(x: f64) i32 {
    const r = @floor(x + 0.5);
    if (r >= std.math.maxInt(i32)) return std.math.maxInt(i32);
    if (r <= std.math.minInt(i32)) return std.math.minInt(i32);
    return @intFromFloat(r);
}

/// The smooth combination of two values of one kind; null when the pair
/// has none (the caller combines them discretely).
fn smooth(allocator: Allocator, from: Value, to: Value, p: f64) Allocator.Error!?Value {
    switch (from) {
        .number => |a| if (to == .number) return .{ .number = lerp(a, to.number, p) },
        .integer => |a| if (to == .integer) return .{ .integer = roundInteger(lerp(@floatFromInt(a), @floatFromInt(to.integer), p)) },
        .color => |a| if (to == .color) {
            const ca = legacyRgba(a) orelse return null;
            const cb = legacyRgba(to.color) orelse return null;
            return .{ .color = .{ .rgba = mixPremultiplied(ca, cb, p) } };
        },
        else => {},
    }
    if (individualTransform(from) != null or individualTransform(to) != null) return try mixTransforms(allocator, from, to, p, .interpolate);
    if (shadowList(from) != null and shadowList(to) != null) return try mixBoxShadows(allocator, shadowList(from).?, shadowList(to).?, p, .interpolate);
    if (from == .transform_origin and to == .transform_origin) return try mixOrigins(allocator, from.transform_origin, 1 - p, to.transform_origin, p);
    if (from == .image_position and to == .image_position) return try mixPositions(allocator, from.image_position, 1 - p, to.image_position, p);
    if (lengthPercentage(from) and lengthPercentage(to)) return try mixLengths(allocator, from, 1 - p, to, p);
    return null;
}

// ============================================================================
// Addition and accumulation
// ============================================================================

/// Values 4 3 "addition": `underlying` + `value`. A not-additive type gives
/// `value`.
pub fn add(allocator: Allocator, l: Longhand, underlying: Value, value: Value) Allocator.Error!Value {
    if (animationType(l) != .by_computed_value) return retained(value);
    // A transform or filter list's `none` is the identity list (Transforms
    // 2 9, Filter Effects 1 11): adding it, or adding to it, changes nothing.
    if (l == .transform or l == .filter) {
        if (isNone(value)) return retained(underlying);
        if (isNone(underlying)) return retained(value);
    }
    switch (underlying) {
        .number => |a| if (value == .number) return .{ .number = a + value.number },
        .integer => |a| if (value == .integer) return .{ .integer = a +| value.integer },
        .color => |a| if (value == .color) {
            if (legacyRgba(a)) |ca| if (legacyRgba(value.color)) |cb| return .{ .color = .{ .rgba = addPremultiplied(ca, cb) } };
        },
        else => {},
    }
    if (lengthPercentage(underlying) and lengthPercentage(value)) {
        if (try mixLengths(allocator, underlying, 1, value, 1)) |sum| return sum;
    }
    if (individualTransform(underlying) != null or individualTransform(value) != null) {
        if (try mixTransforms(allocator, underlying, value, 1, .add)) |sum| return sum;
    }
    if (l == .box_shadow) if (shadowList(underlying)) |a| if (shadowList(value)) |b| {
        // Backgrounds 3 6.1: addition appends the lists; accumulation is
        // the accumulate procedure below.
        if (try concatBoxShadows(allocator, a, b)) |sum| return sum;
    };
    if (underlying == .transform_origin and value == .transform_origin) {
        if (try mixOrigins(allocator, underlying.transform_origin, 1, value.transform_origin, 1)) |sum| return sum;
    }
    if (underlying == .image_position and value == .image_position) {
        if (try mixPositions(allocator, underlying.image_position, 1, value.image_position, 1)) |sum| return sum;
    }
    return retained(value);
}

/// Values 4 3 "accumulation": identical to addition for every type built
/// here (numbers, lengths, colors).
pub fn accumulate(allocator: Allocator, l: Longhand, underlying: Value, value: Value) Allocator.Error!Value {
    // Shadow lists accumulate item by item (Backgrounds 3 6.1), unlike
    // their addition, which appends.
    if (l == .box_shadow) if (shadowList(underlying)) |a| if (shadowList(value)) |b| {
        if (try mixBoxShadows(allocator, a, b, 1, .accumulate)) |sum| return sum;
    };
    return add(allocator, l, underlying, value);
}

// ============================================================================
// Range checking (Values 4 3.1)
// ============================================================================

/// The final composited value of `l` clamped to the range the property
/// accepts. Takes ownership of `v` and returns an owned value.
pub fn clampFinal(l: Longhand, v: Value) Value {
    const grammar = l.info().grammar;
    switch (v) {
        .number => |n| {
            const clamped: f64 = switch (grammar) {
                .opacity => std.math.clamp(n, 0, 1),
                .font_weight => std.math.clamp(n, 1, 1000),
                .flex_factor, .line_height, .text_value => @max(n, 0),
                else => n,
            };
            return .{ .number = clamped };
        },
        .integer => |i| return .{ .integer = switch (grammar) {
            .column_count => @max(i, 1),
            else => i,
        } },
        .length => |len| {
            if (nonNegativeLengths(grammar) and len.value < 0) return .{ .length = .{ .value = 0, .unit = len.unit } };
            return v;
        },
        else => return v,
    }
}

fn nonNegativeLengths(grammar: properties.Grammar) bool {
    return switch (grammar) {
        .length_percentage_nonneg, .size, .max_size, .line_width, .font_size, .column_size, .gap, .stroke_width, .perspective, .line_height, .flex_basis => true,
        else => false,
    };
}

// ============================================================================
// Lengths and percentages
// ============================================================================

fn lengthPercentage(v: Value) bool {
    return switch (v) {
        .length => |len| len.unit == .px or len.unit == .percent,
        .calculation => |c| c.computed,
        else => false,
    };
}

/// `a` * `ka` + `b` * `kb` for two computed <length-percentage>s: a plain
/// length when both are of one unit, else a computed calc() mix.
fn mixLengths(allocator: Allocator, a: Value, ka: f64, b: Value, kb: f64) Allocator.Error!?Value {
    if (a == .length and b == .length and a.length.unit == b.length.unit) {
        return .{ .length = .{ .value = a.length.value * ka + b.length.value * kb, .unit = a.length.unit } };
    }
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try text.appendSlice(allocator, "calc((");
    try appendTerm(allocator, &text, a);
    try text.print(allocator, ") * {d} + (", .{ka});
    try appendTerm(allocator, &text, b);
    try text.print(allocator, ") * {d})", .{kb});
    const grammar: math.Grammar = .{ .kind = .length_percentage };
    const parsed = (try math.parse(allocator, text.items, grammar)) orelse return null;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(allocator, .{});
    // A mix whose percentage part cancelled is a plain length again.
    if (computed.computedNumber()) |number| {
        defer computed.unref();
        const unit: ?values.LengthUnit = switch (number.unit) {
            .px => .px,
            .percent => .percent,
            else => null,
        };
        if (unit) |u| return .{ .length = .{ .value = number.value, .unit = u } };
        return .{ .calculation = try retainedCopy(computed) };
    }
    return .{ .calculation = computed };
}

fn retainedCopy(expression: *math.Expression) Allocator.Error!*math.Expression {
    expression.ref();
    return expression;
}

fn appendTerm(allocator: Allocator, out: *std.ArrayList(u8), v: Value) Allocator.Error!void {
    switch (v) {
        .length => |len| try out.print(allocator, "{d}{s}", .{ len.value, if (len.unit == .percent) "%" else "px" }),
        .calculation => |c| try c.serialize(out, allocator),
        else => unreachable,
    }
}

// ============================================================================
// Individual transforms (CSS Transforms 2 section 8)
// ============================================================================

/// The kind of an individual transform value; `none` counts as the kind of
/// the other side (its identity), so it reports null here.
fn individualTransform(v: Value) ?transform_values.Kind {
    return if (v == .transform) v.transform.kind else null;
}

const TransformOp = enum { interpolate, add };

/// translate and scale: component by component (Transforms 2 8:
/// "interpolate each component"; none is the identity - 0px translations,
/// scale 1); addition sums translations and multiplies scales. rotate:
/// angles of one axis interpolate and add; other axes need the quaternion
/// slerp (pending: discrete). Components of one unit only; a px/% or calc()
/// pair is pending (discrete).
fn mixTransforms(allocator: Allocator, a: Value, b: Value, p: f64, op: TransformOp) Allocator.Error!?Value {
    const kind = individualTransform(a) orelse individualTransform(b).?;
    if (individualTransform(a)) |k| if (k != kind) return null;
    if (individualTransform(b)) |k| if (k != kind) return null;
    const identity = identityComponents(kind);
    const ca: [4]Number = if (a == .transform) a.transform.components else identity;
    const cb: [4]Number = if (b == .transform) b.transform.components else identity;
    var out: [4]math.Numeric = undefined;
    if (kind == .rotate) {
        // One axis (the identity takes the other side's).
        const axis_a = if (a == .transform) ca else cb;
        const axis_b = if (b == .transform) cb else ca;
        for (0..3) |i| {
            const x = literal(axis_a[i]) orelse return null;
            const y = literal(axis_b[i]) orelse return null;
            if (x.value != y.value) return null;
            out[i] = x;
        }
        const angle_a = degrees(if (a == .transform) ca[3] else zeroDegrees()) orelse return null;
        const angle_b = degrees(if (b == .transform) cb[3] else zeroDegrees()) orelse return null;
        out[3] = .{ .value = switch (op) {
            .interpolate => lerp(angle_a, angle_b, p),
            .add => angle_a + angle_b,
        }, .unit = .deg };
    } else {
        for (0..3) |i| {
            const x = literal(ca[i]) orelse return null;
            const y = literal(cb[i]) orelse return null;
            if (x.unit != y.unit and !(isZero(x) or isZero(y))) return null;
            const unit = if (isZero(x) and x.unit != y.unit) y.unit else x.unit;
            out[i] = .{ .unit = unit, .value = switch (op) {
                .interpolate => lerp(x.value, y.value, p),
                .add => if (kind == .scale) x.value * y.value else x.value + y.value,
            } };
        }
        out[3] = .{ .value = 0, .unit = .number };
    }
    const result = try allocator.create(transform_values.Transform);
    result.* = .{ .allocator = allocator, .kind = kind, .components = .{
        .{ .literal = out[0] }, .{ .literal = out[1] }, .{ .literal = out[2] }, .{ .literal = out[3] },
    } };
    return .{ .transform = result };
}

fn identityComponents(kind: transform_values.Kind) [4]Number {
    const px: Number = .{ .literal = .{ .value = 0, .unit = .px } };
    return switch (kind) {
        .translate => .{ px, px, px, Number.scalar(0) },
        .rotate => .{ Number.scalar(0), Number.scalar(0), Number.scalar(1), zeroDegrees() },
        .scale => .{ Number.scalar(1), Number.scalar(1), Number.scalar(1), Number.scalar(0) },
    };
}

fn zeroDegrees() Number {
    return .{ .literal = .{ .value = 0, .unit = .deg } };
}

fn literal(n: Number) ?math.Numeric {
    return switch (n) {
        .literal => |l| l,
        .calculation => |c| c.computedNumber(),
    };
}

fn isZero(n: math.Numeric) bool {
    return n.value == 0 and (n.unit == .px or n.unit == .percent or n.unit == .number);
}

/// An angle in degrees (a computed angle is in its canonical unit, deg).
fn degrees(n: Number) ?f64 {
    const l = literal(n) orelse return null;
    return switch (l.unit) {
        .deg => l.value,
        .rad => l.value * 180 / std.math.pi,
        .grad => l.value * 0.9,
        .turn => l.value * 360,
        .number => if (l.value == 0) 0 else null,
        else => null,
    };
}

// ============================================================================
// Coordinate pairs: transform-origin, the <position> properties
// ============================================================================

/// `a` * `ka` + `b` * `kb` of two computed numbers of one unit (a zero of
/// either length unit takes the other's); null for a calc() or mixed pair.
fn mixNumeric(a: Number, ka: f64, b: Number, kb: f64) ?math.Numeric {
    const x = literal(a) orelse return null;
    const y = literal(b) orelse return null;
    if (x.unit != y.unit and !(isZero(x) or isZero(y))) return null;
    const unit = if (isZero(x) and x.unit != y.unit) y.unit else x.unit;
    return .{ .value = x.value * ka + y.value * kb, .unit = unit };
}

/// transform-origin (Transforms 1: "repeatable list of simple list of
/// length, percentage, or calc"): each coordinate combines as a
/// <length-percentage>; mixed units are pending (discrete).
fn mixOrigins(allocator: Allocator, a: *const box_transform_values.Origin, ka: f64, b: *const box_transform_values.Origin, kb: f64) Allocator.Error!?Value {
    var xy: [2]math.Numeric = undefined;
    for (a.xy, b.xy, &xy) |pa, pb, *out| {
        if (pa != .number or pb != .number) return null;
        out.* = mixNumeric(pa.number, ka, pb.number, kb) orelse return null;
    }
    var z: ?math.Numeric = null;
    if (a.z != null or b.z != null) {
        const zero: Number = .{ .literal = .{ .value = 0, .unit = .px } };
        z = mixNumeric(a.z orelse zero, ka, b.z orelse zero, kb) orelse return null;
    }
    const result = try allocator.create(box_transform_values.Origin);
    result.* = .{ .allocator = allocator };
    result.xy[0] = .{ .number = .{ .literal = xy[0] } };
    result.xy[1] = .{ .number = .{ .literal = xy[1] } };
    if (z) |v| result.z = .{ .literal = v };
    return .{ .transform_origin = result };
}

/// A computed <position> (Values 4 9.1: "each coordinate combines as a
/// <length-percentage>"), axis by axis; a complemented (right/bottom)
/// offset that has not resolved to a plain value is pending (discrete).
fn mixPositions(allocator: Allocator, a: *const position_values.Position, ka: f64, b: *const position_values.Position, kb: f64) Allocator.Error!?Value {
    if (a.data != .computed or b.data != .computed or a.logical != b.logical) return null;
    var offsets: [2]position_values.Offset = undefined;
    var made: usize = 0;
    errdefer for (offsets[0..made]) |o| o.value.release();
    for (a.data.computed, b.data.computed) |oa, ob| {
        if (oa.complement or ob.complement) return null;
        if (!lengthPercentage(oa.value) or !lengthPercentage(ob.value)) return null;
    }
    for (a.data.computed, b.data.computed) |oa, ob| {
        const v = (try mixLengths(allocator, oa.value, ka, ob.value, kb)) orelse {
            for (offsets[0..made]) |o| o.value.release();
            return null;
        };
        offsets[made] = .{ .value = v };
        made += 1;
    }
    const result = try allocator.create(position_values.Position);
    result.* = .{ .allocator = allocator, .data = .{ .computed = offsets }, .logical = a.logical };
    return .{ .image_position = result };
}

// ============================================================================
// box-shadow (Backgrounds 3 6.1: "as a shadow list")
// ============================================================================

const BoxShadowItem = box_shadow_values.Shadow;

/// The items of a box-shadow value; `none` is the empty list.
fn shadowList(v: Value) ?[]const BoxShadowItem {
    return switch (v) {
        .box_shadow => |b| b.items,
        .keyword => |k| if (k == .none) &.{} else null,
        else => null,
    };
}

const ShadowOp = enum { interpolate, accumulate };

/// Pairwise: each shadow's color and lengths combine, the shorter list
/// padded with transparent zero-length shadows whose inset matches its
/// partner's; a pair whose inset differs, or a color that is not a legacy
/// sRGB color (currentcolor), is pending (discrete). The result is a
/// specified value the cascade computes again (its lengths are px and its
/// colors absolute, so it computes to itself).
fn mixBoxShadows(allocator: Allocator, a: []const BoxShadowItem, b: []const BoxShadowItem, p: f64, op: ShadowOp) Allocator.Error!?Value {
    const n = @max(a.len, b.len);
    if (n == 0) return Value.kw(.none);
    const items = try allocator.alloc(BoxShadowItem, n);
    defer allocator.free(items);
    for (0..n) |i| {
        const x: ?BoxShadowItem = if (i < a.len) a[i] else null;
        const y: ?BoxShadowItem = if (i < b.len) b[i] else null;
        const inset = if (x) |v| v.inset else y.?.inset;
        if (x != null and y != null and x.?.inset != y.?.inset) return null;
        const transparent: RgbaColor = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        const cx = if (x) |v| (if (v.color) |c| legacyRgba(c) else null) orelse return null else transparent;
        const cy = if (y) |v| (if (v.color) |c| legacyRgba(c) else null) orelse return null else transparent;
        var item: BoxShadowItem = .{ .inset = inset, .count = 4 };
        item.color = .{ .rgba = switch (op) {
            .interpolate => mixPremultiplied(cx, cy, p),
            .accumulate => addPremultiplied(cx, cy),
        } };
        for (0..4) |k| {
            const lx = shadowLength(x, k) orelse return null;
            const ly = shadowLength(y, k) orelse return null;
            item.lengths[k] = Value.px(switch (op) {
                .interpolate => lerp(lx, ly, p),
                .accumulate => lx + ly,
            });
        }
        items[i] = item;
    }
    return .{ .box_shadow = try box_shadow_values.BoxShadow.create(allocator, items) };
}

/// Addition: the underlying list, then the effect's.
fn concatBoxShadows(allocator: Allocator, a: []const BoxShadowItem, b: []const BoxShadowItem) Allocator.Error!?Value {
    if (a.len + b.len == 0) return Value.kw(.none);
    const items = try allocator.alloc(BoxShadowItem, a.len + b.len);
    defer allocator.free(items);
    @memcpy(items[0..a.len], a);
    @memcpy(items[a.len..], b);
    return .{ .box_shadow = try box_shadow_values.BoxShadow.create(allocator, items) };
}

/// A shadow's k-th length in px (0 for a missing one or a padding shadow);
/// null for one that is not a px length.
fn shadowLength(item: ?BoxShadowItem, k: usize) ?f64 {
    const v = item orelse return 0;
    if (k >= v.count) return 0;
    return switch (v.lengths[k]) {
        .length => |len| if (len.unit == .px) len.value else null,
        else => null,
    };
}

// ============================================================================
// Colors
// ============================================================================

/// The sRGB color of a computed legacy color; null for one that does not
/// combine in sRGB here (a non-legacy color() / lab() expression, or
/// currentcolor, whose mix is a color-mix() - pending).
fn legacyRgba(c: values.Color) ?RgbaColor {
    return switch (c) {
        .rgba => |rgba| rgba,
        .named => |n| n.rgba,
        .transparent_keyword => .{ .r = 0, .g = 0, .b = 0, .a = 0 },
        else => null,
    };
}

const Premultiplied = struct { r: f64, g: f64, b: f64, a: f64 };

fn premultiply(c: RgbaColor) Premultiplied {
    const a: f64 = std.math.clamp(@as(f64, c.a), 0, 1);
    return .{ .r = @as(f64, @floatFromInt(c.r)) * a, .g = @as(f64, @floatFromInt(c.g)) * a, .b = @as(f64, @floatFromInt(c.b)) * a, .a = a };
}

fn unpremultiply(c: Premultiplied) RgbaColor {
    const a = std.math.clamp(c.a, 0, 1);
    if (a == 0) return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    return .{ .r = channel(c.r / a), .g = channel(c.g / a), .b = channel(c.b / a), .a = @floatCast(a) };
}

fn channel(x: f64) u8 {
    return @intFromFloat(std.math.clamp(@round(x), 0, 255));
}

fn mixPremultiplied(a: RgbaColor, b: RgbaColor, p: f64) RgbaColor {
    const pa = premultiply(a);
    const pb = premultiply(b);
    return unpremultiply(.{ .r = lerp(pa.r, pb.r, p), .g = lerp(pa.g, pb.g, p), .b = lerp(pa.b, pb.b, p), .a = lerp(pa.a, pb.a, p) });
}

fn addPremultiplied(a: RgbaColor, b: RgbaColor) RgbaColor {
    const pa = premultiply(a);
    const pb = premultiply(b);
    const alpha = @min(pa.a + pb.a, 1);
    // Channels add premultiplied and clamp to the result's alpha range.
    return unpremultiply(.{ .r = @min(pa.r + pb.r, 255 * alpha), .g = @min(pa.g + pb.g, 255 * alpha), .b = @min(pa.b + pb.b, 255 * alpha), .a = alpha });
}

// ============================================================================
// Tests (pure value kinds; the cascade round trips are in
// tests/css/r3_interpolation_test.zig)
// ============================================================================

const testing = std.testing;

test "animation type default: an unlisted longhand is by computed value, never not animatable" {
    try testing.expectEqual(AnimationType.by_computed_value, animationType(.width));
    try testing.expectEqual(AnimationType.by_computed_value, animationType(.opacity));
    try testing.expectEqual(AnimationType.visibility, animationType(.visibility));
    for (not_animatable) |l| try testing.expectEqual(AnimationType.not_animatable, animationType(l));
    var count: usize = 0;
    for (type_table) |t| {
        if (t == .not_animatable) count += 1;
    }
    try testing.expectEqual(not_animatable.len, count);
}

test "numbers and integers" {
    const a = testing.allocator;
    try testing.expectEqual(@as(f64, 0.5), (try interpolate(a, .opacity, .{ .number = 0 }, .{ .number = 1 }, 0.5)).number);
    try testing.expectEqual(@as(f64, -0.5), (try interpolate(a, .opacity, .{ .number = 0 }, .{ .number = 1 }, -0.5)).number);
    try testing.expectEqual(@as(i32, 3), (try interpolate(a, .order, .{ .integer = 2 }, .{ .integer = 4 }, 0.5)).integer);
    // Halfway rounds towards positive infinity, including below zero.
    try testing.expectEqual(@as(i32, 1), (try interpolate(a, .order, .{ .integer = 0 }, .{ .integer = 1 }, 0.5)).integer);
    try testing.expectEqual(@as(i32, 0), (try interpolate(a, .order, .{ .integer = -1 }, .{ .integer = 0 }, 0.5)).integer);
    try testing.expectEqual(@as(f64, 0.75), (try add(a, .opacity, .{ .number = 0.25 }, .{ .number = 0.5 })).number);
    try testing.expectEqual(@as(f64, 1), clampFinal(.opacity, .{ .number = 1.5 }).number);
    try testing.expectEqual(@as(f64, 1), clampFinal(.font_weight, .{ .number = -3 }).number);
}

test "discrete swaps at one half and is not additive" {
    const a = testing.allocator;
    try testing.expectEqual(values.Keyword.left, (try interpolate(a, .float, Value.kw(.left), Value.kw(.right), 0.49)).keyword);
    try testing.expectEqual(values.Keyword.right, (try interpolate(a, .float, Value.kw(.left), Value.kw(.right), 0.5)).keyword);
    try testing.expectEqual(values.Keyword.right, (try add(a, .float, Value.kw(.left), Value.kw(.right))).keyword);
    // Not animatable: discrete too when asked (the effect stack skips them).
    try testing.expectEqual(values.Keyword.rtl, (try interpolate(a, .direction, Value.kw(.ltr), Value.kw(.rtl), 0.7)).keyword);
}

test "visibility: visible across the open interval" {
    const a = testing.allocator;
    try testing.expectEqual(values.Keyword.visible, (try interpolate(a, .visibility, Value.kw(.hidden), Value.kw(.visible), 0.1)).keyword);
    try testing.expectEqual(values.Keyword.visible, (try interpolate(a, .visibility, Value.kw(.visible), Value.kw(.hidden), 0.9)).keyword);
    try testing.expectEqual(values.Keyword.hidden, (try interpolate(a, .visibility, Value.kw(.hidden), Value.kw(.visible), 0)).keyword);
    try testing.expectEqual(values.Keyword.hidden, (try interpolate(a, .visibility, Value.kw(.visible), Value.kw(.hidden), 1.5)).keyword);
    try testing.expectEqual(values.Keyword.collapse, (try interpolate(a, .visibility, Value.kw(.hidden), Value.kw(.collapse), 0.6)).keyword);
}

test "legacy colors: premultiplied sRGB" {
    const a = testing.allocator;
    const red: Value = .{ .color = .{ .rgba = .{ .r = 255, .g = 0, .b = 0 } } };
    const blue: Value = .{ .color = .{ .rgba = .{ .r = 0, .g = 0, .b = 255 } } };
    const mid = (try interpolate(a, .color, red, blue, 0.5)).color.rgba;
    try testing.expectEqual(@as(u8, 128), mid.r);
    try testing.expectEqual(@as(u8, 128), mid.b);
    const clear: Value = .{ .color = .transparent_keyword };
    const half = (try interpolate(a, .color, clear, red, 0.5)).color.rgba;
    // Premultiplied: the transparent end contributes no hue.
    try testing.expectEqual(@as(u8, 255), half.r);
    try testing.expectEqual(@as(f32, 0.5), half.a);
    const sum = (try add(a, .color, .{ .color = .{ .rgba = .{ .r = 128, .g = 128, .b = 128 } } }, .{ .color = .{ .rgba = .{ .r = 128, .g = 128, .b = 128 } } })).color.rgba;
    try testing.expectEqual(@as(u8, 255), sum.r);
}

test "lengths of one unit stay lengths; mixed units make a calc() mix" {
    try testing.checkAllAllocationFailures(testing.allocator, lengthMixes, .{});
}

fn lengthMixes(a: Allocator) !void {
    const ten = (try interpolate(a, .width, .{ .length = Length.px(0) }, .{ .length = Length.px(20) }, 0.5)).length;
    try testing.expectEqual(@as(f64, 10), ten.value);
    const mixed = try interpolate(a, .width, .{ .length = Length.px(10) }, .{ .length = Length.percent(50) }, 0.5);
    defer mixed.release();
    try testing.expect(mixed == .calculation);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try mixed.calculation.serialize(&out, a);
    try testing.expectEqualStrings("calc(25% + 5px)", out.items);
    // The percentage cancels at p = 0: a plain length.
    const back = try interpolate(a, .width, .{ .length = Length.px(10) }, .{ .length = Length.percent(50) }, 0);
    defer back.release();
    try testing.expect(back == .length);
    try testing.expectEqual(@as(f64, 10), back.length.value);
    const sum = try add(a, .width, .{ .length = Length.px(10) }, .{ .length = Length.percent(50) });
    defer sum.release();
    try testing.expect(sum == .calculation);
    // Lengths and numbers do not combine smoothly (line-height).
    const swap = try interpolate(a, .line_height, .{ .number = 1.5 }, .{ .length = Length.px(20) }, 0.6);
    try testing.expect(swap == .length);
}
