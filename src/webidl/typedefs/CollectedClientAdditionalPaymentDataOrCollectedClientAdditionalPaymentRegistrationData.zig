//! WebIDL typedef: CollectedClientAdditionalPaymentDataOrCollectedClientAdditionalPaymentRegistrationData
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const typedefs = @import("root.zig");
const dictionaries = @import("dictionaries");

pub const CollectedClientAdditionalPaymentDataOrCollectedClientAdditionalPaymentRegistrationData = union(enum) {
    collected_client_additional_payment_data: dictionaries.CollectedClientAdditionalPaymentData,
    collected_client_additional_payment_registration_data: dictionaries.CollectedClientAdditionalPaymentRegistrationData,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "collected_client_additional_payment_data", .kind = .dictionary },
        .{ .field = "collected_client_additional_payment_registration_data", .kind = .dictionary },
    };
};
