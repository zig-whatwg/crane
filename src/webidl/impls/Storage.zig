//! Implementation for Storage interface
//!
//! Connects WebIDL Storage interface to Web Storage backend at src/html/web_storage/
//!
//! Spec: https://html.spec.whatwg.org/multipage/webstorage.html#storage-2
//!
//! The Storage interface provides access to localStorage and sessionStorage,
//! allowing key-value pair storage partitioned by origin.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const StorageInterface = interfaces.Storage;

// Backend import - the actual Storage implementation
const html_core = @import("html_core");
const WebStorage = html_core.web_storage.Storage;
const WebStorageType = html_core.web_storage.StorageType;
const WebStorageError = html_core.web_storage.StorageError;

pub const State = StorageInterface.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    QuotaExceededError,
    InvalidState,
    OutOfMemory,
};

/// Internal state for Storage implementation
///
/// Stores the backend web_storage.Storage instance that manages all storage operations.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend storage instance
    storage: *WebStorage,

    /// Whether we own the storage and should deinit it
    owns_storage: bool,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        if (self.owns_storage) {
            self.storage.deinit();
            allocator.destroy(self.storage);
        }
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // Note: Internal state is set up by initWithStorage or by Window getter
    return instance;
}

/// Initialize a Storage instance with an existing backend storage
/// Called by Window.get_localStorage() and Window.get_sessionStorage()
pub fn initWithStorage(
    allocator: std.mem.Allocator,
    storage: *WebStorage,
    owns_storage: bool,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try StorageInterface.init(allocator, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(State);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .allocator = allocator,
        .storage = storage,
        .owns_storage = owns_storage,
    };

    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance - clean up owned resources only
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC handles slab freeing
}

/// Getter for length
/// Returns the number of key/value pairs in the storage.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return @intCast(internal.storage.length());
}

/// Operation: removeItem
/// HTML 12.2.1: "1. If this's map[key] does not exist, then return. 2. Set
/// oldValue to this's map[key]. 3. Remove this's map[key]. 4. Reorder this.
/// 5. Broadcast this with key, oldValue, and null."
pub fn call_removeItem(instance: *runtime.Instance, key: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;
    // Steps 1-2, copied: the map frees the value it removes.
    const old_value = try allocator.dupe(u8, internal.storage.getItem(key.asSlice()) orelse return);
    defer allocator.free(old_value);
    internal.storage.removeItem(key.asSlice());
    broadcast(instance, key.asSlice(), old_value, null);
}

/// Operation: clear
/// HTML 12.2.1: "1. Clear this's map. 2. Broadcast this with null, null, and
/// null." Whether or not the map held anything, as the spec reads.
pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.storage.clear();
    broadcast(instance, null, null, null);
}

/// Operation: key
/// Returns the name of the nth key, or null if n >= length.
pub fn call_key(instance: *runtime.Instance, index: u32) anyerror!?runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const key_name = internal.storage.key(@intCast(index)) orelse return null;
    return runtime.DOMString.initInterned(key_name);
}

/// Operation: getItem
/// Returns the current value associated with the given key, or null if not found.
pub fn call_getItem(instance: *runtime.Instance, key: runtime.DOMString) anyerror!?runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const value = internal.storage.getItem(key.asSlice()) orelse return null;
    return runtime.DOMString.initInterned(value);
}

