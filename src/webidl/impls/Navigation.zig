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
//! Same-document navigations - pushState/replaceState, fragment navigations
//! and same-document traversals - reach it through dom.navigation_api, which
//! it installs: it moves its current entry, fires currententrychange, fires
//! dispose at the entries that fell out, and settles the promises of the
//! navigate(), traverseTo(), back() and forward() calls they complete.
//!
//! Not modelled, stated: the navigate event (and so intercept(),
//! navigatesuccess, navigateerror, transition and the precommit handlers),
//! activation, and the navigation API state of a navigate() or reload() that
//! makes a new document; their committed and finished promises stay pending,
//! as they do in a browser whose document unloads before they settle.

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
const dom = @import("dom");
const engine = @import("engine");
const log = std.log.scoped(.navigation_api);

pub const State = Navigation.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    SecurityError,
    SyntaxError,
    AbortError,
    OutOfMemory,
};

/// A NavigationHistoryEntry handed out, and the pin that keeps its wrapper.
const Handed = struct {
    instance: *runtime.Instance,
    pin: same_object.Pin = .{},
};

/// An API method tracker (HTML 7.2.6.8), reduced to what settles its
/// promises: which navigation it waits for, and its committed and finished
/// promises (OWNED until the tracker goes).
const Tracker = struct {
    kind: enum { traverse, non_traverse },
    /// A traversal's destination key.
    key: [36]u8 = undefined,
    /// A navigate()'s navigation API state, set on the entry it commits.
    api_state: ?joint_history.SerializedState = null,
    committed: engine.PromiseCapability,
    finished: engine.PromiseCapability,

    fn destroy(self: *Tracker, allocator: Allocator) void {
        engine.releasePromiseCapability(&self.committed);
        engine.releasePromiseCapability(&self.finished);
        if (self.api_state) |*s| s.deinit(allocator);
        allocator.destroy(self);
    }
};

