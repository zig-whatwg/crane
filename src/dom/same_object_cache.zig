//! The generated [SameObject] caches' edges (binding3 item 9h).
//!
//! A generated [SameObject] getter caches the child its impl made in the
//! owner's generated state (`cached_<name>`), as a bare pointer. Whoever
//! wraps the child owns it: the wrapper cache frees it once its wrapper is
//! collected. A script read wraps it, and the binding ties its wrapper to the
//! owner's (interface.zig `recordSameObjectEdge`). A native read -
//! `interfaces.SVGAElement.get_href` from an extract-an-origin step - made a
//! child that nothing wrapped and nothing freed: an SVGAnimatedString, its
//! attribute name and its namespace per element (Codex row 45 Q14).
//!
//! So the getter traces the child it caches from its owner, whoever reads it
//! first (`made`): engine.traceChild makes the child's wrapper in its relevant
//! realm, which then owns the child, and keeps it for exactly as long as the
//! owner's wrapper lives - or holds it until the owner gets one. That is what
//! a script read leaves, so a native read and a script read leave one state.
//! Blink keeps the same object the same way: the owner's `Trace` visits the
//! child's `Member<>` (Element::Trace visits its ElementRareData, whose
//! class_list_, dataset_ and attribute_map_ are traced members).
//!
//! The owner's destruction chain ends an edge still waiting for the owner's
//! wrapper (`end`): engine.forgetTracedChild, which an owner that can be
//! freed unwrapped calls from its teardown. The edge of an owner that has a
//! wrapper dies with the wrapper.
//!
//! The slot is the attribute's, in a namespace of its own ("SameObject:"),
//! apart from the slots impls trace their own children in.
//!
//! An ELEMENT's family-wide caches (classList, part, children, dataset,
//! attributeStyleMap, SVG's and MathML's style, SVG's className) are not in
//! its generated State but in its sparse rare block (lane cg1, N1;
//! dom.node_rare_data, lane rare1): `elementGet` / `elementReserve` /
//! `elementMade`, and `endElement` in the destruction chain. A div paid 56
//! bytes for 7 pointers that are null on nearly every element; the block
//! costs nothing until one is read, and 16 bytes for the first. classList is
//! bit 0, read with no popcount. Blink keeps the same objects in its
//! ElementRareDataVector (Element::classList() -> EnsureElementRareData()
//! .GetClassList / SetClassList; kDataset, kPart, kCssomMapWrapper) and the
//! children collection in NodeListsNodeData. The codegen decides which
//! caches go where (writer.zig `sameObjectPlace`). Identity is unchanged: a
//! field, once set, is never cleared while its element lives.
//!
//! A NODE's childNodes list is in the same block, for any node (lane nm2:
//! the block's word is the node's NodeBase's, and Node's State carried 8
//! bytes for the list on every node): `nodeGet` / `nodeReserve` /
//! `nodeMade` / `endNode`, which find the holder from the node's NodeBase,
//! not through Element's hook. Its slot IS cleared when the list is freed
//! before its node (the list holds the node, never the reverse:
//! dom.refcount's childNodesFreed): the next read makes a new list, as
//! Blink's and WebKit's NodeListsNodeData drop a collected child node list.
const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");
const node_rare_data = @import("node_rare_data.zig");
const instance_bridge = @import("instance_bridge.zig");

/// The traced slot of the [SameObject] attribute whose cache is
/// `cached_<attribute>`.
fn slotOf(comptime attribute: []const u8) engine.TracedSlot {
    return .{ .name = "SameObject:" ++ attribute };
}

/// `child` was just made for `owner`'s [SameObject] `attribute` and cached:
/// `owner` keeps it, as a script read would have it kept.
pub fn made(owner: *runtime.Instance, child: *runtime.Instance, comptime attribute: []const u8) void {
    engine.traceChild(owner, child, slotOf(attribute));
}

/// `owner` no longer keeps the child of its [SameObject] `attribute` that
/// `made` traced: end the edge, or the one waiting for `owner`'s wrapper -
/// for an impl that keeps the object itself (Element's NamedNodeMap) and
/// ends it in its teardown, as `end` does for a State's caches. Never makes
/// a wrapper.
pub fn forget(owner: *runtime.Instance, comptime attribute: []const u8) void {
    engine.forgetTracedChild(owner, slotOf(attribute));
}

/// `owner`'s destruction chain is at `State`'s level: end the edge each of
/// that level's cached children may still wait on (an owner freed before it
/// was ever wrapped). Never makes a wrapper; safe in any teardown, the
/// collector's included (engine.forgetTracedChild).
pub fn end(comptime State: type, owner: *runtime.Instance) void {
    const own = &owner.getState(State).own;
    inline for (comptime std.meta.fieldNames(@TypeOf(own.*)), comptime std.meta.fieldTypes(@TypeOf(own.*))) |field_name, field_type| {
        if (comptime std.mem.startsWith(u8, field_name, "cached_") and field_type == ?*runtime.Instance) {
            if (@field(own, field_name) != null) engine.forgetTracedChild(owner, slotOf(field_name["cached_".len..]));
        }
    }
}

