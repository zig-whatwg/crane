//! Implementation for NavigateEvent interface
//!
//! HTML Standard §7.2.6.5 - The NavigateEvent interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigateevent
//!
//! NavigateEvent is fired at the Navigation object when a navigation is about
//! to occur. The event allows interception for SPA-style routing via intercept().
//!
//! ## Key Features
//!
//! - **intercept()**: Converts navigation to same-document, runs handler
//! - **scroll()**: Manually perform scroll restoration after intercept
//! - **signal**: AbortSignal for tracking navigation lifecycle
//!
//! ## Event Flow
//!
//! 1. Navigation starts (link click, API call, etc.)
//! 2. NavigateEvent is created and fired
//! 3. Handlers may call intercept() to take over navigation
//! 4. If intercepted, handler promise is awaited
//! 5. On success: navigatesuccess event; on failure: navigateerror event

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const NavigateEvent = interfaces.NavigateEvent;

pub const State = NavigateEvent.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SecurityError,
};

/// Internal state for NavigateEvent implementation
pub const InternalState = struct {
    /// Allocator for this event's resources
    allocator: Allocator,

    /// The type of navigation
    navigation_type: enums.NavigationType = ._push_,

    /// The destination entry (NavigationDestination)
    destination: ?*runtime.Instance = null,

    /// Whether this navigation can be intercepted
    /// HTML Standard §7.2.6.5: Only same-origin, non-cross-document navigations can be intercepted
    can_intercept: bool = false,

    /// Whether this navigation was initiated by user action
    user_initiated: bool = false,

    /// Whether this is a hash change (fragment-only navigation)
    hash_change: bool = false,

    /// The AbortSignal for this navigation
    signal: ?*runtime.Instance = null,

    /// FormData for form submissions, null otherwise
    form_data: ?*runtime.Instance = null,

    /// Download request filename if navigation is a download
    download_request: ?[]const u8 = null,

    /// User-provided info passed to navigate() call
    info: ?*const anyopaque = null,

    /// Whether the UA is performing a visual transition
    has_ua_visual_transition: bool = false,

    /// The element that initiated the navigation (e.g., clicked link)
    source_element: ?*runtime.Instance = null,

    // ========================================================================
    // Intercept State
    // ========================================================================

    /// Whether intercept() was called
    intercepted: bool = false,

    /// The intercept handler (callback to run)
    intercept_handler: ?*const anyopaque = null,

    /// Focus reset behavior after intercept
    focus_reset: FocusResetMode = .after_transition,

    /// Scroll behavior after intercept
    scroll_behavior: ScrollMode = .after_transition,

    /// Whether scroll() was manually called
    scroll_called: bool = false,

    /// Whether the dispatch phase is complete
    dispatch_complete: bool = false,

    pub const FocusResetMode = enum {
        after_transition,
        manual,
    };

    pub const ScrollMode = enum {
        after_transition,
        manual,
    };

    pub fn init(allocator: Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.download_request) |req| {
            self.allocator.free(req);
        }
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize NavigateEvent instance
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

/// Deinitialize NavigateEvent instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// HTML Standard §7.2.6.5: NavigateEvent constructor
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: dictionaries.NavigateEventInit) !*runtime.Instance {
    const instance = try init(allocator, State, &NavigateEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Initialize from event init dictionary
    _ = @"type"; // Event type (always "navigate")

    // Set navigation type from init dict
    if (eventInitDict.navigationType) |nav_type_ptr| {
        // In full implementation, would convert from anyopaque to NavigationType
        _ = nav_type_ptr;
    }

    // Set destination (required)
    // Note: destination is *const anyopaque in the dict, would need conversion
    _ = eventInitDict.destination;

    // Set optional boolean flags
    internal.can_intercept = eventInitDict.canIntercept orelse false;
    internal.user_initiated = eventInitDict.userInitiated orelse false;
    internal.hash_change = eventInitDict.hashChange orelse false;
    internal.has_ua_visual_transition = eventInitDict.hasUAVisualTransition orelse false;

    // Set signal (required)
    // Note: signal is *const anyopaque in the dict
    _ = eventInitDict.signal;

    // Set optional properties
    if (eventInitDict.formData) |form_data_ptr| {
        _ = form_data_ptr;
        // internal.form_data = ...
    }

    if (eventInitDict.downloadRequest) |download| {
        internal.download_request = try allocator.dupe(u8, download.asSlice());
    }

    internal.info = eventInitDict.info;

    if (eventInitDict.sourceElement) |source_ptr| {
        _ = source_ptr;
        // internal.source_element = ...
    }

    return instance;
}

// ============================================================================
// Property Getters
// ============================================================================

/// Getter for navigationType
/// HTML Standard §7.2.6.5: Returns the type of navigation
pub fn get_navigationType(instance: *runtime.Instance) anyerror!enums.NavigationType {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.navigation_type;
}

/// Getter for destination
/// HTML Standard §7.2.6.5: Returns the NavigationDestination
pub fn get_destination(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.destination orelse error.InvalidStateError;
}

/// Getter for canIntercept
/// HTML Standard §7.2.6.5: Returns true if intercept() can be called
pub fn get_canIntercept(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.can_intercept;
}

/// Getter for userInitiated
/// HTML Standard §7.2.6.5: Returns true if navigation was user-initiated
pub fn get_userInitiated(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.user_initiated;
}

/// Getter for hashChange
/// HTML Standard §7.2.6.5: Returns true if this is a fragment navigation
pub fn get_hashChange(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.hash_change;
}

/// Getter for signal
/// HTML Standard §7.2.6.5: Returns the AbortSignal for this navigation
pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.signal orelse error.InvalidStateError;
}

