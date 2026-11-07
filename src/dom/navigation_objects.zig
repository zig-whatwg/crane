//! The objects the navigation API makes for a navigation (HTML 7.2.6.8,
//! 7.2.6.9, 7.2.6.10): the NavigationDestination a navigate event carries,
//! the NavigationTransition of an intercepted navigation, the
//! NavigationPrecommitController a precommit handler is given, the
//! NavigateEvent's attributes a precommit redirect() changes, the
//! NavigationActivation of a document and of a pageswap event, and the
//! PageSwapEvent itself. None of them
//! has a constructor script could use for this (NavigateEvent's takes a
//! destination script cannot make), and what each records is its own state,
//! so each installs its part of this hook and Navigation - which fires the
//! event and tracks the navigation - asks it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationdestination
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationtransition
//!
//! lint-impls: hook for NavigateEvent, NavigationDestination, NavigationTransition, NavigationPrecommitController, NavigationActivation, PageSwapEvent

const std = @import("std");
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;
const runtime = @import("runtime");
const joint_history = @import("html_core").navigation.joint_history;
const navigation_api = @import("navigation_api.zig");

/// A NavigationDestination's state (HTML 7.2.6.10.3).
pub const DestinationInit = struct {
    /// Serialized, absolute. BORROWED; the destination copies it.
    url: []const u8,
    /// The NavigationHistoryEntry it is, for a traversal; null otherwise.
    entry: ?*runtime.Instance = null,
    /// Its navigation API state. BORROWED; the destination copies it.
    state: joint_history.SerializedState = .null,
    is_same_document: bool,
};

pub const Destinations = struct {
    /// A new NavigationDestination in `realm`.
    create: *const fn (realm: runtime.Context, init: DestinationInit) anyerror!*runtime.Instance,
    /// Set its URL (a precommit redirect()).
    set_url: *const fn (destination: *runtime.Instance, url: []const u8) anyerror!void,
    /// Set its state (a precommit redirect()), copying it.
    set_state: *const fn (destination: *runtime.Instance, state: joint_history.SerializedState) anyerror!void,
    /// Its entry, or null.
    entry: *const fn (destination: *runtime.Instance) ?*runtime.Instance,
};

/// A NavigationTransition's state (HTML 7.2.6.8).
pub const TransitionInit = struct {
    navigation_type: navigation_api.Kind,
    from: *runtime.Instance,
    destination: *runtime.Instance,
    /// The committed and finished promises. BORROWED; the transition keeps
    /// them for its getters.
    committed: runtime.JSValue,
    finished: runtime.JSValue,
};

pub const Transitions = struct {
    create: *const fn (realm: runtime.Context, init: TransitionInit) anyerror!*runtime.Instance,
};

/// A NavigationActivation's state (HTML 7.2.6.9): its old entry, new entry
/// and navigation type. The activation keeps both entries alive.
pub const ActivationInit = struct {
    from: ?*runtime.Instance,
    entry: *runtime.Instance,
    navigation_type: navigation_api.Kind,
};

pub const Activations = struct {
    /// A new NavigationActivation in `realm`.
    create: *const fn (realm: runtime.Context, init: ActivationInit) anyerror!*runtime.Instance,
    /// HTML "update document for history step application" step 7 for a
    /// document that already has an activation: `activation`'s old entry,
    /// new entry and navigation type become `init`'s (Chromium's
    /// NavigationActivation::Update, from NavigationApi::SetEntriesForRestore
    /// on a back/forward cache restore).
    update: *const fn (activation: *runtime.Instance, init: ActivationInit) void,
};

/// The event "fire the pageswap event" step 5 fires.
pub const PageSwapEvents = struct {
    /// A new PageSwapEvent of type "pageswap" in `realm`, whose activation is
    /// `activation` (held by the event) and whose viewTransition is null.
    create: *const fn (realm: runtime.Context, activation: ?*runtime.Instance) anyerror!*runtime.Instance,
};

pub const Controllers = struct {
    /// A new NavigationPrecommitController in `realm` whose event is `event`.
    create: *const fn (realm: runtime.Context, event: *runtime.Instance) anyerror!*runtime.Instance,
};

pub const Events = struct {
    /// Set a NavigateEvent's navigationType (a precommit redirect()).
    set_navigation_type: *const fn (event: *runtime.Instance, kind: navigation_api.Kind) void,
    /// Set its info (a precommit redirect()). BORROWED; the event keeps it.
    set_info: *const fn (event: *runtime.Instance, info: runtime.JSValue) anyerror!void,
};

