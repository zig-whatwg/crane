//! HTML Parse Errors
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parse-errors
//! HTML Standard §13.2.2 "Parse errors"
//!
//! Parse errors are only errors with the *syntax* of HTML. The error handling
//! for parse errors is well-defined (that's the processing rules described
//! throughout this specification).

const std = @import("std");

const log = std.log.scoped(.parse_errors);

/// Parse error codes as defined in the HTML specification.
///
/// HTML Standard §13.2.2:
/// "Some parse errors have dedicated codes outlined in the table below
/// that should be used by conformance checkers in reports."
pub const ParseErrorCode = enum {
    // DOCTYPE errors
    abrupt_closing_of_empty_comment,
    abrupt_doctype_public_identifier,
    abrupt_doctype_system_identifier,

    // Character reference errors
    absence_of_digits_in_numeric_character_reference,
    character_reference_outside_unicode_range,
    control_character_reference,
    missing_semicolon_after_character_reference,
    noncharacter_character_reference,
    null_character_reference,
    surrogate_character_reference,
    unknown_named_character_reference,

    // CDATA errors
    cdata_in_html_content,
    eof_in_cdata,

    // Comment errors
    eof_in_comment,
    incorrectly_closed_comment,
    incorrectly_opened_comment,
    nested_comment,

    // DOCTYPE errors
    eof_in_doctype,
    invalid_character_sequence_after_doctype_name,
    missing_doctype_name,
    missing_doctype_public_identifier,
    missing_doctype_system_identifier,
    missing_quote_before_doctype_public_identifier,
    missing_quote_before_doctype_system_identifier,
    missing_whitespace_after_doctype_public_keyword,
    missing_whitespace_after_doctype_system_keyword,
    missing_whitespace_before_doctype_name,
    missing_whitespace_between_doctype_public_and_system_identifiers,

    // Tag errors
    duplicate_attribute,
    end_tag_with_attributes,
    end_tag_with_trailing_solidus,
    eof_before_tag_name,
    eof_in_script_html_comment_like_text,
    eof_in_tag,
    invalid_first_character_of_tag_name,
    missing_attribute_value,
    missing_end_tag_name,
    missing_whitespace_between_attributes,
    non_void_html_element_start_tag_with_trailing_solidus,
    unexpected_character_after_doctype_system_identifier,
    unexpected_character_in_attribute_name,
    unexpected_character_in_unquoted_attribute_value,
    unexpected_equals_sign_before_attribute_name,
    unexpected_null_character,
    unexpected_solidus_in_tag,

    // Processing instruction errors. Spec: HTML 13.2.2 - each one names the
    // processing instruction states (13.2.5.72-73) that report it. (The
    // tag open state's former unexpected-question-mark-instead-of-tag-name
    // went with whatwg/html#12118, which made "<?" open a processing
    // instruction.)
    disallowed_processing_instruction_target,
    eof_in_processing_instruction,
    invalid_first_character_of_processing_instruction_target,
    invalid_processing_instruction_target,

    // Input stream errors
    control_character_in_input_stream,
    noncharacter_in_input_stream,
    surrogate_in_input_stream,

    // Tree construction errors (for foreign content, etc.)
    unexpected_token_in_foreign_content,
};

