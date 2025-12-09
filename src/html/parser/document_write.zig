//! Document Write Support
//!
//! Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html
//! HTML Standard §8.4 "Dynamic markup insertion"
//!
//! This module provides support for the document.write() and document.writeln()
//! methods, which allow scripts to dynamically insert content into a document
//! while it is being parsed.
//!
//! ## Implementation Notes
//!
//! Full document.write() support includes:
//! 1. An "insertion point" in the input stream - position where new content is inserted
//! 2. Dynamic insertion of strings at the insertion point
//! 3. Script-created parser tracking - parsers created by document.open()
//! 4. Parser pause flag - to handle nested script execution
//! 5. Nested write handling - document.write() during script execution
//!
//! This implementation supports two modes:
//!
//! **After-parsing mode** (common case): When document.write() is called after
//! initial parsing is complete, it implicitly calls document.open() which creates
//! a new parser. Content is accumulated in a buffer and parsed when document.close()
//! is called.
//!
//! **During-parsing mode**: When document.write() is called from a script during
//! parsing, the content is inserted at the current input stream position
//! (insertion point). This requires integration with the active parser's input stream.

const std = @import("std");
const Allocator = std.mem.Allocator;

const TreeBuilder = @import("tree_builder.zig").TreeBuilder;
const TreeNode = @import("tree_builder.zig").TreeNode;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const InputStream = @import("input_stream.zig").InputStream;

/// Represents the state needed for document.write() support.
///
/// HTML Standard §8.4: This tracks the state required for dynamic markup insertion
/// APIs like document.write(), document.writeln(), document.open(), and document.close().
pub const DocumentWriteState = struct {
    /// The allocator for dynamic memory.
    allocator: Allocator,

    /// Whether this is a script-created parser.
    /// HTML Standard: Script-created parsers can be closed by document.close().
    /// They are created when document.open() is called (implicitly or explicitly).
    is_script_created: bool,

    /// The throw-on-dynamic-markup-insertion counter.
    /// HTML Standard: When > 0, document.open/write/close throw InvalidStateError.
    /// This is incremented during custom element reactions and other contexts
    /// where dynamic markup insertion is not allowed.
    throw_on_dynamic_markup_insertion_counter: u32,

    /// The ignore-destructive-writes counter.
    /// HTML Standard: When > 0, document.write() that would call open() is ignored.
    /// This prevents certain circular scenarios during parsing.
    ignore_destructive_writes_counter: u32,

    /// Whether the active parser was aborted.
    /// HTML Standard: Set when navigation occurs, causing the parser to be aborted.
    active_parser_was_aborted: bool,

    /// The unload counter.
    /// HTML Standard: When > 0 (during beforeunload/unload), certain operations
    /// like destructive writes are ignored.
    unload_counter: u32,

    /// The insertion point position (undefined if no parser).
    /// HTML Standard: Points to where new content should be inserted in the input stream.
    /// When undefined, there is no active parser or the parser has finished.
    insertion_point: ?usize,

    /// Accumulated write buffer.
    /// Content written via document.write() in after-parsing mode.
    /// In during-parsing mode, this would be inserted into the input stream directly.
    write_buffer: std.ArrayList(u8),

    /// Script nesting level.
    /// HTML Standard: Tracks nested script execution for document.write() handling.
    /// document.write() behaves differently based on this level.
    script_nesting_level: u32,

    /// Parser pause flag.
    /// HTML Standard: Set while waiting for a script to finish loading/executing.
    parser_pause_flag: bool,

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
            .write_buffer = .{},
            .script_nesting_level = 0,
            .parser_pause_flag = false,
        };
    }

    /// Free resources.
    pub fn deinit(self: *DocumentWriteState) void {
        self.write_buffer.deinit(self.allocator);
    }

    /// Reset state for a new parser.
    pub fn reset(self: *DocumentWriteState) void {
        self.is_script_created = false;
        self.active_parser_was_aborted = false;
        self.insertion_point = null;
        self.write_buffer.clearRetainingCapacity();
        self.script_nesting_level = 0;
        self.parser_pause_flag = false;
    }

    /// Check if dynamic markup insertion is currently allowed.
    pub fn isDynamicMarkupInsertionAllowed(self: *const DocumentWriteState) bool {
        return self.throw_on_dynamic_markup_insertion_counter == 0;
    }

    /// Check if there is an active parser.
    pub fn hasActiveParser(self: *const DocumentWriteState) bool {
        return self.insertion_point != null;
    }

    /// Increment script nesting level (called when starting script execution).
    pub fn enterScriptExecution(self: *DocumentWriteState) void {
        self.script_nesting_level += 1;
    }

    /// Decrement script nesting level (called when ending script execution).
    pub fn exitScriptExecution(self: *DocumentWriteState) void {
        if (self.script_nesting_level > 0) {
            self.script_nesting_level -= 1;
        }
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
    try state.write_buffer.appendSlice(state.allocator, text);
}

