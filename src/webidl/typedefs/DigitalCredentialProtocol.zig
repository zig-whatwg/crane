//! WebIDL typedef: DigitalCredentialProtocol
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const DigitalCredentialProtocol = union(enum) {
    digital_credential_presentation_protocol: enums.DigitalCredentialPresentationProtocol,
    digital_credential_issuance_protocol: enums.DigitalCredentialIssuanceProtocol,
};
