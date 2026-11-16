//! A Window's Location and History objects: the steps on them that no IDL
//! member names.
//!
//! HTML gives every Window one Location and one History ([SameObject], made
//! with the Window in its relevant realm). Each knows its Window - the
//! Location's relevant global, through which "Location-object navigate"
//! reaches the navigable, and the History's, whose navigable's session
//! history it reads - and the code that makes a navigable's Window wires the
//! Location to that navigable: its URL as the navigable's document commits,
//! and the "navigate" that its href setter, assign() and replace() run. None
//! of that is an IDL member, so each owner installs its steps here from its
//! installHooks, and the navigable code (HTMLIFrameElement's) and the engine
//! adapter's wrapper cache, which keeps a Window's Location and History
//! alive with the Window, ask here instead of naming the impls (AGENTS.md,
//! the impls boundary). A History's Window and navigable are construction
//! arguments (`interfaces.History.initWith`); only the question is here.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-location-interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-history-interface
//!
//! lint-impls: hook for Location, History
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");
const html_core = @import("html_core");

/// What "Location-object navigate" asks of the navigable's engine.
pub const NavigateRequest = html_core.window.iframe_integration.NavigateRequest;

/// The navigable's "navigate" for a Location: `(context, url, request)`,
/// whether a navigable took it. The engine behind it runs "Location-object
/// navigate" step 3 - a relevant document that is not completely loaded
/// makes the navigation a replace - and step 4, "navigate". `context` is the
/// navigable's (an IFrameIntegration), opaque here.
pub const NavigateCallback = *const fn (context: ?*anyopaque, url: []const u8, request: NavigateRequest) bool;

/// What Location supplies.
pub const LocationSteps = struct {
    /// The Window `location` was made for (its relevant global, or the one
    /// `set_window` named), or null: none, or not a Location.
    window: *const fn (location: *runtime.Instance) ?*runtime.Instance,
    /// Make `window` the Window `location` belongs to.
    set_window: *const fn (location: *runtime.Instance, window: *runtime.Instance) void,
    /// The navigable `location` navigates (`callback` with `context`), or
    /// none with a null callback.
    set_navigable: *const fn (location: *runtime.Instance, callback: ?NavigateCallback, context: ?*anyopaque) void,
    /// `location`'s URL is `url`, a URL string its navigable's document
    /// committed with or moved to (a fragment navigation).
    /// Fails as the URL parser does, or out of memory.
    set_url: *const fn (location: *runtime.Instance, url: []const u8) anyerror!void,
};

/// What History supplies.
pub const HistorySteps = struct {
    /// The Window `history` was made for, or null: none, or not a History.
    window: *const fn (history: *runtime.Instance) ?*runtime.Instance,
};

const Hooks = struct {
    location: ?LocationSteps = null,
    history: ?HistorySteps = null,
};
// process-wide: the Location and History steps, installed once by their owners at process start (process_start.zig), with no instance state
var steps: Hook(Hooks) = .init(.{});

/// Called by Location's installHooks, once, at process start (process_start.zig).
pub fn installLocation(location_steps: LocationSteps) void {
    steps.installField("location", location_steps);
}

/// Called by History's installHooks, once, at process start (process_start.zig).
pub fn installHistory(history_steps: HistorySteps) void {
    steps.installField("history", history_steps);
}

/// The Window `location` belongs to; null for a Location made for none, for
/// an object that is no Location, or with no Location installed.
pub fn locationWindow(location: *runtime.Instance) ?*runtime.Instance {
    const location_steps = steps.read().location orelse return null;
    return location_steps.window(location);
}

/// Make `window` the Window `location` belongs to.
pub fn setLocationWindow(location: *runtime.Instance, window: *runtime.Instance) void {
    const location_steps = steps.read().location orelse return;
    location_steps.set_window(location, window);
}

/// Make `location` navigate a navigable: its href setter, assign() and
/// replace() call `callback` with `context` (see NavigateCallback).
pub fn setLocationNavigable(location: *runtime.Instance, callback: ?NavigateCallback, context: ?*anyopaque) void {
    const location_steps = steps.read().location orelse return;
    location_steps.set_navigable(location, callback, context);
}

/// `location`'s URL is now `url` (its navigable's document's).
pub fn setLocationUrl(location: *runtime.Instance, url: []const u8) anyerror!void {
    const location_steps = steps.read().location orelse return error.InvalidStateError;
    return location_steps.set_url(location, url);
}

/// The Window `history` belongs to; null for a History made for none, for
/// an object that is no History, or with no History installed.
pub fn historyWindow(history: *runtime.Instance) ?*runtime.Instance {
    const history_steps = steps.read().history orelse return null;
    return history_steps.window(history);
}

test "with nothing installed no Location or History has a Window, and setting one does nothing" {
    const std = @import("std");
    const override = steps.overrideForTest(.{});
    defer override.restore();
    // Never dereferenced: with nothing installed the calls do not reach it.
    var object: runtime.Instance = undefined;
    try std.testing.expectEqual(@as(?*runtime.Instance, null), locationWindow(&object));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), historyWindow(&object));
    setLocationWindow(&object, &object);
    setLocationNavigable(&object, null, null);
    try std.testing.expectError(error.InvalidStateError, setLocationUrl(&object, "about:blank"));
}
