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

/// The Document's state and value overrides (specs/w3c/execCommand.md,
/// "Common definitions": "For some commands, each Document must have a
/// boolean state override and/or a string value override"). Data only: the
/// html module's execcommand/overrides.zig reads and writes them. The value
/// override of backColor is hiliteColor's ("setting one sets the other").
pub const FormattingOverrides = struct {
    pub const StateCommand = enum { bold, italic, strikethrough, subscript, superscript, underline };
    pub const ValueCommand = enum { create_link, font_name, font_size, fore_color, hilite_color };

    states: std.EnumArray(StateCommand, ?bool) = .initFill(null),
    /// When each state override was set (a running count): restoring them
    /// in that order rebuilds the nesting a deletion recorded.
    state_order: std.EnumArray(StateCommand, u32) = .initFill(0),
    next_order: u32 = 1,
    /// Owned by the EditorState's allocator.
    values: std.EnumArray(ValueCommand, ?[]u8) = .initFill(null),
    /// The selection the overrides were set under: "Whenever the number of
    /// ranges in the selection changes to something different, and whenever
    /// a boundary point of the range at a given index in the selection
    /// changes to something different, the state override and value
    /// override must be unset for every command." An identity record -
    /// addresses with their slab generations, never dereferenced.
    selection: SelectionKey = .{},

    pub const SelectionKey = struct {
        range_count: u32 = 0,
        range: usize = 0,
        range_generation: u64 = 0,
        start: usize = 0,
        start_generation: u64 = 0,
        start_offset: u32 = 0,
        end: usize = 0,
        end_generation: u64 = 0,
        end_offset: u32 = 0,

        pub fn eql(a: SelectionKey, b: SelectionKey) bool {
            return std.meta.eql(a, b);
        }
    };

    /// Whether any override is set.
    pub fn any(self: *const FormattingOverrides) bool {
        for (self.states.values) |state| if (state != null) return true;
        for (self.values.values) |value| if (value != null) return true;
        return false;
    }

    /// Unset every override.
    pub fn clear(self: *FormattingOverrides, allocator: std.mem.Allocator) void {
        self.states = .initFill(null);
        self.state_order = .initFill(0);
        self.next_order = 1;
        for (&self.values.values) |*value| {
            if (value.*) |owned| allocator.free(owned);
            value.* = null;
        }
    }
};

/// Editor configuration per document
/// Tracks all state needed for execCommand operations
pub const EditorState = struct {
    allocator: std.mem.Allocator,

    /// The Document's CSS styling flag, "initially false"
    /// (specs/w3c/execCommand.md, "CSS styling flag"). Set by the
    /// styleWithCSS and useCSS commands; when true, formatting commands
    /// write <span style="..."> rather than <b>, <i>, <u>, etc.
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

    /// Undo/redo history manager
    undo_manager: history.UndoManager,

    /// Reference to associated document (weak reference)
    document: ?DocumentHandle = null,

    /// The Document's state and value overrides (execcommand/overrides.zig).
    formatting_overrides: FormattingOverrides = .{},

    /// Create a new editor state
    pub fn init(allocator: std.mem.Allocator) EditorState {
        return .{
            .allocator = allocator,
            .undo_manager = history.UndoManager.init(allocator),
        };
    }

    /// Clean up editor state
    pub fn deinit(self: *EditorState) void {
        self.formatting_overrides.clear(self.allocator);
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

        // Check undo/redo availability
        return switch (command) {
            .undo => self.undo_manager.canUndo(),
            .redo => self.undo_manager.canRedo(),
            else => true,
        };
    }

    /// The state of a configuration command, or null for a command whose
    /// state is not this object's to answer. styleWithCSS: "True if the CSS
    /// styling flag is true, otherwise false"; useCSS has no state, so
    /// queryCommandState answers false (specs/w3c/execCommand.md).
    pub fn getCommandState(self: *const EditorState, command: Command) ?bool {
        return switch (command) {
            .styleWithCSS => self.style_with_css,
            .useCSS => false,
            else => null,
        };
    }

    /// Get the value for a command
    pub fn getCommandValue(self: *const EditorState, command: Command) ?[]const u8 {
        return switch (command) {
            .defaultParagraphSeparator => self.default_paragraph_separator.toString(),
            // Neither defines a value, so queryCommandValue returns the
            // empty string (Chrome 155, Firefox 158 and Safari 27 agree:
            // tmp/analysis/integrator-probes-1026l/results/swc-*.json).
            .styleWithCSS, .useCSS => "",
            // TODO: Query current selection for formatting values
            else => null,
        };
    }

    /// Set configuration for a command
    pub fn setConfig(self: *EditorState, command: Command, value: ?[]const u8) bool {
        switch (command) {
            // "If value is an ASCII case-insensitive match for the string
            // "false", set the CSS styling flag to false. Otherwise, set the
            // CSS styling flag to true. Either way, return true." No value is
            // execCommand's IDL default, "".
            .styleWithCSS => {
                self.style_with_css = !std.ascii.eqlIgnoreCase(value orelse "", "false");
                return true;
            },
            // useCSS: the same with the opposite values.
            .useCSS => {
                self.style_with_css = std.ascii.eqlIgnoreCase(value orelse "", "false");
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
    try std.testing.expect(state_obj.setConfig(.styleWithCSS, "FALSE"));
    try std.testing.expect(!state_obj.style_with_css);
    try std.testing.expect(state_obj.setConfig(.styleWithCSS, "truer"));
    try std.testing.expect(state_obj.style_with_css);
    try std.testing.expect(state_obj.setConfig(.useCSS, "TRUE"));
    try std.testing.expect(!state_obj.style_with_css);
    try std.testing.expect(state_obj.setConfig(.useCSS, "False"));
    try std.testing.expect(state_obj.style_with_css);
    try std.testing.expectEqual(@as(?bool, true), state_obj.getCommandState(.styleWithCSS));
    try std.testing.expectEqualStrings("", state_obj.getCommandValue(.styleWithCSS).?);

    try std.testing.expect(state_obj.setConfig(.defaultParagraphSeparator, "p"));
    try std.testing.expectEqual(ParagraphSeparator.p, state_obj.default_paragraph_separator);
}

test "ParagraphSeparator" {
    try std.testing.expectEqual(ParagraphSeparator.div, ParagraphSeparator.fromString("div").?);
    try std.testing.expectEqual(ParagraphSeparator.p, ParagraphSeparator.fromString("P").?);
    try std.testing.expect(ParagraphSeparator.fromString("unknown") == null);
}
