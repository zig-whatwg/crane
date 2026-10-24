//! Media Queries Level 5: parse and evaluate.
//!
//! A pure module: it knows the environment only through `MediaValues`, which
//! the host fills in (Crane draws nothing, so there is no layout to ask).
//!
//! ## Specifications
//!
//! - Media Queries Level 5: https://drafts.csswg.org/mediaqueries-5/
//!   (specs/w3c/mediaqueries-5.md) sections 2 (queries, types, features),
//!   3 (syntax, evaluation, error handling), 4, 5.1, 6.1-6.3, 9, 12 and
//!   appendix A (the features answered here).
//! - CSSOM 4.1 "parse a media query list", 4.2 "serialize a media query list".
//!
//! ## Shape
//!
//! `MediaQueryList.parse` turns text into an owned tree (`MediaQuery`,
//! `Condition`, `Feature`); `matches` evaluates it against a `MediaValues`
//! in the three-valued (Kleene) logic of section 3.1; `serialize` writes it
//! back (CSSOM 4.2, with the range syntax kept as written).
//!
//! ## Choices the specification leaves open (see the tests)
//!
//! - A media feature the environment holds no fact for (hover, pointer,
//!   color-gamut, ...) evaluates to unknown - never an invented answer. So
//!   does a feature name nobody defined (section 3.2).
//! - "Negative values" of a range feature that is "false in the negative
//!   range" (width, height, resolution, color, ...) are valid and parsed
//!   (section 2.4.3); only aspect-ratio (whose <ratio> cannot be negative)
//!   and -webkit-device-pixel-ratio reject them, as unknown.
//! - `min-`/`max-` before a discrete feature's name is an unknown feature
//!   name (section 2.4.4); `min-`/`max-` before a range feature in the
//!   boolean form `(min-width)` is a syntax error ("invalid and a syntax
//!   error", same section), which makes the whole query `not all`.

const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const serialize_mod = @import("serialize.zig");

const Token = tokenizer.Token;

// ============================================================================
// The environment
// ============================================================================

/// What a media query is evaluated against: the facts a headless engine can
/// state. Everything else a media feature could ask (hover, pointer,
/// color-gamut, ...) has no fact here and is unknown (module doc).
pub const MediaValues = struct {
    /// The media type the document is displayed on (section 2.3).
    media_type: enum { screen, print } = .screen,
    /// Viewport size in CSS px (the `width` and `height` features, 4.1/4.2).
    width: f64 = 1024,
    height: f64 = 768,
    /// Size of the rendering surface in CSS px (`device-width`/`device-height`).
    device_width: f64 = 1920,
    device_height: f64 = 1080,
    /// Pixel density in device pixels per CSS px (the `resolution` feature, 5.1).
    resolution: f64 = 1,
    /// Bits per color component (the `color` feature, 6.1); 0 for a device
    /// that is not a color device.
    color_bits: u32 = 8,
    /// Entries in the color lookup table (`color-index`, 6.2).
    color_index: u32 = 0,
    /// Bits per pixel of a monochrome frame buffer (`monochrome`, 6.3).
    monochrome_bits: u32 = 0,
    prefers_color_scheme: enum { light, dark } = .light,
    prefers_reduced_motion: enum { no_preference, reduce } = .no_preference,
    prefers_contrast: enum { no_preference, more, less, custom } = .no_preference,
    forced_colors: bool = false,
    scripting: enum { none, initial_only, enabled } = .enabled,
    /// The initial value of `font-size`: what `em`, `rem`, `ex` and `ch` are
    /// relative to in a query (section 1.3).
    font_size: f64 = 16,

    /// Whether two environments are the same (a change means queries must be
    /// re-evaluated, section 2).
    pub fn eql(a: MediaValues, b: MediaValues) bool {
        return std.meta.eql(a, b);
    }
};

// ============================================================================
// The parsed form
// ============================================================================

/// A comparison operator of the range syntax (section 3, <mf-comparison>).
pub const Op = enum {
    lt,
    le,
    gt,
    ge,
    eq,

    fn text(op: Op) []const u8 {
        return switch (op) {
            .lt => "<",
            .le => "<=",
            .gt => ">",
            .ge => ">=",
            .eq => "=",
        };
    }

    /// The same relation read the other way round: `5px < width` is
    /// `width > 5px`.
    fn flip(op: Op) Op {
        return switch (op) {
            .lt => .gt,
            .le => .ge,
            .gt => .lt,
            .ge => .le,
            .eq => .eq,
        };
    }
};

/// An <mf-value> (section 3): a number, a dimension, an ident or a ratio.
/// Idents and units are ASCII-lowercased and in identifier-serialized form.
pub const Value = union(enum) {
    number: struct { value: f64, is_integer: bool },
    dimension: struct { value: f64, unit: []const u8 },
    ident: []const u8,
    ratio: struct { numerator: f64, denominator: f64 },
};

/// The feature a media feature name refers to, when this module answers it.
/// `unknown` is a name nobody defined, or a feature the environment holds no
/// fact for: both evaluate to unknown (module doc).
pub const FeatureId = enum {
    unknown,
    /// A range feature MQ5 defines without a fact here (the viewport segments).
    unanswered_range,
    width,
    height,
    aspect_ratio,
    orientation,
    device_width,
    device_height,
    device_aspect_ratio,
    resolution,
    color,
    color_index,
    monochrome,
    prefers_color_scheme,
    prefers_reduced_motion,
    prefers_contrast,
    forced_colors,
    scripting,
    webkit_device_pixel_ratio,

    /// Section 2.4.1: a "range" feature (min-/max- prefixes, range context).
    fn isRange(id: FeatureId) bool {
        return switch (id) {
            .unanswered_range,
            .width,
            .height,
            .aspect_ratio,
            .device_width,
            .device_height,
            .device_aspect_ratio,
            .resolution,
            .color,
            .color_index,
            .monochrome,
            .webkit_device_pixel_ratio,
            => true,
            else => false,
        };
    }

    const Category = enum { none, length, ratio, resolution, integer, number, keyword };

    fn category(id: FeatureId) Category {
        return switch (id) {
            .unknown, .unanswered_range => .none,
            .width, .height, .device_width, .device_height => .length,
            .aspect_ratio, .device_aspect_ratio => .ratio,
            .resolution => .resolution,
            .color, .color_index, .monochrome => .integer,
            .webkit_device_pixel_ratio => .number,
            .orientation, .prefers_color_scheme, .prefers_reduced_motion, .prefers_contrast, .forced_colors, .scripting => .keyword,
        };
    }
};

/// How a media feature was written (section 3, <media-feature>).
pub const Form = union(enum) {
    /// `(name)`: evaluated in a boolean context (section 2.4.2).
    boolean,
    /// `(name: value)`, `(min-name: value)`, `(max-name: value)`.
    plain: struct { prefix: Prefix, value: Value },
    /// `(name op value)`, `(value op name)` or `(value op name op value)`:
    /// the operands as written, `left` before the name, `right` after it.
    range: struct {
        left: ?struct { value: Value, op: Op } = null,
        right: ?struct { op: Op, value: Value } = null,
    },

    pub const Prefix = enum { none, min, max };
};

/// A media feature in parentheses.
pub const Feature = struct {
    id: FeatureId,
    /// The name as written, ASCII-lowercased, serialized as an identifier.
    name: []const u8,
    form: Form,
};

/// A <media-condition> term (sections 2.5, 3).
pub const Condition = union(enum) {
    feature: Feature,
    /// <general-enclosed>: its text as written. Evaluates to unknown.
    general_enclosed: []const u8,
    /// `( <media-condition> )`
    group: *const Condition,
    /// `not <media-in-parens>`
    not: *const Condition,
    /// `<media-in-parens> [ and <media-in-parens> ]+`
    all_of: []const Condition,
    /// `<media-in-parens> [ or <media-in-parens> ]+`
    any_of: []const Condition,
};

/// One <media-query> (section 3).
pub const MediaQuery = struct {
    pub const Modifier = enum { none, not, only };

    modifier: Modifier = .none,
    /// The <media-type>, ASCII-lowercased and serialized as an identifier;
    /// null for a query that is a bare <media-condition>.
    media_type: ?[]const u8 = null,
    condition: ?Condition = null,

    /// The replacement for a query that does not parse (section 3.2).
    pub const not_all: MediaQuery = .{ .modifier = .not, .media_type = "all" };

    /// Whether the query is true in `values` (section 2: its type matches and
    /// its condition is true; section 2.2.1: `not` negates the whole query;
    /// section 3.1: unknown is false at the top).
    pub fn matches(self: *const MediaQuery, values: *const MediaValues) bool {
        const type_result: Tri = if (self.media_type) |t| Tri.fromBool(typeMatches(t, values)) else .t;
        const condition_result: Tri = if (self.condition) |*c| evalCondition(c, values) else .t;
        var result = type_result.andThen(condition_result);
        if (self.modifier == .not) result = result.negate();
        return result == .t;
    }
};

/// Section 2.3: `all` matches every device, `screen` a device that is not
/// printing, `print` printed output; the deprecated types and any unknown
/// type match nothing.
fn typeMatches(media_type: []const u8, values: *const MediaValues) bool {
    if (std.mem.eql(u8, media_type, "all")) return true;
    if (std.mem.eql(u8, media_type, "screen")) return values.media_type == .screen;
    if (std.mem.eql(u8, media_type, "print")) return values.media_type == .print;
    return false;
}

// ============================================================================
// Three-valued logic (section 3.1)
// ============================================================================

/// "Media Queries use a three-value logic where terms can be true, false, or
/// unknown": Kleene's.
const Tri = enum {
    f,
    t,
    u,

    fn fromBool(b: bool) Tri {
        return if (b) .t else .f;
    }

    fn negate(a: Tri) Tri {
        return switch (a) {
            .t => .f,
            .f => .t,
            .u => .u,
        };
    }

    /// "True if all are true, false if at least one is false, unknown otherwise."
    fn andThen(a: Tri, b: Tri) Tri {
        if (a == .f or b == .f) return .f;
        if (a == .u or b == .u) return .u;
        return .t;
    }

    /// "False if all are false, true if at least one is true, unknown otherwise."
    fn orElse(a: Tri, b: Tri) Tri {
        if (a == .t or b == .t) return .t;
        if (a == .u or b == .u) return .u;
        return .f;
    }
};

fn evalCondition(c: *const Condition, values: *const MediaValues) Tri {
    switch (c.*) {
        .feature => |*f| return evalFeature(f, values),
        // <general-enclosed>: "The result is unknown."
        .general_enclosed => return .u,
        .group => |child| return evalCondition(child, values),
        // <media-not>: "The negation of unknown is unknown."
        .not => |child| return evalCondition(child, values).negate(),
        .all_of => |items| {
            var result: Tri = .t;
            for (items) |*item| result = result.andThen(evalCondition(item, values));
            return result;
        },
        .any_of => |items| {
            var result: Tri = .f;
            for (items) |*item| result = result.orElse(evalCondition(item, values));
            return result;
        },
    }
}

