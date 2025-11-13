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
/// Spec: Text.splitText() steps 6.2-6.5
pub fn updateRangesAfterSplit(document: *Document, node: *Node, new_node: *Node, offset: u32) void {
    document.ranges_mutex.lock();
    defer document.ranges_mutex.unlock();

    for (document.ranges.items) |range| {
        // Step 6.2-6.3: Update start node/offset
        if (range.start_container == node and range.start_offset > offset) {
            range.start_container = new_node;
            range.start_offset -= offset;
        }

        // Step 6.4-6.5: Update end node/offset
        if (range.end_container == node and range.end_offset > offset) {
            range.end_container = new_node;
            range.end_offset -= offset;
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
