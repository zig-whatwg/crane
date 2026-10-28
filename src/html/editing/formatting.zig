//! Formatting queries (html_core stubs)
//!
//! What is left of html_core's formatting stubs: the formatting queries
//! the editing module's query dispatch still reaches for a command the html
//! module does not answer. The inline formatting commands live in
//! src/html/execcommand/inline.zig and the block commands, justify
//! included, in src/html/execcommand/blocks.zig (on the generated
//! interfaces, which html_core cannot reach).
//!
//! Spec: https://w3c.github.io/editing/docs/execCommand/

const std = @import("std");
const commands = @import("commands.zig");
const executor = @import("executor.zig");

pub const Command = commands.Command;
pub const CommandResult = executor.CommandResult;
pub const DocumentHandle = executor.DocumentHandle;

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
