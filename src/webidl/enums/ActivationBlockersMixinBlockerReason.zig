//! WebIDL enum: ActivationBlockersMixinBlockerReason
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const ActivationBlockersMixinBlockerReason = enum {
    __,
    _illegal_subframe_,
    _unsuccessful_registration_,
    _recently_attached_,
    _intersection_changed_,
    _intersection_out_of_viewport_or_clipped_,
    _intersection_occluded_or_distorted_,
    _style_invalid_,
    _type_invalid_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "", "illegal_subframe", "unsuccessful_registration", "recently_attached", "intersection_changed", "intersection_out_of_viewport_or_clipped", "intersection_occluded_or_distorted", "style_invalid", "type_invalid" };
};
