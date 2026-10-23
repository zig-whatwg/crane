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
const color_scheme_mod = @import("color_scheme.zig");

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

/// Plain identity for the tree scope where a value was declared. Zero is
/// the document scope; this never holds a DOM object or a borrowed pointer.
pub const TreeScopeRef = struct {
    serial: u64 = 0,
};

/// The declaration metadata a computed value may need. Copy this out of
/// candidates; their Source pointers are borrowed only during cascade().
pub const ValueSource = struct {
    tree_scope: TreeScopeRef = .{},
    tree_count_allowed: bool = true,
};

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
    /// Whether this declaration may use Values 5 tree-counting inputs.
    tree_count_allowed: bool = true,
    tree_scope: TreeScopeRef = .{},
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
    /// Content 3 / Values 5: synchronous, never saved in a computed value.
    content_attributes: ?@import("generated_content.zig").AttributeLookup = null,
    pseudo: ?[]const u8 = null,
    /// Q83: absent random input skips the candidate at the same availability
    /// boundary as missing metrics. Real DOM resolution supplies this lazily.
    random_base: ?@import("random_values.zig").Provider = null,
    /// Borrowed and called at most once, only for a tree-dependent value.
    tree_counts: ?struct { context: *anyopaque, get: *const fn (*anyopaque) @import("math_values.zig").TreeCounts } = null,
    /// The root element's computed font-size (rem); the initial 16px for
    /// the root itself.
    root_font_size: f64 = 16,
    root_line_height: ?f64 = null,
    root_vertical: bool = false,
    root_upright: bool = false,
    /// The viewport (vw, vh).
    viewport_width: f64 = 1024,
    viewport_height: f64 = 768,
    /// The element is the root element (Display 4 2.8).
    is_root: bool = false,
    /// CSS Color Adjustment 1 2.1, the page color scheme: the used color
    /// scheme of the page's supported color schemes - an element whose
    /// color-scheme is `normal` has it.
    page_color_scheme: color_scheme_mod.Scheme = .light,
    /// The user's preferred color scheme (the host's, as prefers-color-scheme
    /// reports it).
    preferred_color_scheme: color_scheme_mod.Scheme = .light,
};

