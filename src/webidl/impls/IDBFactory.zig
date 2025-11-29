//! Implementation for IDBFactory interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/factory.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbfactory
//!
//! IDBFactory is the entry point for IndexedDB. It provides methods to open
//! and delete databases, list available databases, and compare keys.

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const v8 = @import("v8");
const IDBFactoryInterface = interfaces.IDBFactory;

// Backend imports
const storage = @import("storage");
const BackendFactory = storage.indexeddb.IDBFactory;
const BackendKey = storage.indexeddb.IDBKey;
const BackendKeyRange = storage.indexeddb.IDBKeyRange;

pub const State = IDBFactoryInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    SecurityError,
    TypeError,
    DataError,
};

/// Internal state for IDBFactory
///
/// Stores the backend IDBFactory instance that manages all database operations.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend factory instance
    factory: *BackendFactory,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.factory.deinit();
        allocator.destroy(self.factory);
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
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);

    // Create internal state
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;

    // Create backend factory
    internal.factory = try allocator.create(BackendFactory);
    errdefer allocator.destroy(internal.factory);

    internal.factory.* = BackendFactory.init(allocator);

    // Set default storage key from context origin (if available)
    // TODO: Get origin from runtime context
    internal.factory.setStorageKey("default-origin");

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    runtime.Instance.deinit(instance);
}

/// Operation: open
///
/// Opens a connection to a database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-open
///
/// Returns an IDBOpenDBRequest that will eventually contain the database connection.
pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, version: webidl.Opt(u64)) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Version 0 is invalid per spec - unwrap Opt
    const version_val: ?u64 = if (version.wasPassed()) version.value else null;
    if (version_val != null and version_val.? == 0) {
        return error.TypeError;
    }

    // Convert DOMString to slice for backend
    const name_slice = name.asSlice();

    // Call backend open
    const request = internal.factory.open(name_slice, version_val) catch |err| {
        return switch (err) {
            error.TypeError => error.TypeError,
            error.SecurityError => error.SecurityError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };

    // Wrap the backend request in a WebIDL IDBOpenDBRequest instance
    const request_instance = interfaces.IDBOpenDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend request in the WebIDL wrapper
    const request_state = request_instance.getState(interfaces.IDBOpenDBRequest.State);
    if (request_state.own._internal) |req_internal| {
        // Set the backend request reference
        _ = req_internal;
        _ = request;
        // TODO: Connect backend request to WebIDL request wrapper
    }

    return request_instance;
}

/// Operation: databases
///
/// Returns a Promise that resolves to a sequence of IDBDatabaseInfo dictionaries.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-databases
pub fn call_databases(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const db_list = internal.factory.databases() catch |err| {
        return switch (err) {
            error.SecurityError => error.SecurityError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };

    // TODO: Convert db_list to Promise<sequence<IDBDatabaseInfo>>
    // For now, return the raw pointer - V8 integration layer will handle conversion
    _ = db_list;
    return error.InvalidState; // Placeholder until Promise integration is complete
}

/// Operation: deleteDatabase
///
/// Deletes a database.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-deletedatabase
///
/// Returns an IDBOpenDBRequest that fires success when the database is deleted.
pub fn call_deleteDatabase(instance: *runtime.Instance, name: runtime.DOMString) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert DOMString to slice for backend
    const name_slice = name.asSlice();

    // Call backend deleteDatabase
    const request = internal.factory.deleteDatabase(name_slice) catch |err| {
        return switch (err) {
            error.SecurityError => error.SecurityError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };

    // Wrap the backend request in a WebIDL IDBOpenDBRequest instance
    const request_instance = interfaces.IDBOpenDBRequest.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Store backend request reference
    _ = request;
    // TODO: Connect backend request to WebIDL request wrapper

    return request_instance;
}

/// Operation: cmp
///
/// Compares two IndexedDB keys.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbfactory-cmp
///
/// Returns:
/// -  1 if first > second
/// - -1 if first < second
/// -  0 if first == second
pub fn call_cmp(instance: *runtime.Instance, first: *const anyopaque, second: *const anyopaque) ImplError!i16 {
    const state = instance.getState(State);
    _ = state.own._internal orelse return error.InvalidState;

    // Convert V8 values to IDBKey
    // The anyopaque pointers are actually V8 Value pointers passed through from the V8 layer
    const first_key = convertV8ToKey(first) orelse return error.DataError;
    const second_key = convertV8ToKey(second) orelse return error.DataError;

    // Use the standalone compare function from the key module
    return storage.indexeddb.key.compare(first_key, second_key);
}

/// Convert a V8 value (passed as anyopaque) to an IDBKey
///
/// Per IndexedDB spec, valid keys are:
/// - Number (excluding NaN)
/// - String
/// - Date
/// - ArrayBuffer/ArrayBufferView (binary)
/// - Array of keys
fn convertV8ToKey(ptr: *const anyopaque) ?BackendKey {
    // The anyopaque pointer handling depends on the V8 conversion layer:
    // - For numbers: ptr is a V8 Value pointer (Global<Value>*)
    // - For strings: ptr is a DOMString* (allocated by conversion layer)
    //
    // We distinguish by attempting to interpret as DOMString first.
    // DOMString is a tagged union. We try calling asSlice() which will
    // return the string data regardless of which variant it is.
    //
    // If the pointer is actually a V8 Value, calling asSlice() may return
    // garbage or crash. So we use a heuristic: check if the "length" field
    // (bytes 8-15 in a slice) is a reasonable string length (< 1MB and > 0
    // for non-empty strings).

    const slice_struct = @as(*const extern struct { ptr: [*]const u8, len: usize }, @ptrCast(@alignCast(ptr)));
    const maybe_len = slice_struct.len;

    // Heuristic: if length looks like a reasonable string length (1 to 1MB),
    // assume this is a DOMString
    if (maybe_len > 0 and maybe_len < 1024 * 1024) {
        // Check if the pointer value also looks reasonable
        const ptr_val = @intFromPtr(slice_struct.ptr);
        if (ptr_val > 0x1000) {
            // Likely a DOMString - read the string data directly from the slice
            const str_slice = slice_struct.ptr[0..maybe_len];
            return BackendKey.string(str_slice);
        }
    }

    // Otherwise, it's a V8 Value pointer
    const v8_value: *v8.ffi.Value = @ptrCast(@constCast(ptr));

    // Check type and convert accordingly
    if (v8.ffi.v8_Value_IsNumber(v8_value)) {
        // Extract number value using raw function that gets current context from isolate
        const num = v8.ffi.v8_Value_NumberValue_Raw(ptr);
        if (std.math.isNan(num)) {
            return null; // NaN is not a valid key
        }
        return BackendKey.number(num);
    }

    // TODO: Handle Date, ArrayBuffer, and Array types
    // For now, return null for unsupported types
    return null;
}
