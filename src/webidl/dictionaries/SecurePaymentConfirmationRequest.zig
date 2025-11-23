//! WebIDL dictionary: SecurePaymentConfirmationRequest
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const SecurePaymentConfirmationRequest = struct {
    challenge: *const anyopaque,
    rpId: runtime.USVString,
    credentialIds: *const anyopaque,
    instrument: *const anyopaque,
    timeout: ?u32 = null,
    payeeName: ?runtime.USVString = null,
    payeeOrigin: ?runtime.USVString = null,
    paymentEntitiesLogos: ?*const anyopaque = null,
    extensions: ?*const anyopaque = null,
    browserBoundPubKeyCredParams: ?*const anyopaque = null,
    locale: ?*const anyopaque = null,
    showOptOut: ?bool = null,
};
