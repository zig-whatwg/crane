//! HTML Tokenizer
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization
//! HTML Standard §13.2.5 "Tokenization"
//!
//! The state machine must start in the data state. Most states consume a
//! single character, which may have various side-effects, and either switches
//! the state machine to a new state to reconsume the current input character,
//! or switches it to a new state to consume the next character, or stays in
//! the same state to consume the next character.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

const State = @import("tokenizer_states.zig").State;
const Token = @import("tokens.zig").Token;
const TagToken = @import("tokens.zig").TagToken;
const DoctypeToken = @import("tokens.zig").DoctypeToken;
const CommentToken = @import("tokens.zig").CommentToken;
const InputStream = @import("input_stream.zig").InputStream;
const InputCharacter = @import("input_stream.zig").InputCharacter;
const ParseErrorCode = @import("parse_errors.zig").ParseErrorCode;
const ParseErrorCallback = @import("parse_errors.zig").ParseErrorCallback;
const entities = @import("entities.zig");
const document_write = @import("document_write.zig");
const InputStreamManager = document_write.InputStreamManager;

/// HTML Tokenizer.
///
/// Implements the tokenization stage of the HTML parsing algorithm.
pub const Tokenizer = struct {
    /// Memory allocator.
    allocator: Allocator,

    /// Input stream (for static input mode).
    input: InputStream,

    /// Input stream manager (for dynamic input mode with document.write() support).
    /// When non-null, this takes precedence over the static input.
    input_stream_manager: ?*InputStreamManager,

    /// Current tokenizer state.
    state: State,

    /// Return state for character reference processing.
    return_state: State,

    /// Current token being built.
    current_token: ?Token,

    /// Temporary buffer for various uses.
    temporary_buffer: infra.List(u8),

    /// Last emitted start tag name (for appropriate end tag check).
    last_start_tag_name: ?infra.List(u8),

    /// Character reference code being built.
    character_reference_code: u32,

    /// Queue of tokens to emit.
    token_queue: infra.List(Token),

    /// Head index into token_queue for O(1) dequeue.
    /// Tokens before this index have already been returned.
    token_queue_head: usize,

    /// Whether to reconsume the current character.
    reconsume: bool,

    /// Current input character (for reconsume).
    current_char: InputCharacter,

    /// Error callback.
    error_callback: ?ParseErrorCallback,

    /// Error context.
    error_context: ?*anyopaque,

    /// Initialize a new tokenizer with static input.
    pub fn init(allocator: Allocator, input: []const u8) Tokenizer {
        return Tokenizer{
            .allocator = allocator,
            .input = InputStream.init(input),
            .input_stream_manager = null,
            .state = .data,
            .return_state = .data,
            .current_token = null,
            .temporary_buffer = infra.List(u8).init(allocator),
            .last_start_tag_name = null,
            .character_reference_code = 0,
            .token_queue = infra.List(Token).init(allocator),
            .token_queue_head = 0,
            .reconsume = false,
            .current_char = .eof,
            .error_callback = null,
            .error_context = null,
        };
    }

    /// Initialize a new tokenizer with an InputStreamManager for document.write() support.
    ///
    /// HTML Standard §13.2.3: The input stream supports dynamic insertion of content
    /// via document.write() during script execution. This method configures the
    /// tokenizer to use an InputStreamManager instead of a static input stream.
    pub fn initWithStreamManager(allocator: Allocator, stream_manager: *InputStreamManager) Tokenizer {
        return Tokenizer{
            .allocator = allocator,
            .input = InputStream.init(""), // Unused when stream_manager is set
            .input_stream_manager = stream_manager,
            .state = .data,
            .return_state = .data,
            .current_token = null,
            .temporary_buffer = infra.List(u8).init(allocator),
            .last_start_tag_name = null,
            .character_reference_code = 0,
            .token_queue = infra.List(Token).init(allocator),
            .token_queue_head = 0,
            .reconsume = false,
            .current_char = .eof,
            .error_callback = null,
            .error_context = null,
        };
    }

    /// Get the input stream manager (if using dynamic input mode).
    pub fn getInputStreamManager(self: *Tokenizer) ?*InputStreamManager {
        return self.input_stream_manager;
    }

    /// Check if using dynamic input mode with InputStreamManager.
    pub fn hasDynamicInput(self: *const Tokenizer) bool {
        return self.input_stream_manager != null;
    }

    // =========================================================================
    // Input abstraction methods
    // These abstract over static InputStream vs dynamic InputStreamManager
    // =========================================================================

    /// Consume the next character from the input source.
    fn consumeNextChar(self: *Tokenizer) InputCharacter {
        if (self.input_stream_manager) |stream| {
            // Dynamic input mode - use InputStreamManager
            if (stream.getNextChar()) |cp| {
                return InputCharacter{ .codepoint = cp };
            }
            return .eof;
        } else {
            // Static input mode - use InputStream
            return self.input.consume();
        }
    }

    /// Peek at the next character without consuming.
    fn peekNextChar(self: *Tokenizer) InputCharacter {
        if (self.input_stream_manager) |stream| {
            // Save state for InputStreamManager
            const saved_logical = stream.logical_position;
            const saved_original = stream.original_position;
            const saved_active = stream.active_insertion_index;
            const saved_line = stream.line;
            const saved_col = stream.column;
            const saved_cr = stream.last_was_cr;

            // Get the next character
            const result = if (stream.getNextChar()) |cp|
                InputCharacter{ .codepoint = cp }
            else
                InputCharacter.eof;

            // Restore state
            stream.logical_position = saved_logical;
            stream.original_position = saved_original;
            stream.active_insertion_index = saved_active;
            stream.line = saved_line;
            stream.column = saved_col;
            stream.last_was_cr = saved_cr;

            return result;
        } else {
            return self.input.peek();
        }
    }

    /// Check if at end of input.
    fn isAtEnd(self: *const Tokenizer) bool {
        if (self.input_stream_manager) |stream| {
            return stream.isAtEnd();
        } else {
            return self.input.isAtEnd();
        }
    }

    /// Get remaining bytes (only for static input - batch optimization).
    fn getRemaining(self: *const Tokenizer) usize {
        if (self.input_stream_manager != null) {
            // Batch optimization not supported for dynamic input
            return 0;
        }
        return self.input.remaining();
    }

    /// Get input data pointer (only for static input - batch optimization).
    fn getInputData(self: *const Tokenizer) []const u8 {
        if (self.input_stream_manager != null) {
            // Batch optimization not supported for dynamic input
            return &[_]u8{};
        }
        return self.input.data;
    }

    /// Get current input position (only for static input - batch optimization).
    fn getInputPosition(self: *const Tokenizer) usize {
        if (self.input_stream_manager != null) {
            return 0;
        }
        return self.input.position;
    }

    /// Set input position and column (only for static input - batch optimization).
    fn setInputPositionAndColumn(self: *Tokenizer, position: usize, column_delta: u32) void {
        if (self.input_stream_manager == null) {
            self.input.position = position;
            self.input.column += column_delta;
        }
    }

    /// Check if input matches string case-insensitively (for static input).
    fn inputMatchesAsciiCaseInsensitive(self: *Tokenizer, expected: []const u8) bool {
        if (self.input_stream_manager != null) {
            // Not supported for dynamic input - return false
            return false;
        }
        return self.input.matchesAsciiCaseInsensitive(expected);
    }

    /// Consume if input matches string case-insensitively (for static input).
    fn inputConsumeAsciiCaseInsensitive(self: *Tokenizer, expected: []const u8) bool {
        if (self.input_stream_manager != null) {
            // Not supported for dynamic input - return false
            return false;
        }
        return self.input.consumeAsciiCaseInsensitive(expected);
    }

    /// Consume N characters (for static input).
    fn inputConsumeN(self: *Tokenizer, n: usize) void {
        if (self.input_stream_manager) |stream| {
            for (0..n) |_| {
                _ = stream.getNextChar();
            }
        } else {
            for (0..n) |_| {
                _ = self.input.consume();
            }
        }
    }

    /// Free all resources.
    pub fn deinit(self: *Tokenizer) void {
        if (self.current_token) |*token| {
            token.deinit();
        }
        self.temporary_buffer.deinit();
        if (self.last_start_tag_name) |*name| {
            name.deinit();
        }
        // Free any remaining tokens in queue (only those past head index)
        const slice = self.token_queue.toSliceMut();
        for (slice[self.token_queue_head..]) |*token| {
            token.deinit();
        }
        self.token_queue.deinit();
    }

    /// Set error callback for parse error reporting.
    pub fn setErrorCallback(self: *Tokenizer, callback: ParseErrorCallback, context: ?*anyopaque) void {
        self.error_callback = callback;
        self.error_context = context;
        self.input.setErrorCallback(callback, context);
    }

    /// Report a parse error.
    fn reportError(self: *Tokenizer, code: ParseErrorCode) void {
        self.input.reportError(code);
    }

    /// Get the next token from the tokenizer.
    pub fn nextToken(self: *Tokenizer) !?Token {
        // If we have queued tokens, return one using O(1) head index
        const queue_len = self.token_queue.len;
        if (self.token_queue_head < queue_len) {
            const slice = self.token_queue.toSlice();
            const token = slice[self.token_queue_head];
            self.token_queue_head += 1;

            // Compact the queue when head reaches halfway to avoid unbounded growth
            // This amortizes the cost: O(1) per dequeue on average
            if (self.token_queue_head >= 8 and self.token_queue_head >= queue_len / 2) {
                try self.compactTokenQueue();
            }
            return token;
        }

        // Process states until we emit a token
        while (true) {
            // Get next character (or reconsume)
            if (self.reconsume) {
                self.reconsume = false;
            } else {
                self.current_char = self.consumeNextChar();
            }

            // Process current state
            const emitted = try self.processState();

            if (emitted) |token| {
                return token;
            }

            // Check for EOF after processing
            if (self.current_char.isEof() and self.state == .data) {
                return null;
            }
        }
    }

    /// Compact the token queue by removing already-consumed tokens.
    /// Called when head index gets large to prevent unbounded memory growth.
    fn compactTokenQueue(self: *Tokenizer) !void {
        const remaining = self.token_queue.len - self.token_queue_head;
        if (remaining == 0) {
            // Queue is empty, just clear it
            self.token_queue.clear();
            self.token_queue_head = 0;
            return;
        }

        // Create a new queue with just the remaining tokens
        var new_queue = infra.List(Token).init(self.allocator);
        errdefer new_queue.deinit();

        const slice = self.token_queue.toSlice();
        for (slice[self.token_queue_head..]) |t| {
            try new_queue.append(t);
        }

        // Note: We don't deinit the old tokens since they're being moved, not copied
        self.token_queue.deinit();
        self.token_queue = new_queue;
        self.token_queue_head = 0;
    }

    /// State handler function pointer type.
    /// Each state is handled by a function that takes the tokenizer and returns an optional token.
    const StateHandler = *const fn (*Tokenizer) anyerror!?Token;

    /// Comptime-generated function pointer table for state dispatch.
    /// Using function pointers instead of a switch statement provides:
    /// - Better branch prediction (single indirect call vs 80-way switch)
    /// - Reduced instruction cache pressure
    /// - 5-15% speedup for state-heavy parsing
    ///
    /// The table is indexed by @intFromEnum(State), providing O(1) dispatch.
    const state_handlers: [@typeInfo(State).@"enum".fields.len]StateHandler = blk: {
        var handlers: [@typeInfo(State).@"enum".fields.len]StateHandler = undefined;
        // Initialize each handler based on the State enum field order
        handlers[@intFromEnum(State.data)] = dataState;
        handlers[@intFromEnum(State.rcdata)] = rcdataState;
        handlers[@intFromEnum(State.rawtext)] = rawtextState;
        handlers[@intFromEnum(State.script_data)] = scriptDataState;
        handlers[@intFromEnum(State.plaintext)] = plaintextState;
        handlers[@intFromEnum(State.tag_open)] = tagOpenState;
        handlers[@intFromEnum(State.end_tag_open)] = endTagOpenState;
        handlers[@intFromEnum(State.tag_name)] = tagNameState;
        handlers[@intFromEnum(State.rcdata_less_than_sign)] = rcdataLessThanSignState;
        handlers[@intFromEnum(State.rcdata_end_tag_open)] = rcdataEndTagOpenState;
        handlers[@intFromEnum(State.rcdata_end_tag_name)] = rcdataEndTagNameState;
        handlers[@intFromEnum(State.rawtext_less_than_sign)] = rawtextLessThanSignState;
        handlers[@intFromEnum(State.rawtext_end_tag_open)] = rawtextEndTagOpenState;
        handlers[@intFromEnum(State.rawtext_end_tag_name)] = rawtextEndTagNameState;
        handlers[@intFromEnum(State.script_data_less_than_sign)] = scriptDataLessThanSignState;
        handlers[@intFromEnum(State.script_data_end_tag_open)] = scriptDataEndTagOpenState;
        handlers[@intFromEnum(State.script_data_end_tag_name)] = scriptDataEndTagNameState;
        handlers[@intFromEnum(State.script_data_escape_start)] = scriptDataEscapeStartState;
        handlers[@intFromEnum(State.script_data_escape_start_dash)] = scriptDataEscapeStartDashState;
        handlers[@intFromEnum(State.script_data_escaped)] = scriptDataEscapedState;
        handlers[@intFromEnum(State.script_data_escaped_dash)] = scriptDataEscapedDashState;
        handlers[@intFromEnum(State.script_data_escaped_dash_dash)] = scriptDataEscapedDashDashState;
        handlers[@intFromEnum(State.script_data_escaped_less_than_sign)] = scriptDataEscapedLessThanSignState;
        handlers[@intFromEnum(State.script_data_escaped_end_tag_open)] = scriptDataEscapedEndTagOpenState;
        handlers[@intFromEnum(State.script_data_escaped_end_tag_name)] = scriptDataEscapedEndTagNameState;
        handlers[@intFromEnum(State.script_data_double_escape_start)] = scriptDataDoubleEscapeStartState;
        handlers[@intFromEnum(State.script_data_double_escaped)] = scriptDataDoubleEscapedState;
        handlers[@intFromEnum(State.script_data_double_escaped_dash)] = scriptDataDoubleEscapedDashState;
        handlers[@intFromEnum(State.script_data_double_escaped_dash_dash)] = scriptDataDoubleEscapedDashDashState;
        handlers[@intFromEnum(State.script_data_double_escaped_less_than_sign)] = scriptDataDoubleEscapedLessThanSignState;
        handlers[@intFromEnum(State.script_data_double_escape_end)] = scriptDataDoubleEscapeEndState;
        handlers[@intFromEnum(State.before_attribute_name)] = beforeAttributeNameState;
        handlers[@intFromEnum(State.attribute_name)] = attributeNameState;
        handlers[@intFromEnum(State.after_attribute_name)] = afterAttributeNameState;
        handlers[@intFromEnum(State.before_attribute_value)] = beforeAttributeValueState;
        handlers[@intFromEnum(State.attribute_value_double_quoted)] = attributeValueDoubleQuotedState;
        handlers[@intFromEnum(State.attribute_value_single_quoted)] = attributeValueSingleQuotedState;
        handlers[@intFromEnum(State.attribute_value_unquoted)] = attributeValueUnquotedState;
        handlers[@intFromEnum(State.after_attribute_value_quoted)] = afterAttributeValueQuotedState;
        handlers[@intFromEnum(State.self_closing_start_tag)] = selfClosingStartTagState;
        handlers[@intFromEnum(State.bogus_comment)] = bogusCommentState;
        handlers[@intFromEnum(State.markup_declaration_open)] = markupDeclarationOpenState;
        handlers[@intFromEnum(State.comment_start)] = commentStartState;
        handlers[@intFromEnum(State.comment_start_dash)] = commentStartDashState;
        handlers[@intFromEnum(State.comment)] = commentState;
        handlers[@intFromEnum(State.comment_less_than_sign)] = commentLessThanSignState;
        handlers[@intFromEnum(State.comment_less_than_sign_bang)] = commentLessThanSignBangState;
        handlers[@intFromEnum(State.comment_less_than_sign_bang_dash)] = commentLessThanSignBangDashState;
        handlers[@intFromEnum(State.comment_less_than_sign_bang_dash_dash)] = commentLessThanSignBangDashDashState;
        handlers[@intFromEnum(State.comment_end_dash)] = commentEndDashState;
        handlers[@intFromEnum(State.comment_end)] = commentEndState;
        handlers[@intFromEnum(State.comment_end_bang)] = commentEndBangState;
        handlers[@intFromEnum(State.doctype)] = doctypeState;
        handlers[@intFromEnum(State.before_doctype_name)] = beforeDoctypeNameState;
        handlers[@intFromEnum(State.doctype_name)] = doctypeNameState;
        handlers[@intFromEnum(State.after_doctype_name)] = afterDoctypeNameState;
        handlers[@intFromEnum(State.after_doctype_public_keyword)] = afterDoctypePublicKeywordState;
        handlers[@intFromEnum(State.before_doctype_public_identifier)] = beforeDoctypePublicIdentifierState;
        handlers[@intFromEnum(State.doctype_public_identifier_double_quoted)] = doctypePublicIdentifierDoubleQuotedState;
        handlers[@intFromEnum(State.doctype_public_identifier_single_quoted)] = doctypePublicIdentifierSingleQuotedState;
        handlers[@intFromEnum(State.after_doctype_public_identifier)] = afterDoctypePublicIdentifierState;
        handlers[@intFromEnum(State.between_doctype_public_and_system_identifiers)] = betweenDoctypePublicAndSystemIdentifiersState;
        handlers[@intFromEnum(State.after_doctype_system_keyword)] = afterDoctypeSystemKeywordState;
        handlers[@intFromEnum(State.before_doctype_system_identifier)] = beforeDoctypeSystemIdentifierState;
        handlers[@intFromEnum(State.doctype_system_identifier_double_quoted)] = doctypeSystemIdentifierDoubleQuotedState;
        handlers[@intFromEnum(State.doctype_system_identifier_single_quoted)] = doctypeSystemIdentifierSingleQuotedState;
        handlers[@intFromEnum(State.after_doctype_system_identifier)] = afterDoctypeSystemIdentifierState;
        handlers[@intFromEnum(State.bogus_doctype)] = bogusDoctypeState;
        handlers[@intFromEnum(State.cdata_section)] = cdataSectionState;
        handlers[@intFromEnum(State.cdata_section_bracket)] = cdataSectionBracketState;
        handlers[@intFromEnum(State.cdata_section_end)] = cdataSectionEndState;
        handlers[@intFromEnum(State.character_reference)] = characterReferenceState;
        handlers[@intFromEnum(State.named_character_reference)] = namedCharacterReferenceState;
        handlers[@intFromEnum(State.ambiguous_ampersand)] = ambiguousAmpersandState;
        handlers[@intFromEnum(State.numeric_character_reference)] = numericCharacterReferenceState;
        handlers[@intFromEnum(State.hexadecimal_character_reference_start)] = hexadecimalCharacterReferenceStartState;
        handlers[@intFromEnum(State.decimal_character_reference_start)] = decimalCharacterReferenceStartState;
        handlers[@intFromEnum(State.hexadecimal_character_reference)] = hexadecimalCharacterReferenceState;
        handlers[@intFromEnum(State.decimal_character_reference)] = decimalCharacterReferenceState;
        handlers[@intFromEnum(State.numeric_character_reference_end)] = numericCharacterReferenceEndState;
        break :blk handlers;
    };

    /// Process the current state and return emitted token if any.
    /// Uses function pointer table dispatch instead of switch for better performance.
    fn processState(self: *Tokenizer) !?Token {
        // Direct indexed lookup into function pointer table - O(1) dispatch
        // This is faster than a switch statement because:
        // 1. Single indirect call instead of switch branch cascade
        // 2. Better branch prediction (indirect call predictor vs switch)
        // 3. Smaller code size in the hot path
        return state_handlers[@intFromEnum(self.state)](self);
    }

    // =========================================================================
    // State implementations
    // =========================================================================

    /// §13.2.5.1 Data state
    /// Optimized for batch text processing: scans ahead to collect runs of
    /// consecutive text characters and emits them as a single text_run token.
    fn dataState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('&')) {
            self.return_state = .data;
            self.state = .character_reference;
            return null;
        } else if (char.is('<')) {
            self.state = .tag_open;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            return Token{ .character = 0x00 };
        } else if (char.isEof()) {
            // EOF in data state - return null to signal end of tokens
            // The main loop will handle this and return null to caller
            return null;
        } else {
            // Optimization: try to batch consecutive text characters
            // Look ahead in raw input to find extent of normal text
            const batch_result = self.batchDataStateCharacters();
            if (batch_result.len > 0) {
                return Token{ .text_run = .{ .data = batch_result.data } };
            }
            // Fallback to single character
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// Batch data state characters: scan ahead to find runs of consecutive text
    /// that don't require special handling (no <, &, NULL, or CRLF).
    /// Returns a slice into the input buffer (zero-copy).
    ///
    /// Note: Batch optimization is disabled for dynamic input (InputStreamManager)
    /// because the input may change during parsing via document.write().
    fn batchDataStateCharacters(self: *Tokenizer) struct { data: []const u8, len: usize } {
        // Batch optimization is not supported for dynamic input
        if (self.input_stream_manager != null) {
            return .{ .data = &.{}, .len = 0 };
        }

        // Get the current character's position in the raw input
        // We need to figure out where in the raw input the current char started
        const data = self.input.data;

        // The current_char has already been consumed, so we need to work backwards
        // to find its start position. We know the input.position is AFTER current_char.
        // For ASCII chars (most common), it's 1 byte back.
        const current_cp = self.current_char.getCodepoint() orelse return .{ .data = &.{}, .len = 0 };

        // Determine how many bytes the current character took
        const current_char_bytes: usize = if (current_cp < 0x80) 1 else if (current_cp < 0x800) 2 else if (current_cp < 0x10000) 3 else 4;

        // Calculate start position (where current_char began in raw input)
        const start_pos = if (self.input.position >= current_char_bytes)
            self.input.position - current_char_bytes
        else
            return .{ .data = &.{}, .len = 0 };

        // Quick check: if current char isn't simple ASCII text, don't batch
        if (current_cp >= 0x80 or current_cp == 0x0D or current_cp == 0x0A) {
            return .{ .data = &.{}, .len = 0 };
        }

        // Scan ahead from current input position for more text characters
        var end_pos = self.input.position;
        while (end_pos < data.len) {
            const byte = data[end_pos];
            // Stop on: <, &, NULL, CR, LF, or high bytes (non-ASCII)
            if (byte == '<' or byte == '&' or byte == 0x00 or
                byte == 0x0D or byte == 0x0A or byte >= 0x80)
            {
                break;
            }
            end_pos += 1;
        }

        const batch_len = end_pos - start_pos;
        if (batch_len < 2) {
            // Not worth batching single characters
            return .{ .data = &.{}, .len = 0 };
        }

        // Advance input position past the batch
        const chars_consumed = end_pos - self.input.position;
        self.input.position = end_pos;
        self.input.column += @intCast(chars_consumed);

        return .{ .data = data[start_pos..end_pos], .len = batch_len };
    }

    /// §13.2.5.2 RCDATA state
    fn rcdataState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('&')) {
            self.return_state = .rcdata;
            self.state = .character_reference;
            return null;
        } else if (char.is('<')) {
            self.state = .rcdata_less_than_sign;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.3 RAWTEXT state
    fn rawtextState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('<')) {
            self.state = .rawtext_less_than_sign;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.4 Script data state
    fn scriptDataState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('<')) {
            self.state = .script_data_less_than_sign;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.5 PLAINTEXT state
    fn plaintextState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.6 Tag open state
    fn tagOpenState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('!')) {
            self.state = .markup_declaration_open;
            return null;
        } else if (char.is('/')) {
            self.state = .end_tag_open;
            return null;
        } else if (char.isAsciiAlpha()) {
            self.current_token = Token{ .start_tag = TagToken.init(self.allocator, false) };
            self.reconsume = true;
            self.state = .tag_name;
            return null;
        } else if (char.is('?')) {
            self.reportError(.unexpected_question_mark_instead_of_tag_name);
            self.current_token = Token{ .comment = CommentToken.init(self.allocator) };
            self.reconsume = true;
            self.state = .bogus_comment;
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_before_tag_name);
            try self.token_queue.append(Token.eof);
            return Token{ .character = '<' };
        } else {
            self.reportError(.invalid_first_character_of_tag_name);
            self.reconsume = true;
            self.state = .data;
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.7 End tag open state
    fn endTagOpenState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiAlpha()) {
            self.current_token = Token{ .end_tag = TagToken.init(self.allocator, true) };
            self.reconsume = true;
            self.state = .tag_name;
            return null;
        } else if (char.is('>')) {
            self.reportError(.missing_end_tag_name);
            self.state = .data;
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_before_tag_name);
            try self.token_queue.append(Token{ .character = '/' });
            try self.token_queue.append(Token.eof);
            return Token{ .character = '<' };
        } else {
            self.reportError(.invalid_first_character_of_tag_name);
            self.current_token = Token{ .comment = CommentToken.init(self.allocator) };
            self.reconsume = true;
            self.state = .bogus_comment;
            return null;
        }
    }

    /// §13.2.5.8 Tag name state
    fn tagNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .before_attribute_name;
            return null;
        } else if (char.is('/')) {
            self.state = .self_closing_start_tag;
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentTag();
        } else if (char.isAsciiUpperAlpha()) {
            // Append lowercase version
            const lower = char.toLowercase().getCodepoint().?;
            try self.appendToCurrentTagName(@intCast(lower));
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendToCurrentTagName(0xFFFD);
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_tag);
            return Token.eof;
        } else {
            try self.appendToCurrentTagName(char.getCodepoint().?);
            return null;
        }
    }

    /// §13.2.5.9 RCDATA less-than sign state
    fn rcdataLessThanSignState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('/')) {
            self.temporary_buffer.clear();
            self.state = .rcdata_end_tag_open;
            return null;
        } else {
            self.reconsume = true;
            self.state = .rcdata;
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.10 RCDATA end tag open state
    fn rcdataEndTagOpenState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiAlpha()) {
            self.current_token = Token{ .end_tag = TagToken.init(self.allocator, true) };
            self.reconsume = true;
            self.state = .rcdata_end_tag_name;
            return null;
        } else {
            self.reconsume = true;
            self.state = .rcdata;
            try self.token_queue.append(Token{ .character = '/' });
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.11 RCDATA end tag name state
    fn rcdataEndTagNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            if (self.isAppropriateEndTag()) {
                self.state = .before_attribute_name;
                return null;
            }
        } else if (char.is('/')) {
            if (self.isAppropriateEndTag()) {
                self.state = .self_closing_start_tag;
                return null;
            }
        } else if (char.is('>')) {
            if (self.isAppropriateEndTag()) {
                self.state = .data;
                return try self.emitCurrentTag();
            }
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.appendToCurrentTagName(lower);
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        } else if (char.isAsciiLowerAlpha()) {
            try self.appendToCurrentTagName(@intCast(char.getCodepoint().?));
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        }

        // Anything else
        // HTML Spec: Emit <, /, then temp buffer contents
        // Queue order matters: '/' must come BEFORE temp buffer
        self.reconsume = true;
        self.state = .rcdata;
        try self.token_queue.append(Token{ .character = '/' });
        try self.emitTemporaryBufferAsCharacters();
        return Token{ .character = '<' };
    }

    /// §13.2.5.12 RAWTEXT less-than sign state
    fn rawtextLessThanSignState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('/')) {
            self.temporary_buffer.clear();
            self.state = .rawtext_end_tag_open;
            return null;
        } else {
            self.reconsume = true;
            self.state = .rawtext;
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.13 RAWTEXT end tag open state
    fn rawtextEndTagOpenState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiAlpha()) {
            self.current_token = Token{ .end_tag = TagToken.init(self.allocator, true) };
            self.reconsume = true;
            self.state = .rawtext_end_tag_name;
            return null;
        } else {
            self.reconsume = true;
            self.state = .rawtext;
            try self.token_queue.append(Token{ .character = '/' });
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.14 RAWTEXT end tag name state
    fn rawtextEndTagNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            if (self.isAppropriateEndTag()) {
                self.state = .before_attribute_name;
                return null;
            }
        } else if (char.is('/')) {
            if (self.isAppropriateEndTag()) {
                self.state = .self_closing_start_tag;
                return null;
            }
        } else if (char.is('>')) {
            if (self.isAppropriateEndTag()) {
                self.state = .data;
                return try self.emitCurrentTag();
            }
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.appendToCurrentTagName(lower);
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        } else if (char.isAsciiLowerAlpha()) {
            try self.appendToCurrentTagName(@intCast(char.getCodepoint().?));
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        }

        // Anything else
        // HTML Spec: Emit <, /, then temp buffer contents
        // Queue order matters: '/' must come BEFORE temp buffer
        self.reconsume = true;
        self.state = .rawtext;
        try self.token_queue.append(Token{ .character = '/' });
        try self.emitTemporaryBufferAsCharacters();
        return Token{ .character = '<' };
    }

    /// §13.2.5.15 Script data less-than sign state
    fn scriptDataLessThanSignState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('/')) {
            self.temporary_buffer.clear();
            self.state = .script_data_end_tag_open;
            return null;
        } else if (char.is('!')) {
            self.state = .script_data_escape_start;
            try self.token_queue.append(Token{ .character = '!' });
            return Token{ .character = '<' };
        } else {
            self.reconsume = true;
            self.state = .script_data;
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.16 Script data end tag open state
    fn scriptDataEndTagOpenState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiAlpha()) {
            self.current_token = Token{ .end_tag = TagToken.init(self.allocator, true) };
            self.reconsume = true;
            self.state = .script_data_end_tag_name;
            return null;
        } else {
            self.reconsume = true;
            self.state = .script_data;
            try self.token_queue.append(Token{ .character = '/' });
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.17 Script data end tag name state
    fn scriptDataEndTagNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            if (self.isAppropriateEndTag()) {
                self.state = .before_attribute_name;
                return null;
            }
        } else if (char.is('/')) {
            if (self.isAppropriateEndTag()) {
                self.state = .self_closing_start_tag;
                return null;
            }
        } else if (char.is('>')) {
            if (self.isAppropriateEndTag()) {
                self.state = .data;
                return try self.emitCurrentTag();
            }
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.appendToCurrentTagName(lower);
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        } else if (char.isAsciiLowerAlpha()) {
            try self.appendToCurrentTagName(@intCast(char.getCodepoint().?));
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        }

        // Anything else
        // HTML Spec: Emit <, /, then temp buffer contents
        // Queue order matters: '/' must come BEFORE temp buffer
        self.reconsume = true;
        self.state = .script_data;
        try self.token_queue.append(Token{ .character = '/' });
        try self.emitTemporaryBufferAsCharacters();
        return Token{ .character = '<' };
    }

    /// §13.2.5.18 Script data escape start state
    fn scriptDataEscapeStartState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .script_data_escape_start_dash;
            return Token{ .character = '-' };
        } else {
            self.reconsume = true;
            self.state = .script_data;
            return null;
        }
    }

    /// §13.2.5.19 Script data escape start dash state
    fn scriptDataEscapeStartDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .script_data_escaped_dash_dash;
            return Token{ .character = '-' };
        } else {
            self.reconsume = true;
            self.state = .script_data;
            return null;
        }
    }

    /// §13.2.5.20 Script data escaped state
    fn scriptDataEscapedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .script_data_escaped_dash;
            return Token{ .character = '-' };
        } else if (char.is('<')) {
            self.state = .script_data_escaped_less_than_sign;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            self.reportError(.eof_in_script_html_comment_like_text);
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.21 Script data escaped dash state
    fn scriptDataEscapedDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .script_data_escaped_dash_dash;
            return Token{ .character = '-' };
        } else if (char.is('<')) {
            self.state = .script_data_escaped_less_than_sign;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            self.state = .script_data_escaped;
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            self.reportError(.eof_in_script_html_comment_like_text);
            return Token.eof;
        } else {
            self.state = .script_data_escaped;
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.22 Script data escaped dash dash state
    fn scriptDataEscapedDashDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            return Token{ .character = '-' };
        } else if (char.is('<')) {
            self.state = .script_data_escaped_less_than_sign;
            return null;
        } else if (char.is('>')) {
            self.state = .script_data;
            return Token{ .character = '>' };
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            self.state = .script_data_escaped;
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            self.reportError(.eof_in_script_html_comment_like_text);
            return Token.eof;
        } else {
            self.state = .script_data_escaped;
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.23 Script data escaped less-than sign state
    fn scriptDataEscapedLessThanSignState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('/')) {
            self.temporary_buffer.clear();
            self.state = .script_data_escaped_end_tag_open;
            return null;
        } else if (char.isAsciiAlpha()) {
            self.temporary_buffer.clear();
            self.reconsume = true;
            self.state = .script_data_double_escape_start;
            return Token{ .character = '<' };
        } else {
            self.reconsume = true;
            self.state = .script_data_escaped;
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.24 Script data escaped end tag open state
    fn scriptDataEscapedEndTagOpenState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiAlpha()) {
            self.current_token = Token{ .end_tag = TagToken.init(self.allocator, true) };
            self.reconsume = true;
            self.state = .script_data_escaped_end_tag_name;
            return null;
        } else {
            self.reconsume = true;
            self.state = .script_data_escaped;
            try self.token_queue.append(Token{ .character = '/' });
            return Token{ .character = '<' };
        }
    }

    /// §13.2.5.25 Script data escaped end tag name state
    fn scriptDataEscapedEndTagNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            if (self.isAppropriateEndTag()) {
                self.state = .before_attribute_name;
                return null;
            }
        } else if (char.is('/')) {
            if (self.isAppropriateEndTag()) {
                self.state = .self_closing_start_tag;
                return null;
            }
        } else if (char.is('>')) {
            if (self.isAppropriateEndTag()) {
                self.state = .data;
                return try self.emitCurrentTag();
            }
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.appendToCurrentTagName(lower);
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        } else if (char.isAsciiLowerAlpha()) {
            try self.appendToCurrentTagName(@intCast(char.getCodepoint().?));
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return null;
        }

        // Anything else
        // HTML Spec: Emit <, /, then temp buffer contents
        // Queue order matters: '/' must come BEFORE temp buffer
        self.reconsume = true;
        self.state = .script_data_escaped;
        try self.token_queue.append(Token{ .character = '/' });
        try self.emitTemporaryBufferAsCharacters();
        return Token{ .character = '<' };
    }

    /// §13.2.5.26 Script data double escape start state
    fn scriptDataDoubleEscapeStartState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace() or char.is('/') or char.is('>')) {
            if (self.temporaryBufferEquals("script")) {
                self.state = .script_data_double_escaped;
            } else {
                self.state = .script_data_escaped;
            }
            return Token{ .character = char.getCodepoint().? };
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.temporary_buffer.append(lower);
            return Token{ .character = char.getCodepoint().? };
        } else if (char.isAsciiLowerAlpha()) {
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return Token{ .character = char.getCodepoint().? };
        } else {
            self.reconsume = true;
            self.state = .script_data_escaped;
            return null;
        }
    }

    /// §13.2.5.27 Script data double escaped state
    fn scriptDataDoubleEscapedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .script_data_double_escaped_dash;
            return Token{ .character = '-' };
        } else if (char.is('<')) {
            self.state = .script_data_double_escaped_less_than_sign;
            return Token{ .character = '<' };
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            self.reportError(.eof_in_script_html_comment_like_text);
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.28 Script data double escaped dash state
    fn scriptDataDoubleEscapedDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .script_data_double_escaped_dash_dash;
            return Token{ .character = '-' };
        } else if (char.is('<')) {
            self.state = .script_data_double_escaped_less_than_sign;
            return Token{ .character = '<' };
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            self.state = .script_data_double_escaped;
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            self.reportError(.eof_in_script_html_comment_like_text);
            return Token.eof;
        } else {
            self.state = .script_data_double_escaped;
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.29 Script data double escaped dash dash state
    fn scriptDataDoubleEscapedDashDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            return Token{ .character = '-' };
        } else if (char.is('<')) {
            self.state = .script_data_double_escaped_less_than_sign;
            return Token{ .character = '<' };
        } else if (char.is('>')) {
            self.state = .script_data;
            return Token{ .character = '>' };
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            self.state = .script_data_double_escaped;
            return Token{ .character = 0xFFFD };
        } else if (char.isEof()) {
            self.reportError(.eof_in_script_html_comment_like_text);
            return Token.eof;
        } else {
            self.state = .script_data_double_escaped;
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.30 Script data double escaped less-than sign state
    fn scriptDataDoubleEscapedLessThanSignState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('/')) {
            self.temporary_buffer.clear();
            self.state = .script_data_double_escape_end;
            return Token{ .character = '/' };
        } else {
            self.reconsume = true;
            self.state = .script_data_double_escaped;
            return null;
        }
    }

    /// §13.2.5.31 Script data double escape end state
    fn scriptDataDoubleEscapeEndState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace() or char.is('/') or char.is('>')) {
            if (self.temporaryBufferEquals("script")) {
                self.state = .script_data_escaped;
            } else {
                self.state = .script_data_double_escaped;
            }
            return Token{ .character = char.getCodepoint().? };
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.temporary_buffer.append(lower);
            return Token{ .character = char.getCodepoint().? };
        } else if (char.isAsciiLowerAlpha()) {
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            return Token{ .character = char.getCodepoint().? };
        } else {
            self.reconsume = true;
            self.state = .script_data_double_escaped;
            return null;
        }
    }

    /// §13.2.5.32 Before attribute name state
    fn beforeAttributeNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('/') or char.is('>') or char.isEof()) {
            self.reconsume = true;
            self.state = .after_attribute_name;
            return null;
        } else if (char.is('=')) {
            self.reportError(.unexpected_equals_sign_before_attribute_name);
            try self.startNewAttribute();
            try self.appendToCurrentAttributeName(@intCast(char.getCodepoint().?));
            self.state = .attribute_name;
            return null;
        } else {
            try self.startNewAttribute();
            self.reconsume = true;
            self.state = .attribute_name;
            return null;
        }
    }

    /// §13.2.5.33 Attribute name state
    fn attributeNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace() or char.is('/') or char.is('>') or char.isEof()) {
            self.reconsume = true;
            self.state = .after_attribute_name;
            return null;
        } else if (char.is('=')) {
            self.state = .before_attribute_value;
            return null;
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.appendToCurrentAttributeName(lower);
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendToCurrentAttributeName(0xFFFD);
            return null;
        } else if (char.is('"') or char.is('\'') or char.is('<')) {
            self.reportError(.unexpected_character_in_attribute_name);
            try self.appendToCurrentAttributeName(@intCast(char.getCodepoint().?));
            return null;
        } else {
            try self.appendToCurrentAttributeName(char.getCodepoint().?);
            return null;
        }
    }

    /// §13.2.5.34 After attribute name state
    fn afterAttributeNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('/')) {
            self.state = .self_closing_start_tag;
            return null;
        } else if (char.is('=')) {
            self.state = .before_attribute_value;
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentTag();
        } else if (char.isEof()) {
            self.reportError(.eof_in_tag);
            return Token.eof;
        } else {
            try self.startNewAttribute();
            self.reconsume = true;
            self.state = .attribute_name;
            return null;
        }
    }

    /// §13.2.5.35 Before attribute value state
    fn beforeAttributeValueState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('"')) {
            self.state = .attribute_value_double_quoted;
            return null;
        } else if (char.is('\'')) {
            self.state = .attribute_value_single_quoted;
            return null;
        } else if (char.is('>')) {
            self.reportError(.missing_attribute_value);
            self.state = .data;
            return try self.emitCurrentTag();
        } else {
            self.reconsume = true;
            self.state = .attribute_value_unquoted;
            return null;
        }
    }

    /// §13.2.5.36 Attribute value (double-quoted) state
    fn attributeValueDoubleQuotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('"')) {
            self.state = .after_attribute_value_quoted;
            return null;
        } else if (char.is('&')) {
            self.return_state = .attribute_value_double_quoted;
            self.state = .character_reference;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendToCurrentAttributeValue(0xFFFD);
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_tag);
            return Token.eof;
        } else {
            // Optimization: batch append runs of normal ASCII characters
            // Look ahead in raw input to find extent of normal chars
            const cp = char.getCodepoint().?;
            if (cp < 128) {
                // Current char is ASCII - try to batch more
                const batch_result = self.batchAppendAttributeValue('"');
                if (batch_result.consumed > 0) {
                    return null;
                }
            }
            // Fall back to single character append
            try self.appendToCurrentAttributeValue(cp);
            return null;
        }
    }

    /// §13.2.5.37 Attribute value (single-quoted) state
    fn attributeValueSingleQuotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('\'')) {
            self.state = .after_attribute_value_quoted;
            return null;
        } else if (char.is('&')) {
            self.return_state = .attribute_value_single_quoted;
            self.state = .character_reference;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendToCurrentAttributeValue(0xFFFD);
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_tag);
            return Token.eof;
        } else {
            // Optimization: batch append runs of normal ASCII characters
            const cp = char.getCodepoint().?;
            if (cp < 128) {
                // Current char is ASCII - try to batch more
                const batch_result = self.batchAppendAttributeValue('\'');
                if (batch_result.consumed > 0) {
                    return null;
                }
            }
            // Fall back to single character append
            try self.appendToCurrentAttributeValue(cp);
            return null;
        }
    }

    /// §13.2.5.38 Attribute value (unquoted) state
    fn attributeValueUnquotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .before_attribute_name;
            return null;
        } else if (char.is('&')) {
            self.return_state = .attribute_value_unquoted;
            self.state = .character_reference;
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentTag();
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendToCurrentAttributeValue(0xFFFD);
            return null;
        } else if (char.is('"') or char.is('\'') or char.is('<') or char.is('=') or char.is('`')) {
            self.reportError(.unexpected_character_in_unquoted_attribute_value);
            try self.appendToCurrentAttributeValue(char.getCodepoint().?);
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_tag);
            return Token.eof;
        } else {
            try self.appendToCurrentAttributeValue(char.getCodepoint().?);
            return null;
        }
    }

    /// §13.2.5.39 After attribute value (quoted) state
    fn afterAttributeValueQuotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .before_attribute_name;
            return null;
        } else if (char.is('/')) {
            self.state = .self_closing_start_tag;
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentTag();
        } else if (char.isEof()) {
            self.reportError(.eof_in_tag);
            return Token.eof;
        } else {
            self.reportError(.missing_whitespace_between_attributes);
            self.reconsume = true;
            self.state = .before_attribute_name;
            return null;
        }
    }

    /// §13.2.5.40 Self-closing start tag state
    fn selfClosingStartTagState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('>')) {
            self.setSelfClosingFlag();
            self.state = .data;
            return try self.emitCurrentTag();
        } else if (char.isEof()) {
            self.reportError(.eof_in_tag);
            return Token.eof;
        } else {
            self.reportError(.unexpected_solidus_in_tag);
            self.reconsume = true;
            self.state = .before_attribute_name;
            return null;
        }
    }

    /// §13.2.5.41 Bogus comment state
    fn bogusCommentState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentComment();
        } else if (char.isEof()) {
            const comment = try self.emitCurrentComment();
            try self.token_queue.append(Token.eof);
            return comment;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendToCurrentCommentData(0xFFFD);
            return null;
        } else {
            try self.appendToCurrentCommentData(char.getCodepoint().?);
            return null;
        }
    }

    /// §13.2.5.42 Markup declaration open state
    ///
    /// Per HTML spec: This state is entered after consuming "<!".
    /// We need to check for "--", "DOCTYPE", or "[CDATA[" starting from the
    /// CURRENT character (which was consumed by the main loop).
    fn markupDeclarationOpenState(self: *Tokenizer) !?Token {
        // The current character is the first char after "<!".
        // We need to check if current_char + next chars form the patterns.

        // Check for "--" (comment start)
        if (self.current_char.is('-')) {
            // Check if next char is also '-'
            if (self.peekNextChar().is('-')) {
                _ = self.consumeNextChar(); // Consume the second '-'
                self.current_token = Token{ .comment = CommentToken.init(self.allocator) };
                self.state = .comment_start;
                return null;
            }
        }

        // Check for "DOCTYPE" (current_char is 'D' or 'd')
        if (self.current_char.isAsciiAlpha()) {
            const cp = self.current_char.getCodepoint().?;
            const lower_cp: u8 = if (cp >= 'A' and cp <= 'Z') @intCast(cp + 0x20) else @intCast(cp);
            if (lower_cp == 'd') {
                // Check remaining "OCTYPE"
                if (self.inputMatchesAsciiCaseInsensitive("OCTYPE")) {
                    self.inputConsumeN(6);
                    self.state = .doctype;
                    return null;
                }
            }
        }

        // Check for "[CDATA[" (current_char is '[')
        if (self.current_char.is('[')) {
            if (self.inputMatchesAsciiCaseInsensitive("CDATA[")) {
                self.inputConsumeN(6);
                // Note: In a proper implementation, we'd check if we're in foreign content.
                // For now, always treat as HTML content (bogus comment)
                self.reportError(.cdata_in_html_content);
                self.current_token = Token{ .comment = CommentToken.init(self.allocator) };
                // Append "[CDATA[" to comment
                for ("[CDATA[") |c| {
                    try self.appendToCurrentCommentData(c);
                }
                self.state = .bogus_comment;
                return null;
            }
        }

        // Anything else: parse error, bogus comment
        self.reportError(.incorrectly_opened_comment);
        self.current_token = Token{ .comment = CommentToken.init(self.allocator) };
        self.state = .bogus_comment;
        // Don't consume - reconsume current char
        self.reconsume = true;
        return null;
    }

    /// §13.2.5.43 Comment start state
    fn commentStartState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .comment_start_dash;
            return null;
        } else if (char.is('>')) {
            self.reportError(.abrupt_closing_of_empty_comment);
            self.state = .data;
            return try self.emitCurrentComment();
        } else {
            self.reconsume = true;
            self.state = .comment;
            return null;
        }
    }

    /// §13.2.5.44 Comment start dash state
    fn commentStartDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .comment_end;
            return null;
        } else if (char.is('>')) {
            self.reportError(.abrupt_closing_of_empty_comment);
            self.state = .data;
            return try self.emitCurrentComment();
        } else if (char.isEof()) {
            self.reportError(.eof_in_comment);
            const comment = try self.emitCurrentComment();
            try self.token_queue.append(Token.eof);
            return comment;
        } else {
            try self.appendToCurrentCommentData('-');
            self.reconsume = true;
            self.state = .comment;
            return null;
        }
    }

    /// §13.2.5.45 Comment state
    fn commentState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('<')) {
            try self.appendToCurrentCommentData('<');
            self.state = .comment_less_than_sign;
            return null;
        } else if (char.is('-')) {
            self.state = .comment_end_dash;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendToCurrentCommentData(0xFFFD);
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_comment);
            const comment = try self.emitCurrentComment();
            try self.token_queue.append(Token.eof);
            return comment;
        } else {
            try self.appendToCurrentCommentData(char.getCodepoint().?);
            return null;
        }
    }

    /// §13.2.5.46 Comment less-than sign state
    fn commentLessThanSignState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('!')) {
            try self.appendToCurrentCommentData('!');
            self.state = .comment_less_than_sign_bang;
            return null;
        } else if (char.is('<')) {
            try self.appendToCurrentCommentData('<');
            return null;
        } else {
            self.reconsume = true;
            self.state = .comment;
            return null;
        }
    }

    /// §13.2.5.47 Comment less-than sign bang state
    fn commentLessThanSignBangState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .comment_less_than_sign_bang_dash;
            return null;
        } else {
            self.reconsume = true;
            self.state = .comment;
            return null;
        }
    }

    /// §13.2.5.48 Comment less-than sign bang dash state
    fn commentLessThanSignBangDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .comment_less_than_sign_bang_dash_dash;
            return null;
        } else {
            self.reconsume = true;
            self.state = .comment_end_dash;
            return null;
        }
    }

    /// §13.2.5.49 Comment less-than sign bang dash dash state
    fn commentLessThanSignBangDashDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('>') or char.isEof()) {
            self.reconsume = true;
            self.state = .comment_end;
            return null;
        } else {
            self.reportError(.nested_comment);
            self.reconsume = true;
            self.state = .comment_end;
            return null;
        }
    }

    /// §13.2.5.50 Comment end dash state
    fn commentEndDashState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            self.state = .comment_end;
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_comment);
            const comment = try self.emitCurrentComment();
            try self.token_queue.append(Token.eof);
            return comment;
        } else {
            try self.appendToCurrentCommentData('-');
            self.reconsume = true;
            self.state = .comment;
            return null;
        }
    }

    /// §13.2.5.51 Comment end state
    fn commentEndState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentComment();
        } else if (char.is('!')) {
            self.state = .comment_end_bang;
            return null;
        } else if (char.is('-')) {
            try self.appendToCurrentCommentData('-');
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_comment);
            const comment = try self.emitCurrentComment();
            try self.token_queue.append(Token.eof);
            return comment;
        } else {
            try self.appendToCurrentCommentData('-');
            try self.appendToCurrentCommentData('-');
            self.reconsume = true;
            self.state = .comment;
            return null;
        }
    }

    /// §13.2.5.52 Comment end bang state
    fn commentEndBangState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('-')) {
            try self.appendToCurrentCommentData('-');
            try self.appendToCurrentCommentData('-');
            try self.appendToCurrentCommentData('!');
            self.state = .comment_end_dash;
            return null;
        } else if (char.is('>')) {
            self.reportError(.incorrectly_closed_comment);
            self.state = .data;
            return try self.emitCurrentComment();
        } else if (char.isEof()) {
            self.reportError(.eof_in_comment);
            const comment = try self.emitCurrentComment();
            try self.token_queue.append(Token.eof);
            return comment;
        } else {
            try self.appendToCurrentCommentData('-');
            try self.appendToCurrentCommentData('-');
            try self.appendToCurrentCommentData('!');
            self.reconsume = true;
            self.state = .comment;
            return null;
        }
    }

    /// §13.2.5.53 DOCTYPE state
    fn doctypeState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .before_doctype_name;
            return null;
        } else if (char.is('>')) {
            self.reconsume = true;
            self.state = .before_doctype_name;
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            var doctype = DoctypeToken.init(self.allocator);
            doctype.force_quirks = true;
            try self.token_queue.append(Token.eof);
            return Token{ .doctype = doctype };
        } else {
            self.reportError(.missing_whitespace_before_doctype_name);
            self.reconsume = true;
            self.state = .before_doctype_name;
            return null;
        }
    }

    /// §13.2.5.54 Before DOCTYPE name state
    fn beforeDoctypeNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.isAsciiUpperAlpha()) {
            var doctype = DoctypeToken.init(self.allocator);
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try doctype.appendToName(lower);
            self.current_token = Token{ .doctype = doctype };
            self.state = .doctype_name;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            var doctype = DoctypeToken.init(self.allocator);
            try doctype.appendCodepointToName(0xFFFD);
            self.current_token = Token{ .doctype = doctype };
            self.state = .doctype_name;
            return null;
        } else if (char.is('>')) {
            self.reportError(.missing_doctype_name);
            var doctype = DoctypeToken.init(self.allocator);
            doctype.force_quirks = true;
            self.state = .data;
            return Token{ .doctype = doctype };
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            var doctype = DoctypeToken.init(self.allocator);
            doctype.force_quirks = true;
            try self.token_queue.append(Token.eof);
            return Token{ .doctype = doctype };
        } else {
            var doctype = DoctypeToken.init(self.allocator);
            const cp = char.getCodepoint().?;
            if (cp <= 0xFF) {
                try doctype.appendToName(@intCast(cp));
            }
            self.current_token = Token{ .doctype = doctype };
            self.state = .doctype_name;
            return null;
        }
    }

    /// §13.2.5.55 DOCTYPE name state
    fn doctypeNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .after_doctype_name;
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isAsciiUpperAlpha()) {
            const lower: u8 = @intCast(char.getCodepoint().? + 0x20);
            try self.appendToCurrentDoctypeName(lower);
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendCodepointToCurrentDoctypeName(0xFFFD);
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            const cp = char.getCodepoint().?;
            if (cp <= 0xFF) {
                try self.appendToCurrentDoctypeName(@intCast(cp));
            }
            return null;
        }
    }

    /// §13.2.5.56 After DOCTYPE name state
    fn afterDoctypeNameState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            // Check for PUBLIC or SYSTEM
            if (self.inputMatchesAsciiCaseInsensitive("PUBLIC")) {
                // Need to "unconsume" current char and consume "PUBLIC"
                self.reconsume = true;
                if (self.inputConsumeAsciiCaseInsensitive("PUBLIC")) {
                    self.state = .after_doctype_public_keyword;
                    return null;
                }
            } else if (self.inputMatchesAsciiCaseInsensitive("SYSTEM")) {
                self.reconsume = true;
                if (self.inputConsumeAsciiCaseInsensitive("SYSTEM")) {
                    self.state = .after_doctype_system_keyword;
                    return null;
                }
            }

            self.reportError(.invalid_character_sequence_after_doctype_name);
            self.setDoctypeForceQuirks();
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.57 After DOCTYPE public keyword state
    fn afterDoctypePublicKeywordState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .before_doctype_public_identifier;
            return null;
        } else if (char.is('"')) {
            self.reportError(.missing_whitespace_after_doctype_public_keyword);
            self.startDoctypePublicIdentifier();
            self.state = .doctype_public_identifier_double_quoted;
            return null;
        } else if (char.is('\'')) {
            self.reportError(.missing_whitespace_after_doctype_public_keyword);
            self.startDoctypePublicIdentifier();
            self.state = .doctype_public_identifier_single_quoted;
            return null;
        } else if (char.is('>')) {
            self.reportError(.missing_doctype_public_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            self.reportError(.missing_quote_before_doctype_public_identifier);
            self.setDoctypeForceQuirks();
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.58 Before DOCTYPE public identifier state
    fn beforeDoctypePublicIdentifierState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('"')) {
            self.startDoctypePublicIdentifier();
            self.state = .doctype_public_identifier_double_quoted;
            return null;
        } else if (char.is('\'')) {
            self.startDoctypePublicIdentifier();
            self.state = .doctype_public_identifier_single_quoted;
            return null;
        } else if (char.is('>')) {
            self.reportError(.missing_doctype_public_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            self.reportError(.missing_quote_before_doctype_public_identifier);
            self.setDoctypeForceQuirks();
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.59 DOCTYPE public identifier (double-quoted) state
    fn doctypePublicIdentifierDoubleQuotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('"')) {
            self.state = .after_doctype_public_identifier;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendCodepointToCurrentDoctypePublicIdentifier(0xFFFD);
            return null;
        } else if (char.is('>')) {
            self.reportError(.abrupt_doctype_public_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            const cp = char.getCodepoint().?;
            if (cp <= 0xFF) {
                try self.appendToCurrentDoctypePublicIdentifier(@intCast(cp));
            }
            return null;
        }
    }

    /// §13.2.5.60 DOCTYPE public identifier (single-quoted) state
    fn doctypePublicIdentifierSingleQuotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('\'')) {
            self.state = .after_doctype_public_identifier;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendCodepointToCurrentDoctypePublicIdentifier(0xFFFD);
            return null;
        } else if (char.is('>')) {
            self.reportError(.abrupt_doctype_public_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            const cp = char.getCodepoint().?;
            if (cp <= 0xFF) {
                try self.appendToCurrentDoctypePublicIdentifier(@intCast(cp));
            }
            return null;
        }
    }

    /// §13.2.5.61 After DOCTYPE public identifier state
    fn afterDoctypePublicIdentifierState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .between_doctype_public_and_system_identifiers;
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.is('"')) {
            self.reportError(.missing_whitespace_between_doctype_public_and_system_identifiers);
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_double_quoted;
            return null;
        } else if (char.is('\'')) {
            self.reportError(.missing_whitespace_between_doctype_public_and_system_identifiers);
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_single_quoted;
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            self.reportError(.missing_quote_before_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.62 Between DOCTYPE public and system identifiers state
    fn betweenDoctypePublicAndSystemIdentifiersState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.is('"')) {
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_double_quoted;
            return null;
        } else if (char.is('\'')) {
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_single_quoted;
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            self.reportError(.missing_quote_before_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.63 After DOCTYPE system keyword state
    fn afterDoctypeSystemKeywordState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            self.state = .before_doctype_system_identifier;
            return null;
        } else if (char.is('"')) {
            self.reportError(.missing_whitespace_after_doctype_system_keyword);
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_double_quoted;
            return null;
        } else if (char.is('\'')) {
            self.reportError(.missing_whitespace_after_doctype_system_keyword);
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_single_quoted;
            return null;
        } else if (char.is('>')) {
            self.reportError(.missing_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            self.reportError(.missing_quote_before_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.64 Before DOCTYPE system identifier state
    fn beforeDoctypeSystemIdentifierState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('"')) {
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_double_quoted;
            return null;
        } else if (char.is('\'')) {
            self.startDoctypeSystemIdentifier();
            self.state = .doctype_system_identifier_single_quoted;
            return null;
        } else if (char.is('>')) {
            self.reportError(.missing_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            self.reportError(.missing_quote_before_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.65 DOCTYPE system identifier (double-quoted) state
    fn doctypeSystemIdentifierDoubleQuotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('"')) {
            self.state = .after_doctype_system_identifier;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendCodepointToCurrentDoctypeSystemIdentifier(0xFFFD);
            return null;
        } else if (char.is('>')) {
            self.reportError(.abrupt_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            const cp = char.getCodepoint().?;
            if (cp <= 0xFF) {
                try self.appendToCurrentDoctypeSystemIdentifier(@intCast(cp));
            }
            return null;
        }
    }

    /// §13.2.5.66 DOCTYPE system identifier (single-quoted) state
    fn doctypeSystemIdentifierSingleQuotedState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('\'')) {
            self.state = .after_doctype_system_identifier;
            return null;
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            try self.appendCodepointToCurrentDoctypeSystemIdentifier(0xFFFD);
            return null;
        } else if (char.is('>')) {
            self.reportError(.abrupt_doctype_system_identifier);
            self.setDoctypeForceQuirks();
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            const cp = char.getCodepoint().?;
            if (cp <= 0xFF) {
                try self.appendToCurrentDoctypeSystemIdentifier(@intCast(cp));
            }
            return null;
        }
    }

    /// §13.2.5.67 After DOCTYPE system identifier state
    fn afterDoctypeSystemIdentifierState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isHtmlWhitespace()) {
            // Ignore
            return null;
        } else if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.isEof()) {
            self.reportError(.eof_in_doctype);
            self.setDoctypeForceQuirks();
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            self.reportError(.unexpected_character_after_doctype_system_identifier);
            self.reconsume = true;
            self.state = .bogus_doctype;
            return null;
        }
    }

    /// §13.2.5.68 Bogus DOCTYPE state
    fn bogusDoctypeState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is('>')) {
            self.state = .data;
            return try self.emitCurrentDoctype();
        } else if (char.is(0x00)) {
            self.reportError(.unexpected_null_character);
            // Ignore
            return null;
        } else if (char.isEof()) {
            const doctype = try self.emitCurrentDoctype();
            try self.token_queue.append(Token.eof);
            return doctype;
        } else {
            // Ignore
            return null;
        }
    }

    /// §13.2.5.69 CDATA section state
    fn cdataSectionState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is(']')) {
            self.state = .cdata_section_bracket;
            return null;
        } else if (char.isEof()) {
            self.reportError(.eof_in_cdata);
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
    }

    /// §13.2.5.70 CDATA section bracket state
    fn cdataSectionBracketState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is(']')) {
            self.state = .cdata_section_end;
            return null;
        } else {
            self.reconsume = true;
            self.state = .cdata_section;
            return Token{ .character = ']' };
        }
    }

    /// §13.2.5.71 CDATA section end state
    fn cdataSectionEndState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.is(']')) {
            return Token{ .character = ']' };
        } else if (char.is('>')) {
            self.state = .data;
            return null;
        } else {
            self.reconsume = true;
            self.state = .cdata_section;
            try self.token_queue.append(Token{ .character = ']' });
            return Token{ .character = ']' };
        }
    }

    /// §13.2.5.72 Character reference state
    fn characterReferenceState(self: *Tokenizer) !?Token {
        self.temporary_buffer.clear();
        try self.temporary_buffer.append('&');

        const char = self.current_char;

        if (char.isAsciiAlphanumeric()) {
            self.reconsume = true;
            self.state = .named_character_reference;
            return null;
        } else if (char.is('#')) {
            try self.temporary_buffer.append('#');
            self.state = .numeric_character_reference;
            return null;
        } else {
            try self.flushCodePointsAsCharacterReference();
            self.reconsume = true;
            self.state = self.return_state;
            return null;
        }
    }

    /// §13.2.5.73 Named character reference state
    /// Implements the full named character reference lookup algorithm.
    fn namedCharacterReferenceState(self: *Tokenizer) !?Token {
        // Collect characters that could be part of a named character reference
        // We need to peek ahead to find the longest matching entity
        var entity_buffer: [64]u8 = undefined;
        var entity_len: usize = 0;

        // Copy what we have in the temporary buffer (after the &)
        const temp_slice = self.temporary_buffer.items();
        // Skip the '&' at the start
        const start_offset: usize = if (temp_slice.len > 0 and temp_slice[0] == '&') 1 else 0;
        for (temp_slice[start_offset..]) |c| {
            if (entity_len < entity_buffer.len) {
                entity_buffer[entity_len] = c;
                entity_len += 1;
            }
        }

        // Include the current character
        if (self.current_char.getCodepoint()) |cp| {
            if (cp < 128) {
                if (entity_len < entity_buffer.len) {
                    entity_buffer[entity_len] = @intCast(cp);
                    entity_len += 1;
                }
            }
        }

        // Keep consuming alphanumeric characters to build the potential entity name
        while (true) {
            const next_char = self.peekNextChar();
            if (next_char.isAsciiAlphanumeric() or next_char.is(';')) {
                if (next_char.getCodepoint()) |cp| {
                    if (entity_len < entity_buffer.len) {
                        entity_buffer[entity_len] = @intCast(cp);
                        entity_len += 1;
                    }
                    _ = self.consumeNextChar();
                    // Stop if we hit a semicolon
                    if (next_char.is(';')) break;
                } else break;
            } else {
                break;
            }
        }

        // Look up the longest matching entity
        const input_slice = entity_buffer[0..entity_len];
        const result = entities.lookup(input_slice);

        if (result.entity) |entity| {
            // Check if this is an entity being consumed as part of an attribute
            // Per spec: If the character reference was consumed as part of an attribute,
            // and the last character matched is not ';', and the next input character
            // is either '=' or an ASCII alphanumeric, then flush and switch to return state
            const ends_with_semicolon = entities.hasSemicolon(entity.name);

            if (!ends_with_semicolon and self.isConsumedAsPartOfAttribute()) {
                // Check the next character
                const next = self.peekNextChar();
                if (next.is('=') or next.isAsciiAlphanumeric()) {
                    // Flush the temporary buffer and don't treat as character reference
                    try self.flushCodePointsAsCharacterReference();
                    // Append what we consumed
                    for (input_slice) |c| {
                        if (self.isConsumedAsPartOfAttribute()) {
                            try self.appendToCurrentAttributeValue(c);
                        }
                    }
                    self.state = self.return_state;
                    return null;
                }
            }

            // Report parse error if entity doesn't end with semicolon
            if (!ends_with_semicolon) {
                self.reportError(.missing_semicolon_after_character_reference);
            }

            // Clear the temporary buffer
            self.temporary_buffer.clear();

            // Emit the codepoints from the entity
            // We need to handle this differently based on whether we're in an attribute or not
            if (self.isConsumedAsPartOfAttribute()) {
                for (entity.codepoints) |cp| {
                    try self.appendToCurrentAttributeValue(cp);
                }
                // Append any unconsumed characters after the matched entity
                if (result.consumed < entity_len) {
                    for (input_slice[result.consumed..]) |c| {
                        try self.appendToCurrentAttributeValue(c);
                    }
                }
            } else {
                // Emit character tokens for each codepoint
                // First codepoint returned now, rest will be handled by pending_tokens mechanism
                // For simplicity, emit as characters
                for (entity.codepoints) |cp| {
                    try self.temporary_buffer.append(@intCast(cp & 0xFF));
                    if (cp > 0xFF) {
                        // Handle multi-byte codepoints
                        try self.temporary_buffer.append(@intCast((cp >> 8) & 0xFF));
                        if (cp > 0xFFFF) {
                            try self.temporary_buffer.append(@intCast((cp >> 16) & 0xFF));
                        }
                    }
                }
            }

            self.state = self.return_state;

            // If not in attribute, return the first codepoint as a character token
            if (!self.isConsumedAsPartOfAttribute() and entity.codepoints.len > 0) {
                return Token{ .character = entity.codepoints[0] };
            }
            return null;
        } else {
            // No match found - flush and switch to ambiguous ampersand state
            try self.flushCodePointsAsCharacterReference();
            // Also append the characters we consumed
            for (input_slice) |c| {
                if (self.isConsumedAsPartOfAttribute()) {
                    try self.appendToCurrentAttributeValue(c);
                }
            }
            self.state = .ambiguous_ampersand;
            return null;
        }
    }

    /// §13.2.5.74 Ambiguous ampersand state
    fn ambiguousAmpersandState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiAlphanumeric()) {
            if (self.isConsumedAsPartOfAttribute()) {
                try self.appendToCurrentAttributeValue(char.getCodepoint().?);
            } else {
                return Token{ .character = char.getCodepoint().? };
            }
            return null;
        } else if (char.is(';')) {
            self.reportError(.unknown_named_character_reference);
            self.reconsume = true;
            self.state = self.return_state;
            return null;
        } else {
            self.reconsume = true;
            self.state = self.return_state;
            return null;
        }
    }

    /// §13.2.5.75 Numeric character reference state
    fn numericCharacterReferenceState(self: *Tokenizer) !?Token {
        self.character_reference_code = 0;

        const char = self.current_char;

        if (char.is('x') or char.is('X')) {
            try self.temporary_buffer.append(@intCast(char.getCodepoint().?));
            self.state = .hexadecimal_character_reference_start;
            return null;
        } else {
            self.reconsume = true;
            self.state = .decimal_character_reference_start;
            return null;
        }
    }

    /// §13.2.5.76 Hexadecimal character reference start state
    fn hexadecimalCharacterReferenceStartState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiHexDigit()) {
            self.reconsume = true;
            self.state = .hexadecimal_character_reference;
            return null;
        } else {
            self.reportError(.absence_of_digits_in_numeric_character_reference);
            try self.flushCodePointsAsCharacterReference();
            self.reconsume = true;
            self.state = self.return_state;
            return null;
        }
    }

    /// §13.2.5.77 Decimal character reference start state
    fn decimalCharacterReferenceStartState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiDigit()) {
            self.reconsume = true;
            self.state = .decimal_character_reference;
            return null;
        } else {
            self.reportError(.absence_of_digits_in_numeric_character_reference);
            try self.flushCodePointsAsCharacterReference();
            self.reconsume = true;
            self.state = self.return_state;
            return null;
        }
    }

    /// §13.2.5.78 Hexadecimal character reference state
    fn hexadecimalCharacterReferenceState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiDigit()) {
            self.character_reference_code *|= 16;
            self.character_reference_code +|= @intCast(char.getCodepoint().? - 0x30);
            return null;
        } else if (char.isAsciiUpperHexDigit()) {
            self.character_reference_code *|= 16;
            self.character_reference_code +|= @intCast(char.getCodepoint().? - 0x37);
            return null;
        } else if (char.isAsciiLowerHexDigit()) {
            self.character_reference_code *|= 16;
            self.character_reference_code +|= @intCast(char.getCodepoint().? - 0x57);
            return null;
        } else if (char.is(';')) {
            self.state = .numeric_character_reference_end;
            return null;
        } else {
            self.reportError(.missing_semicolon_after_character_reference);
            self.reconsume = true;
            self.state = .numeric_character_reference_end;
            return null;
        }
    }

    /// §13.2.5.79 Decimal character reference state
    fn decimalCharacterReferenceState(self: *Tokenizer) !?Token {
        const char = self.current_char;

        if (char.isAsciiDigit()) {
            self.character_reference_code *|= 10;
            self.character_reference_code +|= @intCast(char.getCodepoint().? - 0x30);
            return null;
        } else if (char.is(';')) {
            self.state = .numeric_character_reference_end;
            return null;
        } else {
            self.reportError(.missing_semicolon_after_character_reference);
            self.reconsume = true;
            self.state = .numeric_character_reference_end;
            return null;
        }
    }

    /// §13.2.5.80 Numeric character reference end state
    fn numericCharacterReferenceEndState(self: *Tokenizer) !?Token {
        var code = self.character_reference_code;

        // Apply replacements per spec
        if (code == 0) {
            self.reportError(.null_character_reference);
            code = 0xFFFD;
        } else if (code > 0x10FFFF) {
            self.reportError(.character_reference_outside_unicode_range);
            code = 0xFFFD;
        } else if (code >= 0xD800 and code <= 0xDFFF) {
            self.reportError(.surrogate_character_reference);
            code = 0xFFFD;
        } else if ((code >= 0xFDD0 and code <= 0xFDEF) or
            (code & 0xFFFF == 0xFFFE) or (code & 0xFFFF == 0xFFFF))
        {
            self.reportError(.noncharacter_character_reference);
            // Keep the code
        } else if ((code >= 0x01 and code <= 0x08) or
            code == 0x0B or
            (code >= 0x0D and code <= 0x1F) or
            (code >= 0x7F and code <= 0x9F))
        {
            self.reportError(.control_character_reference);
            // Apply C1 control character replacements
            code = switch (code) {
                0x80 => 0x20AC, // EURO SIGN
                0x82 => 0x201A, // SINGLE LOW-9 QUOTATION MARK
                0x83 => 0x0192, // LATIN SMALL LETTER F WITH HOOK
                0x84 => 0x201E, // DOUBLE LOW-9 QUOTATION MARK
                0x85 => 0x2026, // HORIZONTAL ELLIPSIS
                0x86 => 0x2020, // DAGGER
                0x87 => 0x2021, // DOUBLE DAGGER
                0x88 => 0x02C6, // MODIFIER LETTER CIRCUMFLEX ACCENT
                0x89 => 0x2030, // PER MILLE SIGN
                0x8A => 0x0160, // LATIN CAPITAL LETTER S WITH CARON
                0x8B => 0x2039, // SINGLE LEFT-POINTING ANGLE QUOTATION MARK
                0x8C => 0x0152, // LATIN CAPITAL LIGATURE OE
                0x8E => 0x017D, // LATIN CAPITAL LETTER Z WITH CARON
                0x91 => 0x2018, // LEFT SINGLE QUOTATION MARK
                0x92 => 0x2019, // RIGHT SINGLE QUOTATION MARK
                0x93 => 0x201C, // LEFT DOUBLE QUOTATION MARK
                0x94 => 0x201D, // RIGHT DOUBLE QUOTATION MARK
                0x95 => 0x2022, // BULLET
                0x96 => 0x2013, // EN DASH
                0x97 => 0x2014, // EM DASH
                0x98 => 0x02DC, // SMALL TILDE
                0x99 => 0x2122, // TRADE MARK SIGN
                0x9A => 0x0161, // LATIN SMALL LETTER S WITH CARON
                0x9B => 0x203A, // SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
                0x9C => 0x0153, // LATIN SMALL LIGATURE OE
                0x9E => 0x017E, // LATIN SMALL LETTER Z WITH CARON
                0x9F => 0x0178, // LATIN CAPITAL LETTER Y WITH DIAERESIS
                else => code,
            };
        }

        // Emit or append
        self.temporary_buffer.clear();
        // Encode as UTF-8 in temporary buffer conceptually, but we just emit directly
        if (self.isConsumedAsPartOfAttribute()) {
            try self.appendToCurrentAttributeValue(@intCast(code));
        } else {
            self.state = self.return_state;
            return Token{ .character = @intCast(code) };
        }

        self.state = self.return_state;
        return null;
    }

    // =========================================================================
    // Helper functions
    // =========================================================================

    /// Check if current end tag is appropriate.
    fn isAppropriateEndTag(self: *Tokenizer) bool {
        if (self.last_start_tag_name) |last_name| {
            if (self.current_token) |*token| {
                const tag = switch (token.*) {
                    .end_tag => |*t| t,
                    else => return false,
                };
                return std.mem.eql(u8, tag.getTagName(), last_name.toSlice());
            }
        }
        return false;
    }

    /// Check if character reference is consumed as part of an attribute.
    fn isConsumedAsPartOfAttribute(self: *Tokenizer) bool {
        return self.return_state == .attribute_value_double_quoted or
            self.return_state == .attribute_value_single_quoted or
            self.return_state == .attribute_value_unquoted;
    }

    /// Check if temporary buffer equals a string.
    fn temporaryBufferEquals(self: *Tokenizer, expected: []const u8) bool {
        return std.mem.eql(u8, self.temporary_buffer.toSlice(), expected);
    }

    /// Emit temporary buffer contents as character tokens.
    fn emitTemporaryBufferAsCharacters(self: *Tokenizer) !void {
        const slice = self.temporary_buffer.toSlice();
        for (slice) |c| {
            try self.token_queue.append(Token{ .character = c });
        }
    }

    /// Flush code points consumed as character reference.
    fn flushCodePointsAsCharacterReference(self: *Tokenizer) !void {
        const slice = self.temporary_buffer.toSlice();
        for (slice) |c| {
            if (self.isConsumedAsPartOfAttribute()) {
                try self.appendToCurrentAttributeValue(c);
            } else {
                try self.token_queue.append(Token{ .character = c });
            }
        }
    }

    /// Append to current tag name.
    fn appendToCurrentTagName(self: *Tokenizer, cp: u21) !void {
        if (self.current_token) |*token| {
            const tag = switch (token.*) {
                .start_tag => |*t| t,
                .end_tag => |*t| t,
                else => return,
            };
            try tag.appendCodepointToTagName(cp);
        }
    }

    /// Start a new attribute in current tag.
    fn startNewAttribute(self: *Tokenizer) !void {
        if (self.current_token) |*token| {
            const tag = switch (token.*) {
                .start_tag => |*t| t,
                .end_tag => |*t| t,
                else => return,
            };
            try tag.startNewAttribute();
        }
    }

    /// Append to current attribute name.
    fn appendToCurrentAttributeName(self: *Tokenizer, cp: u21) !void {
        if (self.current_token) |*token| {
            const tag = switch (token.*) {
                .start_tag => |*t| t,
                .end_tag => |*t| t,
                else => return,
            };
            try tag.appendCodepointToAttributeName(cp);
        }
    }

    /// Append to current attribute value.
    fn appendToCurrentAttributeValue(self: *Tokenizer, cp: u21) !void {
        if (self.current_token) |*token| {
            const tag = switch (token.*) {
                .start_tag => |*t| t,
                .end_tag => |*t| t,
                else => return,
            };
            try tag.appendCodepointToAttributeValue(cp);
        }
    }

    /// Batch append to current attribute value (more efficient for ASCII runs).
    fn appendSliceToCurrentAttributeValue(self: *Tokenizer, slice: []const u8) !void {
        if (self.current_token) |*token| {
            const tag = switch (token.*) {
                .start_tag => |*t| t,
                .end_tag => |*t| t,
                else => return,
            };
            try tag.appendSliceToAttributeValue(slice);
        }
    }

    /// Batch append attribute value characters until quote or special char.
    /// Scans ahead in the raw input to find runs of normal ASCII characters
    /// and appends them all at once, avoiding per-character overhead.
    ///
    /// Returns the number of bytes consumed from input (including current char).
    fn batchAppendAttributeValue(self: *Tokenizer, quote: u8) struct { consumed: usize } {
        // Batch optimization is not supported for dynamic input
        if (self.input_stream_manager != null) {
            return .{ .consumed = 0 };
        }

        // Get the raw input data starting at current position
        // Note: We've already consumed current_char, so we're looking at remaining input
        const remaining = self.input.remaining();
        if (remaining == 0) {
            return .{ .consumed = 0 };
        }

        const data = self.input.data;
        const start_pos = self.input.position;

        // Scan for run of "normal" ASCII characters (not quote, &, NULL, or non-ASCII)
        var end_pos = start_pos;
        while (end_pos < data.len) {
            const byte = data[end_pos];
            // Stop on: quote char, ampersand, NULL, CR/LF (need newline normalization), or non-ASCII
            if (byte == quote or byte == '&' or byte == 0x00 or
                byte == 0x0D or byte == 0x0A or byte >= 0x80)
            {
                break;
            }
            end_pos += 1;
        }

        const batch_len = end_pos - start_pos;
        if (batch_len == 0) {
            return .{ .consumed = 0 };
        }

        // Get the current character that was already consumed
        const current_cp = self.current_char.getCodepoint() orelse return .{ .consumed = 0 };
        if (current_cp >= 128) {
            return .{ .consumed = 0 };
        }

        // Build slice including current char + batch
        // Current char is ASCII, so it's 1 byte
        const current_byte: u8 = @intCast(current_cp);

        // Append current char + batch slice in one go
        if (self.current_token) |*token| {
            const tag = switch (token.*) {
                .start_tag => |*t| t,
                .end_tag => |*t| t,
                else => return .{ .consumed = 0 },
            };

            // Append current char
            tag.appendSliceToAttributeValue(&[_]u8{current_byte}) catch return .{ .consumed = 0 };

            // Append batch if any
            if (batch_len > 0) {
                tag.appendSliceToAttributeValue(data[start_pos..end_pos]) catch return .{ .consumed = 0 };

                // Advance input position past the batch
                self.input.position = end_pos;
                self.input.column += @intCast(batch_len);
            }
        }

        return .{ .consumed = 1 + batch_len };
    }

    /// Set self-closing flag on current tag.
    fn setSelfClosingFlag(self: *Tokenizer) void {
        if (self.current_token) |*token| {
            const tag = switch (token.*) {
                .start_tag => |*t| t,
                .end_tag => |*t| t,
                else => return,
            };
            tag.self_closing = true;
        }
    }

    /// Emit current tag token.
    fn emitCurrentTag(self: *Tokenizer) !Token {
        if (self.current_token) |*token| {
            // Finish any pending attribute
            switch (token.*) {
                .start_tag => |*t| {
                    try t.finishCurrentAttribute();
                    // Save start tag name
                    if (self.last_start_tag_name) |*name| {
                        name.deinit();
                    }
                    self.last_start_tag_name = infra.List(u8).init(self.allocator);
                    const slice = t.tag_name.toSlice();
                    for (slice) |c| {
                        try self.last_start_tag_name.?.append(c);
                    }
                },
                .end_tag => |*t| {
                    try t.finishCurrentAttribute();
                },
                else => {},
            }

            const result = token.*;
            self.current_token = null;
            return result;
        }
        return Token.eof;
    }

    /// Append to current comment data.
    fn appendToCurrentCommentData(self: *Tokenizer, cp: u21) !void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .comment => |*c| {
                    try c.appendCodepointToData(cp);
                },
                else => {},
            }
        }
    }

    /// Emit current comment token.
    fn emitCurrentComment(self: *Tokenizer) !Token {
        if (self.current_token) |token| {
            self.current_token = null;
            return token;
        }
        return Token.eof;
    }

    /// Append to current DOCTYPE name.
    fn appendToCurrentDoctypeName(self: *Tokenizer, char: u8) !void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| try d.appendToName(char),
                else => {},
            }
        }
    }

    /// Append a Unicode codepoint to current DOCTYPE name (UTF-8 encoded).
    fn appendCodepointToCurrentDoctypeName(self: *Tokenizer, codepoint: u21) !void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| try d.appendCodepointToName(codepoint),
                else => {},
            }
        }
    }

    /// Set force-quirks on current DOCTYPE.
    fn setDoctypeForceQuirks(self: *Tokenizer) void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| d.force_quirks = true,
                else => {},
            }
        }
    }

    /// Start DOCTYPE public identifier.
    fn startDoctypePublicIdentifier(self: *Tokenizer) void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| d.startPublicIdentifier(),
                else => {},
            }
        }
    }

    /// Append to DOCTYPE public identifier.
    fn appendToCurrentDoctypePublicIdentifier(self: *Tokenizer, char: u8) !void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| try d.appendToPublicIdentifier(char),
                else => {},
            }
        }
    }

    /// Append a Unicode codepoint to DOCTYPE public identifier (UTF-8 encoded).
    fn appendCodepointToCurrentDoctypePublicIdentifier(self: *Tokenizer, codepoint: u21) !void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| try d.appendCodepointToPublicIdentifier(codepoint),
                else => {},
            }
        }
    }

    /// Start DOCTYPE system identifier.
    fn startDoctypeSystemIdentifier(self: *Tokenizer) void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| d.startSystemIdentifier(),
                else => {},
            }
        }
    }

    /// Append to DOCTYPE system identifier.
    fn appendToCurrentDoctypeSystemIdentifier(self: *Tokenizer, char: u8) !void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| try d.appendToSystemIdentifier(char),
                else => {},
            }
        }
    }

    /// Append a Unicode codepoint to DOCTYPE system identifier (UTF-8 encoded).
    fn appendCodepointToCurrentDoctypeSystemIdentifier(self: *Tokenizer, codepoint: u21) !void {
        if (self.current_token) |*token| {
            switch (token.*) {
                .doctype => |*d| try d.appendCodepointToSystemIdentifier(codepoint),
                else => {},
            }
        }
    }

    /// Emit current DOCTYPE token.
    fn emitCurrentDoctype(self: *Tokenizer) !Token {
        if (self.current_token) |token| {
            self.current_token = null;
            return token;
        }
        // Return empty doctype if none
        return Token{ .doctype = DoctypeToken.init(self.allocator) };
    }
};