/// Simplified document.writeln() implementation.
///
/// Same as document.write() but appends a newline.
pub fn documentWriteln(state: *DocumentWriteState, text: []const u8) DocumentWriteError!void {
    try documentWrite(state, text);
    try state.write_buffer.append(state.allocator, '\n');
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
// Input Stream Manager for document.write() Integration
// ============================================================================

/// Pending insertion entry for document.write() content.
pub const PendingInsertion = struct {
    /// Position in the logical stream where this insertion begins.
    position: usize,

    /// The content to insert.
    content: []const u8,

    /// Current read position within this insertion.
    read_offset: usize,
};

/// Input stream manager that supports dynamic content insertion.
///
/// HTML Standard §13.2.3.1: The insertion point is a position in the input stream
/// where document.write() content is inserted during parsing.
///
/// This manager wraps an original input stream and handles insertions from
/// document.write() calls during script execution.
pub const InputStreamManager = struct {
    /// Allocator for dynamic memory.
    allocator: Allocator,

    /// Original document source (UTF-8 encoded).
    original_input: []const u8,

    /// Current position in the original input.
    original_position: usize,

    /// Logical position (accounts for insertions).
    logical_position: usize,

    /// Pending insertions from document.write().
    pending_insertions: std.ArrayList(PendingInsertion),

    /// Currently active insertion (if reading from inserted content).
    active_insertion_index: ?usize,

    /// Current insertion point position (null = no active parser).
    /// HTML Standard: Points to where new content should be inserted.
    insertion_point: ?usize,

    /// Line number (1-based).
    line: u32,

    /// Column number (1-based).
    column: u32,

    /// Whether we just saw a CR (for CRLF handling).
    last_was_cr: bool,

    /// Initialize an input stream manager.
    pub fn init(allocator: Allocator, input: []const u8) InputStreamManager {
        return .{
            .allocator = allocator,
            .original_input = input,
            .original_position = 0,
            .logical_position = 0,
            .pending_insertions = .{},
            .active_insertion_index = null,
            .insertion_point = 0, // Start at beginning
            .line = 1,
            .column = 1,
            .last_was_cr = false,
        };
    }

    /// Free resources.
    pub fn deinit(self: *InputStreamManager) void {
        // Free allocated content strings
        for (self.pending_insertions.items) |insertion| {
            self.allocator.free(insertion.content);
        }
        self.pending_insertions.deinit(self.allocator);
    }

    /// Insert content at the current insertion point.
    ///
    /// HTML Standard §13.2.3.1: "Insert the string input into the input stream
    /// just before the insertion point."
    pub fn insert(self: *InputStreamManager, content: []const u8) !void {
        if (self.insertion_point == null) {
            return; // No active parser
        }

        if (content.len == 0) {
            return; // Nothing to insert
        }

        // Copy content (we own it)
        const owned_content = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(owned_content);

        // Insert at current insertion point
        const insertion = PendingInsertion{
            .position = self.insertion_point.?,
            .content = owned_content,
            .read_offset = 0,
        };

        // Insert sorted by position (later insertions at same position come after)
        var insert_idx: usize = self.pending_insertions.items.len;
        for (self.pending_insertions.items, 0..) |existing, i| {
            if (existing.position > insertion.position) {
                insert_idx = i;
                break;
            }
        }

        try self.pending_insertions.insert(self.allocator, insert_idx, insertion);
    }

    /// Get the next character from the stream (considering insertions).
    ///
    /// Returns the next Unicode code point, or null for EOF.
    pub fn getNextChar(self: *InputStreamManager) ?u21 {
        // First, check if we're reading from an active insertion
        if (self.active_insertion_index) |idx| {
            if (idx < self.pending_insertions.items.len) {
                const insertion = &self.pending_insertions.items[idx];
                if (insertion.read_offset < insertion.content.len) {
                    const result = self.decodeUtf8FromSlice(insertion.content, insertion.read_offset);
                    if (result.codepoint) |cp| {
                        insertion.read_offset += result.bytes_consumed;
                        self.logical_position += 1;
                        self.updateLineColumn(cp);
                        return self.normalizeNewline(cp);
                    }
                }
            }
            // Finished with this insertion, move to next or back to original
            self.active_insertion_index = null;
        }

        // Check for insertions at current logical position
        for (self.pending_insertions.items, 0..) |*insertion, i| {
            if (insertion.position == self.logical_position and insertion.read_offset < insertion.content.len) {
                self.active_insertion_index = i;
                return self.getNextChar(); // Recurse to read from insertion
            }
        }

        // Read from original input
        if (self.original_position >= self.original_input.len) {
            return null; // EOF
        }

        const result = self.decodeUtf8FromSlice(self.original_input, self.original_position);
        if (result.codepoint) |cp| {
            self.original_position += result.bytes_consumed;
            self.logical_position += 1;

            // Update insertion point if still defined
            if (self.insertion_point) |ip| {
                if (ip < self.logical_position) {
                    self.insertion_point = self.logical_position;
                }
            }

            self.updateLineColumn(cp);
            return self.normalizeNewline(cp);
        }

        // Invalid UTF-8 - return replacement character
        self.original_position += 1;
        self.logical_position += 1;
        self.column += 1;
        return 0xFFFD;
    }

    /// Normalize newlines per HTML spec.
    fn normalizeNewline(self: *InputStreamManager, cp: u21) u21 {
        if (cp == 0x0D) {
            // CR -> LF
            self.last_was_cr = true;
            return 0x0A;
        } else if (cp == 0x0A and self.last_was_cr) {
            // LF after CR - skip it (CRLF already emitted as single LF)
            self.last_was_cr = false;
            return self.getNextChar() orelse 0x0A; // Recurse, or return LF if EOF
        }
        self.last_was_cr = false;
        return cp;
    }

    /// Update line/column tracking.
    fn updateLineColumn(self: *InputStreamManager, cp: u21) void {
        if (cp == 0x0A or cp == 0x0D) {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
    }

    /// Decode UTF-8 from a slice at the given offset.
    fn decodeUtf8FromSlice(self: *InputStreamManager, data: []const u8, offset: usize) struct { codepoint: ?u21, bytes_consumed: usize } {
        _ = self;
        if (offset >= data.len) {
            return .{ .codepoint = null, .bytes_consumed = 0 };
        }

        const first = data[offset];

        // Single byte (ASCII)
        if (first & 0x80 == 0) {
            return .{ .codepoint = first, .bytes_consumed = 1 };
        }

        // Multi-byte sequence
        const len: usize = if (first & 0xE0 == 0xC0)
            2
        else if (first & 0xF0 == 0xE0)
            3
        else if (first & 0xF8 == 0xF0)
            4
        else
            return .{ .codepoint = null, .bytes_consumed = 1 };

        if (offset + len > data.len) {
            return .{ .codepoint = null, .bytes_consumed = 1 };
        }

        var cp: u21 = switch (len) {
            2 => @as(u21, first & 0x1F),
            3 => @as(u21, first & 0x0F),
            4 => @as(u21, first & 0x07),
            else => unreachable,
        };

        for (1..len) |i| {
            const byte = data[offset + i];
            if (byte & 0xC0 != 0x80) {
                return .{ .codepoint = null, .bytes_consumed = 1 };
            }
            cp = (cp << 6) | @as(u21, byte & 0x3F);
        }

        // Check for overlong encoding
        const min_cp: u21 = switch (len) {
            2 => 0x80,
            3 => 0x800,
            4 => 0x10000,
            else => unreachable,
        };

        if (cp < min_cp or cp > 0x10FFFF) {
            return .{ .codepoint = null, .bytes_consumed = len };
        }

        return .{ .codepoint = cp, .bytes_consumed = len };
    }

    /// Check if at end of input (including insertions).
    pub fn isAtEnd(self: *const InputStreamManager) bool {
        // Check if there are unread insertions
        for (self.pending_insertions.items) |insertion| {
            if (insertion.read_offset < insertion.content.len) {
                return false;
            }
        }
        return self.original_position >= self.original_input.len;
    }

    /// Get current position info.
    pub fn getPosition(self: *const InputStreamManager) struct { line: u32, column: u32, logical_offset: usize } {
        return .{
            .line = self.line,
            .column = self.column,
            .logical_offset = self.logical_position,
        };
    }

    /// Set the insertion point (called when parser reaches a specific position).
    pub fn setInsertionPoint(self: *InputStreamManager, position: ?usize) void {
        self.insertion_point = position;
    }

    /// Get the current insertion point.
    pub fn getInsertionPoint(self: *const InputStreamManager) ?usize {
        return self.insertion_point;
    }

    /// Check if there is an active insertion point.
    pub fn hasInsertionPoint(self: *const InputStreamManager) bool {
        return self.insertion_point != null;
    }

    /// Clear the insertion point (called when parsing completes or is aborted).
    pub fn clearInsertionPoint(self: *InputStreamManager) void {
        self.insertion_point = null;
    }
};

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

// ============================================================================
// InputStreamManager Tests
// ============================================================================

test "InputStreamManager - basic reading without insertions" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "hello");
    defer manager.deinit();

    try std.testing.expectEqual(@as(u21, 'h'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'e'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'l'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'l'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'o'), manager.getNextChar().?);
    try std.testing.expect(manager.getNextChar() == null); // EOF
}

