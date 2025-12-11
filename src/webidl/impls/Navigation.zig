//! Implementation for Navigation interface
//!
//! HTML Standard §7.2.6 - The Navigation API
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigation-api
//!
//! The Navigation API provides a modern, promise-based interface for
//! navigating and manipulating browser history, replacing the older
//! History API for many use cases.
//!
//! ## Key Concepts
//!
//! - **NavigationHistoryEntry**: Represents a single entry in the navigation history
//! - **NavigateEvent**: Fired before navigation, allows interception for SPA routing
//! - **NavigationResult**: Contains promises for navigation completion
//!
//! ## Integration with Session History
//!
//! The Navigation API wraps the underlying session history (§7.4.1),
//! providing a cleaner interface while maintaining spec compliance.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Navigation = interfaces.Navigation;

// HTML navigation infrastructure
const html_core = @import("html_core");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const SessionHistoryEntry = html_core.navigation.SessionHistoryEntry;
const SessionHistoryList = html_core.navigation.SessionHistoryList;
const TraversableNavigable = html_core.navigation.TraversableNavigable;
const Navigable = html_core.navigation.Navigable;
const NavigationType = html_core.navigation.events.NavigationType;

pub const State = Navigation.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SecurityError,
    SyntaxError,
    AbortError,
    OutOfMemory,
};

/// Internal state for Navigation implementation
/// Contains the navigation history entries and event handlers
pub const InternalState = struct {
    /// Allocator for this navigation's resources
    allocator: Allocator,

    /// Reference to the associated traversable navigable
    /// This provides access to the session history
    traversable: ?*TraversableNavigable = null,

    /// Cached NavigationHistoryEntry instances
    /// Lazily created wrappers around session history entries
    entry_cache: std.AutoHashMap(*SessionHistoryEntry, *runtime.Instance),

    /// The current entry index (relative to entries())
    current_index: i64 = -1,

    /// Event handlers (EventHandler is already optional)
    onnavigate: typedefs.EventHandler = null,
    onnavigatesuccess: typedefs.EventHandler = null,
    onnavigateerror: typedefs.EventHandler = null,
    oncurrententrychange: typedefs.EventHandler = null,

    /// Ongoing navigation state
    ongoing_navigation: ?OngoingNavigation = null,

    /// Suppress normal scroll restoration during navigation
    /// HTML Standard §7.2.6.4
    suppress_normal_scroll_restoration: bool = false,

    pub fn init(allocator: Allocator) InternalState {
        return .{
            .allocator = allocator,
            .entry_cache = std.AutoHashMap(*SessionHistoryEntry, *runtime.Instance).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Note: We don't own the traversable - it's owned by the Window
        self.entry_cache.deinit();
    }
};

/// Represents an ongoing navigation operation
const OngoingNavigation = struct {
    /// Navigation ID for tracking
    id: u64,
    /// The navigation type
    navigation_type: NavigationType,
    /// Whether navigation was intercepted
    intercepted: bool = false,
    /// Whether the committed promise was resolved
    committed_resolved: bool = false,
    /// Whether the finished promise was resolved
    finished_resolved: bool = false,
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize Navigation instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize Navigation instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Set the associated traversable navigable
/// Called by Window when setting up the Navigation object
pub fn setTraversable(instance: *runtime.Instance, traversable: *TraversableNavigable) void {
    const internal = getInternal(instance) orelse return;
    internal.traversable = traversable;
}

/// Get the session history list from the traversable
fn getSessionHistory(internal: *InternalState) ?*SessionHistoryList {
    const traversable = internal.traversable orelse return null;
    return &traversable.session_history;
}

/// Get the current session history entry
fn getCurrentEntry(internal: *InternalState) ?*SessionHistoryEntry {
    const traversable = internal.traversable orelse return null;
    const navigable = traversable.navigable;
    return navigable.active_session_history_entry;
}

/// Get the index of an entry in the session history
fn getEntryIndex(internal: *InternalState, entry: *SessionHistoryEntry) ?usize {
    const history = getSessionHistory(internal) orelse return null;
    for (history.entries.items, 0..) |e, i| {
        if (e == entry) return i;
    }
    return null;
}

/// Check if we can navigate back
fn canNavigateBack(internal: *InternalState) bool {
    const current = getCurrentEntry(internal) orelse return false;
    const idx = getEntryIndex(internal, current) orelse return false;
    return idx > 0;
}

/// Check if we can navigate forward
fn canNavigateForward(internal: *InternalState) bool {
    const current = getCurrentEntry(internal) orelse return false;
    const idx = getEntryIndex(internal, current) orelse return false;
    const history = getSessionHistory(internal) orelse return false;
    return idx < history.entries.items.len - 1;
}

// ============================================================================
// Property Getters
// ============================================================================

/// Getter for currentEntry
/// HTML Standard §7.2.6.2: Returns the current NavigationHistoryEntry
pub fn get_currentEntry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const entry = getCurrentEntry(internal) orelse return null;

    // Check if we have a cached wrapper
    if (internal.entry_cache.get(entry)) |cached| {
        return cached;
    }

    // Create a new NavigationHistoryEntry wrapper
    // For now, return null - full implementation would create the wrapper
    return null;
}

/// Getter for transition
/// HTML Standard §7.2.6.2: Returns the ongoing NavigationTransition, or null
pub fn get_transition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    // Return null if no ongoing navigation
    if (internal.ongoing_navigation == null) return null;
    // Full implementation would return a NavigationTransition object
    return null;
}

