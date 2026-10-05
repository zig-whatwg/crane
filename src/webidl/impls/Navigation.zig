//! Implementation for Navigation interface
//!
//! HTML Standard §7.2.6 - The navigation API
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigation-api
//!
//! A Navigation is its window's view of the window's navigable's session
//! history: the traversable's joint history (html_core JointHistory), in
//! which each entry records its navigation API key, ID, state and origin.
//! The entry list is the navigable's contiguous same-origin run of entries
//! around its current one ("get session history entries for the navigation
//! API"), read from the history when asked; each entry is handed out as one
//! NavigationHistoryEntry per session history entry, kept (pinned) for as long
//! as it is in the list, so `navigation.currentEntry === navigation.currentEntry`.
//!
//! What navigates tells it through dom.navigation_api, which it installs:
//! it fires the navigate event before a navigation (7.2.6.10.4), tracks the
//! navigation that event lets through or intercepts - its ongoing navigate
//! event, its API method trackers, its transition (7.2.6.8) - commits an
//! intercepted one and settles it with navigatesuccess or navigateerror, and
//! updates its entries when a same-document navigation commits (7.2.6.4).
//! What intercept() records for a navigate event is kept here too, with the
//! event (EventRecord): the navigation reads and settles it.
//!
//! Deviations, stated:
//! - A navigate event nobody intercepts keeps its API method tracker ongoing
//!   when its destination is cross-document (Blink, and ordering-and-
//!   transition/navigate-cross-document-double: a later navigation rejects
//!   its promises); "commit a navigate event" step 9 would clean it up.
//! - The event's formData carries a form's string entries only; the focus
//!   reset runs the focusing steps on the body (or document element)
//!   without an autofocus delegate; scroll behavior records only that
//!   scrolling happened (no layout).
//! - navigation.activation is made when it is first asked for, or when the
//!   Navigation is made, from what the navigation that committed the
//!   document recorded in the session history (joint_history.Activation)
//!   before any of the document's script ran. A document the host loaded
//!   with no navigation of Crane's before it (the top-level page) has the
//!   activation of a navigation that replaced its initial about:blank: no
//!   old entry, and navigation type "replace".

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const Navigation = interfaces.Navigation;
const EventTargetImpl = @import("EventTarget.zig");
const same_object = @import("same_object.zig");
const navigation_entries = @import("navigation_entries.zig");
const html_core = @import("html_core");
const joint_history = html_core.navigation.joint_history;
const navigate_steps = html_core.navigation.navigate_steps;
const dom = @import("dom");
const engine = @import("engine");
const log = std.log.scoped(.navigation_api);

const Kind = dom.navigation_api.Kind;

pub const State = Navigation.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SecurityError,
    SyntaxError,
    AbortError,
    OutOfMemory,
};

/// A NavigationHistoryEntry handed out, and the edge from the navigation's
/// wrapper that keeps its wrapper (same_object.Traced: one slot per entry,
/// named by its id).
const Handed = struct {
    instance: *runtime.Instance,
    edge: same_object.Traced = .{ .slot = .{ .name = "" } },
    slot_name: [40]u8 = undefined,

    /// `navigation` keeps this entry, in a slot of the entry's own.
    fn hold(self: *Handed, navigation: *runtime.Instance, id: u64) void {
        self.edge.slot = .{ .name = std.fmt.bufPrint(&self.slot_name, "entry:{d}", .{id}) catch return };
        self.edge.hold(navigation, self.instance);
    }
};

/// The name of a per-record slot ("event:3", "controller:3").
fn recordSlot(buffer: []u8, kind: []const u8, id: u64) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "{s}:{d}", .{ kind, id }) catch kind };
}

/// A navigation API method tracker (HTML 7.2.6.8).
const Tracker = struct {
    /// Its key: a traversal's destination key; null for navigate()/reload().
    key: ?[36]u8 = null,
    /// Its info, for the navigate event: kept by an edge from the
    /// navigation's wrapper in this slot (engine.traceValue), never a root -
    /// HTML leaves a cross-document navigation's tracker ongoing on the
    /// document it left, and an info held as a root kept that document's
    /// realm alive. Null: undefined.
    info_slot: ?engine.TracedSlot = null,
    info_slot_name: [40]u8 = undefined,
    /// Its serialized state: navigate()'s and reload()'s navigation API state.
    serialized_state: ?joint_history.SerializedState = null,
    /// The NavigationHistoryEntry it committed to.
    committed_to: ?*runtime.Instance = null,
    committed: engine.PromiseCapability,
    finished: engine.PromiseCapability,
    pending: bool,
    /// Cleaned up: no longer the navigation's ongoing or upcoming tracker.
    cleaned_up: bool = false,
    /// Held by the navigate() or reload() call that made it, until that call
    /// has read its promises - the navigation it starts can settle and clean
    /// it up before.
    held: bool = false,

    /// `navigation`: the Navigation that keeps its info.
    fn destroy(self: *Tracker, allocator: Allocator, navigation: *runtime.Instance) void {
        engine.releasePromiseCapability(&self.committed);
        engine.releasePromiseCapability(&self.finished);
        if (self.info_slot) |slot| engine.forgetTracedChild(navigation, slot);
        if (self.serialized_state) |*s| s.deinit(allocator);
        allocator.destroy(self);
    }
};

/// A NavigateEvent's "interception state".
const InterceptionState = enum { none, intercepted, committed, scrolled, finished };

/// What the navigation API keeps for a navigate event it fired: the event's
/// interception state, handler lists, focus reset and scroll behaviors,
/// abort controller and classic history API state (HTML 7.2.6.10.1), and
/// the API method tracker its commit settles. Kept while it is the ongoing
/// navigate event, and while its handlers' promises are awaited.
const EventRecord = struct {
    id: u64,
    /// The Navigation that fired the event, whose wrapper keeps the event
    /// and its abort controller (edges, not roots: same_object.Traced).
    navigation: *runtime.Instance,
    event: *runtime.Instance,
    event_edge: same_object.Traced = .{ .slot = .{ .name = "" } },
    event_slot: [40]u8 = undefined,
    navigation_type: Kind,
    destination: *runtime.Instance,
    interception_state: InterceptionState = .none,
    precommit_handlers: std.ArrayListUnmanaged(engine.CallbackFunction) = .empty,
    handlers: std.ArrayListUnmanaged(engine.CallbackFunction) = .empty,
    focus_reset: ?dom.navigation_api.FocusReset = null,
    scroll_behavior: ?dom.navigation_api.ScrollBehavior = null,
    controller: *runtime.Instance,
    controller_edge: same_object.Traced = .{ .slot = .{ .name = "" } },
    controller_slot: [40]u8 = undefined,
    classic_state: ?joint_history.SerializedState = null,
    tracker: ?*Tracker = null,
    user_involvement: dom.navigation_api.UserInvolvement = .none,
    /// Set while the event is being dispatched (its dispatch flag).
    dispatching: bool = false,
    /// Set while its handlers are being invoked: a handler can abort the
    /// navigation (remove its frame, start another), and the record it
    /// iterates must outlive that.
    invoking: bool = false,
    /// Its destination's "is same document".
    same_document: bool = false,
    /// The navigate event intercept commit handler steps have run for it.
    handlers_run: bool = false,
    /// "Wait for all"s not yet settled.
    waits: u32 = 0,

    fn destroy(self: *EventRecord, allocator: Allocator) void {
        for (self.precommit_handlers.items) |h| h.release();
        self.precommit_handlers.deinit(allocator);
        for (self.handlers.items) |h| h.release();
        self.handlers.deinit(allocator);
        if (self.classic_state) |*s| s.deinit(allocator);
        self.event_edge.release(self.navigation);
        self.controller_edge.release(self.navigation);
        allocator.destroy(self);
    }
};

/// "navigation's transition": its NavigationTransition, kept by the
/// navigation's wrapper (an edge), and the capabilities of the promises it
/// hands out.
const Transition = struct {
    navigation: *runtime.Instance,
    instance: *runtime.Instance,
    edge: same_object.Traced = .{ .slot = .{ .name = "transition" } },
    committed: engine.PromiseCapability,
    finished: engine.PromiseCapability,

    fn destroy(self: *Transition, allocator: Allocator) void {
        self.edge.release(self.navigation);
        engine.releasePromiseCapability(&self.committed);
        engine.releasePromiseCapability(&self.finished);
        allocator.destroy(self);
    }
};

pub const InternalState = struct {
    allocator: Allocator,
    /// The Navigation this state is: the owner of every edge below.
    navigation: *runtime.Instance,
    /// The relevant global object and its slab generation, found from the
    /// realm on first use.
    window: ?*runtime.Instance = null,
    window_generation: u64 = 0,
    /// The entries handed out, by session history entry id.
    handed: std.AutoHashMapUnmanaged(u64, *Handed) = .empty,
    /// The session history entry that was current when this last looked:
    /// "oldCurrentNHE" for the next currententrychange.
    current_entry_id: u64 = 0,
    /// "Ongoing navigate event", "focus changed during ongoing navigation",
    /// "suppress normal scroll restoration during ongoing navigation".
    ongoing_event: ?*EventRecord = null,
    focus_changed: bool = false,
    suppress_scroll: bool = false,
    /// "Ongoing API method tracker" and "upcoming traverse API method
    /// trackers" (by key).
    ongoing_tracker: ?*Tracker = null,
    upcoming: std.ArrayListUnmanaged(*Tracker) = .empty,
    /// The tracker navigate() or reload() hands to the navigation it starts:
    /// the next navigate event fired while it runs picks it up.
    handoff: ?*Tracker = null,
    transition: ?*Transition = null,
    /// Every tracker and event record alive; each goes once nothing uses it.
    trackers: std.ArrayListUnmanaged(*Tracker) = .empty,
    records: std.ArrayListUnmanaged(*EventRecord) = .empty,
    next_record_id: u64 = 1,
    /// "Navigation's activation", once made, kept by this object's wrapper.
    activation: ?*runtime.Instance = null,
    activation_edge: same_object.Traced = .{ .slot = .{ .name = "activation" } },

    /// Its teardown, the collector's too: each edge goes (same_object.Traced),
    /// and no child is touched - the collector may have freed it first.
    fn deinit(self: *InternalState) void {
        self.activation_edge.release(self.navigation);
        self.activation = null;
        var it = self.handed.valueIterator();
        while (it.next()) |handed| {
            handed.*.edge.release(self.navigation);
            self.allocator.destroy(handed.*);
        }
        self.handed.deinit(self.allocator);
        for (self.records.items) |record| record.destroy(self.allocator);
        self.records.deinit(self.allocator);
        for (self.trackers.items) |tracker| tracker.destroy(self.allocator, self.navigation);
        self.trackers.deinit(self.allocator);
        self.upcoming.deinit(self.allocator);
        if (self.transition) |t| t.destroy(self.allocator);
        self.transition = null;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The Navigation objects alive on this thread. A window whose `navigation`
/// script never asked for has none - nothing can listen to its navigate
/// events or hold its promises - and its navigations are not tracked.
threadlocal var live: std.ArrayListUnmanaged(*runtime.Instance) = .empty;

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.navigation_api.install(.{
        .same_document_navigation = &sameDocumentNavigation,
        .page_swap_activation = &pageSwapActivationHook,
        .entries_removed = &entriesRemovedHook,
        .fire_push_replace_reload = &firePushReplaceReloadHook,
        .fire_traverse = &fireTraverseHook,
        .fire_download_request = &fireDownloadRequestHook,
        .inform_about_aborting_navigation = &informAboutAbortingNavigationHook,
        .inform_about_child_navigable_destruction = &informAboutChildNavigableDestructionHook,
        .intercept = &interceptHook,
        .scroll = &scrollHook,
        .redirect = &redirectHook,
        .add_handler = &addHandlerHook,
    });
}

/// Initialize Navigation instance: an EventTarget, which currententrychange
/// and the navigate events are fired at.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .navigation = instance };
    instance.getState(StateType).own._internal = internal;
    try live.append(std.heap.c_allocator, instance);
    // "Initialize the navigation API entries for a new document": the current
    // entry, handed out now, is the "from" of the first currententrychange.
    _ = currentEntryObject(instance, internal) catch null;
    // "Update document for history step application" step 7: the document's
    // activation, made while its entries are still the ones it was
    // activated with.
    _ = activationObject(instance, internal);
    return instance;
}

/// Deinitialize Navigation instance
pub fn deinit(instance: *runtime.Instance) void {
    for (live.items, 0..) |navigation, i| {
        if (navigation == instance) {
            _ = live.swapRemove(i);
            break;
        }
    }
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    EventTargetImpl.deinit(instance);
}

// ============================================================================
// The window, its navigable and the entry list
// ============================================================================

/// The relevant global object: the Window of this object's realm, from the
/// realm record.
fn windowOf(instance: *runtime.Instance, internal: *InternalState) ?*runtime.Instance {
    if (internal.window) |window| return window;
    const record = instance.ctx.getRealm() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    internal.window = window;
    internal.window_generation = runtime.SlabAllocator.generationOf(window);
    return window;
}

