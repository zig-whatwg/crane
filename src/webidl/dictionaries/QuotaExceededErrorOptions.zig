//! WebIDL dictionary: QuotaExceededErrorOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const QuotaExceededErrorOptions = struct {
    quota: ?f64 = null,
    requested: ?f64 = null,

    /// WebIDL `double` and `float` members (not `unrestricted`): NaN and the
    /// infinities throw a TypeError when the dictionary is converted.
    pub const restricted_members = .{ "quota", "requested" };
};
