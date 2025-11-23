//! WebIDL dictionary: AuthenticationExtensionsPaymentInputs
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const AuthenticationExtensionsPaymentInputs = struct {
    isPayment: ?bool = null,
    browserBoundPubKeyCredParams: ?*const anyopaque = null,
    rpId: ?runtime.USVString = null,
    topOrigin: ?runtime.USVString = null,
    payeeName: ?runtime.USVString = null,
    payeeOrigin: ?runtime.USVString = null,
    paymentEntitiesLogos: ?*const anyopaque = null,
    total: ?*const anyopaque = null,
    instrument: ?*const anyopaque = null,
};
