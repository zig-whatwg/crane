//! Navigable - HTML Standard §7.3
//!
//! A navigable presents a Document to the user via its active session history entry.
//! Traversable navigables additionally can have their session history traversed.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#navigables
//!
//! ## Key Concepts
//!
//! - **Navigable**: A presentation context for a Document
//! - **Traversable Navigable**: A top-level navigable with session history traversal capability
//! - **Container**: The embedding element (iframe, frame, object, embed)
//! - **Active Session History Entry**: The currently presented entry
//!
//! ## Architecture
//!
//! ```
//! TraversableNavigable (top-level browsing context)
//! ├── session_history_entries: []SessionHistoryEntry
//! ├── session_history_traversal_queue: []TraversalTask
//! └── child navigables (iframes, etc.)
//!     └── Navigable
//!         ├── active_session_history_entry
//!         └── current_session_history_entry
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const session_history = @import("session_history.zig");
const SessionHistoryEntry = session_history.SessionHistoryEntry;
const SessionHistoryList = session_history.SessionHistoryList;
const DocumentState = session_history.DocumentState;
const ScrollRestorationMode = session_history.ScrollRestorationMode;

const events = @import("events.zig");
const NavigationType = events.NavigationType;

// ============================================================================
// Navigable State
// ============================================================================

/// The state of a navigable
pub const NavigableState = enum {
    /// Initial state before first navigation
    initial,
    /// Active and presenting a document
    active,
    /// Navigable has been destroyed
    destroyed,
};

// ============================================================================
// Navigable - HTML Standard §7.3
// ============================================================================

/// A navigable is used to present a Document to the user.
///
/// HTML Standard §7.3:
/// "A navigable is a concept which connects Documents with the user's browsing experience."
pub const Navigable = struct {
    allocator: Allocator,

    /// A unique internal ID for this navigable
    id: u64,

    /// The navigable's current session history entry
    /// HTML Standard: "A navigable has a current session history entry, a session history entry."
    current_session_history_entry: ?*SessionHistoryEntry,

    /// The navigable's active session history entry
    /// HTML Standard: "A navigable has an active session history entry, a session history entry.
    /// This is the entry that is currently being presented to the user."
    active_session_history_entry: ?*SessionHistoryEntry,

    /// The parent navigable (null for top-level)
    parent: ?*Navigable,

    /// The container element (iframe, frame, etc.) - opaque pointer to Element
    container: ?*anyopaque,

    /// The target name for window.open() and similar
    /// HTML Standard: "A navigable has a target name, a string."
    target_name: []const u8,

    /// Whether this is a top-level traversable
    is_top_level: bool,

    /// State of this navigable
    state: NavigableState,

    /// Child navigables (for iframes, frames, etc.)
    children: std.ArrayList(*Navigable),

    /// Next ID generator
    var next_id: u64 = 1;

    /// Create a new navigable
    pub fn init(allocator: Allocator) !*Navigable {
        const navigable = try allocator.create(Navigable);
        navigable.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_id, .Add, 1, .monotonic),
            .current_session_history_entry = null,
            .active_session_history_entry = null,
            .parent = null,
            .container = null,
            .target_name = "",
            .is_top_level = false,
            .state = .initial,
            .children = std.ArrayList(*Navigable).init(allocator),
        };
        return navigable;
    }

    /// Free resources
    pub fn deinit(self: *Navigable) void {
        // Note: Don't free session history entries here - they're owned by the traversable
        if (self.target_name.len > 0) {
            self.allocator.free(self.target_name);
        }

        // Recursively deinit children
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();

        self.allocator.destroy(self);
    }

    /// Set the target name
    pub fn setTargetName(self: *Navigable, name: []const u8) !void {
        if (self.target_name.len > 0) {
            self.allocator.free(self.target_name);
        }
        self.target_name = try self.allocator.dupe(u8, name);
    }

    /// Get the active document
    ///
    /// HTML Standard:
    /// "A navigable's active document is its active session history entry's document."
    pub fn activeDocument(self: *const Navigable) ?*anyopaque {
        if (self.active_session_history_entry) |entry| {
            return entry.getDocument();
        }
        return null;
    }

    /// Get the navigable's content document (for container elements)
    pub fn contentDocument(self: *const Navigable) ?*anyopaque {
        return self.activeDocument();
    }

    /// Get the traversable navigable (walk up to top-level)
    ///
    /// HTML Standard:
    /// "A navigable's traversable navigable is the traversable navigable whose
    /// session history entries will be impacted by navigations initiated from
    /// within that navigable."
    pub fn traversableNavigable(self: *const Navigable) ?*Navigable {
        var current: *const Navigable = self;
        while (current.parent) |p| {
            current = p;
        }
        if (current.is_top_level) {
            return @constCast(current);
        }
        return null;
    }

    /// Get the top-level traversable
    pub fn topLevelTraversable(self: *const Navigable) ?*Navigable {
        return self.traversableNavigable();
    }

    /// Check if this navigable is a top-level traversable
    pub fn isTopLevelTraversable(self: *const Navigable) bool {
        return self.is_top_level and self.parent == null;
    }

    /// Add a child navigable
    pub fn addChild(self: *Navigable, child: *Navigable) !void {
        child.parent = self;
        try self.children.append(child);
    }

    /// Remove a child navigable
    pub fn removeChild(self: *Navigable, child: *Navigable) void {
        for (self.children.items, 0..) |c, i| {
            if (c == child) {
                _ = self.children.orderedRemove(i);
                child.parent = null;
                return;
            }
        }
    }

    /// Set the active session history entry
    pub fn setActiveEntry(self: *Navigable, entry: *SessionHistoryEntry) void {
        self.active_session_history_entry = entry;
        self.state = .active;
    }

    /// Set the current session history entry
    pub fn setCurrentEntry(self: *Navigable, entry: *SessionHistoryEntry) void {
        self.current_session_history_entry = entry;
    }

    /// Get the navigable's fully active status
    ///
    /// HTML Standard:
    /// "A Document d is fully active when d is the active document of a navigable
    /// navigable, and either navigable is a top-level traversable, or navigable's
    /// container document is fully active."
    pub fn isFullyActive(self: *const Navigable) bool {
        if (self.state != .active) return false;
        if (self.active_session_history_entry == null) return false;

        if (self.isTopLevelTraversable()) {
            return true;
        }

        // Check if parent's document is fully active
        if (self.parent) |p| {
            return p.isFullyActive();
        }

        return false;
    }

    /// Destroy this navigable
    pub fn destroy(self: *Navigable) void {
        self.state = .destroyed;

        // Destroy all children
        for (self.children.items) |child| {
            child.destroy();
        }
    }
};

