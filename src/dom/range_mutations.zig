//! Range Mutation Algorithms (WHATWG DOM Standard §4.10)
//!
//! Spec: https://dom.spec.whatwg.org/#interface-range
//!
//! ⚠️ **DEPRECATED:** This module contains a simplified implementation that
//! is superseded by the full spec-compliant implementation in
//! `webidl/src/dom/Range.zig` (lines 443-755).
//!
//! **History:**
//! - Created during initial implementation (commit a0b57d6)
//! - Simplified version that only handles CharacterData nodes
//! - Later replaced by full implementation in Range.zig
//! - Kept for reference but NOT USED in production code
//!
//! **What's Here (Simplified):**
//! - deleteContents() - Remove contents from range (CharacterData only)
//! - extractContents() - Move contents to DocumentFragment (CharacterData only)
//! - cloneContents() - Copy contents to DocumentFragment (CharacterData only)
//!
//! **What's in Range.zig (Production):**
//! - Full spec-compliant implementations
//! - Handles cross-node ranges
//! - Handles partially contained nodes
//! - Handles all node types correctly
//!
//! **Action Items:**
//! - This module should be removed in a future cleanup
//! - All functionality is provided by webidl/src/dom/Range.zig
//! - Export in root.zig can be safely removed

const std = @import("std");

/// Delete contents of a range
/// Spec §4.10 line 5096: "The deleteContents() method steps are to remove
/// all contained children within this from their parents, and then delete data within this."
///
/// Simplified implementation: Handles CharacterData node ranges
pub fn deleteContents(range: anytype) !void {
    // Get boundary points
    const start_container = range.get_startContainer();
    const start_offset = range.get_startOffset();
    const end_container = range.get_endContainer();
    const end_offset = range.get_endOffset();

    // If collapsed, nothing to delete
    if (range.get_collapsed()) {
        return;
    }

    // Simple case: same CharacterData node
    if (start_container == end_container and isCharacterDataNode(start_container)) {
        const char_data = start_container.asCharacterData() orelse return error.InvalidNodeType;

        // Delete the data in range
        const current_data = char_data.get_data();
        const allocator = range.allocator;

        // Build new data: before_range + after_range
        const before = current_data[0..start_offset];
        const after = current_data[end_offset..];

        const new_data = try std.mem.concat(allocator, u8, &[_][]const u8{ before, after });
        defer allocator.free(new_data);

        try char_data.call_setData(new_data);

        // Update range to collapse at deletion point
        try range.call_setStart(start_container, start_offset);
        try range.call_setEnd(start_container, start_offset);

        return;
    }

    // TODO(DOM): Full implementation would handle:
    // - Removing contained children
    // - Partially contained nodes
    // - Cross-node deletion
    // For now, this simplified version handles the most common case
}

/// Extract contents of a range into a DocumentFragment
/// Spec §4.10 lines 5098-5146
///
/// Simplified implementation: Handles CharacterData node ranges
pub fn extractContents(range: anytype) !*@import("document_fragment").DocumentFragment {
    const allocator = range.allocator;
    const DocumentFragment = @import("document_fragment").DocumentFragment;
    const dom = @import("dom");

    // Step 1: Create new DocumentFragment
    const start_container = range.get_startContainer();
    const fragment_ptr = try allocator.create(DocumentFragment);
    errdefer allocator.destroy(fragment_ptr);

    const doc = start_container.node_document orelse return error.NoDocument;
    fragment_ptr.* = try DocumentFragment.init(allocator, doc);

    // Step 2: If collapsed, return empty fragment
    if (range.get_collapsed()) {
        return fragment_ptr;
    }

    const start_offset = range.get_startOffset();
    const end_container = range.get_endContainer();
    const end_offset = range.get_endOffset();

    // Step 4: Simple case - same CharacterData node
    if (start_container == end_container and isCharacterDataNode(start_container)) {
        const char_data = start_container.asCharacterData() orelse return error.InvalidNodeType;

        // Create a Text node with the extracted content
        const current_data = char_data.get_data();
        const extracted = current_data[start_offset..end_offset];

        const text_node_ptr = try allocator.create(@import("dom").NodeBase);
        text_node_ptr.* = try @import("dom").NodeBase.createText(allocator, extracted, doc);

        // Append to fragment
        try dom.mutation.append(text_node_ptr, fragment_ptr.asNode());

        // Remove the data from original
        const before = current_data[0..start_offset];
        const after = current_data[end_offset..];
        const new_data = try std.mem.concat(allocator, u8, &[_][]const u8{ before, after });
        defer allocator.free(new_data);

        try char_data.call_setData(new_data);

        // Update range to collapse at extraction point
        try range.call_setStart(start_container, start_offset);
        try range.call_setEnd(start_container, start_offset);

        return fragment_ptr;
    }

    // TODO(DOM): Full implementation would handle complex cases
    return fragment_ptr;
}

/// Clone contents of a range into a DocumentFragment
/// Spec §4.10 lines 5148-5189
///
/// Simplified implementation: Handles CharacterData node ranges
pub fn cloneContents(range: anytype) !*@import("document_fragment").DocumentFragment {
    const allocator = range.allocator;
    const DocumentFragment = @import("document_fragment").DocumentFragment;
    const dom = @import("dom");

    // Step 1: Create new DocumentFragment
    const start_container = range.get_startContainer();
    const fragment_ptr = try allocator.create(DocumentFragment);
    errdefer allocator.destroy(fragment_ptr);

    const doc = start_container.node_document orelse return error.NoDocument;
    fragment_ptr.* = try DocumentFragment.init(allocator, doc);

    // Step 2: If collapsed, return empty fragment
    if (range.get_collapsed()) {
        return fragment_ptr;
    }

    const start_offset = range.get_startOffset();
    const end_container = range.get_endContainer();
    const end_offset = range.get_endOffset();

    // Step 4: Simple case - same CharacterData node
    if (start_container == end_container and isCharacterDataNode(start_container)) {
        const char_data = start_container.asCharacterData() orelse return error.InvalidNodeType;

        // Create a Text node with the cloned content
        const current_data = char_data.get_data();
        const cloned = current_data[start_offset..end_offset];

        const text_node_ptr = try allocator.create(@import("dom").NodeBase);
        text_node_ptr.* = try @import("dom").NodeBase.createText(allocator, cloned, doc);

        // Append to fragment
        try dom.mutation.append(text_node_ptr, fragment_ptr.asNode());

        // Note: Original data is NOT modified (clone, not extract)

        return fragment_ptr;
    }

    // TODO(DOM): Full implementation would handle complex cases
    return fragment_ptr;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if a node is a CharacterData node (Text, Comment, ProcessingInstruction)
fn isCharacterDataNode(node: anytype) bool {
    const Node = @import("node").Node;
    return node.node_type == Node.TEXT_NODE or
        node.node_type == Node.PROCESSING_INSTRUCTION_NODE or
        node.node_type == Node.COMMENT_NODE;
}
