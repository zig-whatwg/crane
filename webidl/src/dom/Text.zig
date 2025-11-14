//! Text interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-text

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");
const CharacterData = @import("character_data").CharacterData;
const ChildNode = @import("child_node").ChildNode;
const NonDocumentTypeChildNode = @import("non_document_type_child_node").NonDocumentTypeChildNode;
const Slottable = @import("slottable").Slottable;
const dom_types = @import("dom_types");

const Allocator = std.mem.Allocator;
const Node = @import("node").Node;

/// DOM Spec: interface Text : CharacterData
/// Text extends CharacterData (fields/methods inherited)
/// Text must EXPLICITLY include parent mixins (codegen doesn't inherit them)
/// CharacterData includes: ChildNode, NonDocumentTypeChildNode
/// Text also includes: Slottable
pub const Text = webidl.interface(struct {
    pub const extends = CharacterData;
    // CRITICAL: Must explicitly include parent mixins - codegen doesn't inherit them!
    pub const includes = .{ ChildNode, NonDocumentTypeChildNode, Slottable }; // From parent CharacterData + Slottable

    allocator: Allocator,

    pub fn init(allocator: Allocator) !Text {
        // NOTE: Parent CharacterData/Node/EventTarget fields must be initialized here
        return .{
            .event_listener_list = null, // From EventTarget
            .node_type = 3, // TEXT_NODE
            .node_name = "#text",
            .parent_node = null,
            .child_nodes = infra.List(*Node).init(allocator),
            .owner_document = null,
            .registered_observers = infra.List(@import("registered_observer").RegisteredObserver).init(allocator),
            .cloning_steps_hook = null,
            .cached_child_nodes = null,
            .allocator = allocator,
            .data = try allocator.dupe(u8, ""),
            // Slottable mixin fields
            .slottable_name = "",
            .assigned_slot = null,
            .manual_slot_assignment = null,
        };
    }

    pub fn deinit(self: *Text) void {
        _ = self;
        // NOTE: Parent CharacterData cleanup is handled by codegen
    }

    /// DOM §4.12 - splitText(offset)
    /// Splits this text node at the given offset and returns the remainder as a new Text node.
    ///
    /// Spec: To split a Text node with offset:
    /// 1. Let length be node's length.
    /// 2. If offset is greater than length, throw "IndexSizeError".
    /// 3. Let count be length minus offset.
    /// 4. Let new data be the result of substringing data with node, offset, and count.
    /// 5. Let new node be a new Text node with same node document. Set new node's data to new data.
    /// 6. If parent is not null:
    ///    6.1. Insert new node into parent before node's next sibling
    ///    6.2-6.5. Update live ranges (TODO: when Range is implemented)
    /// 7. Replace data with node, offset, count, and empty string.
    /// 8. Return new node.
    pub fn call_splitText(self: *Text, offset: u32) !*Text {
        // Step 1: Let length be node's length
        const length = self.get_length();

        // Step 2: If offset is greater than length, throw "IndexSizeError"
        if (offset > length) {
            return error.IndexSizeError;
        }

        // Step 3: Let count be length minus offset
        const count = length - offset;

        // Step 4: Let new data be the result of substringing data with node, offset, and count
        const new_data = try self.call_substringData(offset, count);

        // Step 5: Let new node be a new Text node with same node document
        // Set new node's data to new data
        const new_node = try self.allocator.create(Text);
        new_node.* = try Text.init(self.allocator);

        // Set owner document
        const self_node: *Node = @ptrCast(self);
        const new_node_as_node: *Node = @ptrCast(new_node);
        new_node_as_node.owner_document = self_node.owner_document;
        new_node_as_node.node_type = Node.TEXT_NODE;

        // Set the data by allocating a copy
        const new_node_as_cd: *CharacterData = @ptrCast(new_node);
        self.allocator.free(new_node_as_cd.data);
        new_node_as_cd.data = try self.allocator.dupe(u8, new_data);

        // Step 6: If parent is not null
        const parent = self_node.parent_node;
        if (parent) |p| {
            // Get node's index in parent (needed for range updates)
            const dom = @import("dom");
            const node_index = dom.tree_helpers.getChildIndex(p, self_node) orelse 0;

            // Step 6.1: Insert new node into parent before node's next sibling
            const mutation = dom.mutation;
            const next_sibling = self_node.get_nextSibling();
            try mutation.insert(new_node_as_node, p, next_sibling, false);

            // Steps 6.2-6.5: Update live ranges
            if (self_node.owner_document) |doc| {
                // owner_document is already *Document, no conversion needed
                const range_tracking = @import("range_tracking");
                range_tracking.updateRangesAfterSplit(doc, self_node, new_node_as_node, offset, p, @intCast(node_index));
            }
        }

        // Step 7: Replace data with node, offset, count, and empty string
        try self.call_deleteData(offset, count);

        // Step 8: Return new node
        return new_node;
    }

    /// DOM §4.12 - wholeText getter
    /// Returns the concatenation of the data of all contiguous Text nodes.
    ///
    /// Steps: Return the concatenation of the data of the contiguous Text nodes of this, in tree order.
    pub fn get_wholeText(self: *const Text) ![]const u8 {
        const dom = @import("dom");
        var result = infra.List(u8).init(self.allocator);
        errdefer result.deinit();

        // Collect all contiguous Text nodes in tree order
        // Start from the first contiguous Text node (walk backward to find start)
        var first = &self.base.base;
        while (dom.tree_helpers.getPreviousSibling(first)) |prev| {
            if (prev.node_type != Node.TEXT_NODE) break;
            first = prev;
        }

        // Walk forward from first, collecting data
        var current: ?*Node = first;
        while (current) |node| {
            if (node.node_type == Node.TEXT_NODE) {
                const textNode = node.asText() orelse return error.InvalidNodeTypeError;
                try result.appendSlice(textNode.base.get_data());
                current = dom.tree_helpers.getNextSibling(node);
            } else {
                break;
            }
        }

        return result.toOwnedSlice();
    }
}, .{
    .exposed = &.{.Window},
});
