//! WebIDL dictionary: PaymentMethodChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentRequestUpdateEventInit = @import("PaymentRequestUpdateEventInit.zig").PaymentRequestUpdateEventInit;

pub const PaymentMethodChangeEventInit = struct {
    // Inherited from PaymentRequestUpdateEventInit
    base: PaymentRequestUpdateEventInit,

    methodName: ?runtime.DOMString = null,
    methodDetails: ?anyopaque = null,
};
