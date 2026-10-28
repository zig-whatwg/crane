//! The values the style system carries: a property's specified value as a
//! declaration holds it, and its computed value as a ComputedStyle holds it.
//! One union serves both - Blink's CSSValue / ComputedStyle split is a
//! storage choice, and here the computed form is simply a Value whose
//! lengths are absolute.
//!
//! - `Keyword`: every keyword a supported property takes (one enum; each
//!   property's grammar admits its own subset).
//! - `Length`: a number and a unit (css.length), percentages included. A
//!   computed length is in px, or a percentage.
//! - `Color`: an sRGB color (css.color's Color: 8-bit channels and an alpha)
//!   or currentcolor (CSS Color 4 "currentcolor").
//! - `Display`: CSS Display 4's two-keyword model.
//! - `ColorScheme`: a `color-scheme` list (CSS Color Adjustment 1 2.2), its
//!   serialization and the color scheme support it names.
//! - `text`: a value kept as its serialization - a font-family list, an
//!   <image> - in a counted string, so declarations and computed styles
//!   share it.
//!
//! Spec: https://drafts.csswg.org/css-values-4/
//! Spec: https://drafts.csswg.org/css-display-4/#the-display-properties
//! Spec: https://drafts.csswg.org/cssom-1/#serialize-a-css-component-value

const std = @import("std");
const Allocator = std.mem.Allocator;
const length_mod = @import("values/length.zig");
const color_mod = @import("values/color.zig");
const color_scheme_mod = @import("color_scheme.zig");
const resources = @import("resource_values.zig");

pub const Length = length_mod.Length;
pub const LengthUnit = length_mod.LengthUnit;
pub const RgbaColor = color_mod.Color;
pub const Content = @import("generated_content.zig").Content;
pub const ResourceSource = resources.ResourceSource;
pub const ResourceUrl = resources.ResourceUrl;

// ============================================================================
// Keywords
// ============================================================================

/// Every keyword a supported property's grammar names. The CSS spelling is
/// the tag name with '_' for '-'.
pub const Keyword = enum(u16) {
    auto,
    none,
    normal,
    // CSS UI 4 user-select (auto/none are shared with other properties).
    text,
    contain,
    all,
    // Row118 grid/UI values, kept in one block for parallel property work.
    infinite,
    content_box,
    border_box,
    content,
    both,
    horizontal,
    vertical,
    block,
    @"inline",
    bar,
    underscore,
    manual,
    inert,
    // CSS UI 4 §6.2 / SVG 2 §15.6 pointer-events.
    bounding_box,
    visiblepainted,
    visiblefill,
    visiblestroke,
    painted,
    fill,
    stroke,
    // visibility
    visible,
    hidden,
    collapse,
    // position
    static,
    relative,
    absolute,
    sticky,
    fixed,
    // float, logical sides
    left,
    right,
    inline_start,
    inline_end,
    // direction / unicode-bidi
    ltr,
    rtl,
    embed,
    isolate,
    bidi_override,
    isolate_override,
    plaintext,
    // writing-mode
    horizontal_tb,
    vertical_rl,
    vertical_lr,
    sideways_rl,
    sideways_lr,
    // text-orientation
    mixed,
    upright,
    sideways,
    sideways_right,
    // border styles
    dotted,
    dashed,
    solid,
    double,
    groove,
    ridge,
    inset,
    outset,
    // sizing
    min_content,
    max_content,
    fit_content,
    stretch,
    // Anchor Position 1 §6.2.
    most_width,
    most_height,
    most_block_size,
    most_inline_size,
    // Anchor Position 1 §2.4, newer WG resolution #8913 (2026-02-18):
    // all stable engines lag; upstream WPT and implementer support agree.
    match_parent,
    // font-size
    xx_small,
    x_small,
    small,
    medium,
    large,
    x_large,
    xx_large,
    xxx_large,
    larger,
    smaller,
    // font-style / weight
    italic,
    oblique,
    bold,
    bolder,
    lighter,
    // white-space-collapse
    discard,
    preserve,
    preserve_breaks,
    preserve_spaces,
    break_spaces,
    // text-wrap-mode
    wrap,
    nowrap,
    // text-transform
    capitalize,
    uppercase,
    lowercase,
    full_width,
    full_size_kana,
    math_auto,
    // overflow
    clip,
    scroll,
    // appearance
    base,
    base_select,
    searchfield,
    textarea,
    checkbox,
    radio,
    menulist,
    listbox,
    meter,
    progress_bar,
    button,
    textfield,
    menulist_button,
    // border widths
    thin,
    thick,
    // font-family's initial value (a <generic-family>)
    serif,
    // Row118 animation keyword lists.
    ease,
    reverse,
    alternate,
    alternate_reverse,
    forwards,
    backwards,
    running,
    paused,
    replace,
    add,
    accumulate,
    // CSS Transitions 2 §2.5.
    allow_discrete,
    // CSS UI4 §5.1.1 cursor keywords.
    default,
    context_menu,
    help,
    pointer,
    progress,
    wait,
    cell,
    crosshair,
    vertical_text,
    alias,
    copy,
    move,
    no_drop,
    not_allowed,
    grab,
    grabbing,
    e_resize,
    n_resize,
    ne_resize,
    nw_resize,
    s_resize,
    se_resize,
    sw_resize,
    w_resize,
    ew_resize,
    ns_resize,
    nesw_resize,
    nwse_resize,
    col_resize,
    row_resize,
    all_scroll,
    zoom_in,
    zoom_out,

    context_fill,
    context_stroke,
    center,
    numeric_only,
    allow_keywords,

    // CSS Text4 §§6.1–6.4 (row 124).
    loose,
    strict,
    anywhere,
    break_all,
    keep_all,
    auto_phrase,
    break_word,
    // CSS Text4/5 wrapping, fitting and justification (row 124).
    balance,
    stable,
    pretty,
    grow,
    shrink,
    consistent,
    per_line,
    per_line_all,
    inter_word,
    inter_character,
    no_limit,
    start,
    end,
    no_autospace,
    ideograph_alpha,
    ideograph_numeric,
    punctuation,
    insert,
    space_all,
    space_first,
    trim_start,
    trim_both,
    trim_all,
    space,
    ideographic_space,
    first,
    force_end,
    allow_end,
    last,
    justify,
    discard_before,
    discard_after,
    discard_inner,
    // CSS Text Decoration3/4 (row124).
    underline,
    overline,
    line_through,
    blink,
    spelling_error,
    grammar_error,
    wavy,
    from_font,
    under,
    over,
    filled,
    open,
    dot,
    circle,
    double_circle,
    triangle,
    sesame,
    // CSS Inline3 (row124).
    baseline,
    text_bottom,
    alphabetic,
    ideographic,
    middle,
    central,
    mathematical,
    hanging,
    text_top,
    text_before_edge,
    text_after_edge,
    sub,
    super,
    top,
    bottom,
    drop,
    raise,
    cap,
    ex,
    ideographic_ink,
    trim_end,
    // text-align's "align descendants" values (HTML 15.3 presentational
    // hints), as Chrome and Safari compute them (integrator probe 1027a,
    // lane editing4): -webkit-center, -webkit-left, -webkit-right.
    _webkit_center,
    _webkit_left,
    _webkit_right,
    // The UA sheet's th rule (HTML 15.3.8): center while the parent's
    // text-align is the initial value, else the parent's. Only a UA sheet
    // may declare it; text_values.computeAlignment resolves it.
    _internal_th_center,

    /// The keyword's CSS spelling.
    pub fn name(self: Keyword) []const u8 {
        return switch (self) {
            inline else => |k| comptime dashed(@tagName(k)),
        };
    }

    /// The keyword whose CSS spelling is `text`, ASCII case-insensitively.
    pub fn parse(text: []const u8) ?Keyword {
        var buffer: [32]u8 = undefined;
        if (text.len > buffer.len) return null;
        const lower = std.ascii.lowerString(&buffer, text);
        return by_name.get(lower);
    }

    const by_name = blk: {
        @setEvalBranchQuota(100_000);
        const fields = @typeInfo(Keyword).@"enum".fields;
        var entries: [fields.len]struct { []const u8, Keyword } = undefined;
        for (fields, 0..) |field, i| entries[i] = .{ dashed(field.name), @enumFromInt(field.value) };
        break :blk std.StaticStringMap(Keyword).initComptime(entries);
    };
};

