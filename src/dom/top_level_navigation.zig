//! Navigating the top-level page: HTML "navigate" for a navigable this engine
//! has no navigable engine for - the page Crane was pointed at. Its Location
//! runs what the engine can of it: a fragment navigation, and the navigate
//! event before any navigation (its document cannot be replaced). So Location
//! installs this hook, and the hyperlink and form navigations that choose the
//! top-level page (dom.navigables) ask it without importing Location.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate
//!
//! lint-impls: hook for Location
const process_start = @import("process_start.zig");

const runtime = @import("runtime");
const joint_history = @import("html_core").navigation.joint_history;
const navigation_api = @import("navigation_api.zig");

/// `NavigationHistoryBehavior`.
pub const HistoryBehavior = enum { auto, push, replace };

/// "Navigate"'s optional arguments.
pub const Params = struct {
    history_behavior: HistoryBehavior = .auto,
    source_document: ?*runtime.Instance = null,
    source_element: ?*runtime.Instance = null,
    user_involvement: navigation_api.UserInvolvement = .none,
    /// BORROWED.
    navigation_api_state: ?joint_history.SerializedState = null,
    /// A form submitted "as entity body": its entry list as a FormData - the
    /// navigation has a POST resource, and the navigate event its formData.
    /// BORROWED.
    form_data: ?*runtime.Instance = null,
};

pub const Implementation = struct {
    /// Navigate `window`'s navigable - the top-level page - to `url`
    /// (serialized, absolute).
    navigate: *const fn (window: *runtime.Instance, url: []const u8, params: Params) void,
};

var implementation: ?Implementation = null;

/// Called by Location's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation != null;
}

pub fn navigate(window: *runtime.Instance, url: []const u8, params: Params) void {
    const impl = implementation orelse return;
    impl.navigate(window, url, params);
}
