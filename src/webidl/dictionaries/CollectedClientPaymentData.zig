//! WebIDL dictionary: CollectedClientPaymentData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CollectedClientData = @import("CollectedClientData.zig").CollectedClientData;

pub const CollectedClientPaymentData = struct {
    // Inherited from CollectedClientData
    base: CollectedClientData,

    payment: anyopaque,
};
