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
//! Live NodeLists query their root on demand. Tree-only filters
//! may reuse an indexed cursor when the node document and its mutation version
//! still match. Association-dependent lists are recomputed on every read.

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
const live_collections = @import("dom").live_collections;

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
    elements_by_name,
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
    root_generation: u64 = 0,
    /// A live list HOLDS its root (refcount design 5h; WebKit's
    /// LiveNodeList keeps `Ref<ContainerNode> m_ownerNode`, its
    /// ChildNodeList `Ref<ContainerNode> m_parent`): one counted reference
    /// for its life, and its wrapper keeps the root's opaque root
    /// (`live_collections.root_slot`). A RadioNodeList's root is a
    /// collection, kept but not counted.
    root_hold: node_holds.MemberHold = .{},
    cache: live_collections.IndexCache = .{},
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

    pub fn deinit(self: *InternalState, list: *runtime.Instance) void {
        self.held.release();
        self.root_hold.release(list, live_collections.root_slot);
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
    @import("dom").node_lists.install(.{ .set_static = &setStaticNodes, .set_static_bases = &setStaticBases, .labels = &makeLabels, .named_controls = &makeNamedControls, .elements_by_name = &makeElementsByName });
    // A static list holds its nodes; the removing steps rescue a held tree.
    node_holds.installHooks();
}

