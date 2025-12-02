//! Document Write Support
//!
//! Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html
//! HTML Standard §8.4 "Dynamic markup insertion"
//!
//! This module provides support for the document.write() and document.writeln()
//! methods, which allow scripts to dynamically insert content into a document
//! while it is being parsed.
//!
//! NOTE: Full document.write() support requires significant changes to the
//! input stream and parser to support:
//! 1. An "insertion point" in the input stream
//! 2. Dynamic insertion of strings at the insertion point
//! 3. Script-created parser tracking
//! 4. Parser pause flag
//! 5. Nested write handling
//!
//! This implementation provides a simplified API for the common case where
//! document.write() is called after initial parsing is complete (which opens
//! a new parser).

const std = @import("std");
const Allocator = std.mem.Allocator;

const TreeBuilder = @import("tree_builder.zig").TreeBuilder;
const TreeNode = @import("tree_builder.zig").TreeNode;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const InputStream = @import("input_stream.zig").InputStream;

/// Represents the state needed for document.write() support.
pub const DocumentWriteState = struct {
    /// The allocator for dynamic memory.
    allocator: Allocator,

    /// Whether this is a script-created parser.
    /// Script-created parsers can be closed by document.close().
    is_script_created: bool,

    /// The throw-on-dynamic-markup-insertion counter.
    /// When > 0, document.open/write/close throw InvalidStateError.
    throw_on_dynamic_markup_insertion_counter: u32,

    /// The ignore-destructive-writes counter.
    /// When > 0, document.write() that would call open() is ignored.
    ignore_destructive_writes_counter: u32,

    /// Whether the active parser was aborted.
    active_parser_was_aborted: bool,

    /// The unload counter.
    unload_counter: u32,

    /// The insertion point position (undefined if no parser).
    /// When defined, points to where new content should be inserted.
    insertion_point: ?usize,

    /// Accumulated write buffer.
    /// Content written via document.write() before explicit close.
    write_buffer: std.ArrayList(u8),

    /// Initialize document write state.
    pub fn init(allocator: Allocator) DocumentWriteState {
        return .{
            .allocator = allocator,
            .is_script_created = false,
            .throw_on_dynamic_markup_insertion_counter = 0,
            .ignore_destructive_writes_counter = 0,
            .active_parser_was_aborted = false,
            .unload_counter = 0,
            .insertion_point = null,
            .write_buffer = std.ArrayList(u8).init(allocator),
        };
    }

    /// Free resources.
    pub fn deinit(self: *DocumentWriteState) void {
        self.write_buffer.deinit();
    }

    /// Reset state for a new parser.
    pub fn reset(self: *DocumentWriteState) void {
        self.is_script_created = false;
        self.active_parser_was_aborted = false;
        self.insertion_point = null;
        self.write_buffer.clearRetainingCapacity();
    }
};

/// Error types for document.write operations.
pub const DocumentWriteError = error{
    /// Document is an XML document (document.write not supported).
    InvalidStateError_XMLDocument,

    /// throw-on-dynamic-markup-insertion counter is > 0.
    InvalidStateError_DynamicMarkupInsertion,

    /// Document origin doesn't match entry document origin.
    SecurityError,

    /// Out of memory.
    OutOfMemory,
};

/// Simplified document.open() implementation.
///
/// HTML Standard: The document open steps.
///
/// Note: This is a simplified version that doesn't handle all edge cases
/// like script nesting level checks, navigation, etc.
pub fn documentOpen(state: *DocumentWriteState) DocumentWriteError!void {
    // Step 2: Check throw-on-dynamic-markup-insertion counter
    if (state.throw_on_dynamic_markup_insertion_counter > 0) {
        return DocumentWriteError.InvalidStateError_DynamicMarkupInsertion;
    }

    // Steps 5-6: Check unload counter
    if (state.unload_counter > 0) {
        return; // Ignored
    }

    // Step 7: Check if active parser was aborted
    if (state.active_parser_was_aborted) {
        return; // Ignored
    }

    // Steps 9-14 would involve DOM manipulation (erase nodes, update URL, etc.)
    // For now, just reset state

    // Step 16: Create new HTML parser (script-created)
    state.is_script_created = true;

    // Step 17: Set insertion point to end of input stream
    state.insertion_point = 0;

    // Clear any buffered content
    state.write_buffer.clearRetainingCapacity();
}

/// Simplified document.write() implementation.
///
/// HTML Standard: The document write steps.
///
/// This version accumulates content in a buffer and doesn't actually
/// insert into an active parser's input stream.
pub fn documentWrite(state: *DocumentWriteState, text: []const u8) DocumentWriteError!void {
    // Step 6: Would check XML document (not applicable in our case)

    // Step 7: Check throw-on-dynamic-markup-insertion counter
    if (state.throw_on_dynamic_markup_insertion_counter > 0) {
        return DocumentWriteError.InvalidStateError_DynamicMarkupInsertion;
    }

    // Step 8: Check if active parser was aborted
    if (state.active_parser_was_aborted) {
        return; // Ignored
    }

    // Step 9: If insertion point is undefined
    if (state.insertion_point == null) {
        // Check ignore-destructive-writes counter
        if (state.ignore_destructive_writes_counter > 0 or state.unload_counter > 0) {
            return; // Ignored
        }

        // Call document.open() implicitly
        try documentOpen(state);
    }

    // Step 10: Insert string into input stream at insertion point
    // For now, we just append to the buffer
    try state.write_buffer.appendSlice(text);
}

