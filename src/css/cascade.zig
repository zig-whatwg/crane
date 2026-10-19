//! The cascade (CSS Cascade 5 sections 6-7) and the computed-value step
//! (section 4.4): from the declarations that apply to an element - each with
//! its origin, layer, specificity and position - and its parent's computed
//! style, the element's ComputedStyle.
//!
//! Priority is one u128, most significant first, in Blink's encoding
//! (core/css/resolver/cascade_priority.h): origin and importance (important
//! inverting the origins), tree context (important inverting it), the
//! element-attached flag, layer order (important inverting it), specificity,
//! and order of appearance. A longhand's cascaded value is the candidate
//! with the highest priority; `revert` and `revert-layer` discard candidates
//! and pick again (section 7.3).
//!
//! Logical longhands (CSS Logical 1) are mapped onto physical ones by the
//! element's writing-mode and direction, which cascade first - Blink's
//! "high priority" properties - so a logical and a physical declaration of
//! one side compete in one cascade.
//!
//! Computed values follow each property's "Computed value" line; the
//! adjustments between properties are CSS 2.1 9.7 (position, float and
//! display), CSS Display 4 2.7/2.8 (blockification), CSS Overflow 3
//! (visible/clip fix-up) and CSS Backgrounds 3 (a border with style none or
//! hidden has width 0).
//!
//! Stated: `revert-rule` (Cascade 5's newest keyword, which no browser ships)
//! acts as `revert-layer`; there is no user origin (Crane has no user style
//! sheets) and no animation or transition origin.
//!
//! Spec: https://drafts.csswg.org/css-cascade-5/#cascading
//! Spec: https://drafts.csswg.org/css-cascade-5/#defaulting

const std = @import("std");
const Allocator = std.mem.Allocator;
const properties = @import("properties.zig");
const values = @import("style_values.zig");
const declarations_mod = @import("declarations.zig");
const computed_mod = @import("computed_style.zig");

const Longhand = properties.Longhand;
const Value = values.Value;
const Keyword = values.Keyword;
const Length = values.Length;
const Display = values.Display;
const Declaration = declarations_mod.Declaration;
const DeclarationBlock = declarations_mod.DeclarationBlock;
pub const ComputedStyle = computed_mod.ComputedStyle;

/// Cascade 5 section 6.2, with HTML's author presentational hint origin
/// (section 6.5). Declared in ascending precedence of normal declarations.
pub const Origin = enum(u4) {
    user_agent = 1,
    user = 2,
    presentational_hint = 3,
    author = 4,

    /// "For the purpose of the revert keyword (but not for the revert-layer
    /// keyword) [presentational hints are] considered part of the author
    /// origin."
    fn revertClass(self: Origin) u4 {
        return switch (self) {
            .presentational_hint, .author => 4,
            else => @intFromEnum(self),
        };
    }
};

/// The implicit final layer of unlayered declarations.
pub const unlayered: u16 = std.math.maxInt(u16);

/// Where a block of declarations enters the cascade.
pub const Source = struct {
    origin: Origin,
    /// The layer's position in its origin's layer order; `unlayered` for
    /// declarations in no layer.
    layer: u16 = unlayered,
    /// The style rule's selector's specificity (Selectors 4 17: a, b, c).
    specificity: Specificity = .{},
    /// Order of appearance (section 6.1): later is greater.
    order: u32 = 0,
    /// A style attribute's declarations.
    element_attached: bool = false,
    /// Shadow-including tree context depth (batch 2; 0 is the document).
    tree_depth: u16 = 0,
};

pub const Specificity = struct {
    a: u32 = 0,
    b: u32 = 0,
    c: u32 = 0,

    fn packed30(self: Specificity) u128 {
        const max: u32 = 1023;
        return (@as(u128, @min(self.a, max)) << 20) | (@as(u128, @min(self.b, max)) << 10) | @min(self.c, max);
    }
};

/// One block of declarations that applies to the element.
pub const Matched = struct {
    block: *const DeclarationBlock,
    source: Source,
};

