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
//! Traversal runs here: every navigable of the traversable whose entry at the
//! target step differs from its current one changes. One that stays on its
//! document - a pushState or fragment entry - has its URL and state restored
//! and hears popstate (and hashchange); one that changes documents is
//! navigated to its entry's URL by the navigation engine
//! (dom.navigables.traverseNavigable), since Crane keeps no document for
//! traversal (no bfcache).

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
    if (delta_val == 0) {
        // Step 3: "reload document's node navigable" - its current entry,
        // repopulated from the entry's URL: a traversal of the navigable to
        // the entry it is on. Reload step 1: not while unloading. A
        // navigable the engine has no navigation for - the top-level page -
        // is not reloaded, stated.
        const window = internal.window orelse return;
        reloadNavigable(window, bc);
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
    const top = bc.getTop();
    // Stated exception to the spec's queue (golden rule 2; the integrator's
    // ruling of 2026-10-27 on traverse_the_history_2-5): while an earlier
    // delta traversal of this traversable that changes some navigable's
    // document is queued or running - until that document is active - a
    // further history.go()/back()/forward() is ignored. "Traverse the
    // history by a delta" step 4 would append it, and the queue would apply
    // every delta in turn. Chrome 156 and Firefox 158 land on the FIRST
    // call's target for three calls in one task, in separate tasks, and from
    // the leaving page's pagehide (lane nav2's probe,
    // tmp/probes/nav2-tth-probe.html: tth2 -3,-2,+1 -> page 3; tth3 -2,-1,+3
    // -> 4; tth4 -10,-1,-2 -> 5; tth5 +10,-1,-2 -> 5; the same with each
    // call in its own task; Chrome also from pagehide); Safari 27 sums them
    // (WebKit bug 313808) and is outvoted. WPT
    // html/browsers/history/the-history-interface/traverse_the_history_2..5
    // expect the browsers' result. Scope: delta traversals only, and only
    // while the earlier one is cross-document - the navigation API's
    // traversals and same-document traversals keep the spec's queue.
    if (crossDocumentDeltaPending(top)) return;
    // Step 4.4 asked now: a delta past either end is ignored, and is no
    // earlier traversal for the exception (tth4's -10, tth5's +10). The
    // queued steps ask again when they run.
    const history = ensureEntries(bc) catch return;
    const target = history.stepByDelta(delta_val) orelse return;
    appendTraversal(internal, top, .{ .delta = delta_val }, false, null, changesDocument(top, history, target));
}

/// HTML "reload" `bc`'s navigable: its current entry, repopulated - a
/// traversal of the navigable to the entry it is on. Not while its document
/// is unloading (reload step 1).
fn reloadNavigable(window: *runtime.Instance, bc: *BrowsingContext) void {
    reloadNavigableWithNavigationApiState(window, bc, null);
}

fn reloadNavigableWithNavigationApiState(window: *runtime.Instance, bc: *BrowsingContext, navigation_api_state: ?joint_history.SerializedState) void {
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
    if (!@import("dom").navigation_api.firePushReplaceReload(window, .{
        .navigation_type = .reload,
        .destination_url = url,
        .is_same_document = false,
        .navigation_api_state = api_state,
    })) return;
    // "Apply the reload history step" (apply the history step, with
    // checkForCancelation): beforeunload at the navigable's document and its
    // descendants', before anything unloads; the navigation below does not
    // fire it again.
    const id = bc.id;
    const top_id = bc.getTop().id;
    // The Browser's list, asked again after script ran: `bc` may be freed.
    const navigables = bc.navigables orelse return;
    {
        var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
        defer tree.deinit(bc.allocator);
        bc.collectDescendants(bc.allocator, &tree) catch return;
        if (beforeUnloadCanceled(tree.items, bc.allocator)) return;
    }
    // The handlers ran script: the navigable - or its traversable, which
    // owns `history` - may be gone.
    if (navigables.byId(id) != bc or bc.orphaned or bc.is_closed) return;
    if (navigables.byId(top_id) == null) return;
    const current = history.entryById(entry_id) orelse return;
    if (navigation_api_state != null) {
        // Apply the reload history step only after navigate/beforeunload
        // permit it, to the entry captured before either handler ran.
        history.setEntryApiState(entry_id, api_state);
        api_state = .undefined;
    }
    // A reload's previousEntry is the entry it reloads.
    _ = @import("dom").navigables.traverseNavigable(@ptrCast(bc), current.id, current.url, current.resource, current.id, null);
}