// ============================================================================
// Evaluating a media feature (sections 2.4, 4-6, 9, 12, appendix A)
// ============================================================================

fn evalFeature(f: *const Feature, values: *const MediaValues) Tri {
    // A feature we hold no fact for, or nobody defined (section 3.2).
    if (f.id.category() == .none) return .u;
    switch (f.form) {
        .boolean => return evalBoolean(f.id, values),
        .plain => |p| {
            // Section 2.4.4: "min-" is ">=", "max-" is "<=" (an exact match
            // without a prefix).
            const op: Op = switch (p.prefix) {
                .none => .eq,
                .min => .ge,
                .max => .le,
            };
            return compare(f.id, op, &p.value, values);
        },
        .range => |r| {
            // Section 2.4.1: only "range" features have a range context.
            if (!f.id.isRange()) return .u;
            var result: Tri = .t;
            // Section 2.4.3: both comparisons must be true. An operand that
            // is not a valid value makes the whole feature unknown.
            if (r.left) |l| {
                const one = compare(f.id, l.op.flip(), &l.value, values);
                if (one == .u) return .u;
                result = result.andThen(one);
            }
            if (r.right) |rt| {
                const one = compare(f.id, rt.op, &rt.value, values);
                if (one == .u) return .u;
                result = result.andThen(one);
            }
            return result;
        },
    }
}

/// Section 2.4.2: "If the feature would be true for any value other than the
/// number 0, a <dimension> with the value 0, the keyword none, or a value
/// explicitly defined by that media feature to evaluate as false in a boolean
/// context, the media feature evaluates to true."
fn evalBoolean(id: FeatureId, values: *const MediaValues) Tri {
    switch (id.category()) {
        .none => return .u,
        .length => return Tri.fromBool(lengthFact(id, values) != 0),
        .ratio => {
            const r = ratioFact(id, values);
            return Tri.fromBool(r != 0 and !std.math.isNan(r));
        },
        .resolution, .number => return Tri.fromBool(values.resolution != 0),
        .integer => return Tri.fromBool(integerFact(id, values) != 0),
        .keyword => {
            // `none` (forced-colors, scripting) and `no-preference`
            // (prefers-reduced-motion, prefers-contrast; sections 12.1, 12.3
            // "evaluates as false in the boolean context") are the false
            // values; orientation and prefers-color-scheme have none.
            const fact = keywordFact(id, values);
            return Tri.fromBool(!(std.mem.eql(u8, fact, "none") or std.mem.eql(u8, fact, "no-preference")));
        },
    }
}

/// `feature op value` for one comparison. Unknown when `value` is not a
/// valid value of the feature (section 3.2).
fn compare(id: FeatureId, op: Op, value: *const Value, values: *const MediaValues) Tri {
    switch (id.category()) {
        .none => return .u,
        .length => {
            const v = lengthToPx(value, values) orelse return .u;
            return Tri.fromBool(relation(op, lengthFact(id, values), v));
        },
        .ratio => {
            // <ratio>: two non-negative numbers; a lone number is n/1.
            const v: f64 = switch (value.*) {
                .ratio => |r| if (r.numerator < 0 or r.denominator < 0) return .u else ratioOf(r.numerator, r.denominator),
                .number => |n| if (n.value < 0) return .u else n.value,
                else => return .u,
            };
            if (std.math.isNan(v)) return .u;
            return Tri.fromBool(relation(op, ratioFact(id, values), v));
        },
        .resolution => {
            // <resolution> | infinite (section 5.1): "infinite must be treated
            // as larger than any possible <resolution>".
            const v: f64 = switch (value.*) {
                .dimension => |d| resolutionToDppx(d.value, d.unit) orelse return .u,
                .ident => |i| if (std.mem.eql(u8, i, "infinite")) std.math.inf(f64) else return .u,
                else => return .u,
            };
            return Tri.fromBool(relation(op, values.resolution, v));
        },
        .integer => {
            // <integer> only: "8.5" and "8.0" are not.
            const v: f64 = switch (value.*) {
                .number => |n| if (n.is_integer) n.value else return .u,
                else => return .u,
            };
            return Tri.fromBool(relation(op, integerFact(id, values), v));
        },
        .number => {
            // -webkit-device-pixel-ratio: a non-negative <number>.
            const v: f64 = switch (value.*) {
                .number => |n| if (n.value < 0) return .u else n.value,
                else => return .u,
            };
            return Tri.fromBool(relation(op, values.resolution, v));
        },
        .keyword => {
            // Discrete: an exact match of one of the feature's keywords.
            if (op != .eq) return .u;
            const ident = switch (value.*) {
                .ident => |i| i,
                else => return .u,
            };
            for (keywordValues(id)) |k| {
                if (std.mem.eql(u8, k, ident)) return Tri.fromBool(std.mem.eql(u8, keywordFact(id, values), k));
            }
            return .u;
        },
    }
}

/// "Number comparisons are exact": `fact op value`.
fn relation(op: Op, fact: f64, value: f64) bool {
    return switch (op) {
        .lt => fact < value,
        .le => fact <= value,
        .gt => fact > value,
        .ge => fact >= value,
        .eq => fact == value,
    };
}

fn lengthFact(id: FeatureId, values: *const MediaValues) f64 {
    return switch (id) {
        .width => values.width,
        .height => values.height,
        .device_width => values.device_width,
        .device_height => values.device_height,
        else => unreachable,
    };
}

fn integerFact(id: FeatureId, values: *const MediaValues) f64 {
    return switch (id) {
        .color => @floatFromInt(values.color_bits),
        .color_index => @floatFromInt(values.color_index),
        .monochrome => @floatFromInt(values.monochrome_bits),
        else => unreachable,
    };
}

/// The ratio of two sizes; a zero height is infinitely wide (0/0 is NaN).
fn ratioOf(numerator: f64, denominator: f64) f64 {
    if (denominator == 0) return if (numerator == 0) std.math.nan(f64) else std.math.inf(f64);
    return numerator / denominator;
}

/// Section 4.3: "the ratio of the value of the width media feature to the
/// value of the height media feature"; device-aspect-ratio likewise (A).
fn ratioFact(id: FeatureId, values: *const MediaValues) f64 {
    return switch (id) {
        .aspect_ratio => ratioOf(values.width, values.height),
        .device_aspect_ratio => ratioOf(values.device_width, values.device_height),
        else => unreachable,
    };
}

/// The keyword the environment has for a discrete feature.
fn keywordFact(id: FeatureId, values: *const MediaValues) []const u8 {
    return switch (id) {
        // Section 4.4: portrait "when the height is greater than or equal to
        // the width".
        .orientation => if (values.height >= values.width) "portrait" else "landscape",
        .prefers_color_scheme => switch (values.prefers_color_scheme) {
            .light => "light",
            .dark => "dark",
        },
        .prefers_reduced_motion => switch (values.prefers_reduced_motion) {
            .no_preference => "no-preference",
            .reduce => "reduce",
        },
        .prefers_contrast => switch (values.prefers_contrast) {
            .no_preference => "no-preference",
            .more => "more",
            .less => "less",
            .custom => "custom",
        },
        .forced_colors => if (values.forced_colors) "active" else "none",
        .scripting => switch (values.scripting) {
            .none => "none",
            .initial_only => "initial-only",
            .enabled => "enabled",
        },
        else => unreachable,
    };
}

/// The value syntax of a discrete feature (sections 4.4, 9.1, 12).
fn keywordValues(id: FeatureId) []const []const u8 {
    return switch (id) {
        .orientation => &.{ "portrait", "landscape" },
        .prefers_color_scheme => &.{ "light", "dark" },
        .prefers_reduced_motion => &.{ "no-preference", "reduce" },
        .prefers_contrast => &.{ "no-preference", "less", "more", "custom" },
        .forced_colors => &.{ "none", "active" },
        .scripting => &.{ "none", "initial-only", "enabled" },
        else => unreachable,
    };
}

/// A <length> in CSS px (section 1.3: relative units are relative to the
/// initial values). A number is a length only when it is zero. Null for
/// anything else - not a length, or a unit this module does not know.
fn lengthToPx(value: *const Value, values: *const MediaValues) ?f64 {
    switch (value.*) {
        .number => |n| return if (n.value == 0) 0 else null,
        .dimension => |d| {
            // CSS Values 4 absolute units, as v * numerator / denominator so
            // that 768pt is exactly 1024px.
            const absolute = [_]struct { []const u8, f64, f64 }{
                .{ "px", 1, 1 },
                .{ "in", 96, 1 },
                .{ "pc", 16, 1 },
                .{ "pt", 96, 72 },
                .{ "cm", 96, 2.54 },
                .{ "mm", 96, 25.4 },
                .{ "q", 96, 101.6 },
            };
            inline for (absolute) |unit| {
                if (std.mem.eql(u8, d.unit, unit[0])) return d.value * unit[1] / unit[2];
            }
            // Font-relative: the initial font-size (ex and ch: half of it).
            if (std.mem.eql(u8, d.unit, "em") or std.mem.eql(u8, d.unit, "rem")) return d.value * values.font_size;
            if (std.mem.eql(u8, d.unit, "ex") or std.mem.eql(u8, d.unit, "ch")) return d.value * values.font_size / 2;
            // Viewport-relative: 1% of the viewport. With no dynamic
            // toolbars the small, large and dynamic viewports are one.
            if (viewportUnit(d.unit)) |kind| {
                const w = values.width;
                const h = values.height;
                const base = switch (kind) {
                    .w => w,
                    .h => h,
                    .min => @min(w, h),
                    .max => @max(w, h),
                };
                return d.value * base / 100;
            }
            // Conditional 5 §7, MQ 5 §1.3: an elementless query has no
            // eligible container and uses the initial horizontal axes.
            const math = @import("math_values.zig");
            if (math.Unit.parse(d.unit)) |unit| switch (unit) {
                .cqw, .cqh, .cqi, .cqb, .cqmin, .cqmax => {
                    const context: math.Context = .{
                        .viewport_width = values.width,
                        .viewport_height = values.height,
                    };
                    return context.resolve(.{ .value = d.value, .unit = unit }).value;
                },
                else => {},
            };
            return null;
        },
        else => return null,
    }
}

/// vw, vh, vi, vb, vmin, vmax and their sv/lv/dv variants (CSS Values 4).
/// Horizontal writing mode: the inline axis is the width.
fn viewportUnit(unit: []const u8) ?enum { w, h, min, max } {
    var rest = unit;
    if (rest.len > 0 and (rest[0] == 'v')) {
        rest = rest[1..];
    } else if (rest.len > 1 and (rest[0] == 's' or rest[0] == 'l' or rest[0] == 'd') and rest[1] == 'v') {
        rest = rest[2..];
    } else return null;
    if (std.mem.eql(u8, rest, "w") or std.mem.eql(u8, rest, "i")) return .w;
    if (std.mem.eql(u8, rest, "h") or std.mem.eql(u8, rest, "b")) return .h;
    if (std.mem.eql(u8, rest, "min")) return .min;
    if (std.mem.eql(u8, rest, "max")) return .max;
    return null;
}

