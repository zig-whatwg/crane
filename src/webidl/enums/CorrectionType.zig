//! WebIDL enum: CorrectionType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const CorrectionType = enum {
    _spelling_,
    _punctuation_,
    _capitalization_,
    _grammar_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "spelling", "punctuation", "capitalization", "grammar" };
};
