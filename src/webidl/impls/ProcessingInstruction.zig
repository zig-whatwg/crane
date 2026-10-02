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
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

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

/// The ProcessingInstructions alive, for the final teardown's sweep.
///
/// A PI still alive when the browser ends is never deinit'd one by one:
/// cleanup sweeps the node registries wholesale (impls/cleanup.zig), and its
/// target - the PI's own, outside those registries - then leaked (17 over
/// dom/ranges/Range-surroundContents.html, the PIs in subtrees nothing tore
/// down). So the PI keeps its own list, taken on init and given up on deinit,
/// and installs a sweep (dom.teardown_sweeps) that frees what is left in it.
/// Keyed by address: the entry goes in the PI's deinit, before the slab can
/// reissue the address.
threadlocal var live: ?std.AutoHashMap(*runtime.Instance, void) = null;
threadlocal var live_guard: @import("webidl").utils.tombstones.TombstoneGuard = .{};

fn trackLive(instance: *runtime.Instance) void {
    if (live == null) live = .init(std.heap.c_allocator);
    const map = &live.?;
    live_guard.beforeInsert(map);
    map.put(instance, {}) catch {};
}

fn untrackLive(instance: *runtime.Instance) void {
    const map = if (live) |*m| m else return;
    if (map.remove(instance)) live_guard.noteRemoval(map);
}

/// dom.teardown_sweeps: free the state of every PI still alive.
fn sweepLive() void {
    const map = if (live) |*m| m else return;
    var it = map.keyIterator();
    while (it.next()) |instance| {
        if (getInternal(instance.*)) |internal| {
            internal.deinit();
            internal.target = "";
        }
    }
    map.deinit();
    live = null;
    live_guard.reset();
}

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    @import("dom").teardown_sweeps.install(&sweepLive);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain through CharacterData -> Node -> EventTarget. Calling
    // runtime.Instance.init directly (the codegen stub) left the node with no
    // CharacterData state, so storing its data threw InvalidStateError and
    // document.createProcessingInstruction() could never return a usable node.
    const instance = try CharacterDataImpl.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize ProcessingInstruction internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;
    trackLive(instance);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    untrackLive(instance);
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // And CharacterData's and Node's teardown: its data, its NodeBase and its
    // registry entries. Stopping here left them behind for every PI torn down,
    // with its tree or when its wrapper was collected.
    interfaces.CharacterData.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// =============================================================================
// Getters - DOM §4.13
// =============================================================================

/// Getter for target
/// DOM §4.13 - Returns this's target.
/// Note: Returns owned DOMString - interface layer will free after V8 conversion.
pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.target);
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