/// Getter for formData
/// HTML Standard §7.2.6.5: Returns FormData for form submissions
pub fn get_formData(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.form_data;
}

/// Getter for downloadRequest
/// HTML Standard §7.2.6.5: Returns download filename or null
pub fn get_downloadRequest(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (internal.download_request) |req| {
        return runtime.DOMString.initInterned(req);
    }
    return null;
}

/// Getter for info
/// HTML Standard §7.2.6.5: Returns user-provided info from navigate()
pub fn get_info(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.info orelse error.InvalidStateError;
}

/// Getter for hasUAVisualTransition
/// HTML Standard §7.2.6.5: Returns true if UA is doing a visual transition
pub fn get_hasUAVisualTransition(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.has_ua_visual_transition;
}

/// Getter for sourceElement
/// HTML Standard §7.2.6.5: Returns the element that initiated navigation
pub fn get_sourceElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.source_element;
}

// ============================================================================
// Navigation Operations
// ============================================================================

/// Operation: intercept(options)
/// HTML Standard §7.2.6.6: Intercept the navigation for SPA-style handling
///
/// When intercept() is called:
/// 1. The navigation becomes same-document
/// 2. The handler function is run
/// 3. Scroll position is restored after handler completes (unless manual)
/// 4. Focus is reset after handler completes (unless manual)
pub fn call_intercept(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationInterceptOptions)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if intercept is allowed
    if (!internal.can_intercept) {
        return error.SecurityError;
    }

    // Check if dispatch is already complete
    if (internal.dispatch_complete) {
        return error.InvalidStateError;
    }

    // Mark as intercepted
    internal.intercepted = true;

    // Process options - webidl.Opt wraps with was_passed + value
    if (options.was_passed) {
        const opts = options.value;

        // Store handler
        internal.intercept_handler = opts.handler;

        // Process focusReset option
        if (opts.focusReset) |focus_ptr| {
            // In full implementation, would parse "after-transition" or "manual"
            _ = focus_ptr;
        }

        // Process scroll option
        if (opts.scroll) |scroll_ptr| {
            // In full implementation, would parse "after-transition" or "manual"
            _ = scroll_ptr;
        }
    }
}

/// Operation: scroll()
/// HTML Standard §7.2.6.6: Manually perform scroll restoration
///
/// This should only be called when scroll was set to "manual" in intercept().
/// It triggers the scroll restoration that would normally happen automatically.
pub fn call_scroll(instance: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check if intercept was called
    if (!internal.intercepted) {
        return error.InvalidStateError;
    }

    // Check if scroll was already called
    if (internal.scroll_called) {
        return error.InvalidStateError;
    }

    // Mark scroll as called
    internal.scroll_called = true;

    // Perform scroll restoration
    // In full implementation, this would:
    // 1. Get the destination entry's scroll position
    // 2. Restore scroll position to document
    // 3. Handle fragment scrolling if applicable
}

// ============================================================================
// Internal Helper Functions
// ============================================================================

/// Create a NavigateEvent for a navigation
/// Called by the Navigation implementation when navigation starts
pub fn createForNavigation(
    allocator: Allocator,
    ctx: runtime.Context,
    navigation_type: enums.NavigationType,
    destination: *runtime.Instance,
    options: CreateOptions,
) !*runtime.Instance {
    const instance = try init(allocator, State, &NavigateEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    internal.navigation_type = navigation_type;
    internal.destination = destination;
    internal.can_intercept = options.can_intercept;
    internal.user_initiated = options.user_initiated;
    internal.hash_change = options.hash_change;
    internal.info = options.info;

    return instance;
}

/// Options for creating a NavigateEvent
pub const CreateOptions = struct {
    can_intercept: bool = true,
    user_initiated: bool = false,
    hash_change: bool = false,
    info: ?*const anyopaque = null,
    form_data: ?*runtime.Instance = null,
    download_request: ?[]const u8 = null,
    source_element: ?*runtime.Instance = null,
};

/// Check if this event was intercepted
pub fn wasIntercepted(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.intercepted;
}

/// Mark dispatch as complete
/// Called after the event has finished dispatching
pub fn markDispatchComplete(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.dispatch_complete = true;
}
