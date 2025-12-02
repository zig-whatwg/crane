//! Browsing Context - HTML Standard §7.1
//!
//! A browsing context is an environment in which Document objects are presented to the user.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#browsing-context
//!
//! ## Key Concepts
//!
//! - Browsing contexts present Documents to users (typically in tabs, windows, or iframes)
//! - Each browsing context has a corresponding WindowProxy object
//! - Browsing contexts can be "top-level" (browser tab/window) or "child" (iframe)
//! - The "opener" relationship tracks which context opened which
//!
//! ## Architecture
//!
//! ```
//! BrowsingContext
//! ├── window_proxy: *WindowProxy       # Associated WindowProxy
//! ├── opener: ?*BrowsingContext        # Context that opened this one
//! ├── navigable: ?*Navigable           # Associated navigable
//! ├── is_popup: bool                   # Created via window.open()
//! ├── disowned: bool                   # Opener relationship severed
//! └── virtual_group_id: u64            # Browsing context group ID
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Unique ID generator for browsing contexts
var next_context_id: u64 = 1;
var next_group_id: u64 = 1;

/// A browsing context is an environment in which Document objects are presented.
/// Per HTML Standard §7.1.
pub const BrowsingContext = struct {
    /// Allocator used for this context
    allocator: Allocator,

    /// Unique identifier for this browsing context
    id: u64,

    /// The opener browsing context (§7.1)
    /// The browsing context that opened this one via window.open() or similar.
    /// Null for initially created contexts.
    opener: ?*BrowsingContext,

    /// Whether the opener relationship has been disowned (§7.1)
    /// Set to true when noopener is used or relationship is severed.
    disowned: bool,

    /// Whether this is a popup browsing context (§7.1)
    /// True if created via window.open() with is_popup flag.
    is_popup: bool,

    /// Virtual browsing context group ID (§7.1.3)
    /// Contexts with the same ID are in the same group.
    virtual_group_id: u64,

    /// Whether this context is closed
    is_closed: bool,

    /// Target name for this browsing context
    /// Used for named targeting (e.g., <a target="name">)
    target_name: []const u8,

    /// Parent browsing context (for child contexts)
    parent: ?*BrowsingContext,

    /// Child browsing contexts (iframes, frames)
    children: std.ArrayListUnmanaged(*BrowsingContext),

    /// Initial URL for this browsing context
    initial_url: ?[]const u8,

    /// Create a new browsing context
    pub fn init(allocator: Allocator) !*BrowsingContext {
        const ctx = try allocator.create(BrowsingContext);
        ctx.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_context_id, .Add, 1, .monotonic),
            .opener = null,
            .disowned = false,
            .is_popup = false,
            .virtual_group_id = 0,
            .is_closed = false,
            .target_name = "",
            .parent = null,
            .children = .{},
            .initial_url = null,
        };
        return ctx;
    }

    /// Create a new top-level browsing context
    pub fn initTopLevel(allocator: Allocator) !*BrowsingContext {
        const ctx = try init(allocator);
        ctx.virtual_group_id = @atomicRmw(u64, &next_group_id, .Add, 1, .monotonic);
        return ctx;
    }

    /// Create a new child browsing context with the given parent
    pub fn initChild(allocator: Allocator, parent_ctx: *BrowsingContext) !*BrowsingContext {
        const ctx = try init(allocator);
        ctx.parent = parent_ctx;
        ctx.virtual_group_id = parent_ctx.virtual_group_id;
        try parent_ctx.children.append(parent_ctx.allocator, ctx);
        return ctx;
    }

    /// Create a new auxiliary browsing context (via window.open())
    pub fn initAuxiliary(allocator: Allocator, opener_ctx: *BrowsingContext, is_popup_flag: bool) !*BrowsingContext {
        const ctx = try initTopLevel(allocator);
        ctx.opener = opener_ctx;
        ctx.is_popup = is_popup_flag;
        return ctx;
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *BrowsingContext) void {
        // Recursively deinit children
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit(self.allocator);

        // Free target name if allocated
        if (self.target_name.len > 0) {
            self.allocator.free(self.target_name);
        }

        // Free initial URL if allocated
        if (self.initial_url) |url| {
            self.allocator.free(url);
        }

        self.allocator.destroy(self);
    }

    /// Check if this browsing context is a top-level browsing context (§7.1)
    pub fn isTopLevel(self: *const BrowsingContext) bool {
        return self.parent == null;
    }

    /// Check if this browsing context is a child browsing context (§7.1)
    pub fn isChild(self: *const BrowsingContext) bool {
        return self.parent != null;
    }

    /// Check if this browsing context is script-closable (§7.1)
    /// A browsing context is script-closable if:
    /// - is_popup is true
    /// - opener is non-null and familiar with this context
    /// - session history has only one entry
    pub fn isScriptClosable(self: *const BrowsingContext) bool {
        // Per spec: browsingContext is script-closable if all of the following:
        // 1. is_popup is true
        // 2. is familiar with opener browsing context
        // 3. session history's size is 1
        return self.is_popup and
            self.opener != null and
            !self.disowned;
        // Note: session history size check would require navigable access
    }

    /// Get the top-level browsing context
    pub fn getTop(self: *BrowsingContext) *BrowsingContext {
        var current = self;
        while (current.parent) |p| {
            current = p;
        }
        return current;
    }

    /// Check if two browsing contexts are same origin
    /// This is a simplified check - full implementation needs origin comparison
    pub fn isSameOrigin(self: *const BrowsingContext, other: *const BrowsingContext) bool {
        // In a full implementation, this would compare document origins
        _ = self;
        _ = other;
        return true; // Placeholder - always same-origin for now
    }

    /// Check if two browsing contexts are in the same browsing context group
    pub fn isInSameGroup(self: *const BrowsingContext, other: *const BrowsingContext) bool {
        return self.virtual_group_id == other.virtual_group_id;
    }

    /// Check if this context is familiar with another (§7.1)
    pub fn isFamiliarWith(self: *const BrowsingContext, other: *const BrowsingContext) bool {
        // Per spec: familiar if:
        // - related browsing contexts, or
        // - both top-level with related groups, or
        // - in same unit of related similar-origin browsing contexts

        // Check if they share the same top-level traversable
        if (self.isInSameGroup(other)) {
            return true;
        }

        // Check opener chain
        var ctx: ?*const BrowsingContext = self;
        while (ctx) |c| {
            if (c == other) return true;
            ctx = c.opener;
        }

        ctx = other;
        while (ctx) |c| {
            if (c == self) return true;
            ctx = c.opener;
        }

        return false;
    }

    /// Close this browsing context
    pub fn close(self: *BrowsingContext) void {
        self.is_closed = true;

        // Disown the opener relationship
        self.disowned = true;

        // Close all children
        for (self.children.items) |child| {
            child.close();
        }
    }

    /// Disown the opener relationship (noopener)
    pub fn disown(self: *BrowsingContext) void {
        self.disowned = true;
        self.opener = null;
    }

    /// Set the target name
    pub fn setTargetName(self: *BrowsingContext, name: []const u8) !void {
        if (self.target_name.len > 0) {
            self.allocator.free(self.target_name);
        }
        self.target_name = try self.allocator.dupe(u8, name);
    }

    /// Get the number of child browsing contexts
    pub fn getChildCount(self: *const BrowsingContext) u32 {
        return @intCast(self.children.items.len);
    }

    /// Get a child browsing context by index
    pub fn getChildByIndex(self: *const BrowsingContext, index: u32) ?*BrowsingContext {
        if (index >= self.children.items.len) return null;
        return self.children.items[index];
    }

    /// Find a browsing context by target name
    pub fn findByTargetName(self: *BrowsingContext, name: []const u8) ?*BrowsingContext {
        // Check self
        if (std.mem.eql(u8, self.target_name, name)) {
            return self;
        }

        // Check children recursively
        for (self.children.items) |child| {
            if (child.findByTargetName(name)) |found| {
                return found;
            }
        }

        return null;
    }
};