/// The window's scope while its document is fully active.
fn scopeOf(instance: *runtime.Instance, internal: *InternalState) ?navigation_entries.Scope {
    const window = windowOf(instance, internal) orelse return null;
    return navigation_entries.scopeOf(window, internal.window_generation);
}

/// The NavigationHistoryEntry for `entry`: the one already handed out, or a
/// new one, kept from now on.
fn entryObject(internal: *InternalState, window: *runtime.Instance, entry: *const joint_history.Entry) !*runtime.Instance {
    if (internal.handed.get(entry.id)) |handed| return handed.instance;
    const hook = dom.navigation_history_entries;
    const instance = try hook.create(window, @ptrCast(entry));
    const handed = try internal.allocator.create(Handed);
    handed.* = .{ .instance = instance };
    internal.handed.put(internal.allocator, entry.id, handed) catch |err| {
        internal.allocator.destroy(handed);
        return err;
    };
    handed.hold(internal.navigation, entry.id);
    return instance;
}

/// The entry list: the session history entries of the navigation API, into
/// `out`, with the current one's index; null when entries and events are
/// disabled.
fn entryList(scope: ?navigation_entries.Scope, allocator: Allocator, out: *std.ArrayListUnmanaged(*joint_history.Entry)) ?usize {
    if (navigation_entries.disabled(scope)) return null;
    const s = scope.?;
    return s.history.apiEntries(s.navigable.id, allocator, out) catch null;
}

/// "The current entry": null when entries and events are disabled.
fn currentEntryObject(instance: *runtime.Instance, internal: *InternalState) !?*runtime.Instance {
    const scope = scopeOf(instance, internal);
    if (navigation_entries.disabled(scope)) return null;
    const s = scope.?;
    const entry = s.history.currentEntry(s.navigable.id) orelse return null;
    if (internal.current_entry_id == 0) internal.current_entry_id = entry.id;
    return try entryObject(internal, s.window, entry);
}

// ============================================================================
// Attributes
// ============================================================================

/// Getter for currentEntry: "the current entry of this".
pub fn get_currentEntry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return currentEntryObject(instance, internal);
}

/// "The transition getter steps are to return this's transition."
pub fn get_transition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const transition = internal.transition orelse return null;
    return transition.instance;
}

/// "The activation getter steps are to return this's activation."
pub fn get_activation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return activationObject(instance, internal);
}

/// "1. If this has entries and events disabled, then return false. 2.
/// Assert: this's current entry index is not −1. 3. If this's current entry
/// index is 0, then return false. 4. Return true."
pub fn get_canGoBack(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    const index = entryList(scopeOf(instance, internal), internal.allocator, &entries) orelse return false;
    return index > 0;
}

/// "... 3. If this's current entry index is equal to this's entry list's
/// size − 1, then return false. 4. Return true."
pub fn get_canGoForward(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    const index = entryList(scopeOf(instance, internal), internal.allocator, &entries) orelse return false;
    return index + 1 < entries.items.len;
}

pub fn get_onnavigate(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "navigate");
}

pub fn get_onnavigatesuccess(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "navigatesuccess");
}

pub fn get_onnavigateerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "navigateerror");
}

pub fn get_oncurrententrychange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "currententrychange");
}

pub fn set_onnavigate(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "navigate", value);
}

pub fn set_onnavigatesuccess(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "navigatesuccess", value);
}

pub fn set_onnavigateerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "navigateerror", value);
}

pub fn set_oncurrententrychange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "currententrychange", value);
}

// ============================================================================
// Operations
// ============================================================================

/// entries(): "1. If this has entries and events disabled, then return the
/// empty list. 2. Return this's entry list." A new array on each call.
pub fn call_entries(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    const scope = scopeOf(instance, internal);
    const listed = entryList(scope, internal.allocator, &entries) != null;
    const count: usize = if (listed) entries.items.len else 0;

    const objects = try internal.allocator.alloc(*runtime.Instance, count);
    defer internal.allocator.free(objects);
    for (entries.items[0..count], objects) |entry, *object| object.* = try entryObject(internal, scope.?.window, entry);
    // sequence<NavigationHistoryEntry>, made in the current realm: the
    // entries are kept (pinned), so the array only references them.
    return (try engine.createSequenceOfPlatformObjects(engine.currentRealm() orelse instance.ctx, objects)).take();
}

/// updateCurrentEntry(options): "1. Let current be the current entry of
/// this. 2. If current is null, then throw an "InvalidStateError"
/// DOMException. 3. Let serializedState be
/// StructuredSerializeForStorage(options["state"]), rethrowing any
/// exceptions. 4. Set current's session history entry's navigation API state
/// to serializedState. 5. Fire an event named currententrychange at this
/// using NavigationCurrentEntryChangeEvent, with its navigationType attribute
/// initialized to null and its from initialized to current."
pub fn call_updateCurrentEntry(instance: *runtime.Instance, options: dictionaries.NavigationUpdateCurrentEntryOptions) anyerror!void {
    // `state` is a required dictionary member: WebIDL throws a TypeError when
    // it is missing, and for `any`, a missing member and undefined are one.
    if (options.state == .undefined) return error.TypeError;
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const current = (try currentEntryObject(instance, internal)) orelse return error.InvalidStateError;
    const scope = scopeOf(instance, internal) orelse return error.InvalidStateError;
    const serialized = try navigation_entries.serialize(engine.currentRealm() orelse instance.ctx, internal.allocator, options.state);
    try scope.history.setCurrentApiState(scope.navigable.id, serialized);
    fireCurrentEntryChange(instance, null, current);
}

/// navigate(url, options): HTML 7.2.6.7.
pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString, options: webidl.Opt(dictionaries.NavigationNavigateOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const opts: ?dictionaries.NavigationNavigateOptions = if (options.was_passed) options.value else null;
    // Step 4's document - "this's relevant global object's associated
    // Document" - whether or not it is fully active: steps 1-7 run first
    // (navigate-rejection-order-*-detached.html: a detached frame's
    // navigate() with an unparsable URL or unserializable state reports
    // that, not InvalidStateError).
    const window = windowOf(instance, internal) orelse return earlyError(instance, "InvalidStateError", "The document is not fully active.");
    const document = interfaces.Window.get_document(window) catch return earlyError(instance, "InvalidStateError", "The document is not fully active.");

    // Step 1: "Let urlRecord be the result of parsing a URL given url,
    // relative to this's relevant settings object." Failure: SyntaxError.
    const url_record = parseRelative(document, url, internal.allocator) catch
        return earlyError(instance, "SyntaxError", "The URL could not be parsed.");
    defer internal.allocator.free(url_record);

    // Step 3: "If urlRecord's scheme is "javascript", then return an early
    // error result for a "NotSupportedError" DOMException."
    if (std.ascii.startsWithIgnoreCase(url_record, "javascript:")) {
        return earlyError(instance, "NotSupportedError", "navigate() does not run javascript: URLs.");
    }

    // Step 5: "If options["history"] is "push", and the navigation must be a
    // replace given urlRecord and document, then return an early error
    // result for a "NotSupportedError" DOMException."
    const behavior: dom.navigables.HistoryBehavior = if (opts) |o| switch (o.history orelse ._auto_) {
        ._auto_ => .auto,
        ._push_ => .push,
        ._replace_ => .replace,
    } else .auto;
    if (behavior == .push and dom.document_lifecycle.isInitialAboutBlank(document)) {
        return earlyError(instance, "NotSupportedError", "A push is not possible here.");
    }

    // Steps 6-7: the state, serialized (undefined when absent); an exception
    // is an early error result for that exception.
    var state: joint_history.SerializedState = .undefined;
    if (opts) |o| {
        if (o.state) |value| {
            switch (try serializeState(instance, internal, value)) {
                .serialized => |serialized| state = serialized,
                .threw => |reason| return earlyErrorWith(instance, reason),
            }
        }
    }
    var state_owned = true;
    defer if (state_owned) state.deinit(internal.allocator);

    // Step 8: "If document is not fully active, then return an early error
    // result for an "InvalidStateError" DOMException." Step 9: the unload
    // counter.
    const again = scopeOf(instance, internal) orelse return earlyError(instance, "InvalidStateError", "The document is not fully active.");
    if (dom.document_lifecycle.isUnloading(again.document)) {
        return earlyError(instance, "InvalidStateError", "The document is unloading.");
    }

    // Steps 10-11: "Let info be options["info"], if it exists; otherwise,
    // undefined." The API method tracker.
    const info: runtime.JSValue = if (opts) |o| (o.base.info orelse runtime.JSValue.jsUndefined) else runtime.JSValue.jsUndefined;
    state_owned = false;
    const tracker = try setUpNavigateReloadTracker(instance, internal, info, state);
    tracker.held = true;
    defer {
        tracker.held = false;
        collect(internal);
    }

    // Step 12: "Navigate document's node navigable to urlRecord using
    // document, with historyHandling set to options["history"],
    // navigationAPIState set to serializedState, and apiMethodTracker set to
    // apiMethodTracker." The navigate event the navigation fires picks the
    // tracker up.
    const navigables = dom.navigables;
    internal.handoff = tracker;
    navigables.navigateByTarget(again.document, .{
        .target = "",
        .url = url_record,
        .history_behavior = behavior,
        .navigation_api_state = tracker.serialized_state,
    });
    // A navigation that fired no navigate event leaves the tracker pending.
    if (internal.handoff == tracker) internal.handoff = null;

    // Step 13.
    return derivedResult(instance, internal, tracker);
}

/// reload(options): HTML 7.2.6.7.
pub fn call_reload(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationReloadOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 2-3: "Let serializedState be StructuredSerializeForStorage(undefined).
    // If options["state"] exists, then set serializedState to
    // StructuredSerializeForStorage(options["state"]). If this throws an
    // exception, then return an early error result for that exception."
    var state: joint_history.SerializedState = .undefined;
    var state_given = false;
    if (options.was_passed) {
        if (options.value.state) |value| {
            switch (try serializeState(instance, internal, value)) {
                .serialized => |serialized| {
                    state = serialized;
                    state_given = true;
                },
                .threw => |reason| return earlyErrorWith(instance, reason),
            }
        }
    }
    var state_owned = true;
    defer if (state_owned) state.deinit(internal.allocator);
    // Step 4: "Otherwise: ... If current is not null, then set
    // serializedState to current's session history entry's navigation API
    // state."
    const scope = scopeOf(instance, internal) orelse return earlyError(instance, "InvalidStateError", "The document is not fully active.");
    if (!state_given and !navigation_entries.disabled(scope)) {
        if (scope.history.currentEntry(scope.navigable.id)) |current| state = try current.api_state.clone(internal.allocator);
    }
    // Steps 5-6.
    if (dom.document_lifecycle.isUnloading(scope.document)) return earlyError(instance, "InvalidStateError", "The document is unloading.");
    // Steps 7-8.
    const info: runtime.JSValue = if (options.was_passed) (options.value.base.info orelse runtime.JSValue.jsUndefined) else runtime.JSValue.jsUndefined;
    state_owned = false;
    const tracker = try setUpNavigateReloadTracker(instance, internal, info, state);
    tracker.held = true;
    defer {
        tracker.held = false;
        collect(internal);
    }
    // Step 9: "Reload document's node navigable with navigationAPIState set
    // to serializedState and apiMethodTracker set to apiMethodTracker."
    internal.handoff = tracker;
    ensureHistoryTraversal(scope.window);
    dom.history_traversal.reload(scope.window);
    if (internal.handoff == tracker) internal.handoff = null;
    // Step 10.
    return derivedResult(instance, internal, tracker);
}

/// traverseTo(key, options): "1. If this's current entry index is −1, then
/// return an early error result for an "InvalidStateError" DOMException.
/// 2. If this's entry list does not contain a NavigationHistoryEntry whose
/// session history entry's navigation API key equals key, then return an
/// early error result for an "InvalidStateError" DOMException. 3. Return the
/// result of performing a navigation API traversal given this, key, and
/// options."
pub fn call_traverseTo(instance: *runtime.Instance, key: runtime.DOMString, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    return traverseToKey(instance, key.asSlice(), infoOf(options));
}

/// back(options): "1. If this's current entry index is −1 or 0, then return
/// an early error result for an "InvalidStateError" DOMException. 2. Let key
/// be this's entry list[this's current entry index − 1]'s session history
/// entry's navigation API key. 3. Return the result of performing a
/// navigation API traversal given this, key, and options."
pub fn call_back(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    return traverseByOne(instance, -1, infoOf(options));
}

/// forward(options): the same, for the entry after the current one.
pub fn call_forward(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    return traverseByOne(instance, 1, infoOf(options));
}

fn infoOf(options: webidl.Opt(dictionaries.NavigationOptions)) runtime.JSValue {
    if (!options.was_passed) return runtime.JSValue.jsUndefined;
    return options.value.info orelse runtime.JSValue.jsUndefined;
}

