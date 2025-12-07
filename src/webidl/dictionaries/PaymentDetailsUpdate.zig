//! WebIDL dictionary: PaymentDetailsUpdate
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
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
};
