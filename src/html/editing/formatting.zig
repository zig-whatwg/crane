//! Alignment Commands (html_core stubs)
//!
//! What is left of html_core's formatting stubs: the justify commands and
//! the formatting queries the block commands still reach until their
//! actions move to the html module. The inline formatting commands live in
//! src/html/execcommand/inline.zig (on the generated interfaces, which
//! html_core cannot reach).
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/

const std = @import("std");
const commands = @import("commands.zig");
const executor = @import("executor.zig");

pub const Command = commands.Command;
pub const CommandResult = executor.CommandResult;
pub const DocumentHandle = executor.DocumentHandle;

/// Text alignment options
pub const Alignment = enum {
    left,
    center,
    right,
    full,

    pub fn toCssValue(self: Alignment) []const u8 {
        return switch (self) {
            .left => "left",
            .center => "center",
            .right => "right",
            .full => "justify",
        };
    }
};

/// Execute justify command
/// Sets text alignment for block containing selection
///
/// Spec: https://w3c.github.io/editing/docs/execCommand/#the-justifycenter-command
///
/// Algorithm:
/// 1. Find all block elements containing the selection
/// 2. For each block element:
///    a. If styleWithCSS is true:
///       - Set style="text-align: [left|center|right|justify]"
///    b. Otherwise:
///       - Set align="[left|center|right|justify]" attribute
/// 3. Create undo entry
///
/// Note: justifyLeft, justifyCenter, justifyRight, justifyFull all use
/// this common implementation with different alignment values.
pub fn executeJustify(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    alignment: Alignment,
) !CommandResult {
    _ = allocator;
    _ = document;

    const css_value = alignment.toCssValue();
    _ = css_value;

    // Algorithm when integrated with DOM:
    // 1. Get selection range
    // 2. Find all block-level ancestors
    // 3. For each block:
    //    a. If styleWithCSS: set style.textAlign = alignment
    //    b. Otherwise: set align attribute
    // 4. Record undo entry

    return .{ .success = true };
}

/// Execute justifyLeft command
/// Aligns block to left
pub fn executeJustifyLeft(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .left);
}

/// Execute justifyCenter command
/// Centers block
pub fn executeJustifyCenter(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .center);
}

/// Execute justifyRight command
/// Aligns block to right
pub fn executeJustifyRight(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .right);
}

/// Execute justifyFull command
/// Justifies block (full width alignment)
pub fn executeJustifyFull(allocator: std.mem.Allocator, document: DocumentHandle) !CommandResult {
    return executeJustify(allocator, document, .full);
}

// =============================================================================
// Query Functions
// =============================================================================

/// Query if formatting is active for current selection
pub fn queryFormattingState(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
) bool {
    _ = allocator;
    _ = document;

    // Implementation outline:
    // 1. Get current selection
    // 2. Check if entire selection has the formatting
    // 3. Return true only if ALL of selection is formatted

    return switch (command) {
        .bold, .italic, .underline, .strikeThrough, .subscript, .superscript => {
            // TODO: Query DOM for formatting state
            return false;
        },
        .insertOrderedList, .insertUnorderedList => {
            // Check if selection is in a list
            return false;
        },
        else => false,
    };
}

/// Query formatting value for current selection
pub fn queryFormattingValue(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
) ?[]const u8 {
    _ = allocator;
    _ = document;

    return switch (command) {
        .fontName => null, // TODO: Query current font
        .fontSize => null, // TODO: Query current size
        .foreColor => null, // TODO: Query current color
        .backColor, .hiliteColor => null, // TODO: Query current background
        .formatBlock => null, // TODO: Query current block type
        else => null,
    };
}

/// Query if formatting is indeterminate (mixed) for current selection
pub fn queryFormattingIndeterm(
    allocator: std.mem.Allocator,
    document: DocumentHandle,
    command: Command,
) bool {
    _ = allocator;
    _ = document;
    _ = command;

    // Implementation outline:
    // 1. Get current selection
    // 2. Check if some parts have formatting and some don't
    // 3. Return true if mixed

    return false;
}

// =============================================================================
// Tests
// =============================================================================

test "Alignment.toCssValue" {
    try std.testing.expectEqualStrings("left", Alignment.left.toCssValue());
    try std.testing.expectEqualStrings("center", Alignment.center.toCssValue());
    try std.testing.expectEqualStrings("right", Alignment.right.toCssValue());
    try std.testing.expectEqualStrings("justify", Alignment.full.toCssValue());
}
