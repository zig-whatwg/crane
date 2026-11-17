//! Node's childNodes list is kept in the node's rare block (lane nm2 batch 2,
//! step a; node-memory plan v2 section 6 item 5, lane nm1's queue 2a).
//!
//! Every node's generated State carried `cached_childNodes`, 8 bytes for a
//! [SameObject] NodeList that most nodes never hand out - a Text, a Comment
//! and a childless element included. It is a field of the node's ONE sparse
//! rare block now (dom.node_rare_data's `child_nodes`; the block's word is
//! NodeBase's since this batch's step b), read and kept by the generated
//! getter through dom.same_object_cache's node accessors. Blink keeps the
//! list in the node's rare data (Node::childNodes() ->
//! EnsureRareData().EnsureNodeLists().EnsureChildNodeList, core/dom/node.cc
//! and node_lists_node_data.h at chromium 44274363dc1a), WebKit too
//! (ContainerNode::childNodes -> ensureRareData().ensureNodeLists()
//! .ensureChildNodeList, Source/WebCore/dom/ContainerNode.cpp).
//!
//! - A node whose childNodes was never read has no block; the first read
//!   costs a 16-byte block (one slot).
//! - [SameObject]: the same list every read, on an element, a Text and a
//!   Document alike, and beside an element's own rare fields.
//! - The node's cache is raw (the list holds the node, never the reverse):
//!   when the list is freed before its node the slot is cleared and the next
//!   read makes a new list (dom.refcount's childNodesFreed).
//!
//! The State's size is pinned in node_block_sizes_test.zig; the codegen's
//! output in tests/codegen/cg1_element_same_object_test.zig. Here, what the
//! State and the block's field are, at comptime. The run-time tests - the
//! list read on an element, a Text and a Document, freed before its node,
//! beside an element's own rare fields - are in
//! tests/html/nm2_child_nodes_rare_test.zig (lane mp1): the list is its
//! wrapper's to free, tests/dom's realm has no engine, and the tests freed
//! each list by hand. These name generated interfaces and src/dom types
//! only.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const rare_data = dom.node_rare_data;

/// Whether this build keeps the list in the rare block.
const in_rare = @hasField(rare_data.Field, "child_nodes");

test "Node's State keeps no childNodes cache: it is a field of the node's rare block" {
    if (comptime !in_rare) return error.ChildNodesNotInRareData;
    try testing.expect(!@hasField(@FieldType(interfaces.Node.State, "own"), "cached_childNodes"));
    try testing.expect(rare_data.Value(.child_nodes) == *runtime.Instance);
}
