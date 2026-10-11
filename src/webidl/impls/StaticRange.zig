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
const range_boundaries = @import("dom").range_boundaries;
const same_object = @import("same_object.zig");

// Import related impls
const NodeImpl = @import("Node.zig");

pub const State = StaticRange.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    InvalidNodeTypeError,
    OutOfMemory,
};

/// Internal state for StaticRange implementation
/// Stores boundary points that don't update when tree mutates
///
/// The range keeps both containers for as long as it lives: Blink's
/// StaticRange traces Member<Node> start_container_ and end_container_
/// (third_party/blink/renderer/core/dom/static_range.h), WebKit's holds
/// Ref<Node>. As bare pointers, a container script let go was freed by the
/// next collection and the range answered from its freed slot
/// (crane/ed-static-range-gc.html). Each is an edge from the range's wrapper
/// - waiting, held strongly, while a constructor's range has none yet
/// (engine.traceChild).
pub const InternalState = struct {
    /// Start boundary point - node
    start_container: ?*runtime.Instance,
    /// Start boundary point - offset
    start_offset: u32,
    /// End boundary point - node
    end_container: ?*runtime.Instance,
    /// End boundary point - offset
    end_offset: u32,
    /// The edges that keep the two containers.
    kept_start: same_object.Traced = .{ .slot = .{ .name = "startContainer" } },
    kept_end: same_object.Traced = .{ .slot = .{ .name = "endContainer" } },

    pub fn init() InternalState {
        return .{
            .start_container = null,
            .start_offset = 0,
            .end_container = null,
            .end_offset = 0,
        };
    }
};

/// StaticRange's state, in its Browser's side table (instances B1): StaticRange
/// has no _internal in its generated State.
const Registry = runtime.InstanceRegistry(.static_ranges, InternalState);

/// Get the internal state for an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// This kind of range's answer to AbstractRange's boundary-point getters.
fn boundariesOf(range: *runtime.Instance) ?range_boundaries.Boundaries {
    if (range.stateAs(State) == null) return null;
    const internal = getInternal(range) orelse return null;
    return .{
        .start_container = internal.start_container orelse return null,
        .start_offset = internal.start_offset,
        .end_container = internal.end_container orelse return null,
        .end_offset = internal.end_offset,
    };
}

/// Remove internal state for an instance, returning its block to the arena.
fn removeInternal(instance: *runtime.Instance) void {
    if (Registry.get(instance)) |internal| {
        // A range freed unwrapped (a failed construction) lets the edges
        // waiting for its wrapper go; a collected one's went with it.
        internal.kept_start.release(instance);
        internal.kept_end.release(instance);
    }
    Registry.remove(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    range_boundaries.install(&boundariesOf);
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

    // Internal state, from its Browser's arena, in its Browser's table.
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = InternalState.init();

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
pub fn call_constructor(ctx: runtime.Context, init_data: dictionaries.StaticRangeInit) !*runtime.Instance {
    // Step 1: Check for invalid node types (DocumentType=10, Attr=2)
    // The dictionary's Node members arrive converted, as Instances.
    const start_instance: *runtime.Instance = init_data.startContainer;
    const end_instance: *runtime.Instance = init_data.endContainer;

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
    const instance = try init(ctx.allocator, State, &StaticRange.vtable, ctx);
    errdefer deinit(instance);

    // Step 2: Set start and end boundary points
    try setStart(instance, start_instance, init_data.startOffset);
    try setEnd(instance, end_instance, init_data.endOffset);

    return instance;
}

// =============================================================================
// Setters for boundary points (used by Selection and other code)
// =============================================================================

/// Set the start boundary point; the range keeps its container.
pub fn setStart(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.start_container = node;
    internal.start_offset = offset;
    internal.kept_start.hold(instance, node);
}

/// Set the end boundary point; the range keeps its container.
pub fn setEnd(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.end_container = node;
    internal.end_offset = offset;
    internal.kept_end.hold(instance, node);
}
