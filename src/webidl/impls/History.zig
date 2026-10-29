//! Implementation for History interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-history-interface
//!
//! A History reads and changes the session history of its window's
//! navigable's traversable (`html_core` JointHistory, kept on the top-level
//! BrowsingContext): length and index from its navigable's view of that
//! history (joint_history View, written when the history changes - HTML
//! keeps them per History object), state from the navigable's current
//! entry, pushState/replaceState as "the
//! URL and history update steps", and back/forward/go as "traverse the
//! history by a delta".
//!
//! Traversals, reloads and the updates for navigable creation/destruction run
//! as "apply the history step" on the traversable's session history traversal
//! queue (html_core navigation.apply_history_step, engine-free). History
//! appends them and supplies the steps of it that need a window, a realm or a
//! document (dom.history_traversal, installed below): queueing a global task
//! on a navigable's active window, beforeunload, and "update document for
//! history step application" for a same-document entry - its URL and state
//! restored, popstate (and hashchange).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const History = interfaces.History;
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
const Navigables = html_core.window.Navigables;
const joint_history = html_core.navigation.joint_history;
const navigate_steps = html_core.navigation.navigate_steps;
const traversal_queue = html_core.navigation.traversal_queue;
const apply_history_step = html_core.navigation.apply_history_step;
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");
const engine = @import("engine");
const navigation_entries = @import("navigation_entries.zig");
const log = std.log.scoped(.history);
const history_documents = @import("history_documents.zig");

pub const State = History.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    InvalidStateError,
    DataCloneError,
    OutOfMemory,
};

/// Internal state for History implementation
pub const InternalState = struct {
    /// Allocator for history resources
    allocator: Allocator,

    /// The window whose History this is.
    window: ?*runtime.Instance = null,

    /// That window's navigable, when the window was made for it.
    browsing_context: ?*BrowsingContext = null,

    /// history.state for the entry it was deserialized from: HTML "restore
    /// the history object state" keeps one value per entry, so reading it
    /// twice gives the same object. Kept by an edge from the History's
    /// wrapper (`state_slot`, engine.traceValue), never a root; false: the
    /// next read deserializes the entry's state. (Every state ever
    /// deserialized used to be held, as roots, until the History went: an
    /// event or script that still holds an earlier one keeps it itself.)
    state_entry: u64 = 0,
    has_state: bool = false,

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

/// Where a History keeps its state value.
const state_slot: engine.TracedSlot = .{ .name = "state" };

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // The navigation API's traverseTo(), back(), forward() and reload() run
    // this traversal too.
    @import("dom").history_traversal.install(.{
        .traverse_to_step = &traverseWindowToStep,
        .reload = &reloadWindow,
        .reload_with_navigation_api_state = &reloadWindowWithNavigationApiState,
        .url_and_history_update = &urlAndHistoryUpdateOfWindow,
        .resume_traversal = &resumeTraversalOfWindow,
        // "Apply the history step"'s window, realm and document steps (lane
        // nav2 C2, H-NAV2-HT-APPLY).
        .queue_task = &queueApplyTask,
        .before_unload_canceled = &beforeUnloadCanceled,
        .update_same_document = &sameDocumentTraversal,
        .document_info = &history_documents.infoOf,
    });
}

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
    };

    // Store internal state
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const instance_lifecycle = @import("runtime").instance_lifecycle;
    const is_first = instance_lifecycle.markCleanupStarted(instance);

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // A History freed before script saw it lets its state go.
        if (internal.has_state) engine.forgetTracedChild(instance, state_slot);
        internal.has_state = false;
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }

    if (is_first) {
        instance_lifecycle.markCleanupComplete(instance);
    }
}

// =============================================================================
// The navigable, its document and its traversable's history
// =============================================================================

/// The History's navigable, when its relevant global's document is fully
/// active (HTML History member step 1, delta traverse/shared state step 2).
fn activeNavigable(internal: *InternalState) ?*BrowsingContext {
    const bc = internal.browsing_context orelse return null;
    const window = internal.window orelse return null;
    if (bc.getActiveWindow() != @as(?*anyopaque, @ptrCast(window))) return null;
    // A discarded context may retain its active Window for script. Ask the
    // document's activity hook too, as isDocumentFullyActive in WebKit's
    // History.cpp does; active-window identity alone does not make it active.
    if (!@import("dom").document_activity.fullyActive(window, runtime.SlabAllocator.generationOf(window))) return null;
    return bc;
}

