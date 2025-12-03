//! Editor State Management
//!
//! Maintains editing state for a document including:
//! - designMode and contentEditable state tracking
//! - Command configuration (styleWithCSS, defaultParagraphSeparator)
//! - UI state for editing features
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#editing

const std = @import("std");
const commands = @import("commands.zig");
const history = @import("history.zig");

/// Opaque document handle
pub const DocumentHandle = *anyopaque;

pub const Command = commands.Command;

/// Default paragraph separator options
pub const ParagraphSeparator = enum {
    div,
    p,
    br,

    pub fn fromString(s: []const u8) ?ParagraphSeparator {
        if (std.ascii.eqlIgnoreCase(s, "div")) return .div;
        if (std.ascii.eqlIgnoreCase(s, "p")) return .p;
        if (std.ascii.eqlIgnoreCase(s, "br")) return .br;
        return null;
    }

    pub fn toString(self: ParagraphSeparator) []const u8 {
        return switch (self) {
            .div => "div",
            .p => "p",
            .br => "br",
        };
    }
};

/// Editor configuration per document
/// Tracks all state needed for execCommand operations
pub const EditorState = struct {
    allocator: std.mem.Allocator,

    /// Whether to use CSS for styling (vs HTML elements)
    /// Command: styleWithCSS
    /// When true: uses <span style="...">
    /// When false: uses <b>, <i>, <u>, etc.
    style_with_css: bool = false,

    /// Default paragraph separator element
    /// Command: defaultParagraphSeparator
    default_paragraph_separator: ParagraphSeparator = .div,

    /// Whether absolute positioning editor is enabled
    /// Command: enableAbsolutePositionEditor
    absolute_position_editor: bool = false,

    /// Whether inline table editing UI is enabled
    /// Command: enableInlineTableEditing
    inline_table_editing: bool = false,

    /// Whether object resizing UI is enabled
    /// Command: enableObjectResizing
    object_resizing: bool = true, // Enabled by default in most browsers

    /// Whether content is read-only
    /// Command: contentReadOnly
    content_read_only: bool = false,

    /// Undo/redo history manager
    undo_manager: history.UndoManager,

    /// Reference to associated document (weak reference)
    document: ?DocumentHandle = null,

    /// Create a new editor state
    pub fn init(allocator: std.mem.Allocator) EditorState {
        return .{
            .allocator = allocator,
            .undo_manager = history.UndoManager.init(allocator),
        };
    }

    /// Clean up editor state
    pub fn deinit(self: *EditorState) void {
        self.undo_manager.deinit();
    }

    /// Check if editing is enabled for the document
    /// Returns true if designMode is "on" or any element is contentEditable
    pub fn isEditingEnabled(self: *const EditorState) bool {
        // TODO: Check document's designMode
        // TODO: Check if active element or selection is in contentEditable
        _ = self;
        return true; // Placeholder - assume enabled
    }

    /// Check if a command is enabled given current state
    pub fn isCommandEnabled(self: *const EditorState, command: Command) bool {
        // Check if editing is enabled at all
        if (!self.isEditingEnabled()) {
            // Some commands work even without editing (copy, selectAll)
            return switch (command) {
                .copy, .selectAll => true,
                else => false,
            };
        }

        // Check read-only state
        if (self.content_read_only and command.modifiesContent()) {
            return false;
        }

        // Check undo/redo availability
        return switch (command) {
            .undo => self.undo_manager.canUndo(),
            .redo => self.undo_manager.canRedo(),
            else => true,
        };
    }

    /// Get the value for a command
    pub fn getCommandValue(self: *const EditorState, command: Command) ?[]const u8 {
        return switch (command) {
            .defaultParagraphSeparator => self.default_paragraph_separator.toString(),
            .styleWithCSS => if (self.style_with_css) "true" else "false",
            // TODO: Query current selection for formatting values
            else => null,
        };
    }

    /// Set configuration for a command
    pub fn setConfig(self: *EditorState, command: Command, value: ?[]const u8) bool {
        switch (command) {
            .styleWithCSS => {
                if (value) |v| {
                    self.style_with_css = std.ascii.eqlIgnoreCase(v, "true");
                } else {
                    self.style_with_css = true; // Default to true when called without value
                }
                return true;
            },
            .defaultParagraphSeparator => {
                if (value) |v| {
                    if (ParagraphSeparator.fromString(v)) |sep| {
                        self.default_paragraph_separator = sep;
                        return true;
                    }
                }
                return false;
            },
            .enableAbsolutePositionEditor => {
                self.absolute_position_editor = if (value) |v|
                    std.ascii.eqlIgnoreCase(v, "true")
                else
                    true;
                return true;
            },
            .enableInlineTableEditing => {
                self.inline_table_editing = if (value) |v|
                    std.ascii.eqlIgnoreCase(v, "true")
                else
                    true;
                return true;
            },
            .enableObjectResizing => {
                self.object_resizing = if (value) |v|
                    std.ascii.eqlIgnoreCase(v, "true")
                else
                    true;
                return true;
            },
            .contentReadOnly => {
                self.content_read_only = if (value) |v|
                    std.ascii.eqlIgnoreCase(v, "true")
                else
                    true;
                return true;
            },
            else => return false,
        }
    }
};