/// dom.history_traversal: reload `window`'s navigable.
fn reloadWindow(window: *runtime.Instance) void {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    reloadNavigable(window, bc);
}

/// dom.history_traversal: navigation.reload()'s borrowed serialized state.
fn reloadWindowWithNavigationApiState(window: *runtime.Instance, state: joint_history.SerializedState) void {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    reloadNavigableWithNavigationApiState(window, bc, state);
}

/// dom.history_traversal: queue a traversal of `window`'s traversable to
/// `step` (the navigation API's "perform a navigation API traversal").
fn traverseWindowToStep(window: *runtime.Instance, step: u32) void {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    appendTraversal(internal, bc.getTop(), .{ .step = step }, false, initiatorOf(window, bc), false);
}

/// dom.history_traversal: "resume applying the traverse history step" to
/// `step` - an intercepted traverse navigate event's commit - without firing
/// the navigate event again.
fn resumeTraversalOfWindow(window: *runtime.Instance, step: u32) void {
    const bc = @import("dom").browser_state.browsingContextOf(window) orelse return;
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    appendTraversal(internal, bc.getTop(), .{ .step = step }, true, null, false);
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

/// Where a traversal goes: `delta` used steps away from the current one
/// ("traverse the history by a delta"), or to a given step (the navigation
/// API's traversals).
const Target = union(enum) {
    delta: i32,
    step: u32,
};

/// A traversal on the traversable's session history traversal queue
/// (html_core traversal_queue): "append session history traversal steps"
/// for "traverse the history by a delta" and the navigation API's
/// traversals. One item per traversal; it runs from the queue's service
/// task, and waits for the populations of the navigables it takes to
/// another document before the queue runs the next ("apply the history
/// step" 12.8 and 14: lane nav2 C1).
const TraversalItem = struct {
    item: traversal_queue.Item,
    /// The traversable's Browser's list, which outlives every task of its
    /// loop: the traversable is looked up by id on it.
    navigables: *Navigables,
    top_id: u64,
    target: Target,
    allocator: Allocator,
    /// "Resume applying the traverse history step": the traversable's
    /// navigate event was fired and intercepted; it is not fired again.
    resumed: bool,
    /// "Apply the history step"'s initiatorToCheck with its source snapshot
    /// params; null for a traversal no sandboxed document asked for.
    initiator: ?Initiator = null,
    /// A delta traversal ("traverse the history by a delta") whose target
    /// step, when it was appended, took some navigable to another document:
    /// the go() exception's earlier traversal (`crossDocumentDeltaPending`).
    cross_document_delta: bool = false,

    fn run(item: *traversal_queue.Item) traversal_queue.Outcome {
        const self: *TraversalItem = @fieldParentPtr("item", item);
        return runTraversal(self);
    }

    fn destroy(item: *traversal_queue.Item) void {
        const self: *TraversalItem = @fieldParentPtr("item", item);
        self.allocator.destroy(self);
    }
};

/// The navigable whose document asked for a traversal - by id: it can go
/// before the traversal runs - and that document's source snapshot params:
/// its active sandboxing flag set and whether its window had transient
/// activation, as it asked.
const Initiator = struct {
    navigable: u64,
    snapshot: html_core.navigation.sandbox_navigation.SourceSnapshot,
};

/// The initiator a traversal `window`'s document asks for carries, for the
/// navigable `bc`: null when the document is not sandboxed - an empty
/// sandboxing flag set allows every navigation, so there is nothing to check.
fn initiatorOf(window: ?*runtime.Instance, bc: *BrowsingContext) ?Initiator {
    const w = window orelse return null;
    const document = interfaces.Window.get_document(w) catch return null;
    const flags = @import("dom").document_scripts.activeSandboxingFlags(document);
    if (flags.isEmpty()) return null;
    return .{ .navigable = bc.id, .snapshot = .{
        .sandboxing_flags = flags,
        .has_transient_activation = @import("html").user_activation.hasTransientActivation(w),
    } };
}

/// "Append session history traversal steps" to `top`'s queue: a traversal
/// to `target`. Out of memory, or with no queue to append to (a traversable
/// on no Browser's list), nothing is appended - as a task that could not be
/// queued.
fn appendTraversal(internal: *InternalState, top: *BrowsingContext, target: Target, resumed: bool, initiator: ?Initiator, cross_document_delta: bool) void {
    const navigables = top.navigables orelse return;
    const queue = top.traversalQueue(&scheduleTraversalService) catch return;
    const task = internal.allocator.create(TraversalItem) catch return;
    task.* = .{
        .item = .{ .run = &TraversalItem.run, .destroy = &TraversalItem.destroy },
        .navigables = navigables,
        .top_id = top.id,
        .target = target,
        .allocator = internal.allocator,
        .resumed = resumed,
        .initiator = initiator,
        .cross_document_delta = cross_document_delta,
    };
    _ = queue.append(&task.item);
}

/// Whether a delta traversal of `top` that takes some navigable to another
/// document is queued or running (the go() exception in `call_go`).
fn crossDocumentDeltaPending(top: *BrowsingContext) bool {
    const queue = top.traversal_queue orelse return false;
    if (queue.running) |item| {
        if (isCrossDocumentDelta(item)) return true;
    }
    for (queue.items.items) |item| {
        if (isCrossDocumentDelta(item)) return true;
    }
    return false;
}

fn isCrossDocumentDelta(item: *traversal_queue.Item) bool {
    if (item.run != &TraversalItem.run) return false;
    const traversal: *TraversalItem = @fieldParentPtr("item", item);
    return traversal.target == .delta and traversal.cross_document_delta;
}

/// Whether applying `step` would take some navigable of `top`'s tree to
/// another document: its entry there differs from its current one and is
/// not on the document it shows.
fn changesDocument(top: *BrowsingContext, history: *joint_history.JointHistory, step: u32) bool {
    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(top.allocator);
    top.collectDescendants(top.allocator, &tree) catch return false;
    for (tree.items) |bc| {
        const current = history.currentEntry(bc.id) orelse continue;
        const target_entry = history.entryAt(bc.id, step) orelse continue;
        if (current == target_entry) continue;
        const same_document = current.document_state == target_entry.document_state and
            target_entry.document != null and target_entry.document == bc.getActiveDocument();
        if (!same_document) return true;
    }
    return false;
}

/// The queue's schedule (traversal_queue.Schedule): one service task on an
/// event loop of the traversable's Browser - the traversable's active
/// window's; with none (its realm is being replaced, or it shows no
/// document), a window's in the traversable's own tree; and only then any
/// window's of the same Browser, whose window realms share one agent loop
/// (integrator, conditions 3 and its 2026-10-28 refinement). Never inline.
fn scheduleTraversalService(navigables: *Navigables, traversable_id: u64) bool {
    const top = navigables.byId(traversable_id) orelse return false;
    const loop = serviceLoopOf(navigables, top) orelse return false;
    const allocator = navigables.allocator;
    const task = allocator.create(ServiceTask) catch return false;
    task.* = .{ .navigables = navigables, .traversable_id = traversable_id, .allocator = allocator };
    loop.queueTask(.{ .callback = &ServiceTask.run, .context = task, .drop = &ServiceTask.drop });
    return true;
}

/// The loop `scheduleTraversalService` queues on, if any
/// (TraversalQueue.serviceContext's order).
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

/// The queue's service task: by the traversable's id, never a pointer to
/// its queue.
const ServiceTask = struct {
    navigables: *Navigables,
    traversable_id: u64,
    /// Its own copy: a task dropped at teardown reads nothing else.
    allocator: Allocator,

    fn run(context: ?*anyopaque) void {
        const self: *ServiceTask = @ptrCast(@alignCast(context orelse return));
        const navigables = self.navigables;
        const id = self.traversable_id;
        self.allocator.destroy(self);
        traversal_queue.TraversalQueue.service(navigables, id);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *ServiceTask = @ptrCast(@alignCast(context orelse return));
        self.allocator.destroy(self);
    }
};

/// A navigable that changes entry in a traversal - by id: the changes run
/// script (traverse navigate events, popstate), which can remove a frame
/// and free its browsing context before the next change is applied.
const Change = struct {
    navigable: u64,
    old_url: []u8,
    /// The entry the navigable is on before the traversal (12.1's
    /// previousEntry).
    from_entry: u64,
    target_entry: u64,
    same_document: bool,
    /// The target entry's origin is the current entry's.
    same_origin: bool,
};

/// "Apply the traverse history step" (HTML 7.4.6), without bfcache: every
/// navigable whose target entry differs from its current one changes -
/// within its document when the entry shares the document state, else by a
/// navigation to the entry's URL. A navigable under one that changes
/// documents is not looked at: it goes with its parent's document.
/// Not modelled, stated: history-action activation for the traversable's
/// navigate event.
fn runTraversal(task: *TraversalItem) traversal_queue.Outcome {
    const allocator = task.allocator;
    const navigables = task.navigables;
    const top = navigables.byId(task.top_id) orelse return .done;
    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(allocator);
    top.collectDescendants(allocator, &tree) catch return .done;

    const history = top.jointHistory() catch return .done;
    for (tree.items) |bc| _ = ensureEntries(bc) catch {};

    // Steps 2-4: the target step.
    const target = switch (task.target) {
        .delta => |delta| history.stepByDelta(delta) orelse return .done,
        .step => |step| step,
    };

    // "Apply the history step" step 3: "If initiatorToCheck is not null ...
    // for each navigable of get all navigables whose current session history
    // entry will change or reload: if initiatorToCheck is not allowed by
    // sandboxing to navigate navigable given sourceSnapshotParams, then
    // return "initiator-disallowed"." An initiator gone since it asked is
    // allowed nothing.
    if (task.initiator) |initiator| {
        const source = navigables.byId(initiator.navigable) orelse return .done;
        for (tree.items) |bc| {
            const current = history.currentEntry(bc.id) orelse continue;
            const target_entry = history.entryAt(bc.id, target) orelse continue;
            if (current == target_entry) continue;
            if (!html_core.navigation.sandbox_navigation.allowedBySandboxingToNavigate(source, bc, initiator.snapshot)) return .done;
        }
    }

    // Step 5, "checking if unloading is canceled" step 4: the traversable's
    // navigate event, when its entry changes within its origin. Canceled -
    // or intercepted, whose commit resumes the traversal - and the
    // traversal ends here.
    if (!task.resumed) {
        const current = history.currentEntry(top.id);
        const target_entry = history.entryAt(top.id, target);
        if (current != null and target_entry != null and current.? != target_entry.? and
            std.mem.eql(u8, current.?.origin, target_entry.?.origin))
        {
            if (top.getActiveWindow()) |w| {
                const window: *runtime.Instance = @ptrCast(@alignCast(w));
                if (!@import("dom").navigation_api.fireTraverse(window, target_entry.?.id, .none)) return .done;
            }
        }
    }

    // Step 6: the navigables that change, parents first.
    var changes: std.ArrayListUnmanaged(Change) = .empty;
    defer {
        for (changes.items) |c| allocator.free(c.old_url);
        changes.deinit(allocator);
    }
    var skipped: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer skipped.deinit(allocator);
    for (tree.items) |bc| {
        if (bc.parent) |parent| {
            if (std.mem.indexOfScalar(*BrowsingContext, skipped.items, parent) != null) {
                skipped.append(allocator, bc) catch return .done;
                continue;
            }
        }
        const current = history.currentEntry(bc.id) orelse continue;
        const target_entry = history.entryAt(bc.id, target) orelse continue;
        if (current == target_entry) continue;
        const same_document = current.document_state == target_entry.document_state and
            target_entry.document != null and target_entry.document == bc.getActiveDocument();
        const old_url = allocator.dupe(u8, current.url) catch return .done;
        changes.append(allocator, .{
            .navigable = bc.id,
            .old_url = old_url,
            .from_entry = current.id,
            .target_entry = target_entry.id,
            .same_document = same_document,
            .same_origin = std.mem.eql(u8, current.origin, target_entry.origin),
        }) catch {
            allocator.free(old_url);
            return .done;
        };
        if (!same_document) skipped.append(allocator, bc) catch return .done;
    }

    // "Apply the history step" step 7, with checkForCancelation: "checking
    // if unloading is canceled" for the navigables the traversal takes to
    // another document - beforeunload at each one's active document and its
    // descendants' (`skipped`, parents first) - after the traversable's
    // navigate event and before the other navigables' (step 12.7). Canceled:
    // the traversal ends with nothing changed. The navigations below do not
    // fire it again.
    if (beforeUnloadCanceled(skipped.items, allocator)) return .done;
    // The handlers ran script: the traversable - and its history - may be
    // gone.
    if (navigables.byId(task.top_id) != top) return .done;

    // Each changing navigable's document keeps reading the history it saw
    // until its target entry's document is active ("update document for
    // history step application"): its view is held until then -
    // released by the same-document steps below, a cross-document
    // population's commit or end, or this item's end.
    for (changes.items) |change| history.holdView(change.navigable);
    var any_wait = false;

    // Step 20: the traversable's current session history step. Deviation,
    // stated: set here, before the navigables change, not after they have
    // (lane nav2 C1 keeps today's place; the held views keep what each
    // changing document reads).
    history.setCurrentStep(target);

    for (changes.items) |change| {
        // Looked up again for each change: an earlier change's script may
        // have removed the navigable (a discarded one is closed) - or its
        // traversable.
        const navigable = navigables.byId(change.navigable) orelse continue;
        if (navigable.orphaned or navigable.is_closed) continue;
        if (navigables.byId(task.top_id) != top) return .done;
        // Step 12.7: a navigable other than the traversable whose entry
        // changes within its origin fires a traverse navigate event (not
        // cancelable).
        if (navigable != top and change.same_origin) {
            if (navigable.getActiveWindow()) |w| {
                _ = @import("dom").navigation_api.fireTraverse(@ptrCast(@alignCast(w)), change.target_entry, .none);
            }
            // The event's listeners ran script: the traversable - and the
            // history it owns - may be gone, the navigable too.
            if (navigables.byId(task.top_id) != top) return .done;
            if (navigables.byId(change.navigable) != navigable or navigable.orphaned or navigable.is_closed) continue;
        }
        const entry = history.entryById(change.target_entry) orelse continue;
        if (change.same_document) {
            sameDocumentTraversal(navigable, change.old_url, entry);
            continue;
        }
        // Step 12.8: populate the entry's document - a navigation, whose end
        // this item waits for. The wait is recorded first: the population
        // can end inside the call.
        const TraversalQueue = traversal_queue.TraversalQueue;
        const waiting = TraversalQueue.waitFor(navigables, task.top_id, task.item.token, change.navigable);
        if (waiting) any_wait = true;
        const started = @import("dom").navigables.traverseNavigable(@ptrCast(navigable), entry.id, entry.url, entry.resource, change.from_entry, if (waiting) .{ .traversable_id = task.top_id, .token = task.item.token } else null);
        if (!started) TraversalQueue.populationEnded(navigables, task.top_id, task.item.token, change.navigable);
    }
    // Waiting while any population it started is in flight: the queue
    // finishes it when the last one ends - once its run returns, if all
    // ended inside it.
    return if (any_wait) .pending else .done;
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
