//! WebIDL dictionary: AuthenticationExtensionsPaymentInputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const PaymentCurrencyAmount = @import("PaymentCurrencyAmount.zig").PaymentCurrencyAmount;
const PublicKeyCredentialParameters = @import("PublicKeyCredentialParameters.zig").PublicKeyCredentialParameters;
const PaymentCredentialInstrument = @import("PaymentCredentialInstrument.zig").PaymentCredentialInstrument;
const PaymentEntityLogo = @import("PaymentEntityLogo.zig").PaymentEntityLogo;

pub const AuthenticationExtensionsPaymentInputs = struct {
    isPayment: ?bool = null,
    browserBoundPubKeyCredParams: ?[]const PublicKeyCredentialParameters = null,
    rpId: ?runtime.USVString = null,
    topOrigin: ?runtime.USVString = null,
    payeeName: ?runtime.USVString = null,
    payeeOrigin: ?runtime.USVString = null,
    paymentEntitiesLogos: ?[]const PaymentEntityLogo = null,
    total: ?PaymentCurrencyAmount = null,
    instrument: ?PaymentCredentialInstrument = null,
};