/// Per-element editing state (for contentEditable elements)
pub const ElementEditingState = struct {
    /// The element this state is for
    element: ?DocumentHandle = null,

    /// Whether spellcheck is enabled
    spellcheck: bool = true,

    /// Input mode hint
    input_mode: InputMode = .text,

    /// Enter key behavior hint
    enter_key_hint: EnterKeyHint = .enter,

    /// Virtual keyboard policy
    virtual_keyboard_policy: VirtualKeyboardPolicy = .auto,
};

/// Input mode values
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-inputmode
pub const InputMode = enum {
    none,
    text,
    tel,
    url,
    email,
    numeric,
    decimal,
    search,

    pub fn fromString(s: []const u8) InputMode {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "text")) return .text;
        if (std.mem.eql(u8, s, "tel")) return .tel;
        if (std.mem.eql(u8, s, "url")) return .url;
        if (std.mem.eql(u8, s, "email")) return .email;
        if (std.mem.eql(u8, s, "numeric")) return .numeric;
        if (std.mem.eql(u8, s, "decimal")) return .decimal;
        if (std.mem.eql(u8, s, "search")) return .search;
        return .text; // Default
    }
};

/// Enter key hint values
/// Spec: https://html.spec.whatwg.org/multipage/interaction.html#attr-enterkeyhint
pub const EnterKeyHint = enum {
    enter,
    done,
    go,
    next,
    previous,
    search,
    send,

    pub fn fromString(s: []const u8) EnterKeyHint {
        if (std.mem.eql(u8, s, "enter")) return .enter;
        if (std.mem.eql(u8, s, "done")) return .done;
        if (std.mem.eql(u8, s, "go")) return .go;
        if (std.mem.eql(u8, s, "next")) return .next;
        if (std.mem.eql(u8, s, "previous")) return .previous;
        if (std.mem.eql(u8, s, "search")) return .search;
        if (std.mem.eql(u8, s, "send")) return .send;
        return .enter; // Default
    }
};

/// Virtual keyboard policy values
/// Spec: https://w3c.github.io/virtual-keyboard/
pub const VirtualKeyboardPolicy = enum {
    auto,
    manual,

    pub fn fromString(s: []const u8) VirtualKeyboardPolicy {
        if (std.mem.eql(u8, s, "manual")) return .manual;
        return .auto; // Default
    }
};

test "EditorState init/deinit" {
    const allocator = std.testing.allocator;
    var state_obj = EditorState.init(allocator);
    defer state_obj.deinit();

    try std.testing.expect(!state_obj.style_with_css);
    try std.testing.expect(state_obj.object_resizing);
    try std.testing.expectEqual(ParagraphSeparator.div, state_obj.default_paragraph_separator);
}

test "EditorState.setConfig" {
    const allocator = std.testing.allocator;
    var state_obj = EditorState.init(allocator);
    defer state_obj.deinit();

    try std.testing.expect(state_obj.setConfig(.styleWithCSS, "true"));
    try std.testing.expect(state_obj.style_with_css);

    try std.testing.expect(state_obj.setConfig(.defaultParagraphSeparator, "p"));
    try std.testing.expectEqual(ParagraphSeparator.p, state_obj.default_paragraph_separator);
}

test "ParagraphSeparator" {
    try std.testing.expectEqual(ParagraphSeparator.div, ParagraphSeparator.fromString("div").?);
    try std.testing.expectEqual(ParagraphSeparator.p, ParagraphSeparator.fromString("P").?);
    try std.testing.expect(ParagraphSeparator.fromString("unknown") == null);
}
