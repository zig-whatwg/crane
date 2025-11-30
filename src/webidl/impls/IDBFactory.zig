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

/// Deinitialize instance - clean up owned resources only
/// NOTE: Do NOT call runtime.Instance.deinit() here!
/// The GC integration layer (gc_integration.onObjectFreed) handles:
/// 1. Calling this deinit function (via vtable.deinit)
/// 2. Freeing the Instance handle back to the SlabAllocator
/// Calling Instance.deinit from here would cause infinite recursion.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
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

    // Compare V8 values directly using raw V8 APIs
    // We compare in place to avoid lifetime issues with string buffers
    return compareV8Keys(first, second) orelse return error.DataError;
}

/// Compare two V8 values as IndexedDB keys
/// Returns null if either value is not a valid key type
fn compareV8Keys(first: *const anyopaque, second: *const anyopaque) ?i16 {
    const first_type = getV8KeyType(first) orelse return null;
    const second_type = getV8KeyType(second) orelse return null;

    // Per spec: different types have ordering: array > binary > string > date > number
    if (first_type != second_type) {
        // array = 4, binary = 3, string = 2, date = 1, number = 0
        if (first_type > second_type) return 1;
        return -1;
    }

    // Same type - compare values
    return switch (first_type) {
        0 => compareV8Numbers(first, second), // number
        1 => compareV8Dates(first, second), // date
        2 => compareV8Strings(first, second), // string
        3, 4 => null, // binary, array - TODO
        else => null, // Invalid type
    };
}

/// Get the key type code for a V8 value
/// Returns: 0=number, 1=date, 2=string, 3=binary, 4=array, null=invalid
fn getV8KeyType(ptr: *const anyopaque) ?u8 {
    const v8_value: *v8.ffi.Value = @ptrCast(@constCast(ptr));

    if (v8.ffi.v8_Value_IsNumber(v8_value)) return 0;
    // TODO: Check for Date object
    if (v8.ffi.v8_Value_IsString(v8_value)) return 2;
    // TODO: Check for ArrayBuffer/binary
    // TODO: Check for Array
    return null;
}

/// Compare two V8 number values
fn compareV8Numbers(first: *const anyopaque, second: *const anyopaque) i16 {
    const a = v8.ffi.v8_Value_NumberValue_Raw(first);
    const b = v8.ffi.v8_Value_NumberValue_Raw(second);

    if (std.math.isNan(a) or std.math.isNan(b)) {
        // NaN comparison is weird, but per spec NaN < NaN and NaN > NaN are both false
        return 0;
    }

    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
}

/// Compare two V8 date values (TODO: implement date support)
fn compareV8Dates(_: *const anyopaque, _: *const anyopaque) i16 {
    // TODO: Extract date milliseconds and compare
    return 0;
}

/// Compare two V8 string values
fn compareV8Strings(first: *const anyopaque, second: *const anyopaque) i16 {
    // Get string lengths
    const first_len = v8.ffi.v8_Value_StringLength_Raw(first);
    const second_len = v8.ffi.v8_Value_StringLength_Raw(second);

    if (first_len < 0 or second_len < 0) return 0; // Not strings

    // Use stack buffers for comparison
    var first_buf: [256]u8 = undefined;
    var second_buf: [256]u8 = undefined;

    // Handle empty strings
    if (first_len == 0 and second_len == 0) return 0;
    if (first_len == 0) return -1;
    if (second_len == 0) return 1;

    // For small strings, compare directly
    if (first_len <= 256 and second_len <= 256) {
        const first_written = v8.ffi.v8_Value_StringWriteUtf8_Raw(first, &first_buf, @intCast(first_len));
        const second_written = v8.ffi.v8_Value_StringWriteUtf8_Raw(second, &second_buf, @intCast(second_len));

        if (first_written <= 0 or second_written <= 0) return 0;

        const first_slice = first_buf[0..@intCast(first_written)];
        const second_slice = second_buf[0..@intCast(second_written)];

        // Lexicographic comparison per IndexedDB spec (code unit comparison)
        const min_len = @min(first_slice.len, second_slice.len);
        for (0..min_len) |i| {
            if (first_slice[i] < second_slice[i]) return -1;
            if (first_slice[i] > second_slice[i]) return 1;
        }

        // Prefixes are equal, shorter string is less
        if (first_slice.len < second_slice.len) return -1;
        if (first_slice.len > second_slice.len) return 1;
        return 0;
    }

    // For large strings, compare by length only (TODO: proper large string comparison)
    if (first_len < second_len) return -1;
    if (first_len > second_len) return 1;
    return 0;
}