fn dashed(comptime tag: []const u8) []const u8 {
    @setEvalBranchQuota(10_000);
    comptime var out: [tag.len]u8 = undefined;
    for (tag, 0..) |c, i| out[i] = if (c == '_') '-' else c;
    const final = out;
    return &final;
}

/// The CSS-wide keywords (CSS Values 4 section 6.1; Cascade 5 section 7.3).
pub const CssWide = enum {
    initial,
    inherit,
    unset,
    revert,
    revert_layer,
    revert_rule,

    pub fn parse(text: []const u8) ?CssWide {
        const map = std.StaticStringMap(CssWide).initComptime(.{
            .{ "initial", .initial },           .{ "inherit", .inherit },
            .{ "unset", .unset },               .{ "revert", .revert },
            .{ "revert-layer", .revert_layer }, .{ "revert-rule", .revert_rule },
        });
        var buffer: [16]u8 = undefined;
        if (text.len > buffer.len) return null;
        return map.get(std.ascii.lowerString(&buffer, text));
    }

    pub fn name(self: CssWide) []const u8 {
        return switch (self) {
            .initial => "initial",
            .inherit => "inherit",
            .unset => "unset",
            .revert => "revert",
            .revert_layer => "revert-layer",
            .revert_rule => "revert-rule",
        };
    }
};

// ============================================================================
// Display (CSS Display 4 section 2)
// ============================================================================

/// CSS Text 4 text-transform: `none | [capitalize | uppercase |
/// lowercase] || full-width || full-size-kana | math-auto`. Its computed
/// value is the specified keywords.
pub const TextTransform = struct {
    case: Case = .none,
    full_width: bool = false,
    full_size_kana: bool = false,
    math_auto: bool = false,

    pub const Case = enum(u8) { none, capitalize, uppercase, lowercase };

    pub fn isNone(self: TextTransform) bool {
        return self.case == .none and !self.full_width and !self.full_size_kana and !self.math_auto;
    }

    pub fn eql(a: TextTransform, b: TextTransform) bool {
        return a.case == b.case and a.full_width == b.full_width and a.full_size_kana == b.full_size_kana and a.math_auto == b.math_auto;
    }

    /// The keywords in the grammar's order (Chrome, Firefox and Safari
    /// serialize `full-width lowercase` as `lowercase full-width`:
    /// css/css-text/parsing/text-transform-valid.html).
    pub fn serialize(self: TextTransform, out: *std.ArrayList(u8), allocator: std.mem.Allocator) std.mem.Allocator.Error!void {
        if (self.math_auto) return out.appendSlice(allocator, "math-auto");
        if (self.isNone()) return out.appendSlice(allocator, "none");
        var first = true;
        if (self.case != .none) {
            try out.appendSlice(allocator, @tagName(self.case));
            first = false;
        }
        if (self.full_width) {
            if (!first) try out.append(allocator, ' ');
            try out.appendSlice(allocator, "full-width");
            first = false;
        }
        if (self.full_size_kana) {
            if (!first) try out.append(allocator, ' ');
            try out.appendSlice(allocator, "full-size-kana");
        }
    }
};