/// The URL of `document`, owned by `allocator`; "about:blank" when it has
/// none.
fn documentUrl(document: *runtime.Instance, allocator: Allocator) ![]u8 {
    return history_documents.urlOf(document, allocator);
}

/// The traversable's history, with entries for `bc` and its ancestors.
fn ensureEntries(bc: *BrowsingContext) !*joint_history.JointHistory {
    return bc.ensureHistoryEntries(&history_documents.infoOf);
}

// =============================================================================
// Property Getters/Setters
// =============================================================================

/// Getter for length: "1. If this's relevant global object's associated
/// Document is not fully active, then throw a SecurityError DOMException.
/// 2. Return this's length."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    // This's length: the view of the session history its document last had
    // written (joint_history View).
    return history.historyView(bc.id).length;
}

/// Getter for scrollRestoration: the active entry's scroll restoration mode.
pub fn get_scrollRestoration(instance: *runtime.Instance) anyerror!enums.ScrollRestoration {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    const entry = history.currentEntry(bc.id) orelse return ._auto_;
    return if (entry.scroll_restoration_manual) ._manual_ else ._auto_;
}

/// Setter for scrollRestoration: sets the active entry's mode.
pub fn set_scrollRestoration(instance: *runtime.Instance, value: enums.ScrollRestoration) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    const entry = history.currentEntry(bc.id) orelse return;
    entry.scroll_restoration_manual = value == ._manual_;
}

/// Getter for state: "1. If this's relevant global object's associated
/// Document is not fully active, then throw a SecurityError DOMException.
/// 2. Return this's state" - the navigable's current entry's classic history
/// API state, deserialized once per entry.
pub fn get_state(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    const history = try ensureEntries(bc);
    const entry = history.currentEntry(bc.id) orelse return runtime.JSValue.jsNull;
    // The History keeps the state; the binding gets a hold of its own.
    return (try stateValue(instance, internal, entry)).take();
}

/// The deserialized state of `entry`, kept by `history` for as long as it is
/// the entry: a hold of the caller's own.
fn stateValue(history: *runtime.Instance, internal: *InternalState, entry: *joint_history.Entry) !engine.Owned {
    if (internal.has_state and internal.state_entry == entry.id) {
        if (engine.tracedValue(history, state_slot)) |value| return value;
    }
    // Restored in the History's relevant realm - its window's.
    const owned = try navigation_entries.deserialize(internal.window.?.ctx, entry.state);
    engine.traceValue(history, owned.value, state_slot);
    internal.state_entry = entry.id;
    internal.has_state = true;
    return owned;
}

// =============================================================================
// Navigation Methods
// =============================================================================

