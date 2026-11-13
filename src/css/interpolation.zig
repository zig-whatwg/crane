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
//!   legacy colors interpolate in sRGB), Oklab for any other resolved pair,
//!   and a color-mix() naming currentcolor when either side is currentcolor
//!   (color_values.interpolateColors); addition adds the premultiplied
//!   channels, clamped.
//! - transform lists: transform_interpolation (Transforms 1 section 9,
//!   Transforms 2 sections 13-15); basic shapes, path() and shape():
//!   shape_interpolation (Shapes 1 3.1.1.2 and 3.4, SVG 2 9.3).
//! - visibility: "if one of the values is visible, interpolated as a
//!   discrete step where values of p between 0 and 1 map to visible and other
//!   values of p map to the closer endpoint" (CSS Visibility, Web Animations
//!   Appendix A).
//! - everything else combines as DISCRETE: V_start below p = 0.5, V_end from
//!   it, and not additive (Values 4 3: addition of a not-additive type is
//!   V_result = V_b). Value kinds whose smooth rules are not built yet fall
//!   back here and are listed in `pendingKinds` so the gap stays visible.
//! - composites (pairs, repeatable lists, quads, shadow lists, positions):
//!   component by component (Web Animations 1 5.2 "by computed value" and
//!   "repeatable list"), discrete when any component pair does not combine.
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
const filter_values = @import("filter_values.zig");
const Number = @import("numeric_values.zig").Number;
const syntax_values = @import("syntax_values.zig");
const syntax_definitions = @import("syntax_definitions.zig");
const transform_functions = @import("transform_functions.zig");
const border_radius = @import("border_radius.zig");
const image_layers = @import("image_layers.zig");
const image_size = @import("image_size.zig");
const image_quad = @import("image_quad.zig");
const text_shadow_values = @import("text_shadow_values.zig");
const font_size_adjust = @import("font_size_adjust.zig");
const text_indent = @import("text_indent.zig");
const motion_values = @import("motion_values.zig");
const shape_interpolation = @import("shape_interpolation.zig");
const transform_interpolation = @import("transform_interpolation.zig");
const color_values = @import("color_values.zig");
const font_palette_values = @import("font_palette_values.zig");
const font_settings = @import("font_settings.zig");
const text_values = @import("text_values.zig");
const sizing_values = @import("sizing_values.zig");
const corner_shape_values = @import("corner_shape_values.zig");
const dynamic_range_values = @import("dynamic_range_values.zig");

const Longhand = properties.Longhand;
const Value = values.Value;
const Length = values.Length;

/// Web Animations 1 5.2.
pub const AnimationType = enum {
    not_animatable,
    discrete,
    /// By computed value (and repeatable list: the list rules live with
    /// their value kinds).
    by_computed_value,
    /// See prose: visibility, and overlay (Position 4 §3.4: "auto is
    /// interpolated as a discrete step where values of p such that 0 < p < 1
    /// map to auto ... This is similar to how visibility animates").
    visibility,
};

/// The longhands whose "Animation type" line says "not animatable": the
/// animation and transition controls (Animations 1, Transitions 1), the
/// bidi and writing-mode properties (Writing Modes 4 2.1-2.4, 5.1, 9.1),
/// contain (Contain 2 3), interpolate-size (Values 5 / Sizing 4),
/// forced-color-adjust (Color Adjustment 1 §4), scroll-behavior (Overflow 3
/// §5).
const not_animatable = [_]Longhand{
    .animation_duration,    .animation_timing_function, .animation_delay,            .animation_iteration_count,
    .animation_direction,   .animation_fill_mode,       .animation_play_state,       .animation_name,
    .animation_composition, .animation_timeline,        .animation_range_start,      .animation_range_end,
    .transition_property,   .transition_duration,       .transition_timing_function, .transition_delay,
    .transition_behavior,   .direction,                 .unicode_bidi,               .writing_mode,
    .text_orientation,      .contain,                   .interpolate_size,           .forced_color_adjust,
    .scroll_behavior,       .text_combine_upright,
};

const type_table: [std.meta.fieldNames(Longhand).len]AnimationType = blk: {
    var table = @as([std.meta.fieldNames(Longhand).len]AnimationType, @splat(.by_computed_value));
    for (not_animatable) |l| table[@backingInt(l)] = .not_animatable;
    table[@backingInt(Longhand.visibility)] = .visibility;
    table[@backingInt(Longhand.overlay)] = .visibility;
    break :blk table;
};

/// The value a `.visibility` longhand holds through the whole step.
fn steppedKeyword(l: Longhand) values.Keyword {
    return if (l == .overlay) .auto else .visible;
}

/// The animation type of `l`. Unlisted longhands are "by computed value",
/// whose combination falls back to discrete for any value kind without a
/// smooth rule - never the other way round.
pub fn animationType(l: Longhand) AnimationType {
    return type_table[@backingInt(l)];
}

/// The value kinds that combine discretely today although their types have
/// smooth rules (named so a reader sees the gap, not an approximation).
pub const pendingKinds = [_][]const u8{
    "paint", "sizing_function", "grid_tracks",
};

// ============================================================================
// Interpolation
// ============================================================================

/// Values 4 3 "interpolation" of the computed values `from` and `to` of
/// `l` at `p` (any real: easing can extrapolate).
pub fn interpolate(allocator: Allocator, l: Longhand, from: Value, to: Value, p: f64) Allocator.Error!Value {
    // "p = 1 produces V_B" (Values 4 3). p = 0 is NOT short-cut to V_A: a
    // smooth combination keeps the pair's combined type there - a
    // length-percentage mix stays `calc(0% + 40px)` and an identity `none`
    // is its function (`scale: 1`), as the WPT interpolation files expect at
    // 0 and Chrome, Firefox and Safari return (vertical-align-interpolation,
    // offset-distance-interpolation, scale-interpolation). At p = 1 the
    // mix's zero length term drops (math_values' Q100 canonical form), so
    // V_B is exact either way.
    if (p == 1 and !keepsInterpolatedForm(from, to)) return retained(to);
    switch (animationType(l)) {
        .not_animatable, .discrete => return discrete(from, to, p),
        .visibility => return visibility(steppedKeyword(l), from, to, p),
        .by_computed_value => {},
    }
    if (try smooth(allocator, l, from, to, p)) |v| return v;
    return discrete(from, to, p);
}

/// Whether the pair's interpolated value at p = 1 differs in form from V_B,
/// which the WPT interpolation files expect there and Chrome, Firefox and
/// Safari return: path() data becomes absolute (offset-path-interpolation-
/// 001/-004 expect path('m 20 70') to read `M ...` at 1), and a <position> or
/// a basic shape whose other side has a percentage keeps the mixed type
/// (offset-anchor/-position-interpolation expect `calc(0% + 8px) 80%` from
/// `left top` to `left 8px bottom 20%` at 1; offset-path-interpolation-006/
/// -008 the same for inset() and shape()). Plain length-percentages need no
/// exception: their mix at 1 canonicalizes to V_B (`40%`).
fn keepsInterpolatedForm(from: Value, to: Value) bool {
    if (pathData(to)) return true;
    return switch (to) {
        .image_position, .shape, .motion_path => std.meta.activeTag(from) == std.meta.activeTag(to),
        else => false,
    };
}

/// Whether `v` holds path() data, whose interpolated form is absolute.
fn pathData(v: Value) bool {
    const shape = switch (v) {
        .shape => |s| s,
        .motion_path => |path| if (path.data == .shape) path.data.shape else return false,
        else => return false,
    };
    return shape.data == .path;
}

/// CSS Transitions 1 section 3 "transitionable": the animation type of the
/// pair `from`, `to` of `l` is neither not animatable nor discrete - the
/// property's type, and for a "by computed value" property whether this pair
/// has a smooth combination (box-shadow's `inset` against no `inset` has
/// none: "[0px 0px black] and [inset 10px 10px black] are not
/// transitionable"). A value kind Crane combines discretely for now
/// (`pendingKinds`) is not transitionable until it interpolates.
pub fn transitionable(allocator: Allocator, l: Longhand, from: Value, to: Value) Allocator.Error!bool {
    switch (animationType(l)) {
        .not_animatable, .discrete => return false,
        // Visibility: discrete unless one of the values is `visible`
        // (overlay: `auto`).
        .visibility => return from.isKeyword(steppedKeyword(l)) or to.isKeyword(steppedKeyword(l)),
        .by_computed_value => {},
    }
    const combined = (try smooth(allocator, l, from, to, 0.5)) orelse return false;
    combined.release();
    return true;
}

/// Discrete: V_start for p < 0.5, V_end otherwise (Web Animations 5.2).
pub fn discrete(from: Value, to: Value, p: f64) Value {
    const chosen = if (p < 0.5) from else to;
    chosen.retain();
    return chosen;
}

