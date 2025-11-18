//! WebIDL dictionary: AuthenticationExtensionsPaymentInputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticationExtensionsPaymentInputs = struct {
    isPayment: ?bool = null,
    browserBoundPubKeyCredParams: ?anyopaque = null,
    rpId: ?runtime.DOMString = null,
    topOrigin: ?runtime.DOMString = null,
    payeeName: ?runtime.DOMString = null,
    payeeOrigin: ?runtime.DOMString = null,
    paymentEntitiesLogos: ?anyopaque = null,
    total: ?anyopaque = null,
    instrument: ?anyopaque = null,
};