/// What computing values needs beyond the declarations.
pub const Context = struct {
    allocator: Allocator,
    /// The flat-tree parent's computed style; null for the root element.
    parent: ?*const ComputedStyle,
    /// The root element's computed font-size (rem); the initial 16px for
    /// the root itself.
    root_font_size: f64 = 16,
    /// The viewport (vw, vh).
    viewport_width: f64 = 1024,
    viewport_height: f64 = 768,
    /// The element is the root element (Display 4 2.8).
    is_root: bool = false,
};

const Candidate = struct {
    decl: *const Declaration,
    priority: u128,
    origin: Origin,
    layer: u16,
    important: bool,
};

/// Cascade 5 6.1's priority of a declaration from `source`.
fn priority(source: Source, important: bool) u128 {
    // Origin and importance: normal UA < user < hints < author < important
    // author < important user < important UA.
    const origin: u128 = if (important) 16 - @as(u128, @intFromEnum(source.origin)) else @intFromEnum(source.origin);
    // "When comparing two declarations that are sourced from different
    // encapsulation contexts, then for normal rules the declaration from the
    // outer context wins, and for important rules the declaration from the
    // inner context wins."
    const tree: u128 = if (important) source.tree_depth else 0xFFFF - @as(u128, source.tree_depth);
    // "declarations that are attached directly to an element ... take
    // precedence over declarations the same importance that are mapped via
    // style rule."
    const attached: u128 = @intFromBool(source.element_attached);
    // "for normal rules the declaration whose cascade layer is latest in the
    // layer order wins, and for important rules the declaration whose
    // cascade layer is earliest wins."
    const layer: u128 = if (important) 0xFFFF - @as(u128, source.layer) else source.layer;
    return (origin << 96) | (tree << 80) | (attached << 79) | (layer << 63) | (source.specificity.packed30() << 33) | source.order;
}

/// The cascade and the computed-value step for one element. The style is
/// the caller's (`destroy`).
pub fn cascade(ctx: Context, matched: []const Matched) Allocator.Error!*ComputedStyle {
    const allocator = ctx.allocator;
    var candidates: std.ArrayList(Candidate) = .empty;
    defer candidates.deinit(allocator);
    for (matched) |m| {
        var it = m.block.typed();
        while (it.next()) |d| {
            try candidates.append(allocator, .{
                .decl = d,
                .priority = priority(m.source, d.important),
                .origin = m.source.origin,
                .layer = m.source.layer,
                .important = d.important,
            });
        }
    }
    // Highest priority first.
    std.mem.sort(Candidate, candidates.items, {}, struct {
        fn lessThan(_: void, a: Candidate, b: Candidate) bool {
            return a.priority > b.priority;
        }
    }.lessThan);

    var builder: Builder = .{ .ctx = ctx, .candidates = candidates.items };
    const style = try allocator.create(ComputedStyle);
    style.* = .{ .allocator = allocator, .values = computed_mod.initial_values };
    // `initial_values` holds no counted text; every slot is overwritten
    // below, each holding its own reference.
    builder.style = style;
    errdefer style.destroy();
    try builder.run();
    return style;
}

