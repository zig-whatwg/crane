//! WebIDL typedef: DigitalCredentialProtocol
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const enums = @import("enums");

pub const DigitalCredentialProtocol = union(enum) {
    digital_credential_presentation_protocol: enums.DigitalCredentialPresentationProtocol,
    digital_credential_issuance_protocol: enums.DigitalCredentialIssuanceProtocol,

    /// What each field's member type is, for the binding's union conversion
    /// (WebIDL 3.2.25; webidl.union_arms).
    pub const arms = [_]webidl.UnionArm{
        .{ .field = "digital_credential_presentation_protocol", .kind = .enumeration },
        .{ .field = "digital_credential_issuance_protocol", .kind = .enumeration },
    };
};
