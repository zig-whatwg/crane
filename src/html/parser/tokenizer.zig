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

/// HTML Tokenizer.
///
/// Implements the tokenization stage of the HTML parsing algorithm.
pub const Tokenizer = struct {
    /// Memory allocator.
    allocator: Allocator,

    /// Input stream.
    input: InputStream,

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

    /// Whether to reconsume the current character.
    reconsume: bool,

    /// Current input character (for reconsume).
    current_char: InputCharacter,

    /// Error callback.
    error_callback: ?ParseErrorCallback,

    /// Error context.
    error_context: ?*anyopaque,

    /// Initialize a new tokenizer.
    pub fn init(allocator: Allocator, input: []const u8) Tokenizer {
        return Tokenizer{
            .allocator = allocator,
            .input = InputStream.init(input),
            .state = .data,
            .return_state = .data,
            .current_token = null,
            .temporary_buffer = infra.List(u8).init(allocator),
            .last_start_tag_name = null,
            .character_reference_code = 0,
            .token_queue = infra.List(Token).init(allocator),
            .reconsume = false,
            .current_char = .eof,
            .error_callback = null,
            .error_context = null,
        };
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
        // Free any remaining tokens in queue
        const slice = self.token_queue.toSliceMut();
        for (slice) |*token| {
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
        // If we have queued tokens, return one
        if (self.token_queue.len > 0) {
            // TODO: Remove first element - for now just clear and rebuild
            const slice = self.token_queue.toSlice();
            if (slice.len > 0) {
                const token = slice[0];
                // Shift remaining elements (inefficient but simple)
                var new_queue = infra.List(Token).init(self.allocator);
                for (slice[1..]) |t| {
                    try new_queue.append(t);
                }
                self.token_queue.deinit();
                self.token_queue = new_queue;
                return token;
            }
        }

        // Process states until we emit a token
        while (true) {
            // Get next character (or reconsume)
            if (self.reconsume) {
                self.reconsume = false;
            } else {
                self.current_char = self.input.consume();
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

    /// Process the current state and return emitted token if any.
    fn processState(self: *Tokenizer) !?Token {
        return switch (self.state) {
            .data => try self.dataState(),
            .rcdata => try self.rcdataState(),
            .rawtext => try self.rawtextState(),
            .script_data => try self.scriptDataState(),
            .plaintext => try self.plaintextState(),
            .tag_open => try self.tagOpenState(),
            .end_tag_open => try self.endTagOpenState(),
            .tag_name => try self.tagNameState(),
            .rcdata_less_than_sign => try self.rcdataLessThanSignState(),
            .rcdata_end_tag_open => try self.rcdataEndTagOpenState(),
            .rcdata_end_tag_name => try self.rcdataEndTagNameState(),
            .rawtext_less_than_sign => try self.rawtextLessThanSignState(),
            .rawtext_end_tag_open => try self.rawtextEndTagOpenState(),
            .rawtext_end_tag_name => try self.rawtextEndTagNameState(),
            .script_data_less_than_sign => try self.scriptDataLessThanSignState(),
            .script_data_end_tag_open => try self.scriptDataEndTagOpenState(),
            .script_data_end_tag_name => try self.scriptDataEndTagNameState(),
            .script_data_escape_start => try self.scriptDataEscapeStartState(),
            .script_data_escape_start_dash => try self.scriptDataEscapeStartDashState(),
            .script_data_escaped => try self.scriptDataEscapedState(),
            .script_data_escaped_dash => try self.scriptDataEscapedDashState(),
            .script_data_escaped_dash_dash => try self.scriptDataEscapedDashDashState(),
            .script_data_escaped_less_than_sign => try self.scriptDataEscapedLessThanSignState(),
            .script_data_escaped_end_tag_open => try self.scriptDataEscapedEndTagOpenState(),
            .script_data_escaped_end_tag_name => try self.scriptDataEscapedEndTagNameState(),
            .script_data_double_escape_start => try self.scriptDataDoubleEscapeStartState(),
            .script_data_double_escaped => try self.scriptDataDoubleEscapedState(),
            .script_data_double_escaped_dash => try self.scriptDataDoubleEscapedDashState(),
            .script_data_double_escaped_dash_dash => try self.scriptDataDoubleEscapedDashDashState(),
            .script_data_double_escaped_less_than_sign => try self.scriptDataDoubleEscapedLessThanSignState(),
            .script_data_double_escape_end => try self.scriptDataDoubleEscapeEndState(),
            .before_attribute_name => try self.beforeAttributeNameState(),
            .attribute_name => try self.attributeNameState(),
            .after_attribute_name => try self.afterAttributeNameState(),
            .before_attribute_value => try self.beforeAttributeValueState(),
            .attribute_value_double_quoted => try self.attributeValueDoubleQuotedState(),
            .attribute_value_single_quoted => try self.attributeValueSingleQuotedState(),
            .attribute_value_unquoted => try self.attributeValueUnquotedState(),
            .after_attribute_value_quoted => try self.afterAttributeValueQuotedState(),
            .self_closing_start_tag => try self.selfClosingStartTagState(),
            .bogus_comment => try self.bogusCommentState(),
            .markup_declaration_open => try self.markupDeclarationOpenState(),
            .comment_start => try self.commentStartState(),
            .comment_start_dash => try self.commentStartDashState(),
            .comment => try self.commentState(),
            .comment_less_than_sign => try self.commentLessThanSignState(),
            .comment_less_than_sign_bang => try self.commentLessThanSignBangState(),
            .comment_less_than_sign_bang_dash => try self.commentLessThanSignBangDashState(),
            .comment_less_than_sign_bang_dash_dash => try self.commentLessThanSignBangDashDashState(),
            .comment_end_dash => try self.commentEndDashState(),
            .comment_end => try self.commentEndState(),
            .comment_end_bang => try self.commentEndBangState(),
            .doctype => try self.doctypeState(),
            .before_doctype_name => try self.beforeDoctypeNameState(),
            .doctype_name => try self.doctypeNameState(),
            .after_doctype_name => try self.afterDoctypeNameState(),
            .after_doctype_public_keyword => try self.afterDoctypePublicKeywordState(),
            .before_doctype_public_identifier => try self.beforeDoctypePublicIdentifierState(),
            .doctype_public_identifier_double_quoted => try self.doctypePublicIdentifierDoubleQuotedState(),
            .doctype_public_identifier_single_quoted => try self.doctypePublicIdentifierSingleQuotedState(),
            .after_doctype_public_identifier => try self.afterDoctypePublicIdentifierState(),
            .between_doctype_public_and_system_identifiers => try self.betweenDoctypePublicAndSystemIdentifiersState(),
            .after_doctype_system_keyword => try self.afterDoctypeSystemKeywordState(),
            .before_doctype_system_identifier => try self.beforeDoctypeSystemIdentifierState(),
            .doctype_system_identifier_double_quoted => try self.doctypeSystemIdentifierDoubleQuotedState(),
            .doctype_system_identifier_single_quoted => try self.doctypeSystemIdentifierSingleQuotedState(),
            .after_doctype_system_identifier => try self.afterDoctypeSystemIdentifierState(),
            .bogus_doctype => try self.bogusDoctypeState(),
            .cdata_section => try self.cdataSectionState(),
            .cdata_section_bracket => try self.cdataSectionBracketState(),
            .cdata_section_end => try self.cdataSectionEndState(),
            .character_reference => try self.characterReferenceState(),
            .named_character_reference => try self.namedCharacterReferenceState(),
            .ambiguous_ampersand => try self.ambiguousAmpersandState(),
            .numeric_character_reference => try self.numericCharacterReferenceState(),
            .hexadecimal_character_reference_start => try self.hexadecimalCharacterReferenceStartState(),
            .decimal_character_reference_start => try self.decimalCharacterReferenceStartState(),
            .hexadecimal_character_reference => try self.hexadecimalCharacterReferenceState(),
            .decimal_character_reference => try self.decimalCharacterReferenceState(),
            .numeric_character_reference_end => try self.numericCharacterReferenceEndState(),
        };
    }

    // =========================================================================
    // State implementations
    // =========================================================================

    /// §13.2.5.1 Data state
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
            return Token.eof;
        } else {
            return Token{ .character = char.getCodepoint().? };
        }
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
        self.reconsume = true;
        self.state = .rcdata;
        try self.emitTemporaryBufferAsCharacters();
        try self.token_queue.append(Token{ .character = '/' });
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
        self.reconsume = true;
        self.state = .rawtext;
        try self.emitTemporaryBufferAsCharacters();
        try self.token_queue.append(Token{ .character = '/' });
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
        self.reconsume = true;
        self.state = .script_data;
        try self.emitTemporaryBufferAsCharacters();
        try self.token_queue.append(Token{ .character = '/' });
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
        self.reconsume = true;
        self.state = .script_data_escaped;
        try self.emitTemporaryBufferAsCharacters();
        try self.token_queue.append(Token{ .character = '/' });
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
            try self.appendToCurrentAttributeValue(char.getCodepoint().?);
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
            try self.appendToCurrentAttributeValue(char.getCodepoint().?);
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
    fn markupDeclarationOpenState(self: *Tokenizer) !?Token {
        // Check for "--"
        if (self.input.matchesAsciiCaseInsensitive("--")) {
            _ = self.input.consume();
            _ = self.input.consume();
            self.current_token = Token{ .comment = CommentToken.init(self.allocator) };
            self.state = .comment_start;
            return null;
        }
        // Check for "DOCTYPE"
        else if (self.input.matchesAsciiCaseInsensitive("DOCTYPE")) {
            for (0..7) |_| {
                _ = self.input.consume();
            }
            self.state = .doctype;
            return null;
        }
        // Check for "[CDATA["
        else if (self.input.matchesAsciiCaseInsensitive("[CDATA[")) {
            for (0..7) |_| {
                _ = self.input.consume();
            }
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
        } else {
            self.reportError(.incorrectly_opened_comment);
            self.current_token = Token{ .comment = CommentToken.init(self.allocator) };
            self.state = .bogus_comment;
            // Don't consume - reconsume current char
            self.reconsume = true;
            return null;
        }
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
            if (self.input.matchesAsciiCaseInsensitive("PUBLIC")) {
                // Need to "unconsume" current char and consume "PUBLIC"
                self.reconsume = true;
                if (self.input.consumeAsciiCaseInsensitive("PUBLIC")) {
                    self.state = .after_doctype_public_keyword;
                    return null;
                }
            } else if (self.input.matchesAsciiCaseInsensitive("SYSTEM")) {
                self.reconsume = true;
                if (self.input.consumeAsciiCaseInsensitive("SYSTEM")) {
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

    /// §13.2.5.73 Named character reference state (simplified)
    fn namedCharacterReferenceState(self: *Tokenizer) !?Token {
        // Simplified implementation - just flush and return
        // A full implementation would look up named character references
        try self.flushCodePointsAsCharacterReference();
        self.state = .ambiguous_ampersand;
        return null;
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
                .end_tag => |*t| try t.finishCurrentAttribute(),
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
