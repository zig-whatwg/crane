//! Command Executor
//!
//! Implements execCommand(), queryCommandState(), and related functions.
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/
//! HTML: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-execcommand

const std = @import("std");
const commands = @import("commands.zig");
const state = @import("state.zig");
const history = @import("history.zig");
const formatting = @import("formatting.zig");
const structure = @import("structure.zig");
const selection_ops = @import("selection_ops.zig");

/// Opaque document handle - actual runtime.Instance integration handled at call site
pub const DocumentHandle = *anyopaque;

pub const Command = commands.Command;
pub const EditorState = state.EditorState;
pub const UndoManager = history.UndoManager;

/// Result of executing a command
pub const CommandResult = struct {
    /// Whether the command was successfully executed
    success: bool,
    /// Error message if command failed
    error_message: ?[]const u8 = null,
};

/// Execute an editing command
///
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-execcommand
///
/// Arguments:
/// - document: The document to execute the command on (opaque handle)
/// - command: The command to execute
/// - show_ui: Whether to show UI (ignored by most browsers)
/// - value: Optional value for commands that require one
///
/// Returns: true if command was executed successfully
pub fn execCommand(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command_name: []const u8,
    show_ui: bool,
    value: ?[]const u8,
) !bool {
    _ = show_ui; // Ignored per modern browser behavior

    // Step 1: Parse command name
    const command = Command.fromString(command_name) orelse {
        // Unknown command - return false
        return false;
    };

    // Step 2: Get or create editor state for this document
    const editor_state = getOrCreateEditorState(allocator, document);
    _ = editor_state;

    // Step 3: Check if command is enabled
    // For now, assume enabled - full implementation would check:
    // - designMode
    // - contentEditable on selection
    // - Command-specific requirements

    // Step 4: Execute the command
    const result = try executeCommandImpl(allocator, document, command, value);

    return result.success;
}

/// Execute a specific command
fn executeCommandImpl(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    value: ?[]const u8,
) !CommandResult {
    return switch (command) {
        // Formatting commands
        .bold => formatting.executeBold(allocator, document),
        .italic => formatting.executeItalic(allocator, document),
        .underline => formatting.executeUnderline(allocator, document),
        .strikeThrough => formatting.executeStrikeThrough(allocator, document),
        .subscript => formatting.executeSubscript(allocator, document),
        .superscript => formatting.executeSuperscript(allocator, document),
        .removeFormat => formatting.executeRemoveFormat(allocator, document),

        // Font commands
        .fontName => formatting.executeFontName(allocator, document, value),
        .fontSize => formatting.executeFontSize(allocator, document, value),
        .foreColor => formatting.executeForeColor(allocator, document, value),
        .backColor => formatting.executeBackColor(allocator, document, value),
        .hiliteColor => formatting.executeHiliteColor(allocator, document, value),

        // Alignment commands
        .justifyLeft => formatting.executeJustify(allocator, document, .left),
        .justifyCenter => formatting.executeJustify(allocator, document, .center),
        .justifyRight => formatting.executeJustify(allocator, document, .right),
        .justifyFull => formatting.executeJustify(allocator, document, .full),

        // Structure commands
        .insertParagraph => structure.executeInsertParagraph(allocator, document),
        .insertLineBreak => structure.executeInsertLineBreak(allocator, document),
        .insertHorizontalRule => structure.executeInsertHorizontalRule(allocator, document),
        .formatBlock => structure.executeFormatBlock(allocator, document, value),
        .insertOrderedList => structure.executeInsertOrderedList(allocator, document),
        .insertUnorderedList => structure.executeInsertUnorderedList(allocator, document),
        .indent => structure.executeIndent(allocator, document),
        .outdent => structure.executeOutdent(allocator, document),

        // Link commands
        .createLink => structure.executeCreateLink(allocator, document, value),
        .unlink => structure.executeUnlink(allocator, document),

        // Content insertion commands
        .insertImage => structure.executeInsertImage(allocator, document, value),
        .insertHTML => structure.executeInsertHTML(allocator, document, value),
        .insertText => structure.executeInsertText(allocator, document, value),

        // Clipboard commands
        // TODO: Pass clipboard backend from document/editor state when available
        // For now, use legacy functions that don't require clipboard backend
        .copy => selection_ops.executeCopyLegacy(allocator, document),
        .cut => selection_ops.executeCutLegacy(allocator, document),
        .paste => selection_ops.executePasteLegacy(allocator, document),

        // History commands
        .undo => executeUndo(allocator, document),
        .redo => executeRedo(allocator, document),

        // Selection commands
        .selectAll => selection_ops.executeSelectAll(allocator, document),
        .delete => selection_ops.executeDelete(allocator, document),
        .forwardDelete => selection_ops.executeForwardDelete(allocator, document),

        // Configuration commands
        .styleWithCSS,
        .defaultParagraphSeparator,
        .enableAbsolutePositionEditor,
        .enableInlineTableEditing,
        .enableObjectResizing,
        .contentReadOnly,
        => executeConfigCommand(allocator, document, command, value),
    };
}

