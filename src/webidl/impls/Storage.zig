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
/// Removes the key/value pair with the given key, if it exists.
pub fn call_removeItem(instance: *runtime.Instance, key: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.storage.removeItem(key.asSlice());
}

/// Operation: clear
/// Removes all key/value pairs from the storage.
pub fn call_clear(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.storage.clear();
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
pub fn call_setItem(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    internal.storage.setItem(key.asSlice(), value.asSlice()) catch |err| {
        return switch (err) {
            WebStorageError.QuotaExceededError => error.QuotaExceededError,
            WebStorageError.SecurityError => error.SecurityError,
            WebStorageError.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };
}