// ============================================================================
// An element's caches: in its rare data
// ============================================================================

/// The child `owner`, an element, keeps in its rare data's `field`, or null
/// before it made one. The generated getter's hit: the element's holder,
/// then the field's slot (bit 0 needs no popcount). Never allocates.
pub inline fn elementGet(owner: *runtime.Instance, comptime field: node_rare_data.Field) ?*runtime.Instance {
    comptime std.debug.assert(node_rare_data.Value(field) == *runtime.Instance);
    return node_rare_data.get(node_rare_data.of(owner), field);
}

/// Give `field` its bit in `owner`'s rare data before the child is made, so
/// that keeping it after (`elementMade`) cannot fail: a child must not exist
/// unless it can be kept. InvalidStateError for an instance that is no
/// element.
pub fn elementReserve(owner: *runtime.Instance, comptime field: node_rare_data.Field) error{ OutOfMemory, InvalidStateError }!void {
    const access = node_rare_data.access(owner) orelse return error.InvalidStateError;
    try node_rare_data.reserve(node_rare_data.contextOf(owner), access.holder, field);
}

/// `child` was just made for `owner`'s [SameObject] `attribute`, whose
/// `field` `elementReserve` gave its bit: the element keeps it there, in
/// place (the holder is read now - making the child may have moved the
/// block), and traces it as `made` does. Never allocates.
pub fn elementMade(owner: *runtime.Instance, comptime field: node_rare_data.Field, child: *runtime.Instance, comptime attribute: []const u8) void {
    const access = node_rare_data.access(owner).?;
    node_rare_data.putReserved(access.holder, field, child);
    made(owner, child, attribute);
}

/// One rare-data cache of a level: its field and its attribute (the slot of
/// its edge).
pub const ElementCache = struct {
    field: node_rare_data.Field,
    attribute: []const u8,
};

/// `owner`'s destruction chain is at a level whose caches are `caches`, in
/// its rare data: end the edge each cached child may still wait on, as `end`
/// does for a State's. Runs before Element's teardown frees the block (the
/// chain runs a level before its parent's). The slots are left: the block
/// goes with the element. Never makes a wrapper.
pub fn endElement(owner: *runtime.Instance, comptime caches: []const ElementCache) void {
    const holder = node_rare_data.of(owner);
    if (holder.block == null) return;
    inline for (caches) |cache| {
        if (node_rare_data.get(holder, cache.field) != null) engine.forgetTracedChild(owner, slotOf(cache.attribute));
    }
}

// ============================================================================
// A node's caches: in its rare data, whatever kind of node it is
// ============================================================================

/// The child `owner`, a node, keeps in its rare data's `field`, or null
/// before it made one - and for an instance that is no live node. The
/// generated getter's hit. Never allocates.
pub inline fn nodeGet(owner: *runtime.Instance, comptime field: node_rare_data.Field) ?*runtime.Instance {
    comptime std.debug.assert(node_rare_data.Value(field) == *runtime.Instance);
    const node = instance_bridge.getNodeBase(owner) orelse return null;
    return node_rare_data.get(node.rare, field);
}

/// Give `field` its bit in `owner`'s rare data before the child is made, so
/// that keeping it after (`nodeMade`) cannot fail. InvalidStateError for an
/// instance that is no live node.
pub fn nodeReserve(owner: *runtime.Instance, comptime field: node_rare_data.Field) error{ OutOfMemory, InvalidStateError }!void {
    const node = instance_bridge.getNodeBase(owner) orelse return error.InvalidStateError;
    try node_rare_data.reserve(node.rareContext(), &node.rare, field);
}

/// `child` was just made for `owner`'s [SameObject] `attribute`, whose
/// `field` `nodeReserve` gave its bit: the node keeps it there, in place
/// (the holder is read now - making the child may have moved the block), and
/// traces it as `made` does. Never allocates.
pub fn nodeMade(owner: *runtime.Instance, comptime field: node_rare_data.Field, child: *runtime.Instance, comptime attribute: []const u8) void {
    const node = instance_bridge.getNodeBase(owner).?;
    node_rare_data.putReserved(&node.rare, field, child);
    made(owner, child, attribute);
}

/// `owner`'s destruction chain is at Node's level, whose caches `caches` are
/// in its rare data: end the edge each cached child may still wait on, as
/// `end` does for a State's. Runs before Node's teardown frees the block.
/// Never makes a wrapper.
pub fn endNode(owner: *runtime.Instance, comptime caches: []const ElementCache) void {
    const node = instance_bridge.getNodeBase(owner) orelse return;
    if (node.rare.block == null) return;
    inline for (caches) |cache| {
        if (node_rare_data.get(node.rare, cache.field) != null) engine.forgetTracedChild(owner, slotOf(cache.attribute));
    }
}