var destinations: Hook(?Destinations) = .init(null);
var transitions: Hook(?Transitions) = .init(null);
var controllers: Hook(?Controllers) = .init(null);
var activations: Hook(?Activations) = .init(null);
var page_swap_events: Hook(?PageSwapEvents) = .init(null);
var events: Hook(?Events) = .init(null);

/// Called by NavigationDestination's installHooks, once, at process start (process_start.zig).
pub fn installDestinations(impl: Destinations) void {
    destinations.install(impl);
}

/// Called by NavigationTransition's installHooks, once, at process start (process_start.zig).
pub fn installTransitions(impl: Transitions) void {
    transitions.install(impl);
}

/// Called by NavigationPrecommitController's installHooks, once, at process start (process_start.zig).
pub fn installControllers(impl: Controllers) void {
    controllers.install(impl);
}

/// Called by NavigationActivation's installHooks, once, at process start (process_start.zig).
pub fn installActivations(impl: Activations) void {
    activations.install(impl);
}

/// Called by PageSwapEvent's installHooks, once, at process start (process_start.zig).
pub fn installPageSwapEvents(impl: PageSwapEvents) void {
    page_swap_events.install(impl);
}

/// Called by NavigateEvent's installHooks, once, at process start (process_start.zig).
pub fn installEvents(impl: Events) void {
    events.install(impl);
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn destinationsInstalled() bool {
    return destinations.get() != null;
}
pub fn transitionsInstalled() bool {
    return transitions.get() != null;
}
pub fn controllersInstalled() bool {
    return controllers.get() != null;
}
pub fn eventsInstalled() bool {
    return events.get() != null;
}
pub fn activationsInstalled() bool {
    return activations.get() != null;
}
pub fn pageSwapEventsInstalled() bool {
    return page_swap_events.get() != null;
}

pub fn createDestination(realm: runtime.Context, init: DestinationInit) !*runtime.Instance {
    const impl = destinations.get() orelse return error.NotSupported;
    return impl.create(realm, init);
}

pub fn setDestinationUrl(destination: *runtime.Instance, url: []const u8) !void {
    const impl = destinations.get() orelse return error.NotSupported;
    return impl.set_url(destination, url);
}

pub fn setDestinationState(destination: *runtime.Instance, state: joint_history.SerializedState) !void {
    const impl = destinations.get() orelse return error.NotSupported;
    return impl.set_state(destination, state);
}

pub fn destinationEntry(destination: *runtime.Instance) ?*runtime.Instance {
    const impl = destinations.get() orelse return null;
    return impl.entry(destination);
}

pub fn createTransition(realm: runtime.Context, init: TransitionInit) !*runtime.Instance {
    const impl = transitions.get() orelse return error.NotSupported;
    return impl.create(realm, init);
}

pub fn createActivation(realm: runtime.Context, init: ActivationInit) !*runtime.Instance {
    const impl = activations.get() orelse return error.NotSupported;
    return impl.create(realm, init);
}

/// See Activations.update. Nothing without the implementation.
pub fn updateActivation(activation: *runtime.Instance, init: ActivationInit) void {
    const impl = activations.get() orelse return;
    impl.update(activation, init);
}

pub fn createPageSwapEvent(realm: runtime.Context, activation: ?*runtime.Instance) !*runtime.Instance {
    const impl = page_swap_events.get() orelse return error.NotSupported;
    return impl.create(realm, activation);
}

pub fn createController(realm: runtime.Context, event: *runtime.Instance) !*runtime.Instance {
    const impl = controllers.get() orelse return error.NotSupported;
    return impl.create(realm, event);
}

pub fn setEventNavigationType(event: *runtime.Instance, kind: navigation_api.Kind) void {
    const impl = events.get() orelse return;
    impl.set_navigation_type(event, kind);
}

pub fn setEventInfo(event: *runtime.Instance, info: runtime.JSValue) !void {
    const impl = events.get() orelse return error.NotSupported;
    return impl.set_info(event, info);
}

test "without an installed activation part no NavigationActivation is made" {
    const override = activations.overrideForTest(null);
    defer override.restore();
    try std.testing.expect(!activationsInstalled());
    // Never dereferenced: with no implementation nothing reads them.
    var entry: runtime.Instance = undefined;
    const realm: runtime.Context = @ptrFromInt(0x1000);
    try std.testing.expectError(error.NotSupported, createActivation(realm, .{ .from = null, .entry = &entry, .navigation_type = .push }));
}

test "without an installed pageswap part no PageSwapEvent is made" {
    const override = page_swap_events.overrideForTest(null);
    defer override.restore();
    try std.testing.expect(!pageSwapEventsInstalled());
    const realm: runtime.Context = @ptrFromInt(0x1000);
    try std.testing.expectError(error.NotSupported, createPageSwapEvent(realm, null));
}