/// Execute undo command
/// Reverts the most recent editing operation
///
/// Algorithm:
/// 1. Get UndoManager for document
/// 2. If undo stack is empty, return false
/// 3. Pop entry from undo stack
/// 4. Apply undo_data to reverse the operation
/// 5. Push entry to redo stack
/// 6. Return true
fn executeUndo(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    const editor_state = getOrCreateEditorState(allocator, document);

    // Check if undo is available
    if (!editor_state.undo_manager.canUndo()) {
        return .{ .success = false };
    }

    // Get the entry to undo
    if (editor_state.undo_manager.undo()) |entry| {
        // Apply the undo operation based on entry type
        try applyUndoEntry(allocator, document, entry);
        return .{ .success = true };
    }

    return .{ .success = false };
}

/// Execute redo command
/// Re-applies the most recently undone operation
///
/// Algorithm:
/// 1. Get UndoManager for document
/// 2. If redo stack is empty, return false
/// 3. Pop entry from redo stack
/// 4. Apply redo_data to re-apply the operation
/// 5. Push entry to undo stack
/// 6. Return true
fn executeRedo(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    const editor_state = getOrCreateEditorState(allocator, document);

    // Check if redo is available
    if (!editor_state.undo_manager.canRedo()) {
        return .{ .success = false };
    }

    // Get the entry to redo
    if (editor_state.undo_manager.redo()) |entry| {
        // Apply the redo operation based on entry type
        try applyRedoEntry(allocator, document, entry);
        return .{ .success = true };
    }

    return .{ .success = false };
}

/// Apply an undo entry to reverse an operation
fn applyUndoEntry(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    entry: *history.UndoEntry,
) !void {
    _ = allocator;
    _ = document;

    // Apply based on entry type
    switch (entry.entry_type) {
        .insert_text => {
            // Undo text insertion = delete the inserted text
            // Position is in entry.undo_data.position
            // Length to delete is the inserted text length from redo_data
            // TODO: Integrate with DOM when available
            // deleteText(document, entry.redo_data.position, entry.redo_data.text.len);
        },
        .delete_text => {
            // Undo text deletion = re-insert the deleted text
            // Position is in entry.undo_data.position
            // Text to insert is in entry.undo_data.text
            // TODO: Integrate with DOM when available
            // insertText(document, entry.undo_data.position, entry.undo_data.text);
        },
        .format => {
            // Undo formatting = toggle format back
            // The previous state is in entry.undo_data.format_was_active
            // TODO: Integrate with DOM when available
            // toggleFormat(document, entry.command, entry.undo_data.format_was_active);
        },
        .structure => {
            // Undo structural change = restore previous structure
            // HTML is in entry.undo_data.html
            // TODO: Integrate with DOM when available
            // replaceHtml(document, entry.undo_data.position, entry.undo_data.html);
        },
        .link => {
            // Undo link operation
            // For createLink: remove the link
            // For unlink: restore the link
            // TODO: Integrate with DOM when available
        },
        .insert_content => {
            // Undo content insertion = remove the inserted content
            // TODO: Integrate with DOM when available
        },
        .composite => {
            // Composite entries would need to undo multiple operations
            // TODO: Implement when composite undo is needed
        },
    }
}