/// Browsing context group - manages a group of related browsing contexts
pub const BrowsingContextGroup = struct {
    allocator: Allocator,
    id: u64,
    contexts: std.ArrayList(*BrowsingContext),

    /// Create a new browsing context group
    pub fn init(allocator: Allocator) !*BrowsingContextGroup {
        const group = try allocator.create(BrowsingContextGroup);
        group.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_group_id, .Add, 1, .monotonic),
            .contexts = std.ArrayList(*BrowsingContext).init(allocator),
        };
        return group;
    }

    /// Add a browsing context to this group
    pub fn addContext(self: *BrowsingContextGroup, ctx: *BrowsingContext) !void {
        ctx.virtual_group_id = self.id;
        try self.contexts.append(ctx);
    }

    /// Remove a browsing context from this group
    pub fn removeContext(self: *BrowsingContextGroup, ctx: *BrowsingContext) void {
        for (self.contexts.items, 0..) |c, i| {
            if (c == ctx) {
                _ = self.contexts.orderedRemove(i);
                break;
            }
        }
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *BrowsingContextGroup) void {
        self.contexts.deinit();
        self.allocator.destroy(self);
    }

    /// Get the number of contexts in this group
    pub fn size(self: *const BrowsingContextGroup) usize {
        return self.contexts.items.len;
    }
};

