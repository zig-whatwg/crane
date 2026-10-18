//! WebIDL dictionary: PaymentValidationErrors
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PayerErrors = @import("PayerErrors.zig").PayerErrors;
const AddressErrors = @import("AddressErrors.zig").AddressErrors;

pub const PaymentValidationErrors = struct {
    payer: ?PayerErrors = null,
    shippingAddress: ?AddressErrors = null,
    @"error": ?runtime.DOMString = null,
    paymentMethod: ?runtime.JSValue = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"paymentMethod"};
};
