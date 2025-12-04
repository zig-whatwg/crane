//! Selection and Clipboard Operations
//!
//! Implements selection and clipboard execCommand operations:
//! - Selection commands (selectAll, delete, forwardDelete)
//! - Clipboard commands (copy, cut, paste)
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/
//! Clipboard: https://w3c.github.io/clipboard-apis/
//!
//! These commands require integration with:
//! - Selection API for selection manipulation
//! - Clipboard API for clipboard access (via pluggable ClipboardBackend)
//! - DOM for content modification
//!
//! Note: This module is part of html_core and does NOT have access to runtime/impls.
//! Full DOM integration happens via the html module (full.zig) which has access to
//! both html_core and the webidl modules.

const std = @import("std");
const commands = @import("commands.zig");
const executor = @import("executor.zig");
const platform = @import("platform");

pub const Command = commands.Command;
pub const CommandResult = executor.CommandResult;
pub const DocumentHandle = executor.DocumentHandle;

// Re-export clipboard types for convenience
pub const ClipboardBackend = platform.ClipboardBackend;
pub const ClipboardResult = platform.ClipboardResult;
pub const ClipboardFormat = platform.ClipboardFormat;
pub const ClipboardItem = platform.ClipboardItem;

// =============================================================================
// Selection Commands
// =============================================================================

/// Execute selectAll command
/// Selects all content in the editable area
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-selectall-command
///
/// Algorithm:
/// 1. Let editing host be the nearest editing host of the active range's
///    start node (or document.body if in designMode)
/// 2. Get document's Selection via document.getSelection()
/// 3. Call selection.selectAllChildren(editingHost)
/// 4. Return true (selectAll always succeeds)
///
/// Note: selectAll does NOT create an undo entry as it doesn't modify content.
///
/// TODO: Full implementation requires DOM integration via html module (full.zig)
/// which has access to runtime.Instance and impls.Selection.
pub fn executeSelectAll(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get document instance from handle
    // 2. Call document.getSelection() to get Selection object
    // 3. Get editing host (document.body or contenteditable ancestor)
    // 4. Call selection.selectAllChildren(editingHost)

    return .{ .success = true };
}

/// Execute delete command
/// Deletes selection or character before caret (backspace behavior)
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-delete-command
///
/// Algorithm:
/// 1. Get current selection
/// 2. If selection is not collapsed:
///    a. Call selection.deleteFromDocument()
/// 3. If selection is collapsed (caret):
///    a. Let range = selection.getRangeAt(0)
///    b. If at start of container, merge with previous sibling/parent
///    c. Otherwise, extend range backward by one grapheme cluster
///    d. Delete the range contents
/// 4. Handle special cases:
///    - Empty list items: remove the <li>
///    - Empty block elements: merge with previous block
///    - Tables: don't delete across cell boundaries
/// 5. Create undo entry
///
/// TODO: Full implementation requires DOM integration via html module (full.zig)
/// which has access to runtime.Instance and impls.Selection.
pub fn executeDelete(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get document instance from handle
    // 2. Call document.getSelection() to get Selection object
    // 3. If selection.isCollapsed:
    //    a. Call selection.modify("extend", "backward", "character")
    // 4. Call selection.deleteFromDocument()
    // 5. Record undo entry

    return .{ .success = true };
}

/// Execute forwardDelete command
/// Deletes selection or character after caret (delete key behavior)
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-forwarddelete-command
///
/// Algorithm:
/// 1. Get current selection
/// 2. If selection is not collapsed:
///    a. Call selection.deleteFromDocument()
/// 3. If selection is collapsed (caret):
///    a. Let range = selection.getRangeAt(0)
///    b. If at end of container, merge with next sibling/child
///    c. Otherwise, extend range forward by one grapheme cluster
///    d. Delete the range contents
/// 4. Handle special cases:
///    - At end of list item: merge with next item
///    - At end of block: merge with next block
///    - Tables: don't delete across cell boundaries
/// 5. Create undo entry
///
/// TODO: Full implementation requires DOM integration via html module (full.zig)
/// which has access to runtime.Instance and impls.Selection.
pub fn executeForwardDelete(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;

    // Algorithm when integrated with DOM:
    // 1. Get document instance from handle
    // 2. Call document.getSelection() to get Selection object
    // 3. If selection.isCollapsed:
    //    a. Call selection.modify("extend", "forward", "character")
    // 4. Call selection.deleteFromDocument()
    // 5. Record undo entry

    return .{ .success = true };
}

