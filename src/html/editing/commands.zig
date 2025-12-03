//! Editing Commands (W3C Editing API)
//!
//! Defines all supported execCommand commands per the W3C Editing specification.
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/

const std = @import("std");

/// All supported editing commands
/// Spec: https://w3c.github.io/editing/docs/execCommand/#supported-commands
pub const Command = enum {
    // ==========================================================================
    // Formatting Commands
    // ==========================================================================

    /// Makes selection bold or removes bold
    /// Command: "bold"
    bold,

    /// Makes selection italic or removes italic
    /// Command: "italic"
    italic,

    /// Underlines selection or removes underline
    /// Command: "underline"
    underline,

    /// Strikes through selection or removes strikethrough
    /// Command: "strikeThrough"
    strikeThrough,

    /// Makes selection subscript or removes subscript
    /// Command: "subscript"
    subscript,

    /// Makes selection superscript or removes superscript
    /// Command: "superscript"
    superscript,

    /// Removes formatting from selection
    /// Command: "removeFormat"
    removeFormat,

    // ==========================================================================
    // Font Commands
    // ==========================================================================

    /// Sets font family
    /// Command: "fontName"
    /// Value: font family name (e.g., "Arial", "Times New Roman")
    fontName,

    /// Sets font size (1-7 scale, legacy HTML)
    /// Command: "fontSize"
    /// Value: "1" through "7"
    fontSize,

    /// Sets text foreground color
    /// Command: "foreColor"
    /// Value: color string (e.g., "#ff0000", "red")
    foreColor,

    /// Sets text background color
    /// Command: "backColor"
    /// Value: color string
    backColor,

    /// Sets text highlight color (alias for backColor in most browsers)
    /// Command: "hiliteColor"
    /// Value: color string
    hiliteColor,

    // ==========================================================================
    // Alignment Commands
    // ==========================================================================

    /// Left-aligns the selection
    /// Command: "justifyLeft"
    justifyLeft,

    /// Center-aligns the selection
    /// Command: "justifyCenter"
    justifyCenter,

    /// Right-aligns the selection
    /// Command: "justifyRight"
    justifyRight,

    /// Full-justifies the selection
    /// Command: "justifyFull"
    justifyFull,

    // ==========================================================================
    // List Commands
    // ==========================================================================

    /// Toggles ordered list
    /// Command: "insertOrderedList"
    insertOrderedList,

    /// Toggles unordered list
    /// Command: "insertUnorderedList"
    insertUnorderedList,

    // ==========================================================================
    // Indentation Commands
    // ==========================================================================

    /// Increases indentation
    /// Command: "indent"
    indent,

    /// Decreases indentation
    /// Command: "outdent"
    outdent,

    // ==========================================================================
    // Structure Commands
    // ==========================================================================

    /// Inserts a paragraph break
    /// Command: "insertParagraph"
    insertParagraph,

    /// Inserts a line break (<br>)
    /// Command: "insertLineBreak"
    insertLineBreak,

    /// Inserts a horizontal rule (<hr>)
    /// Command: "insertHorizontalRule"
    insertHorizontalRule,

    /// Formats selection as specified block type
    /// Command: "formatBlock"
    /// Value: block element tag name (e.g., "h1", "p", "blockquote")
    formatBlock,

    // ==========================================================================
    // Link Commands
    // ==========================================================================

    /// Creates a link with the given URL
    /// Command: "createLink"
    /// Value: URL string
    createLink,

    /// Removes link from selection
    /// Command: "unlink"
    unlink,

    // ==========================================================================
    // Media/Content Commands
    // ==========================================================================

    /// Inserts an image
    /// Command: "insertImage"
    /// Value: image URL
    insertImage,

    /// Inserts HTML content
    /// Command: "insertHTML"
    /// Value: HTML string
    insertHTML,

    /// Inserts text content
    /// Command: "insertText"
    /// Value: text string
    insertText,

    // ==========================================================================
    // Clipboard Commands
    // ==========================================================================

    /// Copies selection to clipboard
    /// Command: "copy"
    copy,

    /// Cuts selection to clipboard
    /// Command: "cut"
    cut,

    /// Pastes from clipboard
    /// Command: "paste"
    paste,

    // ==========================================================================
    // History Commands
    // ==========================================================================

    /// Undoes last command
    /// Command: "undo"
    undo,

    /// Redoes last undone command
    /// Command: "redo"
    redo,

    // ==========================================================================
    // Selection Commands
    // ==========================================================================

    /// Selects all content
    /// Command: "selectAll"
    selectAll,

    /// Deletes selection (backspace behavior)
    /// Command: "delete"
    delete,

    /// Deletes forward (delete key behavior)
    /// Command: "forwardDelete"
    forwardDelete,

    // ==========================================================================
    // Other Commands
    // ==========================================================================

    /// Enables/disables absolute positioning for selected element
    /// Command: "enableAbsolutePositionEditor"
    enableAbsolutePositionEditor,

    /// Enables/disables inline table editing UI
    /// Command: "enableInlineTableEditing"
    enableInlineTableEditing,

    /// Enables/disables object resizing UI
    /// Command: "enableObjectResizing"
    enableObjectResizing,

    /// Sets default paragraph separator
    /// Command: "defaultParagraphSeparator"
    /// Value: "div", "p", or "br"
    defaultParagraphSeparator,

    /// Sets CSS styling mode
    /// Command: "styleWithCSS"
    /// Value: "true" or "false"
    styleWithCSS,

    /// Sets content read-only state
    /// Command: "contentReadOnly"
    contentReadOnly,

    /// Parse from string command name
    pub fn fromString(name: []const u8) ?Command {
        return string_to_command.get(name);
    }

    /// Convert to string command name
    pub fn toString(self: Command) []const u8 {
        return switch (self) {
            .bold => "bold",
            .italic => "italic",
            .underline => "underline",
            .strikeThrough => "strikeThrough",
            .subscript => "subscript",
            .superscript => "superscript",
            .removeFormat => "removeFormat",
            .fontName => "fontName",
            .fontSize => "fontSize",
            .foreColor => "foreColor",
            .backColor => "backColor",
            .hiliteColor => "hiliteColor",
            .justifyLeft => "justifyLeft",
            .justifyCenter => "justifyCenter",
            .justifyRight => "justifyRight",
            .justifyFull => "justifyFull",
            .insertOrderedList => "insertOrderedList",
            .insertUnorderedList => "insertUnorderedList",
            .indent => "indent",
            .outdent => "outdent",
            .insertParagraph => "insertParagraph",
            .insertLineBreak => "insertLineBreak",
            .insertHorizontalRule => "insertHorizontalRule",
            .formatBlock => "formatBlock",
            .createLink => "createLink",
            .unlink => "unlink",
            .insertImage => "insertImage",
            .insertHTML => "insertHTML",
            .insertText => "insertText",
            .copy => "copy",
            .cut => "cut",
            .paste => "paste",
            .undo => "undo",
            .redo => "redo",
            .selectAll => "selectAll",
            .delete => "delete",
            .forwardDelete => "forwardDelete",
            .enableAbsolutePositionEditor => "enableAbsolutePositionEditor",
            .enableInlineTableEditing => "enableInlineTableEditing",
            .enableObjectResizing => "enableObjectResizing",
            .defaultParagraphSeparator => "defaultParagraphSeparator",
            .styleWithCSS => "styleWithCSS",
            .contentReadOnly => "contentReadOnly",
        };
    }

    /// Check if command requires a value parameter
    pub fn requiresValue(self: Command) bool {
        return switch (self) {
            .fontName,
            .fontSize,
            .foreColor,
            .backColor,
            .hiliteColor,
            .formatBlock,
            .createLink,
            .insertImage,
            .insertHTML,
            .insertText,
            .defaultParagraphSeparator,
            => true,
            else => false,
        };
    }

    /// Check if command is a formatting toggle
    pub fn isToggle(self: Command) bool {
        return switch (self) {
            .bold,
            .italic,
            .underline,
            .strikeThrough,
            .subscript,
            .superscript,
            .insertOrderedList,
            .insertUnorderedList,
            => true,
            else => false,
        };
    }

    /// Check if command modifies document content
    pub fn modifiesContent(self: Command) bool {
        return switch (self) {
            // Query-only commands
            .copy,
            .selectAll,
            => false,
            else => true,
        };
    }
};