fn traverseByOne(instance: *runtime.Instance, delta: i2, info: runtime.JSValue) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    const index = entryList(scopeOf(instance, internal), internal.allocator, &entries) orelse
        return earlyError(instance, "InvalidStateError", "There is no entry to traverse to.");
    const target = @as(i64, @intCast(index)) + delta;
    if (target < 0 or target >= @as(i64, @intCast(entries.items.len))) {
        return earlyError(instance, "InvalidStateError", "There is no entry to traverse to.");
    }
    const key = entries.items[@intCast(target)].api_key;
    return traverseToKey(instance, &key, info);
}

/// HTML "perform a navigation API traversal" given this and `key`.
fn traverseToKey(instance: *runtime.Instance, key: []const u8, info: runtime.JSValue) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-3: a document that is not fully active, or is unloading.
    const scope = scopeOf(instance, internal) orelse return earlyError(instance, "InvalidStateError", "The document is not fully active.");
    if (dom.document_lifecycle.isUnloading(scope.document)) return earlyError(instance, "InvalidStateError", "The document is unloading.");
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    const index = entryList(scope, internal.allocator, &entries) orelse
        return earlyError(instance, "InvalidStateError", "Entries are disabled.");
    // Step 4: "Let current be the current entry of navigation." Step 5: "If
    // key equals current's session history entry's navigation API key, then
    // return a new NavigationResult whose committed and finished are
    // promises resolved with current."
    const current = entries.items[index];
    if (std.mem.eql(u8, &current.api_key, key)) {
        const nhe = try entryObject(internal, scope.window, current);
        return settledResult(instance, nhe);
    }
    // traverseTo() step 2: "If this's entry list does not contain a
    // NavigationHistoryEntry whose session history entry's navigation API
    // key equals key, then return an early error result for an
    // "InvalidStateError" DOMException."
    const destination = for (entries.items) |entry| {
        if (std.mem.eql(u8, &entry.api_key, key)) break entry;
    } else return earlyError(instance, "InvalidStateError", "No entry has that key.");
    if (key.len != 36) return earlyError(instance, "InvalidStateError", "No entry has that key.");
    var tracker_key: [36]u8 = undefined;
    @memcpy(&tracker_key, key[0..36]);
    // Step 6: "If navigation's upcoming traverse API method trackers[key]
    // exists, then return a navigation API method tracker-derived result for
    // navigation's upcoming traverse API method trackers[key]."
    if (upcomingTracker(internal, &tracker_key)) |existing| return derivedResult(instance, internal, existing.tracker);
    // Steps 7-8: the upcoming traverse API method tracker.
    const tracker = try addUpcomingTraverseTracker(instance, internal, tracker_key, info);
    tracker.held = true;
    defer {
        tracker.held = false;
        collect(internal);
    }
    // Steps 9-12: the traversal to the destination's step - the nearest one
    // that shows it (JointHistory.nearestStepOf, as browsers do).
    ensureHistoryTraversal(scope.window);
    dom.history_traversal.traverseToStep(scope.window, scope.history.nearestStepOf(destination));
    // Step 12.3, when the queued traversal has run: its target already the
    // navigable's active entry - a traversal queued before it took the
    // navigable there - rejects the finished promise.
    queueActiveTargetCheck(instance, scope.window, tracker);
    // Step 13.
    return derivedResult(instance, internal, tracker);
}

/// "Perform a navigation API traversal" step 12.3, checked in a task queued
/// after the traversal's own (History's traversal task, on the same loop):
/// "If targetSHE is navigable's active session history entry: queue a global
/// task ... to reject the finished promise for apiMethodTracker with an
/// "InvalidStateError" DOMException." A traversal that changed the entry
/// fired its navigate event, which took the tracker out of the upcoming
/// ones; one that went to another document has not made it active yet.
const ActiveTargetCheck = struct {
    navigation: *runtime.Instance,
    generation: u64,
    tracker: *Tracker,
    allocator: Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *ActiveTargetCheck = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        if (runtime.SlabAllocator.generationOf(self.navigation) != self.generation) return;
        const internal = getInternal(self.navigation) orelse return;
        // Still an upcoming tracker - pointer and key both: a freed tracker's
        // block is never in the list.
        const key = for (internal.upcoming.items) |t| {
            if (t == self.tracker) break t.key orelse return;
        } else return;
        const scope = scopeOf(self.navigation, internal) orelse return;
        const current = scope.history.currentEntry(scope.navigable.id) orelse return;
        if (!std.mem.eql(u8, &current.api_key, &key)) return;
        const reason = engine.createDOMException(self.navigation.ctx, "InvalidStateError", "The traversal's destination is already the current entry.") catch {
            cleanUp(internal, self.tracker);
            return;
        };
        defer reason.release();
        rejectFinished(internal, self.tracker, reason.value);
        collect(internal);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *ActiveTargetCheck = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

fn queueActiveTargetCheck(navigation: *runtime.Instance, window: *runtime.Instance, tracker: *Tracker) void {
    const internal = getInternal(navigation) orelse return;
    const check = internal.allocator.create(ActiveTargetCheck) catch return;
    check.* = .{
        .navigation = navigation,
        .generation = runtime.SlabAllocator.generationOf(navigation),
        .tracker = tracker,
        .allocator = internal.allocator,
    };
    // With no loop (a context built for tests) the traversal ran in the call.
    const loop = window.ctx.getOptionalEventLoop() orelse return ActiveTargetCheck.run(check);
    loop.queueTask(.{ .callback = &ActiveTargetCheck.run, .context = check, .drop = &ActiveTargetCheck.drop });
}

/// dom.history_traversal is History's: a window that has not made its
/// History yet makes it, which installs the hook.
fn ensureHistoryTraversal(window: *runtime.Instance) void {
    if (dom.history_traversal.isInstalled()) return;
    _ = interfaces.Window.get_history(window) catch {};
}

// ============================================================================
// API method trackers (HTML 7.2.6.8)
// ============================================================================

/// HTML "set up a navigate/reload API method tracker" given `info`
/// (BORROWED) and `serialized_state` (taken).
fn setUpNavigateReloadTracker(instance: *runtime.Instance, internal: *InternalState, info: runtime.JSValue, serialized_state: ?joint_history.SerializedState) !*Tracker {
    var state = serialized_state;
    errdefer if (state) |*s| s.deinit(internal.allocator);
    const tracker = try newTracker(instance, internal, info);
    tracker.serialized_state = state;
    state = null;
    // "pending: false if navigation has entries and events disabled;
    // otherwise true".
    tracker.pending = !navigation_entries.disabled(scopeOf(instance, internal));
    return tracker;
}

/// HTML "add an upcoming traverse API method tracker" given `key` and
/// `info` (BORROWED).
fn addUpcomingTraverseTracker(instance: *runtime.Instance, internal: *InternalState, key: [36]u8, info: runtime.JSValue) !*Tracker {
    const tracker = try newTracker(instance, internal, info);
    tracker.key = key;
    tracker.pending = false;
    try internal.upcoming.append(internal.allocator, tracker);
    return tracker;
}

/// A tracker with its committed and finished promises (1-2: "new promises
/// created in navigation's relevant realm", finished marked as handled).
fn newTracker(instance: *runtime.Instance, internal: *InternalState, info: runtime.JSValue) !*Tracker {
    const realm = instance.ctx;
    var committed = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&committed);
    var finished = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&finished);
    engine.markPromiseAsHandled(realm, finished.promise);
    const tracker = try internal.allocator.create(Tracker);
    errdefer internal.allocator.destroy(tracker);
    tracker.* = .{ .committed = committed, .finished = finished, .pending = true };
    try internal.trackers.append(internal.allocator, tracker);
    if (info != .undefined) {
        const id = internal.next_record_id;
        internal.next_record_id += 1;
        if (std.fmt.bufPrint(&tracker.info_slot_name, "tracker-info:{d}", .{id})) |name| {
            tracker.info_slot = .{ .name = name };
            engine.traceValue(instance, info, tracker.info_slot.?);
        } else |_| {}
    }
    return tracker;
}

const Upcoming = struct { index: usize, tracker: *Tracker };

fn upcomingTracker(internal: *InternalState, key: *const [36]u8) ?Upcoming {
    for (internal.upcoming.items, 0..) |tracker, i| {
        if (tracker.key) |k| if (std.mem.eql(u8, &k, key)) return .{ .index = i, .tracker = tracker };
    }
    return null;
}

/// HTML "clean up" `tracker`: it stops being the ongoing or an upcoming one.
/// Idempotent.
fn cleanUp(internal: *InternalState, tracker: *Tracker) void {
    if (internal.ongoing_tracker == tracker) internal.ongoing_tracker = null;
    for (internal.upcoming.items, 0..) |t, i| {
        if (t == tracker) {
            _ = internal.upcoming.orderedRemove(i);
            break;
        }
    }
    if (internal.handoff == tracker) internal.handoff = null;
    tracker.cleaned_up = true;
    collect(internal);
}

/// HTML "notify about the committed-to entry" given `tracker` and the
/// entry object `nhe` for the session history entry `entry`.
fn notifyCommittedTo(scope: navigation_entries.Scope, tracker: *Tracker, nhe: *runtime.Instance) void {
    // Step 1.
    tracker.committed_to = nhe;
    // Step 2: "If apiMethodTracker's serialized state is not null, then set
    // nhe's session history entry's navigation API state to apiMethodTracker's
    // serialized state."
    if (tracker.serialized_state) |state| {
        const allocator = scope.history.allocator;
        if (state.clone(allocator)) |copy| {
            scope.history.setCurrentApiState(scope.navigable.id, copy) catch {};
        } else |_| {}
    }
    // Step 3: "Resolve apiMethodTracker's committed promise with nhe."
    engine.resolvePromise(&tracker.committed, .{ .instance = nhe }) catch |err| log.debug("[navigation] committed: {s}", .{@errorName(err)});
}

/// HTML "resolve the finished promise" for `tracker`.
fn resolveFinished(internal: *InternalState, tracker: *Tracker) void {
    if (tracker.committed_to) |nhe| {
        engine.resolvePromise(&tracker.finished, .{ .instance = nhe }) catch |err| log.debug("[navigation] finished: {s}", .{@errorName(err)});
    }
    cleanUp(internal, tracker);
}

/// HTML "reject the finished promise" for `tracker` with `reason`
/// (BORROWED).
fn rejectFinished(internal: *InternalState, tracker: *Tracker, reason: runtime.JSValue) void {
    engine.rejectPromise(&tracker.committed, reason) catch {};
    engine.rejectPromise(&tracker.finished, reason) catch {};
    cleanUp(internal, tracker);
}

/// HTML "a navigation API method tracker-derived result" for `tracker`.
fn derivedResult(instance: *runtime.Instance, internal: *InternalState, tracker: *Tracker) !dictionaries.NavigationResult {
    // Step 1: "If apiMethodTracker is pending, then return an early error
    // result for an "AbortError" DOMException." It is then of no further use.
    if (tracker.pending) {
        cleanUp(internal, tracker);
        return earlyError(instance, "AbortError", "The navigation was not started.");
    }
    // Step 2.
    const realm = engine.currentRealm() orelse instance.ctx;
    const committed = try engine.retainValue(realm, tracker.committed.promise);
    errdefer committed.release();
    const finished = try engine.retainValue(realm, tracker.finished.promise);
    return .{ .committed = committed.take(), .finished = finished.take() };
}

/// Free every tracker that is cleaned up and every event record that is no
/// longer ongoing, awaited or being dispatched, once nothing refers to it.
fn collect(internal: *InternalState) void {
    var r: usize = 0;
    while (r < internal.records.items.len) {
        const record = internal.records.items[r];
        if (internal.ongoing_event == record or record.waits > 0 or record.dispatching or record.invoking) {
            r += 1;
            continue;
        }
        _ = internal.records.swapRemove(r);
        record.destroy(internal.allocator);
    }
    var t: usize = 0;
    while (t < internal.trackers.items.len) {
        const tracker = internal.trackers.items[t];
        if (!tracker.cleaned_up or trackerInUse(internal, tracker)) {
            t += 1;
            continue;
        }
        _ = internal.trackers.swapRemove(t);
        tracker.destroy(internal.allocator, internal.navigation);
    }
}

fn trackerInUse(internal: *InternalState, tracker: *Tracker) bool {
    if (tracker.held) return true;
    if (internal.ongoing_tracker == tracker or internal.handoff == tracker) return true;
    for (internal.upcoming.items) |t| if (t == tracker) return true;
    for (internal.records.items) |record| if (record.tracker == tracker) return true;
    return false;
}

// ============================================================================
// Activation (HTML 7.2.6.9) and the pageswap event's (HTML 7.4.6.1)
// ============================================================================

/// "Navigation's activation": made once, from what the navigation that
/// committed the document recorded (joint_history.Activation), and held
/// from then on. Null while the document is not fully active, for the
/// initial about:blank, and when entries and events are disabled - there is
/// then no current entry to be its new entry.
fn activationObject(instance: *runtime.Instance, internal: *InternalState) ?*runtime.Instance {
    if (internal.activation) |activation| return activation;
    const scope = scopeOf(instance, internal);
    if (navigation_entries.disabled(scope)) return null;
    const s = scope.?;
    const current = s.history.currentEntry(s.navigable.id) orelse return null;
    const made = (if (s.history.activationOf(current.document_state)) |record|
        activationFromRecord(internal, s, current, record)
    else
        hostActivation(internal, s, current)) orelse return null;
    internal.activation = made;
    internal.activation_edge.hold(internal.navigation, made);
    return made;
}