// =========================================================================
// Tests
// =========================================================================

test "Tokenizer - simple text" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "hello");
    defer tokenizer.deinit();

    // Should emit 5 character tokens
    var chars: [5]u21 = undefined;
    for (0..5) |i| {
        const token = (try tokenizer.nextToken()).?;
        chars[i] = token.character;
    }

    try std.testing.expectEqualStrings("hello", &[_]u8{
        @intCast(chars[0]),
        @intCast(chars[1]),
        @intCast(chars[2]),
        @intCast(chars[3]),
        @intCast(chars[4]),
    });

    // Next should be null (EOF)
    try std.testing.expectEqual(@as(?Token, null), try tokenizer.nextToken());
}

test "Tokenizer - simple tag" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "<div>");
    defer tokenizer.deinit();

    const token = (try tokenizer.nextToken()).?;
    try std.testing.expect(token == .start_tag);

    var tag = token.start_tag;
    defer tag.deinit();

    try std.testing.expectEqualStrings("div", tag.getTagName());
    try std.testing.expect(!tag.is_end_tag);
    try std.testing.expect(!tag.self_closing);
}

test "Tokenizer - end tag" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "</div>");
    defer tokenizer.deinit();

    const token = (try tokenizer.nextToken()).?;
    try std.testing.expect(token == .end_tag);

    var tag = token.end_tag;
    defer tag.deinit();

    try std.testing.expectEqualStrings("div", tag.getTagName());
    try std.testing.expect(tag.is_end_tag);
}

