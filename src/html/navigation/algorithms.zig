//! Navigation Algorithms - HTML Standard §7.4
//!
//! This module implements the core navigation algorithms from the WHATWG HTML Standard:
//! - navigate: Full page navigation
//! - navigate to a fragment: Same-document fragment navigation
//! - traverse the history by a delta: History traversal
//! - URL and history update steps: pushState/replaceState handling
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html
//!
//! ## Key Algorithms
//!
//! - **Navigate**: Entry point for all navigations
//! - **Navigate to Fragment**: Same-document fragment-only navigation
//! - **History Step Apply**: Apply changes when traversing history
//! - **URL and History Update Steps**: For pushState/replaceState

const std = @import("std");
const Allocator = std.mem.Allocator;

const session_history = @import("session_history.zig");
const SessionHistoryEntry = session_history.SessionHistoryEntry;
const SessionHistoryList = session_history.SessionHistoryList;
const DocumentState = session_history.DocumentState;
const SerializedState = session_history.SerializedState;
const ScrollRestorationMode = session_history.ScrollRestorationMode;

const navigable_mod = @import("navigable.zig");
const Navigable = navigable_mod.Navigable;
const TraversableNavigable = navigable_mod.TraversableNavigable;
const TraversalTask = navigable_mod.TraversalTask;
const UserInvolvement = navigable_mod.UserInvolvement;

const events = @import("events.zig");
const PopStateEvent = events.PopStateEvent;
const HashChangeEvent = events.HashChangeEvent;
const PageTransitionEvent = events.PageTransitionEvent;
const BeforeUnloadEvent = events.BeforeUnloadEvent;
const NavigationType = events.NavigationType;

const hist = @import("history.zig");
const HistoryHandlingBehavior = hist.HistoryHandlingBehavior;
const NavigationHistoryBehavior = hist.NavigationHistoryBehavior;
const canRewriteUrl = hist.canRewriteUrl;

// ============================================================================
// Navigation Errors
// ============================================================================

