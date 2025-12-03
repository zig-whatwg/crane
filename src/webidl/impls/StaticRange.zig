//! Implementation for StaticRange interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-staticrange
//! WHATWG DOM Standard §5
//!
//! A StaticRange is a range that does not update when the node tree mutates.
//! This makes it more efficient for one-time range operations.
//! It extends AbstractRange.
//!
//! NOTE: StaticRange has no OWN attributes in WebIDL (inherits all from AbstractRange).
//! However, it still needs internal storage for boundary points since it's a concrete
//! type that can be instantiated. We store boundary points directly in a global
//! hash map keyed by instance pointer since the generated State has no _internal field.
//!
//! Migrated from: webidl/src/dom/StaticRange.zig

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const StaticRange = interfaces.StaticRange;
const AbstractRange = interfaces.AbstractRange;

// Import related impls
const NodeImpl = @import("Node.zig");
const AbstractRangeImpl = @import("AbstractRange.zig");

pub const State = StaticRange.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    InvalidNodeTypeError,
    OutOfMemory,
};

/// Internal state for StaticRange implementation
/// Stores boundary points that don't update when tree mutates
pub const InternalState = struct {
    /// Start boundary point - node
    start_container: ?*runtime.Instance,
    /// Start boundary point - offset
    start_offset: u32,
    /// End boundary point - node
    end_container: ?*runtime.Instance,
    /// End boundary point - offset
    end_offset: u32,

    pub fn init() InternalState {
        return .{
            .start_container = null,
            .start_offset = 0,
            .end_container = null,
            .end_offset = 0,
        };
    }
};

/// Global storage for StaticRange internal state
/// Since StaticRange has no _internal in its generated State, we use this map
var internal_storage: std.AutoHashMap(*runtime.Instance, *InternalState) = undefined;
var storage_initialized: bool = false;

fn ensureStorageInit() void {
    if (!storage_initialized) {
        internal_storage = std.AutoHashMap(*runtime.Instance, *InternalState).init(std.heap.page_allocator);
        storage_initialized = true;
    }
}

/// Get the internal state for an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    ensureStorageInit();
    return internal_storage.get(instance);
}

/// Store internal state for an instance
fn setInternal(instance: *runtime.Instance, internal: *InternalState) !void {
    ensureStorageInit();
    try internal_storage.put(instance, internal);
}

/// Remove internal state for an instance
fn removeInternal(instance: *runtime.Instance) void {
    ensureStorageInit();
    _ = internal_storage.remove(instance);
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

    // Allocate internal state using arena
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init();

    // Store in our global map
    try setInternal(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Remove from our internal storage
    removeInternal(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// DOM §5 - new StaticRange(init)
///
/// Steps:
/// 1. If init["startContainer"] or init["endContainer"] is a DocumentType or Attr node,
///    then throw an "InvalidNodeTypeError" DOMException.
/// 2. Set this's start to (init["startContainer"], init["startOffset"])
///    and end to (init["endContainer"], init["endOffset"]).
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: dictionaries.StaticRangeInit) !*runtime.Instance {
    // Step 1: Check for invalid node types (DocumentType=10, Attr=2)
    // The dictionary contains *const anyopaque which we cast to *runtime.Instance
    // Need @alignCast because anyopaque has alignment 1, Instance has alignment 8
    const start_instance: *runtime.Instance = @ptrCast(@alignCast(@constCast(init_data.startContainer)));
    const end_instance: *runtime.Instance = @ptrCast(@alignCast(@constCast(init_data.endContainer)));

    if (NodeImpl.getNodeType(start_instance)) |nt| {
        if (nt == NodeImpl.NodeType.DOCUMENT_TYPE_NODE or nt == NodeImpl.NodeType.ATTRIBUTE_NODE) {
            return error.InvalidNodeTypeError;
        }
    }

    if (NodeImpl.getNodeType(end_instance)) |nt| {
        if (nt == NodeImpl.NodeType.DOCUMENT_TYPE_NODE or nt == NodeImpl.NodeType.ATTRIBUTE_NODE) {
            return error.InvalidNodeTypeError;
        }
    }

    // Create instance
    const instance = try init(allocator, State, &StaticRange.vtable, ctx);
    errdefer deinit(instance);

    // Step 2: Set start and end boundary points
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.start_container = start_instance;
    internal.start_offset = init_data.startOffset;
    internal.end_container = end_instance;
    internal.end_offset = init_data.endOffset;

    return instance;
}

// =============================================================================
// AbstractRange Getters (inherited - we provide the implementation)
// =============================================================================

/// Getter for startContainer
pub fn get_startContainer(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.start_container orelse return error.InvalidStateError;
}

/// Getter for startOffset
pub fn get_startOffset(instance: *runtime.Instance) !u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.start_offset;
}

/// Getter for endContainer
pub fn get_endContainer(instance: *runtime.Instance) !*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.end_container orelse return error.InvalidStateError;
}

/// Getter for endOffset
pub fn get_endOffset(instance: *runtime.Instance) !u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.end_offset;
}

/// Getter for collapsed
/// Returns true if start and end are at the same position
pub fn get_collapsed(instance: *runtime.Instance) !bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.start_container == internal.end_container and
        internal.start_offset == internal.end_offset;
}

// =============================================================================
// Setters for boundary points (used by Selection and other code)
// =============================================================================

/// Set the start boundary point
pub fn setStart(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.start_container = node;
    internal.start_offset = offset;
}

/// Set the end boundary point
pub fn setEnd(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.end_container = node;
    internal.end_offset = offset;
}
