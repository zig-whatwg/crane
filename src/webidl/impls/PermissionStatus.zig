//! Permissions 6.3: a query result, constructed through EventTarget's chain.
//! Spec: https://w3c.github.io/permissions/#permissionstatus-interface
//!
//! 6.3.5 Garbage collection: "A PermissionStatus object MUST NOT be garbage
//! collected if it has an event listener whose type is change." The status
//! watches its own listener list (dom.event_listener_changes) and holds one
//! counted keep (engine.keepPlatformObjectAlive) while a change listener is
//! there - WebKit's PermissionStatus::eventListenersDidChange, which
//! recomputes m_hasChangeEventListener for virtualHasPendingActivity; Blink's
//! PermissionStatus::AddedEventListener / RemovedEventListener with
//! ActiveScriptWrappable. The keep ends when the last change listener goes,
//! and at its global's end (`endKeepsInRealm`), never in its teardown.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const permissions = @import("permissions");
const engine = @import("engine");
const dom = @import("dom");

pub const State = interfaces.PermissionStatus.State;
pub const ImplError = error{InvalidStateError};
pub const construction_args = .{ "permission_descriptor", "permission_state", "permission_key", "permission_key_owner" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// [[query]] is owned by value: a permission name and its native fields,
    /// with no reference to the script dictionary or its getters.
    query: ?permissions.PermissionDescriptor = null,
    state: permissions.PermissionState = .prompt,
    store: ?*permissions.BrowserStore = null,
    /// The change listeners' keep (engine.keepPlatformObjectAlive) is held:
    /// taken once when a change listener appears, released once when the
    /// last goes or by its global's teardown (`listenersChanged`,
    /// `endKeepsInRealm`).
    kept: bool = false,
    /// Its global's teardown ran: it is never kept again (WebKit's
    /// virtualHasPendingActivity answers false once its document has no
    /// browsing context; Blink keeps nothing of a destroyed
    /// ExecutionContext).
    ended: bool = false,
};

/// 6.3.1 steps 3.1-3.2. The generated chain has initialized EventTarget.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    // Its listener list's changes reach `listenersChanged`. First: once the
    // store has taken the key below, no fallible work may remain. For a
    // status, whose chain ran EventTarget's init, it allocates nothing.
    try dom.event_listener_changes.watch(instance);
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator };
    if (comptime @hasField(@TypeOf(args), "permission_descriptor")) internal.query = args.permission_descriptor;
    if (comptime @hasField(@TypeOf(args), "permission_state")) internal.state = args.permission_state;
    if (comptime @hasField(@TypeOf(args), "permission_key_owner")) {
        // The caller allocated this key with the construction allocator.
        // Parent/own/store failure leaves its slot untouched. After listen
        // succeeds no fallible work remains, and no slot pointer is retained.
        if (args.permission_key_owner.*) |key| if (internal.query) |descriptor| if (instance.ctx.browser_scope) |scope| {
            const store = try scope.of(permissions.BrowserStore);
            internal.state = try store.listenOwned(instance, key, allocator, descriptor, internal.state, deliverChange);
            args.permission_key_owner.* = null;
            internal.store = store;
        };
    } else if (comptime @hasField(@TypeOf(args), "permission_key")) {
        if (args.permission_key) |key| if (internal.query) |descriptor| if (instance.ctx.browser_scope) |scope| {
            const store = try scope.of(permissions.BrowserStore);
            internal.state = try store.listen(instance, key, descriptor, internal.state, deliverChange);
            internal.store = store;
        };
    }
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    // Releases nothing: the teardown runs only once the wrapper the keep was
    // counted on is gone - collected, or with its realm's end (lesson
    // architecture-a-teardown-never-releases-its-own-keep.md).
    internal.kept = false;
    if (internal.store) |store| store.unlisten(instance);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// The hooks this type owns, installed once at process start through the
/// generated interface: its listener-change step, and the end of its keeps
/// with its global.
pub fn installHooks() void {
    dom.event_listener_changes.installStep(&listenersChanged);
    // A global teardown step, not a document step: a Window the next
    // document reuses (HTML "create and initialize a Document object" step
    // 6) is the same global, and its statuses stay kept
    // (dom.unloading_cleanup).
    dom.unloading_cleanup.installGlobalTeardown(&endKeepsInRealm);
}