test "InputStreamManager - insertion at beginning" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "world");
    defer manager.deinit();

    // Insert at position 0 (beginning)
    manager.setInsertionPoint(0);
    try manager.insert("hello ");

    // Should read: "hello world"
    try std.testing.expectEqual(@as(u21, 'h'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'e'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'l'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'l'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'o'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, ' '), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'w'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'o'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'r'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'l'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'd'), manager.getNextChar().?);
    try std.testing.expect(manager.getNextChar() == null);
}

test "InputStreamManager - insertion mid-stream" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "ab");
    defer manager.deinit();

    // Read first char
    try std.testing.expectEqual(@as(u21, 'a'), manager.getNextChar().?);

    // Insert at current position (after 'a')
    manager.setInsertionPoint(1);
    try manager.insert("XY");

    // Should read: "XY" then "b"
    try std.testing.expectEqual(@as(u21, 'X'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'Y'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'b'), manager.getNextChar().?);
    try std.testing.expect(manager.getNextChar() == null);
}

test "InputStreamManager - multiple insertions" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "ac");
    defer manager.deinit();

    // Insert 'b' at position 1
    manager.setInsertionPoint(1);
    try manager.insert("b");

    // Read everything
    try std.testing.expectEqual(@as(u21, 'a'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'b'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'c'), manager.getNextChar().?);
    try std.testing.expect(manager.getNextChar() == null);
}