pub const Display = struct {
    box: Box = .normal,
    outer: Outer = .inline_,
    inner: Inner = .flow,
    list_item: bool = false,
    /// For `box == .internal`.
    internal: Internal = .table_row_group,

    pub const Box = enum(u8) { normal, none, contents, internal };
    pub const Outer = enum(u8) { block, inline_, run_in };
    pub const Inner = enum(u8) { flow, flow_root, table, flex, grid, ruby, math };
    pub const Internal = enum(u8) {
        table_row_group,
        table_header_group,
        table_footer_group,
        table_row,
        table_cell,
        table_column_group,
        table_column,
        table_caption,
        ruby_base,
        ruby_text,
        ruby_base_container,
        ruby_text_container,

        pub fn name(self: Internal) []const u8 {
            return switch (self) {
                inline else => |k| comptime dashed(@tagName(k)),
            };
        }
    };

    pub const inline_flow: Display = .{};
    pub const block_flow: Display = .{ .outer = .block };
    pub const none: Display = .{ .box = .none };
    pub const contents: Display = .{ .box = .contents };

    pub fn eql(a: Display, b: Display) bool {
        if (a.box != b.box) return false;
        return switch (a.box) {
            .none, .contents => true,
            .internal => a.internal == b.internal,
            .normal => a.outer == b.outer and a.inner == b.inner and a.list_item == b.list_item,
        };
    }

    /// Whether the box is "block-level" (Display 4 glossary): its outer
    /// display type is block. A table caption counts with it for innerText.
    pub fn isBlockLevel(self: Display) bool {
        return self.box == .normal and self.outer == .block;
    }

    /// CSS Contain 2 section 3.1: size containment needs an eligible
    /// principal box. Replaced inline boxes are atomic (Display 4 section
    /// 2.1); a run-in is inline-level too. Table captions are independent
    /// block containers, unlike the other internal table/ruby boxes.
    pub fn canSizeContain(self: Display, replaced: bool) bool {
        return switch (self.box) {
            .none, .contents => false,
            .internal => self.internal == .table_caption,
            .normal => self.inner != .table and
                (self.outer == .block or replaced or (self.inner != .flow and self.inner != .ruby)),
        };
    }

    /// Display 4 section 2.7 "blockify": the computed outer display type
    /// becomes block; an inline flow-root (inline-block) loses its
    /// flow-root nature; a layout-internal box becomes a block container.
    /// No effect on `none` or `contents`.
    pub fn blockified(self: Display) Display {
        return switch (self.box) {
            .none, .contents => self,
            // "If a layout-internal box is blockified, its inner display
            // type converts to flow so that it becomes a block container."
            .internal => block_flow,
            .normal => blk: {
                var out = self;
                // "if an inline block box (inline flow-root) is blockified,
                // it becomes a block box (losing its flow-root nature). For
                // consistency, a run-in flow-root box also blockifies to a
                // block box."
                if (self.inner == .flow_root and self.outer != .block) out.inner = .flow;
                out.outer = .block;
                break :blk out;
            },
        };
    }

    /// The shortest serialization (Display 4: "the precomposed and shorter
    /// legacy forms are preferred"), as getComputedStyle reads it.
    pub fn serialize(self: Display, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self.box) {
            .none => return out.appendSlice(allocator, "none"),
            .contents => return out.appendSlice(allocator, "contents"),
            .internal => return out.appendSlice(allocator, self.internal.name()),
            .normal => {},
        }
        if (self.list_item) {
            // <display-listitem> = <display-outside>? && [flow | flow-root]? && list-item
            if (self.outer == .inline_) try out.appendSlice(allocator, "inline ");
            if (self.outer == .run_in) try out.appendSlice(allocator, "run-in ");
            if (self.inner == .flow_root) try out.appendSlice(allocator, "flow-root ");
            return out.appendSlice(allocator, "list-item");
        }
        const text: []const u8 = switch (self.outer) {
            .block => switch (self.inner) {
                .flow => "block",
                .flow_root => "flow-root",
                .table => "table",
                .flex => "flex",
                .grid => "grid",
                .ruby => "block ruby",
                .math => "block math",
            },
            .inline_ => switch (self.inner) {
                .flow => "inline",
                .flow_root => "inline-block",
                .table => "inline-table",
                .flex => "inline-flex",
                .grid => "inline-grid",
                .ruby => "ruby",
                .math => "math",
            },
            .run_in => switch (self.inner) {
                .flow => "run-in",
                .flow_root => "run-in flow-root",
                .table => "run-in table",
                .flex => "run-in flex",
                .grid => "run-in grid",
                .ruby => "run-in ruby",
                .math => "run-in math",
            },
        };
        try out.appendSlice(allocator, text);
    }
};

// ============================================================================
// Color
// ============================================================================

/// A color value: an absolute sRGB color, or currentcolor (CSS Color 4
/// section 6.4), which a computed value keeps as the keyword.
pub const Color = union(enum) {
    rgba: RgbaColor,
    /// Allocation-free specified initial/reset spelling (Backgrounds 3 §2.10).
    /// Authored RGBA and named colors keep their own representations.
    transparent_keyword,
    /// Immutable owned CSS components, with precision and missingness intact.
    expression: *@import("color_values.zig").Expression,
    current,
    /// A <named-color> or <system-color> keyword: its color, and the
    /// keyword (lowercase), which a specified value serializes as written
    /// (CSS Color 4 15 "Serializing <color> Values": "the keyword ...
    /// converted to ASCII lowercase"). A computed value is its color.
    named: Named,
    /// A <system-color>: kept as the keyword until the computed-value step
    /// resolves it against the element's used color scheme (CSS Color 4
    /// 15.5; CSS Color Adjustment 1 2.4). A computed value never holds one.
    system: color_mod.SystemColor,

    pub const Named = struct {
        rgba: RgbaColor,
        name: *SharedText,
    };

    pub const transparent: Color = .transparent_keyword;
    pub const black: Color = .{ .rgba = RgbaColor.black };

    /// Borrowed inputs; a computed result always owns the references it needs.
    /// null current keeps currentcolor symbolic for inheritance through other
    /// color properties. For the color property, pass the parent's color.
    pub const Context = struct {
        scheme: color_scheme_mod.Scheme = .light,
        current: ?Color = null,
        math: @import("math_values.zig").Context = .{},
    };

    /// Query the original stop graph before computed color resolution. The
    /// computed stage carries the receiving element's own used scheme.
    pub const GradientStage = union(enum) {
        specified,
        computed: color_scheme_mod.Scheme,
    };

    pub fn usesLegacyGradientInterpolation(self: Color, stage: GradientStage) bool {
        return switch (self) {
            .expression => |e| e.usesLegacyGradientInterpolation(stage),
            .rgba, .transparent_keyword, .current, .named, .system => true,
        };
    }

    /// Every holder of a Color takes a reference, including nested paint data.
    /// Scalar colors are allocation-free and need no work here.
    pub fn retain(self: Color) void {
        if (self == .named) self.named.name.ref();
        if (self == .expression) self.expression.ref();
    }

    pub fn release(self: Color) void {
        if (self == .named) self.named.name.unref();
        if (self == .expression) self.expression.unref();
    }

    /// Color 4 §§6.4, 15: specified keywords keep their lowercase spelling.
    pub fn serializeSpecified(self: Color, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        switch (self) {
            .expression => |e| try e.serialize(out, allocator),
            .rgba => |c| try serializeRgba(c, out, allocator),
            .transparent_keyword => try out.appendSlice(allocator, "transparent"),
            .current => try out.appendSlice(allocator, "currentcolor"),
            .named => |n| try out.appendSlice(allocator, n.name.bytes),
            .system => |s| try out.appendSlice(allocator, s.keyword()),
        }
    }

    /// A computed color's own serialization. Resolve currentcolor with the
    /// destination's current color first when CSSOM requires a used color.
    pub fn serializeComputed(self: Color, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
        if (self == .expression) return self.expression.serialize(out, allocator);
        if (self.absolute()) |c| return serializeRgba(c, out, allocator);
        return out.appendSlice(allocator, "currentcolor");
    }

    /// Returns an OWNED value; neither self nor Context's borrowed current
    /// color is consumed. Allocation errors are part of the stable API for
    /// typed components. The caller releases every successful result.
    pub fn resolveComputed(self: Color, allocator: Allocator, context: Context) Allocator.Error!Color {
        return switch (self) {
            .expression => |e| try e.resolve(allocator, context),
            .current => blk: {
                const result = context.current orelse self;
                result.retain();
                break :blk result;
            },
            .rgba => self,
            .transparent_keyword => .{ .rgba = RgbaColor.transparent },
            .named => |n| .{ .rgba = n.rgba },
            .system => |s| .{ .rgba = s.color(context.scheme) },
        };
    }

    /// Aggregates forward this query without inspecting Color's variants.
    /// A future typed variant must explicitly describe its dependencies.
    pub fn containsCurrentColor(self: Color) bool {
        return switch (self) {
            .current => true,
            .expression => |e| e.containsCurrentColor(),
            .rgba, .transparent_keyword, .named, .system => false,
        };
    }

    pub fn needsTreeCounts(self: Color) bool {
        return switch (self) {
            .expression => |e| e.needsTreeCounts(),
            .rgba, .transparent_keyword, .current, .named, .system => false,
        };
    }

    pub fn needsRandomBase(self: Color) bool {
        return switch (self) {
            .expression => |e| e.needsRandomBase(),
            .rgba, .transparent_keyword, .current, .named, .system => false,
        };
    }

    /// Scalar colors need no font or layout metrics, for either destination.
    pub fn needsUnavailableMetrics(self: Color, geometry_length: bool) bool {
        return switch (self) {
            .expression => |e| e.needsUnavailableMetrics(geometry_length),
            .rgba, .transparent_keyword, .current, .named, .system => false,
        };
    }

    pub fn eql(a: Color, b: Color) bool {
        return switch (a) {
            .expression => |e| b == .expression and e.eql(b.expression),
            .current => b == .current,
            .transparent_keyword => b == .transparent_keyword,
            .rgba => |x| switch (b) {
                .rgba => |y| x.eql(y),
                else => false,
            },
            .named => |x| switch (b) {
                .named => |y| x.rgba.eql(y.rgba) and std.mem.eql(u8, x.name.bytes, y.name.bytes),
                else => false,
            },
            .system => |x| b == .system and b.system == x,
        };
    }

    /// The color itself; currentcolor has none of its own. A system color
    /// with no element to take a scheme from is the UA default's (light).
    pub fn absolute(self: Color) ?RgbaColor {
        return switch (self) {
            .expression => |e| e.bytes(),
            .rgba => |c| c,
            .transparent_keyword => RgbaColor.transparent,
            .named => |n| n.rgba,
            .system => |s| s.color(.light),
            .current => null,
        };
    }
};

