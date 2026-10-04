//! WebIDL enum: ScriptWindowAttribution
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ScriptWindowAttribution = enum {
    _self_,
    _descendant_,
    _ancestor_,
    _same_page_,
    _other_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "self", "descendant", "ancestor", "same-page", "other" };
};
