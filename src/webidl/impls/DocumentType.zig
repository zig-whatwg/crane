//! Implementation for DocumentType interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-documenttype
//! WHATWG DOM Standard §4.7
//!
//! DocumentType nodes represent the <!DOCTYPE> declaration.
//! They have a name, publicId, and systemId.
//!
//! Migrated from: webidl/src/dom/DocumentType.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DocumentType = interfaces.DocumentType;

// Import related impls
const NodeImpl = @import("Node.zig");

pub const State = DocumentType.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for DocumentType implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The name of the doctype (e.g., "html" for <!DOCTYPE html>)
    name: []const u8,

    /// The public identifier (empty string if not specified)
    public_id: []const u8,

    /// The system identifier (empty string if not specified)
    system_id: []const u8,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .name = "",
            .public_id = "",
            .system_id = "",
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.name.len > 0) self.allocator.free(self.name);
        if (self.public_id.len > 0) self.allocator.free(self.public_id);
        if (self.system_id.len > 0) self.allocator.free(self.system_id);
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

    // Initialize DocumentType internal state
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
    runtime.Instance.deinit(instance);
}

// =============================================================================
// Getters - DOM §4.7
// =============================================================================

/// Getter for name
/// DOM §4.7 - Returns this's name.
pub fn get_name(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initInterned(internal.name);
}

/// Getter for publicId
/// DOM §4.7 - Returns this's public ID.
pub fn get_publicId(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initInterned(internal.public_id);
}

/// Getter for systemId
/// DOM §4.7 - Returns this's system ID.
pub fn get_systemId(instance: *runtime.Instance) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initInterned(internal.system_id);
}

// =============================================================================
// ChildNode Mixin Operations
// =============================================================================

/// Operation: remove (from ChildNode mixin)
pub fn call_remove(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Remove this node from its parent
    return error.NotImplemented;
}

/// Operation: before (from ChildNode mixin)
pub fn call_before(instance: *runtime.Instance, nodes: *const anyopaque) !void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: after (from ChildNode mixin)
pub fn call_after(instance: *runtime.Instance, nodes: *const anyopaque) !void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

/// Operation: replaceWith (from ChildNode mixin)
pub fn call_replaceWith(instance: *runtime.Instance, nodes: *const anyopaque) !void {
    _ = instance;
    _ = nodes;
    return error.NotImplemented;
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Create a DocumentType with the given properties
pub fn createDocumentType(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    name: []const u8,
    public_id: []const u8,
    system_id: []const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &DocumentType.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Set node type to DOCUMENT_TYPE_NODE (10)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.DOCUMENT_TYPE_NODE);

    // Set doctype properties
    internal.name = try allocator.dupe(u8, name);
    internal.public_id = try allocator.dupe(u8, public_id);
    internal.system_id = try allocator.dupe(u8, system_id);

    return instance;
}