/// CSS Color 4 section 15.2 "Serializing sRGB values": `rgb(r, g, b)` when
/// opaque, else `rgba(r, g, b, a)`, the alpha its shortest form at 8 bits
/// of precision.
pub fn serializeRgba(c: RgbaColor, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (c.a >= 1.0) {
        return out.print(allocator, "rgb({d}, {d}, {d})", .{ c.r, c.g, c.b });
    }
    try out.print(allocator, "rgba({d}, {d}, {d}, ", .{ c.r, c.g, c.b });
    try appendAlpha(c.a, out, allocator);
    try out.append(allocator, ')');
}

/// CSS Color 4 15.1 "serializing alpha values": the alpha rounded to the
/// shortest decimal that maps back to the same 8-bit value.
fn appendAlpha(alpha: f32, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    const a = std.math.clamp(alpha, 0, 1);
    const byte: i32 = @intFromFloat(@round(a * 255));
    // Two decimals when they round-trip, else three.
    const two = @round(a * 100) / 100;
    const value: f64 = if (@as(i32, @intFromFloat(@round(two * 255))) == byte) two else @round(a * 1000) / 1000;
    try appendNumber(value, out, allocator);
}

// ============================================================================
// color-scheme
// ============================================================================

/// A `color-scheme` value other than `normal`: `[ light | dark |
/// <custom-ident> ]+ && only?` (CSS Color Adjustment 1 2.2). Its computed
/// value is as specified ("the keyword normal, or a color scheme support"),
/// so one value serves both.
pub const ColorScheme = struct {
    /// The serialization, per grammar: the schemes in order - light and dark
    /// lowercase, a <custom-ident> as an identifier - then `only`.
    text: *SharedText,
    /// The color scheme support it names (section 2.3).
    support: color_scheme_mod.Support,
};

// ============================================================================
// Shared text
// ============================================================================

