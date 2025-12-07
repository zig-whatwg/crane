//! WebIDL dictionary: RTCErrorInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const RTCErrorInit = struct {
    errorDetail: enums.RTCErrorDetailType,
    sdpLineNumber: ?i32 = null,
    sctpCauseCode: ?i32 = null,
    receivedAlert: ?u32 = null,
    sentAlert: ?u32 = null,
    httpRequestStatusCode: ?i32 = null,
};