const Candidate = struct {
    decl: *const Declaration,
    priority: u128,
    /// Borrowed from the caller's stable Matched slice. Candidates never
    /// escape the synchronous cascade or enter an owned computed value.
    source: *const Source,
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

/// The caller finishes appending matched batches before this call, and
/// keeps the slice and declaration blocks immutable until cascade returns.
/// Like Blink's MatchResult/CascadeMap, candidates refer back to their
/// matched declarations rather than duplicating all source data per property.
fn collectCandidates(allocator: Allocator, matched: []const Matched) Allocator.Error!std.ArrayList(Candidate) {
    var candidates: std.ArrayList(Candidate) = .empty;
    errdefer candidates.deinit(allocator);
    for (matched) |*m| {
        std.debug.assert(@intFromPtr(&m.source) >= @intFromPtr(matched.ptr));
        std.debug.assert(@intFromPtr(&m.source) + @sizeOf(Source) <= @intFromPtr(matched.ptr) + matched.len * @sizeOf(Matched));
        var it = m.block.typed();
        while (it.next()) |d| {
            try candidates.append(allocator, .{
                .decl = d,
                .priority = priority(m.source, d.important),
                .source = &m.source,
            });
        }
    }
    // Both pointers identify ordered positions in stable contiguous slices:
    // Source in Matched, and Declaration in its block's Entry array (typed()
    // iterates forwards). They give the original insertion order without an
    // extra field, keeping Candidate at 32 bytes. No address escapes cascade.
    // This total order also avoids block sort's 512-candidate stack buffer.
    std.mem.sortUnstable(Candidate, candidates.items, {}, struct {
        fn lessThan(_: void, a: Candidate, b: Candidate) bool {
            // Cascade 5 §6.1: the last declaration wins, including two
            // declarations in one block that map to the same physical slot.
            if (a.priority != b.priority) return a.priority > b.priority;
            if (a.source != b.source) return @intFromPtr(a.source) > @intFromPtr(b.source);
            return @intFromPtr(a.decl) > @intFromPtr(b.decl);
        }
    }.lessThan);
    return candidates;
}

/// Cascade 5 §§6–7.3: a property owns a priority-ordered fallback chain.
/// Like Blink's CascadeMap and WebKit's PropertyCascade, lookup starts at
/// that property's head. Candidate order and borrowed Source identity stay
/// unchanged; the separate links keep Candidate at 32 bytes.
const CandidateIndex = struct {
    const none = std.math.maxInt(usize);
    heads: [Longhand.count]usize = @splat(none),
    links: []usize,

    fn init(candidates: []const Candidate, links: []usize) CandidateIndex {
        std.debug.assert(candidates.len == links.len);
        var index: CandidateIndex = .{ .links = links };
        // Candidates are already strongest-first. Prepending backwards
        // preserves that order, including equal-priority declarations.
        var i = candidates.len;
        while (i > 0) {
            i -= 1;
            const property = @intFromEnum(candidates[i].decl.longhand);
            links[i] = index.heads[property];
            index.heads[property] = i;
        }
        return index;
    }

    /// Logical 1 §4: merge a logical chain into its mapped physical chain
    /// only after writing-mode and direction have computed. Global sorted
    /// positions are sufficient to merge without recalculating priorities.
    fn merge(self: *CandidateIndex, logical: Longhand, physical: Longhand) void {
        var a = self.heads[@intFromEnum(logical)];
        if (a == none) return;
        self.heads[@intFromEnum(logical)] = none;
        var b = self.heads[@intFromEnum(physical)];
        var destination = &self.heads[@intFromEnum(physical)];
        while (a != none and b != none) {
            const use_a = a < b;
            const chosen = if (use_a) a else b;
            const next = self.links[chosen];
            destination.* = chosen;
            destination = &self.links[chosen];
            if (use_a) a = next else b = next;
        }
        destination.* = if (a != none) a else b;
    }
};

/// The cascade and the computed-value step for one element. The style is
/// the caller's (`destroy`). Matched blocks must remain stable for this call.
pub fn cascade(ctx: Context, matched: []const Matched) Allocator.Error!*ComputedStyle {
    const allocator = ctx.allocator;
    var candidates = try collectCandidates(allocator, matched);
    defer candidates.deinit(allocator);
    var stack_links: [64]usize = undefined;
    const links = if (candidates.items.len <= stack_links.len)
        stack_links[0..candidates.items.len]
    else
        try allocator.alloc(usize, candidates.items.len);
    defer if (links.len > stack_links.len) allocator.free(links);
    var builder: Builder = .{
        .ctx = ctx,
        .candidates = candidates.items,
        .index = CandidateIndex.init(candidates.items, links),
    };
    defer builder.deinit();
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
    index: CandidateIndex,
    style: *ComputedStyle = undefined,
    writing_mode: Keyword = .horizontal_tb,
    direction: Keyword = .ltr,
    /// The element color scheme, once color-scheme is computed.
    used_scheme: color_scheme_mod.Scheme = .light,
    cached_tree_counts: ?@import("math_values.zig").TreeCounts = null,
    pending: std.ArrayList(PendingResult) = .empty,

    const PendingResult = struct {
        value: *const @import("pending_values.zig").Pending,
        source: ValueSource,
        outcome: @import("pending_values.zig").Outcome,
    };
    fn deinit(self: *Builder) void {
        for (self.pending.items) |entry| entry.outcome.deinit(self.ctx.allocator);
        self.pending.deinit(self.ctx.allocator);
    }
    fn resolvePending(self: *Builder, c: Candidate, l: Longhand) Allocator.Error!struct { assigned: properties.Assigned, unavailable: bool = false } {
        if (c.decl.value != .value or c.decl.value.value != .pending) return .{ .assigned = c.decl.value };
        const pending = c.decl.value.value.pending;
        const source = ValueSource{ .tree_scope = c.source.tree_scope, .tree_count_allowed = c.source.tree_count_allowed };
        var found: ?usize = null;
        for (self.pending.items, 0..) |entry, index| if (entry.value == pending and std.meta.eql(entry.source, source)) {
            found = index;
            break;
        };
        const index = found orelse blk: {
            // Pending key math may need counts; the selected assignment's
            // normal dependency query still runs below after substitution.
            var context = self.mathContext(l);
            if (!source.tree_count_allowed) context.tree_counts = .{ .index = 0, .count = 0 } else context.tree_count_provider = .{ .context = self, .get = pendingTreeCounts };
            const outcome = try pending.resolve(self.ctx.allocator, context);
            errdefer outcome.deinit(self.ctx.allocator);
            const at = self.pending.items.len;
            try self.pending.append(self.ctx.allocator, .{ .value = pending, .source = source, .outcome = outcome });
            break :blk at;
        };
        return switch (self.pending.items[index].outcome) {
            .invalid => .{ .assigned = .{ .css_wide = .unset } },
            .unavailable => .{ .assigned = .{ .css_wide = .unset }, .unavailable = true },
            .resolved => |assignments| blk: {
                for (assignments) |assignment| if (assignment.longhand == c.decl.longhand) break :blk .{ .assigned = assignment.value };
                break :blk .{ .assigned = .{ .css_wide = .unset } };
            },
        };
    }

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
    fn specified(self: *Builder, l: Longhand) Allocator.Error!Specified {
        var excluded = Exclusions{};
        while (true) {
            const picked = (try self.pick(l, &excluded)) orelse return self.defaulted(l);
            const winner = picked.candidate;
            switch (picked.assigned) {
                .value => |v| return .{ .value = .{ .value = v, .source = .{
                    .tree_scope = winner.source.tree_scope,
                    .tree_count_allowed = winner.source.tree_count_allowed,
                } } },
                .css_wide => |k| switch (k) {
                    .initial => return .{ .initial = {} },
                    .inherit => return .{ .inherit = {} },
                    .unset => return self.unset(l),
                    // "revert: ... user-agent origin: Equivalent to unset.
                    // ... author origin: Rolls back the cascaded value to the
                    // user level."
                    .revert => {
                        if (winner.source.origin == .user_agent) return self.unset(l);
                        excluded.revert_class_at_least = winner.source.origin.revertClass();
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

    fn pick(self: *Builder, l: Longhand, excluded: *const Exclusions) Allocator.Error!?struct { candidate: Candidate, assigned: properties.Assigned } {
        var position = self.index.heads[@intFromEnum(l)];
        while (position != CandidateIndex.none) : (position = self.index.links[position]) {
            const c = self.candidates[position];
            if (excluded.excludes(c)) continue;
            // Q17/Q23–25: unavailable cap-height/ascent cannot enter scalar
            // consumers. Only geometry lengths may remain unresolved; the
            // next retained candidate/default wins, with no hidden CSSOM history.
            const preflight = try self.resolvePending(c, l);
            const assigned = preflight.assigned;
            const geometry_length = switch (l.info().grammar) {
                .length_percentage_auto, .length_percentage_nonneg, .size, .max_size, .line_width, .gap, .signed_length, .fit_tolerance => true,
                else => false,
            };
            // Q25/Q83/Q88: this is the single unavailable-input decision,
            // after pending substitution has selected just its live branch.
            const unavailable = preflight.unavailable or (assigned == .value and
                (assigned.value.needsUnavailableMetrics(geometry_length) or
                    (self.ctx.random_base == null and assigned.value.needsRandomBase())));
            if (unavailable) continue;
            return .{ .candidate = c, .assigned = assigned };
        }
        return null;
    }

    fn mapLogicalChains(self: *Builder) void {
        for (0..Longhand.count) |i| {
            const l: Longhand = @enumFromInt(i);
            if (self.index.heads[i] == CandidateIndex.none or l.logical() == null) continue;
            self.index.merge(l, self.target(l));
        }
    }

    fn run(self: *Builder) Allocator.Error!void {
        // The high-priority longhands: the mapping of logical ones, then
        // color-scheme (what every system color resolves against - Blink
        // applies it before color too), then font-size (em), then color
        // (currentcolor).
        self.writing_mode = (try self.computeAndStore(.writing_mode)).keyword;
        self.direction = (try self.computeAndStore(.direction)).keyword;
        self.mapLogicalChains();
        _ = try self.computeAndStore(.text_orientation);
        self.used_scheme = self.elementColorScheme(try self.computeAndStore(.color_scheme));
        self.style.used_color_scheme = self.used_scheme;
        _ = try self.computeAndStore(.font_size);
        _ = try self.computeAndStore(.line_height);
        _ = try self.computeAndStore(.color);
        for (0..Longhand.count) |i| {
            const l: Longhand = @enumFromInt(i);
            if (l.logical() != null) continue;
            switch (l) {
                .writing_mode, .direction, .text_orientation, .color_scheme, .font_size, .line_height, .color => continue,
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

    /// CSS Color Adjustment 1 2.2, the element color scheme of a computed
    /// color-scheme: `normal` is the page color scheme; any other value is
    /// the used color scheme of the color scheme support it names, given
    /// the user's preference (2.3). An inherited value is the parent's, and
    /// so is its result (Blink's ColorScheme::ApplyInherit copies it).
    fn elementColorScheme(self: *const Builder, v: Value) color_scheme_mod.Scheme {
        return switch (v) {
            .color_scheme => |c| color_scheme_mod.used(c.support, self.ctx.preferred_color_scheme),
            else => self.ctx.page_color_scheme,
        };
    }

    /// Compute `l` and store it (holding its own reference).
    fn computeAndStore(self: *Builder, l: Longhand) Allocator.Error!Value {
        const v = try self.compute(l, try self.specified(l));
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
                // The root's color has no parent to inherit from: "the
                // inherited value is the initial value" (Cascade 5 7.3.2),
                // CanvasText in the root's own color scheme.
                if (self.ctx.parent == null and l == .color) return self.computeValue(l, l.info().initial, .{});
                const p = self.parentValue(l);
                p.retain();
                return p;
            },
            // color's initial value, CanvasText, is resolved in the
            // element's color scheme (Chrome 151 and Safari 27.0.1 answer
            // white for `color: initial` under `only dark`; Firefox 144
            // black).
            .initial => if (l == .color or l == .justify_items) l.info().initial else computed_mod.initialComputed(l),
            .value => |v| v.value,
        };
        const source: ValueSource = switch (spec) {
            .value => |specified_value| specified_value.source,
            .initial, .inherit => .{},
        };
        return self.computeValue(l, v, source);
    }

    fn fontSize(self: *const Builder) f64 {
        return self.style.values[@intFromEnum(Longhand.font_size)].length.value;
    }

    fn computeValue(self: *Builder, l: Longhand, v: Value, source: ValueSource) Allocator.Error!Value {
        if (v == .animation_list) return .{ .animation_list = try v.animation_list.compute(self.ctx.allocator, self.computationContext(l, v, source)) };
        if (v == .transform) return .{ .transform = try v.transform.compute(self.ctx.allocator, self.computationContext(l, v, source)) };
        if (v == .grid_line) return .{ .grid_line = try v.grid_line.compute(self.ctx.allocator, self.computationContext(l, v, source)) };
        if (v == .grid_tracks) return .{ .grid_tracks = try v.grid_tracks.compute(self.ctx.allocator, self.computationContext(l, v, source)) };
        if (v == .caret_pair) return .{ .caret_pair = try v.caret_pair.compute(self.ctx.allocator, .{
            .scheme = self.used_scheme,
            .math = self.computationContext(l, v, source),
        }) };
        if (v == .color) {
            // Color4 §6.4: currentcolor in color inherits. Every other
            // destination keeps it symbolic until the receiving element
            // resolves the value, including nested expression origins.
            var root_color: ?values.Color = null;
            defer if (root_color) |color| color.release();
            const current: ?values.Color = if (l != .color) null else if (self.ctx.parent) |parent|
                parent.get(.color).color
            else blk: {
                // Cascade5 §7.3.2: the root inherits its initial color in
                // its own scheme, including a nested currentcolor origin.
                root_color = try l.info().initial.color.resolveComputed(self.ctx.allocator, .{ .scheme = self.used_scheme });
                break :blk root_color;
            };
            return .{ .color = try v.color.resolveComputed(self.ctx.allocator, .{
                .scheme = self.used_scheme,
                .current = current,
                .math = self.computationContext(l, v, source),
            }) };
        }

        if (v == .sizing_function) {
            const argument = try self.computeValue(l, v.sizing_function.argument, source);
            errdefer argument.release();
            return .{ .sizing_function = try values.SizingFunction.create(self.ctx.allocator, argument) };
        }
        if (v == .alignment) {
            const parent = if (self.ctx.parent) |p| p.get(l) else null;
            return .{ .alignment = v.alignment.computed(if (parent) |p| if (p == .alignment) p.alignment else null else null) };
        }
        if (v == .position_area) return .{ .position_area = v.position_area.computed() };
        if (v == .try_fallbacks) {
            v.retain();
            return .{ .try_fallbacks = .{ .list = v.try_fallbacks.list, .computed = true } };
        }
        if (v == .calculation) {
            const expression = try v.calculation.compute(self.ctx.allocator, self.computationContext(l, v, source));
            if (expression.computedNumber()) |number| {
                defer expression.unref();
                const scalar: Value = switch (number.unit) {
                    .number => if (expression.grammar.kind == .integer)
                        .{ .integer = @intFromFloat(number.value) }
                    else
                        .{ .number = number.value },
                    .px => Value.px(number.value),
                    .percent => .{ .length = Length.percent(number.value) },
                    else => {
                        // No scalar longhand currently consumes other dimensions.
                        expression.ref();
                        return .{ .calculation = expression };
                    },
                };
                return self.computeValue(l, scalar, source);
            }
            return .{ .calculation = expression };
        }
        if (l == .outline_width) {
            // UI 4 §3.4 computes width independently of outline-style:none.
            const px: f64 = switch (v) {
                .keyword => |k| switch (k) {
                    .thin => 1,
                    .thick => 5,
                    else => 3,
                },
                .length => |len| self.absolute(len, l),
                else => 0,
            };
            return Value.px(snapBorderWidth(px));
        }
        switch (l) {
            // Writing Modes 4 §5.1: retain the legacy spelling only until
            // computation (Blink/Gecko ship it; their specified forms differ).
            .text_orientation => if (v.isKeyword(.sideways_right)) return Value.kw(.sideways),
            .content => {
                if (v == .content) {
                    if (try v.content.compute(self.ctx.allocator, self.ctx.content_attributes)) |content| return .{ .content = content };
                    // A guaranteed-invalid attr() invalidates the entire
                    // non-inherited declaration at computed-value time.
                    return self.computeValue(.content, Value.kw(.normal), source);
                }
                if (v.isKeyword(.normal)) if (self.ctx.pseudo) |pseudo| {
                    if (std.mem.eql(u8, pseudo, "before") or std.mem.eql(u8, pseudo, "after")) return Value.kw(.none);
                };
                // CSSOM exposes normal on ordinary elements in Chrome,
                // Firefox and Safari (CSS Content's contents is a used rule).
                return v;
            },
            .font_size => return Value.px(self.computeFontSize(v)),
            .font_weight => return .{ .number = self.computeFontWeight(v) },
            // CSS Text4 §8.2: normal is zero in the computed value.
            .opacity => return .{ .number = std.math.clamp(v.number, 0, 1) },
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
                    .length => |len| self.absolute(len, l),
                    else => 0,
                };
                return Value.px(snapBorderWidth(px));
            },
            else => {},
        }
        switch (v) {
            .length => |len| {
                if (len.unit == .percent) return v;
                return Value.px(self.absolute(len, l));
            },
            else => {
                v.retain();
                return v;
            },
        }
    }

    fn usedLineHeight(style: *const ComputedStyle) f64 {
        const em = style.get(.font_size).length.value;
        return switch (style.get(.line_height)) {
            .number => |n| n * em,
            .length => |length| length.value,
            else => em * 1.2, // Existing normal-line-height estimate, Q17.
        };
    }

    fn pendingTreeCounts(raw: *anyopaque) @import("math_values.zig").TreeCounts {
        const self: *Builder = @ptrCast(@alignCast(raw));
        if (self.cached_tree_counts == null) {
            self.cached_tree_counts = if (self.ctx.tree_counts) |provider| provider.get(provider.context) else .{ .index = 1, .count = 1 };
        }
        return self.cached_tree_counts.?;
    }

    /// Values 5 §10: the source restriction belongs to the winning value,
    /// including every nested expression. No inherited value is recomputed.
    fn computationContext(self: *Builder, l: Longhand, v: Value, source: ValueSource) @import("math_values.zig").Context {
        var context = self.mathContext(l);
        if (v.needsTreeCounts()) {
            if (!source.tree_count_allowed) {
                context.tree_counts = .{ .index = 0, .count = 0 };
            } else {
                if (self.cached_tree_counts == null) {
                    self.cached_tree_counts = if (self.ctx.tree_counts) |provider|
                        provider.get(provider.context)
                    else
                        .{ .index = 1, .count = 1 };
                }
                context.tree_counts = self.cached_tree_counts;
            }
        }
        return context;
    }

    fn mathContext(self: *const Builder, l: Longhand) @import("math_values.zig").Context {
        // Values 4 §6.1.1: font-affecting properties use parent metrics;
        // line-height additionally uses its parent's lh to avoid a cycle.
        const font_affecting = l == .font_size or l == .font_weight;
        const parent_em = self.parentValue(.font_size).length.value;
        const em = if (font_affecting) parent_em else self.fontSize();
        const parent_lh = if (self.ctx.parent) |parent| usedLineHeight(parent) else 19.2;
        const own_lh = if (font_affecting or l == .line_height) parent_lh else usedLineHeight(self.style);
        const root_self = self.ctx.is_root and !font_affecting;
        const root_em = if (root_self) self.fontSize() else self.ctx.root_font_size;
        const mode = if (font_affecting) self.parentValue(.writing_mode).keyword else self.writing_mode;
        const orientation = if (font_affecting) self.parentValue(.text_orientation).keyword else self.style.keyword(.text_orientation);
        return .{
            .random_base = self.ctx.random_base,
            .font_size = em,
            .root_font_size = root_em,
            .line_height = own_lh,
            .root_line_height = if (self.ctx.is_root)
                (if (font_affecting or l == .line_height) parent_lh else own_lh)
            else
                self.ctx.root_line_height orelse self.ctx.root_font_size * 1.2,
            .vertical = mode == .vertical_rl or mode == .vertical_lr,
            .upright = orientation == .upright,
            .root_vertical = if (root_self) self.writing_mode == .vertical_rl or self.writing_mode == .vertical_lr else self.ctx.root_vertical,
            .root_upright = if (root_self) self.style.keyword(.text_orientation) == .upright else self.ctx.root_upright,
            .viewport_vertical = self.writing_mode != .horizontal_tb,
            .viewport_width = self.ctx.viewport_width,
            .viewport_height = self.ctx.viewport_height,
            .percentage_basis = if (l == .font_size) parent_em else if (l == .line_height) self.fontSize() else null,
        };
    }

    /// CSS Values 4 section 6: a length's absolute value, in px, its em
    /// the element's own font size.
    fn absolute(self: *const Builder, len: Length, l: Longhand) f64 {
        if (len.unit == .px) return len.value;
        const unit: @import("math_values.zig").Unit = switch (len.unit) {
            .Q => .q,
            inline else => |u| @field(@import("math_values.zig").Unit, @tagName(u)),
        };
        return self.mathContext(l).resolve(.{ .value = len.value, .unit = unit }).value;
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
            .length => |len| self.absolute(len, .font_size),
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
            if (style_kw == .none or style_kw == .hidden) {
                const slot = &s.values[@intFromEnum(pair[1])];
                slot.release();
                slot.* = Value.px(0);
            }
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
    value: struct { value: Value, source: ValueSource },
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
            self.revert_class_at_least = @min(self.revert_class_at_least, c.source.origin.revertClass());
            return;
        }
        self.layers[self.count] = .{ .origin = c.source.origin, .layer = c.source.layer, .important = c.decl.important };
        self.count += 1;
    }

    fn excludes(self: *const Exclusions, c: Candidate) bool {
        if (c.source.origin.revertClass() >= self.revert_class_at_least) return true;
        for (self.layers[0..self.count]) |lv| {
            if (lv.origin != c.source.origin or lv.layer != c.source.layer) continue;
            // An important level's revert-layer also passes the normal
            // declarations of its layer.
            if (lv.important or !c.decl.important) return true;
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

fn cascadeText(parent: ?*const ComputedStyle, text: []const u8, ctx_override: struct { is_root: bool = false, page: color_scheme_mod.Scheme = .light, preferred: color_scheme_mod.Scheme = .light }) !*ComputedStyle {
    var block = try TestBlock.make(text);
    defer block.deinit();
    return cascade(.{
        .allocator = testing.allocator,
        .parent = parent,
        .is_root = ctx_override.is_root,
        .page_color_scheme = ctx_override.page,
        .preferred_color_scheme = ctx_override.preferred,
    }, &.{.{ .block = &block.block, .source = .{ .origin = .author } }});
}

test "system colors compute against the element's used color scheme" {
    // CSS Color 4 15.5: "the computed and used value is the corresponding
    // color"; CSS Color Adjustment 1 2.4: system colors match the element
    // color scheme.
    const light = try cascadeText(null, "color: CanvasText; background-color: Canvas; color-scheme: only light", .{ .is_root = true });
    defer light.destroy();
    try expectResolved(light, .color, "rgb(0, 0, 0)");
    try expectResolved(light, .background_color, "rgb(255, 255, 255)");
    const dark = try cascadeText(null, "color: CanvasText; background-color: Canvas; border-top: 1px solid; color-scheme: only dark", .{ .is_root = true });
    defer dark.destroy();
    try testing.expectEqual(color_scheme_mod.Scheme.dark, dark.used_color_scheme);
    try expectResolved(dark, .color, "rgb(255, 255, 255)");
    try expectResolved(dark, .background_color, "rgb(18, 18, 18)");
    // currentcolor follows the element's color.
    try expectResolved(dark, .border_top_color, "rgb(255, 255, 255)");
    const link = try cascadeText(null, "color: LinkText; background-color: Menu; color-scheme: dark", .{ .is_root = true });
    defer link.destroy();
    try expectResolved(link, .color, "rgb(158, 158, 255)");
    // A deprecated system color is its standard color (Appendix A).
    try expectResolved(link, .background_color, "rgb(18, 18, 18)");
}

test "an inherited system color is the parent's resolved color" {
    // Chrome 151, Firefox 144 and Safari 27.0.1 (lane style4 probe): a light
    // parent's CanvasText reaches its dark child as rgb(0, 0, 0).
    const parent = try cascadeText(null, "color: CanvasText; color-scheme: light", .{ .is_root = true });
    defer parent.destroy();
    const child = try cascadeText(parent, "color-scheme: dark", .{});
    defer child.destroy();
    try testing.expectEqual(color_scheme_mod.Scheme.dark, child.used_color_scheme);
    try expectResolved(child, .color, "rgb(0, 0, 0)");
}

test "color's initial value is CanvasText in the element's own scheme" {
    // The root's default color follows its used scheme - the page's for
    // `normal` - and `color: initial` an element's own (Chrome and Safari;
    // Firefox answers black).
    const root = try cascadeText(null, "", .{ .is_root = true, .page = .dark });
    defer root.destroy();
    try testing.expectEqual(color_scheme_mod.Scheme.dark, root.used_color_scheme);
    try expectResolved(root, .color, "rgb(255, 255, 255)");
    const light_root = try cascadeText(null, "", .{ .is_root = true });
    defer light_root.destroy();
    const initial = try cascadeText(light_root, "color: initial; color-scheme: only dark", .{});
    defer initial.destroy();
    try expectResolved(initial, .color, "rgb(255, 255, 255)");
    // An element with no color declaration inherits it, whatever its scheme.
    const inherits = try cascadeText(light_root, "color-scheme: only dark", .{});
    defer inherits.destroy();
    try expectResolved(inherits, .color, "rgb(0, 0, 0)");
}

test "the element color scheme: normal is the page's, a list is resolved against the preference" {
    const cases = [_]struct { []const u8, color_scheme_mod.Scheme, color_scheme_mod.Scheme, color_scheme_mod.Scheme }{
        // text, page scheme, preference, expected
        .{ "color-scheme: normal", .dark, .light, .dark },
        .{ "color-scheme: normal", .light, .dark, .light },
        .{ "color-scheme: foo", .dark, .light, .light },
        .{ "color-scheme: foo dark", .light, .light, .dark },
        .{ "color-scheme: light dark", .light, .light, .light },
        .{ "color-scheme: light dark", .light, .dark, .dark },
        .{ "color-scheme: only dark light", .light, .light, .light },
    };
    for (cases) |case| {
        const style = try cascadeText(null, case[0], .{ .is_root = true, .page = case[1], .preferred = case[2] });
        defer style.destroy();
        testing.expectEqual(case[3], style.used_color_scheme) catch |err| {
            std.debug.print("{s} page {s} preferred {s}\n", .{ case[0], @tagName(case[1]), @tagName(case[2]) });
            return err;
        };
    }
}

const Cv1Cascade = @This();
const cv1HasSourceApi = @hasDecl(Cv1Cascade, "TreeScopeRef") and
    @hasDecl(Cv1Cascade, "ValueSource") and @hasDecl(Cv1Cascade, "collectCandidates");

fn cv1SourceSpecified(matched: []const Matched, longhand: Longhand, mode: Keyword, direction: Keyword) !Specified {
    var candidates = try Cv1Cascade.collectCandidates(testing.allocator, matched);
    defer candidates.deinit(testing.allocator);
    const links = try testing.allocator.alloc(usize, candidates.items.len);
    defer testing.allocator.free(links);
    var builder = Builder{
        .ctx = .{ .allocator = testing.allocator, .parent = null },
        .candidates = candidates.items,
        .index = CandidateIndex.init(candidates.items, links),
        .writing_mode = mode,
        .direction = direction,
    };
    defer builder.deinit();
    builder.mapLogicalChains();
    return builder.specified(longhand);
}

test "cv1 source defaults to the document and permits tree counts" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    const source: Source = .{ .origin = .author };
    const value_source: Cv1Cascade.ValueSource = .{};
    try testing.expectEqual(@as(u64, 0), source.tree_scope.serial);
    try testing.expectEqual(@as(u64, 0), value_source.tree_scope.serial);
    try testing.expect(source.tree_count_allowed);
    try testing.expect(value_source.tree_count_allowed);
}

test "cv1 source candidate stays thirty two bytes" {
    try testing.expectEqual(@as(usize, 32), @sizeOf(Candidate));
}

test "cv1 source metadata belongs to the winning declaration and is copied out of candidates" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    var low = try TestBlock.make("opacity:.2");
    defer low.deinit();
    var high = try TestBlock.make("opacity:.8");
    defer high.deinit();
    var matched = [_]Matched{
        .{ .block = &high.block, .source = .{ .origin = .author, .order = 2, .tree_scope = .{ .serial = 82 }, .tree_count_allowed = false } },
        .{ .block = &low.block, .source = .{ .origin = .author, .order = 1, .tree_scope = .{ .serial = 17 } } },
    };
    const specified = try cv1SourceSpecified(&matched, .opacity, .horizontal_tb, .ltr);
    matched[0].source.tree_scope.serial = 999;
    try testing.expectEqual(@as(f64, 0.8), specified.value.value.number);
    try testing.expectEqual(@as(u64, 82), specified.value.source.tree_scope.serial);
    try testing.expect(!specified.value.source.tree_count_allowed);
}

test "cv1 source revert and revert layer carry the fallback declaration source" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    var ua = try TestBlock.make("display:block;opacity:.1");
    defer ua.deinit();
    var low = try TestBlock.make("opacity:.4");
    defer low.deinit();
    var high = try TestBlock.make("display:revert;opacity:revert-layer");
    defer high.deinit();
    const matched = [_]Matched{
        .{ .block = &ua.block, .source = .{ .origin = .user_agent, .tree_scope = .{ .serial = 3 } } },
        .{ .block = &low.block, .source = .{ .origin = .author, .layer = 0, .tree_scope = .{ .serial = 4 }, .tree_count_allowed = false } },
        .{ .block = &high.block, .source = .{ .origin = .author, .layer = 1, .tree_scope = .{ .serial = 5 } } },
    };
    const reverted = try cv1SourceSpecified(&matched, .display, .horizontal_tb, .ltr);
    try testing.expectEqual(@as(u64, 3), reverted.value.source.tree_scope.serial);
    const layered = try cv1SourceSpecified(&matched, .opacity, .horizontal_tb, .ltr);
    try testing.expectEqual(@as(u64, 4), layered.value.source.tree_scope.serial);
    try testing.expect(!layered.value.source.tree_count_allowed);
}

test "cv1 source logical remapping keeps the winning rule source" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    var logical = try TestBlock.make("margin-inline-start:7px");
    defer logical.deinit();
    var physical = try TestBlock.make("margin-right:3px");
    defer physical.deinit();
    const matched = [_]Matched{
        .{ .block = &logical.block, .source = .{ .origin = .author, .order = 2, .tree_scope = .{ .serial = 72 } } },
        .{ .block = &physical.block, .source = .{ .origin = .author, .order = 1, .tree_scope = .{ .serial = 31 } } },
    };
    const specified = try cv1SourceSpecified(&matched, .margin_right, .horizontal_tb, .rtl);
    try testing.expectEqual(@as(f64, 7), specified.value.value.length.value);
    try testing.expectEqual(@as(u64, 72), specified.value.source.tree_scope.serial);
}

test "cv1 source initial and inherited defaults do not acquire the resetting rule source" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    var block = try TestBlock.make("font-family:inherit;opacity:initial");
    defer block.deinit();
    const matched = [_]Matched{.{ .block = &block.block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 29 }, .tree_count_allowed = false } }};
    try testing.expect((try cv1SourceSpecified(&matched, .font_family, .horizontal_tb, .ltr)) == .inherit);
    try testing.expect((try cv1SourceSpecified(&matched, .opacity, .horizontal_tb, .ltr)) == .initial);
    try testing.expect((try cv1SourceSpecified(&.{}, .font_family, .horizontal_tb, .ltr)) == .inherit);
    try testing.expect((try cv1SourceSpecified(&.{}, .opacity, .horizontal_tb, .ltr)) == .initial);
}

