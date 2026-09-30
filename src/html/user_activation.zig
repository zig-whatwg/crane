//! HTML 6.4 "Tracking user activation": the activation notification an
//! activation-triggering input event makes, activation consumption, and the
//! sticky, transient and history-action activation states.
//!
//! The timestamps are each Window's own state, reached through the hook
//! Window installs (dom.user_activation_state); the navigables a document's
//! activation reaches are the browsing contexts html_core keeps. Nothing
//! here holds state.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#tracking-user-activation

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const html_core = @import("html_core");

const engine = @import("engine");

const Instance = runtime.Instance;
const BrowsingContext = html_core.window.BrowsingContext;
const state = dom.user_activation_state;

/// HTML "transient activation duration": how long an activation is available
/// to transient activation-gated APIs. Five seconds, as in Blink and Gecko
/// (the spec asks for "at most a few seconds").
pub const transient_activation_duration_ms: f64 = 5000;

/// The most windows one notification or consumption visits: a page deeper or
/// wider than this has the rest left out.
const max_windows = 256;

/// `window`'s browsing context, when it is some live context's active window.
fn browsingContextOf(window: *Instance) ?*BrowsingContext {
    return BrowsingContext.ofWindow(@ptrCast(window));
}

fn activeWindowOf(context: *BrowsingContext) ?*Instance {
    const window = context.getActiveWindow() orelse return null;
    return @ptrCast(@alignCast(window));
}

/// HTML 6.4.2 "activation notification", run before an activation-triggering
/// input event is dispatched in `document`.
pub fn notifyActivation(document: *Instance) void {
    // Step 1: "Assert: document is fully active." A document with no window
    // or browsing context is not, and nothing is activated.
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return;
    var windows: [max_windows]*Instance = undefined;
    var count: usize = 0;
    // Step 2: "Let windows be « document's relevant global object »."
    windows[count] = window;
    count += 1;
    if (browsingContextOf(window)) |context| {
        // Step 3: "Extend windows with the active window of each of
        // document's ancestor navigables."
        var ancestor = context.parent;
        while (ancestor) |parent| : (ancestor = parent.parent) {
            if (count == max_windows) break;
            if (activeWindowOf(parent)) |w| {
                windows[count] = w;
                count += 1;
            }
        }
        // Step 4: "Extend windows with the active window of each of
        // document's descendant navigables, filtered to include only those
        // navigables whose active document's origin is same origin with
        // document's origin."
        var descendants: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer descendants.deinit(std.heap.page_allocator);
        context.collectDescendants(std.heap.page_allocator, &descendants) catch {};
        for (descendants.items) |descendant| {
            if (descendant == context or descendant.orphaned) continue;
            if (!descendant.isSameOrigin(context)) continue;
            if (count == max_windows) break;
            if (activeWindowOf(descendant)) |w| {
                windows[count] = w;
                count += 1;
            }
        }
    }
    // Step 5: "For each window in windows: set window's last activation
    // timestamp to the current high resolution time" - and "notify the
    // close watcher manager about user activation", which Crane has no
    // close watchers for.
    const now = state.sharedCurrentTime();
    for (windows[0..count]) |w| {
        var timestamps = state.get(w);
        timestamps.last_activation = now;
        state.set(w, timestamps);
    }
}

/// HTML 6.4.1 "sticky activation": the current time is at or after the last
/// activation timestamp (which positive infinity never is).
pub fn hasStickyActivation(window: *Instance) bool {
    return isSticky(state.get(window), state.sharedCurrentTime());
}

/// HTML 6.4.1 "transient activation": the current time is at or after the
/// last activation timestamp and before it plus the transient activation
/// duration.
pub fn hasTransientActivation(window: *Instance) bool {
    return isTransient(state.get(window), state.sharedCurrentTime());
}

/// The Window of `realm`: the active window of the browsing context whose
/// window lives in it.
pub fn windowOfRealm(realm: runtime.Context) ?*Instance {
    for (BrowsingContext.liveContexts()) |context| {
        if (context.orphaned) continue;
        const window = activeWindowOf(context) orelse continue;
        if (window.ctx == realm) return window;
    }
    return null;
}