/// Get a human-readable description for a parse error code.
pub fn getErrorDescription(code: ParseErrorCode) []const u8 {
    return switch (code) {
        .abrupt_closing_of_empty_comment => "Empty comment abruptly closed",
        .abrupt_doctype_public_identifier => "DOCTYPE public identifier abruptly terminated",
        .abrupt_doctype_system_identifier => "DOCTYPE system identifier abruptly terminated",
        .absence_of_digits_in_numeric_character_reference => "Numeric character reference has no digits",
        .character_reference_outside_unicode_range => "Character reference outside valid Unicode range",
        .control_character_reference => "Character reference to control character",
        .missing_semicolon_after_character_reference => "Character reference not terminated with semicolon",
        .noncharacter_character_reference => "Character reference to noncharacter",
        .null_character_reference => "Character reference to null",
        .surrogate_character_reference => "Character reference to surrogate",
        .unknown_named_character_reference => "Unknown named character reference",
        .cdata_in_html_content => "CDATA section in HTML content",
        .eof_in_cdata => "End of file in CDATA section",
        .eof_in_comment => "End of file in comment",
        .incorrectly_closed_comment => "Comment incorrectly closed with --!>",
        .incorrectly_opened_comment => "Comment incorrectly opened",
        .nested_comment => "Nested comment",
        .eof_in_doctype => "End of file in DOCTYPE",
        .invalid_character_sequence_after_doctype_name => "Invalid characters after DOCTYPE name",
        .missing_doctype_name => "Missing DOCTYPE name",
        .missing_doctype_public_identifier => "Missing DOCTYPE public identifier",
        .missing_doctype_system_identifier => "Missing DOCTYPE system identifier",
        .missing_quote_before_doctype_public_identifier => "Missing quote before DOCTYPE public identifier",
        .missing_quote_before_doctype_system_identifier => "Missing quote before DOCTYPE system identifier",
        .missing_whitespace_after_doctype_public_keyword => "Missing whitespace after PUBLIC keyword",
        .missing_whitespace_after_doctype_system_keyword => "Missing whitespace after SYSTEM keyword",
        .missing_whitespace_before_doctype_name => "Missing whitespace before DOCTYPE name",
        .missing_whitespace_between_doctype_public_and_system_identifiers => "Missing whitespace between PUBLIC and SYSTEM identifiers",
        .duplicate_attribute => "Duplicate attribute",
        .end_tag_with_attributes => "End tag with attributes",
        .end_tag_with_trailing_solidus => "End tag with trailing /",
        .eof_before_tag_name => "End of file before tag name",
        .eof_in_script_html_comment_like_text => "End of file in script HTML-like comment",
        .eof_in_tag => "End of file in tag",
        .invalid_first_character_of_tag_name => "Invalid first character of tag name",
        .missing_attribute_value => "Missing attribute value",
        .missing_end_tag_name => "Missing end tag name",
        .missing_whitespace_between_attributes => "Missing whitespace between attributes",
        .non_void_html_element_start_tag_with_trailing_solidus => "Non-void element start tag with trailing /",
        .unexpected_character_after_doctype_system_identifier => "Unexpected character after DOCTYPE system identifier",
        .unexpected_character_in_attribute_name => "Unexpected character in attribute name",
        .unexpected_character_in_unquoted_attribute_value => "Unexpected character in unquoted attribute value",
        .unexpected_equals_sign_before_attribute_name => "Unexpected = before attribute name",
        .unexpected_null_character => "Unexpected null character",
        .unexpected_solidus_in_tag => "Unexpected / in tag",
        .disallowed_processing_instruction_target => "Processing instruction target is xml or xml-stylesheet",
        .eof_in_processing_instruction => "End of file in processing instruction",
        .invalid_first_character_of_processing_instruction_target => "Invalid first character of processing instruction target",
        .invalid_processing_instruction_target => "Invalid character in processing instruction target",
        .control_character_in_input_stream => "Control character in input stream",
        .noncharacter_in_input_stream => "Noncharacter in input stream",
        .surrogate_in_input_stream => "Surrogate in input stream",
        .unexpected_token_in_foreign_content => "Unexpected token in foreign content",
    };
}

/// A parse error with location information.
pub const ParseError = struct {
    /// The error code.
    code: ParseErrorCode,

    /// Line number (1-based).
    line: u32,

    /// Column number (1-based).
    column: u32,

    /// Byte offset in the input (0-based).
    offset: usize,
};

/// Callback type for reporting parse errors.
pub const ParseErrorCallback = *const fn (error_info: ParseError, context: ?*anyopaque) void;

/// Parse error reporter that logs errors immediately.
///
/// Use this for immediate feedback during development or debugging.
pub const ParseErrorLogger = struct {
    /// Callback type for custom logging.
    pub const LogCallback = *const fn ([]const u8) void;

    /// Custom log callback (null = use stderr).
    log_callback: ?LogCallback,

    /// Whether to include location info.
    include_location: bool,

    /// Initialize a new error logger.
    pub fn init() ParseErrorLogger {
        return ParseErrorLogger{
            .log_callback = null,
            .include_location = true,
        };
    }

    /// Initialize with a custom log callback.
    pub fn initWithCallback(log_callback: LogCallback) ParseErrorLogger {
        return ParseErrorLogger{
            .log_callback = log_callback,
            .include_location = true,
        };
    }

    /// Static callback function for use with the tokenizer.
    pub fn callback(error_info: ParseError, context: ?*anyopaque) void {
        if (context) |ctx| {
            const logger: *ParseErrorLogger = @ptrCast(@alignCast(ctx));
            logger.logError(error_info);
        } else {
            // Default: log to stderr
            log.warn("Parse error: {s}", .{getErrorDescription(error_info.code)});
        }
    }

    /// Log a single error.
    fn logError(self: *ParseErrorLogger, err: ParseError) void {
        const desc = getErrorDescription(err.code);

        if (self.log_callback) |log_cb| {
            // Custom logging - build message
            var buf: [256]u8 = undefined;
            const msg = if (self.include_location)
                std.fmt.bufPrint(&buf, "{d}:{d}: {s}", .{ err.line, err.column, desc }) catch desc
            else
                desc;
            log_cb(msg);
        } else {
            // Default: stderr
            if (self.include_location) {
                log.warn("{d}:{d}: Parse error: {s}", .{ err.line, err.column, desc });
            } else {
                log.warn("Parse error: {s}", .{desc});
            }
        }
    }
};
