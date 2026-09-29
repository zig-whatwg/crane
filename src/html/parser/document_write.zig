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
            .write_buffer = .empty,
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

/// The HTML parser's input stream, into which document.write() inserts.
///
/// Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-input-byte-stream
/// "The insertion point is the position (just before a character or just
///  before the end of the input stream) where content inserted using
///  document.write() is actually inserted. The insertion point is relative to
///  the position of the character immediately after it, it is not an absolute
///  offset into the input stream. Initially, the insertion point is undefined."
///
/// The stream is one byte buffer: the document's bytes, with everything
/// document.write() inserted spliced in where it was inserted. The tokenizer
/// reads it through its ordinary InputStream, whose `data` is kept a view of
/// the buffer - so the tokenizer's lookahead and batching work on written
/// input exactly as on the document's own. (The manager this replaces kept
/// insertions in a side list, which disabled both: every DOCTYPE in a frame
/// parsed as a bogus comment.)
///
/// An insertion point is a byte offset. Because a character can only be
/// inserted at the current insertion point, only the marks at or after it
/// move: the saved insertion points of enclosing script end tags, and the
/// limits enclosing document.write() calls parse to (`stop_at`).
pub const InputStreamManager = struct {
    allocator: Allocator,

    /// The input stream's bytes.
    buffer: std.ArrayListUnmanaged(u8) = .empty,

    /// The tokenizer reading the stream, whose InputStream `data` is a view
    /// of `buffer` (see `sync`).
    tokenizer: ?*Tokenizer = null,

    /// The insertion point, or null for "undefined".
    insertion_point: ?usize = null,

    /// Insertion points saved by the script end-tag steps ("Let the old
    /// insertion point have the same value as the current insertion point"),
    /// innermost last.
    saved_insertion_points: std.ArrayListUnmanaged(?usize) = .empty,

    /// While document.write()'s inserted characters are being processed, the
    /// tokenizer stops here - "stopping when the tokenizer reaches the
    /// insertion point". Null: it may read to the end of the buffer.
    stop_at: ?usize = null,

    /// The limits of enclosing document.write() calls, innermost last.
    saved_stops: std.ArrayListUnmanaged(?usize) = .empty,

    /// The end of the buffer is the end of the input: the tokenizer meets EOF
    /// there. False for a parser that waits for more (a script-created one
    /// before document.close()), where it suspends instead.
    complete: bool = true,

    /// The parser that processes inserted characters (document write steps
    /// step 11). It runs the tree builder until the tokenizer suspends at
    /// `stop_at`, or the tree construction stage aborts it.
    processor: ?Processor = null,

    pub const Processor = struct {
        context: *anyopaque,
        process: *const fn (context: *anyopaque) void,
    };

    /// A stream holding `input`, which is complete.
    pub fn init(allocator: Allocator, input: []const u8) !InputStreamManager {
        var self = InputStreamManager{ .allocator = allocator };
        try self.buffer.appendSlice(allocator, input);
        return self;
    }

    pub fn deinit(self: *InputStreamManager) void {
        self.buffer.deinit(self.allocator);
        self.saved_insertion_points.deinit(self.allocator);
        self.saved_stops.deinit(self.allocator);
        if (self.tokenizer) |t| t.input_stream_manager = null;
        self.tokenizer = null;
    }

    /// Make `tokenizer` read this stream. It must not move afterwards.
    pub fn attach(self: *InputStreamManager, tokenizer: *Tokenizer) void {
        self.tokenizer = tokenizer;
        tokenizer.input_stream_manager = self;
        self.sync();
    }

    /// What the tokenizer may read: the buffer, up to `stop_at` when set.
    pub fn readable(self: *const InputStreamManager) []const u8 {
        const end = @min(self.stop_at orelse self.buffer.items.len, self.buffer.items.len);
        return self.buffer.items[0..end];
    }

    /// Whether running out of readable input means EOF, rather than waiting
    /// for more.
    pub fn endIsEof(self: *const InputStreamManager) bool {
        return self.complete and self.stop_at == null;
    }

    /// Point the tokenizer's view at the buffer again, after it changed.
    pub fn sync(self: *InputStreamManager) void {
        const tokenizer = self.tokenizer orelse return;
        tokenizer.input.data = self.readable();
    }

    /// "Insert input into the input stream just before the insertion point."
    /// With no insertion point, nothing is inserted.
    pub fn insert(self: *InputStreamManager, content: []const u8) !void {
        const at = self.insertion_point orelse return;
        if (content.len == 0) return;
        try self.buffer.insertSlice(self.allocator, at, content);

        // The insertion point stays just before the character after it.
        self.insertion_point = at + content.len;
        // So does every mark at or after it.
        for (self.saved_insertion_points.items) |*mark| shift(mark, at, content.len);
        for (self.saved_stops.items) |*mark| shift(mark, at, content.len);
        shift(&self.stop_at, at, content.len);
        self.sync();
    }

    fn shift(mark: *?usize, at: usize, len: usize) void {
        if (mark.*) |m| {
            if (m >= at) mark.* = m + len;
        }
    }

    /// The script end-tag steps: "Let the old insertion point have the same
    /// value as the current insertion point. Let the insertion point be just
    /// before the next input character."
    pub fn pushInsertionPoint(self: *InputStreamManager) void {
        self.saved_insertion_points.append(self.allocator, self.insertion_point) catch {
            // Out of memory: keep the insertion point as it is rather than
            // lose the one to restore.
            return;
        };
        self.insertion_point = if (self.tokenizer) |t| t.nextInputPosition() else self.buffer.items.len;
    }

    /// "Let the insertion point have the value of the old insertion point."
    pub fn popInsertionPoint(self: *InputStreamManager) void {
        self.insertion_point = self.saved_insertion_points.pop() orelse null;
    }

    /// Set the insertion point just before the next input character without
    /// saving the old one - the parser's pending parsing-blocking script
    /// steps, which make it undefined again afterwards.
    pub fn setInsertionPointAtNextInputCharacter(self: *InputStreamManager) void {
        self.insertion_point = if (self.tokenizer) |t| t.nextInputPosition() else self.buffer.items.len;
    }

    /// Document write steps step 11: "have the HTML parser process string,
    /// one code point at a time, processing resulting tokens as they are
    /// emitted, and stopping when the tokenizer reaches the insertion point or
    /// when the processing of the tokenizer is aborted by the tree
    /// construction stage."
    pub fn processInserted(self: *InputStreamManager) void {
        const processor = self.processor orelse return;
        self.saved_stops.append(self.allocator, self.stop_at) catch return;
        self.stop_at = self.insertion_point;
        self.sync();
        processor.process(processor.context);
        self.stop_at = self.saved_stops.pop() orelse null;
        self.sync();
    }

    /// Whether there is an insertion point.
    pub fn hasInsertionPoint(self: *const InputStreamManager) bool {
        return self.insertion_point != null;
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