const Builder = struct {
    ctx: Context,
    candidates: []const Candidate,
    style: *ComputedStyle = undefined,
    writing_mode: Keyword = .horizontal_tb,
    direction: Keyword = .ltr,

    fn parentValue(self: *const Builder, l: Longhand) Value {
        if (self.ctx.parent) |p| return p.get(l);
        return computed_mod.initialComputed(l);
    }

    /// The physical longhand a candidate's declaration sets, for this
    /// element's writing mode and direction.
    fn target(self: *const Builder, l: Longhand) Longhand {
        const lg = l.logical() orelse return l;
        return properties.physicalLonghand(lg.group, properties.physicalSide(lg.side, self.writing_mode, self.direction));
    }

    /// Cascade 5 sections 6-7.3: the specified value of physical longhand
    /// `l` - its cascaded value through `revert` and `revert-layer`, or its
    /// default. Borrowed (not retained).
    fn specified(self: *const Builder, l: Longhand) Specified {
        var excluded = Exclusions{};
        while (true) {
            const winner = self.pick(l, &excluded) orelse return self.defaulted(l);
            switch (winner.decl.value) {
                .value => |v| return .{ .value = v },
                .css_wide => |k| switch (k) {
                    .initial => return .{ .initial = {} },
                    .inherit => return .{ .inherit = {} },
                    .unset => return self.unset(l),
                    // "revert: ... user-agent origin: Equivalent to unset.
                    // ... author origin: Rolls back the cascaded value to the
                    // user level."
                    .revert => {
                        if (winner.origin == .user_agent) return self.unset(l);
                        excluded.revert_class_at_least = winner.origin.revertClass();
                    },
                    // "revert-layer: ... rolled back to the earlier layer, so
                    // that the specified value is calculated as if no rules
                    // were specified in the current cascade layer - or
                    // between its normal and important levels."
                    .revert_layer, .revert_rule => excluded.add(winner),
                },
            }
        }
    }

    fn unset(self: *const Builder, l: Longhand) Specified {
        _ = self;
        return if (l.inherited()) .{ .inherit = {} } else .{ .initial = {} };
    }

    fn defaulted(self: *const Builder, l: Longhand) Specified {
        return self.unset(l);
    }

    fn pick(self: *const Builder, l: Longhand, excluded: *const Exclusions) ?Candidate {
        for (self.candidates) |c| {
            if (self.target(c.decl.longhand) != l) continue;
            if (excluded.excludes(c)) continue;
            return c;
        }
        return null;
    }

    fn run(self: *Builder) Allocator.Error!void {
        // The high-priority longhands: the mapping of logical ones, then
        // font-size (em), then color (currentcolor).
        self.writing_mode = (try self.computeAndStore(.writing_mode)).keyword;
        self.direction = (try self.computeAndStore(.direction)).keyword;
        _ = try self.computeAndStore(.font_size);
        _ = try self.computeAndStore(.color);
        for (0..Longhand.count) |i| {
            const l: Longhand = @enumFromInt(i);
            if (l.logical() != null) continue;
            switch (l) {
                .writing_mode, .direction, .font_size, .color => continue,
                else => {},
            }
            _ = try self.computeAndStore(l);
        }
        self.adjust();
        // A logical longhand reads the physical one it maps to.
        for (0..Longhand.count) |i| {
            const l: Longhand = @enumFromInt(i);
            if (l.logical() == null) continue;
            const v = self.style.values[@intFromEnum(self.target(l))];
            v.retain();
            self.style.values[i] = v;
        }
    }

    /// Compute `l` and store it (holding its own reference).
    fn computeAndStore(self: *Builder, l: Longhand) Allocator.Error!Value {
        const v = try self.compute(l, self.specified(l));
        self.style.values[@intFromEnum(l)] = v;
        return v;
    }

    /// Section 4.4: the computed value of `l` from its specified value.
    /// The result holds a reference.
    fn compute(self: *Builder, l: Longhand, spec: Specified) Allocator.Error!Value {
        const v: Value = switch (spec) {
            // "inherit: the property's specified and computed values are the
            // inherited value."
            .inherit => {
                const p = self.parentValue(l);
                p.retain();
                return p;
            },
            .initial => computed_mod.initialComputed(l),
            .value => |v| v,
        };
        return self.computeValue(l, v);
    }

    fn fontSize(self: *const Builder) f64 {
        return self.style.values[@intFromEnum(Longhand.font_size)].length.value;
    }

    fn computeValue(self: *Builder, l: Longhand, v: Value) Allocator.Error!Value {
        switch (l) {
            .font_size => return Value.px(self.computeFontSize(v)),
            .font_weight => return .{ .number = self.computeFontWeight(v) },
            // CSS Color 4 6.4: "if currentcolor is the specified value of
            // the color property, it is treated as if it were inherit."
            .color => if (v == .color) switch (v.color) {
                .current => {
                    const p = self.parentValue(.color);
                    p.retain();
                    return p;
                },
                .named => |n| return .{ .color = .{ .rgba = n.rgba } },
                .rgba => {},
            },
            .opacity => return .{ .number = std.math.clamp(v.number, 0, 1) },
            // A named or system color computes to its color.
            .background_color, .border_top_color, .border_right_color, .border_bottom_color, .border_left_color => if (v == .color and v.color == .named) {
                return .{ .color = .{ .rgba = v.color.named.rgba } };
            },
            .line_height => switch (v) {
                .length => |len| if (len.unit == .percent) return Value.px(len.value / 100 * self.fontSize()),
                else => {},
            },
            .border_top_width, .border_right_width, .border_bottom_width, .border_left_width => {
                const px: f64 = switch (v) {
                    .keyword => |k| switch (k) {
                        .thin => 1,
                        .thick => 5,
                        else => 3,
                    },
                    .length => |len| self.absolute(len),
                    else => 0,
                };
                return Value.px(snapBorderWidth(px));
            },
            else => {},
        }
        switch (v) {
            .length => |len| {
                if (len.unit == .percent) return v;
                return Value.px(self.absolute(len));
            },
            else => {
                v.retain();
                return v;
            },
        }
    }

    /// CSS Values 4 section 6: a length's absolute value, in px, its em
    /// the element's own font size.
    fn absolute(self: *const Builder, len: Length) f64 {
        return self.absoluteWith(len, self.fontSize());
    }

    /// A length's absolute value with `em` as the font size its
    /// font-relative units read. ex and ch have no font metrics to read:
    /// "it must be assumed to be 0.5em". lh and rlh take `normal`'s
    /// customary 1.2 (stated).
    fn absoluteWith(self: *const Builder, len: Length, em: f64) f64 {
        return switch (len.unit) {
            .px => len.value,
            .cm => len.value * 96.0 / 2.54,
            .mm => len.value * 96.0 / 25.4,
            .Q => len.value * 96.0 / 101.6,
            .in => len.value * 96.0,
            .pt => len.value * 96.0 / 72.0,
            .pc => len.value * 16.0,
            .em => len.value * em,
            .rem => len.value * self.ctx.root_font_size,
            .ex, .ch => len.value * em * 0.5,
            .lh => len.value * em * 1.2,
            .rlh => len.value * self.ctx.root_font_size * 1.2,
            .vw, .vi => len.value * self.ctx.viewport_width / 100,
            .vh, .vb => len.value * self.ctx.viewport_height / 100,
            .vmin => len.value * @min(self.ctx.viewport_width, self.ctx.viewport_height) / 100,
            .vmax => len.value * @max(self.ctx.viewport_width, self.ctx.viewport_height) / 100,
            .percent => len.value * em / 100,
        };
    }

    /// CSS Fonts 4 2.5 font-size, against the parent's computed size. The
    /// absolute-size table is the browsers' (Chrome, Firefox and Safari all
    /// answer 9/10/13/16/18/24/32/48px at a medium of 16px), and larger /
    /// smaller scale by their 1.2.
    fn computeFontSize(self: *const Builder, v: Value) f64 {
        const parent = self.parentValue(.font_size).length.value;
        return switch (v) {
            .keyword => |k| switch (k) {
                .xx_small => 9,
                .x_small => 10,
                .small => 13,
                .medium => 16,
                .large => 18,
                .x_large => 24,
                .xx_large => 32,
                .xxx_large => 48,
                .larger => parent * 1.2,
                .smaller => parent / 1.2,
                else => 16,
            },
            // "Percentages: refer to parent element's font size"; em and ex
            // likewise refer to the parent's font.
            .length => |len| self.absoluteWith(len, parent),
            else => parent,
        };
    }

    /// CSS Fonts 4 2.4: normal and bold are 400 and 700; bolder and
    /// lighter are relative to the inherited weight, by its table.
    fn computeFontWeight(self: *const Builder, v: Value) f64 {
        const inherited = self.parentValue(.font_weight).number;
        return switch (v) {
            .number => |n| n,
            .keyword => |k| switch (k) {
                .normal => 400,
                .bold => 700,
                .bolder => if (inherited < 350) 400 else if (inherited < 550) 700 else if (inherited < 900) 900 else inherited,
                .lighter => if (inherited < 100) inherited else if (inherited < 550) 100 else if (inherited < 750) 400 else 700,
                else => 400,
            },
            else => 400,
        };
    }

    /// The adjustments between computed values.
    fn adjust(self: *Builder) void {
        const s = self.style;
        // CSS 2.1 9.7: "if position has the value absolute or fixed, ... the
        // computed value of float is none, and display is set according to
        // the table below" - blockified (Display 4 2.7).
        const position = s.keyword(.position);
        const out_of_flow = position == .absolute or position == .fixed;
        if (out_of_flow) s.values[@intFromEnum(Longhand.float)] = Value.kw(.none);
        const floated = s.keyword(.float) != .none;
        var display = s.display();
        // "A parent with a grid or flex display value blockifies the box's
        // display type."
        const parent_blockifies = if (self.ctx.parent) |p| blk: {
            const pd = p.display();
            break :blk pd.box == .normal and (pd.inner == .flex or pd.inner == .grid);
        } else false;
        if (self.ctx.is_root or out_of_flow or floated or parent_blockifies) display = display.blockified();
        // Display 4 2.8: "a display of contents computes to block on the root
        // element."
        if (self.ctx.is_root and display.box == .contents) display = Display.block_flow;
        s.values[@intFromEnum(Longhand.display)] = .{ .display = display };

        // CSS Overflow 3: "as specified, except with visible/clip computing
        // to auto/hidden (respectively) if one of overflow-x or overflow-y is
        // neither visible nor clip."
        const ox = s.keyword(.overflow_x);
        const oy = s.keyword(.overflow_y);
        const x_plain = ox == .visible or ox == .clip;
        const y_plain = oy == .visible or oy == .clip;
        if (!x_plain or !y_plain) {
            s.values[@intFromEnum(Longhand.overflow_x)] = Value.kw(fixOverflow(ox));
            s.values[@intFromEnum(Longhand.overflow_y)] = Value.kw(fixOverflow(oy));
        }

        // CSS Backgrounds 3 border-width: "absolute length, snapped as a
        // border width; zero if the border style is none or hidden."
        const sides = [_][2]Longhand{
            .{ .border_top_style, .border_top_width },
            .{ .border_right_style, .border_right_width },
            .{ .border_bottom_style, .border_bottom_width },
            .{ .border_left_style, .border_left_width },
        };
        for (sides) |pair| {
            const style_kw = s.keyword(pair[0]);
            if (style_kw == .none or style_kw == .hidden) s.values[@intFromEnum(pair[1])] = Value.px(0);
        }
    }
};