/// Command category for organization
pub const CommandCategory = enum {
    formatting,
    font,
    alignment,
    list,
    indentation,
    structure,
    link,
    media,
    clipboard,
    history,
    selection,
    other,
};

/// Get command category
pub fn getCategory(command: Command) CommandCategory {
    return switch (command) {
        .bold, .italic, .underline, .strikeThrough, .subscript, .superscript, .removeFormat => .formatting,
        .fontName, .fontSize, .foreColor, .backColor, .hiliteColor => .font,
        .justifyLeft, .justifyCenter, .justifyRight, .justifyFull => .alignment,
        .insertOrderedList, .insertUnorderedList => .list,
        .indent, .outdent => .indentation,
        .insertParagraph, .insertLineBreak, .insertHorizontalRule, .formatBlock => .structure,
        .createLink, .unlink => .link,
        .insertImage, .insertHTML, .insertText => .media,
        .copy, .cut, .paste => .clipboard,
        .undo, .redo => .history,
        .selectAll, .delete, .forwardDelete => .selection,
        else => .other,
    };
}

/// Map from string to Command for efficient lookup
const string_to_command = std.StaticStringMap(Command).initComptime(.{
    // Formatting
    .{ "bold", .bold },
    .{ "italic", .italic },
    .{ "underline", .underline },
    .{ "strikethrough", .strikeThrough }, // lowercase variant
    .{ "strikeThrough", .strikeThrough },
    .{ "subscript", .subscript },
    .{ "superscript", .superscript },
    .{ "removeformat", .removeFormat },
    .{ "removeFormat", .removeFormat },

    // Font
    .{ "fontname", .fontName },
    .{ "fontName", .fontName },
    .{ "fontsize", .fontSize },
    .{ "fontSize", .fontSize },
    .{ "forecolor", .foreColor },
    .{ "foreColor", .foreColor },
    .{ "backcolor", .backColor },
    .{ "backColor", .backColor },
    .{ "hilitecolor", .hiliteColor },
    .{ "hiliteColor", .hiliteColor },

    // Alignment
    .{ "justifyleft", .justifyLeft },
    .{ "justifyLeft", .justifyLeft },
    .{ "justifycenter", .justifyCenter },
    .{ "justifyCenter", .justifyCenter },
    .{ "justifyright", .justifyRight },
    .{ "justifyRight", .justifyRight },
    .{ "justifyfull", .justifyFull },
    .{ "justifyFull", .justifyFull },

    // Lists
    .{ "insertorderedlist", .insertOrderedList },
    .{ "insertOrderedList", .insertOrderedList },
    .{ "insertunorderedlist", .insertUnorderedList },
    .{ "insertUnorderedList", .insertUnorderedList },

    // Indentation
    .{ "indent", .indent },
    .{ "outdent", .outdent },

    // Structure
    .{ "insertparagraph", .insertParagraph },
    .{ "insertParagraph", .insertParagraph },
    .{ "insertlinebreak", .insertLineBreak },
    .{ "insertLineBreak", .insertLineBreak },
    .{ "inserthorizontalrule", .insertHorizontalRule },
    .{ "insertHorizontalRule", .insertHorizontalRule },
    .{ "formatblock", .formatBlock },
    .{ "formatBlock", .formatBlock },

    // Links
    .{ "createlink", .createLink },
    .{ "createLink", .createLink },
    .{ "unlink", .unlink },

    // Media
    .{ "insertimage", .insertImage },
    .{ "insertImage", .insertImage },
    .{ "inserthtml", .insertHTML },
    .{ "insertHTML", .insertHTML },
    .{ "inserttext", .insertText },
    .{ "insertText", .insertText },

    // Clipboard
    .{ "copy", .copy },
    .{ "cut", .cut },
    .{ "paste", .paste },

    // History
    .{ "undo", .undo },
    .{ "redo", .redo },

    // Selection
    .{ "selectall", .selectAll },
    .{ "selectAll", .selectAll },
    .{ "delete", .delete },
    .{ "forwarddelete", .forwardDelete },
    .{ "forwardDelete", .forwardDelete },

    // Other
    .{ "enableabsolutepositioneditor", .enableAbsolutePositionEditor },
    .{ "enableAbsolutePositionEditor", .enableAbsolutePositionEditor },
    .{ "enableinlinetableediting", .enableInlineTableEditing },
    .{ "enableInlineTableEditing", .enableInlineTableEditing },
    .{ "enableobjectresizing", .enableObjectResizing },
    .{ "enableObjectResizing", .enableObjectResizing },
    .{ "defaultparagraphseparator", .defaultParagraphSeparator },
    .{ "defaultParagraphSeparator", .defaultParagraphSeparator },
    .{ "stylewithcss", .styleWithCSS },
    .{ "styleWithCSS", .styleWithCSS },
    .{ "contentreadonly", .contentReadOnly },
    .{ "contentReadOnly", .contentReadOnly },
});

test "Command.fromString" {
    const testing = std.testing;

    try testing.expectEqual(Command.bold, Command.fromString("bold").?);
    try testing.expectEqual(Command.italic, Command.fromString("italic").?);
    try testing.expectEqual(Command.strikeThrough, Command.fromString("strikeThrough").?);
    try testing.expectEqual(Command.strikeThrough, Command.fromString("strikethrough").?);
    try testing.expect(Command.fromString("unknown") == null);
}

test "Command.toString" {
    const testing = std.testing;

    try testing.expectEqualStrings("bold", Command.bold.toString());
    try testing.expectEqualStrings("strikeThrough", Command.strikeThrough.toString());
}

test "Command.requiresValue" {
    const testing = std.testing;

    try testing.expect(Command.fontName.requiresValue());
    try testing.expect(Command.createLink.requiresValue());
    try testing.expect(!Command.bold.requiresValue());
    try testing.expect(!Command.undo.requiresValue());
}

test "Command.isToggle" {
    const testing = std.testing;

    try testing.expect(Command.bold.isToggle());
    try testing.expect(Command.italic.isToggle());
    try testing.expect(!Command.fontName.isToggle());
    try testing.expect(!Command.copy.isToggle());
}
