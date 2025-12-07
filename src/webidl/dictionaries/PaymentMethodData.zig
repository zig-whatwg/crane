//! WebIDL dictionary: PaymentMethodData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PaymentMethodData = struct {
    supportedMethods: runtime.DOMString,
    data: ?runtime.JSValue = null,
};