fn fixOverflow(k: Keyword) Keyword {
    return switch (k) {
        .visible => .auto,
        .clip => .hidden,
        else => k,
    };
}

/// CSS Values 4 "snap as a border width" at a device pixel ratio of 1: a
/// width between 0 and 1px is 1px, a larger one is floored.
fn snapBorderWidth(px: f64) f64 {
    if (px <= 0) return 0;
    if (px < 1) return 1;
    return @floor(px);
}

const Specified = union(enum) {
    value: Value,
    initial,
    inherit,
};

const Exclusions = struct {
    /// Candidates of this revert class or later are discarded (`revert`).
    revert_class_at_least: u4 = 15,
    /// (origin, layer, important) levels `revert-layer` discarded.
    layers: [8]Level = undefined,
    count: usize = 0,

    const Level = struct { origin: Origin, layer: u16, important: bool };

    fn add(self: *Exclusions, c: Candidate) void {
        if (self.count == self.layers.len) {
            // Deeper than any real chain: discard the whole origin.
            self.revert_class_at_least = @min(self.revert_class_at_least, c.origin.revertClass());
            return;
        }
        self.layers[self.count] = .{ .origin = c.origin, .layer = c.layer, .important = c.important };
        self.count += 1;
    }

    fn excludes(self: *const Exclusions, c: Candidate) bool {
        if (c.origin.revertClass() >= self.revert_class_at_least) return true;
        for (self.layers[0..self.count]) |lv| {
            if (lv.origin != c.origin or lv.layer != c.layer) continue;
            // An important level's revert-layer also passes the normal
            // declarations of its layer.
            if (lv.important or !c.important) return true;
        }
        return false;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

const TestBlock = struct {
    block: DeclarationBlock,

    fn make(text: []const u8) !TestBlock {
        return .{ .block = try DeclarationBlock.parse(.{ .allocator = testing.allocator }, text) };
    }

    fn deinit(self: *TestBlock) void {
        self.block.deinit();
    }
};

fn resolved(style: *const ComputedStyle, l: Longhand) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    try style.serializeResolved(l, &out, testing.allocator);
    return out.toOwnedSlice(testing.allocator);
}

fn expectResolved(style: *const ComputedStyle, l: Longhand, expected: []const u8) !void {
    const text = try resolved(style, l);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
}

test "origin and importance: author over UA, important UA over everything" {
    var ua = try TestBlock.make("color: red; display: block; margin-left: 1px !important");
    defer ua.deinit();
    var author = try TestBlock.make("color: blue; margin-left: 5px");
    defer author.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &author.block, .source = .{ .origin = .author, .order = 2 } },
        .{ .block = &ua.block, .source = .{ .origin = .user_agent, .order = 1 } },
    });
    defer style.destroy();
    try expectResolved(style, .color, "rgb(0, 0, 255)");
    try expectResolved(style, .display, "block");
    try expectResolved(style, .margin_left, "1px");
}