test "cv1 source borrows only after callers finish appending matched batches" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    var first = try TestBlock.make("opacity:.2");
    defer first.deinit();
    var last = try TestBlock.make("opacity:.8");
    defer last.deinit();
    var matched: std.ArrayList(Matched) = .empty;
    defer matched.deinit(testing.allocator);
    try matched.appendSlice(testing.allocator, &.{.{ .block = &first.block, .source = .{ .origin = .author, .order = 1, .tree_scope = .{ .serial = 1 } } }});
    // Force the second batch to move storage before any candidate borrows it.
    try matched.ensureTotalCapacity(testing.allocator, matched.capacity + 32);
    try matched.appendSlice(testing.allocator, &.{.{ .block = &last.block, .source = .{ .origin = .author, .order = 2, .tree_scope = .{ .serial = 2 } } }});
    const specified = try cv1SourceSpecified(matched.items, .opacity, .horizontal_tb, .ltr);
    try testing.expectEqual(@as(u64, 2), specified.value.source.tree_scope.serial);
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, matched.items);
    defer style.destroy();
    try expectResolved(style, .opacity, "0.8");
}

test "cv1 source inheritance retains parent values after declarations and parent style end" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    try cv1SourceInheritanceRoundTrip(testing.allocator);
}

test "cv1 source candidate and inherited value allocation failures release everything" {
    if (comptime !cv1HasSourceApi) return error.CascadeSourceApiNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, cv1SourceInheritanceRoundTrip, .{});
}

