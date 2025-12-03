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
        .copy => selection_ops.executeCopy(allocator, document),
        .cut => selection_ops.executeCut(allocator, document),
        .paste => selection_ops.executePaste(allocator, document),

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
fn executeUndo(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;
    // TODO: Get editor state and call undo_manager.undo()
    // Then apply the undo operation to the document
    return .{ .success = true };
}

/// Execute redo command
fn executeRedo(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    _ = allocator;
    _ = document;
    // TODO: Get editor state and call undo_manager.redo()
    // Then apply the redo operation to the document
    return .{ .success = true };
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

/// Get or create editor state for a document
fn getOrCreateEditorState(allocator: std.mem.Allocator, document: DocumentHandle) *EditorState {
    // TODO: Store editor state in document's internal state
    // For now, return a static placeholder
    _ = document;
    const Static = struct {
        var editor_state: ?EditorState = null;
    };

    if (Static.editor_state == null) {
        Static.editor_state = EditorState.init(allocator);
    }

    return &Static.editor_state.?;
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