/// Getter for activation
/// HTML Standard §7.2.6.2: Returns NavigationActivation for page load, or null
pub fn get_activation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // NavigationActivation is set during initial page load
    // For now, return null
    return null;
}

/// Getter for canGoBack
/// HTML Standard §7.2.6.2: Returns true if there is a previous entry
pub fn get_canGoBack(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return canNavigateBack(internal);
}

/// Getter for canGoForward
/// HTML Standard §7.2.6.2: Returns true if there is a next entry
pub fn get_canGoForward(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return canNavigateForward(internal);
}

// ============================================================================
// Event Handler Getters/Setters
// ============================================================================

/// Getter for onnavigate
pub fn get_onnavigate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.onnavigate;
}

/// Getter for onnavigatesuccess
pub fn get_onnavigatesuccess(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.onnavigatesuccess;
}

/// Getter for onnavigateerror
pub fn get_onnavigateerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.onnavigateerror;
}

/// Getter for oncurrententrychange
pub fn get_oncurrententrychange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.oncurrententrychange;
}

/// Setter for onnavigate
pub fn set_onnavigate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onnavigate = value;
}

/// Setter for onnavigatesuccess
pub fn set_onnavigatesuccess(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onnavigatesuccess = value;
}

/// Setter for onnavigateerror
pub fn set_onnavigateerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onnavigateerror = value;
}

/// Setter for oncurrententrychange
pub fn set_oncurrententrychange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.oncurrententrychange = value;
}

// ============================================================================
// Navigation Operations
// ============================================================================

/// Operation: entries()
/// HTML Standard §7.2.6.3: Returns a frozen array of NavigationHistoryEntry objects
pub fn call_entries(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = getSessionHistory(internal) orelse return error.InvalidStateError;

    // TODO: Return proper frozen array of NavigationHistoryEntry when V8 array creation is available
    // For now, return undefined - spec requires a frozen array
    return runtime.JSValue.jsUndefined;
}

/// Operation: navigate(url, options)
/// HTML Standard §7.2.6.4: Navigate to a new URL
pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString, options: webidl.Opt(dictionaries.NavigationNavigateOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const traversable = internal.traversable orelse return error.InvalidStateError;

    // Get the URL string - USVString is just []const u8
    const url_str = url;

    // Parse navigation options (webidl.Opt wraps with was_passed + value)
    if (options.was_passed) {
        const opts = options.value;
        _ = opts;
        // Would use opts.state, opts.history, opts.base.info
    }

    // Create a new session history entry for the navigation
    const entry = try SessionHistoryEntry.init(internal.allocator, url_str);
    errdefer entry.deinit();

    // Append to session history
    try traversable.appendEntry(entry);

    // Mark as ongoing navigation
    internal.ongoing_navigation = OngoingNavigation{
        .id = entry.step.getValue() orelse 0,
        .navigation_type = .push,
        .intercepted = false,
    };

    // Return a NavigationResult with committed/finished promises
    // In a full implementation, these would be actual promises
    return dictionaries.NavigationResult{
        .committed = null, // Would be a Promise
        .finished = null, // Would be a Promise
    };
}