test "Tokenizer - self-closing tag" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "<br/>");
    defer tokenizer.deinit();

    const token = (try tokenizer.nextToken()).?;
    try std.testing.expect(token == .start_tag);

    var tag = token.start_tag;
    defer tag.deinit();

    try std.testing.expectEqualStrings("br", tag.getTagName());
    try std.testing.expect(tag.self_closing);
}

test "Tokenizer - tag with attributes" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "<div id=\"foo\" class='bar'>");
    defer tokenizer.deinit();

    const token = (try tokenizer.nextToken()).?;
    try std.testing.expect(token == .start_tag);

    var tag = token.start_tag;
    defer tag.deinit();

    try std.testing.expectEqualStrings("div", tag.getTagName());
    try std.testing.expectEqual(@as(usize, 2), tag.attributes.len);

    const id_attr = tag.getAttribute("id");
    try std.testing.expect(id_attr != null);
    try std.testing.expectEqualStrings("foo", id_attr.?.getValue());

    const class_attr = tag.getAttribute("class");
    try std.testing.expect(class_attr != null);
    try std.testing.expectEqualStrings("bar", class_attr.?.getValue());
}

test "Tokenizer - DOCTYPE" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "<!DOCTYPE html>");
    defer tokenizer.deinit();

    const token = (try tokenizer.nextToken()).?;
    try std.testing.expect(token == .doctype);

    var doctype = token.doctype;
    defer doctype.deinit();

    try std.testing.expectEqualStrings("html", doctype.getName().?);
    try std.testing.expect(!doctype.force_quirks);
}

test "Tokenizer - comment" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "<!-- hello -->");
    defer tokenizer.deinit();

    const token = (try tokenizer.nextToken()).?;
    try std.testing.expect(token == .comment);

    var comment = token.comment;
    defer comment.deinit();

    try std.testing.expectEqualStrings(" hello ", comment.getData());
}

test "Tokenizer - case insensitive tag names" {
    const allocator = std.testing.allocator;

    var tokenizer = Tokenizer.init(allocator, "<DIV>");
    defer tokenizer.deinit();

    const token = (try tokenizer.nextToken()).?;
    try std.testing.expect(token == .start_tag);

    var tag = token.start_tag;
    defer tag.deinit();

    // Tag names should be lowercased
    try std.testing.expectEqualStrings("div", tag.getTagName());
}
