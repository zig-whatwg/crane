//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for IDBCursor interface
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
const IDBCursor = interfaces.IDBCursor;

pub const State = IDBCursor.State;

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

/// Getter for source
pub fn get_source(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) ImplError!enums.IDBCursorDirection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for key
pub fn get_key(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for primaryKey
pub fn get_primaryKey(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for request
pub fn get_request(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: continue
pub fn call_continue(instance: *runtime.Instance, key: *const anyopaque) ImplError!void {
    _ = instance;
    _ = key;
    return error.NotImplemented;
}

/// Operation: continuePrimaryKey
pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: *const anyopaque, primaryKey: *const anyopaque) ImplError!void {
    _ = instance;
    _ = key;
    _ = primaryKey;
    return error.NotImplemented;
}

/// Operation: update
pub fn call_update(instance: *runtime.Instance, value: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: advance
pub fn call_advance(instance: *runtime.Instance, count: u32) ImplError!void {
    _ = instance;
    _ = count;
    return error.NotImplemented;
}