/// "Update document for history step application" step 7, from its record:
/// 7.2-7.4 the old entry - the entry list's entry for
/// previousEntryForActivation, or, for a "replace" by a same-origin
/// document, a new NavigationHistoryEntry for it; 7.5 the new entry -
/// navigation's current entry when the document was activated; 7.6 the
/// navigation type.
///
/// Deviation, stated: step 7.4 also requires previousEntryForActivation's
/// document not to be the initial about:blank. Chrome and Firefox give the
/// initial about:blank's entry as the old entry of the navigation that
/// replaces it (navigation-activation/activation-initial-about-blank.html
/// passes in both), and so does Crane.
fn activationFromRecord(internal: *InternalState, s: navigation_entries.Scope, current: *const joint_history.Entry, record: *const joint_history.Activation) ?*runtime.Instance {
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    const listed = entryList(s, internal.allocator, &entries) != null;
    var from: ?*runtime.Instance = null;
    var from_detached = false;
    if (record.previous) |*previous| {
        // Step 3: "If previousEntryIndex is non-negative, then set
        // activation's old entry to navigation's entry list[previousEntryIndex]."
        if (listed) for (entries.items) |entry| {
            if (entry.id == previous.id) from = entryObject(internal, s.window, entry) catch null;
        };
        // Step 4.
        if (from == null and record.navigation_type == .replace and
            std.mem.eql(u8, previous.origin, current.origin))
        {
            from = detachedEntryObject(s.window, previous);
            from_detached = from != null;
        }
    }
    const generation: u64 = if (from) |f| runtime.SlabAllocator.generationOf(f) else 0;
    defer if (from_detached) from.?.releaseIfUnwrapped(generation);
    const entry = activatedEntry(internal, s, &record.entry) orelse return null;
    return makeActivation(s.window, .{ .from = from, .entry = entry.instance, .navigation_type = kindOf(record.navigation_type) }, entry);
}

/// The activation of a document no navigation of Crane's committed - the
/// top-level page the host loaded: that of the navigation that replaced its
/// top-level traversable's initial about:blank, which the host never made.
/// Its old entry is null (there is no entry before it), its new entry the
/// entry it was loaded with - its document state's first - and its type
/// "replace".
fn hostActivation(internal: *InternalState, s: navigation_entries.Scope, current: *const joint_history.Entry) ?*runtime.Instance {
    var first: *const joint_history.Entry = current;
    for (s.history.entries.items) |*entry| {
        if (entry.navigable == s.navigable.id and entry.document_state == current.document_state and entry.step < first.step) first = entry;
    }
    var snapshot = s.history.snapshot(first) catch return null;
    defer snapshot.deinit(s.history.allocator);
    const entry = activatedEntry(internal, s, &snapshot) orelse return null;
    return makeActivation(s.window, .{ .from = null, .entry = entry.instance, .navigation_type = .replace }, entry);
}

/// The NavigationHistoryEntry an activation's new entry is: the one the
/// navigation API hands out for the entry, while the history still has it,
/// or a new one for the entry as it was.
const ActivatedEntry = struct {
    instance: *runtime.Instance,
    /// Made for this activation alone: let go if the activation is not made.
    detached: bool,
    generation: u64,
};

fn activatedEntry(internal: *InternalState, s: navigation_entries.Scope, snapshot: *const joint_history.EntrySnapshot) ?ActivatedEntry {
    if (s.history.entryById(snapshot.id)) |entry| {
        if (entry.navigable == s.navigable.id) {
            const handed = entryObject(internal, s.window, entry) catch return null;
            return .{ .instance = handed, .detached = false, .generation = 0 };
        }
    }
    const made = detachedEntryObject(s.window, snapshot) orelse return null;
    return .{ .instance = made, .detached = true, .generation = runtime.SlabAllocator.generationOf(made) };
}

/// A new NavigationActivation in `window`'s realm; null when it cannot be
/// made. `entry` is its new entry, let go here if it was made for it alone
/// and nothing came to hold it.
fn makeActivation(window: *runtime.Instance, init_state: dom.navigation_objects.ActivationInit, entry: ActivatedEntry) ?*runtime.Instance {
    defer if (entry.detached) entry.instance.releaseIfUnwrapped(entry.generation);
    const hook = dom.navigation_objects;
    return hook.createActivation(window.ctx, init_state) catch |err| {
        log.debug("[navigation] no activation: {s}", .{@errorName(err)});
        return null;
    };
}

/// "A new NavigationHistoryEntry in" `window`'s realm "whose session history
/// entry is" the entry `snapshot` describes - one the navigation API does not
/// keep, because the entry is not (or no longer) in its entry list. Unwrapped
/// until something holds it.
fn detachedEntryObject(window: *runtime.Instance, snapshot: *const joint_history.EntrySnapshot) ?*runtime.Instance {
    const hook = dom.navigation_history_entries;
    const entry = snapshot.asEntry();
    return hook.create(window, @ptrCast(&entry)) catch null;
}

fn kindOf(navigation_type: joint_history.NavigationType) Kind {
    return switch (navigation_type) {
        .push => .push,
        .replace => .replace,
        .reload => .reload,
        .traverse => .traverse,
    };
}

/// dom.navigation_api: HTML "fire the pageswap event" steps 2-4 for
/// `window`'s navigation API. "Let destinationEntry be determined by
/// switching on navigationType: reload - the current entry of navigation;
/// traverse - the NavigationHistoryEntry in navigation's entry list whose
/// session history entry is targetEntry; push, replace - a new
/// NavigationHistoryEntry in displayedDocument's relevant realm with its
/// session history entry set to targetEntry." Then a new
/// NavigationActivation with old entry the current entry of navigation, new
/// entry destinationEntry, and navigation type navigationType.
///
/// A traversal's target that is not in the entry list - which step 4's
/// same-origin condition rules out in the spec - gets a new entry object as
/// for a push.
///
/// Deviation, stated: History's traversal sets the traversable's current
/// step before it navigates the navigables that change documents (the spec
/// sets it once they are all updated), so for a traversal the current entry
/// - the old entry here, and what navigation.currentEntry reads in the
/// listener - is already the target.
fn pageSwapActivationHook(window: *runtime.Instance, swap: *const dom.navigation_api.PageSwap) ?*runtime.Instance {
    const target = targetOf(window) orelse return null;
    const instance = target.instance;
    const internal = target.internal;
    const s = scopeOf(instance, internal) orelse return null;
    const from = currentEntryObject(instance, internal) catch null;
    const destination: ActivatedEntry = switch (swap.navigation_type) {
        .reload => if (from) |current| .{ .instance = current, .detached = false, .generation = 0 } else detached(s, swap.target) orelse return null,
        .traverse => listedEntry(internal, s, swap.target.id) orelse detached(s, swap.target) orelse return null,
        .push, .replace => detached(s, swap.target) orelse return null,
    };
    return makeActivation(window, .{ .from = from, .entry = destination.instance, .navigation_type = swap.navigation_type }, destination);
}

fn detached(s: navigation_entries.Scope, snapshot: *const joint_history.EntrySnapshot) ?ActivatedEntry {
    const made = detachedEntryObject(s.window, snapshot) orelse return null;
    return .{ .instance = made, .detached = true, .generation = runtime.SlabAllocator.generationOf(made) };
}

/// The entry list's NavigationHistoryEntry for the session history entry
/// `entry_id`, if the list has it.
fn listedEntry(internal: *InternalState, s: navigation_entries.Scope, entry_id: u64) ?ActivatedEntry {
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    if (entryList(s, internal.allocator, &entries) == null) return null;
    for (entries.items) |entry| {
        if (entry.id != entry_id) continue;
        const handed = entryObject(internal, s.window, entry) catch return null;
        return .{ .instance = handed, .detached = false, .generation = 0 };
    }
    return null;
}

// ============================================================================
// Firing the navigate event (HTML 7.2.6.10.4)
// ============================================================================

/// The Navigation of `window`, and its state.
const Target = struct {
    instance: *runtime.Instance,
    internal: *InternalState,
};

fn targetOf(window: *runtime.Instance) ?Target {
    for (live.items) |instance| {
        const internal = getInternal(instance) orelse continue;
        if (windowOf(instance, internal) == window) return .{ .instance = instance, .internal = internal };
    }
    return null;
}

/// dom.navigation_api: HTML "fire a push/replace/reload navigate event".
fn firePushReplaceReloadHook(window: *runtime.Instance, args: *const dom.navigation_api.PushReplaceReload) bool {
    const target = targetOf(window) orelse return true;
    return firePushReplaceReload(target.instance, target.internal, args);
}

fn firePushReplaceReload(instance: *runtime.Instance, internal: *InternalState, args: *const dom.navigation_api.PushReplaceReload) bool {
    // The apiMethodTracker navigate() or reload() hands over.
    var tracker: ?*Tracker = internal.handoff;
    internal.handoff = null;
    // Step 2: "Inform the navigation API about aborting navigation in
    // document's node navigable."
    informAboutAbortingNavigation(instance, internal);
    // Step 3: "If navigation has entries and events disabled, and
    // apiMethodTracker is not null: set apiMethodTracker's pending to false;
    // set apiMethodTracker to null."
    const scope = scopeOf(instance, internal);
    if (tracker) |t| if (navigation_entries.disabled(scope)) {
        t.pending = false;
        cleanUp(internal, t);
        tracker = null;
    };
    // Step 4: "If document is not fully active, then return false."
    const s = scope orelse {
        if (tracker) |t| cleanUp(internal, t);
        return false;
    };
    // Steps 7-11: the destination.
    const api_state: joint_history.SerializedState = args.navigation_api_state orelse
        (if (tracker) |t| (t.serialized_state orelse .null) else .null);
    const destination = makeDestination(instance, .{
        .url = args.destination_url,
        .state = api_state,
        .is_same_document = args.is_same_document,
    }) orelse {
        if (tracker) |t| cleanUp(internal, t);
        return true;
    };
    // Step 12.
    return innerFire(instance, internal, s, .{
        .navigation_type = args.navigation_type,
        .destination = destination,
        .destination_url = args.destination_url,
        .is_same_document = args.is_same_document,
        .user_involvement = args.user_involvement,
        .source_element = args.source_element,
        .classic_state = args.classic_history_api_state,
        .form_data = args.form_data,
        .tracker = tracker,
    });
}

/// dom.navigation_api: HTML "fire a traverse navigate event" for the session
/// history entry `entry_id`.
fn fireTraverseHook(window: *runtime.Instance, entry_id: u64, user_involvement: dom.navigation_api.UserInvolvement) bool {
    const target = targetOf(window) orelse return true;
    const instance = target.instance;
    const internal = target.internal;
    const s = scopeOf(instance, internal) orelse return true;
    const destination_she = s.history.entryById(entry_id) orelse return true;
    // Steps 5-7: the destination's entry, when the entry list has it, and
    // its state.
    var destination_nhe: ?*runtime.Instance = null;
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    if (entryList(s, internal.allocator, &entries) != null) {
        for (entries.items) |entry| {
            if (entry.id == entry_id) destination_nhe = entryObject(internal, s.window, entry) catch null;
        }
    }
    // Step 8: "is same document" if the entry's document is the window's.
    const same_document = destination_she.document != null and destination_she.document == @as(?*anyopaque, @ptrCast(s.document));
    const url = internal.allocator.dupe(u8, destination_she.url) catch return true;
    defer internal.allocator.free(url);
    const destination = makeDestination(instance, .{
        .url = url,
        .entry = destination_nhe,
        .state = if (destination_nhe != null) destination_she.api_state else .null,
        .is_same_document = same_document,
    }) orelse return true;
    // Step 9.
    return innerFire(instance, internal, s, .{
        .navigation_type = .traverse,
        .destination = destination,
        .destination_url = url,
        .destination_entry = destination_nhe,
        .is_same_document = same_document,
        .user_involvement = user_involvement,
    });
}

/// dom.navigation_api: HTML "fire a download request navigate event".
fn fireDownloadRequestHook(window: *runtime.Instance, destination_url: []const u8, user_involvement: dom.navigation_api.UserInvolvement, source_element: ?*runtime.Instance, filename: []const u8) bool {
    const target = targetOf(window) orelse return true;
    const instance = target.instance;
    const internal = target.internal;
    // Deviation, stated: the navigation in progress is aborted first, as
    // "fire a push/replace/reload navigate event" step 2 does - the download
    // request steps leave it ongoing (the inner algorithm's step 2 asserts no
    // ongoing API method tracker), and Blink aborts it
    // (ordering-and-transition/anchor-download-aborts-previous-navigation).
    informAboutAbortingNavigation(instance, internal);
    const s = scopeOf(instance, internal) orelse return true;
    // Steps 2-7: classic history API state null, and a destination at
    // destinationURL with no entry, state StructuredSerializeForStorage(null)
    // and is same document false.
    const destination = makeDestination(instance, .{
        .url = destination_url,
        .state = .null,
        .is_same_document = false,
    }) orelse return true;
    // Step 8: "Return the result of performing the inner navigate event
    // firing algorithm given navigation, "push", event, destination,
    // userInvolvement, sourceElement, null, and filename."
    return innerFire(instance, internal, s, .{
        .navigation_type = .push,
        .destination = destination,
        .destination_url = destination_url,
        .is_same_document = false,
        .user_involvement = user_involvement,
        .source_element = source_element,
        .download_request = filename,
    });
}

