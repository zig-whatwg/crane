//! WebIDL dictionary: CollectedClientPaymentData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CollectedClientAdditionalPaymentRegistrationData = @import("CollectedClientAdditionalPaymentRegistrationData.zig").CollectedClientAdditionalPaymentRegistrationData;
const CollectedClientAdditionalPaymentData = @import("CollectedClientAdditionalPaymentData.zig").CollectedClientAdditionalPaymentData;
const CollectedClientData = @import("CollectedClientData.zig").CollectedClientData;

pub const CollectedClientPaymentData = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from CollectedClientData
    base: CollectedClientData,

    payment: runtime.JSValue,
};
