//! An element's style state: its style attribute's declaration block
//! (CSSOM 6.7, HTML 3.2.6.5 "the style attribute") and its computed style,
//! cached under the key the engine validates it by (design section 5.1).
//!
//! The type lives here and the Element owns the state - one pointer in its
//! internal state, the block allocated on first use and freed in its
//! deinit - so it dies with the element and no side table keyed by its
//! address can outlive it (lesson architecture-an-address-keyed-entry-a-
//! teardown-misses-is-inherited). WebKit keeps the same two things on the
//! element too: the inline style in its ElementData and the computed style
//! of an element with no renderer in its ElementRareData.
//!
//! Nothing here holds a node: a computed style holds values only.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const css = @import("css");
const hooks = @import("hooks.zig");
const css_transitions = @import("../animations/css_transitions.zig");
const css_animations = @import("../animations/css_animations.zig");

const ComputedStyle = css.computed_style.ComputedStyle;
const DeclarationBlock = css.declarations.DeclarationBlock;

/// The inputs a cached computed style was resolved under (design 5.1).
pub const Key = struct {
    /// The node document's DOM tree version.
    tree_version: u64,
    /// The engine's active-sheet generation (sheets, their contents, the
    /// media environment).
    generation: u64,
    /// The engine's slot-assignment version.
    slot_version: u64 = 0,
    /// The document's focused, hovered, pointed, activated and target
    /// elements, by address and generation.
    singletons: [5]u64,

    pub fn eql(a: Key, b: Key) bool {
        return a.tree_version == b.tree_version and a.generation == b.generation and a.slot_version == b.slot_version and std.mem.eql(u64, &a.singletons, &b.singletons);
    }
};

/// Which document singletons (focus, hover, active, target) a cached style
/// depended on during matching (Blink's Element AffectedByFocus /
/// AffectedByHover / AffectedByActive / AffectedByTarget), plus whether this
/// element itself was focused when resolved.
///
/// Fits in 1 byte beside `volatile` and `rendered` in existing alignment
/// padding (ElementStyle stays pinned at 272 bytes).
pub const SingletonDeps = packed struct(u8) {
    /// Matching evaluated :focus-within, or evaluated :focus/:focus-visible
    /// outside the subject's own focus bucket (combinator, :has(), :not(),
    /// :is(), pseudo-element, :host, ::slotted).
    any_focus: bool = false,
    /// This element matched :focus when its style was resolved; a flip in
    /// its own focus state invalidates it (so Buckets.focus rules apply
    /// while focused and drop when blurred).
    was_focused: bool = false,
    /// Matching evaluated :hover.
    any_hover: bool = false,
    /// Matching evaluated :active.
    any_active: bool = false,
    /// Matching evaluated :target.
    any_target: bool = false,
    _pad: u3 = 0,
};