/// Operation: go
/// HTML: "1. Let document be this's associated Document. 2. If document is
/// not fully active, then throw a SecurityError DOMException. 3. If delta is
/// 0, then reload document's node navigable, and return. 4. Traverse the
/// history by a delta given document's node navigable's traversable
/// navigable, delta, and with sourceDocument set to document."
pub fn call_go(instance: *runtime.Instance, delta: webidl.Opt(i32)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const bc = activeNavigable(internal) orelse return error.SecurityError;
    // Delta traverse step 3: "If history's relevant global object's
    // navigable's allowed to perform a navigation or history update returns
    // blocked, then return."
    if (!bc.allowedToNavigateOrUpdateHistory()) return;
    const delta_val: i32 = if (delta.wasPassed()) delta.getValue() else 0;
    const top = bc.getTop();
    // Stated exceptions to the spec's queue for reloads (golden rule 2: the
    // integrator's ruling of 2026-10-27 from lane nav2's three-browser probe,
    // tmp/probes/nav2-tth-probe.html, from the sixth of six top-level
    // entries - Chrome 156 | Firefox 158 | Safari 27: go0_middle [-2,0,-1]
    // 4 | 4 | 5, go0_last [-2,0] 4 | 4 | 6, go0_first [0,-2] 4 | 4 | 4).
    // HTML "reload" step 4 appends "apply the reload history step" behind
    // whatever is queued, and "traverse the history by a delta" step 4
    // appends behind the reload, so the queue would load the page again
    // after a pending traversal, and load it before a later one. Chrome and
    // Firefox, for a TOP-LEVEL traversable's own History:
    // - (a) history.go(0) while an earlier delta traversal that takes it to
    //   another document is pending is ignored (go0_middle, go0_last);
    // - (b) a delta traversal appended while a history.go(0) reload of it is
    //   queued or running cancels the reload (go0_first).
    // location.reload(), navigation.reload() and child navigables keep the
    // spec's queue (integrator, 2026-10-28, lane nav2 C2).
    if (delta_val == 0) {
        if (bc == top and apply_history_step.pendingCrossDocumentDelta(top, null) != null) return;
        // Step 3: "reload document's node navigable". Reload step 1: not
        // while unloading.
        const window = internal.window orelse return;
        reloadNavigable(window, bc, true);
        return;
    }
    // Delta traverse step 4 hands "apply the history step" this's associated
    // Document's navigable as initiatorToCheck. Deviation, stated (golden
    // rule 2, the browsers split): it is not checked here. Firefox 157 and
    // Safari 27 let a sandboxed frame's history.back() and forward()
    // traverse its parent's entries (iframe_sandbox_navigate_history_go_back
    // and _go_forward: both fail with "assert_unreached: no pop state" at
    // aligned wpt.fyi revision cc74d2669f); only Chrome 154 refuses. All
    // three refuse the navigation API's traversals (sandboxing-back-parent,
    // sandboxing-back-sibling: 1/1 each), which Navigation's traverseToKey
    // checks.
    // Stated exceptions to the spec's queue (golden rule 2: Chrome 156 and
    // Firefox 158 agree in every variant; Safari 27 coalesces everywhere,
    // WebKit bug 313808, and is outvoted). "Traverse the history by a delta"
    // step 4 appends every call, and the queue would apply each delta in turn
    // once the one before had finished. The browsers, while an earlier delta
    // traversal that takes a document elsewhere is pending (queued, or its
    // population in flight):
    // - of a TOP-LEVEL traversable: ignore further delta traversals - the
    //   first call's target wins (lane nav2's probes
    //   tmp/probes/nav2-tth-probe.html, tth2 -3,-2,+1 -> page 3 ... tth5, and
    //   nav2-axes-probe.html a/b: back(),back() -> p2, p1#2, one load; WPT
    //   html/browsers/history/the-history-interface/traverse_the_history_2..5);
    // - of a CHILD navigable, made through its own History: coalesce - the
    //   target is the pending target plus the new delta, range-checked from
    //   the pending target (out of range: ignored), replacing the pending
    //   traversal, so only the final target loads (nav2-axes-probe.html c-e:
    //   p1 with one load, whether the parent or the frame calls and whether
    //   the second step is cross- or same-document; WPT
    //   overlapping-navigations-and-traversals/cross-document-traversal-
    //   cross-document-traversal.html "-2 with only one load event" and
    //   cross-document-traversal-same-document-traversal.html "coalesced",
    //   both from WPT #36364). Chrome computes a renderer's offset from the
    //   pending entry (NavigationControllerImpl::GetIndexForOffset), and the
    //   new navigation replaces the pending one.
    // The navigation API's traversals, same-document delta traversals and
    // traversals of other navigables keep the queue. Integrator's rulings of
    // 2026-10-27 and 2026-10-28.
    if (apply_history_step.pendingCrossDocumentDelta(top, if (bc == top) null else bc.id)) |pending| {
        if (bc == top) return;
        apply_history_step.coalesceDelta(top, pending, delta_val);
        return;
    }
    // The reload rule (b) above.
    if (bc == top) _ = apply_history_step.cancelGoZeroReload(top);
    // Whether this one takes a document elsewhere, asked now. One out of
    // range is appended all the same - the queued steps ask again when they
    // run (step 4.4), and an earlier traversal may have made it valid - but
    // it is no pending traversal for the rules above (tth4's -10, tth5's +10).
    const history = ensureEntries(bc) catch return;
    const cross_document = if (history.stepByDelta(delta_val)) |target| apply_history_step.changesDocument(top, history, target) else false;
    apply_history_step.traverse(top, internal.allocator, .{ .delta = delta_val }, .{ .cross_document_delta = cross_document, .delta_navigable = bc.id });
}

