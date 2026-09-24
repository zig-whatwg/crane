//! Implementation for DocumentFragment interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-documentfragment
//! WHATWG DOM Standard §4.8
//!
//! DocumentFragment is a lightweight container for DOM nodes.
//! It's commonly used to build up DOM structures before inserting them.
//!
//! Migrated from: webidl/src/dom/DocumentFragment.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DocumentFragment = interfaces.DocumentFragment;

// Import related impls
const NodeImpl = @import("Node.zig");

// Import mixins for shared interface methods
const mixins = @import("mixins");

pub const State = DocumentFragment.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
    SyntaxError,
};

/// Internal state for DocumentFragment implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Host element for shadow roots (null for regular document fragments)
    /// Per DOM spec: A shadow root's host is always non-null
    host: ?*runtime.Instance,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .host = null,
        };
    }

    pub fn deinit(self: *InternalState) void {
        _ = self;
    }
};

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;
const Registry = utils.InstanceRegistry(InternalState);

/// Public function to get internal state (for other impls that need it)
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// Initialize instance (creates the instance)
/// Chains to NodeImpl.init() to properly initialize the inheritance chain.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to Node's init which chains to EventTarget
    // This properly initializes the entire inheritance chain
    const instance = try NodeImpl.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const ArenaAllocator = @import("runtime").ArenaAllocator;

    // Set the node type for this DocumentFragment
    if (NodeImpl.getInternalState(instance)) |node_internal| {
        node_internal.node_type = NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE;
        // CRITICAL: Also set the NodeBase's node_type for DOM algorithms
        // that read directly from NodeBase (e.g., mutation.zig's isConnectedThroughShadow)
        if (node_internal.node_base) |node_base| {
            node_base.node_type = NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE;
        }
    }

    // Initialize DocumentFragment's own internal state and register it
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = InternalState.init(allocator);

    return instance;
}

/// Get the Node internal state from a DocumentFragment instance
pub fn getNodeInternal(instance: *runtime.Instance) ?*NodeImpl.InternalState {
    return NodeImpl.getInternalState(instance);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Get internal state from registry (where it was stored in init)
    if (Registry.get(instance)) |internal| {
        internal.deinit();
        // Remove from registry to prevent double-free
        Registry.remove(instance);
    }
    // Node cleanup happens via inheritance chain
    NodeImpl.deinit(instance);
}

/// Constructor implementation
/// DOM §4.8 - DocumentFragment()
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &DocumentFragment.vtable, ctx);
    errdefer deinit(instance);

    // Set node type to DOCUMENT_FRAGMENT_NODE (11)
    try NodeImpl.setNodeType(instance, NodeImpl.NodeType.DOCUMENT_FRAGMENT_NODE);

    return instance;
}

// =============================================================================
// ParentNode Mixin Getters
// =============================================================================

// =============================================================================
// ParentNode Mixin Operations
// =============================================================================

// =============================================================================
// NonElementParentNode Mixin Operations
// =============================================================================

/// Clean up ALL remaining internal states.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}