// ============================================================================
// Traversal Task
// ============================================================================

/// A task in the session history traversal queue
pub const TraversalTask = struct {
    /// The target step to traverse to
    target_step: u64,

    /// Source document that initiated the traversal (for security checks)
    source_document: ?*anyopaque,

    /// User involvement type
    user_involvement: UserInvolvement,

    /// Whether this is a reload
    is_reload: bool,

    /// Navigation type
    navigation_type: NavigationType,
};

/// User involvement in navigation
pub const UserInvolvement = enum {
    /// Navigated by browser UI (address bar, bookmarks, etc.)
    browser_ui,
    /// User activated a link or form
    activation,
    /// Programmatic navigation (no user activation)
    none,
};

// ============================================================================
// Traversable Navigable - HTML Standard §7.3.2
// ============================================================================

/// A traversable navigable is a navigable that can be traversed through session history.
///
/// HTML Standard §7.3.2:
/// "A traversable navigable is a navigable that also has:
/// - session history entries, a list of session history entries
/// - current session history step, an integer
/// - session history traversal queue"
pub const TraversableNavigable = struct {
    allocator: Allocator,

    /// The underlying navigable
    navigable: *Navigable,

    /// Session history entries
    /// HTML Standard: "session history entries, a list of session history entries"
    session_history: SessionHistoryList,

    /// The session history traversal queue
    /// HTML Standard: "session history traversal queue, a parallel queue"
    traversal_queue: std.ArrayList(TraversalTask),

    /// Whether traversal is currently running
    traversal_running: bool,

    /// The system visibility state
    /// HTML Standard: "A traversable navigable has a system visibility state, which is
    /// a visibility state. It is initially 'hidden'."
    system_visibility_state: VisibilityState,

    /// Loading mode for cross-origin isolations
    /// HTML Standard: "A traversable navigable has a loading mode, which is a string"
    loading_mode: LoadingMode,

    /// Create a new traversable navigable
    pub fn init(allocator: Allocator, initial_url: []const u8) !*TraversableNavigable {
        const traversable = try allocator.create(TraversableNavigable);
        errdefer allocator.destroy(traversable);

        const navigable = try Navigable.init(allocator);
        errdefer navigable.deinit();

        navigable.is_top_level = true;

        traversable.* = .{
            .allocator = allocator,
            .navigable = navigable,
            .session_history = SessionHistoryList.init(allocator),
            .traversal_queue = std.ArrayList(TraversalTask).init(allocator),
            .traversal_running = false,
            .system_visibility_state = .hidden,
            .loading_mode = .default,
        };

        // Create initial entry
        const entry = try SessionHistoryEntry.init(allocator, initial_url);
        entry.setStep(0);
        try traversable.session_history.append(entry);

        navigable.setActiveEntry(entry);
        navigable.setCurrentEntry(entry);

        return traversable;
    }

    /// Free resources
    pub fn deinit(self: *TraversableNavigable) void {
        self.session_history.deinit();
        self.traversal_queue.deinit();
        self.navigable.deinit();
        self.allocator.destroy(self);
    }

    /// Get the current session history step
    pub fn currentStep(self: *const TraversableNavigable) u64 {
        return self.session_history.current_step;
    }

    /// Get all session history entries
    pub fn entries(self: *const TraversableNavigable) []*SessionHistoryEntry {
        return self.session_history.entries.items;
    }

    /// Get the joint session history length (per HTML spec)
    pub fn jointSessionHistoryLength(self: *const TraversableNavigable) usize {
        return self.session_history.length();
    }

    /// Append a session history entry
    ///
    /// HTML Standard §7.4.3:
    /// "To append a session history entry to a navigable..."
    pub fn appendEntry(self: *TraversableNavigable, entry: *SessionHistoryEntry) !void {
        // Clear forward entries
        self.session_history.clearForward(self.session_history.current_step);

        // Set step to next value
        entry.setStep(self.session_history.current_step + 1);

        // Append
        try self.session_history.append(entry);

        // Update current step
        self.session_history.current_step = entry.step.getValue().?;

        // Update navigable
        self.navigable.setActiveEntry(entry);
        self.navigable.setCurrentEntry(entry);
    }

    /// Enqueue a traversal task
    pub fn enqueueTraversal(self: *TraversableNavigable, task: TraversalTask) !void {
        try self.traversal_queue.append(task);
        // In a real implementation, this would trigger the traversal queue processing
    }

    /// Traverse history by a delta
    ///
    /// HTML Standard §7.4.5:
    /// "To traverse the history by a delta given a traversable navigable traversable,
    /// an integer delta, and an optional source document..."
    pub fn traverseByDelta(
        self: *TraversableNavigable,
        delta: i64,
        source_document: ?*anyopaque,
        user_involvement: UserInvolvement,
    ) !void {
        const current = self.currentStep();
        const new_step = if (delta >= 0)
            current + @as(u64, @intCast(delta))
        else
            current -| @as(u64, @intCast(-delta));

        // Check if step exists
        if (self.session_history.getEntryByStep(new_step) == null) {
            return; // No entry at that step
        }

        try self.enqueueTraversal(.{
            .target_step = new_step,
            .source_document = source_document,
            .user_involvement = user_involvement,
            .is_reload = false,
            .navigation_type = .traverse,
        });
    }

    /// Process the next task in the traversal queue
    pub fn processTraversalQueue(self: *TraversableNavigable) !?TraversalTask {
        if (self.traversal_running) return null;
        if (self.traversal_queue.items.len == 0) return null;

        self.traversal_running = true;
        const task = self.traversal_queue.orderedRemove(0);
        return task;
    }

    /// Complete a traversal task
    pub fn completeTraversal(self: *TraversableNavigable, task: TraversalTask) void {
        self.session_history.current_step = task.target_step;

        if (self.session_history.getEntryByStep(task.target_step)) |entry| {
            self.navigable.setActiveEntry(entry);
            self.navigable.setCurrentEntry(entry);
        }

        self.traversal_running = false;
    }

    /// Get entries that need to be traversed for a given target step
    pub fn getTraversableEntries(
        self: *const TraversableNavigable,
        target_step: u64,
        allocator: Allocator,
    ) ![]*SessionHistoryEntry {
        var result = std.ArrayList(*SessionHistoryEntry).init(allocator);
        errdefer result.deinit();

        // Find all entries between current step and target step that have documents
        const current = self.currentStep();
        const start = if (current < target_step) current else target_step;
        const end = if (current < target_step) target_step else current;

        for (self.session_history.entries.items) |entry| {
            if (entry.step.getValue()) |step| {
                if (step >= start and step <= end) {
                    try result.append(entry);
                }
            }
        }

        return try allocator.dupe(*SessionHistoryEntry, result.items);
    }

    /// Reload the current document
    pub fn reload(self: *TraversableNavigable, user_involvement: UserInvolvement) !void {
        try self.enqueueTraversal(.{
            .target_step = self.currentStep(),
            .source_document = null,
            .user_involvement = user_involvement,
            .is_reload = true,
            .navigation_type = .reload,
        });
    }
};

