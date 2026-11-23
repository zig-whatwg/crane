//! WebIDL dictionary: CollectedClientAdditionalPaymentData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;
const PaymentCredentialInstrument = @import("PaymentCredentialInstrument.zig").PaymentCredentialInstrument;
const PaymentEntityLogo = @import("PaymentEntityLogo.zig").PaymentEntityLogo;

pub const CollectedClientAdditionalPaymentData = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    rpId: runtime.USVString,
    topOrigin: runtime.USVString,
    payeeName: ?runtime.USVString = null,
    payeeOrigin: ?runtime.USVString = null,
    paymentEntitiesLogos: ?[]const PaymentEntityLogo = null,
    total: PaymentCurrencyAmount,
    instrument: PaymentCredentialInstrument,
    browserBoundPublicKey: ?runtime.USVString = null,
};