pub const NavigationError = error{
    /// Navigation was aborted
    Aborted,
    /// Security check failed
    SecurityError,
    /// Invalid URL
    InvalidUrl,
    /// Network error during fetch
    NetworkError,
    /// Document is not fully active
    NotFullyActive,
    /// Target navigable not found
    NavigableNotFound,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// Source Snapshot Params - HTML Standard §7.4.2
// ============================================================================

/// Source snapshot params capture the state of the source document at navigation time
///
/// HTML Standard §7.4.2:
/// "Source snapshot params is a struct with the following items:
/// - has transient activation (boolean)
/// - sandboxing flags (sandboxing flag set)
/// - allows downloading (boolean)
/// - fetch client (environment settings object or null)
/// - source policy container (policy container)"
pub const SourceSnapshotParams = struct {
    /// Whether the source document had transient activation
    has_transient_activation: bool,
    /// Whether downloading is allowed
    allows_downloading: bool,
    /// The source document's origin (simplified from full policy container)
    source_origin: ?[]const u8,
    /// The initiator type
    initiator_type: InitiatorType,

    pub const InitiatorType = enum {
        /// User-initiated (link click, form submission)
        user,
        /// Script-initiated (window.location, etc.)
        script,
        /// Parser-initiated (meta refresh, etc.)
        parser,
        /// Browser UI (address bar, bookmarks)
        browser_ui,
    };

    pub fn init() SourceSnapshotParams {
        return .{
            .has_transient_activation = false,
            .allows_downloading = true,
            .source_origin = null,
            .initiator_type = .script,
        };
    }
};

// ============================================================================
// Target Snapshot Params - HTML Standard §7.4.2
// ============================================================================

/// Target snapshot params capture the state of the target navigable at navigation time
///
/// HTML Standard §7.4.2:
/// "Target snapshot params is a struct with the following items:
/// - sandboxing flags (sandboxing flag set)"
pub const TargetSnapshotParams = struct {
    /// The target navigable's sandboxing flags (simplified)
    is_sandboxed: bool,
    /// Whether scripts are allowed
    allows_scripts: bool,

    pub fn init() TargetSnapshotParams {
        return .{
            .is_sandboxed = false,
            .allows_scripts = true,
        };
    }
};

// ============================================================================
// Navigation Params - HTML Standard §7.4.2
// ============================================================================

/// Navigation params struct used during navigation
///
/// HTML Standard §7.4.2:
/// "Navigation params is a struct with many items..."
pub const NavigationParams = struct {
    allocator: Allocator,

    /// Navigation ID (unique per navigation)
    id: u64,

    /// Navigation type
    navigation_type: NavigationType,

    /// The request (simplified - just URL)
    request_url: []const u8,

    /// Response (opaque - will be set during fetch)
    response: ?*anyopaque,

    /// The final URL after redirects
    final_url: ?[]const u8,

    /// Origin (tuple or opaque origin as string)
    origin: ?[]const u8,

    /// Policy container (simplified)
    policy_container: ?*anyopaque,

    /// The navigable being navigated
    navigable: *Navigable,

    /// History handling
    history_handling: HistoryHandlingBehavior,

    /// Whether this is a reload
    reload: bool,

    /// User involvement
    user_involvement: UserInvolvement,

    /// COOP enforcement result (simplified)
    coop_enforcement_result: ?CoopEnforcementResult,

    /// Fetch controller (for aborting)
    fetch_controller: ?*anyopaque,

    /// Whether navigation was aborted
    aborted: bool,

    /// Next ID generator
    var next_id: u64 = 1;

    pub fn init(allocator: Allocator, navigable: *Navigable, url: []const u8) !*NavigationParams {
        const params = try allocator.create(NavigationParams);
        params.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_id, .Add, 1, .monotonic),
            .navigation_type = .push,
            .request_url = try allocator.dupe(u8, url),
            .response = null,
            .final_url = null,
            .origin = null,
            .policy_container = null,
            .navigable = navigable,
            .history_handling = .push,
            .reload = false,
            .user_involvement = .none,
            .coop_enforcement_result = null,
            .fetch_controller = null,
            .aborted = false,
        };
        return params;
    }

    pub fn deinit(self: *NavigationParams) void {
        self.allocator.free(self.request_url);
        if (self.final_url) |url| {
            self.allocator.free(url);
        }
        if (self.origin) |origin| {
            self.allocator.free(origin);
        }
        self.allocator.destroy(self);
    }

    /// Abort this navigation
    pub fn abort(self: *NavigationParams) void {
        self.aborted = true;
        // In a real implementation, this would also abort the fetch
    }

    /// Check if navigation can proceed
    pub fn canProceed(self: *const NavigationParams) bool {
        return !self.aborted and self.navigable.state != .destroyed;
    }
};

/// COOP enforcement result (simplified)
pub const CoopEnforcementResult = struct {
    /// Whether a browsing context group switch is needed
    needs_browsing_context_group_switch: bool,
    /// The origin to use
    origin: ?[]const u8,
};

// ============================================================================
// Navigate Algorithm - HTML Standard §7.4.3
// ============================================================================

