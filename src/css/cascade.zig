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
//! display), CSS Display 4 2.7/2.8 (blockification) and CSS Overflow 3
//! (visible/clip fix-up). A border width keeps its length whatever the
//! border style (Backgrounds 3 3.3); only its resolved value is zero for a
//! side not drawn (ComputedStyle.serializeResolved).
//!
//! `revert-rule` (Cascade 5 7.3.6) rolls back to the cascade as if the
//! current style rule were not present (Chrome and Safari ship it). Stated:
//! there is no user origin (Crane has no user style sheets) and no animation
//! or transition origin.
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
const custom_mod = @import("custom_properties.zig");
const registered_mod = @import("registered_properties.zig");
const substitution = @import("substitution.zig");

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
    /// Fonts4/5: value-only capability inputs, borrowed for each call (Q46).
    system_fonts: ?@import("font_system.zig").Resolver = null,
    font_metric_ratios: ?@import("font_size_adjust.zig").MetricResolver = null,
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
    /// CSS Environment Variables 1: the document's environment variables,
    /// from the host (Codex row 121 installs the provider). Null: every
    /// name is undefined, so env() takes its fallback.
    environment: ?@import("substitution.zig").Environment = null,
    /// CSS Variables 1 §2.1: resolves a url() that substitution brought into
    /// a value against the consuming declaration's base URL.
    url_resolver: ?@import("pending_values.zig").BaseUrlResolver = null,
    /// The document's media values, for if()'s media() test (Codex row 123);
    /// borrowed for the call. Null: the defaults.
    media_values: ?*const @import("media_queries.zig").MediaValues = null,
    /// if()'s supports() test's selector() function: the check CSS.supports()
    /// and @supports use (src/selector is not a dependency of this module).
    /// Null: every selector() is false.
    selector_check: ?@import("supports.zig").SelectorCheck = null,
    /// Properties and Values API 1: the document's registrations, with
    /// their initial values computed (registered_properties.zig), borrowed
    /// for the call; the style retains it. Null when the document has none:
    /// every custom property is unregistered and nothing below reads it.
    registered: ?*registered_mod.Snapshot = null,
};

const Candidate = struct {
    decl: *const Declaration,
    priority: u128,
    /// Borrowed from the caller's stable Matched slice. Candidates never
    /// escape the synchronous cascade or enter an owned computed value.
    source: *const Source,
};

/// Two token texts equal token by token, whitespace runs (and the comments
/// in them) normalized away at either end and to one between tokens.
fn tokensEqual(a: []const u8, b: []const u8) bool {
    const tokenizer = @import("tokenizer.zig");
    var x = tokenizer.Tokenizer.init(a);
    var y = tokenizer.Tokenizer.init(b);
    x.skipWhitespace();
    y.skipWhitespace();
    while (true) {
        const s = x.next();
        const t = y.next();
        const s_space = s.token_type == .whitespace;
        const t_space = t.token_type == .whitespace;
        if (s_space or t_space) {
            if (s_space != t_space) return false;
            x.skipWhitespace();
            y.skipWhitespace();
            // Trailing whitespace on one side only.
            const s_end = x.peek().token_type == .eof;
            const t_end = y.peek().token_type == .eof;
            if (s_end != t_end) return false;
            continue;
        }
        if (s.token_type != t.token_type) return false;
        if (s.token_type == .eof) return true;
        if (!std.mem.eql(u8, s.value, t.value)) return false;
    }
}

/// Cascade 5 6.1's priority of a declaration from `source`./// Cascade 5 6.1's priority of a declaration from `source`.
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

const LonghandSet = std.EnumSet(Longhand);

/// CSS Pseudo 4 2.1.2 and 2.2.4: the properties that apply to ::first-line
/// and ::first-letter. A declaration of any other longhand in a rule for one
/// of them is not applied: the pseudo-element keeps the value it inherits
/// (from its originating element) or its initial value, as Blink and Gecko
/// expose it through getComputedStyle; custom properties apply to both. The
/// lists are the spec's categories mapped onto Crane's longhands - all font
/// properties, color, opacity, all background properties, the typesetting
/// and inline layout properties that apply to inline boxes (letter-spacing,
/// text-transform, line-height) - and, for ::first-letter, also margin,
/// padding and border properties and float (CSS 2.2 5.12.2).
///
/// "User agents may apply other properties as well": three Crane longhands
/// outside those categories are applied, by browser majority (golden rule
/// 2), since WebKit filters neither pseudo-element (StyleAdjuster.cpp only
/// forces its display; PropertyAllowlist.cpp has no first-letter or
/// first-line list) and so counts for every property Blink or Gecko
/// applies: visibility (Blink's css_properties.json5 valid_for_first_letter
/// and valid_for_first_line) and fill, stroke and stroke-width (Gecko's
/// PropertyRestrictions svg_text_properties, servo/components/style/
/// properties/data.py). The text properties that apply to text and block
/// containers rather than inline boxes - white-space-collapse,
/// text-wrap-mode, text-indent - apply to neither, as in both
/// (css/css-pseudo/first-letter-allowed-properties.html and
/// first-line-allowed-properties.html: Chrome and Firefox pass every "should
/// not be applied" case, Safari fails position, border, margin, padding).
const first_line_longhands: LonghandSet = blk: {
    @setEvalBranchQuota(20_000);
    var set: LonghandSet = .initMany(&.{
        .color,                 .opacity,           .visibility,
        .letter_spacing,        .text_transform,    .line_height,
        .fill,                  .stroke,            .stroke_width,
        .background_color,      .background_image,  .background_position_x,
        .background_position_y, .background_size,   .background_repeat,
        .background_attachment, .background_origin, .background_clip,
    });
    for (std.enums.values(Longhand)) |l| {
        if (std.mem.startsWith(u8, @tagName(l), "font_")) set.insert(l);
    }
    break :blk set;
};

const first_letter_longhands: LonghandSet = blk: {
    @setEvalBranchQuota(20_000);
    var set = first_line_longhands;
    set.insert(.float);
    for (std.enums.values(Longhand)) |l| {
        const name = @tagName(l);
        if (std.mem.startsWith(u8, name, "margin_") or std.mem.startsWith(u8, name, "padding_") or std.mem.startsWith(u8, name, "border_")) set.insert(l);
    }
    break :blk set;
};

/// The longhands that may apply to `pseudo`, or null when every one does.
/// Only ::first-letter and ::first-line filter, so only they pay.
fn appliesTo(pseudo: ?[]const u8) ?*const LonghandSet {
    const name = pseudo orelse return null;
    if (std.mem.eql(u8, name, "first-letter")) return &first_letter_longhands;
    if (std.mem.eql(u8, name, "first-line")) return &first_line_longhands;
    return null;
}