/// HTML "reload" `bc`'s navigable: its current entry, repopulated by "apply
/// the reload history step" on the traversable's queue. Not while its
/// document is unloading (reload step 1). `go_zero`: history.go(0) asked
/// (the reload rules in call_go).
fn reloadNavigable(window: *runtime.Instance, bc: *BrowsingContext, go_zero: bool) void {
    reloadNavigableWithNavigationApiState(window, bc, null, go_zero);
}

fn reloadNavigableWithNavigationApiState(window: *runtime.Instance, bc: *BrowsingContext, navigation_api_state: ?joint_history.SerializedState, go_zero: bool) void {
    const document = interfaces.Window.get_document(window) catch return;
    if (@import("dom").document_lifecycle.isUnloading(document)) return;
    const history = ensureEntries(bc) catch return;
    const entry = history.currentEntry(bc.id) orelse return;
    // "Reload" step 1: no navigation here is "browser UI", so: "Let continue
    // be the result of firing a push/replace/reload navigate event at
    // navigation with navigationType set to "reload", isSameDocument set to
    // false, destinationURL set to navigable's active session history
    // entry's URL, and navigationAPIState set to destinationNavigationAPIState
    // ... If continue is false, then return." Copied: the event's handlers
    // can change the history.
    const allocator = bc.allocator;
    const url = allocator.dupe(u8, entry.url) catch return;
    defer allocator.free(url);
    const entry_id = entry.id;
    // Reload's destinationNavigationAPIState is the optional argument, or
    // the active entry's state. Clone before navigate runs script; the
    // current entry retains its old state until cancellation checks pass.
    var api_state = (navigation_api_state orelse entry.api_state).clone(allocator) catch return;
    defer api_state.deinit(allocator);
    // The Browser's list, asked again after script ran: `bc` may be freed.
    const id = bc.id;
    const navigables = bc.navigables orelse return;
    if (!@import("dom").navigation_api.firePushReplaceReload(window, .{
        .navigation_type = .reload,
        .destination_url = url,
        .is_same_document = false,
        .navigation_api_state = api_state,
    })) return;
    // The handlers ran script: the navigable may be gone.
    if (navigables.byId(id) != bc or bc.orphaned or bc.is_closed) return;
    // Steps 2-4: the entry's reload is pending, and "apply the reload
    // history step" is appended to the traversable's queue - beforeunload at
    // the navigable's document and its descendants' there, then the
    // population, which the item waits for. The navigation API state given
    // becomes the entry's once navigate and beforeunload permit it, the
    // entry captured before either handler ran.
    apply_history_step.reload(bc, allocator, entry_id, if (navigation_api_state != null) api_state else null, go_zero);
}

/// dom.history_traversal: reload `window`'s navigable.
fn reloadWindow(window: *runtime.Instance) void {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    reloadNavigable(window, bc, false);
}

/// dom.history_traversal: navigation.reload()'s borrowed serialized state.
fn reloadWindowWithNavigationApiState(window: *runtime.Instance, state: joint_history.SerializedState) void {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    reloadNavigableWithNavigationApiState(window, bc, state, false);
}

/// dom.history_traversal: queue a traversal of `window`'s traversable to
/// `step` (the navigation API's "perform a navigation API traversal"), with
/// its key's checks (`api`, taken).
fn traverseWindowToStep(window: *runtime.Instance, step: u32, api: ?@import("dom").history_traversal.ApiTraversal) void {
    const drop = struct {
        fn of(a: ?@import("dom").history_traversal.ApiTraversal) void {
            if (a) |given| given.drop(given.context);
        }
    }.of;
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return drop(api);
    const history_instance = interfaces.Window.get_history(window) catch return drop(api);
    const internal = getInternal(history_instance) orelse return drop(api);
    apply_history_step.traverse(bc.getTop(), internal.allocator, .{ .step = step }, .{
        .initiator = initiatorOf(window, bc),
        .api = api,
        .api_navigable = bc.id,
    });
}

/// dom.history_traversal: "resume applying the traverse history step" to
/// `step` - an intercepted traverse navigate event's commit - without firing
/// the navigate event again.
fn resumeTraversalOfWindow(window: *runtime.Instance, step: u32) void {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    apply_history_step.traverse(bc.getTop(), internal.allocator, .{ .step = step }, .{ .resumed = true });
}