fn visibility(stepped: values.Keyword, from: Value, to: Value, p: f64) Value {
    if (!from.isKeyword(stepped) and !to.isKeyword(stepped)) return discrete(from, to, p);
    if (p > 0 and p < 1) return Value.kw(stepped);
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
fn smooth(allocator: Allocator, l: Longhand, from: Value, to: Value, p: f64) Allocator.Error!?Value {
    switch (l.info().grammar) {
        // Borders 4 §3.9.6: the parameter in normalized half-corner space.
        .corner_shape => return corner_shape_values.interpolate(from, to, p),
        // Color HDR 1 §3.1: "by dynamic-range-limit-mix()".
        .dynamic_range_limit => return try dynamic_range_values.interpolate(allocator, from, to, p),
        else => {},
    }
    switch (from) {
        .number => |a| if (to == .number) return .{ .number = lerp(a, to.number, p) },
        .integer => |a| if (to == .integer) return .{ .integer = roundInteger(lerp(@floatFromInt(a), @floatFromInt(to.integer), p)) },
        .color => |a| if (to == .color) {
            // Two legacy colors: premultiplied sRGB here, unclamped until the
            // final value; any other pair (a non-legacy color, currentcolor):
            // color_values (Oklab, or a color-mix() naming currentcolor).
            if (try combineLegacy(allocator, a, to.color, p, .interpolate)) |color| return .{ .color = color };
            return try mixColors(allocator, a, to.color, p);
        },
        else => {},
    }
    if (l == .transform) return try transform_interpolation.combine(allocator, from, to, p, .interpolate);
    // Fonts 4 9.1: font-palette mixes inside (0, 1) and keeps each endpoint
    // outside it (WPT font-palette-interpolation expects `light` at -0.25
    // and 0, `dark` at 1.5).
    if (l == .font_palette) {
        if (p <= 0) return retained(from);
        if (p >= 1) return retained(to);
        return try font_palette_values.interpolatePalettes(allocator, from, to, p);
    }
    if (individualTransform(from) != null or individualTransform(to) != null) return try mixTransforms(allocator, from, to, p, .interpolate);
    if (filterList(from) != null and filterList(to) != null) return try mixFilters(allocator, filterList(from).?, filterList(to).?, p, .interpolate);
    if (shadowList(from) != null and shadowList(to) != null) return try mixBoxShadows(allocator, shadowList(from).?, shadowList(to).?, p, .interpolate);
    if (from == .transform_origin and to == .transform_origin) return try mixOrigins(allocator, from.transform_origin, 1 - p, to.transform_origin, p);
    if (from == .image_position or to == .image_position) if (try mixPositionValues(allocator, from, 1 - p, to, p)) |v| return v;
    if (try mixComposite(allocator, l, from, to, .{ .ka = 1 - p, .kb = p, .p = p })) |v| return v;
    if (textShadowList(from) != null and textShadowList(to) != null) return try mixTextShadows(allocator, textShadowList(from).?, textShadowList(to).?, p, .interpolate);
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
    switch (l.info().grammar) {
        // Defined by interpolation alone, so not additive: a corner shape
        // (Borders 4 §3.9.6), a dynamic range limit (Color HDR 1 §3.1),
        // a <ratio> ("Addition of <ratio>s is not possible", Values 4
        // §5.7.1) and a dash array ("stroke-dasharray is neither additive
        // nor cumulative", web-animations property-types.js dasharrayType,
        // after SVG 2 §13.5.6).
        .corner_shape, .dynamic_range_limit, .aspect_ratio, .dasharray => return retained(value),
        else => {},
    }
    // Transforms 2 section 15: addition appends V_b to V_a (`none` is the
    // empty list).
    if (l == .transform) if (try transform_interpolation.add(allocator, underlying, value)) |sum| return sum;
    // A filter list's `none` is the identity list (Filter Effects 1 11):
    // adding it, or adding to it, changes nothing. backdrop-filter is the
    // same list (Filter Effects 2 §3: "see prose in Filter Effects 1 § 14").
    if (l == .filter or l == .backdrop_filter) {
        if (isNone(value)) return retained(underlying);
        if (isNone(underlying)) return retained(value);
    }
    switch (underlying) {
        .number => |a| if (value == .number) return .{ .number = a + value.number },
        .integer => |a| if (value == .integer) return .{ .integer = a +| value.integer },
        .color => |a| if (value == .color) {
            if (try combineLegacy(allocator, a, value.color, 1, .accumulate)) |sum| return .{ .color = sum };
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
    if (underlying == .image_position or value == .image_position) {
        if (try mixPositionValues(allocator, underlying, 1, value, 1)) |sum| return sum;
    }
    if (l == .text_shadow) if (textShadowList(underlying)) |a| if (textShadowList(value)) |b| {
        // A shadow list adds by appending (Backgrounds 3 6.1, which Text
        // Decoration 3's text-shadow "as shadow list" names).
        if (try concatTextShadows(allocator, a, b)) |sum| return sum;
    };
    if (try mixComposite(allocator, l, underlying, value, .{ .ka = 1, .kb = 1 })) |sum| return sum;
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
    if (l == .text_shadow) if (textShadowList(underlying)) |a| if (textShadowList(value)) |b| {
        if (try mixTextShadows(allocator, a, b, 1, .accumulate)) |sum| return sum;
    };
    // Transforms 2 section 15: accumulation matches the lists as
    // interpolation does and adds each parameter (one-based ones as a + b -
    // 1); a pair that cannot be matched or decomposed is V_b, never the
    // addition's concatenation.
    if (l == .transform) {
        if (try transform_interpolation.combine(allocator, underlying, value, 1, .accumulate)) |sum| return sum;
        return retained(value);
    }
    // Filter Effects 1 11: filter lists accumulate function by function.
    if (l == .filter or l == .backdrop_filter) if (filterList(underlying)) |a| if (filterList(value)) |b| {
        if (try mixFilters(allocator, a, b, 1, .accumulate)) |sum| return sum;
    };
    // translate, rotate and scale accumulate component by component; scale's
    // components as one-based values (mixTransforms).
    if (individualTransform(underlying) != null or individualTransform(value) != null) {
        if (try mixTransforms(allocator, underlying, value, 1, .accumulate)) |sum| return sum;
    }
    return add(allocator, l, underlying, value);
}

// ============================================================================
// Registered custom properties (CSS Properties and Values API 1 2.5)
// ============================================================================

/// Which of Values 4 3's three operations `combineSyntax` performs.
pub const SyntaxOp = enum { interpolate, add, accumulate };

/// CSS Properties and Values API 1 2.5 "Animation Behavior": a registered
/// custom property's computed values "interpolate by computed value, in
/// accordance with the type that they parsed as". So:
/// - a list (`+`, `#`) combines as a simple list, item by item, and has no
///   smooth combination when the lengths differ;
/// - a <transform-list> and a <transform-function>+ combine "as per the
///   transform property" (Transforms 2 14-15: same functions argument by
///   argument; addition appends the lists; accumulation adds each argument,
///   one-based ones as a + b - 1);
/// - a single <transform-function> combines argument by argument (its
///   addition is its accumulation: a single function cannot hold a list);
/// - a number, length, percentage, length-percentage, integer, angle, time
///   or resolution as its numeric type (lengths and percentages mix into a
///   calc(); an integer interpolates as a real and rounds half up, Values 4
///   5.1); a legacy color in premultiplied sRGB, as the color properties.
/// `p` is the interpolation's (any real); addition and accumulation ignore
/// it. Null when the pair has no smooth combination - `*`, an ident, a
/// string, an image or url, mismatched lists, different transform functions
/// (which need matrices, Transforms 2 13) - for the caller to combine
/// discretely. The result is OWNED by the caller; inputs are borrowed.
///
/// Engines (designs only): Blink CSSInterpolationTypesMap picks a
/// CSSInterpolationType per registered syntax component, lists through
/// CSSCustomListInterpolationType, transforms through
/// CSSTransformInterpolationType; Gecko's properties_and_values
/// ComputedValue implements Animate item by item.
///
/// Spec: https://drafts.css-houdini.org/css-properties-values-api-1/#animation-behavior-of-custom-properties
pub fn combineSyntax(allocator: Allocator, a: *const syntax_values.Value, b: *const syntax_values.Value, p: f64, op: SyntaxOp) Allocator.Error!?syntax_values.Value {
    switch (a.data) {
        .universal => return null,
        .single => |x| {
            if (b.data != .single) return null;
            const item = (try combineItem(allocator, x, b.data.single, p, op)) orelse return null;
            return .{ .allocator = allocator, .data = .{ .single = item } };
        },
        .list => |la| {
            if (b.data != .list) return null;
            const lb = b.data.list;
            if (la.separator != lb.separator) return null;
            const transforms = la.separator == .space and allTransforms(la.items) and allTransforms(lb.items);
            if (transforms) {
                if (op == .add) return try concatItems(allocator, la.items, lb.items);
                return try combineTransformLists(allocator, la.items, lb.items, p, op);
            }
            if (la.items.len != lb.items.len) return null;
            const items = try allocator.alloc(syntax_values.Item, la.items.len);
            var made: usize = 0;
            errdefer {
                for (items[0..made]) |*item| item.deinit(allocator);
                allocator.free(items);
            }
            for (la.items, lb.items) |x, y| {
                items[made] = (try combineItem(allocator, x, y, p, op)) orelse {
                    for (items[0..made]) |*item| item.deinit(allocator);
                    allocator.free(items);
                    return null;
                };
                made += 1;
            }
            return .{ .allocator = allocator, .data = .{ .list = .{ .separator = la.separator, .items = items } } };
        },
    }
}

fn allTransforms(items: []const syntax_values.Item) bool {
    for (items) |item| if (item != .transform) return false;
    return true;
}

/// Transforms 2 15: "V_result is equal to V_b appended to V_a".
fn concatItems(allocator: Allocator, a: []const syntax_values.Item, b: []const syntax_values.Item) Allocator.Error!syntax_values.Value {
    const items = try allocator.alloc(syntax_values.Item, a.len + b.len);
    var made: usize = 0;
    errdefer {
        for (items[0..made]) |*item| item.deinit(allocator);
        allocator.free(items);
    }
    for ([_][]const syntax_values.Item{ a, b }) |list| for (list) |item| {
        items[made] = .{ .transform = try transform_interpolation.copyFunction(allocator, item.transform) };
        made += 1;
    };
    return .{ .allocator = allocator, .data = .{ .list = .{ .separator = .space, .items = items } } };
}

/// A registered <transform-list> (or <transform-function>+) combined "as
/// per the transform property" (transform_interpolation: Transforms 1
/// section 9 with Transforms 2 sections 13-15).
fn combineTransformLists(allocator: Allocator, a: []const syntax_values.Item, b: []const syntax_values.Item, p: f64, op: SyntaxOp) Allocator.Error!?syntax_values.Value {
    const items = (try combineTransformItems(allocator, a, b, p, op)) orelse return null;
    return .{ .allocator = allocator, .data = .{ .list = .{ .separator = .space, .items = items } } };
}

/// The transform functions of `a` and `b` combined, as syntax items. OWNED.
fn combineTransformItems(allocator: Allocator, a: []const syntax_values.Item, b: []const syntax_values.Item, p: f64, op: SyntaxOp) Allocator.Error!?[]syntax_values.Item {
    const fa = try allocator.alloc(transform_functions.Function, a.len);
    defer allocator.free(fa);
    for (fa, a) |*f, item| f.* = item.transform;
    const fb = try allocator.alloc(transform_functions.Function, b.len);
    defer allocator.free(fb);
    for (fb, b) |*f, item| f.* = item.transform;
    const combined = (try transform_interpolation.combineFunctions(allocator, fa, fb, p, if (op == .interpolate) .interpolate else .accumulate)) orelse return null;
    defer allocator.free(combined);
    const items = allocator.alloc(syntax_values.Item, combined.len) catch |err| {
        for (combined) |*f| f.deinit();
        return err;
    };
    for (items, combined) |*item, f| item.* = .{ .transform = f };
    return items;
}

fn combineItem(allocator: Allocator, a: syntax_values.Item, b: syntax_values.Item, p: f64, op: SyntaxOp) Allocator.Error!?syntax_values.Item {
    const ka: f64, const kb: f64 = if (op == .interpolate) .{ 1 - p, p } else .{ 1, 1 };
    switch (a) {
        .numeric => |x| {
            if (b != .numeric or b.numeric.data_type != x.data_type) return null;
            const kind = numericKind(x.data_type) orelse return null;
            var number = (try mixNumbers(allocator, x.number, ka, b.numeric.number, kb, kind)) orelse return null;
            // Values 4 5.1: an interpolated <integer> rounds, halfway values
            // towards positive infinity.
            if (x.data_type == .integer) if (literal(number)) |n| {
                number.unref();
                number = .{ .literal = .{ .value = @floatFromInt(roundInteger(n.value)), .unit = n.unit } };
            };
            return .{ .numeric = .{ .data_type = x.data_type, .number = number } };
        },
        .color => |x| {
            if (b != .color) return null;
            const color = (try combineLegacy(allocator, x, b.color, p, if (op == .interpolate) .interpolate else .accumulate)) orelse return null;
            return .{ .color = color };
        },
        .transform => {
            if (b != .transform) return null;
            // A single function: its addition is its accumulation (it
            // cannot hold a list); two different functions combine as
            // matrices (Transforms 2 section 14).
            const one = [_]syntax_values.Item{a};
            const other = [_]syntax_values.Item{b};
            const items = (try combineTransformItems(allocator, &one, &other, p, if (op == .add) .accumulate else op)) orelse return null;
            defer allocator.free(items);
            std.debug.assert(items.len == 1);
            return items[0];
        },
        .image, .url, .ident, .string => return null,
    }
}

fn numericKind(data_type: syntax_definitions.DataType) ?math.Kind {
    return switch (data_type) {
        .length => .length,
        .number => .number,
        .percentage => .percentage,
        .length_percentage => .length_percentage,
        .integer => .integer,
        .angle => .angle,
        .time => .time,
        .resolution => .resolution,
        else => null,
    };
}

/// `a` * `ka` + `b` * `kb` of two computed numbers of `kind`: a literal when
/// both are of one unit (a zero length or percentage takes the other's),
/// else a computed calc() mix (lengths with percentages). Null when the mix
/// does not parse as `kind`. OWNED.
pub fn mixNumbers(allocator: Allocator, a: Number, ka: f64, b: Number, kb: f64, kind: math.Kind) Allocator.Error!?Number {
    if (mixNumeric(a, ka, b, kb)) |n| return .{ .literal = n };
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try text.appendSlice(allocator, "calc((");
    try a.serialize(&text, allocator);
    try text.print(allocator, ") * {d} + (", .{ka});
    try b.serialize(&text, allocator);
    try text.print(allocator, ") * {d})", .{kb});
    const parsed = (try math.parse(allocator, text.items, .{ .kind = kind })) orelse return null;
    defer parsed.expression.unref();
    const computed = try parsed.expression.compute(allocator, .{});
    // A mix whose percentage part cancelled is a plain number again.
    if (computed.computedNumber()) |n| {
        computed.unref();
        return .{ .literal = n };
    }
    return .{ .calculation = computed };
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
        .integer => |i| return .{
            .integer = switch (grammar) {
                // Break3/4 §3.3: orphans/widows stay positive after compositing.
                .column_count, .positive_integer => @max(i, 1),
                else => i,
            },
        },
        .length => |len| {
            if (nonNegativeLengths(grammar) and len.value < 0) return .{ .length = .{ .value = 0, .unit = len.unit } };
            return v;
        },
        // A legacy color carried out of range (or between bytes) by the
        // combining operations (colorOf) is final as the rgb() color it
        // serializes as: each channel clipped to [0, 255] and rounded (CSS
        // Color 4 12.1 legacy colors; color_values.finalLegacy). Shadow and
        // drop-shadow() colors inside a list keep their resolved form, which
        // serializes the same way.
        .color => |c| {
            const rgba = color_values.finalLegacy(c) orelse return v;
            v.release();
            return .{ .color = .{ .rgba = rgba } };
        },
        // scrollbar-color's pair: each color final as a color property's
        // (property-types.js colorPairType: rgb(128, 128, 128) + rgb(255, 0,
        // 0) is carried as 383 and clipped only at the end). A combination
        // result is its own list (one reference), so it is finalized in
        // place; a shared list holds computed colors, already final.
        .text_values => |list| {
            if (list.property != .scrollbar_color or list.refs.load(.acquire) != 1) return v;
            for (@constCast(list.items)) |*item| if (item.* == .color) if (color_values.finalLegacy(item.color)) |rgba| {
                item.release();
                item.* = .{ .color = .{ .rgba = rgba } };
            };
            return v;
        },
        else => return v,
    }
}

fn nonNegativeLengths(grammar: properties.Grammar) bool {
    return switch (grammar) {
        // Rhythm1 §2.1: the final animated <length [0,∞]> is nonnegative.
        .block_step_size => true,
        .length_percentage_nonneg, .size, .max_size, .line_width, .font_size, .column_size, .gap, .stroke_width, .perspective, .line_height, .flex_basis, .contain_intrinsic => true,
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

const TransformOp = enum { interpolate, add, accumulate };

/// Transforms 2 section 5 (the translate, rotate and scale properties): "by
/// computed value" for translate and scale - component by component, a
/// translate's x and y as length-percentages (a px/% pair mixes into a
/// calc()), addition summing translations and multiplying scales - and "as
/// SLERP" for rotate (transform_interpolation.mixAxisAngle). "When ...
/// the from value or to value (but not both) is none, the value none is
/// replaced by the equivalent identity value (0px for translate, 0deg for
/// rotate, 1 for scale)", so the result is never `none`.
fn mixTransforms(allocator: Allocator, a: Value, b: Value, p: f64, op: TransformOp) Allocator.Error!?Value {
    const kind = individualTransform(a) orelse individualTransform(b).?;
    if (individualTransform(a)) |k| if (k != kind) return null;
    if (individualTransform(b)) |k| if (k != kind) return null;
    const identity = identityComponents(kind);
    const ca: [4]Number = if (a == .transform) a.transform.components else identity;
    const cb: [4]Number = if (b == .transform) b.transform.components else identity;
    var out: [4]Number = .{ Number.scalar(0), Number.scalar(0), Number.scalar(0), Number.scalar(0) };
    var done = false;
    defer if (!done) for (out) |n| n.unref();
    if (kind == .rotate) {
        var axis_a: [3]f64 = undefined;
        var axis_b: [3]f64 = undefined;
        for (0..3) |i| {
            axis_a[i] = (literal(ca[i]) orelse return null).value;
            axis_b[i] = (literal(cb[i]) orelse return null).value;
        }
        // `none` rotates by 0deg about the other side's axis.
        if (a != .transform) axis_a = axis_b;
        if (b != .transform) axis_b = axis_a;
        const x: transform_interpolation.AxisAngle = .{ .axis = axis_a, .angle = degrees(ca[3]) orelse return null };
        const y: transform_interpolation.AxisAngle = .{ .axis = axis_b, .angle = degrees(cb[3]) orelse return null };
        const r = switch (op) {
            .interpolate => transform_interpolation.mixAxisAngle(x, y, p),
            .add, .accumulate => transform_interpolation.addAxisAngle(x, y),
        } orelse return null;
        for (0..3) |i| out[i] = Number.scalar(r.axis[i]);
        out[3] = .{ .literal = .{ .value = r.angle, .unit = .deg } };
    } else {
        const ka: f64, const kb: f64 = if (op == .interpolate) .{ 1 - p, p } else .{ 1, 1 };
        for (0..3) |i| {
            if (kind == .scale and op != .interpolate) {
                const x = literal(ca[i]) orelse return null;
                const y = literal(cb[i]) orelse return null;
                // Addition multiplies scales; accumulation adds them with
                // one subtracted (a + b - 1), as Transforms 2 15 combines a
                // transform list's one-based parameters. Golden rule 2: the
                // scale property's "by computed value" would give a + b, but
                // Firefox 159 and Safari 27.2 give a + b - 1 and Chrome 157 a
                // product (accumulation-per-property-002 "scale ..." expect
                // -2 for 2 and -3): the majority.
                out[i] = Number.scalar(if (op == .add) x.value * y.value else x.value + y.value - 1);
                continue;
            }
            const component_kind: math.Kind = if (kind == .scale) .number else if (i < 2) .length_percentage else .length;
            out[i] = (try mixNumbers(allocator, ca[i], ka, cb[i], kb, component_kind)) orelse return null;
        }
    }
    const result = try allocator.create(transform_values.Transform);
    result.* = .{ .allocator = allocator, .kind = kind, .components = out };
    done = true;
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
/// <length-percentage>"), axis by axis. A complemented (right/bottom) offset
/// combines as its distance from the left/top edge, 100% minus it (Values 4
/// 9.1's computed value), so `right 10px` meets `left 30px` as
/// calc(100% - 10px) meets 30px (Blink CSSPositionAxisListInterpolationType
/// converts the same way; Gecko computes `right 10px` to calc(100% - 10px)).
fn mixPositions(allocator: Allocator, a: *const position_values.Position, ka: f64, b: *const position_values.Position, kb: f64) Allocator.Error!?Value {
    if (a.data != .computed or b.data != .computed or a.logical != b.logical) return null;
    var offsets: [2]position_values.Offset = undefined;
    var made: usize = 0;
    var done = false;
    defer if (!done) for (offsets[0..made]) |o| o.value.release();
    for (a.data.computed, b.data.computed) |oa, ob| {
        const v = (try mixOffsets(allocator, oa, ka, ob, kb)) orelse return null;
        offsets[made] = .{ .value = v };
        made += 1;
    }
    const result = try allocator.create(position_values.Position);
    result.* = .{ .allocator = allocator, .data = .{ .computed = offsets }, .logical = a.logical };
    done = true;
    return .{ .image_position = result };
}

/// Two computed <position> values, either of which may be the keyword
/// `center` (object-position's initial value, Images 3 5.5: 50% 50%).
fn mixPositionValues(allocator: Allocator, a: Value, ka: f64, b: Value, kb: f64) Allocator.Error!?Value {
    var center_a = centerPosition(allocator);
    var center_b = centerPosition(allocator);
    const pa: *const position_values.Position = switch (a) {
        .image_position => |p| p,
        .keyword => |k| if (k == .center) &center_a else return null,
        else => return null,
    };
    const pb: *const position_values.Position = switch (b) {
        .image_position => |p| p,
        .keyword => |k| if (k == .center) &center_b else return null,
        else => return null,
    };
    return mixPositions(allocator, pa, ka, pb, kb);
}

/// The computed `center` position, 50% 50%, on the stack (percentages own
/// nothing).
fn centerPosition(allocator: Allocator) position_values.Position {
    const half: Value = .{ .length = Length.percent(50) };
    return .{ .allocator = allocator, .data = .{ .computed = .{ .{ .value = half }, .{ .value = half } } } };
}

/// Two computed offsets combined as length-percentages from the start edge.
/// OWNED; null when either is not a length-percentage.
fn mixOffsets(allocator: Allocator, a: position_values.Offset, ka: f64, b: position_values.Offset, kb: f64) Allocator.Error!?Value {
    const xa = (try startOffset(allocator, a)) orelse return null;
    defer xa.release();
    const xb = (try startOffset(allocator, b)) orelse return null;
    defer xb.release();
    if (!lengthPercentage(xa) or !lengthPercentage(xb)) return null;
    return try mixLengths(allocator, xa, ka, xb, kb);
}

/// A computed offset as its distance from the start edge: a complemented
/// offset is 100% minus it (Values 4 9.1). OWNED; null for one that is not
/// a length-percentage.
fn startOffset(allocator: Allocator, o: position_values.Offset) Allocator.Error!?Value {
    if (!o.complement) return retained(o.value);
    if (!lengthPercentage(o.value)) return null;
    return try mixLengths(allocator, .{ .length = Length.percent(100) }, 1, o.value, -1);
}

// ============================================================================
// Composite values combined component by component (Web Animations 1 5.2
// "by computed value" and "repeatable list"; CSS Values 4 section 3)
// ============================================================================

/// The weights of a linear combination a * ka + b * kb: interpolation at p
/// is (1 - p, p); addition and accumulation are (1, 1) (Values 4 3). `p`
/// is the interpolation's progress, for components that do not combine
/// linearly (a path's arc flags); null for addition and accumulation.
const Weights = struct { ka: f64, kb: f64, p: ?f64 = null };

/// The longhands whose Animation type is "repeatable list" (Web Animations 1
/// 5.2): Backgrounds 3 background-position-x/-y and background-size,
/// Masking 1 mask-position and mask-size.
fn repeatableList(l: Longhand) bool {
    return switch (l) {
        .background_position_x, .background_position_y, .background_size, .mask_position, .mask_size => true,
        else => false,
    };
}

/// A composite pair combined component by component; null when the kinds,
/// or any pair of components, do not combine (Web Animations 5.2: "the
/// property values combine as discrete"). OWNED.
///
/// Engines (designs only): Blink CSSLengthPairInterpolationType (corner
/// radii, border-spacing), CSSSizeListInterpolationType and
/// CSSPositionAxisListInterpolationType over ListInterpolationFunctions'
/// lowest common multiple, CSSBorderImageLengthBoxInterpolationType,
/// CSSFontSizeAdjustInterpolationType, CSSTextIndentInterpolationType;
/// Gecko's derived Animate for the same computed types.
fn mixComposite(allocator: Allocator, l: Longhand, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    if (repeatableList(l)) return try mixRepeatable(allocator, l, a, b, w);
    if (a == .corner_radius and b == .corner_radius) return try mixCorners(allocator, a.corner_radius, b.corner_radius, w);
    if (a == .image_quad or b == .image_quad) return try mixQuads(allocator, a, b, w);
    if (a == .text_values and b == .text_values) return try mixComponents(allocator, l, a, b, w);
    if (a == .font_size_adjust and b == .font_size_adjust) return try mixFontSizeAdjust(allocator, a.font_size_adjust, b.font_size_adjust, w);
    if (a == .indent or b == .indent) return try mixIndents(allocator, a, b, w);
    if (a == .font_settings and b == .font_settings) return try mixFontSettings(allocator, a.font_settings, b.font_settings, w);
    if (l == .offset_rotate) return try mixRotations(allocator, a, b, w);
    if (a == .motion_path and b == .motion_path) return try mixMotionPaths(allocator, a.motion_path, b.motion_path, w);
    if (a == .shape and b == .shape) {
        const shape = (try shape_interpolation.mixShapes(allocator, a.shape, b.shape, .{ .ka = w.ka, .kb = w.kb, .p = w.p })) orelse return null;
        return .{ .shape = shape };
    }
    return null;
}

/// The component lists (text_values.Components) that combine by computed
/// value, component by component; null for the others and for a pair that
/// does not combine (OWNED):
/// - clip's rect() (Masking 1 Appendix A): each offset as a length, an
///   `auto` only with `auto` (Blink CSSClipInterpolationType;
///   web-animations/responsive/clip.html and property-types.js rectType);
/// - contain-intrinsic-* `auto <length>` (Sizing 4 §5.2 "by computed value
///   type"): the lengths, never below zero;
/// - scrollbar-color's two colors (Scrollbars 1 §3; property-types.js
///   colorPairType), each as a color property's;
/// - aspect-ratio's <ratio> (Values 4 §5.7.1, sizing_values.mixRatios);
/// - stroke-dasharray, a repeatable list of length-percentages (SVG 2
///   §13.5.6; property-types.js dasharrayType's mismatched lengths repeat to
///   their least common multiple).
fn mixComponents(allocator: Allocator, l: Longhand, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    const x = a.text_values;
    const y = b.text_values;
    const non_negative = switch (l) {
        .aspect_ratio => return if (w.p == null) null else try sizing_values.mixRatios(allocator, a, b, w.ka, w.kb),
        .stroke_dasharray => return if (w.p == null) null else try mixDasharrays(allocator, x.items, y.items, w),
        .clip, .scrollbar_color => false,
        .contain_intrinsic_width, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_block_size => true,
        else => return null,
    };
    if (x.property != y.property or x.items.len != y.items.len or x.items.len > 4) return null;
    var out: [4]Value = undefined;
    var n: usize = 0;
    defer for (out[0..n]) |v| v.release();
    for (x.items, y.items) |p, q| {
        const mixed = (try mixComponent(allocator, p, q, w)) orelse return null;
        out[n] = if (non_negative) nonNegative(mixed) else mixed;
        n += 1;
    }
    return .{ .text_values = try text_values.Components.create(allocator, x.property, out[0..n]) };
}

/// One component: two colors as the color properties combine them
/// (unclamped until clampFinal, as a color property's), else mixScalar's
/// numbers, length-percentages and equal keywords. OWNED.
fn mixComponent(allocator: Allocator, p: Value, q: Value, w: Weights) Allocator.Error!?Value {
    if (p == .color and q == .color) {
        if (w.p) |t| {
            if (try combineLegacy(allocator, p.color, q.color, t, .interpolate)) |c| return .{ .color = c };
            return try mixColors(allocator, p.color, q.color, t);
        }
        if (try combineLegacy(allocator, p.color, q.color, 1, .accumulate)) |c| return .{ .color = c };
        return null;
    }
    return mixScalar(allocator, p, w.ka, q, w.kb);
}

/// SVG 2 §13.5.6 stroke-dasharray as a repeatable list (Web Animations 1
/// 5.2): both lists repeated to their least common multiple, each pair of
/// length-percentages combined and kept nonnegative. OWNED.
fn mixDasharrays(allocator: Allocator, a: []const Value, b: []const Value, w: Weights) Allocator.Error!?Value {
    if (a.len == 0 or b.len == 0) return null;
    const n = a.len / std.math.gcd(a.len, b.len) * b.len;
    const items = try allocator.alloc(Value, n);
    var made: usize = 0;
    defer {
        for (items[0..made]) |v| v.release();
        allocator.free(items);
    }
    for (0..n) |i| {
        const x = a[i % a.len];
        const y = b[i % b.len];
        if (!lengthPercentage(x) or !lengthPercentage(y)) return null;
        items[i] = nonNegative((try mixLengths(allocator, x, w.ka, y, w.kb)) orelse return null);
        made += 1;
    }
    return .{ .text_values = try text_values.Components.create(allocator, .stroke_dasharray, items) };
}

/// `a` * `ka` + `b` * `kb` of two computed <length-percentage>s (Values 4
/// 5.6.1), for the shape and path combinations. OWNED; null when either is
/// not a length-percentage.
pub fn mixLengthPercentage(allocator: Allocator, a: Value, ka: f64, b: Value, kb: f64) Allocator.Error!?Value {
    if (!lengthPercentage(a) or !lengthPercentage(b)) return null;
    return try mixLengths(allocator, a, ka, b, kb);
}

/// Two computed <position>s combined coordinate by coordinate (Values 4
/// 9.1). OWNED (an `image_position`); null when they do not combine.
pub fn mixPosition(allocator: Allocator, a: *const position_values.Position, ka: f64, b: *const position_values.Position, kb: f64) Allocator.Error!?Value {
    return mixPositions(allocator, a, ka, b, kb);
}

// ============================================================================
// Motion Path (CSS Motion Path 1 2.1, 2.5)
// ============================================================================

const RotationParts = struct { auto: bool, degrees: f64 };

/// A computed offset-rotate as its `auto` flag and angle: `auto` alone is
/// `auto 0deg`, and `reverse` has already computed to `auto` + 180deg.
fn rotationParts(v: Value) ?RotationParts {
    return switch (v) {
        .keyword => |k| if (k == .auto) .{ .auto = true, .degrees = 0 } else null,
        .motion_rotation => |r| .{ .auto = r.mode != null, .degrees = degrees(r.angle) orelse return null },
        else => null,
    };
}

/// Motion Path 1 2.5 offset-rotate, "by computed value": the angles combine
/// when both sides are `auto` (or both are not), else discrete (Blink
/// CSSOffsetRotateInterpolationType's OffsetRotationType check; WPT
/// offset-rotate-interpolation/-composition, which Chrome, Firefox and Safari
/// pass).
fn mixRotations(allocator: Allocator, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    const x = rotationParts(a) orelse return null;
    const y = rotationParts(b) orelse return null;
    if (x.auto != y.auto) return null;
    const angle = x.degrees * w.ka + y.degrees * w.kb;
    // As the property computes: `auto 0deg` is the keyword `auto`.
    if (x.auto and angle == 0) return Value.kw(.auto);
    const rotation = try motion_values.Rotation.create(allocator, if (x.auto) .auto else null, .{ .literal = .{ .value = angle, .unit = .deg } });
    return .{ .motion_rotation = rotation };
}

/// Motion Path 1 2.1 offset-path, "by computed value": the same <coord-box>
/// (Shapes 1 3.4 "the same reference box"), then by kind:
/// - ray() (2.1.1): the same <ray-size>, the same `contain`, and both with or
///   both without `at <position>`; the angle and the position combine
///   (Blink CSSRayInterpolationType; WPT offset-path-interpolation-005 and
///   offset-path-composition);
/// - a <basic-shape> or path(): shape_interpolation.
/// Anything else (a box alone, url(), none) is discrete.
fn mixMotionPaths(allocator: Allocator, a: *const motion_values.Path, b: *const motion_values.Path, w: Weights) Allocator.Error!?Value {
    if (a.box != b.box) return null;
    switch (a.data) {
        .ray => |ra| {
            const rb = switch (b.data) {
                .ray => |r| r,
                else => return null,
            };
            if (ra.size != rb.size or ra.contain != rb.contain) return null;
            if ((ra.position == null) != (rb.position == null)) return null;
            const da = degrees(ra.angle) orelse return null;
            const db = degrees(rb.angle) orelse return null;
            var position: ?*position_values.Position = null;
            defer if (position) |p| p.unref();
            if (ra.position) |pa| {
                const mixed = (try mixPositions(allocator, pa, w.ka, rb.position.?, w.kb)) orelse return null;
                position = mixed.image_position;
            }
            const ray: motion_values.Ray = .{
                .angle = .{ .literal = .{ .value = da * w.ka + db * w.kb, .unit = .deg } },
                .size = ra.size,
                .contain = ra.contain,
                .position = position,
            };
            return .{ .motion_path = try motion_values.Path.create(allocator, .{ .ray = ray }, a.box) };
        },
        .shape => |sa| {
            const sb = switch (b.data) {
                .shape => |s| s,
                else => return null,
            };
            const shape = (try shape_interpolation.mixShapes(allocator, sa, sb, .{ .ka = w.ka, .kb = w.kb, .p = w.p })) orelse return null;
            defer shape.unref();
            return .{ .motion_path = try motion_values.Path.create(allocator, .{ .shape = shape }, a.box) };
        },
        .box, .url => return null,
    }
}

/// One scalar component: <number>s as numbers (Values 4 5.3.1),
/// <length-percentage>s as length-percentages (5.6.1), and identical
/// keywords as themselves (Web Animations 5.2: a discrete component combines
/// only when the two match). OWNED.
fn mixScalar(allocator: Allocator, a: Value, ka: f64, b: Value, kb: f64) Allocator.Error!?Value {
    if (a == .number and b == .number) return .{ .number = a.number * ka + b.number * kb };
    if (lengthPercentage(a) and lengthPercentage(b)) return try mixLengths(allocator, a, ka, b, kb);
    if (a == .keyword and b == .keyword and a.keyword == b.keyword) return retained(a);
    return null;
}

/// A component of a property whose values are never negative (corner radii,
/// border-spacing, background-size, the border-image quads, a shadow's
/// blur). Values 4 3.1 clamps only the final value; these components are
/// clamped where they are combined because their inputs are never negative,
/// so only an extrapolated interpolation leaves the range, and the pair
/// types have no clampFinal of their own (Blink's InterpolableLength
/// clamps the same components with ValueRange::kNonNegative when it builds
/// the value). Takes ownership.
pub fn nonNegative(v: Value) Value {
    return switch (v) {
        .number => |n| if (n < 0) .{ .number = 0 } else v,
        .length => |len| if (len.value < 0) .{ .length = .{ .value = 0, .unit = len.unit } } else v,
        else => v,
    };
}

/// Backgrounds 3 border-*-radius and Tables 3 border-spacing: a pair, each
/// axis a length-percentage.
fn mixCorners(allocator: Allocator, a: border_radius.Corner, b: border_radius.Corner, w: Weights) Allocator.Error!?Value {
    const xa = a.axes();
    const xb = b.axes();
    var out: [2]Value = undefined;
    var made: usize = 0;
    defer for (out[0..made]) |v| v.release();
    for (0..2) |i| {
        out[i] = nonNegative((try mixScalar(allocator, xa[i], w.ka, xb[i], w.kb)) orelse return null);
        made += 1;
    }
    return .{ .corner_radius = try border_radius.Corner.create(allocator, out[0], out[1]) };
}

/// The items of a layered value: a single value is a one-item list.
fn layerItems(v: *const Value) []const Value {
    return if (v.* == .layers) v.layers.items else @as(*const [1]Value, v);
}

/// Web Animations 1 5.2 "repeatable list": both lists repeated to the least
/// common multiple of their lengths, then combined item by item; any item
/// pair that does not combine makes the whole pair discrete.
fn mixRepeatable(allocator: Allocator, l: Longhand, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    const xs = layerItems(&a);
    const ys = layerItems(&b);
    if (xs.len == 0 or ys.len == 0) return null;
    const n = xs.len / std.math.gcd(xs.len, ys.len) * ys.len;
    const items = try allocator.alloc(Value, n);
    var made: usize = 0;
    defer {
        for (items[0..made]) |v| v.release();
        allocator.free(items);
    }
    for (0..n) |i| {
        items[i] = (try mixLayer(allocator, xs[i % xs.len], ys[i % ys.len], w)) orelse return null;
        made += 1;
    }
    if (n == 1) return retained(items[0]);
    return .{ .layers = try image_layers.Layers.create(allocator, l, items) };
}

/// One item of a repeatable list: a background-size (two axes), or a
/// background-position axis (a length-percentage from the start edge).
fn mixLayer(allocator: Allocator, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    if (a == .image_size or b == .image_size) return try mixSizes(allocator, a, b, w);
    if (a == .image_position or b == .image_position) return try mixPositionValues(allocator, a, w.ka, b, w.kb);
    const xa = (try axisOffset(allocator, a)) orelse return null;
    defer xa.release();
    const xb = (try axisOffset(allocator, b)) orelse return null;
    defer xb.release();
    return try mixScalar(allocator, xa, w.ka, xb, w.kb);
}

/// A background-position-x/-y item as a length-percentage from the start
/// edge (Backgrounds 3: "computed value: a list, each item a pair of offsets
/// ... each given as a computed <length-percentage>"). OWNED.
fn axisOffset(allocator: Allocator, v: Value) Allocator.Error!?Value {
    if (v != .image_axis) return retained(v);
    return switch (v.image_axis.data) {
        .computed => |o| try startOffset(allocator, o),
        .specified => null,
    };
}

/// A background-size item's two axes; a single length is `<length> auto`.
fn sizeAxes(v: Value) ?[2]Value {
    return switch (v) {
        .image_size => |s| s.axes,
        .keyword => |k| if (k == .auto) .{ v, v } else null,
        else => if (lengthPercentage(v)) .{ v, Value.kw(.auto) } else null,
    };
}

/// Backgrounds 3 background-size: axis by axis, `auto` only with `auto`.
fn mixSizes(allocator: Allocator, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    const xa = sizeAxes(a) orelse return null;
    const xb = sizeAxes(b) orelse return null;
    var out: [2]Value = undefined;
    var made: usize = 0;
    defer for (out[0..made]) |v| v.release();
    for (0..2) |i| {
        out[i] = nonNegative((try mixScalar(allocator, xa[i], w.ka, xb[i], w.kb)) orelse return null);
        made += 1;
    }
    return .{ .image_size = try image_size.Size.create(allocator, out) };
}

const QuadSides = struct { sides: [4]Value, fill: bool };

/// A border-image-width/-outset/-slice value's four sides; a single value is
/// all four.
fn quadSides(v: Value) ?QuadSides {
    return switch (v) {
        .image_quad => |q| .{ .sides = q.sides, .fill = q.fill },
        .number, .length, .calculation => .{ .sides = @splat(v), .fill = false },
        .keyword => |k| if (k == .auto) .{ .sides = @splat(v), .fill = false } else null,
        else => null,
    };
}

/// Backgrounds 3 border-image-width/-outset/-slice: side by side, a number
/// with a number and a length-percentage with a length-percentage, `auto`
/// only with `auto`, and border-image-slice's `fill` equal on both sides.
fn mixQuads(allocator: Allocator, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    const qa = quadSides(a) orelse return null;
    const qb = quadSides(b) orelse return null;
    if (qa.fill != qb.fill) return null;
    var out: [4]Value = undefined;
    var made: usize = 0;
    defer for (out[0..made]) |v| v.release();
    for (0..4) |i| {
        out[i] = nonNegative((try mixScalar(allocator, qa.sides[i], w.ka, qb.sides[i], w.kb)) orelse return null);
        made += 1;
    }
    return .{ .image_quad = try image_quad.Quad.create(allocator, out, qa.fill) };
}

/// Fonts 5 font-size-adjust: "discrete if the keywords differ, otherwise by
/// computed value type" - the same metric, both aspects numbers.
fn mixFontSizeAdjust(allocator: Allocator, a: *const font_size_adjust.Adjust, b: *const font_size_adjust.Adjust, w: Weights) Allocator.Error!?Value {
    if (a.metric != b.metric) return null;
    const x = a.aspect orelse return null;
    const y = b.aspect orelse return null;
    if (x != .number or y != .number) return null;
    const aspect: Value = .{ .number = @max(x.number * w.ka + y.number * w.kb, 0) };
    return .{ .font_size_adjust = try font_size_adjust.Adjust.create(allocator, a.metric, aspect) };
}

/// Fonts 4 font-variation-settings ("Animation type: (see prose)"): two
/// computed lists of the same axis tags (computed tags are last-wins and
/// sorted, font_settings) interpolate each value as a <number>; any other
/// pair is discrete, and font-feature-settings is discrete (Blink
/// CSSFontVariationSettingsInterpolationType; WPT interpolation-per-property-
/// 001's font-variation-settings cases).
fn mixFontSettings(allocator: Allocator, a: *const font_settings.Settings, b: *const font_settings.Settings, w: Weights) Allocator.Error!?Value {
    if (a.kind != .variation or b.kind != .variation or a.entries.len != b.entries.len) return null;
    const entries = try allocator.alloc(font_settings.Entry, a.entries.len);
    defer allocator.free(entries);
    for (a.entries, b.entries, entries) |x, y, *out| {
        if (!std.mem.eql(u8, &x.tag, &y.tag) or x.value != .number or y.value != .number) return null;
        out.* = .{ .tag = x.tag, .value = .{ .number = x.value.number * w.ka + y.value.number * w.kb } };
    }
    return .{ .font_settings = try font_settings.Settings.create(allocator, .variation, entries) };
}

const IndentParts = struct { offset: Value, flags: text_indent.Flags };

fn indentParts(v: Value) ?IndentParts {
    return switch (v) {
        .indent => |i| .{ .offset = i.offset, .flags = i.flags },
        else => if (lengthPercentage(v)) .{ .offset = v, .flags = .{} } else null,
    };
}

/// Text 3 text-indent: "by computed value type, if the keywords match"
/// (hanging and each-line), the length-percentage combined.
fn mixIndents(allocator: Allocator, a: Value, b: Value, w: Weights) Allocator.Error!?Value {
    const x = indentParts(a) orelse return null;
    const y = indentParts(b) orelse return null;
    if (x.flags.hanging != y.flags.hanging or x.flags.each_line != y.flags.each_line) return null;
    if (!lengthPercentage(x.offset) or !lengthPercentage(y.offset)) return null;
    const offset = (try mixLengths(allocator, x.offset, w.ka, y.offset, w.kb)) orelse return null;
    defer offset.release();
    return .{ .indent = try text_indent.Indent.create(allocator, offset, x.flags) };
}

// ============================================================================
// text-shadow (Text Decoration 3 4: "as shadow list", Backgrounds 3 6.1)
// ============================================================================

const TextShadowItem = text_shadow_values.Shadow;

/// The items of a computed text-shadow value; `none` is the empty list.
fn textShadowList(v: Value) ?[]const TextShadowItem {
    return switch (v) {
        .text_shadow => |s| s.items,
        .keyword => |k| if (k == .none) &.{} else null,
        else => null,
    };
}

/// Pairwise, the shorter list padded with transparent zero-length shadows
/// (Backgrounds 3 6.1). A color that is not a legacy sRGB color (currentcolor
/// before cause 5) is pending: the pair combines discretely.
fn mixTextShadows(allocator: Allocator, a: []const TextShadowItem, b: []const TextShadowItem, p: f64, op: ShadowOp) Allocator.Error!?Value {
    const n = @max(a.len, b.len);
    if (n == 0) return Value.kw(.none);
    const items = try allocator.alloc(TextShadowItem, n);
    defer allocator.free(items);
    var colors: ShadowColors = .{};
    defer colors.release(allocator);
    for (0..n) |i| {
        const x: ?TextShadowItem = if (i < a.len) a[i] else null;
        const y: ?TextShadowItem = if (i < b.len) b[i] else null;
        var item: TextShadowItem = .{ .count = 3 };
        item.color = (try colors.mix(allocator, if (x) |v| v.color orelse .current else null, if (y) |v| v.color orelse .current else null, p, op)) orelse return null;
        for (0..3) |k| {
            const lx = textShadowLength(x, k) orelse return null;
            const ly = textShadowLength(y, k) orelse return null;
            const combined = switch (op) {
                .interpolate => lerp(lx, ly, p),
                .accumulate => lx + ly,
            };
            // The blur radius (the third length) is never negative.
            item.lengths[k] = Value.px(if (k == 2) @max(combined, 0) else combined);
        }
        items[i] = item;
    }
    return .{ .text_shadow = try text_shadow_values.Shadows.create(allocator, items, true) };
}

/// The colors of one shadow list combination: each pair's color (a missing
/// shadow's is transparent), owned here until the list holds its own
/// references. Two legacy colors mix in premultiplied sRGB; any other pair
/// interpolates through color_values (Oklab, or a color-mix() naming
/// currentcolor: Backgrounds 3 6.1 "each shadow's color ... as <color>");
/// only legacy pairs accumulate.
const ShadowColors = struct {
    owned: std.ArrayListUnmanaged(values.Color) = .empty,

    fn mix(self: *ShadowColors, allocator: Allocator, x: ?values.Color, y: ?values.Color, p: f64, op: ShadowOp) Allocator.Error!?values.Color {
        const transparent: values.Color = .{ .rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 } };
        const cx = x orelse transparent;
        const cy = y orelse transparent;
        const color = (try combineLegacy(allocator, cx, cy, p, op)) orelse blk: {
            if (op != .interpolate) return null;
            break :blk (try color_values.interpolateColors(allocator, cx, cy, p)) orelse return null;
        };
        try self.keep(allocator, color);
        return color;
    }

    /// Hold `color` (OWNED) until the list that uses it takes its own
    /// reference; released on failure.
    fn keep(self: *ShadowColors, allocator: Allocator, color: values.Color) Allocator.Error!void {
        if (color != .expression) return;
        self.owned.append(allocator, color) catch |err| {
            color.release();
            return err;
        };
    }

    fn release(self: *ShadowColors, allocator: Allocator) void {
        for (self.owned.items) |c| c.release();
        self.owned.deinit(allocator);
    }
};

/// Addition: the underlying list, then the effect's.
fn concatTextShadows(allocator: Allocator, a: []const TextShadowItem, b: []const TextShadowItem) Allocator.Error!?Value {
    if (a.len + b.len == 0) return Value.kw(.none);
    const items = try allocator.alloc(TextShadowItem, a.len + b.len);
    defer allocator.free(items);
    @memcpy(items[0..a.len], a);
    @memcpy(items[a.len..], b);
    return .{ .text_shadow = try text_shadow_values.Shadows.create(allocator, items, true) };
}

/// A text shadow's k-th length in px (0 for a padding shadow); null for one
/// that is not a px length.
fn textShadowLength(item: ?TextShadowItem, k: usize) ?f64 {
    const v = item orelse return 0;
    if (k >= v.count) return 0;
    return switch (v.lengths[k]) {
        .length => |len| if (len.unit == .px) len.value else null,
        else => null,
    };
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
    var colors: ShadowColors = .{};
    defer colors.release(allocator);
    for (0..n) |i| {
        const x: ?BoxShadowItem = if (i < a.len) a[i] else null;
        const y: ?BoxShadowItem = if (i < b.len) b[i] else null;
        const inset = if (x) |v| v.inset else y.?.inset;
        if (x != null and y != null and x.?.inset != y.?.inset) return null;
        var item: BoxShadowItem = .{ .inset = inset, .count = 4 };
        item.color = (try colors.mix(allocator, if (x) |v| v.color orelse .current else null, if (y) |v| v.color orelse .current else null, p, op)) orelse return null;
        for (0..4) |k| {
            const lx = shadowLength(x, k) orelse return null;
            const ly = shadowLength(y, k) orelse return null;
            const combined = switch (op) {
                .interpolate => lerp(lx, ly, p),
                .accumulate => lx + ly,
            };
            // The blur radius (the third length) is never negative
            // (Backgrounds 3 6.1; the spread may be).
            item.lengths[k] = Value.px(if (k == 2) @max(combined, 0) else combined);
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
// filter (Filter Effects 1 11 "Interpolation of filter")
// ============================================================================

const FilterItem = filter_values.Item;
const FilterFunction = filter_values.Function;

/// The items of a computed filter value; `none` is the empty list.
fn filterList(v: Value) ?[]const FilterItem {
    return switch (v) {
        .filter => |f| f.items,
        .keyword => |k| if (k == .none) &.{} else null,
        else => null,
    };
}

const FilterOp = enum { interpolate, accumulate };

/// Filter Effects 1 11: two lists whose functions match pairwise (the
/// shorter padded with the longer's initial functions) combine function by
/// function; a url() reference or a kind mismatch is discrete. Accumulation
/// of the amount functions whose initial value is 1 subtracts that 1 once
/// (brightness(a) + brightness(b) = brightness(a + b - 1)). The result is a
/// specified value of absolute components, which the cascade computes to
/// itself.
fn mixFilters(allocator: Allocator, a: []const FilterItem, b: []const FilterItem, p: f64, op: FilterOp) Allocator.Error!?Value {
    const n = @max(a.len, b.len);
    if (n == 0) return Value.kw(.none);
    const items = try allocator.alloc(FilterItem, n);
    defer allocator.free(items);
    var colors: ShadowColors = .{};
    defer colors.release(allocator);
    for (0..n) |i| {
        const x: ?FilterFunction = if (i < a.len) (if (a[i] == .function) a[i].function else return null) else null;
        const y: ?FilterFunction = if (i < b.len) (if (b[i] == .function) b[i].function else return null) else null;
        const kind = if (x) |f| f.kind else y.?.kind;
        if (x != null and y != null and x.?.kind != y.?.kind) return null;
        const fx = x orelse initialFilter(kind);
        const fy = y orelse initialFilter(kind);
        items[i] = .{ .function = (try mixFilterFunction(allocator, &colors, fx, fy, p, op)) orelse return null };
    }
    return .{ .filter = try filter_values.Filter.create(allocator, items) };
}

/// The initial value of a filter function (Filter Effects 1 11: "the
/// initial value for interpolation").
fn initialFilter(kind: filter_values.Kind) FilterFunction {
    return .{ .kind = kind, .argument = switch (kind) {
        .blur => .{ .scalar = Value.px(0) },
        .hue_rotate => .{ .angle = .{ .literal = .{ .number = 0, .unit = .deg } } },
        .drop_shadow => .{ .shadow = .{ .color = .{ .rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 } }, .lengths = .{ Value.px(0), Value.px(0), Value.px(0) }, .count = 3 } },
        .brightness, .contrast, .opacity, .saturate => .{ .scalar = .{ .number = 1 } },
        .grayscale, .invert, .sepia => .{ .scalar = .{ .number = 0 } },
    } };
}

/// One pair of computed functions of one kind; null for a component this
/// cannot combine (a calc() or a non-legacy color). A drop-shadow()'s
/// combined color is held in `colors` until the filter list takes its own
/// reference.
fn mixFilterFunction(allocator: Allocator, colors: *ShadowColors, x: FilterFunction, y: FilterFunction, p: f64, op: FilterOp) Allocator.Error!?FilterFunction {
    const one: f64 = switch (x.kind) {
        .brightness, .contrast, .opacity, .saturate => 1,
        else => 0,
    };
    const combine = struct {
        fn f(u: f64, v: f64, t: f64, o: FilterOp, base: f64) f64 {
            return switch (o) {
                .interpolate => lerp(u, v, t),
                .accumulate => u + v - base,
            };
        }
    }.f;
    switch (x.argument) {
        .scalar => |sx| {
            if (y.argument != .scalar) return null;
            const sy = y.argument.scalar;
            // Filter Effects 1 section 6: negative amounts and blur radii are
            // out of range, and grayscale(), invert(), opacity() and sepia()
            // stop at 1 - clamped where combined, as the inputs never leave
            // the range (Blink FilterInterpolationFunctions clamps the same
            // way when it builds the filter; WPT filter-interpolation-003
            // expects blur(0px) and grayscale(1) when extrapolating).
            const upper: f64 = switch (x.kind) {
                .grayscale, .invert, .opacity, .sepia => 1,
                else => std.math.inf(f64),
            };
            if (sx == .number and sy == .number) return .{ .kind = x.kind, .argument = .{ .scalar = .{ .number = std.math.clamp(combine(sx.number, sy.number, p, op, one), 0, upper) } } };
            const lx = pxOf(sx) orelse return null;
            const ly = pxOf(sy) orelse return null;
            return .{ .kind = x.kind, .argument = .{ .scalar = Value.px(@max(combine(lx, ly, p, op, 0), 0)) } };
        },
        .angle => |ax| {
            if (y.argument != .angle or ax != .literal or y.argument.angle != .literal) return null;
            const dx = ax.literal.degrees();
            const dy = y.argument.angle.literal.degrees();
            return .{ .kind = x.kind, .argument = .{ .angle = .{ .literal = .{ .number = combine(dx, dy, p, op, 0), .unit = .deg } } } };
        },
        .shadow => |shx| {
            if (y.argument != .shadow) return null;
            const shy = y.argument.shadow;
            var lengths: [3]Value = undefined;
            for (0..3) |k| {
                const lx = if (k < shx.count) pxOf(shx.lengths[k]) orelse return null else 0;
                const ly = if (k < shy.count) pxOf(shy.lengths[k]) orelse return null else 0;
                const combined = combine(lx, ly, p, op, 0);
                // drop-shadow()'s blur (the third length) is never negative.
                lengths[k] = Value.px(if (k == 2) @max(combined, 0) else combined);
            }
            const color = (try combineLegacy(allocator, shx.color orelse return null, shy.color orelse return null, p, switch (op) {
                .interpolate => .interpolate,
                .accumulate => .accumulate,
            })) orelse return null;
            try colors.keep(allocator, color);
            return .{ .kind = x.kind, .argument = .{ .shadow = .{ .color = color, .lengths = lengths, .count = 3 } } };
        },
        .omitted => return null,
    }
}

fn pxOf(v: Value) ?f64 {
    return switch (v) {
        .length => |len| if (len.unit == .px) len.value else null,
        else => null,
    };
}

// ============================================================================
// Colors
// ============================================================================

/// Two computed colors at least one of which is not a legacy sRGB color
/// (CSS Color 4 section 12; color_values.interpolateColors). OWNED.
fn mixColors(allocator: Allocator, a: values.Color, b: values.Color, p: f64) Allocator.Error!?Value {
    const color = (try color_values.interpolateColors(allocator, a, b, p)) orelse return null;
    return .{ .color = color };
}

/// A computed legacy color (CSS Color 4 12.1) as premultiplied sRGB: its
/// channels on the 0-255 scale times its alpha, which is in [0, 1]. The
/// channels are NOT clamped (CSS Values 4 3.1: "clamping is only applied to
/// the *final* result of applying all interpolation-related operations"):
/// an addition carries rgb(128, 128, 128) + rgb(255, 0, 0) to a red of 383
/// that a later interpolation can bring back into range. Null for a color
/// that does not combine in sRGB here (a non-legacy color, currentcolor:
/// mixColors).
///
/// Golden rule 2: Values 4 8.1.1 says <color> is "not additive", but Chrome
/// 157, Firefox 159 and Safari 27.2 all add colors - every color case of
/// web-animations addition-per-property-001/002 and
/// accumulation-per-property-001/002 passes in all three (wpt.fyi aligned
/// stable run 8c04fb8d43), the "overflowed" ones included - so colors add
/// premultiplied, channel by channel, as here.
const Premultiplied = struct { r: f64, g: f64, b: f64, a: f64 };

fn premultipliedOf(c: values.Color) ?Premultiplied {
    const srgb = color_values.legacySrgb(c) orelse return null;
    const a = std.math.clamp(srgb[3], 0, 1);
    return .{ .r = srgb[0] * 255 * a, .g = srgb[1] * 255 * a, .b = srgb[2] * 255 * a, .a = a };
}

/// The legacy color of `c`: its channels divided by its alpha clamped to
/// [0, 1] (Blink InterpolableColor resolves the same way: the "#RGBa" case
/// rgb(128, 128, 128) + rgba(255, 0, 0, 0.4) is rgb(230, 128, 128)), as an
/// rgb() color when every channel is a byte, else an unclamped resolved
/// legacy color (color_values.unclampedLegacy) that clampFinal makes final.
/// OWNED.
fn colorOf(allocator: Allocator, c: Premultiplied) Allocator.Error!values.Color {
    const a = std.math.clamp(c.a, 0, 1);
    if (a == 0 or std.math.isNan(a)) return .{ .rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 } };
    const channels = [3]f64{ c.r / a, c.g / a, c.b / a };
    var bytes: [3]u8 = undefined;
    for (channels, &bytes) |x, *byte| {
        if (!(x >= 0 and x <= 255) or @round(x) != x) {
            return color_values.unclampedLegacy(allocator, .{ channels[0] / 255, channels[1] / 255, channels[2] / 255 }, a);
        }
        byte.* = @intFromFloat(x);
    }
    return .{ .rgba = .{ .r = bytes[0], .g = bytes[1], .b = bytes[2], .a = @floatCast(a) } };
}

fn mixPremultiplied(a: Premultiplied, b: Premultiplied, p: f64) Premultiplied {
    return .{ .r = lerp(a.r, b.r, p), .g = lerp(a.g, b.g, p), .b = lerp(a.b, b.b, p), .a = lerp(a.a, b.a, p) };
}

/// Addition: channels add premultiplied, unclamped; alpha stays in [0, 1]
/// (Gecko's color Animate clamps the summed alpha the same way).
fn addPremultiplied(a: Premultiplied, b: Premultiplied) Premultiplied {
    return .{ .r = a.r + b.r, .g = a.g + b.g, .b = a.b + b.b, .a = @min(a.a + b.a, 1) };
}

/// Two legacy colors combined in premultiplied sRGB; null when either is
/// not a legacy color. OWNED.
fn combineLegacy(allocator: Allocator, x: values.Color, y: values.Color, p: f64, op: ShadowOp) Allocator.Error!?values.Color {
    const a = premultipliedOf(x) orelse return null;
    const b = premultipliedOf(y) orelse return null;
    return try colorOf(allocator, switch (op) {
        .interpolate => mixPremultiplied(a, b, p),
        .accumulate => addPremultiplied(a, b),
    });
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
    // 127.5 stays a float until the final value rounds it (Values 4 3.1).
    const mid = clampFinal(.color, try interpolate(a, .color, red, blue, 0.5)).color.rgba;
    try testing.expectEqual(@as(u8, 128), mid.r);
    try testing.expectEqual(@as(u8, 128), mid.b);
    const clear: Value = .{ .color = .transparent_keyword };
    const half = (try interpolate(a, .color, clear, red, 0.5)).color.rgba;
    // Premultiplied: the transparent end contributes no hue.
    try testing.expectEqual(@as(u8, 255), half.r);
    try testing.expectEqual(@as(f32, 0.5), half.a);
    // 128 + 128 is 256, unclamped, until the final value clamps it.
    const grey: Value = .{ .color = .{ .rgba = .{ .r = 128, .g = 128, .b = 128 } } };
    const raw = try add(a, .color, grey, grey);
    try testing.expectApproxEqAbs(@as(f64, 256), color_values.legacySrgb(raw.color).?[0] * 255, 1e-9);
    const sum = clampFinal(.color, raw).color.rgba;
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
    // p = 0 keeps the mixed type (Values 4 5.6.1; WPT vertical-align and
    // offset-distance expect calc(0% + 10px) at 0); p = 1 is V_B.
    const back = try interpolate(a, .width, .{ .length = Length.px(10) }, .{ .length = Length.percent(50) }, 0);
    defer back.release();
    try testing.expect(back == .calculation);
    out.clearRetainingCapacity();
    try back.calculation.serialize(&out, a);
    try testing.expectEqualStrings("calc(0% + 10px)", out.items);
    const end = try interpolate(a, .width, .{ .length = Length.px(10) }, .{ .length = Length.percent(50) }, 1);
    defer end.release();
    try testing.expect(end == .length);
    try testing.expectEqual(@as(f64, 50), end.length.value);
    const sum = try add(a, .width, .{ .length = Length.px(10) }, .{ .length = Length.percent(50) });
    defer sum.release();
    try testing.expect(sum == .calculation);
    // Lengths and numbers do not combine smoothly (line-height).
    const swap = try interpolate(a, .line_height, .{ .number = 1.5 }, .{ .length = Length.px(20) }, 0.6);
    try testing.expect(swap == .length);
}