test "specificity, then order of appearance, then the style attribute" {
    var a = try TestBlock.make("color: red; width: 1px");
    defer a.deinit();
    var b = try TestBlock.make("color: green; width: 2px");
    defer b.deinit();
    var attr = try TestBlock.make("width: 3px");
    defer attr.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &a.block, .source = .{ .origin = .author, .specificity = .{ .a = 1 }, .order = 1 } },
        .{ .block = &b.block, .source = .{ .origin = .author, .specificity = .{ .b = 5 }, .order = 2 } },
        .{ .block = &attr.block, .source = .{ .origin = .author, .element_attached = true, .order = 0 } },
    });
    defer style.destroy();
    try expectResolved(style, .color, "rgb(255, 0, 0)");
    try expectResolved(style, .width, "3px");
}

test "layers: later layers win for normal, earlier for important, unlayered last" {
    var first = try TestBlock.make("color: red; width: 1px !important");
    defer first.deinit();
    var second = try TestBlock.make("color: green; width: 2px !important");
    defer second.deinit();
    var plain = try TestBlock.make("margin-top: 7px");
    defer plain.deinit();
    var layered = try TestBlock.make("margin-top: 9px");
    defer layered.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &first.block, .source = .{ .origin = .author, .layer = 0, .order = 1 } },
        .{ .block = &second.block, .source = .{ .origin = .author, .layer = 1, .order = 2 } },
        .{ .block = &plain.block, .source = .{ .origin = .author, .order = 3 } },
        .{ .block = &layered.block, .source = .{ .origin = .author, .layer = 1, .order = 4, .specificity = .{ .a = 9 } } },
    });
    defer style.destroy();
    try expectResolved(style, .color, "rgb(0, 128, 0)");
    try expectResolved(style, .width, "1px");
    try expectResolved(style, .margin_top, "7px");
}

