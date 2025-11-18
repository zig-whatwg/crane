//! WebIDL dictionary: CollectedClientAdditionalPaymentData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const CollectedClientAdditionalPaymentData = struct {
    rpId: runtime.DOMString,
    topOrigin: runtime.DOMString,
    payeeName: ?runtime.DOMString = null,
    payeeOrigin: ?runtime.DOMString = null,
    paymentEntitiesLogos: ?anyopaque = null,
    total: anyopaque,
    instrument: anyopaque,
    browserBoundPublicKey: ?runtime.DOMString = null,
};