/// A counted UTF-8 string: a value kept as its serialization. Not atomic -
/// a value belongs to its document's thread - except that an `immortal`
/// string (the process's UA style sheet's) is never counted at all, so
/// every thread may read it.
pub const SharedText = struct {
    refs: u32,
    allocator: Allocator,
    bytes: []u8,
    resource_urls: []const ResourceUrl = &.{},
    image_kind: enum { generic, url, gradient, other } = .generic,

    const immortal: u32 = std.math.maxInt(u32);

    pub fn create(allocator: Allocator, bytes: []const u8) Allocator.Error!*SharedText {
        const self = try allocator.create(SharedText);
        errdefer allocator.destroy(self);
        self.* = .{ .refs = 1, .allocator = allocator, .bytes = try allocator.dupe(u8, bytes) };
        return self;
    }

    /// Copies both text and occurrences, retaining every occurrence's source.
    pub fn createWithResources(allocator: Allocator, bytes: []const u8, urls: []const ResourceUrl) Allocator.Error!*SharedText {
        const self = try create(allocator, bytes);
        errdefer self.unref();
        self.resource_urls = try resources.cloneAll(allocator, urls, 0);
        return self;
    }

    /// Make the string uncounted: it lives until `destroyImmortal`.
    pub fn makeImmortal(self: *SharedText) void {
        self.refs = immortal;
    }

    pub fn destroyImmortal(self: *SharedText) void {
        std.debug.assert(self.refs == immortal);
        resources.releaseAll(self.allocator, self.resource_urls);
        self.allocator.free(self.bytes);
        self.allocator.destroy(self);
    }

    pub fn ref(self: *SharedText) void {
        if (self.refs == immortal) return;
        self.refs += 1;
    }

    pub fn unref(self: *SharedText) void {
        if (self.refs == immortal) return;
        self.refs -= 1;
        if (self.refs > 0) return;
        resources.releaseAll(self.allocator, self.resource_urls);
        self.allocator.free(self.bytes);
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Value
// ============================================================================

/// CSS Sizing 4 §3.2: an intrinsic sizing function keeps its typed argument
/// until layout. Specified and computed values own separate argument values.
pub const SizingFunction = struct {
    refs: std.atomic.Value(u32) = .init(1),
    allocator: Allocator,
    argument: Value,

    /// Takes ownership of argument on success only.
    pub fn create(allocator: Allocator, argument: Value) Allocator.Error!*SizingFunction {
        const self = try allocator.create(SizingFunction);
        self.* = .{ .allocator = allocator, .argument = argument };
        return self;
    }

    pub fn ref(self: *SizingFunction) void {
        _ = self.refs.fetchAdd(1, .monotonic);
    }

    pub fn unref(self: *SizingFunction) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        self.argument.release();
        self.allocator.destroy(self);
    }
};

/// A property's value, specified or computed.
pub const Value = union(enum) {
    keyword: Keyword,
    length: Length,
    number: f64,
    integer: i32,
    color: Color,
    display: Display,
    text_transform: TextTransform,
    color_scheme: ColorScheme,
    content: *Content,
    calculation: *@import("math_values.zig").Expression,
    sizing_function: *SizingFunction,
    grid_line: *@import("grid_values.zig").Line,
    grid_tracks: *@import("grid_tracks.zig").Tracks,
    grid_areas: *@import("grid_tracks.zig").Areas,
    grid_flow: @import("grid_tracks.zig").Flow,
    caret_pair: *@import("ui_values.zig").CaretPair,
    animation_list: *@import("animation_values.zig").List,
    transform: *@import("transform_values.zig").Transform,
    alignment: @import("alignment.zig").Value,
    position_area: @import("position_area.zig").Area,
    position_visibility: @import("position_visibility.zig").Value,
    containment: @import("containment.zig").Value,
    try_fallbacks: struct { list: *@import("anchor_fallbacks.zig").Fallbacks, computed: bool = false },
    /// Kept as its serialization when no structured value is needed.
    text: *SharedText,
    pending: *@import("pending_values.zig").Pending,
    cursor: *@import("cursor_values.zig").Cursor,
    indent: *@import("text_indent.zig").Indent,
    paint: *@import("svg_paint.zig").Paint,
    filter: *@import("filter_values.zig").Filter,
    box_shadow: *@import("box_shadow_values.zig").BoxShadow,
    shape: *@import("shape_values.zig").Shape,
    corner_radius: @import("border_radius.zig").Corner,
    image_resolution: @import("image_resolution.zig").Value,
    image_position: *@import("position_values.zig").Position,
    image_size: *@import("image_size.zig").Size,
    image_quad: *@import("image_quad.zig").Quad,
    layers: *@import("image_layers.zig").Layers,
    image_keyword: @import("image_keywords.zig").Keyword,
    image_repeat: @import("image_keywords.zig").Repeat,
    image: *@import("image_values.zig").Image,
    image_axis: *@import("position_values.zig").PositionAxis,
    font_width_keyword: @import("font_width.zig").Keyword,
    font_oblique: *@import("font_style.zig").Oblique,
    font_settings: *@import("font_settings.zig").Settings,
    font_family: *@import("font_family.zig").Families,
    font_size_adjust: *@import("font_size_adjust.zig").Adjust,
    font_system: @import("font_system.zig").Keyword,
    text_values: *@import("text_values.zig").Components,
    decoration_keywords: @import("decoration_values.zig").Keywords,
    text_shadow: *@import("text_shadow_values.zig").Shadows,

    /// Borrowed URL candidates in serialization order, valid while this
    /// value is retained. No sheet or document lookup is needed to use them.
    pub fn resourceUrls(self: Value) []const ResourceUrl {
        return switch (self) {
            .text => |t| t.resource_urls,
            .content => |c| c.resource_urls,
            .cursor => |c| c.text.resource_urls,
            .paint => |v| v.url.resourceUrls(),
            .filter => |v| v.text.resource_urls,
            .layers => |v| v.text.resource_urls,
            .image => |v| v.text.resource_urls,
            else => &.{},
        };
    }

    /// Resource identity includes provenance; eql deliberately remains a
    /// value/text comparison. Reuse decisions that keep a source need both.
    pub fn resourcesEql(a: Value, b: Value) bool {
        return resources.eql(a.resourceUrls(), b.resourceUrls());
    }

    /// Take a reference to what the value holds (a copy of it is kept).
    pub fn retain(self: Value) void {
        if (self == .text_values) return self.text_values.ref();
        if (self == .text_shadow) return self.text_shadow.ref();
        if (self == .color) return self.color.retain();
        if (self == .content) return self.content.ref();
        if (self == .cursor) return self.cursor.ref();
        if (self == .indent) return self.indent.ref();
        if (self == .calculation) return self.calculation.ref();
        if (self == .sizing_function) return self.sizing_function.ref();
        if (self == .grid_line) return self.grid_line.ref();
        if (self == .grid_tracks) return self.grid_tracks.ref();
        if (self == .grid_areas) return self.grid_areas.ref();
        if (self == .caret_pair) return self.caret_pair.ref();
        if (self == .animation_list) return self.animation_list.ref();
        if (self == .transform) return self.transform.ref();
        if (self == .pending) return self.pending.ref();
        if (self == .try_fallbacks) return self.try_fallbacks.list.ref();
        if (self == .paint) return self.paint.ref();
        if (self == .filter) return self.filter.ref();
        if (self == .box_shadow) return self.box_shadow.ref();
        if (self == .shape) return self.shape.ref();
        if (self == .corner_radius) return self.corner_radius.ref();
        if (self == .image_resolution) return self.image_resolution.retain();
        if (self == .image_position) return self.image_position.ref();
        if (self == .image_size) return self.image_size.ref();
        if (self == .image_quad) return self.image_quad.ref();
        if (self == .layers) return self.layers.ref();
        if (self == .image) return self.image.ref();
        if (self == .image_axis) return self.image_axis.ref();
        if (self == .font_oblique) return self.font_oblique.ref();
        if (self == .font_settings) return self.font_settings.ref();
        if (self == .font_family) return self.font_family.ref();
        if (self == .font_size_adjust) return self.font_size_adjust.ref();
        if (self.sharedText()) |t| t.ref();
    }

    /// Drop the reference `retain` took.
    pub fn release(self: Value) void {
        if (self == .text_values) return self.text_values.unref();
        if (self == .text_shadow) return self.text_shadow.unref();
        if (self == .color) return self.color.release();
        if (self == .content) return self.content.unref();
        if (self == .cursor) return self.cursor.unref();
        if (self == .indent) return self.indent.unref();
        if (self == .calculation) return self.calculation.unref();
        if (self == .sizing_function) return self.sizing_function.unref();
        if (self == .grid_line) return self.grid_line.unref();
        if (self == .grid_tracks) return self.grid_tracks.unref();
        if (self == .grid_areas) return self.grid_areas.unref();
        if (self == .caret_pair) return self.caret_pair.unref();
        if (self == .animation_list) return self.animation_list.unref();
        if (self == .transform) return self.transform.unref();
        if (self == .pending) return self.pending.unref();
        if (self == .try_fallbacks) return self.try_fallbacks.list.unref();
        if (self == .paint) return self.paint.unref();
        if (self == .filter) return self.filter.unref();
        if (self == .box_shadow) return self.box_shadow.unref();
        if (self == .shape) return self.shape.unref();
        if (self == .corner_radius) return self.corner_radius.unref();
        if (self == .image_resolution) return self.image_resolution.release();
        if (self == .image_position) return self.image_position.unref();
        if (self == .image_size) return self.image_size.unref();
        if (self == .image_quad) return self.image_quad.unref();
        if (self == .layers) return self.layers.unref();
        if (self == .image) return self.image.unref();
        if (self == .image_axis) return self.image_axis.unref();
        if (self == .font_oblique) return self.font_oblique.unref();
        if (self == .font_settings) return self.font_settings.unref();
        if (self == .font_family) return self.font_family.unref();
        if (self == .font_size_adjust) return self.font_size_adjust.unref();
        if (self.sharedText()) |t| t.unref();
    }

    /// The counted text the value holds, if any.
    pub fn sharedText(self: Value) ?*SharedText {
        return switch (self) {
            .text => |t| t,
            .color => |c| if (c == .named) c.named.name else null,
            .color_scheme => |c| c.text,
            else => null,
        };
    }

    pub fn eql(a: Value, b: Value) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        return switch (a) {
            .keyword => |k| k == b.keyword,
            .length => |l| l.value == b.length.value and l.unit == b.length.unit,
            .number => |n| n == b.number,
            .integer => |n| n == b.integer,
            .color => |c| c.eql(b.color),
            .display => |d| d.eql(b.display),
            .text_transform => |t| t.eql(b.text_transform),
            .color_scheme => |c| c.support.eql(b.color_scheme.support) and std.mem.eql(u8, c.text.bytes, b.color_scheme.text.bytes),
            .content => |c| c.eql(b.content),
            .calculation => |c| c.eql(b.calculation),
            .sizing_function => |s| s.argument.eql(b.sizing_function.argument),
            .grid_line => |line| line.eql(b.grid_line),
            .grid_tracks => |tracks| tracks.eql(b.grid_tracks),
            .grid_areas => |areas| areas.eql(b.grid_areas),
            .grid_flow => |flow| std.meta.eql(flow, b.grid_flow),
            .caret_pair => |pair| pair.eql(b.caret_pair),
            .animation_list => |list| list.eql(b.animation_list),
            .transform => |transform| transform.eql(b.transform),
            .alignment => |a_value| a_value.eql(b.alignment),
            .position_area => |a_area| a_area.eql(b.position_area),
            .position_visibility => |v| std.meta.eql(v, b.position_visibility),
            .containment => |v| std.meta.eql(v, b.containment),
            .try_fallbacks => |f| f.computed == b.try_fallbacks.computed and f.list.eql(b.try_fallbacks.list),
            .text => |t| t == b.text or std.mem.eql(u8, t.bytes, b.text.bytes),
            .pending => |pending| pending.eql(b.pending),
            .cursor => |c| c.eql(b.cursor),
            .indent => |v| v.eql(b.indent),
            .paint => |v| v.eql(b.paint),
            .filter => |v| v.eql(b.filter),
            .box_shadow => |v| v.eql(b.box_shadow),
            .shape => |v| v.eql(b.shape),
            .corner_radius => |v| v.eql(b.corner_radius),
            .image_resolution => |v| v.eql(b.image_resolution),
            .image_position => |v| v.eql(b.image_position),
            .image_size => |v| v.eql(b.image_size),
            .image_quad => |v| v.eql(b.image_quad),
            .layers => |v| v.eql(b.layers),
            .image_keyword => |v| v == b.image_keyword,
            .image_repeat => |v| std.meta.eql(v, b.image_repeat),
            .image => |v| v.eql(b.image),
            .image_axis => |v| v.eql(b.image_axis),
            .font_width_keyword => |v| v == b.font_width_keyword,
            .font_oblique => |v| v.eql(b.font_oblique),
            .font_settings => |v| v.eql(b.font_settings),
            .font_family => |v| v.eql(b.font_family),
            .font_size_adjust => |v| v.eql(b.font_size_adjust),
            .font_system => |v| v == b.font_system,
            .text_values => |v| v.eql(b.text_values),
            .decoration_keywords => |v| v.eql(b.decoration_keywords),
            .text_shadow => |v| v.eql(b.text_shadow),
        };
    }

    pub fn kw(k: Keyword) Value {
        return .{ .keyword = k };
    }

    /// Q17/Q23–25: aggregate values must not hide an unsupported scalar.
    /// Keep this switch exhaustive so a new aggregate must choose a rule.
    pub fn needsUnavailableMetrics(self: Value, geometry_length: bool) bool {
        return switch (self) {
            .color => |c| c.needsUnavailableMetrics(geometry_length),
            .calculation => |c| c.needsUnavailableMetrics(geometry_length),
            .sizing_function => |s| s.argument.needsUnavailableMetrics(geometry_length),
            .grid_line => |line| line.needsUnavailableMetrics(),
            .grid_tracks => |tracks| tracks.needsUnavailableMetrics(),
            .caret_pair => |pair| pair.needsUnavailableMetrics(),
            .animation_list => |list| list.needsUnavailableMetrics(),
            .transform => |transform| transform.needsUnavailableMetrics(geometry_length),
            .grid_areas,
            .grid_flow,
            .keyword,
            .length,
            .number,
            .integer,
            .display,
            .text_transform,
            .color_scheme,
            .alignment,
            .position_area,
            .try_fallbacks,
            .text,
            .pending, // Q88: inspect only the resolved, selected branch.
            => false,
            .content => |v| v.needsUnavailableMetrics(geometry_length),
            .cursor => |v| v.needsUnavailableMetrics(geometry_length),
            .indent => |v| v.offset.needsUnavailableMetrics(geometry_length),
            .image_keyword, .image_repeat, .position_visibility, .containment => false,
            .paint => |v| v.needsUnavailableMetrics(geometry_length),
            .filter => |v| v.needsUnavailableMetrics(geometry_length),
            .box_shadow => |v| v.needsUnavailableMetrics(geometry_length),
            .shape => |v| v.needsUnavailableMetrics(geometry_length),
            .corner_radius => |v| v.needsUnavailableMetrics(geometry_length),
            .image_resolution => |v| v.needsUnavailableMetrics(geometry_length),
            .image_position => |v| v.needsUnavailableMetrics(geometry_length),
            .image_size => |v| v.needsUnavailableMetrics(geometry_length),
            .image_quad => |v| v.needsUnavailableMetrics(geometry_length),
            .layers => |v| v.needsUnavailableMetrics(geometry_length),
            .image => |v| v.needsUnavailableMetrics(geometry_length),
            .image_axis => |v| v.needsUnavailableMetrics(geometry_length),
            .font_width_keyword => false,
            .font_oblique => |v| v.needsUnavailableMetrics(),
            .font_settings => |v| v.needsUnavailableMetrics(),
            .font_family, .font_system => false,
            .font_size_adjust => |v| v.needsUnavailableMetrics(),
            .text_values => |v| v.needsUnavailableMetrics(geometry_length),
            .text_shadow => |v| v.needsUnavailableMetrics(geometry_length),
            .decoration_keywords => false,
        };
    }

    /// Values 5 §10: only numeric trees and aggregates can need DOM counts.
    /// Exhaustive so new wrappers must explicitly carry the dependency.
    pub fn needsTreeCounts(self: Value) bool {
        return switch (self) {
            .color => |c| c.needsTreeCounts(),
            .caret_pair => |p| p.needsTreeCounts(),
            .calculation => |c| c.needsTreeCounts(),
            .sizing_function => |s| s.argument.needsTreeCounts(),
            .grid_line => |line| line.needsTreeCounts(),
            .grid_tracks => |tracks| tracks.needsTreeCounts(),
            .animation_list => |list| list.needsTreeCounts(),
            .transform => |transform| transform.needsTreeCounts(),
            .grid_areas,
            .grid_flow,
            .keyword,
            .length,
            .number,
            .integer,
            .display,
            .text_transform,
            .color_scheme,
            .alignment,
            .position_area,
            .try_fallbacks,
            .text,
            .pending, // Q88: inspect only the resolved, selected branch.
            => false,
            .content => |v| v.needsTreeCounts(),
            .cursor => |v| v.needsTreeCounts(),
            .indent => |v| v.offset.needsTreeCounts(),
            .image_keyword, .image_repeat, .position_visibility, .containment => false,
            .paint => |v| v.needsTreeCounts(),
            .filter => |v| v.needsTreeCounts(),
            .box_shadow => |v| v.needsTreeCounts(),
            .shape => |v| v.needsTreeCounts(),
            .corner_radius => |v| v.needsTreeCounts(),
            .image_resolution => |v| v.needsTreeCounts(),
            .image_position => |v| v.needsTreeCounts(),
            .image_size => |v| v.needsTreeCounts(),
            .image_quad => |v| v.needsTreeCounts(),
            .layers => |v| v.needsTreeCounts(),
            .image => |v| v.needsTreeCounts(),
            .image_axis => |v| v.needsTreeCounts(),
            .font_width_keyword => false,
            .font_oblique => |v| v.needsTreeCounts(),
            .font_settings => |v| v.needsTreeCounts(),
            .font_family, .font_system => false,
            .font_size_adjust => |v| v.needsTreeCounts(),
            .text_values => |v| v.needsTreeCounts(),
            .text_shadow => |v| v.needsTreeCounts(),
            .decoration_keywords => false,
        };
    }

    pub fn needsRandomBase(self: Value) bool {
        return switch (self) {
            .color => |c| c.needsRandomBase(),
            .caret_pair => |p| p.needsRandomBase(),
            .calculation => |c| c.needsRandomBase(),
            .sizing_function => |s| s.argument.needsRandomBase(),
            .grid_line => |line| line.needsRandomBase(),
            .grid_tracks => |tracks| tracks.needsRandomBase(),
            .animation_list => |list| list.needsRandomBase(),
            .transform => |transform| transform.needsRandomBase(),
            .grid_areas,
            .grid_flow,
            .keyword,
            .length,
            .number,
            .integer,
            .display,
            .text_transform,
            .color_scheme,
            .alignment,
            .position_area,
            .try_fallbacks,
            .text,
            .pending, // Q88: inspect only the resolved, selected branch.
            => false,
            .content => |v| v.needsRandomBase(),
            .cursor => |v| v.needsRandomBase(),
            .indent => |v| v.offset.needsRandomBase(),
            .image_keyword, .image_repeat, .position_visibility, .containment => false,
            .paint => |v| v.needsRandomBase(),
            .filter => |v| v.needsRandomBase(),
            .box_shadow => |v| v.needsRandomBase(),
            .shape => |v| v.needsRandomBase(),
            .corner_radius => |v| v.needsRandomBase(),
            .image_resolution => |v| v.needsRandomBase(),
            .image_position => |v| v.needsRandomBase(),
            .image_size => |v| v.needsRandomBase(),
            .image_quad => |v| v.needsRandomBase(),
            .layers => |v| v.needsRandomBase(),
            .image => |v| v.needsRandomBase(),
            .image_axis => |v| v.needsRandomBase(),
            .font_width_keyword => false,
            .font_oblique => |v| v.needsRandomBase(),
            .font_settings => |v| v.needsRandomBase(),
            .font_family, .font_system => false,
            .font_size_adjust => |v| v.needsRandomBase(),
            .text_values => |v| v.needsRandomBase(),
            .text_shadow => |v| v.needsRandomBase(),
            .decoration_keywords => false,
        };
    }

    pub fn px(v: f64) Value {
        return .{ .length = Length.px(v) };
    }

    pub fn isKeyword(self: Value, k: Keyword) bool {
        return self == .keyword and self.keyword == k;
    }
};

