//! Implementation for History interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-history-interface
//!
//! A History reads and changes the session history of its window's
//! navigable's traversable (`html_core` JointHistory, kept on the top-level
//! BrowsingContext): length and index from the traversable's used steps,
//! state from the navigable's current entry, pushState/replaceState as "the
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
const joint_history = html_core.navigation.joint_history;
const navigate_steps = html_core.navigation.navigate_steps;
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

/// The History's navigable, when its document is fully active: the window is
/// still the navigable's active window.
fn activeNavigable(internal: *InternalState) ?*BrowsingContext {
    const bc = internal.browsing_context orelse return null;
    const window = internal.window orelse return null;
    if (bc.getActiveWindow() != @as(?*anyopaque, @ptrCast(window))) return null;
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
    return history.lengthAndIndex().length;
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
    queueTraversal(internal, bc.getTop(), .{ .delta = delta_val }, false);
}

/// HTML "reload" `bc`'s navigable: its current entry, repopulated - a
/// traversal of the navigable to the entry it is on. Not while its document
/// is unloading (reload step 1).
fn reloadNavigable(window: *runtime.Instance, bc: *BrowsingContext) void {
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
    const url = bc.allocator.dupe(u8, entry.url) catch return;
    defer bc.allocator.free(url);
    const entry_id = entry.id;
    var api_state = entry.api_state.clone(bc.allocator) catch return;
    defer api_state.deinit(bc.allocator);
    if (!@import("dom").navigation_api.firePushReplaceReload(window, .{
        .navigation_type = .reload,
        .destination_url = url,
        .is_same_document = false,
        .navigation_api_state = api_state,
    })) return;
    const current = history.entryById(entry_id) orelse return;
    // A reload's previousEntry is the entry it reloads.
    @import("dom").navigables.traverseNavigable(@ptrCast(bc), current.id, current.url, current.resource, current.id);
}

/// dom.history_traversal: reload `window`'s navigable.
fn reloadWindow(window: *runtime.Instance) void {
    const bc = BrowsingContext.ofWindow(@ptrCast(window)) orelse return;
    reloadNavigable(window, bc);
}

/// dom.history_traversal: queue a traversal of `window`'s traversable to
/// `step` (the navigation API's "perform a navigation API traversal").
fn traverseWindowToStep(window: *runtime.Instance, step: u32) void {
    const bc = BrowsingContext.ofWindow(@ptrCast(window)) orelse return;
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    queueTraversal(internal, bc.getTop(), .{ .step = step }, false);
}

/// dom.history_traversal: "resume applying the traverse history step" to
/// `step` - an intercepted traverse navigate event's commit - without firing
/// the navigate event again.
fn resumeTraversalOfWindow(window: *runtime.Instance, step: u32) void {
    const bc = BrowsingContext.ofWindow(@ptrCast(window)) orelse return;
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    queueTraversal(internal, bc.getTop(), .{ .step = step }, true);
}