/// dom.history_traversal: the URL and history update steps for `window`'s
/// document - committing an intercepted push or replace navigate event.
/// `serialized` is BORROWED.
fn urlAndHistoryUpdateOfWindow(window: *runtime.Instance, url: []const u8, serialized: ?joint_history.SerializedState, handling: joint_history.HistoryHandling) void {
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    const bc = activeNavigable(internal) orelse return;
    const history = ensureEntries(bc) catch return;
    const active = history.currentEntry(bc.id) orelse return;
    // URL and history update steps 3 and 8: absent serializedData preserves
    // both the old serialized state and the History object's cached value.
    const given: joint_history.SerializedState = serialized orelse active.state;
    const data = given.clone(internal.allocator) catch return;
    urlAndHistoryUpdate(internal, bc, window, url, data, handling, serialized != null) catch |err| {
        log.debug("history: the URL and history update steps failed: {s}", .{@errorName(err)});
    };
}

/// Operation: back - "go(-1)".
pub fn call_back(instance: *runtime.Instance) anyerror!void {
    return call_go(instance, webidl.Opt(i32).passed(-1));
}

/// Operation: forward - "go(1)".
pub fn call_forward(instance: *runtime.Instance) anyerror!void {
    return call_go(instance, webidl.Opt(i32).passed(1));
}

/// Operation: pushState
pub fn call_pushState(instance: *runtime.Instance, data: runtime.JSValue, unused: runtime.DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
    _ = unused;
    return sharedPushReplaceState(instance, data, url, .push);
}

/// Operation: replaceState
pub fn call_replaceState(instance: *runtime.Instance, data: runtime.JSValue, unused: runtime.DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
    _ = unused;
    return sharedPushReplaceState(instance, data, url, .replace);
}

/// How deeply pushState()/replaceState() calls are nested on this thread: a
/// navigate event handler that calls them fires another navigate event.
threadlocal var push_replace_depth: u32 = 0;

/// Step 3's "optionally, throw a SecurityError", taken for calls nested this
/// deep - a navigate handler that pushes or replaces from inside the event
/// its own call fired recurses without end otherwise, as browsers' rate
/// limits also stop (navigate-event/replaceState-inside-back-handler-infinite).
const max_push_replace_depth = 16;

/// HTML "shared history push/replace state steps".
fn sharedPushReplaceState(instance: *runtime.Instance, data: runtime.JSValue, url: webidl.Opt(?runtime.USVString), handling: joint_history.HistoryHandling) !void {
    // Step 3: "Optionally, throw a SecurityError DOMException."
    if (push_replace_depth >= max_push_replace_depth) return error.SecurityError;
    push_replace_depth += 1;
    defer push_replace_depth -= 1;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let document be history's associated Document. If document is
    // not fully active, then throw a SecurityError DOMException."
    const navigable = activeNavigable(internal) orelse return error.SecurityError;
    const window = internal.window orelse return error.SecurityError;
    const document = try interfaces.Window.get_document(window);
    const allocator = internal.allocator;

    // Step 3: "Let serializedData be StructuredSerializeForStorage(data)."
    // Rethrown: a DataCloneError not yet thrown is the binding's to throw.
    var serialized = try navigation_entries.serialize(engine.currentRealm() orelse window.ctx, allocator, data);
    errdefer serialized.deinit(allocator);

    // Step 4: "Let newURL be document's URL."
    const document_url = try documentUrl(document, allocator);
    defer allocator.free(document_url);
    var new_url: []u8 = try allocator.dupe(u8, document_url);
    defer allocator.free(new_url);

    // Step 5: "If url is not null or the empty string" - parse it relative to
    // the relevant settings object; failure, or a URL document's URL cannot
    // be rewritten to, is a SecurityError.
    if (url.wasPassed()) {
        if (url.getValue()) |given| {
            if (given.len > 0) {
                const parsed = try parseRelativeTo(document, given, allocator);
                if (!navigate_steps.canHaveUrlRewritten(document_url, parsed)) {
                    allocator.free(parsed);
                    return error.SecurityError;
                }
                allocator.free(new_url);
                new_url = parsed;
            }
        }
    }

    // Step 6: "If history's relevant global object's navigable's allowed to
    // perform a navigation or history update returns blocked, then return" -
    // after the state is serialized and the URL parsed, which throw first
    // (history_pushstate_too_many_calls_ordering.optional.html).
    if (!navigable.allowedToNavigateOrUpdateHistory()) {
        serialized.deinit(allocator);
        return;
    }

    // Steps 7-9: "Let continue be the result of firing a push/replace/reload
    // navigate event at navigation with navigationType set to
    // historyHandling, isSameDocument set to true, destinationURL set to
    // newURL, and classicHistoryAPIState set to serializedData. If continue
    // is false, then return." An intercepted event runs the URL and history
    // update steps itself, when it commits.
    const continue_navigation = @import("dom").navigation_api.firePushReplaceReload(window, .{
        .navigation_type = switch (handling) {
            .push => .push,
            .replace => .replace,
        },
        .destination_url = new_url,
        .is_same_document = true,
        .classic_history_api_state = serialized,
    });
    if (!continue_navigation) {
        serialized.deinit(allocator);
        return;
    }
    // The event's handlers ran script: the History's document may no longer
    // be fully active.
    const still = activeNavigable(internal) orelse {
        serialized.deinit(allocator);
        return;
    };

    // Step 10: "Run the URL and history update steps given document and
    // newURL, with serializedData set to serializedData and historyHandling
    // set to historyHandling."
    try urlAndHistoryUpdate(internal, still, window, new_url, serialized, handling, true);
}