/// Operation: reload(options)
/// HTML Standard §7.2.6.4: Reload the current entry
pub fn call_reload(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationReloadOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const traversable = internal.traversable orelse return error.InvalidStateError;

    _ = options;

    // Mark the current entry for reload
    if (getCurrentEntry(internal)) |entry| {
        entry.document_state.reload_pending = true;
    }

    // Trigger reload via traversable
    // In full implementation, this would initiate a reload navigation
    _ = traversable;

    internal.ongoing_navigation = OngoingNavigation{
        .id = 0,
        .navigation_type = .reload,
        .intercepted = false,
    };

    return dictionaries.NavigationResult{
        .committed = null,
        .finished = null,
    };
}

/// Operation: traverseTo(key, options)
/// HTML Standard §7.2.6.4: Navigate to a specific entry by key
pub fn call_traverseTo(instance: *runtime.Instance, key: runtime.DOMString, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const traversable = internal.traversable orelse return error.InvalidStateError;
    const history = getSessionHistory(internal) orelse return error.InvalidStateError;

    _ = options;

    // Find entry by key (navigation API key is a UUID)
    // DOMString is a union, use asSlice() to get the string value
    const key_str = key.asSlice();

    const target_entry = history.getEntryByKey(key_str) orelse return error.InvalidStateError;
    const target_step = target_entry.step.getValue() orelse return error.InvalidStateError;

    // Calculate delta and traverse
    const current_step = traversable.currentStep();
    const delta: i64 = @as(i64, @intCast(target_step)) - @as(i64, @intCast(current_step));

    try traversable.traverseByDelta(delta, null, .none);

    internal.ongoing_navigation = OngoingNavigation{
        .id = target_step,
        .navigation_type = .traverse,
        .intercepted = false,
    };

    return dictionaries.NavigationResult{
        .committed = null,
        .finished = null,
    };
}

/// Operation: back(options)
/// HTML Standard §7.2.6.4: Navigate back one entry
pub fn call_back(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const traversable = internal.traversable orelse return error.InvalidStateError;

    _ = options;

    // Check if we can go back
    if (!canNavigateBack(internal)) {
        return error.InvalidStateError;
    }

    // Traverse back by -1
    try traversable.traverseByDelta(-1, null, .none);

    internal.ongoing_navigation = OngoingNavigation{
        .id = traversable.currentStep(),
        .navigation_type = .traverse,
        .intercepted = false,
    };

    return dictionaries.NavigationResult{
        .committed = null,
        .finished = null,
    };
}

/// Operation: forward(options)
/// HTML Standard §7.2.6.4: Navigate forward one entry
pub fn call_forward(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const traversable = internal.traversable orelse return error.InvalidStateError;

    _ = options;

    // Check if we can go forward
    if (!canNavigateForward(internal)) {
        return error.InvalidStateError;
    }

    // Traverse forward by +1
    try traversable.traverseByDelta(1, null, .none);

    internal.ongoing_navigation = OngoingNavigation{
        .id = traversable.currentStep(),
        .navigation_type = .traverse,
        .intercepted = false,
    };

    return dictionaries.NavigationResult{
        .committed = null,
        .finished = null,
    };
}

/// Operation: updateCurrentEntry(options)
/// HTML Standard §7.2.6.4: Update the state of the current entry
pub fn call_updateCurrentEntry(instance: *runtime.Instance, options: dictionaries.NavigationUpdateCurrentEntryOptions) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const entry = getCurrentEntry(internal) orelse return error.InvalidStateError;

    // Update the navigation API state
    // The state is passed as serialized data (required field, not optional)
    // In full implementation, this would deserialize and store the state
    // For now, we just acknowledge the state pointer
    _ = options.state;
    _ = entry;
    // entry.setNavigationApiState(...)

    // Fire currententrychange event
    // In full implementation, this would dispatch the event
}