pub const Cached = struct {
    style: *ComputedStyle,
    /// The style without the animation and transition origins (the base
    /// style), OWNED, when it differs from `style`: kept only for an element
    /// an effect applied to, so that the next style change event has the
    /// before-change style CSS Transitions 1 section 3 compares (Blink keeps
    /// the base computed style on ElementAnimations for the same reason).
    /// Null: `style` is the base style.
    base: ?*ComputedStyle = null,
    key: Key,
    /// The style read per-element dynamic state not covered by a state
    /// invalidation hook (or inherited from one that did): resolved again on
    /// every read (design 5.3).
    @"volatile": bool,
    /// Document singleton dependencies recorded while matching this style.
    deps: SingletonDeps = .{},
    /// The element was being rendered when this style was resolved: no
    /// `display: none` on it or a flat-tree ancestor, and it has not been
    /// removed from the document since (its removing steps clear it). A
    /// style resolved while not rendered is no before-change style (CSS
    /// Transitions 1 section 3, CSS Transitions 2 section 3).
    rendered: bool = true,
    /// H-R3-ENGINE-KEY. The element's own animation component when resolved
    /// (dom.animations.effect_stack.component): 0 with no effect, so a
    /// running animation moves only its targets' keys.
    animations: u64 = 0,
    /// This style's serial (StyleEngine), and its flat-tree parent's when it
    /// was resolved: a parent resolved again since - an animated one or one
    /// whose own focus changed - makes its children resolve again too, so
    /// inheritance follows the new value. `base_serial` advances only on a
    /// real style change event (not an animation-only tick), so children know
    /// whether a parent's resolution is a CSS Transitions style change event.
    /// Four u32s occupy the exact same 16 bytes as two u64s.
    serial: u32 = 0,
    base_serial: u32 = 0,
    parent_serial: u32 = 0,
    parent_base_serial: u32 = 0,

    /// Whether this cached style's inputs still hold under `key` and
    /// `is_focused_now` (Blink's AffectedBy* selective invalidation):
    /// tree/generation/slot mismatches always invalidate; singleton moves
    /// invalidate only when this style depended on that singleton (or this
    /// element's own focus state flipped).
    pub fn validFor(self: *const Cached, key: Key, is_focused_now: bool) bool {
        if (self.key.tree_version != key.tree_version or
            self.key.generation != key.generation or
            self.key.slot_version != key.slot_version) return false;
        if (self.deps.was_focused != is_focused_now) return false;
        if (self.deps.any_focus and self.key.singletons[0] != key.singletons[0]) return false;
        if (self.deps.any_hover and self.key.singletons[1] != key.singletons[1]) return false;
        if (self.deps.any_active and (self.key.singletons[2] != key.singletons[2] or self.key.singletons[3] != key.singletons[3])) return false;
        if (self.deps.any_target and self.key.singletons[4] != key.singletons[4]) return false;
        return true;
    }

    /// The before-change style this cached style gives the next style
    /// change event: its base style, or null when it has none.
    pub fn beforeChange(self: *const Cached) ?*const ComputedStyle {
        if (!self.rendered) return null;
        return self.base orelse self.style;
    }

    /// The cache's hold on its styles ends: each is freed now, or by the
    /// last caller still reading it (dom.style.HeldStyle; lane cs1).
    fn release(self: Cached) void {
        self.style.release();
        if (self.base) |base| base.release();
    }
};

pub const PseudoCached = struct {
    /// The pseudo-element's name, lowercase (`before`).
    name: []u8,
    cached: Cached,
};

/// Values 5 §10 cache: scalar identities only, with no node or realm hold.
/// The document generation rejects address reuse; tree_version rejects moves
/// and adoption. Allocated only when a winning value asks for sibling counts.
pub const SiblingCounts = struct {
    value: css.math_values.TreeCounts,
    document_address: usize,
    document_generation: u64,
    tree_version: u64,

    pub fn matches(self: SiblingCounts, address: usize, generation: u64, version: u64) bool {
        return self.document_address == address and self.document_generation == generation and self.tree_version == version;
    }
};

/// The one per-type presentational hint an element's style keeps, by kind:
/// HTML §15's background hint (eight HTML table and body tags), HTML
/// 15.3.4's font hint (the HTML font element), and SVG 2 §6.6's
/// presentation attributes (SVG elements). The three sets of element types
/// are disjoint, so one slot serves all three - a pointer on every styled
/// element instead of three (lane quick1 b4). Each hint type starts with
/// this header (`header`), and the slot points at it.
pub const Hint = struct {
    kind: Kind,

    pub const Kind = enum(u8) { background, font, svg };
};

/// HTML §15's dynamic background hint. Allocated only for the eight
/// eligible HTML tags with a nonempty background attribute. The strings
/// and typed value have no DOM/realm back link.
pub const BackgroundHint = struct {
    header: Hint = .{ .kind = .background },
    allocator: Allocator,
    input: []u8,
    source: *css.style_values.ResourceSource,
    block: DeclarationBlock,

    pub fn destroy(self: *BackgroundHint) void {
        self.block.deinit();
        self.source.unref();
        self.allocator.free(self.input);
        self.allocator.destroy(self);
    }
};

/// Typed OM identity allocated only when computedStyleMap() is called.
/// Wrapper edges hold the map; this generation-checked link is weak.
pub const ComputedMapLink = struct {
    object: @import("rules.zig").ObjectLink = .{},
};

/// An element's CSS transitions (running and completed) and CSS animations,
/// for it and its pseudo-elements. OWNED by its ElementStyle; no engine
/// handle, so the element's teardown frees it with no engine call.
pub const StyleAnimations = struct {
    transitions: css_transitions.ElementTransitions = .{},
    css_animations: css_animations.ElementAnimations = .{},

    pub fn destroy(self: *StyleAnimations, allocator: Allocator) void {
        self.transitions.deinit(allocator);
        self.css_animations.deinit(allocator);
        allocator.destroy(self);
    }
};