/// Operation: setItem
/// Sets the value of the pair identified by key to value.
/// Throws QuotaExceededError if the new value couldn't be set.
///
/// HTML 12.2.1: "1. Let oldValue be null. ... 3. If this's map[key] exists:
/// set oldValue to this's map[key]; if oldValue is value, then return. ...
/// 7. Broadcast this with key, oldValue, and value." The backend runs steps
/// 2-6; the old value is copied first, since the map frees it when it is
/// replaced.
pub fn call_setItem(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    const old_value: ?[]u8 = if (internal.storage.getItem(key.asSlice())) |v| try allocator.dupe(u8, v) else null;
    defer if (old_value) |v| allocator.free(v);
    // Step 3.2: nothing changes, and nothing is broadcast.
    if (old_value) |v| {
        if (std.mem.eql(u8, v, value.asSlice())) return;
    }

    internal.storage.setItem(key.asSlice(), value.asSlice()) catch |err| {
        return switch (err) {
            WebStorageError.QuotaExceededError => error.QuotaExceededError,
            WebStorageError.SecurityError => error.SecurityError,
            WebStorageError.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };
    broadcast(instance, key.asSlice(), old_value, value.asSlice());
}

// ============================================================================
// HTML 12.2.1 "broadcast" and the storage event
// ============================================================================

/// `instance`'s relevant global object, when it is a Window.
fn relevantWindow(instance: *runtime.Instance) ?*runtime.Instance {
    const record = instance.ctx.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// `window`'s settings object's origin, serialized; null when it cannot be
/// read. Owned, `window.ctx.allocator`.
fn originOf(window: *runtime.Instance) ?[]const u8 {
    const settings = dom.global_settings.of(window) orelse return null;
    return settings.origin(window) catch null;
}

/// HTML "broadcast" `storage` with `key`, `old_value` and `new_value` (each
/// BORROWED).
///
/// "3. Let remoteStorages be all Storage objects excluding storage whose type
/// is storage's type, [whose] relevant settings object's origin is same
/// origin with storage's relevant settings object's origin, and, if type is
/// "session", whose relevant settings object's associated Document's node
/// navigable's traversable navigable is thisDocument's node navigable's
/// traversable navigable."
///
/// Deviation, stated, matching every browser: the event goes to every other
/// fully active Window that has - or, reading it now, would have - such a
/// Storage object, not only to those whose script has already read
/// `localStorage` (Blink's StorageArea::DispatchLocalStorageEvent takes each
/// same-origin window's storage area as it dispatches, making it if need be).
/// WPT's PrefixedLocalStorage listens in a window that never touched
/// storage. Each window's Storage object is taken in its own task.
fn broadcast(storage: *runtime.Instance, key: ?[]const u8, old_value: ?[]const u8, new_value: ?[]const u8) void {
    const internal = storage.getState(State).own._internal orelse return;
    const kind = internal.storage.storage_type;
    // "1. Let thisDocument be storage's relevant global object's associated
    // Document. 2. Let url be the serialization of thisDocument's URL."
    const window = relevantWindow(storage) orelse return;
    const document = interfaces.Window.get_document(window) catch return;
    const url = interfaces.Document.get_URL(document) catch return;
    defer document.ctx.allocator.free(url);
    const origin = originOf(window) orelse return;
    defer window.ctx.allocator.free(origin);
    // An opaque origin has no storage: its getters threw before any change.
    if (std.mem.eql(u8, origin, "null")) return;
    const source_context = html_core.BrowsingContext.ofWindow(@ptrCast(window));
    for (html_core.BrowsingContext.liveContexts()) |context| {
        if (context.orphaned or context.is_closed) continue;
        const remote: *runtime.Instance = @ptrCast(@alignCast(context.getActiveWindow() orelse continue));
        if (remote == window) continue;
        if (remote.stateAs(interfaces.Window.State) == null) continue;
        if (kind == .session) {
            const source = source_context orelse continue;
            if (context.getTop() != source.getTop()) continue;
        }
        const remote_origin = originOf(remote) orelse continue;
        defer remote.ctx.allocator.free(remote_origin);
        if (!std.mem.eql(u8, remote_origin, origin)) continue;
        // "4. For each remoteStorage of remoteStorages: queue a global task
        // on the DOM manipulation task source given remoteStorage's relevant
        // global object to fire an event named storage at remoteStorage's
        // relevant global object, using StorageEvent."
        queueStorageEvent(remote, kind, key, old_value, new_value, url);
    }
}

/// One remote Window's task: its Storage object, and the event at it.
const StorageTask = struct {
    window: *runtime.Instance,
    generation: u64,
    kind: WebStorageType,
    allocator: std.mem.Allocator,
    /// Owned copies.
    key: ?[]u8,
    old_value: ?[]u8,
    new_value: ?[]u8,
    url: []u8,

    fn destroy(self: *StorageTask) void {
        if (self.key) |v| self.allocator.free(v);
        if (self.old_value) |v| self.allocator.free(v);
        if (self.new_value) |v| self.allocator.free(v);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    fn target(self: *const StorageTask) ?*runtime.Instance {
        if (runtime.SlabAllocator.generationOf(self.window) != self.generation) return null;
        return self.window;
    }

    fn run(data: ?*anyopaque) void {
        const self: *StorageTask = @ptrCast(@alignCast(data orelse return));
        defer self.destroy();
        const window = self.target() orelse return;
        engine.runTaskInRealm(window.ctx, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *StorageTask = @ptrCast(@alignCast(data orelse return));
        const window = self.target() orelse return;
        // The event loop runs no task whose document is not fully active:
        // still the window's document, with a browsing context.
        const document = interfaces.Window.get_document(window) catch return;
        const view = (interfaces.Document.get_defaultView(document) catch null) orelse return;
        if (view != window) return;
        // remoteStorage: the window's Storage object of the type.
        const remote = switch (self.kind) {
            .local => interfaces.Window.get_localStorage(window),
            .session => interfaces.Window.get_sessionStorage(window),
        } catch return;
        // "... with key initialized to key, oldValue initialized to
        // oldValue, newValue initialized to newValue, url initialized to url,
        // and storageArea initialized to remoteStorage."
        const init_dict = dictionaries.StorageEventInit{
            .base = .{},
            .key = if (self.key) |v| runtime.DOMString.initInterned(v) else null,
            .oldValue = if (self.old_value) |v| runtime.DOMString.initInterned(v) else null,
            .newValue = if (self.new_value) |v| runtime.DOMString.initInterned(v) else null,
            .url = self.url,
            .storageArea = remote,
        };
        const event = interfaces.StorageEvent.call_constructor(
            window.ctx,
            runtime.DOMString.initInterned("storage"),
            webidl.Opt(dictionaries.StorageEventInit).passed(init_dict),
        ) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        // Fired by the user agent: trusted.
        _ = dom.fire_event.dispatchTrusted(window, event) catch {};
        event.releaseIfUnwrapped(generation);
    }
};

fn queueStorageEvent(window: *runtime.Instance, kind: WebStorageType, key: ?[]const u8, old_value: ?[]const u8, new_value: ?[]const u8, url: []const u8) void {
    const timer = window.ctx.getOptionalTimer() orelse return;
    const allocator = window.ctx.allocator;
    const task = allocator.create(StorageTask) catch return;
    task.* = .{
        .window = window,
        .generation = runtime.SlabAllocator.generationOf(window),
        .kind = kind,
        .allocator = allocator,
        .key = null,
        .old_value = null,
        .new_value = null,
        .url = &.{},
    };
    task.key = if (key) |v| allocator.dupe(u8, v) catch return task.destroy() else null;
    task.old_value = if (old_value) |v| allocator.dupe(u8, v) catch return task.destroy() else null;
    task.new_value = if (new_value) |v| allocator.dupe(u8, v) catch return task.destroy() else null;
    task.url = allocator.dupe(u8, url) catch return task.destroy();
    if (timer.setTimeout(0, StorageTask.run, task) == 0) task.destroy();
}