/// Navigate to a URL
///
/// HTML Standard §7.4.3:
/// "To navigate a navigable navigable to a URL url using a Document sourceDocument,
/// with an optional POST resource, string, or null documentResource (default null),
/// an optional response-or-null response (default null), an optional boolean
/// exceptionsEnabled (default false), an optional NavigationHistoryBehavior
/// historyHandling (default 'auto'), an optional string navigationType (default 'other'),
/// an optional string cspNavigationType (default 'other'), and an optional
/// referrer policy referrerPolicy (default the empty string)..."
pub fn navigate(
    allocator: Allocator,
    navigable: *Navigable,
    url: []const u8,
    source_document: ?*anyopaque,
    options: NavigateOptions,
) NavigationError!*NavigationParams {
    // 1. Let sourceSnapshotParams be the result of snapshotting source snapshot params
    var source_snapshot = SourceSnapshotParams.init();
    if (source_document != null) {
        source_snapshot.initiator_type = .script;
    }

    // 2. Let initiatorOriginSnapshot be sourceDocument's origin
    const initiator_origin = options.initiator_origin;

    // 3. If navigable is not navigable's active document's node navigable, return
    // (Simplified check - in real implementation, verify document association)

    // 4. Let targetSnapshotParams be the result of snapshotting target snapshot params
    const target_snapshot = TargetSnapshotParams.init();

    // 5. Assert: navigable's active session history entry is not null
    if (navigable.active_session_history_entry == null) {
        return NavigationError.NotFullyActive;
    }

    // Create navigation params
    const params = try NavigationParams.init(allocator, navigable, url);
    errdefer params.deinit();

    params.history_handling = options.history_handling.resolve(false);
    params.navigation_type = options.navigation_type;
    params.user_involvement = options.user_involvement;

    if (initiator_origin) |origin| {
        params.origin = try allocator.dupe(u8, origin);
    }

    // 6. Check if this is a fragment navigation
    if (try isFragmentNavigation(url, navigable)) {
        // Handle fragment navigation
        try navigateToFragment(allocator, navigable, url, params.history_handling);
        return params;
    }

    // 7-onwards: Full navigation (fetch, create document, etc.)
    // In a real implementation, this would:
    // - Create a navigation request using source_snapshot
    // - Check target_snapshot for sandboxing flags
    // - Fetch the resource
    // - Process the response
    // - Create a new document
    // - Update session history
    //
    // Store snapshots in params for later use by the fetch/document creation
    // (In a complete implementation, these would be fields on NavigationParams)
    params.user_involvement = if (source_snapshot.has_transient_activation) .activation else params.user_involvement;

    // Check sandboxing from target snapshot
    if (target_snapshot.is_sandboxed and !target_snapshot.allows_scripts) {
        // Would apply sandboxing restrictions to the created document
    }

    return params;
}

/// Options for navigate()
pub const NavigateOptions = struct {
    /// Document resource (for POST submissions or srcdoc)
    document_resource: ?*anyopaque = null,
    /// Response (if already fetched)
    response: ?*anyopaque = null,
    /// Whether to throw exceptions
    exceptions_enabled: bool = false,
    /// History handling behavior
    history_handling: NavigationHistoryBehavior = .auto,
    /// Navigation type
    navigation_type: NavigationType = .push,
    /// CSP navigation type
    csp_navigation_type: []const u8 = "other",
    /// User involvement
    user_involvement: UserInvolvement = .none,
    /// Initiator origin
    initiator_origin: ?[]const u8 = null,
};

// ============================================================================
// Fragment Navigation - HTML Standard §7.4.3.1
// ============================================================================

/// Check if navigation is a fragment navigation (same-document)
///
/// HTML Standard §7.4.3.1:
/// "A navigation is a fragment navigation if all of the following are true:
/// - The request URL has a fragment
/// - The request URL equals the current URL with only fragment different
/// - The request URL's origin is same origin with the current document's origin"
fn isFragmentNavigation(url: []const u8, navigable: *const Navigable) !bool {
    // Must have a fragment
    const has_fragment = std.mem.indexOf(u8, url, "#") != null;
    if (!has_fragment) return false;

    // Get current URL from active entry
    const entry = navigable.active_session_history_entry orelse return false;
    const current_url = entry.url;

    // Compare URLs without fragments
    const url_base = if (std.mem.indexOf(u8, url, "#")) |idx| url[0..idx] else url;
    const current_base = if (std.mem.indexOf(u8, current_url, "#")) |idx| current_url[0..idx] else current_url;

    return std.mem.eql(u8, url_base, current_base);
}

