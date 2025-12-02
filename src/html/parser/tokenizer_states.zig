//! HTML Tokenizer States
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization
//! HTML Standard §13.2.5 "Tokenization"
//!
//! The tokenizer state machine has 80 states as defined in the specification.

/// Tokenizer states as defined in HTML Standard §13.2.5.
///
/// The state machine must start in the data state. Most states consume a
/// single character, which may have various side-effects, and either switches
/// the state machine to a new state to reconsume the current input character,
/// or switches it to a new state to consume the next character, or stays in
/// the same state to consume the next character.
pub const State = enum {
    // Main states
    data,
    rcdata,
    rawtext,
    script_data,
    plaintext,

    // Tag states
    tag_open,
    end_tag_open,
    tag_name,
    rcdata_less_than_sign,
    rcdata_end_tag_open,
    rcdata_end_tag_name,
    rawtext_less_than_sign,
    rawtext_end_tag_open,
    rawtext_end_tag_name,
    script_data_less_than_sign,
    script_data_end_tag_open,
    script_data_end_tag_name,
    script_data_escape_start,
    script_data_escape_start_dash,
    script_data_escaped,
    script_data_escaped_dash,
    script_data_escaped_dash_dash,
    script_data_escaped_less_than_sign,
    script_data_escaped_end_tag_open,
    script_data_escaped_end_tag_name,
    script_data_double_escape_start,
    script_data_double_escaped,
    script_data_double_escaped_dash,
    script_data_double_escaped_dash_dash,
    script_data_double_escaped_less_than_sign,
    script_data_double_escape_end,

    // Attribute states
    before_attribute_name,
    attribute_name,
    after_attribute_name,
    before_attribute_value,
    attribute_value_double_quoted,
    attribute_value_single_quoted,
    attribute_value_unquoted,
    after_attribute_value_quoted,
    self_closing_start_tag,

    // Comment states
    bogus_comment,
    markup_declaration_open,
    comment_start,
    comment_start_dash,
    comment,
    comment_less_than_sign,
    comment_less_than_sign_bang,
    comment_less_than_sign_bang_dash,
    comment_less_than_sign_bang_dash_dash,
    comment_end_dash,
    comment_end,
    comment_end_bang,

    // DOCTYPE states
    doctype,
    before_doctype_name,
    doctype_name,
    after_doctype_name,
    after_doctype_public_keyword,
    before_doctype_public_identifier,
    doctype_public_identifier_double_quoted,
    doctype_public_identifier_single_quoted,
    after_doctype_public_identifier,
    between_doctype_public_and_system_identifiers,
    after_doctype_system_keyword,
    before_doctype_system_identifier,
    doctype_system_identifier_double_quoted,
    doctype_system_identifier_single_quoted,
    after_doctype_system_identifier,
    bogus_doctype,

    // CDATA states
    cdata_section,
    cdata_section_bracket,
    cdata_section_end,

    // Character reference states
    character_reference,
    named_character_reference,
    ambiguous_ampersand,
    numeric_character_reference,
    hexadecimal_character_reference_start,
    decimal_character_reference_start,
    hexadecimal_character_reference,
    decimal_character_reference,
    numeric_character_reference_end,
};

