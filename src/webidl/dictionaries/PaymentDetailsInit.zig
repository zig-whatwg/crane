//! WebIDL dictionary: PaymentDetailsInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentDetailsBase = @import("PaymentDetailsBase.zig").PaymentDetailsBase;

pub const PaymentDetailsInit = struct {
    // Inherited from PaymentDetailsBase
    base: PaymentDetailsBase,

    id: ?runtime.DOMString = null,
    total: anyopaque,
};