pub const InternalState = struct {
    allocator: Allocator,
    /// The relevant global object and its slab generation, found from the
    /// realm on first use.
    window: ?*runtime.Instance = null,
    window_generation: u64 = 0,
    /// The entries handed out, by session history entry id.
    handed: std.AutoHashMapUnmanaged(u64, *Handed) = .empty,
    /// The session history entry that was current when this last looked:
    /// "oldCurrentNHE" for the next currententrychange.
    current_entry_id: u64 = 0,
    trackers: std.ArrayListUnmanaged(*Tracker) = .empty,

    fn deinit(self: *InternalState) void {
        var it = self.handed.valueIterator();
        while (it.next()) |handed| {
            handed.*.pin.release();
            self.allocator.destroy(handed.*);
        }
        self.handed.deinit(self.allocator);
        for (self.trackers.items) |tracker| tracker.destroy(self.allocator);
        self.trackers.deinit(self.allocator);
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize Navigation instance: an EventTarget, which currententrychange
/// is fired at.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    dom.navigation_api.install(.{ .same_document_navigation = &sameDocumentNavigation });
    // "Initialize the navigation API entries for a new document": the current
    // entry, handed out now, is the "from" of the first currententrychange.
    _ = currentEntryObject(instance, internal) catch null;
    return instance;
}

/// Deinitialize Navigation instance
pub fn deinit(instance: *runtime.Instance) void {
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
    // The first entry object installs the hook; a page that has made none
    // makes one to install it, and lets it go.
    if (!hook.isInstalled()) {
        const installer = try interfaces.NavigationHistoryEntry.init(window.ctx.allocator, window.ctx);
        installer.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(installer));
    }
    const instance = try hook.create(window, @ptrCast(entry));
    const handed = try internal.allocator.create(Handed);
    handed.* = .{ .instance = instance };
    internal.handed.put(internal.allocator, entry.id, handed) catch |err| {
        internal.allocator.destroy(handed);
        return err;
    };
    handed.pin.hold(instance);
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

/// Getter for transition: no navigate event is fired, so no transition is
/// ever ongoing.
pub fn get_transition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for activation: not modelled, stated.
pub fn get_activation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
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

/// navigate(url, options): HTML 7.2.6.7. Parsing, the state and the checks
/// are this's; the navigation is the navigable's (dom.navigables). A
/// same-document result settles both promises; a new document's leaves them
/// pending (see the file comment).
pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString, options: webidl.Opt(dictionaries.NavigationNavigateOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const opts: ?dictionaries.NavigationNavigateOptions = if (options.was_passed) options.value else null;
    const scope = scopeOf(instance, internal) orelse return earlyError(instance, "InvalidStateError", "The document is not fully active.");

    // Step 1: "Let urlRecord be the result of parsing a URL given url,
    // relative to this's relevant settings object." Failure: SyntaxError.
    const url_record = parseRelative(scope.document, url, internal.allocator) catch
        return earlyError(instance, "SyntaxError", "The URL could not be parsed.");
    defer internal.allocator.free(url_record);

    // Step 2: "If urlRecord's scheme is "javascript", then return an early
    // error result for a "NotSupportedError" DOMException."
    if (std.ascii.startsWithIgnoreCase(url_record, "javascript:")) {
        return earlyError(instance, "NotSupportedError", "navigate() does not run javascript: URLs.");
    }

    // Step 3: "If options["history"] is "push", and the navigation must be a
    // replace given urlRecord and document, then return an early error
    // result for a "NotSupportedError" DOMException."
    const behavior: dom.navigables.HistoryBehavior = if (opts) |o| switch (o.history orelse ._auto_) {
        ._auto_ => .auto,
        ._push_ => .push,
        ._replace_ => .replace,
    } else .auto;
    if (behavior == .push and dom.document_lifecycle.isInitialAboutBlank(scope.document)) {
        return earlyError(instance, "NotSupportedError", "A push is not possible here.");
    }

    // Steps 4-5: the state, serialized; an exception is an early error
    // result for that exception.
    var state: ?joint_history.SerializedState = null;
    if (opts) |o| {
        if (o.state) |value| {
            switch (try serializeState(instance, internal, value)) {
                .serialized => |serialized| state = serialized,
                .threw => |reason| return earlyErrorWith(instance, reason),
            }
        }
    }
    errdefer if (state) |*s| s.deinit(internal.allocator);

    // Step 6: "If document is not fully active, then return an early error
    // result for an "InvalidStateError" DOMException." Step 7: the unload
    // counter.
    if (dom.document_lifecycle.isUnloading(scope.document)) {
        if (state) |*s| s.deinit(internal.allocator);
        return earlyError(instance, "InvalidStateError", "The document is unloading.");
    }

    // Steps 9-11: the API method tracker, then navigate.
    const result = try track(instance, internal, .{ .kind = .non_traverse, .api_state = state });
    state = null;
    const navigables = dom.navigables;
    if (!navigables.isInstalled()) {
        const installer = try interfaces.Document.call_createElement(scope.document, runtime.DOMString.initInterned("iframe"), webidl.Opt(runtime.JSValue).notPassed());
        installer.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(installer));
    }
    navigables.navigateByTarget(scope.document, .{ .target = "", .url = url_record, .history_behavior = behavior });
    return result;
}

/// reload(options): reload the navigable. A new document, so the promises
/// stay pending; the state option is not carried into it, stated.
pub fn call_reload(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationReloadOptions)) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-2: "Let serializedState be StructuredSerializeForStorage(undefined).
    // If options["state"] exists, then set serializedState to
    // StructuredSerializeForStorage(options["state"]). If this throws an
    // exception, then return an early error result for that exception."
    if (options.was_passed) {
        if (options.value.state) |value| {
            switch (try serializeState(instance, internal, value)) {
                .serialized => |serialized| {
                    var state = serialized;
                    state.deinit(internal.allocator);
                },
                .threw => |reason| return earlyErrorWith(instance, reason),
            }
        }
    }
    const scope = scopeOf(instance, internal) orelse return earlyError(instance, "InvalidStateError", "The document is not fully active.");
    if (dom.document_lifecycle.isUnloading(scope.document)) return earlyError(instance, "InvalidStateError", "The document is unloading.");
    const result = try track(instance, internal, .{ .kind = .non_traverse });
    ensureHistoryTraversal(scope.window);
    dom.history_traversal.reload(scope.window);
    return result;
}

/// traverseTo(key, options): "perform a navigation API traversal".
pub fn call_traverseTo(instance: *runtime.Instance, key: runtime.DOMString, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    _ = options;
    return traverseToKey(instance, key.asSlice());
}

