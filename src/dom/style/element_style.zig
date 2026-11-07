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
    /// The style read per-element dynamic state (or inherited from one
    /// that did): resolved again on every read (design 5.3).
    @"volatile": bool,
    /// H-R3-ENGINE-KEY. The element's own animation component when resolved
    /// (dom.animations.effect_stack.component): 0 with no effect, so a
    /// running animation moves only its targets' keys.
    animations: u64 = 0,
    /// This style's serial (StyleEngine.nextSerial), and its flat-tree
    /// parent's when it was resolved: a parent resolved again since - an
    /// animated one, whose key moved alone - makes its children resolve
    /// again too, so inheritance follows the animated value.
    serial: u64 = 0,
    parent_serial: u64 = 0,
    /// The element was being rendered when this style was resolved: no
    /// `display: none` on it or a flat-tree ancestor, and it has not been
    /// removed from the document since (its removing steps clear it). A
    /// style resolved while not rendered is no before-change style (CSS
    /// Transitions 1 section 3, CSS Transitions 2 section 3).
    rendered: bool = true,

    /// The before-change style this cached style gives the next style
    /// change event: its base style, or null when it has none.
    pub fn beforeChange(self: *const Cached) ?*const ComputedStyle {
        if (!self.rendered) return null;
        return self.base orelse self.style;
    }

    fn destroy(self: Cached) void {
        self.style.destroy();
        if (self.base) |base| base.destroy();
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

/// HTML §15's dynamic background hint. Allocated only for the eight
/// eligible HTML tags with a nonempty background attribute. The strings
/// and typed value have no DOM/realm back link.
pub const BackgroundHint = struct {
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
    sibling_counts: ?*SiblingCounts = null,
    cached: ?Cached = null,
    /// Typed OM §5.3 method identity. Wrapper edges keep this map live; this
    /// generation-checked identity is weak and is never read during teardown.
    computed_map: ?*ComputedMapLink = null,
    pseudo: std.ArrayList(PseudoCached) = .empty,
    background_hint: ?*BackgroundHint = null,
    /// HTML 15.3.4: an HTML font element's color/face/size hint (font_hints.zig).
    font_hint: ?*@import("font_hints.zig").FontHint = null,
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

    pub fn destroy(self: *ElementStyle) void {
        if (self.inline_block) |*block| block.deinit();
        if (self.sibling_counts) |counts| self.allocator.destroy(counts);
        if (self.computed_map) |link| self.allocator.destroy(link);
        self.dropBackgroundHint();
        self.dropFontHint();
        self.dropCache();
        self.pseudo.deinit(self.allocator);
        if (self.animations) |animations| animations.destroy(self.allocator);
        self.allocator.destroy(self);
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

    pub fn dropBackgroundHint(self: *ElementStyle) void {
        if (self.background_hint) |hint| hint.destroy();
        self.background_hint = null;
    }

    pub fn dropFontHint(self: *ElementStyle) void {
        if (self.font_hint) |hint| hint.destroy();
        self.font_hint = null;
    }

    /// Forget every cached style.
    pub fn dropCache(self: *ElementStyle) void {
        if (self.cached) |c| c.destroy();
        self.cached = null;
        for (self.pseudo.items) |p| {
            p.cached.destroy();
            self.allocator.free(p.name);
        }
        self.pseudo.clearRetainingCapacity();
    }

    /// Replace the cached style (taken).
    pub fn setCached(self: *ElementStyle, cached: Cached) void {
        if (self.cached) |old| old.destroy();
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
            existing.cached.destroy();
            existing.cached = cached;
            return;
        }
        errdefer cached.destroy();
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
    const made = ElementStyle.create(element.ctx.allocator) catch return null;
    slot.* = made;
    hooks.controlStyleStateCreated(element);
    return made;
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