/// dom.history_traversal: the URL and history update steps for `window`'s
/// document - committing an intercepted push or replace navigate event.
/// `serialized` is BORROWED.
fn urlAndHistoryUpdateOfWindow(window: *runtime.Instance, url: []const u8, serialized: ?joint_history.SerializedState, handling: joint_history.HistoryHandling) void {
    const history_instance = interfaces.Window.get_history(window) catch return;
    const internal = getInternal(history_instance) orelse return;
    const bc = activeNavigable(internal) orelse return;
    const given: joint_history.SerializedState = serialized orelse .null;
    const data = given.clone(internal.allocator) catch return;
    urlAndHistoryUpdate(internal, bc, window, url, data, handling) catch |err| {
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

/// HTML "shared history push/replace state steps". Not modelled, stated:
/// rate limiting (step 3) beyond the nesting limit above.
fn sharedPushReplaceState(instance: *runtime.Instance, data: runtime.JSValue, url: webidl.Opt(?runtime.USVString), handling: joint_history.HistoryHandling) !void {
    // Step 3: "Optionally, throw a SecurityError DOMException."
    if (push_replace_depth >= max_push_replace_depth) return error.SecurityError;
    push_replace_depth += 1;
    defer push_replace_depth -= 1;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Step 1: "Let document be history's associated Document. If document is
    // not fully active, then throw a SecurityError DOMException."
    _ = activeNavigable(internal) orelse return error.SecurityError;
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
    try urlAndHistoryUpdate(internal, still, window, new_url, serialized, handling);
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
/// is pushed or replaced in the traversable's history. Step 3 - the initial
/// about:blank document always replaces - is the joint history's "replace"
/// of the navigable's only entry.
fn urlAndHistoryUpdate(
    internal: *InternalState,
    bc: *BrowsingContext,
    window: *runtime.Instance,
    new_url: []const u8,
    serialized: joint_history.SerializedState,
    handling: joint_history.HistoryHandling,
) !void {
    const history = try ensureEntries(bc);
    // The new entry's navigation API state is a fresh one (the URL and
    // history update steps do not carry it over).
    try history.commitSameDocument(bc.id, new_url, serialized, handling, .undefined);
    // Step 7: "Restore the history object state" - the next read deserializes
    // the new entry's state.
    internal.has_state = false;
    // Step 8: "Set document's URL to newURL."
    setDocumentUrl(window, new_url);
    // Step 9: "Update the navigation API entries for a same-document
    // navigation given document's relevant global object's navigation API,
    // newEntry, and historyHandling."
    @import("dom").navigation_api.sameDocumentNavigation(window, switch (handling) {
        .push => .push,
        .replace => .replace,
    });
}

/// Set the URL of `window`'s associated Document - which its realm records,
/// and its Location reads.
fn setDocumentUrl(window: *runtime.Instance, url: []const u8) void {
    window.ctx.setDocumentUrl(url) catch |err| log.warn("history: the document URL was not recorded: {s}", .{@errorName(err)});
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

/// A traversal waiting on the traversable's session history traversal queue.
const Traversal = struct {
    top_id: u64,
    target: Target,
    allocator: Allocator,
    /// "Resume applying the traverse history step": the traversable's
    /// navigate event was fired and intercepted; it is not fired again.
    resumed: bool,
};

/// Append session history traversal steps - a task, here - that apply the
/// step `target` names.
fn queueTraversal(internal: *InternalState, top: *BrowsingContext, target: Target, resumed: bool) void {
    const window = internal.window orelse return;
    const task = internal.allocator.create(Traversal) catch return;
    task.* = .{ .top_id = top.id, .target = target, .allocator = internal.allocator, .resumed = resumed };
    const loop = window.ctx.getOptionalEventLoop() orelse return runTraversal(task);
    loop.queueTask(.{ .callback = &runTraversal, .context = task, .drop = &dropTraversal });
}

fn dropTraversal(context: ?*anyopaque) void {
    const task: *Traversal = @ptrCast(@alignCast(context orelse return));
    task.allocator.destroy(task);
}

/// A navigable that changes entry in a traversal.
const Change = struct {
    navigable: *BrowsingContext,
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
/// Not modelled, stated: beforeunload across the traversal (step 5), and
/// history-action activation for the traversable's navigate event.
fn runTraversal(context: ?*anyopaque) void {
    const task: *Traversal = @ptrCast(@alignCast(context orelse return));
    const allocator = task.allocator;
    defer allocator.destroy(task);

    const top = BrowsingContext.byId(task.top_id) orelse return;
    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(allocator);
    top.collectDescendants(allocator, &tree) catch return;

    const history = top.jointHistory() catch return;
    for (tree.items) |bc| _ = ensureEntries(bc) catch {};

    // Steps 2-4: the target step.
    const target = switch (task.target) {
        .delta => |delta| history.stepByDelta(delta) orelse return,
        .step => |step| step,
    };

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
                if (!@import("dom").navigation_api.fireTraverse(window, target_entry.?.id, .none)) return;
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
                skipped.append(allocator, bc) catch return;
                continue;
            }
        }
        const current = history.currentEntry(bc.id) orelse continue;
        const target_entry = history.entryAt(bc.id, target) orelse continue;
        if (current == target_entry) continue;
        const same_document = current.document_state == target_entry.document_state and
            target_entry.document != null and target_entry.document == bc.getActiveDocument();
        const old_url = allocator.dupe(u8, current.url) catch return;
        changes.append(allocator, .{
            .navigable = bc,
            .old_url = old_url,
            .from_entry = current.id,
            .target_entry = target_entry.id,
            .same_document = same_document,
            .same_origin = std.mem.eql(u8, current.origin, target_entry.origin),
        }) catch {
            allocator.free(old_url);
            return;
        };
        if (!same_document) skipped.append(allocator, bc) catch return;
    }

    // Step 20: the traversable's current session history step.
    history.current_step = target;

    for (changes.items) |change| {
        // Step 12.7: a navigable other than the traversable whose entry
        // changes within its origin fires a traverse navigate event (not
        // cancelable).
        if (change.navigable != top and change.same_origin) {
            if (change.navigable.getActiveWindow()) |w| {
                _ = @import("dom").navigation_api.fireTraverse(@ptrCast(@alignCast(w)), change.target_entry, .none);
            }
        }
        const entry = history.entryById(change.target_entry) orelse continue;
        if (change.same_document) {
            sameDocumentTraversal(change.navigable, change.old_url, entry);
        } else {
            @import("dom").navigables.traverseNavigable(@ptrCast(change.navigable), entry.id, entry.url, entry.resource, change.from_entry);
        }
    }
}

/// "Update document for history step application" for a same-document
/// entry (step 6): the document's URL becomes the entry's, history.state its
/// state, and popstate fires at the window - then hashchange, as a task, if
/// the fragment changed.
fn sameDocumentTraversal(bc: *BrowsingContext, old_url: []const u8, entry: *joint_history.Entry) void {
    const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return));
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
