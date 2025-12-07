//! WebIDL dictionary: PaymentValidationErrors
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const PayerErrors = @import("PayerErrors.zig").PayerErrors;
const AddressErrors = @import("AddressErrors.zig").AddressErrors;

pub const PaymentValidationErrors = struct {
    payer: ?PayerErrors = null,
    shippingAddress: ?AddressErrors = null,
    @"error": ?runtime.DOMString = null,
    paymentMethod: ?runtime.JSValue = null,
};
