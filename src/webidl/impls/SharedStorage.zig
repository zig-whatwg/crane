//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for SharedStorage interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Remove this header comment block
//!   3. Add your implementation logic
//!   4. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const SharedStorage = interfaces.SharedStorage;

pub const State = SharedStorage.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for worklet
pub fn get_worklet(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, key: runtime.DOMString, options: dictionaries.SharedStorageModifierMethodOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = key;
    _ = options;
    return error.NotImplemented;
}

/// Operation: append
pub fn call_append(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString, options: dictionaries.SharedStorageModifierMethodOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = key;
    _ = value;
    _ = options;
    return error.NotImplemented;
}

/// Operation: batchUpdate
pub fn call_batchUpdate(instance: *runtime.Instance, methods: *const anyopaque, options: dictionaries.SharedStorageModifierMethodOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = methods;
    _ = options;
    return error.NotImplemented;
}

/// Operation: run
pub fn call_run(instance: *runtime.Instance, name: runtime.DOMString, options: dictionaries.SharedStorageRunOperationMethodOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = name;
    _ = options;
    return error.NotImplemented;
}

/// Operation: createWorklet
pub fn call_createWorklet(instance: *runtime.Instance, moduleURL: runtime.USVString, options: dictionaries.SharedStorageWorkletOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = moduleURL;
    _ = options;
    return error.NotImplemented;
}

/// Operation: set
pub fn call_set(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString, options: dictionaries.SharedStorageSetMethodOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = key;
    _ = value;
    _ = options;
    return error.NotImplemented;
}

/// Operation: length
pub fn call_length(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: remainingBudget
pub fn call_remainingBudget(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, key: runtime.DOMString) ImplError!*const anyopaque {
    _ = instance;
    _ = key;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance, options: dictionaries.SharedStorageModifierMethodOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: selectURL
pub fn call_selectURL(instance: *runtime.Instance, name: runtime.DOMString, urls: *const anyopaque, options: dictionaries.SharedStorageRunOperationMethodOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = name;
    _ = urls;
    _ = options;
    return error.NotImplemented;
}

/// Async iterator: values
/// Returns an async iterator over storage values
pub fn call_values(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Async iterator: getAsyncIterator
/// Returns an async iterator over storage entries
pub fn call_getAsyncIterator(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}
