//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for MIDIPort interface
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
const MIDIPort = interfaces.MIDIPort;

pub const State = MIDIPort.State;

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

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for manufacturer
pub fn get_manufacturer(instance: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!enums.MIDIPortType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for version
pub fn get_version(instance: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) ImplError!enums.MIDIPortDeviceState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for connection
pub fn get_connection(instance: *runtime.Instance) ImplError!enums.MIDIPortConnectionState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onstatechange
pub fn get_onstatechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onstatechange
pub fn set_onstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

