//! WebIDL dictionary: RTCErrorInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const enums = @import("enums");

pub const RTCErrorInit = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    errorDetail: enums.RTCErrorDetailType,
    sdpLineNumber: ?i32 = null,
    sctpCauseCode: ?i32 = null,
    receivedAlert: ?u32 = null,
    sentAlert: ?u32 = null,
    httpRequestStatusCode: ?i32 = null,
};
