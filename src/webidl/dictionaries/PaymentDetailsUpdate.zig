//! WebIDL dictionary: PaymentDetailsUpdate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const AddressErrors = @import("AddressErrors.zig").AddressErrors;
const PayerErrors = @import("PayerErrors.zig").PayerErrors;
const PaymentItem = @import("PaymentItem.zig").PaymentItem;
const PaymentDetailsBase = @import("PaymentDetailsBase.zig").PaymentDetailsBase;

pub const PaymentDetailsUpdate = struct {
    // Inherited from PaymentDetailsBase
    base: PaymentDetailsBase,

    @"error": ?runtime.DOMString = null,
    total: ?PaymentItem = null,
    shippingAddressErrors: ?AddressErrors = null,
    payerErrors: ?PayerErrors = null,
    paymentMethodErrors: ?runtime.JSValue = null,

    /// WebIDL `object` members (or sequences of `object`): a value that is
    /// not an Object throws a TypeError when the dictionary is converted.
    pub const object_members = .{"paymentMethodErrors"};
};
