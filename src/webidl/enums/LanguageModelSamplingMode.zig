//! WebIDL enum: LanguageModelSamplingMode
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const LanguageModelSamplingMode = enum {
    _most_predictable_,
    _predictable_,
    _slightly_predictable_,
    _balanced_,
    _slightly_creative_,
    _creative_,
    _most_creative_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "most-predictable", "predictable", "slightly-predictable", "balanced", "slightly-creative", "creative", "most-creative" };
};