/// Visibility state of a document
pub const VisibilityState = enum {
    visible,
    hidden,

    pub fn toString(self: VisibilityState) []const u8 {
        return switch (self) {
            .visible => "visible",
            .hidden => "hidden",
        };
    }
};

/// Loading mode for cross-origin isolation
pub const LoadingMode = enum {
    default,
    credentialless,

    pub fn toString(self: LoadingMode) []const u8 {
        return switch (self) {
            .default => "default",
            .credentialless => "credentialless",
        };
    }
};

// ============================================================================
// Navigable Utilities
// ============================================================================

/// Get all active child navigables
pub fn getChildNavigables(navigable: *const Navigable, allocator: Allocator) ![]*Navigable {
    var result = std.ArrayList(*Navigable).init(allocator);
    errdefer result.deinit();

    for (navigable.children.items) |child| {
        if (child.state == .active) {
            try result.append(child);
        }
    }

    return try allocator.dupe(*Navigable, result.items);
}

/// Get all descendant navigables (recursive)
pub fn getDescendantNavigables(navigable: *const Navigable, allocator: Allocator) ![]*Navigable {
    var result = std.ArrayList(*Navigable).init(allocator);
    errdefer result.deinit();

    var stack = std.ArrayList(*const Navigable).init(allocator);
    defer stack.deinit();

    try stack.append(navigable);

    while (stack.items.len > 0) {
        const current = stack.pop();
        for (current.children.items) |child| {
            if (child.state == .active) {
                try result.append(child);
                try stack.append(child);
            }
        }
    }

    return try allocator.dupe(*Navigable, result.items);
}