fn cv1SourceInheritanceRoundTrip(allocator: Allocator) !void {
    inline for (.{ "font-family:inherit", "color:red" }) |text| {
        const child = blk: {
            var parent_block = try DeclarationBlock.parse(.{ .allocator = allocator }, "font-family:parent-scope");
            defer parent_block.deinit();
            const parent = try cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 37 } } }});
            defer parent.destroy();
            var child_block = try DeclarationBlock.parse(.{ .allocator = allocator }, text);
            defer child_block.deinit();
            const result = try cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &child_block, .source = .{ .origin = .author, .tree_scope = .{ .serial = 91 } } }});
            errdefer result.destroy();
            try testing.expectEqual(parent.get(.font_family).text, result.get(.font_family).text);
            break :blk result;
        };
        defer child.destroy();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try child.serializeResolved(.font_family, &out, allocator);
        try testing.expectEqualStrings("parent-scope", out.items);
    }
}

test "cv1 index absent properties have empty heads without reading candidates" {
    if (comptime !@hasDecl(@This(), "CandidateIndex")) return error.CascadePropertyIndexMissing;
    const Index = @field(@This(), "CandidateIndex");
    var no_links: [0]usize = .{};
    const index = Index.init(&.{}, &no_links);
    for (index.heads) |head| try testing.expectEqual(Index.none, head);
}

