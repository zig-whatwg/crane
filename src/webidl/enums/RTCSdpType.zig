//! WebIDL enum: RTCSdpType
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RTCSdpType = enum {
    _offer_,
    _pranswer_,
    _answer_,
    _rollback_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "offer", "pranswer", "answer", "rollback" };
};