/// Get a human-readable name for a tokenizer state.
pub fn getStateName(state: State) []const u8 {
    return switch (state) {
        .data => "Data state",
        .rcdata => "RCDATA state",
        .rawtext => "RAWTEXT state",
        .script_data => "Script data state",
        .plaintext => "PLAINTEXT state",
        .tag_open => "Tag open state",
        .end_tag_open => "End tag open state",
        .tag_name => "Tag name state",
        .rcdata_less_than_sign => "RCDATA less-than sign state",
        .rcdata_end_tag_open => "RCDATA end tag open state",
        .rcdata_end_tag_name => "RCDATA end tag name state",
        .rawtext_less_than_sign => "RAWTEXT less-than sign state",
        .rawtext_end_tag_open => "RAWTEXT end tag open state",
        .rawtext_end_tag_name => "RAWTEXT end tag name state",
        .script_data_less_than_sign => "Script data less-than sign state",
        .script_data_end_tag_open => "Script data end tag open state",
        .script_data_end_tag_name => "Script data end tag name state",
        .script_data_escape_start => "Script data escape start state",
        .script_data_escape_start_dash => "Script data escape start dash state",
        .script_data_escaped => "Script data escaped state",
        .script_data_escaped_dash => "Script data escaped dash state",
        .script_data_escaped_dash_dash => "Script data escaped dash dash state",
        .script_data_escaped_less_than_sign => "Script data escaped less-than sign state",
        .script_data_escaped_end_tag_open => "Script data escaped end tag open state",
        .script_data_escaped_end_tag_name => "Script data escaped end tag name state",
        .script_data_double_escape_start => "Script data double escape start state",
        .script_data_double_escaped => "Script data double escaped state",
        .script_data_double_escaped_dash => "Script data double escaped dash state",
        .script_data_double_escaped_dash_dash => "Script data double escaped dash dash state",
        .script_data_double_escaped_less_than_sign => "Script data double escaped less-than sign state",
        .script_data_double_escape_end => "Script data double escape end state",
        .before_attribute_name => "Before attribute name state",
        .attribute_name => "Attribute name state",
        .after_attribute_name => "After attribute name state",
        .before_attribute_value => "Before attribute value state",
        .attribute_value_double_quoted => "Attribute value (double-quoted) state",
        .attribute_value_single_quoted => "Attribute value (single-quoted) state",
        .attribute_value_unquoted => "Attribute value (unquoted) state",
        .after_attribute_value_quoted => "After attribute value (quoted) state",
        .self_closing_start_tag => "Self-closing start tag state",
        .bogus_comment => "Bogus comment state",
        .markup_declaration_open => "Markup declaration open state",
        .comment_start => "Comment start state",
        .comment_start_dash => "Comment start dash state",
        .comment => "Comment state",
        .comment_less_than_sign => "Comment less-than sign state",
        .comment_less_than_sign_bang => "Comment less-than sign bang state",
        .comment_less_than_sign_bang_dash => "Comment less-than sign bang dash state",
        .comment_less_than_sign_bang_dash_dash => "Comment less-than sign bang dash dash state",
        .comment_end_dash => "Comment end dash state",
        .comment_end => "Comment end state",
        .comment_end_bang => "Comment end bang state",
        .doctype => "DOCTYPE state",
        .before_doctype_name => "Before DOCTYPE name state",
        .doctype_name => "DOCTYPE name state",
        .after_doctype_name => "After DOCTYPE name state",
        .after_doctype_public_keyword => "After DOCTYPE public keyword state",
        .before_doctype_public_identifier => "Before DOCTYPE public identifier state",
        .doctype_public_identifier_double_quoted => "DOCTYPE public identifier (double-quoted) state",
        .doctype_public_identifier_single_quoted => "DOCTYPE public identifier (single-quoted) state",
        .after_doctype_public_identifier => "After DOCTYPE public identifier state",
        .between_doctype_public_and_system_identifiers => "Between DOCTYPE public and system identifiers state",
        .after_doctype_system_keyword => "After DOCTYPE system keyword state",
        .before_doctype_system_identifier => "Before DOCTYPE system identifier state",
        .doctype_system_identifier_double_quoted => "DOCTYPE system identifier (double-quoted) state",
        .doctype_system_identifier_single_quoted => "DOCTYPE system identifier (single-quoted) state",
        .after_doctype_system_identifier => "After DOCTYPE system identifier state",
        .bogus_doctype => "Bogus DOCTYPE state",
        .cdata_section => "CDATA section state",
        .cdata_section_bracket => "CDATA section bracket state",
        .cdata_section_end => "CDATA section end state",
        .character_reference => "Character reference state",
        .named_character_reference => "Named character reference state",
        .ambiguous_ampersand => "Ambiguous ampersand state",
        .numeric_character_reference => "Numeric character reference state",
        .hexadecimal_character_reference_start => "Hexadecimal character reference start state",
        .decimal_character_reference_start => "Decimal character reference start state",
        .hexadecimal_character_reference => "Hexadecimal character reference state",
        .decimal_character_reference => "Decimal character reference state",
        .numeric_character_reference_end => "Numeric character reference end state",
    };
}

/// States that process RCDATA content.
pub fn isRcdataState(state: State) bool {
    return switch (state) {
        .rcdata,
        .rcdata_less_than_sign,
        .rcdata_end_tag_open,
        .rcdata_end_tag_name,
        => true,
        else => false,
    };
}

/// States that process RAWTEXT content.
pub fn isRawtextState(state: State) bool {
    return switch (state) {
        .rawtext,
        .rawtext_less_than_sign,
        .rawtext_end_tag_open,
        .rawtext_end_tag_name,
        => true,
        else => false,
    };
}

/// States that process script data.
pub fn isScriptDataState(state: State) bool {
    return switch (state) {
        .script_data,
        .script_data_less_than_sign,
        .script_data_end_tag_open,
        .script_data_end_tag_name,
        .script_data_escape_start,
        .script_data_escape_start_dash,
        .script_data_escaped,
        .script_data_escaped_dash,
        .script_data_escaped_dash_dash,
        .script_data_escaped_less_than_sign,
        .script_data_escaped_end_tag_open,
        .script_data_escaped_end_tag_name,
        .script_data_double_escape_start,
        .script_data_double_escaped,
        .script_data_double_escaped_dash,
        .script_data_double_escaped_dash_dash,
        .script_data_double_escaped_less_than_sign,
        .script_data_double_escape_end,
        => true,
        else => false,
    };
}

/// States that are part of character reference processing.
pub fn isCharacterReferenceState(state: State) bool {
    return switch (state) {
        .character_reference,
        .named_character_reference,
        .ambiguous_ampersand,
        .numeric_character_reference,
        .hexadecimal_character_reference_start,
        .decimal_character_reference_start,
        .hexadecimal_character_reference,
        .decimal_character_reference,
        .numeric_character_reference_end,
        => true,
        else => false,
    };
}

test "State - getStateName" {
    const name = getStateName(.data);
    const std = @import("std");
    try std.testing.expectEqualStrings("Data state", name);
}

test "State - isScriptDataState" {
    const std = @import("std");
    try std.testing.expect(isScriptDataState(.script_data));
    try std.testing.expect(isScriptDataState(.script_data_escaped));
    try std.testing.expect(!isScriptDataState(.data));
    try std.testing.expect(!isScriptDataState(.tag_name));
}