test "cv1 index defaults inherit and initialize independently of unrelated declarations" {
    var parent_block = try TestBlock.make("color:green;font-family:parent-family;opacity:.2");
    defer parent_block.deinit();
    const parent = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block.block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var child_block = try TestBlock.make("width:17px;margin-top:9px");
    defer child_block.deinit();
    const child = try cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{.{ .block = &child_block.block, .source = .{ .origin = .author } }});
    defer child.destroy();
    try expectResolved(child, .color, "rgb(0, 128, 0)");
    try expectResolved(child, .font_family, "parent-family");
    try expectResolved(child, .opacity, "1");
    try expectResolved(child, .margin_left, "0px");
}

test "cv1 index retains origin importance layer specificity and appearance ordering" {
    const Case = struct { first: Source, second: Source, important: bool = false, expected: []const u8 };
    const cases = [_]Case{
        .{ .first = .{ .origin = .user_agent }, .second = .{ .origin = .author }, .expected = "2px" },
        .{ .first = .{ .origin = .user_agent }, .second = .{ .origin = .author }, .important = true, .expected = "1px" },
        .{ .first = .{ .origin = .author, .layer = 0 }, .second = .{ .origin = .author, .layer = 1 }, .expected = "2px" },
        .{ .first = .{ .origin = .author, .layer = 0 }, .second = .{ .origin = .author, .layer = 1 }, .important = true, .expected = "1px" },
        .{ .first = .{ .origin = .author, .specificity = .{ .a = 1 } }, .second = .{ .origin = .author, .specificity = .{ .b = 9 }, .order = 10 }, .expected = "1px" },
        .{ .first = .{ .origin = .author, .order = 7 }, .second = .{ .origin = .author, .order = 8 }, .expected = "2px" },
        .{ .first = .{ .origin = .author, .element_attached = true }, .second = .{ .origin = .author, .specificity = .{ .a = 9 }, .order = 10 }, .expected = "1px" },
    };
    for (cases) |case| {
        var first = try TestBlock.make(if (case.important) "margin-left:1px!important;color:red" else "margin-left:1px;color:red");
        defer first.deinit();
        var second = try TestBlock.make(if (case.important) "opacity:.5;margin-left:2px!important" else "opacity:.5;margin-left:2px");
        defer second.deinit();
        const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
            .{ .block = &second.block, .source = case.second },
            .{ .block = &first.block, .source = case.first },
        });
        defer style.destroy();
        try expectResolved(style, .margin_left, case.expected);
        try expectResolved(style, .opacity, "0.5");
    }
}

