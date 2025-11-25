//! Implementation for CDATASection interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-cdatasection
//! WHATWG DOM Standard §4.12
//!
//! CDATASection extends Text but adds no additional members.
//! It's used to represent CDATA sections in XML documents.
//! Node type is CDATA_SECTION_NODE (4).
//!
//! Migrated from: webidl/src/dom/CDATASection.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CDATASection = interfaces.CDATASection;

// Import related impls
const CharacterDataImpl = @import("CharacterData.zig");
const NodeImpl = @import("Node.zig");

pub const State = CDATASection.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for CDATASection implementation
/// CDATASection has no own attributes - all state is inherited from Text/CharacterData
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // CDATASection has no own state to initialize
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // CDATASection has no own state to clean up
    runtime.Instance.deinit(instance);
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Create a CDATASection with the given data
pub fn createCDATASection(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    data: []const u8,
) !*runtime.Instance {
    const instance = try init(allocator, State, &CDATASection.vtable, ctx);
    errdefer deinit(instance);

    // Set node type to CDATA_SECTION_NODE (4)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.CDATA_SECTION_NODE);

    // Set the data via CharacterData
    try CharacterDataImpl.setData(instance, data);

    return instance;
}
