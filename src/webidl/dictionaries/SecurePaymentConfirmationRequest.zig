//! WebIDL dictionary: SecurePaymentConfirmationRequest
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const AuthenticationExtensionsClientInputs = @import("AuthenticationExtensionsClientInputs.zig").AuthenticationExtensionsClientInputs;
const PaymentCredentialInstrument = @import("PaymentCredentialInstrument.zig").PaymentCredentialInstrument;
const PublicKeyCredentialParameters = @import("PublicKeyCredentialParameters.zig").PublicKeyCredentialParameters;
const PaymentEntityLogo = @import("PaymentEntityLogo.zig").PaymentEntityLogo;

pub const SecurePaymentConfirmationRequest = struct {
    challenge: typedefs.BufferSource,
    rpId: runtime.USVString,
    credentialIds: []const typedefs.BufferSource,
    instrument: PaymentCredentialInstrument,
    timeout: ?u32 = null,
    payeeName: ?runtime.USVString = null,
    payeeOrigin: ?runtime.USVString = null,
    paymentEntitiesLogos: ?[]const PaymentEntityLogo = null,
    extensions: ?AuthenticationExtensionsClientInputs = null,
    browserBoundPubKeyCredParams: ?[]const PublicKeyCredentialParameters = null,
    locale: ?[]const runtime.USVString = null,
    showOptOut: ?bool = null,
};