/// Navigate to a fragment (same-document navigation)
///
/// HTML Standard §7.4.3.1:
/// "To navigate to a fragment given a navigable navigable, a URL url,
/// and a history handling behavior historyHandling..."
pub fn navigateToFragment(
    allocator: Allocator,
    navigable: *Navigable,
    url: []const u8,
    history_handling: HistoryHandlingBehavior,
) !void {
    // 1. Let destinationNavigationID be a new navigation ID
    // (Used for tracking - omitted in simplified implementation)

    // 2. If historyHandling is "auto", then set historyHandling to "push"
    const actual_handling = history_handling;

    // 3. Let document be navigable's active document
    const entry = navigable.active_session_history_entry orelse return;
    const old_url = entry.url;

    // 4. If historyHandling is "push", then...
    if (actual_handling == .push) {
        // Get the traversable
        const traversable = navigable.traversableNavigable() orelse return;

        // Create a new session history entry
        const new_entry = try SessionHistoryEntry.init(allocator, url);
        errdefer new_entry.deinit();

        // Copy document state from current entry
        new_entry.document_state.document = entry.document_state.document;

        // Copy state
        new_entry.classic_history_api_state = try entry.classic_history_api_state.clone(allocator);
        new_entry.scroll_restoration_mode = entry.scroll_restoration_mode;

        // Append to session history
        try traversable.appendEntry(new_entry);
    } else {
        // Replace: just update the URL
        try entry.setUrl(url);
    }

    // 5. Scroll to the fragment identifier
    // (In real implementation, this would scroll the document)

    // 6. Fire a hashchange event if fragment changed
    const old_fragment = std.mem.indexOf(u8, old_url, "#");
    const new_fragment = std.mem.indexOf(u8, url, "#");

    const fragments_differ = blk: {
        if (old_fragment == null and new_fragment == null) break :blk false;
        if (old_fragment == null or new_fragment == null) break :blk true;
        break :blk !std.mem.eql(u8, old_url[old_fragment.?..], url[new_fragment.?..]);
    };

    if (fragments_differ) {
        // Would fire hashchange event here
        // The event dispatcher would be called with old_url and url
    }
}

// ============================================================================
// URL and History Update Steps - HTML Standard §7.4.3.2
// ============================================================================

/// URL and history update steps for pushState/replaceState
///
/// HTML Standard §7.4.3.2:
/// "The URL and history update steps given a Document document, a URL newURL,
/// serialized state newSerializedState, and history handling behavior
/// historyHandling are..."
pub fn urlAndHistoryUpdateSteps(
    allocator: Allocator,
    navigable: *Navigable,
    new_url: []const u8,
    serialized_state: ?SerializedState,
    history_handling: HistoryHandlingBehavior,
) !void {
    // 1. Let activeEntry be navigable's active session history entry
    const active_entry = navigable.active_session_history_entry orelse return;

    // 2. Let newEntry be a new session history entry, with
    //    - URL: newURL
    //    - document state: activeEntry's document state
    //    - classic history API state: newSerializedState

    if (history_handling == .push) {
        // Get the traversable
        const traversable = navigable.traversableNavigable() orelse return;

        // Create new entry
        const new_entry = try SessionHistoryEntry.init(allocator, new_url);
        errdefer new_entry.deinit();

        // Copy document state reference
        new_entry.document_state.document = active_entry.document_state.document;

        // Set the state
        if (serialized_state) |state| {
            new_entry.setClassicHistoryApiState(try state.clone(allocator));
        }

        // Append to history
        try traversable.appendEntry(new_entry);
    } else {
        // Replace: update the current entry
        try active_entry.setUrl(new_url);

        if (serialized_state) |state| {
            active_entry.setClassicHistoryApiState(try state.clone(allocator));
        }
    }
}

// ============================================================================
// History Traversal - HTML Standard §7.4.5
// ============================================================================

