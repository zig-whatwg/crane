//! WebIDL dictionary: BluetoothDataFilterInit
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const BluetoothDataFilterInit = struct {
    dataPrefix: ?typedefs.BufferSource = null,
    mask: ?typedefs.BufferSource = null,
};