/// A new NavigationDestination in `instance`'s relevant realm; null when it
/// could not be made (the navigation then goes on without an event).
fn makeDestination(instance: *runtime.Instance, init_state: dom.navigation_objects.DestinationInit) ?*runtime.Instance {
    const hook = dom.navigation_objects;
    return hook.createDestination(instance.ctx, init_state) catch |err| {
        log.debug("[navigation] no destination: {s}", .{@errorName(err)});
        return null;
    };
}

/// The inner navigate event firing algorithm's arguments.
const Firing = struct {
    navigation_type: Kind,
    destination: *runtime.Instance,
    /// The destination's URL. BORROWED.
    destination_url: []const u8,
    destination_entry: ?*runtime.Instance = null,
    is_same_document: bool,
    user_involvement: dom.navigation_api.UserInvolvement = .none,
    source_element: ?*runtime.Instance = null,
    classic_state: ?joint_history.SerializedState = null,
    /// "formDataEntryList", as a FormData holding it. BORROWED.
    form_data: ?*runtime.Instance = null,
    /// "downloadRequestFilename": a download's filename (the hyperlink's
    /// download attribute value), null for a navigation. BORROWED.
    download_request: ?[]const u8 = null,
    tracker: ?*Tracker = null,
};

/// HTML "the inner navigate event firing algorithm": whether the navigation
/// continues.
fn innerFire(instance: *runtime.Instance, internal: *InternalState, scope: navigation_entries.Scope, firing: Firing) bool {
    const allocator = internal.allocator;
    const realm = instance.ctx;
    const destination_generation = runtime.SlabAllocator.generationOf(firing.destination);
    var destination_held = false;
    defer if (!destination_held) firing.destination.releaseIfUnwrapped(destination_generation);
    var tracker = firing.tracker;

    // Step 1: "If navigation has entries and events disabled, then return
    // true."
    if (navigation_entries.disabled(scope)) {
        if (tracker) |t| cleanUp(internal, t);
        return true;
    }
    // Step 2: "Assert: navigation's ongoing API method tracker is null."
    if (internal.ongoing_tracker) |stale| cleanUp(internal, stale);
    // Step 3: "If destination's entry is non-null ... If navigation's
    // upcoming traverse API method trackers[destinationKey] exists: set
    // apiMethodTracker to it and remove it."
    if (firing.destination_entry) |entry| {
        const key = interfaces.NavigationHistoryEntry.get_key(entry) catch runtime.DOMString.initEmpty();
        var key_copy = key;
        defer key_copy.deinit(realm.allocator);
        if (key.asSlice().len == 36) {
            var destination_key: [36]u8 = undefined;
            @memcpy(&destination_key, key.asSlice()[0..36]);
            if (upcomingTracker(internal, &destination_key)) |found| {
                tracker = found.tracker;
                _ = internal.upcoming.orderedRemove(found.index);
            }
        }
    }
    // Step 4: "If apiMethodTracker is null: ... set apiMethodTracker to the
    // result of setting up a navigate/reload API method tracker for this
    // given undefined and null."
    if (tracker == null) {
        tracker = setUpNavigateReloadTracker(instance, internal, runtime.JSValue.jsUndefined, null) catch return true;
        // Deviation, stated: nobody can hold this tracker's committed
        // promise, so it is marked as handled - rejecting it when the
        // navigation is canceled or aborted would otherwise report an
        // unhandled rejection no browser reports.
        engine.markPromiseAsHandled(realm, tracker.?.committed.promise);
    }
    const api_tracker = tracker.?;
    // Steps 5-6.
    internal.ongoing_tracker = api_tracker;
    api_tracker.pending = false;

    // Steps 7-8.
    const navigable = scope.navigable;
    const document_url = interfaces.Document.get_URL(scope.document) catch return true;
    defer scope.document.ctx.allocator.free(document_url);

    // Step 9: canIntercept.
    const can_intercept = navigate_steps.canHaveUrlRewritten(document_url, firing.destination_url) and
        (firing.is_same_document or firing.navigation_type != .traverse);
    // Step 10: traverseCanBeCanceled. No navigation here is "browser UI".
    const traverse_can_be_canceled = navigable.parent == null and firing.is_same_document and
        firing.user_involvement != .browser_ui;
    // Step 11: cancelable.
    const cancelable = firing.navigation_type != .traverse or traverse_can_be_canceled;
    // Steps 19-20: the abort controller and its signal.
    const controller = interfaces.AbortController.call_constructor(realm) catch return true;
    const controller_generation = runtime.SlabAllocator.generationOf(controller);
    const signal = interfaces.AbortController.get_signal(controller) catch {
        controller.releaseIfUnwrapped(controller_generation);
        return true;
    };
    // Step 22: hashChange.
    const hash_change = firing.classic_state == null and firing.is_same_document and
        navigate_steps.equalsExcludingFragments(firing.destination_url, document_url) and
        !optionalEql(navigate_steps.fragmentOf(firing.destination_url), navigate_steps.fragmentOf(document_url));
    // Step 16: "If formDataEntryList is not null, then initialize event's
    // formData to a new FormData created in navigation's relevant realm,
    // associated to formDataEntryList." A FormData of this realm with the
    // same entries.
    const form_data: ?*runtime.Instance = if (firing.form_data) |source| formDataIn(realm, source) catch null else null;
    const form_data_generation = if (form_data) |fd| runtime.SlabAllocator.generationOf(fd) else 0;
    defer if (form_data) |fd| fd.releaseIfUnwrapped(form_data_generation);
    // The tracker's info, read back from the navigation's wrapper.
    const info: ?engine.Owned = if (api_tracker.info_slot) |slot| engine.tracedValue(instance, slot) else null;
    defer if (info) |i| i.release();
    // Steps 1, 12-24: the event.
    const event = interfaces.NavigateEvent.call_constructor(realm, runtime.DOMString.initInterned("navigate"), .{
        .base = .{ .cancelable = cancelable },
        .navigationType = navigationTypeOf(firing.navigation_type),
        .destination = firing.destination,
        .canIntercept = can_intercept,
        .userInitiated = firing.user_involvement != .none,
        .hashChange = hash_change,
        .signal = signal,
        .formData = form_data,
        .downloadRequest = if (firing.download_request) |filename| runtime.DOMString.initInterned(filename) else null,
        .info = if (info) |i| i.borrow() else null,
        .hasUAVisualTransition = false,
        .sourceElement = firing.source_element,
    }) catch |err| {
        log.debug("[navigation] no navigate event: {s}", .{@errorName(err)});
        controller.releaseIfUnwrapped(controller_generation);
        return true;
    };
    destination_held = true;

    // Steps 25-28: the ongoing navigate event.
    const record = allocator.create(EventRecord) catch {
        event.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(event));
        controller.releaseIfUnwrapped(controller_generation);
        return true;
    };
    record.* = .{
        .id = internal.next_record_id,
        .navigation = internal.navigation,
        .event = event,
        .navigation_type = firing.navigation_type,
        .destination = firing.destination,
        .controller = controller,
        .tracker = api_tracker,
        .user_involvement = firing.user_involvement,
        .same_document = firing.is_same_document,
    };
    internal.next_record_id += 1;
    if (firing.classic_state) |state| record.classic_state = state.clone(allocator) catch null;
    record.event_edge.slot = recordSlot(&record.event_slot, "event", record.id);
    record.event_edge.hold(record.navigation, event);
    record.controller_edge.slot = recordSlot(&record.controller_slot, "controller", record.id);
    record.controller_edge.hold(record.navigation, controller);
    internal.records.append(allocator, record) catch {
        record.destroy(allocator);
        return true;
    };
    internal.ongoing_event = record;
    internal.focus_changed = false;
    internal.suppress_scroll = false;

    // Step 29: "Let dispatchResult be the result of dispatching event at
    // navigation."
    record.dispatching = true;
    const dispatch_result = EventTargetImpl.dispatchTrusted(instance, event) catch true;
    record.dispatching = false;
    defer collect(internal);

    // Step 30: canceled.
    if (!dispatch_result) {
        // 30.1: consuming history-action activation is not modelled.
        // 30.2: "If event's abort controller's signal is not aborted, then
        // abort the ongoing navigation given navigation."
        if (!signalAborted(record) and internal.ongoing_event == record) abortOngoingNavigation(instance, internal, null);
        return false;
    }

    // Step 32: "If event's interception state is "none", then return true."
    // A same-document navigation nobody intercepted settles when its update
    // runs the navigate event intercept commit handler steps ("update the
    // navigation API entries for a same-document navigation" step 14) - with
    // no handlers, navigatesuccess a microtask later. A cross-document one
    // keeps its navigate event and API method tracker ongoing: a later
    // navigation aborts them, rejecting the tracker's promises
    // (ordering-and-transition/navigate-cross-document-double). Deviation,
    // stated: step 30 commits it, and commit step 9 cleans that tracker up -
    // which leaves it ongoing in Blink and the WPT ordering tests.
    if (record.interception_state == .none) return true;

    // Steps 32-33: "Let fromNHE be the current entry of navigation."
    const from = (currentEntryObject(instance, internal) catch null) orelse {
        processHandlerFailureWithAbortError(instance, internal, record);
        return false;
    };
    // Steps 34-36: the transition, its promises marked as handled.
    setTransition(instance, internal, record, from);

    // Step 37: "If event's navigation precommit handler list is empty, then
    // commit event given apiMethodTracker and return false."
    if (record.precommit_handlers.items.len == 0) {
        commit(instance, internal, record);
        return false;
    }
    // Steps 38-41: the precommit handlers, awaited.
    runPrecommitHandlers(instance, internal, record);
    // Step 42.
    return false;
}

fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
    if (a) |x| return if (b) |y| std.mem.eql(u8, x, y) else false;
    return b == null;
}

/// A new FormData in `realm` whose entry list is `source`'s: the entries a
/// form submission's navigate event reports. Only string entries are carried
/// over (FormData's append(name, blob) is not implemented).
fn formDataIn(realm: runtime.Context, source: *runtime.Instance) !*runtime.Instance {
    const form_data = try interfaces.FormData.call_constructor(realm, webidl.Opt(*runtime.Instance).notPassed(), webidl.Opt(?*runtime.Instance).notPassed());
    errdefer form_data.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(form_data));
    for (interfaces.FormData.getEntriesForIterable(source) orelse &.{}) |entry| switch (entry.value) {
        .usvstring => |value| try interfaces.FormData.call_append(form_data, entry.name, value),
        .file => {},
    };
    return form_data;
}

fn navigationTypeOf(kind: Kind) enums.NavigationType {
    return switch (kind) {
        .push => ._push_,
        .replace => ._replace_,
        .reload => ._reload_,
        .traverse => ._traverse_,
    };
}

fn signalAborted(record: *EventRecord) bool {
    const signal = interfaces.AbortController.get_signal(record.controller) catch return true;
    return interfaces.AbortSignal.get_aborted(signal) catch true;
}

/// Steps 34-36: navigation's transition - a new NavigationTransition, with
/// new committed and finished promises marked as handled.
fn setTransition(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord, from: *runtime.Instance) void {
    const realm = instance.ctx;
    if (internal.transition) |old| {
        old.destroy(internal.allocator);
        internal.transition = null;
    }
    var committed = engine.createPromise(realm) catch return;
    var finished = engine.createPromise(realm) catch {
        engine.releasePromiseCapability(&committed);
        return;
    };
    engine.markPromiseAsHandled(realm, finished.promise);
    engine.markPromiseAsHandled(realm, committed.promise);
    const hook = dom.navigation_objects;
    const transition_instance = hook.createTransition(realm, .{
        .navigation_type = record.navigation_type,
        .from = from,
        .destination = record.destination,
        .committed = committed.promise,
        .finished = finished.promise,
    }) catch {
        engine.releasePromiseCapability(&committed);
        engine.releasePromiseCapability(&finished);
        return;
    };
    const transition = internal.allocator.create(Transition) catch {
        engine.releasePromiseCapability(&committed);
        engine.releasePromiseCapability(&finished);
        transition_instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(transition_instance));
        return;
    };
    transition.* = .{ .navigation = internal.navigation, .instance = transition_instance, .committed = committed, .finished = finished };
    transition.edge.hold(internal.navigation, transition_instance);
    internal.transition = transition;
}