/// A <resolution> in dppx (CSS Values 4: dpi, dpcm, dppx, x).
fn resolutionToDppx(value: f64, unit: []const u8) ?f64 {
    if (std.mem.eql(u8, unit, "dppx") or std.mem.eql(u8, unit, "x")) return value;
    if (std.mem.eql(u8, unit, "dpi")) return value / 96;
    if (std.mem.eql(u8, unit, "dpcm")) return value * 2.54 / 96;
    return null;
}

// ============================================================================
// Parsing (sections 3, 3.2; CSSOM 4.1)
// ============================================================================

/// `SyntaxError` is a hard error inside a term (`(min-width)`, section
/// 2.4.4): the whole query is `not all`, with no <general-enclosed> fallback.
const Error = error{ OutOfMemory, SyntaxError };

/// How deeply parentheses may nest. Deeper is a syntax error (a query is
/// script-controlled text and the parser recurses once per level).
const max_nesting = 128;

/// A feature name: the feature, and the prefix it was written with.
const Name = struct { id: FeatureId, prefix: Form.Prefix };

const feature_table = [_]struct { []const u8, FeatureId }{
    .{ "width", .width },
    .{ "height", .height },
    .{ "aspect-ratio", .aspect_ratio },
    .{ "orientation", .orientation },
    .{ "device-width", .device_width },
    .{ "device-height", .device_height },
    .{ "device-aspect-ratio", .device_aspect_ratio },
    .{ "resolution", .resolution },
    .{ "color", .color },
    .{ "color-index", .color_index },
    .{ "monochrome", .monochrome },
    .{ "prefers-color-scheme", .prefers_color_scheme },
    .{ "prefers-reduced-motion", .prefers_reduced_motion },
    .{ "prefers-contrast", .prefers_contrast },
    .{ "forced-colors", .forced_colors },
    .{ "scripting", .scripting },
    .{ "-webkit-device-pixel-ratio", .webkit_device_pixel_ratio },
    // Range features MQ5 defines that the environment has no fact for:
    // known only so that `(min-...)` in the boolean form is a syntax error.
    .{ "horizontal-viewport-segments", .unanswered_range },
    .{ "vertical-viewport-segments", .unanswered_range },
};

fn lookupFeature(name: []const u8) FeatureId {
    for (feature_table) |entry| {
        if (std.mem.eql(u8, entry[0], name)) return entry[1];
    }
    return .unknown;
}

/// Resolve an ASCII-lowercased feature name (section 2.4.4): "min-"/"max-"
/// before a range feature's name; before a discrete feature's - or an
/// undefined - name it is an unknown feature name.
fn resolveName(name: []const u8) Name {
    // WebKit's prefixed forms of device-pixel-ratio (not "min-" + a name).
    if (std.mem.eql(u8, name, "-webkit-min-device-pixel-ratio")) return .{ .id = .webkit_device_pixel_ratio, .prefix = .min };
    if (std.mem.eql(u8, name, "-webkit-max-device-pixel-ratio")) return .{ .id = .webkit_device_pixel_ratio, .prefix = .max };
    const prefixes = [_]struct { []const u8, Form.Prefix }{ .{ "min-", .min }, .{ "max-", .max } };
    for (prefixes) |p| {
        if (std.mem.startsWith(u8, name, p[0])) {
            const base = lookupFeature(name[p[0].len..]);
            if (base.isRange() and base != .webkit_device_pixel_ratio) return .{ .id = base, .prefix = p[1] };
            return .{ .id = .unknown, .prefix = .none };
        }
    }
    return .{ .id = lookupFeature(name), .prefix = .none };
}

