//! Implementation for Slottable mixin
//!
//! Spec: https://dom.spec.whatwg.org/#interface-slottable
//!
//! This impl contains the actual logic for Slottable methods.
//! The mixin file delegates to these functions.
//!
//! The Slottable mixin defines:
//! - assignedSlot - Returns the assigned slot, if any

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");

const dom = @import("dom");

pub const State = interfaces.Slottable.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

// =============================================================================
// Slottable Attributes
// =============================================================================

/// assignedSlot: "return the result of find a slot given this and true".
/// Spec: https://dom.spec.whatwg.org/#dom-slotable-assignedslot
///
/// Element and Text still bind their own (Slottable is not yet among
/// codegen's inherited_mixins), which run the same algorithm.
pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return dom.shadow_dom_algorithms.assignedSlotForScript(instance);
}
