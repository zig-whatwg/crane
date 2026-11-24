//! HTML Tokenizer States
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization
//! HTML Standard §13.2.5 "Tokenization"
//!
//! The tokenizer state machine has the specification's 84 states (13.2.5.1-84),
//! and one of its own: decimal_character_reference_start.

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

    // Processing instruction states (13.2.5.72-76)
    processing_instruction_open,
    processing_instruction_target,
    after_processing_instruction_target,
    processing_instruction_data,
    processing_instruction_questionable,

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