const Parser = struct {
    arena: std.mem.Allocator,
    input: []const u8,
    tokens: []const Token,
    /// For an opening token (left paren, bracket or brace): the index of its
    /// matching closer, or `tokens.len` when end of input closes it
    /// ("consume a simple block"). Undefined for other tokens.
    closer: []const usize,
    /// Whether a token is the closer of some block.
    closer_matched: []const bool,

    fn tt(p: *const Parser, i: usize) tokenizer.TokenType {
        return p.tokens[i].token_type;
    }

    fn isWs(p: *const Parser, i: usize) bool {
        return p.tokens[i].token_type == .whitespace;
    }

    fn isKeyword(p: *const Parser, i: usize, keyword: []const u8) bool {
        return p.tokens[i].token_type == .ident and tokenizer.nameEql(p.tokens[i].value, keyword);
    }

    fn isDelim(p: *const Parser, i: usize, c: u8) bool {
        const t = p.tokens[i];
        return t.token_type == .delim and t.value.len == 1 and t.value[0] == c;
    }

    fn skipWs(p: *const Parser, start: usize, end: usize) usize {
        var i = start;
        while (i < end and p.isWs(i)) i += 1;
        return i;
    }

    /// `end` without trailing whitespace.
    fn trimEnd(p: *const Parser, start: usize, end: usize) usize {
        var e = end;
        while (e > start and p.isWs(e - 1)) e -= 1;
        return e;
    }

    /// Reserved words that are not a <media-type> (section 3).
    fn isReservedWord(p: *const Parser, i: usize) bool {
        const reserved = [_][]const u8{ "only", "not", "and", "or", "layer" };
        for (reserved) |r| {
            if (p.isKeyword(i, r)) return true;
        }
        return false;
    }

    /// The ident at `i` as the spec's token value, ASCII-lowercased, in
    /// serialized-identifier form (its decoded form for every keyword).
    fn identText(p: *const Parser, raw: []const u8) Error![]const u8 {
        const lower = try p.lowerDecoded(raw);
        return serialize_mod.serializeIdentifier(p.arena, lower);
    }

    fn lowerDecoded(p: *const Parser, raw: []const u8) Error![]u8 {
        const decoded = try tokenizer.decode(p.arena, raw);
        for (decoded) |*c| c.* = std.ascii.toLower(c.*);
        return decoded;
    }

    // ------------------------------------------------------------------
    // <media-query-list>
    // ------------------------------------------------------------------

    /// "To parse a <media-query-list> production, parse a comma-separated
    /// list of component values, then parse each entry in the returned list
    /// as a <media-query>" (section 3). Commas inside a block do not
    /// separate (a block is one component value); a stray closing token is a
    /// component value of its own.
    fn parseList(p: *const Parser) error{OutOfMemory}![]const MediaQuery {
        const n = p.tokens.len;
        // "This definition intentionally accepts an empty list."
        if (p.skipWs(0, n) == n) return &.{};

        var queries: std.ArrayList(MediaQuery) = .empty;
        var start: usize = 0;
        var i: usize = 0;
        while (i <= n) {
            if (i == n or p.tt(i) == .comma) {
                // 3.2: a query that does not match the grammar "must be
                // replaced by not all"; the damage stops at the comma.
                const query = p.parseMediaQuery(start, i) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.SyntaxError => null,
                };
                try queries.append(p.arena, query orelse MediaQuery.not_all);
                start = i + 1;
                i += 1;
                continue;
            }
            switch (p.tt(i)) {
                .left_paren, .left_bracket, .left_brace => i = if (p.closer[i] >= n) n else p.closer[i] + 1,
                else => i += 1,
            }
        }
        return queries.items;
    }

    // ------------------------------------------------------------------
    // <media-query>
    // ------------------------------------------------------------------

    /// <media-query> = <media-condition>
    ///               | [ not | only ]? <media-type> [ and <media-condition-without-or> ]?
    /// Null: the entry does not match the grammar.
    fn parseMediaQuery(p: *const Parser, start: usize, end_in: usize) Error!?MediaQuery {
        var i = p.skipWs(start, end_in);
        const end = p.trimEnd(i, end_in);
        if (i >= end) return null;

        var query: MediaQuery = .{};
        switch (p.tt(i)) {
            .left_paren, .function => {},
            .ident => {
                const is_not = p.isKeyword(i, "not");
                const is_only = p.isKeyword(i, "only");
                if (is_not or is_only) {
                    const j = p.skipWs(i + 1, end);
                    if (j < end and p.tt(j) == .ident and !p.isReservedWord(j)) {
                        query.modifier = if (is_not) .not else .only;
                        i = j;
                    } else if (is_not and j < end and (p.tt(j) == .left_paren or p.tt(j) == .function)) {
                        // `not (...)`: a <media-not>, below.
                        return p.parseWholeCondition(i, end, true);
                    } else return null;
                } else if (p.isReservedWord(i)) {
                    return null;
                }
                // <media-type> [ and <media-condition-without-or> ]?
                query.media_type = try p.identText(p.tokens[i].value);
                i = p.skipWs(i + 1, end);
                if (i == end) return query;
                if (!p.isKeyword(i, "and")) return null;
                i = p.skipWs(i + 1, end);
                if (i >= end) return null;
                const condition = (try p.parseWholeCondition(i, end, false)) orelse return null;
                query.condition = condition.condition;
                return query;
            },
            else => return null,
        }
        return p.parseWholeCondition(i, end, true);
    }

    /// A bare <media-condition> (`allow_or`) running exactly to `end`, as a
    /// query.
    fn parseWholeCondition(p: *const Parser, start: usize, end: usize, allow_or: bool) Error!?MediaQuery {
        var i = start;
        const condition = (try p.parseCondition(&i, end, allow_or, 0)) orelse return null;
        if (p.skipWs(i, end) != end) return null;
        return .{ .condition = condition };
    }

    // ------------------------------------------------------------------
    // <media-condition>
    // ------------------------------------------------------------------

    /// <media-condition> = <media-not> | <media-in-parens> [ <media-and>* | <media-or>* ]
    /// <media-condition-without-or> = <media-not> | <media-in-parens> <media-and>*
    /// Stops after the longest match; the caller checks what is left.
    /// A mixture of `and` and `or` is not a condition.
    fn parseCondition(p: *const Parser, i: *usize, end: usize, allow_or: bool, depth: u32) Error!?Condition {
        i.* = p.skipWs(i.*, end);
        if (i.* >= end) return null;
        if (p.isKeyword(i.*, "not")) {
            // <media-not> = not <media-in-parens>
            i.* = p.skipWs(i.* + 1, end);
            const child = (try p.parseInParens(i, end, depth)) orelse return null;
            return .{ .not = try p.box(child) };
        }
        const first = (try p.parseInParens(i, end, depth)) orelse return null;

        var items: std.ArrayList(Condition) = .empty;
        var is_and = false;
        while (true) {
            const j = p.skipWs(i.*, end);
            if (j >= end) break;
            const next_and = p.isKeyword(j, "and");
            const next_or = p.isKeyword(j, "or");
            if (!next_and and !(next_or and allow_or)) break;
            if (items.items.len == 0) {
                is_and = next_and;
                try items.append(p.arena, first);
            } else if (is_and != next_and) {
                // `(a) and (b) or (c)`: not a media condition.
                return null;
            }
            i.* = p.skipWs(j + 1, end);
            const term = (try p.parseInParens(i, end, depth)) orelse return null;
            try items.append(p.arena, term);
        }
        if (items.items.len == 0) return first;
        return if (is_and) .{ .all_of = items.items } else .{ .any_of = items.items };
    }

    fn box(p: *const Parser, c: Condition) Error!*const Condition {
        const slot = try p.arena.create(Condition);
        slot.* = c;
        return slot;
    }

    /// <media-in-parens> = ( <media-condition> ) | ( <media-feature> ) | <general-enclosed>
    /// "The <general-enclosed> branch must only be chosen if the input does
    /// not match either of the preceding branches." Null when the term does
    /// not exist or is a syntax error (a `(min-width)` in the boolean form,
    /// a bad token).
    fn parseInParens(p: *const Parser, i: *usize, end: usize, depth: u32) Error!?Condition {
        if (i.* >= end) return null;
        const open = i.*;
        switch (p.tt(open)) {
            .left_paren => {
                if (depth >= max_nesting) return error.SyntaxError;
                const close = p.closer[open];
                const inner_start = open + 1;
                const inner_end = @min(close, p.tokens.len);
                i.* = @min(close + 1, p.tokens.len);

                // ( <media-condition> )
                {
                    var k = inner_start;
                    if (try p.parseCondition(&k, inner_end, true, depth + 1)) |inner| {
                        if (p.skipWs(k, inner_end) == inner_end) return .{ .group = try p.box(inner) };
                    }
                }
                // ( <media-feature> )
                switch (try p.parseFeature(inner_start, inner_end)) {
                    .feature => |f| return .{ .feature = f },
                    .none => {},
                }
                return p.generalEnclosed(open, inner_start, inner_end, close);
            },
            .function => {
                // The function token does not carry its `(`: the next token.
                if (open + 1 >= p.tokens.len or p.tt(open + 1) != .left_paren) return null;
                const close = p.closer[open + 1];
                i.* = @min(close + 1, p.tokens.len);
                return p.generalEnclosed(open, open + 2, @min(close, p.tokens.len), close);
            },
            else => return null,
        }
    }

    /// <general-enclosed> = [ <function-token> <any-value>? ) ] | [ ( <any-value>? ) ]
    /// Null when the contents are not an <any-value>.
    fn generalEnclosed(p: *const Parser, first: usize, inner_start: usize, inner_end: usize, close: usize) Error!?Condition {
        if (!p.isAnyValue(inner_start, inner_end)) return null;
        const text_start = @intFromPtr(p.tokens[first].value.ptr) - @intFromPtr(p.input.ptr);
        var text_end: usize = p.input.len;
        var closed = false;
        if (close < p.tokens.len) {
            text_end = @intFromPtr(p.tokens[close].value.ptr) - @intFromPtr(p.input.ptr) + p.tokens[close].value.len;
            closed = true;
        }
        const raw = p.input[text_start..text_end];
        const text = if (closed) try p.arena.dupe(u8, raw) else try std.mem.concat(p.arena, u8, &.{ raw, ")" });
        return .{ .general_enclosed = text };
    }

    /// <any-value>: "one or more tokens of any type, except <bad-string-token>,
    /// <bad-url-token>, unmatched <)-token>, <]-token>, or <}-token>." A
    /// closer is matched when some block ends at it (`closer_matched`).
    fn isAnyValue(p: *const Parser, start: usize, end: usize) bool {
        for (start..end) |i| {
            switch (p.tt(i)) {
                .bad_string, .bad_url => return false,
                .right_paren, .right_bracket, .right_brace => if (!p.closer_matched[i]) return false,
                else => {},
            }
        }
        return true;
    }

    // ------------------------------------------------------------------
    // <media-feature>
    // ------------------------------------------------------------------

    const FeatureResult = union(enum) {
        feature: Feature,
        /// Not a <media-feature>: <general-enclosed> then.
        none,
    };

    /// <media-feature> = [ <mf-plain> | <mf-boolean> | <mf-range> ], the
    /// tokens between the parentheses.
    fn parseFeature(p: *const Parser, start: usize, end_in: usize) Error!FeatureResult {
        const first = p.skipWs(start, end_in);
        const end = p.trimEnd(first, end_in);
        if (first >= end) return .none;

        // <mf-boolean> = <mf-name>; <mf-plain> = <mf-name> : <mf-value>
        if (p.tt(first) == .ident) {
            var j = p.skipWs(first + 1, end);
            if (j == end) {
                // Section 2.4.4: "Attempting to evaluate a min/max prefixed
                // media feature in a boolean context is invalid and a syntax
                // error."
                const named = try p.featureName(first);
                if (named.resolved.id != .unknown and named.resolved.prefix != .none) return error.SyntaxError;
                return .{ .feature = .{ .id = named.resolved.id, .name = named.text, .form = .boolean } };
            }
            if (p.tt(j) == .colon) {
                j = p.skipWs(j + 1, end);
                const value = (try p.parseValue(&j, end)) orelse return .none;
                if (p.skipWs(j, end) != end) return .none;
                const named = try p.featureName(first);
                return .{ .feature = .{ .id = named.resolved.id, .name = named.text, .form = .{ .plain = .{ .prefix = named.resolved.prefix, .value = value } } } };
            }
        }

        // <mf-range>: V0 op V1 [ op V2 ]
        var i = first;
        const v0 = (try p.parseOperand(&i, end)) orelse return .none;
        i = p.skipWs(i, end);
        const op1 = p.parseOp(&i, end) orelse return .none;
        i = p.skipWs(i, end);
        const v1 = (try p.parseOperand(&i, end)) orelse return .none;
        i = p.skipWs(i, end);
        if (i == end) {
            // `name op value` (the name first when both are idents) or
            // `value op name`.
            if (v0.name_index != null) {
                return p.rangeFeature(v0.name_index.?, .{ .right = .{ .op = op1, .value = v1.value } });
            } else if (v1.name_index != null) {
                return p.rangeFeature(v1.name_index.?, .{ .left = .{ .value = v0.value, .op = op1 } });
            }
            return .none;
        }
        const op2 = p.parseOp(&i, end) orelse return .none;
        i = p.skipWs(i, end);
        const v2 = (try p.parseOperand(&i, end)) orelse return .none;
        if (p.skipWs(i, end) != end) return .none;
        // <mf-value> <mf-lt> <mf-name> <mf-lt> <mf-value> or the same with
        // <mf-gt>: never `=`, never mixed.
        const lt1 = op1 == .lt or op1 == .le;
        const lt2 = op2 == .lt or op2 == .le;
        const gt1 = op1 == .gt or op1 == .ge;
        const gt2 = op2 == .gt or op2 == .ge;
        if (!((lt1 and lt2) or (gt1 and gt2))) return .none;
        const name_index = v1.name_index orelse return .none;
        return p.rangeFeature(name_index, .{ .left = .{ .value = v0.value, .op = op1 }, .right = .{ .op = op2, .value = v2.value } });
    }

    fn rangeFeature(p: *const Parser, name_index: usize, form: @FieldType(Form, "range")) Error!FeatureResult {
        const named = try p.featureName(name_index);
        // The range context takes the plain name only: "min-width > 5px"
        // names no feature.
        const id: FeatureId = if (named.resolved.prefix == .none) named.resolved.id else .unknown;
        return .{ .feature = .{ .id = id, .name = named.text, .form = .{ .range = form } } };
    }

    const NamedFeature = struct { resolved: Name, text: []const u8 };

    fn featureName(p: *const Parser, index: usize) Error!NamedFeature {
        const lower = try p.lowerDecoded(p.tokens[index].value);
        return .{
            .resolved = resolveName(lower),
            .text = try serialize_mod.serializeIdentifier(p.arena, lower),
        };
    }

    /// <mf-comparison> = <mf-lt> | <mf-gt> | <mf-eq>: "No whitespace is
    /// allowed between the < or > <delim-token>s and the following =."
    fn parseOp(p: *const Parser, i: *usize, end: usize) ?Op {
        if (i.* >= end) return null;
        if (p.isDelim(i.*, '=')) {
            i.* += 1;
            return .eq;
        }
        const lt = p.isDelim(i.*, '<');
        if (!lt and !p.isDelim(i.*, '>')) return null;
        const eq = i.* + 1 < end and p.isDelim(i.* + 1, '=');
        i.* += if (eq) 2 else 1;
        return if (lt) (if (eq) Op.le else Op.lt) else (if (eq) Op.ge else Op.gt);
    }

    const Operand = struct {
        value: Value,
        /// Token index when the operand is an ident (it may be the name).
        name_index: ?usize,
    };

    fn parseOperand(p: *const Parser, i: *usize, end: usize) Error!?Operand {
        const index = i.*;
        const value = (try p.parseValue(i, end)) orelse return null;
        return .{ .value = value, .name_index = if (p.tt(index) == .ident) index else null };
    }

    /// <mf-value> = <number> | <dimension> | <ident> | <ratio>
    /// <ratio> = <number [0,inf]> [ / <number [0,inf]> ]? (a negative one is
    /// parsed here and found invalid when evaluated: unknown either way).
    fn parseValue(p: *const Parser, i: *usize, end: usize) Error!?Value {
        if (i.* >= end) return null;
        const t = p.tokens[i.*];
        switch (t.token_type) {
            .number => {
                const number = t.numeric_value orelse return null;
                var j = p.skipWs(i.* + 1, end);
                if (j < end and p.isDelim(j, '/')) {
                    j = p.skipWs(j + 1, end);
                    if (j < end and p.tt(j) == .number) {
                        const denominator = p.tokens[j].numeric_value orelse return null;
                        i.* = j + 1;
                        return .{ .ratio = .{ .numerator = number, .denominator = denominator } };
                    }
                    return null;
                }
                i.* += 1;
                return .{ .number = .{ .value = number, .is_integer = t.is_integer } };
            },
            .dimension => {
                const number = t.numeric_value orelse return null;
                const unit = t.unit orelse return null;
                i.* += 1;
                return .{ .dimension = .{ .value = number, .unit = try p.identText(unit) } };
            },
            .ident => {
                i.* += 1;
                return .{ .ident = try p.identText(t.value) };
            },
            else => return null,
        }
    }
};