// ============================================================================
// Number serialization
// ============================================================================

/// CSSOM "serialize a CSS component value" for <number>: base ten, the
/// shortest form, "-" when negative. CSSOM says at most 6 decimals; Chrome,
/// Firefox and Safari print 6 significant digits (getComputedStyle of
/// `font-size: 1.123456789em` at 16px reads "17.9753px" in all three), and
/// golden rule 2 follows them.
pub fn appendNumber(value: f64, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    if (std.math.isNan(value)) return out.appendSlice(allocator, "NaN");
    if (std.math.isInf(value)) return out.appendSlice(allocator, if (value > 0) "infinity" else "-infinity");
    if (value == 0) return out.append(allocator, '0');
    const magnitude = @abs(value);
    // Six significant digits, and never more than CSSOM's 6 decimals.
    const exponent: i32 = @intFromFloat(@floor(std.math.log10(magnitude)));
    const decimals: usize = @intCast(std.math.clamp(5 - exponent, 0, 6));
    // f64's largest finite value has 309 integer digits. Include sign and
    // all six fractional digits: finite overflow must never serialize as 0.
    var buffer: [320]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d:.[1]}", .{ value, decimals }) catch unreachable;
    var end = text.len;
    if (std.mem.indexOfScalar(u8, text, '.') != null) {
        while (end > 0 and text[end - 1] == '0') end -= 1;
        if (end > 0 and text[end - 1] == '.') end -= 1;
    }
    const trimmed = text[0..end];
    // "-0" after rounding is 0.
    if (std.mem.eql(u8, trimmed, "-0")) return out.append(allocator, '0');
    try out.appendSlice(allocator, trimmed);
}

