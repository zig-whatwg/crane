//! Implementation for IDBKeyRange interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/key_range.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbkeyrange
//!
//! IDBKeyRange represents a continuous interval over keys. Used to retrieve
//! a range of records from an object store or index.

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const IDBKeyRangeInterface = interfaces.IDBKeyRange;

// Backend imports
const storage = @import("storage");
const BackendKeyRange = storage.indexeddb.IDBKeyRange;
const BackendKey = storage.indexeddb.IDBKey;

pub const State = IDBKeyRangeInterface.State;

pub const ImplError = error{
    InvalidState,
    OutOfMemory,
    DataError,
};

/// Internal state for IDBKeyRange
///
/// Stores the backend key range that defines the bounds.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Backend key range
    range: BackendKeyRange,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        var range = self.range;
        range.deinit();
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

    // Default to unbounded range
    internal.range = BackendKeyRange.unbounded();

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for lower
///
/// Returns the lower bound of the range, or undefined if no lower bound.
pub fn get_lower(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.range.lower) |lower| {
        return convertKeyToV8(lower);
    }

    // Return undefined for no lower bound - use V8 undefined
    const v8 = @import("v8");
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidState;
    return @ptrCast(v8.ffi.v8_Undefined(isolate));
}

/// Getter for upper
///
/// Returns the upper bound of the range, or undefined if no upper bound.
pub fn get_upper(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.range.upper) |upper| {
        return convertKeyToV8(upper);
    }

    // Return undefined for no upper bound - use V8 undefined
    const v8 = @import("v8");
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidState;
    return @ptrCast(v8.ffi.v8_Undefined(isolate));
}

/// Getter for lowerOpen
///
/// Returns true if the lower bound is open (excluded).
pub fn get_lowerOpen(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.range.lower_open;
}

/// Getter for upperOpen
///
/// Returns true if the upper bound is open (excluded).
pub fn get_upperOpen(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.range.upper_open;
}

/// Static operation: only
///
/// Creates a key range containing only a single key.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-only
pub fn call_only(instance: *runtime.Instance, value: *const anyopaque) ImplError!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS value to IDBKey
    const key = convertToKey(value) catch return error.DataError;

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Set the range to only(key)
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = BackendKeyRange.only(key);
    }

    return new_instance;
}

/// Operation: includes
///
/// Returns true if the given key is within this range.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-includes
pub fn call_includes(instance: *runtime.Instance, key: *const anyopaque) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert JS value to IDBKey
    const idb_key = convertToKey(key) catch return error.DataError;

    return internal.range.includes(idb_key);
}

/// Static operation: bound
///
/// Creates a key range with both lower and upper bounds.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-bound
pub fn call_bound(instance: *runtime.Instance, lower: *const anyopaque, upper: *const anyopaque, lowerOpen: webidl.Opt(bool), upperOpen: webidl.Opt(bool)) ImplError!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS values to IDBKey
    const lower_key = convertToKey(lower) catch return error.DataError;
    const upper_key = convertToKey(upper) catch return error.DataError;

    // Create the range - unwrap Opt bools (default false)
    const lower_open = if (lowerOpen.wasPassed()) lowerOpen.value else false;
    const upper_open = if (upperOpen.wasPassed()) upperOpen.value else false;
    const range = BackendKeyRange.bound(lower_key, upper_key, lower_open, upper_open) catch {
        return error.DataError;
    };

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Set the range
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = range;
    }

    return new_instance;
}

/// Static operation: upperBound
///
/// Creates a key range with only an upper bound.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-upperbound
pub fn call_upperBound(instance: *runtime.Instance, upper: *const anyopaque, open: webidl.Opt(bool)) ImplError!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS value to IDBKey
    const upper_key = convertToKey(upper) catch return error.DataError;

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Set the range - unwrap Opt (default false)
    const open_val = if (open.wasPassed()) open.value else false;
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = BackendKeyRange.upperBound(upper_key, open_val);
    }

    return new_instance;
}

/// Static operation: lowerBound
///
/// Creates a key range with only a lower bound.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-lowerbound
pub fn call_lowerBound(instance: *runtime.Instance, lower: *const anyopaque, open: webidl.Opt(bool)) ImplError!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS value to IDBKey
    const lower_key = convertToKey(lower) catch return error.DataError;

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Set the range - unwrap Opt (default false)
    const open_val = if (open.wasPassed()) open.value else false;
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = BackendKeyRange.lowerBound(lower_key, open_val);
    }

    return new_instance;
}

/// Convert IDBKey to V8 value (anyopaque pointer)
///
/// This handles the conversion from backend IDBKey type to V8 values.
/// Returns an opaque pointer that can be returned directly to JavaScript.
fn convertKeyToV8(key: BackendKey) !*const anyopaque {
    const v8 = @import("v8");
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.InvalidState;

    switch (key.key_type) {
        .number => {
            // Convert number key to V8 Number
            const num = v8.ffi.v8_Number_New(isolate, key.value.number);
            return @ptrCast(num);
        },
        .date => {
            // Convert date key to V8 Date (milliseconds since epoch)
            // For now, return as a number (Date support requires context)
            const ms_as_f64: f64 = @floatFromInt(key.value.date);
            const num = v8.ffi.v8_Number_New(isolate, ms_as_f64);
            return @ptrCast(num);
        },
        .string => {
            // Convert string key to V8 String
            const str = key.value.string;
            const v8_str = v8.ffi.v8_String_NewFromUtf8(isolate, str.ptr, @intCast(str.len));
            if (v8_str) |s| {
                return @ptrCast(s);
            }
            return error.InvalidState;
        },
        .binary => {
            // Binary data - would need ArrayBuffer support
            // For now, return undefined
            return @ptrCast(v8.ffi.v8_Undefined(isolate));
        },
        .array => {
            // Array of keys - would need Array support with recursive conversion
            // For now, return undefined
            return @ptrCast(v8.ffi.v8_Undefined(isolate));
        },
    }
}

/// Convert anyopaque to IDBKey
///
/// This handles the conversion from V8 values (passed as opaque pointers)
/// to the backend IDBKey type.
///
/// Per IndexedDB spec, valid key types are:
/// - number (not NaN)
/// - Date (converted to its time value)
/// - string
/// - binary (ArrayBuffer, etc.)
/// - array (of valid keys)
fn convertToKey(ptr: *const anyopaque) !BackendKey {
    const v8 = @import("v8");

    // Cast to V8 value
    const value: *v8.ffi.Value = @ptrCast(@constCast(ptr));

    // Check for number first (most common case)
    if (v8.ffi.v8_Value_IsNumber(value)) {
        const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.DataError;
        const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.DataError;
        const num = v8.ffi.v8_Value_NumberValue(value, context);

        // Check for NaN - NaN is not a valid key
        if (num != num) { // NaN check: NaN != NaN
            return error.DataError;
        }

        return BackendKey.number(num);
    }

    // Check for string
    if (v8.ffi.v8_Value_IsString(value)) {
        // For now, return a number placeholder - full implementation would need
        // V8 string extraction with allocator
        // TODO: Implement proper string key extraction
        return error.DataError;
    }

    // Check for Array (array of keys)
    if (v8.ffi.v8_Value_IsArray(value)) {
        // TODO: Implement array key conversion
        return error.DataError;
    }

    // Check for object - could be Date or other objects
    // For now, we don't have v8_Value_IsDate so we can't distinguish
    if (v8.ffi.v8_Value_IsObject(value)) {
        // TODO: Implement Date and ArrayBuffer key support
        return error.DataError;
    }

    // Invalid key type
    return error.DataError;
}