test "BrowsingContext - init and deinit" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.init(allocator);
    defer ctx.deinit();

    try std.testing.expect(ctx.opener == null);
    try std.testing.expect(!ctx.disowned);
    try std.testing.expect(!ctx.is_popup);
    try std.testing.expect(!ctx.is_closed);
}

test "BrowsingContext - top-level creation" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.initTopLevel(allocator);
    defer ctx.deinit();

    try std.testing.expect(ctx.isTopLevel());
    try std.testing.expect(!ctx.isChild());
    try std.testing.expect(ctx.virtual_group_id > 0);
}

test "BrowsingContext - child creation" {
    const allocator = std.testing.allocator;

    const parent = try BrowsingContext.initTopLevel(allocator);
    defer parent.deinit();

    const child = try BrowsingContext.initChild(allocator, parent);
    // child is freed by parent.deinit()

    try std.testing.expect(child.isChild());
    try std.testing.expect(!child.isTopLevel());
    try std.testing.expect(child.parent == parent);
    try std.testing.expectEqual(@as(u32, 1), parent.getChildCount());
}

test "BrowsingContext - auxiliary creation" {
    const allocator = std.testing.allocator;

    const opener = try BrowsingContext.initTopLevel(allocator);
    defer opener.deinit();

    const popup = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer popup.deinit();

    try std.testing.expect(popup.opener == opener);
    try std.testing.expect(popup.is_popup);
    try std.testing.expect(popup.isTopLevel());
}

test "BrowsingContext - getTop" {
    const allocator = std.testing.allocator;

    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();

    const child1 = try BrowsingContext.initChild(allocator, top);
    const child2 = try BrowsingContext.initChild(allocator, child1);

    try std.testing.expect(top.getTop() == top);
    try std.testing.expect(child1.getTop() == top);
    try std.testing.expect(child2.getTop() == top);
}

test "BrowsingContext - target name" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.init(allocator);
    defer ctx.deinit();

    try ctx.setTargetName("myframe");
    try std.testing.expectEqualStrings("myframe", ctx.target_name);
}

test "BrowsingContext - close" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.init(allocator);
    defer ctx.deinit();

    try std.testing.expect(!ctx.is_closed);
    ctx.close();
    try std.testing.expect(ctx.is_closed);
    try std.testing.expect(ctx.disowned);
}

test "BrowsingContextGroup - basic operations" {
    const allocator = std.testing.allocator;

    const group = try BrowsingContextGroup.init(allocator);
    defer group.deinit();

    const ctx1 = try BrowsingContext.init(allocator);
    defer ctx1.deinit();

    const ctx2 = try BrowsingContext.init(allocator);
    defer ctx2.deinit();

    try group.addContext(ctx1);
    try group.addContext(ctx2);

    try std.testing.expectEqual(@as(usize, 2), group.size());
    try std.testing.expect(ctx1.isInSameGroup(ctx2));
}