test "cv1 index shadow priority preserves the actual winning tree scope" {
    inline for (.{ false, true }) |important| {
        var outer = try TestBlock.make(if (important) "opacity:.2!important" else "opacity:.2");
        defer outer.deinit();
        var inner = try TestBlock.make(if (important) "opacity:.8!important" else "opacity:.8");
        defer inner.deinit();
        const result = try cv1SourceSpecified(&.{
            .{ .block = &inner.block, .source = .{ .origin = .author, .tree_depth = 2, .tree_scope = .{ .serial = 88 } } },
            .{ .block = &outer.block, .source = .{ .origin = .author, .tree_depth = 0, .tree_scope = .{ .serial = 22 } } },
        }, .opacity, .horizontal_tb, .ltr);
        try testing.expectEqual(@as(u64, if (important) 88 else 22), result.value.source.tree_scope.serial);
        try testing.expectEqual(@as(f64, if (important) 0.8 else 0.2), result.value.value.number);
    }
}

test "cv1 index revert and revert layer traverse only the property's fallback chain" {
    var ua = try TestBlock.make("margin-left:1px;opacity:.1");
    defer ua.deinit();
    var low = try TestBlock.make("margin-left:3px;opacity:.3;color:green");
    defer low.deinit();
    var middle = try TestBlock.make("margin-left:revert;opacity:.5;display:block");
    defer middle.deinit();
    var high = try TestBlock.make("margin-left:revert-layer;opacity:revert-layer;width:99px");
    defer high.deinit();
    const matched = [_]Matched{
        .{ .block = &high.block, .source = .{ .origin = .author, .layer = 2, .tree_scope = .{ .serial = 4 } } },
        .{ .block = &ua.block, .source = .{ .origin = .user_agent, .tree_scope = .{ .serial = 1 } } },
        .{ .block = &middle.block, .source = .{ .origin = .author, .layer = 1, .tree_scope = .{ .serial = 3 } } },
        .{ .block = &low.block, .source = .{ .origin = .author, .layer = 0, .tree_scope = .{ .serial = 2 } } },
    };
    const margin = try cv1SourceSpecified(&matched, .margin_left, .horizontal_tb, .ltr);
    const opacity = try cv1SourceSpecified(&matched, .opacity, .horizontal_tb, .ltr);
    try testing.expectEqual(@as(f64, 1), margin.value.value.length.value);
    try testing.expectEqual(@as(u64, 1), margin.value.source.tree_scope.serial);
    try testing.expectEqual(@as(f64, 0.5), opacity.value.value.number);
    try testing.expectEqual(@as(u64, 3), opacity.value.source.tree_scope.serial);
}

