//! Per-document range tracking for live range updates
//! Spec: https://dom.spec.whatwg.org/#concept-live-range
//!
//! This module provides infrastructure for tracking live ranges per-document
//! and updating them when DOM mutations occur.

const std = @import("std");
const Range = @import("range").Range;
const Node = @import("node").Node;
const Document = @import("document").Document;

/// Update ranges after text node split
/// Spec: Text.splitText() steps 6.2-6.5 (DOM Standard §4.9)
/// Also needs parent node index for steps 6.4-6.5
pub fn updateRangesAfterSplit(document: *Document, node: *Node, new_node: *Node, offset: u32, parent: *Node, node_index: u32) void {
    document.ranges_mutex.lock();
    defer document.ranges_mutex.unlock();

    for (document.ranges.items) |range| {
        // Step 6.2: For each live range whose start node is node and start offset > offset,
        // set its start node to new_node and decrease its start offset by offset
        if (range.start_container == node and range.start_offset > offset) {
            range.start_container = new_node;
            range.start_offset -= offset;
        }

        // Step 6.3: For each live range whose end node is node and end offset > offset,
        // set its end node to new_node and decrease its end offset by offset
        if (range.end_container == node and range.end_offset > offset) {
            range.end_container = new_node;
            range.end_offset -= offset;
        }

        // Step 6.4: For each live range whose start node is parent and start offset
        // is equal to the index of node + 1, increase its start offset by 1
        if (range.start_container == parent and range.start_offset == node_index + 1) {
            range.start_offset += 1;
        }

        // Step 6.5: For each live range whose end node is parent and end offset
        // is equal to the index of node + 1, increase its end offset by 1
        if (range.end_container == parent and range.end_offset == node_index + 1) {
            range.end_offset += 1;
        }
    }
}

/// Update ranges after character data replacement
/// Spec: CharacterData.replaceData() steps 8-11
pub fn updateRangesAfterReplace(document: *Document, node: *Node, offset: u32, count: u32, new_length: u32) void {
    document.ranges_mutex.lock();
    defer document.ranges_mutex.unlock();

    for (document.ranges.items) |range| {
        // Step 8-9: Update ranges whose start container is node
        if (range.start_container == node) {
            if (range.start_offset > offset and range.start_offset <= offset + count) {
                // Start offset is within replaced range
                range.start_offset = offset;
            } else if (range.start_offset > offset + count) {
                // Start offset is after replaced range
                range.start_offset = range.start_offset - count + new_length;
            }
        }

        // Step 10-11: Update ranges whose end container is node
        if (range.end_container == node) {
            if (range.end_offset > offset and range.end_offset <= offset + count) {
                // End offset is within replaced range
                range.end_offset = offset;
            } else if (range.end_offset > offset + count) {
                // End offset is after replaced range
                range.end_offset = range.end_offset - count + new_length;
            }
        }
    }
}