/// An owned media query list (CSSOM 4.1 "parse a media query list").
pub const MediaQueryList = struct {
    arena: std.heap.ArenaAllocator,
    queries: []const MediaQuery,

    /// "Parse a media query list" for `text`: each comma-separated entry that
    /// does not match the grammar is `not all` (section 3.2). Free with
    /// `deinit`.
    pub fn parse(allocator: std.mem.Allocator, text: []const u8) error{OutOfMemory}!MediaQueryList {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        // Tokens and block matches are scratch; the arena holds the result.
        var tokens: std.ArrayList(Token) = .empty;
        defer tokens.deinit(allocator);
        var tz = tokenizer.Tokenizer.init(text);
        while (true) {
            const token = tz.next();
            if (token.token_type == .eof) break;
            try tokens.append(allocator, token);
        }

        // "Consume a simple block": a block ends at the closer of its own
        // kind; other closers inside it are ordinary tokens, and end of
        // input closes whatever is open.
        const closer = try allocator.alloc(usize, tokens.items.len);
        defer allocator.free(closer);
        const closer_matched = try allocator.alloc(bool, tokens.items.len);
        defer allocator.free(closer_matched);
        @memset(closer_matched, false);
        var open_stack: std.ArrayList(usize) = .empty;
        defer open_stack.deinit(allocator);
        for (tokens.items, 0..) |token, i| {
            switch (token.token_type) {
                .left_paren, .left_bracket, .left_brace => {
                    closer[i] = tokens.items.len;
                    try open_stack.append(allocator, i);
                },
                .right_paren, .right_bracket, .right_brace => {
                    if (open_stack.items.len == 0) continue;
                    const top = open_stack.items[open_stack.items.len - 1];
                    const matches_top = switch (tokens.items[top].token_type) {
                        .left_paren => token.token_type == .right_paren,
                        .left_bracket => token.token_type == .right_bracket,
                        else => token.token_type == .right_brace,
                    };
                    if (matches_top) {
                        closer[top] = i;
                        closer_matched[i] = true;
                        _ = open_stack.pop();
                    }
                },
                else => {},
            }
        }

        const parser: Parser = .{
            .arena = arena.allocator(),
            .input = text,
            .tokens = tokens.items,
            .closer = closer,
            .closer_matched = closer_matched,
        };
        const queries = try parser.parseList();
        return .{ .arena = arena, .queries = queries };
    }

    pub fn deinit(self: *MediaQueryList) void {
        self.arena.deinit();
        self.* = undefined;
    }

    /// Section 2.1: "A media query list is true if any of its component media
    /// queries are true"; an empty one evaluates to true. Unknown is false
    /// (section 3.1).
    pub fn matches(self: *const MediaQueryList, values: *const MediaValues) bool {
        if (self.queries.len == 0) return true;
        for (self.queries) |*query| {
            if (query.matches(values)) return true;
        }
        return false;
    }

    /// Parse `text` and evaluate it once.
    pub fn matchesQuery(allocator: std.mem.Allocator, text: []const u8, values: *const MediaValues) error{OutOfMemory}!bool {
        var list = try parse(allocator, text);
        defer list.deinit();
        return list.matches(values);
    }

    // ------------------------------------------------------------------
    // Serialization (CSSOM 4.2)
    // ------------------------------------------------------------------

    /// CSSOM 4.2 "serialize a media query list": the queries in order,
    /// separated by ", "; the empty list is the empty string. A query is
    /// "not "/"only ", the type, " and ", then its condition (the type `all`
    /// is left out of a query that has a condition and is not negated). The
    /// range syntax is written as it was given; names and keywords are
    /// ASCII-lowercased.
    pub fn serialize(self: *const MediaQueryList, w: *std.Io.Writer) std.Io.Writer.Error!void {
        for (self.queries, 0..) |*query, i| {
            if (i != 0) try w.writeAll(", ");
            try serializeQuery(query, w);
        }
    }

    /// CSSOM 4.2 "serialize a media query" for the query at `index`.
    pub fn serializeAt(self: *const MediaQueryList, index: usize, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try serializeQuery(&self.queries[index], w);
    }
};

fn serializeQuery(q: *const MediaQuery, w: *std.Io.Writer) std.Io.Writer.Error!void {
    switch (q.modifier) {
        .none => {},
        .not => try w.writeAll("not "),
        .only => try w.writeAll("only "),
    }
    if (q.media_type) |t| {
        const omit_type = q.condition != null and q.modifier == .none and std.mem.eql(u8, t, "all");
        if (!omit_type) {
            try w.writeAll(t);
            if (q.condition != null) try w.writeAll(" and ");
        }
    }
    if (q.condition) |*c| try serializeCondition(c, w);
}

fn serializeCondition(c: *const Condition, w: *std.Io.Writer) std.Io.Writer.Error!void {
    switch (c.*) {
        .feature => |*f| try serializeFeature(f, w),
        .general_enclosed => |text| try w.writeAll(text),
        .group => |inner| {
            try w.writeByte('(');
            try serializeCondition(inner, w);
            try w.writeByte(')');
        },
        .not => |inner| {
            try w.writeAll("not ");
            try serializeCondition(inner, w);
        },
        .all_of => |items| try serializeJoined(items, " and ", w),
        .any_of => |items| try serializeJoined(items, " or ", w),
    }
}

fn serializeJoined(items: []const Condition, separator: []const u8, w: *std.Io.Writer) std.Io.Writer.Error!void {
    for (items, 0..) |*item, i| {
        if (i != 0) try w.writeAll(separator);
        try serializeCondition(item, w);
    }
}

fn serializeFeature(f: *const Feature, w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeByte('(');
    switch (f.form) {
        .boolean => try w.writeAll(f.name),
        .plain => |p| {
            try w.writeAll(f.name);
            try w.writeAll(": ");
            try serializeValue(&p.value, w);
        },
        .range => |r| {
            if (r.left) |l| {
                try serializeValue(&l.value, w);
                try w.print(" {s} ", .{l.op.text()});
            }
            try w.writeAll(f.name);
            if (r.right) |rt| {
                try w.print(" {s} ", .{rt.op.text()});
                try serializeValue(&rt.value, w);
            }
        },
    }
    try w.writeByte(')');
}

