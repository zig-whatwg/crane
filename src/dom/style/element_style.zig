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
    key: Key,
    /// The style read per-element dynamic state (or inherited from one
    /// that did): resolved again on every read (design 5.3).
    @"volatile": bool,
};

pub const PseudoCached = struct {
    /// The pseudo-element's name, lowercase (`before`).
    name: []u8,
    cached: Cached,
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

pub const ElementStyle = struct {
    allocator: Allocator,
    /// The style attribute's declarations, once parsed.
    inline_block: ?DeclarationBlock = null,
    inline_state: InlineState = .unparsed,
    /// CSSOM "declaration block's updating flag": the block is being
    /// written into the attribute, whose change steps must not parse it.
    updating: bool = false,
    cached: ?Cached = null,
    pseudo: std.ArrayList(PseudoCached) = .empty,
    background_hint: ?*BackgroundHint = null,

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
        self.dropBackgroundHint();
        self.dropCache();
        self.pseudo.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn dropBackgroundHint(self: *ElementStyle) void {
        if (self.background_hint) |hint| hint.destroy();
        self.background_hint = null;
    }

    /// Forget every cached style.
    pub fn dropCache(self: *ElementStyle) void {
        if (self.cached) |c| c.style.destroy();
        self.cached = null;
        for (self.pseudo.items) |p| {
            p.cached.style.destroy();
            self.allocator.free(p.name);
        }
        self.pseudo.clearRetainingCapacity();
    }

    /// Replace the cached style (taken).
    pub fn setCached(self: *ElementStyle, cached: Cached) void {
        if (self.cached) |old| old.style.destroy();
        self.cached = cached;
    }

    pub fn pseudoCached(self: *ElementStyle, name: []const u8) ?*PseudoCached {
        for (self.pseudo.items) |*p| if (std.mem.eql(u8, p.name, name)) return p;
        return null;
    }

    /// Replace the cached style of pseudo-element `name` (taken).
    pub fn setPseudoCached(self: *ElementStyle, name: []const u8, cached: Cached) Allocator.Error!void {
        if (self.pseudoCached(name)) |existing| {
            existing.cached.style.destroy();
            existing.cached = cached;
            return;
        }
        errdefer cached.style.destroy();
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
    const key: Key = .{ .tree_version = 1, .generation = 1, .singletons = .{0} ** 5 };
    state.setCached(.{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    state.setCached(.{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    try state.setPseudoCached("before", .{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    try state.setPseudoCached("before", .{ .style = try ComputedStyle.initial(std.testing.allocator), .key = key, .@"volatile" = false });
    try std.testing.expectEqual(@as(usize, 1), state.pseudo.items.len);
    try std.testing.expect(key.eql(state.pseudoCached("before").?.cached.key));
}