// =============================================================================
// Clipboard Commands
// =============================================================================

/// Execute copy command using the clipboard backend
/// Copies selection to clipboard
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-copy-command
/// Clipboard API: https://w3c.github.io/clipboard-apis/#copy-action
///
/// Algorithm:
/// 1. Check if clipboard write is permitted
/// 2. Get current selection
/// 3. If selection is collapsed (no content selected):
///    a. Return false (nothing to copy)
/// 4. Get selected content in multiple formats:
///    a. text/plain: selection.toString()
///    b. text/html: serialize selection range to HTML
/// 5. Write to clipboard via backend
/// 6. Return true
///
/// Note: copy does NOT create an undo entry as it doesn't modify content.
pub fn executeCopy(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    clipboard: ClipboardBackend,
) !CommandResult {
    // Check permission
    if (!clipboard.canWrite()) {
        return .{ .success = false };
    }

    // Get selection text and HTML
    // TODO: Integrate with Selection API when available
    const selection_text = getSelectionText(allocator, document);
    const selection_html = getSelectionHtml(allocator, document);

    // If no selection, nothing to copy
    if (selection_text == null and selection_html == null) {
        return .{ .success = false };
    }

    // Write to clipboard
    if (selection_html) |html| {
        const result = clipboard.writeHtml(html, selection_text);
        if (selection_text) |text| allocator.free(text);
        allocator.free(html);
        return .{ .success = result == .success };
    } else if (selection_text) |text| {
        const result = clipboard.writeText(text);
        allocator.free(text);
        return .{ .success = result == .success };
    }

    return .{ .success = false };
}

/// Execute cut command using the clipboard backend
/// Cuts selection to clipboard
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-cut-command
/// Clipboard API: https://w3c.github.io/clipboard-apis/#cut-action
///
/// Algorithm:
/// 1. Execute copy command first
/// 2. If copy failed (e.g., selection collapsed):
///    a. Return false
/// 3. If copy succeeded:
///    a. Call selection.deleteFromDocument()
///    b. Create undo entry with deleted content
/// 4. Return true
///
/// Note: cut DOES create an undo entry (unlike copy) because it modifies content.
pub fn executeCut(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    clipboard: ClipboardBackend,
) !CommandResult {
    // First, copy to clipboard
    const copy_result = try executeCopy(allocator, document, clipboard);
    if (!copy_result.success) {
        return .{ .success = false };
    }

    // Then delete the selection
    // TODO: Integrate with Selection API and UndoManager
    // deleteSelection(document);
    // recordUndoEntry(document, .cut);

    return .{ .success = true };
}

/// Execute paste command using the clipboard backend
/// Pastes from clipboard
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-paste-command
/// Clipboard API: https://w3c.github.io/clipboard-apis/#paste-action
///
/// Algorithm:
/// 1. Check if clipboard read is permitted
/// 2. Read from clipboard via backend
/// 3. If clipboard is empty:
///    a. Return false
/// 4. Delete current selection if not collapsed
/// 5. Determine paste format based on content and context:
///    a. If text/html available and not pasting into <pre> or <code>:
///       - Parse HTML via DOMParser or template element
///       - Sanitize (remove scripts, normalize styles)
///       - Insert document fragment
///    b. Otherwise (text/plain or constrained context):
///       - Create text node with clipboard text
///       - Insert at caret position
/// 6. Create undo entry with inserted content
/// 7. Return true
///
/// Security Note: paste requires:
/// - User gesture (click, keypress)
/// - Clipboard read permission (may prompt user)
/// - Content sanitization to prevent XSS
pub fn executePaste(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    clipboard: ClipboardBackend,
) !CommandResult {
    _ = document;

    // Check permission
    if (!clipboard.canRead()) {
        return .{ .success = false };
    }

    // Check if clipboard has content
    if (!clipboard.hasContent()) {
        return .{ .success = false };
    }

    // Try to read HTML first, fall back to text
    if (clipboard.readHtml(allocator)) |html| {
        defer allocator.free(html);
        // TODO: Sanitize HTML and insert into DOM
        // const sanitized = sanitizeHtml(html);
        // insertHtmlAtCaret(document, sanitized);
        // recordUndoEntry(document, .paste);
        return .{ .success = true };
    } else if (clipboard.readText(allocator)) |text| {
        defer allocator.free(text);
        // TODO: Insert text at caret
        // insertTextAtCaret(document, text);
        // recordUndoEntry(document, .paste);
        return .{ .success = true };
    }

    return .{ .success = false };
}

