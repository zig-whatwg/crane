//! Implementation for NodeList interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-nodelist
//! WHATWG DOM Standard §4.2.6
//!
//! A NodeList object is a collection of nodes, usually returned by
//! properties such as Node.childNodes and methods such as
//! document.querySelectorAll().
//!
//! ## Live vs Static Collections
//!
//! Per spec (https://dom.spec.whatwg.org/#concept-collection):
//! - A collection can be either **live** or **static**
//! - If a collection is live, the attributes and methods operate on the
//!   **actual underlying data**, not a snapshot
//! - Node.childNodes returns a **live** NodeList
//! - document.querySelectorAll() returns a **static** NodeList
//!
//! ## [SameObject] Semantics
//!
//! The `childNodes` attribute has [SameObject] extended attribute, meaning
//! the same NodeList object must be returned on every access. This is
//! achieved by caching the NodeList in Node's internal state.
//!
//! ## Implementation
//!
//! Live NodeLists don't store nodes directly. Instead, they store a reference
//! to the root node and query children on-demand. This ensures the collection
//! always reflects the current DOM state without requiring invalidation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const NodeList = interfaces.NodeList;
const node_holds = @import("dom").node_holds;

pub const State = NodeList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Type of live collection filter
pub const LiveCollectionType = enum {
    labels,
    named_controls,
    /// Match all direct children (for Node.childNodes)
    children,
    /// Match elements by tag name (for getElementsByTagName)
    elements_by_tag,
    /// Match elements by class name (for getElementsByClassName)
    elements_by_class,
    /// Match elements by namespace and local name
    elements_by_ns,
};

/// Internal state for NodeList implementation
/// NodeList can be either live (reflecting DOM changes) or static (snapshot)
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// A static list's nodes, which it HOLDS for as long as it lives,
    /// whatever happens to the trees they came from: Blink's StaticNodeList
    /// holds HeapVector<Member<Node>> (core/dom/static_node_list.h), WebKit's
    /// Vector<Ref<Node>>. Native holds, no wrapper per node: the list roots
    /// only the root of a tree holding one of them that is not a document
    /// with a window (src/dom/node_holds.zig). Held as bare pointers, a node
    /// whose detached tree was collected was freed under the list
    /// (crane/ed-static-nodelist-gc.html). Live lists query on demand and
    /// hold nothing here.
    held: node_holds.Holder,

    /// Whether this is a live NodeList (reflects DOM changes) or static
    is_live: bool = false,

    /// For live NodeLists, the root node to query from
    root: ?*runtime.Instance = null,
    labels_root_generation: u64 = 0,
    labels_root_traced: bool = false,
    control_name: ?[]const u8 = null,

    /// Type of live collection (determines what nodes match)
    live_type: LiveCollectionType = .children,

    /// Filter parameters for live collections
    /// For elements_by_tag: the tag name to match
    /// For elements_by_class: the class name to match
    filter_name: ?[]const u8 = null,

    /// Namespace URI for elements_by_ns filter
    filter_namespace: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, list: *runtime.Instance) InternalState {
        return .{
            .allocator = allocator,
            .held = node_holds.Holder.init(allocator, list),
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.held.release();
        if (self.control_name) |name| self.allocator.free(name);
        // Note: filter_name and filter_namespace are slices into
        // other owned memory, don't free them here
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // Other impls fill a static list they created (an element's labels).
    @import("dom").node_lists.install(.{ .set_static = &setStaticNodes, .labels = &makeLabels, .named_controls = &makeNamedControls });
    // A static list holds its nodes; the removing steps rescue a held tree.
    node_holds.installHooks();
}

fn makeNamedControls(list: *runtime.Instance, collection: *runtime.Instance, name: []const u8) !void {
    const internal = getInternal(list) orelse return error.InvalidState;
    internal.control_name = try internal.allocator.dupe(u8, name);
    // The same retained root mechanism serves a collection as a labels target.
    try makeLabels(list, collection);
    internal.live_type = .named_controls;
}

fn namedControlAt(internal: *InternalState, wanted: ?u32, count: *u32) ?*runtime.Instance {
    const collection = internal.root orelse return null;
    if (runtime.SlabAllocator.generationOf(collection) != internal.labels_root_generation or runtime.instance_lifecycle.isCleanedUp(collection)) return null;
    const name = internal.control_name orelse return null;
    const length = interfaces.HTMLCollection.get_length(collection) catch return null;
    var index: u32 = 0;
    while (index < length) : (index += 1) {
        const element = (interfaces.HTMLCollection.call_item(collection, index) catch null) orelse continue;
        if (!@import("html").form_associated.hasControlName(element, name)) continue;
        if (wanted) |target| if (count.* == target) return element;
        count.* += 1;
    }
    return null;
}

fn makeLabels(list: *runtime.Instance, element: *runtime.Instance) !void {
    const internal = getInternal(list) orelse return error.InvalidState;
    internal.is_live = true;
    internal.live_type = .labels;
    internal.root = element;
    internal.labels_root_generation = runtime.SlabAllocator.generationOf(element);
    if (list.ctx.hasEngine()) {
        @import("engine").traceChild(list, element, .{ .name = "labelsTarget" });
        internal.labels_root_traced = true;
    }
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

    // Initialize internal state
    const state = instance.getState(State);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator, instance);
    state.own._internal = internal;

    // Initialize length to 0
    state.own.length = 0;

    return instance;
}