test "InputStreamManager - newline normalization" {
    const allocator = std.testing.allocator;

    // Test CR -> LF
    var manager1 = InputStreamManager.init(allocator, "a\rb");
    defer manager1.deinit();

    try std.testing.expectEqual(@as(u21, 'a'), manager1.getNextChar().?);
    try std.testing.expectEqual(@as(u21, '\n'), manager1.getNextChar().?); // CR normalized
    try std.testing.expectEqual(@as(u21, 'b'), manager1.getNextChar().?);
}

test "InputStreamManager - UTF-8 decoding" {
    const allocator = std.testing.allocator;

    // Test multi-byte UTF-8 (€ = U+20AC = E2 82 AC)
    var manager = InputStreamManager.init(allocator, "\xE2\x82\xAC");
    defer manager.deinit();

    try std.testing.expectEqual(@as(u21, 0x20AC), manager.getNextChar().?);
    try std.testing.expect(manager.getNextChar() == null);
}

test "InputStreamManager - insertion point tracking" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "test");
    defer manager.deinit();

    try std.testing.expect(manager.hasInsertionPoint());
    try std.testing.expectEqual(@as(?usize, 0), manager.getInsertionPoint());

    manager.clearInsertionPoint();
    try std.testing.expect(!manager.hasInsertionPoint());
    try std.testing.expectEqual(@as(?usize, null), manager.getInsertionPoint());

    manager.setInsertionPoint(5);
    try std.testing.expect(manager.hasInsertionPoint());
    try std.testing.expectEqual(@as(?usize, 5), manager.getInsertionPoint());
}

