//! Text interface per WHATWG DOM Standard
//! Spec: https://dom.spec.whatwg.org/#interface-text

const std = @import("std");
const webidl = @import("webidl");
const CharacterData = @import("character_data").CharacterData;
const ChildNode = @import("child_node").ChildNode;
const NonDocumentTypeChildNode = @import("non_document_type_child_node").NonDocumentTypeChildNode;
const Slottable = @import("slottable").Slottable;
const dom_types = @import("dom_types");

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
        return .{
            .allocator = allocator,
            // TODO: Initialize CharacterData parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *Text) void {
        _ = self;
        // NOTE: Parent CharacterData cleanup is handled by codegen
    }

    /// DOM §4.12 - splitText(offset)
    /// Splits this text node at the given offset and returns the remainder as a new Text node.
    ///
    /// Steps:
    /// 1. Let length be node's length.
    /// 2. If offset is greater than length, throw "IndexSizeError".
    /// 3. Let count be length minus offset.
    /// 4. Let new data be the result of substringing data with node, offset, and count.
    /// 5. Let new node be a new Text node with same node document. Set new node's data to new data.
    /// 6. If parent is not null:
    ///    - Insert new node into parent before node's next sibling
    ///    - Update ranges (TODO)
    /// 7. Replace data with node, offset, count, and empty string.
    /// 8. Return new node.
    pub fn call_splitText(self: *Text, offset: u32) !*Text {
        const length = self.get_length();

        // Step 2: Check bounds
        if (offset > length) {
            return error.IndexSizeError;
        }

        // Step 3: Calculate count
        const count = length - offset;

        // Step 4: Get new data substring
        const new_data = try self.call_substringData(offset, count);

        // Step 5: Create new Text node
        const new_node = try self.allocator.create(Text);
        new_node.* = try Text.init(self.allocator);
        // Set the data by allocating a copy
        self.allocator.free(new_node.data);
        new_node.data = try self.allocator.dupe(u8, new_data);

        // Step 6: Parent handling (simplified - full spec requires tree mutation)
        // TODO: Insert new node into parent before node's next sibling
        // TODO: Update ranges

        // Step 7: Remove the split portion from this node
        try self.call_deleteData(offset, count);

        // Step 8: Return new node
        return new_node;
    }

    /// DOM §4.12 - wholeText getter
    /// Returns the concatenation of the data of all contiguous Text nodes.
    ///
    /// Steps: Return the concatenation of the data of the contiguous Text nodes of this, in tree order.
    pub fn get_wholeText(self: *const Text) ![]const u8 {
        // Simplified implementation - just return this node's data
        // Full implementation would need to:
        // 1. Find all contiguous Text node siblings (previous and next)
        // 2. Concatenate their data in tree order
        //
        // For now, without full tree implementation, just return own data
        // TODO: Implement contiguous Text node traversal
        return self.get_data();
    }
}, .{
    .exposed = &.{.Window},
});
