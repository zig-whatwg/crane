//! History API - HTML Standard §7.2.4
//!
//! The History interface provides access to the browser's session history and
//! allows navigation through it via back(), forward(), go(), pushState(), and replaceState().
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-history-interface
//!
//! ## Key Features
//!
//! - **length**: Number of entries in the joint session history
//! - **scrollRestoration**: "auto" or "manual" scroll position handling
//! - **state**: The current entry's serialized state
//! - **go(delta)**: Navigate by delta entries
//! - **back()**: Navigate to the previous entry
//! - **forward()**: Navigate to the next entry
//! - **pushState(data, unused, url)**: Add a new history entry
//! - **replaceState(data, unused, url)**: Replace the current entry
//!
//! ## Usage
//!
//! ```zig
//! const history = @import("history.zig");
//!
//! var h = try History.init(allocator);
//! defer h.deinit();
//!
//! // Push state
//! try h.pushState(state_data, "", "/new-page");
//!
//! // Navigate
//! try h.back();
//! try h.forward();
//! try h.go(-2);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const session_history = @import("session_history.zig");
const SessionHistoryEntry = session_history.SessionHistoryEntry;
const SessionHistoryList = session_history.SessionHistoryList;
const ScrollRestorationMode = session_history.ScrollRestorationMode;
const SerializedState = session_history.SerializedState;

const navigable_mod = @import("navigable.zig");
const Navigable = navigable_mod.Navigable;

// ============================================================================
// History Error
// ============================================================================