/// A length as CSSOM serializes a <dimension>/<percentage>: the number,
/// then the unit.
pub fn appendLength(l: Length, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try appendNumber(l.value, out, allocator);
    try out.appendSlice(allocator, switch (l.unit) {
        .Q => "q",
        else => l.unit.toString(),
    });
}

/// CSSOM "serialize a string": `"`, each code point (escaped where it
/// must be), `"`.
pub fn appendString(text: []const u8, out: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try out.append(allocator, '"');
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        if (c == 0) {
            try out.appendSlice(allocator, "\u{FFFD}");
        } else if ((c >= 0x01 and c <= 0x1F) or c == 0x7F) {
            try out.print(allocator, "\\{x} ", .{c});
        } else if (c == '"' or c == '\\') {
            try out.append(allocator, '\\');
            try out.append(allocator, c);
        } else {
            try out.append(allocator, c);
        }
        i += 1;
    }
    try out.append(allocator, '"');
}

// ============================================================================
// Tests
// ============================================================================

fn expectNumber(expected: []const u8, value: f64) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try appendNumber(value, &out, std.testing.allocator);
    try std.testing.expectEqualStrings(expected, out.items);
}

test "numbers serialize in the shortest form, 6 significant digits" {
    try expectNumber("0", 0);
    try expectNumber("2", 2);
    try expectNumber("-3", -3);
    try expectNumber("0.5", 0.5);
    try expectNumber("14.2222", 14.222222);
    try expectNumber("17.9753", 17.97530862);
    try expectNumber("1234.57", 1234.5678);
    try expectNumber("0.333333", 1.0 / 3.0);
    try expectNumber("0", -0.0000001);
}