/// Apply the history step
///
/// HTML Standard §7.4.6:
/// "To apply the history step step to a traversable navigable traversable..."
pub fn applyHistoryStep(
    traversable: *TraversableNavigable,
    step: u64,
    source_document: ?*anyopaque,
    initiator_to_check: ?*Navigable,
    user_involvement: UserInvolvement,
    allocator: Allocator,
) !void {
    _ = source_document;
    _ = initiator_to_check;

    // 1. Assert: This is running within traversable's session history traversal queue
    // (Simplified - we don't have actual parallel queues)

    // 2. Let targetEntry be the entry in traversable's session history entries with step equal to step
    const target_entry = traversable.session_history.getEntryByStep(step) orelse return;

    // 3. Let currentEntry be the active session history entry
    const current_entry = traversable.navigable.active_session_history_entry orelse return;

    // 4. If targetEntry is currentEntry, return
    if (target_entry == current_entry) return;

    // 5. Let changingNavigables be the result of getting all navigables that need updating
    // (Simplified - just handle the main navigable)

    // 6-7. Check security and determine navigation type
    const is_same_document = blk: {
        // Same document if same document object
        if (target_entry.document_state.document) |target_doc| {
            if (current_entry.document_state.document) |current_doc| {
                break :blk target_doc == current_doc;
            }
        }
        break :blk false;
    };

    // 8. Update session history entries
    traversable.session_history.current_step = step;
    traversable.navigable.setActiveEntry(target_entry);
    traversable.navigable.setCurrentEntry(target_entry);

    // 9. Fire events
    if (is_same_document) {
        // Fire popstate
        const state = target_entry.classic_history_api_state;
        const event = try PopStateEvent.init(allocator, try state.clone(allocator), false);
        defer event.deinit();
        // Would dispatch event to document here
    }

    // 10. Handle scroll restoration
    if (target_entry.scroll_restoration_mode == .auto and user_involvement != .none) {
        // Would restore scroll position here using target_entry.scroll_position_data
        // In a real implementation, this would scroll the viewport
    }
}

/// Traverse the history by a delta
///
/// HTML Standard §7.4.5:
/// "To traverse the history by a delta given a traversable navigable traversable,
/// an integer delta, and an optional source document..."
pub fn traverseHistoryByDelta(
    traversable: *TraversableNavigable,
    delta: i64,
    source_document: ?*anyopaque,
) !void {
    try traversable.traverseByDelta(delta, source_document, .none);
}

// ============================================================================
// Document Loading Helpers
// ============================================================================

/// Check if a navigation should be intercepted
///
/// This is called during navigation to check if the navigation should be
/// handled by the Navigation API's intercept() method.
pub fn shouldInterceptNavigation(
    navigable: *const Navigable,
    url: []const u8,
    navigation_type: NavigationType,
) bool {
    // In a real implementation, this would check:
    // 1. If the Navigation API's navigate event was intercepted
    // 2. If the handler called event.intercept()
    // 3. If the navigation is same-document eligible

    _ = navigable;
    _ = url;
    _ = navigation_type;

    return false;
}

/// Abort a document's navigation
pub fn abortDocumentNavigation(navigable: *Navigable) void {
    // In a real implementation, this would:
    // 1. Cancel ongoing fetches
    // 2. Abort the document's parser
    // 3. Fire abort events
    _ = navigable;
}

// ============================================================================
// Unload Handling - HTML Standard §7.4.7
// ============================================================================

/// Run the unload steps for a document
///
/// HTML Standard §7.4.7.2:
/// "To unload a Document document..."
pub fn unloadDocument(
    allocator: Allocator,
    navigable: *Navigable,
    new_entry: ?*SessionHistoryEntry,
) !bool {
    // 1. Assert: This is running as part of a task queued on the main event loop
    // (Simplified - we don't have the full event loop)

    // 2. Let unloadTimingInfo be a new document unload timing info
    // (Timing info omitted for simplicity)

    // 3. If document's page showing flag is true...
    // Fire pagehide event
    const pagehide_event = try PageTransitionEvent.init(allocator, "pagehide", false);
    defer pagehide_event.deinit();
    // Would dispatch event here

    // 4. Update document's page showing flag
    // (Would set to false)

    // 5. Fire unload event
    // (Would fire unload event here)

    // 6. Unload all nested navigables
    for (navigable.children.items) |child| {
        _ = try unloadDocument(allocator, child, null);
    }

    _ = new_entry;

    return true; // Unload succeeded
}