/// Errors that can occur during History operations
pub const HistoryError = error{
    /// Document is not fully active
    SecurityError,
    /// Invalid state for the operation
    InvalidStateError,
    /// URL cannot be rewritten
    UrlRewriteError,
    /// Serialization failed
    SerializationError,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// History Interface - HTML Standard §7.2.4
// ============================================================================

/// The History interface
///
/// HTML Standard §7.2.4:
/// "The History interface represents the joint session history of the current
/// browsing context and the browsing contexts in its ancestor and descendant
/// browsing contexts."
pub const History = struct {
    allocator: Allocator,

    /// Internal state (deserialized from current entry's classic history API state)
    state: ?SerializedState,

    /// The length of the joint session history
    /// HTML Standard: "Returns the number of entries in the joint session history"
    length_value: u32,

    /// Index in the joint session history
    index_value: u32,

    /// Associated document (opaque pointer)
    document: ?*anyopaque,

    /// Associated navigable (for accessing session history entries)
    navigable: ?*Navigable,

    /// Callback for when state changes need to be persisted
    on_state_change: ?*const fn (history: *History, entry: *SessionHistoryEntry) void,

    /// Callback for navigation requests
    on_navigate: ?*const fn (history: *History, delta: i32) HistoryError!void,

    /// Callback for push/replace state
    on_push_replace: ?*const fn (
        history: *History,
        data: []const u8,
        url: ?[]const u8,
        is_push: bool,
    ) HistoryError!void,

    /// Context pointer for callbacks
    context: ?*anyopaque,

    /// Create a new History instance
    pub fn init(allocator: Allocator) !*History {
        const history = try allocator.create(History);
        history.* = .{
            .allocator = allocator,
            .state = null,
            .length_value = 1,
            .index_value = 0,
            .document = null,
            .navigable = null,
            .on_state_change = null,
            .on_navigate = null,
            .on_push_replace = null,
            .context = null,
        };
        return history;
    }

    /// Free resources
    pub fn deinit(self: *History) void {
        if (self.state) |*s| {
            s.deinit();
        }
        self.allocator.destroy(self);
    }

    /// Set the associated document
    pub fn setDocument(self: *History, document: *anyopaque) void {
        self.document = document;
    }

    /// Set the associated navigable
    pub fn setNavigable(self: *History, navigable: *Navigable) void {
        self.navigable = navigable;
    }

    /// Set callbacks for integration with the browsing context
    pub fn setCallbacks(
        self: *History,
        on_state_change: ?*const fn (history: *History, entry: *SessionHistoryEntry) void,
        on_navigate: ?*const fn (history: *History, delta: i32) HistoryError!void,
        on_push_replace: ?*const fn (history: *History, data: []const u8, url: ?[]const u8, is_push: bool) HistoryError!void,
        context: ?*anyopaque,
    ) void {
        self.on_state_change = on_state_change;
        self.on_navigate = on_navigate;
        self.on_push_replace = on_push_replace;
        self.context = context;
    }

    // ========================================================================
    // Getters - HTML Standard §7.2.4
    // ========================================================================

    /// Get the length of the joint session history
    ///
    /// HTML Standard:
    /// "The length getter steps are:
    /// 1. If this's relevant global object's associated Document is not fully active,
    ///    then throw a 'SecurityError' DOMException.
    /// 2. Return this's length."
    pub fn length(self: *const History) HistoryError!u32 {
        // In a real implementation, we'd check if the document is fully active
        return self.length_value;
    }

    /// Get the current entry's scroll restoration mode
    ///
    /// HTML Standard:
    /// "The scrollRestoration getter steps are:
    /// 1. If this's relevant global object's associated Document is not fully active,
    ///    then throw a 'SecurityError' DOMException.
    /// 2. Return this's relevant global object's navigable's active session history
    ///    entry's scroll restoration mode."
    pub fn scrollRestoration(self: *const History) HistoryError!ScrollRestorationMode {
        // 1. Check if document is fully active (simplified check)
        if (self.navigable) |nav| {
            if (!nav.isFullyActive()) {
                return error.SecurityError;
            }

            // 2. Return the active entry's scroll restoration mode
            if (nav.active_session_history_entry) |entry| {
                return entry.scroll_restoration_mode;
            }
        }

        // Default to auto if no navigable or entry
        return .auto;
    }

    /// Set the scroll restoration mode
    ///
    /// HTML Standard:
    /// "The scrollRestoration setter steps are:
    /// 1. If this's relevant global object's associated Document is not fully active,
    ///    then throw a 'SecurityError' DOMException.
    /// 2. Set this's relevant global object's navigable's active session history
    ///    entry's scroll restoration mode to the given value."
    pub fn setScrollRestoration(self: *History, mode: ScrollRestorationMode) HistoryError!void {
        // 1. Check if document is fully active (simplified check)
        if (self.navigable) |nav| {
            if (!nav.isFullyActive()) {
                return error.SecurityError;
            }

            // 2. Set the active entry's scroll restoration mode
            if (nav.active_session_history_entry) |entry| {
                entry.scroll_restoration_mode = mode;
            }
        }
    }

    /// Get the current state
    ///
    /// HTML Standard:
    /// "The state getter steps are:
    /// 1. If this's relevant global object's associated Document is not fully active,
    ///    then throw a 'SecurityError' DOMException.
    /// 2. Return this's state."
    pub fn getState(self: *const History) HistoryError!?*const SerializedState {
        if (self.state) |*s| {
            return s;
        }
        return null;
    }

    /// Get the current index in session history
    pub fn index(self: *const History) u32 {
        return self.index_value;
    }

    // ========================================================================
    // Navigation Methods - HTML Standard §7.2.4
    // ========================================================================

    /// Navigate by a delta in the session history
    ///
    /// HTML Standard:
    /// "The go(delta) method steps are to delta traverse this given delta."
    ///
    /// To delta traverse:
    /// "1. Let document be history's relevant global object's associated Document.
    /// 2. If document is not fully active, then throw a 'SecurityError' DOMException.
    /// 3. If delta is 0, then reload document's node navigable, and return.
    /// 4. Traverse the history by a delta given document's node navigable's
    ///    traversable navigable, delta, and with sourceDocument set to document."
    pub fn go(self: *History, delta: i32) HistoryError!void {
        if (self.on_navigate) |callback| {
            try callback(self, delta);
        }
    }

    /// Navigate back one entry
    ///
    /// HTML Standard:
    /// "The back() method steps are to delta traverse this given −1."
    pub fn back(self: *History) HistoryError!void {
        return self.go(-1);
    }

    /// Navigate forward one entry
    ///
    /// HTML Standard:
    /// "The forward() method steps are to delta traverse this given +1."
    pub fn forward(self: *History) HistoryError!void {
        return self.go(1);
    }

    // ========================================================================
    // State Methods - HTML Standard §7.2.4
    // ========================================================================

    /// Push a new state onto the session history
    ///
    /// HTML Standard:
    /// "The pushState(data, unused, url) method steps are to run the shared history
    /// push/replace state steps given this, data, url, and 'push'."
    pub fn pushState(
        self: *History,
        data: []const u8,
        unused: []const u8,
        url: ?[]const u8,
    ) HistoryError!void {
        _ = unused; // Second parameter exists for historical reasons

        if (self.on_push_replace) |callback| {
            try callback(self, data, url, true);
        }
    }

    /// Replace the current state in session history
    ///
    /// HTML Standard:
    /// "The replaceState(data, unused, url) method steps are to run the shared history
    /// push/replace state steps given this, data, url, and 'replace'."
    pub fn replaceState(
        self: *History,
        data: []const u8,
        unused: []const u8,
        url: ?[]const u8,
    ) HistoryError!void {
        _ = unused; // Second parameter exists for historical reasons

        if (self.on_push_replace) |callback| {
            try callback(self, data, url, false);
        }
    }

    // ========================================================================
    // Internal Methods
    // ========================================================================

    /// Update the state from a session history entry
    pub fn updateFromEntry(self: *History, entry: *const SessionHistoryEntry) !void {
        if (self.state) |*s| {
            s.deinit();
        }
        self.state = try entry.classic_history_api_state.clone(self.allocator);
    }

    /// Update length and index values
    pub fn updateLengthAndIndex(self: *History, new_length: u32, new_index: u32) void {
        self.length_value = new_length;
        self.index_value = new_index;
    }

    /// Restore state for history step application
    ///
    /// HTML Standard §7.4.6:
    /// "To restore the history object state given a Document document and a
    /// session history entry entry:
    /// 1. Let state be StructuredDeserialize(entry's classic history API state, ...).
    /// 2. Set document's history object's state to state."
    pub fn restoreState(self: *History, entry: *const SessionHistoryEntry) !void {
        try self.updateFromEntry(entry);
    }
};

// ============================================================================
// URL Rewrite Validation - HTML Standard §7.2.4
// ============================================================================

/// Check if a document can have its URL rewritten to a target URL
///
/// HTML Standard:
/// "A Document document can have its URL rewritten to a URL targetURL if:
/// 1. Let documentURL be document's URL.
/// 2. If targetURL and documentURL differ in their scheme, username, password,
///    host, or port components, then return false.
/// 3. If targetURL's scheme is an HTTP(S) scheme, then return true.
/// 4. If targetURL's scheme is 'file', then:
///    a. If targetURL and documentURL differ in their path component, return false.
///    b. Return true.
/// 5. If targetURL and documentURL differ in their path component or query
///    components, then return false.
/// 6. Return true."
pub fn canRewriteUrl(document_url: []const u8, target_url: []const u8) bool {
    // Simplified implementation - a full implementation would parse URLs
    // and compare components according to the spec

    // For now, allow same-origin URLs and fragment-only changes
    if (std.mem.eql(u8, document_url, target_url)) {
        return true;
    }

    // Check if target is just a fragment change
    if (std.mem.indexOf(u8, target_url, "#")) |hash_idx| {
        const base = target_url[0..hash_idx];
        if (std.mem.eql(u8, document_url, base)) {
            return true;
        }

        // Check if document URL also has a fragment
        if (std.mem.indexOf(u8, document_url, "#")) |doc_hash_idx| {
            const doc_base = document_url[0..doc_hash_idx];
            if (std.mem.eql(u8, doc_base, base)) {
                return true;
            }
        }
    }

    // For HTTP(S), allow path/query/fragment changes
    if (std.mem.startsWith(u8, document_url, "http://") or
        std.mem.startsWith(u8, document_url, "https://"))
    {
        // Extract origin (scheme + host + port)
        const doc_origin = extractOrigin(document_url);
        const target_origin = extractOrigin(target_url);

        if (doc_origin != null and target_origin != null) {
            return std.mem.eql(u8, doc_origin.?, target_origin.?);
        }
    }

    return false;
}

/// Extract the origin from a URL (scheme + host + port)
fn extractOrigin(url: []const u8) ?[]const u8 {
    // Find the scheme separator
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;

    // Find the path start (first / after scheme://)
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;

    return url[0 .. scheme_end + 3 + path_start];
}

// ============================================================================
// History Handling Behavior - HTML Standard §7.4.2
// ============================================================================

/// History handling behavior for navigation
///
/// HTML Standard §7.4.2:
/// "A history handling behavior is a NavigationHistoryBehavior that is either
/// 'push' or 'replace', i.e., that has been resolved away from any initial 'auto' value."
pub const HistoryHandlingBehavior = enum {
    /// Add a new session history entry
    push,
    /// Replace the active session history entry
    replace,

    pub fn toString(self: HistoryHandlingBehavior) []const u8 {
        return switch (self) {
            .push => "push",
            .replace => "replace",
        };
    }
};

/// Navigation history behavior (before resolution)
pub const NavigationHistoryBehavior = enum {
    /// Will be resolved to push or replace
    auto,
    /// Add a new session history entry
    push,
    /// Replace the active session history entry
    replace,

    /// Resolve auto to a concrete behavior
    pub fn resolve(self: NavigationHistoryBehavior, is_replace: bool) HistoryHandlingBehavior {
        return switch (self) {
            .auto => if (is_replace) .replace else .push,
            .push => .push,
            .replace => .replace,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "History - init and deinit" {
    const allocator = std.testing.allocator;

    const history = try History.init(allocator);
    defer history.deinit();

    try std.testing.expectEqual(@as(u32, 1), try history.length());
    try std.testing.expectEqual(@as(u32, 0), history.index());
}

test "canRewriteUrl - same URL" {
    try std.testing.expect(canRewriteUrl(
        "https://example.com/page",
        "https://example.com/page",
    ));
}

test "canRewriteUrl - fragment change" {
    try std.testing.expect(canRewriteUrl(
        "https://example.com/page",
        "https://example.com/page#section",
    ));
}

test "canRewriteUrl - path change on HTTP" {
    try std.testing.expect(canRewriteUrl(
        "https://example.com/page1",
        "https://example.com/page2",
    ));
}

test "canRewriteUrl - cross-origin" {
    try std.testing.expect(!canRewriteUrl(
        "https://example.com/page",
        "https://other.com/page",
    ));
}

test "extractOrigin" {
    const origin = extractOrigin("https://example.com:8080/path/to/page");
    try std.testing.expect(origin != null);
    try std.testing.expectEqualStrings("https://example.com:8080/", origin.?);
}

test "HistoryHandlingBehavior - resolution" {
    try std.testing.expectEqual(
        HistoryHandlingBehavior.push,
        NavigationHistoryBehavior.auto.resolve(false),
    );
    try std.testing.expectEqual(
        HistoryHandlingBehavior.replace,
        NavigationHistoryBehavior.auto.resolve(true),
    );
    try std.testing.expectEqual(
        HistoryHandlingBehavior.push,
        NavigationHistoryBehavior.push.resolve(true),
    );
}

test "History - scrollRestoration default is auto" {
    const allocator = std.testing.allocator;

    const history = try History.init(allocator);
    defer history.deinit();

    // Without a navigable, should return default (auto)
    const mode = try history.scrollRestoration();
    try std.testing.expectEqual(ScrollRestorationMode.auto, mode);
}

test "History - scrollRestoration with navigable" {
    const allocator = std.testing.allocator;

    // Create a traversable navigable (includes navigable + entry)
    const navigable_module = @import("navigable.zig");
    const traversable = try navigable_module.TraversableNavigable.init(allocator, "https://example.com/");
    defer traversable.deinit();

    const history = try History.init(allocator);
    defer history.deinit();

    // Connect history to navigable
    history.setNavigable(traversable.navigable);

    // Default mode should be auto
    const mode = try history.scrollRestoration();
    try std.testing.expectEqual(ScrollRestorationMode.auto, mode);

    // Set to manual
    try history.setScrollRestoration(.manual);

    // Verify it changed
    const new_mode = try history.scrollRestoration();
    try std.testing.expectEqual(ScrollRestorationMode.manual, new_mode);

    // Set back to auto
    try history.setScrollRestoration(.auto);
    const final_mode = try history.scrollRestoration();
    try std.testing.expectEqual(ScrollRestorationMode.auto, final_mode);
}