fn serializeValue(v: *const Value, w: *std.Io.Writer) std.Io.Writer.Error!void {
    switch (v.*) {
        .number => |n| try w.print("{d}", .{n.value}),
        .dimension => |d| try w.print("{d}{s}", .{ d.value, d.unit }),
        .ident => |i| try w.writeAll(i),
        .ratio => |r| try w.print("{d} / {d}", .{ r.numerator, r.denominator }),
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

fn matchesWith(text: []const u8, values: MediaValues) !bool {
    var list = try MediaQueryList.parse(testing.allocator, text);
    defer list.deinit();
    return list.matches(&values);
}

fn expectMatch(text: []const u8, values: MediaValues, expected: bool) !void {
    const got = try matchesWith(text, values);
    if (got != expected) {
        std.debug.print("media query \"{s}\": expected {}, got {}\n", .{ text, expected, got });
        return error.TestExpectedEqual;
    }
}

fn expectT(text: []const u8) !void {
    try expectMatch(text, .{}, true);
}

fn expectF(text: []const u8) !void {
    try expectMatch(text, .{}, false);
}

fn expectSerialized(text: []const u8, expected: []const u8) !void {
    var list = try MediaQueryList.parse(testing.allocator, text);
    defer list.deinit();
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try list.serialize(&aw.writer);
    try testing.expectEqualStrings(expected, aw.written());
}

test "MediaValues defaults and eql" {
    const a: MediaValues = .{};
    try testing.expectEqual(@as(f64, 1024), a.width);
    try testing.expectEqual(@as(f64, 768), a.height);
    try testing.expectEqual(@as(f64, 1920), a.device_width);
    try testing.expectEqual(@as(f64, 1080), a.device_height);
    try testing.expectEqual(@as(f64, 1), a.resolution);
    try testing.expectEqual(@as(u32, 8), a.color_bits);
    try testing.expectEqual(@as(u32, 0), a.color_index);
    try testing.expectEqual(@as(u32, 0), a.monochrome_bits);
    try testing.expectEqual(@as(f64, 16), a.font_size);
    try testing.expect(a.media_type == .screen);
    try testing.expect(a.scripting == .enabled);
    try testing.expect(MediaValues.eql(a, .{}));
    var b = a;
    b.width = 1025;
    try testing.expect(!MediaValues.eql(a, b));
    b = a;
    b.prefers_color_scheme = .dark;
    try testing.expect(!MediaValues.eql(a, b));
}

test "an empty media query list matches (section 2.1)" {
    try expectT("");
    try expectT("   ");
    try expectT("/* nothing */");
    try expectSerialized("", "");
    var list = try MediaQueryList.parse(testing.allocator, " ");
    defer list.deinit();
    try testing.expectEqual(@as(usize, 0), list.queries.len);
}

test "media types (section 2.3)" {
    try expectT("all");
    try expectT("screen");
    try expectF("print");
    try expectMatch("print", .{ .media_type = .print }, true);
    try expectMatch("screen", .{ .media_type = .print }, false);
    try expectMatch("all", .{ .media_type = .print }, true);
    // ASCII case-insensitive.
    try expectT("SCREEN");
    try expectT("Screen");
    try expectMatch("PRINT", .{ .media_type = .print }, true);
    // The deprecated types are valid and match nothing.
    for ([_][]const u8{ "tty", "tv", "projection", "handheld", "braille", "embossed", "aural", "speech" }) |t| {
        try expectF(t);
        try expectMatch(t, .{ .media_type = .print }, false);
        // ... valid: negating one is true, not an error.
        var buf: [32]u8 = undefined;
        const negated = try std.fmt.bufPrint(&buf, "not {s}", .{t});
        try expectT(negated);
        try expectSerialized(negated, negated);
    }
    // An unknown type is valid and does not match (section 3.2).
    try expectF("unknown");
    try expectT("not unknown");
    try expectSerialized("unknown", "unknown");
    // Escapes name the same type.
    try expectT("\\73 creen");
}

test "the reserved keywords are not media types (section 3)" {
    for ([_][]const u8{ "only", "not", "and", "or", "layer" }) |t| {
        try expectF(t);
        try expectSerialized(t, "not all");
    }
    try expectSerialized("or and (color)", "not all");
    try expectF("or and (color)");
    try expectSerialized("not and", "not all");
    try expectSerialized("only only", "not all");
    try expectSerialized("not not screen", "not all");
    try expectSerialized("only", "not all");
    try expectSerialized("only (color)", "not all");
}

test "not and only (sections 2.2.1, 2.2.2)" {
    try expectF("not all");
    try expectT("not print");
    try expectF("not screen");
    try expectT("only screen");
    try expectF("only print");
    try expectF("not screen and (color)");
    try expectT("not print and (color)");
    try expectT("only screen and (color)");
    try expectT("NOT PRINT");
    try expectT("ONLY SCREEN AND (COLOR)");
}

test "media features combined with a type (section 2)" {
    try expectT("screen and (color)");
    try expectF("print and (color)");
    try expectT("all and (color)");
    try expectT("screen and (color) and (min-width: 600px)");
    try expectF("screen and (color) and (min-width: 2000px)");
    try expectT("screen and not (min-width: 2000px)");
    // <media-condition-without-or>: no `or` after a type.
    try expectSerialized("screen and (color) or (width)", "not all");
    try expectSerialized("screen and", "not all");
    try expectSerialized("screen (color)", "not all");
    try expectSerialized("screen and or (color)", "not all");
    // A condition alone matches on every media type.
    try expectMatch("(color)", .{ .media_type = .print }, true);
}

test "width and height: plain, min/max, range forms (sections 4.1, 4.2, 2.4.3, 2.4.4)" {
    try expectT("(width: 1024px)");
    try expectF("(width: 1023px)");
    try expectF("(width: 1025px)");
    try expectT("(min-width: 1024px)");
    try expectT("(min-width: 1000px)");
    try expectF("(min-width: 1025px)");
    try expectT("(max-width: 1024px)");
    try expectF("(max-width: 1023px)");
    try expectT("(height: 768px)");
    try expectT("(min-height: 768px)");
    try expectF("(min-height: 769px)");
    try expectT("(max-height: 768px)");
    try expectT("(width >= 1024px)");
    try expectF("(width > 1024px)");
    try expectT("(width <= 1024px)");
    try expectF("(width < 1024px)");
    try expectT("(width = 1024px)");
    try expectT("(width>=1024px)");
    try expectT("(width>1000px)");
    try expectT("(1000px < width)");
    try expectF("(1024px < width)");
    try expectT("(1024px <= width)");
    try expectT("(2000px > width)");
    try expectT("(1024px = width)");
    try expectT("(1000px < width < 1100px)");
    try expectF("(1024px < width < 1100px)");
    try expectT("(1024px <= width <= 1024px)");
    try expectT("(1100px > width > 1000px)");
    try expectT("(1100px >= width >= 1024px)");
    try expectF("(1100px > width > 1024px)");
    try expectT("(700px <= height <= 800px)");
    try expectT("(width: 1024.0px)");
    try expectT("(width: 1.024e3px)");
    // The feature is read from the environment.
    try expectMatch("(width: 500px)", .{ .width = 500 }, true);
    try expectMatch("(min-width: 500px) and (max-width: 600px)", .{ .width = 550 }, true);
    try expectMatch("(min-width: 500px) and (max-width: 600px)", .{ .width = 650 }, false);
    // Fractional viewports (section 2.4.4).
    try expectMatch("(width > 320px)", .{ .width = 320.5 }, true);
    try expectMatch("(max-width: 320px)", .{ .width = 320.5 }, false);
    try expectMatch("(min-width: 320.01px)", .{ .width = 320.5 }, true);
}

test "length units (section 1.3)" {
    try expectT("(width: 1024px)");
    try expectT("(width: 64em)");
    try expectT("(width: 64rem)");
    try expectT("(width: 128ex)");
    try expectT("(width: 128ch)");
    try expectMatch("(width: 32em)", .{ .width = 640, .font_size = 20 }, true);
    try expectT("(width: 100vw)");
    try expectT("(width: 50vw) or (width: 100vw)");
    try expectT("(height: 100vh)");
    try expectT("(height: 100vmin)");
    try expectT("(width: 100vmax)");
    try expectT("(height: 50vh) or (height: 100vh)");
    try expectF("(width: 10in)");
    try expectT("(min-width: 10in)");
    try expectT("(width: 768pt)");
    try expectT("(width: 64pc)");
    try expectT("(min-width: 20cm)");
    try expectF("(min-width: 30cm)");
    try expectT("(min-width: 200mm)");
    try expectF("(min-width: 300mm)");
    try expectT("(min-width: 800q)");
    try expectF("(min-width: 1200q)");
    try expectT("(width: 1024PX)");
    try expectT("(width: 64EM)");
    // A zero needs no unit.
    try expectT("(min-width: 0)");
    try expectF("(max-width: 0)");
    try expectT("(min-width: 0px)");
    // A non-zero number is not a length, nor is an unknown unit: unknown.
    try expectF("(width: 1024)");
    try expectF("(min-width: 600)");
    try expectF("(width: 5foo)");
    try expectF("not (width: 5foo)");
    try expectF("not (width: 1024)");
    try expectF("(width: 50%)");
    try expectF("(width: auto)");
}

test "negative values: width, height, resolution are false in the negative range (section 2.4.3)" {
    // The three examples of the specification: a green background.
    try expectT("not (width <= -100px)");
    try expectT("(height > -100px)");
    try expectT("not (resolution: -300dpi)");
    try expectT("(width > -200px)");
    try expectF("(width <= -100px)");
    try expectF("(width < -100px)");
    try expectF("(width: -1px)");
    try expectF("(min-width: -1px) and (max-width: -1px)");
    try expectT("(min-width: -1px)");
    try expectF("(max-width: -1px)");
    try expectT("(color > -1)");
    try expectF("(color: -8)");
    try expectT("(monochrome > -1)");
    try expectT("(resolution > -1dppx)");
    try expectF("(resolution <= -1dppx)");
    try expectT("(device-width >= -5px)");
}

test "aspect-ratio and device-aspect-ratio (sections 4.3, A)" {
    // 1024 x 768 is 4:3.
    try expectT("(aspect-ratio: 4/3)");
    try expectT("(aspect-ratio: 4 / 3)");
    try expectT("(aspect-ratio: 8/6)");
    try expectT("(aspect-ratio: 4/ 3)");
    try expectF("(aspect-ratio: 16/9)");
    try expectT("(min-aspect-ratio: 1)");
    try expectT("(min-aspect-ratio: 4/3)");
    try expectF("(min-aspect-ratio: 16/9)");
    try expectT("(max-aspect-ratio: 16/9)");
    try expectF("(max-aspect-ratio: 5/4)");
    try expectT("(aspect-ratio > 1)");
    try expectT("(aspect-ratio >= 4/3)");
    try expectF("(aspect-ratio > 4/3)");
    try expectT("(1 < aspect-ratio < 16/9)");
    try expectT("(aspect-ratio: 1.3333333333333333)");
    // A single number is n/1.
    try expectF("(aspect-ratio: 1)");
    try expectMatch("(aspect-ratio: 1)", .{ .width = 500, .height = 500 }, true);
    try expectMatch("(aspect-ratio: 16/9)", .{ .width = 1280, .height = 720 }, true);
    try expectMatch("(aspect-ratio: 32/18)", .{ .width = 1280, .height = 720 }, true);
    // Not a ratio, or not a valid one: unknown.
    try expectF("(aspect-ratio: 5px)");
    try expectF("(aspect-ratio: wide)");
    try expectF("not (aspect-ratio: -1/2)");
    try expectF("not (aspect-ratio: 1/2/3)");
    // Boolean context.
    try expectT("(aspect-ratio)");
    // device-aspect-ratio is 1920/1080.
    try expectT("(device-aspect-ratio: 16/9)");
    try expectT("(device-aspect-ratio: 1920/1080)");
    try expectF("(device-aspect-ratio: 4/3)");
    try expectT("(min-device-aspect-ratio: 16/10)");
    try expectF("(max-device-aspect-ratio: 16/10)");
}

test "orientation (section 4.4)" {
    try expectT("(orientation)");
    try expectT("(orientation: landscape)");
    try expectF("(orientation: portrait)");
    try expectT("(ORIENTATION: LANDSCAPE)");
    try expectMatch("(orientation: portrait)", .{ .width = 500, .height = 800 }, true);
    try expectMatch("(orientation: landscape)", .{ .width = 500, .height = 800 }, false);
    // "portrait when the height is greater than or equal to the width".
    try expectMatch("(orientation: portrait)", .{ .width = 600, .height = 600 }, true);
    try expectMatch("(orientation: landscape)", .{ .width = 600, .height = 600 }, false);
    // Discrete: no prefixes (an unknown feature name), no range context, no
    // other values.
    try expectF("(min-orientation: portrait)");
    try expectF("not (min-orientation: portrait)");
    try expectF("(max-orientation: landscape)");
    try expectF("(orientation > portrait)");
    try expectF("(orientation: 5)");
    try expectF("not (orientation: square)");
}

test "device-width and device-height (appendix A)" {
    try expectT("(device-width: 1920px)");
    try expectT("(device-height: 1080px)");
    try expectT("(min-device-width: 1920px)");
    try expectF("(min-device-width: 1921px)");
    try expectT("(max-device-height: 1080px)");
    try expectF("(max-device-height: 1079px)");
    try expectT("(device-width > 1000px)");
    try expectT("(1000px < device-height < 1100px)");
    try expectMatch("(device-width: 320px)", .{ .device_width = 320 }, true);
}

test "resolution (section 5.1)" {
    try expectT("(resolution: 1dppx)");
    try expectT("(resolution: 1x)");
    try expectT("(resolution: 96dpi)");
    try expectF("(resolution: 72dpi)");
    try expectT("(min-resolution: 1dppx)");
    try expectF("(min-resolution: 2dppx)");
    try expectT("(max-resolution: 2dppx)");
    try expectF("(resolution >= 2dppx)");
    try expectMatch("(resolution >= 2dppx)", .{ .resolution = 2 }, true);
    try expectMatch("(min-resolution: 192dpi)", .{ .resolution = 2 }, true);
    try expectMatch("(resolution: 2x)", .{ .resolution = 2 }, true);
    try expectMatch("(resolution: 1.5dppx)", .{ .resolution = 1.5 }, true);
    try expectT("(min-resolution: 30dpcm)");
    try expectF("(min-resolution: 40dpcm)");
    try expectT("(max-resolution: 40dpcm)");
    try expectT("(1dppx <= resolution < 2dppx)");
    // `infinite` is larger than any resolution.
    try expectF("(resolution: infinite)");
    try expectT("(resolution < infinite)");
    try expectF("(resolution > 1000dpi)");
    try expectF("(min-resolution: infinite)");
    try expectT("(max-resolution: infinite)");
    try expectT("(resolution)");
    // A bare number is not a resolution.
    try expectF("(resolution: 1)");
    try expectF("not (resolution: 1)");
    try expectF("(resolution: 1px)");
    try expectF("(resolution: high)");
}

test "-webkit-device-pixel-ratio" {
    try expectT("(-webkit-device-pixel-ratio: 1)");
    try expectF("(-webkit-device-pixel-ratio: 2)");
    try expectT("(-webkit-min-device-pixel-ratio: 1)");
    try expectF("(-webkit-min-device-pixel-ratio: 1.5)");
    try expectT("(-webkit-max-device-pixel-ratio: 2)");
    try expectF("(-webkit-max-device-pixel-ratio: 0.5)");
    try expectMatch("(-webkit-min-device-pixel-ratio: 1.5)", .{ .resolution = 2 }, true);
    try expectMatch("(-webkit-device-pixel-ratio: 1.25)", .{ .resolution = 1.25 }, true);
    try expectT("(-webkit-device-pixel-ratio > 0.5)");
    try expectT("(-webkit-device-pixel-ratio)");
    try expectT("(-WEBKIT-MIN-DEVICE-PIXEL-RATIO: 1)");
    // Numbers only; never negative.
    try expectF("(-webkit-min-device-pixel-ratio: 1dppx)");
    try expectF("not (-webkit-min-device-pixel-ratio: -1)");
    try expectF("(-webkit-min-device-pixel-ratio: dppx)");
    // No min-/max- prefix on the prefixed name.
    try expectF("(min--webkit-device-pixel-ratio: 1)");
}

test "color, color-index and monochrome (sections 6.1-6.3)" {
    try expectT("(color)");
    try expectT("(color: 8)");
    try expectF("(color: 10)");
    try expectT("(min-color: 1)");
    try expectT("(min-color: 8)");
    try expectF("(min-color: 9)");
    try expectT("(max-color: 8)");
    try expectF("(max-color: 7)");
    try expectT("(color >= 8)");
    try expectF("(color > 8)");
    try expectT("(4 <= color <= 8)");
    try expectMatch("(color)", .{ .color_bits = 0 }, false);
    try expectMatch("not (color)", .{ .color_bits = 0 }, true);
    try expectMatch("(color: 0)", .{ .color_bits = 0 }, true);
    try expectMatch("(min-color: 4)", .{ .color_bits = 5 }, true);
    // <integer> only.
    try expectF("(color: 8.5)");
    try expectF("(color: 8.0)");
    try expectF("not (color: 8.5)");
    try expectF("(color: 20example)");
    try expectF("not (color: 20example)");
    try expectSerialized("(color: 20example)", "(color: 20example)");
    try expectF("(color: eight)");

    try expectF("(color-index)");
    try expectF("(min-color-index: 1)");
    try expectT("(color-index: 0)");
    try expectT("(max-color-index: 0)");
    try expectMatch("(color-index)", .{ .color_index = 256 }, true);
    try expectMatch("(min-color-index: 256)", .{ .color_index = 256 }, true);
    try expectMatch("(min-color-index: 257)", .{ .color_index = 256 }, false);
    try expectMatch("(color-index >= 1)", .{ .color_index = 256 }, true);

    try expectF("(monochrome)");
    try expectT("(monochrome: 0)");
    try expectF("(min-monochrome: 1)");
    try expectMatch("(monochrome)", .{ .monochrome_bits = 2 }, true);
    try expectMatch("(monochrome >= 2)", .{ .monochrome_bits = 2 }, true);
    try expectMatch("(monochrome > 2)", .{ .monochrome_bits = 2 }, false);
    try expectMatch("print and (color)", .{ .media_type = .print, .color_bits = 0 }, false);
    try expectMatch("print and (monochrome)", .{ .media_type = .print, .monochrome_bits = 1, .color_bits = 0 }, true);
}

test "preference features (section 12)" {
    // prefers-color-scheme
    try expectT("(prefers-color-scheme: light)");
    try expectF("(prefers-color-scheme: dark)");
    try expectT("(prefers-color-scheme)");
    try expectT("(PREFERS-COLOR-SCHEME: LIGHT)");
    try expectMatch("(prefers-color-scheme: dark)", .{ .prefers_color_scheme = .dark }, true);
    try expectMatch("(prefers-color-scheme: light)", .{ .prefers_color_scheme = .dark }, false);
    try expectMatch("(prefers-color-scheme)", .{ .prefers_color_scheme = .dark }, true);
    try expectMatch("not (prefers-color-scheme: dark)", .{ .prefers_color_scheme = .light }, true);
    try expectF("(prefers-color-scheme: sepia)");
    // sepia is a value no one defined: unknown, so even `not` is false.
    try expectF("not (prefers-color-scheme: sepia)");
    try expectF("(min-prefers-color-scheme: light)");

    // prefers-reduced-motion: no-preference is false in a boolean context.
    try expectT("(prefers-reduced-motion: no-preference)");
    try expectF("(prefers-reduced-motion: reduce)");
    try expectF("(prefers-reduced-motion)");
    try expectMatch("(prefers-reduced-motion)", .{ .prefers_reduced_motion = .reduce }, true);
    try expectMatch("(prefers-reduced-motion: reduce)", .{ .prefers_reduced_motion = .reduce }, true);
    try expectMatch("(prefers-reduced-motion: no-preference)", .{ .prefers_reduced_motion = .reduce }, false);
    try expectMatch("not (prefers-reduced-motion)", .{ .prefers_reduced_motion = .reduce }, false);
    try expectT("not (prefers-reduced-motion)");

    // prefers-contrast
    try expectT("(prefers-contrast: no-preference)");
    try expectF("(prefers-contrast: more)");
    try expectF("(prefers-contrast)");
    inline for (.{ "more", "less", "custom" }, .{ .more, .less, .custom }) |name, tag| {
        const v: MediaValues = .{ .prefers_contrast = tag };
        try expectMatch("(prefers-contrast: " ++ name ++ ")", v, true);
        try expectMatch("(prefers-contrast)", v, true);
        try expectMatch("(prefers-contrast: no-preference)", v, false);
    }
    try expectMatch("(prefers-contrast: less)", .{ .prefers_contrast = .more }, false);

    // forced-colors
    try expectT("(forced-colors: none)");
    try expectF("(forced-colors: active)");
    try expectF("(forced-colors)");
    try expectMatch("(forced-colors: active)", .{ .forced_colors = true }, true);
    try expectMatch("(forced-colors)", .{ .forced_colors = true }, true);
    try expectMatch("(forced-colors: none)", .{ .forced_colors = true }, false);
}

test "scripting (section 9.1)" {
    try expectT("(scripting: enabled)");
    try expectF("(scripting: none)");
    try expectF("(scripting: initial-only)");
    try expectT("(scripting)");
    try expectMatch("(scripting: none)", .{ .scripting = .none }, true);
    try expectMatch("(scripting)", .{ .scripting = .none }, false);
    try expectMatch("not (scripting)", .{ .scripting = .none }, true);
    try expectMatch("(scripting: initial-only)", .{ .scripting = .initial_only }, true);
    try expectMatch("(scripting)", .{ .scripting = .initial_only }, true);
    try expectMatch("(scripting: enabled)", .{ .scripting = .initial_only }, false);
    try expectT("(scripting: ENABLED)");
}

test "features the environment has no fact for are unknown (section 3.2)" {
    for ([_][]const u8{
        "hover",                      "any-hover",            "pointer",                      "any-pointer",
        "display-mode",               "color-gamut",          "dynamic-range",                "update",
        "overflow-block",             "overflow-inline",      "grid",                         "scan",
        "inverted-colors",            "prefers-reduced-data", "prefers-reduced-transparency", "environment-blending",
        "nav-controls",               "video-color-gamut",    "video-dynamic-range",          "horizontal-viewport-segments",
        "vertical-viewport-segments", "ua-color-scheme",      "device-posture",               "made-up-feature",
    }) |name| {
        var buf: [96]u8 = undefined;
        // Boolean form: unknown, so false and its negation false.
        const plain = try std.fmt.bufPrint(&buf, "({s})", .{name});
        try expectF(plain);
        var buf2: [96]u8 = undefined;
        const negated = try std.fmt.bufPrint(&buf2, "not ({s})", .{name});
        try expectF(negated);
        var buf3: [96]u8 = undefined;
        const valued = try std.fmt.bufPrint(&buf3, "({s}: 1)", .{name});
        try expectF(valued);
        var buf4: [96]u8 = undefined;
        const negated_valued = try std.fmt.bufPrint(&buf4, "not ({s}: hover)", .{name});
        try expectF(negated_valued);
    }
    try expectSerialized("(hover: hover)", "(hover: hover)");
    // ... but Kleene logic lets a known term decide.
    try expectT("(hover) or (color)");
    try expectF("(hover) and (color)");
}

test "three-valued logic (section 3.1)" {
    // not (unknown) is unknown, which is false at the top.
    try expectF("(hover)");
    try expectF("not (hover)");
    try expectF("not (not (hover))");
    // unknown or true is true; unknown and false is false.
    try expectT("(width) or (hover)");
    try expectT("(hover) or (width)");
    try expectF("(hover) or (width < 1px)");
    try expectF("(hover) and (width)");
    try expectF("(hover) and (width < 1px)");
    try expectF("(width < 1px) and (hover)");
    try expectF("(width < 1px) or (hover)");
    // Negation of the Kleene results.
    try expectT("not ((hover) and (width < 1px))"); // not false
    try expectF("not ((hover) or (width))"); // not true
    try expectF("not ((hover) or (width < 1px))"); // not unknown
    try expectF("not ((hover) and (width))"); // not unknown
    try expectT("not ((width < 1px) or (height < 1px))");
    // Nested conditions.
    try expectT("not (not (width))");
    try expectT("((width) and (height)) or (hover)");
    try expectT("(hover) or ((width) and (height))");
    try expectF("(hover) and ((width) and (height))");
    try expectT("(not (width < 1px))");
    try expectT("(not (width < 1px)) and (height)");
    try expectT("(width) and (height) and (color)");
    try expectF("(width) and (height) and (width < 1px)");
    try expectT("(width < 1px) or (height < 1px) or (color)");
    try expectF("(width < 1px) or (height < 1px) or (hover)");
    // The media type and an unknown condition: type decides when false.
    try expectF("screen and (hover)");
    try expectF("not screen and (hover)"); // not unknown
    try expectT("not print and (hover)"); // not (false and unknown)
    try expectF("print and (hover)");
    // General enclosed: unknown.
    try expectF("foo(bar)");
    try expectF("not foo(bar)");
    try expectT("foo(bar) or (width)");
    try expectF("foo(bar) and (width)");
    try expectF("(foo bar)");
    try expectT("(foo bar) or (width)");
    try expectF("not (foo bar)");
    try expectSerialized("(width) and (foo bar) or (height)", "not all");
}

test "mixing and, or and not at one level is invalid (section 2.5)" {
    try expectSerialized("(width) and (height) or (color)", "not all");
    try expectSerialized("(width) or (height) and (color)", "not all");
    try expectSerialized("not (width) and (height)", "not all");
    try expectSerialized("not (width) or (height)", "not all");
    try expectSerialized("(width) and not (height)", "not all");
    try expectSerialized("not (width) not (height)", "not all");
    try expectSerialized("(width) (height)", "not all");
    try expectSerialized("(width) and", "not all");
    try expectSerialized("and (width)", "not all");
    try expectSerialized("(width) and and (height)", "not all");
    try expectF("(width) and (height) or (color)");
    // Parentheses group.
    try expectT("((width) and (height)) or (color)");
    try expectT("(width) and ((height) or (hover))");
    // `not (hover) or (height)` is not a media condition (not takes one term):
    // the group is general-enclosed, unknown.
    try expectF("(width) and (not (hover) or (height))");
}

test "whitespace around keywords and function tokens (section 3)" {
    // `and(` is a function token, not the keyword.
    try expectSerialized("(width) and(height)", "not all");
    try expectSerialized("not(width)", "not(width)");
    try expectF("not(width)");
    try expectT("(width)and (height)");
    try expectT("(width) and\n(height)");
    try expectT("screen and\t(width)");
    try expectT("  screen  and  ( width : 1024px )  ");
    try expectF("(width:1024px)and(height:768px)");
    try expectT("screen /* c */ and /* d */ (width)");
    try expectT("( /* c */ width /* d */ : /* e */ 1024px /* f */ )");
    // No whitespace between < or > and =.
    try expectT("(width <= 1024px)");
    try expectT("(width >= 1024px)");
    try expectF("(width < = 1024px)");
    try expectF("(width > = 1024px)");
    try expectF("not (width < = 1024px)");
    try expectT("(width < = 1024px) or (width)");
}

test "min- and max- prefixes (section 2.4.4)" {
    // Boolean form with a prefix on a range feature is a syntax error: the
    // whole query becomes `not all`.
    try expectSerialized("(min-width)", "not all");
    try expectSerialized("(max-height)", "not all");
    try expectSerialized("(min-width) or (width)", "not all");
    try expectF("(min-width) or (width)");
    try expectSerialized("(-webkit-min-device-pixel-ratio)", "not all");
    // ... an unknown feature name is not (it might be a future range feature).
    try expectT("(min-foo) or (width)");
    // Discrete features take no prefix: an unknown feature name.
    try expectF("(min-grid: 1)");
    try expectT("(min-grid: 1) or (width)");
    try expectF("not (min-grid: 1)");
    try expectF("(max-scripting: enabled)");
    try expectF("(min-prefers-color-scheme: light)");
    // Prefixes are not part of the range context.
    try expectF("(min-width > 5px)");
    try expectT("(min-width > 5px) or (width)");
    // min-/max- are ASCII case-insensitive and may be escaped.
    try expectT("(MIN-WIDTH: 1000px)");
    try expectT("(Max-Width: 2000px)");
    try expectT("(\\6d in-width: 1000px)");
}

test "media feature syntax (section 3)" {
    // Case-insensitive names and keywords; escapes.
    try expectT("(\\77idth: 1024px)");
    try expectT("(WIDTH: 1024PX)");
    // Malformed features are general-enclosed: unknown.
    try expectF("(width:)");
    try expectF("(width: 1024px 768px)");
    try expectF("(width 1024px)");
    try expectF("(: 1024px)");
    try expectF("(width: : 1024px)");
    try expectF("(width: 1024px; )");
    try expectT("(width:) or (width)");
    try expectF("(1px < 2px)");
    try expectF("(width < height)");
    try expectF("not (width < height)");
    // Range forms with mixed directions or `=` twice are not features.
    try expectF("(1px < width > 5px)");
    try expectF("not (1px < width > 5px)");
    try expectF("(1px = width = 5px)");
    try expectF("(1px = width < 5px)");
    try expectF("(1px < width = 5px)");
    try expectF("(width < 1px < 2px)");
    try expectT("(1px < width < 5000px)");
    // Empty parentheses are general-enclosed.
    try expectF("()");
    try expectT("() or (width)");
    // Strings and urls as values: unknown.
    try expectF("(width: \"1024px\")");
    // `-` and `+` signs.
    try expectT("(width: +1024px)");
    try expectF("(width: --1024px)");
}

test "serialization (CSSOM 4.2)" {
    try expectSerialized("not screen and (min-WIDTH:5px) AND (max-width:40px)", "not screen and (min-width: 5px) and (max-width: 40px)");
    try expectSerialized("all and (color) and (color)", "(color) and (color)");
    try expectSerialized("all", "all");
    try expectSerialized("SCREEN", "screen");
    try expectSerialized("only screen", "only screen");
    try expectSerialized("only SCREEN and (color)", "only screen and (color)");
    try expectSerialized("not all and (color)", "not all and (color)");
    try expectSerialized("print and (color)", "print and (color)");
    try expectSerialized("(color)", "(color)");
    try expectSerialized("(  Color  )", "(color)");
    try expectSerialized("not (color)", "not (color)");
    try expectSerialized("screen, print", "screen, print");
    try expectSerialized("screen,print ,  (width)", "screen, print, (width)");
    try expectSerialized("screen, (hover) , &x", "screen, (hover), not all");
    try expectSerialized(",", "not all, not all");
    try expectSerialized("screen,", "screen, not all");
    try expectSerialized("(width >= 600px)", "(width >= 600px)");
    try expectSerialized("(width>=600px)", "(width >= 600px)");
    try expectSerialized("(600px<=width)", "(600px <= width)");
    try expectSerialized("(400px < width < 800px)", "(400px < width < 800px)");
    try expectSerialized("(800px>=width>400px)", "(800px >= width > 400px)");
    try expectSerialized("(width=600px)", "(width = 600px)");
    try expectSerialized("(aspect-ratio: 16/9)", "(aspect-ratio: 16 / 9)");
    try expectSerialized("(aspect-ratio:1.5)", "(aspect-ratio: 1.5)");
    try expectSerialized("(prefers-color-scheme:DARK)", "(prefers-color-scheme: dark)");
    try expectSerialized("((color) or (width))", "((color) or (width))");
    try expectSerialized("(not (color)) and (width)", "(not (color)) and (width)");
    try expectSerialized("(color) AND (width) AND (height)", "(color) and (width) and (height)");
    try expectSerialized("(resolution: 2DPPX)", "(resolution: 2dppx)");
    try expectSerialized("(width: 1.5em)", "(width: 1.5em)");
    try expectSerialized("(width: 0)", "(width: 0)");
    try expectSerialized("(-webkit-min-device-pixel-ratio:2)", "(-webkit-min-device-pixel-ratio: 2)");
    try expectSerialized("foo(bar baz)", "foo(bar baz)");
    try expectSerialized("(hover: hover) and (foo bar)", "(hover: hover) and (foo bar)");
    // An unclosed block is closed.
    try expectSerialized("(min-width: 600px", "(min-width: 600px)");
    // Serialize, parse again: the same list.
    try expectSerialized("not screen and (min-width: 5px) and (max-width: 40px)", "not screen and (min-width: 5px) and (max-width: 40px)");
}

test "error recovery: a bad query becomes not all (section 3.2)" {
    // The examples of the specification.
    // "@media (example, all,), speech" is "not all, speech".
    try expectF("(example, all,), speech");
    try expectMatch("(example, all,), speech", .{ .media_type = .print }, false);
    try expectT("(example, all,), screen");
    try expectT("(example, all,), all");
    try expectF("&test, speech");
    try expectT("&test, screen");
    try expectSerialized("&test, speech", "not all, speech");
    // An unclosed block swallows the rest, commas included.
    try expectF("(example, speech");
    try expectF("(example, screen");
    try expectSerialized("(example, screen", "(example, screen)");
    // "screen and (max-weight: 3kg) and (color), (color)" is "not all, (color)".
    try expectT("screen and (max-weight: 3kg) and (color), (color)");
    try expectMatch("screen and (max-weight: 3kg) and (color), (color)", .{ .color_bits = 0 }, false);
    try expectF("screen and (max-weight: 3kg) and (color)");
    // "test;,all": the query is "not all, all".
    try expectT("test;,all");
    try expectSerialized("test;,all", "not all, all");
    // Empty entries are `not all`, but an entirely empty list is empty.
    try expectT(", screen");
    try expectT("screen,");
    try expectT("screen,,print");
    try expectF(",");
    try expectF(", ,");
    try expectF("print,");
    try expectF(",print");
    // Anything other than a query.
    try expectF("5px");
    try expectF("screen 5px");
    try expectT("screen 5px, screen");
    try expectF("\"screen\"");
    try expectF("screen !important");
    try expectF("#screen");
    try expectF("screen)");
    try expectT("screen), screen");
    try expectF("[screen]");
    try expectF("{screen}");
    try expectF("screen and [width]");
    try expectF("@screen");
    try expectF("screen;");
    try expectF("<!-- screen");
    // A mismatched closer is just a token: still invalid, still local.
    try expectT("(width: ] ), screen");
    try expectSerialized("(width: ] )", "not all");
    // Commas inside blocks do not split.
    try expectSerialized("(foo, bar), (width)", "(foo, bar), (width)");
    try expectSerialized("foo(a, b, c)", "foo(a, b, c)");
    try expectSerialized("[a, b], screen", "not all, screen");
    try expectSerialized("{a, b}, screen", "not all, screen");
    try expectSerialized("screen and (a, b), print", "screen and (a, b), print");
    // A bad token inside a general-enclosed block makes the query invalid.
    try expectSerialized("(foo: \"x\ny), screen", "not all, screen");
    try expectF("(foo: \"x\ny) or (width)");
    try expectT("(foo: \"x\") or (width)");
    try expectSerialized("(foo: url(a b))", "not all");
    try expectF("(foo: url(a b)) or (width)");
    try expectT("(foo: url(a)) or (width)");
    // An unmatched closer inside a general-enclosed block likewise.
    try expectF("(foo ] bar) or (width)");
    try expectF("(foo } bar) or (width)");
    try expectT("(foo [ bar ]) or (width)");
    try expectT("(foo { bar }) or (width)");
    try expectF("(foo [ bar )) or (width)");
    try expectF("bar(foo ] x) or (width)");
    // Stray tokens after a good query.
    try expectF("screen and (color) foo");
    try expectF("(color) foo");
    try expectT("(color) , "); // the empty entry after the comma is `not all`
}

test "a syntax error inside a group invalidates the whole query" {
    try expectSerialized("((min-width)) or (width)", "not all");
    try expectSerialized("not ((max-height))", "not all");
    try expectSerialized("(width) and ((min-color) or (color))", "not all");
    // Not a syntax error: an unknown name stays unknown.
    try expectT("((min-foo)) or (width)");
}

test "deep nesting" {
    const allocator = testing.allocator;
    // Groups nest to a limit; a deeper query is `not all` (and the parser
    // does not recurse without bound).
    for ([_]struct { depth: usize, matches: bool }{
        .{ .depth = 64, .matches = true },
        .{ .depth = 127, .matches = true },
        .{ .depth = 5000, .matches = false },
    }) |case| {
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try text.appendNTimes(allocator, '(', case.depth);
        try text.appendSlice(allocator, "(width)");
        try text.appendNTimes(allocator, ')', case.depth);
        const got = try matchesWith(text.items, .{});
        try testing.expectEqual(case.matches, got);
    }
    // General-enclosed contents nest freely (they are not recursed into).
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try text.appendSlice(allocator, "(foo ");
    try text.appendNTimes(allocator, '[', 5000);
    try text.appendNTimes(allocator, ']', 5000);
    try text.appendSlice(allocator, ") or (width)");
    try testing.expect(try matchesWith(text.items, .{}));
}

test "ownership: no leaks on any path" {
    const inputs = [_][]const u8{
        "",
        "screen",
        "not screen and (min-WIDTH:5px) AND (max-width:40px), (400px < width < 800px)",
        "(width) and ((height) or (not (aspect-ratio: 16/9))), foo(bar baz)",
        "(\\77idth: 1024px), only \\73creen and (resolution: 2dppx)",
        "(example, all,), speech, &x, (min-width) , (foo: \"x\ny)",
    };
    for (inputs) |input| {
        var list = try MediaQueryList.parse(testing.allocator, input);
        list.deinit();
    }
    const Check = struct {
        fn run(allocator: std.mem.Allocator, input: []const u8) !void {
            var list = try MediaQueryList.parse(allocator, input);
            defer list.deinit();
            _ = list.matches(&.{});
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();
            // The allocating writer reports an allocation failure as WriteFailed.
            list.serialize(&aw.writer) catch return error.OutOfMemory;
        }
    };
    for (inputs) |input| {
        try testing.checkAllAllocationFailures(testing.allocator, Check.run, .{input});
    }
}

test "matchesQuery" {
    const v: MediaValues = .{};
    try testing.expect(try MediaQueryList.matchesQuery(testing.allocator, "screen and (min-width: 1000px)", &v));
    try testing.expect(!try MediaQueryList.matchesQuery(testing.allocator, "print", &v));
    try testing.expect(try MediaQueryList.matchesQuery(testing.allocator, "", &v));
}