/// Prompt to unload (beforeunload handling)
///
/// HTML Standard §7.4.7.1:
/// "To check if unloading is canceled given a list of navigables navigablesToCheck..."
pub fn promptToUnload(
    allocator: Allocator,
    navigable: *Navigable,
) !bool {
    // 1. Let document be navigable's active document
    _ = navigable.activeDocument() orelse return true;

    // 2. Fire a beforeunload event
    const event = try BeforeUnloadEvent.init(allocator);
    defer event.deinit();
    // Would dispatch event here

    // 3. Check if canceled
    if (event.shouldShowPrompt()) {
        // In a real implementation, this would show a confirmation dialog
        // For now, always allow unload
        return true;
    }

    return true;
}

// ============================================================================
// Tests
// ============================================================================

test "SourceSnapshotParams - init" {
    const params = SourceSnapshotParams.init();
    try std.testing.expect(!params.has_transient_activation);
    try std.testing.expect(params.allows_downloading);
}

test "NavigationParams - init and deinit" {
    const allocator = std.testing.allocator;

    const navigable = try Navigable.init(allocator);
    defer navigable.deinit();

    const params = try NavigationParams.init(allocator, navigable, "https://example.com/");
    defer params.deinit();

    try std.testing.expectEqualStrings("https://example.com/", params.request_url);
    try std.testing.expect(!params.aborted);
}

test "NavigationParams - abort" {
    const allocator = std.testing.allocator;

    const navigable = try Navigable.init(allocator);
    defer navigable.deinit();

    const params = try NavigationParams.init(allocator, navigable, "https://example.com/");
    defer params.deinit();

    try std.testing.expect(params.canProceed());

    params.abort();

    try std.testing.expect(!params.canProceed());
    try std.testing.expect(params.aborted);
}

test "isFragmentNavigation - same document" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/page");
    defer traversable.deinit();

    // Same document with different fragment
    const is_fragment = try isFragmentNavigation("https://example.com/page#section", traversable.navigable);
    try std.testing.expect(is_fragment);
}

test "isFragmentNavigation - different document" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/page1");
    defer traversable.deinit();

    // Different path - not fragment navigation
    const is_fragment = try isFragmentNavigation("https://example.com/page2#section", traversable.navigable);
    try std.testing.expect(!is_fragment);
}

test "urlAndHistoryUpdateSteps - push" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/page1");
    defer traversable.deinit();

    try urlAndHistoryUpdateSteps(
        allocator,
        traversable.navigable,
        "https://example.com/page2",
        null,
        .push,
    );

    try std.testing.expectEqual(@as(usize, 2), traversable.jointSessionHistoryLength());
    try std.testing.expectEqual(@as(u64, 1), traversable.currentStep());
}

test "urlAndHistoryUpdateSteps - replace" {
    const allocator = std.testing.allocator;

    const traversable = try TraversableNavigable.init(allocator, "https://example.com/page1");
    defer traversable.deinit();

    try urlAndHistoryUpdateSteps(
        allocator,
        traversable.navigable,
        "https://example.com/page2",
        null,
        .replace,
    );

    // Should still be 1 entry (replaced, not added)
    try std.testing.expectEqual(@as(usize, 1), traversable.jointSessionHistoryLength());
    try std.testing.expectEqual(@as(u64, 0), traversable.currentStep());

    // URL should be updated
    const entry = traversable.session_history.getEntryByStep(0).?;
    try std.testing.expectEqualStrings("https://example.com/page2", entry.url);
}