/// Apply a redo entry to re-apply an operation
fn applyRedoEntry(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    entry: *history.UndoEntry,
) !void {
    _ = allocator;
    _ = document;

    // Apply based on entry type
    switch (entry.entry_type) {
        .insert_text => {
            // Redo text insertion = insert the text again
            // Position is in entry.redo_data.position
            // Text to insert is in entry.redo_data.text
            // TODO: Integrate with DOM when available
            // insertText(document, entry.redo_data.position, entry.redo_data.text);
        },
        .delete_text => {
            // Redo text deletion = delete the text again
            // Position is in entry.redo_data.position
            // Length to delete is the deleted text length from undo_data
            // TODO: Integrate with DOM when available
            // deleteText(document, entry.undo_data.position, entry.undo_data.text.len);
        },
        .format => {
            // Redo formatting = apply format
            // The target state is in entry.redo_data.format_was_active
            // TODO: Integrate with DOM when available
            // toggleFormat(document, entry.command, entry.redo_data.format_was_active);
        },
        .structure => {
            // Redo structural change = apply the structure
            // TODO: Integrate with DOM when available
        },
        .link => {
            // Redo link operation
            // TODO: Integrate with DOM when available
        },
        .insert_content => {
            // Redo content insertion = insert the content
            // TODO: Integrate with DOM when available
        },
        .composite => {
            // Composite entries would need to redo multiple operations
            // TODO: Implement when composite redo is needed
        },
    }
}

/// Execute configuration command
fn executeConfigCommand(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    value: ?[]const u8,
) !CommandResult {
    var editor_state = getOrCreateEditorState(allocator, document);
    const success = editor_state.setConfig(command, value);
    return .{ .success = success };
}

/// Check if a command is enabled
///
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandenabled
pub fn queryCommandEnabled(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command_name: []const u8,
) !bool {
    const command = Command.fromString(command_name) orelse return false;
    const editor_state = getOrCreateEditorState(allocator, document);
    return editor_state.isCommandEnabled(command);
}

/// Get the current state of a toggle command
///
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandstate
pub fn queryCommandState(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command_name: []const u8,
) !bool {
    const command = Command.fromString(command_name) orelse return false;

    // Only toggle commands have meaningful state
    if (!command.isToggle()) {
        return false;
    }

    // Query the current selection's formatting
    return formatting.queryFormattingState(allocator, document, command);
}

/// Check if a command is supported
///
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandsupported
pub fn queryCommandSupported(
    command_name: []const u8,
) bool {
    return Command.fromString(command_name) != null;
}

/// Get the current value for a valued command
///
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandvalue
pub fn queryCommandValue(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command_name: []const u8,
) !?[]const u8 {
    const command = Command.fromString(command_name) orelse return null;

    // Check editor state for config commands
    const editor_state = getOrCreateEditorState(allocator, document);
    if (editor_state.getCommandValue(command)) |value| {
        return value;
    }

    // Query current selection for formatting values
    return formatting.queryFormattingValue(allocator, document, command);
}

