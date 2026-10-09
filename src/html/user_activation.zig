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

/// Whether a navigation of `target` (a navigable's html_core browsing
/// context) to `url` that `source_document` started is refused: a frame
/// navigating its top-level traversable away while it is cross-origin with
/// it and has no user activation. HTML has no such step - its navigate only
/// checks the sandboxing flags - so this is a deviation, stated (golden rule
/// 2): Firefox and Safari ship it, Chrome stable does not, so it is a 2-of-3
/// majority. wpt.fyi (run cc74d2669f): navigating-across-documents/
/// cross-origin-top-navigation-without-user-activation.window.html and its
/// -nested variant pass in Firefox 157 and Safari 27 and fail in Chrome 154.
/// Gecko: BrowsingContext::CheckFramebusting, with
/// BrowsingContext::ComputeIsFramebustingAllowed (docshell/base/
/// BrowsingContext.cpp), called from LoadURI and nsDocShell::InternalLoad for
/// every load. WebKit: Document::isNavigationBlockedByThirdPartyIFrameRedirectBlocking,
/// called from Document::canNavigate (dom/Document.cpp), whose
/// CanNavigateState::Unable the Location setter throws as a SecurityError
/// (Location::setLocation).
///
/// It applies only when the target is a top-level traversable (Gecko IsTop();
/// WebKit requester.topFrameID == targetFrame.frameID()) other than the
/// source's own navigable, and only to the top of the source's own page
/// (Gecko allows a source in another browser - a popup navigating its opener
/// - and WebKit checks only the requester's own top). Each exception, and who
/// allows it:
/// - No source document - a navigation the engine or the embedder starts,
///   not a page: allowed by all three (Gecko: a null SourceBrowsingContext).
///   Traversals, reloads and a container navigating its own child never get
///   here (the caller does not ask, or the target is not top-level).
/// - The source's window has transient activation: allowed by all three
///   (Gecko: nsDocShellLoadState::HasValidUserGestureActivation; WebKit:
///   hasHadUserInteraction).
/// - The source's window has sticky activation only (the transient window
///   has passed or was consumed): allowed by WebKit (hasHadUserInteraction is
///   "has the user ever interacted") and by Chrome; Gecko refuses - 2 of 3
///   allow.
/// - The source's navigable is same origin with the top-level traversable:
///   allowed by all three (Gecko: SameOriginWithTop; WebKit:
///   canAccessAncestor of the target's origin).
/// - The source's navigable is sandboxed with allow-top-navigation and its
///   parent is allowed by these rules: allowed by Gecko
///   (ComputeIsFramebustingAllowed recurses to the parent), WebKit (an
///   attribute sandbox whose parent is same origin with top) and Chrome.
/// - The destination is same site with the top-level traversable's origin
///   (same scheme, and same host or registrable domain): allowed by WebKit
///   (the last step of its check) and Chrome; Gecko refuses - 2 of 3 allow.
/// Not taken: Gecko's per-site popup permission (no permission store), and
/// WebKit's "untrusted first-party iframe" (one that loaded both a
/// third-party script and a third-party frame), which neither Gecko nor
/// Chrome blocks.
pub fn topNavigationBlocked(source_document: ?*Instance, target: *BrowsingContext, url: []const u8) bool {
    if (target.parent != null) return false;
    const source = source_document orelse return false;
    const source_window = (interfaces.Document.get_defaultView(source) catch null) orelse return false;
    const source_context = browsingContextOf(source_window) orelse return false;
    if (source_context == target) return false;
    if (source_context.getTop() != target) return false;
    // Transient or sticky activation.
    if (hasStickyActivation(source_window)) return false;
    if (framebustingAllowed(source_context, target)) return false;
    if (sameSiteWithTop(target, url)) return false;
    return true;
}

/// Gecko's ComputeIsFramebustingAllowed for `context` under `top`: it is
/// top, it is same origin with top, or it is sandboxed with
/// allow-top-navigation and its parent is allowed.
fn framebustingAllowed(context: *BrowsingContext, top: *BrowsingContext) bool {
    var current = context;
    var depth: usize = 0;
    while (depth < max_windows) : (depth += 1) {
        const parent = current.parent orelse return true;
        if (current == top) return true;
        if (sameOriginWith(current, top)) return true;
        const flags = current.sandbox_flags orelse return false;
        if (!flags.allow_top_navigation) return false;
        current = parent;
    }
    return false;
}

/// Whether the active windows of `a` and `b` have the same origin (an opaque
/// origin is the same as none other).
fn sameOriginWith(a: *BrowsingContext, b: *BrowsingContext) bool {
    const allocator = std.heap.page_allocator;
    const origin_a = windowOriginOf(a, allocator) orelse return false;
    defer allocator.free(origin_a);
    const origin_b = windowOriginOf(b, allocator) orelse return false;
    defer allocator.free(origin_b);
    if (std.mem.eql(u8, origin_a, "null")) return false;
    return std.mem.eql(u8, origin_a, origin_b);
}

/// The serialized origin of `context`'s active window, owned by `allocator`.
fn windowOriginOf(context: *BrowsingContext, allocator: std.mem.Allocator) ?[]u8 {
    const window = activeWindowOf(context) orelse return null;
    const origin = interfaces.Window.get_origin(window) catch return null;
    defer window.ctx.allocator.free(origin);
    return allocator.dupe(u8, origin) catch null;
}

/// WebKit's last step: `url` has the scheme of `top`'s origin, and the same
/// host or registrable domain.
fn sameSiteWithTop(top: *BrowsingContext, url: []const u8) bool {
    const allocator = std.heap.page_allocator;
    const url_mod = @import("url");
    const parse = url_mod.parser.basic_url_parser.parse;
    const origin = windowOriginOf(top, allocator) orelse return false;
    defer allocator.free(origin);
    var top_record = parse(allocator, origin, null) catch return false;
    defer top_record.deinit();
    var destination = parse(allocator, url, null) catch return false;
    defer destination.deinit();
    if (!std.mem.eql(u8, top_record.scheme(), destination.scheme())) return false;
    const top_host = top_record.host orelse return false;
    const destination_host = destination.host orelse return false;
    if (hostsEqual(top_host, destination_host)) return true;
    const top_site = (url_mod.public_suffix.getRegistrableDomain(allocator, top_host) catch return false) orelse return false;
    defer allocator.free(top_site);
    const destination_site = (url_mod.public_suffix.getRegistrableDomain(allocator, destination_host) catch return false) orelse return false;
    defer allocator.free(destination_site);
    return std.ascii.eqlIgnoreCase(top_site, destination_site);
}

fn hostsEqual(a: anytype, b: @TypeOf(a)) bool {
    return switch (a) {
        .domain => |d| b == .domain and std.mem.eql(u8, d, b.domain),
        .opaque_host => |o| b == .opaque_host and std.mem.eql(u8, o, b.opaque_host),
        .ipv4 => |v| b == .ipv4 and v == b.ipv4,
        .ipv6 => |v| b == .ipv6 and std.mem.eql(u16, &v, &b.ipv6),
        .empty => b == .empty,
    };
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
