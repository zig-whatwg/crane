//! Implementation for ProcessingInstruction interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-processinginstruction
//! WHATWG DOM Standard §4.13
//!
//! ProcessingInstruction nodes represent processing instructions in XML.
//! They extend CharacterData and have an associated target.
//! Node type is PROCESSING_INSTRUCTION_NODE (7).
//!
//! Migrated from: webidl/src/dom/ProcessingInstruction.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ProcessingInstruction = interfaces.ProcessingInstruction;

// Import related impls
const CharacterDataImpl = @import("CharacterData.zig");
const NodeImpl = @import("Node.zig");

pub const State = ProcessingInstruction.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for ProcessingInstruction implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The target of this processing instruction (e.g., "xml-stylesheet")
    target: []const u8,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .target = "",
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.target.len > 0) self.allocator.free(self.target);
    }
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

    // Initialize ProcessingInstruction internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// =============================================================================
// Getters - DOM §4.13
// =============================================================================

/// Getter for target
/// DOM §4.13 - Returns this's target.
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initInterned(internal.target);
}

/// Getter for sheet (from LinkStyle mixin - CSSOM)
/// Returns the associated stylesheet, if any
pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    // TODO: Return associated CSSStyleSheet if this is <?xml-stylesheet?>
    // Requires CSSOM integration
    return error.NotImplemented;
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Get the target string directly (for cloning)
pub fn getTarget(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.target;
}

/// Create a ProcessingInstruction with the given target and data
pub fn createProcessingInstruction(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    target: []const u8,
    data: []const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &ProcessingInstruction.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Set node type to PROCESSING_INSTRUCTION_NODE (7)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.PROCESSING_INSTRUCTION_NODE);

    // Set the target
    internal.target = try allocator.dupe(u8, target);

    // Set the data via CharacterData
    try CharacterDataImpl.setData(instance, data);

    return instance;
}