/// HTML "user navigation involvement" for an Event `event`: "activation"
/// when its isTrusted attribute was initialized to true, otherwise "none".
pub fn userNavigationInvolvement(event: *Instance) dom.navigation_api.UserInvolvement {
    const trusted = interfaces.Event.get_isTrusted(event) catch false;
    return if (trusted) .activation else .none;
}

/// Whether the incumbent global object has transient activation: HTML
/// "Location-object navigate" step 3 asks it of the script that navigates.
/// No incumbent realm (a navigation engine code starts) is no activation.
pub fn incumbentHasTransientActivation() bool {
    const realm = engine.incumbentRealm() orelse return false;
    const window = windowOfRealm(realm) orelse return false;
    return hasTransientActivation(window);
}

/// HTML 6.4.1 "history-action activation": the last history-action
/// activation timestamp differs from the last activation timestamp.
pub fn hasHistoryActionActivation(window: *Instance) bool {
    const timestamps = state.get(window);
    return timestamps.last_history_action_activation != timestamps.last_activation;
}

fn isSticky(timestamps: state.Timestamps, now: f64) bool {
    return now >= timestamps.last_activation;
}

fn isTransient(timestamps: state.Timestamps, now: f64) bool {
    return now >= timestamps.last_activation and now < timestamps.last_activation + transient_activation_duration_ms;
}

/// The active windows of the inclusive descendant navigables of the
/// top-level traversable of `window`'s navigable, into `out`; how many.
/// Steps 1-4 of both consumption algorithms.
fn windowsOfTop(window: *Instance, out: []*Instance) usize {
    // Step 1: "If W's navigable is null, then return."
    const context = browsingContextOf(window) orelse return 0;
    // Step 2: "Let top be W's navigable's top-level traversable."
    const top = context.getTop();
    // Step 3: "Let navigables be the inclusive descendant navigables of
    // top's active document." Step 4: their active windows.
    var navigables: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer navigables.deinit(std.heap.page_allocator);
    top.collectDescendants(std.heap.page_allocator, &navigables) catch {};
    var count: usize = 0;
    for (navigables.items) |navigable| {
        if (navigable.orphaned or count == out.len) continue;
        if (activeWindowOf(navigable)) |w| {
            out[count] = w;
            count += 1;
        }
    }
    return count;
}

/// HTML 6.4.2 "consume user activation" given `window`.
pub fn consume(window: *Instance) void {
    var windows: [max_windows]*Instance = undefined;
    const count = windowsOfTop(window, &windows);
    // Step 5: "For each window in windows, if window's last activation
    // timestamp is not positive infinity, then set window's last activation
    // timestamp to negative infinity."
    for (windows[0..count]) |w| {
        var timestamps = state.get(w);
        if (std.math.isPositiveInf(timestamps.last_activation)) continue;
        timestamps.last_activation = -std.math.inf(f64);
        state.set(w, timestamps);
    }
}

/// HTML 6.4.2 "consume history-action user activation" given `window`.
pub fn consumeHistoryAction(window: *Instance) void {
    var windows: [max_windows]*Instance = undefined;
    const count = windowsOfTop(window, &windows);
    // Step 5: "For each window in windows, set window's last history-action
    // activation timestamp to window's last activation timestamp."
    for (windows[0..count]) |w| {
        var timestamps = state.get(w);
        timestamps.last_history_action_activation = timestamps.last_activation;
        state.set(w, timestamps);
    }
}

test "sticky and transient activation from the timestamps" {
    const never: state.Timestamps = .{};
    try std.testing.expect(!isSticky(never, 1000));
    try std.testing.expect(!isTransient(never, 1000));
    const activated: state.Timestamps = .{ .last_activation = 1000 };
    try std.testing.expect(isSticky(activated, 1000));
    try std.testing.expect(isTransient(activated, 1000));
    try std.testing.expect(isTransient(activated, 1000 + transient_activation_duration_ms - 1));
    try std.testing.expect(!isTransient(activated, 1000 + transient_activation_duration_ms));
    try std.testing.expect(isSticky(activated, 1000 + transient_activation_duration_ms));
    try std.testing.expect(!isSticky(activated, 999));
    // Consumed: negative infinity keeps sticky activation, ends transient.
    const consumed: state.Timestamps = .{ .last_activation = -std.math.inf(f64) };
    try std.testing.expect(isSticky(consumed, 1000));
    try std.testing.expect(!isTransient(consumed, 1000));
}