/// The caller finishes appending matched batches before this call, and
/// keeps the slice and declaration blocks immutable until cascade returns.
/// Like Blink's MatchResult/CascadeMap, candidates refer back to their
/// matched declarations rather than duplicating all source data per property.
/// A declaration of a longhand outside `applies` is not a candidate.
fn collectCandidates(allocator: Allocator, matched: []const Matched, applies: ?*const LonghandSet) Allocator.Error!std.ArrayList(Candidate) {
    var candidates: std.ArrayList(Candidate) = .empty;
    errdefer candidates.deinit(allocator);
    for (matched) |*m| {
        std.debug.assert(@intFromPtr(&m.source) >= @intFromPtr(matched.ptr));
        std.debug.assert(@intFromPtr(&m.source) + @sizeOf(Source) <= @intFromPtr(matched.ptr) + matched.len * @sizeOf(Matched));
        var it = m.block.typed();
        while (it.next()) |d| {
            if (applies) |set| if (!set.contains(d.longhand)) continue;
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

/// A custom property declaration that applies to the element (CSS
/// Variables 1 §2: "Custom properties are ordinary properties ... resolved
/// with the normal inheritance and cascade rules").
const CustomCandidate = struct {
    decl: *const declarations_mod.Custom,
    priority: u128,
    source: *const Source,
};

/// The custom property candidates of `matched`, by name (code units), each
/// name's strongest first with the same priority and tie-breaks as the
/// longhands' candidates. Only blocks that hold custom properties are read.
fn collectCustomCandidates(allocator: Allocator, matched: []const Matched) Allocator.Error!std.ArrayList(CustomCandidate) {
    var candidates: std.ArrayList(CustomCandidate) = .empty;
    errdefer candidates.deinit(allocator);
    for (matched) |*m| {
        if (m.block.custom_count == 0) continue;
        var it = m.block.customs();
        while (it.next()) |d| try candidates.append(allocator, .{ .decl = d, .priority = priority(m.source, d.important), .source = &m.source });
    }
    std.mem.sortUnstable(CustomCandidate, candidates.items, {}, struct {
        fn lessThan(_: void, a: CustomCandidate, b: CustomCandidate) bool {
            switch (std.mem.order(u8, a.decl.name.bytes, b.decl.name.bytes)) {
                .lt => return true,
                .gt => return false,
                .eq => {},
            }
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
    var candidates = try collectCandidates(allocator, matched, appliesTo(ctx.pseudo));
    defer candidates.deinit(allocator);
    var stack_links: [64]usize = undefined;
    const links = if (candidates.items.len <= stack_links.len)
        stack_links[0..candidates.items.len]
    else
        try allocator.alloc(usize, candidates.items.len);
    defer if (links.len > stack_links.len) allocator.free(links);
    // Custom properties: only when a matched block declares one.
    var custom_candidates: std.ArrayList(CustomCandidate) = .empty;
    defer custom_candidates.deinit(allocator);
    for (matched) |*m| if (m.block.custom_count != 0) {
        custom_candidates = try collectCustomCandidates(allocator, matched);
        break;
    };
    var builder: Builder = .{
        .ctx = ctx,
        .candidates = candidates.items,
        .index = CandidateIndex.init(candidates.items, links),
        .custom_candidates = custom_candidates.items,
    };
    defer builder.deinit();
    const style = try allocator.create(ComputedStyle);
    style.* = .{ .allocator = allocator, .values = computed_mod.initial_values };
    // `initial_values` holds no counted text; every slot is overwritten
    // below, each holding its own reference.
    builder.style = style;
    errdefer style.destroy();
    if (ctx.registered) |r| {
        r.retain();
        style.registered = r;
    }
    try builder.run();
    return style;
}

/// How Builder.run defaults a longhand that no declaration touches (an
/// empty CandidateIndex chain). Cascade 5 7.1 "defaulting": an inherited
/// property takes its parent's computed value, any other its initial value.
pub const DefaultPath = enum {
    /// Today's specified() -> compute() walk: the safe answer.
    compute,
    /// Store the parent's computed value (initialComputed at the root).
    inherit,
    /// Keep the shared initial computed value already in the slot.
    initial,
};

/// The longhands Builder.run computes eagerly in its high-priority prefix.
fn isHighPriority(l: Longhand) bool {
    return switch (l) {
        .writing_mode, .direction, .text_orientation, .color_scheme, .font_size, .line_height, .color => true,
        else => false,
    };
}

/// Whether a longhand whose initial value is `initial` may default without
/// the compute walk. An ALLOWLIST whose default is `.compute` (AGENTS.md:
/// gates default to the safe answer): `.initial` only for a value whose
/// computeValue result is the value itself in every element context.
/// Font-relative and viewport lengths (font metrics, the parent's em, the
/// viewport), math values (tree counts, random(), metrics), images, lists,
/// transforms and any tag added later are not proven and compute.
pub fn defaultPathFor(l: Longhand, initial: Value) DefaultPath {
    if (l.logical() != null or isHighPriority(l)) return .compute;
    if (l.inherited()) return .inherit;
    switch (l) {
        // computeValue reads element context for these initial values:
        // content's `normal` is `none` on ::before/::after (CSS Content 3),
        // and justify-items' `legacy` reads the parent (Align 3 7.1).
        .content, .justify_items => return .compute,
        else => {},
    }
    return switch (initial) {
        .keyword, .number, .integer, .display, .grid_flow, .image_repeat, .image_keyword, .position_visibility, .containment => .initial,
        // Align 3: only a lone `legacy` reads the parent.
        .alignment => |a| if (a.position == .legacy) .compute else .initial,
        // An absolute length is its own computed value; a percentage stays.
        .length => |len| if (len.unit == .px or len.unit == .percent) .initial else .compute,
        // Color 4 6.4: currentcolor stays symbolic outside `color` itself,
        // and an rgba color is already computed.
        .color => |c| switch (c) {
            .rgba, .current => .initial,
            else => .compute,
        },
        else => .compute,
    };
}

/// Each longhand's default path, from its initial computed value.
pub const default_path: [Longhand.count]DefaultPath = blk: {
    @setEvalBranchQuota(100_000);
    var out: [Longhand.count]DefaultPath = undefined;
    for (0..Longhand.count) |i| out[i] = defaultPathFor(@enumFromInt(i), computed_mod.initial_values[i]);
    break :blk out;
};

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
    custom_candidates: []const CustomCandidate = &.{},
    /// One per custom property name with candidates, sorted by name.
    custom_states: std.ArrayList(CustomState) = .empty,
    /// Values 5 Appendix A: the substitution contexts being guarded.
    guards: std.ArrayList(Guard) = .empty,
    /// font-size and line-height are computed once, by run() or earlier when
    /// a registered property's font-relative units pull them in.
    font_size_done: bool = false,
    line_height_done: bool = false,

    const CustomState = struct {
        name: *custom_mod.Text,
        /// The name's candidates: custom_candidates[first..end].
        first: usize,
        end: usize,
        status: enum { unresolved, resolving, done } = .unresolved,
        /// One reference, once done; null is the guaranteed-invalid value.
        value: ?*custom_mod.Text = null,
    };

    const GuardKind = substitution.GuardKind;

    const Guard = struct {
        kind: GuardKind,
        name: []const u8,
        cyclic: bool = false,
    };

    const PendingResult = struct {
        value: *const @import("pending_values.zig").Pending,
        source: ValueSource,
        outcome: @import("pending_values.zig").Outcome,
    };
    fn deinit(self: *Builder) void {
        for (self.pending.items) |entry| entry.outcome.deinit(self.ctx.allocator);
        self.pending.deinit(self.ctx.allocator);
        for (self.custom_states.items) |state| if (state.value) |v| v.release();
        self.custom_states.deinit(self.ctx.allocator);
        self.guards.deinit(self.ctx.allocator);
    }

    // ------------------------------------------------------------------------
    // Custom properties (CSS Variables 1 §§2-3, Values 5 Appendix A)
    // ------------------------------------------------------------------------

    /// The custom property phase, before any longhand: unregistered custom
    /// properties depend only on one another and the environment, and any
    /// longhand may reference one. Like WebKit's Builder (applyCustomProperty
    /// on reference, applyCustomProperties for the rest) and Blink's
    /// StyleCascade LookupAndApply, a property referenced by var() is
    /// resolved when referenced, the others in order; each once.
    /// The custom property states, one per name with candidates, before any
    /// longhand: each resolves when a var() first reaches it.
    fn collectCustomStates(self: *Builder) Allocator.Error!void {
        var first: usize = 0;
        while (first < self.custom_candidates.len) {
            const name = self.custom_candidates[first].decl.name;
            var end = first + 1;
            while (end < self.custom_candidates.len and std.mem.eql(u8, self.custom_candidates[end].decl.name.bytes, name.bytes)) end += 1;
            try self.custom_states.append(self.ctx.allocator, .{ .name = name, .first = first, .end = end });
            first = end;
        }
    }

    fn resolveCustomProperties(self: *Builder) Allocator.Error!void {
        const parent_record: ?*custom_mod.CustomProperties = if (self.ctx.parent) |p| p.custom else null;
        if (self.custom_candidates.len == 0) {
            // No declaration: the inherited map, shared (no copy), and no
            // non-inherited record (an unset registered property is its
            // initial value, which the snapshot holds).
            if (parent_record) |r| {
                r.retain();
                self.style.custom = r;
            }
            return;
        }
        const allocator = self.ctx.allocator;
        for (0..self.custom_states.items.len) |i| {
            if (self.custom_states.items[i].status == .unresolved) try self.resolveCustom(i);
        }
        // The records: the values this cascade changed over what the
        // element would take by default - the parent's inherited record, or
        // for an `inherits: false` registered property its initial value.
        var changes: std.ArrayList(custom_mod.CustomProperties.Entry) = .empty;
        defer changes.deinit(allocator);
        var own: std.ArrayList(custom_mod.CustomProperties.Entry) = .empty;
        defer own.deinit(allocator);
        for (self.custom_states.items) |state| {
            const reg = self.registration(state.name.bytes);
            if (reg != null and !reg.?.inherits) {
                if (!sameText(state.value, reg.?.initial)) try own.append(allocator, .{ .name = state.name, .value = state.value });
                continue;
            }
            const inherited: ?*custom_mod.Text = if (parent_record) |r| switch (r.lookup(state.name.bytes)) {
                .value => |v| v,
                .invalid => null,
                .absent => if (reg) |g| g.initial else null,
            } else if (reg) |g| g.initial else null;
            if (!sameText(state.value, inherited)) try changes.append(allocator, .{ .name = state.name, .value = state.value });
        }
        if (own.items.len != 0) self.style.custom_own = try custom_mod.CustomProperties.create(allocator, null, own.items);
        if (changes.items.len == 0) {
            if (parent_record) |r| {
                r.retain();
                self.style.custom = r;
            }
            return;
        }
        self.style.custom = try custom_mod.CustomProperties.create(allocator, parent_record, changes.items);
    }

    /// The registration of `name` when it has a syntax other than the
    /// universal one - the properties whose computed value is typed.
    fn typedRegistration(self: *const Builder, name: []const u8) ?*const registered_mod.Snapshot.Entry {
        const reg = self.registration(name) orelse return null;
        return if (reg.syntax.universal) null else reg;
    }

    /// Properties and Values API 1 §2.4: `text` (the specified value with
    /// its arbitrary substitution functions substituted) parsed against the
    /// registration's syntax and computed; the computed value's
    /// serialization is what var() substitutes (Blink CustomProperty::
    /// ApplyValue -> ConvertRegisteredPropertyValue ->
    /// ConvertRegisteredPropertyVariableData; WebKit
    /// computeCustomPropertyValueForSyntax). A failed parse is invalid at
    /// computed-value time: unset. Retained.
    fn typedCustom(self: *Builder, name: []const u8, reg: *const registered_mod.Snapshot.Entry, text: []const u8, taint: []const substitution.TaintRange, pending: ?*const @import("pending_values.zig").Pending) Allocator.Error!?*custom_mod.Text {
        // §2.5 / unit-cycles.html: font-relative units make font-size (and
        // lh line-height) a dependency. While that property is itself being
        // substituted - its var() reached here - both are in a cycle (Blink
        // StyleCascade HasFontSizeDependency -> CascadeResolver::
        // DetectCycle); otherwise it is computed first (WebKit: a font-size
        // dependency calls updateFont()).
        const deps = fontDependencies(text, self.ctx.is_root);
        if (deps.font_size or deps.line_height) {
            if (self.wouldCycle(.property, Longhand.font_size.name())) {
                self.markIfCyclic(.property, Longhand.font_size.name());
                return retained(self.defaultCustom(name));
            }
            if (deps.line_height and self.wouldCycle(.property, Longhand.line_height.name())) {
                self.markIfCyclic(.property, Longhand.line_height.name());
                return retained(self.defaultCustom(name));
            }
            try self.ensureFontSize();
            if (deps.line_height) try self.ensureLineHeight();
        }
        const allocator = self.ctx.allocator;
        const bytes = (try self.computeTyped(allocator, reg, text, pending)) orelse return retained(self.defaultCustom(name));
        errdefer allocator.free(bytes);
        // Computation reorders tokens, so taint covers the whole value when
        // any input token was tainted (both shipping browsers taint a var()
        // value as a whole when attr() produced tokens in it; RULINGS 1025t).
        const whole: []substitution.TaintRange = if (taint.len == 0) &.{} else blk: {
            const ranges = try allocator.alloc(substitution.TaintRange, 1);
            ranges[0] = .{ .start = 0, .end = bytes.len, .kind = .own };
            break :blk ranges;
        };
        errdefer if (whole.len != 0) allocator.free(whole);
        return try custom_mod.Text.adopt(allocator, bytes, whole);
    }

    /// `text` parsed against `reg`'s syntax and computed in this element's
    /// context, serialized (owned by `allocator`); null when the syntax
    /// does not match.
    fn computeTyped(self: *Builder, allocator: Allocator, reg: *const registered_mod.Snapshot.Entry, text: []const u8, pending: ?*const @import("pending_values.zig").Pending) Allocator.Error!?[]u8 {
        // A declaration's own url()s resolve against its base (the
        // pending value keeps them); a query value's are left as written.
        var value = (if (pending) |p|
            try p.parseSyntax(allocator, &reg.syntax, text, self.ctx.url_resolver)
        else
            try reg.syntax.parseValue(.{ .allocator = allocator }, text)) orelse return null;
        defer value.deinit();
        var computed = try value.compute(allocator, .{
            .math = self.mathContext(.width),
            .color = .{ .scheme = self.used_scheme },
            .writing_mode = self.writing_mode,
            .direction = self.direction,
        });
        defer computed.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try computed.serialize(&out, allocator);
        return try out.toOwnedSlice(allocator);
    }

    const FontDependencies = struct { font_size: bool = false, line_height: bool = false };

    /// Which of font-size and line-height a registered value's units read
    /// (the units syntax_values.isComputationallyIndependent rejects): em,
    /// ex, cap, ch, ic read font-size, lh line-height; their root forms read
    /// the root's, which is this element only on the root.
    fn fontDependencies(text: []const u8, is_root: bool) FontDependencies {
        var deps: FontDependencies = .{};
        var tokenizer = @import("tokenizer.zig").Tokenizer.init(text);
        while (true) {
            const token = tokenizer.next();
            if (token.token_type == .eof) return deps;
            if (token.token_type != .dimension) continue;
            const unit = token.unit orelse continue;
            const nameEql = @import("tokenizer.zig").nameEql;
            inline for (.{ "em", "ex", "cap", "ch", "ic" }) |u| if (nameEql(unit, u)) {
                deps.font_size = true;
            };
            if (nameEql(unit, "lh")) deps.line_height = true;
            if (is_root) {
                inline for (.{ "rem", "rex", "rcap", "rch", "ric" }) |u| if (nameEql(unit, u)) {
                    deps.font_size = true;
                };
                if (nameEql(unit, "rlh")) deps.line_height = true;
            }
        }
    }

    fn ensureFontSize(self: *Builder) Allocator.Error!void {
        if (self.font_size_done) return;
        self.font_size_done = true;
        _ = try self.computeAndStore(.font_size);
    }

    fn ensureLineHeight(self: *Builder) Allocator.Error!void {
        if (self.line_height_done) return;
        try self.ensureFontSize();
        self.line_height_done = true;
        _ = try self.computeAndStore(.line_height);
    }

    fn sameText(a: ?*custom_mod.Text, b: ?*custom_mod.Text) bool {
        if (a == null or b == null) return a == null and b == null;
        return a.?.eql(b.?);
    }

    /// The registration of custom property `name`, or null: unregistered.
    fn registration(self: *const Builder, name: []const u8) ?*const registered_mod.Snapshot.Entry {
        const snapshot = self.ctx.registered orelse return null;
        return snapshot.find(name);
    }

    /// The initial value of `name`: a registered property's computed
    /// initial value, else the guaranteed-invalid value (null). Borrowed.
    fn initialCustom(self: *const Builder, name: []const u8) ?*custom_mod.Text {
        const reg = self.registration(name) orelse return null;
        return reg.initial;
    }

    /// The parent's computed value of `name` ("inherit"); the initial value
    /// at the root. Borrowed.
    fn parentCustom(self: *const Builder, name: []const u8) ?*custom_mod.Text {
        const parent = self.ctx.parent orelse return self.initialCustom(name);
        return parent.customValueIn(name, self.ctx.registered);
    }

    /// What `name` computes to when no declaration applies, and for
    /// `unset`: the parent's value for an inherited property (every
    /// unregistered one), the initial value for an `inherits: false` one.
    fn defaultCustom(self: *const Builder, name: []const u8) ?*custom_mod.Text {
        if (self.registration(name)) |reg| if (!reg.inherits) return reg.initial;
        return self.parentCustom(name);
    }

    fn retained(text: ?*custom_mod.Text) ?*custom_mod.Text {
        if (text) |t| t.retain();
        return text;
    }

    fn findCustom(self: *const Builder, name: []const u8) ?usize {
        var lo: usize = 0;
        var hi = self.custom_states.items.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            switch (std.mem.order(u8, self.custom_states.items[mid].name.bytes, name)) {
                .eq => return mid,
                .lt => lo = mid + 1,
                .gt => hi = mid,
            }
        }
        return null;
    }

    /// Values 5 Appendix A, "guard" a substitution context: a context
    /// already guarded marks every context from it to the top cyclic.
    fn guard(self: *Builder, kind: GuardKind, name: []const u8) Allocator.Error!usize {
        self.markIfCyclic(kind, name);
        const at = self.guards.items.len;
        try self.guards.append(self.ctx.allocator, .{ .kind = kind, .name = name });
        return at;
    }

    /// The guard's end; whether its context was marked cyclic.
    fn unguard(self: *Builder, at: usize) bool {
        const cyclic = self.guards.items[at].cyclic;
        self.guards.items.len = at;
        return cyclic;
    }

    /// Whether guarding (kind, name) now would find a cycle - a query that
    /// marks nothing.
    fn wouldCycle(self: *const Builder, kind: GuardKind, name: []const u8) bool {
        for (self.guards.items) |g| if (g.kind == kind and std.mem.eql(u8, g.name, name)) return true;
        return false;
    }

    fn markIfCyclic(self: *Builder, kind: GuardKind, name: []const u8) void {
        // Blink CascadeResolver::DetectCycle: [cycle_start, top) is in the
        // cycle.
        for (self.guards.items, 0..) |g, k| if (g.kind == kind and std.mem.eql(u8, g.name, name)) {
            for (self.guards.items[k..]) |*entry| entry.cyclic = true;
            return;
        };
    }

    /// "Property replacement" of custom property `custom_states[i]`, under
    /// its ("property", name) guard. A cycle makes it guaranteed-invalid,
    /// fallback or not (Values 5: "When a cycle is detected, all
    /// participants in the cycle become invalid").
    fn resolveCustom(self: *Builder, i: usize) Allocator.Error!void {
        // Codex row 122 Q39 ruling: a referenced custom property's computed
        // value belongs to the element, so it is computed without the
        // caller's attribute guards (attr-cycle.html case 27: --y's raw
        // read of data-foo inside --x's attr(data-foo type(*)) is no
        // cycle); property guards still stack, so property cycles are
        // caught, and within one substitution chain every attr() lookup
        // stays guarded (Q24, probe 1025q). Blink keeps one stack
        // (CascadeResolver: style_cascade.cc ResolveAttrInto locks
        // {kAttribute, name}, ResolveVarInto -> LookupAndApply applies the
        // referenced property under the same resolver and returns false
        // when that caused a cycle), so there the result follows the order
        // custom properties are applied in; this makes it order-independent.
        const saved = try self.hideAttributeGuards();
        defer self.restoreGuards(saved);
        try self.resolveCustomGuarded(i);
    }

    /// The guard stack while attribute guards are hidden: the caller's
    /// whole stack, and where each guard of the view came from.
    const SavedGuards = struct {
        outer: ?std.ArrayList(Guard) = null,
        origin: []usize = &.{},
    };

    /// Replaces the guard stack with its property (and function) guards
    /// alone; restoreGuards puts the whole stack back, carrying any cycle
    /// mark made meanwhile to the guard it came from.
    fn hideAttributeGuards(self: *Builder) Allocator.Error!SavedGuards {
        var hidden: usize = 0;
        for (self.guards.items) |g| if (g.kind == .attribute) {
            hidden += 1;
        };
        if (hidden == 0) return .{};
        const allocator = self.ctx.allocator;
        const kept = self.guards.items.len - hidden;
        const origin = try allocator.alloc(usize, kept);
        errdefer allocator.free(origin);
        var view: std.ArrayList(Guard) = try .initCapacity(allocator, kept);
        for (self.guards.items, 0..) |g, k| if (g.kind != .attribute) {
            origin[view.items.len] = k;
            view.appendAssumeCapacity(g);
        };
        const outer = self.guards;
        self.guards = view;
        return .{ .outer = outer, .origin = origin };
    }

    fn restoreGuards(self: *Builder, saved: SavedGuards) void {
        const outer = saved.outer orelse return;
        for (self.guards.items[0..saved.origin.len], saved.origin) |g, k| if (g.cyclic) {
            outer.items[k].cyclic = true;
        };
        self.guards.deinit(self.ctx.allocator);
        self.guards = outer;
        self.ctx.allocator.free(saved.origin);
    }

    fn resolveCustomGuarded(self: *Builder, i: usize) Allocator.Error!void {
        self.custom_states.items[i].status = .resolving;
        const name = self.custom_states.items[i].name.bytes;
        const at = try self.guard(.property, name);
        var value = self.computeCustom(i) catch |err| {
            _ = self.unguard(at);
            self.custom_states.items[i].status = .done;
            return err;
        };
        if (self.unguard(at)) {
            if (value) |v| v.release();
            // In a cycle: invalid at computed-value time - the
            // guaranteed-invalid value, or for a registered property with a
            // syntax, unset (Values 5 "Invalid Substitution"; unit-cycles.html).
            value = if (self.typedRegistration(name) != null) retained(self.defaultCustom(name)) else null;
        }
        self.custom_states.items[i].value = value;
        self.custom_states.items[i].status = .done;
    }

    /// Cascade 5 §§6-7.3 for one custom property, then its computed value
    /// (CSS Variables 1 §2: "specified value with variables substituted, or
    /// the guaranteed-invalid value"). Retained; null is the
    /// guaranteed-invalid value.
    fn computeCustom(self: *Builder, i: usize) Allocator.Error!?*custom_mod.Text {
        const state = self.custom_states.items[i];
        const name = state.name.bytes;
        var excluded = Exclusions{};
        var position = state.first;
        while (position < state.end) : (position += 1) {
            const c = self.custom_candidates[position];
            if (excluded.excludesSource(c.source, c.decl.important)) continue;
            const keyword: values.CssWide = switch (c.decl.value) {
                .css_wide => |k| k,
                .text => |t| {
                    if (self.typedRegistration(name)) |reg| return self.typedCustom(name, reg, t.bytes, t.taint, null);
                    t.retain();
                    return t;
                },
                .pending => |pending| blk: {
                    var host = self.substitutionHost(self.mathContext(.width));
                    host.tree_scope = c.source.tree_scope.serial;
                    switch (try pending.substituteCustom(self.ctx.allocator, host, name)) {
                        // Values 5 "Invalid Substitution": an unregistered
                        // (or universal) custom property's computed value is
                        // the guaranteed-invalid value; a registered one with
                        // a syntax is unset.
                        .invalid => return if (self.typedRegistration(name) != null) retained(self.defaultCustom(name)) else null,
                        // Q83: missing random input skips the candidate.
                        .unavailable => continue,
                        .substituted => |result| {
                            // "If a property value, after property
                            // replacement, contains only a single CSS-wide
                            // keyword ..., its value is determined as if
                            // that keyword were its specified value all
                            // along."
                            if (substitution.soleKeyword(result.text)) |keyword| {
                                self.ctx.allocator.free(result.text);
                                self.ctx.allocator.free(result.taint);
                                break :blk values.CssWide.parse(keyword).?;
                            }
                            if (self.typedRegistration(name)) |reg| {
                                defer {
                                    self.ctx.allocator.free(result.text);
                                    self.ctx.allocator.free(result.taint);
                                }
                                return self.typedCustom(name, reg, result.text, result.taint, pending);
                            }
                            errdefer {
                                self.ctx.allocator.free(result.text);
                                self.ctx.allocator.free(result.taint);
                            }
                            return try custom_mod.Text.adopt(self.ctx.allocator, result.text, result.taint);
                        },
                    }
                },
            };
            switch (keyword) {
                // §2.2: initial is the guaranteed-invalid value for an
                // unregistered property; a registered one's is its
                // registration's (Properties and Values API 1 §2.4).
                .initial => return retained(self.initialCustom(name)),
                .inherit => return retained(self.parentCustom(name)),
                // Unregistered custom properties are inherited, so unset is
                // inherit; a registered one follows its `inherits`.
                .unset => return retained(self.defaultCustom(name)),
                .revert => {
                    if (c.source.origin == .user_agent) return retained(self.defaultCustom(name));
                    excluded.revert_class_at_least = @min(excluded.revert_class_at_least, c.source.origin.revertClass());
                },
                .revert_layer => excluded.addLevel(c.source.*, c.decl.important),
                .revert_rule => excluded.addRule(c.source),
            }
        }
        // No declaration left: the default.
        return retained(self.defaultCustom(name));
    }

    /// substitution.Host's var() lookup: this element's custom property,
    /// resolved now if it is declared here and not yet, else the inherited
    /// value. A reference to one being resolved is a cycle.
    fn customValueCallback(context: *anyopaque, name: []const u8) substitution.Error!?substitution.Computed {
        const self: *Builder = @ptrCast(@alignCast(context));
        if (self.findCustom(name)) |i| {
            switch (self.custom_states.items[i].status) {
                .done => {},
                .resolving => {
                    self.markIfCyclic(.property, name);
                    return null;
                },
                .unresolved => try self.resolveCustom(i),
            }
            const value = self.custom_states.items[i].value orelse return null;
            return value.computed();
        }
        // No declaration here: the default (inherited or initial).
        const value = self.defaultCustom(name) orelse return null;
        return value.computed();
    }

    /// inherit() (Values 5 §8.6, Codex row 123): the parent's computed value
    /// of `name`; at the root the initial value, guaranteed-invalid for an
    /// unregistered custom property.
    fn parentCustomValueCallback(context: *anyopaque, name: []const u8) substitution.Error!?substitution.Computed {
        const self: *Builder = @ptrCast(@alignCast(context));
        const value = self.parentCustom(name) orelse return null;
        return value.computed();
    }

    fn hasValueCallback(context: *anyopaque, name: []const u8) substitution.Error!substitution.Flagged(bool) {
        if (!custom_mod.isName(name)) return .{ .value = false, .tainted = false };
        const value = (try customValueCallback(context, name)) orelse return .{ .value = false, .tainted = false };
        return .{ .value = true, .tainted = value.taint.len != 0 };
    }

    /// style(name: value) (CSS Conditional 5 §6.2; Values 5 if()): the
    /// query value computed as `name`'s own value would be, compared with the
    /// element's computed value. A CSS-wide keyword computes as it does in a
    /// declaration (integrator probes 1025h/1025i, RULINGS.md - Chrome, the
    /// one browser shipping if(); Blink StyleCascade::EvalIfStyleFeature
    /// resolves the query value like a declaration of the property):
    /// `initial` is the property's initial value - guaranteed-invalid for an
    /// unregistered custom property, so it matches a missing one; `inherit`
    /// is the parent's computed value; `unset` is `inherit`, custom
    /// properties being inherited; `revert`, `revert-layer` and
    /// `revert-rule` make the feature false (row 123 Q5 ruling,
    /// tmp/plans/codex-condfns-questions.md). A registered property's
    /// initial value and `inherits` are its registration's.
    fn queryValueMatchesCallback(context: *anyopaque, name: []const u8, value_text: []const u8) substitution.Error!?substitution.Flagged(bool) {
        const self: *Builder = @ptrCast(@alignCast(context));
        if (!custom_mod.isName(name)) return null;
        if (custom_mod.cssWideKeyword(value_text)) |keyword| {
            const current = try customValueCallback(context, name);
            const expected: ?substitution.Computed = switch (keyword) {
                .initial => computedOf(self.initialCustom(name)),
                .inherit => computedOf(self.parentCustom(name)),
                .unset => computedOf(self.defaultCustom(name)),
                .revert, .revert_layer, .revert_rule => return .{ .value = false, .tainted = false },
            };
            const tainted = (if (current) |c| c.taint.len != 0 else false) or (if (expected) |e| e.taint.len != 0 else false);
            const equal = if (current == null or expected == null) current == null and expected == null else tokensEqual(current.?.text, expected.?.text);
            return .{ .value = equal, .tainted = tainted };
        }
        var arena = std.heap.ArenaAllocator.init(self.ctx.allocator);
        defer arena.deinit();
        var query = try self.substituteText(arena.allocator(), value_text);
        // A registered property with a syntax: the query value parsed and
        // computed under its registration (a mismatch matches nothing),
        // compared with the element's computed value.
        if (self.typedRegistration(name)) |reg| {
            query.text = (try self.computeTyped(arena.allocator(), reg, query.text, null)) orelse return .{ .value = false, .tainted = query.tainted };
        }
        const value = (try customValueCallback(context, name)) orelse return .{ .value = false, .tainted = query.tainted };
        return .{ .value = tokensEqual(value.text, query.text), .tainted = query.tainted or value.taint.len != 0 };
    }

    fn computedOf(text: ?*custom_mod.Text) ?substitution.Computed {
        const t = text orelse return null;
        return t.computed();
    }

    fn numericValueCallback(context: *anyopaque, operand: []const u8) substitution.Error!?substitution.Flagged(substitution.Numeric) {
        const self: *Builder = @ptrCast(@alignCast(context));
        var arena = std.heap.ArenaAllocator.init(self.ctx.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const text: Substituted = if (try substitution.customPropertyName(a, operand)) |name| blk: {
            const value = (try customValueCallback(context, name)) orelse return null;
            break :blk .{ .text = value.text, .tainted = value.taint.len != 0 };
        } else try self.substituteText(a, operand);
        const number = (try self.numeric(a, text.text)) orelse return null;
        return .{ .value = number, .tainted = text.tainted };
    }

    fn mediaCallback(context: *anyopaque, query_text: []const u8) substitution.Error!bool {
        const self: *Builder = @ptrCast(@alignCast(context));
        const media = self.ctx.media_values orelse &@import("media_queries.zig").MediaValues{};
        return @import("media_queries.zig").MediaQueryList.evaluateTest(self.ctx.allocator, query_text, media);
    }

    fn supportsCallback(context: *anyopaque, text: []const u8, quirks: bool) substitution.Error!bool {
        const self: *Builder = @ptrCast(@alignCast(context));
        return @import("supports.zig").evaluateTest(self.ctx.allocator, text, quirks, self.ctx.selector_check);
    }

    const Substituted = struct { text: []const u8, tainted: bool };

    /// `text` with its arbitrary substitution functions substituted for
    /// this element, and whether that brought in taint; error.Invalid for
    /// the guaranteed-invalid value.
    fn substituteText(self: *Builder, allocator: Allocator, text: []const u8) substitution.Error!Substituted {
        const source = substitution.originalText(text);
        if (!substitution.mentionsFunction(source)) return .{ .text = source, .tainted = false };
        const nodes = try substitution.parse(allocator, source);
        const rendered = try substitution.substituteAndRender(allocator, nodes, self.substitutionHost(self.mathContext(.width)), .{});
        return .{ .text = rendered.text, .tainted = rendered.taint.len != 0 };
    }

    /// One numeric value of `text` - a number, percentage or dimension token,
    /// or a math function - computed with the shared math in this element's
    /// context and converted to canonical units.
    fn numeric(self: *Builder, allocator: Allocator, text: []const u8) Allocator.Error!?substitution.Numeric {
        const math = @import("math_values.zig");
        const context = self.mathContext(.width);
        var stream = properties.Stream.init(text);
        const token = stream.peek();
        const literal: ?math.Numeric = switch (token.token_type) {
            .number => .{ .value = token.numeric_value orelse return null, .unit = .number },
            .percentage => .{ .value = token.numeric_value orelse return null, .unit = .percent },
            .dimension => .{ .value = token.numeric_value orelse return null, .unit = math.Unit.parse(token.unit orelse return null) orelse return null },
            else => null,
        };
        const value: math.Numeric = if (literal) |n| blk: {
            _ = stream.next();
            if (!stream.atEnd()) return null;
            break :blk context.resolve(n);
        } else blk: {
            for ([_]math.Kind{ .number, .percentage, .length, .angle, .time, .resolution }) |kind| {
                var attempt = properties.Stream.init(text);
                const parsed = (try properties.mathValue(.{ .allocator = allocator }, &attempt, .{ .kind = kind })) orelse continue;
                defer parsed.release();
                if (!attempt.atEnd()) continue;
                const computed = try parsed.calculation.compute(allocator, context);
                defer computed.unref();
                const known = computed.knownNumber() orelse return null;
                break :blk context.resolve(known);
            }
            return null;
        };
        const dimension: substitution.Numeric.Dimension = switch (value.unit.base() orelse return .{ .value = value.value, .dimension = .number }) {
            .percent => .percentage,
            .length => if (value.unit == .px) .length else return null,
            .angle => .angle,
            .time => .time,
            .frequency => .frequency,
            .resolution => .resolution,
            .flex => return null,
        };
        return .{ .value = value.value, .dimension = dimension };
    }

    /// attr() (Codex row 122): the element's attribute through the DOM's
    /// Context.content_attributes lookup (the originating element's for a
    /// pseudo-element). Batch 1 answers the no-namespace case only - a
    /// prefixed name gives null, so the fallback applies - until row 122
    /// extends the lookup with namespaces and the winning declaration's tree
    /// scope (passed here already).
    fn attributeCallback(context: *anyopaque, tree_scope: u64, map: ?*const substitution.NamespaceMap, prefix: ?[]const u8, local_name: []const u8) ?substitution.Attribute {
        _ = tree_scope;
        _ = map;
        const self: *Builder = @ptrCast(@alignCast(context));
        if (prefix != null) return null;
        const lookup = self.ctx.content_attributes orelse return null;
        const value = lookup.get(lookup.context, local_name) orelse return null;
        return .{ .value = value, .namespace = null, .local_name = local_name };
    }

    fn guardCallback(context: *anyopaque, kind: substitution.GuardKind, name: []const u8) Allocator.Error!usize {
        const self: *Builder = @ptrCast(@alignCast(context));
        return self.guard(kind, name);
    }

    fn unguardCallback(context: *anyopaque, at: usize) bool {
        const self: *Builder = @ptrCast(@alignCast(context));
        return self.unguard(at);
    }

    fn wouldCycleCallback(context: *anyopaque, kind: substitution.GuardKind, name: []const u8) bool {
        const self: *Builder = @ptrCast(@alignCast(context));
        return self.wouldCycle(kind, name);
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
            var host = self.substitutionHost(context);
            host.tree_scope = source.tree_scope.serial;
            // Values 5 "replace substitution functions in a property": the
            // property's own ("property", name) context is guarded.
            const guarded = try self.guard(.property, l.name());
            var outcome = pending.resolve(self.ctx.allocator, host, self.ctx.url_resolver) catch |err| {
                _ = self.unguard(guarded);
                return err;
            };
            if (self.unguard(guarded)) {
                outcome.deinit(self.ctx.allocator);
                outcome = .invalid;
            }
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

    /// What substitution reads from this element (substitution.Host): its
    /// custom properties, the environment and the math context.
    fn substitutionHost(self: *Builder, context: @import("math_values.zig").Context) substitution.Host {
        return .{
            .context = self,
            .custom_value = customValueCallback,
            .parent_custom_value = parentCustomValueCallback,
            .attribute = attributeCallback,
            .guard = guardCallback,
            .unguard = unguardCallback,
            .would_cycle = wouldCycleCallback,
            .has_value = hasValueCallback,
            .query_value_matches = queryValueMatchesCallback,
            .numeric_value = numericValueCallback,
            .media = mediaCallback,
            .supports = supportsCallback,
            .environment = self.ctx.environment,
            .math = context,
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
                    .revert_layer => excluded.add(winner),
                    // Cascade 5 7.3.6: "as if the current style rule had not
                    // been present at all" - every declaration of the rule
                    // (one matched block) is passed over.
                    .revert_rule => excluded.addRule(winner.source),
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
                .column_size => true,
                else => false,
            };
            // Q25/Q83/Q88: this is the single unavailable-input decision,
            // after pending substitution has selected just its live branch.
            // Q59/Q92: a null font View is defensive; unavailable scalar
            // inputs are already excluded by this same decision.
            const unavailable = preflight.unavailable or (assigned == .value and
                (assigned.value.needsUnavailableMetrics(geometry_length) or
                    (self.ctx.random_base == null and assigned.value.needsRandomBase()) or
                    (assigned.value == .font_size_adjust and assigned.value.font_size_adjust.fromFont() and
                        (self.ctx.font_metric_ratios == null or @import("font_request.zig").fromComputed(self.style) == null))));
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
        // CSS Variables 1: the custom property states first - any longhand,
        // the high-priority ones included, may substitute one, which then
        // resolves when it is first reached.
        try self.collectCustomStates();
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
        try self.ensureFontSize();
        try self.ensureLineHeight();
        // The custom properties not yet reached by a var(): after font-size
        // and line-height, which a registered one's font-relative units read
        // (Blink StyleCascade::Apply applies custom properties after
        // UpdateFont and line-height, pulling them in earlier on demand).
        try self.resolveCustomProperties();
        _ = try self.computeAndStore(.color);
        for (0..Longhand.count) |i| {
            const l: Longhand = @enumFromInt(i);
            if (l.logical() != null or isHighPriority(l)) continue;
            // Untouched: the defaulting step without the compute walk
            // (design: Blink StyleResolver::InitStyle -> CreateNewStyle takes
            // non-inherited data from the initial style and inherited data
            // from the parent, and StyleCascade applies only declared
            // properties; WebKit's Resolver::initializeStateAndStyle does
            // inheritFrom(parent) and its Builder applies only the
            // PropertyCascade). A longhand with candidates, even all of them
            // later skipped, takes specified() below, unchanged.
            if (self.index.heads[i] == CandidateIndex.none) switch (default_path[i]) {
                // compute(.inherit) without the dispatch: the parent's value,
                // or initialComputed at the root (color is high-priority).
                .inherit => {
                    const v = self.parentValue(l);
                    v.retain();
                    self.style.values[i] = v;
                    continue;
                },
                // The slot already holds initial_values[i], which is what
                // compute(.initial) yields for an allowlisted longhand.
                .initial => continue,
                .compute => {},
            };
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
        // Fonts4 §2.7: resolve the pending system value before the scalar
        // font-size/weight/width paths, retaining no borrowed provider data.
        if (v == .font_system) {
            const selected = try @import("font_system.zig").compute(self.ctx.allocator, self.ctx.system_fonts, v.font_system, l);
            defer selected.release();
            return self.computeValue(l, selected, source);
        }
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
        if (l == .outline_width or l == .column_rule_width) {
            // UI 4 §3.4 computes width independently of outline-style:none.
            // Multicol 1 §4.4 likewise retains an undrawn rule's width.
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
                    if (try v.content.compute(self.ctx.allocator, self.ctx.content_attributes)) |content| {
                        defer content.unref();
                        return .{ .content = try content.computeImages(self.ctx.allocator, ComponentContext.init(self, source)) };
                    }
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
            .fill, .stroke => return @import("svg_paint.zig").compute(v, self.ctx.allocator, .{ .scheme = self.used_scheme, .math = self.computationContext(l, v, source) }),
            .stroke_width => if (v == .number) return Value.px(v.number),
            .font_size => return Value.px(self.computeFontSize(v)),
            .font_weight => return .{ .number = self.computeFontWeight(v) },
            .font_width => return @import("font_width.zig").compute(v),
            // CSS Text4 §8.2: normal is zero in the computed value.
            .letter_spacing => if (v.isKeyword(.normal)) return Value.px(0),
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
            .indent => |indent| {
                const offset = try self.computeValue(.margin_left, indent.offset, source);
                defer offset.release();
                return .{ .indent = try @import("text_indent.zig").Indent.create(self.ctx.allocator, offset, indent.flags) };
            },
            .filter => |value| return .{ .filter = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .box_shadow => |value| return .{ .box_shadow = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .shape => |value| return .{ .shape = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .corner_radius => |value| return .{ .corner_radius = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .image_resolution => |value| return .{ .image_resolution = try value.compute(self.ctx.allocator, self.computationContext(l, v, source)) },
            .image_position => |value| return .{ .image_position = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .image_size => |value| return .{ .image_size = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .image_quad => |value| return .{ .image_quad = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .layers => |value| return .{ .layers = try value.compute(self.ctx.allocator, l, ComponentContext.init(self, source)) },
            .image => |value| return value.compute(self.ctx.allocator, self.used_scheme, ComponentContext.init(self, source)),
            .cursor => |value| return .{ .cursor = try value.compute(self.ctx.allocator, ComponentContext.init(self, source)) },
            .image_axis => |value| return .{ .image_axis = try value.compute(self.ctx.allocator, if (l == .background_position_x) 0 else 1, ComponentContext.init(self, source)) },
            .font_oblique => |value| return value.compute(self.ctx.allocator, self.computationContext(l, v, source)),
            .font_settings => |value| return .{ .font_settings = try value.compute(self.ctx.allocator, self.computationContext(l, v, source)) },
            .font_family => |family| return .{ .font_family = try family.capture(self.ctx.allocator, source.tree_scope) },
            .font_size_adjust => |font_adjust| return switch (try font_adjust.compute(self.ctx.allocator, self.computationContext(l, v, source), self.ctx.font_metric_ratios, @import("font_request.zig").fromComputed(self.style))) {
                .value => |computed| computed,
                // The single unavailable decision skips real unavailable
                // candidates. Q87: a defensive failure computes as unset,
                // which for this inherited longhand is compute(.inherit):
                // the parent's value, retained. Written out rather than
                // calling compute(): a compute <-> computeValue recursion
                // stopped LLVM inlining compute into computeAndStore and
                // slowed every longhand of every element (Q212, lesson
                // debugging-a-hot-path-cost-can-be-a-call-graph-shape-...).
                .unavailable => blk: {
                    comptime std.debug.assert(Longhand.font_size_adjust.inherited());
                    const inherited = self.parentValue(l);
                    inherited.retain();
                    break :blk inherited;
                },
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
        const font_affecting = @import("font_values.zig").isFontAffecting(l);
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

        // Contain 2 §2: aliases share the computed flag set and shortest
        // serialization. No layout state or allocation is needed here.
        const containment = s.get(.contain).containment.computed();
        s.values[@intFromEnum(Longhand.contain)] = .{ .containment = containment };
        const parent_box = if (self.ctx.parent) |p| p.box_context else .other;
        s.box_context = if (parent_box == .suppressed or display.box == .none)
            .suppressed
        else if (display.box == .contents)
            parent_box
        else if (display.inner == .grid)
            .grid
        else
            .other;
        // Grid 2 §9: a subgrid must be an in-flow grid item and cannot
        // establish an independent formatting context. Contain 2 §§3.3,
        // 3.5 and §4: layout/paint containment, including content-visibility.
        const content_visibility = s.keyword(.content_visibility);
        const independent = containment.layout or containment.paint or content_visibility == .auto or content_visibility == .hidden;
        s.subgrid_ineligible = s.box_context != .suppressed and display.box == .normal and display.inner == .grid and
            (parent_box != .grid or out_of_flow or independent);

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
    /// The rules (matched blocks, by their Source) `revert-rule` discarded.
    rules: [8]*const Source = undefined,
    rule_count: usize = 0,

    const Level = struct { origin: Origin, layer: u16, important: bool };

    fn add(self: *Exclusions, c: Candidate) void {
        self.addLevel(c.source.*, c.decl.important);
    }

    fn addLevel(self: *Exclusions, source: Source, important: bool) void {
        if (self.count == self.layers.len) {
            // Deeper than any real chain: discard the whole origin.
            self.revert_class_at_least = @min(self.revert_class_at_least, source.origin.revertClass());
            return;
        }
        self.layers[self.count] = .{ .origin = source.origin, .layer = source.layer, .important = important };
        self.count += 1;
    }

    fn addRule(self: *Exclusions, source: *const Source) void {
        if (self.rule_count == self.rules.len) {
            // Deeper than any real chain: discard the rule's whole layer.
            self.addLevel(source.*, false);
            return;
        }
        self.rules[self.rule_count] = source;
        self.rule_count += 1;
    }

    fn excludes(self: *const Exclusions, c: Candidate) bool {
        return self.excludesSource(c.source, c.decl.important);
    }

    fn excludesSource(self: *const Exclusions, source_ref: *const Source, important: bool) bool {
        for (self.rules[0..self.rule_count]) |rule| if (rule == source_ref) return true;
        const source = source_ref.*;
        if (source.origin.revertClass() >= self.revert_class_at_least) return true;
        for (self.layers[0..self.count]) |lv| {
            if (lv.origin != source.origin or lv.layer != source.layer) continue;
            // An important level's revert-layer also passes the normal
            // declarations of its layer.
            if (lv.important or !important) return true;
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
    try expectResolved(child, .font_family, "A B, serif");
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
    var candidates = try Cv1Cascade.collectCandidates(testing.allocator, matched, null);
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
            try testing.expectEqual(parent.get(.font_family).font_family, result.get(.font_family).font_family);
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

// Component computation for structured CSS image/shape values, without layout.
const ComponentContext = struct {
    builder: *Builder,
    source: ValueSource,
    writing_mode: values.Keyword,
    direction: values.Keyword,

    fn init(builder: *Builder, source: ValueSource) ComponentContext {
        return .{ .builder = builder, .source = source, .writing_mode = builder.writing_mode, .direction = builder.direction };
    }
    pub fn length(self: ComponentContext, value: Value) Allocator.Error!Value {
        return self.builder.computeValue(.margin_left, value, self.source);
    }
    pub fn color(self: ComponentContext, value: values.Color) Allocator.Error!values.Color {
        return value.resolveComputed(self.builder.ctx.allocator, .{
            .scheme = self.builder.used_scheme,
            .math = self.builder.computationContext(.filter, .{ .color = value }, self.source),
        });
    }
    pub fn component(self: ComponentContext, longhand: Longhand, value: Value) Allocator.Error!Value {
        return self.builder.computeValue(longhand, value, self.source);
    }
};

// Q73/Q74: pin source capture separately from the nested Color consumer below.
test "ci1 nested component context copies its winning declaration source" {
    const allocator = testing.allocator;
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, "mask-size: 1em 2em");
    defer block.deinit();
    try testing.expect(block.entries.items.len > 0);
    var matched = [_]Matched{.{
        .block = &block,
        .source = .{ .origin = .author, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = false },
    }};
    var candidates = try collectCandidates(allocator, &matched, null);
    defer candidates.deinit(allocator);
    const links = try allocator.alloc(usize, candidates.items.len);
    defer allocator.free(links);
    var builder = Builder{
        .ctx = .{ .allocator = allocator, .parent = null },
        .candidates = candidates.items,
        .index = CandidateIndex.init(candidates.items, links),
    };
    const style = try allocator.create(ComputedStyle);
    style.* = .{ .allocator = allocator, .values = computed_mod.initial_values };
    defer style.destroy();
    builder.style = style;
    try builder.run();
    const winner = try builder.specified(.mask_size);
    try testing.expect(winner == .value);
    const context = ComponentContext.init(&builder, winner.value.source);
    matched[0].source.tree_scope.serial = 999;
    matched[0].source.tree_count_allowed = true;
    const length = try context.length(.{ .length = .{ .value = 2, .unit = .em } });
    defer length.release();
    try testing.expect(length.eql(Value.px(32)));
    const nested_value = try context.component(.mask_size, winner.value.value);
    defer nested_value.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try properties.serializeValue(.mask_size, nested_value, &out, allocator);
    try testing.expectEqualStrings("16px 32px", out.items);
    try testing.expectEqual(@as(u64, 71), context.source.tree_scope.serial);
    try testing.expect(!context.source.tree_count_allowed);
}

fn ci1NestedColorSource(allocator: Allocator, allowed: bool) !void {
    var low = try DeclarationBlock.parse(.{ .allocator = allocator }, "filter:drop-shadow(rgb(calc(sibling-index() * 20) 0 0) 1px 2px)");
    defer low.deinit();
    try testing.expect(low.get(.filter) != null);
    var high = try DeclarationBlock.parse(.{ .allocator = allocator }, "filter:revert");
    defer high.deinit();
    var matched = [_]Matched{
        .{ .block = &low, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
        .{ .block = &high, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
    };
    const Probe = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque) @import("math_values.zig").TreeCounts {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .index = 3, .count = 7 };
        }
    };
    var probe: Probe = .{};
    var candidates = try collectCandidates(allocator, &matched, null);
    defer candidates.deinit(allocator);
    const links = try allocator.alloc(usize, candidates.items.len);
    defer allocator.free(links);
    var builder = Builder{
        .ctx = .{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &probe, .get = Probe.get } },
        .candidates = candidates.items,
        .index = CandidateIndex.init(candidates.items, links),
    };
    const style = try allocator.create(ComputedStyle);
    style.* = .{ .allocator = allocator, .values = computed_mod.initial_values };
    defer style.destroy();
    builder.style = style;
    try builder.run();
    const winner = try builder.specified(.filter);
    try testing.expect(winner == .value);
    const context = ComponentContext.init(&builder, winner.value.source);
    matched[0].source.tree_scope.serial = 1234;
    matched[0].source.tree_count_allowed = !allowed;
    // Q74/Q93: the actual nested Color consumer sees the retained winner's
    // scope and permission even after the caller changes its Source record.
    try testing.expectEqual(@as(u64, 71), context.source.tree_scope.serial);
    try testing.expectEqual(allowed, context.source.tree_count_allowed);
    const nested = try context.component(.filter, winner.value.value);
    defer nested.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try nested.filter.serializeResolved(values.Color.black, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "drop-shadow(rgb(60, 0, 0) 1px 2px 0px)" else "drop-shadow(rgb(0, 0, 0) 1px 2px 0px)", out.items);
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), probe.calls);
}

test "ci1 winning source survives to a nested typed filter color consumer" {
    try testing.checkAllAllocationFailures(testing.allocator, ci1NestedColorSource, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, ci1NestedColorSource, .{true});
}

test "a defensive unavailable font-size-adjust computes as its inherited value" {
    var parent_block = try TestBlock.make("font-size-adjust: 0.4");
    defer parent_block.deinit();
    const parent = try cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &parent_block.block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var block = try TestBlock.make("font-size-adjust: cap-height from-font");
    defer block.deinit();
    var it = block.block.typed();
    const from_font = it.next().?.value.value;
    // No metric capability: Adjust.compute answers .unavailable, which the
    // cascade's pick() normally excludes before computeValue is reached.
    const style = try ComputedStyle.initial(testing.allocator);
    defer style.destroy();
    var no_links: [0]usize = .{};
    var builder: Builder = .{ .ctx = .{ .allocator = testing.allocator, .parent = parent }, .candidates = &.{}, .index = CandidateIndex.init(&.{}, &no_links), .style = style };
    defer builder.deinit();
    const v = try builder.computeValue(.font_size_adjust, from_font, .{});
    defer v.release();
    try testing.expect(std.meta.eql(parent.get(.font_size_adjust), v));
    // At the root the inherited value is the initial one.
    var root_builder: Builder = .{ .ctx = .{ .allocator = testing.allocator, .parent = null, .is_root = true }, .candidates = &.{}, .index = CandidateIndex.init(&.{}, &no_links), .style = style };
    defer root_builder.deinit();
    const root_value = try root_builder.computeValue(.font_size_adjust, from_font, .{});
    defer root_value.release();
    try testing.expect(std.meta.eql(computed_mod.initialComputed(.font_size_adjust), root_value));
}

/// The substitution Host of an element after its custom property phase, for
/// the if() style() query tests (rows 122/123 call these from a function's
/// replace; none of today's functions does).
fn withHost(allocator: Allocator, text: []const u8, parent_text: ?[]const u8, body: *const fn (substitution.Host) anyerror!void) !void {
    return withRegisteredHost(allocator, null, text, parent_text, body);
}

fn withRegisteredHost(allocator: Allocator, registered: ?*registered_mod.Snapshot, text: []const u8, parent_text: ?[]const u8, body: *const fn (substitution.Host) anyerror!void) !void {
    var parent: ?*ComputedStyle = null;
    defer if (parent) |p| p.destroy();
    if (parent_text) |pt| {
        var block = try DeclarationBlock.parse(.{ .allocator = allocator }, pt);
        defer block.deinit();
        parent = try cascade(.{ .allocator = allocator, .parent = null, .is_root = true, .registered = registered }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    }
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, text);
    defer block.deinit();
    const matched = [_]Matched{.{ .block = &block, .source = .{ .origin = .author } }};
    var candidates = try collectCandidates(allocator, &matched, null);
    defer candidates.deinit(allocator);
    const links = try allocator.alloc(usize, candidates.items.len);
    defer allocator.free(links);
    var customs = try collectCustomCandidates(allocator, &matched);
    defer customs.deinit(allocator);
    var builder: Builder = .{
        .ctx = .{ .allocator = allocator, .parent = parent, .selector_check = &hostTestSelectorCheck, .registered = registered },
        .candidates = candidates.items,
        .index = CandidateIndex.init(candidates.items, links),
        .custom_candidates = customs.items,
    };
    defer builder.deinit();
    const style = try allocator.create(ComputedStyle);
    style.* = .{ .allocator = allocator, .values = computed_mod.initial_values };
    defer style.destroy();
    builder.style = style;
    try builder.collectCustomStates();
    try builder.resolveCustomProperties();
    try body(builder.substitutionHost(builder.mathContext(.width)));
}

/// A stand-in for src/selector's check, as supports.zig's tests use: a
/// selector with `:unknown` does not parse.
fn hostTestSelectorCheck(allocator: Allocator, text: []const u8) bool {
    _ = allocator;
    return text.len != 0 and std.mem.indexOf(u8, text, ":unknown") == null;
}

test "if() supports(selector(...)) asks the context's selector check, as CSS.supports() does" {
    try withHost(testing.allocator, "--a: 1", null, struct {
        fn body(host: substitution.Host) anyerror!void {
            const supports = host.supports.?;
            try testing.expect(try supports(host.context, "selector(h2 > p)", false));
            try testing.expect(!try supports(host.context, "selector(h2:unknown)", false));
            try testing.expect(try supports(host.context, "not selector(h2:unknown)", false));
        }
    }.body);
}

test "a referenced custom property resolves without the caller's attribute guards; property guards stay and marks map back" {
    // Codex row 122 Q39 ruling (integrator, 2026-10-26): a referenced custom
    // property's computed value belongs to the element, so computing it on
    // demand starts WITHOUT the caller's attribute guards (attr-cycle.html
    // case 27); property guards still stack, so property cycles are caught.
    var no_links: [0]usize = .{};
    var builder: Builder = .{ .ctx = .{ .allocator = testing.allocator, .parent = null }, .candidates = &.{}, .index = CandidateIndex.init(&.{}, &no_links) };
    defer builder.deinit();
    _ = try builder.guard(.property, "--x");
    _ = try builder.guard(.attribute, "data-foo");
    _ = try builder.guard(.property, "--w");
    const saved = try builder.hideAttributeGuards();
    try testing.expectEqual(@as(usize, 2), builder.guards.items.len);
    try testing.expect(!builder.wouldCycle(.attribute, "data-foo"));
    try testing.expect(builder.wouldCycle(.property, "--x"));
    // A cycle back to --w found inside marks --w (and what is above it).
    builder.markIfCyclic(.property, "--w");
    builder.restoreGuards(saved);
    try testing.expectEqual(@as(usize, 3), builder.guards.items.len);
    try testing.expect(!builder.guards.items[0].cyclic);
    try testing.expect(!builder.guards.items[1].cyclic);
    try testing.expect(builder.guards.items[2].cyclic);
    try testing.expect(builder.wouldCycle(.attribute, "data-foo"));
}

test "style() queries: hasValue reads custom properties only" {
    try withHost(testing.allocator, "--a: 1; --empty:; --bad: var(--missing)", "--inherited: x", struct {
        fn body(host: substitution.Host) anyerror!void {
            try testing.expect((try host.has_value.?(host.context, "--a")).value);
            // The empty value is a value; the guaranteed-invalid one is not.
            try testing.expect((try host.has_value.?(host.context, "--empty")).value);
            try testing.expect(!(try host.has_value.?(host.context, "--bad")).value);
            try testing.expect(!(try host.has_value.?(host.context, "--absent")).value);
            try testing.expect((try host.has_value.?(host.context, "--inherited")).value);
            try testing.expect(!(try host.has_value.?(host.context, "color")).value);
            try testing.expect(!(try host.has_value.?(host.context, "--a")).tainted);
        }
    }.body);
}

test "style() queries: queryValueMatches compares tokens, substituting the query first" {
    try withHost(testing.allocator, "--a: red  blue; --n: 10px; --bad: var(--missing)", null, struct {
        fn body(host: substitution.Host) anyerror!void {
            const matches = host.query_value_matches.?;
            try testing.expect((try matches(host.context, "--a", "red blue")).?.value);
            try testing.expect((try matches(host.context, "--a", "  red /* c */ blue ")).?.value);
            try testing.expect(!(try matches(host.context, "--a", "red")).?.value);
            try testing.expect((try matches(host.context, "--n", "var(--n)")).?.value);
            try testing.expect(!(try matches(host.context, "--bad", "x")).?.value);
            try testing.expect(!(try matches(host.context, "--a", "red blue")).?.tainted);
            // A failed substitution of the query is an error the caller catches.
            try testing.expectError(error.Invalid, matches(host.context, "--a", "var(--missing)"));
            // Not a custom property: unknown.
            try testing.expect((try matches(host.context, "color", "red")) == null);
        }
    }.body);
}

test "style() queries: a CSS-wide keyword query value is computed as the property's own value would be" {
    // integrator probes 1025h/1025i (RULINGS.md, Chrome - the one browser
    // shipping if()): style(--missing: initial) is true; initial is the
    // guaranteed-invalid value for an unregistered custom property, inherit
    // the parent's computed value, unset inherit (custom properties
    // inherit); revert and revert-layer are false (row 123 Q5 ruling).
    try withHost(testing.allocator, "--a: red; --empty:; --bad: var(--missing); --same: x; --differs: y", "--same: x; --differs: z", struct {
        fn body(host: substitution.Host) anyerror!void {
            const matches = host.query_value_matches.?;
            // initial: a missing or guaranteed-invalid property matches.
            try testing.expect((try matches(host.context, "--missing", "initial")).?.value);
            try testing.expect((try matches(host.context, "--missing", "INITIAL")).?.value);
            try testing.expect((try matches(host.context, "--bad", "initial")).?.value);
            try testing.expect(!(try matches(host.context, "--a", "initial")).?.value);
            // The empty value is a value, not the guaranteed-invalid one.
            try testing.expect(!(try matches(host.context, "--empty", "initial")).?.value);
            // inherit and unset: the parent's computed value.
            try testing.expect((try matches(host.context, "--same", "inherit")).?.value);
            try testing.expect(!(try matches(host.context, "--differs", "inherit")).?.value);
            try testing.expect((try matches(host.context, "--same", "unset")).?.value);
            try testing.expect(!(try matches(host.context, "--differs", "unset")).?.value);
            try testing.expect(!(try matches(host.context, "--a", "inherit")).?.value);
            // Missing on both: the parent's guaranteed-invalid equals ours.
            try testing.expect((try matches(host.context, "--missing", "inherit")).?.value);
            try testing.expect((try matches(host.context, "--missing", "unset")).?.value);
            // revert and revert-layer: false, whatever the value.
            try testing.expect(!(try matches(host.context, "--missing", "revert")).?.value);
            try testing.expect(!(try matches(host.context, "--a", "revert-layer")).?.value);
            // Still compared as tokens when the keyword is not the whole value.
            try testing.expect(!(try matches(host.context, "--missing", "initial x")).?.value);
        }
    }.body);
}

/// A snapshot of one registration, for the style() query tests: --len,
/// <length>, initial 10px, inherits as given.
fn lengthSnapshot(allocator: Allocator, inherits: bool) !*registered_mod.Snapshot {
    var definition = try @import("syntax_definitions.zig").parse(allocator, "<length>");
    defer definition.deinit();
    var initial = (try definition.parseValue(.{ .allocator = allocator }, "10px")).?;
    defer initial.deinit();
    return registered_mod.Snapshot.create(allocator, .{}, &.{.{ .name = "--len", .syntax_text = "<length>", .inherits = inherits, .initial_value = &initial }});
}

fn registeredQueries(allocator: Allocator) !void {
    const snapshot = try lengthSnapshot(allocator, false);
    defer snapshot.release();
    try withRegisteredHost(allocator, snapshot, "--len: calc(4px + 1em); font-size: 10px", "--len: 3px", struct {
        fn body(host: substitution.Host) anyerror!void {
            const matches = host.query_value_matches.?;
            // The query value is computed under the registration, in the
            // element's context (row 123 Q5: "plain feature computes the
            // query value under the property's registration").
            try testing.expect((try matches(host.context, "--len", "14px")).?.value);
            try testing.expect((try matches(host.context, "--len", "calc(7px * 2)")).?.value);
            try testing.expect((try matches(host.context, "--len", "1.4em")).?.value);
            try testing.expect(!(try matches(host.context, "--len", "13px")).?.value);
            // A value its syntax does not match is no match.
            try testing.expect(!(try matches(host.context, "--len", "red")).?.value);
            // initial is the registration's; inherits: false makes unset
            // initial; inherit is the parent's.
            try testing.expect(!(try matches(host.context, "--len", "initial")).?.value);
            try testing.expect((try matches(host.context, "--missing", "initial")).?.value);
            // A registered property at its initial value has a value (RULINGS 1025h).
            try testing.expect((try host.has_value.?(host.context, "--len")).value);
        }
    }.body);
    try withRegisteredHost(allocator, snapshot, "color: red", "--len: 3px", struct {
        fn body(host: substitution.Host) anyerror!void {
            const matches = host.query_value_matches.?;
            try testing.expect((try matches(host.context, "--len", "initial")).?.value);
            try testing.expect((try matches(host.context, "--len", "unset")).?.value);
            try testing.expect((try matches(host.context, "--len", "10px")).?.value);
            try testing.expect(!(try matches(host.context, "--len", "inherit")).?.value);
            try testing.expect((try host.has_value.?(host.context, "--len")).value);
        }
    }.body);
}

test "style() queries on a registered property compute the query value under its registration" {
    try registeredQueries(testing.allocator);
}

test "registered style() queries survive every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, registeredQueries, .{});
}

test "style() queries: a keyword query value at the root reads no parent" {
    try withHost(testing.allocator, "--a: red", null, struct {
        fn body(host: substitution.Host) anyerror!void {
            const matches = host.query_value_matches.?;
            try testing.expect((try matches(host.context, "--missing", "inherit")).?.value);
            try testing.expect(!(try matches(host.context, "--a", "inherit")).?.value);
            try testing.expect(!(try matches(host.context, "--a", "unset")).?.value);
        }
    }.body);
}

test "style() keyword queries survive every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: Allocator) !void {
            try withHost(allocator, "--a: red; --same: x", "--same: x", struct {
                fn body(host: substitution.Host) anyerror!void {
                    const matches = host.query_value_matches.?;
                    try testing.expect((try matches(host.context, "--missing", "initial")).?.value);
                    try testing.expect((try matches(host.context, "--same", "inherit")).?.value);
                }
            }.body);
        }
    }.run, .{});
}

test "style() range queries: numericValue in canonical units, from a name or a literal" {
    try withHost(testing.allocator, "--len: 2in; --em: 2em; --angle: 0.5turn; --t: 250ms; --res: 2dppx; --pct: 40%; --num: 3; --calc: calc(1px + 1px); --word: big; --bad: var(--missing)", null, struct {
        fn body(host: substitution.Host) anyerror!void {
            const value = host.numeric_value.?;
            try testing.expectEqual(substitution.Numeric{ .value = 192, .dimension = .length }, (try value(host.context, "--len")).?.value);
            // Font-relative units resolve in the element's context (16px).
            try testing.expectEqual(substitution.Numeric{ .value = 32, .dimension = .length }, (try value(host.context, "--em")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 180, .dimension = .angle }, (try value(host.context, "--angle")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 0.25, .dimension = .time }, (try value(host.context, "--t")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 2, .dimension = .resolution }, (try value(host.context, "--res")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 40, .dimension = .percentage }, (try value(host.context, "--pct")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 3, .dimension = .number }, (try value(host.context, "--num")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 2, .dimension = .length }, (try value(host.context, "--calc")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 1000, .dimension = .frequency }, (try value(host.context, "1khz")).?.value);
            try testing.expectEqual(substitution.Numeric{ .value = 10, .dimension = .length }, (try value(host.context, "calc(var(--num) * 1px + 7px)")).?.value);
            try testing.expect((try value(host.context, "--word")) == null);
            try testing.expect((try value(host.context, "--bad")) == null);
            try testing.expect((try value(host.context, "1px 2px")) == null);
            try testing.expectError(error.Invalid, value(host.context, "var(--missing)"));
        }
    }.body);
}

test "if() media() and supports() tests: true, false, or unknown (error.Invalid)" {
    try withHost(testing.allocator, "--a: 1", null, struct {
        fn body(host: substitution.Host) anyerror!void {
            const media = host.media.?;
            // The defaults: a 1024x768 screen.
            try testing.expect(try media(host.context, "width > 10px"));
            try testing.expect(try media(host.context, "(width > 10px) and (height > 10px)"));
            try testing.expect(!try media(host.context, "width < 10px"));
            try testing.expect(try media(host.context, "not (width < 10px)"));
            // Malformed, or unknown (general-enclosed): unknown to the caller.
            try testing.expectError(error.Invalid, media(host.context, "width >"));
            try testing.expectError(error.Invalid, media(host.context, "(frobnicate)"));
            try testing.expectError(error.Invalid, media(host.context, "screen"));
            const supports = host.supports.?;
            try testing.expect(try supports(host.context, "color: red", false));
            try testing.expect(try supports(host.context, "(color: red) and (width: 1px)", false));
            try testing.expect(!try supports(host.context, "color: 10px", false));
            try testing.expect(try supports(host.context, "not (color: 10px)", false));
            // The consuming declaration's quirks mode: unitless lengths.
            try testing.expect(try supports(host.context, "width: 10", true));
            try testing.expect(!try supports(host.context, "width: 10", false));
            try testing.expectError(error.Invalid, supports(host.context, "color red", false));
            try testing.expectError(error.Invalid, supports(host.context, "(color: red) and", false));
        }
    }.body);
}

test "Host.attribute reads the element's attribute through content_attributes, no namespace" {
    const Attributes = struct {
        fn get(_: *const anyopaque, name: []const u8) ?[]const u8 {
            if (std.mem.eql(u8, name, "data-size")) return "10px";
            return null;
        }
    };
    var marker: u8 = 0;
    const allocator = testing.allocator;
    var block = try DeclarationBlock.parse(.{ .allocator = allocator }, "color: red");
    defer block.deinit();
    const matched = [_]Matched{.{ .block = &block, .source = .{ .origin = .author } }};
    var candidates = try collectCandidates(allocator, &matched, null);
    defer candidates.deinit(allocator);
    const links = try allocator.alloc(usize, candidates.items.len);
    defer allocator.free(links);
    var builder: Builder = .{
        .ctx = .{ .allocator = allocator, .parent = null, .content_attributes = .{ .context = &marker, .get = Attributes.get } },
        .candidates = candidates.items,
        .index = CandidateIndex.init(candidates.items, links),
    };
    defer builder.deinit();
    const host = builder.substitutionHost(.{});
    // A synthetic attr()-like evaluation: the attribute, the canonical
    // local name, no namespace; a prefix or a missing attribute is null.
    const found = host.attribute.?(host.context, 7, null, null, "data-size").?;
    try testing.expectEqualStrings("10px", found.value);
    try testing.expect(found.namespace == null);
    try testing.expectEqualStrings("data-size", found.local_name);
    try testing.expect(host.attribute.?(host.context, 7, null, "svg", "data-size") == null);
    try testing.expect(host.attribute.?(host.context, 7, null, null, "missing") == null);
}

test "style() query functions leak nothing under allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: Allocator) !void {
            try withHost(allocator, "--a: red; --n: calc(1px + 2px)", null, struct {
                fn body(host: substitution.Host) anyerror!void {
                    _ = try host.query_value_matches.?(host.context, "--a", "red");
                    _ = try host.numeric_value.?(host.context, "--n");
                }
            }.body);
        }
    }.run, .{});
}