/// Get the inclusive ancestor navigables
pub fn getInclusiveAncestorNavigables(navigable: *const Navigable, allocator: Allocator) ![]*Navigable {
    var result = std.ArrayList(*Navigable).init(allocator);
    errdefer result.deinit();

    var current: ?*const Navigable = navigable;
    while (current) |nav| {
        try result.append(@constCast(nav));
        current = nav.parent;
    }

    return try allocator.dupe(*Navigable, result.items);
}

// ============================================================================
// Tests
// ============================================================================

test "Navigable - init and deinit" {
    const allocator = std.testing.allocator;

    const navigable = try Navigable.init(allocator);
    defer navigable.deinit();

    try std.testing.expect(navigable.parent == null);
    try std.testing.expect(!navigable.is_top_level);
    try std.testing.expectEqual(NavigableState.initial, navigable.state);
}

test "Navigable - parent child relationship" {
    const allocator = std.testing.allocator;

    const parent = try Navigable.init(allocator);
    defer parent.deinit();

    const child = try Navigable.init(allocator);
    // Don't defer deinit - parent will handle it

    try parent.addChild(child);

    try std.testing.expectEqual(parent, child.parent);
    try std.testing.expectEqual(@as(usize, 1), parent.children.items.len);
}

test "TraversableNavigable - init and deinit" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/");
    defer traversable.deinit();

    try std.testing.expect(traversable.navigable.is_top_level);
    try std.testing.expectEqual(@as(usize, 1), traversable.jointSessionHistoryLength());
    try std.testing.expectEqual(@as(u64, 0), traversable.currentStep());
}

test "TraversableNavigable - append entry" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/page1");
    defer traversable.deinit();

    const entry = try SessionHistoryEntry.init(allocator, "https://example.com/page2");
    try traversable.appendEntry(entry);

    try std.testing.expectEqual(@as(usize, 2), traversable.jointSessionHistoryLength());
    try std.testing.expectEqual(@as(u64, 1), traversable.currentStep());
}

test "TraversableNavigable - traverse by delta" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/page1");
    defer traversable.deinit();

    const entry = try SessionHistoryEntry.init(allocator, "https://example.com/page2");
    try traversable.appendEntry(entry);

    // Go back
    try traversable.traverseByDelta(-1, null, .none);

    try std.testing.expectEqual(@as(usize, 1), traversable.traversal_queue.items.len);
    try std.testing.expectEqual(@as(u64, 0), traversable.traversal_queue.items[0].target_step);
}

test "Navigable - fully active check" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/");
    defer traversable.deinit();

    // Top-level navigable should be fully active
    try std.testing.expect(traversable.navigable.isFullyActive());
}

test "getChildNavigables" {
    const allocator = std.testing.allocator;

    const parent = try Navigable.init(allocator);
    defer parent.deinit();
    parent.state = .active;

    const child1 = try Navigable.init(allocator);
    child1.state = .active;
    try parent.addChild(child1);

    const child2 = try Navigable.init(allocator);
    child2.state = .initial; // Not active
    try parent.addChild(child2);

    const active_children = try getChildNavigables(parent, allocator);
    defer allocator.free(active_children);

    try std.testing.expectEqual(@as(usize, 1), active_children.len);
}
