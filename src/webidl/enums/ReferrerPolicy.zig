//! WebIDL enum: ReferrerPolicy
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ReferrerPolicy = enum {
    __,
    _no_referrer_,
    _no_referrer_when_downgrade_,
    _same_origin_,
    _origin_,
    _strict_origin_,
    _origin_when_cross_origin_,
    _strict_origin_when_cross_origin_,
    _unsafe_url_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "", "no-referrer", "no-referrer-when-downgrade", "same-origin", "origin", "strict-origin", "origin-when-cross-origin", "strict-origin-when-cross-origin", "unsafe-url" };
};