fn makeElementsByName(list: *runtime.Instance, document: *runtime.Instance, name: []const u8) !void {
    const internal = getInternal(list) orelse return error.InvalidState;
    internal.control_name = try internal.allocator.dupe(u8, name);
    internal.is_live = true;
    internal.root = document;
    internal.root_generation = runtime.SlabAllocator.generationOf(document);
    internal.root_hold.take(list, document, live_collections.root_slot);
    internal.live_type = .elements_by_name;
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
    if (runtime.SlabAllocator.generationOf(collection) != internal.root_generation or runtime.instance_lifecycle.isCleanedUp(collection)) return null;
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
    internal.root_generation = runtime.SlabAllocator.generationOf(element);
    internal.root_hold.take(list, element, live_collections.root_slot);
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
    const internal = try runtime.arenaOf(instance).create(InternalState);
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

/// dom.node_lists: `setStaticNodes`, given the tree nodes, all descendants
/// of `within`.
fn setStaticBases(list: *runtime.Instance, nodes: []const *@import("dom").NodeBase, within: *@import("dom").NodeBase) anyerror!void {
    clear(list);
    const internal = getInternal(list) orelse return error.InvalidState;
    try internal.held.hold(*@import("dom").NodeBase, nodes, node_holds.hostIncludingRoot(within));
    list.getState(State).own.length = @intCast(internal.held.holds.len);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // A childNodes list's owner caches it raw: it lets go of it now.
        if (internal.is_live and internal.live_type == .children) {
            if (internal.root_hold.get()) |owner| @import("dom").refcount.childNodesFreed(owner, instance);
        }
        internal.deinit(instance);

        // Return the block itself, not just what it points to.
        // `internal.deinit()` releases the strings and lists the state
        // OWNS; without this the state struct stays allocated for the
        // life of the process - measured at 208 bytes per discarded
        // element across the impls still doing it this way.
        runtime.arenaOf(instance).destroy(InternalState, internal);
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
    internal.root_generation = runtime.SlabAllocator.generationOf(root);
    internal.root_hold.take(instance, root, live_collections.root_slot);
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
        .elements_by_name => {
            if (!prepareCache(internal)) return 0;
            var walk = NameWalk{ .root = root, .name = internal.control_name orelse return 0 };
            const length = internal.cache.count(&walk);
            if (walk.failed) internal.cache = .{};
            return length;
        },
        .named_controls => {
            // Form-owner association needs invalidation beyond tree versions.
            var count: u32 = 0;
            _ = namedControlAt(internal, null, &count);
            return count;
        },
        .labels => {
            // Label association needs invalidation beyond tree versions.
            if (runtime.SlabAllocator.generationOf(root) != internal.root_generation or runtime.instance_lifecycle.isCleanedUp(root)) return 0;
            const labels = @import("html").form_associated.labelsOf(internal.allocator, root) catch return 0;
            defer internal.allocator.free(labels);
            return @intCast(labels.len);
        },
        .children => {
            if (!prepareCache(internal)) return 0;
            if (internal.cache.version != null) {
                var walk = ChildrenWalk{ .root = root };
                return internal.cache.count(&walk);
            }
            // Keep the existing null-version traversal until the counter is wired.
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

    switch (internal.live_type) {
        .elements_by_name => {
            if (!prepareCache(internal)) return null;
            var walk = NameWalk{ .root = root, .name = internal.control_name orelse return null };
            const node = internal.cache.item(&walk, index);
            if (walk.failed) internal.cache = .{};
            return node;
        },
        .named_controls => {
            // Form-owner association needs invalidation beyond tree versions.
            var count: u32 = 0;
            return namedControlAt(internal, index, &count);
        },
        .labels => {
            // Label association needs invalidation beyond tree versions.
            if (runtime.SlabAllocator.generationOf(root) != internal.root_generation or runtime.instance_lifecycle.isCleanedUp(root)) return null;
            const labels = @import("html").form_associated.labelsOf(internal.allocator, root) catch return null;
            defer internal.allocator.free(labels);
            return if (index < labels.len) labels[index] else null;
        },
        .children => {
            if (!prepareCache(internal)) return null;
            if (internal.cache.version != null) {
                var walk = ChildrenWalk{ .root = root };
                return internal.cache.item(&walk, index);
            }
            // Keep the existing null-version traversal until the counter is wired.
            // Walk children to find the nth one
            var child = interfaces.Node.get_firstChild(root) catch null;
            var current_index: u32 = 0;

            while (child) |c| {
                if (current_index == index) {
                    return c;
                }
                current_index += 1;
                child = interfaces.Node.get_nextSibling(c) catch null;
            }
            return null;
        },
        // Other live collection types can be added here
        else => return null,
    }
}

fn prepareCache(internal: *InternalState) bool {
    const root = internal.root orelse return false;
    // Nothing changed since the last full check: one registry read.
    const root_base = internal.root_hold.liveBase();
    if (root_base) |base| if (internal.cache.fresh(base)) return true;
    const link = live_collections.Link{ .instance = root, .generation = internal.root_generation };
    if (link.get() == null) {
        internal.cache = .{};
        return false;
    }
    const document = live_collections.nodeDocument(root);
    const version = if (document) |doc| live_collections.treeVersion(doc) else null;
    _ = internal.cache.begin(link, document, version);
    if (root_base) |base| internal.cache.keyDocument(base);
    return true;
}

const ChildrenWalk = struct {
    root: *runtime.Instance,

    pub fn first(self: *@This()) ?*runtime.Instance {
        return interfaces.Node.get_firstChild(self.root) catch null;
    }
    pub fn next(_: *@This(), node: *runtime.Instance) ?*runtime.Instance {
        return interfaces.Node.get_nextSibling(node) catch null;
    }
};

/// HTML getElementsByName steps: all HTML descendants whose null-namespace
/// name attribute is identical to the query, in tree order. Empty matches a
/// present name="", never a missing name. Blink NameNodeList uses this filter.
const NameWalk = struct {
    root: *runtime.Instance,
    name: []const u8,
    failed: bool = false,

    pub fn first(self: *@This()) ?*runtime.Instance {
        return self.seek(interfaces.Node.get_firstChild(self.root) catch null);
    }
    pub fn next(self: *@This(), node: *runtime.Instance) ?*runtime.Instance {
        return self.seek(self.nextInTree(node));
    }
    fn seek(self: *@This(), start: ?*runtime.Instance) ?*runtime.Instance {
        var current = start;
        while (current) |node| : (current = self.nextInTree(node)) {
            if (self.matches(node) catch {
                self.failed = true;
                return null;
            }) return node;
        }
        return null;
    }
    fn nextInTree(self: *@This(), node: *runtime.Instance) ?*runtime.Instance {
        if (interfaces.Node.get_firstChild(node) catch null) |child| return child;
        var current = node;
        while (current != self.root) {
            if (interfaces.Node.get_nextSibling(current) catch null) |sibling| return sibling;
            current = (interfaces.Node.get_parentNode(current) catch null) orelse return null;
        }
        return null;
    }
    fn matches(self: *@This(), node: *runtime.Instance) !bool {
        if ((try interfaces.Node.get_nodeType(node)) != interfaces.Node.get_ELEMENT_NODE()) return false;
        var namespace = (try interfaces.Element.get_namespaceURI(node)) orelse return false;
        defer namespace.deinit(node.ctx.allocator);
        if (!std.mem.eql(u8, namespace.asSlice(), "http://www.w3.org/1999/xhtml")) return false;
        var value = (try interfaces.Element.call_getAttributeNS(node, null, runtime.DOMString.initInterned("name"))) orelse return false;
        defer value.deinit(node.ctx.allocator);
        return std.mem.eql(u8, value.asSlice(), self.name);
    }
};
