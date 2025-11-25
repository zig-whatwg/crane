//! Implementation for Comment interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-comment
//! WHATWG DOM Standard §4.14
//!
//! Comment represents a comment in the document tree.
//! It extends CharacterData and has node type COMMENT_NODE (8).
//!
//! Note: Comment has no own attributes beyond what it inherits from CharacterData,
//! so it has no InternalState. All state is managed via inheritance.
//!
//! Migrated from: webidl/src/dom/Comment.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Comment = interfaces.Comment;

// Import related impls
const CharacterDataImpl = @import("CharacterData.zig");
const NodeImpl = @import("Node.zig");

pub const State = Comment.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for Comment implementation
/// Comment has no own attributes - all state is inherited from CharacterData/Node
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Comment has no own state to initialize
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Comment has no own state to clean up
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// DOM §4.14 - Comment(data)
/// Creates a new Comment node with the given data (default empty string)
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, data: runtime.DOMString) !*runtime.Instance {
    const instance = try init(allocator, State, &Comment.vtable, ctx);
    errdefer deinit(instance);

    // Set node type to COMMENT_NODE (8)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.COMMENT_NODE);

    // Set the comment data via CharacterData
    try CharacterDataImpl.setData(instance, data.asSlice());

    return instance;
}