/// dom.node_lists: make an empty list the static list of `nodes`, held.
/// `within`: a node they all descend from, whose root they share.
fn setStaticNodes(list: *runtime.Instance, nodes: []const *runtime.Instance, within: ?*runtime.Instance) anyerror!void {
    clear(list);
    const internal = getInternal(list) orelse return error.InvalidState;
    const root_hint: ?*@import("dom").NodeBase = if (within) |node|
        if (@import("dom").instance_bridge.getNodeBase(@ptrCast(node))) |base| node_holds.hostIncludingRoot(base) else null
    else
        null;
    try internal.held.hold(*runtime.Instance, nodes, root_hint);
    list.getState(State).own.length = @intCast(internal.held.holds.len);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.labels_root_traced) @import("engine").forgetTracedChild(instance, .{ .name = "labelsTarget" });
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for length
/// Spec: https://dom.spec.whatwg.org/#dom-nodelist-length
/// Returns the number of nodes in the collection.
/// For live collections, queries the root node on-demand.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;

    // For live collections, query on-demand
    if (internal.is_live) {
        return getLiveLength(internal);
    }

    // For static collections, the held nodes
    return @intCast(internal.held.holds.len);
}

/// Operation: item(index)
/// Spec: https://dom.spec.whatwg.org/#dom-nodelist-item
/// Returns the node at the given index, or null if out of bounds.
/// For live collections, queries the root node on-demand.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    // For live collections, query on-demand
    if (internal.is_live) {
        return getLiveItem(internal, index);
    }

    // For static collections, the held node; null out of bounds, per spec.
    return internal.held.get(index);
}

// ============================================================================
// Internal helper functions (for DOM implementation)
// ============================================================================

/// Clear all nodes from the list, letting go of its holds.
pub fn clear(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.held.release();

    // Update length in state
    const state = instance.getState(State);
    state.own.length = 0;
}

// ============================================================================
// Live Collection Support
// ============================================================================

/// Create a live NodeList for Node.childNodes
/// This is a live collection that reflects changes to the DOM tree
/// Spec: https://dom.spec.whatwg.org/#concept-collection-live
pub fn createLiveChildNodes(allocator: std.mem.Allocator, ctx: runtime.Context, root: *runtime.Instance) !*runtime.Instance {
    const instance = try init(allocator, State, &NodeList.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidState;

    // Configure as a live collection
    internal.is_live = true;
    internal.root = root;
    internal.live_type = .children;

    return instance;
}

/// Get the length of a live collection by querying the root node
/// For .children type, counts direct children of root
fn getLiveLength(internal: *InternalState) u32 {
    const root = internal.root orelse return 0;

    // Import Node impl to access helper functions
    const NodeImpl = @import("Node.zig");

    switch (internal.live_type) {
        .named_controls => {
            var count: u32 = 0;
            _ = namedControlAt(internal, null, &count);
            return count;
        },
        .labels => {
            if (runtime.SlabAllocator.generationOf(root) != internal.labels_root_generation or runtime.instance_lifecycle.isCleanedUp(root)) return 0;
            const labels = @import("html").form_associated.labelsOf(internal.allocator, root) catch return 0;
            defer internal.allocator.free(labels);
            return @intCast(labels.len);
        },
        .children => {
            // Count direct children using Node's helper
            return NodeImpl.getChildCount(root);
        },
        // Other live collection types can be added here
        else => return 0,
    }
}

/// Get the nth item from a live collection by querying the root node
/// For .children type, returns the nth direct child
fn getLiveItem(internal: *InternalState, index: u32) ?*runtime.Instance {
    const root = internal.root orelse return null;

    // Import Node impl to access helper functions
    const NodeImpl = @import("Node.zig");

    switch (internal.live_type) {
        .named_controls => {
            var count: u32 = 0;
            return namedControlAt(internal, index, &count);
        },
        .labels => {
            if (runtime.SlabAllocator.generationOf(root) != internal.labels_root_generation or runtime.instance_lifecycle.isCleanedUp(root)) return null;
            const labels = @import("html").form_associated.labelsOf(internal.allocator, root) catch return null;
            defer internal.allocator.free(labels);
            return if (index < labels.len) labels[index] else null;
        },
        .children => {
            // Walk children to find the nth one
            var child = NodeImpl.getFirstChild(root);
            var current_index: u32 = 0;

            while (child) |c| {
                if (current_index == index) {
                    return c;
                }
                current_index += 1;
                child = NodeImpl.getNextSibling(c);
            }
            return null;
        },
        // Other live collection types can be added here
        else => return null,
    }
}