/// `url` parsed relative to `document`'s base URL and serialized; owned.
fn parseRelativeTo(document: *runtime.Instance, url: []const u8, allocator: Allocator) ![]u8 {
    const base = interfaces.Node.get_baseURI(document) catch "";
    defer if (base.len > 0) document.ctx.allocator.free(base);
    var base_record = if (base.len > 0) basic_parser.parse(allocator, base, null) catch null else null;
    defer if (base_record) |*b| b.deinit();
    var parsed = basic_parser.parse(allocator, url, if (base_record) |*b| b else null) catch return error.SecurityError;
    defer parsed.deinit();
    return @constCast(try url_serializer.serialize(allocator, &parsed, false));
}

/// HTML "URL and history update steps" given the History's document and
/// `new_url`, taking `serialized`. The document's URL changes now; the entry
/// is pushed or replaced in the traversable's history - always replaced on
/// an initial about:blank document (step 4).
fn urlAndHistoryUpdate(
    internal: *InternalState,
    bc: *BrowsingContext,
    window: *runtime.Instance,
    new_url: []const u8,
    serialized: joint_history.SerializedState,
    handling: joint_history.HistoryHandling,
    restore_state: bool,
) !void {
    // Step 4: "If document's is initial about:blank is true, then set
    // historyHandling to "replace"." - pushState() on an initial about:blank
    // document behaves as replaceState(), wherever that document's
    // navigable's entry sits in the joint session history.
    const effective: joint_history.HistoryHandling = blk: {
        const document = interfaces.Window.get_document(window) catch break :blk handling;
        break :blk if (@import("dom").document_lifecycle.isInitialAboutBlank(document)) .replace else handling;
    };
    const history = try ensureEntries(bc);
    // The new entry's navigation API state is a fresh one (the URL and
    // history update steps do not carry it over).
    try history.commitSameDocument(bc.id, new_url, serialized, effective, .undefined);
    // Step 7: "Restore the history object state" - the next read deserializes
    // the new entry's state.
    if (restore_state) {
        internal.has_state = false;
    } else if (history.currentEntry(bc.id)) |entry| {
        internal.state_entry = entry.id;
    }
    // Step 8: "Set document's URL to newURL."
    setDocumentUrl(window, new_url);
    // Step 9: "Update the navigation API entries for a same-document
    // navigation given document's relevant global object's navigation API,
    // newEntry, and historyHandling."
    @import("dom").navigation_api.sameDocumentNavigation(window, switch (effective) {
        .push => .push,
        .replace => .replace,
    });
}

/// Set the URL of `window`'s associated Document - which its realm records,
/// and its Location reads. A same-document change: the realm's creation URL
/// (the cookie URL) stays the document's at creation.
fn setDocumentUrl(window: *runtime.Instance, url: []const u8) void {
    window.ctx.updateDocumentUrl(url) catch |err| log.warn("history: the document URL was not recorded: {s}", .{@errorName(err)});
}