/// Simplified document.writeln() implementation.
///
/// Same as document.write() but appends a newline.
pub fn documentWriteln(state: *DocumentWriteState, text: []const u8) DocumentWriteError!void {
    try documentWrite(state, text);
    try state.write_buffer.append('\n');
}

/// Simplified document.close() implementation.
///
/// HTML Standard: The close() method.
pub fn documentClose(state: *DocumentWriteState) DocumentWriteError!void {
    // Step 2: Check throw-on-dynamic-markup-insertion counter
    if (state.throw_on_dynamic_markup_insertion_counter > 0) {
        return DocumentWriteError.InvalidStateError_DynamicMarkupInsertion;
    }

    // Step 3: If no script-created parser, return
    if (!state.is_script_created) {
        return;
    }

    // Step 4: Insert explicit EOF at end of input stream
    // (In our case, we'll just mark the insertion point as undefined)
    state.insertion_point = null;

    // Steps 5-6: Would run tokenizer on accumulated content
    // This is where we'd actually parse the buffered content
}

/// Get the accumulated content from document.write() calls.
///
/// This returns the content that would be parsed when document.close() is called.
pub fn getWriteBuffer(state: *const DocumentWriteState) []const u8 {
    return state.write_buffer.items;
}

/// Parse content accumulated via document.write() after close.
///
/// This is a convenience function that takes the write buffer and parses it.
/// In a real implementation, this would happen incrementally as content is written.
pub fn parseWriteBuffer(allocator: Allocator, state: *const DocumentWriteState) !*TreeBuilder {
    const fragment_parser = @import("fragment_parser.zig");
    return try fragment_parser.parseHTMLFromString(allocator, state.write_buffer.items);
}

// ============================================================================
// Tests
// ============================================================================

test "DocumentWriteState - basic write" {
    const allocator = std.testing.allocator;

    var state = DocumentWriteState.init(allocator);
    defer state.deinit();

    // Write should implicitly open
    try documentWrite(&state, "Hello");
    try std.testing.expect(state.is_script_created);
    try std.testing.expect(state.insertion_point != null);
    try std.testing.expectEqualStrings("Hello", getWriteBuffer(&state));

    // Write more
    try documentWrite(&state, ", World!");
    try std.testing.expectEqualStrings("Hello, World!", getWriteBuffer(&state));
}

test "DocumentWriteState - writeln" {
    const allocator = std.testing.allocator;

    var state = DocumentWriteState.init(allocator);
    defer state.deinit();

    try documentWriteln(&state, "Line 1");
    try documentWriteln(&state, "Line 2");

    try std.testing.expectEqualStrings("Line 1\nLine 2\n", getWriteBuffer(&state));
}

test "DocumentWriteState - open and close" {
    const allocator = std.testing.allocator;

    var state = DocumentWriteState.init(allocator);
    defer state.deinit();

    // Explicit open
    try documentOpen(&state);
    try std.testing.expect(state.is_script_created);
    try std.testing.expect(state.insertion_point != null);

    // Write some content
    try documentWrite(&state, "<p>Test</p>");

    // Close
    try documentClose(&state);
    try std.testing.expect(state.insertion_point == null);

    // Content should still be available
    try std.testing.expectEqualStrings("<p>Test</p>", getWriteBuffer(&state));
}

test "DocumentWriteState - throw-on-dynamic-markup-insertion" {
    const allocator = std.testing.allocator;

    var state = DocumentWriteState.init(allocator);
    defer state.deinit();

    // Set counter
    state.throw_on_dynamic_markup_insertion_counter = 1;

    // All operations should fail
    try std.testing.expectError(
        DocumentWriteError.InvalidStateError_DynamicMarkupInsertion,
        documentOpen(&state),
    );
    try std.testing.expectError(
        DocumentWriteError.InvalidStateError_DynamicMarkupInsertion,
        documentWrite(&state, "test"),
    );
    try std.testing.expectError(
        DocumentWriteError.InvalidStateError_DynamicMarkupInsertion,
        documentClose(&state),
    );
}

test "DocumentWriteState - ignore when aborted" {
    const allocator = std.testing.allocator;

    var state = DocumentWriteState.init(allocator);
    defer state.deinit();

    // Set aborted flag
    state.active_parser_was_aborted = true;

    // Write should be ignored (no error, but nothing written)
    try documentWrite(&state, "ignored");
    try std.testing.expectEqualStrings("", getWriteBuffer(&state));
}

test "DocumentWriteState - ignore destructive writes during unload" {
    const allocator = std.testing.allocator;

    var state = DocumentWriteState.init(allocator);
    defer state.deinit();

    // Set unload counter
    state.unload_counter = 1;

    // Write should be ignored
    try documentWrite(&state, "ignored");
    try std.testing.expectEqualStrings("", getWriteBuffer(&state));
}