test "inheritance and the CSS-wide keywords" {
    var parent_block = try TestBlock.make("color: red; margin-left: 4px; font-size: 20px");
    defer parent_block.deinit();
    const parent = try cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &parent_block.block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try TestBlock.make("margin-left: inherit; font-size: 2em; width: 1em; visibility: initial");
    defer child_block.deinit();
    const child = try cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block.block, .source = .{ .origin = .author } }});
    defer child.destroy();
    try expectResolved(child, .color, "rgb(255, 0, 0)");
    try expectResolved(child, .margin_left, "4px");
    try expectResolved(child, .font_size, "40px");
    try expectResolved(child, .width, "40px");
    try expectResolved(child, .visibility, "visible");
    try expectResolved(parent, .display, "block");
}

test "revert rolls back to the UA origin; revert-layer to the earlier layer" {
    var ua = try TestBlock.make("display: block; color: red");
    defer ua.deinit();
    var low = try TestBlock.make("color: green");
    defer low.deinit();
    var high = try TestBlock.make("display: revert; color: revert-layer");
    defer high.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &ua.block, .source = .{ .origin = .user_agent } },
        .{ .block = &low.block, .source = .{ .origin = .author, .layer = 0, .order = 1 } },
        .{ .block = &high.block, .source = .{ .origin = .author, .layer = 1, .order = 2 } },
    });
    defer style.destroy();
    try expectResolved(style, .display, "block");
    try expectResolved(style, .color, "rgb(0, 128, 0)");
}