// =============================================================================
// Traversal
// =============================================================================

/// The initiator a traversal `window`'s document asks for carries, for the
/// navigable `bc` ("apply the history step"'s initiatorToCheck and its
/// source snapshot params: the document's active sandboxing flag set and
/// whether its window had transient activation, as it asked): null when the
/// document is not sandboxed - an empty sandboxing flag set allows every
/// navigation, so there is nothing to check.
fn initiatorOf(window: ?*runtime.Instance, bc: *BrowsingContext) ?apply_history_step.Initiator {
    const w = window orelse return null;
    const document = interfaces.Window.get_document(w) catch return null;
    const flags = @import("dom").document_scripts.activeSandboxingFlags(document);
    if (flags.isEmpty()) return null;
    return .{ .navigable = bc.id, .snapshot = .{
        .sandboxing_flags = flags,
        .has_transient_activation = @import("html").user_activation.hasTransientActivation(w),
    } };
}

/// dom.history_traversal queue_task: "queue a global task on the navigation
/// and traversal task source" of `navigable`'s active window - or, with
/// none (its realm is being replaced, or it shows no document), on the loop
/// its traversable's queue is serviced on: the traversable's active
/// window's, a window's in its own tree, and only then any window's of the
/// same Browser, whose window realms share one agent loop (integrator,
/// conditions 3 and its 2026-10-28 refinement). Never inline.
fn queueApplyTask(navigables: *Navigables, navigable: *BrowsingContext, task: @import("dom").history_traversal.Task) bool {
    const loop = loopOfContext(navigable) orelse serviceLoopOf(navigables, navigable.getTop()) orelse return false;
    loop.queueTask(.{ .callback = task.callback, .context = task.context, .drop = task.drop });
    return true;
}

/// The loop `queueApplyTask` falls back to (TraversalQueue.serviceContext's
/// order).
fn serviceLoopOf(navigables: *Navigables, top: *BrowsingContext) ?runtime.EventLoop {
    const bc = traversal_queue.TraversalQueue.serviceContext(navigables, top, {}, hasLoop) orelse return null;
    return loopOfContext(bc);
}

fn hasLoop(_: void, bc: *BrowsingContext) bool {
    return loopOfContext(bc) != null;
}

fn loopOfContext(bc: *BrowsingContext) ?runtime.EventLoop {
    const w = bc.getActiveWindow() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(w));
    return window.ctx.getOptionalEventLoop();
}

/// Beforeunload at the active document of each of `contexts`, in order:
/// whether any was canceled ("checking if unloading is canceled" -
/// "continue" unless a prompt was shown and the user stayed; none is shown
/// without sticky activation). The documents are taken before any handler
/// runs - script can take a frame away - and each is skipped if it went.
fn beforeUnloadCanceled(contexts: []const *BrowsingContext, allocator: Allocator) bool {
    const Held = struct { document: *runtime.Instance, generation: u64 };
    var documents: std.ArrayListUnmanaged(Held) = .empty;
    defer documents.deinit(allocator);
    for (contexts) |bc| {
        const document: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveDocument() orelse continue));
        documents.append(allocator, .{ .document = document, .generation = runtime.SlabAllocator.generationOf(document) }) catch return false;
    }
    var canceled = false;
    for (documents.items) |held| {
        if (runtime.SlabAllocator.generationOf(held.document) != held.generation) continue;
        if (@import("dom").document_lifecycle.fireBeforeUnload(held.document).canceled) canceled = true;
    }
    return canceled;
}

/// "Update document for history step application" for a same-document
/// entry (step 6): the document's URL becomes the entry's, history.state its
/// state, and popstate fires at the window - then hashchange, as a task, if
/// the fragment changed.
fn sameDocumentTraversal(bc: *BrowsingContext, old_url: []const u8, entry: *joint_history.Entry) void {
    const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return));
    // Steps 3-4 and 6.4.2: the document's History length and index and its
    // navigation API entries are the traversable's now - its view, held
    // since the traversal began (JointHistory.holdView), is written.
    if (bc.getTop().joint_history) |history| history.releaseView(bc.id);
    // The traversal task switches into each changed navigable's realm.
    var traversal: SameDocumentTraversal = .{ .window = window, .old_url = old_url, .entry = entry };
    engine.runInRealm(window.ctx, SameDocumentTraversal.steps, &traversal) catch |err| {
        log.debug("history: same-document traversal not applied: {s}", .{@errorName(err)});
    };
}

