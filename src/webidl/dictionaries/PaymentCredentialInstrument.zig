//! WebIDL dictionary: PaymentCredentialInstrument
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");

pub const PaymentCredentialInstrument = struct {
    displayName: runtime.USVString,
    icon: runtime.USVString,
    iconMustBeShown: ?bool = null,
    details: ?runtime.USVString = null,
};
