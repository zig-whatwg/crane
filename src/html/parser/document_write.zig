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
//! a persistent script-created parser. Each write resumes that parser at its
//! insertion point; document.close() supplies explicit EOF.
//!
//! **During-parsing mode**: When document.write() is called from a script during
//! parsing, the content is inserted at the current input stream position
//! (insertion point). This requires integration with the active parser's input stream.
//!
//! This file holds the parser's input stream, InputStreamManager. The
//! document.open()/write()/close() steps are Document.zig's call_open,
//! call_write and call_close (src/webidl/impls/), over the script-created
//! parser in html/scripted_parser.zig.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Tokenizer = @import("tokenizer.zig").Tokenizer;

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

    /// HTML "abort a parser": stop tokenization without supplying EOF.
    aborted: bool = false,

    /// Tree construction consumed explicit EOF and stopped parsing.
    eof_processed: bool = false,

    /// The associated tree construction stage's actual script nesting level.
    /// A script-created stream has an insertion point even between scripts.
    script_nesting_level: ?*const u32 = null,

    /// How many times document.write() inserted characters (`insert`): a
    /// speculative HTML parser started before an insertion reads a copy of
    /// the stream without it, and starts again (HTML 13.2.8, "start the
    /// speculative HTML parser" step 3).
    insertions: u64 = 0,

    /// The parser that processes inserted characters (document write steps
    /// step 11). It runs the tree builder until the tokenizer suspends at
    /// `stop_at`, or the tree construction stage aborts it.
    processor: ?Processor = null,

    pub const Processor = struct {
        context: *anyopaque,
        process: *const fn (context: *anyopaque) void,
        /// Keep a heap parser alive until this invocation has restored the
        /// readable limit, including any nested script's close/open calls.
        retain: ?*const fn (context: *anyopaque) void = null,
        release: ?*const fn (context: *anyopaque) void = null,
        after_process: ?*const fn (context: *anyopaque) void = null,
        abort: ?*const fn (context: *anyopaque) void = null,
        /// The parser's pending parsing-blocking script is ready: how its
        /// parser resumes when that is not `processInserted` (a fragment
        /// parser's: "execute the pending parsing-blocking scripts", then
        /// "run a fragment parser" - HTML "an end tag whose tag name is
        /// script", the fragment case).
        resume_after_blocking_script: ?*const fn (context: *anyopaque) void = null,
    };

    /// The pending parsing-blocking script of this stream's parser is ready
    /// to be parser-executed: the parser resumes, the way its processor
    /// says, or by processing what was inserted.
    pub fn resumeAfterBlockingScript(self: *InputStreamManager) void {
        if (self.processor) |processor| if (processor.resume_after_blocking_script) |resume_parser| return resume_parser(processor.context);
        self.processInserted();
    }

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
        if (self.aborted) return;
        const at = self.insertion_point orelse return;
        if (content.len == 0) return;
        try self.buffer.insertSlice(self.allocator, at, content);
        self.insertions += 1;

        // The insertion point stays just before the character after it.
        self.insertion_point = at + content.len;
        // So does every mark at or after it.
        for (self.saved_insertion_points.items) |*mark| shift(mark, at, content.len);
        for (self.saved_stops.items) |*mark| shift(mark, at, content.len);
        shift(&self.stop_at, at, content.len);
        self.sync();
    }

    /// Append `content` to the end of the input stream (HTML "stream HTML"
    /// step 12.4: a streaming fragment parser's input, which is never
    /// inserted at an insertion point). Every mark at the old end - the
    /// insertion point, the saved ones, the limit an ongoing run parses to -
    /// stays at the end, so a run in progress consumes the new input too.
    pub fn appendToEnd(self: *InputStreamManager, content: []const u8) !void {
        if (self.aborted or content.len == 0) return;
        const end = self.buffer.items.len;
        try self.buffer.appendSlice(self.allocator, content);
        const new_end = self.buffer.items.len;
        if (self.insertion_point) |point| if (point == end) {
            self.insertion_point = new_end;
        };
        for (self.saved_insertion_points.items) |*mark| moveEnd(mark, end, new_end);
        for (self.saved_stops.items) |*mark| moveEnd(mark, end, new_end);
        moveEnd(&self.stop_at, end, new_end);
        self.sync();
    }

    fn moveEnd(mark: *?usize, end: usize, new_end: usize) void {
        if (mark.*) |m| {
            if (m == end) mark.* = new_end;
        }
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
        if (processor.retain) |retain| retain(processor.context);
        defer if (processor.release) |release| release(processor.context);
        self.saved_stops.append(self.allocator, self.stop_at) catch return;
        self.stop_at = self.insertion_point;
        self.sync();
        processor.process(processor.context);
        self.stop_at = self.saved_stops.pop() orelse null;
        self.sync();
        if (processor.after_process) |after_process| after_process(processor.context);
    }

    /// Whether there is an insertion point.
    pub fn hasInsertionPoint(self: *const InputStreamManager) bool {
        return self.insertion_point != null;
    }

    pub fn isExecutingScript(self: *const InputStreamManager) bool {
        return if (self.script_nesting_level) |level| level.* > 0 else false;
    }

    /// HTML "abort a parser" step 1. Document invokes this before the
    /// interactive readiness callback; it does not finish open elements yet.
    pub fn discardInput(self: *InputStreamManager) void {
        self.aborted = true;
        self.insertion_point = null;
        const consumed = if (self.tokenizer) |tokenizer| tokenizer.nextInputPosition() else 0;
        self.buffer.shrinkRetainingCapacity(@min(consumed, self.buffer.items.len));
        for (self.saved_insertion_points.items) |*mark| mark.* = null;
        for (self.saved_stops.items) |*mark| mark.* = null;
        self.stop_at = null;
        self.sync();
    }

    /// Finish aborting after Document's interactive readiness update. The
    /// associated tree construction stage performs step 4's stack pop;
    /// Document owns the readiness updates in steps 3 and 5.
    pub fn abort(self: *InputStreamManager) void {
        self.discardInput();
        const processor = self.processor orelse return;
        const abort_parser = processor.abort orelse return;
        if (processor.retain) |retain| retain(processor.context);
        defer if (processor.release) |release| release(processor.context);
        abort_parser(processor.context);
    }
};
