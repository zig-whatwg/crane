//! WebIDL dictionary: PaymentHandlerResponse
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AddressInit = @import("AddressInit.zig").AddressInit;

pub const PaymentHandlerResponse = struct {
    methodName: ?runtime.DOMString = null,
    details: ?runtime.JSValue = null,
    payerName: ?runtime.DOMString = null,
    payerEmail: ?runtime.DOMString = null,
    payerPhone: ?runtime.DOMString = null,
    shippingAddress: ?AddressInit = null,
    shippingOption: ?runtime.DOMString = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"details"};

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{ "payerName", "payerEmail", "payerPhone", "shippingOption" };
};