test "cv1 index merges logical and physical chains after both mapping properties compute" {
    const Case = struct { mode: []const u8, direction: []const u8, inline_start: Longhand, block_start: Longhand };
    const cases = [_]Case{
        .{ .mode = "horizontal-tb", .direction = "ltr", .inline_start = .margin_left, .block_start = .margin_top },
        .{ .mode = "horizontal-tb", .direction = "rtl", .inline_start = .margin_right, .block_start = .margin_top },
        .{ .mode = "vertical-rl", .direction = "ltr", .inline_start = .margin_top, .block_start = .margin_right },
        .{ .mode = "vertical-rl", .direction = "rtl", .inline_start = .margin_bottom, .block_start = .margin_right },
        .{ .mode = "vertical-lr", .direction = "ltr", .inline_start = .margin_top, .block_start = .margin_left },
        .{ .mode = "vertical-lr", .direction = "rtl", .inline_start = .margin_bottom, .block_start = .margin_left },
        .{ .mode = "sideways-rl", .direction = "ltr", .inline_start = .margin_top, .block_start = .margin_right },
        .{ .mode = "sideways-rl", .direction = "rtl", .inline_start = .margin_bottom, .block_start = .margin_right },
        .{ .mode = "sideways-lr", .direction = "ltr", .inline_start = .margin_bottom, .block_start = .margin_left },
        .{ .mode = "sideways-lr", .direction = "rtl", .inline_start = .margin_top, .block_start = .margin_left },
    };
    for (cases) |case| {
        var physical = try TestBlock.make("margin:3px");
        defer physical.deinit();
        const text = try std.fmt.allocPrint(testing.allocator, "writing-mode:{s};direction:{s};margin-inline-start:7px;margin-block-start:11px", .{ case.mode, case.direction });
        defer testing.allocator.free(text);
        var logical = try TestBlock.make(text);
        defer logical.deinit();
        const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
            .{ .block = &logical.block, .source = .{ .origin = .author, .order = 2 } },
            .{ .block = &physical.block, .source = .{ .origin = .author, .order = 1 } },
        });
        defer style.destroy();
        try expectResolved(style, case.inline_start, "7px");
        try expectResolved(style, case.block_start, "11px");
        try expectResolved(style, .margin_inline_start, "7px");
        try expectResolved(style, .margin_block_start, "11px");
    }
}

