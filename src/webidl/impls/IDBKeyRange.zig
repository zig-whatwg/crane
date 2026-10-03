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
const dom = @import("dom");
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
pub fn get_lower(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.range.lower) |lower| {
        return (try dom.indexeddb_keys.toValue(instance.ctx, lower)).take();
    }

    // Return undefined for no lower bound
    return runtime.JSValue.jsUndefined;
}

/// Getter for upper
///
/// Returns the upper bound of the range, or undefined if no upper bound.
pub fn get_upper(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.range.upper) |upper| {
        return (try dom.indexeddb_keys.toValue(instance.ctx, upper)).take();
    }

    // Return undefined for no upper bound
    return runtime.JSValue.jsUndefined;
}

/// Getter for lowerOpen
///
/// Returns true if the lower bound is open (excluded).
pub fn get_lowerOpen(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.range.lower_open;
}

/// Getter for upperOpen
///
/// Returns true if the upper bound is open (excluded).
pub fn get_upperOpen(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.range.upper_open;
}

/// Static operation: only
///
/// Creates a key range containing only a single key.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-only
pub fn call_static_only(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS value to IDBKey
    var key = try dom.indexeddb_keys.require(instance.ctx, value, instance.ctx.allocator);
    defer key.deinit();

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    errdefer runtime.Instance.deinit(new_instance);

    // Set the range to only(key) - with keys of its own (`keptRange`).
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = try keptRange(new_internal.allocator, BackendKeyRange.only(key));
    }

    return new_instance;
}

/// Operation: includes
///
/// Returns true if the given key is within this range.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-includes
pub fn call_includes(instance: *runtime.Instance, key: runtime.JSValue) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert JS value to IDBKey
    var idb_key = try dom.indexeddb_keys.require(instance.ctx, key, instance.ctx.allocator);
    defer idb_key.deinit();

    return internal.range.includes(idb_key);
}

/// Static operation: bound
///
/// Creates a key range with both lower and upper bounds.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-bound
pub fn call_static_bound(instance: *runtime.Instance, lower: runtime.JSValue, upper: runtime.JSValue, lowerOpen: webidl.Opt(bool), upperOpen: webidl.Opt(bool)) anyerror!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS values to IDBKey
    var lower_key = try dom.indexeddb_keys.require(instance.ctx, lower, instance.ctx.allocator);
    defer lower_key.deinit();
    var upper_key = try dom.indexeddb_keys.require(instance.ctx, upper, instance.ctx.allocator);
    defer upper_key.deinit();

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

    errdefer runtime.Instance.deinit(new_instance);

    // Set the range - with keys of its own (`keptRange`).
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = try keptRange(new_internal.allocator, range);
    }

    return new_instance;
}

/// Static operation: upperBound
///
/// Creates a key range with only an upper bound.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-upperbound
pub fn call_static_upperBound(instance: *runtime.Instance, upper: runtime.JSValue, open: webidl.Opt(bool)) anyerror!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS value to IDBKey
    var upper_key = try dom.indexeddb_keys.require(instance.ctx, upper, instance.ctx.allocator);
    defer upper_key.deinit();

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    errdefer runtime.Instance.deinit(new_instance);

    // Set the range - unwrap Opt (default false)
    const open_val = if (open.wasPassed()) open.value else false;
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = try keptRange(new_internal.allocator, BackendKeyRange.upperBound(upper_key, open_val));
    }

    return new_instance;
}

/// Static operation: lowerBound
///
/// Creates a key range with only a lower bound.
///
/// Spec: https://w3c.github.io/IndexedDB/#dom-idbkeyrange-lowerbound
pub fn call_static_lowerBound(instance: *runtime.Instance, lower: runtime.JSValue, open: webidl.Opt(bool)) anyerror!*runtime.Instance {
    // Static method - use context directly, not instance state
    const allocator = instance.ctx.allocator;

    // Convert JS value to IDBKey
    var lower_key = try dom.indexeddb_keys.require(instance.ctx, lower, instance.ctx.allocator);
    defer lower_key.deinit();

    // Create new range instance
    const new_instance = IDBKeyRangeInterface.init(allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    errdefer runtime.Instance.deinit(new_instance);

    // Set the range - unwrap Opt (default false)
    const open_val = if (open.wasPassed()) open.value else false;
    const new_state = new_instance.getState(State);
    if (new_state.own._internal) |new_internal| {
        new_internal.range = try keptRange(new_internal.allocator, BackendKeyRange.lowerBound(lower_key, open_val));
    }

    return new_instance;
}

/// The range `range` as this range keeps it: its own copy of every key.
///
/// A key made from an argument (`convertFromJSValue`) borrows that argument's
/// bytes, and the binding frees them when the call returns: stored as they
/// were, `IDBKeyRange.only("a").lower` read freed memory. Each bound gets a
/// copy of its own - `only` stores one key as both bounds, so each bound a
/// separate copy - and the range's deinit frees them (it frees bound keys
/// once the range has an allocator).
fn keptRange(allocator: std.mem.Allocator, range: BackendKeyRange) !BackendKeyRange {
    var kept = range;
    kept.lower = null;
    kept.upper = null;
    kept.allocator = allocator;
    errdefer kept.deinit();
    if (range.lower) |lower| kept.lower = try lower.clone(allocator);
    if (range.upper) |upper| kept.upper = try upper.clone(allocator);
    return kept;
}

pub fn installHooks() void {
    dom.indexeddb.installKeyRanges(.{ .copy = copyRange });
}
fn copyRange(instance: *runtime.Instance, allocator: std.mem.Allocator) !BackendKeyRange {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return keptRange(allocator, internal.range);
}