/// Steps 38-41: a NavigationPrecommitController for the event, each
/// precommit handler invoked with it, and all their promises awaited.
fn runPrecommitHandlers(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord) void {
    const realm = instance.ctx;
    const hook = dom.navigation_objects;
    const controller = hook.createController(realm, record.event) catch {
        processHandlerFailureWithAbortError(instance, internal, record);
        return;
    };
    const controller_generation = runtime.SlabAllocator.generationOf(controller);
    defer controller.releaseIfUnwrapped(controller_generation);
    var promises: std.ArrayListUnmanaged(engine.Owned) = .empty;
    defer {
        for (promises.items) |p| p.release();
        promises.deinit(internal.allocator);
    }
    // The list can grow while it is walked: a handler's own addHandler()
    // adds to the navigation handler list, not this one. The record is held
    // while they run: a handler can abort the navigation.
    record.invoking = true;
    var i: usize = 0;
    while (i < record.precommit_handlers.items.len) : (i += 1) {
        const handler = record.precommit_handlers.items[i];
        const promise = invokeToPromise(realm, &handler, &.{.{ .instance = controller }}) orelse continue;
        promises.append(internal.allocator, promise) catch {
            promise.release();
            continue;
        };
    }
    record.invoking = false;
    var values: std.ArrayListUnmanaged(runtime.JSValue) = .empty;
    defer values.deinit(internal.allocator);
    for (promises.items) |p| values.append(internal.allocator, p.value) catch {};
    waitForAll(instance, record, .precommit, values.items);
}

/// WebIDL "invoke" `handler` - whose return type is a promise type - with
/// `args`: the promise it returned, or one resolved with what it returned,
/// or rejected with what it threw. OWNED; null when it could not run.
fn invokeToPromise(realm: runtime.Context, handler: *const engine.CallbackFunction, args: []const runtime.JSValue) ?engine.Owned {
    const completion = engine.invokeCallbackFunction(realm, handler, .undefined, args, .rethrow) catch |err| {
        log.debug("[navigation] handler not invoked: {s}", .{@errorName(err)});
        return null;
    };
    return switch (completion) {
        .normal => |value| blk: {
            defer value.release();
            break :blk engine.createResolvedPromise(realm, value.value) catch null;
        },
        .throw => |reason| blk: {
            defer reason.release();
            break :blk engine.createRejectedPromise(realm, reason.value) catch null;
        },
    };
}

/// HTML "commit a navigate event" given the event's record, for an event
/// that was intercepted (step 7; innerFire returns for the others).
fn commit(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord) void {
    const realm = instance.ctx;
    // Step 3: "If event's relevant global object's associated Document is not
    // fully active, then return."
    const scope = scopeOf(instance, internal) orelse return;
    // Step 4: "If event's abort controller's signal is aborted, then return."
    if (signalAborted(record)) return;
    // Step 6: "Prepare to run script given navigation's relevant settings
    // object" - microtasks wait until the update below has fired its events
    // and invoked the handlers.
    const script_scope = engine.prepareToRunScript(realm) catch null;
    defer if (script_scope) |s| engine.cleanUpAfterRunningScript(s);
    // Step 7.1.
    record.interception_state = .committed;
    // Step 7.2.
    switch (record.navigation_type) {
        .push, .replace => {
            // "Run the URL and history update steps given event's relevant
            // global object's associated Document and event's destination's
            // URL, with serializedData set to event's classic history API
            // state and historyHandling set to event's navigationType."
            const url = interfaces.NavigationDestination.get_url(record.destination) catch return;
            defer record.destination.ctx.allocator.free(url);
            ensureHistoryTraversal(scope.window);
            dom.history_traversal.urlAndHistoryUpdate(scope.window, url, record.classic_state, if (record.navigation_type == .push) .push else .replace);
        },
        .reload => sameDocumentNavigation(scope.window, .reload),
        .traverse => {
            // 1. "Set navigation's suppress normal scroll restoration during
            // ongoing navigation to true."
            internal.suppress_scroll = true;
            // 4. "Append the following session history traversal steps to
            // navigable's traversable navigable: resume applying the traverse
            // history step given event's destination's entry's session
            // history entry's step."
            const entry = dom.navigation_objects.destinationEntry(record.destination) orelse return;
            const entry_id = dom.navigation_history_entries.entryId(entry);
            const she = scope.history.entryById(entry_id) orelse return;
            ensureHistoryTraversal(scope.window);
            dom.history_traversal.resumeTraversal(scope.window, she.step);
        },
    }
    // Step 8: "If navigation's transition is not null, then resolve
    // navigation's transition's committed promise with undefined."
    if (internal.transition) |transition| engine.resolvePromise(&transition.committed, runtime.JSValue.jsUndefined) catch {};
    // Step 9 cleans up the tracker of a navigation whose end result is not
    // same-document: an intercepted one always is. Step 10 is the defer
    // above. The handlers run when the update the switch above started
    // reaches the navigation API entries (interceptCommitHandlerSteps).
}

/// HTML "navigate event intercept commit handler steps" for the event
/// `record`, run by "update the navigation API entries for a same-document
/// navigation" (step 14) after currententrychange and dispose: each of the
/// event's navigation handlers invoked, and "wait for all" of their
/// promises - one resolved with undefined when there are none - whose
/// success steps fire navigatesuccess and whose failure step processes the
/// handler failure. Once per event.
fn interceptCommitHandlerSteps(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord) void {
    if (record.handlers_run) return;
    record.handlers_run = true;
    const realm = instance.ctx;
    // Steps 1-2: "For each handler of event's navigation handler list:
    // append the result of invoking handler with an empty arguments list to
    // promisesList."
    var promises: std.ArrayListUnmanaged(engine.Owned) = .empty;
    defer {
        for (promises.items) |p| p.release();
        promises.deinit(internal.allocator);
    }
    // The record is held while they run (a handler that removes its frame
    // aborts the navigation, which would let the record go), and a handler
    // that calls intercept() again cannot add to it: interception state is
    // "committed".
    record.invoking = true;
    var i: usize = 0;
    while (i < record.handlers.items.len) : (i += 1) {
        const handler = record.handlers.items[i];
        const promise = invokeToPromise(realm, &handler, &.{}) orelse continue;
        promises.append(internal.allocator, promise) catch promise.release();
    }
    record.invoking = false;
    var values: std.ArrayListUnmanaged(runtime.JSValue) = .empty;
    defer values.deinit(internal.allocator);
    for (promises.items) |p| values.append(internal.allocator, p.value) catch {};
    // Steps 3-4: none is one resolved with undefined (waitForAll), then
    // "wait for all of promisesList".
    waitForAll(instance, record, .handlers, values.items);
}

/// The ongoing navigate event whose handlers a same-document update runs
/// (step 14's navigateEvent): one that is not being dispatched - an update
/// its own listener made (history.pushState() in onnavigate) is not its
/// commit - and that either committed an interception or, uninterepted,
/// navigates to a same-document destination. Null for none: an update no
/// navigate event led to (none was fired, or a cross-document navigation's
/// is ongoing), which the standard leaves unguarded.
fn eventForUpdate(internal: *InternalState) ?*EventRecord {
    const record = internal.ongoing_event orelse return null;
    if (record.dispatching or record.handlers_run) return null;
    return switch (record.interception_state) {
        .committed => record,
        .none => if (record.same_document) record else null,
        .intercepted, .scrolled, .finished => null,
    };
}

/// What a "wait for all" settles.
const WaitPhase = enum { precommit, handlers };

/// WebIDL "wait for all" of `promises` (BORROWED), for the event `record`:
/// the success steps or the failure steps of `phase`, in a microtask.
fn waitForAll(instance: *runtime.Instance, record: *EventRecord, phase: WaitPhase, promises: []const runtime.JSValue) void {
    const realm = instance.ctx;
    // "If total is 0, then queue a microtask to perform successSteps": the
    // same as waiting for one promise resolved with undefined.
    var resolved: ?engine.Owned = null;
    defer if (resolved) |r| r.release();
    var list = promises;
    var single: [1]runtime.JSValue = undefined;
    if (list.len == 0) {
        resolved = engine.createResolvedPromise(realm, runtime.JSValue.jsUndefined) catch return;
        single[0] = resolved.?.value;
        list = &single;
    }
    const wait = std.heap.c_allocator.create(Wait) catch return;
    wait.* = .{
        .navigation = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .record_id = record.id,
        .phase = phase,
        .remaining = list.len,
        .live = list.len,
    };
    record.waits += 1;
    // One reference of its own while the reactions are set up: a reaction
    // can run - and release - only after this returns, but a failure below
    // releases now.
    wait.live += 1;
    defer wait.release();
    for (list, 0..) |promise, i| {
        engine.reactToPromise(realm, promise, &Wait.steps, wait) catch {
            // The rest never react: the wait ends here, without an outcome.
            wait.live -= list.len - i;
            if (!wait.done) {
                wait.done = true;
                wait.deliver();
            }
            return;
        };
    }
}

/// One "wait for all": its promises' reactions share it, and the last to
/// run frees it. The navigation is held by address and slab generation - a
/// reaction can run after the page is gone.
///
/// The outcome is delivered by the reaction that decides it, as WebIDL's
/// fulfillment and rejection handlers perform successSteps and failureSteps:
/// for promises already settled when the wait begins, in the first
/// microtask after the navigation, before the reactions script attaches to
/// the navigation's promises afterwards (ordering-and-transition/:
/// navigatesuccess before "committed fulfilled").
const Wait = struct {
    navigation: *runtime.Instance,
    generation: u64,
    record_id: u64,
    phase: WaitPhase,
    remaining: usize,
    live: usize,
    done: bool = false,
    outcome: ?Outcome = null,
    /// The rejection reason, held until it is delivered.
    reason: ?engine.Owned = null,

    const Outcome = enum { fulfilled, rejected };

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .rejected = rejected, .dropped = droppedWait };

    /// A reaction that ended without a step - its realm ended first: only
    /// the reference it held goes; nothing is delivered.
    fn droppedWait(data: ?*anyopaque) void {
        const self: *Wait = @ptrCast(@alignCast(data.?));
        self.release();
    }

    fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Wait = @ptrCast(@alignCast(data.?));
        if (!self.done) {
            self.remaining -= 1;
            if (self.remaining == 0) self.decide(.fulfilled, runtime.JSValue.jsUndefined);
        }
        self.release();
    }

    fn rejected(data: ?*anyopaque, reason: runtime.JSValue) void {
        const self: *Wait = @ptrCast(@alignCast(data.?));
        if (!self.done) self.decide(.rejected, reason);
        self.release();
    }

    /// The outcome is known: deliver it now.
    fn decide(self: *Wait, outcome: Outcome, reason: runtime.JSValue) void {
        self.done = true;
        self.outcome = outcome;
        if (runtime.SlabAllocator.generationOf(self.navigation) != self.generation) return;
        const realm = self.navigation.ctx;
        if (outcome == .rejected) self.reason = engine.retainValue(realm, reason) catch null;
        self.deliver();
    }

    fn release(self: *Wait) void {
        self.live -= 1;
        if (self.live > 0) return;
        if (self.reason) |r| r.release();
        std.heap.c_allocator.destroy(self);
    }

    /// The outcome, to the navigation - when it and the record are still
    /// there. None: the wait ended without an outcome.
    fn deliver(self: *Wait) void {
        if (runtime.SlabAllocator.generationOf(self.navigation) != self.generation) return;
        const internal = getInternal(self.navigation) orelse return;
        const record = for (internal.records.items) |r| {
            if (r.id == self.record_id) break r;
        } else return;
        record.waits -= 1;
        defer collect(internal);
        const outcome = self.outcome orelse return;
        switch (outcome) {
            .fulfilled => switch (self.phase) {
                .precommit => commit(self.navigation, internal, record),
                .handlers => successSteps(self.navigation, internal, record),
            },
            .rejected => processHandlerFailure(self.navigation, internal, record, if (self.reason) |r| r.value else runtime.JSValue.jsUndefined),
        }
    }
};

/// Commit step 14's success steps (and those of a same-document navigation
/// nobody intercepted).
fn successSteps(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord) void {
    // 1. "If event's relevant global object is not fully active, then abort
    // these steps."
    _ = scopeOf(instance, internal) orelse return;
    // 2. "If event's abort controller's signal is aborted, then abort these
    // steps."
    if (signalAborted(record)) return;
    // 3-4. The ongoing navigate event ends.
    if (internal.ongoing_event == record) internal.ongoing_event = null;
    // 5. "Finish event given true."
    finish(instance, internal, record, true);
    // 6. "Resolve the finished promise for apiMethodTracker."
    if (record.tracker) |tracker| {
        record.tracker = null;
        resolveFinished(internal, tracker);
    }
    // 7. "Fire an event named navigatesuccess at navigation."
    fireSimple(instance, "navigatesuccess");
    // 8-9. The transition's finished promise, and no transition.
    if (internal.transition) |transition| {
        engine.resolvePromise(&transition.finished, runtime.JSValue.jsUndefined) catch {};
        transition.destroy(internal.allocator);
        internal.transition = null;
    }
}

