//! The objects the navigation API makes for a navigation (HTML 7.2.6.8,
//! 7.2.6.10): the NavigationDestination a navigate event carries, the
//! NavigationTransition of an intercepted navigation, the
//! NavigationPrecommitController a precommit handler is given, and the
//! NavigateEvent's attributes a precommit redirect() changes. None of them
//! has a constructor script could use for this (NavigateEvent's takes a
//! destination script cannot make), and what each records is its own state,
//! so each installs its part of this hook and Navigation - which fires the
//! event and tracks the navigation - asks it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationdestination
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationtransition
//!
//! lint-impls: hook for NavigateEvent, NavigationDestination, NavigationTransition, NavigationPrecommitController

const std = @import("std");
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

threadlocal var destinations: ?Destinations = null;
threadlocal var transitions: ?Transitions = null;
threadlocal var controllers: ?Controllers = null;
threadlocal var events: ?Events = null;

/// Called by NavigationDestination. Idempotent.
pub fn installDestinations(impl: Destinations) void {
    destinations = impl;
}

/// Called by NavigationTransition. Idempotent.
pub fn installTransitions(impl: Transitions) void {
    transitions = impl;
}

/// Called by NavigationPrecommitController. Idempotent.
pub fn installControllers(impl: Controllers) void {
    controllers = impl;
}

/// Called by NavigateEvent. Idempotent.
pub fn installEvents(impl: Events) void {
    events = impl;
}

/// Each part is installed when its type makes its first object; a caller
/// with none makes one first (through the interface's `init`) and lets it go.
pub fn destinationsInstalled() bool {
    return destinations != null;
}
pub fn transitionsInstalled() bool {
    return transitions != null;
}
pub fn controllersInstalled() bool {
    return controllers != null;
}
pub fn eventsInstalled() bool {
    return events != null;
}

pub fn createDestination(realm: runtime.Context, init: DestinationInit) !*runtime.Instance {
    const impl = destinations orelse return error.NotSupported;
    return impl.create(realm, init);
}

pub fn setDestinationUrl(destination: *runtime.Instance, url: []const u8) !void {
    const impl = destinations orelse return error.NotSupported;
    return impl.set_url(destination, url);
}

pub fn setDestinationState(destination: *runtime.Instance, state: joint_history.SerializedState) !void {
    const impl = destinations orelse return error.NotSupported;
    return impl.set_state(destination, state);
}

pub fn destinationEntry(destination: *runtime.Instance) ?*runtime.Instance {
    const impl = destinations orelse return null;
    return impl.entry(destination);
}

pub fn createTransition(realm: runtime.Context, init: TransitionInit) !*runtime.Instance {
    const impl = transitions orelse return error.NotSupported;
    return impl.create(realm, init);
}

pub fn createController(realm: runtime.Context, event: *runtime.Instance) !*runtime.Instance {
    const impl = controllers orelse return error.NotSupported;
    return impl.create(realm, event);
}

pub fn setEventNavigationType(event: *runtime.Instance, kind: navigation_api.Kind) void {
    const impl = events orelse return;
    impl.set_navigation_type(event, kind);
}

pub fn setEventInfo(event: *runtime.Instance, info: runtime.JSValue) !void {
    const impl = events orelse return error.NotSupported;
    return impl.set_info(event, info);
}
