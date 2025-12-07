//! WebIDL dictionary: CollectedClientPaymentData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CollectedClientAdditionalPaymentRegistrationData = @import("CollectedClientAdditionalPaymentRegistrationData.zig").CollectedClientAdditionalPaymentRegistrationData;
const CollectedClientAdditionalPaymentData = @import("CollectedClientAdditionalPaymentData.zig").CollectedClientAdditionalPaymentData;
const CollectedClientData = @import("CollectedClientData.zig").CollectedClientData;

pub const CollectedClientPaymentData = struct {
    // Inherited from CollectedClientData
    base: CollectedClientData,

    payment: *const anyopaque,
};