test "InputStreamManager - no insertion when no insertion point" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "test");
    defer manager.deinit();

    // Clear insertion point
    manager.clearInsertionPoint();

    // Insert should be ignored
    try manager.insert("ignored");

    // Should just read original
    try std.testing.expectEqual(@as(u21, 't'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 'e'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 's'), manager.getNextChar().?);
    try std.testing.expectEqual(@as(u21, 't'), manager.getNextChar().?);
    try std.testing.expect(manager.getNextChar() == null);
}

test "InputStreamManager - line column tracking" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "ab\ncd");
    defer manager.deinit();

    _ = manager.getNextChar(); // a
    const pos1 = manager.getPosition();
    try std.testing.expectEqual(@as(u32, 1), pos1.line);
    try std.testing.expectEqual(@as(u32, 2), pos1.column);

    _ = manager.getNextChar(); // b
    _ = manager.getNextChar(); // \n

    const pos2 = manager.getPosition();
    try std.testing.expectEqual(@as(u32, 2), pos2.line);
    try std.testing.expectEqual(@as(u32, 1), pos2.column);
}

test "InputStreamManager - isAtEnd" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "a");
    defer manager.deinit();

    try std.testing.expect(!manager.isAtEnd());
    _ = manager.getNextChar();
    try std.testing.expect(manager.isAtEnd());
}

// ============================================================================
// Tokenizer Integration Tests
// ============================================================================

test "Tokenizer with InputStreamManager - basic parsing" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "<p>Hello</p>");
    defer manager.deinit();

    var tokenizer = Tokenizer.initWithStreamManager(allocator, &manager);
    defer tokenizer.deinit();

    // Should parse start tag
    const token1 = try tokenizer.nextToken();
    try std.testing.expect(token1 != null);
    try std.testing.expect(token1.? == .start_tag);
    try std.testing.expectEqualStrings("p", token1.?.start_tag.getTagName());

    // Should parse text
    const token2 = try tokenizer.nextToken();
    try std.testing.expect(token2 != null);
    // Could be character or text_run depending on batch optimization
    switch (token2.?) {
        .character => |c| try std.testing.expectEqual(@as(u21, 'H'), c),
        .text_run => |tr| try std.testing.expectEqualStrings("Hello", tr.data),
        else => return error.UnexpectedToken,
    }
}

test "Tokenizer with InputStreamManager - document.write simulation" {
    const allocator = std.testing.allocator;

    // Start with partial HTML
    var manager = InputStreamManager.init(allocator, "<div></div>");
    defer manager.deinit();

    var tokenizer = Tokenizer.initWithStreamManager(allocator, &manager);
    defer tokenizer.deinit();

    // Read <div>
    const token1 = try tokenizer.nextToken();
    try std.testing.expect(token1 != null);
    try std.testing.expect(token1.? == .start_tag);
    try std.testing.expectEqualStrings("div", token1.?.start_tag.getTagName());

    // Simulate document.write() inserting content at current position
    // In a real scenario, this would happen during script execution
    // Note: The current logical position is after <div> (position 5)
    const current_pos = manager.logical_position;
    manager.setInsertionPoint(current_pos);
    try manager.insert("<span>inserted</span>");

    // The tokenizer should now see the inserted content
    const token2 = try tokenizer.nextToken();
    try std.testing.expect(token2 != null);
    try std.testing.expect(token2.? == .start_tag);
    try std.testing.expectEqualStrings("span", token2.?.start_tag.getTagName());
}

test "TreeBuilder with InputStreamManager - hasInsertionPoint" {
    const allocator = std.testing.allocator;

    var manager = InputStreamManager.init(allocator, "<html></html>");
    defer manager.deinit();

    var tokenizer = Tokenizer.initWithStreamManager(allocator, &manager);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.initWithStreamManager(allocator, &tokenizer, &manager);
    defer builder.deinit();

    // Should have insertion point initially
    try std.testing.expect(builder.hasInsertionPoint());
    try std.testing.expect(builder.supportsDocumentWrite());

    // Clear insertion point
    builder.clearInsertionPoint();
    try std.testing.expect(!builder.hasInsertionPoint());
    try std.testing.expect(!builder.supportsDocumentWrite());
}