/// back(options): "1. If this's current entry index is −1 or 0, then return
/// an early error result for an "InvalidStateError" DOMException. 2. Let key
/// be this's entry list[this's current entry index − 1]'s session history
/// entry's navigation API key. 3. Return the result of performing a
/// navigation API traversal given this, key, and options."
pub fn call_back(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    _ = options;
    return traverseByOne(instance, -1);
}

/// forward(options): the same, for the entry after the current one.
pub fn call_forward(instance: *runtime.Instance, options: webidl.Opt(dictionaries.NavigationOptions)) anyerror!dictionaries.NavigationResult {
    _ = options;
    return traverseByOne(instance, 1);
}

fn traverseByOne(instance: *runtime.Instance, delta: i2) anyerror!dictionaries.NavigationResult {
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
    return traverseToKey(instance, &key);
}

/// HTML "perform a navigation API traversal" given this and `key`.
fn traverseToKey(instance: *runtime.Instance, key: []const u8) anyerror!dictionaries.NavigationResult {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // Steps 1-2: a document that is not fully active, or is unloading.
    const scope = scopeOf(instance, internal) orelse return earlyError(instance, "InvalidStateError", "The document is not fully active.");
    if (dom.document_lifecycle.isUnloading(scope.document)) return earlyError(instance, "InvalidStateError", "The document is unloading.");
    var entries: std.ArrayListUnmanaged(*joint_history.Entry) = .empty;
    defer entries.deinit(internal.allocator);
    const index = entryList(scope, internal.allocator, &entries) orelse
        return earlyError(instance, "InvalidStateError", "Entries are disabled.");
    // Step 3: "Let current be the current entry of navigation." Step 4: "If
    // key equals current's session history entry's navigation API key, then
    // return a new NavigationResult whose committed and finished are
    // promises resolved with current."
    const current = entries.items[index];
    if (std.mem.eql(u8, &current.api_key, key)) {
        const nhe = try entryObject(internal, scope.window, current);
        return settledResult(instance, nhe);
    }
    // Step 5: "If navigation's entry list does not contain a
    // NavigationHistoryEntry whose session history entry's navigation API
    // key equals key, then return an early error result for an
    // "InvalidStateError" DOMException."
    const destination = for (entries.items) |entry| {
        if (std.mem.eql(u8, &entry.api_key, key)) break entry;
    } else return earlyError(instance, "InvalidStateError", "No entry has that key.");
    // Steps 6-12: the tracker, then the traversal to the destination's step.
    var tracker_key: [36]u8 = undefined;
    @memcpy(&tracker_key, key[0..36]);
    const result = try track(instance, internal, .{ .kind = .traverse, .key = tracker_key });
    ensureHistoryTraversal(scope.window);
    dom.history_traversal.traverseToStep(scope.window, destination.step);
    return result;
}

/// dom.history_traversal is History's: a window that has not made its
/// History yet makes it, which installs the hook.
fn ensureHistoryTraversal(window: *runtime.Instance) void {
    if (dom.history_traversal.isInstalled()) return;
    _ = interfaces.Window.get_history(window) catch {};
}

// ============================================================================
// Same-document navigations (dom.navigation_api)
// ============================================================================