test "cv1 index preserves cross logical physical rollback and unavailable scalar fallback" {
    var low = try TestBlock.make("margin-inline-start:7px;opacity:.4;direction:rtl");
    defer low.deinit();
    var high = try TestBlock.make("margin-right:revert-layer;opacity:calc(1cap / 1px)");
    defer high.deinit();
    const style = try cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &high.block, .source = .{ .origin = .author, .layer = 1 } },
        .{ .block = &low.block, .source = .{ .origin = .author, .layer = 0 } },
    });
    defer style.destroy();
    try expectResolved(style, .margin_right, "7px");
    try expectResolved(style, .opacity, "0.4");
}

test "cv1 index large candidate storage releases every allocation failure" {
    try cv1IndexLarge(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, cv1IndexLarge, .{});
}

fn cv1IndexLarge(allocator: Allocator) !void {
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, "opacity:.25;direction:rtl;margin-inline-start:7px");
    defer block.deinit();
    var matched: [80]Matched = undefined;
    for (&matched, 0..) |*entry, i| entry.* = .{ .block = &block, .source = .{ .origin = .author, .order = @intCast(i), .tree_scope = .{ .serial = i } } };
    const style = try cascade(.{ .allocator = allocator, .parent = null }, &matched);
    defer style.destroy();
    try testing.expectEqual(@as(f64, 0.25), style.get(.opacity).number);
    try testing.expectEqual(@as(f64, 7), style.get(.margin_right).length.value);
}