/// dom.event_listener_changes: `target`'s listener list changed. Kept while
/// it has a change listener (6.3.5) - an onchange handler's included, as its
/// listener is in the list. Only a status registered with its Browser's
/// store can ever hear a change, and only those can its global's teardown
/// find, so only those are kept: an unregistered one (no Browser, no
/// permission key) fires nothing, and its collection is not observable.
fn listenersChanged(target: *runtime.Instance) void {
    const state = target.stateAs(State) orelse return;
    const internal = state.own._internal orelse return;
    const wanted = internal.store != null and !internal.ended and
        dom.event_listener_types.hasListenersOfType(target, "change");
    if (wanted == internal.kept) return;
    if (wanted) {
        // Script added the listener, so the wrapper exists; a keep on an
        // unwrapped instance could fail silently (lesson
        // architecture-a-keep-on-an-unwrapped-object-can-fail-silently.md),
        // and nothing collects an unwrapped one.
        if (!engine.hasWrapper(target)) return;
        engine.keepPlatformObjectAlive(target);
        internal.kept = true;
    } else {
        internal.kept = false;
        engine.releasePlatformObject(target);
    }
}

/// A global teardown step (dom.unloading_cleanup), which also runs when a
/// worker's global scope ends: `realm`'s statuses are kept no longer, and
/// never again, while its wrapper cache still counts the keeps. The
/// Permissions spec names no such step; the engines end the hold there:
/// WebKit's virtualHasPendingActivity answers false once the document has no
/// browsing context, and Blink's ActiveScriptWrappableManager keeps no
/// wrapper whose ExecutionContext is destroyed. A destroyed document's
/// statuses hear no change anyway (the update steps' fully active check).
fn endKeepsInRealm(realm: runtime.Context) void {
    const scope = realm.browser_scope orelse return;
    const store = scope.existing(permissions.BrowserStore) orelse return;
    const listeners = store.listenersIn(realm, realm.allocator) catch return;
    defer realm.allocator.free(listeners);
    for (listeners) |listener| {
        // This realm's own status, read only while its slot is still it.
        if (runtime.SlabAllocator.generationOf(listener.instance) != listener.generation) continue;
        const state = listener.instance.stateAs(State) orelse continue;
        const internal = state.own._internal orelse continue;
        internal.ended = true;
        if (!internal.kept) continue;
        internal.kept = false;
        engine.releasePlatformObject(listener.instance);
    }
}

/// 6.3.3: return this's state.
pub fn get_state(instance: *runtime.Instance) anyerror!enums.PermissionState {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return switch (internal.state) {
        .granted => ._granted_,
        .denied => ._denied_,
        .prompt => ._prompt_,
    };
}

/// 6.3.2: return the name initialized at construction.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const query = internal.query orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(query.name.toString());
}

/// On the status's own task sink and thread, after its registration was
/// checked.
fn deliverChange(instance: *runtime.Instance, next: permissions.PermissionState) void {
    if (!instance.ctx.hasEngine()) return;
    var delivery = Change{ .instance = instance, .next = next };
    engine.runTaskInRealm(instance.ctx, Change.run, &delivery) catch {};
}

const Change = struct {
    instance: *runtime.Instance,
    next: permissions.PermissionState,

    fn run(data: ?*anyopaque) void {
        const self: *Change = @ptrCast(@alignCast(data.?));
        const instance = self.instance;
        const realm = instance.ctx;
        // PermissionStatus update steps 1.1-1.2: an inactive Window's
        // document receives neither the state update nor its change event.
        if (realm.isWindow()) {
            const record = realm.getRealm() orelse return;
            const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
            if (!dom.document_activity.fullyActive(window, runtime.SlabAllocator.generationOf(window))) return;
        }
        const internal = instance.getState(State).own._internal orelse return;
        if (internal.state == self.next) return;
        // Steps 2-3. The queued value is the result of the descriptor's
        // query algorithm, including Storage Access's denied -> prompt rule.
        internal.state = self.next;
        // Step 4, on the queued permissions task: a trusted, non-bubbling,
        // non-cancelable Event. The generated onchange accessor shares the
        // EventTarget listener path with addEventListener.
        const event = interfaces.Event.call_constructor(realm, runtime.DOMString.initInterned("change"), .notPassed()) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        // The status is kept for its own dispatch: a once listener's removal
        // (inner invoke step 2.5) ends the listeners' keep before the
        // listener runs, and the event path holds no target that is not a
        // node. WebKit's queueTaskToDispatchEvent task
        // (ActiveDOMObjectEventDispatchTask) holds the object and counts a
        // pending activity until the task is done. An independent counted
        // keep: it never ends the listeners' one.
        const hold = engine.hasWrapper(instance);
        if (hold) engine.keepPlatformObjectAlive(instance);
        defer if (hold) engine.releasePlatformObject(instance);
        _ = dom.fire_event.dispatchTrusted(instance, event) catch {};
        event.releaseIfUnwrapped(generation);
    }
};