test "keywords round-trip their CSS spelling" {
    try std.testing.expectEqual(Keyword.inline_start, Keyword.parse("INLINE-START").?);
    try std.testing.expectEqualStrings("inline-start", Keyword.inline_start.name());
    try std.testing.expectEqualStrings("xxx-large", Keyword.xxx_large.name());
    try std.testing.expect(Keyword.parse("inline_start") == null);
    try std.testing.expectEqual(CssWide.revert_layer, CssWide.parse("Revert-Layer").?);
}

test "Display serializes its shortest form and blockifies per Display 4 2.7" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    const cases = [_]struct { Display, []const u8 }{
        .{ .{}, "inline" },
        .{ .{ .outer = .block }, "block" },
        .{ .{ .inner = .flow_root }, "inline-block" },
        .{ .{ .outer = .block, .inner = .flow_root }, "flow-root" },
        .{ .{ .outer = .block, .list_item = true }, "list-item" },
        .{ .{ .list_item = true }, "inline list-item" },
        .{ .{ .box = .internal, .internal = .table_cell }, "table-cell" },
        .{ .{ .inner = .ruby }, "ruby" },
        .{ Display.none, "none" },
    };
    for (cases) |case| {
        out.clearRetainingCapacity();
        try case[0].serialize(&out, std.testing.allocator);
        try std.testing.expectEqualStrings(case[1], out.items);
    }
    try std.testing.expect((Display{ .inner = .flow_root }).blockified().eql(Display.block_flow));
    try std.testing.expect((Display{ .inner = .flex }).blockified().eql(.{ .outer = .block, .inner = .flex }));
    try std.testing.expect((Display{ .box = .internal, .internal = .table_cell }).blockified().eql(Display.block_flow));
    try std.testing.expect(Display.none.blockified().eql(Display.none));
}

test "colors serialize as rgb() or rgba()" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    try serializeRgba(RgbaColor.rgb(255, 0, 0), &out, std.testing.allocator);
    try std.testing.expectEqualStrings("rgb(255, 0, 0)", out.items);
    out.clearRetainingCapacity();
    try serializeRgba(RgbaColor.transparent, &out, std.testing.allocator);
    try std.testing.expectEqualStrings("rgba(0, 0, 0, 0)", out.items);
    out.clearRetainingCapacity();
    try serializeRgba(RgbaColor.rgba(0, 0, 0, 0.5), &out, std.testing.allocator);
    try std.testing.expectEqualStrings("rgba(0, 0, 0, 0.5)", out.items);
}

test "SharedText counts, and an immortal one is never counted" {
    const text = try SharedText.create(std.testing.allocator, "serif");
    text.ref();
    text.unref();
    text.unref();
    const ua = try SharedText.create(std.testing.allocator, "monospace");
    ua.makeImmortal();
    ua.ref();
    ua.unref();
    ua.unref();
    ua.destroyImmortal();
}