/// sameDocumentTraversal's steps, in the window's realm.
const SameDocumentTraversal = struct {
    window: *runtime.Instance,
    old_url: []const u8,
    entry: *joint_history.Entry,

    fn steps(data: ?*anyopaque) void {
        const self: *SameDocumentTraversal = @ptrCast(@alignCast(data.?));
        applySameDocumentEntry(self.window, self.old_url, self.entry);
    }
};

fn applySameDocumentEntry(window: *runtime.Instance, old_url: []const u8, entry: *joint_history.Entry) void {
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;

    // Copied: popstate's handlers can push entries, which moves them.
    const allocator = internal.allocator;
    const new_url = allocator.dupe(u8, entry.url) catch return;
    defer allocator.free(new_url);

    setDocumentUrl(window, new_url);
    // 6.3: "Restore the history object state given document and entry."
    internal.has_state = false;
    const kept_state: ?engine.Owned = stateValue(history_instance, internal, entry) catch null;
    defer if (kept_state) |k| k.release();
    const state = if (kept_state) |k| k.value else runtime.JSValue.jsNull;
    // 6.4.1: "Update the navigation API entries for a same-document
    // navigation given navigation, entry, and "traverse"" - before popstate.
    @import("dom").navigation_api.sameDocumentNavigation(window, .traverse);
    // 6.4.3: popstate, with the state.
    const event = interfaces.PopStateEvent.call_constructor(
        window.ctx,
        runtime.DOMString.initInterned("popstate"),
        webidl.Opt(dictionaries.PopStateEventInit).passed(.{ .base = .{}, .state = state }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(window, event) catch {};
    event.releaseIfUnwrapped(generation);

    // 6.4.5: hashchange, when the fragment changed.
    const old_fragment = navigate_steps.fragmentOf(old_url) orelse "";
    const new_fragment = navigate_steps.fragmentOf(new_url) orelse "";
    if (!std.mem.eql(u8, old_fragment, new_fragment)) queueHashChange(window, old_url, new_url);
}

/// A queued hashchange at a window, held with its slab generation.
const HashChange = struct {
    window: *runtime.Instance,
    generation: u64,
    old_url: []u8,
    new_url: []u8,
    allocator: Allocator,

    fn destroy(self: *HashChange) void {
        self.allocator.free(self.old_url);
        self.allocator.free(self.new_url);
        self.allocator.destroy(self);
    }
};

fn queueHashChange(window: *runtime.Instance, old_url: []const u8, new_url: []const u8) void {
    const allocator = window.ctx.allocator;
    const task = allocator.create(HashChange) catch return;
    const old_copy = allocator.dupe(u8, old_url) catch {
        allocator.destroy(task);
        return;
    };
    const new_copy = allocator.dupe(u8, new_url) catch {
        allocator.free(old_copy);
        allocator.destroy(task);
        return;
    };
    task.* = .{
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .old_url = old_copy,
        .new_url = new_copy,
        .allocator = allocator,
    };
    const loop = window.ctx.getOptionalEventLoop() orelse return runHashChange(task);
    loop.queueTask(.{ .callback = &runHashChange, .context = task, .drop = &dropHashChange });
}

fn dropHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    task.destroy();
}

fn runHashChange(context: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(context orelse return));
    defer task.destroy();
    if (runtime.SlabAllocator.generationOf(task.window) != task.generation) return;
    // A global task of the window: it runs in the window's realm.
    engine.runTaskInRealm(task.window.ctx, fireHashChange, task) catch |err| log.debug("history: hashchange not fired: {s}", .{@errorName(err)});
}

fn fireHashChange(data: ?*anyopaque) void {
    const task: *HashChange = @ptrCast(@alignCast(data.?));
    const event = interfaces.HashChangeEvent.call_constructor(
        task.window.ctx,
        runtime.DOMString.initInterned("hashchange"),
        webidl.Opt(dictionaries.HashChangeEventInit).passed(.{ .base = .{}, .oldURL = task.old_url, .newURL = task.new_url }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = @import("dom").fire_event.dispatchTrusted(task.window, event) catch {};
    event.releaseIfUnwrapped(generation);
}
