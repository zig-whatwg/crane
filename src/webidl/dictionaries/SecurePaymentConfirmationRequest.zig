//! WebIDL dictionary: SecurePaymentConfirmationRequest
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SecurePaymentConfirmationRequest = struct {
    challenge: anyopaque,
    rpId: runtime.DOMString,
    credentialIds: anyopaque,
    instrument: anyopaque,
    timeout: ?u32 = null,
    payeeName: ?runtime.DOMString = null,
    payeeOrigin: ?runtime.DOMString = null,
    paymentEntitiesLogos: ?anyopaque = null,
    extensions: ?anyopaque = null,
    browserBoundPubKeyCredParams: ?anyopaque = null,
    locale: ?anyopaque = null,
    showOptOut: ?bool = null,
};