/// Check if a command's state is indeterminate
///
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#dom-document-querycommandindeterm
pub fn queryCommandIndeterm(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command_name: []const u8,
) !bool {
    const command = Command.fromString(command_name) orelse return false;

    // Only toggle commands can be indeterminate
    if (!command.isToggle()) {
        return false;
    }

    // Check if selection spans mixed formatting
    return formatting.queryFormattingIndeterm(allocator, document, command);
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Document to EditorState mapping
/// In production, this should be stored in the document's internal state
var document_states: ?std.AutoHashMap(usize, *EditorState) = null;

/// Get or create editor state for a document
fn getOrCreateEditorState(allocator: std.mem.Allocator, document: DocumentHandle) *EditorState {
    const doc_addr = @intFromPtr(document);

    // Initialize the map if needed
    if (document_states == null) {
        document_states = std.AutoHashMap(usize, *EditorState).init(allocator);
    }

    // Look up or create state for this document
    if (document_states.?.get(doc_addr)) |state_ptr| {
        return state_ptr;
    }

    // Create new state
    const new_state = allocator.create(EditorState) catch {
        // Fallback to static state on allocation failure
        const Static = struct {
            var editor_state: ?EditorState = null;
        };
        if (Static.editor_state == null) {
            Static.editor_state = EditorState.init(allocator);
        }
        return &Static.editor_state.?;
    };
    new_state.* = EditorState.init(allocator);
    new_state.document = document;

    document_states.?.put(doc_addr, new_state) catch {};

    return new_state;
}

/// Clean up editor state for a document (call when document is destroyed)
pub fn cleanupEditorState(allocator: std.mem.Allocator, document: DocumentHandle) void {
    if (document_states) |*states| {
        const doc_addr = @intFromPtr(document);
        if (states.fetchRemove(doc_addr)) |kv| {
            kv.value.deinit();
            allocator.destroy(kv.value);
        }
    }
}

// =============================================================================
// Undo Entry Recording Helpers
// =============================================================================

/// Record an undo entry for a text operation
pub fn recordTextOperation(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    deleted_text: ?[]const u8,
    inserted_text: ?[]const u8,
    position: usize,
) !void {
    const editor_state = getOrCreateEditorState(allocator, document);
    const entry = try history.UndoEntry.initTextOperation(
        allocator,
        command,
        deleted_text,
        inserted_text,
        position,
    );
    try editor_state.undo_manager.push(entry);
}

/// Record an undo entry for a formatting operation
pub fn recordFormatOperation(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    was_active: bool,
) !void {
    const editor_state = getOrCreateEditorState(allocator, document);
    const entry = history.UndoEntry.initFormatOperation(allocator, command, was_active);
    try editor_state.undo_manager.push(entry);
}

/// Record an undo entry for a structure operation (paragraphs, lists, etc.)
pub fn recordStructureOperation(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    old_html: ?[]const u8,
    new_html: ?[]const u8,
    position: usize,
) !void {
    const editor_state = getOrCreateEditorState(allocator, document);

    var entry = history.UndoEntry{
        .allocator = allocator,
        .entry_type = .structure,
        .command = command,
        .undo_data = .{
            .position = position,
        },
        .redo_data = .{
            .position = position,
        },
        .timestamp = std.time.timestamp(),
    };

    // Copy HTML strings
    if (old_html) |html| {
        entry.undo_data.html = try allocator.dupe(u8, html);
    }
    if (new_html) |html| {
        entry.redo_data.html = try allocator.dupe(u8, html);
    }

    try editor_state.undo_manager.push(entry);
}

/// Record an undo entry for a link operation
pub fn recordLinkOperation(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    old_html: ?[]const u8,
    new_html: ?[]const u8,
    position: usize,
) !void {
    const editor_state = getOrCreateEditorState(allocator, document);

    var entry = history.UndoEntry{
        .allocator = allocator,
        .entry_type = .link,
        .command = command,
        .undo_data = .{
            .position = position,
        },
        .redo_data = .{
            .position = position,
        },
        .timestamp = std.time.timestamp(),
    };

    // Copy HTML strings
    if (old_html) |html| {
        entry.undo_data.html = try allocator.dupe(u8, html);
    }
    if (new_html) |html| {
        entry.redo_data.html = try allocator.dupe(u8, html);
    }

    try editor_state.undo_manager.push(entry);
}

/// Record an undo entry for content insertion (image, HTML)
pub fn recordContentInsertion(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    inserted_html: []const u8,
    position: usize,
) !void {
    const editor_state = getOrCreateEditorState(allocator, document);

    var entry = history.UndoEntry{
        .allocator = allocator,
        .entry_type = .insert_content,
        .command = command,
        .undo_data = .{
            .position = position,
        },
        .redo_data = .{
            .position = position,
        },
        .timestamp = std.time.timestamp(),
    };

    entry.redo_data.html = try allocator.dupe(u8, inserted_html);

    try editor_state.undo_manager.push(entry);
}

/// Check if undo is available for a document
pub fn canUndo(allocator: std.mem.Allocator, document: DocumentHandle) bool {
    const editor_state = getOrCreateEditorState(allocator, document);
    return editor_state.undo_manager.canUndo();
}

/// Check if redo is available for a document
pub fn canRedo(allocator: std.mem.Allocator, document: DocumentHandle) bool {
    const editor_state = getOrCreateEditorState(allocator, document);
    return editor_state.undo_manager.canRedo();
}

/// Get the number of undo entries for a document
pub fn getUndoCount(allocator: std.mem.Allocator, document: DocumentHandle) usize {
    const editor_state = getOrCreateEditorState(allocator, document);
    return editor_state.undo_manager.undoCount();
}

/// Get the number of redo entries for a document
pub fn getRedoCount(allocator: std.mem.Allocator, document: DocumentHandle) usize {
    const editor_state = getOrCreateEditorState(allocator, document);
    return editor_state.undo_manager.redoCount();
}

/// Clear undo/redo history for a document
pub fn clearUndoHistory(allocator: std.mem.Allocator, document: DocumentHandle) void {
    const editor_state = getOrCreateEditorState(allocator, document);
    editor_state.undo_manager.clear();
}

// =============================================================================
// Tests
// =============================================================================

test "queryCommandSupported" {
    try std.testing.expect(queryCommandSupported("bold"));
    try std.testing.expect(queryCommandSupported("italic"));
    try std.testing.expect(queryCommandSupported("createLink"));
    try std.testing.expect(!queryCommandSupported("unknownCommand"));
    try std.testing.expect(!queryCommandSupported(""));
}

test "undo/redo integration" {
    const allocator = std.testing.allocator;

    // Use a dummy document handle
    var dummy: u8 = 0;
    const document: DocumentHandle = &dummy;

    // Initially, undo should not be available
    try std.testing.expect(!canUndo(allocator, document));
    try std.testing.expect(!canRedo(allocator, document));

    // Record a formatting operation
    try recordFormatOperation(allocator, document, .bold, false);

    // Now undo should be available
    try std.testing.expect(canUndo(allocator, document));
    try std.testing.expect(!canRedo(allocator, document));
    try std.testing.expectEqual(@as(usize, 1), getUndoCount(allocator, document));

    // Execute undo
    const undo_result = try executeUndo(allocator, document);
    try std.testing.expect(undo_result.success);

    // Now redo should be available, undo should not
    try std.testing.expect(!canUndo(allocator, document));
    try std.testing.expect(canRedo(allocator, document));
    try std.testing.expectEqual(@as(usize, 1), getRedoCount(allocator, document));

    // Execute redo
    const redo_result = try executeRedo(allocator, document);
    try std.testing.expect(redo_result.success);

    // Back to initial state after redo
    try std.testing.expect(canUndo(allocator, document));
    try std.testing.expect(!canRedo(allocator, document));

    // Clean up
    cleanupEditorState(allocator, document);
}

test "undo fails when nothing to undo" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;
    const document: DocumentHandle = &dummy;

    // Undo should fail when nothing to undo
    const result = try executeUndo(allocator, document);
    try std.testing.expect(!result.success);

    // Clean up
    cleanupEditorState(allocator, document);
}

test "redo fails when nothing to redo" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;
    const document: DocumentHandle = &dummy;

    // Redo should fail when nothing to redo
    const result = try executeRedo(allocator, document);
    try std.testing.expect(!result.success);

    // Clean up
    cleanupEditorState(allocator, document);
}

test "clear undo history" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;
    const document: DocumentHandle = &dummy;

    // Record some operations
    try recordFormatOperation(allocator, document, .bold, false);
    try recordFormatOperation(allocator, document, .italic, false);

    try std.testing.expectEqual(@as(usize, 2), getUndoCount(allocator, document));

    // Clear history
    clearUndoHistory(allocator, document);

    try std.testing.expectEqual(@as(usize, 0), getUndoCount(allocator, document));
    try std.testing.expect(!canUndo(allocator, document));

    // Clean up
    cleanupEditorState(allocator, document);
}

test "record text operation" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;
    const document: DocumentHandle = &dummy;

    // Record a text insertion
    try recordTextOperation(allocator, document, .insertText, null, "Hello", 0);

    try std.testing.expectEqual(@as(usize, 1), getUndoCount(allocator, document));
    try std.testing.expect(canUndo(allocator, document));

    // Clean up
    cleanupEditorState(allocator, document);
}