/// HTML "process navigate event handler failure" given the event's record
/// and `reason` (BORROWED).
fn processHandlerFailure(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord, reason: runtime.JSValue) void {
    // 1. Not fully active: return.
    _ = scopeOf(instance, internal) orelse return;
    // 2. Aborted: return.
    if (signalAborted(record)) return;
    // 3. "Assert: event is ... navigation API's ongoing navigate event."
    if (internal.ongoing_event != record) return;
    // 4. "If event's interception state is not "intercepted", then finish
    // event given false."
    if (record.interception_state != .intercepted) finish(instance, internal, record, false);
    // 5. "Abort event given reason."
    abortEvent(instance, internal, record, reason);
}

fn processHandlerFailureWithAbortError(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord) void {
    const reason = engine.createDOMException(instance.ctx, "AbortError", "The navigation was aborted.") catch return;
    defer reason.release();
    processHandlerFailure(instance, internal, record, reason.value);
}

/// HTML "finish" a NavigateEvent given `did_fulfill`.
fn finish(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord, did_fulfill: bool) void {
    switch (record.interception_state) {
        // 1. Assert: not "finished".
        .finished => return,
        // 2. "If event's interception state is "intercepted" ... set it to
        // "finished" and return."
        .intercepted => {
            record.interception_state = .finished;
            return;
        },
        // 3. "If event's interception state is "none", then return."
        .none => return,
        .committed, .scrolled => {},
    }
    // 4. "Potentially reset the focus given event."
    potentiallyResetFocus(instance, internal, record);
    // 5. "If didFulfill is true, then potentially process scroll behavior
    // given event."
    if (did_fulfill) potentiallyProcessScroll(record);
    // 6.
    record.interception_state = .finished;
}

/// HTML "potentially reset the focus" given the event's record: the body
/// (or the document element) is focused unless focus changed during the
/// navigation or the event asked for "manual". The autofocus delegate is
/// not modelled, stated.
fn potentiallyResetFocus(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord) void {
    // 3-5.
    const focus_changed = internal.focus_changed;
    internal.focus_changed = false;
    if (focus_changed) return;
    // 6.
    if (record.focus_reset == .manual) return;
    // 7-10: the focus target.
    const scope = scopeOf(instance, internal) orelse return;
    const target = (interfaces.Document.get_body(scope.document) catch null) orelse
        (interfaces.Document.get_documentElement(scope.document) catch null) orelse return;
    // 11: "Run the focusing steps for focusTarget."
    if (target.stateAs(interfaces.HTMLElement.State) != null) {
        interfaces.HTMLElement.call_focus(target, webidl.Opt(dictionaries.FocusOptions).notPassed()) catch {};
    }
}

/// HTML "potentially process scroll behavior": with no layout, processing
/// it records only that scrolling happened.
fn potentiallyProcessScroll(record: *EventRecord) void {
    if (record.interception_state == .scrolled) return;
    if (record.scroll_behavior == .manual) return;
    record.interception_state = .scrolled;
}

/// HTML "abort a NavigateEvent" given `reason` (BORROWED).
fn abortEvent(instance: *runtime.Instance, internal: *InternalState, record: *EventRecord, reason: runtime.JSValue) void {
    const realm = instance.ctx;
    // 2. "Signal abort on event's abort controller given reason."
    interfaces.AbortController.call_abort(record.controller, webidl.Opt(runtime.JSValue).passed(reason)) catch {};
    // 3. "Let errorInfo be the result of extracting error information from
    // reason."
    var arena = std.heap.ArenaAllocator.init(internal.allocator);
    defer arena.deinit();
    const info: ?engine.ErrorInfo = engine.extractErrorInformation(realm, reason, arena.allocator()) catch null;
    // 4. "Set navigation's ongoing navigate event to null."
    if (internal.ongoing_event == record) internal.ongoing_event = null;
    // 5. "If navigation's ongoing API method tracker is non-null, then reject
    // the finished promise for apiMethodTracker with reason."
    if (internal.ongoing_tracker) |tracker| {
        if (record.tracker == tracker) record.tracker = null;
        rejectFinished(internal, tracker, reason);
    }
    // 6. "Fire an event named navigateerror at navigation using ErrorEvent,
    // with additional attributes initialized according to errorInfo."
    fireNavigateError(instance, info, reason);
    // 7-10. The transition's promises, rejected, and no transition.
    if (internal.transition) |transition| {
        engine.rejectPromise(&transition.committed, reason) catch {};
        engine.rejectPromise(&transition.finished, reason) catch {};
        transition.destroy(internal.allocator);
        internal.transition = null;
    }
    collect(internal);
}

/// HTML "abort the ongoing navigation" given `error` (BORROWED; null: a new
/// AbortError DOMException in navigation's relevant realm).
fn abortOngoingNavigation(instance: *runtime.Instance, internal: *InternalState, error_value: ?runtime.JSValue) void {
    // 1-2.
    const record = internal.ongoing_event orelse return;
    // 3-4.
    internal.focus_changed = false;
    internal.suppress_scroll = false;
    // 5.
    var made: ?engine.Owned = null;
    defer if (made) |m| m.release();
    const reason: runtime.JSValue = error_value orelse blk: {
        made = engine.createDOMException(instance.ctx, "AbortError", "The navigation was aborted.") catch return;
        break :blk made.?.value;
    };
    // 6. "If event's dispatch flag is set, then set event's canceled flag to
    // true." Deviation, stated: through preventDefault(), which leaves a
    // non-cancelable event (a traversal of a frame) uncanceled.
    if (record.dispatching) interfaces.Event.call_preventDefault(record.event) catch {};
    // 7. "Abort event given error."
    abortEvent(instance, internal, record, reason);
}

/// HTML "inform the navigation API about aborting navigation": abort the
/// ongoing navigate event until there is none (aborting can run script that
/// starts another).
fn informAboutAbortingNavigation(instance: *runtime.Instance, internal: *InternalState) void {
    var guard: usize = 0;
    while (internal.ongoing_event != null and guard < 64) : (guard += 1) {
        abortOngoingNavigation(instance, internal, null);
    }
}

fn informAboutAbortingNavigationHook(window: *runtime.Instance) void {
    const target = targetOf(window) orelse return;
    informAboutAbortingNavigation(target.instance, target.internal);
}

/// HTML "inform the navigation API about child navigable destruction".
fn informAboutChildNavigableDestructionHook(window: *runtime.Instance) void {
    const target = targetOf(window) orelse return;
    const instance = target.instance;
    const internal = target.internal;
    // 1.
    informAboutAbortingNavigation(instance, internal);
    // 2-4: every upcoming traversal's finished promise rejected with a new
    // AbortError.
    while (internal.upcoming.items.len > 0) {
        const tracker = internal.upcoming.items[0];
        const reason = engine.createDOMException(instance.ctx, "AbortError", "The navigable was destroyed.") catch {
            cleanUp(internal, tracker);
            continue;
        };
        defer reason.release();
        rejectFinished(internal, tracker, reason.value);
    }
}

// ============================================================================
// NavigateEvent and NavigationPrecommitController methods
// ============================================================================

/// The navigation that fired `event`, and the event's record there.
const EventOwner = struct {
    instance: *runtime.Instance,
    internal: *InternalState,
    record: *EventRecord,
};

fn ownerOf(event: *runtime.Instance) ?EventOwner {
    const realm_record = event.ctx.getRealm() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(realm_record.global_object orelse return null));
    const target = targetOf(window) orelse return null;
    for (target.internal.records.items) |record| {
        if (record.event == event) return .{ .instance = target.instance, .internal = target.internal, .record = record };
    }
    return null;
}

/// dom.navigation_api: intercept(options) steps 4.2-9.
fn interceptHook(event: *runtime.Instance, options: dom.navigation_api.InterceptOptions) anyerror!void {
    const owner = ownerOf(event) orelse return error.InvalidStateError;
    const record = owner.record;
    const allocator = owner.internal.allocator;
    // 4.2: "Append options["precommitHandler"] to this's navigation precommit
    // handler list."
    if (options.precommit_handler) |handler| {
        try record.precommit_handlers.append(allocator, engine.takeCallbackFunction(handler));
    }
    // 5. Assert: none or intercepted. 6.
    record.interception_state = .intercepted;
    // 7.
    if (options.handler) |handler| {
        try record.handlers.append(allocator, engine.takeCallbackFunction(handler));
    }
    // 8-9. A later value overrides an earlier one (the warning is optional).
    if (options.focus_reset) |f| record.focus_reset = f;
    if (options.scroll) |s| record.scroll_behavior = s;
}

/// dom.navigation_api: scroll() steps 2-3.
fn scrollHook(event: *runtime.Instance) anyerror!void {
    const owner = ownerOf(event) orelse return error.InvalidStateError;
    // 2. "If this's interception state is not "committed", then throw an
    // "InvalidStateError" DOMException."
    if (owner.record.interception_state != .committed) return error.InvalidStateError;
    // 3. "Process scroll behavior given this."
    owner.record.interception_state = .scrolled;
}

/// Shared checks for `event`, from its navigation: what the event's own
/// methods check themselves (NavigateEvent.sharedChecks), for the
/// precommit controller's.
fn sharedChecksOf(owner: EventOwner) !void {
    _ = scopeOf(owner.instance, owner.internal) orelse return error.InvalidStateError;
    if (!(try interfaces.Event.get_isTrusted(owner.record.event))) return error.SecurityError;
    if (try interfaces.Event.get_defaultPrevented(owner.record.event)) return error.InvalidStateError;
}

/// dom.navigation_api: NavigationPrecommitController's redirect() steps
/// 2-12.
fn redirectHook(event: *runtime.Instance, args: *const dom.navigation_api.Redirect) anyerror!void {
    const owner = ownerOf(event) orelse return error.InvalidStateError;
    const record = owner.record;
    const internal = owner.internal;
    // 2.
    try sharedChecksOf(owner);
    // 3.
    if (record.interception_state != .intercepted) return error.InvalidStateError;
    // 4.
    if (record.navigation_type != .push and record.navigation_type != .replace) return error.InvalidStateError;
    // 5-7.
    const scope = scopeOf(owner.instance, internal) orelse return error.InvalidStateError;
    const destination_url = parseRelative(scope.document, args.url, internal.allocator) catch return error.SyntaxError;
    defer internal.allocator.free(destination_url);
    // 8.
    const document_url = try interfaces.Document.get_URL(scope.document);
    defer scope.document.ctx.allocator.free(document_url);
    if (!navigate_steps.canHaveUrlRewritten(document_url, destination_url)) return error.SecurityError;
    // 9.
    if (args.history) |kind| {
        record.navigation_type = kind;
        dom.navigation_objects.setEventNavigationType(event, kind);
    }
    // 10.
    if (args.state) |value| {
        var serialized = try navigation_entries.serialize(engine.currentRealm() orelse owner.instance.ctx, internal.allocator, value);
        defer serialized.deinit(internal.allocator);
        try dom.navigation_objects.setDestinationState(record.destination, serialized);
        if (internal.ongoing_tracker) |tracker| {
            if (tracker.serialized_state) |*old| old.deinit(internal.allocator);
            tracker.serialized_state = try serialized.clone(internal.allocator);
        }
    }
    // 11.
    try dom.navigation_objects.setDestinationUrl(record.destination, destination_url);
    // 12.
    if (args.info) |info| try dom.navigation_objects.setEventInfo(event, info);
}

/// dom.navigation_api: NavigationPrecommitController's addHandler() steps
/// 2-4.
fn addHandlerHook(event: *runtime.Instance, handler: *const anyopaque) anyerror!void {
    const owner = ownerOf(event) orelse return error.InvalidStateError;
    try sharedChecksOf(owner);
    if (owner.record.interception_state != .intercepted) return error.InvalidStateError;
    try owner.record.handlers.append(owner.internal.allocator, engine.takeCallbackFunction(handler));
}

// ============================================================================
// Same-document navigations (dom.navigation_api)
// ============================================================================