test "logical longhands map by writing mode and direction and cascade with physical ones" {
    var block = try TestBlock.make("margin-inline-start: 5px; margin-left: 3px; direction: rtl; padding-block: 2px");
    defer block.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block.block, .source = .{ .origin = .author } }});
    defer style.destroy();
    // In rtl, inline-start is the right side.
    try expectResolved(style, .margin_right, "5px");
    try expectResolved(style, .margin_left, "3px");
    try expectResolved(style, .margin_inline_start, "5px");
    try expectResolved(style, .padding_top, "2px");
    try expectResolved(style, .padding_bottom, "2px");
}

test "computed adjustments: blockification, float, overflow, border widths" {
    var block = try TestBlock.make("display: inline-block; position: absolute; float: left; overflow-x: hidden; border-top: 2.5px solid; border-left-width: 0.5px; border-left-style: solid; border-right-width: 9px");
    defer block.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block.block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try expectResolved(style, .display, "block");
    try expectResolved(style, .float, "none");
    try expectResolved(style, .overflow_y, "auto");
    try expectResolved(style, .border_top_width, "2px");
    try expectResolved(style, .border_left_width, "1px");
    try expectResolved(style, .border_right_width, "0px");
}

test "values compute: font-size keywords, line-height, colors, opacity, rem" {
    var block = try TestBlock.make("font-size: small; line-height: 1.5; border-top-color: currentcolor; color: lime; opacity: 2; margin-top: 2rem; font-weight: bolder");
    defer block.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null, .root_font_size = 10 }, &.{.{ .block = &block.block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try expectResolved(style, .font_size, "13px");
    try expectResolved(style, .line_height, "19.5px");
    try expectResolved(style, .border_top_color, "rgb(0, 255, 0)");
    try expectResolved(style, .opacity, "1");
    try expectResolved(style, .margin_top, "20px");
    try expectResolved(style, .font_weight, "700");
}

test "a flex container blockifies its children" {
    var parent_block = try TestBlock.make("display: inline-flex");
    defer parent_block.deinit();
    const parent = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block.block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try TestBlock.make("display: inline");
    defer child_block.deinit();
    const child = try cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block.block, .source = .{ .origin = .author } }});
    defer child.destroy();
    try expectResolved(child, .display, "block");
}

test "text values are shared, not leaked" {
    var block = try TestBlock.make("font-family: \"A B\", serif; background-image: url(x.png)");
    defer block.deinit();
    const parent = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block.block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
    defer child.destroy();
    try expectResolved(child, .font_family, "\"A B\", serif");
    try expectResolved(child, .background_image, "none");
}

test "color-scheme is inherited and computes as specified" {
    var parent_block = try TestBlock.make("color-scheme: only dark Purple");
    defer parent_block.deinit();
    const parent = try cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &parent_block.block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    try expectResolved(parent, .color_scheme, "dark Purple only");
    const child = try cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{});
    defer child.destroy();
    try expectResolved(child, .color_scheme, "dark Purple only");
    var reset_block = try TestBlock.make("color-scheme: initial");
    defer reset_block.deinit();
    const reset = try cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &reset_block.block, .source = .{ .origin = .author } }});
    defer reset.destroy();
    try expectResolved(reset, .color_scheme, "normal");
}
