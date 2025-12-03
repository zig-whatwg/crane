//! Editing APIs (HTML §6.5)
//!
//! Implements document.execCommand() and related editing functionality.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#editing
//! W3C Editing API: https://w3c.github.io/editing/docs/execCommand/
//!
//! ## Commands
//!
//! This module implements ~40 editing commands that operate on the current
//! selection or document state. Commands are organized by category:
//!
//! - **Formatting**: bold, italic, underline, strikeThrough, subscript, superscript
//! - **Font**: fontName, fontSize, foreColor, backColor, hiliteColor
//! - **Alignment**: justifyLeft, justifyCenter, justifyRight, justifyFull
//! - **Lists**: insertOrderedList, insertUnorderedList
//! - **Indentation**: indent, outdent
//! - **Structure**: insertParagraph, insertLineBreak, insertHorizontalRule
//! - **Links**: createLink, unlink
//! - **Media**: insertImage, insertHTML, insertText
//! - **Clipboard**: copy, cut, paste
//! - **History**: undo, redo
//! - **Selection**: selectAll, delete, forwardDelete
//!
//! ## Architecture
//!
//! The editing system uses:
//! - `Command` enum for all supported commands
//! - `CommandState` for queryCommandState/queryCommandEnabled
//! - `EditorState` for undo/redo history
//! - Integration with Selection API for range operations
//!
//! ## Usage
//!
//! ```zig
//! const editing = @import("html/editing/root.zig");
//!
//! // Execute a command
//! const success = try editing.execCommand(document, .bold, null, null);
//!
//! // Query command state
//! const is_bold = try editing.queryCommandState(document, .bold);
//!
//! // Check if command is enabled
//! const can_bold = try editing.queryCommandEnabled(document, .bold);
//! ```

const std = @import("std");

// Core editing functionality
pub const commands = @import("commands.zig");
pub const executor = @import("executor.zig");
pub const state = @import("state.zig");
pub const history = @import("history.zig");

// Re-export primary types
pub const Command = commands.Command;
pub const CommandResult = executor.CommandResult;
pub const EditorState = state.EditorState;
pub const UndoManager = history.UndoManager;
pub const UndoEntry = history.UndoEntry;

// Re-export primary functions
pub const execCommand = executor.execCommand;
pub const queryCommandEnabled = executor.queryCommandEnabled;
pub const queryCommandState = executor.queryCommandState;
pub const queryCommandSupported = executor.queryCommandSupported;
pub const queryCommandValue = executor.queryCommandValue;
pub const queryCommandIndeterm = executor.queryCommandIndeterm;

test {
    std.testing.refAllDecls(@This());
}
