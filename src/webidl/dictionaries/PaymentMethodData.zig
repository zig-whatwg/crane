//! WebIDL dictionary: PaymentMethodData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const PaymentMethodData = struct {
    supportedMethods: runtime.DOMString,
    data: ?runtime.JSValue = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"data"};
};
