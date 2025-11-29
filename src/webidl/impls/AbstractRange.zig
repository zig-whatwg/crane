//! Implementation for AbstractRange interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-abstractrange
//! WHATWG DOM Standard §5
//!
//! AbstractRange is a base interface for Range and StaticRange.
//! It provides readonly access to boundary points (start and end).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const AbstractRange = interfaces.AbstractRange;

pub const State = AbstractRange.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
};

/// Internal state for AbstractRange implementation
/// AbstractRange stores two boundary points: start and end
pub const InternalState = struct {
    /// Start boundary point - node
    start_container: ?*runtime.Instance = null,

    /// Start boundary point - offset
    start_offset: u32 = 0,

    /// End boundary point - node
    end_container: ?*runtime.Instance = null,

    /// End boundary point - offset
    end_offset: u32 = 0,
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState{};
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    runtime.Instance.deinit(instance);
}

/// Getter for startContainer
/// Spec: https://dom.spec.whatwg.org/#dom-range-startcontainer
/// Returns the node at the start of the range
pub fn get_startContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.startContainer;
}

/// Getter for startOffset
/// Spec: https://dom.spec.whatwg.org/#dom-range-startoffset
/// Returns the offset within the start node
pub fn get_startOffset(instance: *runtime.Instance) anyerror!u32 {
    const state = instance.getState(State);
    return state.own.startOffset;
}

/// Getter for endContainer
/// Spec: https://dom.spec.whatwg.org/#dom-range-endcontainer
/// Returns the node at the end of the range
pub fn get_endContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    return state.own.endContainer;
}

/// Getter for endOffset
/// Spec: https://dom.spec.whatwg.org/#dom-range-endoffset
/// Returns the offset within the end node
pub fn get_endOffset(instance: *runtime.Instance) anyerror!u32 {
    const state = instance.getState(State);
    return state.own.endOffset;
}

/// Getter for collapsed
/// Spec: https://dom.spec.whatwg.org/#dom-range-collapsed
/// Returns true if the range's start and end are the same position
pub fn get_collapsed(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.startContainer == state.own.endContainer and
        state.own.startOffset == state.own.endOffset;
}

// ============================================================================
// Helper functions for subclasses (Range, StaticRange)
// ============================================================================

/// Set the start boundary point
pub fn setStart(instance: *runtime.Instance, container: *runtime.Instance, offset: u32) void {
    const state = instance.getState(State);
    state.own.startContainer = container;
    state.own.startOffset = offset;
}

/// Set the end boundary point
pub fn setEnd(instance: *runtime.Instance, container: *runtime.Instance, offset: u32) void {
    const state = instance.getState(State);
    state.own.endContainer = container;
    state.own.endOffset = offset;
}