/// dom.navigation_api: HTML "update the navigation API entries for a
/// same-document navigation" at `window`'s navigation API.
fn sameDocumentNavigation(window: *runtime.Instance, kind: Kind) void {
    const target = targetOf(window) orelse return;
    const navigation = target.instance;
    const internal = target.internal;
    const scope = scopeOf(navigation, internal);
    // Step 1: "If navigation has entries and events disabled, then return."
    if (navigation_entries.disabled(scope)) return;
    const s = scope.?;
    const destination = s.history.currentEntry(s.navigable.id) orelse return;

    // Step 2: "Let oldCurrentNHE be the current entry of navigation."
    const old_id = internal.current_entry_id;
    const old_current: ?*runtime.Instance = if (internal.handed.get(old_id)) |h| h.instance else null;
    internal.current_entry_id = destination.id;

    // Steps 3-6: the entries that fall out - past the new one for a push,
    // the replaced one for a replace - are those no longer in the history.
    var disposed: std.ArrayListUnmanaged(*Handed) = .empty;
    defer disposed.deinit(internal.allocator);
    if (kind == .push or kind == .replace) {
        var it = internal.handed.iterator();
        while (it.next()) |kv| {
            if (s.history.entryById(kv.key_ptr.*) == null) disposed.append(internal.allocator, kv.value_ptr.*) catch {};
        }
        for (disposed.items) |handed| {
            _ = internal.handed.remove(dom.navigation_history_entries.entryId(handed.instance));
        }
        // Steps 5.3 and 6 append them in entry list order; the map has none.
        // The entries are gone from the history, so their ids - made in the
        // order the entries were - stand for their places in the list.
        std.mem.sort(*Handed, disposed.items, {}, struct {
            fn lessThan(_: void, a: *Handed, b: *Handed) bool {
                return dom.navigation_history_entries.entryId(a.instance) < dom.navigation_history_entries.entryId(b.instance);
            }
        }.lessThan);
    }

    const new_current = entryObject(internal, s.window, destination) catch return;

    // Step 11's "prepare to run script given navigation's relevant settings
    // object", taken before step 8: resolving the committed promise is a
    // call into the engine, which - with nothing else on the stack, in a
    // traversal's task - would run its reactions right away, before
    // currententrychange. Step 15 cleans up.
    const script_scope = engine.prepareToRunScript(navigation.ctx) catch null;
    defer if (script_scope) |scope_| engine.cleanUpAfterRunningScript(scope_);

    // Step 8: "If navigation's ongoing API method tracker is non-null, then
    // notify about the committed-to entry given navigation's ongoing API
    // method tracker and the current entry of navigation."
    if (internal.ongoing_tracker) |tracker| notifyCommittedTo(s, tracker, new_current);

    // A push that prunes the entries after the current one takes away the
    // destination of any traversal to them still waiting: it is aborted,
    // before its navigate event is ever fired (navigation-methods/
    // forward-to-pruned-entry). The traversal itself finds nothing to do.
    if (kind == .push) abortPrunedTraversals(navigation, internal, s);

    // Step 12: currententrychange, from the old current entry (for a
    // reload, the current one).
    if (old_current) |from| fireCurrentEntryChange(navigation, navigationTypeOf(kind), from);

    // Step 13: "For each disposedNHE of disposedNHEs: fire an event named
    // dispose at disposedNHE." Then let each go.
    for (disposed.items) |handed| {
        fireSimple(handed.instance, "dispose");
        handed.edge.release(internal.navigation);
        internal.allocator.destroy(handed);
    }

    // Step 14: "Run the navigate event intercept commit handler steps given
    // navigation, navigateEvent, and apiMethodTracker" - navigation's ongoing
    // navigate event and API method tracker (steps 9-10), read now: the
    // events above can start another navigation.
    if (eventForUpdate(internal)) |record| interceptCommitHandlerSteps(navigation, internal, record);

    // A push cleared the forward session history of the whole traversable:
    // the other navigables' forward entries went with it.
    if (kind == .push) disposeEntriesRemovedElsewhere(navigation, s);
}

/// Every other navigation API of `s`'s traversable disposes of the entries
/// a push by `navigation`'s navigable removed from the session history - a
/// frame's push truncates its parent's forward entries, and the parent's
/// NavigationHistoryEntry objects for them fire dispose.
///
/// HTML's "update the navigation API entries for a same-document
/// navigation" disposes only the navigating navigable's entries, and "clear
/// the forward session history" removes every navigable's: the other
/// navigables' NavigationHistoryEntry objects are left with no entry and
/// no event. All three browsers fire dispose for them
/// (per-entry-events/dispose-for-navigation-in-child.html); this is Blink's
/// NavigationApi::DisposeEntriesForSessionHistoryRemoval, which the browser
/// process asks of each frame whose entries a navigation removed.
fn disposeEntriesRemovedElsewhere(navigation: *runtime.Instance, s: navigation_entries.Scope) void {
    const top = s.navigable.getTop();
    // Taken before any event is fired: dispose handlers run script, which
    // can make and free navigation objects.
    const Other = struct { instance: *runtime.Instance, generation: u64 };
    var others: std.ArrayListUnmanaged(Other) = .empty;
    defer others.deinit(std.heap.c_allocator);
    for (live.items) |other| {
        if (other == navigation) continue;
        const other_internal = getInternal(other) orelse continue;
        const other_scope = scopeOf(other, other_internal) orelse continue;
        if (other_scope.navigable == s.navigable or other_scope.navigable.getTop() != top) continue;
        others.append(std.heap.c_allocator, .{ .instance = other, .generation = runtime.SlabAllocator.generationOf(other) }) catch return;
    }
    for (others.items) |other| {
        if (runtime.SlabAllocator.generationOf(other.instance) != other.generation) continue;
        disposeEntriesForSessionHistoryRemoval(other.instance);
    }
}

/// dom.navigation_api: the traversable whose top-level browsing context is
/// `top_ptr` lost session history entries to a cross-document push -
/// every navigation API of it disposes of those it handed out.
fn entriesRemovedHook(top_ptr: *anyopaque) void {
    const top: *html_core.window.BrowsingContext = @ptrCast(@alignCast(top_ptr));
    // Taken before any event is fired: dispose handlers run script, which
    // can make and free navigation objects.
    const Other = struct { instance: *runtime.Instance, generation: u64 };
    var others: std.ArrayListUnmanaged(Other) = .empty;
    defer others.deinit(std.heap.c_allocator);
    for (live.items) |navigation| {
        const internal = getInternal(navigation) orelse continue;
        const s = scopeOf(navigation, internal) orelse continue;
        if (s.navigable.getTop() != top) continue;
        others.append(std.heap.c_allocator, .{ .instance = navigation, .generation = runtime.SlabAllocator.generationOf(navigation) }) catch return;
    }
    for (others.items) |other| {
        if (runtime.SlabAllocator.generationOf(other.instance) != other.generation) continue;
        disposeEntriesForSessionHistoryRemoval(other.instance);
    }
}

/// Blink's NavigationApi::DisposeEntriesForSessionHistoryRemoval: the
/// entries `navigation` has handed out whose session history entries are
/// gone leave its entry list, and each fires dispose. Its current entry
/// never does - it stays its navigable's active entry.
fn disposeEntriesForSessionHistoryRemoval(navigation: *runtime.Instance) void {
    const internal = getInternal(navigation) orelse return;
    const scope = scopeOf(navigation, internal);
    if (navigation_entries.disabled(scope)) return;
    const s = scope.?;
    var disposed: std.ArrayListUnmanaged(*Handed) = .empty;
    defer disposed.deinit(internal.allocator);
    var it = internal.handed.iterator();
    while (it.next()) |kv| {
        if (kv.key_ptr.* == internal.current_entry_id) continue;
        if (s.history.entryById(kv.key_ptr.*) == null) disposed.append(internal.allocator, kv.value_ptr.*) catch return;
    }
    for (disposed.items) |handed| {
        _ = internal.handed.remove(dom.navigation_history_entries.entryId(handed.instance));
    }
    for (disposed.items) |handed| {
        fireSimple(handed.instance, "dispose");
        handed.edge.release(internal.navigation);
        internal.allocator.destroy(handed);
    }
}

/// Reject, with an AbortError, every upcoming traverse API method tracker
/// whose destination key is no longer in the navigable's session history.
fn abortPrunedTraversals(navigation: *runtime.Instance, internal: *InternalState, s: navigation_entries.Scope) void {
    var i: usize = 0;
    while (i < internal.upcoming.items.len) {
        const tracker = internal.upcoming.items[i];
        const key = tracker.key orelse {
            i += 1;
            continue;
        };
        if (s.history.entryByKey(s.navigable.id, &key) != null) {
            i += 1;
            continue;
        }
        const reason = engine.createDOMException(navigation.ctx, "AbortError", "The traversal's destination was removed.") catch {
            cleanUp(internal, tracker);
            continue;
        };
        defer reason.release();
        rejectFinished(internal, tracker, reason.value);
    }
}

// ============================================================================
// Promises and events
// ============================================================================

/// A NavigationResult whose promises are both resolved with `nhe`.
fn settledResult(instance: *runtime.Instance, nhe: *runtime.Instance) !dictionaries.NavigationResult {
    const realm = engine.currentRealm() orelse instance.ctx;
    const committed = try engine.createResolvedPromise(realm, .{ .instance = nhe });
    errdefer committed.release();
    const finished = try engine.createResolvedPromise(realm, .{ .instance = nhe });
    return .{ .committed = committed.take(), .finished = finished.take() };
}

/// HTML "an early error result" for a DOMException named `name`: committed
/// and finished both rejected with it, finished marked as handled.
fn earlyError(instance: *runtime.Instance, name: []const u8, message: []const u8) !dictionaries.NavigationResult {
    const realm = engine.currentRealm() orelse instance.ctx;
    const exception = try engine.createDOMException(realm, name, message);
    defer exception.release();
    return earlyErrorWith(instance, exception);
}

/// HTML "an early error result" for `reason` (OWNED by the caller, which
/// releases it): committed and finished both rejected with it, finished
/// marked as handled.
fn earlyErrorWith(instance: *runtime.Instance, reason: engine.Owned) !dictionaries.NavigationResult {
    const realm = engine.currentRealm() orelse instance.ctx;
    const committed = try engine.createRejectedPromise(realm, reason.value);
    errdefer committed.release();
    const finished = try engine.createRejectedPromise(realm, reason.value);
    engine.markPromiseAsHandled(realm, finished.value);
    return .{ .committed = committed.take(), .finished = finished.take() };
}

/// The outcome of serializing a navigation API state: the serialization, or
/// what it threw (OWNED) - which navigate() and reload() return as an early
/// error result.
const StateSerialization = union(enum) {
    serialized: joint_history.SerializedState,
    threw: engine.Owned,
};

/// StructuredSerializeForStorage(`value`), catching what it throws - a
/// DataCloneError, or an exception from a getter - as a value.
fn serializeState(instance: *runtime.Instance, internal: *InternalState, value: runtime.JSValue) !StateSerialization {
    const realm = engine.currentRealm() orelse instance.ctx;
    var job: SerializeJob = .{ .realm = realm, .allocator = internal.allocator, .value = value };
    if (try engine.completionOf(realm, SerializeJob.run, &job)) |thrown| return .{ .threw = thrown };
    return .{ .serialized = job.result.? };
}

const SerializeJob = struct {
    realm: runtime.Context,
    allocator: Allocator,
    value: runtime.JSValue,
    result: ?joint_history.SerializedState = null,

    fn run(data: ?*anyopaque) engine.Error!void {
        const self: *SerializeJob = @ptrCast(@alignCast(data.?));
        self.result = navigation_entries.serialize(self.realm, self.allocator, self.value) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.DataCloneError => error.DataCloneError,
            error.ExceptionPending => error.ExceptionPending,
            else => error.OperationFailed,
        };
    }
};

/// Fire currententrychange at `navigation` with `navigation_type` and `from`.
fn fireCurrentEntryChange(navigation: *runtime.Instance, navigation_type: ?enums.NavigationType, from: *runtime.Instance) void {
    const event = interfaces.NavigationCurrentEntryChangeEvent.call_constructor(
        navigation.ctx,
        runtime.DOMString.initInterned("currententrychange"),
        .{ .base = .{}, .navigationType = navigation_type, .from = from },
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = EventTargetImpl.dispatchTrusted(navigation, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Fire navigateerror at `navigation`, an ErrorEvent with `info`'s
/// attributes and `reason` as its error.
fn fireNavigateError(navigation: *runtime.Instance, info: ?engine.ErrorInfo, reason: runtime.JSValue) void {
    const event = interfaces.ErrorEvent.call_constructor(
        navigation.ctx,
        runtime.DOMString.initInterned("navigateerror"),
        webidl.Opt(dictionaries.ErrorEventInit).passed(.{
            .base = .{},
            .message = if (info) |i| runtime.DOMString.initInterned(i.message) else null,
            .filename = if (info) |i| i.filename else null,
            .lineno = if (info) |i| i.lineno else null,
            .colno = if (info) |i| i.colno else null,
            .@"error" = reason,
        }),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = EventTargetImpl.dispatchTrusted(navigation, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Fire a plain event named `event_type` at `target`.
fn fireSimple(target: *runtime.Instance, event_type: []const u8) void {
    const event = interfaces.Event.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.EventInit).notPassed(),
    ) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = EventTargetImpl.dispatchTrusted(target, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// `url` parsed relative to `document`'s base URL and serialized; owned.
fn parseRelative(document: *runtime.Instance, url: []const u8, allocator: Allocator) ![]u8 {
    const base = interfaces.Node.get_baseURI(document) catch return error.SyntaxError;
    defer document.ctx.allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const record = (interfaces.URL.call_static_parse(document, url, base_arg) catch return error.SyntaxError) orelse return error.SyntaxError;
    defer runtime.Instance.deinit(record);
    const href = interfaces.URL.get_href(record) catch return error.SyntaxError;
    defer record.ctx.allocator.free(href);
    return allocator.dupe(u8, href);
}
