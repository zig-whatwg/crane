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
const clock = @import("clock");
const runtime = @import("runtime");
const dom = @import("dom");

/// Opaque document handle - actual runtime.Instance integration handled at call site
pub const DocumentHandle = *anyopaque;

pub const Command = commands.Command;
pub const EditorState = state.EditorState;
pub const UndoStack = history.UndoStack;

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
    const editor_state = try getOrCreateEditorState(allocator, document);
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
        // The inline formatting commands are the html module's
        // (src/html/execcommand/inline.zig, on the generated interfaces,
        // which html_core cannot reach); Document.execCommand dispatches them
        // there before this executor, so they never arrive here.
        .bold,
        .italic,
        .underline,
        .strikeThrough,
        .subscript,
        .superscript,
        .removeFormat,
        .fontName,
        .fontSize,
        .foreColor,
        .backColor,
        .hiliteColor,
        => .{ .success = false },

        // The block formatting commands are the html module's
        // (src/html/execcommand/blocks.zig, on the generated interfaces,
        // which html_core cannot reach); Document.execCommand dispatches
        // them there before this executor, so they never arrive here.
        .insertParagraph,
        .insertLineBreak,
        .insertHorizontalRule,
        .formatBlock,
        .insertOrderedList,
        .insertUnorderedList,
        .indent,
        .outdent,
        .justifyLeft,
        .justifyCenter,
        .justifyRight,
        .justifyFull,
        => .{ .success = false },

        // Link commands
        .createLink => structure.executeCreateLink(allocator, document, value),
        .unlink => structure.executeUnlink(allocator, document),

        // Content insertion commands
        .insertImage => structure.executeInsertImage(allocator, document, value),
        .insertHTML => structure.executeInsertHTML(allocator, document, value),
        .insertText => structure.executeInsertText(allocator, document, value),

        // The clipboard commands are the html module's (src/html/execcommand/
        // clipboard.zig: the Clipboard API's actions through the platform
        // protocol's clipboard); Document.execCommand dispatches them there
        // before this executor, so they never arrive here.
        .copy, .cut, .paste => .{ .success = false },

        // undo and redo are the html module's (src/html/execcommand/undo.zig,
        // over the history in history.zig); Document.execCommand dispatches
        // them there before this executor, so they never arrive here.
        .undo, .redo => .{ .success = false },

        // selectAll, delete and forwardDelete are the html module's
        // (src/html/execcommand/, on the generated interfaces, which
        // html_core cannot reach); Document.execCommand dispatches them
        // there before this executor, so they never arrive here.
        .selectAll, .delete, .forwardDelete => .{ .success = false },

        // Configuration commands
        .styleWithCSS,
        .useCSS,
        .defaultParagraphSeparator,
        .enableAbsolutePositionEditor,
        .enableInlineTableEditing,
        .enableObjectResizing,
        => executeConfigCommand(allocator, document, command, value),
    };
}

/// Execute configuration command
fn executeConfigCommand(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
    value: ?[]const u8,
) !CommandResult {
    var editor_state = try getOrCreateEditorState(allocator, document);
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
    const editor_state = try getOrCreateEditorState(allocator, document);
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

    // The configuration commands' state is the Document's: the CSS styling
    // flag, false until a command sets it.
    switch (command) {
        .styleWithCSS, .useCSS => {
            const editor_state = existingEditorState(document) orelse return false;
            return editor_state.getCommandState(command) orelse false;
        },
        else => {},
    }

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
    const editor_state = try getOrCreateEditorState(allocator, document);
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

/// The editor state of `document` (a Document instance), made on its first
/// editing command with `allocator` - the document's own - and kept by the
/// Document itself (dom.document_internals.editorState), which frees it
/// with itself through `freeEditorState` (dom.editor_states).
///
/// It was a process-global, unlocked map keyed by the document's address,
/// made with the first caller's allocator and never emptied: a leak per
/// document, a race between Browsers on two threads, and a stale state for
/// a new document at a reused address (lane leaks6).
fn getOrCreateEditorState(allocator: std.mem.Allocator, document: DocumentHandle) error{OutOfMemory}!*EditorState {
    if (existingEditorState(document)) |existing| return existing;
    const new_state = try allocator.create(EditorState);
    new_state.* = EditorState.init(allocator);
    new_state.document = document;
    // Not a Document with state: nothing could keep it.
    if (!dom.document_internals.setEditorState(@ptrCast(@alignCast(document)), new_state)) {
        new_state.deinit();
        allocator.destroy(new_state);
        return error.OutOfMemory;
    }
    return new_state;
}

/// The editor state of `document` (a Document instance), made on first use
/// as `getOrCreateEditorState` does: the html module's execcommand reads the
/// CSS styling flag and the Document's state and value overrides here.
pub fn editorStateOf(allocator: std.mem.Allocator, document: DocumentHandle) error{OutOfMemory}!*EditorState {
    return getOrCreateEditorState(allocator, document);
}

/// `document`'s editor state, or null before its first editing command.
fn existingEditorState(document: DocumentHandle) ?*EditorState {
    const state_ptr = dom.document_internals.editorState(@ptrCast(@alignCast(document))) orelse return null;
    return @ptrCast(@alignCast(state_ptr));
}

/// dom.editor_states: free a Document's editor state, with the document.
fn freeEditorState(state_ptr: *anyopaque, allocator: std.mem.Allocator) void {
    const editor_state: *EditorState = @ptrCast(@alignCast(state_ptr));
    editor_state.deinit();
    allocator.destroy(editor_state);
}

/// dom.editor_states: the nodes a Document's editor state holds - its undo
/// history's (history.zig) - named to the collector from the Document's
/// `traceHeldNodes`, in its atomic pause. Reads only.
fn traceEditorState(state_ptr: *anyopaque, tracer: *dom.editor_states.Tracer) void {
    const editor_state: *const EditorState = @ptrCast(@alignCast(state_ptr));
    editor_state.undo_stack.trace(tracer);
}

/// dom.editor_states: a destroyed Document's editor state lets go of the
/// nodes it holds - its undo history empties (refcount step 7b).
fn releaseEditorStateNodes(state_ptr: *anyopaque) void {
    const editor_state: *EditorState = @ptrCast(@alignCast(state_ptr));
    editor_state.undo_stack.clear();
}

/// dom.editor_states: whether a Document's editor state holds nodes now - a
/// step on its undo or redo list.
fn editorStateHoldsNodes(state_ptr: *anyopaque) bool {
    const editor_state: *const EditorState = @ptrCast(@alignCast(state_ptr));
    return editor_state.undo_stack.canUndo() or editor_state.undo_stack.canRedo();
}

/// The editing subsystem's steps in a Document's tracing, destruction and
/// teardown, installed once at process start by Document's installHooks (the
/// owner of the editing commands).
pub fn installHooks() void {
    dom.editor_states.install(.{ .free = &freeEditorState, .trace = &traceEditorState, .release_nodes = &releaseEditorStateNodes, .holds_nodes = &editorStateHoldsNodes });
}
