//! WebIDL dictionary: ConstrainBooleanOrDOMStringParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const ConstrainBooleanOrDOMStringParameters = struct {
    exact: ?runtime.JSValue = null,
    ideal: ?runtime.JSValue = null,

    /// Inline union members typed runtime.JSValue: one present with the
    /// value null converts to `.null`, for the impl to convert by the union.
    pub const jsvalue_union_members = .{ "exact", "ideal" };
};