/// dom.navigation_api: HTML "update the navigation API entries for a
/// same-document navigation" at `window`'s navigation API.
fn sameDocumentNavigation(window: *runtime.Instance, kind: dom.navigation_api.Kind) void {
    const navigation = interfaces.Window.get_navigation(window) catch return;
    const internal = getInternal(navigation) orelse return;
    const scope = scopeOf(navigation, internal);
    // Step 1: "If navigation has entries and events disabled, then return."
    if (navigation_entries.disabled(scope)) return;
    const s = scope.?;
    const destination = s.history.currentEntry(s.navigable.id) orelse return;

    // Step 2: "Let oldCurrentNHE be the current entry of navigation."
    const old_id = internal.current_entry_id;
    const old_current: ?*runtime.Instance = if (internal.handed.get(old_id)) |h| h.instance else null;
    internal.current_entry_id = destination.id;

    // A navigate() whose same-document navigation this is sets the entry's
    // navigation API state (navigate to a fragment's navigationAPIState).
    const tracker_index: ?usize = findTracker(internal, kind, &destination.api_key);
    if (tracker_index) |i| {
        if (internal.trackers.items[i].api_state) |state| {
            internal.trackers.items[i].api_state = null;
            s.history.setCurrentApiState(s.navigable.id, state) catch {};
        }
    }

    // Steps 3-6: the entries that fall out - past the new one for a push,
    // the replaced one for a replace - are those no longer in the history.
    var disposed: std.ArrayListUnmanaged(*Handed) = .empty;
    defer disposed.deinit(internal.allocator);
    if (kind != .traverse) {
        var it = internal.handed.iterator();
        while (it.next()) |kv| {
            if (s.history.entryById(kv.key_ptr.*) == null) disposed.append(internal.allocator, kv.value_ptr.*) catch {};
        }
        for (disposed.items) |handed| {
            _ = internal.handed.remove(dom.navigation_history_entries.entryId(handed.instance));
        }
    }

    const new_current = entryObject(internal, s.window, destination) catch return;

    // Step 7: "If navigation's ongoing API method tracker is non-null, then
    // notify about the committed-to entry."
    var tracker: ?*Tracker = null;
    if (tracker_index) |i| {
        tracker = internal.trackers.orderedRemove(i);
        resolveWith(&tracker.?.committed, new_current);
    }

    // Step 11: currententrychange, from the old current entry.
    if (old_current) |from| {
        fireCurrentEntryChange(navigation, switch (kind) {
            .push => ._push_,
            .replace => ._replace_,
            .traverse => ._traverse_,
        }, from);
    }

    // Step 12: "For each disposedNHE of disposedNHEs: fire an event named
    // dispose at disposedNHE." Then let each go.
    for (disposed.items) |handed| {
        fireSimple(handed.instance, "dispose");
        handed.pin.release();
        internal.allocator.destroy(handed);
    }

    // Step 13, less the navigate event: the navigation is finished.
    if (tracker) |t| {
        resolveWith(&t.finished, new_current);
        t.destroy(internal.allocator);
    }
}

/// The tracker a same-document navigation of `kind` completes: a traversal
/// to the entry whose key is `key`, or the latest navigate() for a push or
/// replace.
fn findTracker(internal: *InternalState, kind: dom.navigation_api.Kind, key: *const [36]u8) ?usize {
    var i = internal.trackers.items.len;
    while (i > 0) {
        i -= 1;
        const t = internal.trackers.items[i];
        switch (kind) {
            .traverse => if (t.kind == .traverse and std.mem.eql(u8, &t.key, key)) return i,
            .push, .replace => if (t.kind == .non_traverse) return i,
        }
    }
    return null;
}

// ============================================================================
// Promises and events
// ============================================================================

/// A tracker with fresh committed and finished promises, and the
/// NavigationResult that hands them to script. "finished" is marked as
/// handled: a navigation that ends in an error rejects it with nobody
/// listening.
fn track(instance: *runtime.Instance, internal: *InternalState, template: Tracker0) !dictionaries.NavigationResult {
    const realm = engine.currentRealm() orelse instance.ctx;
    var committed = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&committed);
    var finished = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&finished);
    engine.markPromiseAsHandled(realm, finished.promise);

    const committed_result = try engine.retainValue(realm, committed.promise);
    errdefer committed_result.release();
    const finished_result = try engine.retainValue(realm, finished.promise);
    errdefer finished_result.release();

    const tracker = try internal.allocator.create(Tracker);
    errdefer internal.allocator.destroy(tracker);
    tracker.* = .{
        .kind = template.kind,
        .key = template.key,
        .api_state = template.api_state,
        .committed = committed,
        .finished = finished,
    };
    try internal.trackers.append(internal.allocator, tracker);
    return .{ .committed = committed_result.take(), .finished = finished_result.take() };
}

/// What a tracker is made from.
const Tracker0 = struct {
    kind: @FieldType(Tracker, "kind"),
    key: [36]u8 = undefined,
    api_state: ?joint_history.SerializedState = null,
};

/// Resolve `capability`'s promise with the entry `nhe` (its wrapper, in the
/// entry's relevant realm). A failure leaves it pending, which is what a
/// navigation whose document went away does anyway.
fn resolveWith(capability: *engine.PromiseCapability, nhe: *runtime.Instance) void {
    engine.resolvePromise(capability, .{ .instance = nhe }) catch |err| log.debug("[navigation] resolve: {s}", .{@errorName(err)});
}

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
