//! Selection Command Integration
//!
//! Provides DOM-integrated implementations of selection-related execCommand
//! operations (selectAll, delete, forwardDelete).
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/
//!
//! ## Architecture Note
//!
//! This module lives in src/html/ (full.zig module) because it needs access to
//! runtime, interfaces, and impls modules. The stub implementations in
//! src/html/editing/selection_ops.zig are used by html_core which doesn't have
//! access to WebIDL modules.
//!
//! When the full html module is used, callers should prefer these implementations
//! which provide actual DOM manipulation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const impls = @import("impls");

/// Result of executing a command (mirrors editing.CommandResult)
pub const CommandResult = struct {
    /// Whether the command was successfully executed
    success: bool,
    /// Error message if command failed
    error_message: ?[]const u8 = null,
};

/// Document handle - can be cast to runtime.Instance when valid
pub const DocumentHandle = *anyopaque;

/// Convert DocumentHandle to runtime.Instance
fn getDocumentInstance(handle: ?DocumentHandle) ?*runtime.Instance {
    const h = handle orelse return null;
    return @ptrCast(@alignCast(h));
}

/// Execute selectAll command with full DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-selectall-command
///
/// Algorithm:
/// 1. Get document's Selection via document.getSelection()
/// 2. Get editing host (document.body for now)
/// 3. Call selection.selectAllChildren(editingHost)
/// 4. Return true (selectAll always succeeds)
pub fn executeSelectAll(allocator: std.mem.Allocator, document: ?DocumentHandle) !CommandResult {
    _ = allocator;

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    // Get document's Selection
    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    // Get editing host (document.body)
    const body_opt = impls.Document.get_body(doc_instance) catch null;
    const editing_host = body_opt orelse {
        return .{ .success = false, .error_message = "No body element" };
    };

    // Call selection.selectAllChildren(editingHost)
    impls.Selection.call_selectAllChildren(selection, editing_host) catch {
        return .{ .success = false, .error_message = "Failed to select all children" };
    };

    return .{ .success = true };
}

/// Execute delete command with full DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-delete-command
///
/// Algorithm:
/// 1. Get current selection
/// 2. If selection is not collapsed: deleteFromDocument()
/// 3. If collapsed: extend backward by one character, then delete
/// 4. Record undo entry
pub fn executeDelete(allocator: std.mem.Allocator, document: ?DocumentHandle) !CommandResult {
    _ = allocator;

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    // Get document's Selection
    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    // Check if selection is collapsed
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;

    if (!is_collapsed) {
        // Selection has content - delete it
        impls.Selection.call_deleteFromDocument(selection) catch {
            return .{ .success = false, .error_message = "Failed to delete selection" };
        };

        // TODO: Record undo entry
        return .{ .success = true };
    }

    // Selection is collapsed (caret) - delete character before caret
    // First, extend selection backward by one character
    impls.Selection.call_modify(
        selection,
        .{ .was_passed = true, .value = runtime.DOMString.initInterned("extend") },
        .{ .was_passed = true, .value = runtime.DOMString.initInterned("backward") },
        .{ .was_passed = true, .value = runtime.DOMString.initInterned("character") },
    ) catch {
        // At start of content, nothing to delete
        return .{ .success = true };
    };

    // Check if we actually extended (not at boundary)
    const still_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (still_collapsed) {
        // Couldn't extend - at start of content
        return .{ .success = true };
    }

    // Now delete the extended selection
    impls.Selection.call_deleteFromDocument(selection) catch {
        return .{ .success = false, .error_message = "Failed to delete character" };
    };

    // TODO: Record undo entry
    return .{ .success = true };
}

/// Execute forwardDelete command with full DOM integration
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-forwarddelete-command
///
/// Algorithm:
/// 1. Get current selection
/// 2. If selection is not collapsed: deleteFromDocument()
/// 3. If collapsed: extend forward by one character, then delete
/// 4. Record undo entry
pub fn executeForwardDelete(allocator: std.mem.Allocator, document: ?DocumentHandle) !CommandResult {
    _ = allocator;

    const doc_instance = getDocumentInstance(document) orelse {
        return .{ .success = false, .error_message = "Invalid document" };
    };

    // Get document's Selection
    const selection_opt = impls.Document.call_getSelection(doc_instance) catch {
        return .{ .success = false, .error_message = "Failed to get selection" };
    };

    const selection = selection_opt orelse {
        return .{ .success = false, .error_message = "No selection available" };
    };

    // Check if selection is collapsed
    const is_collapsed = impls.Selection.get_isCollapsed(selection) catch true;

    if (!is_collapsed) {
        // Selection has content - delete it
        impls.Selection.call_deleteFromDocument(selection) catch {
            return .{ .success = false, .error_message = "Failed to delete selection" };
        };

        // TODO: Record undo entry
        return .{ .success = true };
    }

    // Selection is collapsed (caret) - delete character after caret
    // First, extend selection forward by one character
    impls.Selection.call_modify(
        selection,
        .{ .was_passed = true, .value = runtime.DOMString.initInterned("extend") },
        .{ .was_passed = true, .value = runtime.DOMString.initInterned("forward") },
        .{ .was_passed = true, .value = runtime.DOMString.initInterned("character") },
    ) catch {
        // At end of content, nothing to delete
        return .{ .success = true };
    };

    // Check if we actually extended (not at boundary)
    const still_collapsed = impls.Selection.get_isCollapsed(selection) catch true;
    if (still_collapsed) {
        // Couldn't extend - at end of content
        return .{ .success = true };
    }

    // Now delete the extended selection
    impls.Selection.call_deleteFromDocument(selection) catch {
        return .{ .success = false, .error_message = "Failed to delete character" };
    };

    // TODO: Record undo entry
    return .{ .success = true };
}

test "selection_commands module compiles" {
    try std.testing.expect(true);
}
