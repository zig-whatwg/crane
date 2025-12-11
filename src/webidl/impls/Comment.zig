//! Implementation for Comment interface
//! DOM §4.11 - Comment nodes contain arbitrary character data (comments)
//!
//! Inheritance: Comment → CharacterData → Node → EventTarget

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const Comment = interfaces.Comment;

// Parent class implementation
const CharacterDataImpl = @import("CharacterData.zig");
const NodeImpl = @import("Node.zig");

pub const State = Comment.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for Comment
/// Comment doesn't need additional state beyond CharacterData
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Initialize instance (creates the instance)
/// Chains to parent class: CharacterData → Node → EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (CharacterData) which chains to Node → EventTarget
    const instance = try CharacterDataImpl.init(allocator, StateType, vtable, ctx);
    errdefer CharacterDataImpl.deinit(instance);

    // Set node type to COMMENT_NODE (8)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.COMMENT_NODE);

    // Initialize Comment internal state in global registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try Registry.set(instance, internal);

    return instance;
}

/// Get Comment's internal state from the registry
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);

    // Chain to parent deinit
    CharacterDataImpl.deinit(instance);
}

/// Constructor implementation
/// DOM §4.11 - Comment(data)
/// Creates a new Comment node with the given data
pub fn call_constructor(ctx: runtime.Context, data: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &Comment.vtable, ctx);
    errdefer deinit(instance);

    // Set the comment data via CharacterData
    const data_slice = if (data.was_passed) data.value.asSlice() else "";
    try CharacterDataImpl.setData(instance, data_slice);

    return instance;
}

/// Clean up ALL remaining internal states.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}