pub const ElementStyle = struct {
    allocator: Allocator,
    /// The style attribute's declarations, once parsed.
    inline_block: ?DeclarationBlock = null,
    inline_state: InlineState = .unparsed,
    /// CSSOM "declaration block's updating flag": the block is being
    /// written into the attribute, whose change steps must not parse it.
    updating: bool = false,
    /// True when this ElementStyle block itself was allocated in its
    /// Browser's cage `.satellite` partition (`createForElement`); fits in
    /// existing alignment padding next to `updating` (`@sizeOf(ElementStyle)`
    /// stays pinned at 272 bytes).
    in_satellite: bool = false,
    sibling_counts: ?*SiblingCounts = null,
    cached: ?Cached = null,
    /// Typed OM §5.3 method identity. Wrapper edges keep this map live; this
    /// generation-checked identity is weak and is never read during teardown.
    computed_map: ?*ComputedMapLink = null,
    pseudo: std.ArrayList(PseudoCached) = .empty,
    /// The element's presentational hint (`Hint`): a background hint
    /// (resource_loading.backgroundHint), an HTML font element's
    /// color/face/size hint (font_hints.zig) or an SVG element's
    /// presentation attributes (svg_hints.zig).
    hint: ?*Hint = null,
    /// CSS Transitions 1 section 3 and CSS Animations 1 section 2: the
    /// element's transitions and CSS animations (dom.animations), made at the
    /// first of either. One pointer for both, so ElementStyle does not grow.
    /// Holds no engine handle: borrowed links and values.
    animations: ?*StyleAnimations = null,

    pub const InlineState = enum {
        /// Parse the attribute's value on the next read.
        unparsed,
        parsed,
        /// Content Security Policy blocked the value: "the style rules
        /// defined in the attribute's value must not be applied".
        blocked,
    };

    pub fn create(allocator: Allocator) Allocator.Error!*ElementStyle {
        const self = try allocator.create(ElementStyle);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// Allocate an ElementStyle for a live Element in its Browser's cage
    /// `.satellite` partition (allocator-hardening batch B2, item 3). Sub-
    /// allocations (`pseudo` names, hints, animations) keep `element.ctx.allocator`.
    pub fn createForElement(element: *runtime.Instance) Allocator.Error!*ElementStyle {
        const scope = runtime.BrowserScope.ofInstance(element);
        if (scope.existingHeapEngine()) |eng| {
            const mem = try eng.allocSatellite(@sizeOf(ElementStyle), @alignOf(ElementStyle), @returnAddress());
            const self: *ElementStyle = @ptrCast(@alignCast(mem));
            self.* = .{ .allocator = element.ctx.allocator, .in_satellite = true };
            return self;
        }
        return create(element.ctx.allocator);
    }

    pub fn destroy(self: *ElementStyle) void {
        if (self.inline_block) |*block| block.deinit();
        if (self.sibling_counts) |counts| self.allocator.destroy(counts);
        if (self.computed_map) |link| self.allocator.destroy(link);
        self.dropHint();
        self.dropCache();
        self.pseudo.deinit(self.allocator);
        if (self.animations) |animations| animations.destroy(self.allocator);
        if (self.in_satellite) {
            runtime.heap.Engine.freeSatelliteOf(self, @sizeOf(ElementStyle), @alignOf(ElementStyle));
        } else {
            self.allocator.destroy(self);
        }
    }

    /// The element's transitions and CSS animations, made on first use.
    pub fn ensureAnimations(self: *ElementStyle) Allocator.Error!*StyleAnimations {
        if (self.animations) |animations| return animations;
        const made = try self.allocator.create(StyleAnimations);
        made.* = .{};
        self.animations = made;
        return made;
    }

    /// Cache a measured pair if possible; callers retain their stack answer
    /// on allocation failure, so caching never changes a computed value.
    pub fn cacheSiblingCounts(self: *ElementStyle, counts: SiblingCounts) bool {
        const record = self.sibling_counts orelse self.allocator.create(SiblingCounts) catch return false;
        record.* = counts;
        self.sibling_counts = record;
        return true;
    }

    /// The background hint, if the slot holds one.
    pub fn backgroundHint(self: *const ElementStyle) ?*BackgroundHint {
        const hint = self.hint orelse return null;
        if (hint.kind != .background) return null;
        return @alignCast(@fieldParentPtr("header", hint));
    }

    /// The font hint, if the slot holds one.
    pub fn fontHint(self: *const ElementStyle) ?*@import("font_hints.zig").FontHint {
        const hint = self.hint orelse return null;
        if (hint.kind != .font) return null;
        return @alignCast(@fieldParentPtr("header", hint));
    }

    /// The SVG presentation-attribute hint, if the slot holds one.
    pub fn svgHint(self: *const ElementStyle) ?*@import("svg_hints.zig").SvgHint {
        const hint = self.hint orelse return null;
        if (hint.kind != .svg) return null;
        return @alignCast(@fieldParentPtr("header", hint));
    }

    /// Keep `hint` in the slot, dropping the one of its kind it replaces.
    /// One element carries hints of one kind only (`Hint`): a slot holding
    /// another kind is a broken assumption, which fails here, loudly, in
    /// every safe build, rather than freeing the other hint unseen.
    pub fn setHint(self: *ElementStyle, hint: *Hint) void {
        if (self.hint) |old| {
            if (old.kind != hint.kind) @panic("ElementStyle.setHint: an element with presentational hints of two kinds");
            destroyHint(old);
        }
        self.hint = hint;
    }

    pub fn dropBackgroundHint(self: *ElementStyle) void {
        const hint = self.hint orelse return;
        if (hint.kind != .background) return;
        destroyHint(hint);
        self.hint = null;
    }

    pub fn dropFontHint(self: *ElementStyle) void {
        const hint = self.hint orelse return;
        if (hint.kind != .font) return;
        destroyHint(hint);
        self.hint = null;
    }

    pub fn dropSvgHint(self: *ElementStyle) void {
        const hint = self.hint orelse return;
        if (hint.kind != .svg) return;
        destroyHint(hint);
        self.hint = null;
    }

    /// Drop the slot's hint, whatever its kind.
    pub fn dropHint(self: *ElementStyle) void {
        const hint = self.hint orelse return;
        destroyHint(hint);
        self.hint = null;
    }

    fn destroyHint(hint: *Hint) void {
        switch (hint.kind) {
            .background => @as(*BackgroundHint, @alignCast(@fieldParentPtr("header", hint))).destroy(),
            .font => @as(*@import("font_hints.zig").FontHint, @alignCast(@fieldParentPtr("header", hint))).destroy(),
            .svg => @as(*@import("svg_hints.zig").SvgHint, @alignCast(@fieldParentPtr("header", hint))).destroy(),
        }
    }

    /// Forget every cached style.
    pub fn dropCache(self: *ElementStyle) void {
        if (self.cached) |c| c.release();
        self.cached = null;
        for (self.pseudo.items) |p| {
            p.cached.release();
            self.allocator.free(p.name);
        }
        self.pseudo.clearRetainingCapacity();
    }

    /// Replace the cached style (taken).
    pub fn setCached(self: *ElementStyle, cached: Cached) void {
        if (self.cached) |old| old.release();
        self.cached = cached;
    }

    /// The element left the document (its removing steps): no cached style
    /// of it is a before-change style any more.
    pub fn markRemoved(self: *ElementStyle) void {
        if (self.cached) |*c| c.rendered = false;
        for (self.pseudo.items) |*p| p.cached.rendered = false;
    }

    pub fn pseudoCached(self: *ElementStyle, name: []const u8) ?*PseudoCached {
        for (self.pseudo.items) |*p| if (std.mem.eql(u8, p.name, name)) return p;
        return null;
    }

    /// Replace the cached style of pseudo-element `name` (taken).
    pub fn setPseudoCached(self: *ElementStyle, name: []const u8, cached: Cached) Allocator.Error!void {
        if (self.pseudoCached(name)) |existing| {
            existing.cached.release();
            existing.cached = cached;
            return;
        }
        errdefer cached.release();
        const copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(copy);
        try self.pseudo.append(self.allocator, .{ .name = copy, .cached = cached });
    }
};

/// `element`'s style state, made on first use; null for an instance that
/// is not an Element (or before Element installed its hook).
pub fn of(element: *runtime.Instance) ?*ElementStyle {
    const slot = hooks.elementStyleSlot(element) orelse return null;
    if (slot.*) |found| return found;
    const made = ElementStyle.createForElement(element) catch return null;
    slot.* = made;
    hooks.controlStyleStateCreated(element);
    return made;
}

comptime {
    if (@sizeOf(usize) == 8 and @sizeOf(ElementStyle) != 272)
        @compileError(std.fmt.comptimePrint("ElementStyle size changed from 272 bytes: {d}", .{@sizeOf(ElementStyle)}));
}

/// `element`'s style state if it has one already.
pub fn existingOf(element: *runtime.Instance) ?*ElementStyle {
    const slot = hooks.elementStyleSlot(element) orelse return null;
    return slot.*;
}

test "an element's style state keeps one cached style per pseudo-element" {
    const state = try ElementStyle.create(std.testing.allocator);
    defer state.destroy();
    const key: Key = .{ .tree_version = 1, .generation = 1, .singletons = @splat(0) };
    state.setCached(.{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    state.setCached(.{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    try state.setPseudoCached("before", .{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    try state.setPseudoCached("before", .{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    try std.testing.expectEqual(@as(usize, 1), state.pseudo.items.len);
    try std.testing.expect(key.eql(state.pseudoCached("before").?.cached.key));
}

test "a cached style owns its base style, and a removed element's cache is no before-change style" {
    const state = try ElementStyle.create(std.testing.allocator);
    defer state.destroy();
    const key: Key = .{ .tree_version = 1, .generation = 1, .singletons = @splat(0) };
    const style = try ComputedStyle.initial(std.testing.allocator);
    const base = try ComputedStyle.initial(std.testing.allocator);
    state.setCached(.{ .style = style, .base = base, .key = key, .@"volatile" = false });
    try std.testing.expect(state.cached.?.beforeChange() == base);
    // Replacing it frees both (std.testing.allocator fails the test on a leak).
    const plain = try ComputedStyle.initial(std.testing.allocator);
    state.setCached(.{ .style = plain, .key = key, .@"volatile" = false });
    try std.testing.expect(state.cached.?.beforeChange() == plain);
    try state.setPseudoCached("before", .{ .style = try ComputedStyle.initial(std.testing.allocator), .base = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    state.markRemoved();
    try std.testing.expect(state.cached.?.beforeChange() == null);
    try std.testing.expect(state.pseudoCached("before").?.cached.beforeChange() == null);
}

test "the background hint's element types are not the font element (the hint slot holds one kind)" {
    const resource_loading = @import("resource_loading.zig");
    for ([_][]const u8{ "body", "table", "thead", "tbody", "tfoot", "tr", "td", "th" }) |name| {
        try std.testing.expect(resource_loading.hasBackgroundHint(name));
    }
    try std.testing.expect(!resource_loading.hasBackgroundHint("font"));
}

test "Cached.validFor selectively invalidates only on recorded singleton dependencies or own focus flips" {
    const base_key: Key = .{ .tree_version = 1, .generation = 2, .slot_version = 3, .singletons = .{ 10, 20, 30, 40, 50 } };
    const style = try ComputedStyle.initial(std.testing.allocator);
    defer style.release();
    const cached: Cached = .{ .style = style, .key = base_key, .@"volatile" = false, .deps = .{} };
    // Unrelated singleton changes keep an independent cached style valid.
    const moved_all: Key = .{ .tree_version = 1, .generation = 2, .slot_version = 3, .singletons = .{ 11, 21, 31, 41, 51 } };
    try std.testing.expect(cached.validFor(moved_all, false));
    // Own focus flipping always invalidates.
    try std.testing.expect(!cached.validFor(base_key, true));
    // Tree, generation, or slot version always invalidates.
    try std.testing.expect(!cached.validFor(.{ .tree_version = 2, .generation = 2, .slot_version = 3, .singletons = base_key.singletons }, false));
    try std.testing.expect(!cached.validFor(.{ .tree_version = 1, .generation = 3, .slot_version = 3, .singletons = base_key.singletons }, false));
    try std.testing.expect(!cached.validFor(.{ .tree_version = 1, .generation = 2, .slot_version = 4, .singletons = base_key.singletons }, false));
    // Recording any_focus invalidates when singletons[0] changes, but not singletons[1..].
    const focus_dep: Cached = .{ .style = style, .key = base_key, .@"volatile" = false, .deps = .{ .any_focus = true } };
    try std.testing.expect(focus_dep.validFor(.{ .tree_version = 1, .generation = 2, .slot_version = 3, .singletons = .{ 10, 99, 99, 99, 99 } }, false));
    try std.testing.expect(!focus_dep.validFor(.{ .tree_version = 1, .generation = 2, .slot_version = 3, .singletons = .{ 11, 20, 30, 40, 50 } }, false));
}
