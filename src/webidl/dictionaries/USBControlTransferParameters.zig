//! WebIDL dictionary: USBControlTransferParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const USBControlTransferParameters = struct {
    requestType: enums.USBRequestType,
    recipient: enums.USBRecipient,
    request: u8,
    value: u16,
    index: u16,
};
