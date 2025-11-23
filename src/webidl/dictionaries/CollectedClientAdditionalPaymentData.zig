//! WebIDL dictionary: CollectedClientAdditionalPaymentData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CollectedClientAdditionalPaymentData = struct {
    rpId: runtime.USVString,
    topOrigin: runtime.USVString,
    payeeName: ?runtime.USVString = null,
    payeeOrigin: ?runtime.USVString = null,
    paymentEntitiesLogos: ?*const anyopaque = null,
    total: *const anyopaque,
    instrument: *const anyopaque,
    browserBoundPublicKey: ?runtime.USVString = null,
};
