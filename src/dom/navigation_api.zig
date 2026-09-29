//! The navigation API's side of a navigation (HTML 7.2.6): the window's
//! `navigation` object fires the navigate event before a navigation happens
//! (7.2.6.10.4 "fire a push/replace/reload navigate event", "fire a traverse
//! navigate event"), tracks the navigation it lets through or intercepts
//! (7.2.6.8 "ongoing navigation tracking"), and updates its entries when a
//! same-document navigation commits (7.2.6.4 "update the navigation API
//! entries for a same-document navigation").
//!
//! All of that is the Navigation object's state - its ongoing navigate
//! event, its API method trackers, its transition, and what each navigate
//! event's intercept() recorded - so Navigation installs this hook. What
//! navigates - History (pushState, replaceState, traversal), Location and the
//! navigable containers (fragment navigations, "navigate" step 21, reload) -
//! tells it here, and so do the NavigateEvent's and the
//! NavigationPrecommitController's methods, which act on that state.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigate-event-firing
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#update-the-navigation-api-entries-for-a-same-document-navigation
//!
//! lint-impls: hook for Navigation

const std = @import("std");
const runtime = @import("runtime");
const joint_history = @import("html_core").navigation.joint_history;

/// A NavigationType.
pub const Kind = enum { push, replace, reload, traverse };

/// HTML "user navigation involvement".
pub const UserInvolvement = enum { none, activation, browser_ui };

/// NavigationFocusReset and NavigationScrollBehavior, as intercept() hands
/// them over.
pub const FocusReset = enum { after_transition, manual };
pub const ScrollBehavior = enum { after_transition, manual };

/// HTML "fire a push/replace/reload navigate event"'s arguments.
pub const PushReplaceReload = struct {
    navigation_type: Kind,
    /// Serialized, absolute. BORROWED for the call.
    destination_url: []const u8,
    is_same_document: bool,
    user_involvement: UserInvolvement = .none,
    source_element: ?*runtime.Instance = null,
    /// The navigation API state for the destination; null is
    /// StructuredSerializeForStorage(null) - the default. BORROWED.
    navigation_api_state: ?joint_history.SerializedState = null,
    /// The classic history API state (pushState's and replaceState's data),
    /// or null. BORROWED.
    classic_history_api_state: ?joint_history.SerializedState = null,
    /// "formDataEntryList": a form's entry list, when the navigation's
    /// document resource is its POST resource, as a FormData holding it (in
    /// any realm). BORROWED.
    form_data: ?*runtime.Instance = null,
};

/// What intercept() was given.
pub const InterceptOptions = struct {
    /// The binding's converted callback functions, as it hands them over
    /// (engine.takeCallbackFunction takes them), or null when absent.
    precommit_handler: ?*const anyopaque = null,
    handler: ?*const anyopaque = null,
    focus_reset: ?FocusReset = null,
    scroll: ?ScrollBehavior = null,
};

/// What NavigationPrecommitController.redirect() was given.
pub const Redirect = struct {
    /// The URL as given, not yet parsed. BORROWED.
    url: []const u8,
    history: ?Kind = null,
    /// options["state"], present or not. BORROWED.
    state: ?runtime.JSValue = null,
    /// options["info"], present or not. BORROWED.
    info: ?runtime.JSValue = null,
};

pub const Implementation = struct {
    same_document_navigation: *const fn (window: *runtime.Instance, kind: Kind) void,
    fire_push_replace_reload: *const fn (window: *runtime.Instance, args: *const PushReplaceReload) bool,
    fire_traverse: *const fn (window: *runtime.Instance, entry_id: u64, user_involvement: UserInvolvement) bool,
    inform_about_aborting_navigation: *const fn (window: *runtime.Instance) void,
    inform_about_child_navigable_destruction: *const fn (window: *runtime.Instance) void,
    intercept: *const fn (event: *runtime.Instance, options: InterceptOptions) anyerror!void,
    scroll: *const fn (event: *runtime.Instance) anyerror!void,
    redirect: *const fn (event: *runtime.Instance, redirect: *const Redirect) anyerror!void,
    add_handler: *const fn (event: *runtime.Instance, handler: *const anyopaque) anyerror!void,
};

threadlocal var implementation: ?Implementation = null;

/// Called by Navigation. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `window`'s navigable has made a same-document navigation of `kind`:
/// its current session history entry is the destination. Nothing happens
/// before any window has a navigation object.
pub fn sameDocumentNavigation(window: *runtime.Instance, kind: Kind) void {
    const impl = implementation orelse return;
    impl.same_document_navigation(window, kind);
}

/// HTML "fire a push/replace/reload navigate event" at `window`'s
/// navigation API: whether the navigation continues. With no Navigation
/// object made yet - no script has asked for `window.navigation` - there is
/// nobody to hear the event, and it continues.
pub fn firePushReplaceReload(window: *runtime.Instance, args: PushReplaceReload) bool {
    const impl = implementation orelse return true;
    return impl.fire_push_replace_reload(window, &args);
}

/// HTML "fire a traverse navigate event" at `window`'s navigation API, for
/// the session history entry `entry_id`: whether the traversal continues.
pub fn fireTraverse(window: *runtime.Instance, entry_id: u64, user_involvement: UserInvolvement) bool {
    const impl = implementation orelse return true;
    return impl.fire_traverse(window, entry_id, user_involvement);
}

/// HTML "inform the navigation API about aborting navigation" in `window`'s
/// navigable.
pub fn informAboutAbortingNavigation(window: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.inform_about_aborting_navigation(window);
}

/// HTML "inform the navigation API about child navigable destruction" for
/// the navigable whose active window is `window`.
pub fn informAboutChildNavigableDestruction(window: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.inform_about_child_navigable_destruction(window);
}

/// NavigateEvent's intercept(options), steps 4-9, once the event has passed
/// its own checks (1-3).
pub fn intercept(event: *runtime.Instance, options: InterceptOptions) !void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.intercept(event, options);
}

/// NavigateEvent's scroll(), steps 2-3, once the event has passed shared
/// checks.
pub fn scroll(event: *runtime.Instance) !void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.scroll(event);
}

/// NavigationPrecommitController's redirect() for `event`, steps 3-12.
pub fn redirect(event: *runtime.Instance, args: Redirect) !void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.redirect(event, &args);
}

/// NavigationPrecommitController's addHandler() for `event`, steps 3-4.
pub fn addHandler(event: *runtime.Instance, handler: *const anyopaque) !void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.add_handler(event, handler);
}

test "without an installed implementation nothing is told, and navigations continue" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var window: runtime.Instance = undefined;
    sameDocumentNavigation(&window, .push);
    try std.testing.expect(firePushReplaceReload(&window, .{ .navigation_type = .push, .destination_url = "https://a.test/#x", .is_same_document = true }));
    try std.testing.expect(fireTraverse(&window, 1, .none));
    informAboutAbortingNavigation(&window);
    try std.testing.expectError(error.InvalidStateError, intercept(&window, .{}));
    try std.testing.expectError(error.InvalidStateError, scroll(&window));
}