// =============================================================================
// Legacy Compatibility Functions (without clipboard backend parameter)
// =============================================================================

/// Legacy executeCopy - uses stub behavior
/// For backwards compatibility until all callers pass clipboard backend
pub fn executeCopyLegacy(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;
    // Legacy stub behavior
    return .{ .success = true };
}

/// Legacy executeCut - uses stub behavior
pub fn executeCutLegacy(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;
    return .{ .success = true };
}

/// Legacy executePaste - uses stub behavior
pub fn executePasteLegacy(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;
    return .{ .success = true };
}

// =============================================================================
// Selection Helpers
// =============================================================================

/// Get the current selection from document
pub fn getDocumentSelection(document: DocumentHandle) ?*anyopaque {
    // Would call document.getSelection()
    _ = document;
    return null;
}

/// Check if selection is collapsed (caret with no range)
pub fn isSelectionCollapsed(selection: *anyopaque) bool {
    // Would check selection.isCollapsed
    _ = selection;
    return true;
}

/// Get selection as plain text
/// TODO: Integrate with Selection API
fn getSelectionText(allocator: std.mem.Allocator, document: DocumentHandle) ?[]const u8 {
    _ = allocator;
    _ = document;
    // Would call selection.toString()
    return null;
}

/// Get selection as HTML
/// TODO: Integrate with Selection API
fn getSelectionHtml(allocator: std.mem.Allocator, document: DocumentHandle) ?[]const u8 {
    _ = allocator;
    _ = document;
    // Would serialize selection range to HTML
    return null;
}

/// Get selection as plain text (public interface)
pub fn getSelectionAsText(
    allocator: std.mem.Allocator,
    selection: *anyopaque,
) !?[]const u8 {
    _ = allocator;
    // Would call selection.toString()
    _ = selection;
    return null;
}

/// Get selection as HTML (public interface)
pub fn getSelectionAsHTML(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    selection: *anyopaque,
) !?[]const u8 {
    _ = allocator;
    _ = document;
    _ = selection;

    // Implementation outline:
    // 1. Get range from selection
    // 2. Clone contents to document fragment
    // 3. Serialize fragment to HTML string

    return null;
}

/// Delete the current selection
pub fn deleteSelection(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    selection: *anyopaque,
) !bool {
    _ = allocator;
    _ = document;
    _ = selection;

    // Implementation outline:
    // 1. Call selection.deleteFromDocument()
    // 2. Handle special cases (tables, lists, etc.)

    return true;
}

// =============================================================================
// Tests
// =============================================================================

test "selection_ops module compiles" {
    try std.testing.expect(true);
}

test "executeCopy with stub clipboard" {
    const allocator = std.testing.allocator;

    const stub = try platform.StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    // With no selection, copy should fail (return false)
    // But since getSelectionText/Html return null, it will return false
    const result = try executeCopy(allocator, null, clipboard);
    try std.testing.expect(!result.success);
}

test "executePaste with empty clipboard" {
    const allocator = std.testing.allocator;

    const stub = try platform.StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    // Empty clipboard should fail
    const result = try executePaste(allocator, null, clipboard);
    try std.testing.expect(!result.success);
}

test "executePaste with text content" {
    const allocator = std.testing.allocator;

    const stub = try platform.StubClipboardBackend.init(allocator);
    const clipboard = stub.backend();
    defer clipboard.deinit();

    // Put something in clipboard
    _ = clipboard.writeText("Hello, world!");

    // Should succeed (clipboard has content)
    const result = try executePaste(allocator, null, clipboard);
    try std.testing.expect(result.success);
}

test "executePaste with denied permissions" {
    const allocator = std.testing.allocator;

    const denied = try platform.DeniedClipboardBackend.init(allocator);
    const clipboard = denied.backend();
    defer clipboard.deinit();

    // Should fail due to permission denied
    const result = try executePaste(allocator, null, clipboard);
    try std.testing.expect(!result.success);
}

test "executeCopy with denied permissions" {
    const allocator = std.testing.allocator;

    const denied = try platform.DeniedClipboardBackend.init(allocator);
    const clipboard = denied.backend();
    defer clipboard.deinit();

    // Should fail due to permission denied
    const result = try executeCopy(allocator, null, clipboard);
    try std.testing.expect(!result.success);
}
