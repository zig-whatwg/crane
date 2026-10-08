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
const dom = @import("dom");
const engine = @import("engine");

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

    /// The template that owns this fragment, null for ordinary fragments.
    /// ShadowRoot exposes its own host through the ShadowRoot interface.
    host: ?*runtime.Instance,
    host_generation: u64 = 0,

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

pub fn installHooks() void {
    dom.template_contents.install(.{ .set_host = &setTemplateHost, .host = &templateHost, .clear_host = &clearTemplateHost });
}

/// The template whose contents this fragment is: a native pointer, checked by
/// generation on every read (`templateHost`). No edge is traced to the
/// template's wrapper: that made a wrapper for a template script had not seen
/// yet - from then on the collector's to free with it - and a constructor
/// binding the template to NewTarget's object would replace that wrapper
/// (PR-M1). The template owns the fragment natively instead
/// (`dom.template_contents.ownedByLiveTemplate`).
fn setTemplateHost(fragment: *runtime.Instance, host: *runtime.Instance) !void {
    const internal = Registry.get(fragment) orelse return error.InvalidStateError;
    internal.host = host;
    internal.host_generation = runtime.SlabAllocator.generationOf(host);
}

fn clearTemplateHost(fragment: *runtime.Instance) void {
    const internal = Registry.get(fragment) orelse return;
    internal.host = null;
    internal.host_generation = 0;
}

fn templateHost(fragment: *runtime.Instance) ?*runtime.Instance {
    const internal = Registry.get(fragment) orelse return null;
    const host = internal.host orelse return null;
    return if (runtime.SlabAllocator.generationOf(host) == internal.host_generation) host else null;
}

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
    const instance = try interfaces.Node.initWithState(allocator, StateType, vtable, ctx);
    errdefer interfaces.Node.deinit(instance);

    const ArenaAllocator = @import("runtime").ArenaAllocator;

    // Set the node type for this DocumentFragment
    try dom.node_creation.setType(instance, interfaces.Node.get_DOCUMENT_FRAGMENT_NODE());

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
        engine.forgetTracedChild(instance, .{ .name = "template owner document" });
        internal.deinit();
        // Remove from registry to prevent double-free
        Registry.remove(instance);
    }
    // Node cleanup happens via inheritance chain
    interfaces.Node.deinit(instance);
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
