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
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const AbstractRange = interfaces.AbstractRange;
const range_boundaries = @import("dom").range_boundaries;

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

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
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
    // Release the internal block. `init` allocates one from the state arena, and
    // with no deinit body at all it was held for the life of the process.
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for startContainer
/// Spec: https://dom.spec.whatwg.org/#dom-range-startcontainer
/// Returns the node at the start of the range
pub fn get_startContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try boundaries(instance)).start_container;
}

/// Getter for startOffset
/// Spec: https://dom.spec.whatwg.org/#dom-range-startoffset
/// Returns the offset within the start node
pub fn get_startOffset(instance: *runtime.Instance) anyerror!u32 {
    return (try boundaries(instance)).start_offset;
}

/// Getter for endContainer
/// Spec: https://dom.spec.whatwg.org/#dom-range-endcontainer
/// Returns the node at the end of the range
pub fn get_endContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return (try boundaries(instance)).end_container;
}

/// Getter for endOffset
/// Spec: https://dom.spec.whatwg.org/#dom-range-endoffset
/// Returns the offset within the end node
pub fn get_endOffset(instance: *runtime.Instance) anyerror!u32 {
    return (try boundaries(instance)).end_offset;
}

/// Getter for collapsed
/// Spec: https://dom.spec.whatwg.org/#dom-range-collapsed
/// "if its start node is its end node and its start offset is its end offset"
pub fn get_collapsed(instance: *runtime.Instance) anyerror!bool {
    const b = try boundaries(instance);
    return b.start_container == b.end_container and b.start_offset == b.end_offset;
}

/// This range's start and end. They live in the subclass that maintains them -
/// a live Range moves them on every mutation, a StaticRange never does - which
/// answers through `dom.range_boundaries`. The generated state's own
/// startContainer/endContainer fields are never written by either, so they
/// are not read here.
fn boundaries(instance: *runtime.Instance) !range_boundaries.Boundaries {
    return range_boundaries.of(instance) orelse error.InvalidStateError;
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
