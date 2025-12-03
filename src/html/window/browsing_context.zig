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
const infra = @import("infra");

// Import security policy types for COOP/COEP
const security_policies = @import("../navigation/security_policies.zig");
const CoopValue = security_policies.CoopValue;
const CoepValue = security_policies.CoepValue;

/// Unique ID generator for browsing contexts
var next_context_id: u64 = 1;
var next_group_id: u64 = 1;

// ============================================================================
// Sandbox Flags - HTML Standard §4.8.5
// ============================================================================

/// Sandbox flags for iframe browsing contexts.
/// Per HTML Standard §4.8.5.4 (https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox)
///
/// When an iframe has the sandbox attribute:
/// - If empty, all restrictions apply
/// - If contains allow-* tokens, those specific restrictions are lifted
///
/// This is a packed struct for efficient storage and operations.
pub const SandboxFlags = packed struct {
    /// allow-scripts: Allow script execution
    allow_scripts: bool = false,

    /// allow-same-origin: Keep the sandboxed document's origin
    /// (otherwise it gets a unique opaque origin)
    allow_same_origin: bool = false,

    /// allow-forms: Allow form submission
    allow_forms: bool = false,

    /// allow-popups: Allow window.open() and similar
    allow_popups: bool = false,

    /// allow-top-navigation: Allow navigating the top-level browsing context
    allow_top_navigation: bool = false,

    /// allow-top-navigation-by-user-activation: Allow top navigation with user gesture
    allow_top_navigation_by_user_activation: bool = false,

    /// allow-pointer-lock: Allow Pointer Lock API
    allow_pointer_lock: bool = false,

    /// allow-modals: Allow alert(), confirm(), prompt()
    allow_modals: bool = false,

    /// allow-orientation-lock: Allow screen orientation lock
    allow_orientation_lock: bool = false,

    /// allow-presentation: Allow Presentation API
    allow_presentation: bool = false,

    /// allow-downloads: Allow downloads (non-standard but widely supported)
    allow_downloads: bool = false,

    /// allow-storage-access-by-user-activation: Allow storage access with user gesture
    allow_storage_access_by_user_activation: bool = false,

    /// allow-popups-to-escape-sandbox: Popups don't inherit sandbox
    allow_popups_to_escape_sandbox: bool = false,

    /// allow-top-navigation-to-custom-protocols: Allow navigation to custom protocols
    allow_top_navigation_to_custom_protocols: bool = false,

    // Padding to align to byte boundary (14 flags, need 2 more for 16 bits)
    _padding: u2 = 0,

    /// Default flags (all restrictions enabled = all false)
    pub const RESTRICTIVE = SandboxFlags{};

    /// No restrictions (all permissions allowed)
    pub const PERMISSIVE = SandboxFlags{
        .allow_scripts = true,
        .allow_same_origin = true,
        .allow_forms = true,
        .allow_popups = true,
        .allow_top_navigation = true,
        .allow_top_navigation_by_user_activation = true,
        .allow_pointer_lock = true,
        .allow_modals = true,
        .allow_orientation_lock = true,
        .allow_presentation = true,
        .allow_downloads = true,
        .allow_storage_access_by_user_activation = true,
        .allow_popups_to_escape_sandbox = true,
        .allow_top_navigation_to_custom_protocols = true,
    };

    /// Parse a space-separated sandbox attribute value into SandboxFlags.
    /// Per spec, empty sandbox attribute means all restrictions apply.
    /// Each "allow-*" token lifts that specific restriction.
    pub fn parse(value: []const u8) SandboxFlags {
        var flags = SandboxFlags.RESTRICTIVE;

        // Tokenize by whitespace
        var iter = std.mem.tokenizeAny(u8, value, " \t\n\r\x0c");
        while (iter.next()) |token| {
            const lower = std.ascii.lowerString(undefined, token);
            if (std.mem.eql(u8, lower, "allow-scripts")) {
                flags.allow_scripts = true;
            } else if (std.mem.eql(u8, lower, "allow-same-origin")) {
                flags.allow_same_origin = true;
            } else if (std.mem.eql(u8, lower, "allow-forms")) {
                flags.allow_forms = true;
            } else if (std.mem.eql(u8, lower, "allow-popups")) {
                flags.allow_popups = true;
            } else if (std.mem.eql(u8, lower, "allow-top-navigation")) {
                flags.allow_top_navigation = true;
            } else if (std.mem.eql(u8, lower, "allow-top-navigation-by-user-activation")) {
                flags.allow_top_navigation_by_user_activation = true;
            } else if (std.mem.eql(u8, lower, "allow-pointer-lock")) {
                flags.allow_pointer_lock = true;
            } else if (std.mem.eql(u8, lower, "allow-modals")) {
                flags.allow_modals = true;
            } else if (std.mem.eql(u8, lower, "allow-orientation-lock")) {
                flags.allow_orientation_lock = true;
            } else if (std.mem.eql(u8, lower, "allow-presentation")) {
                flags.allow_presentation = true;
            } else if (std.mem.eql(u8, lower, "allow-downloads")) {
                flags.allow_downloads = true;
            } else if (std.mem.eql(u8, lower, "allow-storage-access-by-user-activation")) {
                flags.allow_storage_access_by_user_activation = true;
            } else if (std.mem.eql(u8, lower, "allow-popups-to-escape-sandbox")) {
                flags.allow_popups_to_escape_sandbox = true;
            } else if (std.mem.eql(u8, lower, "allow-top-navigation-to-custom-protocols")) {
                flags.allow_top_navigation_to_custom_protocols = true;
            }
            // Unknown tokens are ignored per spec
        }

        return flags;
    }

    /// Parse with allocator for proper case-insensitive comparison
    pub fn parseAlloc(allocator: Allocator, value: []const u8) !SandboxFlags {
        var flags = SandboxFlags.RESTRICTIVE;

        // Tokenize by whitespace
        var iter = std.mem.tokenizeAny(u8, value, " \t\n\r\x0c");
        while (iter.next()) |token| {
            // Allocate lowercase buffer
            const lower = try allocator.alloc(u8, token.len);
            defer allocator.free(lower);
            for (token, 0..) |c, i| {
                lower[i] = std.ascii.toLower(c);
            }

            if (std.mem.eql(u8, lower, "allow-scripts")) {
                flags.allow_scripts = true;
            } else if (std.mem.eql(u8, lower, "allow-same-origin")) {
                flags.allow_same_origin = true;
            } else if (std.mem.eql(u8, lower, "allow-forms")) {
                flags.allow_forms = true;
            } else if (std.mem.eql(u8, lower, "allow-popups")) {
                flags.allow_popups = true;
            } else if (std.mem.eql(u8, lower, "allow-top-navigation")) {
                flags.allow_top_navigation = true;
            } else if (std.mem.eql(u8, lower, "allow-top-navigation-by-user-activation")) {
                flags.allow_top_navigation_by_user_activation = true;
            } else if (std.mem.eql(u8, lower, "allow-pointer-lock")) {
                flags.allow_pointer_lock = true;
            } else if (std.mem.eql(u8, lower, "allow-modals")) {
                flags.allow_modals = true;
            } else if (std.mem.eql(u8, lower, "allow-orientation-lock")) {
                flags.allow_orientation_lock = true;
            } else if (std.mem.eql(u8, lower, "allow-presentation")) {
                flags.allow_presentation = true;
            } else if (std.mem.eql(u8, lower, "allow-downloads")) {
                flags.allow_downloads = true;
            } else if (std.mem.eql(u8, lower, "allow-storage-access-by-user-activation")) {
                flags.allow_storage_access_by_user_activation = true;
            } else if (std.mem.eql(u8, lower, "allow-popups-to-escape-sandbox")) {
                flags.allow_popups_to_escape_sandbox = true;
            } else if (std.mem.eql(u8, lower, "allow-top-navigation-to-custom-protocols")) {
                flags.allow_top_navigation_to_custom_protocols = true;
            }
            // Unknown tokens are ignored per spec
        }

        return flags;
    }

    /// Check if scripts are blocked (sandbox without allow-scripts)
    pub fn blocksScripts(self: SandboxFlags) bool {
        return !self.allow_scripts;
    }

    /// Check if same-origin is sandboxed (gets opaque origin)
    pub fn sandboxesSameOrigin(self: SandboxFlags) bool {
        return !self.allow_same_origin;
    }

    /// Check if forms are blocked
    pub fn blocksForms(self: SandboxFlags) bool {
        return !self.allow_forms;
    }

    /// Check if popups are blocked
    pub fn blocksPopups(self: SandboxFlags) bool {
        return !self.allow_popups;
    }

    /// Check if top navigation is blocked
    pub fn blocksTopNavigation(self: SandboxFlags) bool {
        return !self.allow_top_navigation and !self.allow_top_navigation_by_user_activation;
    }

    /// Check if modals (alert/confirm/prompt) are blocked
    pub fn blocksModals(self: SandboxFlags) bool {
        return !self.allow_modals;
    }

    /// Supported tokens for DOMTokenList.supports()
    pub const SUPPORTED_TOKENS = [_][]const u8{
        "allow-downloads",
        "allow-forms",
        "allow-modals",
        "allow-orientation-lock",
        "allow-pointer-lock",
        "allow-popups",
        "allow-popups-to-escape-sandbox",
        "allow-presentation",
        "allow-same-origin",
        "allow-scripts",
        "allow-storage-access-by-user-activation",
        "allow-top-navigation",
        "allow-top-navigation-by-user-activation",
        "allow-top-navigation-to-custom-protocols",
    };
};

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

    /// Sandbox flags for this browsing context (§4.8.5.4)
    /// Null means no sandbox restrictions apply.
    /// When set, these flags determine what the sandboxed context can do.
    sandbox_flags: ?SandboxFlags,

    /// Whether this context is sandboxed (has sandbox attribute)
    is_sandboxed: bool,

    // === Cross-Origin Isolation (HTML Standard §7.2.5) ===

    /// Cross-Origin-Opener-Policy value
    /// Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-opener-policy-value
    coop_value: CoopValue = .unsafe_none,

    /// Cross-Origin-Embedder-Policy value
    /// Spec: https://html.spec.whatwg.org/multipage/browsers.html#coep
    coep_value: CoepValue = .unsafe_none,

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
            .sandbox_flags = null,
            .is_sandboxed = false,
            .coop_value = .unsafe_none,
            .coep_value = .unsafe_none,
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

    /// Set sandbox flags on this browsing context
    /// Per HTML Standard §4.8.5.4
    pub fn setSandboxFlags(self: *BrowsingContext, flags: SandboxFlags) void {
        self.sandbox_flags = flags;
        self.is_sandboxed = true;
    }

    /// Clear sandbox flags (remove sandboxing)
    pub fn clearSandboxFlags(self: *BrowsingContext) void {
        self.sandbox_flags = null;
        self.is_sandboxed = false;
    }

    /// Check if this context allows script execution
    pub fn allowsScripts(self: *const BrowsingContext) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_scripts;
        }
        return true; // Not sandboxed, allow scripts
    }

    /// Check if this context allows form submission
    pub fn allowsForms(self: *const BrowsingContext) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_forms;
        }
        return true;
    }

    /// Check if this context allows popups
    pub fn allowsPopups(self: *const BrowsingContext) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_popups;
        }
        return true;
    }

    /// Check if this context allows top navigation
    pub fn allowsTopNavigation(self: *const BrowsingContext) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_top_navigation;
        }
        return true;
    }

    // === Cross-Origin Isolation (HTML Standard §7.2.5) ===

    /// Check if this browsing context is cross-origin isolated
    /// Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-isolated
    ///
    /// A browsing context is cross-origin isolated if:
    /// 1. COOP is same-origin
    /// 2. COEP is require-corp or credentialless
    ///
    /// This enables access to APIs like SharedArrayBuffer that are only
    /// available in cross-origin isolated contexts.
    pub fn isCrossOriginIsolated(self: *const BrowsingContext) bool {
        return security_policies.isCrossOriginIsolated(self.coop_value, self.coep_value);
    }

    /// Set COOP value for this browsing context
    /// Called after navigation when processing response headers.
    pub fn setCoop(self: *BrowsingContext, value: CoopValue) void {
        self.coop_value = value;
    }

    /// Set COEP value for this browsing context
    /// Called after navigation when processing response headers.
    pub fn setCoep(self: *BrowsingContext, value: CoepValue) void {
        self.coep_value = value;
    }

    /// Get COOP value
    pub fn getCoop(self: *const BrowsingContext) CoopValue {
        return self.coop_value;
    }

    /// Get COEP value
    pub fn getCoep(self: *const BrowsingContext) CoepValue {
        return self.coep_value;
    }

    /// Check if this context allows modals (alert/confirm/prompt)
    pub fn allowsModals(self: *const BrowsingContext) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_modals;
        }
        return true;
    }

    /// Check if this context preserves same-origin (vs opaque origin)
    pub fn preservesSameOrigin(self: *const BrowsingContext) bool {
        if (self.sandbox_flags) |flags| {
            return flags.allow_same_origin;
        }
        return true;
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
    contexts: infra.List(*BrowsingContext),

    /// Create a new browsing context group
    pub fn init(allocator: Allocator) !*BrowsingContextGroup {
        const group = try allocator.create(BrowsingContextGroup);
        group.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_group_id, .Add, 1, .monotonic),
            .contexts = infra.List(*BrowsingContext).init(allocator),
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
    pub fn getSize(self: *const BrowsingContextGroup) usize {
        return self.contexts.size();
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

test "BrowsingContext - disown severs opener relationship" {
    const allocator = std.testing.allocator;

    // Create opener and popup
    const opener = try BrowsingContext.initTopLevel(allocator);
    defer opener.deinit();

    const popup = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer popup.deinit();

    // Verify opener is set
    try std.testing.expect(popup.opener == opener);
    try std.testing.expect(!popup.disowned);

    // Disown - this simulates window.opener = null
    popup.disown();

    // Verify relationship is severed
    try std.testing.expect(popup.opener == null);
    try std.testing.expect(popup.disowned);
}

test "BrowsingContext - auxiliary with noopener starts disowned" {
    const allocator = std.testing.allocator;

    // Create opener
    const opener = try BrowsingContext.initTopLevel(allocator);
    defer opener.deinit();

    // Simulate noopener: create auxiliary but immediately disown
    const popup = try BrowsingContext.initAuxiliary(allocator, opener, true);
    defer popup.deinit();
    popup.disown(); // noopener semantics

    // The popup should have no accessible opener
    try std.testing.expect(popup.opener == null);
    try std.testing.expect(popup.disowned);
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

    try std.testing.expectEqual(@as(usize, 2), group.getSize());
    try std.testing.expect(ctx1.isInSameGroup(ctx2));
}

// ============================================================================
// SandboxFlags Tests
// ============================================================================

test "SandboxFlags - parseAlloc empty string is fully restrictive" {
    const allocator = std.testing.allocator;

    const flags = try SandboxFlags.parseAlloc(allocator, "");

    try std.testing.expect(!flags.allow_scripts);
    try std.testing.expect(!flags.allow_same_origin);
    try std.testing.expect(!flags.allow_forms);
    try std.testing.expect(!flags.allow_popups);
    try std.testing.expect(!flags.allow_top_navigation);
}

test "SandboxFlags - parseAlloc single flag" {
    const allocator = std.testing.allocator;

    const flags = try SandboxFlags.parseAlloc(allocator, "allow-scripts");

    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(!flags.allow_same_origin);
    try std.testing.expect(!flags.allow_forms);
}

test "SandboxFlags - parseAlloc multiple flags" {
    const allocator = std.testing.allocator;

    const flags = try SandboxFlags.parseAlloc(allocator, "allow-scripts allow-forms allow-same-origin");

    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(flags.allow_same_origin);
    try std.testing.expect(flags.allow_forms);
    try std.testing.expect(!flags.allow_popups);
}

test "SandboxFlags - parseAlloc case insensitive" {
    const allocator = std.testing.allocator;

    const flags = try SandboxFlags.parseAlloc(allocator, "ALLOW-SCRIPTS Allow-Forms");

    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(flags.allow_forms);
}

test "SandboxFlags - parseAlloc ignores unknown tokens" {
    const allocator = std.testing.allocator;

    const flags = try SandboxFlags.parseAlloc(allocator, "allow-scripts unknown-token allow-forms");

    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(flags.allow_forms);
}

test "SandboxFlags - parseAlloc with whitespace" {
    const allocator = std.testing.allocator;

    const flags = try SandboxFlags.parseAlloc(allocator, "  allow-scripts   allow-forms  \t\n allow-popups  ");

    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(flags.allow_forms);
    try std.testing.expect(flags.allow_popups);
}

test "SandboxFlags - RESTRICTIVE constant" {
    const flags = SandboxFlags.RESTRICTIVE;

    try std.testing.expect(!flags.allow_scripts);
    try std.testing.expect(!flags.allow_same_origin);
    try std.testing.expect(!flags.allow_forms);
    try std.testing.expect(!flags.allow_popups);
}

test "SandboxFlags - PERMISSIVE constant" {
    const flags = SandboxFlags.PERMISSIVE;

    try std.testing.expect(flags.allow_scripts);
    try std.testing.expect(flags.allow_same_origin);
    try std.testing.expect(flags.allow_forms);
    try std.testing.expect(flags.allow_popups);
    try std.testing.expect(flags.allow_top_navigation);
}

test "SandboxFlags - helper methods" {
    const allocator = std.testing.allocator;

    // Test blocksScripts
    const restrictive = try SandboxFlags.parseAlloc(allocator, "");
    try std.testing.expect(restrictive.blocksScripts());

    const with_scripts = try SandboxFlags.parseAlloc(allocator, "allow-scripts");
    try std.testing.expect(!with_scripts.blocksScripts());

    // Test sandboxesSameOrigin
    try std.testing.expect(restrictive.sandboxesSameOrigin());

    const with_same_origin = try SandboxFlags.parseAlloc(allocator, "allow-same-origin");
    try std.testing.expect(!with_same_origin.sandboxesSameOrigin());
}

test "BrowsingContext - sandbox flags" {
    const allocator = std.testing.allocator;

    const ctx = try BrowsingContext.init(allocator);
    defer ctx.deinit();

    // Not sandboxed by default
    try std.testing.expect(!ctx.is_sandboxed);
    try std.testing.expect(ctx.allowsScripts());
    try std.testing.expect(ctx.allowsForms());

    // Set restrictive sandbox
    ctx.setSandboxFlags(SandboxFlags.RESTRICTIVE);
    try std.testing.expect(ctx.is_sandboxed);
    try std.testing.expect(!ctx.allowsScripts());
    try std.testing.expect(!ctx.allowsForms());

    // Clear sandbox
    ctx.clearSandboxFlags();
    try std.testing.expect(!ctx.is_sandboxed);
    try std.testing.expect(ctx.allowsScripts());
}
