//! WebIDL dictionary: PaymentMethodChangeEventInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentRequestUpdateEventInit = @import("PaymentRequestUpdateEventInit.zig").PaymentRequestUpdateEventInit;

pub const PaymentMethodChangeEventInit = struct {
    // Inherited from PaymentRequestUpdateEventInit
    base: PaymentRequestUpdateEventInit,

    methodName: ?runtime.DOMString = null,
    methodDetails: ?runtime.JSValue = null,

    /// Optional members whose IDL type is nullable: a present null is the
    /// value null. Any other member's present null converts by its type.
    pub const nullable_members = .{"methodDetails"};
};
