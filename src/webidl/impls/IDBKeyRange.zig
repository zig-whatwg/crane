//! Implementation for IDBKeyRange interface
//!
//! Connects WebIDL interface to IndexedDB backend at src/storage/indexeddb/key_range.zig
//!
//! Spec: https://w3c.github.io/IndexedDB/#idbkeyrange
//!
//! IDBKeyRange represents a continuous interval over keys. Used to retrieve
//! a range of records from an object store or index.

const std = @import("std");
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
    runtime.Instance.deinit(instance);
}

/// Getter for lower
///
/// Returns the lower bound of the range, or undefined if no lower bound.
pub fn get_lower(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.range.lower) |lower| {
        // TODO: Convert IDBKey to JS value
        _ = lower;
        return error.InvalidState; // Placeholder - need key-to-JS conversion
    }

    // Return undefined for no lower bound
    return error.InvalidState; // Placeholder
}

/// Getter for upper
///
/// Returns the upper bound of the range, or undefined if no upper bound.
pub fn get_upper(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.range.upper) |upper| {
        // TODO: Convert IDBKey to JS value
        _ = upper;
        return error.InvalidState; // Placeholder - need key-to-JS conversion
    }

    // Return undefined for no upper bound
    return error.InvalidState; // Placeholder
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
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert JS value to IDBKey
    const key = convertToKey(value) catch return error.DataError;

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(internal.allocator, instance.ctx) catch {
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
pub fn call_bound(instance: *runtime.Instance, lower: *const anyopaque, upper: *const anyopaque, lowerOpen: bool, upperOpen: bool) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert JS values to IDBKey
    const lower_key = convertToKey(lower) catch return error.DataError;
    const upper_key = convertToKey(upper) catch return error.DataError;

    // Create the range
    const range = BackendKeyRange.bound(lower_key, upper_key, lowerOpen, upperOpen) catch {
        return error.DataError;
    };

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(internal.allocator, instance.ctx) catch {
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
pub fn call_upperBound(instance: *runtime.Instance, upper: *const anyopaque, open: bool) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert JS value to IDBKey
    const upper_key = convertToKey(upper) catch return error.DataError;

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Set the range
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = BackendKeyRange.upperBound(upper_key, open);
    }

    return new_instance;
}

/// Static operation: lowerBound
///
/// Creates a key range with only a lower bound.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-lowerbound
pub fn call_lowerBound(instance: *runtime.Instance, lower: *const anyopaque, open: bool) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert JS value to IDBKey
    const lower_key = convertToKey(lower) catch return error.DataError;

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Set the range
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = BackendKeyRange.lowerBound(lower_key, open);
    }

    return new_instance;
}

/// Convert anyopaque to IDBKey
///
/// This handles the conversion from V8 values (passed as opaque pointers)
/// to the backend IDBKey type.
fn convertToKey(ptr: *const anyopaque) !BackendKey {
    // For now, assume the pointer is directly an IDBKey
    // In full implementation, this would inspect the JS value type
    // and construct the appropriate IDBKey variant
    _ = ptr;

    // TODO: Implement proper JS value to IDBKey conversion
    // This requires integration with the V8 conversions layer
    return BackendKey.number(0); // Placeholder
}
