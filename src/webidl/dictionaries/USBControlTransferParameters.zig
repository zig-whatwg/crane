//! WebIDL dictionary: USBControlTransferParameters
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");

pub const USBControlTransferParameters = struct {
    requestType: *const anyopaque,
    recipient: *const anyopaque,
    request: u8,
    value: u16,
    index: u16,
};
